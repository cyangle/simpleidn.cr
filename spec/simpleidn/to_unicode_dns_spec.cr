# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.to_unicode_dns" do
  describe "Non-strict mode behavior (DNS)" do
    it "should handle * in non-strict mode" do
      SimpleIDN.to_unicode_dns("*.xn--mllerriis-l8a.com").should eq("*.møllerriis.com")
    end

    it "should handle leading _ in non-strict mode" do
      SimpleIDN.to_unicode_dns("_something.xn--mllerriis-l8a.com").should eq("_something.møllerriis.com")
    end

    it "accepts underscore-prefixed labels" do
      SimpleIDN.to_unicode_dns("_dmarc.example.com").should eq("_dmarc.example.com")
    end

    it "accepts wildcard labels" do
      SimpleIDN.to_unicode_dns("*.example.com").should eq("*.example.com")
    end

    it "accepts @ symbol" do
      SimpleIDN.to_unicode_dns("@").should eq("@")
    end

    it "converts punycode in non-strict mode" do
      SimpleIDN.to_unicode_dns("xn--mnchen-3ya.de").should eq("münchen.de")
    end

    it "handles mixed underscore and punycode" do
      SimpleIDN.to_unicode_dns("_dmarc.xn--mnchen-3ya.de").should eq("_dmarc.münchen.de")
    end
  end

  describe "Edge cases" do
    it "should return nil for nil" do
      SimpleIDN.to_unicode_dns(nil).should be_nil
    end
  end
end
