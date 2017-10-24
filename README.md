# MirageOS hands-on

In this main README.md you find the general links and setup instructions
for getting to an initial environment for running Mirage unikernels.
You will find further specific instructions inside the unikernels directories.

## Setup
* Opam (package manager) + Mirage library installation instructions
  can be found at https://mirage.io/wiki/install 

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

* MirageOS official Hello-world guide: https://mirage.io/wiki/hello-world
* MirageOS official example unikernels to start your own code from:
  https://github.com/mirage/mirage-skeleton 

