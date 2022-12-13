package main

import "core:fmt"
import "core:runtime"

write_right_x64 :: proc(f: ^File) {
	times := count(f, '>')
	if times > 1 {
		str := fmt.aprintf("\tadd rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc rbx\n")
	}
}

write_left_x64 :: proc(f: ^File) {
	times := count(f, '<')
	if times > 1 {
		str := fmt.aprintf("\tsub rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec rbx\n")
	}
}

write_input_x64 :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output_x64 :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add_x64 :: proc(f: ^File) {
	times := count(f, '+')
	if times > 1 {
		str := fmt.aprintf("\tadd byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc byte [rbx]\n")
	}
}

write_sub_x64 :: proc(f: ^File) {
	times := count(f, '-')
	if times > 1 {
		str := fmt.aprintf("\tsub byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec byte [rbx]\n")
	}
}

write_loop_begin_x64 :: proc(f: ^File) {
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" +
						"\tje lb_end_%d\n" +
						"lb_start_%d:\n", f.loop, f.loop)
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end_x64 :: proc(f: ^File) {
	id := f.loop_arr[len(f.loop_arr)-1]
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" + 
						"\tjne lb_start_%d\n" + 
						"lb_end_%d:\n", id, id)
	defer delete(str)
	write(f, str)
	arr_tmp := cast(^runtime.Raw_Dynamic_Array)&f.loop_arr
	arr_tmp.len = arr_tmp.len-1
	f.index += 1
}

write_setup_x64 :: proc(f: ^File) {
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
}

write_exit_x64 :: proc(f: ^File) {
	write(f, 	"\tmov rsp, rbp\n" +
				"\tpop rbp\n" + 
				"\tmov rax, SYS_EXIT\n" + 
				"\tmov rdi, 0\n" + 
				"\tsyscall\n")
}
