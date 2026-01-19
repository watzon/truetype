# TrueType Library Roadmap

> A roadmap to production-ready TrueType/OpenType font parsing and manipulation in Crystal.

## Current Status

The library provides a solid foundation for TrueType font parsing and subsetting, covering approximately **50-60% of a production-ready implementation**. It's sufficient for basic PDF font embedding, supports web font formats, and handles most font types encountered in the wild.

### What Works Today

| Category              | Features                                                          | Status   |
| --------------------- | ----------------------------------------------------------------- | -------- |
| **Core Tables**       | `head`, `hhea`, `hmtx`, `maxp`, `cmap`, `name`, `post`, `OS/2`    | Complete |
| **TrueType Outlines** | `glyf`, `loca` table parsing                                      | Complete |
| **Character Mapping** | cmap formats 0, 4, 6, 12                                          | Complete |
| **Font Metrics**      | Units per em, ascender, descender, cap height, bounding box       | Complete |
| **Glyph Metrics**     | Advance widths, glyph IDs, character widths                       | Complete |
| **Font Info**         | PostScript name, family name, style flags (bold/italic/monospace) | Complete |
| **Subsetting**        | Glyph subsetting with composite glyph support                     | Complete |
| **PDF Support**       | Font descriptor flags, StemV estimation                           | Complete |
| **Kerning**           | `kern` table (format 0, 2), kerning API, text width with kerning  | Complete |
| **CFF/OTF**           | CFF table parsing, CharStrings, outline extraction                | Complete |
| **WOFF**              | Header parsing, zlib decompression, sfnt conversion               | Complete |
| **WOFF2**             | Header parsing, Brotli decompression, sfnt reconstruction         | Complete |
| **Font Collections**  | TTC/OTC parsing, multi-font access                                | Complete |
| **Glyph Outlines**    | Contour extraction, SVG path export, bounding boxes               | Complete |
| **Vertical Metrics**  | `vhea`, `vmtx`, `VORG` tables, vertical writing support           | Complete |

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
- [ ] Support CFF-based font subsetting (future enhancement)

### Web Font Formats ✅

- [x] WOFF support
  - [x] Parse WOFF header
  - [x] Decompress tables (zlib/DEFLATE)
  - [x] Extract metadata
- [x] WOFF2 support
  - [x] Parse WOFF2 header
  - [x] Brotli decompression
  - [x] Reconstruct sfnt from compressed data
  - [ ] Full glyf/loca transform reconstruction (partial - returns data as-is)

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

## Phase 3: Variable Fonts

Support for OpenType Font Variations (modern variable fonts).

### Core Variation Tables

- [ ] Parse `fvar` table
  - [ ] Axis records (tag, min, default, max, name)
  - [ ] Named instance records
- [ ] Parse `STAT` table (style attributes)
  - [ ] Axis values
  - [ ] Axis value format 1-4
- [ ] Parse `avar` table (axis variations/segment maps)

### TrueType Variations

- [ ] Parse `gvar` table
  - [ ] Shared tuples
  - [ ] Glyph variation data
  - [ ] Delta interpolation
- [ ] Parse `cvar` table (CVT variations)

### Metrics Variations

- [ ] Parse `HVAR` table (horizontal metrics variations)
- [ ] Parse `VVAR` table (vertical metrics variations)
- [ ] Parse `MVAR` table (miscellaneous metrics variations)

### Variation API

- [ ] Get/set axis coordinates
- [ ] Interpolate glyph outlines at coordinates
- [ ] Interpolate metrics at coordinates
- [ ] Generate static instance from variable font
- [ ] List available axes and named instances

---

## Phase 4: Color Fonts

Support for color emoji and decorative color fonts.

### COLR/CPAL (Layered Color)

- [ ] Parse `CPAL` table (color palettes)
- [ ] Parse `COLR` v0 table (layered glyphs)
- [ ] Parse `COLR` v1 table
  - [ ] Gradients (linear, radial, sweep)
  - [ ] Transformations
  - [ ] Blend modes
  - [ ] Variable color support

### SVG Glyphs

- [ ] Parse `SVG ` table
- [ ] Extract SVG documents per glyph range
- [ ] Handle gzip-compressed SVG data

### Bitmap Color Glyphs

- [ ] Parse `CBDT` table (color bitmap data)
- [ ] Parse `CBLC` table (color bitmap location)
- [ ] Parse `sbix` table (Apple color bitmaps)
- [ ] Support PNG, JPEG, TIFF embedded images

---

## Phase 5: Hinting & Rendering

Low-level features for high-quality text rendering.

### Hinting Tables

- [ ] Parse `cvt ` table (control values)
- [ ] Parse `fpgm` table (font program)
- [ ] Parse `prep` table (control value program)
- [ ] Parse `gasp` table (grid-fitting and anti-aliasing)

### TrueType Bytecode (Optional)

- [ ] Implement TrueType instruction interpreter
- [ ] Graphics state management
- [ ] Stack operations
- [ ] Point manipulation
- [ ] Delta hints

### Additional Metrics

- [ ] Parse `hdmx` table (horizontal device metrics)
- [ ] Parse `LTSH` table (linear threshold)
- [ ] Parse `VDMX` table (vertical device metrics)

---

## Phase 6: Extended Format Support

Additional formats and specialized tables.

### CFF2 (Variable CFF)

- [ ] Parse CFF2 header
- [ ] Parse VariationStore
- [ ] Blend operators in CharStrings
- [ ] Variable font support for CFF outlines

### Legacy Bitmap Fonts

- [ ] Parse `EBDT` table (embedded bitmap data)
- [ ] Parse `EBLC` table (embedded bitmap location)
- [ ] Parse `EBSC` table (embedded bitmap scaling)

### Mathematical Typesetting

- [ ] Parse `MATH` table
  - [ ] Math constants
  - [ ] Math glyph info
  - [ ] Math variants
  - [ ] Math assembly

### Additional Tables

- [ ] Parse `BASE` table (baseline data)
- [ ] Parse `JSTF` table (justification)
- [ ] Parse `DSIG` table (digital signature)
- [ ] Parse `meta` table (metadata)
- [ ] Parse `PCLT` table (PCL 5)

### Extended cmap Formats

- [ ] cmap format 2 (mixed 8/16-bit)
- [ ] cmap format 13 (many-to-one)
- [ ] cmap format 14 (Unicode variation sequences)

---

## API Improvements

Enhancements to make the library easier to use.

### High-Level API

- [ ] `Font.open(path)` with format auto-detection
- [ ] `font.shape(text, features)` for text shaping
- [ ] `font.render(text)` returning positioned glyphs
- [ ] `font.instance(weight: 700, width: 100)` for variable fonts
- [ ] `font.subset(chars)` with options (hints, features, etc.)

### Text Layout

- [ ] Basic text width calculation with kerning
- [ ] Line breaking support
- [ ] Bi-directional text support (UAX #9)
- [ ] Text shaping integration (consider HarfBuzz bindings)

### Error Handling

- [ ] Detailed parse error messages with byte offsets
- [ ] Font validation mode
- [ ] Graceful handling of malformed fonts
- [ ] Warning collection for non-fatal issues

### Performance

- [ ] Lazy table parsing (only parse when accessed)
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
