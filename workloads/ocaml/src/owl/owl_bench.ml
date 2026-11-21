(* Pure-OCaml scientific computing & ML benchmark using owl-base:
   1. Reverse-mode automatic differentiation (Algodiff) training a 2D CNN
      (conv2d -> tanh -> max_pool2d -> dense -> MSE) with SGD.
   2. 2D Gray-Scott reaction-diffusion stencil via conv2d on float64 Bigarrays.
   3. Adaptive Romberg numerical quadrature. *)

module A = Owl_base_dense_ndarray_d
module AD = Owl_algodiff_generic.Make (Owl_base_algodiff_primal_ops.D)

let train_cnn ~steps =
  let batch = 4 and h = 12 and w = 12 and c_out = 4 in
  let x =
    AD.Arr
      (A.init [| batch; h; w; 1 |] (fun i ->
           sin (float_of_int (i + 1) *. 0.07)))
  in
  let target =
    AD.Arr
      (A.init [| batch; 2 |] (fun i -> cos (float_of_int (i + 1) *. 0.19)))
  in
  let k_conv =
    ref
      (A.init [| 3; 3; 1; c_out |] (fun i ->
           0.2 *. sin (float_of_int (i + 1) *. 0.31)))
  in
  let flat_dim = (h / 2) * (w / 2) * c_out in
  let w_fc =
    ref
      (A.init [| flat_dim; 2 |] (fun i ->
           0.1 *. cos (float_of_int (i + 1) *. 0.23)))
  in
  let b_fc = ref (A.zeros [| 1; 2 |]) in
  let lr = 0.02 in
  let denom = float_of_int (batch * 2) in
  let last_loss = ref 0.0 in
  for _ = 1 to steps do
    let tag = AD.tag () in
    let k = AD.make_reverse (AD.Arr !k_conv) tag in
    let wf = AD.make_reverse (AD.Arr !w_fc) tag in
    let bf = AD.make_reverse (AD.Arr !b_fc) tag in
    let conv = AD.NN.conv2d ~padding:Owl_types.SAME x k [| 1; 1 |] in
    let act = AD.Maths.tanh conv in
    let pool = AD.NN.max_pool2d Owl_types.SAME act [| 2; 2 |] [| 2; 2 |] in
    let flat = AD.Maths.reshape pool [| batch; flat_dim |] in
    let pred = AD.Maths.(flat *@ wf + bf) in
    let diff = AD.Maths.(pred - target) in
    let loss = AD.Maths.(sum' (diff * diff) / F denom) in
    AD.reverse_prop (AD.F 1.0) loss;
    last_loss := AD.unpack_flt loss;
    let upd r node =
      let g = AD.unpack_arr (AD.adjval node) in
      r := A.sub !r (A.mul_scalar g lr)
    in
    upd k_conv k;
    upd w_fc wf;
    upd b_fc bf
  done;
  !last_loss

let gray_scott ~n ~steps =
  let lap =
    A.of_array
      [| 0.05; 0.2; 0.05; 0.2; -1.0; 0.2; 0.05; 0.2; 0.05 |]
      [| 3; 3; 1; 1 |]
  in
  let u = ref (A.ones [| 1; n; n; 1 |]) in
  let v = ref (A.zeros [| 1; n; n; 1 |]) in
  let c0 = n / 3 and c1 = 2 * n / 3 in
  for i = c0 to c1 do
    for j = c0 to c1 do
      A.set !u [| 0; i; j; 0 |] 0.5;
      A.set !v [| 0; i; j; 0 |] 0.25
    done
  done;
  let du = 0.16 and dv = 0.08 and f = 0.035 and k = 0.065 in
  for _ = 1 to steps do
    let lu = A.conv2d ~padding:Owl_types.SAME !u lap [| 1; 1 |] in
    let lv = A.conv2d ~padding:Owl_types.SAME !v lap [| 1; 1 |] in
    let uvv = A.mul !u (A.mul !v !v) in
    let du_dt =
      A.add (A.sub (A.mul_scalar lu du) uvv)
        (A.mul_scalar (A.scalar_sub 1.0 !u) f)
    in
    let dv_dt =
      A.sub (A.add (A.mul_scalar lv dv) uvv) (A.mul_scalar !v (f +. k))
    in
    u := A.add !u du_dt;
    v := A.add !v dv_dt
  done;
  A.sum' !u +. A.sum' !v

let () =
  let loss = train_cnn ~steps:6 in
  let gs = gray_scott ~n:32 ~steps:20 in
  let q =
    Owl_maths_quadrature.romberg ~n:12
      (fun x -> sin (x *. x) *. exp (-0.1 *. x))
      0.0 10.0
  in
  Printf.printf "loss=%.6f gs=%.6f q=%.6f\n" loss gs q
