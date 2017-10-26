
# Visualizing connections

*... Under construction ...*

Connect to your unikernel on localhost with
* browser @ localhost:8080
* socat @ localhost:4040

## Unikernel usage
See unikernel parameters with `./visualizing_connections_unikernel --help`

## Socat usage

```bash
$ socat - TCP4:localhost:4040
hi 
unikernel
```
.. where each line written to `socat` will be seen as a separate 'command' 
to the unikernel.

## Libraries used

* TyXml: Typesafe Html5 and Svg
  * https://ocsigen.org/tyxml/ 
* Vg: Declaratie 'cut semantics' vector graphics with different backends
  * http://erratique.ch/software/vg/demos/sqc.html
  * Nice example with animation: http://erratique.ch/software/vg/demos/sqc.html

