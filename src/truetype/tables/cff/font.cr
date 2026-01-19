module TrueType
  module Tables
    # Parsed CFF font data for extracting outlines
    class CFFFont
      include IOHelpers

      getter cff : CFF::Table
      getter top_dict : CFF::Dict
      getter private_dict : CFF::Dict?
      getter charstrings : CFF::Index?
      getter local_subrs : CFF::Index?

      def initialize(
        @cff : CFF::Table,
        @top_dict : CFF::Dict,
        @private_dict : CFF::Dict?,
        @charstrings : CFF::Index?,
        @local_subrs : CFF::Index?
      )
      end

      def self.parse(data : Bytes) : CFFFont
        cff = CFF::Table.parse(data)
        top_dict_data = cff.top_dicts[0]
        top_dict = CFF::Dict.parse(top_dict_data)

        charstrings = parse_charstrings(data, top_dict)
        private_dict, local_subrs = parse_private_dict(data, top_dict)

        new(cff, top_dict, private_dict, charstrings, local_subrs)
      end

      def glyph_count : Int32
        @charstrings.try(&.size) || 0
      end

      def charstring(glyph_id : UInt16) : Bytes
        @charstrings.try(&.[glyph_id.to_i]) || Bytes.empty
      end

      def glyph_outline(glyph_id : UInt16) : GlyphOutline
        data = charstring(glyph_id)
        return GlyphOutline.new if data.empty?

        interpreter = CFF::CharstringInterpreter.new
        interpreter.execute(data)
      end

      private def self.parse_charstrings(data : Bytes, top_dict : CFF::Dict) : CFF::Index?
        offset = top_dict.int(CFF::DictOp::CHAR_STRINGS, 0)
        return nil if offset <= 0

        io = IO::Memory.new(data)
        io.seek(offset)
        CFF::Index.parse(io)
      rescue
        nil
      end

      private def self.parse_private_dict(data : Bytes, top_dict : CFF::Dict) : Tuple(CFF::Dict?, CFF::Index?)
        values = top_dict.int_array(CFF::DictOp::PRIVATE)
        return {nil, nil} if values.size < 2

        size = values[0]
        offset = values[1]

        return {nil, nil} if size <= 0 || offset <= 0 || offset + size > data.size

        private_data = data[offset, size]
        private_dict = CFF::Dict.parse(private_data)

        local_subrs = parse_local_subrs(data, private_dict, offset)
        {private_dict, local_subrs}
      rescue
        {nil, nil}
      end

      private def self.parse_local_subrs(data : Bytes, private_dict : CFF::Dict, private_offset : Int32) : CFF::Index?
        subrs_offset = private_dict.int(CFF::DictOp::SUBRS, 0)
        return nil if subrs_offset <= 0

        io = IO::Memory.new(data)
        io.seek(private_offset + subrs_offset)
        CFF::Index.parse(io)
      rescue
        nil
      end

      extend IOHelpers
    end
  end
end
