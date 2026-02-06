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

    it "should handle * in non-strict mode" do
      SimpleIDN.to_unicode("*.xn--mllerriis-l8a.com", strict: false).should eq("*.møllerriis.com")
    end

    it "should handle leading _ in non-strict mode" do
      SimpleIDN.to_unicode("_something.xn--mllerriis-l8a.com", strict: false).should eq("_something.møllerriis.com")
    end

    it "should reject * in strict mode (default)" do
      SimpleIDN.to_unicode("*.xn--mllerriis-l8a.com").should be_nil
    end

    it "should reject leading _ in strict mode (default)" do
      SimpleIDN.to_unicode("_something.xn--mllerriis-l8a.com").should be_nil
    end

    it "should return nil for nil" do
      SimpleIDN.to_unicode(nil).should be_nil
    end

    it "should return . if only . given" do
      SimpleIDN.to_unicode(".").should eq(".")
    end

    it "returns nil when the input is an invalid ACE" do
      SimpleIDN.to_unicode("xn---").should be_nil
    end
  end

  describe "to_ascii" do
    it "should pass all test cases" do
      TESTCASES_JOSEFSSON.each do |testcase, vector|
        SimpleIDN.to_ascii(vector[0].as(String)).should eq(vector[1].as(String))
      end
    end

    it "should handle * in non-strict mode" do
      SimpleIDN.to_ascii("*.hello.com", strict: false).should eq("*.hello.com")
    end

    it "should reject * in strict mode (default)" do
      SimpleIDN.to_ascii("*.hello.com").should be_nil
    end

    it "should handle @ in non-strict mode" do
      SimpleIDN.to_ascii("@.hello.com", strict: false).should eq("@.hello.com")
    end

    it "should reject @ in strict mode (default)" do
      SimpleIDN.to_ascii("@.hello.com").should be_nil
    end

    it "should handle leading _ in non-strict mode" do
      SimpleIDN.to_ascii("_something.example.org", strict: false).should eq("_something.example.org")
    end

    it "should reject leading _ in strict mode (default)" do
      SimpleIDN.to_ascii("_something.example.org").should be_nil
    end

    it "should return nil for nil" do
      SimpleIDN.to_ascii(nil).should be_nil
    end

    it "should return . if only . given" do
      SimpleIDN.to_ascii(".").should eq(".")
    end

    it "should return @ in non-strict mode" do
      SimpleIDN.to_ascii("@", strict: false).should eq("@")
    end

    it "should reject @ in strict mode (default)" do
      SimpleIDN.to_ascii("@").should be_nil
    end

    it "should handle issue 8" do
      SimpleIDN.to_ascii("verm├Âgensberater").should eq("xn--vermgensberater-6jb1778m")
    end
  end
end
