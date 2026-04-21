#!/bin/bash
#
# Build fpcup (CLI installer tool) for Linux using an installed FPC.
#
# Invokes fpc directly to compile fpcup.lpr.
# Output: upbin/fpcup-x86_64-linux  (or the native CPU variant)
#
# Usage:
#   bash build.sh
#   FPC=/opt/fpc-3.3.1/bin/fpc bash build.sh
#   bash build.sh --fpc /opt/fpc-3.3.1/bin/fpc
#
set -euo pipefail

SRCDIR="$(cd "$(dirname "$0")" && pwd)"

# ---- resolve FPC -------------------------------------------------------
# Accept --fpc <path> argument, else FPC env var, else search PATH.

FPC_EXE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fpc) FPC_EXE="$2"; shift 2 ;;
    *)     echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$FPC_EXE" ]]; then
  FPC_EXE="${FPC:-$(command -v fpc 2>/dev/null || true)}"
fi

if [[ -z "$FPC_EXE" || ! -x "$FPC_EXE" ]]; then
  echo "Error: FPC compiler not found." >&2
  echo "  Install FPC or pass --fpc /path/to/fpc  or set FPC=/path/to/fpc" >&2
  exit 1
fi

FPC_VER="$("$FPC_EXE" -iV 2>&1 | head -1)"
echo "FPC compiler : $FPC_EXE ($FPC_VER)"

# ---- target ------------------------------------------------------------

TARGET_CPU="$(uname -m | sed 's/x86_64/x86_64/; s/aarch64/aarch64/; s/armv.*/arm/')"
TARGET_OS="linux"

OUT_EXE="${SRCDIR}/upbin/fpcup-${TARGET_CPU}-${TARGET_OS}"
UNIT_OUT="${SRCDIR}/buildlibs/fpcup/${TARGET_CPU}-${TARGET_OS}"

echo "Target       : ${TARGET_CPU}-${TARGET_OS}"
echo "Output       : ${OUT_EXE}"
echo "Started      : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

mkdir -p "$(dirname "$OUT_EXE")" "$UNIT_OUT"

# ---- unit search paths (from fpcup.lpi) --------------------------------

FU_ARGS=(
  "-Fu${SRCDIR}/sources"
  "-Fu${SRCDIR}/sources/up"
  "-Fu${SRCDIR}/sources/crossinstallers"
  "-Fu${SRCDIR}/synaser"
  "-Fu${SRCDIR}/dcpcrypt/Hashes"
  "-Fu${SRCDIR}/dcpcrypt"
  "-Fu${SRCDIR}/dcpcrypt/Ciphers"
)

FI_ARGS=(
  "-Fi${SRCDIR}/sources"
  "-Fi${SRCDIR}/sources/up"
  "-Fi${SRCDIR}/dcpcrypt/Ciphers"
  "-Fi${UNIT_OUT}"
)

# ---- invoke fpc --------------------------------------------------------

set -x
"$FPC_EXE" \n  "${SRCDIR}/fpcup.lpr" \n  "-P${TARGET_CPU}" \n  "-T${TARGET_OS}" \n  -O2 -XX -CX -Xs -l- \n  "-o${OUT_EXE}" \n  "-FU${UNIT_OUT}" \n  "${FU_ARGS[@]}" \n  "${FI_ARGS[@]}" \n  -dFPCONLY \n  -dDisableRemoteLog \n  2>&1 | tee "${SRCDIR}/build.log"
set +x

# ---- report ------------------------------------------------------------

echo ""
echo "=== Build Complete: $(date '+%Y-%m-%d %H:%M:%S') ==="
if [[ -f "$OUT_EXE" ]]; then
  SIZE="$(stat -c%s "$OUT_EXE" 2>/dev/null || stat -f%z "$OUT_EXE")"
  echo "  $(basename "$OUT_EXE"): ${SIZE} bytes"
fi
echo "  Build log : ${SRCDIR}/build.log"
