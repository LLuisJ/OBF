package main

import "core:fmt"
import "core:runtime"

write_right_x86_windows :: proc(f: ^File) {
	times := count(f, '>')
	if times > 1 {
		str := fmt.aprintf("\tadd ebx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc ebx\n")
	}
}

write_left_x86_windows :: proc(f: ^File) {
	times := count(f, '<')
	if times > 1 {
		str := fmt.aprintf("\tsub ebx, %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec ebx\n")
	}
}

write_input_x86_windows :: proc(f: ^File) {
	write(f, "\tcall _input\n")
	f.index += 1
}

write_output_x86_windows :: proc(f: ^File) {
	write(f, "\tcall _output\n")
	f.index += 1
}

write_add_x86_windows :: proc(f: ^File) {
	times := count(f, '+')
	if times > 1 {
		str := fmt.aprintf("\tadd byte [ebx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tinc byte [ebx]\n")
	}
}

write_sub_x86_windows :: proc(f: ^File) {
	times := count(f, '-')
	if times > 1 {
		str := fmt.aprintf("\tsub byte [ebx], %d\n", times)
		defer delete(str)
		write(f, str)
	} else {
		write(f, "\tdec byte [ebx]\n")
	}
}

write_loop_begin_x86_windows :: proc(f: ^File) {
	str := fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
						"\tje lb_end_%d\n" + 
						"lb_start_%d:\n", f.loop, f.loop)
	defer delete(str)
	write(f, str)
	append(&f.loop_arr, f.loop)
	f.loop += 1
	f.index += 1
}

write_loop_end_x86_windows :: proc(f: ^File) {
	id := pop(&f.loop_arr)
	str := fmt.aprintf(	"\tcmp byte [ebx], 0\n" + 
						"\tjne lb_start_%d\n" + 
						"lb_end_%d:\n", id, id)
	defer delete(str)
	write(f, str)
	f.index += 1
}

write_setup_x86_windows :: proc(f: ^File) {
	write(f, 	"BITS 32\n" + 
				"default rel\n" + 
				"global main\n" + 
				"STDOUT_HANDLE equ -11\n" + 
				"STDIN_HANDLE equ -10\n" + 
				"extern _ExitProcess@4, _GetStdHandle@4, _WriteConsoleA@20, _ReadConsoleA@20, _CloseHandle@4\n" + 
				"section .data\n" + 
				"\tbuffer times 30000 db 0\n" + 
				"\tout_handle dd 0\n" + 
				"\tin_handle dd 0\n" + 
				"\toutbuffer times 8192 db 0\n" +
				"\toutbuffer_len dd 0\n" +
				"section .bss\n" + 
				"\tinput: resb 3\n" + 
				"\tread: resb 4\n" + 
				"\twritten: resb 4\n" + 
				"section .text\n" + 
				"_input:\n" + 
				"\tcall _print\n" +
				"\tpush 0\n" + 
				"\tpush read\n" + 
				"\tpush 1\n" + 
				"\tpush input\n" + 
				"\tpush dword [in_handle]\n" + 
				"\tcall _ReadConsoleA@20\n" + 
				"\tmov al, byte [input]\n" + 
				"\tmov byte [ebx], al\n" + 
				"\tret\n" + 
				"_output:\n" +
				"\tmov eax, outbuffer\n" +
				"\tadd eax, [outbuffer_len]\n" +
				"\tmov cl, byte [ebx]\n" +
				"\tmov byte [eax], cl\n" +
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
				"\tpush 0\n" + 
				"\tpush written\n" + 
				"\tpush dword [outbuffer_len]\n" + 
				"\tpush outbuffer\n" + 
				"\tpush dword [out_handle]\n" + 
				"\tcall _WriteConsoleA@20\n" + 
				"\tmov dword [outbuffer_len], 0\n" +
				"\tret\n" + 
				"main:\n" + 
				"\tpush esp\n" + 
				"\tmov ebp, esp\n" + 
				"\tmov ebx, buffer\n" + 
				"\tpush STDOUT_HANDLE\n" + 
				"\tcall _GetStdHandle@4\n" + 
				"\tmov [out_handle], eax\n" + 
				"\tpush STDIN_HANDLE\n" + 
				"\tcall _GetStdHandle@4\n" + 
				"\tmov [in_handle], eax\n")
}

write_exit_x86_windows :: proc(f: ^File) {
	write(f, 	"\tcall _print\n" +
				"\tpush dword [out_handle]\n" + 
				"\tcall _CloseHandle@4\n" + 
				"\tpush dword [in_handle]\n" + 
				"\tcall _CloseHandle@4\n" + 
				"\tmov esp, ebp\n" + 
				"\tpop ebp\n" +  
				"\tpush 0\n" + 
				"\tcall _ExitProcess@4\n")
}

compile_cmd_x86_windows :: proc(name: string) -> string {
	return fmt.aprintf("nasm -fwin32 %s", name)
}

link_cmd_x86_windows :: proc(name: string) -> string {
	when ODIN_OS != .Windows {
		return ""
	}
	return fmt.aprintf("link /subsystem:console /nologo /nodefaultlib /entry:main %s kernel32.Lib", name)
}
