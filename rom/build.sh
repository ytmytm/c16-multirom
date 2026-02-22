#!/usr/bin/env bash
# Build 64K U3 (system) and U4 (function) ROMs for C16/Plus4 multirom.
# Run with no args for interactive mode; otherwise --pal/--ntsc and --kernal-lower/--kernal-upper (or --kernal for both).
# Downloads default ROMs (Zimmers, Parobek) once into sources/.
#
# Layout (A15 selects lower/upper 32K half of each ROM):
#
#   U3 (system ROM) - 64K:
#     Lower half (A15=0):  $0000-$3FFF BASIC (16K)  +  $4000-$7FFF KERNAL (16K)  <- choose one
#     Upper half (A15=1):  $8000-$BFFF BASIC (16K)  +  $C000-$FFFF KERNAL (16K)  <- choose another
#     BASIC is the same in both halves; kernal can differ (e.g. stock lower, JiffyDOS upper).
#
#   U4 (function ROM) - 64K:
#     Lower half (A15=0):  $0000-$7FFF 3-plus-1 (32K, stock)
#     Upper half (A15=1):  $8000-$FFFF Parobek (32K)
#     Jumper/ATtiny A15: closed = lower (3-plus-1), open = upper (Parobek).
#
set -e
ROM_SIZE=65536
SIZE_16K=16384
SIZE_32K=32768

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$SCRIPT_DIR/sources"
Zimmers="$SOURCES/zimmers"
Parobek="$SOURCES/parobek"
Kernals6510="$SOURCES/6510"
Jiffydos="$SOURCES/jiffydos"
OUT="$SCRIPT_DIR/out"

# Default URLs (download once)
URL_BASIC="https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/basic.318006-01.bin"
URL_KERNAL_PAL="https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/kernal.318004-05.bin"
URL_KERNAL_NTSC="https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/kernal.318005-05.bin"
URL_3PLUS1_LOW="https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/3-plus-1.317053-01.bin"
URL_3PLUS1_HIGH="https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/3-plus-1.317054-01.bin"
URL_PAROBEK_ZIP="https://github.com/ytmytm/plus4-parobek/releases/download/release-v1.1/parobek-via.zip"
URL_6510_ZIP="https://hackjunk.com/wp-content/uploads/2019/05/6510-kernals-c16-1.zip"

download_if_missing() {
  local url="$1"
  local outpath="$2"
  if [[ -f "$outpath" ]]; then
    return 0
  fi
  echo "Downloading: $url"
  mkdir -p "$(dirname "$outpath")"
  if command -v curl &>/dev/null; then
    curl -fSL -o "$outpath" "$url"
  else
    wget -q -O "$outpath" "$url"
  fi
}

ensure_parobek_rom() {
  local zip_path="$Parobek/parobek-via.zip"
  local rom_path="$Parobek/parobek.bin"
  if [[ -f "$rom_path" ]]; then
    return 0
  fi
  download_if_missing "$URL_PAROBEK_ZIP" "$zip_path"
  echo "Extracting Parobek ROM from zip..."
  (cd "$Parobek" && unzip -o -j parobek-via.zip '*.bin' '*.rom' 2>/dev/null || unzip -o -j parobek-via.zip)
  # Use first extracted .bin or .rom as 32K function ROM
  for f in "$Parobek"/*.bin "$Parobek"/*.rom; do
    [[ -e "$f" ]] || continue
    if [[ "$(basename "$f")" != "parobek-via.zip" ]]; then
      local size
      size="$(wc -c < "$f")"
      if [[ "$size" -ge "$SIZE_32K" ]]; then
        head -c "$SIZE_32K" "$f" > "$rom_path"
        echo "Using $(basename "$f") as Parobek ROM (32K)."
        return 0
      fi
    fi
  done
  echo "Error: no suitable ROM found in parobek-via.zip" >&2
  exit 1
}

ensure_6510_kernals() {
  local zip_path="$Kernals6510/6510-kernals-c16-1.zip"
  local pal_path="$Kernals6510/kernal-6510-pal.bin"
  local ntsc_path="$Kernals6510/kernal-6510-ntsc.bin"
  if [[ -f "$pal_path" && -f "$ntsc_path" ]]; then
    return 0
  fi
  download_if_missing "$URL_6510_ZIP" "$zip_path"
  echo "Extracting 6510 kernals from zip..."
  mkdir -p "$Kernals6510"
  (cd "$Kernals6510" && unzip -o -j 6510-kernals-c16-1.zip)
  for f in "$Kernals6510"/*.bin; do
    [[ -e "$f" ]] || continue
    local name; name="$(basename "$f")"
    if [[ "$name" == *[pP][aA][lL]* ]]; then
      cp "$f" "$pal_path"
    elif [[ "$name" == *[nN][tT][sS][cC]* ]]; then
      cp "$f" "$ntsc_path"
    fi
  done
  if [[ ! -f "$pal_path" || ! -f "$ntsc_path" ]]; then
    echo "Error: could not find PAL and NTSC 6510 kernals in zip" >&2
    exit 1
  fi
}

pad_to() {
  local file="$1"
  local size="$2"
  local current
  current="$(wc -c < "$file")"
  if [[ "$current" -lt "$size" ]]; then
    local pad=$(( size - current ))
    dd bs=1 count="$pad" if=/dev/zero 2>/dev/null | tr '\0' '\377' >> "$file"
  fi
}

build_64k_rom() {
  local outfile="$1"
  shift
  mkdir -p "$(dirname "$outfile")"
  # Concat pieces, take first ROM_SIZE bytes (dd for exact truncation), then pad if needed
  cat "$@" 2>/dev/null | dd of="$outfile.tmp" bs=1 count="$ROM_SIZE" 2>/dev/null
  pad_to "$outfile.tmp" "$ROM_SIZE"
  mv "$outfile.tmp" "$outfile"
  echo "Built $(basename "$outfile") ($(wc -c < "$outfile") bytes)"
}

# Parse optional args (no args => interactive later)
PAL=1
KERNAL_LOWER="stock"
KERNAL_UPPER="jiffydos"
HAD_ARGS=0
while [[ $# -gt 0 ]]; do
  HAD_ARGS=1
  case "$1" in
    --pal)   PAL=1; shift ;;
    --ntsc)  PAL=0; shift ;;
    --kernal=*)   KERNAL_LOWER="${1#--kernal=}"; KERNAL_UPPER="${1#--kernal=}"; shift ;;
    --kernal-lower=*) KERNAL_LOWER="${1#--kernal-lower=}"; shift ;;
    --kernal-upper=*) KERNAL_UPPER="${1#--kernal-upper=}"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$HAD_ARGS" -eq 0 ]]; then
  echo "Interactive mode (use --pal/--ntsc --kernal-lower=... --kernal-upper=... to skip)."
  echo ""
  echo "TV standard:"
  echo "  1) PAL (default)"
  echo "  2) NTSC"
  read -r -p "Choice [1]: " tv
  tv="${tv:-1}"
  if [[ "$tv" == "2" ]]; then PAL=0; else PAL=1; fi

  echo ""
  echo "Kernal for U3 lower half (A15=0), e.g. stock:"
  echo "  1) Stock (PAL/NTSC from Zimmers, default)"
  echo "  2) JiffyDOS (sources/jiffydos/)"
  echo "  3) 6510-patched (downloaded from hackjunk.com)"
  read -r -p "Choice [1]: " k
  k="${k:-1}"
  case "$k" in
    2) KERNAL_LOWER="jiffydos" ;;
    3) KERNAL_LOWER="6510" ;;
    *) KERNAL_LOWER="stock" ;;
  esac

  echo ""
  echo "Kernal for U3 upper half (A15=1), e.g. JiffyDOS:"
  echo "  1) Stock (PAL/NTSC from Zimmers)"
  echo "  2) JiffyDOS (sources/jiffydos/, default)"
  echo "  3) 6510-patched (downloaded from hackjunk.com)"
  read -r -p "Choice [2]: " k
  k="${k:-2}"
  case "$k" in
    1) KERNAL_UPPER="stock" ;;
    3) KERNAL_UPPER="6510" ;;
    *) KERNAL_UPPER="jiffydos" ;;
  esac
fi

# Resolve kernal type to file path (uses global PAL)
resolve_kernal() {
  local k="$1"
  case "$k" in
    stock)
      if [[ "$PAL" -eq 1 ]]; then
        download_if_missing "$URL_KERNAL_PAL" "$Zimmers/kernal.318004-05.bin"
        echo "$Zimmers/kernal.318004-05.bin"
      else
        download_if_missing "$URL_KERNAL_NTSC" "$Zimmers/kernal.318005-05.bin"
        echo "$Zimmers/kernal.318005-05.bin"
      fi
      ;;
    jiffydos)
      local jpal="" jntsc=""
      for f in "$Jiffydos"/*.bin; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f")"
        [[ "$name" == *[pP][aA][lL]* ]] && jpal="$f"
        [[ "$name" == *[nN][tT][sS][cC]* ]] && jntsc="$f"
      done
      if [[ "$PAL" -eq 1 ]]; then echo "$jpal"; else echo "$jntsc"; fi
      ;;
    6510)
      ensure_6510_kernals
      if [[ "$PAL" -eq 1 ]]; then echo "$Kernals6510/kernal-6510-pal.bin"; else echo "$Kernals6510/kernal-6510-ntsc.bin"; fi
      ;;
    *)
      echo "" ;;
  esac
}

KERNAL_FILE_LOWER="$(resolve_kernal "$KERNAL_LOWER")"
KERNAL_FILE_UPPER="$(resolve_kernal "$KERNAL_UPPER")"

if [[ -z "$KERNAL_FILE_LOWER" ]]; then
  echo "No kernal file for lower half (KERNAL_LOWER=$KERNAL_LOWER). For JiffyDOS add .bin with PAL/NTSC in name to sources/jiffydos/." >&2
  exit 1
fi
if [[ -z "$KERNAL_FILE_UPPER" ]]; then
  echo "No kernal file for upper half (KERNAL_UPPER=$KERNAL_UPPER). For JiffyDOS add .bin with PAL/NTSC in name to sources/jiffydos/." >&2
  exit 1
fi
if [[ ! -f "$KERNAL_FILE_LOWER" ]]; then
  echo "Missing kernal file: $KERNAL_FILE_LOWER" >&2
  exit 1
fi
if [[ ! -f "$KERNAL_FILE_UPPER" ]]; then
  echo "Missing kernal file: $KERNAL_FILE_UPPER" >&2
  exit 1
fi

# Download all default sources we need
download_if_missing "$URL_BASIC" "$Zimmers/basic.318006-01.bin"
download_if_missing "$URL_3PLUS1_LOW" "$Zimmers/3-plus-1.317053-01.bin"
download_if_missing "$URL_3PLUS1_HIGH" "$Zimmers/3-plus-1.317054-01.bin"
ensure_parobek_rom

# BASIC: if 32K use low/high 16K; if 16K use same for both halves
BASIC_FULL="$Zimmers/basic.318006-01.bin"
BASIC_LOW="$OUT/.basic-low.bin"
BASIC_HIGH="$OUT/.basic-high.bin"
BASIC_SZ="$(wc -c < "$BASIC_FULL")"
head -c "$SIZE_16K" "$BASIC_FULL" > "$BASIC_LOW"
if [[ "$BASIC_SZ" -ge "$(( SIZE_16K * 2 ))" ]]; then
  tail -c "+$(( SIZE_16K + 1 ))" "$BASIC_FULL" | head -c "$SIZE_16K" > "$BASIC_HIGH"
else
  cp "$BASIC_LOW" "$BASIC_HIGH"
fi

# U3: basic-low (16K) + kernal lower (16K) + basic-high (16K) + kernal upper (16K)
build_64k_rom "$OUT/u3-system.rom" "$BASIC_LOW" "$KERNAL_FILE_LOWER" "$BASIC_HIGH" "$KERNAL_FILE_UPPER"
echo "  U3 lower (A15=0): BASIC + $KERNAL_LOWER"
echo "  U3 upper (A15=1): BASIC + $KERNAL_UPPER"

# U4: 3+1 low (16K) + 3+1 high (16K) + parobek (32K)
PAROBEK_ROM="$Parobek/parobek.bin"
build_64k_rom "$OUT/u4-function.rom" \
  "$Zimmers/3-plus-1.317053-01.bin" \
  "$Zimmers/3-plus-1.317054-01.bin" \
  "$PAROBEK_ROM"
echo "  U4 lower (A15=0): 3-plus-1 (32K)"
echo "  U4 upper (A15=1): Parobek (32K)"

echo "Done. ROMs in $OUT/"
