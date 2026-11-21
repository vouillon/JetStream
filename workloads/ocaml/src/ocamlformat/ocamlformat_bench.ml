(* Format an OCaml implementation file with ocamlformat's default profile and
   write the result to <file>.out. *)

let () =
  let input_name = Sys.argv.(1) in
  let source = In_channel.with_open_bin input_name In_channel.input_all in
  match
    Ocamlformat_lib.Translation_unit.parse_and_format
      Ocamlformat_lib.Syntax.Use_file ~input_name ~source
      Ocamlformat_lib.Conf.default
  with
  | Ok formatted ->
      Out_channel.with_open_bin (input_name ^ ".out") (fun oc ->
          output_string oc formatted)
  | Error e ->
      Ocamlformat_lib.Translation_unit.Error.print Format.err_formatter e;
      exit 1
