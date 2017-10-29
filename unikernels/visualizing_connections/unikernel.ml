open Sexplib
open Lwt.Infix

open Types
    
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

let ok_lwt x = Lwt.return @@ Ok x
let err_lwt x = Lwt.return @@ Error x

let (>>*=) m f =
  m >>= function
  | Error _ as e -> Lwt.return e
  | Ok x -> f x

module State = struct

  let position = ref 0

  let name = ref ""
  
  let known_actors : (Ipaddr.V4.t * (Types.actor option)) list ref
    = ref []

  let nth_actor n = List.nth !known_actors n
  
  let save_actor_ip ip =
    let has_ip (ip', _) = ip' = ip in
    match CCList.find_idx has_ip !known_actors with
    | Some (index, _) -> index
    | None ->
      known_actors := (ip, None) :: !known_actors;
      0

end
  
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

  let dispatch_cmd ~stack ~ip cmd_str =
    let open Rresult in
    let is_remote = not @@ Ipaddr.V4.(localhost = ip || any = ip) in
    let ip_str = Ipaddr.V4.to_string ip in
    let restrict_remote thunk =
      if is_remote then
        let err_msg = Printf.sprintf
            "external actor with ip '%s' tried to run local command: '%s'"
            ip_str (String.trim cmd_str) in
        err_lwt (R.msg @@ err_msg)
      else thunk ()
    in
    let rec aux = function
      | `Actor ip ->
        restrict_remote @@ fun () ->
        let actor_index = State.save_actor_ip ip in
        log_cmd (fun f ->
            f "saved ip %s at index %d"
              (Ipaddr.V4.to_string ip) actor_index);
        aux @@ `Send_msg actor_index
      | `Master ip ->
        restrict_remote (fun () -> failwith "todo")
      | `Position p ->
        restrict_remote (fun () -> failwith "todo")
      | `Send_msg actor_index ->
        (*goto howto: [
            send msg dst; DONE
            save vis-state; 
            send msg master
          ]*)
        restrict_remote @@ fun () ->
        let (dst_ip, actor) = State.nth_actor actor_index in
        let tcpv4 = Stack.tcpv4 stack in
        let open Lwt.Infix in
        Stack.TCPV4.create_connection tcpv4 (dst_ip, 4040)
        >>= begin function
          | Error _ ->
            err_lwt (
              R.msg @@ Printf.sprintf "error contacting destination %s"
                (Ipaddr.V4.to_string dst_ip)
            )
          | Ok flow ->
            let sexp_str =
              { name = !State.name; position = !State.position }
              |> Types.sexp_of_remote_msg
              |> Sexp.to_string in
            let message = Printf.sprintf "remote %s\n" sexp_str in
            let payload = Cstruct.of_string message in
            Stack.TCPV4.write flow payload >>= function
            | Error _ ->
              err_lwt (
                R.msg @@ Printf.sprintf "error writing to destination %s"
                  (Ipaddr.V4.to_string dst_ip)
              )
            | Ok _ as ok ->
              log_cmd (fun f ->
                  f "succesfully wrote message to %s"
                    (Ipaddr.V4.to_string dst_ip)
                );
              Stack.TCPV4.close flow >>= fun () -> 
              ok_lwt ()
        end 
      | `Remote msg ->
        log_cmd (fun f -> f "remote msg from %s" ip_str);
        ok_lwt ()
    in
    (Parse.cmd cmd_str |> Lwt.return)
    >>*= aux 
    
  let serve_cmd ~stack flow =
    let dst, dst_port = Stack.TCPV4.dst flow in
    let dst_str = Ipaddr.V4.to_string dst in
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
        (*should have continued reading here or parsed packet-based protocol*)
        let buff_str = Cstruct.to_string buff in
        begin dispatch_cmd ~stack ~ip:dst buff_str >|= function
        | Ok () ->
          log_cmd (fun f -> f "succesfully parsed msg.")
        | Error e_msg ->
          log_cmd (fun f -> f "%a." Rresult.R.pp_msg e_msg);
        end >>= fun () -> 
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
      Stack.listen_tcpv4 stack ~port:cmd_socket_port (D.serve_cmd ~stack);
      Stack.listen stack
    in
    Lwt.join [
      serve_http;
      serve_cmd;
    ]

end
