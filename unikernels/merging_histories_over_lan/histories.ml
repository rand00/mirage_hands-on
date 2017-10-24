open Lwt.Infix

(** Common signature for http and https. *)
module type HTTP = Cohttp_lwt.Server

(* Logging *)
let http_src = Logs.Src.create "http" ~doc:"HTTP server"
module Http_log = (val Logs.src_log http_src : Logs.LOG)

module Dispatch (S: HTTP) = struct

  let failf fmt = Fmt.kstrf Lwt.fail_with fmt

  let http_dispatch port uri =
    (*>goto make body from tyxml*)
    let body = "" in
    (*>goto make correct header*)
    let headers = Cohttp.Header.init_with "location" "hej.html" in
    S.respond_string ~status:`OK ~body ~headers ()
  
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
    S.make ~conn_closed ~callback ()

end

module Main
    (Pclock: Mirage_types.PCLOCK)
    (Http: HTTP) 
= struct

  module D = Dispatch(Http)

  let start _clock http =
    let http_port = Key_gen.http_port () in
    let tcp = `TCP http_port in
    let serve_http =
      Http_log.info (fun f -> f "listening on %d/TCP" http_port);
      http tcp @@ D.serve (D.http_dispatch http_port)
    in
    serve_http
    (*Lwt.join [ https; http ]*)

end
