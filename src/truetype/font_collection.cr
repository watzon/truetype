module TrueType
  # TTC/OTC Header structure
  struct FontCollectionHeader
    include IOHelpers

    # TTC tag ('ttcf')
    getter ttc_tag : String

    # Major version (1 or 2)
    getter major_version : UInt16

    # Minor version
    getter minor_version : UInt16

    # Number of fonts in collection
    getter num_fonts : UInt32

    # Offsets to each font's OffsetTable
    getter offset_table_offsets : Array(UInt32)

    # DSIG tag (version 2+ only)
    getter dsig_tag : UInt32?

    # DSIG table length (version 2+ only)
    getter dsig_length : UInt32?

    # DSIG table offset (version 2+ only)
    getter dsig_offset : UInt32?

    def initialize(
      @ttc_tag : String,
      @major_version : UInt16,
      @minor_version : UInt16,
      @num_fonts : UInt32,
      @offset_table_offsets : Array(UInt32),
      @dsig_tag : UInt32? = nil,
      @dsig_length : UInt32? = nil,
      @dsig_offset : UInt32? = nil,
    )
    end

    # Parse header from bytes
    def self.parse(data : Bytes) : FontCollectionHeader
      io = IO::Memory.new(data)
      parse(io)
    end

    # Parse header from IO
    def self.parse(io : IO) : FontCollectionHeader
      begin
        ttc_tag = read_tag(io)
      rescue ex : IO::EOFError
        raise ParseError.new("Invalid font collection: data too small")
      end

      unless ttc_tag == "ttcf"
        raise ParseError.new("Invalid TTC tag: #{ttc_tag}")
      end

      begin
        major_version = read_uint16(io)
        minor_version = read_uint16(io)
        num_fonts = read_uint32(io)
      rescue ex : IO::EOFError
        raise ParseError.new("Invalid font collection: header truncated")
      end

      offset_table_offsets = Array(UInt32).new(num_fonts.to_i)
      num_fonts.times do
        offset_table_offsets << read_uint32(io)
      end

      dsig_tag = nil
      dsig_length = nil
      dsig_offset = nil

      if major_version >= 2
        dsig_tag = read_uint32(io)
        dsig_length = read_uint32(io)
        dsig_offset = read_uint32(io)
      end

      new(
        ttc_tag, major_version, minor_version, num_fonts,
        offset_table_offsets, dsig_tag, dsig_length, dsig_offset
      )
    end

    extend IOHelpers
  end

  # Represents a TTC (TrueType Collection) or OTC (OpenType Collection) file
  # containing multiple fonts that may share table data.
  class FontCollection
    include IOHelpers

    # Raw collection data
    getter data : Bytes

    # Collection header
    getter header : FontCollectionHeader

    # Cached parsers for each font
    @fonts : Array(Parser?)

    def initialize(@data : Bytes, @header : FontCollectionHeader)
      @fonts = Array(Parser?).new(@header.num_fonts.to_i, nil)
    end

    # Parse a font collection from file path
    def self.parse(path : String) : FontCollection
      parse(File.read(path).to_slice)
    end

    # Parse a font collection from bytes
    def self.parse(data : Bytes) : FontCollection
      raise ParseError.new("Font collection data is too small") if data.size < 12

      header = FontCollectionHeader.parse(data)
      new(data, header)
    end

    # Check if data appears to be a font collection
    def self.collection?(data : Bytes) : Bool
      return false if data.size < 4
      String.new(data[0, 4]) == "ttcf"
    end

    # Check if file appears to be a font collection
    def self.collection?(path : String) : Bool
      File.open(path, "rb") do |file|
        tag = Bytes.new(4)
        return false if file.read(tag) < 4
        String.new(tag) == "ttcf"
      end
    rescue
      false
    end

    # Get the number of fonts in the collection
    def size : Int32
      @header.num_fonts.to_i
    end

    # Check if collection is empty
    def empty? : Bool
      size == 0
    end

    # Get font at index
    def [](index : Int32) : Parser
      font(index)
    end

    # Get font at index or nil
    def []?(index : Int32) : Parser?
      return nil if index < 0 || index >= size
      font(index)
    end

    # Get font by index (cached)
    def font(index : Int32) : Parser
      raise IndexError.new("Font index out of range: #{index}") if index < 0 || index >= size

      @fonts[index] ||= begin
        offset = @header.offset_table_offsets[index]
        parse_font_at_offset(offset)
      end
    end

    # Iterate over all fonts
    def each(& : Parser ->)
      size.times do |i|
        yield font(i)
      end
    end

    # Iterate over all fonts with index
    def each_with_index(& : Parser, Int32 ->)
      size.times do |i|
        yield font(i), i
      end
    end

    # Map over all fonts
    def map(& : Parser -> T) : Array(T) forall T
      result = Array(T).new(size)
      each { |f| result << yield f }
      result
    end

    # Get font names
    def font_names : Array(String)
      map(&.postscript_name)
    end

    # Get font family names
    def family_names : Array(String)
      map(&.family_name)
    end

    # Find font by name (case-insensitive match on PostScript name or family name)
    def find_by_name(name : String) : Parser?
      name_lower = name.downcase
      size.times do |i|
        f = font(i)
        if f.postscript_name.downcase == name_lower || f.family_name.downcase == name_lower
          return f
        end
      end
      nil
    end

    # Check if collection has DSIG (digital signature)
    def has_dsig? : Bool
      @header.dsig_tag == 0x44534947 # 'DSIG'
    end

    private def parse_font_at_offset(offset : UInt32) : Parser
      raise ParseError.new("Font offset out of range") if offset >= @data.size

      io = IO::Memory.new(@data)
      io.seek(offset.to_i64)

      # Read sfnt version
      sfnt_version = read_uint32(io)

      # Validate sfnt version
      unless Parser.valid_sfnt_version?(sfnt_version)
        raise ParseError.new("Invalid sfnt version at offset #{offset}: 0x#{sfnt_version.to_s(16)}")
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

      # Create parser with shared data
      Parser.new(@data, table_records, sfnt_version)
    end

    extend IOHelpers
  end
end
