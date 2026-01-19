module TrueType
  module Tables
    module Color
      # RGBA color record (stored as BGRA in font file)
      struct ColorRecord
        # Red component (0-255)
        getter red : UInt8

        # Green component (0-255)
        getter green : UInt8

        # Blue component (0-255)
        getter blue : UInt8

        # Alpha component (0=transparent, 255=opaque)
        getter alpha : UInt8

        def initialize(@red : UInt8, @green : UInt8, @blue : UInt8, @alpha : UInt8)
        end

        # Returns the color as a 32-bit RGBA value
        def to_rgba : UInt32
          (@red.to_u32 << 24) | (@green.to_u32 << 16) | (@blue.to_u32 << 8) | @alpha.to_u32
        end

        # Returns the color as a 32-bit ARGB value
        def to_argb : UInt32
          (@alpha.to_u32 << 24) | (@red.to_u32 << 16) | (@green.to_u32 << 8) | @blue.to_u32
        end

        # Returns the color as a CSS hex string (#RRGGBB or #RRGGBBAA)
        def to_hex : String
          if @alpha == 255
            "#%02x%02x%02x" % {@red, @green, @blue}
          else
            "#%02x%02x%02x%02x" % {@red, @green, @blue, @alpha}
          end
        end

        # Returns the color as CSS rgba() function
        def to_css : String
          if @alpha == 255
            "rgb(#{@red}, #{@green}, #{@blue})"
          else
            "rgba(#{@red}, #{@green}, #{@blue}, #{@alpha / 255.0})"
          end
        end

        # Foreground color placeholder (0xFFFF in palette index means use foreground)
        def self.foreground : ColorRecord
          new(0_u8, 0_u8, 0_u8, 255_u8)
        end
      end

      # Palette type flags (CPAL v1)
      @[Flags]
      enum PaletteType : UInt32
        # Palette is appropriate for use when displaying on a light background
        UsableWithLightBackground = 0x0001
        # Palette is appropriate for use when displaying on a dark background
        UsableWithDarkBackground = 0x0002
      end

      # The 'CPAL' table contains color palettes used by COLR table.
      # Each palette contains the same number of color entries.
      class CPAL
        include IOHelpers

        # Table version (0 or 1)
        getter version : UInt16

        # Number of color entries in each palette
        getter num_palette_entries : UInt16

        # Number of palettes
        getter num_palettes : UInt16

        # All color records (shared across palettes)
        getter color_records : Array(ColorRecord)

        # Starting index for each palette into color_records
        getter color_record_indices : Array(UInt16)

        # Palette types (v1 only, nil for v0)
        getter palette_types : Array(PaletteType)?

        # Palette label name IDs (v1 only, nil for v0)
        # Points to name table entries
        getter palette_labels : Array(UInt16)?

        # Palette entry label name IDs (v1 only, nil for v0)
        # Points to name table entries for each color entry
        getter palette_entry_labels : Array(UInt16)?

        def initialize(
          @version : UInt16,
          @num_palette_entries : UInt16,
          @num_palettes : UInt16,
          @color_records : Array(ColorRecord),
          @color_record_indices : Array(UInt16),
          @palette_types : Array(PaletteType)? = nil,
          @palette_labels : Array(UInt16)? = nil,
          @palette_entry_labels : Array(UInt16)? = nil
        )
        end

        # Parse CPAL table from raw bytes
        def self.parse(data : Bytes) : CPAL
          io = IO::Memory.new(data)

          version = read_uint16(io)
          num_palette_entries = read_uint16(io)
          num_palettes = read_uint16(io)
          num_color_records = read_uint16(io)
          color_records_offset = read_uint32(io)

          # Read color record indices for each palette
          color_record_indices = Array(UInt16).new(num_palettes.to_i)
          num_palettes.times do
            color_record_indices << read_uint16(io)
          end

          # Version 1 has additional offsets
          palette_types_offset = 0_u32
          palette_labels_offset = 0_u32
          palette_entry_labels_offset = 0_u32

          if version >= 1
            palette_types_offset = read_uint32(io)
            palette_labels_offset = read_uint32(io)
            palette_entry_labels_offset = read_uint32(io)
          end

          # Read color records (BGRA format)
          io.seek(color_records_offset.to_i)
          color_records = Array(ColorRecord).new(num_color_records.to_i)
          num_color_records.times do
            blue = read_uint8(io)
            green = read_uint8(io)
            red = read_uint8(io)
            alpha = read_uint8(io)
            color_records << ColorRecord.new(red, green, blue, alpha)
          end

          # Parse v1 extensions
          palette_types : Array(PaletteType)? = nil
          palette_labels : Array(UInt16)? = nil
          palette_entry_labels : Array(UInt16)? = nil

          if version >= 1
            # Palette types
            if palette_types_offset > 0
              io.seek(palette_types_offset.to_i)
              palette_types = Array(PaletteType).new(num_palettes.to_i)
              num_palettes.times do
                palette_types << PaletteType.new(read_uint32(io))
              end
            end

            # Palette labels
            if palette_labels_offset > 0
              io.seek(palette_labels_offset.to_i)
              palette_labels = Array(UInt16).new(num_palettes.to_i)
              num_palettes.times do
                palette_labels << read_uint16(io)
              end
            end

            # Palette entry labels
            if palette_entry_labels_offset > 0
              io.seek(palette_entry_labels_offset.to_i)
              palette_entry_labels = Array(UInt16).new(num_palette_entries.to_i)
              num_palette_entries.times do
                palette_entry_labels << read_uint16(io)
              end
            end
          end

          new(
            version,
            num_palette_entries,
            num_palettes,
            color_records,
            color_record_indices,
            palette_types,
            palette_labels,
            palette_entry_labels
          )
        end

        # Get a color from a specific palette
        # Returns nil if palette or entry index is out of range
        def color(palette_index : Int, entry_index : Int) : ColorRecord?
          return nil if palette_index < 0 || palette_index >= @num_palettes
          return nil if entry_index < 0 || entry_index >= @num_palette_entries

          base_index = @color_record_indices[palette_index].to_i
          color_index = base_index + entry_index

          return nil if color_index >= @color_records.size
          @color_records[color_index]
        end

        # Get a color from the first (default) palette
        def color(entry_index : Int) : ColorRecord?
          color(0, entry_index)
        end

        # Get all colors in a palette
        def palette(palette_index : Int) : Array(ColorRecord)?
          return nil if palette_index < 0 || palette_index >= @num_palettes

          base_index = @color_record_indices[palette_index].to_i
          result = Array(ColorRecord).new(@num_palette_entries.to_i)

          @num_palette_entries.times do |i|
            idx = base_index + i
            break if idx >= @color_records.size
            result << @color_records[idx]
          end

          result
        end

        # Get the default (first) palette
        def default_palette : Array(ColorRecord)
          palette(0) || [] of ColorRecord
        end

        # Get palette type flags (v1 only)
        def palette_type(palette_index : Int) : PaletteType?
          @palette_types.try(&.[palette_index]?)
        end

        # Check if palette is suitable for light backgrounds
        def usable_with_light_background?(palette_index : Int) : Bool
          palette_type(palette_index).try(&.usable_with_light_background?) || false
        end

        # Check if palette is suitable for dark backgrounds
        def usable_with_dark_background?(palette_index : Int) : Bool
          palette_type(palette_index).try(&.usable_with_dark_background?) || false
        end

        # Total number of color records
        def total_colors : Int32
          @color_records.size
        end

        # Iterate over all palettes
        def each_palette(&)
          @num_palettes.times do |i|
            if pal = palette(i)
              yield i, pal
            end
          end
        end

        extend IOHelpers
      end
    end
  end
end
