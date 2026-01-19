# HarfBuzz integration for TrueType
#
# This module provides Crystal bindings for the HarfBuzz text shaping library.
# It is only available when compiled with the `-Dharfbuzz` flag.
#
# ## Installation
#
# 1. Install HarfBuzz on your system:
#    - macOS: `brew install harfbuzz`
#    - Ubuntu/Debian: `apt install libharfbuzz-dev`
#    - Fedora: `dnf install harfbuzz-devel`
#    - Arch: `pacman -S harfbuzz`
#
# 2. Compile with the flag: `crystal build -Dharfbuzz your_app.cr`
#
# ## Usage
#
# ```crystal
# require "truetype"
#
# font = TrueType::Font.open("font.ttf")
#
# # Full HarfBuzz shaping for complex scripts
# glyphs = font.shape_advanced("مرحبا بالعالم", features: ["liga", "kern"])
#
# glyphs.each do |g|
#   puts "Glyph #{g.id} at (#{g.x_offset}, #{g.y_offset}), advance: #{g.x_advance}"
# end
# ```

{% if flag?(:harfbuzz) %}

require "./harfbuzz/lib"
require "./harfbuzz/blob"
require "./harfbuzz/face"
require "./harfbuzz/font"
require "./harfbuzz/buffer"
require "./harfbuzz/feature"
require "./harfbuzz/shaper"

module TrueType
  # Returns true if HarfBuzz support is compiled in
  def self.harfbuzz_available? : Bool
    true
  end
end

{% else %}

module TrueType
  # Returns true if HarfBuzz support is compiled in
  def self.harfbuzz_available? : Bool
    false
  end

  # Exception raised when HarfBuzz functions are called but HarfBuzz is not available
  class HarfBuzzNotAvailable < Exception
    def initialize(method_name : String = "shape_advanced")
      super(<<-MSG
        HarfBuzz is not available. The method '#{method_name}' requires HarfBuzz support.

        To enable HarfBuzz:
        1. Install HarfBuzz on your system:
           - macOS: brew install harfbuzz
           - Ubuntu/Debian: apt install libharfbuzz-dev
           - Fedora: dnf install harfbuzz-devel
           - Arch: pacman -S harfbuzz

        2. Recompile with the -Dharfbuzz flag:
           crystal build -Dharfbuzz your_app.cr

        Alternatively, use 'shape()' for basic shaping (char->glyph + kerning),
        or 'shape_best_effort()' which automatically falls back to basic shaping.
        MSG
      )
    end
  end
end

{% end %}
