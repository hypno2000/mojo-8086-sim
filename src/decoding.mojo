from collections import List, InlineArray, Dict
from virtual_machine import Instruction, RegisterType, MemoryExpression, Operand
from pathlib.path import Path
from util import *

alias debug = False
alias instr_buffer_size = 6

fn decode_file(file_path: Path) raises -> List[Instruction]:
    var file = open(file_path, "r")
    var bytes = InlineArray[UInt8, instr_buffer_size](0)
    read_bytes(bytes, file, instr_buffer_size)
    var instructions = List[Instruction]()

    var instr = decode_instr(bytes)
    while instr:
        print(String(instr))
        instructions.append(instr)
        read_bytes(bytes, file, instr.size)
        instr = decode_instr(bytes)

    return instructions

fn read_bytes[size: Int](mut bytes: InlineArray[UInt8, size], file: FileHandle, count: UInt8) raises:
    """Reads `count` bytes from the file and stores them in the bytes array.

    If `count` is smaller than the `size` of the bytes array, then the existing
    bytes are shifted to the left to make space for the new bytes.
    """
    if count > size:
        raise "Count is greater than size"

    for i in range(size - count):
        bytes[i] = bytes[i + count]

    bytes_list = file.read_bytes(Int(count))

    for i in range(count):
        bytes[size - count + i] = bytes_list[i] if i < len(bytes_list) else 0

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
fn decode_instr(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    if bytes[0] == 0x00 and bytes[1] == 0x00:
        return Instruction.invalid

    return decode_op_mov(bytes) or
        decode_op_add(bytes) or
        decode_op_sub(bytes) or
        decode_op_cmp(bytes) or
        decode_op_add_sub_cmp(bytes) or
        decode_op_jump(bytes)

# MOV
fn decode_op_mov(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    # Register/memory to/from register
    # +------------+------------+-----------+-----------+
    # | 100010 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if bytes[0] >> 2 == 0b100010:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 2
        var d = (bytes[0] & 0b00000010) >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var reg = (bytes[1] & 0b00111000) >> 3
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, bytes, byte_index) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, bytes, byte_index)
        
        return Instruction(Instruction.mov.op, byte_index, 16 if w else 8, source, destination)

    # Immediate to register/memory
    # +-----------+-------------+-----------+-----------+-----------+---------------+
    # | 1100011 w | mod 000 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----------+-------------+-----------+-----------+-----------+---------------+
    elif bytes[0] >> 1 == 0b1100011:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(0, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(0, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        destination = decode_rm(rm, w, mod, bytes, byte_index)
        source = decode_immediate(w, bytes, byte_index)

        return Instruction(Instruction.mov.op, byte_index, 16 if w else 8, source, destination)

    # Immediate to register
    # +------------+-------------+-----------+---------------+
    # | 1011 w reg | mod 000 r/m | data      | data if w = 1 |
    # +------------+-------------+-----------+---------------+
    elif bytes[0] >> 4 == 0b1011:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 4
        var w = (bytes[0] & 0b00001000) >> 3
        var reg = bytes[0] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=4) + dim(bits(w, count=1)) + dim(bits(reg, count=3)), " ", color("yellow", bits(op_code, count=4)))
            print("      W:", dim(bits(op_code, count=4)) + bits(w, count=1) + dim(bits(reg, count=3)), "    ", color("yellow", bits(w, count=1)))
            print("    REG:", dim(bits(op_code, count=4)) + dim(bits(w, count=1)) + bits(reg, count=3), "  ", color("yellow", bits(reg, count=3)))

        destination = decode_reg(reg, w)
        source = decode_immediate(w, bytes, byte_index)
        
        return Instruction(Instruction.mov.op, byte_index, 16 if w else 8, source, destination)

    # Memory to accumulator
    # +-----------+-------------+------+
    # | 1010000 w | addr-lo | addr-hi  |
    # +-----------+-------------+------+
    elif bytes[0] >> 1 == 0b1010000:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = Operand(mem_expr=MemoryExpression(displacement=Int16(read_value[DType.uint8](bytes, byte_index)) if w == 0 else read_value[DType.int16](bytes, byte_index)))
        destination = Operand(register=RegisterType.ax)

        return Instruction(Instruction.mov.op, byte_index, 16 if w else 8, source, destination)

    # Accumulator to memory
    # +-----------+-------------+------+
    # | 1010001 w | addr-lo | addr-hi  |
    # +-----------+-------------+------+
    elif bytes[0] >> 1 == 0b1010001:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = Operand(register=RegisterType.ax)
        destination = Operand(mem_expr=MemoryExpression(displacement=Int16(read_value[DType.uint8](bytes, byte_index)) if w == 0 else read_value[DType.int16](bytes, byte_index)))

        return Instruction(Instruction.mov.op, byte_index, 16 if w else 8, source, destination)
    else:
        return Instruction.invalid

# ADD
fn decode_op_add(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 000000 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if bytes[0] >> 2 == 0b000000:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 2
        var d = (bytes[0] & 0b00000010) >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var reg = (bytes[1] & 0b00111000) >> 3
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, bytes, byte_index) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, bytes, byte_index)

        return Instruction(Instruction.add.op, byte_index, 16 if w else 8, source, destination)

    # Immediate to accumulator
    # +-----------+------+-------------+
    # | 0000010 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif bytes[0] >> 1 == 0b0000010:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = decode_immediate(w, bytes, byte_index)
        destination = Operand(register=RegisterType.ax if w else RegisterType.al)

        return Instruction(Instruction.add.op, byte_index, 16 if w else 8, source, destination)
    else:
        return Instruction.invalid

# SUB
fn decode_op_sub(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 001010 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if bytes[0] >> 2 == 0b001010:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 2
        var d = (bytes[0] & 0b00000010) >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var reg = (bytes[1] & 0b00111000) >> 3
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, bytes, byte_index) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, bytes, byte_index)

        return Instruction(Instruction.sub.op, byte_index, 16 if w else 8, source, destination)

    # Immediate to accumulator
    # +-----------+------+-------------+
    # | 0010110 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif bytes[0] >> 1 == 0b0010110:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = decode_immediate(w, bytes, byte_index)
        destination = Operand(register=RegisterType.ax if w else RegisterType.al)

        return Instruction(Instruction.sub.op, byte_index, 16 if w else 8, source, destination)
    else:
        return Instruction.invalid

# CMP
fn decode_op_cmp(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    # Reg/memory with register to either
    # +------------+------------+-----------+-----------+
    # | 001110 d w | mod reg rm | (DISP-LO) | (DISP-HI) |
    # +------------+------------+-----------+-----------+
    if bytes[0] >> 2 == 0b001110:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 2
        var d = (bytes[0] & 0b00000010) >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var reg = (bytes[1] & 0b00111000) >> 3
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=6) + dim(bits(d, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      D:", dim(bits(op_code, count=6)) + bits(d, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(d, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(d, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(reg, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("    REG:", dim(bits(mod, count=2)) + bits(reg, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(reg, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(reg, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        source = decode_rm(rm, w, mod, bytes, byte_index) if d else decode_reg(reg, w)  
        destination = decode_reg(reg, w) if d else decode_rm(rm, w, mod, bytes, byte_index)

        return Instruction(Instruction.cmp.op, byte_index, 16 if w else 8, source, destination)

    # Immediate with accumulator
    # +-----------+------+-------------+
    # | 0011110 w | data | data if w=1 |
    # +-----------+------+-------------+
    elif bytes[0] >> 1 == 0b0011110:
        var byte_index: UInt8 = 1
        var op_code = bytes[0] >> 1
        var w = bytes[0] & 0b00000001

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=7) + dim(bits(w, count=1)), " ", color("yellow", bits(op_code, count=7)))
            print("      W:", dim(bits(op_code, count=7)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))

        source = decode_immediate(w, bytes, byte_index)
        destination = Operand(register=RegisterType.ax if w else RegisterType.al)

        return Instruction(Instruction.cmp.op, byte_index, 16 if w else 8, source, destination)
    else:
        return Instruction.invalid

# ADD/SUB/CMP Immediate to register/memory
fn decode_op_add_sub_cmp(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    # Immediate to register/memory
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | ADD | 100000 s w | mod 000 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | SUB | 100000 s w | mod 101 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    # | CMP | 100000 s w | mod 111 r/m | (DISP-LO) | (DISP-HI) | data      | data if w = 1 |
    # +-----+------------+-------------+-----------+-----------+-----------+---------------+
    if bytes[0] >> 2 == 0b100000:
        var byte_index: UInt8 = 2
        var op_code = bytes[0] >> 2
        var s = (bytes[0] & 0b00000010) >> 1
        var w = bytes[0] & 0b00000001
        var mod = bytes[1] >> 6
        var op = (bytes[1] & 0b00111000) >> 3
        var rm = bytes[1] & 0b00000111

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))
            print("Op Code:", bits(op_code, count=6) + dim(bits(s, count=1)) + dim(bits(w, count=1)), color("yellow", bits(op_code, count=6)))
            print("      S:", dim(bits(op_code, count=6)) + bits(s, count=1) + dim(bits(w, count=1)), "    ", color("yellow", bits(s, count=1)))
            print("      W:", dim(bits(op_code, count=6)) + dim(bits(s, count=1)) + bits(w, count=1), "    ", color("yellow", bits(w, count=1)))
            print("2. Byte:", bits(bytes[1]), "  ", color("blue", String(bytes[1])))
            print("    MOD:", bits(mod, count=2) + dim(bits(op, count=3)) + dim(bits(rm, count=3)), "   ", color("yellow", bits(mod, count=2)))
            print("     OP:", dim(bits(mod, count=2)) + bits(op, count=3) + dim(bits(rm, count=3)), "  ", color("yellow", bits(op, count=3)))
            print("    R/M:", dim(bits(mod, count=2)) + dim(bits(op, count=3)) + bits(rm, count=3), "  ", color("yellow", bits(rm, count=3)))

        destination = decode_rm(rm, w, mod, bytes, byte_index)

        source = Operand(immediate=UInt16(read_value[DType.uint8](bytes, byte_index)), imm_signed=Bool(s)) if s and w else
                 Operand(immediate=UInt16(read_value[DType.uint16](bytes, byte_index)), imm_signed=Bool(s)) if w else
                 Operand(immediate=UInt16(read_value[DType.int8](bytes, byte_index)), imm_signed=Bool(s))
        
        var instr_op = Instruction.add.op if op == 0b000 else
                      Instruction.sub.op if op == 0b101 else
                      Instruction.cmp.op if op == 0b111 else
                      Instruction.invalid.op

        return Instruction(instr_op, byte_index, 16 if w else 8, source, destination)
    else:   
        return Instruction.invalid

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
fn decode_op_jump(bytes: InlineArray[UInt8, instr_buffer_size]) -> Instruction:
    var instr = Instruction.invalid

    if bytes[0] == 0b01110100:
        instr = Instruction.je
    elif bytes[0] == 0b01111100:
        instr = Instruction.jl
    elif bytes[0] == 0b01111110:
        instr = Instruction.jle
    elif bytes[0] == 0b01110010:
        instr = Instruction.jb
    elif bytes[0] == 0b01110110:
        instr = Instruction.jbe
    elif bytes[0] == 0b01111010:
        instr = Instruction.jp
    elif bytes[0] == 0b01110000:
        instr = Instruction.jo
    elif bytes[0] == 0b01111000:
        instr = Instruction.js
    elif bytes[0] == 0b01110101:
        instr = Instruction.jne
    elif bytes[0] == 0b01111101:
        instr = Instruction.jnl
    elif bytes[0] == 0b01111111:
        instr = Instruction.jnle
    elif bytes[0] == 0b01110011:
        instr = Instruction.jnb
    elif bytes[0] == 0b01110111:
        instr = Instruction.jnbe
    elif bytes[0] == 0b01111011:
        instr = Instruction.jnp
    elif bytes[0] == 0b01110001:
        instr = Instruction.jno
    elif bytes[0] == 0b01111001:
        instr = Instruction.jns
    elif bytes[0] == 0b11100010:
        instr = Instruction.loop
    elif bytes[0] == 0b11100001:
        instr = Instruction.loopz
    elif bytes[0] == 0b11100000:
        instr = Instruction.loopnz
    elif bytes[0] == 0b11100011:
        instr = Instruction.jcxz

    if instr:
        var byte_index: UInt8 = 1
        var instr_ptr = Operand(instr_ptr=read_value[DType.int8](bytes, byte_index))

        @parameter
        if debug:
            print("1. Byte:", bits(bytes[0]), "  ", color("blue", String(bytes[0])))

        return Instruction(instr.op, byte_index, 16, destination=instr_ptr)
    else:
        return Instruction.invalid

fn decode_immediate(w: UInt8, bytes: InlineArray[UInt8, instr_buffer_size], mut byte_index: UInt8) -> Operand:
    return Operand(immediate=UInt16(read_value[DType.uint8](bytes, byte_index)) if w == 0 else read_value[DType.uint16](bytes, byte_index))

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
fn decode_reg(reg: UInt8, w: UInt8) -> Operand:
    if reg == 0b000:
        return Operand(register=RegisterType.al if w == 0 else RegisterType.ax)
    elif reg == 0b001:
        return Operand(register=RegisterType.cl if w == 0 else RegisterType.cx)
    elif reg == 0b010:
        return Operand(register=RegisterType.dl if w == 0 else RegisterType.dx)
    elif reg == 0b011:
        return Operand(register=RegisterType.bl if w == 0 else RegisterType.bx)
    elif reg == 0b100:
        return Operand(register=RegisterType.ah if w == 0 else RegisterType.sp)
    elif reg == 0b101:
        return Operand(register=RegisterType.ch if w == 0 else RegisterType.bp)
    elif reg == 0b110:
        return Operand(register=RegisterType.dh if w == 0 else RegisterType.si)
    else:
        return Operand(register=RegisterType.bh if w == 0 else RegisterType.di)

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
fn decode_rm(rm: UInt8, w: UInt8, mod: UInt8, bytes: InlineArray[UInt8, instr_buffer_size], mut byte_index: UInt8) -> Operand:
    if mod == 0b11:
        return decode_reg(rm, w)
    else:
        return Operand(mem_expr=decode_memory(rm, w, mod, bytes, byte_index))

fn decode_memory(rm: UInt8, w: UInt8, mod: UInt8, bytes: InlineArray[UInt8, instr_buffer_size], mut byte_index: UInt8) -> MemoryExpression:
    if mod == 0b00:
        if rm == 0b000:
            return MemoryExpression(RegisterType.bx, RegisterType.si)
        elif rm == 0b001:
            return MemoryExpression(RegisterType.bx, RegisterType.di)
        elif rm == 0b010:
            return MemoryExpression(RegisterType.bp, RegisterType.si)
        elif rm == 0b011:
            return MemoryExpression(RegisterType.bp, RegisterType.di)
        elif rm == 0b100:
            return MemoryExpression(index_reg=RegisterType.si)
        elif rm == 0b101:
            return MemoryExpression(index_reg=RegisterType.di)
        elif rm == 0b110:
            return MemoryExpression(displacement=Int16(read_value[DType.uint16](bytes, byte_index)))
        else:
            return MemoryExpression(base_reg=RegisterType.bx)
    elif mod == 0b01:
        if rm == 0b000:
            return MemoryExpression(RegisterType.bx, RegisterType.si, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b001:
            return MemoryExpression(RegisterType.bx, RegisterType.di, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b010:
            return MemoryExpression(RegisterType.bp, RegisterType.si, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b011:
            return MemoryExpression(RegisterType.bp, RegisterType.di, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b100:
            return MemoryExpression(index_reg=RegisterType.si, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b101:
            return MemoryExpression(index_reg=RegisterType.di, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        elif rm == 0b110:
            return MemoryExpression(base_reg=RegisterType.bp, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
        else:
            return MemoryExpression(base_reg=RegisterType.bx, displacement=Int16(read_value[DType.int8](bytes, byte_index)))
    else:
        if rm == 0b000:
            return MemoryExpression(RegisterType.bx, RegisterType.si, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b001:
            return MemoryExpression(RegisterType.bx, RegisterType.di, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b010:
            return MemoryExpression(RegisterType.bp, RegisterType.si, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b011:
            return MemoryExpression(RegisterType.bp, RegisterType.di, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b100:
            return MemoryExpression(index_reg=RegisterType.si, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b101:
            return MemoryExpression(index_reg=RegisterType.di, displacement=read_value[DType.int16](bytes, byte_index))
        elif rm == 0b110:
            return MemoryExpression(base_reg=RegisterType.bp, displacement=read_value[DType.int16](bytes, byte_index))
        else:
            return MemoryExpression(base_reg=RegisterType.bx, displacement=read_value[DType.int16](bytes, byte_index))

fn read_value[type: DType](bytes: InlineArray[UInt8, instr_buffer_size], mut byte_index: UInt8) -> SIMD[type, 1]:
    @parameter
    if type.sizeof() == 1:
        var byte = bytes[byte_index]
        byte_index += 1
        return SIMD[type, 1](byte)
    else:
        var byte1 = bytes[byte_index]
        byte_index += 1
        var byte2 = bytes[byte_index]
        byte_index += 1
        return SIMD[type, 1](byte2) << 8 | SIMD[type, 1](byte1)
        