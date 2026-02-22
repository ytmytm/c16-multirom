# Build 64K U3 (system) and U4 (function) ROMs for C16/Plus4 multirom.
# Default target runs the interactive script (downloads once, prompts for PAL/NTSC and kernal).
# Non-interactive: make build-ni KERNAL_LOWER=stock KERNAL_UPPER=jiffydos   or   ./build.sh --kernal-lower=stock --kernal-upper=jiffydos

SHELL := /bin/bash
OUT_DIR := out
ROMS := $(OUT_DIR)/u3-system.rom $(OUT_DIR)/u4-function.rom

.PHONY: all build help clean

all: build

build:
	@./build.sh

# Non-interactive: pass through to script
# e.g. make build-ni KERNAL_LOWER=stock KERNAL_UPPER=jiffydos   or   KERNAL=jiffydos (both halves)
build-ni:
	@args=""; \
	[[ "$(PAL)" == "0" ]] && args="$$args --ntsc" || args="$$args --pal"; \
	[[ -n "$(KERNAL)" ]] && args="$$args --kernal=$(KERNAL)"; \
	[[ -n "$(KERNAL_LOWER)" ]] && args="$$args --kernal-lower=$(KERNAL_LOWER)"; \
	[[ -n "$(KERNAL_UPPER)" ]] && args="$$args --kernal-upper=$(KERNAL_UPPER)"; \
	./build.sh $$args

help:
	@echo "C16/Plus4 multirom ROM builder"
	@echo ""
	@echo "  make          - interactive build (downloads sources once, prompts for options)"
	@echo "  make build    - same as above"
	@echo "  make build-ni - non-interactive: PAL=0 for NTSC, KERNAL_LOWER/KERNAL_UPPER=stock|jiffydos|6510 (or KERNAL for both)"
	@echo "  make clean    - remove built ROMs and temp files"
	@echo ""
	@echo "Sources:  sources/zimmers/ (downloaded), sources/parobek/, sources/6510/ (downloaded), sources/jiffydos/ (you provide)"
	@echo "Output:   out/u3-system.rom, out/u4-function.rom"
	@echo ""
	@echo "JiffyDOS kernals (place in sources/jiffydos/):"
	@echo "  jiffydos-kernal-pal.bin, jiffydos-kernal-ntsc.bin"

clean:
	rm -f $(ROMS) $(OUT_DIR)/.basic-low.bin $(OUT_DIR)/.basic-high.bin
