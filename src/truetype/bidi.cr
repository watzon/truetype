# Unicode Bidirectional Algorithm (UAX #9) support.
#
# This implementation resolves paragraph levels, explicit embeddings/isolates,
# weak/neutral classes, implicit levels, and visual reordering for a single line.

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

    private struct LevelRun
      getter start : Int32
      getter stop : Int32

      def initialize(@start : Int32, @stop : Int32)
      end
    end

    private struct IsolatingRunSequence
      getter runs : Array(LevelRun)
      getter indices : Array(Int32)
      getter sos : CharClass
      getter eos : CharClass

      def initialize(@runs : Array(LevelRun), @indices : Array(Int32), @sos : CharClass, @eos : CharClass)
      end
    end

    private struct BracketPair
      getter start_pos : Int32
      getter end_pos : Int32

      def initialize(@start_pos : Int32, @end_pos : Int32)
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
            char = @chars[logical_index]
            if @levels[logical_index].odd?
              io << (Bidi.mirrored_char(char) || char)
            else
              io << char
            end
          end
        end
      end
    end

    def self.resolve(text : String, direction_override : ParagraphDirection = ParagraphDirection::Auto) : Result
      chars = text.chars
      return empty_result(text, chars) if chars.empty?

      original_classes = chars.map { |char| bidi_class(char) }
      processing_classes = original_classes.dup
      levels = Array.new(chars.size, 0)

      base_level = determine_paragraph_level(processing_classes, chars, direction_override)

      level_runs = [] of LevelRun
      apply_explicit_embeddings!(chars, original_classes, processing_classes, levels, base_level, level_runs)

      sequences = build_isolating_run_sequences(original_classes, levels, level_runs, base_level)
      sequences.each do |sequence|
        resolve_weak_types!(sequence, processing_classes)
        resolve_neutral_types!(sequence, chars, original_classes, processing_classes, levels)
      end

      apply_implicit_levels!(processing_classes, levels)
      assign_levels_to_removed_chars!(original_classes, levels, base_level)
      apply_l1!(original_classes, levels, base_level)

      visual_to_logical = reorder_visual_indices(levels)
      logical_to_visual = invert_order(visual_to_logical)

      display_visual_to_logical = visual_to_logical.reject do |logical_index|
        display_ignorable?(original_classes[logical_index])
      end
      display_logical_to_visual = Array.new(chars.size, -1)
      display_visual_to_logical.each_with_index do |logical_index, visual_index|
        display_logical_to_visual[logical_index] = visual_index
      end

      Result.new(
        text,
        chars,
        original_classes,
        processing_classes,
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

    def self.mirrored_char(char : Char) : Char?
      paired_bracket(char)
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

    private def self.determine_paragraph_level(classes : Array(CharClass), _chars : Array(Char), direction_override : ParagraphDirection) : Int32
      case direction_override
      when ParagraphDirection::LeftToRight
        return 0
      when ParagraphDirection::RightToLeft
        return 1
      else
        isolate_stack = [] of Int32

        classes.each_with_index do |klass, index|
          case klass
          when CharClass::L
            if isolate_start = isolate_stack.last?
              classes[isolate_start] = CharClass::LRI if classes[isolate_start] == CharClass::FSI
            else
              return 0
            end
          when CharClass::R, CharClass::AL
            if isolate_start = isolate_stack.last?
              classes[isolate_start] = CharClass::RLI if classes[isolate_start] == CharClass::FSI
            else
              return 1
            end
          when CharClass::RLI, CharClass::LRI, CharClass::FSI
            isolate_stack << index
          when CharClass::PDI
            isolate_stack.pop?
          end
        end
      end

      0
    end

    private def self.apply_explicit_embeddings!(
      chars : Array(Char),
      original_classes : Array(CharClass),
      classes : Array(CharClass),
      levels : Array(Int32),
      base_level : Int32,
      level_runs : Array(LevelRun),
    )
      stack = [EmbeddingState.new(base_level)]
      overflow_isolate_count = 0
      overflow_embedding_count = 0
      valid_isolate_count = 0

      current_run_level = base_level
      current_run_start = 0

      original_classes.each_with_index do |klass, index|
        current_state = stack.last
        current_level = current_state.level

        case klass
        when CharClass::RLE, CharClass::LRE, CharClass::RLO, CharClass::LRO, CharClass::RLI, CharClass::LRI, CharClass::FSI
          levels[index] = current_level

          is_isolate = isolate_initiator?(klass)
          if is_isolate
            if override_class = current_state.override_class
              classes[index] = override_class
            else
              classes[index] = klass
            end
          end

          target_rtl = case klass
                       when CharClass::RLE, CharClass::RLO, CharClass::RLI
                         true
                       when CharClass::FSI
                         first_strong_isolate_direction(chars, index + 1, 0) == ParagraphDirection::RightToLeft
                       else
                         false
                       end

          new_level = target_rtl ? least_greater_odd_level(current_level) : least_greater_even_level(current_level)

          if new_level <= MAX_EXPLICIT_DEPTH && overflow_isolate_count == 0 && overflow_embedding_count == 0
            override_class = case klass
                             when CharClass::RLO
                               CharClass::R
                             when CharClass::LRO
                               CharClass::L
                             else
                               nil
                             end

            stack << EmbeddingState.new(new_level, override_class, isolate: is_isolate)

            if is_isolate
              valid_isolate_count += 1
            else
              # Match Unicode reference behavior for retained explicit controls.
              levels[index] = new_level
            end
          else
            if is_isolate
              overflow_isolate_count += 1
            elsif overflow_isolate_count == 0
              overflow_embedding_count += 1
            end
          end

          classes[index] = CharClass::BN unless is_isolate
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

          state = stack.last
          levels[index] = state.level
          if override_class = state.override_class
            classes[index] = override_class
          else
            classes[index] = CharClass::PDI
          end
        when CharClass::PDF
          if overflow_isolate_count > 0
            # In overflow isolate mode, PDF has no effect.
          elsif overflow_embedding_count > 0
            overflow_embedding_count -= 1
          elsif stack.size > 1 && !stack.last.isolate?
            stack.pop
          end

          levels[index] = stack.last.level
          classes[index] = CharClass::BN
        when CharClass::B
          # X8: Paragraph separators reset the embedding state.
          levels[index] = base_level
          classes[index] = CharClass::B
          stack = [EmbeddingState.new(base_level)]
          overflow_isolate_count = 0
          overflow_embedding_count = 0
          valid_isolate_count = 0
        else
          levels[index] = current_level

          if override_class = current_state.override_class
            # Keep retained BNs intact (Unicode retaining explicit formatting chars).
            classes[index] = override_class unless klass == CharClass::BN
          else
            classes[index] = klass
          end
        end

        if index == 0
          current_run_level = levels[index]
        elsif !removed_by_x9?(original_classes[index]) && levels[index] != current_run_level
          level_runs << LevelRun.new(current_run_start, index)
          current_run_level = levels[index]
          current_run_start = index
        end
      end

      level_runs << LevelRun.new(current_run_start, levels.size.to_i32) if levels.size > current_run_start
    end

    private def self.build_isolating_run_sequences(
      original_classes : Array(CharClass),
      levels : Array(Int32),
      level_runs : Array(LevelRun),
      base_level : Int32,
    ) : Array(IsolatingRunSequence)
      return [] of IsolatingRunSequence if level_runs.empty?

      has_isolate_controls = original_classes.any? { |klass| isolate_control?(klass) }
      sequences = [] of IsolatingRunSequence

      unless has_isolate_controls
        level_runs.each do |run|
          runs = [run]
          indices = flatten_runs(runs)

          first_index = first_non_removed_index(indices, original_classes) || run.start
          last_index = last_non_removed_index(indices, original_classes) || (run.stop - 1)

          seq_level = levels[first_index]
          end_level = levels[last_index]
          pred_level = previous_non_removed_level(original_classes, levels, run.start, base_level)
          succ_level = next_non_removed_level(original_classes, levels, run.stop, base_level)

          sos = embedding_direction_for_level(max_level(seq_level, pred_level))
          eos = embedding_direction_for_level(max_level(end_level, succ_level))

          sequences << IsolatingRunSequence.new(runs, indices, sos, eos)
        end

        return sequences
      end

      run_sequences = [] of Array(LevelRun)
      stack = [([] of LevelRun)]

      level_runs.each do |run|
        start_class = original_classes[run.start]
        end_class = last_non_removed_class_in_run(original_classes, run) || start_class

        current_sequence = if start_class == CharClass::PDI && stack.size > 1
                             stack.pop
                           else
                             [] of LevelRun
                           end

        current_sequence << run

        if isolate_initiator?(end_class)
          stack << current_sequence
        else
          run_sequences << current_sequence
        end
      end

      stack.reverse_each do |sequence|
        run_sequences << sequence unless sequence.empty?
      end

      run_sequences.each do |runs|
        indices = flatten_runs(runs)

        first_index = first_non_removed_index(indices, original_classes) || runs.first.start
        last_index = last_non_removed_index(indices, original_classes) || (runs.last.stop - 1)

        seq_level = levels[first_index]
        end_level = levels[last_index]

        start_of_sequence = runs.first.start
        end_of_sequence = runs.last.stop

        pred_level = previous_non_removed_level(original_classes, levels, start_of_sequence, base_level)

        last_non_removed_before_end = last_non_removed_class_before(original_classes, end_of_sequence)
        succ_level = if last_non_removed_before_end && isolate_initiator?(last_non_removed_before_end)
                       base_level
                     else
                       next_non_removed_level(original_classes, levels, end_of_sequence, base_level)
                     end

        sos = embedding_direction_for_level(max_level(seq_level, pred_level))
        eos = embedding_direction_for_level(max_level(end_level, succ_level))

        sequences << IsolatingRunSequence.new(runs, indices, sos, eos)
      end

      sequences
    end

    private def self.resolve_weak_types!(sequence : IsolatingRunSequence, classes : Array(CharClass))
      prev_class_before_w4 = sequence.sos
      prev_class_before_w5 = sequence.sos
      prev_class_before_w1 = sequence.sos
      last_strong_is_al = false

      et_run_positions = [] of Int32
      bn_run_positions = [] of Int32

      indices = sequence.indices
      pos = 0

      while pos < indices.size
        index = indices[pos]

        if classes[index] == CharClass::BN
          bn_run_positions << pos
          pos += 1
          next
        end

        w2_processing_class = classes[index]

        # W1
        if classes[index] == CharClass::NSM
          classes[index] = case prev_class_before_w1
                           when CharClass::RLI, CharClass::LRI, CharClass::FSI, CharClass::PDI
                             CharClass::ON
                           else
                             prev_class_before_w1
                           end
          w2_processing_class = classes[index]
        end

        prev_class_before_w1 = classes[index]

        # W2 + W3
        case classes[index]
        when CharClass::EN
          classes[index] = CharClass::AN if last_strong_is_al
        when CharClass::AL
          classes[index] = CharClass::R
        end

        case w2_processing_class
        when CharClass::L, CharClass::R
          last_strong_is_al = false
        when CharClass::AL
          last_strong_is_al = true
        end

        class_before_w456 = classes[index]

        # W4/W5/W6 (separators)
        case classes[index]
        when CharClass::EN
          et_run_positions.each { |et_pos| classes[indices[et_pos]] = CharClass::EN }
          et_run_positions.clear
        when CharClass::ES, CharClass::CS
          next_class = sequence.eos
          lookahead = pos + 1

          while lookahead < indices.size
            lookahead_class = classes[indices[lookahead]]
            unless removed_by_x9?(lookahead_class)
              next_class = lookahead_class
              break
            end
            lookahead += 1
          end

          next_class = CharClass::AN if next_class == CharClass::EN && last_strong_is_al

          classes[index] = case {prev_class_before_w4, classes[index], next_class}
                           when {CharClass::EN, CharClass::ES, CharClass::EN},
                                {CharClass::EN, CharClass::CS, CharClass::EN}
                             CharClass::EN
                           when {CharClass::AN, CharClass::CS, CharClass::AN}
                             CharClass::AN
                           else
                             CharClass::ON
                           end

          if classes[index] == CharClass::ON
            left = pos - 1
            while left >= 0
              left_index = indices[left]
              break unless classes[left_index] == CharClass::BN

              classes[left_index] = CharClass::ON
              left -= 1
            end

            right = pos + 1
            while right < indices.size
              right_index = indices[right]
              break unless classes[right_index] == CharClass::BN

              classes[right_index] = CharClass::ON
              right += 1
            end
          end
        when CharClass::ET
          if prev_class_before_w5 == CharClass::EN
            classes[index] = CharClass::EN
          else
            et_run_positions.concat(bn_run_positions)
            et_run_positions << pos
          end
        end

        bn_run_positions.clear

        prev_class_before_w5 = classes[index]

        # W6 (terminators)
        if prev_class_before_w5 != CharClass::ET
          et_run_positions.each { |et_pos| classes[indices[et_pos]] = CharClass::ON }
          et_run_positions.clear
        end

        prev_class_before_w4 = class_before_w456

        pos += 1
      end

      et_run_positions.each { |et_pos| classes[indices[et_pos]] = CharClass::ON }

      # W7
      last_strong_is_l = sequence.sos == CharClass::L
      indices.each do |index|
        case classes[index]
        when CharClass::EN
          classes[index] = CharClass::L if last_strong_is_l
        when CharClass::L
          last_strong_is_l = true
        when CharClass::R, CharClass::AL
          last_strong_is_l = false
        end
      end
    end

    private def self.resolve_neutral_types!(
      sequence : IsolatingRunSequence,
      chars : Array(Char),
      original_classes : Array(CharClass),
      classes : Array(CharClass),
      levels : Array(Int32),
    )
      embedding_class = embedding_direction_for_level(levels[sequence.runs.first.start])
      opposite_embedding_class = embedding_class == CharClass::L ? CharClass::R : CharClass::L
      indices = sequence.indices

      bracket_pairs = identify_bracket_pairs(sequence, chars, classes)

      bracket_pairs.each do |pair|
        found_embedding = false
        found_opposite = false
        class_to_set : CharClass? = nil

        inside = pair.start_pos + 1
        while inside < pair.end_pos
          klass = classes[indices[inside]]

          if klass == embedding_class
            found_embedding = true
          elsif klass == opposite_embedding_class
            found_opposite = true
          elsif klass == CharClass::EN || klass == CharClass::AN
            if embedding_class == CharClass::L
              found_opposite = true
            else
              found_embedding = true
            end
          end

          break if found_embedding
          inside += 1
        end

        if found_embedding
          class_to_set = embedding_class
        elsif found_opposite
          previous_strong = sequence.sos

          back = pair.start_pos - 1
          while back >= 0
            klass = classes[indices[back]]

            case klass
            when CharClass::L
              previous_strong = CharClass::L
              break
            when CharClass::R, CharClass::EN, CharClass::AN
              previous_strong = CharClass::R
              break
            end

            back -= 1
          end

          class_to_set = previous_strong
        end

        next unless class_to_set

        open_index = indices[pair.start_pos]
        close_index = indices[pair.end_pos]

        classes[open_index] = class_to_set
        classes[close_index] = class_to_set

        left = pair.start_pos - 1
        while left >= 0
          index = indices[left]
          break unless classes[index] == CharClass::BN

          classes[index] = class_to_set
          left -= 1
        end

        right = pair.start_pos + 1
        while right < indices.size
          index = indices[right]
          if original_classes[index] == CharClass::NSM || classes[index] == CharClass::BN
            classes[index] = class_to_set
            right += 1
          else
            break
          end
        end

        right = pair.end_pos + 1
        while right < indices.size
          index = indices[right]
          if original_classes[index] == CharClass::NSM || classes[index] == CharClass::BN
            classes[index] = class_to_set
            right += 1
          else
            break
          end
        end
      end

      # N1/N2
      pos = 0
      prev_class = sequence.sos

      while pos < indices.size
        index = indices[pos]

        if ni_type?(classes[index]) || classes[index] == CharClass::BN
          run_start = pos
          pos += 1

          while pos < indices.size
            run_class = classes[indices[pos]]
            break unless ni_type?(run_class) || run_class == CharClass::BN

            pos += 1
          end

          next_class = pos < indices.size ? classes[indices[pos]] : sequence.eos

          resolved = if prev_class == CharClass::L && next_class == CharClass::L
                       CharClass::L
                     elsif rtl_group?(prev_class) && rtl_group?(next_class)
                       CharClass::R
                     else
                       embedding_class
                     end

          i = run_start
          while i < pos
            classes[indices[i]] = resolved
            i += 1
          end

          prev_class = resolved
          next
        end

        prev_class = classes[index]
        pos += 1
      end
    end

    private def self.apply_implicit_levels!(classes : Array(CharClass), levels : Array(Int32))
      classes.each_with_index do |klass, index|
        next if removed_by_x9?(klass)

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

    private def self.assign_levels_to_removed_chars!(original_classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      original_classes.each_with_index do |klass, index|
        next unless removed_by_x9?(klass)

        levels[index] = index > 0 ? levels[index - 1] : base_level
      end
    end

    private def self.apply_l1!(original_classes : Array(CharClass), levels : Array(Int32), base_level : Int32)
      reset_from : Int32? = 0
      reset_to : Int32? = nil
      prev_level = base_level

      original_classes.each_with_index do |klass, index|
        case klass
        when CharClass::B, CharClass::S
          reset_to = index + 1
          reset_from ||= index
        when CharClass::WS, CharClass::FSI, CharClass::LRI, CharClass::RLI, CharClass::PDI
          reset_from ||= index
        when CharClass::RLE, CharClass::LRE, CharClass::RLO, CharClass::LRO, CharClass::PDF, CharClass::BN
          reset_from ||= index
          levels[index] = prev_level
        else
          reset_from = nil
        end

        if from = reset_from
          if to = reset_to
            from.upto(to - 1) { |i| levels[i] = base_level }
            reset_from = nil
            reset_to = nil
          end
        end

        prev_level = levels[index]
      end

      if from = reset_from
        from.upto(levels.size.to_i32 - 1) { |i| levels[i] = base_level } unless levels.empty?
      end
    end

    private def self.reorder_visual_indices(levels : Array(Int32)) : Array(Int32)
      visual = Array.new(levels.size) { |index| index.to_i32 }
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

    private def self.identify_bracket_pairs(
      sequence : IsolatingRunSequence,
      chars : Array(Char),
      classes : Array(CharClass),
    ) : Array(BracketPair)
      pairs = [] of BracketPair
      stack = [] of Tuple(UInt32, Int32)

      sequence.indices.each_with_index do |logical_index, pos|
        next unless classes[logical_index] == CharClass::ON

        codepoint = chars[logical_index].ord.to_u32
        entry = Data::PAIRED_BRACKETS[codepoint]?
        next unless entry

        pair_codepoint = entry[0]
        type = entry[1]

        if type == :Open
          break if stack.size >= 63

          stack << {canonical_opening_bracket(codepoint), pos.to_i32}
          next
        end

        canonical_opening = canonical_opening_bracket(pair_codepoint)
        match = stack.size - 1
        while match >= 0
          if stack[match][0] == canonical_opening
            pairs << BracketPair.new(stack[match][1], pos.to_i32)
            stack = match > 0 ? stack[0...match] : [] of Tuple(UInt32, Int32)
            break
          end

          match -= 1
        end
      end

      pairs.sort_by!(&.start_pos)
      pairs
    end

    # UAX #9 BD16 requires matching a closing paired bracket against the opener
    # or its canonical equivalent.
    private def self.canonical_opening_bracket(opening_codepoint : UInt32) : UInt32
      case opening_codepoint
      when 0x2329_u32 # LEFT-POINTING ANGLE BRACKET
        0x3008_u32    # LEFT ANGLE BRACKET
      else
        opening_codepoint
      end
    end

    private def self.flatten_runs(runs : Array(LevelRun)) : Array(Int32)
      indices = [] of Int32
      runs.each do |run|
        i = run.start
        while i < run.stop
          indices << i
          i += 1
        end
      end
      indices
    end

    private def self.first_non_removed_index(indices : Array(Int32), classes : Array(CharClass)) : Int32?
      indices.each do |index|
        return index unless removed_by_x9?(classes[index])
      end
      nil
    end

    private def self.last_non_removed_index(indices : Array(Int32), classes : Array(CharClass)) : Int32?
      idx = indices.size - 1
      while idx >= 0
        index = indices[idx]
        return index unless removed_by_x9?(classes[index])
        idx -= 1
      end
      nil
    end

    private def self.last_non_removed_class_in_run(classes : Array(CharClass), run : LevelRun) : CharClass?
      i = run.stop - 1
      while i >= run.start
        klass = classes[i]
        return klass unless removed_by_x9?(klass)
        i -= 1
      end
      nil
    end

    private def self.last_non_removed_class_before(classes : Array(CharClass), end_index : Int32) : CharClass?
      i = end_index - 1
      while i >= 0
        klass = classes[i]
        return klass unless removed_by_x9?(klass)
        i -= 1
      end
      nil
    end

    private def self.previous_non_removed_level(classes : Array(CharClass), levels : Array(Int32), before_index : Int32, default_level : Int32) : Int32
      i = before_index - 1
      while i >= 0
        return levels[i] unless removed_by_x9?(classes[i])
        i -= 1
      end
      default_level
    end

    private def self.next_non_removed_level(classes : Array(CharClass), levels : Array(Int32), start_index : Int32, default_level : Int32) : Int32
      i = start_index
      while i < classes.size
        return levels[i] unless removed_by_x9?(classes[i])
        i += 1
      end
      default_level
    end

    private def self.max_level(a : Int32, b : Int32) : Int32
      a > b ? a : b
    end

    private def self.rtl_group?(klass : CharClass) : Bool
      klass == CharClass::R || klass == CharClass::AN || klass == CharClass::EN
    end

    private def self.ni_type?(klass : CharClass) : Bool
      case klass
      when CharClass::B, CharClass::S, CharClass::WS, CharClass::ON,
           CharClass::FSI, CharClass::LRI, CharClass::RLI, CharClass::PDI
        true
      else
        false
      end
    end

    private def self.removed_by_x9?(klass : CharClass) : Bool
      case klass
      when CharClass::RLE, CharClass::LRE, CharClass::RLO, CharClass::LRO,
           CharClass::PDF, CharClass::BN
        true
      else
        false
      end
    end

    private def self.display_ignorable?(klass : CharClass) : Bool
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

    private def self.isolate_initiator?(klass : CharClass) : Bool
      klass == CharClass::RLI || klass == CharClass::LRI || klass == CharClass::FSI
    end

    private def self.isolate_control?(klass : CharClass) : Bool
      isolate_initiator?(klass) || klass == CharClass::PDI
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
          return ParagraphDirection::LeftToRight if isolate_depth == 0
        when CharClass::R, CharClass::AL
          return ParagraphDirection::RightToLeft if isolate_depth == 0
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
