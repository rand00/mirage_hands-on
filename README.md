# MirageOS hands-on

In this main README.md you find the general links and setup instructions
for getting to an initial environment for running Mirage unikernels.
You will find further specific instructions inside the unikernels directories.

## Setup
* OCaml, Opam (package manager) and the MirageOS library installation instructions
  can be found at https://mirage.io/wiki/install 

## Common Mirage unikernel development workflow
```bash
mirage cleanup
mirage_configure --net=socket -t unix   # here several possible configuration-options exist
make depend   # fetches dependencies from `opam`
make
./your-unikernel   # run the unikernel (will be named what you specified in config.ml)
```
If you have already run the previous once, and have not added any new packages to the
dependencies in config.ml, you can just run `make && ./your-unikernel`.

```bash
./your-unikernel --help   #to open a man-page for your own unikernel (:
```

## Helpful Mirage development links
* Types for arguments of your 'Main' functor: http://docs.mirage.io/mirage-types-lwt/Mirage_types_lwt/index.html
* Search for Opam packages: https://opam.ocaml.org/packages/
  * Find links to the packages documentation from here, or read the `*.mli` files
    contained in your local opam folder with libraries (they are usually well documented).
    Find this folder with `opam var lib`.
* Mirage modules documentation: http://mirage.github.io/mirage/
  * Note that Mirage depends on other libraries in some of the module interfaces,
    so when you see 
    a line in a Mirage module like `include Functoria.KEY`, this means that
    the types in the `Functoria.KEY` module are also part of the current module.
    Therefore also lookup the documentation for Functoria if you want to understand
    the full interface.

## Links for further reading

* MirageOS official Hello World guide: https://mirage.io/wiki/hello-world
* MirageOS official example unikernels - a good place to start your own
  unikernels from:
  https://github.com/mirage/mirage-skeleton 

