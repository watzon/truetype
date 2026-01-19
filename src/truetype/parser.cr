module TrueType
  # Error raised when parsing a TrueType font fails
  class ParseError < Exception
  end

  # TrueType/OpenType font parser.
  # Parses .ttf and .otf font files and provides access to font data.
  class Parser
    include IOHelpers

    # Raw font data
    getter data : Bytes

    # Table records
    getter table_records : Hash(String, TableRecord)

    # Parsed tables (lazy loaded)
    @head : Tables::Head?
    @hhea : Tables::Hhea?
    @maxp : Tables::Maxp?
    @hmtx : Tables::Hmtx?
    @cmap : Tables::Cmap?
    @loca : Tables::Loca?
    @glyf : Tables::Glyf?
    @name : Tables::Name?
    @post : Tables::Post?
    @os2 : Tables::OS2?
    @kern : Tables::Kern?
    @vhea : Tables::Vhea?
    @vmtx : Tables::Vmtx?
    @vorg : Tables::Vorg?
    @cff : Tables::CFFFont?
    @gdef : Tables::OpenType::GDEF?
    @gsub : Tables::OpenType::GSUB?
    @gpos : Tables::OpenType::GPOS?

    # Font type (TrueType or CFF)
    getter sfnt_version : UInt32

    def initialize(@data : Bytes, @table_records : Hash(String, TableRecord), @sfnt_version : UInt32)
    end

    # Parse a TrueType font from a file path
    def self.parse(path : String) : Parser
      parse(File.read(path).to_slice)
    end

    # Parse a TrueType font from bytes
    def self.parse(data : Bytes) : Parser
      raise ParseError.new("Font data is too small") if data.size < 12

      io = IO::Memory.new(data)

      # Read sfnt version
      sfnt_version = read_uint32(io)

      # Validate sfnt version
      unless valid_sfnt_version?(sfnt_version)
        raise ParseError.new("Invalid sfnt version: 0x#{sfnt_version.to_s(16)}")
      end

      # Read table directory
      num_tables = read_uint16(io)
      _search_range = read_uint16(io)
      _entry_selector = read_uint16(io)
      _range_shift = read_uint16(io)

      # Read table records
      table_records = Hash(String, TableRecord).new
      num_tables.times do
        record = TableRecord.parse(io)
        table_records[record.tag] = record
      end

      new(data, table_records, sfnt_version)
    end

    # Check if the sfnt version is valid (public for FontCollection use)
    def self.valid_sfnt_version?(version : UInt32) : Bool
      version == 0x00010000 ||   # TrueType
        version == 0x4F54544F || # 'OTTO' (CFF)
        version == 0x74727565 || # 'true' (Apple TrueType)
        version == 0x74797031    # 'typ1' (Type 1)
    end

    # Check if this is a TrueType font (glyf outlines)
    def truetype? : Bool
      @sfnt_version == 0x00010000 || @sfnt_version == 0x74727565
    end

    # Check if this is a CFF font
    def cff? : Bool
      @sfnt_version == 0x4F54544F
    end

    # Check if a table exists
    def has_table?(tag : String) : Bool
      @table_records.has_key?(tag)
    end

    # Get raw table data
    def table_data(tag : String) : Bytes?
      record = @table_records[tag]?
      return nil unless record

      start_offset = record.offset.to_i
      end_offset = start_offset + record.length.to_i
      return nil if end_offset > @data.size

      @data[start_offset...end_offset]
    end

    # Get the head table
    def head : Tables::Head
      @head ||= begin
        data = table_data("head") || raise ParseError.new("Missing required table: head")
        Tables::Head.parse(data)
      end
    end

    # Get the hhea table
    def hhea : Tables::Hhea
      @hhea ||= begin
        data = table_data("hhea") || raise ParseError.new("Missing required table: hhea")
        Tables::Hhea.parse(data)
      end
    end

    # Get the maxp table
    def maxp : Tables::Maxp
      @maxp ||= begin
        data = table_data("maxp") || raise ParseError.new("Missing required table: maxp")
        Tables::Maxp.parse(data)
      end
    end

    # Get the hmtx table
    def hmtx : Tables::Hmtx
      @hmtx ||= begin
        data = table_data("hmtx") || raise ParseError.new("Missing required table: hmtx")
        Tables::Hmtx.parse(data, hhea.number_of_h_metrics, maxp.num_glyphs)
      end
    end

    # Get the cmap table
    def cmap : Tables::Cmap
      @cmap ||= begin
        data = table_data("cmap") || raise ParseError.new("Missing required table: cmap")
        Tables::Cmap.parse(data)
      end
    end

    # Get the loca table
    def loca : Tables::Loca
      @loca ||= begin
        data = table_data("loca") || raise ParseError.new("Missing required table: loca")
        Tables::Loca.parse(data, head.long_offsets?, maxp.num_glyphs)
      end
    end

    # Get the glyf table
    def glyf : Tables::Glyf
      @glyf ||= begin
        data = table_data("glyf") || raise ParseError.new("Missing required table: glyf")
        Tables::Glyf.parse(data)
      end
    end

    # Get the name table
    def name : Tables::Name
      @name ||= begin
        data = table_data("name") || raise ParseError.new("Missing required table: name")
        Tables::Name.parse(data)
      end
    end

    # Get the post table
    def post : Tables::Post
      @post ||= begin
        data = table_data("post") || raise ParseError.new("Missing required table: post")
        Tables::Post.parse(data)
      end
    end

    # Get the OS/2 table
    def os2 : Tables::OS2?
      @os2 ||= begin
        data = table_data("OS/2")
        data ? Tables::OS2.parse(data) : nil
      end
    end

    # Get the kern table
    def kern : Tables::Kern?
      @kern ||= begin
        data = table_data("kern")
        data ? Tables::Kern.parse(data) : nil
      end
    end

    # Get the vhea table (vertical header)
    def vhea : Tables::Vhea?
      @vhea ||= begin
        data = table_data("vhea")
        data ? Tables::Vhea.parse(data) : nil
      end
    end

    # Get the vmtx table (vertical metrics)
    def vmtx : Tables::Vmtx?
      @vmtx ||= begin
        data = table_data("vmtx")
        return nil unless data

        vhea_table = vhea
        return nil unless vhea_table

        Tables::Vmtx.parse(data, vhea_table.number_of_v_metrics, maxp.num_glyphs)
      end
    end

    # Get the VORG table (vertical origin for CFF fonts)
    def vorg : Tables::Vorg?
      @vorg ||= begin
        data = table_data("VORG")
        data ? Tables::Vorg.parse(data) : nil
      end
    end

    # Get the CFF font data (for CFF-based fonts)
    def cff_font : Tables::CFFFont?
      @cff ||= begin
        data = table_data("CFF ")
        data ? Tables::CFFFont.parse(data) : nil
      end
    end

    # Get the GDEF table (glyph definition)
    def gdef : Tables::OpenType::GDEF?
      @gdef ||= begin
        record = @table_records["GDEF"]?
        return nil unless record
        Tables::OpenType::GDEF.parse(@data, record.offset, record.length)
      end
    end

    # Get the GSUB table (glyph substitution)
    def gsub : Tables::OpenType::GSUB?
      @gsub ||= begin
        record = @table_records["GSUB"]?
        return nil unless record
        Tables::OpenType::GSUB.parse(@data, record.offset, record.length)
      end
    end

    # Get the GPOS table (glyph positioning)
    def gpos : Tables::OpenType::GPOS?
      @gpos ||= begin
        record = @table_records["GPOS"]?
        return nil unless record
        Tables::OpenType::GPOS.parse(@data, record.offset, record.length)
      rescue ex : ParseError
        # Some fonts have malformed GPOS tables - fall back gracefully
        nil
      end
    end

    # Check if the font supports vertical writing
    def vertical_writing? : Bool
      has_table?("vhea") && has_table?("vmtx")
    end

    # Get the PostScript name
    def postscript_name : String
      name.postscript_name || name.full_name || "Unknown"
    end

    # Get the font family name
    def family_name : String
      name.font_family || "Unknown"
    end

    # Get the units per em
    def units_per_em : UInt16
      head.units_per_em
    end

    # Get the ascender (in font units)
    def ascender : Int16
      os2.try(&.ascender) || hhea.ascent
    end

    # Get the descender (in font units)
    def descender : Int16
      os2.try(&.descender) || hhea.descent
    end

    # Get the cap height (in font units)
    def cap_height : Int16
      os2.try(&.cap_height) || (ascender * 0.7).to_i16
    end

    # Get the italic angle
    def italic_angle : Float64
      post.italic_angle
    end

    # Check if the font is bold
    def bold? : Bool
      os2.try(&.bold?) || head.bold?
    end

    # Check if the font is italic
    def italic? : Bool
      os2.try(&.italic?) || head.italic?
    end

    # Check if the font is monospaced
    def monospaced? : Bool
      post.monospaced?
    end

    # Get the glyph ID for a Unicode codepoint
    def glyph_id(codepoint : UInt32) : UInt16
      cmap.glyph_id(codepoint) || 0_u16
    end

    # Get the glyph ID for a character
    def glyph_id(char : Char) : UInt16
      glyph_id(char.ord.to_u32)
    end

    # Get the advance width for a glyph (in font units)
    def advance_width(glyph_id : UInt16) : UInt16
      hmtx.advance_width(glyph_id)
    end

    # Get the advance height for a glyph (in font units)
    # Returns the advance height for vertical writing, or 0 if vertical metrics aren't available
    def advance_height(glyph_id : UInt16) : UInt16
      vmtx.try(&.advance_height(glyph_id)) || 0_u16
    end

    # Get the advance height for a character (in font units)
    def char_height(char : Char) : UInt16
      advance_height(glyph_id(char))
    end

    # Get the left side bearing for a glyph (in font units)
    def left_side_bearing(glyph_id : UInt16) : Int16
      hmtx.left_side_bearing(glyph_id)
    end

    # Get the top side bearing for a glyph (in font units)
    # Returns the top side bearing for vertical writing, or 0 if not available
    def top_side_bearing(glyph_id : UInt16) : Int16
      vmtx.try(&.top_side_bearing(glyph_id)) || 0_i16
    end

    # Get the vertical origin Y for a glyph (in font units)
    # Returns the vertical origin from VORG if available, otherwise estimates from ascender
    def vert_origin_y(glyph_id : UInt16) : Int16
      if vorg_table = vorg
        vorg_table.vert_origin_y(glyph_id)
      else
        # Estimate: use ascender as the vertical origin
        ascender
      end
    end

    # Get the advance width for a character (in font units)
    def char_width(char : Char) : UInt16
      advance_width(glyph_id(char))
    end

    # Get the kerning adjustment between two glyphs (in font units)
    # Checks GPOS table first (OpenType kerning), then falls back to kern table (legacy)
    # Returns 0 if no kerning is defined
    def kerning(left_glyph : UInt16, right_glyph : UInt16) : Int16
      # Try GPOS first (modern OpenType kerning)
      if gpos_table = gpos
        result = gpos_table.kern(left_glyph, right_glyph)
        return result if result != 0
      end

      # Fall back to legacy kern table
      kern.try(&.kern(left_glyph, right_glyph)) || 0_i16
    end

    # Get the kerning adjustment between two characters (in font units)
    def kerning(left : Char, right : Char) : Int16
      kerning(glyph_id(left), glyph_id(right))
    end

    # Check if the font has kerning data (legacy kern table or GPOS kern feature)
    def has_kerning? : Bool
      # Check for GPOS kern feature
      if gpos_table = gpos
        return true unless gpos_table.lookups_for_feature("kern").empty?
      end

      # Check legacy kern table
      kern.try { |k| !k.empty? } || false
    end

    # Check if the font has OpenType layout tables
    def has_opentype_layout? : Bool
      has_table?("GPOS") || has_table?("GSUB")
    end

    # Check if the font has a specific GSUB feature
    def has_gsub_feature?(tag : String) : Bool
      return false unless gsub_table = gsub
      !gsub_table.lookups_for_feature(tag).empty?
    end

    # Check if the font has a specific GPOS feature
    def has_gpos_feature?(tag : String) : Bool
      return false unless gpos_table = gpos
      !gpos_table.lookups_for_feature(tag).empty?
    end

    # Check if the font supports ligatures
    def has_ligatures? : Bool
      has_gsub_feature?("liga") || has_gsub_feature?("clig") || has_gsub_feature?("dlig")
    end

    # Get the glyph class for a glyph (base, ligature, mark, component)
    def glyph_class(glyph_id : UInt16) : Tables::OpenType::GDEF::GlyphClass?
      gdef.try(&.glyph_class(glyph_id))
    end

    # Check if a glyph is a mark (combining glyph)
    def mark_glyph?(glyph_id : UInt16) : Bool
      gdef.try(&.mark?(glyph_id)) || false
    end

    # Check if a glyph is a base glyph
    def base_glyph?(glyph_id : UInt16) : Bool
      gdef.try(&.base?(glyph_id)) || false
    end

    # Calculate the total width of a string including kerning (in font units)
    def text_width(text : String) : Int32
      return 0 if text.empty?

      total = 0_i32
      prev_glyph : UInt16? = nil

      text.each_char do |char|
        glyph = glyph_id(char)

        # Add kerning adjustment if there's a previous glyph
        if prev = prev_glyph
          total += kerning(prev, glyph).to_i32
        end

        # Add advance width
        total += advance_width(glyph).to_i32
        prev_glyph = glyph
      end

      total
    end

    # Get the font bounding box
    def bounding_box : Tuple(Int16, Int16, Int16, Int16)
      head.bounding_box
    end

    # Get the outline for a glyph
    # For TrueType glyphs, returns contours from glyf table
    # For CFF glyphs, returns contours from charstrings
    def glyph_outline(glyph_id : UInt16) : GlyphOutline
      if truetype?
        glyph_data = glyf.glyph(glyph_id, loca)
        return GlyphOutline.new if glyph_data.empty?

        if glyph_data.composite?
          extract_composite_outline(glyph_data)
        else
          OutlineExtractor.extract_simple(glyph_data)
        end
      elsif cff?
        cff_font.try(&.glyph_outline(glyph_id)) || GlyphOutline.new
      else
        GlyphOutline.new
      end
    end

    # Get the outline for a character
    def char_outline(char : Char) : GlyphOutline
      glyph_outline(glyph_id(char))
    end

    # Get the outline as SVG path data for a glyph
    def glyph_svg_path(glyph_id : UInt16) : String
      glyph_outline(glyph_id).to_svg_path
    end

    # Get the outline as SVG path data for a character
    def char_svg_path(char : Char) : String
      char_outline(char).to_svg_path
    end

    # Get a complete SVG for a glyph
    def glyph_svg(glyph_id : UInt16, width : Int32? = nil, height : Int32? = nil) : String
      glyph_outline(glyph_id).to_svg(width, height)
    end

    # Get a complete SVG for a character
    def char_svg(char : Char, width : Int32? = nil, height : Int32? = nil) : String
      char_outline(char).to_svg(width, height)
    end

    # Get the bounding box for a specific glyph
    def glyph_bounding_box(glyph_id : UInt16) : Tuple(Int16, Int16, Int16, Int16)
      return {0_i16, 0_i16, 0_i16, 0_i16} unless truetype?

      glyph_data = glyf.glyph(glyph_id, loca)
      {glyph_data.x_min, glyph_data.y_min, glyph_data.x_max, glyph_data.y_max}
    end

    # Get the bounding box for a character
    def char_bounding_box(char : Char) : Tuple(Int16, Int16, Int16, Int16)
      glyph_bounding_box(glyph_id(char))
    end

    private def extract_composite_outline(glyph_data : Tables::GlyphData) : GlyphOutline
      components = OutlineExtractor.parse_composite_components(glyph_data)
      result = GlyphOutline.new(
        [] of Contour,
        glyph_data.x_min,
        glyph_data.y_min,
        glyph_data.x_max,
        glyph_data.y_max,
        composite: true
      )

      components.each do |component|
        component_glyph = glyf.glyph(component.glyph_id, loca)
        next if component_glyph.empty?

        # Recursively get the component outline
        component_outline = if component_glyph.composite?
                              extract_composite_outline(component_glyph)
                            else
                              OutlineExtractor.extract_simple(component_glyph)
                            end

        next if component_outline.empty?

        # Apply transformation
        # The full transformation is: [a b] [x]   [e]
        #                             [c d] [y] + [f]
        # where e = arg1 and f = arg2 (if ARGS_ARE_XY_VALUES)
        e = component.arg1.to_f64
        f = component.arg2.to_f64

        transformed = component_outline.transform(
          component.a, component.b,
          component.c, component.d,
          e, f
        )

        result.merge!(transformed)
      end

      result
    end

    # Get flags for PDF font descriptor
    def flags : UInt32
      flags = 0_u32

      # Bit 1: FixedPitch
      flags |= (1 << 0) if monospaced?

      # Bit 2: Serif (not easily detected, skip)
      # Bit 3: Symbolic (not easily detected, skip)

      # Bit 4: Script (not easily detected, skip)

      # Bit 6: Italic
      flags |= (1 << 6) if italic?

      # Bit 17: AllCap (not easily detected, skip)
      # Bit 18: SmallCap (not easily detected, skip)
      # Bit 19: ForceBold (not easily detected, skip)

      # If not symbolic, set Nonsymbolic (bit 5)
      flags |= (1 << 5) # Assume nonsymbolic for most fonts

      flags
    end

    # Get the StemV value for PDF (estimate based on weight)
    def stem_v : Int32
      if os2_table = os2
        # Estimate from weight class
        weight = os2_table.weight_class
        if weight <= 400
          68 + (weight / 4)
        else
          68 + (weight / 2)
        end.to_i32
      else
        # Default estimate
        80_i32
      end
    end

    extend IOHelpers
  end
end
