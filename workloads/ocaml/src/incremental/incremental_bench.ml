(* Incremental DAG stabilization benchmark: reactive grid with incremental
   folds, cutoffs, dynamic bind rewiring, and balanced tree reductions. *)

module Incr = Incremental.Make ()

let () =
  let rows = ref 128 in
  let cols = ref 16 in
  let steps = ref 25000 in
  let spec =
    [
      ("--rows", Arg.Set_int rows, "Number of grid rows");
      ("--cols", Arg.Set_int cols, "Number of grid cols");
      ("--steps", Arg.Set_int steps, "Number of update/stabilize steps");
    ]
  in
  Arg.parse spec (fun _ -> ())
    "incremental_bench [--rows R] [--cols C] [--steps N]";
  let r = !rows and c = !cols and n = !steps in
  let cells =
    Array.init r (fun i ->
        Array.init c (fun j -> Incr.Var.create (((i * 17) + (j * 31)) mod 100)))
  in
  let mode = Incr.Var.create 0 in
  let row_nodes =
    Array.init r (fun i ->
        let vars = Array.map Incr.Var.watch cells.(i) in
        let sum =
          Incr.unordered_array_fold vars ~init:0
            ~f:(fun acc x -> acc + x)
            ~update:(F_inverse (fun acc x -> acc - x))
        in
        let weighted =
          Incr.map3 sum vars.(0) vars.(c - 1) ~f:(fun s v0 v1 ->
              (s * 3) + (v0 lxor v1))
        in
        let bucket = Incr.map weighted ~f:(fun x -> x / 16) in
        Incr.set_cutoff bucket Incr.Cutoff.phys_equal;
        Incr.bind (Incr.Var.watch mode) ~f:(fun m ->
            if (m + i) mod 3 = 0 then
              Incr.map2 bucket weighted ~f:(fun b w -> (b * 7) + (w mod 13))
            else Incr.map2 sum bucket ~f:(fun s b -> (s lxor b) + i)))
  in
  let total =
    match
      Incr.reduce_balanced row_nodes ~f:(fun x -> x) ~reduce:(fun a b ->
          ((a * 31) + b) land 0x3fffffff)
    with
    | Some node -> node
    | None -> Incr.return 0
  in
  let obs = Incr.observe total in
  Incr.stabilize ();
  let checksum = ref (Incr.Observer.value_exn obs) in
  let state = ref 123456789 in
  let next_int bound =
    state := ((!state * 48271) + 12345) land 0x3fffffff;
    !state mod bound
  in
  for step = 1 to n do
    for _ = 1 to 4 do
      let i = next_int r in
      let j = next_int c in
      Incr.Var.set cells.(i).(j) (next_int 1000)
    done;
    if step mod 25 = 0 then Incr.Var.set mode (step / 25);
    Incr.stabilize ();
    checksum := ((!checksum * 31) + Incr.Observer.value_exn obs) land 0x3fffffff
  done;
  Printf.printf "checksum: %d\n" !checksum
