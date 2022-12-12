/*
	This whole program was basically just an exercise for me to learn the odin language and a bit of assembler.
	It is by no means efficient/the fastest, but it works.
	And brainfuck seemed like a good language to compile because of its simplicity.
	To use this compiler, you need nasm and some kind of linker (this stuff needs to be in the path).
	The program calls:
		- nasm -felf64 <name>.o | nasm -felf <name>.o
		- ld <name>.o -o <name>
	For now this only works on x86/x64 linux.
	As far as i can see, this doesn't depend on any library since it uses syscalls for input/output.
*/
package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:runtime"
import "core:slice"
import "core:strings"
import "core:time"

File :: struct {
	index: 		int,
	loop:		int,
	loop_arr:	[dynamic]int,
	data: 		[]u8,
	out:		^strings.Builder,
}

Generator :: enum {
	X64,
	X86,
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
	when ODIN_OS != .Linux {
		#panic("unsupported platform (only linux for now)")
	}
	when ODIN_ARCH == .amd64 {
		generator := Generator.X64
	} else when ODIN_ARCH == .i386 {
		generator := Generator.X86
	} else {
		#panic("unsupported architecture")
	}
	if len(os.args) > 2 {
		if slice.contains(os.args, "-r") {
			run = true
		}
		if slice.contains(os.args, "-k") {
			keep_asm = true
		}
		when ODIN_ARCH == .amd64 {
			if slice.contains(os.args, "-32") {
				generator = .X86
			}
		} else when ODIN_ARCH == .i386 {
			if slice.contains(os.args, "-64") {
				generator = .X64
			}
		}
	}
	if !os.exists(source_file) {
		fmt.printf("file %s does not exist\n", source_file)
		os.exit(1)
	}
	arr_loop := make([dynamic]int, 0)
	file := File{0, 0, arr_loop, nil, nil}
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
	start := time.now()
	write_setup(&file, generator)
	main_loop(&file, generator)
	write_exit(&file, generator)
	ok = os.write_entire_file(asm_file_path, transmute([]u8)strings.to_string(file.out^), true)
	if !ok {
		cleanup_file(&file)
		fmt.println("error writing to file")
		os.exit(1)
	}
	cleanup_file(&file)
	nasm_str: string
	if generator == .X64 {
		nasm_str = fmt.aprintf("nasm -felf64 %s", asm_file_path)
	} else {
		nasm_str = fmt.aprintf("nasm -felf %s", asm_file_path)
	}
	defer delete(nasm_str)
	nasm_str_c := strings.clone_to_cstring(nasm_str)
	defer delete(nasm_str_c)
	if ierr := libc.system(nasm_str_c); ierr != 0 {
		fmt.println("error calling nasm")
		os.exit(1)
	}
	ld_str: string
	if generator == .X64 {
		ld_str = fmt.aprintf("ld %s.o -o %s", asm_file_name, asm_file_name)
	} else {
		ld_str = fmt.aprintf("ld -m elf_i386 %s.o -o %s", asm_file_name, asm_file_name)
	}
	defer delete(ld_str)
	ld_str_c := strings.clone_to_cstring(ld_str)
	defer delete(ld_str_c)
	if ierr := libc.system(ld_str_c); ierr != 0 {
		fmt.println("error calling ld")
		os.exit(1)
	}
	delete_o_file := fmt.aprintf("%s.o", asm_file_name)
	defer delete(delete_o_file)
	delete_o_file_c := strings.clone_to_cstring(delete_o_file)
	defer delete(delete_o_file_c)
	_ = libc.remove(delete_o_file_c)
	if !keep_asm {
		asm_file_path_c := strings.clone_to_cstring(asm_file_path)
		defer delete(asm_file_path_c)
		_ = libc.remove(asm_file_path_c)
	}
	if run {
		run_file := fmt.aprintf("./%s", asm_file_name)
		defer delete(run_file)
		run_file_c := strings.clone_to_cstring(run_file)
		defer delete(run_file_c)
		if ierr := libc.system(run_file_c); ierr != 0 {
			fmt.println("error running program")
			os.exit(1)
		}
	}
}

main_loop :: proc(f: ^File, generator: Generator) {
	for f.index < len(f.data) {
		switch f.data[f.index] {
			case '>':
				write_right(f, generator)
			case '<':
				write_left(f, generator)
			case '.':
				write_output(f)
			case ',':
				write_input(f)
			case '+':
				write_add(f, generator)
			case '-':
				write_sub(f, generator)
			case '[':
				write_loop_begin(f, generator)
			case ']':
				write_loop_end(f, generator)
			case:
				f.index += 1
				continue
		}
	}
}

write_right :: proc(f: ^File, gen: Generator) {
	times := count(f, '>')
	if times > 1 {
		str: string
		if gen == .X64 {
			str = fmt.aprintf("\tadd rbx, %d\n", times)
		} else {
			str = fmt.aprintf("\tadd ebx, %d\n", times)
		}
		defer delete(str)
		write(f, str)
	} else {
		if gen == .X64 {
			write(f, "\tinc rbx\n")
		} else {
			write(f, "\tinc ebx\n")
		}
	}
}

write_left :: proc(f: ^File, gen: Generator) {
	times := count(f, '<')
	if times > 1 {
		str: string
		if gen == .X64 {
			str = fmt.aprintf("\tsub rbx, %d\n", times)
		} else {
			str = fmt.aprintf("\tsub ebx, %d\n", times)
		}
		defer delete(str)
		write(f, str)
	} else {
		if gen == .X64 {
			write(f, "\tdec rbx\n")
		} else {
			write(f, "\tdec ebx\n")
		}
	}
}

write_input :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add :: proc(f: ^File, gen: Generator) {
	times := count(f, '+')
	if times > 1 {
		str: string
		if gen == .X64 {
			str = fmt.aprintf("\tadd byte [rbx], %d\n", times)
		} else {
			str = fmt.aprintf("\tadd byte [ebx], %d\n", times)
		}
		defer delete(str)
		write(f, str)
	} else {
		if gen == .X64 {
			write(f, "\tinc byte [rbx]\n")
		} else {
			write(f, "\tinc byte [ebx]\n")
		}
	}
}

write_sub :: proc(f: ^File, gen: Generator) {
	times := count(f, '-')
	if times > 1 {
		str: string
		if gen == .X64 {
			str = fmt.aprintf("\tsub byte [rbx], %d\n", times)
		} else {
			str = fmt.aprintf("\tsub byte [ebx], %d\n", times)
		}
		defer delete(str)
		write(f, str)
	} else {
		if gen == .X64 {
			write(f, "\tdec byte [rbx]\n")
		} else {
			write(f, "\tdec  byte [ebx]\n")
		}
	}
}

write_loop_begin :: proc(f: ^File, gen: Generator) {
	str: string
	if gen == .X64 {
		str = fmt.aprintf(	"\tcmp byte [rbx], 0\n" +
							"\tje lb_end_%d\n" +
							"lb_start_%d:\n", f.loop, f.loop)
	} else {
		str = fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
							"\tje lb_end_%d\n" + 
							"lb_start_%d:\n", f.loop, f.loop)
	}
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end :: proc(f: ^File, gen: Generator) {
	id := f.loop_arr[len(f.loop_arr)-1]
	str: string
	if gen == .X64 {
		str = fmt.aprintf(	"\tcmp byte [rbx], 0\n" + 
							"\tjne lb_start_%d\n" + 
							"lb_end_%d:\n", id, id)
	} else {
		str = fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
							"\tjne lb_start_%d\n" + 
							"lb_end_%d:\n", id, id)
	}
	defer delete(str)
	write(f, str)
	arr_tmp := cast(^runtime.Raw_Dynamic_Array)&f.loop_arr
	arr_tmp.len = arr_tmp.len-1
	f.index += 1
}

write_setup :: proc(f: ^File, gen: Generator) {
	if gen == .X64 {
		write(f, 	"BITS 64\n" + 
					"global _start\n" + 
					"SYS_READ 	equ 0\n" + 
					"SYS_WRITE 	equ 1\n" + 
					"SYS_EXIT 	equ 60\n" + 
					"STDIN		equ 0\n" + 
					"STDOUT		equ 1\n" + 
					"section .data\n" + 
					"	buffer times 30000 db 0\n" + 
					"section .bss\n" + 
					"	input: resb 2\n" + 
					"section .text\n" + 
					"_input:\n" +
					"\tmov rax, SYS_READ\n" + 
					"\tmov rdi, STDIN\n" + 
					"\tmov rsi, input\n" + 
					"\tmov rdx, 2\n" + 
					"\tsyscall\n" + 
					"\tmov al, byte[input]\n" + 
					"\tmov byte[rbx], al\n" + 
					"\tret\n" + 
					"_output:\n" +
					"\tmov rax, SYS_WRITE\n" + 
					"\tmov rdi, STDOUT\n" + 
					"\tmov rsi, rbx\n" + 
					"\tmov rdx, 1\n" + 
					"\tsyscall\n" + 
					"\tret\n" + 
					"_start:\n" + 
					"\tpush rbp\n" + 
					"\tmov rbp, rsp\n" + 
					"\tmov rbx, buffer\n")
	} else {
		write(f, 	"BITS 32\n" + 
					"global _start\n" + 
					"SYS_READ 	equ 3\n" + 
					"SYS_WRITE 	equ 4\n" + 
					"SYS_EXIT 	equ 1\n" + 
					"STDIN		equ 0\n" + 
					"STDOUT		equ 1\n" + 
					"section .data\n" + 
					"\tbuffer times 30000 db 0\n" + 
					"section .bss\n" + 
					"\tinput: resb 2\n" + 
					"section .text\n" + 
					"_input:\n" +
					"\tpush ebx\n" +
					"\tmov eax, SYS_READ\n" + 
					"\tmov ebx, STDIN\n" + 
					"\tmov ecx, input\n" + 
					"\tmov edx, 2\n" + 
					"\tint 80h\n" +
					"\tpop ebx\n" + 
					"\tmov al, byte[input]\n" + 
					"\tmov byte[ebx], al\n" + 
					"\tret\n" + 
					"_output:\n" +
					"\tpush ebx\n" +
					"\tmov eax, SYS_WRITE\n" + 
					"\tmov ecx, ebx\n" + 
					"\tmov ebx, STDOUT\n" + 
					"\tmov edx, 1\n" + 
					"\tint 80h\n" +
					"\tpop ebx\n" + 
					"\tret\n" + 
					"_start:\n" + 
					"\tpush ebp\n" + 
					"\tmov ebp, esp\n" + 
					"\tmov ebx, buffer\n")
	}
}

write_exit :: proc(f: ^File, gen: Generator) {
	if gen == .X64 {
		write(f, 	"\tmov rsp, rbp\n" +
					"\tpop rbp\n" + 
					"\tmov rax, SYS_EXIT\n" + 
					"\tmov rdi, 0\n" + 
					"\tsyscall\n")
	} else {
		write(f, 	"\tmov esp, ebp\n" + 
					"\tpop ebp\n" + 
					"\tmov eax, SYS_EXIT\n" + 
					"\tmov ebx, 0\n" + 
					"\tint 80h\n")
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
