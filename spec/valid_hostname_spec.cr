require "./spec_helper"

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

    it "rejects trailing dots by default" do
      SimpleIDN.valid_hostname?("example.com.").should be_false
      SimpleIDN.valid_hostname?("com.").should be_false
      SimpleIDN.valid_hostname?(".").should be_false
    end

    it "rejects consecutive dots" do
      SimpleIDN.valid_hostname?("example..com").should be_false
      SimpleIDN.valid_hostname?("a..b").should be_false
    end

    it "allows trailing dots when explicitly allowed" do
      SimpleIDN.valid_hostname?("example.com.", allow_trailing_dot: true).should be_true
      SimpleIDN.valid_hostname?("com.", allow_trailing_dot: true).should be_true
    end

    it "rejects single dot even if trailing dot is allowed" do
      SimpleIDN.valid_hostname?(".", allow_trailing_dot: true).should be_false
    end
  end

  describe "Unicode separators" do
    it "rejects unicode dots that normalize to ASCII dots (by default)" do
      # These normalize to "example.com." which is rejected due to trailing dot
      SimpleIDN.valid_hostname?("example.com。").should be_false
      SimpleIDN.valid_hostname?("example.com．").should be_false
      SimpleIDN.valid_hostname?("example.com｡").should be_false
    end

    it "allows unicode dots if trailing dot is allowed" do
      SimpleIDN.valid_hostname?("example.com。", allow_trailing_dot: true).should be_true
      SimpleIDN.valid_hostname?("example.com．", allow_trailing_dot: true).should be_true
      SimpleIDN.valid_hostname?("example.com｡", allow_trailing_dot: true).should be_true
    end

    it "rejects consecutive unicode dots" do
      # "example..com"
      SimpleIDN.valid_hostname?("example。｡com").should be_false
    end
  end

  describe "Strict mode (RFC 1123)" do
    it "defaults to strict: true" do
      # Rejects *, _, @
      SimpleIDN.valid_hostname?("*.example.com").should be_false
      SimpleIDN.valid_hostname?("_dmarc.example.com").should be_false
      SimpleIDN.valid_hostname?("user@example.com").should be_false
    end

    it "allows DNS labels in non-strict mode" do
      SimpleIDN.valid_hostname?("*.example.com", strict: false).should be_true
      SimpleIDN.valid_hostname?("_dmarc.example.com", strict: false).should be_true
    end

    it "still enforcing structural rules in non-strict mode" do
      # Even in non-strict mode, we don't want empty labels/leading dots if checking for validity
      SimpleIDN.valid_hostname?(".example.com", strict: false).should be_false
      SimpleIDN.valid_hostname?("example.com.", strict: false).should be_false
      SimpleIDN.valid_hostname?("example..com", strict: false).should be_false
    end
  end

  describe "Transitional processing" do
    it "supports transitional option" do
      # ß -> ss in transitional
      # ß -> xn--zca (preserved) in nontransitional

      # Just verifying it doesn't crash, exact output depends on IDNA version
      SimpleIDN.valid_hostname?("faß.de", transitional: true).should be_true
      SimpleIDN.valid_hostname?("faß.de", transitional: false).should be_true
    end
  end
end
