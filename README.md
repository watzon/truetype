# truetype

> A pure Crystal library for parsing and subsetting TrueType/OpenType fonts.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Parsing a Font](#parsing-a-font)
  - [Accessing Font Information](#accessing-font-information)
  - [Font Subsetting](#font-subsetting)
  - [Available Tables](#available-tables)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Background

TrueType and OpenType fonts are complex binary formats that require careful parsing to extract glyph data, metrics, and other font information. This library provides a pure Crystal implementation for working with these font formats without external dependencies.

Key capabilities include:
- Parsing TrueType (.ttf) and OpenType (.otf) font files
- Access font metadata (names, metrics, bounding boxes)
- Character to glyph mapping with full Unicode support
- Font subsetting for embedding (includes only used glyphs to reduce file size)

This library is particularly useful for PDF generation, text rendering engines, and any application that needs to embed or manipulate font files programmatically.

## Install

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  truetype:
    github: watzon/truetype
```

Then run:

```bash
shards install
```

## Usage

### Parsing a Font

```crystal
require "truetype"

# Parse from file
font = TrueType::Parser.parse("path/to/font.ttf")

# Or from bytes
data = File.read("path/to/font.ttf").to_slice
font = TrueType::Parser.parse(data)
```

### Accessing Font Information

```crystal
font = TrueType::Parser.parse("DejaVuSans.ttf")

# Font names
puts font.postscript_name  # => "DejaVuSans"
puts font.family_name      # => "DejaVu Sans"

# Font metrics
puts font.units_per_em     # => 2048
puts font.ascender         # => 1901
puts font.descender        # => -483

# Glyph information
glyph_id = font.glyph_id('A')
width = font.advance_width(glyph_id)
puts "Glyph ID for 'A': #{glyph_id}, width: #{width}"

# Or directly
width = font.char_width('A')
```

### Font Subsetting

Create a smaller font file containing only the glyphs you need:

```crystal
font = TrueType::Parser.parse("DejaVuSans.ttf")
subsetter = TrueType::Subsetter.new(font)

# Mark characters as used
subsetter.use("Hello, World!")

# Generate the subset font
subset_data = subsetter.subset

# The subset is much smaller than the original
puts "Original: #{font.data.size} bytes"
puts "Subset: #{subset_data.size} bytes"

# Get the glyph mapping for text encoding
mapping = subsetter.unicode_to_glyph_map
```

### Available Tables

The parser provides access to standard TrueType tables:

- `head` - Font header (units per em, bounding box, style flags)
- `hhea` - Horizontal header (ascender, descender, line gap)
- `hmtx` - Horizontal metrics (advance widths, left side bearings)
- `maxp` - Maximum profile (number of glyphs)
- `cmap` - Character to glyph mapping
- `loca` - Glyph location index
- `glyf` - Glyph outlines (TrueType only)
- `name` - Font naming table
- `post` - PostScript information
- `OS/2` - OS/2 and Windows metrics

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
