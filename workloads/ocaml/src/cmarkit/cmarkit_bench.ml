(* Parse a CommonMark document with Cmarkit (extensions enabled) and render
   to XHTML, repeating a fixed number of times. *)

let () =
  let repeats = ref 1 in
  let file = ref "" in
  let spec =
    [ ("--repeats", Arg.Set_int repeats, "Number of times to render the input") ]
  in
  Arg.parse spec (fun path -> file := path)
    "cmarkit_bench [--repeats N] <file.md>";
  let content = In_channel.with_open_bin !file In_channel.input_all in
  let last = ref "" in
  for _ = 1 to !repeats do
    let doc =
      Cmarkit.Doc.of_string ~layout:false ~locs:true ~file:!file ~strict:false
        content
    in
    let r = Cmarkit_html.xhtml_renderer ~safe:true () in
    last := Cmarkit_renderer.doc_to_string r doc
  done;
  print_string !last
