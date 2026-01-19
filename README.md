# truetype

> A pure Crystal library for parsing and manipulating TrueType/OpenType fonts.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Quick Start](#quick-start)
  - [Opening Fonts](#opening-fonts)
  - [Text Shaping](#text-shaping)
  - [Advanced Text Shaping (HarfBuzz)](#advanced-text-shaping-harfbuzz)
  - [Variable Fonts](#variable-fonts)
  - [Font Subsetting](#font-subsetting)
  - [Text Layout](#text-layout)
  - [Font Validation](#font-validation)
  - [Low-Level API](#low-level-api)
- [Supported Features](#supported-features)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Background

TrueType and OpenType fonts are complex binary formats that require careful parsing to extract glyph data, metrics, and other font information. This library provides a pure Crystal implementation for working with these font formats without external dependencies (except optional Brotli for WOFF2).

Key capabilities include:
- **Format Support**: TTF, OTF, WOFF, WOFF2, TTC/OTC font collections
- **Variable Fonts**: Full variation axis support (weight, width, slant, etc.)
- **Color Fonts**: COLR/CPAL, SVG, sbix, CBDT/CBLC
- **OpenType Layout**: GSUB/GPOS tables for ligatures, kerning, etc.
- **Text Shaping**: Basic shaping with kerning and layout
- **Subsetting**: Create minimal fonts with only needed glyphs
- **Math Fonts**: MATH table for mathematical typesetting

## Install

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  truetype:
    github: watzon/truetype
```

For WOFF2 support, also add:

```yaml
dependencies:
  brotli:
    github: naqvis/brotli.cr
```

Then run:

```bash
shards install
```

## Usage

### Quick Start

```crystal
require "truetype"

# Open any font format with auto-detection
font = TrueType::Font.open("path/to/font.ttf")  # or .otf, .woff, .woff2, .ttc

# Access font information
puts font.name              # "DejaVu Sans"
puts font.postscript_name   # "DejaVuSans"
puts font.units_per_em      # 2048

# Shape text (with kerning)
glyphs = font.shape("Hello!")
glyphs.each do |g|
  puts "Glyph #{g.id}: advance=#{g.x_advance}"
end

# Create a subset for embedding
subset = font.subset("Hello World!")
File.write("subset.ttf", subset)
```

### Opening Fonts

The `Font.open` method provides automatic format detection:

```crystal
# Open from file path
font = TrueType::Font.open("font.ttf")     # TrueType
font = TrueType::Font.open("font.otf")     # OpenType (CFF)
font = TrueType::Font.open("font.woff")    # WOFF
font = TrueType::Font.open("font.woff2")   # WOFF2

# Open from bytes
data = File.read("font.ttf").to_slice
font = TrueType::Font.open(data)

# Open font collections (returns all fonts)
fonts = TrueType::Font.open_collection("collection.ttc")
fonts.each { |f| puts f.name }

# Check if data is a valid font before opening
TrueType::Font.font?("font.ttf")  # => true
TrueType::Font.font?(data)        # Check bytes directly

# Detect font format without parsing
TrueType::Font.detect_format(data)  # => :ttf, :otf, :woff, :woff2, :collection

# Access font properties
puts font.name           # Family name
puts font.style          # Style (Regular, Bold, etc.)
puts font.version        # Version string
puts font.copyright      # Copyright notice

# Check font type
font.truetype?   # TrueType outlines (glyf)
font.cff?        # CFF outlines
font.variable?   # Variable font
font.color?      # Color font
font.monospaced? # Monospaced
font.bold?       # Bold weight
font.italic?     # Italic style
```

### Text Shaping

Shape text into positioned glyphs:

```crystal
font = TrueType::Font.open("font.ttf")

# Basic shaping (includes kerning)
glyphs = font.shape("Hello World!")

glyphs.each do |glyph|
  puts "Glyph ID: #{glyph.id}"
  puts "Cluster: #{glyph.cluster}"
  puts "Advance: #{glyph.x_advance}"
end

# Shaping options
options = TrueType::ShapingOptions.new(
  kerning: true,
  ligatures: true,
  contextual_alternates: true
)
glyphs = font.shape("fi fl", options)

# Get absolute positions for rendering
rendered = font.render("Hello!")
rendered.each do |g|
  puts "Glyph #{g.id} at x=#{g.x_offset}"
end

# Calculate text width
width = font.text_width("Hello World!")
```

### Advanced Text Shaping (HarfBuzz)

For complex scripts (Arabic, Hebrew, Devanagari, Thai, etc.) or advanced OpenType features, you can optionally enable HarfBuzz integration:

**Installation:**

1. Install HarfBuzz on your system:
   ```bash
   # macOS
   brew install harfbuzz

   # Ubuntu/Debian
   apt install libharfbuzz-dev

   # Fedora
   dnf install harfbuzz-devel

   # Arch
   pacman -S harfbuzz
   ```

2. Compile with the `-Dharfbuzz` flag:
   ```bash
   crystal build -Dharfbuzz your_app.cr
   ```

**Usage:**

```crystal
require "truetype"

font = TrueType::Font.open("font.ttf")

# Check if HarfBuzz is available at runtime
if TrueType.harfbuzz_available?
  # Full HarfBuzz shaping for complex scripts
  glyphs = font.shape_advanced("مرحبا بالعالم")  # Arabic text

  glyphs.each do |g|
    puts "Glyph #{g.id} at (#{g.x_offset}, #{g.y_offset})"
  end

  # With specific features and options
  options = TrueType::HarfBuzz::ShapingOptions.new(
    direction: TrueType::HarfBuzz::Direction::RTL,
    script: "Arab",
    features: [
      TrueType::HarfBuzz::Features.liga,
      TrueType::HarfBuzz::Features.kern
    ]
  )
  glyphs = font.shape_advanced("مرحبا", options)

  # Preset options for common scripts
  glyphs = font.shape_advanced("שלום", TrueType::HarfBuzz::ShapingOptions.hebrew)
  glyphs = font.shape_advanced("Hello", TrueType::HarfBuzz::ShapingOptions.latin)

  # Get positioned glyphs with absolute coordinates
  rendered = font.render_advanced("Hello World!")

  # For repeated shaping, reuse the HarfBuzz font for efficiency
  hb_font = font.harfbuzz_font
  texts.each do |text|
    result = TrueType::HarfBuzz::Shaper.shape_with_font(hb_font, text)
  end
end

# Graceful fallback: uses HarfBuzz if available, otherwise basic shaping
glyphs = font.shape_best_effort("Hello مرحبا")
```

**Available Features:**

```crystal
# Common feature presets
TrueType::HarfBuzz::Features.liga      # Standard ligatures
TrueType::HarfBuzz::Features.kern      # Kerning
TrueType::HarfBuzz::Features.smcp      # Small caps
TrueType::HarfBuzz::Features.onum      # Oldstyle figures
TrueType::HarfBuzz::Features.tnum      # Tabular figures
TrueType::HarfBuzz::Features.frac      # Fractions
TrueType::HarfBuzz::Features.swsh      # Swashes
TrueType::HarfBuzz::Features.salt(2)   # Stylistic alternate #2
TrueType::HarfBuzz::Features.stylistic_set(3)  # Stylistic set ss03

# Parse from CSS-like strings
feature = TrueType::HarfBuzz::Feature.parse!("liga")
feature = TrueType::HarfBuzz::Feature.parse!("-kern")  # Disable
feature = TrueType::HarfBuzz::Feature.parse!("aalt=2")
features = TrueType::HarfBuzz::Feature.parse_list("liga,kern,-calt,smcp")
```

### Variable Fonts

Work with variable font axes:

```crystal
font = TrueType::Font.open("RobotoFlex.ttf")

# Check if variable
if font.variable?
  # List available axes
  font.variation_axes.each do |axis|
    puts "#{axis.tag}: #{axis.min_value}..#{axis.max_value} (default: #{axis.default_value})"
  end

  # Create an instance with specific axis values
  bold = font.instance(wght: 700)
  condensed = font.instance(wght: 700, wdth: 75)

  # Or use a hash
  instance = font.instance({"wght" => 700.0, "wdth" => 75.0})

  # Use a named instance
  font.named_instances.each_with_index do |inst, i|
    puts "Instance #{i}: #{inst.subfamily_name_id}"
  end
  instance = font.instance(0)  # First named instance

  # Get interpolated metrics
  puts instance.ascender
  puts instance.advance_width('A')
end
```

### Font Subsetting

Create smaller fonts containing only needed glyphs:

```crystal
font = TrueType::Font.open("DejaVuSans.ttf")

# Basic subset from text
subset = font.subset("Hello World!")
File.write("subset.ttf", subset)

# Subset from character set
chars = Set{'H', 'e', 'l', 'o', ' ', 'W', 'r', 'd', '!'}
subset = font.subset(chars)

# With options
options = TrueType::SubsetOptions.new(
  preserve_hints: true,
  preserve_layout: true,
  preserve_kerning: true
)
subset = font.subset("Hello", options)

# Preset options
subset = font.subset("Hello", TrueType::SubsetOptions.pdf)  # Minimal for PDF
subset = font.subset("Hello", TrueType::SubsetOptions.web)  # For web fonts

# Check size reduction
puts "Original: #{font.data.size} bytes"
puts "Subset: #{subset.size} bytes"
```

### Text Layout

Layout text with line breaking:

```crystal
font = TrueType::Font.open("font.ttf")

# Create layout engine
layout = font.layout_engine

# Measure text
width = layout.measure_width("Hello World!")
height = layout.measure_height(2)  # Height for 2 lines

# Layout with word wrap
options = TrueType::LayoutOptions.new(max_width: 500)
paragraph = font.layout("Hello World! This is a long text that will wrap.", options)

puts "Lines: #{paragraph.line_count}"
puts "Width: #{paragraph.width}"
puts "Height: #{paragraph.height}"

# Iterate over lines with positions
paragraph.each_line_with_position do |line, y|
  puts "Line at y=#{y}: #{line.width}px wide"
  line.glyphs.each do |glyph|
    # Render glyph...
  end
end

# Layout options
options = TrueType::LayoutOptions.new(
  max_width: 500,
  line_height: 1.2,
  align: TrueType::TextAlign::Left,
  kerning: true,
  ligatures: true,
  word_wrap: true
)
```

### Font Validation

Validate font files:

```crystal
font = TrueType::Font.open("font.ttf")

# Full validation
result = font.validate

if result.valid?
  puts "Font is valid!"
  if result.warnings?
    puts "Warnings:"
    result.warnings.each { |w| puts "  - #{w}" }
  end
else
  puts "Font is invalid!"
  result.errors.each { |e| puts "  Error: #{e}" }
end

# Quick validity check
font.valid?  # => true/false
```

### Low-Level API

For advanced use cases, access the parser directly. You can also create a `Font` from an existing parser:

```crystal
parser = TrueType::Parser.parse("font.ttf")

# Create a Font from an existing parser (useful for low-level work)
font = TrueType::Font.from_parser(parser)

# Access individual tables
parser.head.units_per_em
parser.hhea.ascent
parser.maxp.num_glyphs
parser.cmap.glyph_id('A'.ord.to_u32)

# Check for tables
parser.has_table?("GPOS")
parser.has_table?("GSUB")

# Access table data
if parser.has_kerning?
  parser.kerning('A', 'V')
end

# OpenType layout
if gsub = parser.gsub
  gsub.features.each { |f| puts f.tag }
end

# Glyph outlines
outline = parser.glyph_outline(glyph_id)
svg_path = outline.to_svg_path
```

## Supported Features

| Category | Features | Status |
|----------|----------|--------|
| **Core Tables** | head, hhea, hmtx, maxp, cmap, name, post, OS/2 | Complete |
| **Outlines** | TrueType (glyf/loca), CFF, CFF2 | Complete |
| **Web Fonts** | WOFF, WOFF2 | Complete |
| **Collections** | TTC/OTC | Complete |
| **Variable Fonts** | fvar, gvar, avar, HVAR, VVAR, MVAR, cvar, STAT | Complete |
| **Color Fonts** | COLR v0/v1, CPAL, SVG, CBDT/CBLC, sbix | Complete |
| **OpenType Layout** | GDEF, GSUB, GPOS | Complete |
| **Kerning** | kern table, GPOS kern feature | Complete |
| **Math** | MATH table | Complete |
| **Subsetting** | TrueType, CFF | Complete |
| **Text Shaping** | Basic (kerning, width), HarfBuzz (optional) | Complete |
| **Text Layout** | Width, height, line breaking | Complete |
| **Validation** | Table validation, warnings | Complete |

See [ROADMAP.md](ROADMAP.md) for detailed feature status.

## Maintainers

[@watzon](https://github.com/watzon)

## Contributing

Issues and pull requests are welcome! Feel free to check the [issue tracker](https://github.com/watzon/truetype/issues) if you want to contribute.

1. Fork it (<https://github.com/watzon/truetype/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

[MIT](LICENSE) © Chris Watson
