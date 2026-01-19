module TrueType
  module Tables
    module OpenType
      # The 'JSTF' table contains justification information.
      # It defines which GSUB/GPOS lookups to enable/disable
      # to shrink or extend text to fill a line.
      class JSTF
        include IOHelpers

        # Table version (1.0)
        getter version : UInt32

        # Script records
        getter scripts : Array(JstfScript)

        def initialize(@version : UInt32, @scripts : Array(JstfScript))
        end

        def self.parse(data : Bytes) : JSTF
          io = IO::Memory.new(data)

          major = read_uint16(io)
          minor = read_uint16(io)
          version = (major.to_u32 << 16) | minor.to_u32

          script_count = read_uint16(io)

          # Read script records
          script_records = Array(Tuple(String, UInt16)).new(script_count.to_i)
          script_count.times do
            tag = read_tag(io)
            offset = read_uint16(io)
            script_records << {tag, offset}
          end

          # Parse scripts
          scripts = script_records.compact_map do |tag, offset|
            next nil if offset == 0
            JstfScript.parse(data, offset.to_u32, tag)
          end

          new(version, scripts)
        end

        # Get script by tag
        def script(tag : String) : JstfScript?
          @scripts.find { |s| s.script_tag == tag }
        end

        extend IOHelpers
      end

      # JSTF Script record
      class JstfScript
        include IOHelpers

        getter script_tag : String
        getter extender_glyphs : Array(UInt16)
        getter default_lang_sys : JstfLangSys?
        getter lang_sys_records : Array(JstfLangSysRecord)

        def initialize(
          @script_tag : String,
          @extender_glyphs : Array(UInt16),
          @default_lang_sys : JstfLangSys?,
          @lang_sys_records : Array(JstfLangSysRecord)
        )
        end

        def self.parse(data : Bytes, offset : UInt32, script_tag : String) : JstfScript
          io = IO::Memory.new(data[offset.to_i..])

          extender_glyph_offset = read_uint16(io)
          default_lang_sys_offset = read_uint16(io)
          lang_sys_count = read_uint16(io)

          # Read language system records
          lang_records = Array(Tuple(String, UInt16)).new(lang_sys_count.to_i)
          lang_sys_count.times do
            tag = read_tag(io)
            lang_offset = read_uint16(io)
            lang_records << {tag, lang_offset}
          end

          # Parse extender glyphs
          extender_glyphs = [] of UInt16
          if extender_glyph_offset != 0
            eg_io = IO::Memory.new(data[(offset + extender_glyph_offset).to_i..])
            count = read_uint16(eg_io)
            count.times { extender_glyphs << read_uint16(eg_io) }
          end

          # Parse default lang sys
          default_lang_sys : JstfLangSys? = nil
          if default_lang_sys_offset != 0
            default_lang_sys = JstfLangSys.parse(data, offset + default_lang_sys_offset)
          end

          # Parse language systems
          lang_sys_records = lang_records.compact_map do |tag, lang_offset|
            next nil if lang_offset == 0
            lang_sys = JstfLangSys.parse(data, offset + lang_offset)
            JstfLangSysRecord.new(tag, lang_sys)
          end

          new(script_tag, extender_glyphs, default_lang_sys, lang_sys_records)
        end

        # Get language system by tag
        def lang_sys(tag : String) : JstfLangSys?
          record = @lang_sys_records.find { |r| r.lang_sys_tag == tag }
          record.try(&.lang_sys) || @default_lang_sys
        end

        extend IOHelpers
      end

      # Language system record
      struct JstfLangSysRecord
        getter lang_sys_tag : String
        getter lang_sys : JstfLangSys

        def initialize(@lang_sys_tag : String, @lang_sys : JstfLangSys)
        end
      end

      # JSTF Language System
      class JstfLangSys
        include IOHelpers

        getter priorities : Array(JstfPriority)

        def initialize(@priorities : Array(JstfPriority))
        end

        def self.parse(data : Bytes, offset : UInt32) : JstfLangSys
          io = IO::Memory.new(data[offset.to_i..])

          priority_count = read_uint16(io)

          # Read priority offsets
          priority_offsets = Array(UInt16).new(priority_count.to_i)
          priority_count.times { priority_offsets << read_uint16(io) }

          # Parse priorities
          priorities = priority_offsets.compact_map do |p_offset|
            next nil if p_offset == 0
            JstfPriority.parse(data, offset + p_offset)
          end

          new(priorities)
        end

        extend IOHelpers
      end

      # JSTF Priority - defines which lookups to enable/disable
      class JstfPriority
        include IOHelpers

        # GSUB lookups to enable during shrinkage
        getter gsub_shrinkage_enable : Array(UInt16)?
        # GSUB lookups to disable during shrinkage
        getter gsub_shrinkage_disable : Array(UInt16)?
        # GPOS lookups to enable during shrinkage
        getter gpos_shrinkage_enable : Array(UInt16)?
        # GPOS lookups to disable during shrinkage
        getter gpos_shrinkage_disable : Array(UInt16)?
        # Max shrinkage adjustment
        getter shrinkage_max : JstfMax?

        # GSUB lookups to enable during extension
        getter gsub_extension_enable : Array(UInt16)?
        # GSUB lookups to disable during extension
        getter gsub_extension_disable : Array(UInt16)?
        # GPOS lookups to enable during extension
        getter gpos_extension_enable : Array(UInt16)?
        # GPOS lookups to disable during extension
        getter gpos_extension_disable : Array(UInt16)?
        # Max extension adjustment
        getter extension_max : JstfMax?

        def initialize(
          @gsub_shrinkage_enable : Array(UInt16)?,
          @gsub_shrinkage_disable : Array(UInt16)?,
          @gpos_shrinkage_enable : Array(UInt16)?,
          @gpos_shrinkage_disable : Array(UInt16)?,
          @shrinkage_max : JstfMax?,
          @gsub_extension_enable : Array(UInt16)?,
          @gsub_extension_disable : Array(UInt16)?,
          @gpos_extension_enable : Array(UInt16)?,
          @gpos_extension_disable : Array(UInt16)?,
          @extension_max : JstfMax?
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : JstfPriority
          io = IO::Memory.new(data[offset.to_i..])

          gsub_shrinkage_enable_offset = read_uint16(io)
          gsub_shrinkage_disable_offset = read_uint16(io)
          gpos_shrinkage_enable_offset = read_uint16(io)
          gpos_shrinkage_disable_offset = read_uint16(io)
          shrinkage_max_offset = read_uint16(io)
          gsub_extension_enable_offset = read_uint16(io)
          gsub_extension_disable_offset = read_uint16(io)
          gpos_extension_enable_offset = read_uint16(io)
          gpos_extension_disable_offset = read_uint16(io)
          extension_max_offset = read_uint16(io)

          new(
            parse_lookup_list(data, offset, gsub_shrinkage_enable_offset),
            parse_lookup_list(data, offset, gsub_shrinkage_disable_offset),
            parse_lookup_list(data, offset, gpos_shrinkage_enable_offset),
            parse_lookup_list(data, offset, gpos_shrinkage_disable_offset),
            shrinkage_max_offset != 0 ? JstfMax.parse(data, offset + shrinkage_max_offset) : nil,
            parse_lookup_list(data, offset, gsub_extension_enable_offset),
            parse_lookup_list(data, offset, gsub_extension_disable_offset),
            parse_lookup_list(data, offset, gpos_extension_enable_offset),
            parse_lookup_list(data, offset, gpos_extension_disable_offset),
            extension_max_offset != 0 ? JstfMax.parse(data, offset + extension_max_offset) : nil
          )
        end

        private def self.parse_lookup_list(data : Bytes, base_offset : UInt32, offset : UInt16) : Array(UInt16)?
          return nil if offset == 0

          io = IO::Memory.new(data[(base_offset + offset).to_i..])
          count = read_uint16(io)
          lookups = Array(UInt16).new(count.to_i)
          count.times { lookups << read_uint16(io) }
          lookups
        end

        extend IOHelpers
      end

      # JSTF Max - maximum adjustment values
      class JstfMax
        include IOHelpers

        getter lookup_indices : Array(UInt16)

        def initialize(@lookup_indices : Array(UInt16))
        end

        def self.parse(data : Bytes, offset : UInt32) : JstfMax
          io = IO::Memory.new(data[offset.to_i..])

          count = read_uint16(io)
          indices = Array(UInt16).new(count.to_i)
          count.times { indices << read_uint16(io) }

          new(indices)
        end

        extend IOHelpers
      end
    end
  end
end
