open Lwt.Infix

(** Common signature for http and https. *)
module type HTTP = Cohttp_lwt.Server

(* Logging *)
let http_src = Logs.Src.create "http" ~doc:"HTTP server"
module Http_log = (val Logs.src_log http_src : Logs.LOG)

module Dispatch
    (Stack: Mirage_types_lwt.STACKV4)
    (Http: HTTP)
= struct

  let failf fmt = Fmt.kstrf Lwt.fail_with fmt

  let http_dispatch port get_ip_str uri =
    let ip_str = get_ip_str () in
    let body = Frontpage.(to_string @@ content ~ip_str) in
    (*>goto make correct header - add content-type etc.*)
    let headers = Cohttp.Header.init () in
    Http.respond_string ~status:`OK ~body ~headers ()
  
  let serve dispatch =
    let callback (_, cid) request _body =
      let uri = Cohttp.Request.uri request in
      let cid = Cohttp.Connection.to_string cid in
      Http_log.info (fun f -> f "[%s] serving %s." cid (Uri.to_string uri));
      dispatch uri
    in
    let conn_closed (_,cid) =
      let cid = Cohttp.Connection.to_string cid in
      Http_log.info (fun f -> f "[%s] closing" cid);
    in
    Http.make ~conn_closed ~callback ()

end

module Main
    (Stack: Mirage_types_lwt.STACKV4)
    (Pclock: Mirage_types.PCLOCK)
    (Http: HTTP) 
= struct

  module D = Dispatch(Stack)(Http)
  module Ip = Stack.IPV4

  (*>goto: gets the ip 0.0.0.0 on unix & net=socket - correct?*)
  let ip_str stack () =
    Stack.ipv4 stack
    |> Ip.get_ip |> List.hd
    |> Ipaddr.V4.to_string
  
  let start stack _clock http =
    let http_port = Key_gen.http_port () in
    let tcp = `TCP http_port in
    let serve_http =
      Http_log.info (fun f -> f "listening on %d/TCP" http_port);
      http tcp @@ D.serve (D.http_dispatch http_port (ip_str stack))
    in
    serve_http
    (*Lwt.join [ https; http ]*)

end
