(* Pure-OCaml cryptographic hashing benchmark using digestif.ocaml:
   computes chained SHA-256 (int32), SHA-512 (int64), and BLAKE2B (int64)
   digests over an input file. *)

let hash_rounds (type a) (module H : Digestif.S with type t = a) data rounds =
  let prev = ref (H.to_raw_string (H.digest_string data)) in
  for _ = 1 to rounds do
    let ctx = H.feed_string H.empty !prev in
    let ctx = H.feed_string ctx data in
    prev := H.to_raw_string (H.get ctx)
  done;
  H.to_hex (H.of_raw_string !prev)

let () =
  let rounds = ref 5 in
  let file = ref "" in
  let spec =
    [ ("--rounds", Arg.Set_int rounds, "Number of chained hash rounds") ]
  in
  Arg.parse spec (fun path -> file := path)
    "digestif_bench [--rounds N] <file>";
  let data = In_channel.with_open_bin !file In_channel.input_all in
  let r = !rounds in
  let s256 = hash_rounds (module Digestif.SHA256) data r in
  let s512 = hash_rounds (module Digestif.SHA512) data r in
  let b2b = hash_rounds (module Digestif.BLAKE2B) data r in
  Printf.printf "sha256:  %s\nsha512:  %s\nblake2b: %s\n" s256 s512 b2b
