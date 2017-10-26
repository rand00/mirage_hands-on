
# Visualizing connections

*... Under construction ...*

Connect to your unikernel on localhost with
* browser @ localhost:8080
* socat @ localhost:4040

## Unikernel usage
* See unikernel parameters with `./visualizing_connections_unikernel --help`
* See how to compile the unikernel at the main README 
  * https://github.com/rand00/mirage_hands-on 

## Socat usage

The port 4040 of your unikernel is used for sending commands from your
computer to the unikernel.

```bash
$ socat - TCP4:localhost:4040
hi 
unikernel
```
.. where each line written in `socat` will be seen as a separate command. 

## Libraries used

* TyXml: Typesafe Html5 and Svg
  * https://ocsigen.org/tyxml/ 
* Vg: Declaratie 'cut semantics' vector graphics with different backends
  * http://erratique.ch/software/vg/demos/sqc.html
  * Nice example with animation: http://erratique.ch/software/vg/demos/sqc.html

