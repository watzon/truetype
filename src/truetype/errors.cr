# Enhanced error handling for TrueType font parsing.
#
# This module provides detailed error messages with byte offsets
# and contextual information for debugging font parsing issues.

module TrueType
  # Base exception for all TrueType errors
  class Error < Exception
    # The byte offset where the error occurred (if applicable)
    getter offset : Int64?

    # The table tag where the error occurred (if applicable)
    getter table : String?

    def initialize(message : String, @offset : Int64? = nil, @table : String? = nil, cause : Exception? = nil)
      super(message, cause)
    end

    # Format error with offset information
    def to_s(io : IO) : Nil
      io << message
      if offset = @offset
        io << " (at offset 0x" << offset.to_s(16).upcase << ")"
      end
      if table = @table
        io << " [table: " << table << "]"
      end
    end
  end

  # Error during font parsing
  class ParseError < Error
    def initialize(message : String, offset : Int64? = nil, table : String? = nil, cause : Exception? = nil)
      super(message, offset, table, cause)
    end

    # Create a parse error with offset
    def self.at(offset : Int64, message : String, table : String? = nil) : ParseError
      new(message, offset, table)
    end

    # Create from an IO position
    def self.at_io(io : IO, message : String, table : String? = nil) : ParseError
      new(message, io.pos, table)
    end
  end

  # Error when a required table is missing
  class MissingTableError < ParseError
    getter table_tag : String

    def initialize(@table_tag : String)
      super("Missing required table: #{@table_tag}", table: @table_tag)
    end
  end

  # Error when a table is malformed
  class MalformedTableError < ParseError
    def initialize(table_tag : String, message : String, offset : Int64? = nil)
      super("Malformed #{table_tag} table: #{message}", offset, table_tag)
    end
  end

  # Error when an unsupported format is encountered
  class UnsupportedFormatError < ParseError
    getter format_version : UInt32?

    def initialize(message : String, @format_version : UInt32? = nil, offset : Int64? = nil, table : String? = nil)
      super(message, offset, table)
    end
  end

  # Error during font subsetting
  class SubsetError < Error
    def initialize(message : String, cause : Exception? = nil)
      super(message, cause: cause)
    end
  end

  # Error during glyph outline extraction
  class OutlineError < Error
    getter glyph_id : UInt16?

    def initialize(message : String, @glyph_id : UInt16? = nil, offset : Int64? = nil)
      super(message, offset)
    end
  end

  # Warning (non-fatal issue) collected during parsing
  struct Warning
    # Warning message
    getter message : String

    # Byte offset where the warning occurred
    getter offset : Int64?

    # Table tag where the warning occurred
    getter table : String?

    # Severity: :info, :warning, :error (recoverable)
    getter severity : Symbol

    def initialize(@message : String, @offset : Int64? = nil, @table : String? = nil, @severity : Symbol = :warning)
    end

    def to_s(io : IO) : Nil
      io << "[" << @severity.to_s.upcase << "] " << @message
      if offset = @offset
        io << " (at offset 0x" << offset.to_s(16).upcase << ")"
      end
      if table = @table
        io << " [table: " << table << "]"
      end
    end
  end

  # Collector for warnings during parsing
  class WarningCollector
    getter warnings : Array(Warning)
    property? enabled : Bool

    def initialize(@enabled : Bool = false)
      @warnings = [] of Warning
    end

    # Add a warning
    def warn(message : String, offset : Int64? = nil, table : String? = nil) : Nil
      return unless @enabled
      @warnings << Warning.new(message, offset, table, :warning)
    end

    # Add an info message
    def info(message : String, offset : Int64? = nil, table : String? = nil) : Nil
      return unless @enabled
      @warnings << Warning.new(message, offset, table, :info)
    end

    # Add an error that was recovered from
    def recovered(message : String, offset : Int64? = nil, table : String? = nil) : Nil
      return unless @enabled
      @warnings << Warning.new(message, offset, table, :error)
    end

    # Clear all warnings
    def clear : Nil
      @warnings.clear
    end

    # Check if there are any warnings
    def any? : Bool
      !@warnings.empty?
    end

    # Number of warnings
    def size : Int32
      @warnings.size
    end

    # Iterate over warnings
    def each(& : Warning ->)
      @warnings.each { |w| yield w }
    end

    # Get warnings of a specific severity
    def by_severity(severity : Symbol) : Array(Warning)
      @warnings.select { |w| w.severity == severity }
    end

    # Get all error-level warnings
    def errors : Array(Warning)
      by_severity(:error)
    end

    # Check if there are any error-level warnings
    def errors? : Bool
      @warnings.any? { |w| w.severity == :error }
    end

    # Dump all warnings to a string
    def to_s(io : IO) : Nil
      @warnings.each_with_index do |w, i|
        io << "\n" if i > 0
        w.to_s(io)
      end
    end
  end

  # Font validation result
  struct ValidationResult
    # Whether the font is valid
    getter? valid : Bool

    # Collected warnings
    getter warnings : Array(Warning)

    # Critical errors that make the font unusable
    getter errors : Array(String)

    def initialize(@valid : Bool, @warnings : Array(Warning), @errors : Array(String))
    end

    # Check if there are any warnings
    def warnings? : Bool
      !@warnings.empty?
    end

    # Check if there are any errors
    def errors? : Bool
      !@errors.empty?
    end

    # Get a summary string
    def summary : String
      if @valid
        if @warnings.empty?
          "Font is valid"
        else
          "Font is valid with #{@warnings.size} warning(s)"
        end
      else
        "Font is invalid: #{@errors.size} error(s)"
      end
    end

    def to_s(io : IO) : Nil
      io << summary
      if @errors.any?
        io << "\n\nErrors:\n"
        @errors.each { |e| io << "  - " << e << "\n" }
      end
      if @warnings.any?
        io << "\n\nWarnings:\n"
        @warnings.each { |w| io << "  - "; w.to_s(io); io << "\n" }
      end
    end
  end

  # Font validator
  class Validator
    getter font : Parser
    getter warnings : WarningCollector
    @errors : Array(String)

    def initialize(@font : Parser)
      @warnings = WarningCollector.new(enabled: true)
      @errors = [] of String
    end

    # Run full validation
    def validate : ValidationResult
      @errors.clear
      @warnings.clear

      validate_required_tables
      validate_head
      validate_hhea
      validate_maxp
      validate_cmap
      validate_name

      if @font.truetype?
        validate_loca
        validate_glyf
      elsif @font.cff?
        validate_cff
      end

      ValidationResult.new(@errors.empty?, @warnings.warnings.dup, @errors.dup)
    end

    private def validate_required_tables
      required = ["head", "hhea", "maxp", "cmap", "name", "post", "hmtx"]
      required.each do |tag|
        unless @font.has_table?(tag)
          @errors << "Missing required table: #{tag}"
        end
      end

      if @font.truetype?
        ["glyf", "loca"].each do |tag|
          unless @font.has_table?(tag)
            @errors << "Missing required TrueType table: #{tag}"
          end
        end
      elsif @font.cff?
        unless @font.has_table?("CFF ") || @font.has_table?("CFF2")
          @errors << "Missing required CFF table"
        end
      end
    end

    private def validate_head
      return unless @font.has_table?("head")

      head = @font.head
      unless head.magic_number == 0x5F0F3CF5
        @errors << "Invalid head table magic number: 0x#{head.magic_number.to_s(16)}"
      end

      if head.units_per_em < 16 || head.units_per_em > 16384
        @warnings.warn("Unusual units_per_em: #{head.units_per_em}", table: "head")
      end
    end

    private def validate_hhea
      return unless @font.has_table?("hhea")

      hhea = @font.hhea
      if hhea.number_of_h_metrics == 0
        @errors << "hhea numberOfHMetrics is 0"
      end
    end

    private def validate_maxp
      return unless @font.has_table?("maxp")

      maxp = @font.maxp
      if maxp.num_glyphs == 0
        @warnings.warn("Font has 0 glyphs", table: "maxp")
      end
    end

    private def validate_cmap
      return unless @font.has_table?("cmap")

      cmap = @font.cmap
      if cmap.encoding_records.empty?
        @errors << "cmap table has no encoding records"
      end

      unicode_mapping = cmap.unicode_mapping
      if unicode_mapping.nil? || unicode_mapping.empty?
        @warnings.warn("No Unicode cmap found", table: "cmap")
      end
    end

    private def validate_name
      return unless @font.has_table?("name")

      name = @font.name
      if name.postscript_name.nil?
        @warnings.warn("No PostScript name in name table", table: "name")
      end
    end

    private def validate_loca
      return unless @font.has_table?("loca")

      loca = @font.loca
      maxp = @font.maxp

      # loca should have numGlyphs + 1 entries
      expected = maxp.num_glyphs.to_i32 + 1
      actual = loca.offsets.size
      if actual != expected
        @warnings.warn("loca table has #{actual} entries, expected #{expected}", table: "loca")
      end
    end

    private def validate_glyf
      return unless @font.has_table?("glyf") && @font.has_table?("loca")

      glyf_data = @font.table_data("glyf")
      return unless glyf_data

      loca = @font.loca
      maxp = @font.maxp

      # Check that glyph offsets are valid
      maxp.num_glyphs.times do |i|
        offset = loca.offset(i.to_u16)
        length = loca.length(i.to_u16)

        if offset > glyf_data.size
          @warnings.warn("Glyph #{i} offset (#{offset}) exceeds glyf table size", table: "glyf")
        elsif offset + length > glyf_data.size
          @warnings.warn("Glyph #{i} extends beyond glyf table", table: "glyf")
        end
      end
    end

    private def validate_cff
      return unless @font.has_table?("CFF ") || @font.has_table?("CFF2")

      cff = @font.cff_font
      if cff.nil?
        @warnings.warn("Could not parse CFF table", table: "CFF ")
      end
    end
  end
end
