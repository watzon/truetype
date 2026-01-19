module TrueType
  module Tables
    module Metadata
      # The 'PCLT' table contains information needed to use the font with
      # PCL (Printer Command Language) printers.
      # This is a legacy table mainly for HP LaserJet compatibility.
      class PCLT
        include IOHelpers

        # Table version (should be 1.0 = 0x00010000)
        getter version : UInt32

        # Font number (vendor-assigned)
        getter font_number : UInt32

        # Character width (for fixed-pitch fonts)
        getter pitch : UInt16

        # x-height of lowercase characters
        getter x_height : UInt16

        # Style word (describes font style)
        getter style : UInt16

        # Type family (identifies typeface family)
        getter type_family : UInt16

        # Height of capital letters
        getter cap_height : UInt16

        # Symbol set (character encoding)
        getter symbol_set : UInt16

        # Typeface string (16 characters, null-padded)
        getter typeface : String

        # Character complement (8 bytes)
        getter character_complement : Bytes

        # File name (6 characters, null-padded)
        getter file_name : String

        # Stroke weight (-7 to 7, 0 = medium)
        getter stroke_weight : Int8

        # Width type (-5 to 5, 0 = normal)
        getter width_type : Int8

        # Serif style (0 = sans-serif)
        getter serif_style : UInt8

        # Reserved byte
        getter reserved : UInt8

        def initialize(
          @version : UInt32,
          @font_number : UInt32,
          @pitch : UInt16,
          @x_height : UInt16,
          @style : UInt16,
          @type_family : UInt16,
          @cap_height : UInt16,
          @symbol_set : UInt16,
          @typeface : String,
          @character_complement : Bytes,
          @file_name : String,
          @stroke_weight : Int8,
          @width_type : Int8,
          @serif_style : UInt8,
          @reserved : UInt8
        )
        end

        def self.parse(data : Bytes) : PCLT
          io = IO::Memory.new(data)

          version = read_uint32(io)
          font_number = read_uint32(io)
          pitch = read_uint16(io)
          x_height = read_uint16(io)
          style = read_uint16(io)
          type_family = read_uint16(io)
          cap_height = read_uint16(io)
          symbol_set = read_uint16(io)

          # Read typeface (16 bytes)
          typeface_bytes = Bytes.new(16)
          io.read(typeface_bytes)
          typeface = String.new(typeface_bytes).rstrip('\0')

          # Read character complement (8 bytes)
          character_complement = Bytes.new(8)
          io.read(character_complement)

          # Read file name (6 bytes)
          file_name_bytes = Bytes.new(6)
          io.read(file_name_bytes)
          file_name = String.new(file_name_bytes).rstrip('\0')

          stroke_weight = read_int8(io)
          width_type = read_int8(io)
          serif_style = read_uint8(io)
          reserved = read_uint8(io)

          new(
            version, font_number, pitch, x_height, style, type_family,
            cap_height, symbol_set, typeface, character_complement,
            file_name, stroke_weight, width_type, serif_style, reserved
          )
        end

        # Check if this is a fixed-pitch font
        def fixed_pitch? : Bool
          @pitch != 0
        end

        # Get stroke weight description
        def stroke_weight_name : String
          case @stroke_weight
          when -7 then "Ultra Thin"
          when -6 then "Extra Thin"
          when -5 then "Thin"
          when -4 then "Extra Light"
          when -3 then "Light"
          when -2 then "Demi Light"
          when -1 then "Semi Light"
          when 0  then "Medium"
          when 1  then "Semi Bold"
          when 2  then "Demi Bold"
          when 3  then "Bold"
          when 4  then "Extra Bold"
          when 5  then "Black"
          when 6  then "Extra Black"
          when 7  then "Ultra Black"
          else         "Unknown"
          end
        end

        # Get width type description
        def width_type_name : String
          case @width_type
          when -5 then "Ultra Compressed"
          when -4 then "Extra Compressed"
          when -3 then "Compressed"
          when -2 then "Condensed"
          when -1 then "Semi Condensed"
          when 0  then "Normal"
          when 1  then "Semi Expanded"
          when 2  then "Expanded"
          when 3  then "Extra Expanded"
          when 4  then "Ultra Expanded"
          else         "Unknown"
          end
        end

        # Check if this is a serif font
        def serif? : Bool
          @serif_style != 0 && @serif_style <= 10
        end

        # Check if this is a sans-serif font
        def sans_serif? : Bool
          @serif_style == 0
        end

        extend IOHelpers
      end
    end
  end
end
