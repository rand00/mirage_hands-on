
open Sexplib
open Rresult
open Astring
open Astring.String

let is_num str = for_all Char.Ascii.is_digit str

let parse_remote_msg s =
  let str = String.trim @@ Sub.to_string s in
  try
    Sexp.of_string str
    |> Types.remote_msg_of_sexp
    |> R.ok
  with _ ->
    Error (R.msg @@ "Wrong format of remote-msg: '"^str^"'")

let parse_ip s =
  let str = String.trim @@ Sub.to_string s in
  Ipaddr.V4.of_string str
  |> R.of_option ~none:(fun () ->
      Error (R.msg @@ "Wrong format ipv4: '"^str^"'")
    )

let parse_position s =
  let str = String.trim @@ Sub.to_string s in
  if is_num str then
    Ok (int_of_string str)
  else
    Error (R.msg "Position was not a digit")

let drop_white s = Sub.drop ~sat:Char.Ascii.is_white s

let is_token c = not (Char.Ascii.is_white c)

let parse_cmd s =
  let cmd, rest = Sub.span ~sat:is_token s in
  drop_white rest |> fun data ->
  match Sub.to_string cmd |> Ascii.lowercase with
  | "remote" ->
    parse_remote_msg data >>= fun remote_msg -> 
    Ok (`Remote (remote_msg))
  | "actor" ->
    parse_ip data >>= fun ip ->
    Ok (`Actor ip)
  | "master" ->
    parse_ip data >>= fun ip ->
    Ok (`Master ip)
  | "position" ->
    parse_position data >>= fun pos -> 
    Ok (`Position (pos))
  | msg when is_num msg ->
    Ok(`Send_msg (int_of_string msg))
  | s -> Error(R.msg @@ "Unknown command '"^s^"'")

let cmd str =
  Sub.v str |> drop_white |> parse_cmd
  


