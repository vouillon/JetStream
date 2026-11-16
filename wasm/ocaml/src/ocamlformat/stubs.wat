;; Primitives of the Base library (used by ocamlformat-lib) that wasm_of_ocaml
;; does not provide. Base_am_testing is called when Base is initialized; the
;; other two are not called by the benchmark.
(module
   ;; Not running inline tests.
   (func (export "Base_am_testing") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "Base_clear_caml_backtrace_pos")
      (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   ;; Base.Bool.select
   (func (export "caml_csel_value")
      (param $c (ref eq)) (param $a (ref eq)) (param $b (ref eq))
      (result (ref eq))
      (if (result (ref eq)) (i31.get_s (ref.cast (ref i31) (local.get $c)))
         (then (local.get $a))
         (else (local.get $b))))
)
