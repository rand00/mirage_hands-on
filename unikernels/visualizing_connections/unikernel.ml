open Lwt.Infix

module type HTTP = Cohttp_lwt.S.Server

(* Logging *)
(* goto find simpler way to define this if possible... *)
let http_src = Logs.Src.create "http" ~doc:"HTTP server"
module Http_log = (val Logs.src_log http_src : Logs.LOG)
let log_http = Http_log.info

let cmd_src = Logs.Src.create "cmd_socket" ~doc:"TCP cmd server"
module Cmd_log = (val Logs.src_log cmd_src : Logs.LOG)
let log_cmd = Cmd_log.info
let warn_cmd = Cmd_log.warn

let failf fmt = Fmt.kstrf Lwt.fail_with fmt

module Dispatch
    (Stack: Mirage_types_lwt.STACKV4) 
    (Http: HTTP)
= struct

  let dispatch_http port get_ip_str uri =
    let ip_str = get_ip_str () in
    let body = Frontpage.(to_string @@ content ~ip_str) in
    let headers = Cohttp.Header.init () in (*<goto make correct header*)
    Http.respond_string ~status:`OK ~body ~headers ()
  
  let serve_http dispatch =
    let callback (_, cid) request _body =
      let uri = Cohttp.Request.uri request in
      let cid = Cohttp.Connection.to_string cid in
      log_http (fun f -> f "[%s] serving %s." cid (Uri.to_string uri));
      dispatch uri
    in
    let conn_closed (_,cid) =
      let cid = Cohttp.Connection.to_string cid in
      log_http (fun f -> f "[%s] closing" cid);
    in
    Http.make ~conn_closed ~callback ()

  let dispatch_cmd ~ip cmd_str =
    let open Rresult in
    let ip_str = Ipaddr.V4.to_string ip in
    Parse.cmd cmd_str >>= function
    | `Remote msg -> log_cmd (fun f -> f "remote msg from %s" ip_str); Ok ()
    | `Actor ip -> log_cmd (fun f -> f "actor msg from %s" ip_str); Ok ()
    | `Master ip -> failwith "todo"
    | `Position p -> failwith "todo"
    | `Send_msg actor_index -> failwith "todo"
    
  
  (*goto filter external ip's optionally (but pr. default)*)
  let serve_cmd flow =
    let dst, dst_port = Stack.TCPV4.dst flow in
    let dst_str = (Ipaddr.V4.to_string dst) in
    let pp_error = Stack.TCPV4.pp_error in
    log_cmd (fun f -> f "%s connected on port %d" dst_str dst_port);
    let rec loop flow = 
      Stack.TCPV4.read flow >>= function
      | Ok `Eof ->
        log_cmd (fun f -> f "closing connection to %s" dst_str);
        Lwt.return_unit
      | Error e ->
        warn_cmd (fun f -> f "error reading data from: %a" pp_error e);
        Lwt.return_unit
      | Ok (`Data buff) ->
        let buff_str = Cstruct.to_string buff in
        log_cmd (*goto remove later?*)
          (fun f -> f "read from '%s': %d bytes: %s" 
              dst_str
              (Cstruct.len buff)
              (Cstruct.to_string buff |> String.trim));
        begin match dispatch_cmd ~ip:dst buff_str with
          | Ok _ -> log_cmd (fun f -> f "Succesfully parsed msg.")
          | Error e_msg ->
            log_cmd (fun f -> f "Cmd-parser: %a." Rresult.R.pp_msg e_msg)
        end;
        loop flow
    in
    loop flow >>= fun () -> Stack.TCPV4.close flow

end

module Main
    (Stack: Mirage_types_lwt.STACKV4)
    (Pclock: Mirage_types.PCLOCK)
    (Http: HTTP) 
= struct

  module D = Dispatch(Stack)(Http)

  (*note: gets the ip 0.0.0.0 on unix & net=socket 
    - should this be set manually?*)
  let ip_str stack () =
    Stack.(ipv4 stack |> IPV4.get_ip)
    |> List.hd
    |> Ipaddr.V4.to_string
  
  let start stack _clock http =
    let cmd_socket_port = Key_gen.cmd_socket_port () in
    let http_port = Key_gen.http_port () in
    let serve_http =
      log_http (fun f -> f "listening on %d/TCP" http_port);
      http (`TCP http_port)
      @@ D.serve_http (D.dispatch_http http_port (ip_str stack))
    and serve_cmd =
      log_cmd (fun f -> f "listening on %d/TCP" cmd_socket_port);
      Stack.listen_tcpv4 stack ~port:cmd_socket_port D.serve_cmd;
      Stack.listen stack
    in
    Lwt.join [
      serve_http;
      serve_cmd;
    ]

end
