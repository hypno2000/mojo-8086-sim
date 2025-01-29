import sys
from decoding import decode_file, debug
from pathlib.path import cwd, Path
from collections import List
from virtual_machine import Instruction, Computer
from memory import Span

fn main() raises:
    var file_path = cwd().joinpath(String(sys.argv()[1])) if len(
        sys.argv()
    ) > 1 else Path("/Users/reio/Code/virtual-cpu/data/listing41")
    @parameter
    if debug:
        print(file_path)
    
    var computer = Computer()
    var exit_code = computer.run_program(open(file_path, "r").read_bytes())

    @parameter
    if debug:
        computer.core_dump()
        print("Exit code: ", String(exit_code))

    if sys.argv()[2] == "--dump-memory":
        var stdout = sys.stdout
        stdout.write_bytes(Span(array=computer.memory.memory[]))

# fn main() raises:
#     var file_path = cwd().joinpath(String(argv()[1])) if len(
#         argv()
#     ) > 1 else Path("/Users/reio/Code/virtual-cpu/data/listing41")
#     print(file_path)
#     var instructions: List[Instruction] = decode_file(file_path)

#     var computer = Computer()
#     computer.core_dump()

#     print("================= INSTRUCTIONS =================")

#     for instruction in instructions:
#         print(String(instruction[]))

#     print("================================================")

#     for instruction in instructions:
#         instruction[].execute(computer)

#     computer.core_dump()
