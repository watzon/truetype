module TrueType
  module Tables
    module Color
      # Special palette index indicating foreground color should be used
      FOREGROUND_COLOR_INDEX = 0xFFFF_u16

      # Layer record for COLR v0
      struct LayerRecord
        # Glyph ID for this layer
        getter glyph_id : UInt16

        # Palette entry index (0xFFFF = foreground color)
        getter palette_index : UInt16

        def initialize(@glyph_id : UInt16, @palette_index : UInt16)
        end

        # Check if this layer uses the foreground color
        def foreground? : Bool
          @palette_index == FOREGROUND_COLOR_INDEX
        end
      end

      # Base glyph record for COLR v0
      struct BaseGlyphRecord
        # Glyph ID of the base glyph
        getter glyph_id : UInt16

        # Index of first layer record
        getter first_layer_index : UInt16

        # Number of layers for this glyph
        getter num_layers : UInt16

        def initialize(@glyph_id : UInt16, @first_layer_index : UInt16, @num_layers : UInt16)
        end
      end

      # The 'COLR' table defines color glyphs using layered colored glyphs (v0)
      # or a paint graph with gradients and transforms (v1).
      class COLR
        include IOHelpers

        # Table version (0 or 1)
        getter version : UInt16

        # Base glyph records (v0)
        getter base_glyph_records : Array(BaseGlyphRecord)

        # Layer records (v0)
        getter layer_records : Array(LayerRecord)

        # Raw table data (for v1 paint parsing)
        @data : Bytes

        # V1 offsets
        @base_glyph_list_offset : UInt32
        @layer_list_offset : UInt32
        @clip_list_offset : UInt32
        @var_index_map_offset : UInt32
        @item_variation_store_offset : UInt32

        def initialize(
          @version : UInt16,
          @base_glyph_records : Array(BaseGlyphRecord),
          @layer_records : Array(LayerRecord),
          @data : Bytes,
          @base_glyph_list_offset : UInt32 = 0,
          @layer_list_offset : UInt32 = 0,
          @clip_list_offset : UInt32 = 0,
          @var_index_map_offset : UInt32 = 0,
          @item_variation_store_offset : UInt32 = 0
        )
        end

        # Parse COLR table from raw bytes
        def self.parse(data : Bytes) : COLR
          io = IO::Memory.new(data)

          version = read_uint16(io)
          num_base_glyph_records = read_uint16(io)
          base_glyph_records_offset = read_uint32(io)
          layer_records_offset = read_uint32(io)
          num_layer_records = read_uint16(io)

          # V1 additional fields
          base_glyph_list_offset = 0_u32
          layer_list_offset = 0_u32
          clip_list_offset = 0_u32
          var_index_map_offset = 0_u32
          item_variation_store_offset = 0_u32

          if version >= 1
            base_glyph_list_offset = read_uint32(io)
            layer_list_offset = read_uint32(io)
            clip_list_offset = read_uint32(io)
            var_index_map_offset = read_uint32(io)
            item_variation_store_offset = read_uint32(io)
          end

          # Parse v0 base glyph records
          base_glyph_records = Array(BaseGlyphRecord).new(num_base_glyph_records.to_i)
          if base_glyph_records_offset > 0 && num_base_glyph_records > 0
            io.seek(base_glyph_records_offset.to_i)
            num_base_glyph_records.times do
              glyph_id = read_uint16(io)
              first_layer_index = read_uint16(io)
              num_layers = read_uint16(io)
              base_glyph_records << BaseGlyphRecord.new(glyph_id, first_layer_index, num_layers)
            end
          end

          # Parse v0 layer records
          layer_records = Array(LayerRecord).new(num_layer_records.to_i)
          if layer_records_offset > 0 && num_layer_records > 0
            io.seek(layer_records_offset.to_i)
            num_layer_records.times do
              glyph_id = read_uint16(io)
              palette_index = read_uint16(io)
              layer_records << LayerRecord.new(glyph_id, palette_index)
            end
          end

          new(
            version,
            base_glyph_records,
            layer_records,
            data,
            base_glyph_list_offset,
            layer_list_offset,
            clip_list_offset,
            var_index_map_offset,
            item_variation_store_offset
          )
        end

        # Check if this is a v1 COLR table
        def v1? : Bool
          @version >= 1
        end

        # Check if a glyph has color layers (v0)
        def has_layers?(glyph_id : UInt16) : Bool
          find_base_glyph(glyph_id) != nil
        end

        # Get the layers for a glyph (v0)
        # Returns nil if glyph has no color layers
        def layers(glyph_id : UInt16) : Array(LayerRecord)?
          base = find_base_glyph(glyph_id)
          return nil unless base

          result = Array(LayerRecord).new(base.num_layers.to_i)
          base.num_layers.times do |i|
            idx = base.first_layer_index.to_i + i
            break if idx >= @layer_records.size
            result << @layer_records[idx]
          end
          result
        end

        # Get the number of layers for a glyph
        def layer_count(glyph_id : UInt16) : Int32
          find_base_glyph(glyph_id).try(&.num_layers.to_i) || 0
        end

        # Check if glyph has v1 paint data
        def has_paint?(glyph_id : UInt16) : Bool
          return false unless v1?
          return false if @base_glyph_list_offset == 0

          # Search the v1 base glyph list
          find_v1_base_glyph(glyph_id) != nil
        end

        # Check if a glyph has any color data (v0 layers or v1 paint)
        def has_color_glyph?(glyph_id : UInt16) : Bool
          has_layers?(glyph_id) || has_paint?(glyph_id)
        end

        # Get all glyph IDs that have color data
        def color_glyph_ids : Array(UInt16)
          result = Set(UInt16).new

          # V0 base glyphs
          @base_glyph_records.each do |record|
            result << record.glyph_id
          end

          # V1 base glyphs
          if v1? && @base_glyph_list_offset > 0
            each_v1_base_glyph do |glyph_id, _|
              result << glyph_id
            end
          end

          result.to_a.sort
        end

        # Number of base glyphs with color data
        def base_glyph_count : Int32
          count = @base_glyph_records.size

          if v1? && @base_glyph_list_offset > 0
            io = IO::Memory.new(@data[@base_glyph_list_offset.to_i..])
            count += read_uint32(io).to_i
          end

          count
        end

        # Get the paint offset for a v1 glyph
        # Returns nil if not found
        def paint_offset(glyph_id : UInt16) : UInt32?
          return nil unless v1?
          find_v1_base_glyph(glyph_id)
        end

        # Get a paint table reader at the given offset
        # Used by Paint classes to navigate the paint graph
        def paint_reader(offset : UInt32) : IO::Memory?
          return nil if offset == 0 || offset >= @data.size
          IO::Memory.new(@data[offset.to_i..])
        end

        # Iterate over v1 base glyphs (glyph_id, paint_offset)
        private def each_v1_base_glyph(&)
          return unless v1?
          return if @base_glyph_list_offset == 0

          io = IO::Memory.new(@data[@base_glyph_list_offset.to_i..])
          count = read_uint32(io)

          count.times do
            glyph_id = read_uint16(io)
            paint_offset = read_uint32(io)
            yield glyph_id, paint_offset
          end
        end

        # Find a base glyph record by glyph ID using binary search
        private def find_base_glyph(glyph_id : UInt16) : BaseGlyphRecord?
          # Base glyph records are sorted by glyph ID
          low = 0
          high = @base_glyph_records.size - 1

          while low <= high
            mid = (low + high) // 2
            record = @base_glyph_records[mid]

            if record.glyph_id < glyph_id
              low = mid + 1
            elsif record.glyph_id > glyph_id
              high = mid - 1
            else
              return record
            end
          end

          nil
        end

        # Find a v1 base glyph paint offset by glyph ID
        private def find_v1_base_glyph(glyph_id : UInt16) : UInt32?
          return nil unless v1?
          return nil if @base_glyph_list_offset == 0

          io = IO::Memory.new(@data[@base_glyph_list_offset.to_i..])
          count = read_uint32(io)

          # V1 base glyph list is also sorted by glyph ID
          # Each record is 6 bytes: uint16 glyphId + uint32 paintOffset
          low = 0
          high = count.to_i - 1

          while low <= high
            mid = (low + high) // 2
            io.seek(4 + mid * 6) # Skip count + mid records
            mid_glyph_id = read_uint16(io)

            if mid_glyph_id < glyph_id
              low = mid + 1
            elsif mid_glyph_id > glyph_id
              high = mid - 1
            else
              return read_uint32(io)
            end
          end

          nil
        end

        extend IOHelpers
      end
    end
  end
end
