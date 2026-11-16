(* Headless CAMLBOY benchmark: run a ROM for a fixed number of frames and
   print a checksum of the frame buffers. Adapted from CAMLBOY's
   bin/sdl2/bench.ml (MIT License, Copyright (c) 2021 linoscope). *)

open Camlboy_lib

let run ~rom_bytes ~frames =
  let cartridge = Detect_cartridge.f ~rom_bytes in
  let module Camlboy = Camlboy.Make (val cartridge) in
  let camlboy = Camlboy.create_with_rom ~rom_bytes ~print_serial_port:false in
  let frame_count = ref 0 in
  let checksum = ref 0 in
  while !frame_count < frames do
    match Camlboy.run_instruction camlboy with
    | In_frame -> ()
    | Frame_ended fb ->
        incr frame_count;
        Array.iter
          (Array.iter (fun c ->
               let v =
                 match c with
                 | `White -> 0
                 | `Light_gray -> 1
                 | `Dark_gray -> 2
                 | `Black -> 3
               in
               checksum := ((!checksum * 31) + v) land 0x3fffffff))
          fb
  done;
  !checksum

let () =
  let usage_msg = "camlboy_bench [--frames <frames>] <rom_path>" in
  let frames = ref 1000 in
  let rom_path = ref "" in
  let spec = [ ("--frames", Arg.Set_int frames, "Number of frames to run") ] in
  Arg.parse spec (fun path -> rom_path := path) usage_msg;
  let rom_bytes = Read_rom_file.f !rom_path in
  Printf.printf "checksum: %d\n" (run ~rom_bytes ~frames:!frames)
