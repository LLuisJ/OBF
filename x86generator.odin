package main

import "core:fmt"
import "core:runtime"

write_right_x86 :: proc(f: ^File) {
	times := count(f, '>')
	if times > 1 {
		str := fmt.aprintf("\tadd ebx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc ebx\n")
	}
}

write_left_x86 :: proc(f: ^File) {
	times := count(f, '<')
	if times > 1 {
		str := fmt.aprintf("\tsub ebx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec ebx\n")
	}
}

write_input_x86 :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output_x86 :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add_x86 :: proc(f: ^File) {
	times := count(f, '+')
	if times > 1 {
		str := fmt.aprintf("\tadd byte [ebx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc byte [ebx]\n")
	}
}

write_sub_x86 :: proc(f: ^File) {
	times := count(f, '-')
	if times > 1 {
		str := fmt.aprintf("\tsub byte [ebx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec  byte [ebx]\n")
	}
}

write_loop_begin_x86 :: proc(f: ^File) {
	str := fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
						"\tje lb_end_%d\n" + 
						"lb_start_%d:\n", f.loop, f.loop)
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end_x86 :: proc(f: ^File) {
	id := f.loop_arr[len(f.loop_arr)-1]
	str := fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
						"\tjne lb_start_%d\n" + 
						"lb_end_%d:\n", id, id)
	defer delete(str)
	write(f, str)
	arr_tmp := cast(^runtime.Raw_Dynamic_Array)&f.loop_arr
	arr_tmp.len = arr_tmp.len-1
	f.index += 1
}

write_setup_x86 :: proc(f: ^File) {
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

write_exit_x86 :: proc(f: ^File) {
	write(f, 	"\tmov esp, ebp\n" + 
				"\tpop ebp\n" + 
				"\tmov eax, SYS_EXIT\n" + 
				"\tmov ebx, 0\n" + 
				"\tint 80h\n")
}

compile_cmd_x86 :: proc(f: ^File, name: string) -> string {
	return fmt.aprintf("nasm -felf %s", name)
}

link_cmd_x86 :: proc(f: ^File, name: string) -> string {
	when ODIN_ARCH == .i386 {
		return fmt.aprintf("ld %s.o -o %s", name, name)
	} else when ODIN_ARCH == .amd64 {
		return fmt.aprintf("ld -m elf_i386 %s.o -o %s", name, name)
	} else {
		return ""
	}
}
