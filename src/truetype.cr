# TrueType/OpenType font parsing and subsetting library for Crystal.
#
# This library provides comprehensive support for reading and manipulating
# TrueType (.ttf), OpenType (.otf), WOFF, and WOFF2 font files, including
# font subsetting for embedding in documents.
#
# ## Quick Start
#
# ```
# require "truetype"
#
# # Open any font format with auto-detection
# font = TrueType::Font.open("path/to/font.ttf")  # or .otf, .woff, .woff2, .ttc
#
# # Access font information
# puts font.name              # "DejaVu Sans"
# puts font.postscript_name   # "DejaVuSans"
# puts font.units_per_em      # 2048
#
# # Shape text (with kerning and basic layout)
# glyphs = font.shape("Hello!")
# glyphs.each do |g|
#   puts "Glyph #{g.id}: advance=#{g.x_advance}"
# end
#
# # Variable fonts
# if font.variable?
#   bold = font.instance(wght: 700)
#   puts bold.text_width("Bold text")
# end
#
# # Subset for embedding
# subset = font.subset("Hello World!")
# File.write("subset.ttf", subset)
# ```
#
# ## Low-Level API
#
# For advanced use cases, the `Parser` class provides direct access to
# all font tables and data structures:
#
# ```
# parser = TrueType::Parser.parse("font.ttf")
# parser.head.units_per_em
# parser.cmap.glyph_id('A'.ord.to_u32)
# parser.glyf.glyph(glyph_id, parser.loca)
# ```
module TrueType
  VERSION = "0.1.0"
end

# IO Helpers for binary reading/writing
require "./truetype/io_helpers"

# Error handling
require "./truetype/errors"

# Table record structure
require "./truetype/table_record"

# Individual table parsers
require "./truetype/tables/head"
require "./truetype/tables/hhea"
require "./truetype/tables/maxp"
require "./truetype/tables/hmtx"
require "./truetype/tables/cmap"
require "./truetype/tables/loca"
require "./truetype/tables/glyf"
require "./truetype/tables/name"
require "./truetype/tables/post"
require "./truetype/tables/os2"
require "./truetype/tables/kern"
require "./truetype/tables/vhea"
require "./truetype/tables/vmtx"
require "./truetype/tables/vorg"

# OpenType layout tables
require "./truetype/tables/opentype/coverage"
require "./truetype/tables/opentype/class_def"
require "./truetype/tables/opentype/common"
require "./truetype/tables/opentype/context"
require "./truetype/tables/opentype/gdef"
require "./truetype/tables/opentype/gsub"
require "./truetype/tables/opentype/gpos"
require "./truetype/tables/opentype/base"
require "./truetype/tables/opentype/jstf"

# Variable font tables
require "./truetype/tables/variations/fvar"
require "./truetype/tables/variations/stat"
require "./truetype/tables/variations/avar"
require "./truetype/tables/variations/gvar"
require "./truetype/tables/variations/item_variation_store"
require "./truetype/tables/variations/hvar"
require "./truetype/tables/variations/vvar"
require "./truetype/tables/variations/mvar"
require "./truetype/tables/variations/cvar"

# Color font tables
require "./truetype/tables/color/cpal"
require "./truetype/tables/color/colr"
require "./truetype/tables/color/paint"
require "./truetype/tables/color/svg"
require "./truetype/tables/color/cblc"
require "./truetype/tables/color/cbdt"
require "./truetype/tables/color/sbix"

# Hinting tables
require "./truetype/tables/hinting/cvt"
require "./truetype/tables/hinting/fpgm"
require "./truetype/tables/hinting/prep"
require "./truetype/tables/hinting/gasp"
require "./truetype/tables/hinting/ltsh"
require "./truetype/tables/hinting/hdmx"
require "./truetype/tables/hinting/vdmx"

# Legacy bitmap tables
require "./truetype/tables/bitmap/eblc"
require "./truetype/tables/bitmap/ebdt"
require "./truetype/tables/bitmap/ebsc"

# Math tables (for mathematical typesetting)
require "./truetype/tables/math/constants"
require "./truetype/tables/math/glyph_info"
require "./truetype/tables/math/variants"
require "./truetype/tables/math/table"

# Metadata tables
require "./truetype/tables/metadata/dsig"
require "./truetype/tables/metadata/meta"
require "./truetype/tables/metadata/pclt"

# Outline types and extraction
require "./truetype/outline"
require "./truetype/outline_extractor"

# CFF parsing and subsetting
require "./truetype/tables/cff/index"
require "./truetype/tables/cff/dict"
require "./truetype/tables/cff/table"
require "./truetype/tables/cff/charstring"
require "./truetype/tables/cff/font"
require "./truetype/tables/cff/subsetter"

# CFF2 (Variable CFF) support
require "./truetype/tables/cff/cff2_table"
require "./truetype/tables/cff/cff2_charstring"
require "./truetype/tables/cff/cff2_font"

# Main parser and subsetter
require "./truetype/parser"
require "./truetype/subsetter"
require "./truetype/font_collection"
require "./truetype/woff"
require "./truetype/woff2"
require "./truetype/variation_instance"
require "./truetype/font"
require "./truetype/text_layout"

# Optional HarfBuzz support (compile with -Dharfbuzz)
require "./truetype/shaping/harfbuzz"
