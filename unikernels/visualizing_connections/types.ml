open Sexplib.Std

(*Note that the cmd-type is specified as polymorphic variants
  in the Parse module *)

type remote_msg = {
  name : string;
  position : float;
} [@@deriving sexp]

type master_msg = {
  name : string;
  position : float;
  to_ip : string;
} [@@deriving sexp]

