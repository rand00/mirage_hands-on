open Rresult
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

  let master = ref None
  
  let position = ref 0

  let name = ref ""
  
  let known_actors : (Ipaddr.V4.t * (Types.actor option)) list ref
    = ref []

  let nth_actor n = try Ok(List.nth !known_actors n)
    with _ -> Error (R.msg "Actor index not filled.")
  
  let save_actor (ip, actor) =
    let has_ip (ip', _) = ip' = ip in
    match CCList.find_idx has_ip !known_actors with
    | Some (index, _) ->
      begin match actor with
      | None -> index
      | Some _ as a ->
        known_actors := CCList.set_at_idx index (ip, a)
            !known_actors;
        index
      end 
    | None ->
      let known_actors' = !known_actors @ [ip,actor] in
      known_actors := known_actors';
      pred @@ List.length known_actors'

  let save_actor_ip ip = save_actor (ip, None)

  let master_unviewed : (Ipaddr.V4.t * Types.master_msg) list ref
    = ref [] 

  let master_viewed : (Ipaddr.V4.t * Types.master_msg) list ref
    = ref [] 
  
end
  
module Dispatch
    (Stack: Mirage_types_lwt.STACKV4) 
    (Http: HTTP)
= struct

  let dispatch_http port get_ip_str uri =
    let ip_str = get_ip_str () in
    let body, headers = match Uri.path uri with
      | "" | "/" ->
        (Frontpage.(to_string @@ content ~ip_str),
         Cohttp.Header.init ())
      | "/master" ->
        (*debugging*)
        log_http (fun f -> f "viewed %d unviewed %d actors %d"
                     (List.length !State.master_viewed)
                     (List.length !State.master_unviewed)
                     (List.length !State.known_actors)
                 );
        let body = Masterpage.Graphics.(
            render_svg ~log:(fun s -> log_http (fun f -> f"%s" s))
            @@ visualize
              ~viewed:!State.master_viewed
              ~unviewed:!State.master_unviewed
              ~actors:!State.known_actors 
          ) in
        begin
          State.master_viewed := !State.master_unviewed @ !State.master_viewed;
          State.master_unviewed := [];
        end;
        let headers = Cohttp.Header.(
            init ()
            |> (fun t -> add t "Content-Type" "image/svg+xml")
            |> (fun t -> add t "Content-Language" "non-html")
          )
        in
        body, headers
    (*goto add 'wrong-page' page*)
    in
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

  let send_message ~stack ~dst_ip type_ =
    let open Rresult in
    let open Lwt.Infix in
    let tcpv4 = Stack.tcpv4 stack in
    let dst_ip_real = match type_ with `To_master ip -> ip | _ -> dst_ip in
    let dst_port = 4040 
    in
    let connection =
      Stack.TCPV4.create_connection tcpv4 (dst_ip_real, dst_port)
    and timeout =
      OS.Time.sleep_ns (Duration.of_ms 700) >>= fun () ->
      err_lwt `Timeout
    in
    Lwt.pick [connection; timeout] >>= function
    | Error `Timeout ->
      err_lwt (
        R.msg @@ Printf.sprintf "timeout for connection %s on port %d"
          (Ipaddr.V4.to_string dst_ip_real) dst_port
      )
    | Error _ ->
      err_lwt (
        R.msg @@ Printf.sprintf "error connecting to %s on port %d"
          (Ipaddr.V4.to_string dst_ip_real) dst_port
      )
    | Ok flow ->
      let sexp_str =
        begin match type_ with
        | `To_actor ->
          `Msg_actor {
            name = !State.name;
            position = !State.position }
        | `To_master _master_ip ->
          `Msg_master {
            name = !State.name;
            position = !State.position;
            to_ip = Ipaddr.V4.to_string dst_ip }
        end 
        |> Types.sexp_of_remote_msg
        |> Sexp.to_string
      in
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
        restrict_remote @@ fun () ->
        State.master := Some ip;
        log_cmd (fun f -> f "set master ip to %s" (Ipaddr.V4.to_string ip));
        ok_lwt ()
      | `Position p ->
        restrict_remote @@ fun () ->
        State.position := p;
        log_cmd (fun f -> f "set position to %d" p);
        ok_lwt ()
      | `Send_msg actor_index ->
        (*goto add: [
            save local-visualization-state; 
          ]*)
        restrict_remote @@ fun () ->
        begin match State.nth_actor actor_index with
          | Error e -> err_lwt e
          | Ok (actor_ip, actor) -> 
            log_cmd (fun f ->
                let name = (match actor with
                      Some a -> a.name
                    | None -> "UNKNOWN") in
                f "sending message to actor %s with ip %s"
                  name (Ipaddr.V4.to_string actor_ip)
              );
            send_message `To_actor ~dst_ip:actor_ip ~stack 
            >>*= fun () ->
            begin match !State.master with
              | None -> ok_lwt () 
              | Some master_ip ->
                send_message (`To_master master_ip) ~dst_ip:actor_ip ~stack
            end
        end 
      | `Remote msg ->
        begin match msg with
          | `Msg_actor am ->
            let index = State.save_actor (ip, Some am) in
            log_cmd (fun f ->
                f "got message from actor %s@%s - info saved to index %d"
                  am.name ip_str index);
          | `Msg_master mm -> 
            State.(master_unviewed := (ip, mm) :: !master_unviewed);
            let ifrom = State.save_actor (ip, Some {
                name = mm.name;
                position = mm.position
              })
            and ito = State.save_actor_ip @@
              Ipaddr.V4.of_string_exn mm.to_ip 
            in
            log_cmd (fun f -> f "%s@%s (index %d) -> %s (index %d)"
                        mm.name ip_str ifrom mm.to_ip ito);
        end;
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
        (*goto fix: use packet-based protocol on top of tcp*)
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
