# TrueType Library Roadmap

> A roadmap to production-ready TrueType/OpenType font parsing and manipulation in Crystal.

## Current Status

The library provides a comprehensive foundation for TrueType/OpenType parsing and table access. Table parsing coverage is broad, but **end-to-end behavior is not yet complete** in shaping, layout, subsetting options, bidi, and validation depth.

**Remaining major features** (Phases 7-9):

- Full GSUB/GPOS lookup application in the default shaping path (non-HarfBuzz)
- Bidirectional text support (UAX #9) for mixed LTR/RTL text
- Full `SubsetOptions` behavior and subset output format conversion
- Full layout option behavior (`align`, `direction`, `line_height`, hyphenation)
- Validation hardening and malformed-font resilience

### What Works Today

| Category              | Features                                                                    | Status                                                   |
| --------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Core Tables**       | `head`, `hhea`, `hmtx`, `maxp`, `cmap`, `name`, `post`, `OS/2`              | Complete                                                 |
| **TrueType Outlines** | `glyf`, `loca` table parsing                                                | Complete                                                 |
| **Character Mapping** | cmap formats 0, 2, 4, 6, 12, 13, 14                                         | Complete                                                 |
| **Font Metrics**      | Units per em, ascender, descender, cap height, bounding box                 | Complete                                                 |
| **Glyph Metrics**     | Advance widths, glyph IDs, character widths                                 | Complete                                                 |
| **Font Info**         | PostScript name, family name, style flags (bold/italic/monospace)           | Complete                                                 |
| **Subsetting**        | TrueType/CFF glyph subsetting core path                                     | Partial (options/output format pending)                  |
| **PDF Support**       | Font descriptor flags, StemV estimation                                     | Complete                                                 |
| **Kerning**           | `kern` table (format 0, 2), GPOS pair-kerning helper                        | Complete                                                 |
| **CFF/OTF**           | CFF table parsing, CharStrings, outline extraction, subsetting              | Complete                                                 |
| **WOFF/WOFF2 Input**  | Header parsing, decompression, sfnt reconstruction                          | Complete                                                 |
| **Font Collections**  | TTC/OTC parsing, multi-font access                                          | Complete                                                 |
| **Glyph Outlines**    | Contour extraction, SVG path export, bounding boxes                         | Complete                                                 |
| **Vertical Metrics**  | `vhea`, `vmtx`, `VORG` tables, vertical writing support                     | Complete                                                 |
| **OpenType Layout**   | `GDEF`, `GSUB`, `GPOS` parsing and feature registry                         | Parsed (application partial)                             |
| **Variable Fonts**    | `fvar`, `gvar`, `avar`, `HVAR`, `VVAR`, `MVAR`, `cvar`, `STAT`              | Complete                                                 |
| **Color Fonts**       | `CPAL`, `COLR` v0/v1, `SVG `, `CBDT`/`CBLC`, `sbix`                         | Complete                                                 |
| **Hinting Tables**    | `cvt `, `fpgm`, `prep`, `gasp`, `hdmx`, `LTSH`, `VDMX`                      | Complete                                                 |
| **Extended Formats**  | CFF2, MATH, BASE, JSTF, DSIG, meta, PCLT, EBLC/EBDT/EBSC                    | Complete                                                 |
| **High-Level API**    | `Font.open`, `font.render`, `font.instance`, `font.subset`, `font.validate` | Partial (some behavior flags pending)                    |
| **Text Layout**       | Measurement and line breaking                                               | Basic (alignment/direction/line-height behavior pending) |
| **Validation**        | Structural checks and warnings collection                                   | Basic (deep validation pending)                          |

### What's NOT Yet Supported

| Category         | Feature                                                                        | Status   |
| ---------------- | ------------------------------------------------------------------------------ | -------- |
| **Text Shaping** | Full OpenType shaping (GSUB/GPOS lookup application)                           | Phase 7  |
| **Text Shaping** | Complex script shapers (Arabic, Indic, Thai, etc.)                             | Phase 7  |
| **Text Shaping** | Parity in non-HarfBuzz fallback shaper                                         | Phase 7  |
| **Bidi**         | Unicode Bidirectional Algorithm (UAX #9)                                       | Phase 8  |
| **Bidi**         | Mixed LTR/RTL text layout                                                      | Phase 8  |
| **Subsetting**   | `SubsetOptions` behavior + subset output format conversion                     | Phase 9  |
| **Layout**       | Full layout option behavior (`align`, `direction`, `line_height`, hyphenation) | Phase 9  |
| **Validation**   | Deep validation beyond structural checks                                       | Phase 9  |
| **Resilience**   | Robust handling of malformed optional layout tables                            | Phase 9  |
| **Hinting**      | TrueType bytecode interpreter                                                  | Optional |

---

## Phase 1: Core Completeness ✅

Essential features for handling the majority of font files in the wild.

### Kerning Support ✅

- [x] Parse legacy `kern` table
  - [x] Format 0 (ordered list of kerning pairs)
  - [x] Format 2 (class-based kerning)
- [x] Provide `kern(glyph1, glyph2)` API
- [x] Integrate kerning into text width calculations

### CFF/OTF Support ✅

- [x] Parse `CFF ` table header and index structures
- [x] Parse Top DICT and Private DICT
- [x] Parse CharStrings (Type 2 charstring operators)
- [x] Parse Subrs and GlobalSubrs
- [x] Extract glyph outlines from CFF data
- [x] Support CFF-based font subsetting (desubroutinization approach)

### Web Font Formats ✅

- [x] WOFF support
  - [x] Parse WOFF header
  - [x] Decompress tables (zlib/DEFLATE)
  - [x] Extract metadata
- [x] WOFF2 support
  - [x] Parse WOFF2 header
  - [x] Brotli decompression
  - [x] Reconstruct sfnt from compressed data
  - [x] Full glyf/loca transform reconstruction
  - [x] hmtx transform reconstruction

### Font Collections ✅

- [x] Parse TTC/OTC header
- [x] Access individual fonts by index
- [x] Share table data between fonts in collection

### Glyph Outline API ✅

- [x] Extract glyph contours as point arrays
- [x] Distinguish on-curve vs off-curve points
- [x] Handle composite glyph transformations
- [x] Convert outlines to SVG path data
- [x] Provide bounding box per glyph

### Vertical Metrics ✅

- [x] Parse `vhea` table (vertical header)
- [x] Parse `vmtx` table (vertical metrics)
- [x] Provide vertical advance heights
- [x] Support `VORG` table for CFF fonts

---

## Phase 2: OpenType Layout (Parsing Complete, Application In Progress)

Features required for proper typography and international text support.

### GDEF Table ✅

- [x] Parse GlyphClassDef (base, ligature, mark, component)
- [x] Parse AttachList
- [x] Parse LigCaretList
- [x] Parse MarkAttachClassDef
- [x] Parse MarkGlyphSetsDef

### GPOS Table (Glyph Positioning) ✅

- [x] Parse GPOS header and script/feature/lookup lists
- [x] Lookup Type 1: Single adjustment
- [x] Lookup Type 2: Pair adjustment (modern kerning)
- [x] Lookup Type 3: Cursive attachment
- [x] Lookup Type 4: Mark-to-base attachment
- [x] Lookup Type 5: Mark-to-ligature attachment
- [x] Lookup Type 6: Mark-to-mark attachment
- [x] Lookup Type 7: Context positioning
- [x] Lookup Type 8: Chained context positioning
- [x] Lookup Type 9: Extension positioning
- [ ] Apply GPOS features in shaping pipeline (`kern`, `mark`, `mkmk`, etc.) (currently partial)

### GSUB Table (Glyph Substitution) ✅

- [x] Parse GSUB header and script/feature/lookup lists
- [x] Lookup Type 1: Single substitution
- [x] Lookup Type 2: Multiple substitution
- [x] Lookup Type 3: Alternate substitution
- [x] Lookup Type 4: Ligature substitution
- [x] Lookup Type 5: Context substitution
- [x] Lookup Type 6: Chained context substitution
- [x] Lookup Type 7: Extension substitution
- [x] Lookup Type 8: Reverse chaining substitution
- [ ] Apply GSUB features in shaping pipeline (`liga`, `clig`, `dlig`, `calt`, etc.) (currently partial)

### Coverage & Class Definition Tables ✅

- [x] Parse Coverage Format 1 (glyph list)
- [x] Parse Coverage Format 2 (range records)
- [x] Parse ClassDef Format 1 (array)
- [x] Parse ClassDef Format 2 (range records)

### Feature Registry Support (Parsing) ✅

- [x] Common ligatures (`liga`)
- [x] Contextual ligatures (`clig`)
- [x] Discretionary ligatures (`dlig`)
- [x] Kerning (`kern`)
- [x] Mark positioning (`mark`, `mkmk`)
- [x] Contextual alternates (`calt`)
- [x] Stylistic alternates (`salt`)
- [x] Numeric features (`lnum`, `onum`, `pnum`, `tnum`, `frac`)
- [x] Small caps (`smcp`, `c2sc`)
- [x] Localized forms (`locl`)

> **Note**: Context-based lookups (Types 5-8) are fully parsed. The structures are complete and ready for use in a shaping engine. Full text shaping requires implementing lookup application logic that chains nested lookups.

### Lookup Application Engine (Pending)

- [ ] Script/language system selection for feature activation
- [ ] GSUB Lookup Type 1-4 application in default shaper
- [ ] GSUB Lookup Type 5-8 (context/chaining/reverse) application
- [ ] GPOS single adjustment application in default shaper
- [ ] GPOS mark/cursive attachment application
- [ ] Lookup flag support (ignore marks/ligatures/base, mark filtering sets)
- [ ] Extension lookup recursion with robust bounds checking

---

## Phase 3: Variable Fonts ✅

Support for OpenType Font Variations (modern variable fonts).

### Core Variation Tables ✅

- [x] Parse `fvar` table
  - [x] Axis records (tag, min, default, max, name)
  - [x] Named instance records
- [x] Parse `STAT` table (style attributes)
  - [x] Axis values
  - [x] Axis value format 1-4
- [x] Parse `avar` table (axis variations/segment maps)

### TrueType Variations ✅

- [x] Parse `gvar` table
  - [x] Shared tuples
  - [x] Glyph variation data
  - [x] Tuple scalar calculation
  - [x] Delta interpolation for outline points
  - [x] `compute_glyph_deltas` for computing point adjustments
- [x] Parse `cvar` table (CVT variations)
  - [x] Tuple variation headers
  - [x] `compute_cvt_deltas` for interpolating CVT values

### Metrics Variations ✅

- [x] Parse `HVAR` table (horizontal metrics variations)
  - [x] ItemVariationStore parsing
  - [x] DeltaSetIndexMap parsing
  - [x] Advance width delta calculation
  - [x] LSB/RSB delta calculation
- [x] Parse `VVAR` table (vertical metrics variations)
  - [x] Advance height delta calculation
  - [x] TSB/BSB/VOrg delta calculation
- [x] Parse `MVAR` table (miscellaneous metrics variations)
  - [x] Value records for font-wide metrics
  - [x] Support for all metric tags (hasc, hdsc, xhgt, cpht, etc.)

### Variation API ✅

- [x] List available axes and named instances
- [x] Normalize coordinates (with avar support)
- [x] Interpolate metrics at coordinates
  - [x] `advance_width_delta` / `interpolated_advance_width`
  - [x] `metric_delta` for font-wide metrics
  - [x] `interpolated_ascender` / `interpolated_descender`
  - [x] `interpolated_x_height` / `interpolated_cap_height`
- [x] Get/set axis coordinates via `VariationInstance` class
  - [x] `set(tag, value)` / `get(tag)` for individual axes
  - [x] `reset(tag)` / `reset_all` for defaults
  - [x] Factory methods from Parser
- [x] Interpolate glyph outlines at coordinates
  - [x] `interpolated_glyph_outline(glyph_id, coords)`
  - [x] Full outline with applied deltas
- [x] Static instance generation helpers
  - [x] `interpolated_glyph_outlines` for all glyphs
  - [x] `interpolated_advance_widths` for all glyphs
  - [x] `interpolated_metrics` for font-wide values

---

## Phase 4: Color Fonts ✅

Support for color emoji and decorative color fonts.

### COLR/CPAL (Layered Color) ✅

- [x] Parse `CPAL` table (color palettes)
  - [x] Version 0 and 1 support
  - [x] Multiple palette support
  - [x] Color record parsing (BGRA)
  - [x] Palette type flags (v1)
- [x] Parse `COLR` v0 table (layered glyphs)
  - [x] BaseGlyphRecord parsing
  - [x] LayerRecord parsing
  - [x] Binary search for glyph lookup
- [x] Parse `COLR` v1 table
  - [x] BaseGlyphList for v1 glyphs
  - [x] Paint graph parsing (32 paint formats)
  - [x] Gradients (linear, radial, sweep)
  - [x] Transformations (translate, scale, rotate, skew)
  - [x] Blend modes (CompositeMode)
  - [x] ColorLine and ColorStop parsing

### SVG Glyphs ✅

- [x] Parse `SVG ` table
- [x] Extract SVG documents per glyph range
- [x] Handle gzip-compressed SVG data
- [x] Binary search for glyph lookup

### Bitmap Color Glyphs ✅

- [x] Parse `CBDT` table (color bitmap data)
  - [x] Format 17: SmallMetrics + PNG
  - [x] Format 18: BigMetrics + PNG
  - [x] Format 19: Metrics in CBLC + PNG
  - [x] Legacy formats 1, 2, 5, 6, 7
- [x] Parse `CBLC` table (color bitmap location)
  - [x] BitmapSize records
  - [x] IndexSubtable formats 1-5
  - [x] Glyph location lookup
- [x] Parse `sbix` table (Apple color bitmaps)
  - [x] Strike parsing (by PPEM)
  - [x] PNG/JPEG/TIFF support
  - [x] Dupe references
- [x] Support PNG, JPEG, TIFF embedded images

### Color Font API ✅

- [x] `color_font?` detection
- [x] `color_glyph_type` enumeration (Layered, Paint, SVG, Bitmap)
- [x] `has_color_glyph?` check
- [x] `color_glyph_svg` extraction
- [x] `color_glyph_layers` for COLR v0
- [x] `color_glyph_bitmap` for CBDT/sbix
- [x] `palette_color` access

---

## Phase 5: Hinting & Rendering

Low-level features for high-quality text rendering.

### Hinting Tables ✅

- [x] Parse `cvt ` table (control values)
- [x] Parse `fpgm` table (font program)
- [x] Parse `prep` table (control value program)
- [x] Parse `gasp` table (grid-fitting and anti-aliasing)

### TrueType Bytecode (Optional)

- [ ] Implement TrueType instruction interpreter
- [ ] Graphics state management
- [ ] Stack operations
- [ ] Point manipulation
- [ ] Delta hints

### Additional Metrics ✅

- [x] Parse `hdmx` table (horizontal device metrics)
- [x] Parse `LTSH` table (linear threshold)
- [x] Parse `VDMX` table (vertical device metrics)

---

## Phase 6: Extended Format Support ✅

Additional formats and specialized tables.

### CFF2 (Variable CFF) ✅

- [x] Parse CFF2 header
- [x] Parse VariationStore
- [x] Blend operators in CharStrings
- [x] Variable font support for CFF outlines

### Legacy Bitmap Fonts ✅

- [x] Parse `EBDT` table (embedded bitmap data)
- [x] Parse `EBLC` table (embedded bitmap location)
- [x] Parse `EBSC` table (embedded bitmap scaling)

### Mathematical Typesetting ✅

- [x] Parse `MATH` table
  - [x] Math constants (51 metrics)
  - [x] Math glyph info (italics, accents, kerning)
  - [x] Math variants (glyph construction)
  - [x] Math assembly (glyph part records)

### Additional Tables ✅

- [x] Parse `BASE` table (baseline data)
- [x] Parse `JSTF` table (justification)
- [x] Parse `DSIG` table (digital signature)
- [x] Parse `meta` table (metadata)
- [x] Parse `PCLT` table (PCL 5)

### Extended cmap Formats ✅

- [x] cmap format 2 (mixed 8/16-bit for CJK)
- [x] cmap format 13 (many-to-one range mappings)
- [x] cmap format 14 (Unicode Variation Sequences)

---

## Phase 7: Text Shaping Engine

Full OpenType text shaping for complex scripts. This phase aims to provide HarfBuzz-level shaping capabilities, either through native implementation or library bindings.

### HarfBuzz Bindings ✅

- [x] FFI bindings for core HarfBuzz types
  - [x] `hb_blob_t` - Data blob management
  - [x] `hb_face_t`, `hb_font_t` - Font handle types
  - [x] `hb_buffer_t` - Text buffer management
  - [x] `hb_feature_t` - OpenType feature specification
  - [x] `hb_glyph_info_t`, `hb_glyph_position_t` - Output types
  - [x] `hb_direction_t`, `hb_script_t`, `hb_language_t` - Text properties
- [x] Crystal wrapper classes
  - [x] `HarfBuzz::Blob` - Binary data wrapper
  - [x] `HarfBuzz::Face` - Load from file or bytes
  - [x] `HarfBuzz::Font` - Font with size/variations
  - [x] `HarfBuzz::Buffer` - Text input/output
  - [x] `HarfBuzz::Feature` - Feature tag/value with CSS-like parsing
  - [x] `HarfBuzz::ShapingOptions` - Options struct with presets for common scripts
  - [x] `HarfBuzz::Shaper` - High-level shaping API
- [x] Integration with TrueType::Font
  - [x] `font.shape_advanced(text, options)` - Full HarfBuzz shaping
  - [x] `font.render_advanced(text, options)` - Positioned glyphs
  - [x] `font.shape_best_effort(text, options)` - Fallback to basic shaping when HarfBuzz unavailable
  - [x] `font.harfbuzz_font` - Reusable HarfBuzz font for efficiency
  - [x] `TrueType.harfbuzz_available?` - Runtime availability check
- [x] Compile-time flag: `-Dharfbuzz` to enable HarfBuzz support
- [x] Memory management (reference counting via finalize)
- [x] Feature presets module (`HarfBuzz::Features`)
- [ ] Error handling (convert HarfBuzz errors to Crystal exceptions) - partial

> **Note**: HarfBuzz support is optional. Compile with `-Dharfbuzz` to enable. When disabled, `shape_best_effort` falls back to basic shaping (char→glyph + kerning).

### Default Shaper Parity (Non-HarfBuzz)

- [x] Implement ligature substitution in `Font#shape` fallback path
- [x] Honor `ShapingOptions#features` in fallback path
- [x] Honor script/language selection in fallback path
- [x] Apply GSUB/GPOS lookup chains in fallback path
- [x] Keep fallback behavior deterministic across fonts (with and without optional tables)
- [x] Add script-specific shaping tests (Arabic, Hebrew, Indic, Thai) for fallback behavior

---

## Phase 8: Bidirectional Text Support

Implementation of Unicode Bidirectional Algorithm (UAX #9) for mixed LTR/RTL text.

### Character Classification

- [x] Bidi_Class property lookup for all Unicode characters
  - [x] Strong types: L (Left-to-Right), R (Right-to-Left), AL (Arabic Letter)
  - [x] Weak types: EN, ES, ET, AN, CS, NSM, BN
  - [x] Neutral types: B, S, WS, ON
  - [x] Explicit formatting types: LRE, RLE, LRO, RLO, PDF, LRI, RLI, FSI, PDI
- [x] Bidi_Paired_Bracket property for bracket pairing
- [x] Bidi_Paired_Bracket_Type (Open/Close/None)

### Algorithm Implementation

- [x] **P1-P3**: Paragraph level determination
  - [x] Find first strong directional character
  - [x] Support explicit paragraph direction override
- [x] **X1-X8**: Explicit embedding levels
  - [x] LRE/RLE embedding (increase level)
  - [x] LRO/RLO override (force direction)
  - [x] PDF terminator
  - [x] Directional isolates (LRI, RLI, FSI, PDI)
  - [x] Max depth enforcement (125 levels)
- [x] **W1-W7**: Weak type resolution
  - [x] NSM inherits from preceding
  - [x] EN/AN context resolution
  - [x] Separator handling
- [x] **N0**: Bracket pairing
  - [x] Identify paired brackets
  - [x] Match opening/closing pairs
  - [x] Assign direction based on context
- [x] **N1-N2**: Neutral type resolution
  - [x] Resolve neutrals between strong types
  - [x] Handle isolate boundaries
- [x] **I1-I2**: Implicit level assignment
  - [x] Assign levels based on resolved types

### Reordering

- [x] **L1**: Line-based reordering
  - [x] Break into level runs
  - [x] Reverse odd-level runs
  - [x] Handle trailing whitespace
- [x] **L2**: Line break handling
- [x] **L3-L4**: Combining mark and control character handling

### Integration

- [x] `TextLayout` integration for bidi paragraphs
- [x] Visual-to-logical and logical-to-visual index mapping
- [x] Cursor movement in bidi text
- [x] Text selection in mixed-direction text

### Testing

- [x] Pass Unicode BidiTest.txt conformance suite (500K+ test cases)
- [x] Pass BidiCharacterTest.txt per-character tests

---

## Phase 9: Completion & Hardening

Close the remaining behavior gaps so the library reaches complete functional coverage, not only table parsing coverage.

### Subsetting Completion

- [ ] Apply `SubsetOptions#include_notdef`
- [ ] Apply `SubsetOptions#preserve_hints` (retain or strip hinting tables and instructions)
- [ ] Apply `SubsetOptions#preserve_layout` (retain/subset GSUB/GPOS/GDEF as configured)
- [ ] Apply `SubsetOptions#preserve_kerning` for `kern` and GPOS pair kerning data
- [ ] Apply `SubsetOptions#subset_names` (minimal name table mode)
- [ ] Apply `SubsetOptions#remove_signature` (DSIG handling)
- [ ] Implement output conversion for subset result (`:ttf`, `:otf`, `:woff`, `:woff2`)

### Layout Completion

- [ ] Implement alignment offsets in output glyph positions
- [ ] Implement `LayoutOptions#direction` behavior
- [ ] Apply `line_height` to paragraph y-positioning and total layout height
- [ ] Implement hyphenation path using `hyphen_char`
- [ ] Add layout regression tests for all options

### Validation & Robustness Completion

- [ ] Expand validation beyond required-table checks (cross-table consistency and bounds)
- [ ] Add stricter OpenType layout table validation for malformed offsets/lengths
- [ ] Ensure optional malformed tables degrade gracefully without crashing high-level APIs
- [ ] Add corpus-based malformed font tests and fuzzing harness

### Completion Criteria

- [ ] `font.shape` fallback path applies GSUB/GPOS features sufficiently for non-complex Latin typography
- [ ] `shape_best_effort` behavior is predictable with and without HarfBuzz
- [ ] All `SubsetOptions` flags are observable in tests
- [ ] `LayoutOptions` fields all affect output behavior and are covered by tests
- [x] Bidi conformance tests are green
- [ ] No known crashers on malformed optional tables in default API paths

---

## API Improvements (In Progress)

Enhancements to make the library easier to use.

### High-Level API (In Progress)

- [x] `Font.open(path)` with format auto-detection (TTF, OTF, WOFF, WOFF2, TTC/OTC)
- [ ] `font.shape(text, features)` full feature behavior in default path
- [x] `font.render(text)` returning positioned glyphs with cumulative positions
- [x] `font.instance(weight: 700, width: 100)` for variable fonts
- [ ] `font.subset(chars)` with full options behavior (hints/layout/kerning/names/signature)
- [ ] Subset output conversion (`:ttf`, `:otf`, `:woff`, `:woff2`)

### Text Layout (In Progress)

- [x] Basic text width calculation with kerning
- [x] Line breaking support with configurable max width
- [ ] Alignments (`Left`, `Center`, `Right`, `Justify`) applied to glyph positions
- [x] Directional layout option (`LeftToRight`, `RightToLeft`) applied in line ordering
- [ ] `line_height` applied to paragraph layout output (not just measurement helper)
- [ ] Hyphenation behavior (`hyphen_char`) in wrap logic
- [x] Bi-directional text support (UAX #9)
- [ ] Shaping-aware line breaking and layout integration

### Error Handling (In Progress)

- [x] Detailed parse error messages with byte offsets
- [x] Font validation mode (`font.validate`)
- [x] Graceful handling of many malformed fonts
- [x] Warning collection for non-fatal issues
- [ ] Recover from non-`ParseError` optional-table decode failures (for example `IO::EOFError`)
- [ ] Normalize exception surface for malformed layout tables

### Performance

- [x] Lazy table parsing (only parse when accessed)
- [ ] Glyph outline caching
- [ ] Memory-mapped file support for large fonts
- [ ] Parallel table parsing (where applicable)

---

## Testing & Quality

### Test Coverage

- [x] Unit tests for table parsing primitives and helpers
- [x] Integration tests with real-world fonts in fixtures
- [x] Subsetting round-trip tests (core behavior)
- [x] Variable font interpolation tests
- [x] Color font table tests
- [ ] Behavior tests for full GSUB/GPOS application outcomes
- [ ] Subset option behavior tests (`SubsetOptions` flags + output format)
- [ ] Malformed-font resilience/fuzz tests for optional tables
- [x] Bidi conformance tests (UAX #9 test suites)

### Test Fonts

- [x] Include open-source test fonts in fixtures
- [ ] Cover edge cases (empty glyphs, max values, malformed tables, etc.)
- [x] Include variable font test cases
- [x] Include color font test cases

### Benchmarks

- [ ] Font parsing speed benchmarks
- [ ] Subsetting performance benchmarks
- [ ] Memory usage profiling
- [ ] Comparison with other implementations

---

## Documentation

- [ ] API documentation for all public methods
- [x] Usage examples in README
- [ ] Guide: PDF font embedding
- [ ] Guide: Web font subsetting
- [ ] Guide: Working with variable fonts
- [ ] Guide: Text shaping basics

---

## Contributing

Contributions are welcome! When working on this roadmap:

1. Pick an unchecked item from the current phase
2. Open an issue to discuss the approach
3. Submit a PR with tests
4. Update this roadmap when complete

Priority should generally follow the phase order, but feel free to work on items that interest you or that you need for your use case.
