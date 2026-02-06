# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.to_ascii_dns" do
  describe "Non-strict mode behavior (DNS)" do
    it "should handle * in non-strict mode" do
      SimpleIDN.to_ascii_dns("*.hello.com").should eq("*.hello.com")
    end

    it "should handle @ in non-strict mode" do
      SimpleIDN.to_ascii_dns("@.hello.com").should eq("@.hello.com")
    end

    it "should handle leading _ in non-strict mode" do
      SimpleIDN.to_ascii_dns("_something.example.org").should eq("_something.example.org")
    end

    it "should return @ in non-strict mode" do
      SimpleIDN.to_ascii_dns("@").should eq("@")
    end

    it "accepts underscore-prefixed labels (for SRV/DMARC/DKIM)" do
      SimpleIDN.to_ascii_dns("_dmarc.example.com").should eq("_dmarc.example.com")
      SimpleIDN.to_ascii_dns("_tcp.example.com").should eq("_tcp.example.com")
      SimpleIDN.to_ascii_dns("_sip._tcp.example.com").should eq("_sip._tcp.example.com")
    end

    it "accepts wildcard labels" do
      SimpleIDN.to_ascii_dns("*.example.com").should eq("*.example.com")
      SimpleIDN.to_ascii_dns("*.*.example.com").should eq("*.*.example.com")
    end

    it "accepts labels with underscores in the middle" do
      SimpleIDN.to_ascii_dns("my_label.example.com").should eq("my_label.example.com")
    end

    it "still validates and converts IDN labels" do
      SimpleIDN.to_ascii_dns("münchen.de").should eq("xn--mnchen-3ya.de")
      SimpleIDN.to_ascii_dns("日本語.jp").should eq("xn--wgv71a119e.jp")
    end

    it "still rejects invalid IDNA (Bidi, ContextJ violations)" do
      # ZWNJ without proper context is still rejected
      SimpleIDN.to_ascii_dns("a\u200Cb").should be_nil
    end

    it "still enforces length limits" do
      long_label = "a" * 64
      SimpleIDN.to_ascii_dns(long_label).should be_nil
    end

    it "mixes underscore labels with IDN labels" do
      result = SimpleIDN.to_ascii_dns("_dmarc.münchen.de")
      result.should eq("_dmarc.xn--mnchen-3ya.de")
    end

    it "allows trailing dot" do
      SimpleIDN.to_ascii_dns("example.com.").should eq("example.com.")
    end

    it "rejects consecutive dots" do
      SimpleIDN.to_ascii_dns("a..b").should be_nil
    end
  end

  describe "Transitional combinations" do
    it "supports transitional=true" do
      SimpleIDN.to_ascii_dns("*.faß.de", transitional: true).should eq("*.fass.de")
    end

    it "supports transitional=false" do
      SimpleIDN.to_ascii_dns("_dmarc.faß.de", transitional: false).should eq("_dmarc.xn--fa-hia.de")
    end
  end

  describe "Edge cases" do
    it "returns nil for nil" do
      SimpleIDN.to_ascii_dns(nil).should be_nil
    end

    it "returns nil for single dot" do
      SimpleIDN.to_ascii_dns(".").should be_nil
    end

    it "returns nil for empty string" do
      SimpleIDN.to_ascii_dns("").should be_nil
    end
  end
end
