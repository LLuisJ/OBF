# OBF

OBF is a brainfuck compiler written in [odin](https://github.com/odin-lang/Odin). It compiles brainfuck code to nasm assembly.

#### Disclaimer: The generated assembly is not guaranteed to be stable/fast/efficient or anything else. This is a hobby project to learn assembly. If you want to make it better, I would be happy if you create a pr and improve something.

Currently supported is win32 x86/x64 and elf x86/x64.

In the examples folder are a few examples, all compile without problems.

nasm and a linker (ld/link) both need to be in the path.

#### Building:

Assuming you have odin installed correctly and in the path, you can just run:

```
cd obf
odin build . -out:obf
```

#### Usage:
```
./obf file.bf [-r (run) | -k (keep asm) | (-32 (generate 32 bit asm) | -64 (generate 64 bit asm)) (only works on linux)]
```
There should be an executable in the current directory now.

If you passed -r it will run it automatically.

If you passed -k it will keep the assembly file. Otherwise it will be deleted.

Passing -32/-64 only works on linux systems. On windows the generated assembly is based on the env variable VSCMD_ARG_HOST_ARCH (automatically set in native tools command prompt). So you need to either start a native tools command promp (x64 for 64 bit executables, x86 for 32 bit ones) or call vcvarsall.bat.

On 32 bit systems, obf will generate 32 bit asm. You can generate 64 bit asm by passing the -64 flag.

On 64 bit systems, obf will generate 64 bit asm. You can generate 32 bit asm by passing the -32 flag.

Passing the -32 flag on x86 arch or -64 flag on x64 arch will do nothing.

You can simply run the file executable.

The executables don't depend on libc, they only use syscalls, so it should work out of the box.

Windows executables depend on kernel32.dll but since it is installed with windows and always available (AFAIK) this isn't really a problem (See the comment in main.odin for a bit more explanation).

Big thanks to http://brainfuck.org/ for some of the examples in the examples folder.
