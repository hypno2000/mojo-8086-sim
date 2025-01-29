from collections import InlineArray, Optional
from memory import OwnedPointer
from util import *
from decoding import decode_instr, instr_buffer_size, debug

alias memory_size = 65535

struct Computer:
    var cpu: OwnedPointer[CPU]
    var memory: Memory

    fn __init__(out self):
        self.cpu = OwnedPointer(CPU())
        self.memory = Memory()

    fn effective_address(self, expr: MemoryExpression) -> UInt16:
        var base_reg = self.cpu[].get_reg[DType.uint16](expr.base_reg.value()) if expr.base_reg else 0
        var index_reg = self.cpu[].get_reg[DType.uint16](expr.index_reg.value()) if expr.index_reg else 0
        var displacement = expr.displacement.value() if expr.displacement else 0
        return UInt16(Int16(base_reg + index_reg) + displacement)

    fn get_value[type: DType](self, operand: Operand) raises -> SIMD[type, 1]:
        if operand.register:
            return self.cpu[].get_reg[type](operand.register.value())
        elif operand.mem_expr:
            return self.memory.load[type](self.effective_address(operand.mem_expr.value()))
        elif operand.immediate:
            return SIMD[type, 1](operand.immediate.value())
        elif operand.instr_ptr:
            return SIMD[type, 1](operand.instr_ptr.value())
        else:
            print(color("yellow", "Unable to get value of: " + String(operand)))
            return SIMD[type, 1](0)

    fn set_value[type: DType](mut self, operand: Operand, value: SIMD[type, 1]) raises:
        if operand.register:
            self.cpu[].set_reg[type](operand.register.value(), value)
            @parameter
            if debug:
                self.cpu[].print_reg(operand.register.value())
        elif operand.mem_expr:
            self.memory.store[type](self.effective_address(operand.mem_expr.value()), value)
        else:
            print(color("yellow", "Unable to set value of: " + String(operand)))
            return

    fn run_program(mut self, instr_bytes: List[UInt8]) raises -> Int8:
        # load the program into memory
        for i in range(len(instr_bytes)):
            self.memory.store[DType.uint8](i, instr_bytes[i])

        # set the instruction pointer to the first instruction
        self.cpu[].set_reg[DType.uint16](RegisterType.ip, 0)

        # run the first instruction
        while self.run_instruction():
            pass
        return 0

    fn run_instruction(mut self) raises -> Instruction:
        # get the instruction pointer
        var ip = self.cpu[].get_reg[DType.uint16](RegisterType.ip)

        # read the instruction from memory
        var buffer = self.memory.load[instr_buffer_size](ip)

        # decode the instruction
        var instr = decode_instr(buffer)

        if instr != Instruction.invalid:
            # increment the instruction pointer
            self.cpu[].set_reg[DType.uint16](RegisterType.ip, ip + UInt16(instr.size))

            # execute the instruction
            instr.execute(self)

        return instr

    fn core_dump(self):
        self.cpu[].print_registers()
        self.memory.dump()

@value
struct CPU:
    # Instruction Pointer Register
    var ip: InlineArray[UInt8, 2]
    # Accumulator Register
    var ax: InlineArray[UInt8, 2]
    # Base Register
    var bx: InlineArray[UInt8, 2]
    # Counter Register
    var cx: InlineArray[UInt8, 2]
    # Data Register
    var dx: InlineArray[UInt8, 2]
    # Base Pointer Register
    var bp: InlineArray[UInt8, 2]
    # Stack Pointer Register
    var sp: InlineArray[UInt8, 2]
    # Source Index Register
    var si: InlineArray[UInt8, 2]
    # Destination Index Register
    var di: InlineArray[UInt8, 2]
    # Flags Register
    var flags: UInt16

    fn __init__(out self):
        self.ip = InlineArray[UInt8, 2](0)
        self.ax = InlineArray[UInt8, 2](0)
        self.bx = InlineArray[UInt8, 2](0)
        self.cx = InlineArray[UInt8, 2](0)
        self.dx = InlineArray[UInt8, 2](0)
        self.bp = InlineArray[UInt8, 2](0)
        self.sp = InlineArray[UInt8, 2](0)
        self.si = InlineArray[UInt8, 2](0)
        self.di = InlineArray[UInt8, 2](0)
        self.flags = 0

    fn print_registers(self):
        print("================= REGISTERS ====================")
        self.print_reg(RegisterType.ax)
        self.print_reg(RegisterType.bx)
        self.print_reg(RegisterType.cx)
        self.print_reg(RegisterType.dx)
        self.print_reg(RegisterType.bp)
        self.print_reg(RegisterType.sp)
        self.print_reg(RegisterType.si)
        self.print_reg(RegisterType.di)
        self.print_reg(RegisterType.ip)
        self.print_flags()
        print("================================================")

    fn print_reg(self, register_type: RegisterType):
        if register_type == RegisterType.ax:
            print("             ax:", bytes_to_bin(self.ax), bytes_to_hex(self.ax), pad_left(combine_bytes(self.ax), 5), bytes_to_string(self.ax))
        elif register_type == RegisterType.bx:
            print("             bx:", bytes_to_bin(self.bx), bytes_to_hex(self.bx), pad_left(combine_bytes(self.bx), 5), bytes_to_string(self.bx))
        elif register_type == RegisterType.cx:
            print("             cx:", bytes_to_bin(self.cx), bytes_to_hex(self.cx), pad_left(combine_bytes(self.cx), 5), bytes_to_string(self.cx))
        elif register_type == RegisterType.dx:
            print("             dx:", bytes_to_bin(self.dx), bytes_to_hex(self.dx), pad_left(combine_bytes(self.dx), 5), bytes_to_string(self.dx))
        elif register_type == RegisterType.bp:
            print("             bp:", bytes_to_bin(self.bp), bytes_to_hex(self.bp), pad_left(combine_bytes(self.bp), 5))
        elif register_type == RegisterType.sp:
            print("             sp:", bytes_to_bin(self.sp), bytes_to_hex(self.sp), pad_left(combine_bytes(self.sp), 5))
        elif register_type == RegisterType.si:
            print("             si:", bytes_to_bin(self.si), bytes_to_hex(self.si), pad_left(combine_bytes(self.si), 5))
        elif register_type == RegisterType.di:
            print("             di:", bytes_to_bin(self.di), bytes_to_hex(self.di), pad_left(combine_bytes(self.di), 5))
        elif register_type == RegisterType.ip:
            print("             ip:", bytes_to_bin(self.ip), bytes_to_hex(self.ip), pad_left(combine_bytes(self.ip), 5))

    fn print_flags(self):
        flag_bytes = split_bytes[True](self.flags)
        print("flags:", bytes_to_bin(flag_bytes), bytes_to_hex(flag_bytes), self.get_flags())

    fn set_ip(mut self, offset: Int8):
        var ip = self.get_reg[DType.uint16](RegisterType.ip)
        self.set_reg[DType.uint16](RegisterType.ip, UInt16(Int16(ip) + Int16(offset)))

    fn get_reg[type: DType](self, register_type: RegisterType) -> SIMD[type, 1]:
        @parameter
        if type.bitwidth() == 8:
            if register_type == RegisterType.al:
                return SIMD[type, 1](self.ax[0])
            elif register_type == RegisterType.ah:
                return SIMD[type, 1](self.ax[1])
            elif register_type == RegisterType.bl:
                return SIMD[type, 1](self.bx[0])
            elif register_type == RegisterType.bh:
                return SIMD[type, 1](self.bx[1])
            elif register_type == RegisterType.cl:
                return SIMD[type, 1](self.cx[0])
            elif register_type == RegisterType.ch:
                return SIMD[type, 1](self.cx[1])
            elif register_type == RegisterType.dl:
                return SIMD[type, 1](self.dx[0])
            elif register_type == RegisterType.dh:
                return SIMD[type, 1](self.dx[1])
        else:
            if register_type == RegisterType.ip:
                return SIMD[type, 1](combine_bytes(self.ip))
            elif register_type == RegisterType.ax:
                return SIMD[type, 1](combine_bytes(self.ax))
            elif register_type == RegisterType.bx:
                return SIMD[type, 1](combine_bytes(self.bx))
            elif register_type == RegisterType.cx:
                return SIMD[type, 1](combine_bytes(self.cx))
            elif register_type == RegisterType.dx:
                return SIMD[type, 1](combine_bytes(self.dx))
            elif register_type == RegisterType.bp:
                return SIMD[type, 1](combine_bytes(self.bp))
            elif register_type == RegisterType.sp:
                return SIMD[type, 1](combine_bytes(self.sp))
            elif register_type == RegisterType.si:
                return SIMD[type, 1](combine_bytes(self.si))
            elif register_type == RegisterType.di:
                return SIMD[type, 1](combine_bytes(self.di))
    
        print(color("yellow", "Get: Invalid register type for " + String(type.bitwidth()) + "bit data type: " + String(register_type)))
        return SIMD[type, 1](0)

    fn set_reg[type: DType](mut self, register_type: RegisterType, value: SIMD[type, 1]):
        if register_type == RegisterType.ip:
            self.ip = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.ax:
            self.ax = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.bx:
            self.bx = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.cx:
            self.cx = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.dx:
            self.dx = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.bp:
            self.bp = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.sp:
            self.sp = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.si:
            self.si = split_bytes(SIMD[DType.uint16, 1](value))
        elif register_type == RegisterType.di:
            self.di = split_bytes(SIMD[DType.uint16, 1](value))

        @parameter
        if type.bitwidth() == 8:
            if register_type == RegisterType.al:
                self.ax[0] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.ah:
                self.ax[1] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.bl:
                self.bx[0] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.bh:
                self.bx[1] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.cl:
                self.cx[0] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.ch:
                self.cx[1] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.dl:
                self.dx[0] = SIMD[DType.uint8, 1](value)
            elif register_type == RegisterType.dh:
                self.dx[1] = SIMD[DType.uint8, 1](value)
            else:
                print(color("yellow", "Set: Invalid register type for " + String(type.bitwidth()) + "bit data type: " + String(register_type)))
                return

    fn get_flags(self) -> String:
        var out = String()
        if self.get_flag[CPUFlag.carry]():
            out += String(CPUFlag.carry)
        if self.get_flag[CPUFlag.parity]():
            out += String(CPUFlag.parity)
        if self.get_flag[CPUFlag.aux_carry]():
            out += String(CPUFlag.aux_carry)
        if self.get_flag[CPUFlag.zero]():
            out += String(CPUFlag.zero)
        if self.get_flag[CPUFlag.sign]():
            out += String(CPUFlag.sign)
        if self.get_flag[CPUFlag.trap]():
            out += String(CPUFlag.trap)
        if self.get_flag[CPUFlag.interrupt]():
            out += String(CPUFlag.interrupt)
        if self.get_flag[CPUFlag.direction]():
            out += String(CPUFlag.direction)
        if self.get_flag[CPUFlag.overflow]():
            out += String(CPUFlag.overflow)

        return out

    fn get_flag[flag: CPUFlag](self) -> Bool:
        return (self.flags >> UInt16(flag.bit)) & 1 != 0

    fn set_flags[type: DType](mut self, value: SIMD[type, 1]):
        self.set_flag[CPUFlag.zero](value == 0)
        @parameter
        if type.bitwidth() == 8:
            self.set_flag[CPUFlag.sign](Int8(value) < 0)
        else:
            self.set_flag[CPUFlag.sign](Int16(value) < 0)
        self.set_flag[CPUFlag.parity](parity[type](value))

    fn set_flag[flag: CPUFlag](mut self, value: Bool = True):
        if value:
            self.flags = self.flags | (1 << UInt16(flag.bit))
            @parameter
            if debug:
                print("       set flag:", bytes_to_bin[True](self.flags), color("green", String(flag)))
        else:
            self.clear_flag[flag]()

    fn clear_flag[flag: CPUFlag](mut self):
        self.flags = self.flags & ~ (1 << UInt16(flag.bit))
        @parameter
        if debug:
            print("     clear flag:", bytes_to_bin[True](self.flags), color("red", String(flag)))

    fn toggle_flag[flag: CPUFlag](mut self):
        self.flags = self.flags ^ (1 << UInt16(flag.bit))
        @parameter
        if debug:
            print("    toggle flag:", bytes_to_bin[True](self.flags), color("yellow", String(flag)))

@value
struct RegisterType(Stringable, Representable, Intable, KeyElement):
    var value: UInt8

    alias invalid = RegisterType(0)
    alias ip = RegisterType(1)
    alias ax = RegisterType(2)
    alias al = RegisterType(3)
    alias ah = RegisterType(4)
    alias bx = RegisterType(5)
    alias bl = RegisterType(6)
    alias bh = RegisterType(7)
    alias cx = RegisterType(8)
    alias cl = RegisterType(9)
    alias ch = RegisterType(10)
    alias dx = RegisterType(11)
    alias dl = RegisterType(12)
    alias dh = RegisterType(13)
    alias bp = RegisterType(14)
    alias sp = RegisterType(15)
    alias si = RegisterType(16)
    alias di = RegisterType(17)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __int__(self) -> Int:
        return Int(self.value)

    fn __hash__(self) -> UInt:
        return hash(self.value)

    fn __repr__(self) -> String:
        return String(self)

    fn __str__(self) -> String:
        if self == RegisterType.ax:
            return "ax"
        elif self == RegisterType.ip:
            return "ip"
        elif self == RegisterType.al:
            return "al"
        elif self == RegisterType.ah:
            return "ah"
        elif self == RegisterType.bx:
            return "bx"
        elif self == RegisterType.bl:
            return "bl"
        elif self == RegisterType.bh:
            return "bh"
        elif self == RegisterType.cx:
            return "cx"
        elif self == RegisterType.cl:
            return "cl"
        elif self == RegisterType.ch:
            return "ch"
        elif self == RegisterType.dx:
            return "dx"
        elif self == RegisterType.dl:
            return "dl"
        elif self == RegisterType.dh:
            return "dh"
        elif self == RegisterType.bp:
            return "bp"
        elif self == RegisterType.sp:
            return "sp"
        elif self == RegisterType.si:
            return "si"
        elif self == RegisterType.di:
            return "di"
        else:
            return "invalid"

    fn byte_size(self) -> UInt8:
        if self in [RegisterType.al, RegisterType.bl, RegisterType.cl, RegisterType.dl, RegisterType.ah, RegisterType.bh, RegisterType.ch, RegisterType.dh]:
            return 1
        else:
            return 2

    fn bit_size(self) -> UInt8:
        return self.byte_size() * 8

    fn byte_offset(self) -> UInt8:
        if self in [RegisterType.ah, RegisterType.bh, RegisterType.ch, RegisterType.dh]:
            return 1
        else:
            return 0

struct CPUFlag:
    # Flags
    # +----+----+-----------------------+--------------------------------------------------------------------+
    # | Bit| N  | Name                  | Description                                                        |
    # +----+----+-----------------------+--------------------------------------------------------------------+
    # |  0 | CF | Carry Flag            | Indicates a carry out/borrow into the most significant bit.        |
    # |  2 | PF | Parity Flag           | Indicates whether the number of set bits is even or odd.           |
    # |  4 | AF | Auxiliary Carry Flag  | Used in binary-coded decimal (BCD) operations.                     |
    # |  6 | ZF | Zero Flag             | Indicates if the result of an operation is zero.                   |
    # |  7 | SF | Sign Flag             | Indicates the sign of the result (1 for negative, 0 for positive). |
    # |  8 | TF | Trap Flag             | Enables single-step debugging.                                     |
    # |  9 | IF | Interrupt Enable Flag | Enables/disables interrupts.                                       |
    # | 10 | DF | Direction Flag        | Determines string operation direction (increment/decrement).       |
    # | 11 | OF | Overflow Flag         | Indicates if an arithmetic overflow occurred.                      |
    # +----+----+-----------------------+--------------------------------------------------------------------+
    var bit: UInt8

    alias carry = CPUFlag(0)
    alias parity = CPUFlag(2)
    alias aux_carry = CPUFlag(4)
    alias zero = CPUFlag(6)
    alias sign = CPUFlag(7)
    alias trap = CPUFlag(8)
    alias interrupt = CPUFlag(9)
    alias direction = CPUFlag(10)
    alias overflow = CPUFlag(11)

    fn __init__(out self, bit: UInt8):
        self.bit = bit

    fn __eq__(self, other: Self) -> Bool:
        return self.bit == other.bit

    fn __ne__(self, other: Self) -> Bool:
        return self.bit != other.bit

    fn __int__(self) -> Int:
        return Int(self.bit)

    fn __hash__(self) -> UInt:
        return hash(self.bit)

    fn __repr__(self) -> String:
        return String(self)

    fn __str__(self) -> String:
        if self == CPUFlag.carry:
            return "C"
        elif self == CPUFlag.parity:
            return "P"
        elif self == CPUFlag.aux_carry:
            return "A"
        elif self == CPUFlag.zero:
            return "Z"
        elif self == CPUFlag.sign:
            return "S"
        elif self == CPUFlag.trap:
            return "T"
        elif self == CPUFlag.interrupt:
            return "I"
        elif self == CPUFlag.direction:
            return "D"
        elif self == CPUFlag.overflow:
            return "O"
        else:
            return "invalid"

struct Memory:
    var memory: OwnedPointer[InlineArray[UInt8, memory_size]]

    fn __init__(out self):
        self.memory = OwnedPointer(InlineArray[UInt8, memory_size](unsafe_uninitialized=True))
        for i in range(memory_size):
            self.memory[][i] = 0

    fn load[count: Int](self, address: UInt16) raises -> InlineArray[UInt8, count]:
        if address + (count - 1) >= UInt16(memory_size):
            raise "Load: Address out of bounds (" + String(count) + " x 8bit): " + String(address + (count - 1)) + " (max: " + String(UInt16(memory_size - 1)) + ")"
        var buffer = InlineArray[UInt8, count](unsafe_uninitialized=True)
        for i in range(count):
            buffer[i] = self.memory[][address + i]
        return buffer

    fn load[type: DType](self, address: UInt16) raises -> SIMD[type, 1]:
        @parameter
        if type.bitwidth() == 8:
            if address >= UInt16(memory_size):
                raise "Load: Address out of bounds (8bit): " + String(address) + " (max: " + String(UInt16(memory_size - 1)) + ")"
            return SIMD[type, 1](self.memory[][address])
        else:
            if address >= UInt16(memory_size - 1):
                raise "Load: Address out of bounds (16bit): " + String(address) + " (max: " + String(UInt16(memory_size - 1)) + ")"
            return SIMD[type, 1](combine_bytes(InlineArray[UInt8, 2](self.memory[][address], self.memory[][address + 1])))

    fn store[type: DType](mut self, address: UInt16, value: SIMD[type, 1]) raises:
        if type.bitwidth() == 8:
            if address >= UInt16(memory_size):
                raise "Store: Address out of bounds (8bit): " + String(address) + " (max: " + String(UInt16(memory_size - 1)) + ") - " + String(address >= UInt16(memory_size))
            self.memory[][address] = SIMD[DType.uint8, 1](value)
        else:
            if address >= UInt16(memory_size - 1):
                raise "Store: Address out of bounds (16bit): " + String(address) + " (max: " + String(UInt16(memory_size - 1)) + ")"
            var bytes = split_bytes(SIMD[DType.uint16, 1](value))
            self.memory[][address] = bytes[0]
            self.memory[][address + 1] = bytes[1]

    fn dump(self):
        print("==================== MEMORY ====================")
        print(bytes_to_hex(self.memory))
        print("================================================")

@value
struct Operand(Stringable, Representable):
    var register: Optional[RegisterType]
    var mem_expr: Optional[MemoryExpression]
    var immediate: Optional[UInt16]
    var imm_signed: Bool
    var instr_ptr: Optional[Int8]

    fn __init__(
        out self,
        register: Optional[RegisterType] = None,
        mem_expr: Optional[MemoryExpression] = None,
        immediate: Optional[UInt16] = None,
        imm_signed: Bool = False,
        instr_ptr: Optional[Int8] = None
    ):
        self.register = register
        self.mem_expr = mem_expr
        self.immediate = immediate
        self.imm_signed = imm_signed
        self.instr_ptr = instr_ptr

    fn __str__(self) -> String:
        if self.register:
            return String(self.register.value())
        elif self.mem_expr:
            return String(self.mem_expr.value())
        elif self.immediate:
            return String(self.immediate.value())
        elif self.instr_ptr:
            return String("$") + ("+" if self.instr_ptr.value() >= 0 else "") + String(self.instr_ptr.value())
        else:
            return "None"

    fn __repr__(self) -> String:
        return "Operand(" +
                  (String(self.register.value()) if self.register else "None") + ", " +
                  (String(self.mem_expr.value()) if self.mem_expr else "None") + ", " +
                  (String(self.immediate.value()) if self.immediate else "None") + ", " +
                  (String(self.imm_signed) if self.immediate else "None") + ", " +
                  (String(self.instr_ptr.value()) if self.instr_ptr else "None") +
                ")"

@value
struct MemoryExpression(Stringable, Representable, CollectionElement):
    var base_reg: Optional[RegisterType]
    var index_reg: Optional[RegisterType]
    var displacement: Optional[Int16]

    fn __init__(out self):
        self.base_reg = None
        self.index_reg = None
        self.displacement = None

    fn __init__(
        out self,
        base_reg: Optional[RegisterType] = None,
        index_reg: Optional[RegisterType] = None,
        displacement: Optional[Int16] = None
    ):
        self.base_reg = base_reg
        self.index_reg = index_reg
        self.displacement = displacement

    fn __str__(self) -> String:
        if self.base_reg and self.index_reg and self.displacement:
            return "[" + String(self.base_reg.value()) + " + " + String(self.index_reg.value()) + " + " + String(self.displacement.value()) + "]"
        if self.base_reg and self.index_reg:
            return "[" + String(self.base_reg.value()) + " + " + String(self.index_reg.value()) + "]"
        if self.base_reg and self.displacement:
            return "[" + String(self.base_reg.value()) + " + " + String(self.displacement.value()) + "]"
        if self.base_reg:
            return "[" + String(self.base_reg.value()) + "]"
        if self.index_reg:
            return "[" + String(self.index_reg.value()) + "]"
        if self.displacement:
            return "[" + String(self.displacement.value()) + "]"
        return "None"

    fn __repr__(self) -> String:
        return "MemoryExpression(" +
                 (String(self.base_reg.value()) if self.base_reg else "None") + ", " +
                 (String(self.index_reg.value()) if self.index_reg else "None") + ", " +
                 (String(self.displacement.value()) if self.displacement else "None") +
               ")"

@value
struct Instruction(Stringable, Representable, CollectionElement, Boolable):
    """
    Register/memory to/from register.
    """
    var op: UInt8
    var size: UInt8
    var data_bitwidth: UInt8
    var source: Optional[Operand]
    var destination: Optional[Operand]

    alias invalid = Instruction(0)
    alias mov = Instruction(1)
    alias add = Instruction(2)
    alias sub = Instruction(3)
    alias cmp = Instruction(4)
    alias je = Instruction(5)
    alias jl = Instruction(6)
    alias jle = Instruction(7)
    alias jb = Instruction(8)
    alias jbe = Instruction(9)
    alias jp = Instruction(10)
    alias jo = Instruction(11)
    alias js = Instruction(12)
    alias jne = Instruction(13)
    alias jnl = Instruction(14)
    alias jnle = Instruction(15)
    alias jnb = Instruction(16)
    alias jnbe = Instruction(17)
    alias jnp = Instruction(18)
    alias jno = Instruction(19)
    alias jns = Instruction(20)
    alias loop = Instruction(21)
    alias loopz = Instruction(22)
    alias loopnz = Instruction(23)
    alias jcxz = Instruction(24)

    fn __init__(
        out self,
        op: UInt8,
        size: UInt8 = 0,
        data_bitwidth: UInt8 = 0,
        source: Optional[Operand] = None,
        destination: Optional[Operand] = None
    ):
        self.op = op
        self.size = size
        self.data_bitwidth = data_bitwidth
        self.source = source
        self.destination = destination
    
    fn __bool__(self) -> Bool:
        return self.op != 0

    fn __eq__(self, other: Self) -> Bool:
        return self.op == other.op

    fn __ne__(self, other: Self) -> Bool:
        return self.op != other.op

    fn __int__(self) -> Int:
        return Int(self.op)

    fn __hash__(self) -> UInt:
        return hash(self.op)

    fn __str__(self) -> String:
        var op_str = String()
        var extra = String()
        if self.source and self.destination:
            op_str = self.mnemonic() + " " + String(self.destination.value()) + ", " + String(self.source.value())
            if self.source.value().imm_signed:
                extra = ", signed"
        elif self.destination:
            op_str = self.mnemonic() + " " + String(self.destination.value())
        else:
            op_str = self.mnemonic()
        return op_str + " ;; " + String(self.data_bitwidth) + "bit data" + extra

    fn __repr__(self) -> String:
        return String(self)

    fn mnemonic(self) -> String:
        if self == Instruction.mov:
            return "mov"
        elif self == Instruction.add:
            return "add"
        elif self == Instruction.sub:
            return "sub"
        elif self == Instruction.cmp:
            return "cmp"
        elif self == Instruction.je:
            return "je"
        elif self == Instruction.jl:
            return "jl"
        elif self == Instruction.jle:
            return "jle"
        elif self == Instruction.jb:
            return "jb"
        elif self == Instruction.jbe:
            return "jbe"
        elif self == Instruction.jp:
            return "jp"
        elif self == Instruction.jo:
            return "jo"
        elif self == Instruction.js:
            return "js"
        elif self == Instruction.jne:
            return "jne"
        elif self == Instruction.jnl:
            return "jnl"
        elif self == Instruction.jnle:
            return "jnle"
        elif self == Instruction.jnb:
            return "jnb"
        elif self == Instruction.jnbe:
            return "jnbe"
        elif self == Instruction.jnp:
            return "jnp"
        elif self == Instruction.jno:
            return "jno"
        elif self == Instruction.jns:
            return "jns"
        elif self == Instruction.loop:
            return "loop"
        elif self == Instruction.loopz:
            return "loopz"
        elif self == Instruction.loopnz:
            return "loopnz"
        elif self == Instruction.jcxz:
            return "jcxz"
        else:
            return "invalid"

    fn execute(self, mut computer: Computer) raises:
        if self == Instruction.mov:
            if self.destination and self.source:
                if self.data_bitwidth == 8:
                    self.op_mov[DType.uint8](computer)
                else:
                    self.op_mov[DType.uint16](computer)
            else:
                raise "Invalid operands for mov instruction: " + String(self)
                
        elif self == Instruction.add:
            if self.destination and self.source:
                if self.data_bitwidth == 8:
                    if self.source.value().imm_signed:
                        self.op_add[DType.int8](computer)
                    else:
                        self.op_add[DType.uint8](computer)
                else:
                    if self.source.value().imm_signed:
                        self.op_add[DType.int16](computer)
                    else:
                        self.op_add[DType.uint16](computer)
                
            else:
                raise "Invalid operands for add instruction: " + String(self)
        elif self == Instruction.sub:
            if self.destination and self.source:
                if self.data_bitwidth == 8:
                    if self.source.value().imm_signed:
                        self.op_sub[DType.int8](computer)
                    else:
                        self.op_sub[DType.uint8](computer)
                else:
                    if self.source.value().imm_signed:
                        self.op_sub[DType.int16](computer)
                    else:
                        self.op_sub[DType.uint16](computer)
            else:
                raise "Invalid operands for sub instruction: " + String(self)

        elif self == Instruction.cmp:
            if self.destination and self.source:
                if self.data_bitwidth == 8:
                    if self.source.value().imm_signed:
                        self.op_cmp[DType.int8](computer)
                    else:
                        self.op_cmp[DType.uint8](computer)
                else:
                    if self.source.value().imm_signed:
                        self.op_cmp[DType.int16](computer)
                    else:
                        self.op_cmp[DType.uint16](computer)
            else:
                raise "Invalid operands for sub instruction: " + String(self)

        elif self == Instruction.jne:
            var destination = computer.get_value[DType.int8](self.destination.value())

            @parameter
            if debug:
                print(color("cyan", "EXEC: " + String(self)))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))
            if not computer.cpu[].get_flag[CPUFlag.zero]():
                computer.cpu[].set_ip(destination)

        # Loop CX times. The 8086 LOOP instruction decrements CX, then loops if CX is non-zero.
        elif self == Instruction.loop:
            var destination = computer.get_value[DType.int8](self.destination.value())
            var cx = computer.cpu[].get_reg[DType.uint16](RegisterType.cx)

            @parameter
            if debug:
                print(color("cyan", "EXEC: " + String(self)))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))

            var result = cx - 1
            computer.cpu[].set_reg[DType.uint16](RegisterType.cx, result)
            computer.cpu[].set_flags(result)
            if not computer.cpu[].get_flag[CPUFlag.zero]():
                computer.cpu[].set_ip(destination)
        else:
            raise "Execution not implemented for: " + String(self)

    fn op_mov[type: DType](self, mut computer: Computer) raises:
        var source = computer.get_value[type](self.source.value())
        var destination = computer.get_value[type](self.destination.value())

        @parameter
        if debug:
            print(color("cyan", "EXEC: " + String(self)))

            @parameter
            if type.bitwidth() == 8:
                print("         source: " + bytes_to_bin(UInt8(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))
            else:
                print("         source: " + bytes_to_bin(UInt16(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt16(destination)) + ", " + pad_left(destination, 5))

        computer.set_value[type](self.destination.value(), source)

    fn op_add[type: DType](self, mut computer: Computer) raises:
        var source = computer.get_value[type](self.source.value())
        var destination = computer.get_value[type](self.destination.value())
        var result = source + destination

        @parameter
        if debug:
            print(color("cyan", "EXEC: " + String(self)))

            @parameter
            if type.bitwidth() == 8:
                print("         source: " + bytes_to_bin(UInt8(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt8(result)) + ", " + pad_left(result, 5))
            else:
                print("         source: " + bytes_to_bin(UInt16(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt16(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt16(result)) + ", " + pad_left(result, 5))

        computer.set_value[type](self.destination.value(), result)
        computer.cpu[].set_flags(result)

    fn op_sub[type: DType](self, mut computer: Computer) raises:
        var source = computer.get_value[type](self.source.value())
        var destination = computer.get_value[type](self.destination.value())
        var result = destination - source

        @parameter
        if debug:
            print(color("cyan", "EXEC: " + String(self)))
            @parameter
            if type.bitwidth() == 8:
                print("         source: " + bytes_to_bin(UInt8(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt8(result)) + ", " + pad_left(result, 5))
            else:
                print("         source: " + bytes_to_bin(UInt16(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt16(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt16(result)) + ", " + pad_left(result, 5))

        computer.set_value[type](self.destination.value(), result)
        computer.cpu[].set_flags(result)

    fn op_cmp[type: DType](self, mut computer: Computer) raises:
        var source = computer.get_value[type](self.source.value())
        var destination = computer.get_value[type](self.destination.value())
        var result = destination - source
        @parameter
        if debug:
            print(color("cyan", "EXEC: " + String(self)))

            @parameter
            if type.bitwidth() == 8:
                print("         source: " + bytes_to_bin(UInt8(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt8(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt8(result)) + ", " + pad_left(result, 5))
            else:
                print("         source: " + bytes_to_bin(UInt16(source)) + ", " + pad_left(source, 5))
                print("    destination: " + bytes_to_bin(UInt16(destination)) + ", " + pad_left(destination, 5))
                print("         result: " + bytes_to_bin(UInt16(result)) + ", " + pad_left(result, 5))

        computer.cpu[].set_flags(result)