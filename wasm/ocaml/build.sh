#!/bin/bash
# Build the OCaml workloads: OCaml programs compiled to WasmGC with
# wasm_of_ocaml. Requires opam (2.2+), git, curl, python3 and Binaryen
# (wasm-opt, wasm-merge, version 120 or later) on the PATH.
#
# The OCaml toolchain is installed in a separate opam root (_opam-root/), using
# a fixed commit of opam-repository; it is reused across builds. Third-party
# sources are fetched into _*/ and vendor/. The output goes to build/.

set -euo pipefail
cd "$(dirname "$0")"

OCAML_VERSION=5.4.0
OPAM_REPOSITORY_COMMIT=49c3ff00c7cf462380b7c42e8de0412e2a2372d3
JSOO_REPO=https://github.com/ocsigen/js_of_ocaml.git
JSOO_COMMIT=be44d3863fc248ca79d975bb85507e15588b7233
CAMLBOY_REPO=https://github.com/linoscope/CAMLBOY.git
CAMLBOY_COMMIT=11ae10a1e1ea318a64e6c13018c96be5aaaf23bb
KAPPATOOLS_REPO=https://github.com/Kappa-Dev/KappaTools.git
KAPPATOOLS_COMMIT=7f8fd869c4f83ea113dc614b1e052bda73c69ae2
MSAT_VERSION=0.9.1
OCAMLFORMAT_LIB_VERSION=0.29.0
BIGSTRINGAF_VERSION=0.10.0
CMARKIT_VERSION=0.4.0
DIGESTIF_VERSION=1.4.2
INCREMENTAL_VERSION=v0.17.0

# Workload sizes.
CAMLBOY_FRAMES=200
# DIMACS instances of the msat-bin test suite.
MSAT_INSTANCES="sat/hanoi4.cnf ssa/ssa6288-047.cnf"
# KaSim simulation of the EGFR/SoS signalling model of KappaTools' examples.
# The model divides the initial numbers of molecules (and the volume) by its
# 'scale' variable, 1/2 by default; a larger scale makes the simulation of the
# events, rather than the construction of the initial state, dominate.
KASIM_SCALE=10
KASIM_EVENTS=25000
CMARKIT_REPEATS=40
DIGESTIF_ROUNDS=5
INCREMENTAL_ROWS=128
INCREMENTAL_COLS=16
INCREMENTAL_STEPS=25000

BUILD_LOG="$(realpath build.log)"
echo "Built on $(date --rfc-3339=seconds)" | tee "$BUILD_LOG"
log() { echo "$@" | tee -a "$BUILD_LOG"; }

rm -rf build/ vendor/ _build/ _jsoo/ _camlboy/ _herdtools7/ _zarith_stubs_js/ \
  _kappatools/ _msat/ _cmarkit/ _proto/

# Fetch a single commit of a git repository.
fetch_commit() {
  local repo=$1 commit=$2 dir=$3
  git init -q "$dir"
  git -C "$dir" fetch -q --depth 1 "$repo" "$commit"
  git -C "$dir" checkout -q FETCH_HEAD
  log "$repo: $(git -C "$dir" log -1 --format='%H %cd %s')"
}

# A separate opam root, so that the user's opam configuration is neither used
# nor modified.
export OPAMROOT="$PWD/_opam-root" OPAMSWITCH=jetstream
unset OPAM_SWITCH_PREFIX
oe() { opam exec -- "$@"; }

if [ ! -d _opam-root ]; then
  rm -rf _opam-repository
  mkdir _opam-repository
  curl -sSfL "https://github.com/ocaml/opam-repository/archive/$OPAM_REPOSITORY_COMMIT.tar.gz" |
    tar xz --strip-components=1 -C _opam-repository
  opam init --bare --no-setup --yes default "$PWD/_opam-repository"
  opam switch create jetstream "ocaml-base-compiler.$OCAML_VERSION" --yes
fi
log "opam-repository: $OPAM_REPOSITORY_COMMIT"

# wasm_of_ocaml (and the js_of_ocaml compiler, which is one of the workloads)
# at a fixed commit. js_of_ocaml derives its version from `git describe`; keep
# git from finding the enclosing JetStream repository when opam builds it.
export GIT_CEILING_DIRECTORIES="$PWD"
fetch_commit "$JSOO_REPO" "$JSOO_COMMIT" _jsoo
for pkg in js_of_ocaml-compiler js_of_ocaml wasm_of_ocaml-compiler; do
  opam pin add --yes --no-action --kind=path "$pkg" "$PWD/_jsoo"
done
# The libraries used by the programs (KaSim needs lwt, num, re, fmt, logs,
# yojson and camlp-streams).
opam install --yes \
  js_of_ocaml-compiler wasm_of_ocaml-compiler js_of_ocaml ocamlfind \
  "ocamlformat-lib.$OCAMLFORMAT_LIB_VERSION" "bigstringaf.$BIGSTRINGAF_VERSION" \
  "msat.$MSAT_VERSION" "cmarkit.$CMARKIT_VERSION" "digestif.$DIGESTIF_VERSION" \
  "incremental.$INCREMENTAL_VERSION" \
  lwt num re fmt logs yojson camlp-streams stdlib-shims result
log "OCaml: $(oe ocamlc -version)"
log "wasm_of_ocaml: $(oe wasm_of_ocaml --version)"
log "Binaryen: $(wasm-opt --version)"
log "Installed opam packages:"
opam list --installed --columns=name,version --normalise | tee -a "$BUILD_LOG"

# Third-party sources.
fetch_commit "$CAMLBOY_REPO" "$CAMLBOY_COMMIT" _camlboy
mkdir -p vendor/camlboy
cp -r _camlboy/lib _camlboy/LICENSE vendor/camlboy/
fetch_commit "$KAPPATOOLS_REPO" "$KAPPATOOLS_COMMIT" _kappatools
git -C _kappatools apply "$PWD/patches/kappatools.patch"
opam source --dir=_msat "msat-bin.$MSAT_VERSION" > /dev/null
log "msat-bin: $MSAT_VERSION"
opam source --dir=_cmarkit "cmarkit.$CMARKIT_VERSION" > /dev/null
log "cmarkit: $CMARKIT_VERSION"

# Bytecode (for wasm_of_ocaml) and native (to compute the expected outputs)
# versions of the programs.
oe dune build --root . --no-print-directory --profile release \
  src/camlboy/camlboy_bench.bc src/camlboy/camlboy_bench.exe \
  src/ocamlformat/ocamlformat_bench.bc src/ocamlformat/ocamlformat_bench.exe \
  src/msat/msat_bench.bc src/msat/msat_bench.exe \
  src/cmarkit/cmarkit_bench.bc src/cmarkit/cmarkit_bench.exe \
  src/digestif/digestif_bench.bc src/digestif/digestif_bench.exe \
  src/incremental/incremental_bench.bc src/incremental/incremental_bench.exe \
  2>&1 | tee -a "$BUILD_LOG"
# The js_of_ocaml compiler workload is built without findlib support, which
# it does not use, and which would embed the path of the switch's findlib.conf.
sed -i '/(js_of_ocaml-compiler.findlib-support ->/d' _jsoo/compiler/bin-js_of_ocaml/dune
oe dune build --root _jsoo --no-print-directory --profile release compiler/bin-js_of_ocaml/js_of_ocaml.bc \
  2>&1 | tee -a "$BUILD_LOG"
oe dune build --root _kappatools --no-print-directory --profile release core/main/KaSim.bc core/main/KaSim.exe \
  2>&1 | tee -a "$BUILD_LOG"

mkdir -p build

# Compile a bytecode program to build/NAME.js (the wasm_of_ocaml loader) and
# build/NAME.wasm (the code, which must be a single module).
compile() {
  local name=$1 bytecode=$2
  shift 2
  oe wasm_of_ocaml --effects=disabled --opt 2 --pretty "$@" "$bytecode" -o "build/$name.js" \
    2>&1 | tee -a "$BUILD_LOG"
  local modules=(build/"$name".assets/*.wasm)
  if [ ${#modules[@]} -ne 1 ]; then
    echo "Expected a single Wasm module for $name" >&2
    exit 1
  fi
  mv "${modules[0]}" "build/$name.wasm"
  rm -r "build/$name.assets"
}

compile camlboy _build/default/src/camlboy/camlboy_bench.bc
compile ocamlformat _build/default/src/ocamlformat/ocamlformat_bench.bc src/ocamlformat/stubs.wat
compile js_of_ocaml _jsoo/_build/default/compiler/bin-js_of_ocaml/js_of_ocaml.bc
compile msat _build/default/src/msat/msat_bench.bc
compile kasim _kappatools/_build/default/core/main/KaSim.bc src/kasim/stubs.wat
compile cmarkit _build/default/src/cmarkit/cmarkit_bench.bc
compile digestif _build/default/src/digestif/digestif_bench.bc
compile incremental _build/default/src/incremental/incremental_bench.bc src/ocamlformat/stubs.wat

# Inputs.
cp _camlboy/resource/games/tobu.gb build/camlboy-tobu.gb
cp "$(oe ocamlfind query ocamlformat-lib)/Fmt_odoc.ml" build/ocamlformat-input.ml
# js_of_ocaml compiles the CAMLBOY library separately (as in dune dev builds).
cp _build/default/vendor/camlboy/lib/camlboy_lib.cma build/js_of_ocaml-input.cma
i=0
for instance in $MSAT_INSTANCES; do
  cp "_msat/tests/$instance" "build/msat-$i.cnf"
  i=$((i + 1))
done
cp _kappatools/examples/large/sos/sos.ka build/kasim-sos.ka
# Build a CommonMark input document from the CommonMark spec examples bundled
# with cmarkit's test suite.
python3 - _cmarkit/test/spec.json build/cmarkit-spec.md <<'EOF'
import json, sys
spec = json.load(open(sys.argv[1], encoding="utf-8"))
md = "\n\n".join(
    f"## Example {ex['example']} ({ex['section']})\n\n{ex['markdown']}"
    for ex in spec
)
open(sys.argv[2], "w", encoding="utf-8").write(md)
EOF

# Expected outputs, from the native versions of the programs. The js_of_ocaml
# compiler is run as bytecode, from the build used for the workload, since its
# version appears in its output.
EXPECTED=$(mktemp -d)
(cd "$EXPECTED" &&
  "$OLDPWD/_build/default/src/camlboy/camlboy_bench.exe" --frames "$CAMLBOY_FRAMES" \
    "$OLDPWD/build/camlboy-tobu.gb" > camlboy.out &&
  cp "$OLDPWD/build/ocamlformat-input.ml" input.ml &&
  "$OLDPWD/_build/default/src/ocamlformat/ocamlformat_bench.exe" input.ml &&
  oe ocamlrun "$OLDPWD/_jsoo/_build/default/compiler/bin-js_of_ocaml/js_of_ocaml.bc" \
    compile "$OLDPWD/build/js_of_ocaml-input.cma" -o out.js &&
  cp "$OLDPWD"/build/msat-*.cnf . &&
  "$OLDPWD/_build/default/src/msat/msat_bench.exe" msat-*.cnf > msat.out &&
  cp "$OLDPWD/build/kasim-sos.ka" sos.ka &&
  "$OLDPWD/_kappatools/_build/default/core/main/KaSim.exe" sos.ka -var scale "$KASIM_SCALE" \
    -seed 42 -u event -l "$KASIM_EVENTS" -p "$((KASIM_EVENTS / 100))" -mode batch --no-log -o data.csv > /dev/null &&
  "$OLDPWD/_build/default/src/cmarkit/cmarkit_bench.exe" --repeats "$CMARKIT_REPEATS" \
    "$OLDPWD/build/cmarkit-spec.md" > cmarkit.out &&
  "$OLDPWD/_build/default/src/digestif/digestif_bench.exe" --rounds "$DIGESTIF_ROUNDS" \
    "$OLDPWD/build/camlboy-tobu.gb" > digestif.out &&
  "$OLDPWD/_build/default/src/incremental/incremental_bench.exe" \
    --rows "$INCREMENTAL_ROWS" --cols "$INCREMENTAL_COLS" --steps "$INCREMENTAL_STEPS" \
    > incremental.out)

python3 - "$EXPECTED" "$CAMLBOY_FRAMES" "$KASIM_SCALE" "$KASIM_EVENTS" \
  "$CMARKIT_REPEATS" "$DIGESTIF_ROUNDS" "$INCREMENTAL_ROWS" "$INCREMENTAL_COLS" "$INCREMENTAL_STEPS" \
  > build/manifest.json <<'EOF'
import glob, json, os, sys

(
    expected_dir, camlboy_frames, kasim_scale, kasim_events,
    cmarkit_repeats, digestif_rounds, incr_rows, incr_cols, incr_steps,
) = sys.argv[1:10]

def fnv1a(path, ignore=()):
    data = open(os.path.join(expected_dir, path), "rb").read()
    # Lines starting with one of the prefixes in [ignore] vary between runs.
    data = b"\n".join(l for l in data.split(b"\n")
                      if not any(l.startswith(p.encode()) for p in ignore))
    h = 0x811C9DC5
    for b in data:
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return "%d:%08x" % (len(data), h)

msat_files = sorted(os.path.basename(p) for p in glob.glob(os.path.join(expected_dir, "msat-*.cnf")))

# For each workload: the preload keys of its loader, code and input files (the
# names under which the files are visible to the program; a bundle is a JSON
# file of several input files), its command line, and the checksum of its main
# output, ignoring the lines starting with the given prefixes.
manifest = {
    "camlboy": {
        "loader": "camlboyLoader", "wasm": "camlboyWasm",
        "files": {"tobu.gb": "camlboyRom"},
        "argv": ["--frames", camlboy_frames, "tobu.gb"],
        "output": "<stdout>", "expected": fnv1a("camlboy.out"),
    },
    "msat": {
        "loader": "msatLoader", "wasm": "msatWasm",
        "files": {name: "msatInput%d" % i for i, name in enumerate(msat_files)},
        "argv": msat_files,
        "output": "<stdout>", "expected": fnv1a("msat.out"),
    },
    "kasim": {
        "loader": "kasimLoader", "wasm": "kasimWasm",
        "files": {"sos.ka": "kasimModel"},
        "argv": ["sos.ka", "-var", "scale", kasim_scale, "-seed", "42",
                 "-u", "event", "-l", kasim_events,
                 "-p", str(int(kasim_events) // 100), "-mode", "batch",
                 "--no-log", "-o", "data.csv"],
        # The header lines contain the command line and a random identifier.
        "output": "data.csv", "ignore": ["#"],
        "expected": fnv1a("data.csv", ["#"]),
    },
    "incremental": {
        "loader": "incrementalLoader", "wasm": "incrementalWasm",
        "files": {},
        "argv": ["--rows", incr_rows, "--cols", incr_cols, "--steps", incr_steps],
        "output": "<stdout>", "expected": fnv1a("incremental.out"),
    },
    "digestif": {
        "loader": "digestifLoader", "wasm": "digestifWasm",
        "files": {"tobu.gb": "camlboyRom"},
        "argv": ["--rounds", digestif_rounds, "tobu.gb"],
        "output": "<stdout>", "expected": fnv1a("digestif.out"),
    },
    "ocamlformat": {
        "loader": "ocamlformatLoader", "wasm": "ocamlformatWasm",
        "files": {"input.ml": "ocamlformatInput"},
        "argv": ["input.ml"],
        "output": "input.ml.out", "expected": fnv1a("input.ml.out"),
    },
    "js_of_ocaml": {
        "loader": "jsoLoader", "wasm": "jsoWasm",
        "files": {"input.cma": "jsoInput"},
        "argv": ["compile", "input.cma", "-o", "out.js"],
        "output": "out.js", "expected": fnv1a("out.js"),
    },
    "cmarkit": {
        "loader": "cmarkitLoader", "wasm": "cmarkitWasm",
        "files": {"spec.md": "cmarkitInput"},
        "argv": ["--repeats", cmarkit_repeats, "spec.md"],
        "output": "<stdout>", "expected": fnv1a("cmarkit.out"),
    },
}
json.dump(manifest, sys.stdout, indent=2)
print()
EOF
rm -rf "$EXPECTED"

log "Build success"
