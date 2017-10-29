
# Visualizing connections

*... Under construction ...*

Connect to your unikernel on localhost with
* browser @ localhost:8080
* socat @ localhost:4040

## Unikernel usage
* See how to compile the unikernel at the main README 
  * https://github.com/rand00/mirage_hands-on 
* When compiled, see unikernel parameters with `./visualizing_connections_unikernel --help`
  and the following `socat` usage section. 
* Read (and modify) the source! 
  * The source files are:
    * `config.ml`: The place where you specify which packages, parameters
      and keys the unikernel depends on.
    * `unikernel.ml`: The entry to the unikernel, containing the Main functor
      parametrized by the modules specified in `config.ml`.
    * `frontpage.ml`: A module containing a function for generating the
      type-safe html for the front-page served by your unikernel on port
      `8080`.
    * `parse.ml`: Parsing of the commands written to the tcp-socket
      served at port `4040`.
    * `types.ml`: The types for e.g. messages - some of these derive 
      s-expression readers/writers for easy transmission of ocaml
      values.

## Socat usage

The port 4040 of your unikernel is used for sending commands from your
computer to the unikernel.

```bash
$ socat READLINE TCP4:localhost:4040
<cmd>
...
```
.. note that on some systems `socat` doesn't support the `READLINE` parameter
which gives a bash-like interface. Exchange `READLINE` with `-` to make it
work.

### Commands supported via `socat` interface

Each line written in `socat` will be seen as a separate command. 
There exist the following commands meant to be used locally (until you add more!).
These commands are pr. default restricted to `localhost` usage only:
* `position <degrees>` where `<degrees>` is the angle in degrees (clockwise) from 
  which your unikernel is positioned (physically) relative to the master unikernel.
* `master <ip>` where `<ip>` is the address of the 'master' unikernel on the
  network. Use this to register your unikernels external communication at the
  master node.
* `actor <ip>` where `<ip>` is an address you want the unikernel to remember
  for some other unikernel. This command also sends a message right away
  to this ip. Afterwards use the `<index>` command to send more messages
  swiftly.
* `<index>`; an integer given, which sends a message to the `i`'th unikernel-ip 
  registered with the `actor` command.

The rest of the commands supported, are used for communication between unikernels.
* `remote <sexp>` where `<sexp>` is an internal s-expression format for 
  messages from other unikernels.


## Libraries used

* TyXml: Typesafe Html5 and Svg
  * https://ocsigen.org/tyxml/ 
* Sexplib / `ppx_sexp_conv`: Ocaml-values to/from s-expressions.
  * https://github.com/janestreet/ppx_sexp_conv 
* Astring: Library for parsing strings, created to support very readable 
  and correct, but more verbose code than regular-expression based parsing.
  * http://erratique.ch/software/astring/doc/Astring (see examples at bottom)
* Vg: Declarative 'cut semantics' vector graphics parametrized by different 
  backends.
  * http://erratique.ch/software/vg/doc/index
  * Nice example with animation: http://erratique.ch/software/vg/demos/sqc.html
