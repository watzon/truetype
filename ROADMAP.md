# TrueType Library Roadmap

> A roadmap to production-ready TrueType/OpenType font parsing and manipulation in Crystal.

## Current Status

The library provides a comprehensive foundation for TrueType font parsing and subsetting, covering approximately **90% of a production-ready implementation**. It's sufficient for PDF font embedding, supports web font formats, variable fonts, color fonts, CFF2 variable fonts, mathematical typesetting (MATH table), and handles virtually all font types encountered in the wild.

**Remaining major features** (Phases 7-8):
- Full OpenType text shaping for complex scripts (Arabic, Hebrew, Indic, Thai, etc.)
- Bidirectional text support (UAX #9) for mixed LTR/RTL text

### What Works Today

| Category              | Features                                                          | Status   |
| --------------------- | ----------------------------------------------------------------- | -------- |
| **Core Tables**       | `head`, `hhea`, `hmtx`, `maxp`, `cmap`, `name`, `post`, `OS/2`    | Complete |
| **TrueType Outlines** | `glyf`, `loca` table parsing                                      | Complete |
| **Character Mapping** | cmap formats 0, 4, 6, 12                                          | Complete |
| **Font Metrics**      | Units per em, ascender, descender, cap height, bounding box       | Complete |
| **Glyph Metrics**     | Advance widths, glyph IDs, character widths                       | Complete |
| **Font Info**         | PostScript name, family name, style flags (bold/italic/monospace) | Complete |
| **Subsetting**        | TrueType and CFF glyph subsetting with composite glyph support    | Complete |
| **PDF Support**       | Font descriptor flags, StemV estimation                           | Complete |
| **Kerning**           | `kern` table (format 0, 2), kerning API, text width with kerning  | Complete |
| **CFF/OTF**           | CFF table parsing, CharStrings, outline extraction, subsetting    | Complete |
| **WOFF**              | Header parsing, zlib decompression, sfnt conversion               | Complete |
| **WOFF2**             | Header parsing, Brotli decompression, sfnt reconstruction         | Complete |
| **Font Collections**  | TTC/OTC parsing, multi-font access                                | Complete |
| **Glyph Outlines**    | Contour extraction, SVG path export, bounding boxes               | Complete |
| **Vertical Metrics**  | `vhea`, `vmtx`, `VORG` tables, vertical writing support           | Complete |
| **OpenType Layout**   | `GDEF`, `GSUB`, `GPOS` tables, feature parsing                    | Complete |
| **Variable Fonts**    | `fvar`, `gvar`, `avar`, `HVAR`, `VVAR`, `MVAR`, `cvar`, `STAT`    | Complete |
| **Color Fonts**       | `CPAL`, `COLR` v0/v1, `SVG `, `CBDT`/`CBLC`, `sbix`               | Complete |
| **Hinting Tables**    | `cvt `, `fpgm`, `prep`, `gasp`, `hdmx`, `LTSH`, `VDMX`            | Complete |
| **Extended Formats**  | CFF2, MATH, BASE, JSTF, DSIG, meta, PCLT, EBLC/EBDT/EBSC          | Complete |
| **Extended cmap**     | cmap formats 2, 13, 14 (UVS)                                       | Complete |
| **High-Level API**    | `Font.open`, `font.shape`, `font.render`, `font.subset`, `font.instance` | Complete |
| **Text Layout**       | Text measurement, line breaking, paragraph layout                  | Complete |
| **Validation**        | Font validation, warnings collection, detailed error messages      | Complete |

### What's NOT Yet Supported

| Category | Feature | Status |
|----------|---------|--------|
| **Text Shaping** | Full OpenType shaping (GSUB/GPOS lookup application) | Phase 7 |
| **Text Shaping** | Complex script shapers (Arabic, Indic, Thai, etc.) | Phase 7 |
| **Text Shaping** | HarfBuzz integration | Phase 7 |
| **Bidi** | Unicode Bidirectional Algorithm (UAX #9) | Phase 8 |
| **Bidi** | Mixed LTR/RTL text layout | Phase 8 |
| **Hinting** | TrueType bytecode interpreter | Optional |

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

## Phase 2: OpenType Layout (In Progress)

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
- [x] Apply GPOS features by tag (`kern`, `mark`, `mkmk`, etc.)

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
- [x] Apply GSUB features by tag (`liga`, `clig`, `dlig`, `calt`, etc.)

### Coverage & Class Definition Tables ✅

- [x] Parse Coverage Format 1 (glyph list)
- [x] Parse Coverage Format 2 (range records)
- [x] Parse ClassDef Format 1 (array)
- [x] Parse ClassDef Format 2 (range records)

### Feature Registry Support ✅

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

---

## Phase 8: Bidirectional Text Support

Implementation of Unicode Bidirectional Algorithm (UAX #9) for mixed LTR/RTL text.

### Character Classification

- [ ] Bidi_Class property lookup for all Unicode characters
  - [ ] Strong types: L (Left-to-Right), R (Right-to-Left), AL (Arabic Letter)
  - [ ] Weak types: EN, ES, ET, AN, CS, NSM, BN
  - [ ] Neutral types: B, S, WS, ON
  - [ ] Explicit formatting types: LRE, RLE, LRO, RLO, PDF, LRI, RLI, FSI, PDI
- [ ] Bidi_Paired_Bracket property for bracket pairing
- [ ] Bidi_Paired_Bracket_Type (Open/Close/None)

### Algorithm Implementation

- [ ] **P1-P3**: Paragraph level determination
  - [ ] Find first strong directional character
  - [ ] Support explicit paragraph direction override
- [ ] **X1-X8**: Explicit embedding levels
  - [ ] LRE/RLE embedding (increase level)
  - [ ] LRO/RLO override (force direction)
  - [ ] PDF terminator
  - [ ] Directional isolates (LRI, RLI, FSI, PDI)
  - [ ] Max depth enforcement (125 levels)
- [ ] **W1-W7**: Weak type resolution
  - [ ] NSM inherits from preceding
  - [ ] EN/AN context resolution
  - [ ] Separator handling
- [ ] **N0**: Bracket pairing
  - [ ] Identify paired brackets
  - [ ] Match opening/closing pairs
  - [ ] Assign direction based on context
- [ ] **N1-N2**: Neutral type resolution
  - [ ] Resolve neutrals between strong types
  - [ ] Handle isolate boundaries
- [ ] **I1-I2**: Implicit level assignment
  - [ ] Assign levels based on resolved types

### Reordering

- [ ] **L1**: Line-based reordering
  - [ ] Break into level runs
  - [ ] Reverse odd-level runs
  - [ ] Handle trailing whitespace
- [ ] **L2**: Line break handling
- [ ] **L3-L4**: Combining mark and control character handling

### Integration

- [ ] `TextLayout` integration for bidi paragraphs
- [ ] Visual-to-logical and logical-to-visual index mapping
- [ ] Cursor movement in bidi text
- [ ] Text selection in mixed-direction text

### Testing

- [ ] Pass Unicode BidiTest.txt conformance suite (500K+ test cases)
- [ ] Pass BidiCharacterTest.txt per-character tests

---

## API Improvements ✅

Enhancements to make the library easier to use.

### High-Level API ✅

- [x] `Font.open(path)` with format auto-detection (TTF, OTF, WOFF, WOFF2, TTC/OTC)
- [x] `font.shape(text, features)` for text shaping with kerning and ligatures
- [x] `font.render(text)` returning positioned glyphs with cumulative positions
- [x] `font.instance(weight: 700, width: 100)` for variable fonts
- [x] `font.subset(chars)` with options (hints, features, etc.)

### Text Layout ✅

- [x] Basic text width calculation with kerning
- [x] Line breaking support with configurable max width
- [ ] Bi-directional text support (UAX #9)
- [ ] Text shaping integration (consider HarfBuzz bindings)

### Error Handling ✅

- [x] Detailed parse error messages with byte offsets
- [x] Font validation mode (`font.validate`)
- [x] Graceful handling of malformed fonts
- [x] Warning collection for non-fatal issues

### Performance

- [x] Lazy table parsing (only parse when accessed)
- [ ] Glyph outline caching
- [ ] Memory-mapped file support for large fonts
- [ ] Parallel table parsing (where applicable)

---

## Testing & Quality

### Test Coverage

- [ ] Unit tests for all table parsers
- [ ] Integration tests with real-world fonts
- [ ] Subsetting round-trip tests
- [ ] Variable font interpolation tests
- [ ] Color font rendering tests

### Test Fonts

- [ ] Include open-source test fonts in fixtures
- [ ] Cover edge cases (empty glyphs, max values, etc.)
- [ ] Include variable font test cases
- [ ] Include color font test cases

### Benchmarks

- [ ] Font parsing speed benchmarks
- [ ] Subsetting performance benchmarks
- [ ] Memory usage profiling
- [ ] Comparison with other implementations

---

## Documentation

- [ ] API documentation for all public methods
- [ ] Usage examples in README
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
