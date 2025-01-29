from collections import InlineArray, Optional, Dict
from sys import argv
from pathlib.path import cwd
from memory import OwnedPointer

var debug = False

struct MyFileHandle:
    var file: FileHandle
    var position: Int64

    fn __init__(out self, owned file: FileHandle, position: Int64):
        self.file = file^
        self.position = position

    fn read_bytes(mut self, count: Int64) raises -> List[UInt8]:
        var bytes = self.file.read_bytes(count)
        if debug:
            print("Read", count, "bytes from position", self.position)
            self.position += count
        return bytes

fn main() raises:
    var filename = String(argv()[1]) if len(argv()) > 1 else "listing38"
    var file = MyFileHandle(open(cwd().joinpath(filename), "r"), 0)
    
    
    var output = String()
    try:
        while decode_op(file, output):
            pass
    except e:
        print(color("red", String(e)))
    finally:
        print("; source file: " + filename + "\n")
        print("bits 16\n")
        print(output)

# op_code: OPERATION (INSTRUCTION) CODE
#
# Table 4-7. Single-Bit Field Encoding
# ----------------------------------------------------
# d: DIRECTION IS TO REGISTER/DIRECTION IS FROM REGISTER
# 0: Instruction source is specified in REG field
# 1: Instruction destination is specified in REG field
#
# S is used in conjunction with W to indicate sign extension of immediate fields in arithmetic instructions
#
# 0: No sign extension
# 1: Sign extend 8-bit immediate data to 16 bits if W=1
#
# W: WORD/BYTE OPERATION
#
# 0: Instruction operates on byte data
# 1: Instruction operates on word data
#
# V distinguishes between single- and variable-bit shifts and rotates.
#
# 0: Shift/ rotate count is one
# 1: Shift/rotate count is specified in CL register
#
# Z is used as a compare bit with the zero flag in conditional repeat and loop instructions.
# 0: Repeat/loop while zero flag is clear
# 1: Repeat/loop while zero flag is set
#
# MOD: REGISTER OPERAND/REGISTERS TO USE IN EA CALCULATION
# REG: REGISTER OPERAND/EXTENSION OF OPCODE
# R/M: REGISTER MODE/MEMORY MODE WITH DISPLACEMENT LENGTH
fn decode_op(mut file: MyFileHandle, mut output: String) raises -> Bool:
    if debug:
        print("=====================================")
    var first_byte = file.read_bytes(1)[0]
    if debug:
        print("1. Byte:", bits(first_byte), "  ", color("blue", String(first_byte)))
    return decode_op_mov(first_byte, file, output) or
        decode_op_add(first_byte, file, output) or
        decode_op_sub(first_byte, file, output) or
        decode_op_cmp(first_byte, file, output) or
        decode_op_add_sub_cmp(first_byte, file, output) or
        decode_op_jump(first_byte, file, output)

# MOV
fn decode_op_mov(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    # Register/memory to/from register
    # +------------+------------+-----------+-----------+
    # | 100010 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if first_byte >> 2 == 0b100010:
        var op_code = first_byte >> 2
        var d = (first_byte & 0b00000010) >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var reg = (second_byte & 0b00111000) >> 3
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, file) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, file)
        if debug:
            print(color("green", "mov " + destination + ", " + source))
        output += "mov " + destination + ", " + source + "\n"
        return True

    # Immediate to register/memory
    # +-----------+-------------+-----------+-----------+-----------+---------------+
    # | 1100011 w | mod 000 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----------+-------------+-----------+-----------+-----------+---------------+
    elif first_byte >> 1 == 0b1100011:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(0, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(0, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        destination = decode_rm(rm, w, mod, file)
        source = decode_immediate[DType.uint8](file, mod) if w == 0 else decode_immediate[DType.uint16](file, mod)
        if debug:
            print(color("green", "mov " + destination + ", " + source))
        output += "mov " + destination + ", " + source + "\n"
        return True

    # Immediate to register
    # +------------+-------------+-----------+---------------+
    # | 1011 w reg | mod 000 r/m | data      | data if w = 1 |
    # +------------+-------------+-----------+---------------+
    elif first_byte >> 4 == 0b1011:
        var op_code = first_byte >> 4
        var w = (first_byte & 0b00001000) >> 3
        var reg = first_byte & 0b00000111

        if debug:
            print("Op Code:", bits(op_code, count=4) + dim(bits(w, count=1)) + dim(bits(reg, count=3)), " ", color("yellow", bits(op_code, count=4)))
            print("      W:", dim(bits(op_code, count=4)) + bits(w, count=1) + dim(bits(reg, count=3)), "    ", color("yellow", bits(w, count=1)))
            print("    REG:", dim(bits(op_code, count=4)) + dim(bits(w, count=1)) + bits(reg, count=3), "  ", color("yellow", bits(reg, count=3)))

        destination = decode_reg(reg, w)
        source = decode_immediate[DType.uint8](file) if w == 0 else decode_immediate[DType.uint16](file)
        if debug:
            print(color("green", "mov " + destination + ", " + source))
        output += "mov " + destination + ", " + source + "\n"
        return True

    # Memory to accumulator
    # +-----------+-------------+------+
    # | 1010000 w | addr-lo | addr-hi  |
    # +-----------+-------------+------+
    elif first_byte >> 1 == 0b1010000:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = String(read_value[DType.uint8](file)) if w == 0 else String(read_value[DType.uint16](file))
        if debug:
            print(color("green", "mov ax, " + source))
        output += "mov ax, [" + source + "]\n"
        return True

    # Accumulator to memory
    # +-----------+-------------+------+
    # | 1010001 w | addr-lo | addr-hi  |
    # +-----------+-------------+------+
    elif first_byte >> 1 == 0b1010001:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        destination = String(read_value[DType.uint8](file)) if w == 0 else String(read_value[DType.uint16](file))
        if debug:
            print(color("green", "mov " + destination + ", ax"))
        output += "mov [" + destination + "], ax" + "\n"
        return True
    else:
        return False

# ADD
fn decode_op_add(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 000000 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if first_byte >> 2 == 0b000000:
        var op_code = first_byte >> 2
        var d = (first_byte & 0b00000010) >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var reg = (second_byte & 0b00111000) >> 3
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, file) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, file)
        if debug:
            print(color("green", "add " + destination + ", " + source))
        output += "add " + destination + ", " + source + "\n"
        return True

    # Immediate to accumulator
    # +-----------+------+-------------+
    # | 0000010 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif first_byte >> 1 == 0b0000010:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))


        source = String(read_value[DType.uint8](file)) if w == 0 else String(read_value[DType.uint16](file))
        var reg = String("ax" if w else "al")
        if debug:
            print(color("green", "add " + reg + ", " + source))
        output += "add " + reg + ", " + source + "\n"
        return True
    else:
        return False

# SUB
fn decode_op_sub(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 001010 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if first_byte >> 2 == 0b001010:
        var op_code = first_byte >> 2
        var d = (first_byte & 0b00000010) >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var reg = (second_byte & 0b00111000) >> 3
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, file) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, file)
        if debug:
            print(color("green", "sub " + destination + ", " + source))
        output += "sub " + destination + ", " + source + "\n"
        return True

    # Immediate to accumulator
    # +-----------+------+-------------+
    # | 0010110 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif first_byte >> 1 == 0b0010110:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = String(read_value[DType.uint8](file)) if w == 0 else String(read_value[DType.uint16](file))
        var reg = String("ax" if w else "al")
        if debug:
            print(color("green", "sub " + reg + ", " + source))
        output += "sub " + reg + ", " + source + "\n"
        return True
    else:
        return False

# CMP
fn decode_op_cmp(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 001110 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if first_byte >> 2 == 0b001110:
        var op_code = first_byte >> 2
        var d = (first_byte & 0b00000010) >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var reg = (second_byte & 0b00111000) >> 3
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, file) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, file)
        if debug:
            print(color("green", "cmp " + destination + ", " + source))
        output += "cmp " + destination + ", " + source + "\n"
        return True

    # Immediate with accumulator
    # +-----------+------+-------------+
    # | 0011110 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif first_byte >> 1 == 0b0011110:
        var op_code = first_byte >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = String(read_value[DType.uint8](file)) if w == 0 else String(read_value[DType.uint16](file))
        var reg = String("ax" if w else "al")
        if debug:
            print(color("green", "cmp " + reg + ", " + source))
        output += "cmp " + reg + ", " + source + "\n"
        return True
    else:
        return False

# ADD/SUB/CMP Immediate to register/memory
fn decode_op_add_sub_cmp(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    # Immediate to register/memory
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | ADD | 100000 s w | mod 000 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | SUB | 100000 s w | mod 101 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | CMP | 100000 s w | mod 111 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    if first_byte >> 2 == 0b100000:
        var op_code = first_byte >> 2
        var s = (first_byte & 0b00000010) >> 1
        var w = first_byte & 0b00000001

        if debug:
            print("Op Code:", bits(op_code, count=6) + dim(bits(s, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      S:", dim(bits(op_code, count=6)) + bits(s, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(s, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(s, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        var second_byte = file.read_bytes(1)[0]
        if debug:
            print("2. Byte:", bits(second_byte), "  ", color("blue", String(second_byte)))

        var mod = second_byte >> 6
        var op = (second_byte & 0b00111000) >> 3
        var rm = second_byte & 0b00000111

        if debug:
            print("    MOD:", bits(mod, count=2) + dim(bits(op, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("     OP:", dim(bits(mod, count=2)) + bits(op, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(op, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(op, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        destination = decode_rm(rm, w, mod, file, "byte " if w == 0 else "word ")
        if s and w:
            source = decode_immediate[DType.uint8](file, mod, ignore_bit_text=True)
        elif w:
            source = decode_immediate[DType.uint16](file, mod, ignore_bit_text=True)
        else:
            source = decode_immediate[DType.int8](file, mod, ignore_bit_text=True)
        op_code_str = decode_op_add_sub_cmp(op)
        if debug:
            print(color("green", op_code_str + " " + destination + ", " + source))
        output += op_code_str + " " + destination + ", " + source + "\n"
        return True
    else:   
        return False

fn decode_op_add_sub_cmp(op: UInt8) raises -> String:
    if op == 0b000:
        return "add"
    elif op == 0b101:
        return "sub"
    elif op == 0b111:
        return "cmp"
    else:
        raise "Not implemented op code: " + bits(op, count=3)

# +---------------+-----------------------------------+-------------------+
# | Instruction   | Description                       | Binary Code       |
# +---------------+-----------------------------------+-------------------+
# | JE/JZ         | Jump on equal/zero                | 01110100 IP+INC8  |
# | JL/JNGE       | Jump on less/not greater or equal | 01111100 IP+INC8  |
# | JLE/JNG       | Jump on less or equal/not greater | 01111110 IP+INC8  |
# | JB/JNAE       | Jump on below/not above or equal  | 01110010 IP+INC8  |
# | JBE/JNA       | Jump on below or equal/not above  | 01110110 IP+INC8  |
# | JP/JPE        | Jump on parity/parity even        | 01111010 IP+INC8  |
# | JO            | Jump on overflow                  | 01110000 IP+INC8  |
# | JS            | Jump on sign                      | 01111000 IP+INC8  |
# | JNE/JNZ       | Jump on not equal/not zero        | 01110101 IP+INC8  |
# | JNL/JGE       | Jump on not less/greater or equal | 01111101 IP+INC8  |
# | JNLE/JG       | Jump on not less or equal/greater | 01111111 IP+INC8  |
# | JNB/JAE       | Jump on not below/above or equal  | 01110011 IP+INC8  |
# | JNBE/JA       | Jump on not below or equal/above  | 01110111 IP+INC8  |
# | JNP/JPO       | Jump on not par/par odd           | 01111011 IP+INC8  |
# | JNO           | Jump on not overflow              | 01110001 IP+INC8  |
# | JNS           | Jump on not sign                  | 01111001 IP+INC8  |
# | LOOP          | Loop CX times                     | 11100010 IP+INC8  |
# | LOOPZ/LOOPE   | Loop while zero/equal             | 11100001 IP+INC8  |
# | LOOPNZ/LOOPNE | Loop while not zero/equal         | 11100000 IP+INC8  |
# | JCXZ          | Jump on CX zero                   | 11100011 IP+INC8  |
# +---------------+-----------------------------------+-------------------+
fn decode_op_jump(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    var op_str = ""

    if first_byte == 0b01110100:
        op_str = "je"
    elif first_byte == 0b01111100:
        op_str = "jl"
    elif first_byte == 0b01111110:
        op_str = "jle"
    elif first_byte == 0b01110010:
        op_str = "jb"
    elif first_byte == 0b01110110:
        op_str = "jbe"
    elif first_byte == 0b01111010:
        op_str = "jp"
    elif first_byte == 0b01110000:
        op_str = "jo"
    elif first_byte == 0b01111000:
        op_str = "js"
    elif first_byte == 0b01110101:
        op_str = "jne"
    elif first_byte == 0b01111101:
        op_str = "jnl"
    elif first_byte == 0b01111111:
        op_str = "jnle"
    elif first_byte == 0b01110011:
        op_str = "jnb"
    elif first_byte == 0b01110111:
        op_str = "jnbe"
    elif first_byte == 0b01111011:
        op_str = "jnp"
    elif first_byte == 0b01110001:
        op_str = "jno"
    elif first_byte == 0b01111001:
        op_str = "jns"
    elif first_byte == 0b11100010:
        op_str = "loop"
    elif first_byte == 0b11100001:
        op_str = "loopz"
    elif first_byte == 0b11100000:
        op_str = "loopnz"
    elif first_byte == 0b11100011:
        op_str = "jcxz"

    if op_str != "":
        var instr_ptr = read_value[DType.int8](file)
        if debug:
            print(color("green", String(op_str) + " " + String(instr_ptr)))
        output += String(op_str) + " $" + String(instr_ptr) + "\n"
        return True
    else:
        return False

fn decode_op_other(first_byte: UInt8, mut file: MyFileHandle, mut output: String) raises -> Bool:
    var op_str = ""

    if first_byte == 0b11111100:
        op_str = "cld"

    if op_str != "":
        if debug:
            print(color("green", String(op_str)))
        output += String(op_str) + "\n"
        return True
    else:
        return False

fn decode_immediate[type: DType](mut file: MyFileHandle, mod: UInt8 = 0b00, ignore_bit_text: Bool = False) raises -> String:
    @parameter
    bit_text = "byte" if type.sizeof() == 1 else "word"

    var value = String(read_value[type](file))
    return value if mod == 0b11 or ignore_bit_text else bit_text + " " + value

# Table 4-9. REG (Register) Field Encoding
# +-------+-----+-----+
# | REG   | W=0 | W=1 |
# +-------+-----+-----+
# | 000   | AL  | AX  |
# | 001   | CL  | CX  |
# | 010   | DL  | DX  |
# | 011   | BL  | BX  |
# | 100   | AH  | SP  |
# | 101   | CH  | BP  |
# | 110   | DH  | SI  |
# | 111   | BH  | DI  |
# +-------+-----+-----+
fn decode_reg(reg: UInt8, w: UInt8) -> String:
    if reg == 0b000:
        return "al" if w == 0 else "ax"
    elif reg == 0b001:
        return "cl" if w == 0 else "cx"
    elif reg == 0b010:
        return "dl" if w == 0 else "dx"
    elif reg == 0b011:
        return "bl" if w == 0 else "bx"
    elif reg == 0b100:
        return "ah" if w == 0 else "sp"
    elif reg == 0b101:
        return "ch" if w == 0 else "bp"
    elif reg == 0b110:
        return "dh" if w == 0 else "si"
    else:
        return "bh" if w == 0 else "di"

#
# Table 4-8. MOD (Mode) Field Encoding
# +------+------------------------------------------+
# | CODE | EXPLANATION                              |
# +------+------------------------------------------+
# | 00   | Memory Mode, no displacement follows*    |
# | 01   | Memory Mode, 8-bit displacement follows  |
# | 10   | Memory Mode, 16-bit displacement follows |
# | 11   | Register Mode (no displacement)          |
# +------+------------------------------------------+
# *Except when R/M = 110, then 16-bit displacement follows
#
# Table 4-10. R/M (Register/Memory) Field Encoding
# +-----+-----+-----+-----+------------------------------------------------------+
# | MOD = 11              | EFFECTIVE ADDRESS CALCULATION                        |
# +-----+-----+-----+-----+------------------------------------------------------+
# | R/M | W=0 | W=1 | R/M | MOD=00       | MOD=01            | MOD=10            |
# +-----+-----+-----+-----+------------------------------------------------------+
# | 000 | AL  | AX  | 000 | (BX) + (SI)  | (BX) + (SI) + D8  | (BX) + (SI) + D16 |
# | 001 | CL  | CX  | 001 | (BX) + (DI)  | (BX) + (DI) + D8  | (BX) + (DI) + D16 |
# | 010 | DL  | DX  | 010 | (BP) + (SI)  | (BP) + (SI) + D8  | (BP) + (SI) + D16 |
# | 011 | BL  | BX  | 011 | (BP) + (DI)  | (BP) + (DI) + D8  | (BP) + (DI) + D16 |
# | 100 | AH  | SP  | 100 | (SI)         | (SI) + D8         | (SI) + D16        |
# | 101 | CH  | BP  | 101 | (DI)         | (DI) + D8         | (DI) + D16        |
# | 110 | DH  | SI  | 110 | DIRECT ADDR  | (BP) + D8         | (BP) + D16        |
# | 111 | BH  | DI  | 111 | (BX)         | (BX) + D8         | (BX) + D16        |
# +-----+-----+-----+-----+------------------------------------------------------+
fn decode_rm(rm: UInt8, w: UInt8, mod: UInt8, mut file: MyFileHandle, bit_text: String = "") raises -> String:
    if mod == 0b11:
        return decode_reg(rm, w)
    else:
        return decode_memory(rm, w, mod, file, bit_text)

fn decode_memory(rm: UInt8, w: UInt8, mod: UInt8, mut file: MyFileHandle, bit_text: String = "") raises -> String:
    if mod == 0b00:
        if rm == 0b000:
            return bit_text + "[bx + si]"
        elif rm == 0b001:
            return bit_text + "[bx + di]"
        elif rm == 0b010:
            return bit_text + "[bp + si]"
        elif rm == 0b011:
            return bit_text + "[bp + di]"
        elif rm == 0b100:
            return bit_text + "[si]"
        elif rm == 0b101:
            return bit_text + "[di]"
        elif rm == 0b110:
            return bit_text + "[" + String(read_value[DType.uint16](file)) + "]"
        else:
            return bit_text + "[bx]"
    elif mod == 0b01:
        if rm == 0b000:
            return bit_text + "[" + disp[DType.int8]("bx + si", file) + "]"
        elif rm == 0b001:
            return bit_text + "[" + disp[DType.int8]("bx + di", file) + "]"
        elif rm == 0b010:
            return bit_text + "[" + disp[DType.int8]("bp + si", file) + "]"
        elif rm == 0b011:
            return bit_text + "[" + disp[DType.int8]("bp + di", file) + "]"
        elif rm == 0b100:
            return bit_text + "[" + disp[DType.int8]("si", file) + "]"
        elif rm == 0b101:
            return bit_text + "[" + disp[DType.int8]("di", file) + "]"
        elif rm == 0b110:
            return bit_text + "[" + disp[DType.int8]("bp", file) + "]"
        else:
            return bit_text + "[" + disp[DType.int8]("bx", file) + "]"
    else:
        if rm == 0b000:
            return bit_text + "[" + disp[DType.int16]("bx + si", file) + "]"
        elif rm == 0b001:
            return bit_text + "[" + disp[DType.int16]("bx + di", file) + "]"
        elif rm == 0b010:
            return bit_text + "[" + disp[DType.int16]("bp + si", file) + "]"
        elif rm == 0b011:
            return bit_text + "[" + disp[DType.int16]("bp + di", file) + "]"
        elif rm == 0b100:
            return bit_text + "[" + disp[DType.int16]("si", file) + "]"
        elif rm == 0b101:
            return bit_text + "[" + disp[DType.int16]("di", file) + "]"
        elif rm == 0b110:
            return bit_text + "[" + disp[DType.int16]("bp", file) + "]"
        else:
            return bit_text + "[" + disp[DType.int16]("bx", file) + "]"

fn disp[type: DType](reg_str: String, mut file: MyFileHandle) raises -> String:
    var disp = read_value[type](file)
    if disp > 0:
        return reg_str + " + " + String(disp)
    elif disp < 0:
        return reg_str + " - " + String(-disp)
    else:
        return reg_str

fn read_value[type: DType](mut file: MyFileHandle) raises -> SIMD[type, 1]:
    var bytes = file.read_bytes(type.sizeof())
    @parameter
    if type.sizeof() == 1:
        return SIMD[type, 1](bytes[0])
    else:
        return SIMD[type, 1](bytes[1]) << 8 | SIMD[type, 1](bytes[0])
        
fn bits(byte: UInt8, count: UInt8 = 8) -> String:   
    var bits = InlineArray[UInt8, 8](fill=0)
    var my_byte = byte
    for i in range(8):
        bits[7 - i] = my_byte & 1
        my_byte >>= 1

    var bits_string = String()
    for i in range(8 - count, 8):
        bits_string += String(bits[i])

    return bits_string

fn color(color: StringLiteral, text: String) -> String:
    var colors = Dict[String, UInt8]()
    colors["red"] = 31
    colors["green"] = 32
    colors["yellow"] = 33
    colors["blue"] = 34
    colors["magenta"] = 35
    colors["cyan"] = 36
    colors["white"] = 37
    colors["bold"] = 1
    colors["dim"] = 2

    try:
        return "\x1b[" + String(colors[color]) + "m" + text + "\x1b[0m"
    except:
        return text

fn dim(text: String) raises -> String:
    return color("dim", text)