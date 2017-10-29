open Sexplib.Std

(*Note that the cmd-type is specified as polymorphic variants
  in the Parse module *)

type actor = {
  name : string;
  position : int;
} [@@deriving sexp]

type actor_msg = actor [@@ deriving sexp]

type master_msg = {
  name : string;
  position : int;
  to_ip : string;
} [@@deriving sexp]

type remote_msg = [
  | `Msg_actor of actor_msg
  | `Msg_master of master_msg
][@@deriving sexp]



