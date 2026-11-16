(* Solve SAT problems in DIMACS CNF format with msat, and print whether each
   is satisfiable (after checking the model) or not. *)

module S = Msat_sat

let parse file =
  let ic = open_in_bin file in
  let clauses = ref [] and current = ref [] in
  (try
     while true do
       let line = String.trim (input_line ic) in
       if line <> "" && line.[0] <> 'c' && line.[0] <> 'p' && line.[0] <> '%'
       then
         List.iter
           (fun token ->
             if token <> "" then
               match int_of_string token with
               | 0 ->
                   clauses := List.rev !current :: !clauses;
                   current := []
               | n -> current := n :: !current)
           (String.split_on_char ' '
              (String.map (fun c -> if c = '\t' then ' ' else c) line))
     done
   with End_of_file -> ());
  close_in ic;
  List.rev !clauses

let solve file =
  let clauses = parse file in
  let st = S.create ~store_proof:false ~size:`Big () in
  S.assume st (List.map (List.map S.Int_lit.make) clauses) ();
  match S.solve st with
  | S.Sat sat ->
      let ok =
        List.for_all
          (List.exists (fun l -> sat.Msat.eval (S.Int_lit.make l)))
          clauses
      in
      Printf.printf "%s: sat%s\n" file (if ok then "" else " (wrong model)")
  | S.Unsat _ -> Printf.printf "%s: unsat\n" file

let () =
  for i = 1 to Array.length Sys.argv - 1 do
    solve Sys.argv.(i)
  done
