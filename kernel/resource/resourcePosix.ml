(* -------------------------------------------------------------------- *)
exception InvalidResource

let () =
  Callback.register_exception
    "fr.inria.native-coq.resource.exn.InvalidResource"
    InvalidResource

(* -------------------------------------------------------------------- *)
type mmap

external length  : mmap -> int64 = "caml_resource_length"
external create  : string -> mmap = "caml_resource_from_filename"
external get1    : mmap -> int -> int = "caml_resource_get1"
external getle32 : mmap -> int -> int = "caml_resource_le32"
