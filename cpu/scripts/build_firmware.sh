#!/usr/bin/env bash

set -u

PROGRAM="${1:-game}"
TOOLCHAIN="${RISCV_TOOLCHAIN:-/opt/AMD/2026.1/gnu/riscv/lin/bin}"
PREFIX="${TOOLCHAIN}/riscv64-unknown-elf-"

cd "$(dirname "$0")/.."

mkdir -p build/firmware

"${PREFIX}as" \
    -march=rv32i \
    -mabi=ilp32 \
    -o "build/firmware/${PROGRAM}.o" \
    "firmware/${PROGRAM}.S" || exit 1

"${PREFIX}ld" \
    -m elf32lriscv \
    --no-relax \
    -T firmware/link.ld \
    -o "build/firmware/${PROGRAM}.elf" \
    "build/firmware/${PROGRAM}.o" || exit 1

"${PREFIX}objcopy" \
    -O binary \
    "build/firmware/${PROGRAM}.elf" \
    "build/firmware/${PROGRAM}.bin" || exit 1

SIZE=$(stat -c%s "build/firmware/${PROGRAM}.bin")

if [ "$SIZE" -gt 8192 ]; then
    echo "ERROR: programa de ${SIZE} bytes excede ROM de 8192 bytes"
    exit 1
fi

if [ $((SIZE % 4)) -ne 0 ]; then
    echo "ERROR: imagen ROM no alineada a 32 bits"
    exit 1
fi

python3 - "$PROGRAM" <<'PY'
from pathlib import Path
import struct
import sys

program = sys.argv[1]

data = Path(f"build/firmware/{program}.bin").read_bytes()
words = []

for i in range(0, len(data), 4):
    words.append(f"{struct.unpack_from('<I', data, i)[0]:08x}")

while len(words) < 2048:
    words.append("00000013")

Path(f"firmware/{program}.hex").write_text(
    "\n".join(words) + "\n",
    encoding="ascii"
)
PY

"${PREFIX}objdump" \
    -d -M no-aliases \
    "build/firmware/${PROGRAM}.elf" \
    > "build/firmware/${PROGRAM}.dis" || exit 1

echo "ROM generada: ${SIZE} bytes de programa, capacidad 8192 bytes"
echo "firmware/${PROGRAM}.hex"
