# OBF

OBF (odin brainfuck) is a brainfuck compiler written on [odin](https://github.com/odin-lang/Odin). It compiles brainfuck code to nasm assembly.

Currently supported is only elf x64.

In the examples folder is a helloworld and mandelbrot example, both compile successfully.

nasm and a linker (ld) both need to be in the path.

#### Building:

Assuming you have odin installed correctly and in the path, you can just run:

```
cd obf
odin build . -out:obf
```

#### Usage:
```
./obf file.bf [-r (run) | -k (keep asm) | -32 (generate 32 bit asm)]
```
There should be an executable in the current directory now.

If you passed -r it will run it automatically.

If you passed -k it will keep the assembly file. Otherwise it will be deleted.

You can simply run the file executable.

The executables don't depend on libc, they only use syscalls, so it should work out of the box.

Btw: BIG thanks to Tsoding for making all those videos about his development of the porth language, since it helped me a lot in understanding assembly
and compilers in general.

Tsoding Daily Porth Playlist: [Youtube](https://www.youtube.com/playlist?list=PLpM-Dvs8t0VbMZA7wW9aR3EtBqe2kinu4)
