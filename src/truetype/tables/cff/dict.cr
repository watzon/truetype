module TrueType
  module Tables
    module CFF
      # DICT operand value
      alias DictValue = Int32 | Float64 | Array(Int32) | Array(Float64)

      # CFF DICT parser for Top DICT and Private DICT
      class Dict
        include IOHelpers

        # Parsed key-value pairs
        getter entries : Hash(Int32, DictValue)

        def initialize(@entries : Hash(Int32, DictValue) = {} of Int32 => DictValue)
        end

        def self.parse(data : Bytes) : Dict
          entries = {} of Int32 => DictValue
          return new(entries) if data.empty?

          io = IO::Memory.new(data)
          operands = [] of DictValue

          while io.pos < data.size
            b0 = read_uint8(io)

            case b0
            when 0..11
              # Operator
              operator = b0.to_i32
              store_operands(entries, operator, operands)
              operands.clear
            when 12
              # Two-byte operator
              b1 = read_uint8(io)
              operator = 1200 + b1.to_i32
              store_operands(entries, operator, operands)
              operands.clear
            when 13..18
              # Operator
              operator = b0.to_i32
              store_operands(entries, operator, operands)
              operands.clear
            when 19..20
              # Operator
              operator = b0.to_i32
              store_operands(entries, operator, operands)
              operands.clear
            when 21..27
              # Reserved (treat as operator)
              operator = b0.to_i32
              store_operands(entries, operator, operands)
              operands.clear
            when 28
              # 16-bit signed integer
              b1 = read_uint8(io)
              b2 = read_uint8(io)
              unsigned = (b1.to_u16 << 8) | b2.to_u16
              value = unsigned.to_i16!.to_i32
              operands << value
            when 29
              # 32-bit signed integer
              b1 = read_uint8(io)
              b2 = read_uint8(io)
              b3 = read_uint8(io)
              b4 = read_uint8(io)
              value = (b1.to_i32 << 24) | (b2.to_i32 << 16) | (b3.to_i32 << 8) | b4.to_i32
              operands << value
            when 30
              # Real number
              operands << read_real(io)
            when 32..246
              # Small integer
              operands << (b0.to_i32 - 139)
            when 247..250
              # Positive integer
              b1 = read_uint8(io)
              operands << ((b0.to_i32 - 247) * 256 + b1.to_i32 + 108)
            when 251..254
              # Negative integer
              b1 = read_uint8(io)
              operands << (-(b0.to_i32 - 251) * 256 - b1.to_i32 - 108)
            when 255
              # Reserved
              break
            end
          end

          new(entries)
        end

        private def self.store_operands(entries : Hash(Int32, DictValue), op : Int32, operands : Array(DictValue))
          return if operands.empty?

          if operands.size == 1
            entries[op] = operands[0]
          else
            # Check if all integers
            if operands.all? { |v| v.is_a?(Int32) }
              entries[op] = operands.map { |v| v.as(Int32) }
            else
              entries[op] = operands.map { |v| v.is_a?(Float64) ? v : v.as(Int32).to_f64 }
            end
          end
        end

        private def self.read_real(io : IO) : Float64
          str = String.build do |s|
            loop do
              b = read_uint8(io)
              nibbles = [(b >> 4) & 0x0F, b & 0x0F]

              nibbles.each do |n|
                case n
                when 0..9  then s << ('0'.ord + n).chr
                when 0x0A  then s << '.'
                when 0x0B  then s << 'E'
                when 0x0C  then s << "E-"
                when 0x0E  then s << '-'
                when 0x0F  then return s.to_s.to_f64
                end
              end
            end
          end
          str.to_f64
        rescue
          0.0
        end

        # Get integer value
        def int(key : Int32, default : Int32 = 0) : Int32
          value = @entries[key]?
          case value
          when Int32   then value
          when Float64 then value.to_i32
          else              default
          end
        end

        # Get float value
        def float(key : Int32, default : Float64 = 0.0) : Float64
          value = @entries[key]?
          case value
          when Float64 then value
          when Int32   then value.to_f64
          else              default
          end
        end

        # Get array of integers
        def int_array(key : Int32) : Array(Int32)
          value = @entries[key]?
          case value
          when Array(Int32)   then value
          when Array(Float64) then value.map(&.to_i32)
          when Int32          then [value]
          when Float64        then [value.to_i32]
          else                     [] of Int32
          end
        end

        # Check if key exists
        def has?(key : Int32) : Bool
          @entries.has_key?(key)
        end

        extend IOHelpers
      end

      # Standard DICT operator codes
      module DictOp
        VERSION             =  0
        NOTICE              =  1
        FULL_NAME           =  2
        FAMILY_NAME         =  3
        WEIGHT              =  4
        FONT_BBOX           =  5
        UNIQUE_ID           = 13
        XUID                = 14
        CHARSET             = 15
        ENCODING            = 16
        CHAR_STRINGS        = 17
        PRIVATE             = 18
        COPYRIGHT           = 1200
        IS_FIXED_PITCH      = 1201
        ITALIC_ANGLE        = 1202
        UNDERLINE_POSITION  = 1203
        UNDERLINE_THICKNESS = 1204
        PAINT_TYPE          = 1205
        CHARSTRING_TYPE     = 1206
        FONT_MATRIX         = 1207
        STROKE_WIDTH        = 1208
        SYNTHETIC_BASE      = 1220
        POST_SCRIPT         = 1221
        BASE_FONT_NAME      = 1222
        BASE_FONT_BLEND     = 1223
        ROS                 = 1230
        CID_FONT_VERSION    = 1231
        CID_FONT_REVISION   = 1232
        CID_FONT_TYPE       = 1233
        CID_COUNT           = 1234
        UID_BASE            = 1235
        FD_ARRAY            = 1236
        FD_SELECT           = 1237
        FONT_NAME           = 1238

        # Private DICT operators
        BLUE_VALUES         =  6
        OTHER_BLUES         =  7
        FAMILY_BLUES        =  8
        FAMILY_OTHER_BLUES  =  9
        STD_HW              = 10
        STD_VW              = 11
        SUBRS               = 19
        DEFAULT_WIDTH_X     = 20
        NOMINAL_WIDTH_X     = 21
        BLUE_SCALE          = 1209
        BLUE_SHIFT          = 1210
        BLUE_FUZZ           = 1211
        STEM_SNAP_H         = 1212
        STEM_SNAP_V         = 1213
        FORCE_BOLD          = 1214
        LANGUAGE_GROUP      = 1217
        EXPANSION_FACTOR    = 1218
        INITIAL_RANDOM_SEED = 1219
      end
    end
  end
end
