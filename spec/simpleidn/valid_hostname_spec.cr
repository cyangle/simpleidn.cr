# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.valid_hostname?" do
  describe "Basic hostname validation" do
    it "validates standard ASCII hostnames" do
      SimpleIDN.valid_hostname?("example.com").should be_true
      SimpleIDN.valid_hostname?("sub.example.com").should be_true
      SimpleIDN.valid_hostname?("my-host.com").should be_true
      SimpleIDN.valid_hostname?("123.com").should be_true
    end

    it "validates uppercase hostnames (case insensitive)" do
      SimpleIDN.valid_hostname?("EXAMPLE.COM").should be_true
      SimpleIDN.valid_hostname?("Example.Com").should be_true
    end

    it "validates IDN hostnames" do
      SimpleIDN.valid_hostname?("münchen.de").should be_true
      SimpleIDN.valid_hostname?("日本語.jp").should be_true
      SimpleIDN.valid_hostname?("xn--mnchen-3ya.de").should be_true # punycode
    end

    it "rejects invalid hostnames" do
      SimpleIDN.valid_hostname?(nil).should be_false
      SimpleIDN.valid_hostname?("").should be_false
      SimpleIDN.valid_hostname?("-start.com").should be_false
      SimpleIDN.valid_hostname?("end-.com").should be_false
      SimpleIDN.valid_hostname?("inv alid.com").should be_false
    end
  end

  describe "Structural validation (dots)" do
    it "rejects leading dots" do
      SimpleIDN.valid_hostname?(".example.com").should be_false
      SimpleIDN.valid_hostname?(".com").should be_false
    end

    it "rejects trailing dots" do
      SimpleIDN.valid_hostname?("example.com.").should be_false
      SimpleIDN.valid_hostname?("com.").should be_false
      SimpleIDN.valid_hostname?(".").should be_false
    end

    it "rejects consecutive dots" do
      SimpleIDN.valid_hostname?("example..com").should be_false
      SimpleIDN.valid_hostname?("a..b").should be_false
    end
  end

  describe "Unicode separators" do
    it "rejects unicode dots that normalize to ASCII dots at the end" do
      # These normalize to "example.com." which is rejected
      SimpleIDN.valid_hostname?("example.com。").should be_false
      SimpleIDN.valid_hostname?("example.com．").should be_false
      SimpleIDN.valid_hostname?("example.com｡").should be_false
    end

    it "rejects consecutive unicode dots" do
      # "example..com"
      SimpleIDN.valid_hostname?("example。｡com").should be_false
    end
  end

  describe "Strict mode (RFC 1123)" do
    it "enforces strict rules" do
      # Rejects *, _, @
      SimpleIDN.valid_hostname?("*.example.com").should be_false
      SimpleIDN.valid_hostname?("_dmarc.example.com").should be_false
      SimpleIDN.valid_hostname?("user@example.com").should be_false
    end
  end
end
