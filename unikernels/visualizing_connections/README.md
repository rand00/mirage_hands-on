
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
* Read (and modify) the source! The unikernel is kept relatively simple, 
  so it should be relatively simple to modify its behaviour.

## Socat usage

The port 4040 of your unikernel is used for sending commands from your
computer to the unikernel.

```bash
$ socat READLINE TCP4:localhost:4040
<cmd>
...
```
.. note that on some systems `socat` doesn't support the READLINE parameter
which gives a bash-like interface. Exchange 'READLINE' with '-' to make it
work.

Each line written in `socat` will be seen as a separate command. 
There exist the following commands (until you add more):
* `remote <sexp>` where `<sexp>` is an internal s-expression format for 
  messages from other unikernels.
* `actor <ip>` where `<ip>` is an address you want the unikernel to remember
  for some other unikernel. This command also sends a message right away
  to this ip.
* `master <ip>` where `<ip>` is the address of the 'master' unikernel on the
  network.
* `position <degrees>` where `<degrees>` is the angle in degrees (clockwise) from 
  which your unikernel is positioned relative to the master unikernel.
* `<index>` which sends a message to the i'th unikernel ip registered with 
  the `actor` command.

## Libraries used

* TyXml: Typesafe Html5 and Svg
  * https://ocsigen.org/tyxml/ 
* Vg: Declaratie 'cut semantics' vector graphics with different backends
  * http://erratique.ch/software/vg/demos/sqc.html
  * Nice example with animation: http://erratique.ch/software/vg/demos/sqc.html

