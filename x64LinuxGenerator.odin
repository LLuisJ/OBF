package main

import "core:fmt"
import "core:runtime"

write_right_x64_linux :: proc(f: ^File) {
	times := count(f, '>')
	if times > 1 {
		str := fmt.aprintf("\tadd rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc rbx\n")
	}
}

write_left_x64_linux :: proc(f: ^File) {
	times := count(f, '<')
	if times > 1 {
		str := fmt.aprintf("\tsub rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec rbx\n")
	}
}

write_input_x64_linux :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output_x64_linux :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add_x64_linux :: proc(f: ^File) {
	times := count(f, '+')
	if times > 1 {
		str := fmt.aprintf("\tadd byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc byte [rbx]\n")
	}
}

write_sub_x64_linux :: proc(f: ^File) {
	times := count(f, '-')
	if times > 1 {
		str := fmt.aprintf("\tsub byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec byte [rbx]\n")
	}
}

write_loop_begin_x64_linux :: proc(f: ^File) {
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" +
						"\tje lb_end_%d\n" +
						"lb_start_%d:\n", f.loop, f.loop)
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end_x64_linux :: proc(f: ^File) {
	id := pop(&f.loop_arr)
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" + 
						"\tjne lb_start_%d\n" + 
						"lb_end_%d:\n", id, id)
	defer delete(str)
	write(f, str)
	f.index += 1
}

write_setup_x64_linux :: proc(f: ^File) {
	write(f, 	"BITS 64\n" + 
				"global _start\n" + 
				"SYS_READ 	equ 0\n" + 
				"SYS_WRITE 	equ 1\n" + 
				"SYS_EXIT 	equ 60\n" + 
				"STDIN		equ 0\n" + 
				"STDOUT		equ 1\n" + 
				"section .data\n" + 
				"\tbuffer times 30000 db 0\n" + 
				"\toutbuffer times 8192 db 0\n" +
				"\toutbuffer_len dd 0\n" +
				"section .bss\n" + 
				"\tinput: resb 2\n" + 
				"section .text\n" + 
				"_input:\n" +
				"\tcall _print\n" +
				"\tmov rax, SYS_READ\n" + 
				"\tmov rdi, STDIN\n" + 
				"\tmov rsi, input\n" + 
				"\tmov rdx, 2\n" + 
				"\tsyscall\n" + 
				"\tmov al, byte[input]\n" + 
				"\tmov byte[rbx], al\n" + 
				"\tret\n" + 
				"_output:\n" +
				"\tmov rax, outbuffer\n" +
				"\tadd rax, [outbuffer_len]\n" +
				"\tmov cl, byte [rbx]\n" +
				"\tmov byte [rax], cl\n" +
				"\tinc dword [outbuffer_len]\n" +
				"\tcmp dword [outbuffer_len], 8192\n" +
				"\tjne .newline\n" +
				"\tcall _print\n" +
				"\tjmp .return\n" +
				"\t.newline:\n" +
				"\tcmp cl, 10\n" +
				"\tjne .return\n" +
				"\tcall _print\n" +
				"\t.return:\n" +
				"\tret\n" +
				"_print:\n" +
				"\tmov rax, SYS_WRITE\n" + 
				"\tmov rdi, STDOUT\n" + 
				"\tmov rsi, outbuffer\n" + 
				"\tmov rdx, [outbuffer_len]\n" + 
				"\tsyscall\n" + 
				"\tmov dword [outbuffer_len], 0\n" +
				"\tret\n" + 
				"_start:\n" + 
				"\tpush rbp\n" + 
				"\tmov rbp, rsp\n" + 
				"\tmov rbx, buffer\n")
}

write_exit_x64_linux :: proc(f: ^File) {
	write(f, 	"\tcall _print\n" +
				"\tmov rsp, rbp\n" +
				"\tpop rbp\n" + 
				"\tmov rax, SYS_EXIT\n" + 
				"\tmov rdi, 0\n" + 
				"\tsyscall\n")
}

compile_cmd_x64_linux :: proc(name: string) -> string {
	return fmt.aprintf("nasm -felf64 %s", name)
}

link_cmd_x64_linux :: proc(name: string) -> string {
	when ODIN_OS != .Linux {
		return ""
	}
	when ODIN_ARCH == .amd64 {
		return fmt.aprintf("ld %s.o -o %s", name, name)
	} else when ODIN_ARCH == .i386 {
		// This is not tested. It should work (i think?). I don't know though if it should be elf32_x86_64.
		// But does this make sense? Compiling a 64 bit executable on a 32 bit system? Does this work when running the executable?
		return fmt.aprintf("ld -m elf_x86_64 %s.o -o %s", name, name)
	} else {
		return ""
	}
}
