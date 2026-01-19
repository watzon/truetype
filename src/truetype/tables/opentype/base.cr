module TrueType
  module Tables
    module OpenType
      # The 'BASE' table (Baseline) contains information about baseline positions
      # and min/max extent values for different scripts and language systems.
      #
      # This table is used for aligning text of different scripts on a common
      # baseline, particularly for mixing scripts like Latin with CJK or Arabic.
      class BASE
        include IOHelpers

        # Table version (1.0 or 1.1)
        getter version : UInt32

        # Horizontal axis data (for horizontal text)
        getter horiz_axis : Axis?

        # Vertical axis data (for vertical text)
        getter vert_axis : Axis?

        # Item variation store offset (version 1.1 only)
        getter item_var_store_offset : UInt32?

        def initialize(
          @version : UInt32,
          @horiz_axis : Axis?,
          @vert_axis : Axis?,
          @item_var_store_offset : UInt32? = nil
        )
        end

        # Parse BASE table from raw bytes
        def self.parse(data : Bytes) : BASE
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          version = (major_version.to_u32 << 16) | minor_version.to_u32

          horiz_axis_offset = read_uint16(io)
          vert_axis_offset = read_uint16(io)

          # Version 1.1 has additional ItemVariationStore offset
          item_var_store_offset : UInt32? = nil
          if major_version >= 1 && minor_version >= 1
            item_var_store_offset = read_uint32(io)
          end

          horiz_axis : Axis? = nil
          vert_axis : Axis? = nil

          if horiz_axis_offset != 0
            horiz_axis = Axis.parse(data, horiz_axis_offset.to_u32)
          end

          if vert_axis_offset != 0
            vert_axis = Axis.parse(data, vert_axis_offset.to_u32)
          end

          new(version, horiz_axis, vert_axis, item_var_store_offset)
        end

        # Get baseline for a script and baseline tag (horizontal axis)
        def baseline(script : String, baseline_tag : String) : Int16?
          horiz_axis.try(&.baseline(script, baseline_tag))
        end

        # Get baseline for a script and baseline tag (vertical axis)
        def vertical_baseline(script : String, baseline_tag : String) : Int16?
          vert_axis.try(&.baseline(script, baseline_tag))
        end

        # Get min/max extent for a script (horizontal axis)
        def min_max(script : String, language : String? = nil) : Tuple(Int16, Int16)?
          horiz_axis.try(&.min_max(script, language))
        end

        # Get min/max extent for a script (vertical axis)
        def vertical_min_max(script : String, language : String? = nil) : Tuple(Int16, Int16)?
          vert_axis.try(&.min_max(script, language))
        end

        # Check if version 1.1 (has item variation store)
        def version_1_1? : Bool
          (@version >> 16) >= 1 && (@version & 0xFFFF) >= 1
        end

        extend IOHelpers
      end

      # Axis table for horizontal or vertical baselines
      class Axis
        include IOHelpers

        # Base tag list (registered baseline tags like "romn", "ideo", "hang", etc.)
        getter base_tag_list : Array(String)?

        # Base script list
        getter base_script_list : Array(BaseScript)

        def initialize(
          @base_tag_list : Array(String)?,
          @base_script_list : Array(BaseScript)
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : Axis
          io = IO::Memory.new(data[offset.to_i..])

          base_tag_list_offset = read_uint16(io)
          base_script_list_offset = read_uint16(io)

          # Parse base tag list
          base_tag_list : Array(String)? = nil
          if base_tag_list_offset != 0
            tag_io = IO::Memory.new(data[(offset + base_tag_list_offset).to_i..])
            base_tag_count = read_uint16(tag_io)
            base_tag_list = Array(String).new(base_tag_count.to_i)
            base_tag_count.times do
              base_tag_list << read_tag(tag_io)
            end
          end

          # Parse base script list
          base_script_list = Array(BaseScript).new
          if base_script_list_offset != 0
            script_list_io = IO::Memory.new(data[(offset + base_script_list_offset).to_i..])
            base_script_count = read_uint16(script_list_io)

            # Read script records
            script_records = Array(Tuple(String, UInt16)).new(base_script_count.to_i)
            base_script_count.times do
              script_tag = read_tag(script_list_io)
              script_offset = read_uint16(script_list_io)
              script_records << {script_tag, script_offset}
            end

            # Parse each script
            script_records.each do |script_tag, script_offset|
              if script_offset != 0
                script = BaseScript.parse(
                  data,
                  (offset + base_script_list_offset + script_offset).to_u32,
                  script_tag,
                  base_tag_list
                )
                base_script_list << script
              end
            end
          end

          new(base_tag_list, base_script_list)
        end

        # Get baseline value for a script and baseline tag
        def baseline(script_tag : String, baseline_tag : String) : Int16?
          script = @base_script_list.find { |s| s.script_tag == script_tag }
          script.try(&.baseline(baseline_tag))
        end

        # Get min/max extent for a script
        def min_max(script_tag : String, language_tag : String? = nil) : Tuple(Int16, Int16)?
          script = @base_script_list.find { |s| s.script_tag == script_tag }
          script.try(&.min_max(language_tag))
        end

        extend IOHelpers
      end

      # Base script table
      class BaseScript
        include IOHelpers

        # Script tag (e.g., "latn", "cyrl", "arab")
        getter script_tag : String

        # Base values (baseline coordinates)
        getter base_values : BaseValues?

        # Default min/max extent values
        getter default_min_max : MinMax?

        # Language-specific min/max values
        getter base_lang_sys_records : Array(BaseLangSysRecord)

        def initialize(
          @script_tag : String,
          @base_values : BaseValues?,
          @default_min_max : MinMax?,
          @base_lang_sys_records : Array(BaseLangSysRecord)
        )
        end

        def self.parse(data : Bytes, offset : UInt32, script_tag : String, tag_list : Array(String)?) : BaseScript
          io = IO::Memory.new(data[offset.to_i..])

          base_values_offset = read_uint16(io)
          default_min_max_offset = read_uint16(io)
          base_lang_sys_count = read_uint16(io)

          # Read language system records
          lang_records = Array(Tuple(String, UInt16)).new(base_lang_sys_count.to_i)
          base_lang_sys_count.times do
            lang_tag = read_tag(io)
            min_max_offset = read_uint16(io)
            lang_records << {lang_tag, min_max_offset}
          end

          # Parse base values
          base_values : BaseValues? = nil
          if base_values_offset != 0
            base_values = BaseValues.parse(data, (offset + base_values_offset).to_u32, tag_list)
          end

          # Parse default min/max
          default_min_max : MinMax? = nil
          if default_min_max_offset != 0
            default_min_max = MinMax.parse(data, (offset + default_min_max_offset).to_u32)
          end

          # Parse language-specific min/max
          base_lang_sys_records = lang_records.compact_map do |lang_tag, min_max_offset|
            if min_max_offset != 0
              min_max = MinMax.parse(data, (offset + min_max_offset).to_u32)
              BaseLangSysRecord.new(lang_tag, min_max)
            end
          end

          new(script_tag, base_values, default_min_max, base_lang_sys_records)
        end

        # Get baseline value for a baseline tag
        def baseline(baseline_tag : String) : Int16?
          @base_values.try(&.baseline(baseline_tag))
        end

        # Get min/max extent (optionally for specific language)
        def min_max(language_tag : String? = nil) : Tuple(Int16, Int16)?
          if lang_tag = language_tag
            lang_record = @base_lang_sys_records.find { |r| r.lang_sys_tag == lang_tag }
            if record = lang_record
              return {record.min_max.min_coord, record.min_max.max_coord}
            end
          end

          # Fall back to default
          if default = @default_min_max
            {default.min_coord, default.max_coord}
          else
            nil
          end
        end

        extend IOHelpers
      end

      # Base values table containing baseline coordinates
      class BaseValues
        include IOHelpers

        # Index of default baseline in base_coords
        getter default_baseline_index : UInt16

        # Baseline coordinates (one per baseline tag)
        getter base_coords : Array(BaseCoord)

        # Baseline tag list (for looking up by tag name)
        @tag_list : Array(String)?

        def initialize(
          @default_baseline_index : UInt16,
          @base_coords : Array(BaseCoord),
          @tag_list : Array(String)? = nil
        )
        end

        def self.parse(data : Bytes, offset : UInt32, tag_list : Array(String)?) : BaseValues
          io = IO::Memory.new(data[offset.to_i..])

          default_baseline_index = read_uint16(io)
          base_coord_count = read_uint16(io)

          # Read offsets to base coordinates
          coord_offsets = Array(UInt16).new(base_coord_count.to_i)
          base_coord_count.times do
            coord_offsets << read_uint16(io)
          end

          # Parse base coordinates
          base_coords = coord_offsets.map do |coord_offset|
            BaseCoord.parse(data, (offset + coord_offset).to_u32)
          end

          new(default_baseline_index, base_coords, tag_list)
        end

        # Get baseline value for a baseline tag
        def baseline(baseline_tag : String) : Int16?
          if tags = @tag_list
            index = tags.index(baseline_tag)
            if idx = index
              return @base_coords[idx]?.try(&.coordinate)
            end
          end
          nil
        end

        # Get default baseline coordinate
        def default_baseline : Int16?
          @base_coords[@default_baseline_index.to_i]?.try(&.coordinate)
        end

        extend IOHelpers
      end

      # Base coordinate (format 1, 2, or 3)
      struct BaseCoord
        include IOHelpers

        # Format (1, 2, or 3)
        getter format : UInt16

        # Baseline coordinate value
        getter coordinate : Int16

        # Reference glyph (format 2 only)
        getter reference_glyph : UInt16?

        # Reference point (format 2 only)
        getter base_coord_point : UInt16?

        # Device table offset (format 3 only)
        getter device_offset : UInt16?

        def initialize(
          @format : UInt16,
          @coordinate : Int16,
          @reference_glyph : UInt16? = nil,
          @base_coord_point : UInt16? = nil,
          @device_offset : UInt16? = nil
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : BaseCoord
          io = IO::Memory.new(data[offset.to_i..])

          format = read_uint16(io)
          coordinate = read_int16(io)

          case format
          when 1
            new(format, coordinate)
          when 2
            reference_glyph = read_uint16(io)
            base_coord_point = read_uint16(io)
            new(format, coordinate, reference_glyph, base_coord_point)
          when 3
            device_offset = read_uint16(io)
            new(format, coordinate, device_offset: device_offset)
          else
            new(format, coordinate)
          end
        end

        extend IOHelpers
      end

      # Min/max extent values
      struct MinMax
        include IOHelpers

        # Minimum extent coordinate
        getter min_coord : Int16

        # Maximum extent coordinate
        getter max_coord : Int16

        # Feature table count (for specific features)
        getter feat_min_max_count : UInt16

        def initialize(
          @min_coord : Int16,
          @max_coord : Int16,
          @feat_min_max_count : UInt16 = 0
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : MinMax
          io = IO::Memory.new(data[offset.to_i..])

          min_coord_offset = read_uint16(io)
          max_coord_offset = read_uint16(io)
          feat_min_max_count = read_uint16(io)

          min_coord = 0_i16
          max_coord = 0_i16

          if min_coord_offset != 0
            coord = BaseCoord.parse(data, (offset + min_coord_offset).to_u32)
            min_coord = coord.coordinate
          end

          if max_coord_offset != 0
            coord = BaseCoord.parse(data, (offset + max_coord_offset).to_u32)
            max_coord = coord.coordinate
          end

          new(min_coord, max_coord, feat_min_max_count)
        end

        extend IOHelpers
      end

      # Language system record with min/max values
      struct BaseLangSysRecord
        # Language system tag (e.g., "dflt", "DEU ", "TRK ")
        getter lang_sys_tag : String

        # Min/max extent values
        getter min_max : MinMax

        def initialize(@lang_sys_tag : String, @min_max : MinMax)
        end
      end
    end
  end
end
