# OCaml workloads

OCaml programs compiled to WasmGC with
[wasm_of_ocaml](https://ocsigen.org/js_of_ocaml/latest/manual/wasm_overview).
They are grouped into two line items:

- `ocaml-tools-wasm`: OCaml developer tools.
  - The [js_of_ocaml](https://github.com/ocsigen/js_of_ocaml) compiler,
    compiling a bytecode library (the CAMLBOY emulator library) to JavaScript,
    as done for separate compilation in development builds.
  - [ocamlformat](https://github.com/ocaml-ppx/ocamlformat), formatting one of
    its own source files (`Fmt_odoc.ml`) with the default profile.
- `ocaml-apps-wasm`: OCaml applications.
  - The [CAMLBOY](https://github.com/linoscope/CAMLBOY) Game Boy emulator,
    running the first 200 frames of the homebrew game
    [Tobu Tobu Girl](https://tangramgames.dk/tobutobugirl/) headless.
  - The [herd7](https://github.com/herd/herdtools7) memory model simulator,
    checking 13 litmus tests of herdtools7's `catalogue/aarch64` against the
    AArch64 memory model.
  - The [msat](https://github.com/Gbury/mSAT) SAT solver, solving two problems
    of the DIMACS benchmark set (a towers of Hanoi planning problem and a
    circuit fault analysis problem) with a small driver (`src/msat/`).
  - The [KaSim](https://github.com/Kappa-Dev/KappaTools) simulator of
    rule-based models written in Kappa, simulating KappaTools' model of EGF
    receptor signalling (`examples/large/sos/sos.ka`) for 25,000 events, with
    a fixed seed and 20 times fewer molecules than by default.

Each iteration runs all the programs of the line item, each in a new instance
with its command line and input files. The Wasm modules are compiled once, in
the first iteration. The output of the last run is compared with that of the
native version of the program.

## Running the programs

wasm_of_ocaml generates a JavaScript loader (`build/*.js`) and a Wasm module
(`build/*.wasm`). The loader supports command-line arguments, exit codes and
file output only when running under Node.js. `benchmark.js` therefore provides
a minimal Node.js-like environment (`process`, `require("node:fs")`, …) backed
by an in-memory file system, so that the unmodified loader can run in browsers
and JavaScript shells. Lines of the output which vary between runs (herd7
reports the running time of each test, and the output of KaSim starts with its
command line and a random identifier) are ignored when checking it.

## Building

Run `./build.sh`. It requires opam (2.2 or later), git, curl, python3, GMP
and Binaryen (version 120 or later). It creates an opam root in `_opam-root/`,
separate from the user's, with a fixed commit of opam-repository, and installs
OCaml 5.4.0 and wasm_of_ocaml (pinned to a commit of the js_of_ocaml
repository), fetches the third-party sources at fixed versions (applying the
patches in `patches/`, see below), builds the programs and compiles them with
`wasm_of_ocaml --effects=disabled --opt 2 --pretty`. `--pretty` keeps a name
section in the Wasm modules, for profiling; the code is otherwise almost
identical to that produced without it.
`build.log` records the versions used. The programs' command lines and
expected output checksums are written to `build/manifest.json`.

The drivers of the workloads are in `src/`, with primitives that wasm_of_ocaml
does not implement:

- `src/ocamlformat/stubs.wat`: three primitives of the Base library (used by
  ocamlformat-lib). Only `Base_am_testing` is called, when Base is
  initialized.
- `src/kasim/stubs.wat`: primitives of the threads and lwt.unix libraries,
  used by KaSim. Those called when the libraries are initialized return
  plausible values; KaSim writes its output with `Lwt_io`, which uses the
  three blit functions.

herd7 uses zarith, whose Wasm implementation comes from
[zarith_stubs_js](https://github.com/janestreet/zarith_stubs_js), with fixes
to Wasm validation errors (branch `wasm-validation-fixes` of the
[ocaml-wasm fork](https://github.com/ocaml-wasm/zarith_stubs_js)).
`patches/kappatools.patch` renames the identifier `effect` (a keyword since
OCaml 5.3) in KappaTools, and adapts its JSON reading to yojson 3.

herd7's inputs (the AArch64 model, made of `aarch64.cat` and the files it
includes, and the litmus tests) are bundled in `build/herd-inputs.json`.

## Licenses

- js_of_ocaml compiler and runtime: LGPL-2.1-or-later with OCaml linking
  exception. The compiler also links menhirLib (LGPL-2.0 with linking
  exception), cmdliner (ISC), sedlex (MIT) and yojson (BSD-3-Clause).
- ocamlformat: MIT, with parts under LGPL-2.1 with OCaml linking exception.
  Its dependencies include LGPL libraries (menhirLib, fix, ocp-indent) and
  MIT/ISC libraries (Base, uucp, uuseg, …).
- CAMLBOY: MIT. `src/camlboy/camlboy_bench.ml` is adapted from CAMLBOY's
  `bin/sdl2/bench.ml`.
- Tobu Tobu Girl (`build/camlboy-tobu.gb`) by Tangram Games: the source code
  is licensed under the MIT License, and the assets (images, text, sound and
  music) under the
  [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
- herdtools7 (herd7, the litmus tests and model files of
  `build/herd-inputs.json`): CeCILL-B, except its ASL interpreter (`asllib/`,
  linked into herd7) and the model files with an Arm Ltd copyright header,
  which are under the BSD-3-Clause license. zarith: LGPL-2.0 with OCaml linking
  exception; zarith_stubs_js: MIT.
- msat: Apache-2.0; iter (used by msat): BSD-2-Clause. The problems
  (`build/msat-*.cnf`) come from the second DIMACS Implementation Challenge
  benchmark set, as included in msat's test suite: `hanoi4.cnf` by Bart Selman
  and `ssa6288-047.cnf` by Allen Van Gelder and Yumi Tsuji.
- KappaTools (KaSim, `build/kasim-sos.ka`): LGPL-3.0. Its dependencies:
  lwt (MIT), re, num, camlp-streams (LGPL-2.1 with OCaml linking exception),
  fmt, logs (ISC), yojson and result (BSD-3-Clause).
- The OCaml standard library, linked into all the programs: LGPL-2.1 with
  OCaml linking exception. bigstringaf (used by CAMLBOY): BSD-3-Clause.
