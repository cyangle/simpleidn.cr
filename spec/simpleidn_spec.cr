require "./spec_helper"
require "./test_vectors"

describe SimpleIDN do
  describe "to_unicode" do
    it "should pass all test cases" do
      TESTCASES_JOSEFSSON.each do |testcase, vector|
        # vector is Array(String | Bool)
        # Check reversibility: vector[2] is boolean true if present
        if vector.size > 2 && vector[2] == true
          next
        end

        SimpleIDN.to_unicode(vector[1].as(String)).should eq(vector[0].as(String))
      end
    end

    it "should respect * and not try to decode it" do
      SimpleIDN.to_unicode("*.xn--mllerriis-l8a.com").should eq("*.møllerriis.com")
    end

    it "should respect leading _ and not try to encode it" do
      SimpleIDN.to_unicode("_something.xn--mllerriis-l8a.com").should eq("_something.møllerriis.com")
    end

    it "should return nil for nil" do
      SimpleIDN.to_unicode(nil).should be_nil
    end

    it "should return . if only . given" do
      SimpleIDN.to_unicode(".").should eq(".")
    end

    it "raises when the input is an invalid ACE" do
      expect_raises(SimpleIDN::ConversionError) do
        SimpleIDN.to_unicode("xn---")
      end
    end
  end

  describe "to_ascii" do
    it "should pass all test cases" do
      TESTCASES_JOSEFSSON.each do |testcase, vector|
        SimpleIDN.to_ascii(vector[0].as(String)).should eq(vector[1].as(String))
      end
    end

    it "should respect * and not try to encode it" do
      SimpleIDN.to_ascii("*.hello.com").should eq("*.hello.com")
    end

    it "should respect @ and not try to encode it" do
      SimpleIDN.to_ascii("@.hello.com").should eq("@.hello.com")
    end

    it "should respect leading _ and not try to encode it" do
      SimpleIDN.to_ascii("_something.example.org").should eq("_something.example.org")
    end

    it "should return nil for nil" do
      SimpleIDN.to_ascii(nil).should be_nil
    end

    it "should return . if only . given" do
      SimpleIDN.to_ascii(".").should eq(".")
    end

    it "should return @ if @ is given" do
      SimpleIDN.to_ascii("@").should eq("@")
    end

    it "should handle issue 8" do
      SimpleIDN.to_ascii("verm├Âgensberater").should eq("xn--vermgensberater-6jb1778m")
    end
  end

  describe "uts #46" do
    it "should pass all test cases" do
      File.each_line(File.join(__DIR__, "IdnaTestV2.txt")) do |line|
        line = line.split('#').first
        next if line.nil? || line.empty?
        parts = line.split(';').map(&.strip)
        next if parts.size < 2 || parts[1].empty?

        # Decode unicode escapes
        decode_escapes = ->(str : String) {
          str.gsub(/\\u([0-9a-fA-F]{4})/) do |match|
            match[1].to_i(16).chr
          end
        }

        begin
          parts[0] = decode_escapes.call(parts[0])
          parts[1] = decode_escapes.call(parts[1])
        rescue ArgumentError
          # invalid char mapping
          next
        end

        parts[1] = parts[0] if parts[1].empty?

        while parts.size < 7
          parts << ""
        end

        parts[3] = parts[1] if parts[3].empty?
        parts[5] = parts[3] if parts[5].empty?

        parts[2] = "[]" if parts[2].empty?
        parts[4] = parts[2] if parts[4].empty?
        parts[6] = parts[4] if parts[6].empty?

        if parts[2].includes?("P4") # The only supported error code for now
          expect_raises(SimpleIDN::ConversionError) do
            SimpleIDN.to_unicode(parts[0])
          end
        elsif parts[2] == "[]"
          SimpleIDN.to_unicode(parts[0]).should eq(parts[1])
        end

        if parts[4] == "[]"
          SimpleIDN.to_ascii(parts[0], false).should eq(parts[3])
        end

        if parts[6] == "[]"
          SimpleIDN.to_ascii(parts[0], true).should eq(parts[5])
        end
      end
    end
  end
end
