open Sexplib.Std

(*Note that the cmd-type is specified as polymorphic variants
  in the Parse module *)

type actor = {
  name : string;
  position : float;
} [@@deriving sexp]

type remote_msg = actor [@@deriving sexp]

type master_msg = {
  name : string;
  position : float;
  to_ip : string;
} [@@deriving sexp]

