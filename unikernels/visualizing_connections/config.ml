open Mirage

let stack = generic_stackv4 default_network
let http_srv = http_server @@ conduit_direct ~tls:false stack

let http_port =
  let doc = "Listening HTTP port." in
  let arg = Key.Arg.info ~doc ["http"] in
  Key.(create "http_port" Arg.(opt int 8080 arg))

let cmd_socket_port =
  let doc = "Listening cmd-interface port (should be \
             the same as for the other unikernels)." in
  let arg = Key.Arg.info ~doc ["cmd_socket"] in
  Key.(create "cmd_socket_port" Arg.(opt int 4040 arg))

let main =
  let packages = [
    package "uri";
    package "tyxml";
    package "astring";
    package "ppx_sexp_conv";
    package "containers";
    package "gg"; 
    package "vg";
    package "vg.svg";
  ] 
  and keys = List.map Key.abstract [
      http_port;
      cmd_socket_port;
    ]
  in
  foreign "Unikernel.Main"
    ~packages
    ~keys
    (stackv4 @-> pclock @-> http @-> job)


let () =
  register "visualizing_connections_unikernel" [
    main $ stack $ default_posix_clock $ http_srv
  ]
