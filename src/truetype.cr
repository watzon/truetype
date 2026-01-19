# TrueType/OpenType font parsing and subsetting library for Crystal.
#
# This library provides comprehensive support for reading and manipulating
# TrueType (.ttf) and OpenType (.otf) font files, including font subsetting
# for embedding in documents.
#
# ## Quick Start
#
# ```
# require "truetype"
#
# # Parse a font file
# font = TrueType::Parser.parse("path/to/font.ttf")
#
# # Access font information
# puts font.postscript_name
# puts font.units_per_em
# puts font.ascender
#
# # Get glyph metrics
# glyph_id = font.glyph_id('A')
# width = font.advance_width(glyph_id)
#
# # Create a subset with only needed glyphs
# subsetter = TrueType::Subsetter.new(font)
# subsetter.use("Hello World!")
# subset_data = subsetter.subset
# ```
module TrueType
  VERSION = "0.1.0"
end

# IO Helpers for binary reading/writing
require "./truetype/io_helpers"

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
