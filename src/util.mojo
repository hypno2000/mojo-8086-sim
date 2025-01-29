from collections import InlineArray, Dict
from memory import OwnedPointer
from utils import StringSlice

fn bits(byte: UInt8, count: UInt8 = 8) -> String:   
    var bits = InlineArray[UInt8, 8](0)
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

fn dim(text: String) -> String:
    return color("dim", text)

fn bytes_to_string(value: UInt8) -> String:
    return bytes_to_string(InlineArray[UInt8, 1](value))

fn bytes_to_string[big_endian: Bool = False](value: UInt16) -> String:
    var array = split_bytes[big_endian](value)
    return bytes_to_string(array)
    
fn bytes_to_string[size: Int](array: InlineArray[UInt8, size]) -> String:
    var out = String()
    @parameter
    for i in range(min(16, size)):
        if i > 0:
            out += ", "
        out += pad_left(array[i], 3, " ")
    return "[ " + out + " ]"

fn bytes_to_bin(value: UInt8) -> String:
    return bytes_to_bin(InlineArray[UInt8, 1](value))

fn bytes_to_bin[big_endian: Bool = False](value: UInt16) -> String:
    var array = split_bytes[big_endian](value)
    return bytes_to_bin(array)

fn bytes_to_bin(value: Int8) -> String:
    return bytes_to_bin(InlineArray[UInt8, 1](UInt8(value)))

fn bytes_to_bin[big_endian: Bool = False](value: Int16) -> String:
    var array = split_bytes[big_endian](UInt16(value))
    return bytes_to_bin(array)

fn bytes_to_bin[size: Int](array: InlineArray[UInt8, size]) -> String:
    var out = String()
    @parameter
    for i in range(min(16, size)):
        if i > 0:
            out += ", "
        out += bits(array[i], 8)
    return "[" + out + "]"

fn bytes_to_hex(value: UInt8) -> String:
    return bytes_to_hex(InlineArray[UInt8, 1](value))

fn bytes_to_hex[big_endian: Bool = False](value: UInt16) -> String:
    var array = split_bytes[big_endian](value)
    return bytes_to_hex(array)

fn bytes_to_hex[size: Int](array: InlineArray[UInt8, size]) -> String:
    var out = String()
    @parameter
    for i in range(min(16, size)):
        if i > 0:
            out += ", "
        out += pad_left(hex(array[i], prefix=StringSlice("")), 2, "0")
    return "[" + out + "]"

fn bytes_to_hex[size: Int](array: OwnedPointer[InlineArray[UInt8, size]]) -> String:
    var out = String()
    @parameter
    for i in range(min(16, size)):
        if i > 0:
            out += ", "
        out += pad_left(hex(array[][i], prefix=StringSlice("")), 2, "0")
    return "[" + out + "]"

fn combine_bytes[big_endian: Bool = False](bytes: InlineArray[UInt8, 2]) -> UInt16:
    @parameter
    if big_endian:
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    else:
        return UInt16(bytes[1]) << 8 | UInt16(bytes[0])

fn split_bytes[big_endian: Bool = False](value: UInt16) -> InlineArray[UInt8, 2]:
    @parameter
    if big_endian:
        return InlineArray[UInt8, 2](UInt8(value >> 8), UInt8(value & 0xFF))
    else:
        return InlineArray[UInt8, 2](UInt8(value & 0xFF), UInt8(value >> 8))

fn pad_left(str: String, length: Int, char: String = " ") -> String:
    return char * (length - len(str)) + str

fn pad_right(str: String, length: Int, char: String = " ") -> String:
    return str + char * (length - len(str))

fn pad_left[type: Stringable](value: type, length: Int, char: String = " ") -> String:
    return pad_left(String(value), length, char)

fn pad_right[type: Stringable](value: type, length: Int, char: String = " ") -> String:
    return pad_right(String(value), length, char)

fn count_set_bits[T: DType](value: SIMD[T, 1]) -> UInt8:
    var count: UInt8 = 0
    var n = value
    while n > 0:
        count += UInt8(n & 1)
        n = n >> 1
    return count

fn parity[T: DType](value: SIMD[T, 1]) -> Bool:
    return count_set_bits(value) & 1 == 0
