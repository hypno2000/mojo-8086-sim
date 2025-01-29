from collections import InlineArray

alias memory_size = 65536

fn main():
    _ = InlineArray[UInt8, memory_size](fill=0)
    # _ = InlineArray[UInt8, memory_size](unsafe_uninitialized=True)
