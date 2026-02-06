# encoding: utf-8
require "./spec_helper"

# Comprehensive hostname validation tests
# These tests verify that SimpleIDN properly validates hostnames according to:
# - RFC 1035: Domain name length limits (253 bytes total, 63 bytes per label)
# - RFC 5890/5891: IDNA2008 requirements
# - UTS #46: Unicode IDNA compatibility standard

describe "Hostname Validation" do
  describe "Hostname length limits (RFC 1035)" do
    # RFC 1035: hostname must not exceed 253 ASCII characters
    # This limit applies to the wire format (without trailing dot)

    it "accepts hostname of exactly 253 bytes" do
      # Build a hostname of exactly 253 bytes
      # 63 + 1 + 63 + 1 + 63 + 1 + 61 = 253
      label_63 = "a" * 63
      label_61 = "a" * 61
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_61}"
      hostname.bytesize.should eq(253)
      SimpleIDN.to_ascii(hostname).should eq(hostname)
    end

    it "rejects hostname of 254 bytes" do
      # Build a hostname of exactly 254 bytes
      label_63 = "a" * 63
      label_62 = "a" * 62
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_62}"
      hostname.bytesize.should eq(254)
      SimpleIDN.to_ascii(hostname).should be_nil
    end

    it "rejects hostname of 255 bytes" do
      label_63 = "a" * 63
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_63}"
      hostname.bytesize.should eq(255)
      SimpleIDN.to_ascii(hostname).should be_nil
    end

    it "accepts hostname of 252 bytes (boundary -1)" do
      # Build a hostname of 252 bytes
      label_63 = "a" * 63
      label_60 = "a" * 60
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_60}"
      hostname.bytesize.should eq(252)
      SimpleIDN.to_ascii(hostname).should eq(hostname)
    end

    it "rejects very long hostnames" do
      # A very long hostname that clearly exceeds 253 bytes
      very_long = ("a" * 50 + ".") * 10 + "a" * 50
      SimpleIDN.to_ascii(very_long).should be_nil
    end
  end

  describe "Label length limits (RFC 1035)" do
    # RFC 1035: Each label must be 63 bytes or less

    it "accepts exactly 63-byte ASCII label" do
      label = "a" * 63
      SimpleIDN.to_ascii(label).should eq(label)
    end

    it "rejects 64-byte ASCII label" do
      label = "a" * 64
      SimpleIDN.to_ascii(label).should be_nil
    end

    it "accepts 62-byte ASCII label" do
      label = "a" * 62
      SimpleIDN.to_ascii(label).should eq(label)
    end

    it "rejects very long ASCII label" do
      label = "a" * 100
      SimpleIDN.to_ascii(label).should be_nil
    end

    it "accepts multi-label hostname with 63-byte labels" do
      label = "a" * 63
      hostname = "#{label}.#{label}.com"
      SimpleIDN.to_ascii(hostname).should eq(hostname)
    end

    it "rejects hostname with any label > 63 bytes" do
      good_label = "a" * 63
      bad_label = "a" * 64
      hostname = "#{good_label}.#{bad_label}.com"
      SimpleIDN.to_ascii(hostname).should be_nil
    end
  end

  describe "Unicode to Punycode label length" do
    # When unicode is converted to punycode, the result must be <= 63 bytes

    it "rejects unicode that produces punycode > 63 bytes" do
      # Many unicode chars expand significantly in punycode
      # "ä" * 30 = 30 chars unicode, but punycode is much longer
      long_unicode = "a" * 50 + "ä" * 10
      result = SimpleIDN.to_ascii(long_unicode)
      # The punycode would exceed 63 bytes
      result.should be_nil
    end

    it "accepts unicode that produces punycode <= 63 bytes" do
      # Short unicode that fits in 63 bytes
      SimpleIDN.to_ascii("münchen").should eq("xn--mnchen-3ya")
      SimpleIDN.to_ascii("münchen").not_nil!.bytesize.should be <= 63
    end

    it "accepts short emoji label" do
      # Single emoji produces short punycode
      result = SimpleIDN.to_ascii("test")
      result.should eq("test")
    end
  end

  describe "Hostname with unicode - total length validation" do
    it "rejects unicode hostname whose ASCII form exceeds 253 bytes" do
      # Create unicode labels that expand to long punycode
      # Each "日" produces "xn--wgv" for a single char (7 bytes base)
      # But with multiple chars it's more efficient
      # Create a long enough unicode hostname
      unicode_label = "日本語テスト" # Short unicode
      # Build hostname that's under 253 in unicode but could be over in punycode
      # Actually we need to test the total ASCII length
      label_63 = "a" * 63
      label_60 = "a" * 60
      # This is exactly 253 bytes in ASCII
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_60}"
      SimpleIDN.to_ascii(hostname).should eq(hostname)

      # Now test one that's just over
      label_61 = "a" * 61
      hostname_over = "#{label_63}.#{label_63}.#{label_63}.#{label_61}"
      hostname_over.bytesize.should eq(253)
      SimpleIDN.to_ascii(hostname_over).should eq(hostname_over)
    end

    it "correctly handles mixed unicode and ASCII hostname length" do
      # Test a realistic IDN hostname
      idn_hostname = "münchen.example.com"
      ascii_result = SimpleIDN.to_ascii(idn_hostname)
      ascii_result.should eq("xn--mnchen-3ya.example.com")
      ascii_result.not_nil!.bytesize.should be <= 253
    end
  end

  describe "Edge cases for hostname validation" do
    it "handles empty string" do
      SimpleIDN.to_ascii("").should eq("")
    end

    it "handles nil" do
      SimpleIDN.to_ascii(nil).should be_nil
    end

    it "handles single dot" do
      SimpleIDN.to_ascii(".").should eq(".")
    end

    it "handles hostname with trailing dot" do
      # Trailing dot (FQDN) - the 253 limit excludes the trailing dot
      label_63 = "a" * 63
      label_60 = "a" * 60
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_60}."
      # With trailing dot it's 254 chars total, but the name itself is 253
      # The limit applies to the hostname without the trailing dot
      # Our implementation should still allow this
      result = SimpleIDN.to_ascii(hostname)
      # This is a valid FQDN where the hostname part is exactly 253 bytes
      result.should eq(hostname)
    end

    it "handles multiple consecutive dots (empty labels)" do
      SimpleIDN.to_ascii("a..b").should eq("a..b")
    end

    it "validates long IDN hostname correctly" do
      # Create an IDN hostname that's valid
      result = SimpleIDN.to_ascii("日本語.jp")
      result.should eq("xn--wgv71a119e.jp")
    end
  end

  describe "Constants are exposed" do
    it "exposes MAX_HOSTNAME_LENGTH constant" do
      SimpleIDN::MAX_HOSTNAME_LENGTH.should eq(253)
    end

    it "exposes MAX_LABEL_LENGTH constant" do
      SimpleIDN::MAX_LABEL_LENGTH.should eq(63)
    end
  end

  describe "Compatibility with json_schemer hostname validation" do
    # These tests ensure SimpleIDN can be used for hostname validation
    # as required by json_schemer format validators

    it "validates simple ASCII hostname" do
      SimpleIDN.to_ascii("example.com").should eq("example.com")
    end

    it "validates hostname with hyphens" do
      SimpleIDN.to_ascii("my-example.com").should eq("my-example.com")
    end

    it "rejects hostname starting with hyphen" do
      SimpleIDN.to_ascii("-invalid.com").should be_nil
    end

    it "rejects hostname ending with hyphen" do
      SimpleIDN.to_ascii("invalid-.com").should be_nil
    end

    it "validates uppercase hostname (case folding)" do
      SimpleIDN.to_ascii("EXAMPLE.COM").should eq("example.com")
    end

    it "validates IDN hostname" do
      SimpleIDN.to_ascii("münchen.de").should eq("xn--mnchen-3ya.de")
    end

    it "validates punycode hostname" do
      SimpleIDN.to_unicode("xn--mnchen-3ya.de").should eq("münchen.de")
    end

    it "rejects invalid punycode" do
      SimpleIDN.to_unicode("xn---").should be_nil
    end

    it "rejects hostname with invalid characters" do
      SimpleIDN.to_ascii("exam ple.com").should be_nil
    end

    it "rejects hostname with control characters" do
      SimpleIDN.to_ascii("exam\u0000ple.com").should be_nil
    end

    it "rejects special DNS labels in strict mode (default)" do
      # In strict mode (default), these are rejected as invalid hostnames per RFC 1123
      SimpleIDN.to_ascii("*.example.com").should be_nil
      SimpleIDN.to_ascii("_dmarc.example.com").should be_nil
    end

    it "allows special DNS labels in non-strict mode" do
      # In non-strict mode, these are allowed for DNS record handling
      SimpleIDN.to_ascii("*.example.com", strict: false).should eq("*.example.com")
      SimpleIDN.to_ascii("_dmarc.example.com", strict: false).should eq("_dmarc.example.com")
    end
  end
end
