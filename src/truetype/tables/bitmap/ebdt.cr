module TrueType
  module Tables
    module Bitmap
      # Image format for embedded bitmap data
      enum EmbeddedBitmapFormat : UInt16
        # Format 1: Small metrics, byte-aligned data
        SmallMetricsByteAligned = 1
        # Format 2: Small metrics, bit-aligned data
        SmallMetricsBitAligned = 2
        # Format 5: Metrics in EBLC, bit-aligned data
        MetricsInEBLCBitAligned = 5
        # Format 6: Big metrics, byte-aligned data
        BigMetricsByteAligned = 6
        # Format 7: Big metrics, bit-aligned data
        BigMetricsBitAligned = 7
        # Format 8: Small metrics with component data
        SmallMetricsComponent = 8
        # Format 9: Big metrics with component data
        BigMetricsComponent = 9
      end

      # Embedded bitmap data extracted from EBDT
      struct EmbeddedBitmap
        # Image width in pixels
        getter width : UInt8

        # Image height in pixels
        getter height : UInt8

        # Horizontal bearing X
        getter bearing_x : Int8

        # Horizontal bearing Y
        getter bearing_y : Int8

        # Horizontal advance
        getter advance : UInt8

        # Image format
        getter image_format : EmbeddedBitmapFormat

        # Bit depth (1 = monochrome, 2, 4, or 8 = grayscale)
        getter bit_depth : UInt8

        # Raw bitmap data
        getter data : Bytes

        def initialize(
          @width : UInt8,
          @height : UInt8,
          @bearing_x : Int8,
          @bearing_y : Int8,
          @advance : UInt8,
          @image_format : EmbeddedBitmapFormat,
          @bit_depth : UInt8,
          @data : Bytes
        )
        end

        # Check if this is a monochrome (1-bit) bitmap
        def monochrome? : Bool
          @bit_depth == 1
        end

        # Check if this is a grayscale bitmap
        def grayscale? : Bool
          @bit_depth > 1
        end
      end

      # Component data for composite bitmap glyphs (formats 8/9)
      struct BitmapComponent
        include IOHelpers

        # Component glyph ID
        getter glyph_id : UInt16

        # X offset for placement
        getter x_offset : Int8

        # Y offset for placement
        getter y_offset : Int8

        def initialize(@glyph_id : UInt16, @x_offset : Int8, @y_offset : Int8)
        end

        def self.parse(io : IO) : BitmapComponent
          glyph_id = read_uint16(io)
          x_offset = io.read_byte.not_nil!.to_i8!
          y_offset = io.read_byte.not_nil!.to_i8!
          new(glyph_id, x_offset, y_offset)
        end

        extend IOHelpers
      end

      # The 'EBDT' table (Embedded Bitmap Data) contains the actual bitmap data
      # for embedded bitmap glyphs. Used in conjunction with EBLC for location info.
      # This is the legacy version of CBDT (Color Bitmap Data).
      class EBDT
        include IOHelpers

        # Major version (2 for EBDT)
        getter major_version : UInt16

        # Minor version (0)
        getter minor_version : UInt16

        # Raw table data
        @data : Bytes

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @data : Bytes
        )
        end

        # Parse EBDT table from raw bytes
        def self.parse(data : Bytes) : EBDT
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)

          new(major_version, minor_version, data)
        end

        # Get bitmap data for a glyph given its location info from EBLC
        def glyph_bitmap(location : GlyphBitmapLocation, bit_depth : UInt8 = 1_u8) : EmbeddedBitmap?
          return nil if location.image_data_offset >= @data.size

          io = IO::Memory.new(@data[location.image_data_offset.to_i..])

          format = EmbeddedBitmapFormat.new(location.image_format)

          case format
          when .small_metrics_byte_aligned?, .small_metrics_bit_aligned?
            # Format 1/2: SmallGlyphMetrics + bitmap data
            metrics = SmallGlyphMetrics.parse(io)
            remaining = location.image_data_length.to_i - 5 # 5 bytes for small metrics
            data = Bytes.new(remaining.clamp(0, @data.size))
            io.read_fully(data)

            EmbeddedBitmap.new(
              metrics.width,
              metrics.height,
              metrics.bearing_x,
              metrics.bearing_y,
              metrics.advance,
              format,
              bit_depth,
              data
            )
          when .big_metrics_byte_aligned?, .big_metrics_bit_aligned?
            # Format 6/7: BigGlyphMetrics + bitmap data
            metrics = BigGlyphMetrics.parse(io)
            remaining = location.image_data_length.to_i - 8 # 8 bytes for big metrics
            data = Bytes.new(remaining.clamp(0, @data.size))
            io.read_fully(data)

            EmbeddedBitmap.new(
              metrics.width,
              metrics.height,
              metrics.hori_bearing_x,
              metrics.hori_bearing_y,
              metrics.hori_advance,
              format,
              bit_depth,
              data
            )
          when .metrics_in_eblc_bit_aligned?
            # Format 5: Bitmap data only (metrics from EBLC)
            data = Bytes.new(location.image_data_length.to_i)
            io.read_fully(data)

            metrics = location.metrics
            if metrics
              EmbeddedBitmap.new(
                metrics.width,
                metrics.height,
                metrics.hori_bearing_x,
                metrics.hori_bearing_y,
                metrics.hori_advance,
                format,
                bit_depth,
                data
              )
            else
              EmbeddedBitmap.new(
                0_u8, 0_u8, 0_i8, 0_i8, 0_u8,
                format,
                bit_depth,
                data
              )
            end
          when .small_metrics_component?
            # Format 8: SmallGlyphMetrics + padding + numComponents + components
            # This is a composite glyph - return metrics only, components need separate lookup
            metrics = SmallGlyphMetrics.parse(io)
            _pad = io.read_byte # 1 byte padding
            num_components = read_uint16(io)

            # Skip component data for now (would need recursive lookup)
            # Just return empty bitmap with metrics
            EmbeddedBitmap.new(
              metrics.width,
              metrics.height,
              metrics.bearing_x,
              metrics.bearing_y,
              metrics.advance,
              format,
              bit_depth,
              Bytes.empty
            )
          when .big_metrics_component?
            # Format 9: BigGlyphMetrics + numComponents + components
            # This is a composite glyph
            metrics = BigGlyphMetrics.parse(io)
            num_components = read_uint16(io)

            # Skip component data for now
            EmbeddedBitmap.new(
              metrics.width,
              metrics.height,
              metrics.hori_bearing_x,
              metrics.hori_bearing_y,
              metrics.hori_advance,
              format,
              bit_depth,
              Bytes.empty
            )
          else
            nil
          end
        rescue
          nil
        end

        # Get component data for a composite glyph (formats 8/9)
        def glyph_components(location : GlyphBitmapLocation) : Array(BitmapComponent)?
          return nil if location.image_data_offset >= @data.size

          io = IO::Memory.new(@data[location.image_data_offset.to_i..])

          format = EmbeddedBitmapFormat.new(location.image_format)

          case format
          when .small_metrics_component?
            # Format 8: SmallGlyphMetrics + padding + numComponents + components
            io.skip(6) # 5 bytes metrics + 1 byte padding
            num_components = read_uint16(io)

            components = Array(BitmapComponent).new(num_components.to_i)
            num_components.times do
              components << BitmapComponent.parse(io)
            end
            components
          when .big_metrics_component?
            # Format 9: BigGlyphMetrics + numComponents + components
            io.skip(8) # 8 bytes metrics
            num_components = read_uint16(io)

            components = Array(BitmapComponent).new(num_components.to_i)
            num_components.times do
              components << BitmapComponent.parse(io)
            end
            components
          else
            nil
          end
        rescue
          nil
        end

        extend IOHelpers
      end
    end
  end
end
