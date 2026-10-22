#!/usr/bin/env python3
"""Exile sprite data converter: BBC Micro mode 1 (2 bpp) -> Atari mode 4 / GR.15 format.

Python rewrite of sprites_convert.php.

Input
    Raw binary, no header. Default: sprite_test_bbc_mode1_128x81.bin
    128 px wide (32 bytes per line) and 81 lines, BBC pixel bit order.

Step 1, bit swap (same as the PHP):
    BBC mode 1 packs a byte as four pixels, each with its two bits split:
        pixel0 = bits 7,3   pixel1 = bits 6,2   pixel2 = bits 5,1   pixel3 = bits 4,0
    Atari puts each pixel's two bits side by side:
        pixel0 = bits 7,6   pixel1 = bits 5,4   pixel2 = bits 3,2   pixel3 = bits 1,0
    Taking the bits in the order [7,3,6,2,5,1,4,0] does this.

Step 2, input layout (--input-layout)
    linear      (default) bytes are already 32 per line. This is what
                sprite_test_bbc_mode1_128x81.bin contains (checked against
                sprite_test.png).
    bbc-cells   the BBC stores 8-byte cells (4 px wide x 8 lines), 32 cells
                per cell row = 256 bytes. The cells are rearranged into lines.

Step 3, output layout (--output-layout)
    columns     (default) 80 bytes per 4 px column: column c holds lines 0..79
                of that column. 4x8 chunks are 8 consecutive bytes, 10 chunks
                per column, columns follow each other.
    lines       32 bytes per line, line after line (GR.15 order).

Step 4, output format (--format)
    bin         raw binary.
    mads        MADS source with `dta`, 16 bytes per line:
                    \tdta $00,$01,$02,...

Default output name: sprite_test_atari_columns_128x80.bin (or .asm for mads).

Usage:
    python sprites_convert.py [input] [output]
        [--lines 80] [--input-layout linear|bbc-cells]
        [--output-layout columns|lines] [--format bin|mads]
"""
import argparse
import os
import sys

DEFAULT_INPUT = "sprite_test_bbc_mode1_128x81.bin"
DEFAULT_OUTPUT_STEM = "sprite_test_atari_columns_128x80"

# Output bit i (from MSB = bit 7 down) takes input bit SRC_BIT[i] (bit 7 = MSB).
SRC_BIT = [7, 3, 6, 2, 5, 1, 4, 0]

CELL_BYTES = 8        # 8 lines per 4x8 cell
BYTES_PER_LINE = 32   # 128 px at 4 px per byte
CELLS_PER_ROW = 32    # 32 cells x 4 px = 128 px
CELL_ROW_BYTES = CELL_BYTES * CELLS_PER_ROW   # 256 bytes = 8 lines
MADS_BYTES_PER_LINE = 16


def swap_byte(b):
    out = 0
    for i, src in enumerate(SRC_BIT):
        if (b >> src) & 1:
            out |= 1 << (7 - i)
    return out


def swap_bits(data):
    table = [swap_byte(b) for b in range(256)]
    return bytes(table[b] for b in data)


def bbc_cells_to_lines(data, lines):
    """Rearrange BBC cell order (cell rows of 32 cells x 8 bytes) into 32-byte lines."""
    cell_rows = lines // CELL_BYTES
    out = bytearray(lines * BYTES_PER_LINE)
    for row in range(cell_rows):
        for col in range(CELLS_PER_ROW):
            for k in range(CELL_BYTES):
                src = row * CELL_ROW_BYTES + col * CELL_BYTES + k
                dst = (row * CELL_BYTES + k) * BYTES_PER_LINE + col
                out[dst] = data[src]
    return bytes(out)


def lines_to_columns(lines_data, lines):
    """Transpose 32-byte lines into 4 px columns of `lines` bytes each."""
    out = bytearray(lines * BYTES_PER_LINE)
    for y in range(lines):
        for c in range(BYTES_PER_LINE):
            out[c * lines + y] = lines_data[y * BYTES_PER_LINE + c]
    return bytes(out)


def format_mads(data, label):
    """MADS source: one `dta` line per 16 bytes, values as $hh."""
    out = ["; %s" % label, "; %d bytes" % len(data)]
    for i in range(0, len(data), MADS_BYTES_PER_LINE):
        chunk = data[i:i + MADS_BYTES_PER_LINE]
        out.append("\tdta " + ",".join("$%02X" % b for b in chunk))
    return ("\n".join(out) + "\n").encode("ascii")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", nargs="?", default=DEFAULT_INPUT)
    ap.add_argument("output", nargs="?",
                    help="default: %s.bin or .asm depending on --format" % DEFAULT_OUTPUT_STEM)
    ap.add_argument("--lines", type=int, default=80, help="output height in lines (default 80)")
    ap.add_argument("--input-layout", choices=["linear", "bbc-cells"], default="linear")
    ap.add_argument("--output-layout", choices=["columns", "lines"], default="columns")
    ap.add_argument("--format", choices=["bin", "mads"], default="bin")
    args = ap.parse_args()

    if not os.path.isfile(args.input):
        sys.exit("Can't open file %s." % args.input)
    output = args.output or DEFAULT_OUTPUT_STEM + (".asm" if args.format == "mads" else ".bin")

    with open(args.input, "rb") as f:
        data = f.read()

    swapped = swap_bits(data)

    if args.input_layout == "bbc-cells":
        need = (args.lines // CELL_BYTES) * CELL_ROW_BYTES
        if len(swapped) < need:
            sys.exit("Input has %d bytes, %d lines need %d." % (len(swapped), args.lines, need))
        if len(swapped) > need:
            print("note: %d trailing bytes ignored" % (len(swapped) - need))
        lines = bbc_cells_to_lines(swapped, args.lines)
    else:
        need = args.lines * BYTES_PER_LINE
        if len(swapped) < need:
            sys.exit("Input has %d bytes, %d lines need %d." % (len(swapped), args.lines, need))
        if len(swapped) > need:
            print("note: %d trailing bytes ignored (%d lines of input)"
                  % (len(swapped) - need, len(swapped) // BYTES_PER_LINE))
        lines = swapped[:need]

    if args.output_layout == "columns":
        result = lines_to_columns(lines, args.lines)
        desc = "%d bytes per column" % args.lines
    else:
        result = lines
        desc = "%d bytes per line" % BYTES_PER_LINE

    if args.format == "mads":
        result = format_mads(result, os.path.basename(output))

    with open(output, "wb") as f:
        f.write(result)
    print("wrote %d bytes (%s, %s, %s) to %s" %
          (len(result), args.output_layout, desc, args.format, output))


if __name__ == "__main__":
    main()
