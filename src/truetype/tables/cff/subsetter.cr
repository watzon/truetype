module TrueType
  module Tables
    module CFF
      # CFF font subsetter - creates a minimal CFF table with only needed glyphs
      #
      # Strategy: Desubroutinize all CharStrings (inline subroutine calls) to avoid
      # the complexity of subroutine dependency tracking and renumbering.
      class Subsetter
        include IOHelpers

        # Original CFF table data
        getter data : Bytes

        # Parsed CFF structures
        getter table : Table
        getter top_dict : Dict
        getter private_dict : Dict?
        getter charstrings : Index?
        getter local_subrs : Index?
        getter global_subrs : Index

        def initialize(@data : Bytes)
          @table = Table.parse(@data)
          top_dict_data = @table.top_dicts[0]
          @top_dict = Dict.parse(top_dict_data)
          @charstrings = parse_charstrings
          @private_dict, @local_subrs = parse_private_dict
          @global_subrs = @table.global_subrs
        end

        # Create a subset CFF table with only the specified glyphs
        # glyph_ids should be sorted and include glyph 0 (.notdef)
        def subset(glyph_ids : Array(UInt16)) : Bytes
          io = IO::Memory.new

          # Track positions for offset fixups
          offsets = {} of Symbol => Int32

          # === CFF Header (4 bytes) ===
          io.write_byte(@table.major)
          io.write_byte(@table.minor)
          io.write_byte(4_u8)  # headerSize
          io.write_byte(4_u8)  # offSize (we'll use 4-byte offsets for simplicity)

          # === Name INDEX ===
          write_name_index(io)

          # === Top DICT INDEX (placeholder - we'll rewrite) ===
          offsets[:top_dict_index] = io.pos
          top_dict_placeholder_start = io.pos
          # Write placeholder - will be overwritten
          write_placeholder_index(io, 64) # Reserve space for top dict

          # === String INDEX ===
          offsets[:string_index] = io.pos
          write_string_index(io)

          # === Global Subrs INDEX (empty - we desubroutinize) ===
          offsets[:global_subrs] = io.pos
          write_empty_index(io)

          # === Charset ===
          offsets[:charset] = io.pos
          write_charset(io, glyph_ids)

          # === CharStrings INDEX ===
          offsets[:charstrings] = io.pos
          write_charstrings(io, glyph_ids)

          # === Private DICT ===
          offsets[:private] = io.pos
          private_size = write_private_dict(io)
          offsets[:private_size] = private_size

          # Now rewrite Top DICT with correct offsets
          result = io.to_slice.dup
          rewrite_top_dict(result, offsets, top_dict_placeholder_start, glyph_ids.size)

          result
        end

        private def parse_charstrings : Index?
          offset = @top_dict.int(DictOp::CHAR_STRINGS, 0)
          return nil if offset <= 0

          io = IO::Memory.new(@data)
          io.seek(offset)
          Index.parse(io)
        rescue
          nil
        end

        private def parse_private_dict : Tuple(Dict?, Index?)
          values = @top_dict.int_array(DictOp::PRIVATE)
          return {nil, nil} if values.size < 2

          size = values[0]
          offset = values[1]

          return {nil, nil} if size <= 0 || offset <= 0 || offset + size > @data.size

          private_data = @data[offset, size]
          private_dict = Dict.parse(private_data)

          local_subrs = parse_local_subrs(private_dict, offset)
          {private_dict, local_subrs}
        rescue
          {nil, nil}
        end

        private def parse_local_subrs(private_dict : Dict, private_offset : Int32) : Index?
          subrs_offset = private_dict.int(DictOp::SUBRS, 0)
          return nil if subrs_offset <= 0

          io = IO::Memory.new(@data)
          io.seek(private_offset + subrs_offset)
          Index.parse(io)
        rescue
          nil
        end

        private def write_name_index(io : IO) : Nil
          # Copy the first font name
          name = @table.names.size > 0 ? @table.names[0] : Bytes.empty
          if name.empty?
            name = "Subset".to_slice
          end
          write_index(io, [name])
        end

        private def write_string_index(io : IO) : Nil
          # Copy original string index
          strings = [] of Bytes
          @table.strings.each { |s| strings << s }
          write_index(io, strings)
        end

        private def write_empty_index(io : IO) : Nil
          write_uint16(io, 0_u16)
        end

        private def write_placeholder_index(io : IO, size : Int32) : Nil
          # Write a placeholder index that we'll overwrite later
          write_uint16(io, 1_u16)      # count = 1
          io.write_byte(4_u8)          # offSize = 4
          write_uint32(io, 1_u32)      # offset[0] = 1
          write_uint32(io, (size + 1).to_u32)  # offset[1]
          size.times { io.write_byte(0_u8) }   # placeholder data
        end

        private def write_charset(io : IO, glyph_ids : Array(UInt16)) : Nil
          # Format 0: array of SIDs
          # Skip glyph 0 (.notdef) - it's implicit
          io.write_byte(0_u8) # format

          # For subset, we use SID 0 for all glyphs (or we could track original SIDs)
          # Using format 0 with sequential SIDs starting from 1
          (1...glyph_ids.size).each do |i|
            # Use SID = glyph index (simple approach)
            write_uint16(io, i.to_u16)
          end
        end

        private def write_charstrings(io : IO, glyph_ids : Array(UInt16)) : Nil
          cs = @charstrings
          return write_empty_index(io) unless cs

          # Collect and desubroutinize charstrings
          charstring_data = [] of Bytes
          glyph_ids.each do |gid|
            original = cs[gid.to_i]
            desubr = desubroutinize(original)
            charstring_data << desubr
          end

          write_index(io, charstring_data)
        end

        private def write_private_dict(io : IO) : Int32
          start_pos = io.pos

          pd = @private_dict
          unless pd
            # Write minimal private dict with just defaultWidthX and nominalWidthX
            write_dict_int(io, 0, DictOp::DEFAULT_WIDTH_X)
            write_dict_int(io, 0, DictOp::NOMINAL_WIDTH_X)
            return io.pos - start_pos
          end

          # Copy relevant private dict entries (exclude Subrs since we desubroutinize)
          copy_dict_entry(io, pd, DictOp::BLUE_VALUES)
          copy_dict_entry(io, pd, DictOp::OTHER_BLUES)
          copy_dict_entry(io, pd, DictOp::FAMILY_BLUES)
          copy_dict_entry(io, pd, DictOp::FAMILY_OTHER_BLUES)
          copy_dict_entry(io, pd, DictOp::STD_HW)
          copy_dict_entry(io, pd, DictOp::STD_VW)
          copy_dict_entry(io, pd, DictOp::BLUE_SCALE)
          copy_dict_entry(io, pd, DictOp::BLUE_SHIFT)
          copy_dict_entry(io, pd, DictOp::BLUE_FUZZ)
          copy_dict_entry(io, pd, DictOp::STEM_SNAP_H)
          copy_dict_entry(io, pd, DictOp::STEM_SNAP_V)
          copy_dict_entry(io, pd, DictOp::FORCE_BOLD)
          copy_dict_entry(io, pd, DictOp::LANGUAGE_GROUP)
          copy_dict_entry(io, pd, DictOp::EXPANSION_FACTOR)
          copy_dict_entry(io, pd, DictOp::INITIAL_RANDOM_SEED)

          # Always write default/nominal width
          default_width = pd.int(DictOp::DEFAULT_WIDTH_X, 0)
          nominal_width = pd.int(DictOp::NOMINAL_WIDTH_X, 0)
          write_dict_int(io, default_width, DictOp::DEFAULT_WIDTH_X)
          write_dict_int(io, nominal_width, DictOp::NOMINAL_WIDTH_X)

          # Note: We intentionally omit SUBRS since we desubroutinize

          io.pos - start_pos
        end

        private def copy_dict_entry(io : IO, dict : Dict, op : Int32) : Nil
          return unless dict.has?(op)

          value = dict.entries[op]
          case value
          when Int32
            write_dict_int(io, value, op)
          when Float64
            write_dict_real(io, value, op)
          when Array(Int32)
            value.each { |v| write_dict_number(io, v) }
            write_dict_operator(io, op)
          when Array(Float64)
            value.each { |v| write_dict_real_number(io, v) }
            write_dict_operator(io, op)
          end
        end

        private def write_dict_int(io : IO, value : Int32, op : Int32) : Nil
          write_dict_number(io, value)
          write_dict_operator(io, op)
        end

        private def write_dict_real(io : IO, value : Float64, op : Int32) : Nil
          write_dict_real_number(io, value)
          write_dict_operator(io, op)
        end

        private def write_dict_number(io : IO, value : Int32) : Nil
          if value >= -107 && value <= 107
            io.write_byte((value + 139).to_u8)
          elsif value >= 108 && value <= 1131
            adjusted = value - 108
            io.write_byte((247 + (adjusted >> 8)).to_u8)
            io.write_byte((adjusted & 0xFF).to_u8)
          elsif value >= -1131 && value <= -108
            adjusted = -value - 108
            io.write_byte((251 + (adjusted >> 8)).to_u8)
            io.write_byte((adjusted & 0xFF).to_u8)
          elsif value >= -32768 && value <= 32767
            io.write_byte(28_u8)
            io.write_byte(((value >> 8) & 0xFF).to_u8)
            io.write_byte((value & 0xFF).to_u8)
          else
            io.write_byte(29_u8)
            write_uint32(io, value.to_u32!)
          end
        end

        private def write_dict_real_number(io : IO, value : Float64) : Nil
          # Convert to string and encode as CFF real
          str = value.to_s
          io.write_byte(30_u8)

          nibbles = [] of UInt8
          str.each_char do |c|
            case c
            when '0'..'9' then nibbles << (c.ord - '0'.ord).to_u8
            when '.'      then nibbles << 0x0A_u8
            when 'E', 'e' then nibbles << 0x0B_u8
            when '-'      then nibbles << 0x0E_u8
            end
          end
          nibbles << 0x0F_u8 # end marker

          # Pad to even number
          nibbles << 0x0F_u8 if nibbles.size.odd?

          nibbles.each_slice(2) do |pair|
            byte = (pair[0] << 4) | pair[1]
            io.write_byte(byte)
          end
        end

        private def write_dict_operator(io : IO, op : Int32) : Nil
          if op >= 1200
            io.write_byte(12_u8)
            io.write_byte((op - 1200).to_u8)
          else
            io.write_byte(op.to_u8)
          end
        end

        private def write_index(io : IO, items : Array(Bytes)) : Nil
          count = items.size
          if count == 0
            write_uint16(io, 0_u16)
            return
          end

          # Calculate total data size to determine offSize
          total_size = items.sum(&.size)
          off_size = offset_size(total_size + 1)

          write_uint16(io, count.to_u16)
          io.write_byte(off_size)

          # Write offsets (1-based)
          offset = 1_u32
          write_offset(io, offset, off_size)
          items.each do |item|
            offset += item.size
            write_offset(io, offset, off_size)
          end

          # Write data
          items.each { |item| io.write(item) }
        end

        private def offset_size(max_offset : Int32) : UInt8
          if max_offset <= 0xFF
            1_u8
          elsif max_offset <= 0xFFFF
            2_u8
          elsif max_offset <= 0xFFFFFF
            3_u8
          else
            4_u8
          end
        end

        private def write_offset(io : IO, offset : UInt32, size : UInt8) : Nil
          case size
          when 1 then io.write_byte(offset.to_u8)
          when 2 then write_uint16(io, offset.to_u16)
          when 3
            io.write_byte(((offset >> 16) & 0xFF).to_u8)
            io.write_byte(((offset >> 8) & 0xFF).to_u8)
            io.write_byte((offset & 0xFF).to_u8)
          else
            write_uint32(io, offset)
          end
        end

        private def rewrite_top_dict(data : Bytes, offsets : Hash(Symbol, Int32), start_pos : Int32, num_glyphs : Int32) : Nil
          io = IO::Memory.new

          # Build new Top DICT with correct offsets
          # charset offset
          write_dict_int(io, offsets[:charset], DictOp::CHARSET)

          # charstrings offset
          write_dict_int(io, offsets[:charstrings], DictOp::CHAR_STRINGS)

          # Private DICT (size, offset)
          write_dict_number(io, offsets[:private_size])
          write_dict_number(io, offsets[:private])
          write_dict_operator(io, DictOp::PRIVATE)

          # Copy some metadata from original top dict if present
          copy_top_dict_metadata(io)

          top_dict_data = io.to_slice

          # Now write the Top DICT INDEX at the placeholder position
          result_io = IO::Memory.new(data)
          result_io.seek(start_pos)

          # Write Top DICT INDEX
          write_uint16(result_io, 1_u16)  # count = 1
          off_size = offset_size(top_dict_data.size + 1)
          result_io.write_byte(off_size)
          write_offset(result_io, 1_u32, off_size)
          write_offset(result_io, (top_dict_data.size + 1).to_u32, off_size)
          result_io.write(top_dict_data)
        end

        private def copy_top_dict_metadata(io : IO) : Nil
          # Copy useful metadata entries
          if @top_dict.has?(DictOp::FONT_BBOX)
            bbox = @top_dict.int_array(DictOp::FONT_BBOX)
            if bbox.size == 4
              bbox.each { |v| write_dict_number(io, v) }
              write_dict_operator(io, DictOp::FONT_BBOX)
            end
          end

          if @top_dict.has?(DictOp::FONT_MATRIX)
            # Font matrix is typically floats
            vals = @top_dict.entries[DictOp::FONT_MATRIX]?
            if vals.is_a?(Array(Float64))
              vals.each { |v| write_dict_real_number(io, v) }
              write_dict_operator(io, DictOp::FONT_MATRIX)
            elsif vals.is_a?(Array(Int32))
              vals.each { |v| write_dict_number(io, v) }
              write_dict_operator(io, DictOp::FONT_MATRIX)
            end
          end
        end

        # === Desubroutinization ===
        # Inline all subroutine calls to produce standalone CharStrings

        private def desubroutinize(charstring : Bytes) : Bytes
          return charstring if charstring.empty?

          io = IO::Memory.new
          stack = [] of Bytes
          execute_with_inlining(charstring, io, stack, 0)
          io.to_slice
        end

        private def execute_with_inlining(data : Bytes, output : IO, stack : Array(Bytes), depth : Int32) : Nil
          return if depth > 10  # Prevent infinite recursion

          i = 0
          operand_buffer = IO::Memory.new

          while i < data.size
            b0 = data[i]
            i += 1

            case b0
            when 10
              # callsubr - local subroutine call
              # Pop biased index, inline the subroutine
              subr_index = pop_operand(operand_buffer)
              flush_operands(operand_buffer, output)
              inline_local_subr(subr_index, output, stack, depth)
            when 29
              # callgsubr - global subroutine call
              subr_index = pop_operand(operand_buffer)
              flush_operands(operand_buffer, output)
              inline_global_subr(subr_index, output, stack, depth)
            when 11
              # return - end of subroutine, don't write to output
              flush_operands(operand_buffer, output)
              return
            when 14
              # endchar - write it and stop
              flush_operands(operand_buffer, output)
              output.write_byte(14_u8)
              return
            when 28
              # 16-bit signed integer
              if i + 1 < data.size
                operand_buffer.write_byte(28_u8)
                operand_buffer.write_byte(data[i])
                operand_buffer.write_byte(data[i + 1])
                i += 2
              end
            when 32..246
              operand_buffer.write_byte(b0)
            when 247..250
              if i < data.size
                operand_buffer.write_byte(b0)
                operand_buffer.write_byte(data[i])
                i += 1
              end
            when 251..254
              if i < data.size
                operand_buffer.write_byte(b0)
                operand_buffer.write_byte(data[i])
                i += 1
              end
            when 255
              # 32-bit fixed point
              if i + 3 < data.size
                operand_buffer.write_byte(255_u8)
                4.times do
                  operand_buffer.write_byte(data[i])
                  i += 1
                end
              end
            when 12
              # Two-byte operator
              flush_operands(operand_buffer, output)
              output.write_byte(12_u8)
              if i < data.size
                output.write_byte(data[i])
                i += 1
              end
            else
              # Regular operator
              flush_operands(operand_buffer, output)
              output.write_byte(b0)
            end
          end

          flush_operands(operand_buffer, output)
        end

        private def pop_operand(buffer : IO::Memory) : Int32
          # Parse the last operand from buffer and remove it
          data = buffer.to_slice
          return 0 if data.empty?

          # Find the start of the last operand by scanning backwards
          # This is tricky - we need to find where the last number starts
          # For simplicity, we'll decode all operands and take the last one
          values = decode_operands(data)
          return 0 if values.empty?

          # Remove the last operand from buffer
          last_value = values.pop
          buffer.clear

          # Re-encode remaining operands
          values.each { |v| write_charstring_number(buffer, v) }

          last_value
        end

        private def decode_operands(data : Bytes) : Array(Int32)
          result = [] of Int32
          i = 0

          while i < data.size
            b0 = data[i]
            i += 1

            case b0
            when 28
              if i + 1 < data.size
                value = (data[i].to_i16 << 8) | data[i + 1].to_i16
                result << value.to_i32
                i += 2
              end
            when 32..246
              result << (b0.to_i32 - 139)
            when 247..250
              if i < data.size
                result << ((b0.to_i32 - 247) * 256 + data[i].to_i32 + 108)
                i += 1
              end
            when 251..254
              if i < data.size
                result << (-(b0.to_i32 - 251) * 256 - data[i].to_i32 - 108)
                i += 1
              end
            when 255
              if i + 3 < data.size
                value = (data[i].to_i32 << 24) | (data[i + 1].to_i32 << 16) |
                        (data[i + 2].to_i32 << 8) | data[i + 3].to_i32
                # Fixed point 16.16
                result << (value >> 16)  # Just take integer part for index
                i += 4
              end
            end
          end

          result
        end

        private def write_charstring_number(io : IO, value : Int32) : Nil
          if value >= -107 && value <= 107
            io.write_byte((value + 139).to_u8)
          elsif value >= 108 && value <= 1131
            adjusted = value - 108
            io.write_byte((247 + (adjusted >> 8)).to_u8)
            io.write_byte((adjusted & 0xFF).to_u8)
          elsif value >= -1131 && value <= -108
            adjusted = -value - 108
            io.write_byte((251 + (adjusted >> 8)).to_u8)
            io.write_byte((adjusted & 0xFF).to_u8)
          else
            io.write_byte(28_u8)
            io.write_byte(((value >> 8) & 0xFF).to_u8)
            io.write_byte((value & 0xFF).to_u8)
          end
        end

        private def flush_operands(buffer : IO::Memory, output : IO) : Nil
          data = buffer.to_slice
          output.write(data) unless data.empty?
          buffer.clear
        end

        private def inline_local_subr(biased_index : Int32, output : IO, stack : Array(Bytes), depth : Int32) : Nil
          subrs = @local_subrs
          return unless subrs

          # Calculate bias
          bias = subr_bias(subrs.size)
          actual_index = biased_index + bias

          return if actual_index < 0 || actual_index >= subrs.size

          subr_data = subrs[actual_index]
          execute_with_inlining(subr_data, output, stack, depth + 1)
        end

        private def inline_global_subr(biased_index : Int32, output : IO, stack : Array(Bytes), depth : Int32) : Nil
          # Calculate bias
          bias = subr_bias(@global_subrs.size)
          actual_index = biased_index + bias

          return if actual_index < 0 || actual_index >= @global_subrs.size

          subr_data = @global_subrs[actual_index]
          execute_with_inlining(subr_data, output, stack, depth + 1)
        end

        private def subr_bias(count : Int32) : Int32
          if count < 1240
            107
          elsif count < 33900
            1131
          else
            32768
          end
        end

        extend IOHelpers
      end
    end
  end
end
