module TrueType
  module Tables
    module OpenType
      # Script record in ScriptList
      struct ScriptRecord
        getter tag : String
        getter offset : UInt16

        def initialize(@tag : String, @offset : UInt16)
        end
      end

      # Language system record
      struct LangSysRecord
        getter tag : String
        getter offset : UInt16

        def initialize(@tag : String, @offset : UInt16)
        end
      end

      # Language system table
      struct LangSys
        include IOHelpers
        extend IOHelpers

        getter lookup_order : UInt16 # Reserved, always 0
        getter required_feature_index : UInt16
        getter feature_indices : Array(UInt16)

        def initialize(@lookup_order : UInt16, @required_feature_index : UInt16, @feature_indices : Array(UInt16))
        end

        # Check if there's a required feature
        def has_required_feature? : Bool
          @required_feature_index != 0xFFFF
        end

        def self.parse(io : IO) : LangSys
          lookup_order = read_uint16(io)
          required_feature_index = read_uint16(io)
          feature_count = read_uint16(io)

          feature_indices = Array(UInt16).new(feature_count.to_i)
          feature_count.times do
            feature_indices << read_uint16(io)
          end

          new(lookup_order, required_feature_index, feature_indices)
        end
      end

      # Script table
      class ScriptTable
        include IOHelpers
        extend IOHelpers

        getter default_lang_sys : LangSys?
        getter lang_sys_records : Array(LangSysRecord)
        getter lang_sys_tables : Hash(String, LangSys)

        def initialize(@default_lang_sys : LangSys?, @lang_sys_records : Array(LangSysRecord), @lang_sys_tables : Hash(String, LangSys))
        end

        # Get language system by tag (e.g., "DEU ", "ENG ")
        def lang_sys(tag : String) : LangSys?
          @lang_sys_tables[tag]?
        end

        def self.parse(io : IO, offset : UInt32) : ScriptTable
          io.seek(offset.to_i64)
          base_offset = offset

          default_lang_sys_offset = read_uint16(io)
          lang_sys_count = read_uint16(io)

          lang_sys_records = Array(LangSysRecord).new(lang_sys_count.to_i)
          lang_sys_count.times do
            tag = read_tag(io)
            off = read_uint16(io)
            lang_sys_records << LangSysRecord.new(tag, off)
          end

          default_lang_sys = if default_lang_sys_offset > 0
                               io.seek((base_offset + default_lang_sys_offset).to_i64)
                               LangSys.parse(io)
                             else
                               nil
                             end

          lang_sys_tables = Hash(String, LangSys).new
          lang_sys_records.each do |rec|
            io.seek((base_offset + rec.offset).to_i64)
            lang_sys_tables[rec.tag] = LangSys.parse(io)
          end

          new(default_lang_sys, lang_sys_records, lang_sys_tables)
        end
      end

      # Script list
      class ScriptList
        include IOHelpers
        extend IOHelpers

        getter scripts : Hash(String, ScriptTable)

        def initialize(@scripts : Hash(String, ScriptTable))
        end

        # Get script by tag (e.g., "latn", "cyrl", "arab")
        def script(tag : String) : ScriptTable?
          @scripts[tag]?
        end

        # Get the default script (DFLT or latn)
        def default_script : ScriptTable?
          @scripts["DFLT"]? || @scripts["latn"]?
        end

        def self.parse(io : IO, offset : UInt32) : ScriptList
          io.seek(offset.to_i64)
          base_offset = offset

          script_count = read_uint16(io)
          script_records = Array(ScriptRecord).new(script_count.to_i)

          script_count.times do
            tag = read_tag(io)
            off = read_uint16(io)
            script_records << ScriptRecord.new(tag, off)
          end

          scripts = Hash(String, ScriptTable).new
          script_records.each do |rec|
            scripts[rec.tag] = ScriptTable.parse(io, base_offset + rec.offset)
          end

          new(scripts)
        end
      end

      # Feature record
      struct FeatureRecord
        getter tag : String
        getter offset : UInt16

        def initialize(@tag : String, @offset : UInt16)
        end
      end

      # Feature table
      struct FeatureTable
        include IOHelpers
        extend IOHelpers

        getter feature_params : UInt16
        getter lookup_indices : Array(UInt16)

        def initialize(@feature_params : UInt16, @lookup_indices : Array(UInt16))
        end

        def self.parse(io : IO) : FeatureTable
          feature_params = read_uint16(io)
          lookup_count = read_uint16(io)

          lookup_indices = Array(UInt16).new(lookup_count.to_i)
          lookup_count.times do
            lookup_indices << read_uint16(io)
          end

          new(feature_params, lookup_indices)
        end
      end

      # Feature list
      class FeatureList
        include IOHelpers
        extend IOHelpers

        getter features : Array(Tuple(String, FeatureTable))

        def initialize(@features : Array(Tuple(String, FeatureTable)))
        end

        # Get feature by index
        def feature(index : Int32) : Tuple(String, FeatureTable)?
          @features[index]?
        end

        # Get all features with a specific tag
        def features_by_tag(tag : String) : Array(Tuple(Int32, FeatureTable))
          result = [] of Tuple(Int32, FeatureTable)
          @features.each_with_index do |(t, ft), idx|
            result << {idx, ft} if t == tag
          end
          result
        end

        def self.parse(io : IO, offset : UInt32) : FeatureList
          io.seek(offset.to_i64)
          base_offset = offset

          feature_count = read_uint16(io)
          feature_records = Array(FeatureRecord).new(feature_count.to_i)

          feature_count.times do
            tag = read_tag(io)
            off = read_uint16(io)
            feature_records << FeatureRecord.new(tag, off)
          end

          features = Array(Tuple(String, FeatureTable)).new(feature_count.to_i)
          feature_records.each do |rec|
            io.seek((base_offset + rec.offset).to_i64)
            features << {rec.tag, FeatureTable.parse(io)}
          end

          new(features)
        end
      end

      # Value record flags
      @[Flags]
      enum ValueFormat : UInt16
        XPlacement        = 0x0001
        YPlacement        = 0x0002
        XAdvance          = 0x0004
        YAdvance          = 0x0008
        XPlaDevice        = 0x0010
        YPlaDevice        = 0x0020
        XAdvDevice        = 0x0040
        YAdvDevice        = 0x0080
      end

      # Value record for positioning adjustments
      struct ValueRecord
        include IOHelpers
        extend IOHelpers

        getter x_placement : Int16
        getter y_placement : Int16
        getter x_advance : Int16
        getter y_advance : Int16
        getter x_pla_device : UInt16
        getter y_pla_device : UInt16
        getter x_adv_device : UInt16
        getter y_adv_device : UInt16

        def initialize(
          @x_placement : Int16 = 0,
          @y_placement : Int16 = 0,
          @x_advance : Int16 = 0,
          @y_advance : Int16 = 0,
          @x_pla_device : UInt16 = 0,
          @y_pla_device : UInt16 = 0,
          @x_adv_device : UInt16 = 0,
          @y_adv_device : UInt16 = 0
        )
        end

        def self.parse(io : IO, format : ValueFormat) : ValueRecord
          x_placement = format.x_placement? ? read_int16(io) : 0_i16
          y_placement = format.y_placement? ? read_int16(io) : 0_i16
          x_advance = format.x_advance? ? read_int16(io) : 0_i16
          y_advance = format.y_advance? ? read_int16(io) : 0_i16
          x_pla_device = format.x_pla_device? ? read_uint16(io) : 0_u16
          y_pla_device = format.y_pla_device? ? read_uint16(io) : 0_u16
          x_adv_device = format.x_adv_device? ? read_uint16(io) : 0_u16
          y_adv_device = format.y_adv_device? ? read_uint16(io) : 0_u16

          new(x_placement, y_placement, x_advance, y_advance,
            x_pla_device, y_pla_device, x_adv_device, y_adv_device)
        end

        def self.size(format : ValueFormat) : Int32
          size = 0
          size += 2 if format.x_placement?
          size += 2 if format.y_placement?
          size += 2 if format.x_advance?
          size += 2 if format.y_advance?
          size += 2 if format.x_pla_device?
          size += 2 if format.y_pla_device?
          size += 2 if format.x_adv_device?
          size += 2 if format.y_adv_device?
          size
        end
      end

      # Anchor table for attachment points
      abstract class Anchor
        include IOHelpers
        extend IOHelpers

        abstract def x : Int16
        abstract def y : Int16

        def self.parse(io : IO, offset : UInt32) : Anchor
          io.seek(offset.to_i64)
          format = read_uint16(io)

          case format
          when 1
            AnchorFormat1.new(read_int16(io), read_int16(io))
          when 2
            x = read_int16(io)
            y = read_int16(io)
            point = read_uint16(io)
            AnchorFormat2.new(x, y, point)
          when 3
            x = read_int16(io)
            y = read_int16(io)
            x_device = read_uint16(io)
            y_device = read_uint16(io)
            AnchorFormat3.new(x, y, x_device, y_device)
          else
            raise ParseError.new("Unknown Anchor format: #{format}")
          end
        end
      end

      class AnchorFormat1 < Anchor
        getter x : Int16
        getter y : Int16

        def initialize(@x : Int16, @y : Int16)
        end
      end

      class AnchorFormat2 < Anchor
        getter x : Int16
        getter y : Int16
        getter anchor_point : UInt16

        def initialize(@x : Int16, @y : Int16, @anchor_point : UInt16)
        end
      end

      class AnchorFormat3 < Anchor
        getter x : Int16
        getter y : Int16
        getter x_device_offset : UInt16
        getter y_device_offset : UInt16

        def initialize(@x : Int16, @y : Int16, @x_device_offset : UInt16, @y_device_offset : UInt16)
        end
      end
    end
  end
end
