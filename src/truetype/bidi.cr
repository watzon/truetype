# Unicode Bidirectional Algorithm (UAX #9) support.
#
# This implementation focuses on paragraph-level bidi resolution and line
# reordering so mixed-direction text can be laid out correctly without relying
# on external dependencies.

module TrueType
  module Bidi
    MAX_EXPLICIT_DEPTH = 125

    enum CharClass
      L
      R
      AL
      EN
      ES
      ET
      AN
      CS
      NSM
      BN
      B
      S
      WS
      ON
      LRE
      RLE
      LRO
      RLO
      PDF
      LRI
      RLI
      FSI
      PDI
    end

    enum PairedBracketType
      None
      Open
      Close
    end

    enum ParagraphDirection
      Auto
      LeftToRight
      RightToLeft
    end

    private struct EmbeddingState
      getter level : Int32
      getter override_class : CharClass?
      getter? isolate : Bool

      def initialize(@level : Int32, @override_class : CharClass? = nil, @isolate : Bool = false)
      end
    end

    struct Result
      getter text : String
      getter chars : Array(Char)
      getter original_classes : Array(CharClass)
      getter resolved_classes : Array(CharClass)
      getter levels : Array(Int32)
      getter base_level : Int32
      getter visual_to_logical : Array(Int32)
      getter logical_to_visual : Array(Int32)
      getter display_visual_to_logical : Array(Int32)
      getter display_logical_to_visual : Array(Int32)

      def initialize(
        @text : String,
        @chars : Array(Char),
        @original_classes : Array(CharClass),
        @resolved_classes : Array(CharClass),
        @levels : Array(Int32),
        @base_level : Int32,
        @visual_to_logical : Array(Int32),
        @logical_to_visual : Array(Int32),
        @display_visual_to_logical : Array(Int32),
        @display_logical_to_visual : Array(Int32),
      )
      end

      def base_direction : ParagraphDirection
        @base_level.odd? ? ParagraphDirection::RightToLeft : ParagraphDirection::LeftToRight
      end

      def visual_text : String
        String.build do |io|
          @display_visual_to_logical.each do |logical_index|
            io << @chars[logical_index]
          end
        end
      end
    end

    def self.resolve(text : String, direction_override : ParagraphDirection = ParagraphDirection::Auto) : Result
      chars = text.chars
      return empty_result(text, chars) if chars.empty?

      original_classes = chars.map { |char| bidi_class(char) }
      resolved_classes = original_classes.dup
      levels = Array.new(chars.size, 0)

      base_level = determine_paragraph_level(resolved_classes, chars, direction_override)

      apply_explicit_embeddings!(chars, resolved_classes, levels, base_level)
      resolve_weak_types!(resolved_classes, levels, base_level)
      resolve_brackets!(chars, resolved_classes, levels, base_level)
      resolve_neutral_types!(resolved_classes, levels, base_level)
      apply_implicit_levels!(resolved_classes, levels)
      apply_l1!(resolved_classes, levels, base_level)

      visual_to_logical = reorder_visual_indices(levels)
      logical_to_visual = invert_order(visual_to_logical)

      display_visual_to_logical = visual_to_logical.reject do |logical_index|
        removed_by_x9?(original_classes[logical_index])
      end
      display_logical_to_visual = Array.new(chars.size, -1)
      display_visual_to_logical.each_with_index do |logical_index, visual_index|
        display_logical_to_visual[logical_index] = visual_index
      end

      Result.new(
        text,
        chars,
        original_classes,
        resolved_classes,
        levels,
        base_level,
        visual_to_logical,
        logical_to_visual,
        display_visual_to_logical,
        display_logical_to_visual
      )
    end

    def self.reorder_visually(text : String, direction_override : ParagraphDirection = ParagraphDirection::Auto) : String
      resolve(text, direction_override).visual_text
    end

    def self.bidi_class(char : Char) : CharClass
      bidi_class(char.ord.to_u32)
    end

    def self.bidi_class(codepoint : UInt32) : CharClass
      klass = CharClass::L

      Data::BIDI_CLASS_RANGES.each do |start_cp, end_cp, klass_symbol|
        break if start_cp > codepoint
        next unless codepoint <= end_cp

        klass = symbol_to_class(klass_symbol)
      end

      klass
    end

    def self.paired_bracket(char : Char) : Char?
      paired = paired_bracket(char.ord.to_u32)
      paired ? paired.not_nil!.unsafe_chr : nil
    end

    def self.paired_bracket(codepoint : UInt32) : UInt32?
      Data::PAIRED_BRACKETS[codepoint]?.try(&.first)
    end

    def self.paired_bracket_type(char : Char) : PairedBracketType
      paired_bracket_type(char.ord.to_u32)
    end

    def self.paired_bracket_type(codepoint : UInt32) : PairedBracketType
      entry = Data::PAIRED_BRACKETS[codepoint]?
      return PairedBracketType::None unless entry

      entry[1] == :Open ? PairedBracketType::Open : PairedBracketType::Close
    end

    private def self.empty_result(text : String, chars : Array(Char)) : Result
      Result.new(
        text,
        chars,
        [] of CharClass,
        [] of CharClass,
        [] of Int32,
        0,
        [] of Int32,
        [] of Int32,
        [] of Int32,
        [] of Int32
      )
    end

    private def self.determine_paragraph_level(classes : Array(CharClass), chars : Array(Char), direction_override : ParagraphDirection) : Int32
      case direction_override
      when ParagraphDirection::LeftToRight
        return 0
      when ParagraphDirection::RightToLeft
        return 1
      else
        classes.each_with_index do |klass, index|
          case klass
          when CharClass::L
            return 0
          when CharClass::R, CharClass::AL
            return 1
          when CharClass::FSI
            direction = first_strong_isolate_direction(chars, index + 1, 0)
            return direction == ParagraphDirection::RightToLeft ? 1 : 0
          end
        end
      end

      0
    end

    private def self.apply_explicit_embeddings!(chars : Array(Char), classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      stack = [EmbeddingState.new(base_level)]
      overflow_isolate_count = 0
      overflow_embedding_count = 0
      valid_isolate_count = 0

      classes.each_with_index do |klass, index|
        current_level = stack.last.level

        case klass
        when CharClass::RLE, CharClass::LRE, CharClass::RLO, CharClass::LRO
          new_level = case klass
                      when CharClass::RLE, CharClass::RLO
                        least_greater_odd_level(current_level)
                      else
                        least_greater_even_level(current_level)
                      end

          if new_level <= MAX_EXPLICIT_DEPTH && overflow_isolate_count == 0 && overflow_embedding_count == 0
            override_class = case klass
                             when CharClass::RLO
                               CharClass::R
                             when CharClass::LRO
                               CharClass::L
                             else
                               nil
                             end
            stack << EmbeddingState.new(new_level, override_class)
          else
            overflow_embedding_count += 1
          end

          levels[index] = current_level
          classes[index] = CharClass::BN
        when CharClass::PDF
          if overflow_isolate_count > 0
            # In overflow isolate mode PDF has no effect.
          elsif overflow_embedding_count > 0
            overflow_embedding_count -= 1
          elsif stack.size > 1 && !stack.last.isolate?
            stack.pop
          end

          levels[index] = current_level
          classes[index] = CharClass::BN
        when CharClass::RLI, CharClass::LRI, CharClass::FSI
          isolate_direction = case klass
                              when CharClass::RLI
                                ParagraphDirection::RightToLeft
                              when CharClass::LRI
                                ParagraphDirection::LeftToRight
                              else
                                first_strong_isolate_direction(chars, index + 1, current_level)
                              end

          new_level = isolate_direction == ParagraphDirection::RightToLeft ? least_greater_odd_level(current_level) : least_greater_even_level(current_level)

          if new_level <= MAX_EXPLICIT_DEPTH && overflow_isolate_count == 0 && overflow_embedding_count == 0
            stack << EmbeddingState.new(new_level, nil, isolate: true)
            valid_isolate_count += 1
          else
            overflow_isolate_count += 1
          end

          levels[index] = current_level
          classes[index] = CharClass::BN
        when CharClass::PDI
          if overflow_isolate_count > 0
            overflow_isolate_count -= 1
          elsif valid_isolate_count > 0
            overflow_embedding_count = 0

            while stack.size > 1
              state = stack.pop
              break if state.isolate?
            end

            valid_isolate_count -= 1
          end

          levels[index] = stack.last.level
          classes[index] = CharClass::BN
        else
          levels[index] = current_level
          if override_class = stack.last.override_class
            classes[index] = override_class
          end
        end
      end
    end

    private def self.resolve_weak_types!(classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      # W1: NSM takes type of previous character.
      classes.each_index do |index|
        next unless classes[index] == CharClass::NSM

        classes[index] = previous_type_for_nsm(classes, levels, index, base_level)
      end

      # W2: EN after AL becomes AN.
      classes.each_with_index do |klass, index|
        next unless klass == CharClass::EN

        j = index - 1
        while j >= 0
          case classes[j]
          when CharClass::AL
            classes[index] = CharClass::AN
            break
          when CharClass::L, CharClass::R
            break
          end
          j -= 1
        end
      end

      # W3: Change AL to R.
      classes.map! { |klass| klass == CharClass::AL ? CharClass::R : klass }

      # W4: Resolve separators between numbers.
      1.upto(classes.size - 2) do |index|
        prev = classes[index - 1]
        curr = classes[index]
        nxt = classes[index + 1]

        if curr == CharClass::ES && prev == CharClass::EN && nxt == CharClass::EN
          classes[index] = CharClass::EN
        elsif curr == CharClass::CS && prev == CharClass::EN && nxt == CharClass::EN
          classes[index] = CharClass::EN
        elsif curr == CharClass::CS && prev == CharClass::AN && nxt == CharClass::AN
          classes[index] = CharClass::AN
        end
      end

      # W5: ET adjacent to EN becomes EN.
      index = 0
      while index < classes.size
        if classes[index] == CharClass::ET
          start = index
          index += 1
          while index < classes.size && classes[index] == CharClass::ET
            index += 1
          end
          stop = index - 1

          left_en = start > 0 && classes[start - 1] == CharClass::EN
          right_en = index < classes.size && classes[index] == CharClass::EN

          if left_en || right_en
            start.upto(stop) { |i| classes[i] = CharClass::EN }
          end
        else
          index += 1
        end
      end

      # W6: Remaining separators/terminators become ON.
      classes.map! do |klass|
        case klass
        when CharClass::ES, CharClass::ET, CharClass::CS
          CharClass::ON
        else
          klass
        end
      end

      # W7: EN following L strong type becomes L.
      classes.each_with_index do |klass, index|
        next unless klass == CharClass::EN

        j = index - 1
        while j >= 0
          case classes[j]
          when CharClass::L
            classes[index] = CharClass::L
            break
          when CharClass::R
            break
          end
          j -= 1
        end
      end
    end

    private def self.resolve_brackets!(chars : Array(Char), classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      pairs = find_bracket_pairs(chars)

      pairs.each do |open_index, close_index|
        direction = bracket_direction(classes, levels, open_index, close_index, base_level)
        classes[open_index] = direction
        classes[close_index] = direction
      end
    end

    private def self.resolve_neutral_types!(classes : Array(CharClass), levels : Array(Int32), _base_level : Int32)
      index = 0
      while index < classes.size
        unless neutral_type?(classes[index])
          index += 1
          next
        end

        start = index
        while index < classes.size && neutral_type?(classes[index])
          index += 1
        end
        stop = index - 1

        before = surrounding_strong_or_number(classes, start - 1, -1)
        after = surrounding_strong_or_number(classes, index, +1)

        resolved = if before && after && before == after
                     before
                   else
                     embedding_direction_for_level(levels[start])
                   end

        start.upto(stop) { |i| classes[i] = resolved }
      end
    end

    private def self.apply_implicit_levels!(classes : Array(CharClass), levels : Array(Int32))
      classes.each_with_index do |klass, index|
        next if klass == CharClass::BN

        if levels[index].even?
          case klass
          when CharClass::R
            levels[index] += 1
          when CharClass::AN, CharClass::EN
            levels[index] += 2
          end
        else
          case klass
          when CharClass::L, CharClass::AN, CharClass::EN
            levels[index] += 1
          end
        end
      end
    end

    private def self.apply_l1!(classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      classes.each_with_index do |klass, index|
        next unless klass == CharClass::B || klass == CharClass::S

        levels[index] = base_level

        j = index - 1
        while j >= 0
          break unless classes[j] == CharClass::WS || classes[j] == CharClass::BN

          levels[j] = base_level
          j -= 1
        end
      end

      j = classes.size - 1
      while j >= 0
        break unless classes[j] == CharClass::WS || classes[j] == CharClass::BN

        levels[j] = base_level
        j -= 1
      end
    end

    private def self.reorder_visual_indices(levels : Array(Int32)) : Array(Int32)
      visual = Array.new(levels.size) { |index| index }
      return visual if levels.empty?

      min_odd_level = levels.select(&.odd?).min?
      return visual unless min_odd_level

      current_level = levels.max
      while current_level >= min_odd_level
        index = 0
        while index < visual.size
          if levels[visual[index]] >= current_level
            start = index
            index += 1
            while index < visual.size && levels[visual[index]] >= current_level
              index += 1
            end
            reverse_slice!(visual, start, index)
          else
            index += 1
          end
        end

        current_level -= 1
      end

      visual
    end

    private def self.reverse_slice!(values : Array(Int32), start_index : Int32, end_index : Int32)
      left = start_index
      right = end_index - 1

      while left < right
        values[left], values[right] = values[right], values[left]
        left += 1
        right -= 1
      end
    end

    private def self.invert_order(visual_to_logical : Array(Int32)) : Array(Int32)
      logical_to_visual = Array.new(visual_to_logical.size, -1)
      visual_to_logical.each_with_index do |logical_index, visual_index|
        logical_to_visual[logical_index] = visual_index
      end
      logical_to_visual
    end

    private def self.find_bracket_pairs(chars : Array(Char)) : Array(Tuple(Int32, Int32))
      pairs = [] of Tuple(Int32, Int32)
      stack = [] of Tuple(Int32, UInt32)

      chars.each_with_index do |char, index|
        codepoint = char.ord.to_u32
        entry = Data::PAIRED_BRACKETS[codepoint]?
        next unless entry

        expected_pair = entry[0]
        type = entry[1]

        if type == :Open
          stack << {index, expected_pair}
          next
        end

        # Find the closest compatible opener and discard any unmatched inner openers.
        match_index = stack.size - 1
        while match_index >= 0
          break if stack[match_index][1] == codepoint
          match_index -= 1
        end

        next if match_index < 0

        open_index = stack[match_index][0]
        pairs << {open_index, index}
        stack = match_index > 0 ? stack[0...match_index] : [] of Tuple(Int32, UInt32)
      end

      pairs
    end

    private def self.bracket_direction(classes : Array(CharClass), levels : Array(Int32), open_index : Int32, close_index : Int32, _base_level : Int32) : CharClass
      has_l = false
      has_r = false

      (open_index + 1).upto(close_index - 1) do |index|
        has_l ||= classes[index] == CharClass::L
        has_r ||= classes[index] == CharClass::R
      end

      return CharClass::L if has_l && !has_r
      return CharClass::R if has_r && !has_l

      embedding_direction = embedding_direction_for_level(levels[open_index])

      before = surrounding_strong_or_number(classes, open_index - 1, -1)
      after = surrounding_strong_or_number(classes, close_index + 1, +1)

      if before && after && before == after
        before
      elsif before
        before
      elsif after
        after
      else
        embedding_direction
      end
    end

    private def self.previous_type_for_nsm(classes : Array(CharClass), levels : Array(Int32), index : Int32, base_level : Int32) : CharClass
      j = index - 1
      while j >= 0
        return classes[j] unless classes[j] == CharClass::BN
        j -= 1
      end

      embedding_direction_for_level(index < levels.size ? levels[index] : base_level)
    end

    private def self.surrounding_strong_or_number(classes : Array(CharClass), start_index : Int32, step : Int32) : CharClass?
      index = start_index
      while index >= 0 && index < classes.size
        case classes[index]
        when CharClass::L
          return CharClass::L
        when CharClass::R, CharClass::AN, CharClass::EN
          return CharClass::R
        end

        index += step
      end

      nil
    end

    private def self.neutral_type?(klass : CharClass) : Bool
      case klass
      when CharClass::WS, CharClass::ON, CharClass::B, CharClass::S, CharClass::BN
        true
      else
        false
      end
    end

    private def self.removed_by_x9?(klass : CharClass) : Bool
      case klass
      when CharClass::BN,
           CharClass::LRE, CharClass::RLE, CharClass::LRO, CharClass::RLO,
           CharClass::PDF, CharClass::LRI, CharClass::RLI, CharClass::FSI,
           CharClass::PDI
        true
      else
        false
      end
    end

    private def self.embedding_direction_for_level(level : Int32) : CharClass
      level.odd? ? CharClass::R : CharClass::L
    end

    private def self.least_greater_even_level(level : Int32) : Int32
      level.even? ? level + 2 : level + 1
    end

    private def self.least_greater_odd_level(level : Int32) : Int32
      level.even? ? level + 1 : level + 2
    end

    private def self.first_strong_isolate_direction(chars : Array(Char), start_index : Int32, default_level : Int32) : ParagraphDirection
      isolate_depth = 0
      index = start_index

      while index < chars.size
        klass = bidi_class(chars[index])

        case klass
        when CharClass::L
          return ParagraphDirection::LeftToRight
        when CharClass::R, CharClass::AL
          return ParagraphDirection::RightToLeft
        when CharClass::LRI, CharClass::RLI, CharClass::FSI
          isolate_depth += 1
        when CharClass::PDI
          if isolate_depth == 0
            break
          end
          isolate_depth -= 1
        end

        index += 1
      end

      default_level.odd? ? ParagraphDirection::RightToLeft : ParagraphDirection::LeftToRight
    end

    private def self.symbol_to_class(symbol : Symbol) : CharClass
      case symbol
      when :L   then CharClass::L
      when :R   then CharClass::R
      when :AL  then CharClass::AL
      when :EN  then CharClass::EN
      when :ES  then CharClass::ES
      when :ET  then CharClass::ET
      when :AN  then CharClass::AN
      when :CS  then CharClass::CS
      when :NSM then CharClass::NSM
      when :BN  then CharClass::BN
      when :B   then CharClass::B
      when :S   then CharClass::S
      when :WS  then CharClass::WS
      when :ON  then CharClass::ON
      when :LRE then CharClass::LRE
      when :RLE then CharClass::RLE
      when :LRO then CharClass::LRO
      when :RLO then CharClass::RLO
      when :PDF then CharClass::PDF
      when :LRI then CharClass::LRI
      when :RLI then CharClass::RLI
      when :FSI then CharClass::FSI
      when :PDI then CharClass::PDI
      else
        CharClass::L
      end
    end
  end
end
