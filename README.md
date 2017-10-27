# MirageOS hands-on

In this main README.md you find the general links and setup instructions
for getting to an initial environment for running Mirage unikernels.
You will find further specific instructions inside the unikernels directories.

## Setup
* OCaml, Opam (package manager) and the MirageOS library installation instructions
  can be found at
  * Linux/Unix/OSX
    * https://mirage.io/wiki/install
  * Windows + Windows Subsystem for Linux (I havn't tested this with Mirage)
    * http://themargin.io/2017/02/02/OCaml_on_win/
* Editor setup (type-check in-code, code-completion, type-at-point, jump-to-location, indentation, documentation)
  * Opam user setup (app to automatically setup editor configuration)
    * https://github.com/AltGr/opam-user-setup 

## Common Mirage unikernel development workflow
```bash
mirage cleanup
mirage configure --net=socket -t unix   # here several possible configuration-options exist
make depend   
make
./your-unikernel   # run the unikernel (will be named what you specified in config.ml)
```
If you have already run the previous once, and have not added any new packages to the
dependencies in config.ml, you can just run `make && ./your-unikernel`. Else for
major changes to config.ml you need to run the whole clean-config-depend-make chain.

```bash
./your-unikernel --help   # to open the custom man-page for your own unikernel (:
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

### Pioneer projects to contribute to on MirageOS
See https://github.com/mirage/mirage-www/wiki/Pioneer-Projects

### Projects using Mirage

* Nymote: MirageOS for private cloud and ownership of own data
  * http://nymote.org/blog/
* Getting Things Done app for the browser (merging of state between browser tabs etc.)
  * http://www.roscidus.com/blog/blog/2015/04/28/cuekeeper-gitting-things-done-in-the-browser/

### Interesting libraries

* Irmin (Git-like distributed datastore)
  * Irmin github: https://github.com/mirage/irmin 
  * EzIrmin (easy wrapper for Irmin) guide: https://github.com/kayceesrk/ezirmin
    * Note: EzIrmin not compatible with Mirage for now, but interesting read
* TyXML : https://ocsigen.org/tyxml/
  * Typesafe Html5 and Svg
* Vg by Daniel Bünzli (and all his other libraries!) : http://erratique.ch/software/vg
  * Functional declarative vector-graphics with cut instead of paste semantics.


