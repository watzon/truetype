# Phase 6: Extended Format Support - Implementation Plan

## Overview

This document details the implementation plan for Phase 6 of the TrueType library, covering extended format support including CFF2 (Variable CFF), legacy bitmap fonts, mathematical typesetting, and additional OpenType tables.

## File Structure

```
src/truetype/
├── tables/
│   ├── cmap.cr                    # Extended with formats 2, 13, 14
│   ├── bitmap/                    # NEW: Legacy bitmap tables
│   │   ├── eblc.cr               # Embedded Bitmap Location
│   │   ├── ebdt.cr               # Embedded Bitmap Data
│   │   └── ebsc.cr               # Embedded Bitmap Scaling
│   ├── math/                      # NEW: Mathematical typesetting
│   │   ├── constants.cr          # MathConstants (51 metrics)
│   │   ├── glyph_info.cr         # MathGlyphInfo subtable
│   │   ├── variants.cr           # MathVariants subtable
│   │   └── table.cr              # MATH table wrapper
│   ├── cff/
│   │   ├── table.cr              # Existing CFF1 table
│   │   ├── cff2_table.cr         # NEW: CFF2 header/structure
│   │   ├── cff2_charstring.cr    # NEW: CFF2 charstring with blend
│   │   └── cff2_font.cr          # NEW: CFF2Font class
│   ├── opentype/
│   │   ├── base.cr               # NEW: BASE table
│   │   └── jstf.cr               # NEW: JSTF table
│   └── metadata/                  # NEW: Metadata tables
│       ├── dsig.cr               # Digital Signature
│       ├── meta.cr               # Metadata
│       └── pclt.cr               # PCL 5
├── parser.cr                      # Updated with new table accessors
└── truetype.cr                    # Updated requires
```

---

## 1. Extended cmap Formats

### 1.1 Format 2 (Mixed 8/16-bit Encodings)

**Purpose**: Support for CJK fonts with mixed single/double-byte encodings

**Structure**:
```crystal
# SubHeader for format 2
struct CmapFormat2SubHeader
  getter first_code : UInt16       # First valid low byte
  getter entry_count : UInt16      # Number of valid codes  
  getter id_delta : Int16          # Delta for calculating GID
  getter id_range_offset : UInt16  # Offset to glyph indices
end
```

**Algorithm**:
1. High byte indexes into 256-entry subHeaderKeys array
2. If subHeaderKey == 0: single-byte lookup
3. Else: use SubHeader for two-byte lookup

### 1.2 Format 13 (Many-to-One Range Mappings)

**Purpose**: Maps multiple character codes to the same glyph (e.g., ".notdef" ranges)

**Structure**:
```crystal
# Same as Format 12 but all chars in range map to same GID
struct CmapFormat13Group
  getter start_char_code : UInt32
  getter end_char_code : UInt32
  getter glyph_id : UInt32  # Single GID for entire range
end
```

**Difference from Format 12**: Format 12 uses `start_glyph_id` and increments for each char. Format 13 uses the same GID for all chars in range.

### 1.3 Format 14 (Unicode Variation Sequences)

**Purpose**: Support for Unicode variation selectors (emoji skin tones, CJK variants)

**Structure**:
```crystal
class CmapFormat14
  # Variation selector to default/non-default UVS mappings
  getter variation_selectors : Hash(UInt32, VariationSelector)
  
  struct VariationSelector
    getter var_selector : UInt32
    getter default_uvs : Array(UnicodeRange)?      # Use default glyph
    getter non_default_uvs : Hash(UInt32, UInt16)? # Specific glyph overrides
  end
end
```

**API Addition**:
```crystal
def glyph_id(codepoint : UInt32, variation_selector : UInt32?) : UInt16?
```

---

## 2. Legacy Bitmap Tables (EBLC/EBDT/EBSC)

### 2.1 EBLC (Embedded Bitmap Location)

**Mirror of**: CBLC (Color Bitmap Location)

**Differences from CBLC**:
- Version 2.0 (vs 3.0 for CBLC)
- Used for monochrome/grayscale bitmaps
- Same BitmapSize and IndexSubtable formats

**Implementation**: Copy CBLC structure, adjust version handling.

### 2.2 EBDT (Embedded Bitmap Data)

**Mirror of**: CBDT (Color Bitmap Data)

**Differences from CBDT**:
- Version 2.0 (vs 3.0 for CBDT)
- No PNG formats (formats 17, 18, 19)
- Primarily formats 1-9 for monochrome/grayscale

**Image Formats**:
| Format | Metrics | Data |
|--------|---------|------|
| 1 | Small | Byte-aligned |
| 2 | Small | Bit-aligned |
| 5 | In EBLC | Bit-aligned |
| 6 | Big | Byte-aligned |
| 7 | Big | Bit-aligned |
| 8 | Small | Component |
| 9 | Big | Component |

### 2.3 EBSC (Embedded Bitmap Scaling)

**Purpose**: Define how to scale bitmaps for sizes without explicit strikes

**Structure**:
```crystal
class EBSC
  getter version : UInt16
  getter num_sizes : UInt32
  getter sizes : Array(BitmapScale)
  
  struct BitmapScale
    getter hori : SbitLineMetrics
    getter vert : SbitLineMetrics
    getter ppem_x : UInt8
    getter ppem_y : UInt8
    getter substitute_ppem_x : UInt8  # Use this strike instead
    getter substitute_ppem_y : UInt8
  end
end
```

---

## 3. MATH Table (Mathematical Typesetting)

### 3.1 MathConstants (51 Metrics)

**Categories**:
- **Scaling**: ScriptPercentScaleDown (80%), ScriptScriptPercentScaleDown (60%)
- **General**: AxisHeight, AccentBaseHeight, MathLeading
- **Subscript/Superscript**: 15 constants for positioning
- **Limits**: 4 constants for integral/sum limits
- **Stacks**: 6 constants for stacked expressions
- **Fractions**: 8 constants for fraction layout
- **Radicals**: 6 constants for square roots
- **Over/Underbar**: 6 constants for accents

**Implementation**:
```crystal
struct MathConstants
  # Each value is either Int16 or MathValueRecord
  getter script_percent_scale_down : Int16
  getter axis_height : MathValueRecord
  # ... 49 more constants
end

struct MathValueRecord
  getter value : Int16
  getter device_offset : UInt16  # Optional device table
end
```

### 3.2 MathGlyphInfo

**Subtables**:
1. **MathItalicsCorrection**: Italic slant adjustment per glyph
2. **MathTopAccentAttachment**: Horizontal positions for accents
3. **ExtendedShapeCoverage**: Glyphs that are "extended shapes"
4. **MathKernInfo**: Per-corner kerning for super/subscripts

**MathKern Structure**:
```crystal
struct MathKern
  getter correction_heights : Array(MathValueRecord)
  getter kern_values : Array(MathValueRecord)  # One more than heights
  
  def kern_at(height : Int16) : Int16
    # Binary search through heights, return appropriate kern
  end
end
```

### 3.3 MathVariants

**Purpose**: Glyph size variants and assembly for stretchy glyphs

**Structure**:
```crystal
class MathVariants
  getter min_connector_overlap : UInt16
  getter vert_glyph_coverage : Coverage
  getter horiz_glyph_coverage : Coverage
  getter vert_constructions : Array(MathGlyphConstruction)
  getter horiz_constructions : Array(MathGlyphConstruction)
end

struct MathGlyphConstruction
  getter glyph_assembly : GlyphAssembly?
  getter variants : Array(MathGlyphVariant)
end

struct GlyphAssembly
  getter italics_correction : MathValueRecord
  getter parts : Array(GlyphPartRecord)
end

struct GlyphPartRecord
  getter glyph_id : UInt16
  getter start_connector_length : UInt16
  getter end_connector_length : UInt16
  getter full_advance : UInt16
  getter part_flags : UInt16  # Bit 0 = extender
  
  def extender? : Bool
    (part_flags & 1) != 0
  end
end
```

### 3.4 Parser API

```crystal
class Parser
  # Check if font has math support
  def math_font? : Bool
  
  # Get math constant
  def math_constant(constant : MathConstant) : Int16
  
  # Get italics correction for glyph
  def math_italics_correction(glyph_id : UInt16) : Int16?
  
  # Get math kern at corner
  def math_kern(glyph_id : UInt16, corner : MathKernCorner, height : Int16) : Int16
  
  # Get glyph variants (vertical or horizontal)
  def math_glyph_variants(glyph_id : UInt16, vertical : Bool) : Array(MathGlyphVariant)?
  
  # Get glyph assembly for constructing large glyphs
  def math_glyph_assembly(glyph_id : UInt16, vertical : Bool) : GlyphAssembly?
end
```

---

## 4. CFF2 (Variable CFF)

### 4.1 Key Differences from CFF1

| Feature | CFF1 | CFF2 |
|---------|------|------|
| Header size field | hdrSize (8-bit) | headerSize (16-bit) |
| Name INDEX | Present | Removed |
| String INDEX | Present | Removed |
| Encoding | Present | Removed (use cmap) |
| Charset | Present | Removed (use post) |
| Private DICT | Offset in Top DICT | Per-FDArray entry |
| VariationStore | N/A | After Top DICT |
| blend operator | N/A | Operator 16 |

### 4.2 CFF2 Header

```crystal
struct CFF2Header
  getter major_version : UInt8     # Must be 2
  getter minor_version : UInt8
  getter header_size : UInt16      # Offset to Top DICT
  getter top_dict_length : UInt16  # Size of Top DICT
end
```

### 4.3 CFF2 Structure

```
CFF2 Table
├── Header (8 bytes)
├── Top DICT (variable)
├── Global Subr INDEX
├── VariationStore (if variable)
├── CharStrings INDEX
└── FDArray
    └── Font DICT
        └── Private DICT
            └── Local Subrs INDEX
```

### 4.4 VariationStore in CFF2

**Reuse**: `ItemVariationStore` from `src/truetype/tables/variations/item_variation_store.cr`

**Location**: Directly after Top DICT at offset specified by `vstore` operator

### 4.5 Blend Operator

**Operator 16**: Variable interpolation in CharStrings

**Stack Effect**:
```
n(0) .. n(k-1) d(0,0) .. d(k-1,0) ... d(0,n-1) .. d(k-1,n-1) n blend
  →
v(0) .. v(k-1)
```

Where:
- `k` = number of operands
- `n` = numBlends (from TopDICT vsindex)
- `d(i,j)` = delta for operand i, region j
- `v(i) = n(i) + Σ(d(i,j) × scalar(j))`

**Implementation**:
```crystal
class CFF2CharstringInterpreter < CharstringInterpreter
  @variation_store : ItemVariationStore?
  @normalized_coords : Array(Float64)?
  
  def handle_blend
    num_blends = @stack.pop.to_i
    k = @stack.size // (num_blends + 1)
    
    k.times do |i|
      base = @stack[i]
      delta_total = 0.0
      num_blends.times do |j|
        delta = @stack[k + i * num_blends + j]
        scalar = @variation_store.get_scalar(j, @normalized_coords)
        delta_total += delta * scalar
      end
      @stack[i] = base + delta_total
    end
    
    # Remove delta values from stack
    @stack = @stack[0, k]
  end
end
```

### 4.6 CFF2Font Class

```crystal
class CFF2Font
  getter header : CFF2Header
  getter top_dict : CFF::Dict
  getter global_subrs : CFF::Index
  getter variation_store : ItemVariationStore?
  getter charstrings : CFF::Index
  getter fd_array : Array(FontDict)
  
  def glyph_outline(glyph_id : UInt16, coords : Array(Float64)? = nil) : GlyphOutline
    interpreter = CFF2CharstringInterpreter.new(
      variation_store: @variation_store,
      normalized_coords: coords
    )
    interpreter.execute(charstrings[glyph_id])
  end
end
```

---

## 5. BASE Table (Baseline Data)

### 5.1 Structure

```crystal
class BASE
  getter version : UInt32  # 1.0 or 1.1
  getter horiz_axis : Axis?
  getter vert_axis : Axis?
  
  struct Axis
    getter base_tag_list : Array(String)  # 4-char tags like "romn", "ideo"
    getter base_script_list : Array(BaseScript)
  end
  
  struct BaseScript
    getter script_tag : String
    getter base_values : BaseValues?
    getter min_max : MinMax?
    getter base_lang_sys_records : Array(BaseLangSysRecord)
  end
  
  struct BaseValues
    getter default_baseline_index : UInt16
    getter base_coords : Array(BaseCoord)
  end
  
  struct BaseCoord
    getter format : UInt16  # 1, 2, or 3
    getter coordinate : Int16
    getter reference_glyph : UInt16?  # Format 2
    getter device_table : DeviceTable?  # Format 3
  end
end
```

### 5.2 API

```crystal
def baseline(script : String, baseline_tag : String, vertical : Bool = false) : Int16?
def min_max(script : String, language : String? = nil) : Tuple(Int16, Int16)?
```

---

## 6. JSTF Table (Justification)

### 6.1 Structure

```crystal
class JSTF
  getter version : UInt32
  getter jstf_script_records : Array(JstfScriptRecord)
  
  struct JstfScriptRecord
    getter script_tag : String
    getter extender_glyphs : Array(UInt16)
    getter jstf_lang_sys_records : Array(JstfLangSysRecord)
  end
  
  struct JstfLangSysRecord
    getter lang_sys_tag : String
    getter jstf_priorities : Array(JstfPriority)
  end
  
  struct JstfPriority
    getter gsub_shrinkage_enable : Array(UInt16)?   # Lookup indices
    getter gsub_shrinkage_disable : Array(UInt16)?
    getter gpos_shrinkage_enable : Array(UInt16)?
    getter gpos_shrinkage_disable : Array(UInt16)?
    getter shrinkage_max : JstfMax?
    getter gsub_extension_enable : Array(UInt16)?
    getter gsub_extension_disable : Array(UInt16)?
    getter gpos_extension_enable : Array(UInt16)?
    getter gpos_extension_disable : Array(UInt16)?
    getter extension_max : JstfMax?
  end
end
```

---

## 7. Metadata Tables

### 7.1 DSIG (Digital Signature)

```crystal
class DSIG
  getter version : UInt32
  getter num_signatures : UInt16
  getter flags : UInt16
  getter signatures : Array(SignatureRecord)
  
  struct SignatureRecord
    getter format : UInt32  # Usually 1
    getter length : UInt32
    getter offset : UInt32
    getter signature_data : Bytes
  end
  
  def signed? : Bool
    @num_signatures > 0
  end
end
```

### 7.2 meta (Metadata)

```crystal
class Meta
  getter version : UInt32
  getter flags : UInt32
  getter data_maps : Array(DataMap)
  
  struct DataMap
    getter tag : String       # "dlng", "slng", etc.
    getter data : String      # Text content
  end
  
  def design_languages : Array(String)?  # "dlng" tag
  def supported_languages : Array(String)?  # "slng" tag
end
```

### 7.3 PCLT (PCL 5)

```crystal
class PCLT
  getter version : UInt16
  getter font_number : UInt32
  getter pitch : UInt16
  getter x_height : UInt16
  getter style : UInt16
  getter type_family : UInt16
  getter cap_height : UInt16
  getter symbol_set : UInt16
  getter typeface : String  # 16 bytes
  getter character_complement : Bytes  # 8 bytes
  getter stroke_weight : Int8
  getter width_type : Int8
  getter serif_style : UInt8
end
```

---

## 8. Implementation Order

### Phase 6.1: cmap Extensions (Low Risk)
1. Add `parse_format2` to `cmap.cr`
2. Add `parse_format13` to `cmap.cr`
3. Add `CmapFormat14` class for variation sequences
4. Extend `glyph_id` API with variation selector support
5. Add tests

### Phase 6.2: Legacy Bitmap (Medium Risk)
1. Create `src/truetype/tables/bitmap/` directory
2. Implement `EBLC` (copy from `CBLC`)
3. Implement `EBDT` (copy from `CBDT`)
4. Implement `EBSC`
5. Add Parser integration
6. Add tests

### Phase 6.3: BASE Table (Medium Risk)
1. Create `src/truetype/tables/opentype/base.cr`
2. Implement parsing
3. Add Parser integration
4. Add tests

### Phase 6.4: MATH Table (High Complexity)
1. Create `src/truetype/tables/math/` directory
2. Implement `MathValueRecord` helper
3. Implement `MathConstants`
4. Implement `MathGlyphInfo`
5. Implement `MathVariants`
6. Create wrapper `MATH` class
7. Add Parser integration with API methods
8. Add tests

### Phase 6.5: CFF2 (Highest Complexity)
1. Create `CFF2Header` struct
2. Create `CFF2Table` parser
3. Create `CFF2CharstringInterpreter` with blend
4. Create `CFF2Font` class
5. Update Parser to detect CFF2 vs CFF1
6. Add interpolated outline support
7. Add tests

### Phase 6.6: JSTF Table (Low Priority)
1. Create `src/truetype/tables/opentype/jstf.cr`
2. Implement parsing
3. Add Parser integration
4. Add tests

### Phase 6.7: Metadata Tables (Low Priority)
1. Create `src/truetype/tables/metadata/` directory
2. Implement `DSIG`
3. Implement `meta`
4. Implement `PCLT`
5. Add Parser integration
6. Add tests

---

## 9. Testing Strategy

### Unit Tests
- Parse each table from known test fonts
- Verify field values against expected data
- Test edge cases (empty tables, max values)

### Integration Tests
- Round-trip: parse → access API → verify results
- Variable font tests for CFF2
- Math layout tests with known math fonts

### Test Fonts
- Latin Modern Math (MATH table)
- Source Han Sans (cmap format 2)
- Adobe Variable Font Prototype (CFF2)
- Google Noto Emoji (variation sequences)

---

## 10. Estimated Timeline

| Component | Estimated Effort | Dependencies |
|-----------|------------------|--------------|
| cmap formats | 1 day | None |
| EBLC/EBDT/EBSC | 1 day | CBLC/CBDT patterns |
| BASE | 0.5 day | OpenType common |
| MATH | 2-3 days | None |
| CFF2 | 3-4 days | ItemVariationStore, CFF1 |
| JSTF | 0.5 day | OpenType common |
| Metadata | 0.5 day | None |
| Tests | 1-2 days | All above |

**Total**: ~10-12 days for complete Phase 6 implementation
