module TrueType
  module Tables
    module OpenType
      # GDEF (Glyph Definition) table
      # Provides glyph classification and attachment point information
      class GDEF
        include IOHelpers
        extend IOHelpers

        # Glyph class values
        enum GlyphClass : UInt16
          Base      = 1 # Base glyph (single character, spacing)
          Ligature  = 2 # Ligature glyph (multiple characters, spacing)
          Mark      = 3 # Mark glyph (non-spacing combining)
          Component = 4 # Component glyph (part of composite)
        end

        getter version_major : UInt16
        getter version_minor : UInt16
        getter glyph_class_def : ClassDef?
        getter attach_list : AttachList?
        getter lig_caret_list : LigCaretList?
        getter mark_attach_class_def : ClassDef?
        getter mark_glyph_sets_def : MarkGlyphSetsDef?
        getter item_var_store_offset : UInt32?

        def initialize(
          @version_major : UInt16,
          @version_minor : UInt16,
          @glyph_class_def : ClassDef?,
          @attach_list : AttachList?,
          @lig_caret_list : LigCaretList?,
          @mark_attach_class_def : ClassDef?,
          @mark_glyph_sets_def : MarkGlyphSetsDef?,
          @item_var_store_offset : UInt32?
        )
        end

        # Get the glyph class for a glyph ID
        def glyph_class(glyph_id : UInt16) : GlyphClass?
          return nil unless gcd = @glyph_class_def
          class_id = gcd.class_id(glyph_id)
          return nil if class_id == 0
          GlyphClass.from_value?(class_id)
        end

        # Check if a glyph is a base glyph
        def base?(glyph_id : UInt16) : Bool
          glyph_class(glyph_id) == GlyphClass::Base
        end

        # Check if a glyph is a ligature
        def ligature?(glyph_id : UInt16) : Bool
          glyph_class(glyph_id) == GlyphClass::Ligature
        end

        # Check if a glyph is a mark (combining)
        def mark?(glyph_id : UInt16) : Bool
          glyph_class(glyph_id) == GlyphClass::Mark
        end

        # Check if a glyph is a component
        def component?(glyph_id : UInt16) : Bool
          glyph_class(glyph_id) == GlyphClass::Component
        end

        # Get the mark attachment class for a glyph
        def mark_attach_class(glyph_id : UInt16) : UInt16
          return 0_u16 unless mac = @mark_attach_class_def
          mac.class_id(glyph_id)
        end

        # Check if a glyph is in a specific mark glyph set
        def in_mark_glyph_set?(glyph_id : UInt16, set_index : Int32) : Bool
          return false unless mgs = @mark_glyph_sets_def
          mgs.contains?(set_index, glyph_id)
        end

        def self.parse(data : Bytes, offset : UInt32, length : UInt32) : GDEF
          io = IO::Memory.new(data[offset, length])
          table_start = offset.to_i64

          version_major = read_uint16(io)
          version_minor = read_uint16(io)

          glyph_class_def_offset = read_uint16(io)
          attach_list_offset = read_uint16(io)
          lig_caret_list_offset = read_uint16(io)
          mark_attach_class_def_offset = read_uint16(io)

          # Version 1.2+ has MarkGlyphSetsDef
          mark_glyph_sets_def_offset = 0_u16
          if version_minor >= 2
            mark_glyph_sets_def_offset = read_uint16(io)
          end

          # Version 1.3+ has ItemVariationStore
          item_var_store_offset : UInt32? = nil
          if version_minor >= 3
            item_var_store_offset = read_uint32(io)
          end

          # Parse sub-tables
          table_data = data[offset, length]
          table_io = IO::Memory.new(table_data)

          glyph_class_def = if glyph_class_def_offset > 0
                              ClassDef.parse(table_io, glyph_class_def_offset.to_u32)
                            else
                              nil
                            end

          attach_list = if attach_list_offset > 0
                          AttachList.parse(table_io, attach_list_offset.to_u32)
                        else
                          nil
                        end

          lig_caret_list = if lig_caret_list_offset > 0
                             LigCaretList.parse(table_io, lig_caret_list_offset.to_u32)
                           else
                             nil
                           end

          mark_attach_class_def = if mark_attach_class_def_offset > 0
                                    ClassDef.parse(table_io, mark_attach_class_def_offset.to_u32)
                                  else
                                    nil
                                  end

          mark_glyph_sets_def = if mark_glyph_sets_def_offset > 0
                                  MarkGlyphSetsDef.parse(table_io, mark_glyph_sets_def_offset.to_u32)
                                else
                                  nil
                                end

          new(
            version_major,
            version_minor,
            glyph_class_def,
            attach_list,
            lig_caret_list,
            mark_attach_class_def,
            mark_glyph_sets_def,
            item_var_store_offset
          )
        end
      end

      # Attachment point list
      class AttachList
        include IOHelpers
        extend IOHelpers

        getter coverage : Coverage
        getter attach_points : Array(Array(UInt16))

        def initialize(@coverage : Coverage, @attach_points : Array(Array(UInt16)))
        end

        # Get attachment points for a glyph
        def points_for(glyph_id : UInt16) : Array(UInt16)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @attach_points[idx]?
        end

        def self.parse(io : IO, offset : UInt32) : AttachList
          io.seek(offset.to_i64)
          base_offset = offset

          coverage_offset = read_uint16(io)
          glyph_count = read_uint16(io)

          attach_point_offsets = Array(UInt16).new(glyph_count.to_i)
          glyph_count.times do
            attach_point_offsets << read_uint16(io)
          end

          coverage = Coverage.parse(io, base_offset + coverage_offset)

          attach_points = attach_point_offsets.map do |apo|
            io.seek((base_offset + apo).to_i64)
            point_count = read_uint16(io)
            points = Array(UInt16).new(point_count.to_i)
            point_count.times { points << read_uint16(io) }
            points
          end

          new(coverage, attach_points)
        end
      end

      # Ligature caret list
      class LigCaretList
        include IOHelpers
        extend IOHelpers

        getter coverage : Coverage
        getter lig_glyphs : Array(Array(CaretValue))

        def initialize(@coverage : Coverage, @lig_glyphs : Array(Array(CaretValue)))
        end

        # Get caret positions for a ligature glyph
        def carets_for(glyph_id : UInt16) : Array(CaretValue)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @lig_glyphs[idx]?
        end

        def self.parse(io : IO, offset : UInt32) : LigCaretList
          io.seek(offset.to_i64)
          base_offset = offset

          coverage_offset = read_uint16(io)
          lig_glyph_count = read_uint16(io)

          lig_glyph_offsets = Array(UInt16).new(lig_glyph_count.to_i)
          lig_glyph_count.times do
            lig_glyph_offsets << read_uint16(io)
          end

          coverage = Coverage.parse(io, base_offset + coverage_offset)

          lig_glyphs = lig_glyph_offsets.map do |lgo|
            io.seek((base_offset + lgo).to_i64)
            caret_count = read_uint16(io)
            caret_offsets = Array(UInt16).new(caret_count.to_i)
            caret_count.times { caret_offsets << read_uint16(io) }

            caret_offsets.map do |co|
              CaretValue.parse(io, base_offset + lgo + co)
            end
          end

          new(coverage, lig_glyphs)
        end
      end

      # Caret value for ligature positioning
      abstract class CaretValue
        include IOHelpers
        extend IOHelpers

        abstract def coordinate : Int16

        def self.parse(io : IO, offset : UInt32) : CaretValue
          io.seek(offset.to_i64)
          format = read_uint16(io)

          case format
          when 1
            CaretValueFormat1.new(read_int16(io))
          when 2
            CaretValueFormat2.new(read_uint16(io))
          when 3
            coord = read_int16(io)
            device_offset = read_uint16(io)
            CaretValueFormat3.new(coord, device_offset)
          else
            raise ParseError.new("Unknown CaretValue format: #{format}")
          end
        end
      end

      # CaretValue Format 1: Design units only
      class CaretValueFormat1 < CaretValue
        getter coord : Int16

        def initialize(@coord : Int16)
        end

        def coordinate : Int16
          @coord
        end
      end

      # CaretValue Format 2: Contour point
      class CaretValueFormat2 < CaretValue
        getter caret_value_point : UInt16

        def initialize(@caret_value_point : UInt16)
        end

        def coordinate : Int16
          # Would need glyph outline to resolve point index
          0_i16
        end
      end

      # CaretValue Format 3: Design units + device table
      class CaretValueFormat3 < CaretValue
        getter coord : Int16
        getter device_offset : UInt16

        def initialize(@coord : Int16, @device_offset : UInt16)
        end

        def coordinate : Int16
          @coord
        end
      end

      # Mark glyph sets definition (GDEF v1.2+)
      class MarkGlyphSetsDef
        include IOHelpers
        extend IOHelpers

        getter coverages : Array(Coverage)

        def initialize(@coverages : Array(Coverage))
        end

        def contains?(set_index : Int32, glyph_id : UInt16) : Bool
          return false if set_index < 0 || set_index >= @coverages.size
          @coverages[set_index].covers?(glyph_id)
        end

        def self.parse(io : IO, offset : UInt32) : MarkGlyphSetsDef
          io.seek(offset.to_i64)
          base_offset = offset

          format = read_uint16(io)
          mark_set_count = read_uint16(io)

          coverage_offsets = Array(UInt32).new(mark_set_count.to_i)
          mark_set_count.times do
            coverage_offsets << read_uint32(io)
          end

          coverages = coverage_offsets.map do |co|
            Coverage.parse(io, base_offset + co)
          end

          new(coverages)
        end
      end
    end
  end
end
