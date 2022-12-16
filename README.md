# OBF

OBF is a brainfuck compiler written in [odin](https://github.com/odin-lang/Odin). It compiles brainfuck code to nasm assembly.

Currently supported is only elf x86/x64 (Windows x64 support is experimental, but examples run without any problems).

In the examples folder is a helloworld and mandelbrot example, both compile successfully.

nasm and a linker (ld/link) both need to be in the path.

#### Building:

Assuming you have odin installed correctly and in the path, you can just run:

```
cd obf
odin build . -out:obf
```

#### Usage:
```
./obf file.bf [-r (run) | -k (keep asm) | (-32 (generate 32 bit asm) | -64 (generate 64 bit asm))]
```
There should be an executable in the current directory now.

If you passed -r it will run it automatically.

If you passed -k it will keep the assembly file. Otherwise it will be deleted.

On 32 bit systems, obf will generate 32 bit asm. You can generate 64 bit asm by passing the -64 flag.

On 64 bit systems, obf will generate 64 bit asm. You can generate 32 bit asm by passing the -32 flag.

Passing the -32 flag on x86 arch or -64 flag on x64 arch will do nothing.

You can simply run the file executable.

The executables don't depend on libc, they only use syscalls, so it should work out of the box.

Big thanks to http://brainfuck.org/ for some of the examples in the examples folder.

Btw: BIG thanks to Tsoding for making all those videos about his development of the porth language, since it helped me a lot in understanding assembly
and compilers in general.

Tsoding Daily Porth Playlist: [Youtube](https://www.youtube.com/playlist?list=PLpM-Dvs8t0VbMZA7wW9aR3EtBqe2kinu4)
