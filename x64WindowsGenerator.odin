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
	id := pop(&f.loop_arr)
	str := fmt.aprintf(	"\tcmp byte [rbx], 0\n" + 
						"\tjne lb_start_%d\n" + 
						"lb_end_%d:\n", id, id)
	defer delete(str)
	write(f, str)
	f.index += 1
}

write_setup_x64_windows :: proc(f: ^File) {
	write(f, 	"BITS 64\n" + 
				"default rel\n" + 
				"global _main\n" + 
				"STDOUT_HANDLE equ -11\n" + 
				"STDIN_HANDLE equ -10\n" + 
				"extern ExitProcess, GetStdHandle, WriteConsoleA, ReadConsoleA, CloseHandle\n" +
				"section .data\n" + 
				"\tbuffer times 30000 db 0\n" + 
				"\tout_handle dq 0\n" +
				"\tin_handle dq 0\n" + 
				"\toutbuffer times 8192 db 0\n" +
				"\toutbuffer_len dd 0\n" +
				"section .bss\n" + 
				"\tinput: resb 3\n" +
				"\tread: resb 4\n" + 
				"\twritten: resb 4\n" +  
				"section .text\n" + 
				"_input:\n" +
				"\tsub rsp, 40\n" + 
				"\tcall _print\n" +
				"\tmov rcx, [in_handle]\n" + 
				"\tmov rdx, input\n" + 
				"\tmov r8, 1\n" + 
				"\tmov r9, read\n" + 
				"\tcall ReadConsoleA\n" + 
				"\tmov al, byte [input]\n" + 
				"\tmov byte [rbx], al\n" + 
				"\tadd rsp, 40\n" + 
				"\tret\n" + 
				"_output:\n" + 
				"\tsub rsp, 40\n" +
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
				"\tadd rsp, 40\n" +
				"\tret\n" +
				"_print:\n" +
				"\tsub rsp, 40\n" +
				"\tmov rcx, [out_handle]\n" + 
				"\tmov rdx, outbuffer\n" + 
				"\tmov r8, [outbuffer_len]\n" + 
				"\tmov r9, written\n" + 
				"\tcall WriteConsoleA\n" +
				"\tmov dword [outbuffer_len], 0\n" +
				"\tadd rsp, 40\n" +
				"\tret\n" +
				"_main:\n" + 
				"\tpush rsp\n" + 
				"\tmov rbp, rsp\n" + 
				"\tsub rsp, 40\n" + 
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
	write(f, 	"\tcall _print\n" +
				"\tmov rcx, [out_handle]\n" + 
				"\tcall CloseHandle\n" + 
				"\tmov rcx, [in_handle]\n" + 
				"\tcall CloseHandle\n" + 
				"\tadd rsp, 8\n" + 
				"\tmov rsp, rbp\n" + 
				"\tpop rbp\n" + 
				"\tmov rcx, 0\n" + 
				"\tcall ExitProcess\n")
}

compile_cmd_x64_windows :: proc(name: string) -> string {
	return fmt.aprintf("nasm -fwin64 %s", name)
}

link_cmd_x64_windows :: proc(name: string) -> string {
	when ODIN_OS != .Windows {
		return ""
	}
	// The "/nologo" option is just to shut up the microsoft copyright notice they print every time.
	return fmt.aprintf("link /subsystem:console /nologo /nodefaultlib /entry:_main %s kernel32.Lib", name)	
}
