require "compress/zlib"

module TrueType
  # WOFF table directory entry
  struct WoffTableEntry
    include IOHelpers

    # 4-byte table tag
    getter tag : String

    # Offset to compressed table data (from start of WOFF file)
    getter offset : UInt32

    # Compressed length of table
    getter comp_length : UInt32

    # Uncompressed length of table
    getter orig_length : UInt32

    # Checksum of uncompressed data
    getter orig_checksum : UInt32

    def initialize(@tag : String, @offset : UInt32, @comp_length : UInt32, @orig_length : UInt32, @orig_checksum : UInt32)
    end

    # Parse a table entry from IO
    def self.parse(io : IO) : WoffTableEntry
      tag = read_tag(io)
      offset = read_uint32(io)
      comp_length = read_uint32(io)
      orig_length = read_uint32(io)
      orig_checksum = read_uint32(io)

      new(tag, offset, comp_length, orig_length, orig_checksum)
    end

    # Check if table is compressed
    def compressed? : Bool
      @comp_length != @orig_length
    end

    extend IOHelpers
  end

  # WOFF file header
  struct WoffHeader
    include IOHelpers

    # WOFF signature (0x774F4646 = 'wOFF')
    getter signature : UInt32

    # The sfnt version of the original font
    getter flavor : UInt32

    # Total size of the WOFF file
    getter length : UInt32

    # Number of tables
    getter num_tables : UInt16

    # Reserved (should be 0)
    getter reserved : UInt16

    # Total size of uncompressed font data
    getter total_sfnt_size : UInt32

    # Major version of WOFF
    getter major_version : UInt16

    # Minor version of WOFF
    getter minor_version : UInt16

    # Offset to metadata block (0 if none)
    getter meta_offset : UInt32

    # Compressed size of metadata block
    getter meta_length : UInt32

    # Uncompressed size of metadata block
    getter meta_orig_length : UInt32

    # Offset to private data block (0 if none)
    getter priv_offset : UInt32

    # Size of private data block
    getter priv_length : UInt32

    WOFF_SIGNATURE = 0x774F4646_u32

    def initialize(
      @signature : UInt32,
      @flavor : UInt32,
      @length : UInt32,
      @num_tables : UInt16,
      @reserved : UInt16,
      @total_sfnt_size : UInt32,
      @major_version : UInt16,
      @minor_version : UInt16,
      @meta_offset : UInt32,
      @meta_length : UInt32,
      @meta_orig_length : UInt32,
      @priv_offset : UInt32,
      @priv_length : UInt32,
    )
    end

    # Parse header from IO
    def self.parse(io : IO) : WoffHeader
      signature = read_uint32(io)
      flavor = read_uint32(io)
      length = read_uint32(io)
      num_tables = read_uint16(io)
      reserved = read_uint16(io)
      total_sfnt_size = read_uint32(io)
      major_version = read_uint16(io)
      minor_version = read_uint16(io)
      meta_offset = read_uint32(io)
      meta_length = read_uint32(io)
      meta_orig_length = read_uint32(io)
      priv_offset = read_uint32(io)
      priv_length = read_uint32(io)

      new(
        signature, flavor, length, num_tables, reserved, total_sfnt_size,
        major_version, minor_version, meta_offset, meta_length, meta_orig_length,
        priv_offset, priv_length
      )
    end

    # Check if this is a valid WOFF signature
    def valid? : Bool
      @signature == WOFF_SIGNATURE
    end

    # Check if this has metadata
    def has_metadata? : Bool
      @meta_offset > 0 && @meta_length > 0
    end

    # Check if this has private data
    def has_private_data? : Bool
      @priv_offset > 0 && @priv_length > 0
    end

    extend IOHelpers
  end

  # WOFF font format parser
  # Converts WOFF to standard TrueType/OpenType data
  class Woff
    include IOHelpers

    # Original WOFF data
    getter data : Bytes

    # Parsed header
    getter header : WoffHeader

    # Table entries
    getter tables : Array(WoffTableEntry)

    # Decompressed metadata (XML)
    @metadata : String?

    def initialize(@data : Bytes, @header : WoffHeader, @tables : Array(WoffTableEntry))
    end

    # Parse WOFF file from path
    def self.parse(path : String) : Woff
      parse(File.read(path).to_slice)
    end

    # Parse WOFF file from bytes
    def self.parse(data : Bytes) : Woff
      raise ParseError.new("WOFF data is too small") if data.size < 44

      io = IO::Memory.new(data)
      header = WoffHeader.parse(io)

      unless header.valid?
        raise ParseError.new("Invalid WOFF signature: 0x#{header.signature.to_s(16)}")
      end

      tables = Array(WoffTableEntry).new(header.num_tables.to_i)
      header.num_tables.times do
        tables << WoffTableEntry.parse(io)
      end

      new(data, header, tables)
    end

    # Check if data appears to be WOFF
    def self.woff?(data : Bytes) : Bool
      return false if data.size < 4
      io = IO::Memory.new(data)
      sig = read_uint32(io)
      sig == WoffHeader::WOFF_SIGNATURE
    rescue
      false
    end

    # Check if file appears to be WOFF
    def self.woff?(path : String) : Bool
      File.open(path, "rb") do |file|
        bytes = Bytes.new(4)
        return false if file.read(bytes) < 4
        woff?(bytes)
      end
    rescue
      false
    end

    # Get the sfnt version (TrueType or CFF)
    def sfnt_version : UInt32
      @header.flavor
    end

    # Check if this is TrueType flavor
    def truetype? : Bool
      @header.flavor == 0x00010000 || @header.flavor == 0x74727565
    end

    # Check if this is CFF flavor
    def cff? : Bool
      @header.flavor == 0x4F54544F # 'OTTO'
    end

    # Get table data (decompressed if needed)
    def table_data(tag : String) : Bytes?
      entry = @tables.find { |t| t.tag == tag }
      return nil unless entry

      decompress_table(entry)
    end

    # Decompress table data
    private def decompress_table(entry : WoffTableEntry) : Bytes
      raw = @data[entry.offset, entry.comp_length]

      if entry.compressed?
        # Decompress using zlib
        output = IO::Memory.new(entry.orig_length.to_i)
        Compress::Zlib::Reader.open(IO::Memory.new(raw)) do |reader|
          IO.copy(reader, output)
        end
        output.to_slice
      else
        raw.dup
      end
    rescue ex
      raise ParseError.new("Failed to decompress table #{entry.tag}: #{ex.message}")
    end

    # Get metadata (decompressed XML)
    def metadata : String?
      return @metadata if @metadata
      return nil unless @header.has_metadata?

      raw = @data[@header.meta_offset, @header.meta_length]

      if @header.meta_length != @header.meta_orig_length
        # Decompress
        output = IO::Memory.new(@header.meta_orig_length.to_i)
        Compress::Zlib::Reader.open(IO::Memory.new(raw)) do |reader|
          IO.copy(reader, output)
        end
        @metadata = String.new(output.to_slice)
      else
        @metadata = String.new(raw)
      end

      @metadata
    rescue
      nil
    end

    # Get private data
    def private_data : Bytes?
      return nil unless @header.has_private_data?
      @data[@header.priv_offset, @header.priv_length].dup
    end

    # Convert WOFF to standard TrueType/OpenType format
    def to_sfnt : Bytes
      num_tables = @tables.size

      # Calculate table sizes for sfnt
      search_range = (2 ** Math.log2(num_tables).floor.to_i) * 16
      entry_selector = Math.log2(search_range / 16).floor.to_i
      range_shift = (num_tables * 16) - search_range

      # Calculate header size and offsets
      header_size = 12 + (num_tables * 16)
      table_start = ((header_size + 3) // 4) * 4

      # Decompress all tables and calculate offsets
      decompressed_tables = @tables.map { |t| {t, decompress_table(t)} }

      table_offsets = [] of UInt32
      current_offset = table_start.to_u32
      decompressed_tables.each do |_, data|
        table_offsets << current_offset
        padded_length = ((data.size + 3) // 4) * 4
        current_offset += padded_length.to_u32
      end

      # Build sfnt
      output = IO::Memory.new(current_offset.to_i)

      # Write header
      write_uint32(output, @header.flavor)
      write_uint16(output, num_tables.to_u16)
      write_uint16(output, search_range.to_u16)
      write_uint16(output, entry_selector.to_u16)
      write_uint16(output, range_shift.to_u16)

      # Write table records
      decompressed_tables.each_with_index do |(entry, data), i|
        output.write(entry.tag.to_slice)
        write_uint32(output, calculate_checksum(data))
        write_uint32(output, table_offsets[i])
        write_uint32(output, data.size.to_u32)
      end

      # Pad to table start
      while output.pos < table_start
        output.write_byte(0_u8)
      end

      # Write tables
      decompressed_tables.each do |_, data|
        output.write(data)
        # Pad to 4-byte boundary
        padding = (4 - (data.size % 4)) % 4
        padding.times { output.write_byte(0_u8) }
      end

      output.to_slice
    end

    # Convert to Parser
    def to_parser : Parser
      Parser.parse(to_sfnt)
    end

    private def calculate_checksum(data : Bytes) : UInt32
      sum = 0_u32
      i = 0
      while i < data.size
        value = 0_u32
        4.times do |j|
          value <<= 8
          value |= (data[i + j]? || 0_u8).to_u32
        end
        sum &+= value
        i += 4
      end
      sum
    end

    extend IOHelpers
  end
end
