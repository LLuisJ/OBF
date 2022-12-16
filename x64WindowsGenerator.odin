package main

import "core:fmt"
import "core:runtime"

write_right_x64_windows :: proc(f: ^File) {
	times := count(f, '>')
	if times > 1 {
		str := fmt.aprintf("\tadd rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc rbx\n")
	}
}

write_left_x64_windows :: proc(f: ^File) {
	times := count(f, '<')
	if times > 1 {
		str := fmt.aprintf("\tsub rbx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec rbx\n")
	}
}

write_input_x64_windows :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output_x64_windows :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add_x64_windows :: proc(f: ^File) {
	times := count(f, '+')
	if times > 1 {
		str := fmt.aprintf("\tadd byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc byte [rbx]\n")
	}
}

write_sub_x64_windows :: proc(f: ^File) {
	times := count(f, '-')
	if times > 1 {
		str := fmt.aprintf("\tsub byte [rbx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec byte [rbx]\n")
	}
}

write_loop_begin_x64_windows :: proc(f: ^File) {
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" + 
						"\tje lb_end_%d\n" + 
						"lb_start_%d:\n", f.loop, f.loop)
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end_x64_windows :: proc(f: ^File) {
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

write_setup_x64_windows :: proc(f: ^File) {
	write(f, 	"BITS 64\n" + 
				"default rel\n" +
				"global _main\n" + 
				"STDOUT_HANDLE equ -11\n" + 
				"STDIN_HANDLE equ -10\n" + 
				"extern ExitProcess, GetStdHandle, WriteFile, ReadFile, CloseHandle\n" +
				"section .data\n" + 
				"\tbuffer times 30000 db 0\n" + 
				"\tout_handle dq 0\n" +
				"\tin_handle dq 0\n" + 
				"section .bss\n" + 
				"\tinput: resb 2\n" +
				"\tnum_written: resd 1" + 
				"_input:\n" +
				"\tsub rsp, 48\n" + 
				"\tmov rcx, [in_handle]\n" + 
				"\tmov rdx, input\n" + 
				"\tmov r8, 1\n" + 
				"\tmov r9, 0\n" + 
				"\tpush 0\n" + 
				"\tret\n" + 
				"_output:\n" + 
				"\tsub rsp, 48\n" +
				"\tmov rcx, [output_handle]\n" + 
				"\tmov rdx, buffer\n" + 
				"\tmov r8, 1\n" + 
				"\tmov r9, num_written\n" + 
				"\tpush qword 0\n" + 
				"\tcall WriteFile\n" +
				"\tadd rsp, 48\n" +
				"\tret\n" +
				"_main:\n" + 
				"\tpush rbp\n" + 
				"\tsub rsp, 40\n" + 
				"\tmov rbp, rsp\n" +
				"\tmov rbx, buffer\n" +
				"\tmov rcx, STDOUT_HANDLE\n" + 
				"\tcall GetStdHandle\n" + 
				"\tmov [out_handle], rax\n" + 
				"\tadd rsp, 32\n" + 
				"\tsub rsp, 32\n" + 
				"\tmov rcx, STDIN_HANDLE\n" + 
				"\tcall GetStdHandle\n" + 
				"\tmov [in_handle], rax\n" + 
				"\tadd rsp, 32\n")
}

write_exit_x64_windows :: proc(f: ^File) {
	write(f, 	"\tmov rcx, [out_handle]\n" + 
				"\tcall CloseHandle\n" + 
				"\tmov rcx, [in_handle]\n" + 
				"\tcall CloseHandle\n" + 
				"\tmov rsp, rbp\n" + 
				"\tpop rbp\n" + 
				"\tadd rsp, 8\n" + 
				"\tmov rcx, 0\n" + 
				"\tcall ExitProcess\n")
}

compile_cmd_x64_windows :: proc(name: string) -> string {
	when ODIN_OS == .Linux {
		return ""
	}
	return fmt.aprintf("nasm -fwin64 %s", name)
}

link_command_x64_windows :: proc(name: string) -> string {
	when ODIN_OS == .Linux {
		return ""
	}
	return fmt.aprintf("link /subsystem:console /nodefaultlib /entry:main %s kernel32.Lib", name)
}
