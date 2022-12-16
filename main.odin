/*
	This whole program was basically just an exercise for me to learn the odin language and a bit of assembler.
	It is by no means efficient/the fastest, but it works.
	And brainfuck seemed like a good language to compile because of its simplicity.
	To use this compiler, you need nasm and some kind of linker (this stuff needs to be in the path).
	The program calls:
		- nasm -felf64 <name>.o | nasm -felf <name>.o | nasm -fwin64 <name>.obj
		- ld <name>.o -o <name> | link /subsystem:console /nologo /nodefaultlib /entry:_main <name>.obj kernel32.Lib
	For now this only works on x86/x64 linux.
	As far as i can see, this doesn't depend on any library since it uses syscalls for input/output.
	On windows the only dependency is kernel32.dll but since it is always available (AFAIK) and windows syscalls are
	unstable at best, this is the best solution.
	A X86Windows target is defined in the generator but it is not implemented.
	Since a linker is needed for windows, you need to run this program from the native tools command prompt.
*/
package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:runtime"
import "core:slice"
import "core:strings"


Generator :: enum {
	X64Linux,
	X86Linux,
	x64Windows,
	x86Windows,
	UNKNOWN,
}

File :: struct {
	index: 		int,
	loop:		int,
	loop_arr:	[dynamic]int,
	data: 		[]u8,
	out:		^strings.Builder,
	gen:		Generator,
}

main :: proc() {
	/* 
		This delete shuts up valgrind about a possible memory leak.
		Technically speaking valgrind is correct, that os.args is never freed,
		but this is a problem/bug on odin's side, not the user. This just
		frees the args when the program exits.
	*/
	defer delete(os.args)
	if len(os.args) < 2 || len(os.args) > 5 {
		fmt.println("usage: obf <bf file> [-r (run) | -k (keep asm) | -32 (generate 32 bit asm)]")
		os.exit(1)
	}
	source_file := os.args[1]
	run := false
	keep_asm := false
	when ODIN_OS != .Linux && ODIN_OS != .Windows {
		#panic("unsupported platform (only linux/windows for now)")
	}
	arr_loop := make([dynamic]int, 0)
	file := File{0, 0, arr_loop, nil, nil, .UNKNOWN}
	when ODIN_OS == .Windows {
		when ODIN_ARCH == .amd64 {
			file.gen = .x64Windows
		} else when ODIN_ARCH == .i386 {
			file.gen = .x86Windows
		} else {
			#panic("unsupported architecture")
		}
	} else when ODIN_OS == .Linux {
		when ODIN_ARCH == .amd64 {
			file.gen = .X64Linux
		} else when ODIN_ARCH == .i386 {
			file.gen = .X86Linux
		} else {
			#panic("unsupported architecture")
		}
	}
	if len(os.args) > 2 {
		if slice.contains(os.args, "-r") {
			run = true
		}
		if slice.contains(os.args, "-k") {
			keep_asm = true
		}
		when ODIN_OS == .Windows {
			when ODIN_ARCH == .amd64 {
				if slice.contains(os.args, "-32") {
					file.gen = .x86Windows
				}
			} else when ODIN_ARCH == .i386 {
				if slice.contains(os.args, "-64") {
					file.gen = .x64Windows
				}
			}
		} else when ODIN_OS == .Linux {
			when ODIN_ARCH == .amd64 {
				if slice.contains(os.args, "-32") {
					file.gen = .X86Linux
				}
			} else when ODIN_ARCH == .i386 {
				if slice.contains(os.args, "-64") {
					file.gen = .X64Linux
				}
			}
		}
	}
	if !os.exists(source_file) {
		fmt.printf("file %s does not exist\n", source_file)
		os.exit(1)
	}
	builder := strings.builder_make_none()
	file.out = &builder
	content, ok := os.read_entire_file_from_filename(source_file)
	if !ok {
		fmt.println("error reading file")
		os.exit(1)
	}
	file.data = content
	asm_file_name := filepath.stem(filepath.base(source_file))
	if asm_file_name == "" {
		asm_file_name = "out"
	}
	asm_file_path := strings.join([]string{asm_file_name, ".asm"}, "")
	defer delete(asm_file_path)
	write_setup(&file)
	main_loop(&file)
	write_exit(&file)
	ok = os.write_entire_file(asm_file_path, transmute([]u8)strings.to_string(file.out^), true)
	cleanup_file(&file)
	if !ok {
		fmt.println("error writing to file")
		os.exit(1)
	}
	nasm_str := compile_cmd(&file, asm_file_path)
	if nasm_str != "" {
		nasm_str_c := strings.clone_to_cstring(nasm_str)
		defer delete(nasm_str)
		defer delete(nasm_str_c)
		if ierr := libc.system(nasm_str_c); ierr != 0 {
			fmt.println("error calling nasm")
			os.exit(1)
		}
	} else {
		fmt.println("got an empty compile string")
		os.exit(1)
	}
	ld_str := link_cmd(&file, asm_file_name)
	if ld_str != "" {
		ld_str_c := strings.clone_to_cstring(ld_str)
		defer delete(ld_str)
		defer delete(ld_str_c)
		if ierr := libc.system(ld_str_c); ierr != 0 {
			fmt.println("error calling ld")
			os.exit(1)
		}
	} else {
		fmt.println("got an empty linker string")
		os.exit(1)
	}
	when ODIN_OS != .Windows {
		delete_o_file := fmt.aprintf("%s.o", asm_file_name)
	} else {
		delete_o_file := fmt.aprintf("%s.obj", asm_file_name)
	}
	delete_o_file_c := strings.clone_to_cstring(delete_o_file)
	defer delete(delete_o_file)
	defer delete(delete_o_file_c)
	_ = libc.remove(delete_o_file_c)
	if !keep_asm {
		asm_file_path_c := strings.clone_to_cstring(asm_file_path)
		defer delete(asm_file_path_c)
		_ = libc.remove(asm_file_path_c)
	}
	if run {
		when ODIN_OS != .Windows {
			run_file := fmt.aprintf("./%s", asm_file_name)
		} else {
			run_file := fmt.aprintf("%s.exe", asm_file_name)
		}
		run_file_c := strings.clone_to_cstring(run_file)
		defer delete(run_file)
		defer delete(run_file_c)
		if ierr := libc.system(run_file_c); ierr != 0 {
			fmt.println("error running program")
			os.exit(1)
		}
	}
}

main_loop :: proc(f: ^File) {
	for f.index < len(f.data) {
		switch f.data[f.index] {
			case '>':
				write_right(f)
			case '<':
				write_left(f)
			case '.':
				write_output(f)
			case ',':
				write_input(f)
			case '+':
				write_add(f)
			case '-':
				write_sub(f)
			case '[':
				write_loop_begin(f)
			case ']':
				write_loop_end(f)
			case:
				f.index += 1
				continue
		}
	}
}

write_right :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_right_x64_linux(f)
		case .X86Linux:
			write_right_x86_linux(f)
		case .x64Windows:
			write_right_x64_windows(f)
	}
}

write_left :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_left_x64_linux(f)
		case .X86Linux:
			write_left_x86_linux(f)
		case .x64Windows:
			write_left_x64_windows(f)
	}
}

write_input :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_input_x64_linux(f)
		case .X86Linux:
			write_input_x86_linux(f)
		case .x64Windows:
			write_input_x64_windows(f)
	}
}

write_output :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_output_x64_linux(f)
		case .X86Linux:
			write_output_x86_linux(f)
		case .x64Windows:
			write_output_x64_windows(f)
	}
}

write_add :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_add_x64_linux(f)
		case .X86Linux:
			write_add_x86_linux(f)
		case .x64Windows:
			write_add_x64_windows(f)
	}
}

write_sub :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_sub_x64_linux(f)
		case .X86Linux:
			write_sub_x86_linux(f)
		case .x64Windows:
			write_sub_x64_windows(f)
	}
}

write_loop_begin :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_loop_begin_x64_linux(f)
		case .X86Linux:
			write_loop_begin_x86_linux(f)
		case .x64Windows:
			write_loop_begin_x64_windows(f)
	}
}

write_loop_end :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_loop_end_x64_linux(f)
		case .X86Linux:
			write_loop_end_x86_linux(f)
		case .x64Windows:
			write_loop_end_x64_windows(f)
	}
}

write_setup :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_setup_x64_linux(f)
		case .X86Linux:
			write_setup_x86_linux(f)
		case .x64Windows:
			write_setup_x64_windows(f)
	}
}

write_exit :: proc(f: ^File) {
	#partial switch f.gen {
		case .X64Linux:
			write_exit_x64_linux(f)
		case .X86Linux:
			write_exit_x86_linux(f)
		case .x64Windows:
			write_exit_x64_windows(f)
	}
}

compile_cmd :: proc(f: ^File, name: string) -> string {
	#partial switch f.gen {
		case .X64Linux:
			return compile_cmd_x64_linux(name)
		case .X86Linux:
			return compile_cmd_x86_linux(name)
		case .x64Windows:
			return compile_cmd_x64_windows(name)
		case:
			return ""
	}
}

link_cmd :: proc(f: ^File, name: string) -> string {
	#partial switch f.gen {
		case .X64Linux:
			return link_cmd_x64_linux(name)
		case .X86Linux:
			return link_cmd_x86_linux(name)
		case .x64Windows:
			return link_cmd_x64_windows(name)
		case:
			return ""
	}
}

count :: proc(f: ^File, char: u8) -> int {
	initial_index := f.index
	for f.index < len(f.data) && f.data[f.index] == char {
		f.index += 1
	}
	return f.index - initial_index
}

write :: proc(f: ^File, content: string) {
	new_len := len(f.out.buf) + len(content)
	if len(f.out.buf) < new_len {
		strings.builder_grow(f.out, new_len)
	}
	_ = strings.write_string(f.out, content)
}

cleanup_file :: proc(f: ^File) {
	if f.data != nil {
		delete(f.data)
		f.data = nil
	}
	if f.out != nil {
		strings.builder_destroy(f.out)
		f.out = nil
	}
	if f.loop_arr != nil {
		delete(f.loop_arr)
		f.loop_arr = nil
	}
}
