require "../spec_helper"

describe TrueType::Tables::Hinting do
  font = TrueType::Parser.parse(FONT_PATH)

  describe TrueType::Tables::Hinting::Cvt do
    it "can be accessed from the parser" do
      # DejaVuSans has hinting tables
      cvt = font.cvt
      if cvt
        cvt.should be_a(TrueType::Tables::Hinting::Cvt)
        cvt.size.should be > 0
      end
    end

    it "provides control values" do
      cvt = font.cvt
      if cvt && cvt.size > 0
        # First value should be accessible
        cvt[0].should be_a(Int16)
        cvt[0]?.should_not be_nil
      end
    end

    it "returns nil for out of bounds access" do
      cvt = font.cvt
      if cvt
        cvt[999999]?.should be_nil
      end
    end

    it "serializes to bytes" do
      cvt = font.cvt
      if cvt
        bytes = cvt.to_bytes
        bytes.size.should eq(cvt.size * 2) # Each FWORD is 2 bytes
      end
    end
  end

  describe TrueType::Tables::Hinting::Fpgm do
    it "can be accessed from the parser" do
      fpgm = font.fpgm
      if fpgm
        fpgm.should be_a(TrueType::Tables::Hinting::Fpgm)
        fpgm.size.should be > 0
      end
    end

    it "contains TrueType bytecode" do
      fpgm = font.fpgm
      if fpgm && fpgm.size > 0
        fpgm[0].should be_a(UInt8)
        fpgm.instructions.should be_a(Bytes)
      end
    end

    it "serializes to bytes" do
      fpgm = font.fpgm
      if fpgm
        bytes = fpgm.to_bytes
        bytes.size.should eq(fpgm.size)
      end
    end
  end

  describe TrueType::Tables::Hinting::Prep do
    it "can be accessed from the parser" do
      prep = font.prep
      if prep
        prep.should be_a(TrueType::Tables::Hinting::Prep)
        prep.size.should be > 0
      end
    end

    it "contains TrueType bytecode" do
      prep = font.prep
      if prep && prep.size > 0
        prep[0].should be_a(UInt8)
        prep.instructions.should be_a(Bytes)
      end
    end

    it "serializes to bytes" do
      prep = font.prep
      if prep
        bytes = prep.to_bytes
        bytes.size.should eq(prep.size)
      end
    end
  end

  describe TrueType::Tables::Hinting::Gasp do
    it "can be accessed from the parser" do
      gasp = font.gasp
      if gasp
        gasp.should be_a(TrueType::Tables::Hinting::Gasp)
        gasp.size.should be > 0
      end
    end

    it "provides behavior at different ppem sizes" do
      gasp = font.gasp
      if gasp
        # Get behavior for small ppem
        behavior_small = gasp.behavior(8_u16)
        behavior_small.should be_a(TrueType::Tables::Hinting::Gasp::Behavior)

        # Get behavior for large ppem
        behavior_large = gasp.behavior(100_u16)
        behavior_large.should be_a(TrueType::Tables::Hinting::Gasp::Behavior)
      end
    end

    it "provides gridfitting and grayscale flags" do
      gasp = font.gasp
      if gasp
        # These should return boolean values
        gasp.gridfit?(12_u16).should be_a(Bool)
        gasp.grayscale?(12_u16).should be_a(Bool)
      end
    end

    it "has version information" do
      gasp = font.gasp
      if gasp
        gasp.version.should be >= 0
        gasp.version.should be <= 1
      end
    end

    it "has sorted ranges" do
      gasp = font.gasp
      if gasp && gasp.size > 1
        prev_ppem = 0_u16
        gasp.ranges.each do |range|
          range.range_max_ppem.should be >= prev_ppem
          prev_ppem = range.range_max_ppem
        end
      end
    end

    it "serializes to bytes" do
      gasp = font.gasp
      if gasp
        bytes = gasp.to_bytes
        bytes.size.should eq(4 + gasp.size * 4) # header + records
      end
    end
  end

  describe TrueType::Tables::Hinting::Ltsh do
    it "can be accessed from the parser" do
      ltsh = font.ltsh
      # LTSH is optional, so just check the type if present
      if ltsh
        ltsh.should be_a(TrueType::Tables::Hinting::Ltsh)
      end
    end

    it "provides per-glyph thresholds if present" do
      ltsh = font.ltsh
      if ltsh && ltsh.size > 0
        ltsh.threshold(0_u16).should be_a(UInt8)
      end
    end
  end

  describe TrueType::Tables::Hinting::Hdmx do
    it "can be accessed from the parser" do
      hdmx = font.hdmx
      # hdmx is optional
      if hdmx
        hdmx.should be_a(TrueType::Tables::Hinting::Hdmx)
      end
    end

    it "provides available sizes if present" do
      hdmx = font.hdmx
      if hdmx
        sizes = hdmx.available_sizes
        sizes.should be_a(Array(UInt8))
      end
    end
  end

  describe TrueType::Tables::Hinting::Vdmx do
    it "can be accessed from the parser" do
      vdmx = font.vdmx
      # VDMX is optional
      if vdmx
        vdmx.should be_a(TrueType::Tables::Hinting::Vdmx)
      end
    end

    it "provides bounds if present" do
      vdmx = font.vdmx
      if vdmx && vdmx.size > 0
        # Try to get bounds for a common ppem
        bounds = vdmx.bounds(12_u16)
        if bounds
          bounds[0].should be_a(Int16) # yMax
          bounds[1].should be_a(Int16) # yMin
        end
      end
    end
  end

  describe "Parser convenience methods" do
    it "has_hinting? returns boolean" do
      font.has_hinting?.should be_a(Bool)
    end

    it "has_gasp? returns boolean" do
      font.has_gasp?.should be_a(Bool)
    end

    it "gasp_behavior returns behavior flags" do
      behavior = font.gasp_behavior(12_u16)
      behavior.should be_a(TrueType::Tables::Hinting::Gasp::Behavior)
    end

    it "gasp_gridfit? returns boolean" do
      font.gasp_gridfit?(12_u16).should be_a(Bool)
    end

    it "gasp_grayscale? returns boolean" do
      font.gasp_grayscale?(12_u16).should be_a(Bool)
    end

    it "control_value returns Int16 or nil" do
      val = font.control_value(0)
      if val
        val.should be_a(Int16)
      end
    end

    it "control_value_count returns count" do
      count = font.control_value_count
      count.should be >= 0
    end
  end
end
