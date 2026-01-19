module TrueType
  module Tables
    module Hinting
      # The 'hdmx' (Horizontal Device Metrics) table stores pre-computed
      # integer advance widths for specific ppem sizes.
      #
      # This table allows the text layout engine to build integer width
      # tables without calling the scaler for each glyph, improving
      # rendering performance.
      #
      # Table tag: 'hdmx'
      class Hdmx
        include IOHelpers

        # A single device record containing widths for all glyphs at a ppem
        class DeviceRecord
          include IOHelpers

          # Pixel size for this record (ppem)
          getter pixel_size : UInt8

          # Maximum width in the widths array
          getter max_width : UInt8

          # Array of widths for each glyph (numGlyphs entries)
          getter widths : Array(UInt8)

          def initialize(@pixel_size : UInt8, @max_width : UInt8, @widths : Array(UInt8))
          end

          # Parse a device record from an IO
          def self.parse(io : IO, num_glyphs : UInt16, size_device_record : UInt32) : DeviceRecord
            start_pos = io.pos
            pixel_size = read_uint8(io)
            max_width = read_uint8(io)

            widths = Array(UInt8).new(num_glyphs.to_i) do
              read_uint8(io)
            end

            # Skip padding to 32-bit alignment
            bytes_read = io.pos - start_pos
            padding = size_device_record.to_i - bytes_read
            skip_bytes(io, padding) if padding > 0

            new(pixel_size, max_width, widths)
          end

          # Get the width for a specific glyph
          def width(glyph_id : UInt16) : UInt8?
            @widths[glyph_id.to_i]?
          end

          # Calculate the padded record size for a given number of glyphs
          def self.padded_size(num_glyphs : Int32) : UInt32
            # 2 bytes header + num_glyphs bytes, padded to 4-byte boundary
            size = 2 + num_glyphs
            ((size + 3) & ~3).to_u32
          end

          # Serialize this record to bytes with padding
          def to_bytes(size_device_record : UInt32) : Bytes
            io = IO::Memory.new
            write(io, size_device_record)
            io.to_slice
          end

          # Write this record to an IO with padding
          def write(io : IO, size_device_record : UInt32) : Nil
            start_pos = io.pos
            io.write_byte(@pixel_size)
            io.write_byte(@max_width)
            @widths.each { |w| io.write_byte(w) }

            # Add padding to reach size_device_record
            bytes_written = io.pos - start_pos
            padding = size_device_record.to_i - bytes_written
            padding.times { io.write_byte(0_u8) }
          end

          extend IOHelpers
        end

        # Table version (should be 0)
        getter version : UInt16

        # Number of device records
        getter num_records : UInt16

        # Size of each device record (32-bit aligned)
        getter size_device_record : UInt32

        # Array of device records (sorted by pixel_size)
        getter records : Array(DeviceRecord)

        def initialize(
          @version : UInt16,
          @num_records : UInt16,
          @size_device_record : UInt32,
          @records : Array(DeviceRecord)
        )
        end

        # Parse the hdmx table from raw bytes
        # num_glyphs is required from maxp table
        def self.parse(data : Bytes, num_glyphs : UInt16) : Hdmx
          io = IO::Memory.new(data)
          parse(io, num_glyphs)
        end

        # Parse the hdmx table from an IO
        def self.parse(io : IO, num_glyphs : UInt16) : Hdmx
          version = read_uint16(io)
          num_records = read_uint16(io)
          size_device_record = read_uint32(io)

          records = Array(DeviceRecord).new(num_records.to_i) do
            DeviceRecord.parse(io, num_glyphs, size_device_record)
          end

          new(version, num_records, size_device_record, records)
        end

        # Get a device record for a specific ppem size
        def record(ppem : UInt8) : DeviceRecord?
          @records.find { |r| r.pixel_size == ppem }
        end

        # Get the width of a glyph at a specific ppem size
        def width(glyph_id : UInt16, ppem : UInt8) : UInt8?
          record(ppem).try(&.width(glyph_id))
        end

        # Get all available ppem sizes
        def available_sizes : Array(UInt8)
          @records.map(&.pixel_size)
        end

        # Check if data exists for a specific ppem
        def has_size?(ppem : UInt8) : Bool
          @records.any? { |r| r.pixel_size == ppem }
        end

        # Number of records
        def size : Int32
          @records.size
        end

        # Check if the table is empty
        def empty? : Bool
          @records.empty?
        end

        # Serialize this table to bytes
        def to_bytes : Bytes
          io = IO::Memory.new
          write(io)
          io.to_slice
        end

        # Write this table to an IO
        def write(io : IO) : Nil
          write_uint16(io, @version)
          write_uint16(io, @num_records)
          write_uint32(io, @size_device_record)
          @records.each do |record|
            record.write(io, @size_device_record)
          end
        end

        extend IOHelpers
      end
    end
  end
end
