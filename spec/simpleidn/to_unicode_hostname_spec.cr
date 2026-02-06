# encoding: utf-8
require "../spec_helper"
require "../test_vectors"

describe "SimpleIDN.to_unicode_hostname" do
  describe "Josefsson Test Vectors" do
    it "should pass all test cases" do
      TESTCASES_JOSEFSSON.each do |testcase, vector|
        # vector is Array(String | Bool)
        # Check reversibility: vector[2] is boolean true if present
        if vector.size > 2 && vector[2] == true
          next
        end

        SimpleIDN.to_unicode_hostname(vector[1].as(String)).should eq(vector[0].as(String))
      end
    end
  end

  describe "Strict mode behavior (Hostname)" do
    it "should reject * in strict mode" do
      SimpleIDN.to_unicode_hostname("*.xn--mllerriis-l8a.com").should be_nil
    end

    it "should reject leading _ in strict mode" do
      SimpleIDN.to_unicode_hostname("_something.xn--mllerriis-l8a.com").should be_nil
    end

    it "rejects underscore-prefixed labels" do
      SimpleIDN.to_unicode_hostname("_dmarc.example.com").should be_nil
    end

    it "rejects wildcard labels" do
      SimpleIDN.to_unicode_hostname("*.example.com").should be_nil
    end

    it "accepts valid punycode" do
      SimpleIDN.to_unicode_hostname("xn--mnchen-3ya.de").should eq("münchen.de")
    end
  end

  describe "Conformance / Decoding" do
    it "decodes Greek final sigma" do
      SimpleIDN.to_unicode_hostname("xn--nxasmm1c").should eq("βόλος")
    end

    it "decodes Greek regular sigma" do
      SimpleIDN.to_unicode_hostname("xn--nxasmq6b").should eq("βόλοσ")
    end

    it "decodes German umlaut" do
      SimpleIDN.to_unicode_hostname("xn--bcher-kva.de").should eq("bücher.de")
    end
  end

  describe "Invalid punycode detection" do
    it "returns nil for invalid ACE prefix" do
      SimpleIDN.to_unicode_hostname("xn---").should be_nil
    end

    it "returns nil for invalid punycode encoding" do
      SimpleIDN.to_unicode_hostname("xn--a-").should be_nil
    end

    it "handles valid ACE labels" do
      SimpleIDN.to_unicode_hostname("xn--nxasmq6b").should eq("βόλοσ")
    end
  end

  describe "Edge cases" do
    it "should return nil for nil" do
      SimpleIDN.to_unicode_hostname(nil).should be_nil
    end

    it "should return nil if only . given" do
      SimpleIDN.to_unicode_hostname(".").should be_nil
    end

    it "should return nil if empty string given" do
      SimpleIDN.to_unicode_hostname("").should be_nil
    end
  end
end
