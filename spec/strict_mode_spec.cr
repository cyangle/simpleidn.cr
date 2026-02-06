# encoding: utf-8
require "./spec_helper"

# Tests for strict vs non-strict (permissive) mode
# - strict=true (default): RFC 1123 hostname validation (LDH characters only)
# - strict=false: Permissive DNS record mode (allows _, *, @ for SRV, wildcards, etc.)

describe "Strict Mode (RFC 1123 Hostname Validation)" do
  # strict=true is the default, enforcing RFC 1123 LDH rule

  describe "to_ascii with strict=true (default)" do
    it "rejects underscore-prefixed labels" do
      SimpleIDN.to_ascii("_dmarc.example.com").should be_nil
      SimpleIDN.to_ascii("_tcp.example.com").should be_nil
      SimpleIDN.to_ascii("_sip._tcp.example.com").should be_nil
    end

    it "rejects wildcard labels" do
      SimpleIDN.to_ascii("*.example.com").should be_nil
      SimpleIDN.to_ascii("*.*.example.com").should be_nil
    end

    it "rejects @ symbol" do
      SimpleIDN.to_ascii("@").should be_nil
      SimpleIDN.to_ascii("@.example.com").should be_nil
    end

    it "rejects labels with underscores in the middle" do
      SimpleIDN.to_ascii("my_label.example.com").should be_nil
    end

    it "accepts valid LDH hostnames" do
      SimpleIDN.to_ascii("example.com").should eq("example.com")
      SimpleIDN.to_ascii("my-example.com").should eq("my-example.com")
      SimpleIDN.to_ascii("sub.domain.example.com").should eq("sub.domain.example.com")
    end

    it "accepts hostnames starting with digits" do
      SimpleIDN.to_ascii("123.example.com").should eq("123.example.com")
      SimpleIDN.to_ascii("3com.com").should eq("3com.com")
    end

    it "accepts IDN hostnames" do
      SimpleIDN.to_ascii("münchen.de").should eq("xn--mnchen-3ya.de")
      SimpleIDN.to_ascii("日本語.jp").should eq("xn--wgv71a119e.jp")
    end

    it "rejects hostnames starting with hyphen" do
      SimpleIDN.to_ascii("-invalid.com").should be_nil
    end

    it "rejects hostnames ending with hyphen" do
      SimpleIDN.to_ascii("invalid-.com").should be_nil
    end
  end

  describe "to_unicode with strict=true (default)" do
    it "rejects underscore-prefixed labels" do
      SimpleIDN.to_unicode("_dmarc.example.com").should be_nil
    end

    it "rejects wildcard labels" do
      SimpleIDN.to_unicode("*.example.com").should be_nil
    end

    it "accepts valid punycode" do
      SimpleIDN.to_unicode("xn--mnchen-3ya.de").should eq("münchen.de")
    end
  end
end

describe "Non-Strict Mode (Permissive DNS Record Mode)" do
  # strict=false allows non-LDH characters for DNS records

  describe "to_ascii with strict=false" do
    it "accepts underscore-prefixed labels (for SRV/DMARC/DKIM)" do
      SimpleIDN.to_ascii("_dmarc.example.com", strict: false).should eq("_dmarc.example.com")
      SimpleIDN.to_ascii("_tcp.example.com", strict: false).should eq("_tcp.example.com")
      SimpleIDN.to_ascii("_sip._tcp.example.com", strict: false).should eq("_sip._tcp.example.com")
    end

    it "accepts wildcard labels" do
      SimpleIDN.to_ascii("*.example.com", strict: false).should eq("*.example.com")
      SimpleIDN.to_ascii("*.*.example.com", strict: false).should eq("*.*.example.com")
    end

    it "accepts @ symbol (zone apex shorthand)" do
      SimpleIDN.to_ascii("@", strict: false).should eq("@")
      SimpleIDN.to_ascii("@.example.com", strict: false).should eq("@.example.com")
    end

    it "accepts labels with underscores in the middle" do
      SimpleIDN.to_ascii("my_label.example.com", strict: false).should eq("my_label.example.com")
    end

    it "still validates and converts IDN labels" do
      SimpleIDN.to_ascii("münchen.de", strict: false).should eq("xn--mnchen-3ya.de")
      SimpleIDN.to_ascii("日本語.jp", strict: false).should eq("xn--wgv71a119e.jp")
    end

    it "still rejects invalid IDNA (Bidi, ContextJ violations)" do
      # ZWNJ without proper context is still rejected
      SimpleIDN.to_ascii("a\u200Cb", strict: false).should be_nil
    end

    it "still enforces length limits" do
      long_label = "a" * 64
      SimpleIDN.to_ascii(long_label, strict: false).should be_nil
    end

    it "mixes underscore labels with IDN labels" do
      result = SimpleIDN.to_ascii("_dmarc.münchen.de", strict: false)
      result.should eq("_dmarc.xn--mnchen-3ya.de")
    end
  end

  describe "to_unicode with strict=false" do
    it "accepts underscore-prefixed labels" do
      SimpleIDN.to_unicode("_dmarc.example.com", strict: false).should eq("_dmarc.example.com")
    end

    it "accepts wildcard labels" do
      SimpleIDN.to_unicode("*.example.com", strict: false).should eq("*.example.com")
    end

    it "accepts @ symbol" do
      SimpleIDN.to_unicode("@", strict: false).should eq("@")
    end

    it "converts punycode in non-strict mode" do
      SimpleIDN.to_unicode("xn--mnchen-3ya.de", strict: false).should eq("münchen.de")
    end

    it "handles mixed underscore and punycode" do
      SimpleIDN.to_unicode("_dmarc.xn--mnchen-3ya.de", strict: false).should eq("_dmarc.münchen.de")
    end
  end
end

describe "Transitional + Strict Mode Combinations" do
  it "supports transitional=true with strict=true" do
    # ß maps to ss in transitional mode
    SimpleIDN.to_ascii("faß.de", transitional: true, strict: true).should eq("fass.de")
  end

  it "supports transitional=true with strict=false" do
    SimpleIDN.to_ascii("*.faß.de", transitional: true, strict: false).should eq("*.fass.de")
  end

  it "supports transitional=false with strict=true (default)" do
    # ß is preserved in nontransitional mode
    SimpleIDN.to_ascii("faß.de").should eq("xn--fa-hia.de")
  end

  it "supports transitional=false with strict=false" do
    SimpleIDN.to_ascii("_dmarc.faß.de", transitional: false, strict: false).should eq("_dmarc.xn--fa-hia.de")
  end
end

describe "Edge Cases" do
  describe "Empty labels and dots" do
    it "handles empty string in both modes" do
      SimpleIDN.to_ascii("").should eq("")
      SimpleIDN.to_ascii("", strict: false).should eq("")
    end

    it "handles single dot in both modes" do
      SimpleIDN.to_ascii(".").should eq(".")
      SimpleIDN.to_ascii(".", strict: false).should eq(".")
    end

    it "handles trailing dot (FQDN) in both modes" do
      SimpleIDN.to_ascii("example.com.").should eq("example.com.")
      SimpleIDN.to_ascii("example.com.", strict: false).should eq("example.com.")
    end

    it "handles consecutive dots in both modes" do
      SimpleIDN.to_ascii("a..b").should eq("a..b")
      SimpleIDN.to_ascii("a..b", strict: false).should eq("a..b")
    end
  end

  describe "nil handling" do
    it "returns nil for nil input in both modes" do
      SimpleIDN.to_ascii(nil).should be_nil
      SimpleIDN.to_ascii(nil, strict: false).should be_nil
      SimpleIDN.to_unicode(nil).should be_nil
      SimpleIDN.to_unicode(nil, strict: false).should be_nil
    end
  end

  describe "Length limits apply in both modes" do
    it "rejects labels > 63 bytes in strict mode" do
      SimpleIDN.to_ascii("a" * 64).should be_nil
    end

    it "rejects labels > 63 bytes in non-strict mode" do
      SimpleIDN.to_ascii("a" * 64, strict: false).should be_nil
    end

    it "rejects hostname > 253 bytes in strict mode" do
      label_63 = "a" * 63
      label_62 = "a" * 62
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_62}" # 254 bytes
      SimpleIDN.to_ascii(hostname).should be_nil
    end

    it "rejects hostname > 253 bytes in non-strict mode" do
      label_63 = "a" * 63
      label_62 = "a" * 62
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_62}" # 254 bytes
      SimpleIDN.to_ascii(hostname, strict: false).should be_nil
    end

    it "accepts hostname of exactly 253 bytes in both modes" do
      label_63 = "a" * 63
      label_61 = "a" * 61
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_61}" # 253 bytes
      SimpleIDN.to_ascii(hostname).should eq(hostname)
      SimpleIDN.to_ascii(hostname, strict: false).should eq(hostname)
    end
  end
end

describe "JSON Schema 2020-12 Hostname Format Compatibility" do
  # These tests verify SimpleIDN meets JSON Schema draft 2020-12 requirements
  # for "hostname" (RFC 1123) and "idn-hostname" (RFC 5890) formats

  describe "hostname format (RFC 1123)" do
    it "accepts valid hostnames" do
      SimpleIDN.to_ascii("example.com").should eq("example.com")
      SimpleIDN.to_ascii("sub.example.com").should eq("sub.example.com")
      SimpleIDN.to_ascii("my-host.example.com").should eq("my-host.example.com")
      SimpleIDN.to_ascii("host123.example.com").should eq("host123.example.com")
    end

    it "rejects non-LDH hostnames" do
      SimpleIDN.to_ascii("_invalid.com").should be_nil
      SimpleIDN.to_ascii("*.invalid.com").should be_nil
      SimpleIDN.to_ascii("invalid@.com").should be_nil
      SimpleIDN.to_ascii("inv alid.com").should be_nil
    end

    it "validates punycode hostnames" do
      # Punycode-encoded IDN is valid for hostname format
      SimpleIDN.to_ascii("xn--mnchen-3ya.de").should eq("xn--mnchen-3ya.de")
    end
  end

  describe "idn-hostname format (RFC 5890)" do
    it "accepts and converts IDN hostnames" do
      SimpleIDN.to_ascii("münchen.de").should eq("xn--mnchen-3ya.de")
      SimpleIDN.to_ascii("日本語.jp").should eq("xn--wgv71a119e.jp")
      SimpleIDN.to_ascii("россия.рф").should eq("xn--h1alffa9f.xn--p1ai")
    end

    it "rejects invalid IDN (IDNA2008 violations)" do
      # Leading hyphen
      SimpleIDN.to_ascii("-münchen.de").should be_nil
      # Invalid CONTEXTJ
      SimpleIDN.to_ascii("a\u200Cb").should be_nil
    end
  end
end
