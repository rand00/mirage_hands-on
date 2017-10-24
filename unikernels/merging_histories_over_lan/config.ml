open Mirage

let stack = generic_stackv4 default_network
let http_srv = http_server @@ conduit_direct ~tls:false stack

let http_port =
  let doc = Key.Arg.info ~doc:"Listening HTTP port." ["http"] in
  Key.(create "http_port" Arg.(opt int 8080 doc))

let main =
  let packages = [
    package "uri"; 
  ] in
  let keys = List.map Key.abstract [
      http_port
    ] in
  foreign "Histories.Main"
    ~packages
    ~keys
    (pclock @-> http @-> job)

let () =
  register "histories_unikernel" [main $ default_posix_clock $ http_srv]
