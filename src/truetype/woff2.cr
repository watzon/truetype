require "brotli"

module TrueType
  # WOFF2 table directory entry
  struct Woff2TableEntry
    include IOHelpers

    # Table flags (includes tag for known tables)
    getter flags : UInt8

    # Custom tag (if flags & 0x3F == 63)
    getter tag : String?

    # Original (uncompressed) length
    getter orig_length : UInt32

    # Transform length (for transformed tables)
    getter transform_length : UInt32?

    def initialize(@flags : UInt8, @tag : String?, @orig_length : UInt32, @transform_length : UInt32?)
    end

    # Get the table tag
    def table_tag : String
      if t = @tag
        t
      else
        KNOWN_TAGS[@flags & 0x3F]? || "????"
      end
    end

    # Check if table has transform
    def transformed? : Bool
      # Transform version is in bits 6-7
      transform_version = (@flags >> 6) & 0x03
      transform_version != 3 # 3 means no transform
    end

    # Known table tags (index 0-62)
    KNOWN_TAGS = [
      "cmap", "head", "hhea", "hmtx", "maxp", "name", "OS/2", "post",
      "cvt ", "fpgm", "glyf", "loca", "prep", "CFF ", "VORG", "EBDT",
      "EBLC", "gasp", "hdmx", "kern", "LTSH", "PCLT", "VDMX", "vhea",
      "vmtx", "BASE", "GDEF", "GPOS", "GSUB", "EBSC", "JSTF", "MATH",
      "CBDT", "CBLC", "COLR", "CPAL", "SVG ", "sbix", "acnt", "avar",
      "bdat", "bloc", "bsln", "cvar", "fdsc", "feat", "fmtx", "fvar",
      "gvar", "hsty", "just", "lcar", "mort", "morx", "opbd", "prop",
      "trak", "Zapf", "Silf", "Glat", "Gloc", "Feat", "Sill",
    ]

    extend IOHelpers
  end

  # WOFF2 file header
  struct Woff2Header
    include IOHelpers

    WOFF2_SIGNATURE = 0x774F4632_u32 # 'wOF2'

    getter signature : UInt32
    getter flavor : UInt32
    getter length : UInt32
    getter num_tables : UInt16
    getter reserved : UInt16
    getter total_sfnt_size : UInt32
    getter total_compressed_size : UInt32
    getter major_version : UInt16
    getter minor_version : UInt16
    getter meta_offset : UInt32
    getter meta_length : UInt32
    getter meta_orig_length : UInt32
    getter priv_offset : UInt32
    getter priv_length : UInt32

    def initialize(
      @signature : UInt32,
      @flavor : UInt32,
      @length : UInt32,
      @num_tables : UInt16,
      @reserved : UInt16,
      @total_sfnt_size : UInt32,
      @total_compressed_size : UInt32,
      @major_version : UInt16,
      @minor_version : UInt16,
      @meta_offset : UInt32,
      @meta_length : UInt32,
      @meta_orig_length : UInt32,
      @priv_offset : UInt32,
      @priv_length : UInt32
    )
    end

    def self.parse(io : IO) : Woff2Header
      signature = read_uint32(io)
      flavor = read_uint32(io)
      length = read_uint32(io)
      num_tables = read_uint16(io)
      reserved = read_uint16(io)
      total_sfnt_size = read_uint32(io)
      total_compressed_size = read_uint32(io)
      major_version = read_uint16(io)
      minor_version = read_uint16(io)
      meta_offset = read_uint32(io)
      meta_length = read_uint32(io)
      meta_orig_length = read_uint32(io)
      priv_offset = read_uint32(io)
      priv_length = read_uint32(io)

      new(
        signature, flavor, length, num_tables, reserved,
        total_sfnt_size, total_compressed_size,
        major_version, minor_version,
        meta_offset, meta_length, meta_orig_length,
        priv_offset, priv_length
      )
    end

    def valid? : Bool
      @signature == WOFF2_SIGNATURE
    end

    extend IOHelpers
  end

  # WOFF2 font format parser
  class Woff2
    include IOHelpers

    getter data : Bytes
    getter header : Woff2Header
    getter tables : Array(Woff2TableEntry)

    def initialize(@data : Bytes, @header : Woff2Header, @tables : Array(Woff2TableEntry))
    end

    def self.parse(path : String) : Woff2
      parse(File.read(path).to_slice)
    end

    def self.parse(data : Bytes) : Woff2
      raise ParseError.new("WOFF2 data is too small") if data.size < 48

      io = IO::Memory.new(data)
      header = Woff2Header.parse(io)

      unless header.valid?
        raise ParseError.new("Invalid WOFF2 signature: 0x#{header.signature.to_s(16)}")
      end

      tables = parse_table_directory(io, header.num_tables)
      new(data, header, tables)
    end

    def self.woff2?(data : Bytes) : Bool
      return false if data.size < 4
      io = IO::Memory.new(data)
      sig = read_uint32(io)
      sig == Woff2Header::WOFF2_SIGNATURE
    rescue
      false
    end

    def self.woff2?(path : String) : Bool
      File.open(path, "rb") do |file|
        bytes = Bytes.new(4)
        return false if file.read(bytes) < 4
        woff2?(bytes)
      end
    rescue
      false
    end

    def sfnt_version : UInt32
      @header.flavor
    end

    def truetype? : Bool
      @header.flavor == 0x00010000 || @header.flavor == 0x74727565
    end

    def cff? : Bool
      @header.flavor == 0x4F54544F
    end

    # Convert WOFF2 to standard sfnt format
    def to_sfnt : Bytes
      # Decompress the compressed data stream
      compressed_offset = calculate_compressed_offset
      compressed_data = @data[compressed_offset, @header.total_compressed_size]
      decompressed = decompress_brotli(compressed_data)

      # Reconstruct sfnt from decompressed tables
      reconstruct_sfnt(decompressed)
    end

    def to_parser : Parser
      Parser.parse(to_sfnt)
    end

    private def self.parse_table_directory(io : IO, num_tables : UInt16) : Array(Woff2TableEntry)
      tables = Array(Woff2TableEntry).new(num_tables.to_i)

      num_tables.times do
        flags = read_uint8(io)
        tag_index = flags & 0x3F

        tag = if tag_index == 63
                read_tag(io)
              else
                nil
              end

        orig_length = read_uint_base128(io)

        transform_length = if (flags >> 6) & 0x03 != 3
                             # Has transform
                             read_uint_base128(io)
                           else
                             nil
                           end

        tables << Woff2TableEntry.new(flags, tag, orig_length, transform_length)
      end

      tables
    end

    # Read UIntBase128 variable-length integer
    private def self.read_uint_base128(io : IO) : UInt32
      result = 0_u32
      5.times do
        byte = read_uint8(io)
        result = (result << 7) | (byte & 0x7F).to_u32
        return result if (byte & 0x80) == 0
      end
      raise ParseError.new("Invalid UIntBase128 encoding")
    end

    private def calculate_compressed_offset : Int32
      # Header is 48 bytes
      offset = 48

      # Add table directory size
      @tables.each do |table|
        offset += 1 # flags
        offset += 4 if (table.flags & 0x3F) == 63 # custom tag
        offset += uint_base128_size(table.orig_length)
        if table.transform_length
          offset += uint_base128_size(table.transform_length.not_nil!)
        end
      end

      offset
    end

    private def uint_base128_size(value : UInt32) : Int32
      return 1 if value < 128
      return 2 if value < 16384
      return 3 if value < 2097152
      return 4 if value < 268435456
      5
    end

    private def decompress_brotli(data : Bytes) : Bytes
      Compress::Brotli.decode(data)
    rescue ex
      raise ParseError.new("Brotli decompression failed: #{ex.message}")
    end

    private def reconstruct_sfnt(decompressed : Bytes) : Bytes
      num_tables = @tables.size

      # Calculate sfnt structure sizes
      search_range = (2 ** Math.log2(num_tables).floor.to_i) * 16
      entry_selector = Math.log2(search_range / 16).floor.to_i
      range_shift = (num_tables * 16) - search_range

      header_size = 12 + (num_tables * 16)
      table_start = ((header_size + 3) // 4) * 4

      # Extract table data from decompressed stream
      table_data = extract_tables(decompressed)

      # Calculate offsets
      table_offsets = [] of UInt32
      current_offset = table_start.to_u32
      table_data.each do |data|
        table_offsets << current_offset
        padded_length = ((data.size + 3) // 4) * 4
        current_offset += padded_length.to_u32
      end

      # Build sfnt
      output = IO::Memory.new(current_offset.to_i)

      write_uint32(output, @header.flavor)
      write_uint16(output, num_tables.to_u16)
      write_uint16(output, search_range.to_u16)
      write_uint16(output, entry_selector.to_u16)
      write_uint16(output, range_shift.to_u16)

      # Write table records
      @tables.each_with_index do |table, i|
        output.write(table.table_tag.to_slice)
        write_uint32(output, calculate_checksum(table_data[i]))
        write_uint32(output, table_offsets[i])
        write_uint32(output, table_data[i].size.to_u32)
      end

      # Pad to table start
      while output.pos < table_start
        output.write_byte(0_u8)
      end

      # Write tables
      table_data.each do |data|
        output.write(data)
        padding = (4 - (data.size % 4)) % 4
        padding.times { output.write_byte(0_u8) }
      end

      output.to_slice
    end

    private def extract_tables(decompressed : Bytes) : Array(Bytes)
      result = [] of Bytes
      offset = 0

      @tables.each do |table|
        length = table.transform_length || table.orig_length
        table_bytes = decompressed[offset, length]

        # Handle table transforms
        if table.transformed?
          table_bytes = reverse_transform(table, table_bytes, table.orig_length)
        end

        result << table_bytes
        offset += length.to_i
      end

      result
    end

    private def reverse_transform(table : Woff2TableEntry, data : Bytes, orig_length : UInt32) : Bytes
      tag = table.table_tag

      case tag
      when "glyf", "loca"
        # glyf/loca have special transforms - for now return as-is
        # Full implementation would reconstruct from transformed format
        data
      when "hmtx"
        # hmtx transform - return as-is for now
        data
      else
        data
      end
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
