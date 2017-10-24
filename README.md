# MirageOS hands-on

## Setup
* Opam (package manager) + Mirage library installation instructions
  can be found at https://mirage.io/wiki/install 

## Helpful Mirage Links
* Types for arguments of your 'Main' functor: http://docs.mirage.io/mirage-types-lwt/Mirage_types_lwt/index.html
* Mirage modules documentation: http://mirage.github.io/mirage/
  * Note that Mirage depends on other libraries in some interface, so when you see
    a line in a Mirage module like `include Functoria.KEY`, this means that
    the types in the `Functoria.KEY` module are also part of the current module.
    Therefore also lookup the documentation for Functoria if you want to understand
    the full interface.

## Unikernels specific links

### Merging histories over LAN

#### Libraries

##### EzIrmin
* Guide: http://kcsrk.info/ocaml/irmin/crdt/2017/02/15/an-easy-interface-to-irmin-library/

##### Lwt
* Guide: https://mirage.io/docs/tutorial-lwt 

## Links for further reading

* MirageOS official Hello-world guide: https://mirage.io/wiki/hello-world
* MirageOS official example unikernels to start your own code from:
  https://github.com/mirage/mirage-skeleton 

