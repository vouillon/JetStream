;; Primitives of the threads and lwt.unix libraries, used by KaSim, that
;; wasm_of_ocaml does not provide. Those called when the libraries are
;; initialized return plausible values (no signal handling, no notification
;; channel); KaSim writes its output with Lwt_io, which uses the three blit
;; functions.
(module
   (import "env" "caml_bigstring_blit_bytes_to_ba"
      (func $blit_bytes_to_ba
         (param (ref eq) (ref eq) (ref eq) (ref eq) (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_blit_ba_to_bytes"
      (func $blit_ba_to_bytes
         (param (ref eq) (ref eq) (ref eq) (ref eq) (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_blit_ba_to_ba"
      (func $blit_ba_to_ba
         (param (ref eq) (ref eq) (ref eq) (ref eq) (ref eq)) (result (ref eq))))

   (type $block (array (mut (ref eq))))

   (func (export "caml_thread_initialize") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   ;; Some 1024
   (func (export "lwt_unix_iov_max") (param (ref eq)) (result (ref eq))
      (array.new_fixed $block 2
         (ref.i31 (i32.const 0)) (ref.i31 (i32.const 1024))))

   ;; Little_endian
   (func (export "lwt_unix_system_byte_order") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_get_page_size") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 4096)))

   ;; A file descriptor which is never used.
   (func (export "lwt_unix_init_notification") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 100)))

   (func (export "lwt_unix_set_pool_size") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_handle_signal") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_set_signal")
      (param (ref eq) (ref eq) (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_remove_signal")
      (param (ref eq) (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_init_signals") (param (ref eq)) (result (ref eq))
      (ref.i31 (i32.const 0)))

   (func (export "lwt_unix_blit_from_bytes")
      (param $src (ref eq)) (param $src_off (ref eq)) (param $dst (ref eq))
      (param $dst_off (ref eq)) (param $len (ref eq)) (result (ref eq))
      (call $blit_bytes_to_ba (local.get $src) (local.get $src_off)
         (local.get $dst) (local.get $dst_off) (local.get $len)))

   (func (export "lwt_unix_blit_to_bytes")
      (param $src (ref eq)) (param $src_off (ref eq)) (param $dst (ref eq))
      (param $dst_off (ref eq)) (param $len (ref eq)) (result (ref eq))
      (call $blit_ba_to_bytes (local.get $src) (local.get $src_off)
         (local.get $dst) (local.get $dst_off) (local.get $len)))

   (func (export "lwt_unix_blit")
      (param $src (ref eq)) (param $src_off (ref eq)) (param $dst (ref eq))
      (param $dst_off (ref eq)) (param $len (ref eq)) (result (ref eq))
      (call $blit_ba_to_ba (local.get $src) (local.get $src_off)
         (local.get $dst) (local.get $dst_off) (local.get $len)))
)
