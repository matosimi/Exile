# Exile Atari port: renderer notes

Working notes on the native (Atari) background renderer, what has been verified
against the BBC original, and what is still open. Written from the session on
2026-10-23/24. Items marked **verified** were checked against data or a
screenshot; items marked **unverified** are inferences.

## 1. Goal and approach

- Port of the BBC Micro game Exile to Atari XL/XE, MADS assembler, `Exile.asm`.
- Original approach emulated BBC VRAM and converted it to Atari charsets every
  frame. Too slow (about 100k instructions per frame).
- Current approach: draw background squares directly into Atari mode 4 charsets
  from the BBC sprite data (the "tile renderer", `bg_tiles_test`).
- Target for comparison: `images/8.png` (BBC renderer output converted to Atari
  palette, same Altirra framing as our screenshots).

## 2. Screen and Altirra framing (verified)

- Mode 4 narrow playfield: 32 cells x 4 px = 128 px wide, 192 lines tall.
- Altirra shows the playfield at 2x horizontally, 1x vertically, inside a
  border. Measured: horizontal offset 40 px, vertical offset 16 lines.
- A square (BBC) is 4 Atari byte-columns wide (16 px) and 32 lines tall.
  In Altirra: square `(i, j)` starts at x = 40 + 32*i, y = 16 + 32*j.
- Charset layout: band = row>>2, page = `m4_charset_pages[band] + (row&3)`,
  byte = page*256 + col*8 + (Y&7); pixel order: left pixel in bits 7-6.
- 2bpp pixel values: 0 = background (treated as transparent by the tile
  writer), 1-3 = colour registers.

## 3. Sprite sheet (verified)

- Raw BBC sheet: `exile_sprite_data_raw_bitmap.xex`, 2592 bytes = 81 rows x 32
  bytes (BBC mode 1, 4 px per byte, pixels split across bits).
- Converted sheet: `sprite_sheet_atari_columns_128x81.bin`, 2592 bytes =
  32 columns x 81 bytes. Verified column by column against the raw sheet.
  Every column is 81 bytes: stride 81 is correct.
- Bit swap for the Atari 2bpp pixel order: `SRC_BIT = [7,3,6,2,5,1,4,0]`
  (`sprites_convert.py`).
- `sprite_colbase` (old blitter, stride was 80) was corrected to 81. The old
  blitter is only reached from `sprite_init` (startup) and does not affect the
  output, because the main loop clears the charsets every frame.

## 4. Sprite tables (verified and corrected)

Tables are read from the built `Exile.xex`, using label + `$1100` (the file
offset for these data tables; the labels alone read as zeros).

| table | meaning (current reading) |
|---|---|
| `sprite_offset_a_lookup[s]` | `a`: column = `rbo(a) & $1F`, `rbo` = ASL,ADC#0,ASL,ADC#0 (verified against the tile code) |
| `sprite_offset_a_lookup[s] >> 4 & 3` | pixel phase, pixels into the first byte (plotter bits 4-5 of `a`; mirrored for H-flipped sprites) |
| `sprite_offset_b_lookup[s]` | packed `b` is combined with height when unflipped, then rotate-left-through-carry twice to form the source pointer |
| `sprite_width_lookup[s]` | width in px = `w >> 4` (`$F0` = 15 px) |
| `sprite_height_lookup[s]` | height in lines = `(h >> 3) + 1`; native `tt_draw` increments the encoded inclusive count |

Important corrections made during this session:

- **Source row uses the plotter pointer transform:** choose `b` for V-flipped
  sprites or `b + (height & $F8)` otherwise, preserve the addition carry, then
  rotate left through carry twice. `tt_draw` decodes that byte address into a
  row index for the 81-byte column-major sheet.
- **Column count** includes the encoded inclusive width and effective phase;
  pixels beyond the final sprite pixel are masked in the last destination byte.
  Without that mask, sprite 5 (`w = $50`, six pixels inclusive) was drawn as
  eight pixels, causing native sprites to spill horizontally into padding.

## 5. Flips (verified against the plotter, not yet against the screen)

- Orientation byte `square_orientation`: bit 7 = horizontal flip, bit 6 =
  vertical flip (plotter code `BPL` on bit 7, `BVC` on bit 6, lines ~2371,
  6133-6147).
- Palette selection is per square via `background_palette_lookup` plus the
  original Y/orientation-dependent rules. The native renderer now derives the
  four source-color mappings from `this_object_palette` and
  `palette_value_to_pixel_lookup`, whose pair colors are interleaved BBC Mode 2
  bitplanes (not high/low nibbles), then remaps each packed pixel pair before
  writing mode 4. Transparency is determined from the original source pixels,
  so a visible color mapped to index 0 remains opaque.
- There is no per-sprite palette swap. The plotter's `$01<->$02`,
  `$10<->$20`, `$11<->$22` swap only reorders the left/right pixel within a
  Mode 2 byte when the sprite is drawn at an odd pixel phase; the colors stay
  the same. `vram_convert` maps each BBC pixel to `colour & 3`, so the native
  renderer must not swap colors 1 and 2. The earlier swap blocks in `tt_draw`
  were removed (verified by frozen-frame comparison with the reference).
- Native flip selection combines sprite width/height low bits with
  `square_orientation`, matching the plotter's unshifted drawing flags. The
  plotter shifts a temporary copy for clipping, then reloads the unshifted
  flags before drawing pixels. Source-order corrections still need visual
  confirmation against the reference capture.
- Native source-row addressing uses the BBC packed-pointer calculation,
  including the carry from `b + height`. Effective V-flag conditions for
  selecting the start row and traversal direction remain experimental; using
  the plotter-derived conditions visibly flipped the native sprites.

## 6. Background squares and objects (verified structure)

- `determine_background` (line ~4044) returns a value `v`. Plain squares: the
  sprite is `background_sprite_lookup[v] & $7F`. Empty square = `$19` (skipped).
- Three paths, recorded in `FLAG_TABLE` (see section 8):
  0 plain, 1 hash hit (background object such as a door; returns the object's
  handler value, not a background index), 2 object number without a hash entry.
- In the current capture, 5 squares are flag 1 and none are flag 2. On this
  path `calculate_background` returns a special object code (0-8), not the
  resolved lookup value. `bg_tiles_test` now preserves the post-handler result
  and orientation from `determine_background`, matching the original plotter.
  The prior raw-value fallback made several squares select generic `$46/$4E`
  sprites; native object behavior still needs visual testing.
- Doors/gates: `determine_background` calls a background object's handler
  only when `object_handler_table_h[sprite] AND background_processing_flag`
  is nonzero. `handle_background_door` then replaces the square with
  `door_square_sprite_lookup` (`$17`/`$2A` solid wall, `$19` empty), which is
  the collision shape, not a visual. The BBC strip plotter sets the flag to
  `call_object_handlers_when_redrawing_screen & $80` (normally 0), so a door
  square keeps value 3 -> sprite `$46` (1x1 placeholder) and only the door
  object draws the gate. `bg_tiles_test` therefore forces the flag to 0
  around `determine_background` (the stale `$10/$20/$40` left by water and
  collision code drew solid bricks and re-ran door handlers every frame).
- `background_y_offset_lookup[v] & $F0`: vertical position of the sprite in the
  square. Native placement now converts the original plotter's bottom/end
  scanline (`this_object_y_low + sprite_height`) into a top-down start line by
  subtracting `sprite_height >> 3`. `tt_draw` increments the encoded height
  before drawing, so the endpoint difference already accounts for the
  inclusive line. This needs capture verification, especially where adjacent
  terrain sprites should meet.

## 7. Window and origin (verified by experiment)

- The window is squares `i = -1..8`, `j = -1..5` around `screen_start_square`,
  with the sub-square offsets `screen_start_square_x/y_low_tiles`.
- Origin shifted one square left or right: both made the overlap with the
  target worse (1,728 and 2,458 px against 4,352). The original origin is right.
- Extending the loops to `i = -1..8`, `j = -1..5` changed nothing visible.
- Wrap-around: destination lines and columns are 8-bit; the clip checks
  (`CMP #192`, `CMP #32`) handle negative starts correctly.

## 8. Debug instrumentation (temporary, remove before finishing)

- `DUMP_TABLE = $BA90`: 70 bytes, selected sprite ID per window square
  (`(j+1)*10 + (i+1)` index), `$FF` = empty or skipped. This is the masked
  `background_sprite_lookup` result used to read the atlas.
- `DUMP_DONE = $BAD6`: 1 when a pass has completed.
- `FLAG_TABLE = $BC00`: 70 bytes, path in bits 7-6 and resolved lookup value
  in bits 5-0; `$FF` means unvisited. Decode with `path = value >> 6` and
  `lookup = value & $3F`. For path 1, this is the post-handler return value;
  in test-map mode, it is the synthetic map index.
- `DBG_OBJFLAG = $BF2A`: set in `determine_background`.
- Lines marked `DEBUG:` / `TEST:` in `Exile.asm` should be removed or made
  permanent once the renderer is settled.

## 9. Renderer state (`bg_tiles_test` in `Exile.asm`)

- Clears charsets each frame (`clear_charsets` in `main_loop`), then calls
  `bg_tiles_test`.
- Startup does not call `bg_save`: its 6 KB `$A800-$BFFF` buffer overlaps the
  converted sprite sheet at `$B000`. The old background-copy sprite test has no
  active move/erase callers; the native renderer clears and redraws charsets.
- Per square: lookup sprite, `a`/`b`/width/height, column count (section 4),
  destination column from `i*4 + floor((this_object_x_low - screen_start_square_x_low)/64)`,
  effective pixel phase from the same signed X delta, first line from the
  plotter endpoint conversion, plus the square-indexed Y offset.
- Native test-map mode fills a 10x5 window (square coordinates `i=-1..8`,
  `j=-1..3`) with `((j+1)*10 + (i+1)) & $3F`, starting orientation 0. Mode 2
  runs the BBC setup helper and uses its resolved sprite and final orientation.
  This selects indices 0-49 and matches the BBC converter's 128-line output
  window.
- Reference test-map mode uses the same sequence and square coordinates, but
  calls the original `plot_sprite` into BBC Mode 2 VRAM before `vram_convert`.
- Applies the BBC per-square palette mapping to source colors and keeps source
  color 0 transparent, even when a visible palette color maps to Atari index 0.
- Phase alignment is applied for both orientations. H-flipped sprites use the
  mirrored phase and adjacent source column on the opposite side; this change
  is experimental and needs comparison against the reference.
- Calibration routine `calib_test` draws sprites 0, 1, 36, 39, 43, 52, 68, 98
  in normal, H-flipped, V-flipped rows. Recheck its H-flipped row against the
  reference (`scratchpad/calib_reference.png`) with the experimental polarity.

## 10. Measurements against `images/8.png`

Overlap = lit pixels in both, rows above the blue band (y < 140):

| screenshot | both | only target | only native |
|---|---|---|---|
| 7 (before window/flip work) | 4,352 | 5,418 | 2,090 |
| 10 (origin one square left) | 1,728 | 8,042 | 3,470 |
| 11 (origin one square right) | 2,458 | 7,312 | 4,240 |
| 12 (column count fix) | 6,446 | 3,324 | 2,542 |
| 13 (phase shift) | 6,446 | 3,324 | 2,410 |

Per square, native coverage is about 50-80% of the target. Row 0 and the
left-edge squares are weakest; some squares are over-covered.

The bottom two rows of the target (j = 4, 5) are fully lit: a blue striped band
in the converter output, not made of squares. Ignored in the comparison.

## 11. Open questions

1. Gaps between tiles: the plotter draws `h >> 3` lines, so a 31-line sprite
   leaves its last line empty. Whether the BBC output has the same gap depends
   on the vertical offset; not checked.
2. Determine H-flip polarity with one known flipped square; current polarity is
  chosen by visual proximity, not by the plotter's apparent bit contract.
3. Vertical flip start line and `background_y_offset` units: not confirmed.
4. Pixel phase for flipped sprites: not implemented.
5. Palette (`$9C` / `$CF`): colour only; out of scope for shapes.
6. Row 0 and left edge squares: coverage is low; check whether those squares
   are plain or object squares via `FLAG_TABLE`.

## 12. How to test

- Build the stable BBC-reference default with `build.cmd` (MADS, in the project
  folder). Native mode 1 remains available as an experimental game map.
- `BG_RENDERER_MODE=0` selects the BBC-VRAM game reference (default), `1`
  selects the native game map, `2` selects the native synthetic map, and `3`
  selects the same synthetic map through the BBC plotter and converter. Mode 3
  brackets the pass with `change_display_mode`, matching the normal background
  strip's overwrite behavior; `plot_sprite` applies
  `palette_value_to_pixel_lookup` during that pass.
- Ready-to-capture paired test builds: `Exile-reference-maptest.xex` (mode 3)
  and `Exile-maptest.xex` (mode 2). Capture both from the same start state,
  then combine with
  `python compare_renderers.py reference-maptest.png native-maptest.png maptest-comparison.png`.
  The script places reference on the left and native on the right. Optional
  crop syntax is `--crop X,Y,WIDTH,HEIGHT` and applies identically to both.
- The standard synthetic map sets `square_orientation=0`, so it does not test
  flipped Y placement. Build with `-d:BG_FLIP_TEST=1` in both modes 2 and 3 to
  alternate H/V/HV orientation by square coordinates; the matching outputs
  are `Exile-maptest-fliptest.xex` and
  `Exile-reference-maptest-fliptest.xex`.
- Silhouette-only diagnostic: build modes 2 and 3 with
  `-d:BG_SILHOUETTE_TEST=1`. The outputs are `Exile-silhouette-test.xex` and
  `Exile-reference-silhouette-test.xex`. Both map every nontransparent source
  pixel to one visible color while preserving sprite source offsets, phase,
  dimensions, and transparency.
- Single-cell default-palette probe: build modes 2 and 3 with
  `-d:BG_SINGLE_SPRITE_TEST=1 -d:BG_SINGLE_SPRITE_INDEX=9`. The outputs are
  `Exile-native-single-default-9.xex` and
  `Exile-reference-single-default-9.xex`. Tile 9 selects sprite `$70`
  ("sucker") with no intrinsic flip flags.
- Raw BBC-VRAM mask probe: build mode 3 with
  `-d:BG_SINGLE_SPRITE_TEST=1 -d:BG_SINGLE_SPRITE_INDEX=9`
  `-d:BG_RAW_BBC_MASK_TEST=1` to produce
  `Exile-reference-raw-bbc-mask-9.xex`. Compare it with mode 2 built using
  `-d:BG_SINGLE_SPRITE_TEST=1 -d:BG_SINGLE_SPRITE_INDEX=9`
  `-d:BG_SILHOUETTE_TEST=1`, producing `Exile-native-atlas-mask-9.xex`.
  Reference collapses nonzero BBC Mode 2 pixels before the normal VRAM
  converter; a matching mask means the plotter wrote them and the normal
  conversion/palette projection is where pixels disappear.
- Palette-only diagnostic: build modes 2 and 3 with `-d:BG_PALETTE_TEST=1`.
  The outputs are `Exile-palette-test.xex` and
  `Exile-reference-palette-test.xex`. Both repeat sprite 5 with fixed
  position/orientation and primary color, cycling pair palettes `$B0`-`$BF`.
  Sprite 5 contains pixel indices 0-3 and has no intrinsic flips. Override the
  sprite with `-d:BG_PALETTE_TEST_SPRITE=N` to test another atlas entry.
- `Exile-reference.xex` and `Exile.xex` are the separate game-map reference
  and native builds. Capture from the same start state for gameplay comparison.
- Visual check: run `Exile.xex` in Altirra, save the screen as PNG, compare
  with `images/8.png`. Altirra framing per section 2.
- Headless harness (`scratchpad/calib_dump.py`, based on `run4.py`): py65 MPU,
  NMI simulated on `$FFFA`, `SETVBV`/`XITVBV` stubs. Very slow (hundreds of
  millions of steps for one main-loop pass) and not reliable for full-screen
  output. Use Altirra instead.
- Tables for debugging: read `$BA90`, `$BAD6`, `$BC00` in Altirra's memory
  viewer after a run.

## 13. Key files

- `Exile.asm`: game source, renderer, debug tables.
- `sprites_convert.py`: sheet conversion (bit swap, columns).
- `sprite_sheet_atari_columns_128x81.bin`: converted sheet (81 bytes per column).
- `exile_sprite_data_raw_bitmap.xex`: raw BBC sheet (81 x 32 bytes).
- `scratchpad/calib_ref.py`: reference renderer for the calibration sprites.
- `scratchpad/calib_reference.png`: calibration reference image.
- `images/8.png`: target (BBC renderer, converted). `images/13.png`: latest
  Altirra screen with the phase change.
- `dl_mode4_test.asm`, `dl_test.asm`: standalone display-list tests, not part
  of Exile.
