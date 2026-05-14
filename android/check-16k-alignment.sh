#!/usr/bin/env bash
# Verifies that every native (.so) library inside a built Android App Bundle
# or APK is aligned for 16 KB memory page sizes — the requirement Google Play
# enforces from 31 May 2026 for any app update targeting Android 15+.
#
# What it checks (per .so file):
#   1. The first PT_LOAD segment's `align` (objdump -p) is >= 0x4000 (16 KB).
#   2. The file is stored uncompressed inside the zip (CRC method 0).
#
# Usage:
#   ./android/check-16k-alignment.sh build/app/outputs/bundle/release/app-release.aab
#   ./android/check-16k-alignment.sh build/app/outputs/flutter-apk/app-release.apk
#
# Exit code is non-zero on any failure so this can drop into CI gates.
set -euo pipefail

BUNDLE="${1:-}"
if [[ -z "${BUNDLE}" || ! -f "${BUNDLE}" ]]; then
  echo "Usage: $0 <path-to-app-release.aab|.apk>" >&2
  exit 2
fi

# Locate objdump — prefer the one shipped by Android NDK (handles arm64 + x86
# without extra setup). Fall back to system `objdump` / `llvm-objdump`.
find_objdump() {
  if command -v llvm-objdump >/dev/null 2>&1; then
    echo "llvm-objdump"; return
  fi
  # Best-effort NDK lookup using flutter's reported NDK path.
  local ndk_root=""
  if command -v flutter >/dev/null 2>&1; then
    ndk_root="$(flutter --version --machine 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('flutterRoot',''))" 2>/dev/null || true)"
  fi
  local candidates=(
    "${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objdump"
    "${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
    "${ANDROID_HOME:-}/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objdump"
    "${ANDROID_HOME:-}/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
    "${HOME}/Library/Android/sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objdump"
    "${HOME}/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
  )
  for c in "${candidates[@]}"; do
    if [[ -x "${c}" ]]; then echo "${c}"; return; fi
  done
  echo "objdump"
}
OBJDUMP="$(find_objdump)"

if ! "${OBJDUMP}" --help 2>&1 | grep -q 'private-headers\|--private-headers\|-p '; then
  echo "warn: ${OBJDUMP} does not look like llvm-objdump; alignment parsing may break" >&2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "==> Extracting native libraries from ${BUNDLE}"
# AAB layout: base/lib/<abi>/*.so + module splits.
# APK layout: lib/<abi>/*.so.
# Use python to extract since it's available everywhere and preserves names.
python3 - "${BUNDLE}" "${TMP}" <<'PY'
import sys, zipfile, os
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        if not info.filename.endswith(".so"):
            continue
        if "/lib/" not in info.filename:
            continue
        dest = os.path.join(out, info.filename)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with z.open(info) as src_f, open(dest, "wb") as dst_f:
            dst_f.write(src_f.read())
        # Record whether this entry was stored compressed.
        method = "deflated" if info.compress_type == zipfile.ZIP_DEFLATED else "stored"
        print(f"{info.filename}\t{method}", flush=True)
PY

# Use a while-read loop instead of `mapfile` so this script also runs on
# macOS's stock bash 3.2 (where `mapfile` is unavailable).
SO_FILES=()
while IFS= read -r line; do
  SO_FILES+=("${line}")
done < <(find "${TMP}" -name "*.so" | sort)
if [[ "${#SO_FILES[@]}" -eq 0 ]]; then
  echo "ok: no native libraries found (pure-Dart build)"
  exit 0
fi

fail=0
echo
printf "%-72s %-10s %s\n" "library" "align" "result"
printf -- "------------------------------------------------------------------------ ---------- ------\n"
for so in "${SO_FILES[@]}"; do
  rel="${so#${TMP}/}"
  # Play's 16 KB requirement only applies to 64-bit ABIs. 32-bit Android
  # kernels (armeabi-v7a, x86) still use 4 KB pages, so mis-aligned 32-bit
  # libraries are downgraded from FAIL to SKIP and don't fail the build.
  is_64bit=true
  case "${rel}" in
    *"/armeabi-v7a/"*|*"/x86/"*) is_64bit=false ;;
  esac
  # First LOAD segment's `align` column from llvm-objdump -p output.
  align_hex="$( "${OBJDUMP}" -p "${so}" 2>/dev/null \
    | awk '/^[[:space:]]*LOAD/ {print $NF; exit}' )"
  if [[ -z "${align_hex}" ]]; then
    printf "%-72s %-10s %s\n" "${rel}" "?" "FAIL (unreadable)"
    fail=1
    continue
  fi
  # Normalize values like "2**14" or "16384" or "0x4000" to a decimal. Use
  # bash regex (BASH_REMATCH) instead of `${var#pattern}` because the latter
  # treats `*` as a glob wildcard and silently misparses "2**N" tokens.
  if [[ "${align_hex}" =~ ^2\*\*([0-9]+)$ ]]; then
    align_dec=$(( 1 << ${BASH_REMATCH[1]} ))
  elif [[ "${align_hex}" =~ ^0x([0-9a-fA-F]+)$ ]]; then
    align_dec=$(( 16#${BASH_REMATCH[1]} ))
  elif [[ "${align_hex}" =~ ^[0-9]+$ ]]; then
    align_dec="${align_hex}"
  else
    printf "%-72s %-10s %s\n" "${rel}" "${align_hex}" "FAIL (unparseable)"
    fail=1
    continue
  fi
  if [[ "${align_dec}" -ge 16384 ]]; then
    printf "%-72s %-10s %s\n" "${rel}" "${align_dec}" "OK"
  elif [[ "${is_64bit}" == "false" ]]; then
    printf "%-72s %-10s %s\n" "${rel}" "${align_dec}" "SKIP (32-bit ABI, 16 KB N/A)"
  else
    printf "%-72s %-10s %s\n" "${rel}" "${align_dec}" "FAIL (need >= 16384)"
    fail=1
  fi
done

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "All native libraries are 16 KB-aligned. Safe to upload to Google Play."
  exit 0
fi
echo "One or more libraries are NOT 16 KB-aligned. Most common fixes:"
echo "  - Rebuild on Flutter 3.27+ with NDK r27+ (this project pins r28)."
echo "  - Upgrade the plugin that owns the offending .so (often Firebase BoM,"
echo "    mobile_scanner, or any prebuilt-binary plugin)."
echo "  - Confirm android.bundle.enableUncompressedNativeLibs=true is set."
exit 1
