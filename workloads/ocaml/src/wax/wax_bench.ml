(* Compile a Wax source module to a validated WebAssembly binary using wax-lib.
   With [--decompile <in.wasm> <out.wax>], decompile a Wasm binary to Wax
   (used by build.sh to produce the input module). *)

let decompile input output =
  let color = Wax_utils.Colors.Never in
  let bytes = In_channel.with_open_bin input In_channel.input_all in
  let features = Wax_utils.Feature.default () in
  let bin_ast =
    Wax_utils.Diagnostic.run ~color ~palette:Wax_utils.Colors.wax_theme
      ~source:None (fun d ->
        Wax_wasm.Wasm_parser.module_ d ~features ~filename:input bytes)
  in
  let text_ast = Wax_wasm.Binary_to_text.module_ ~features bin_ast in
  let wax_ast =
    Wax_utils.Diagnostic.run ~color ~palette:Wax_utils.Colors.wax_theme
      ~source:None (fun d ->
        Wax_conversion.From_wasm.module_ ~faithful:false ~features d text_ast)
  in
  let wax_ast =
    Wax_utils.Diagnostic.run ~color ~palette:Wax_utils.Colors.wax_theme
      ~source:None (fun d ->
        Wax_lang.Typing.f ~simplify:true ~faithful:false d wax_ast)
    |> snd |> Wax_lang.Typing.erase_types
  in
  Out_channel.with_open_bin output (fun oc ->
      Wax_lang.Output.run_channel oc (fun p ->
          Wax_lang.Output.module_ p ~color ~out_channel:oc ~tail:[]
            ~trivia:(Wax_utils.Trivia.empty ()) wax_ast);
      output_char oc '\n')

let compile input output =
  let contents = In_channel.with_open_bin input In_channel.input_all in
  let bin =
    Wax.wax_to_binary ~validate:true ~warn_unused:false ~try_table:true
      ~filename:input contents
  in
  Out_channel.with_open_bin output (fun out_channel ->
      Wax.output_binary ~out_channel bin)

let () =
  match Sys.argv with
  | [| _; "--decompile"; input; output |] -> decompile input output
  | [| _; input; output |] -> compile input output
  | _ ->
      prerr_endline "Usage: wax_bench [--decompile] <input> <output>";
      exit 2
