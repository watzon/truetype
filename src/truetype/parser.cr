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

    # Variable font tables (lazy loaded)
    @fvar : Tables::Variations::Fvar?
    @stat : Tables::Variations::Stat?
    @avar : Tables::Variations::Avar?
    @gvar : Tables::Variations::Gvar?
    @hvar : Tables::Variations::Hvar?
    @vvar : Tables::Variations::Vvar?
    @mvar : Tables::Variations::Mvar?
    @cvar : Tables::Variations::Cvar?

    # Color font tables (lazy loaded)
    @cpal : Tables::Color::CPAL?
    @colr : Tables::Color::COLR?
    @svg : Tables::Color::SVG?
    @cblc : Tables::Color::CBLC?
    @cbdt : Tables::Color::CBDT?
    @sbix : Tables::Color::Sbix?

    # Hinting tables (lazy loaded)
    @cvt : Tables::Hinting::Cvt?
    @fpgm : Tables::Hinting::Fpgm?
    @prep : Tables::Hinting::Prep?
    @gasp : Tables::Hinting::Gasp?
    @ltsh : Tables::Hinting::Ltsh?
    @hdmx : Tables::Hinting::Hdmx?
    @vdmx : Tables::Hinting::Vdmx?

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

    # Get the fvar table (font variations)
    def fvar : Tables::Variations::Fvar?
      @fvar ||= begin
        data = table_data("fvar")
        data ? Tables::Variations::Fvar.parse(data) : nil
      end
    end

    # Check if this is a variable font
    def variable_font? : Bool
      has_table?("fvar")
    end

    # Get all variation axes (empty array if not a variable font)
    def variation_axes : Array(Tables::Variations::VariationAxisRecord)
      fvar.try(&.axes) || [] of Tables::Variations::VariationAxisRecord
    end

    # Get all named instances (empty array if not a variable font)
    def named_instances : Array(Tables::Variations::InstanceRecord)
      fvar.try(&.instances) || [] of Tables::Variations::InstanceRecord
    end

    # Get the STAT table (style attributes)
    def stat : Tables::Variations::Stat?
      @stat ||= begin
        data = table_data("STAT")
        data ? Tables::Variations::Stat.parse(data) : nil
      end
    end

    # Get the avar table (axis variations)
    def avar : Tables::Variations::Avar?
      @avar ||= begin
        data = table_data("avar")
        data ? Tables::Variations::Avar.parse(data) : nil
      end
    end

    # Get the gvar table (glyph variations)
    def gvar : Tables::Variations::Gvar?
      @gvar ||= begin
        data = table_data("gvar")
        data ? Tables::Variations::Gvar.parse(data) : nil
      end
    end

    # Normalize user coordinates to the [-1, 1] space with avar adjustments.
    # Takes a hash of axis tag => user value and returns normalized coordinates
    # in axis order as defined by fvar.
    def normalize_variation_coordinates(user_coords : Hash(String, Float64)) : Array(Float64)?
      fvar_table = fvar
      return nil unless fvar_table

      # First apply default normalization
      normalized = fvar_table.normalize_coordinates(user_coords)

      # Then apply avar adjustments if present
      if avar_table = avar
        normalized = avar_table.map_coordinates(normalized)
      end

      normalized
    end

    # Check if a glyph has variation data (for variable fonts with gvar)
    def glyph_has_variations?(glyph_id : UInt16) : Bool
      gvar.try(&.has_variation_data?(glyph_id)) || false
    end

    # Get the HVAR table (horizontal metrics variations)
    def hvar : Tables::Variations::Hvar?
      @hvar ||= begin
        data = table_data("HVAR")
        data ? Tables::Variations::Hvar.parse(data) : nil
      end
    end

    # Get the VVAR table (vertical metrics variations)
    def vvar : Tables::Variations::Vvar?
      @vvar ||= begin
        data = table_data("VVAR")
        data ? Tables::Variations::Vvar.parse(data) : nil
      end
    end

    # Get the MVAR table (miscellaneous metrics variations)
    def mvar : Tables::Variations::Mvar?
      @mvar ||= begin
        data = table_data("MVAR")
        data ? Tables::Variations::Mvar.parse(data) : nil
      end
    end

    # Get the cvar table (CVT variations)
    def cvar : Tables::Variations::Cvar?
      @cvar ||= begin
        data = table_data("cvar")
        return nil unless data
        fvar_table = fvar
        return nil unless fvar_table
        # CVT count comes from the cvt table size (each entry is 2 bytes)
        cvt_data = table_data("cvt ")
        cvt_count = cvt_data ? (cvt_data.size // 2).to_u16 : 0_u16
        Tables::Variations::Cvar.parse(data, cvt_count, fvar_table.axis_count)
      end
    end

    # Get the CPAL table (color palette)
    def cpal : Tables::Color::CPAL?
      @cpal ||= begin
        data = table_data("CPAL")
        data ? Tables::Color::CPAL.parse(data) : nil
      end
    end

    # Get the COLR table (color glyph definitions)
    def colr : Tables::Color::COLR?
      @colr ||= begin
        data = table_data("COLR")
        data ? Tables::Color::COLR.parse(data) : nil
      end
    end

    # Get the SVG table (SVG glyph documents)
    def svg : Tables::Color::SVG?
      @svg ||= begin
        data = table_data("SVG ")
        data ? Tables::Color::SVG.parse(data) : nil
      end
    end

    # Get the CBLC table (color bitmap location)
    def cblc : Tables::Color::CBLC?
      @cblc ||= begin
        data = table_data("CBLC")
        data ? Tables::Color::CBLC.parse(data) : nil
      end
    end

    # Get the CBDT table (color bitmap data)
    def cbdt : Tables::Color::CBDT?
      @cbdt ||= begin
        data = table_data("CBDT")
        data ? Tables::Color::CBDT.parse(data) : nil
      end
    end

    # Get the sbix table (Apple color bitmaps)
    def sbix : Tables::Color::Sbix?
      @sbix ||= begin
        data = table_data("sbix")
        data ? Tables::Color::Sbix.parse(data, maxp.num_glyphs) : nil
      end
    end

    # Get the cvt table (Control Value Table)
    def cvt : Tables::Hinting::Cvt?
      @cvt ||= begin
        data = table_data("cvt ")
        data ? Tables::Hinting::Cvt.parse(data) : nil
      end
    end

    # Get the fpgm table (Font Program)
    def fpgm : Tables::Hinting::Fpgm?
      @fpgm ||= begin
        data = table_data("fpgm")
        data ? Tables::Hinting::Fpgm.parse(data) : nil
      end
    end

    # Get the prep table (Control Value Program)
    def prep : Tables::Hinting::Prep?
      @prep ||= begin
        data = table_data("prep")
        data ? Tables::Hinting::Prep.parse(data) : nil
      end
    end

    # Get the gasp table (Grid-fitting and Scan-conversion Procedure)
    def gasp : Tables::Hinting::Gasp?
      @gasp ||= begin
        data = table_data("gasp")
        data ? Tables::Hinting::Gasp.parse(data) : nil
      end
    end

    # Get the LTSH table (Linear Threshold)
    def ltsh : Tables::Hinting::Ltsh?
      @ltsh ||= begin
        data = table_data("LTSH")
        data ? Tables::Hinting::Ltsh.parse(data) : nil
      end
    end

    # Get the hdmx table (Horizontal Device Metrics)
    def hdmx : Tables::Hinting::Hdmx?
      @hdmx ||= begin
        data = table_data("hdmx")
        data ? Tables::Hinting::Hdmx.parse(data, maxp.num_glyphs) : nil
      end
    end

    # Get the VDMX table (Vertical Device Metrics)
    def vdmx : Tables::Hinting::Vdmx?
      @vdmx ||= begin
        data = table_data("VDMX")
        data ? Tables::Hinting::Vdmx.parse(data) : nil
      end
    end

    # Check if this is a color font
    def color_font? : Bool
      has_table?("COLR") || has_table?("SVG ") ||
        has_table?("CBDT") || has_table?("sbix")
    end

    # Check if the font has TrueType hinting data
    def has_hinting? : Bool
      has_table?("cvt ") || has_table?("fpgm") || has_table?("prep")
    end

    # Check if the font has gasp table for rasterization hints
    def has_gasp? : Bool
      has_table?("gasp")
    end

    # Get the gasp behavior flags for a given ppem size
    def gasp_behavior(ppem : UInt16) : Tables::Hinting::Gasp::Behavior
      gasp.try(&.behavior(ppem)) || Tables::Hinting::Gasp::Behavior::None
    end

    # Check if gridfitting should be used at a given ppem
    def gasp_gridfit?(ppem : UInt16) : Bool
      gasp.try(&.gridfit?(ppem)) || false
    end

    # Check if grayscale rendering should be used at a given ppem
    def gasp_grayscale?(ppem : UInt16) : Bool
      gasp.try(&.grayscale?(ppem)) || false
    end

    # Get a control value from the CVT table
    def control_value(index : Int32) : Int16?
      cvt.try(&.[index]?)
    end

    # Get the number of control values
    def control_value_count : Int32
      cvt.try(&.size) || 0
    end

    # Check if a glyph scales linearly at a given ppem (from LTSH)
    def glyph_linear_at?(glyph_id : UInt16, ppem : UInt8) : Bool
      ltsh.try(&.linear_at?(glyph_id, ppem)) || false
    end

    # Get pre-computed device width for a glyph at a specific ppem (from hdmx)
    def device_width(glyph_id : UInt16, ppem : UInt8) : UInt8?
      hdmx.try(&.width(glyph_id, ppem))
    end

    # Get vertical device metrics bounds for a given ppem (from VDMX)
    def vdmx_bounds(ppem : UInt16) : Tuple(Int16, Int16)?
      vdmx.try(&.bounds(ppem))
    end

    # Type of color glyph available for a glyph
    enum ColorGlyphType
      # COLR v0 layered color glyphs
      Layered
      # COLR v1 paint graph
      Paint
      # SVG document
      SVG
      # Bitmap (CBDT/CBLC or sbix)
      Bitmap
    end

    # Get the type of color glyph available for a glyph
    def color_glyph_type(glyph_id : UInt16) : ColorGlyphType?
      # Check SVG first (highest quality)
      if svg_table = svg
        return ColorGlyphType::SVG if svg_table.has_svg?(glyph_id)
      end

      # Check COLR
      if colr_table = colr
        if colr_table.v1? && colr_table.has_paint?(glyph_id)
          return ColorGlyphType::Paint
        elsif colr_table.has_layers?(glyph_id)
          return ColorGlyphType::Layered
        end
      end

      # Check bitmaps (CBDT/CBLC)
      if cblc_table = cblc
        cblc_table.available_sizes.each do |ppem|
          return ColorGlyphType::Bitmap if cblc_table.has_bitmap?(glyph_id, ppem)
        end
      end

      # Check sbix
      if sbix_table = sbix
        sbix_table.available_sizes.each do |ppem|
          return ColorGlyphType::Bitmap if sbix_table.has_glyph?(glyph_id, ppem)
        end
      end

      nil
    end

    # Check if a glyph has color data
    def has_color_glyph?(glyph_id : UInt16) : Bool
      color_glyph_type(glyph_id) != nil
    end

    # Get the SVG document for a color glyph
    def color_glyph_svg(glyph_id : UInt16) : String?
      svg.try(&.svg_document(glyph_id))
    end

    # Get the COLR layers for a color glyph (v0)
    def color_glyph_layers(glyph_id : UInt16) : Array(Tables::Color::LayerRecord)?
      colr.try(&.layers(glyph_id))
    end

    # Get the color bitmap for a glyph at a given PPEM size
    # Tries CBDT/CBLC first, then sbix
    def color_glyph_bitmap(glyph_id : UInt16, ppem : UInt8) : Tables::Color::ColorBitmap?
      # Try CBDT/CBLC first
      if cblc_table = cblc
        if cbdt_table = cbdt
          location = cblc_table.glyph_location(glyph_id, ppem)
          if location
            bitmap = cbdt_table.glyph_bitmap(location)
            return bitmap if bitmap
          end
        end
      end

      # Try sbix
      if sbix_table = sbix
        glyph_data = sbix_table.glyph_data(glyph_id, ppem)
        if glyph_data && !glyph_data.dupe?
          # Convert sbix glyph data to ColorBitmap
          return Tables::Color::ColorBitmap.new(
            0_u8, 0_u8, # Width/height not stored in sbix
            glyph_data.origin_offset_x.to_i8,
            glyph_data.origin_offset_y.to_i8,
            0_u8, # Advance not stored in sbix
            glyph_data.png? ? Tables::Color::ImageFormat::SmallMetricsPNG :
              Tables::Color::ImageFormat::SmallMetricsByteAligned,
            glyph_data.data
          )
        end
      end

      nil
    end

    # Get a color from the CPAL palette
    def palette_color(palette_index : Int, entry_index : Int) : Tables::Color::ColorRecord?
      cpal.try(&.color(palette_index, entry_index))
    end

    # Get a color from the default (first) palette
    def palette_color(entry_index : Int) : Tables::Color::ColorRecord?
      cpal.try(&.color(entry_index))
    end

    # Get the advance width delta for a glyph at given variation coordinates.
    # Returns 0.0 if HVAR table is not present or coordinates are nil.
    def advance_width_delta(glyph_id : UInt16, user_coords : Hash(String, Float64)) : Float64
      normalized = normalize_variation_coordinates(user_coords)
      return 0.0 unless normalized
      hvar.try(&.advance_width_delta(glyph_id, normalized)) || 0.0
    end

    # Get the interpolated advance width for a glyph at given variation coordinates.
    # Returns the base advance width if not a variable font or HVAR is missing.
    def interpolated_advance_width(glyph_id : UInt16, user_coords : Hash(String, Float64)) : Int32
      base_width = advance_width(glyph_id)
      delta = advance_width_delta(glyph_id, user_coords)
      (base_width + delta).round.to_i32
    end

    # Get a font-wide metric delta at given variation coordinates.
    # Common metric tags: hasc, hdsc, hlgp, xhgt, cpht, etc.
    # Returns 0.0 if MVAR table is not present or the metric tag is not found.
    def metric_delta(tag : String, user_coords : Hash(String, Float64)) : Float64
      normalized = normalize_variation_coordinates(user_coords)
      return 0.0 unless normalized
      mvar.try(&.metric_delta(tag, normalized)) || 0.0
    end

    # Get the interpolated ascender at given variation coordinates.
    def interpolated_ascender(user_coords : Hash(String, Float64)) : Int16
      base = ascender
      delta = metric_delta("hasc", user_coords)
      (base + delta).round.to_i16
    end

    # Get the interpolated descender at given variation coordinates.
    def interpolated_descender(user_coords : Hash(String, Float64)) : Int16
      base = descender
      delta = metric_delta("hdsc", user_coords)
      (base + delta).round.to_i16
    end

    # Get the interpolated x-height at given variation coordinates.
    def interpolated_x_height(user_coords : Hash(String, Float64)) : Int16?
      base = os2.try(&.sx_height)
      return nil unless base
      delta = metric_delta("xhgt", user_coords)
      (base + delta).round.to_i16
    end

    # Get the interpolated cap height at given variation coordinates.
    def interpolated_cap_height(user_coords : Hash(String, Float64)) : Int16
      base = cap_height
      delta = metric_delta("cpht", user_coords)
      (base + delta).round.to_i16
    end

    # Get a glyph outline with variation deltas applied.
    # Returns the base outline if not a variable font or glyph has no variations.
    def interpolated_glyph_outline(glyph_id : UInt16, user_coords : Hash(String, Float64)) : GlyphOutline?
      # Get base outline
      base_outline = glyph_outline(glyph_id)
      return nil unless base_outline
      return base_outline unless variable_font?

      # Normalize coordinates
      normalized = normalize_variation_coordinates(user_coords)
      return base_outline unless normalized

      # Get gvar table
      gvar_table = gvar
      return base_outline unless gvar_table

      # Check if glyph has variations
      return base_outline unless gvar_table.has_variation_data?(glyph_id)

      # Count total points across all contours
      point_count = base_outline.point_count
      return base_outline if point_count == 0

      # Compute deltas
      deltas = gvar_table.compute_glyph_deltas(glyph_id, normalized, point_count)
      return base_outline unless deltas
      return base_outline unless deltas.any_nonzero?

      # Apply deltas to create new outline
      apply_deltas_to_outline(base_outline, deltas)
    end

    # Apply computed deltas to a glyph outline, returning a new interpolated outline.
    private def apply_deltas_to_outline(
      outline : GlyphOutline,
      deltas : Tables::Variations::Gvar::GlyphDeltas
    ) : GlyphOutline
      new_contours = [] of Contour
      point_idx = 0

      outline.contours.each do |contour|
        new_points = [] of OutlinePoint

        contour.points.each do |point|
          if point_idx < deltas.size
            new_x = (point.x + deltas.x_deltas[point_idx]).round.to_i16
            new_y = (point.y + deltas.y_deltas[point_idx]).round.to_i16
            new_points << OutlinePoint.new(new_x, new_y, point.type)
          else
            new_points << point
          end
          point_idx += 1
        end

        new_contours << Contour.new(new_points)
      end

      # Recalculate bounding box
      all_points = new_contours.flat_map(&.points)
      if all_points.empty?
        GlyphOutline.new(new_contours, 0_i16, 0_i16, 0_i16, 0_i16, outline.composite?)
      else
        x_min = all_points.min_of(&.x)
        y_min = all_points.min_of(&.y)
        x_max = all_points.max_of(&.x)
        y_max = all_points.max_of(&.y)
        GlyphOutline.new(new_contours, x_min, y_min, x_max, y_max, outline.composite?)
      end
    end

    # Create a new VariationInstance for this font.
    # Returns a VariationInstance initialized with default axis values.
    # For non-variable fonts, returns an instance that behaves like the static font.
    def variation_instance : VariationInstance
      VariationInstance.new(self)
    end

    # Create a VariationInstance from a named instance.
    # Returns nil if the index is out of range.
    def variation_instance(named_instance_index : Int32) : VariationInstance?
      VariationInstance.from_named_instance(self, named_instance_index)
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
