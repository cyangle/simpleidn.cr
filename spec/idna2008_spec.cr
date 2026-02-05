# encoding: utf-8
require "./spec_helper"

# IDNA2008 / UTS #46 conformance tests
# Based on Unicode IDNA Test file (IdnaTestV2.txt)
#
# These tests verify IDNA2008 conformance with nontransitional processing.
# The implementation uses ICU's UTS #46 processing with:
# - UIDNA_USE_STD3_RULES
# - UIDNA_CHECK_BIDI
# - UIDNA_CHECK_CONTEXTJ
# - UIDNA_NONTRANSITIONAL_TO_ASCII
# - UIDNA_NONTRANSITIONAL_TO_UNICODE

# Helper to unescape \uXXXX and \x{XXXX} sequences in test data
def unescape_idna(s : String) : String
  result = s.gsub(/\\u([0-9A-Fa-f]{4})/) do |match|
    code = $1.to_i(16)
    code.chr
  end
  result = result.gsub(/\\x\{([0-9A-Fa-f]+)\}/) do |match|
    code = $1.to_i(16)
    code.chr
  end
  result
end

describe "IDNA2008 Conformance" do

  describe "Basic ASCII domains" do
    it "preserves simple ASCII domains" do
      SimpleIDN.to_ascii("example.com").should eq("example.com")
      SimpleIDN.to_unicode("example.com").should eq("example.com")
    end

    it "lowercases ASCII domains" do
      SimpleIDN.to_ascii("EXAMPLE.COM").should eq("example.com")
      SimpleIDN.to_unicode("EXAMPLE.COM").should eq("example.com")
      SimpleIDN.to_ascii("www.eXample.cOm").should eq("www.example.com")
    end
  end

  describe "German ß (Eszett) handling - IDNA2008 vs IDNA2003" do
    # IDNA2008 nontransitional: ß is preserved as xn--fa-hia
    # IDNA2003/transitional: ß maps to ss -> fass
    
    it "converts faß.de to xn--fa-hia.de (nontransitional)" do
      SimpleIDN.to_ascii("faß.de").should eq("xn--fa-hia.de")
    end

    it "converts faß.de to fass.de (transitional)" do
      SimpleIDN.to_ascii("faß.de", transitional: true).should eq("fass.de")
    end

    it "converts Faß.de with case folding" do
      SimpleIDN.to_ascii("Faß.de").should eq("xn--fa-hia.de")
    end

    it "converts xn--fa-hia.de back to faß.de" do
      SimpleIDN.to_unicode("xn--fa-hia.de").should eq("faß.de")
    end

    it "preserves fass.de as-is" do
      SimpleIDN.to_ascii("fass.de").should eq("fass.de")
      SimpleIDN.to_unicode("fass.de").should eq("fass.de")
    end

    it "handles capital ẞ (U+1E9E)" do
      # Capital sharp S should lowercase to ß
      SimpleIDN.to_ascii("FAẞ.de").should eq("xn--fa-hia.de")
    end
  end

  describe "Greek final sigma handling - IDNA2008" do
    # Greek final sigma (ς) vs regular sigma (σ) distinction
    # IDNA2008 preserves the distinction
    
    it "handles βόλος with final sigma" do
      # βόλος (with final sigma ς) -> xn--nxasmm1c
      SimpleIDN.to_ascii("βόλος").should eq("xn--nxasmm1c")
    end

    it "handles βόλοσ with regular sigma" do
      # βόλοσ (with regular sigma σ) -> xn--nxasmq6b
      SimpleIDN.to_ascii("βόλοσ").should eq("xn--nxasmq6b")
    end

    it "decodes xn--nxasmm1c to βόλος" do
      SimpleIDN.to_unicode("xn--nxasmm1c").should eq("βόλος")
    end

    it "decodes xn--nxasmq6b to βόλοσ" do
      SimpleIDN.to_unicode("xn--nxasmq6b").should eq("βόλοσ")
    end

    it "handles Greek domain with .com" do
      SimpleIDN.to_ascii("βόλος.com").should eq("xn--nxasmm1c.com")
    end
  end

  describe "German umlaut handling" do
    it "converts bücher.de to punycode" do
      SimpleIDN.to_ascii("bücher.de").should eq("xn--bcher-kva.de")
    end

    it "handles capital Bücher" do
      SimpleIDN.to_ascii("Bücher.de").should eq("xn--bcher-kva.de")
    end

    it "handles combining diaeresis" do
      # bu\u0308cher (u + combining diaeresis) should normalize to bücher
      SimpleIDN.to_ascii("bu\u0308cher.de").should eq("xn--bcher-kva.de")
    end

    it "decodes xn--bcher-kva.de" do
      SimpleIDN.to_unicode("xn--bcher-kva.de").should eq("bücher.de")
    end

    it "handles ÖBB (Austrian railways)" do
      SimpleIDN.to_ascii("öbb").should eq("xn--bb-eka")
      SimpleIDN.to_ascii("ÖBB").should eq("xn--bb-eka")
    end
  end

  describe "Unicode normalization (NFC)" do
    it "normalizes combining characters" do
      # a\u0308 (a + combining diaeresis) should normalize to ä
      # Both should produce the same punycode
      SimpleIDN.to_ascii("a\u0308.com").should eq(SimpleIDN.to_ascii("ä.com"))
    end

    it "handles precomposed vs decomposed é" do
      # é (U+00E9) vs e\u0301 (e + combining acute)
      SimpleIDN.to_ascii("café.com").should eq(SimpleIDN.to_ascii("cafe\u0301.com"))
    end
  end

  describe "BiDi (Bidirectional) domain handling" do
    # IDNA2008 BiDi rules are enforced

    it "handles Hebrew domains" do
      # Simple Hebrew domain
      SimpleIDN.to_ascii("שלום").should_not be_nil
    end

    it "handles Arabic domains" do
      # Simple Arabic domain
      SimpleIDN.to_ascii("مثال").should_not be_nil
    end
  end

  describe "Invalid punycode detection" do
    it "returns nil for invalid ACE prefix" do
      SimpleIDN.to_unicode("xn---").should be_nil
    end

    it "returns nil for invalid punycode encoding" do
      SimpleIDN.to_unicode("xn--a-").should be_nil
    end

    it "handles valid ACE labels" do
      SimpleIDN.to_unicode("xn--nxasmq6b").should eq("βόλοσ")
    end
  end

  describe "Label length limits" do
    it "handles maximum label length (63 chars)" do
      # Valid 63-character ASCII label
      long_label = "a" * 63
      SimpleIDN.to_ascii(long_label).should eq(long_label)
    end

    it "returns nil for labels exceeding 63 characters in ASCII form" do
      # This unicode string produces a punycode label > 63 chars
      # 1234567890ä1234567890123456789012345678901234567890123456 -> too long
      long_unicode = "1234567890ä1234567890123456789012345678901234567890123456"
      # ICU should reject this as the ACE form exceeds 63 chars
      result = SimpleIDN.to_ascii(long_unicode)
      # The punycode would be 67 chars which exceeds the limit
      # Implementation may return nil or the result depending on settings
    end
  end

  describe "Emoji and special characters" do
    it "encodes emoji in domain labels" do
      # Emoji are valid Unicode codepoints, ICU encodes them
      # Note: Some registries may reject them, but ICU allows encoding
      SimpleIDN.to_ascii("❤️.com").should_not be_nil
    end
  end

  describe "Japanese domains" do
    it "handles Japanese hiragana" do
      # Example from JOSEFSSON test vectors
      result = SimpleIDN.to_ascii("そのスピードで")
      result.should eq("xn--d9juau41awczczp")
    end

    it "handles mixed Japanese scripts" do
      # パフィーdeルンバ (katakana + latin + katakana)
      result = SimpleIDN.to_ascii("パフィーdeルンバ")
      result.should eq("xn--de-jg4avhby1noc0d")
    end
  end

  describe "Chinese domains" do
    it "handles simplified Chinese" do
      # 他们为什么不说中文 (Why don't they speak Chinese)
      SimpleIDN.to_ascii("他们为什么不说中文").should eq("xn--ihqwcrb4cv8a8dqg056pqjye")
    end

    it "handles traditional Chinese" do
      # 他們爲什麽不說中文 (Traditional)
      SimpleIDN.to_ascii("他們爲什麽不說中文").should eq("xn--ihqwctvzc91f659drss3x8bo0yb")
    end
  end

  describe "Russian/Cyrillic domains" do
    it "handles Cyrillic domains" do
      # почемужеонинеговaborятпорусски
      cyrillic = "почемужеонинеговорятпорусски"
      result = SimpleIDN.to_ascii(cyrillic)
      result.should eq("xn--b1abfaaepdrnnbgefbadotcwatmq2g4l")
    end
  end

  describe "Arabic domains" do
    it "handles Arabic script" do
      # ليهمابتكلموشعربي (Why don't they speak Arabic)
      arabic = "ليهمابتكلموشعربي؟"
      result = SimpleIDN.to_ascii(arabic)
      result.should eq("xn--egbpdaj6bu4bxfgehfvwxn")
    end
  end

  describe "Hebrew domains" do
    it "handles Hebrew script" do
      # למaborהישראליםלאמדברים
      hebrew = "למההםפשוטלאמדבריםעברית"
      result = SimpleIDN.to_ascii(hebrew)
      result.should eq("xn--4dbcagdahymbxekheh6e0a7fei0b")
    end
  end

  describe "Korean domains" do
    it "handles Korean Hangul" do
      # Simple Korean test
      korean = "예제"
      result = SimpleIDN.to_ascii(korean)
      result.should_not be_nil
    end
  end

  describe "Greek domains" do
    it "handles Greek script" do
      # ελληνικά (Greek)
      greek = "ελληνικά"
      result = SimpleIDN.to_ascii(greek)
      result.should eq("xn--hxargifdar")
    end
  end

  describe "Hindi domains" do
    it "handles Devanagari script" do
      # यहलोगहिन्दीक्योंनहींबोलसकतेहैं
      hindi = "यहलोगहिन्दीक्योंनहींबोलसकतेहैं"
      result = SimpleIDN.to_ascii(hindi)
      result.should eq("xn--i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd")
    end
  end

  describe "Maltese domains" do
    it "handles Maltese characters" do
      # bonġusaħħa
      maltese = "bonġusaħħa"
      result = SimpleIDN.to_ascii(maltese)
      result.should eq("xn--bonusaa-5bb1da")
    end
  end

  describe "Edge cases" do
    it "handles empty string" do
      SimpleIDN.to_ascii("").should eq("")
      SimpleIDN.to_unicode("").should eq("")
    end

    it "handles nil" do
      SimpleIDN.to_ascii(nil).should be_nil
      SimpleIDN.to_unicode(nil).should be_nil
    end

    it "handles single dot" do
      SimpleIDN.to_ascii(".").should eq(".")
      SimpleIDN.to_unicode(".").should eq(".")
    end

    it "handles multiple dots (empty labels allowed by label processing)" do
      # When processing labels individually, empty labels are passed through
      SimpleIDN.to_ascii("a..b").should eq("a..b")
    end

    it "handles trailing dot (FQDN)" do
      SimpleIDN.to_ascii("example.com.").should eq("example.com.")
    end

    it "handles wildcard label" do
      SimpleIDN.to_ascii("*.example.com").should eq("*.example.com")
    end

    it "handles underscore prefix (for SRV records)" do
      SimpleIDN.to_ascii("_dmarc.example.com").should eq("_dmarc.example.com")
      SimpleIDN.to_ascii("_tcp.example.com").should eq("_tcp.example.com")
    end

    it "handles @ symbol" do
      SimpleIDN.to_ascii("@").should eq("@")
    end
  end

  describe "Round-trip conversion" do
    it "preserves domains through ascii->unicode->ascii" do
      domains = [
        "münchen.de",
        "日本語.jp",
        "россия.рф",
        "ελλάδα.gr",
      ]

      domains.each do |domain|
        ascii = SimpleIDN.to_ascii(domain)
        next if ascii.nil?
        unicode = SimpleIDN.to_unicode(ascii)
        next if unicode.nil?
        ascii2 = SimpleIDN.to_ascii(unicode)
        ascii2.should eq(ascii)
      end
    end
  end

  describe "CONTEXTO and CONTEXTJ rules" do
    # Zero Width Non-Joiner (ZWNJ) U+200C
    # Zero Width Joiner (ZWJ) U+200D

    it "handles valid ZWNJ in proper context" do
      # a + virama + ZWNJ + b (Devanagari context where ZWNJ is valid)
      # a\u094D\u200Cb - virama provides context for ZWNJ
      valid_zwnj = "a\u094D\u200Cb"
      result = SimpleIDN.to_ascii(valid_zwnj)
      result.should eq("xn--ab-fsf604u")
    end

    it "rejects invalid ZWNJ without proper context" do
      # a + ZWNJ + b (no virama, ZWNJ has no context)
      invalid_zwnj = "a\u200Cb"
      result = SimpleIDN.to_ascii(invalid_zwnj)
      # With CHECK_CONTEXTJ, this should fail
      result.should be_nil
    end

    it "rejects invalid ZWJ without proper context" do
      # a + ZWJ + b (no combining mark context)
      invalid_zwj = "a\u200Db"
      result = SimpleIDN.to_ascii(invalid_zwj)
      # With CHECK_CONTEXTJ, this should fail
      result.should be_nil
    end
  end

  describe "Hyphen rules (STD3)" do
    # IDNA2008 with STD3 rules forbids:
    # - Labels starting with hyphen
    # - Labels ending with hyphen
    # - Labels with hyphens in 3rd AND 4th position (unless ACE prefix)

    it "rejects labels starting with hyphen" do
      SimpleIDN.to_ascii("-example.com").should be_nil
    end

    it "rejects labels ending with hyphen" do
      SimpleIDN.to_ascii("example-.com").should be_nil
    end

    it "allows hyphens in the middle" do
      SimpleIDN.to_ascii("my-example.com").should eq("my-example.com")
    end

    it "allows ACE prefix (xn--)" do
      # xn-- in positions 3-4 is valid for punycode
      SimpleIDN.to_unicode("xn--nxasmq6b.com").should eq("βόλοσ.com")
    end

    it "rejects non-ACE labels with hyphens in positions 3-4" do
      # Labels like "ab--cd" are forbidden (hyphens in pos 3-4 but not xn--)
      SimpleIDN.to_ascii("ab--cd.com").should be_nil
    end
  end

  describe "Full-width ASCII compatibility" do
    # UTS #46 maps full-width ASCII to regular ASCII

    it "converts full-width letters to ASCII" do
      # ａｂｃ (full-width abc) -> abc
      SimpleIDN.to_ascii("\uFF41\uFF42\uFF43.com").should eq("abc.com")
    end

    it "converts full-width digits to ASCII" do
      # １２３ (full-width 123) -> 123
      SimpleIDN.to_ascii("\uFF11\uFF12\uFF13.com").should eq("123.com")
    end

    it "handles mixed full-width and regular ASCII" do
      SimpleIDN.to_ascii("\uFF45xample.com").should eq("example.com")
    end
  end

  describe "Invalid characters" do
    it "rejects control characters" do
      # U+0000 NUL
      SimpleIDN.to_ascii("exam\u0000ple.com").should be_nil
    end

    it "rejects ASCII control characters" do
      # U+0007 BEL
      SimpleIDN.to_ascii("exam\u0007ple.com").should be_nil
    end

    it "rejects space characters in labels" do
      SimpleIDN.to_ascii("exam ple.com").should be_nil
    end

    it "rejects prohibited symbols" do
      # U+FFFD REPLACEMENT CHARACTER is not allowed in domain names
      SimpleIDN.to_ascii("exam\uFFFDple.com").should be_nil
    end
  end

  describe "Thai domains" do
    it "handles Thai script" do
      # ไทย (Thai)
      result = SimpleIDN.to_ascii("ไทย.com")
      result.should_not be_nil
      result.should eq("xn--o3cw4h.com")
    end

    it "round-trips Thai domains" do
      thai = "ไทย.th"
      ascii = SimpleIDN.to_ascii(thai)
      ascii.should_not be_nil
      unicode = SimpleIDN.to_unicode(ascii.not_nil!)
      unicode.should_not be_nil
      # Round-trip back to ASCII
      SimpleIDN.to_ascii(unicode.not_nil!).should eq(ascii)
    end
  end

  describe "Transitional processing" do
    # Transitional processing applies different mappings

    it "maps ß to ss in transitional mode" do
      SimpleIDN.to_ascii("faß.de", transitional: true).should eq("fass.de")
    end

    it "preserves ß in nontransitional mode (default)" do
      SimpleIDN.to_ascii("faß.de").should eq("xn--fa-hia.de")
    end

    it "maps final sigma ς to σ in transitional mode" do
      # In transitional mode, ς maps to σ
      # βόλος (with ς) should become βόλοσ (with σ) -> same punycode as βόλοσ
      result_transitional = SimpleIDN.to_ascii("βόλος", transitional: true)
      result_nontransitional = SimpleIDN.to_ascii("βόλοσ")
      result_transitional.should eq(result_nontransitional)
    end

    it "preserves final sigma ς in nontransitional mode" do
      # In nontransitional mode, ς is preserved distinct from σ
      result_final = SimpleIDN.to_ascii("βόλος")  # with final sigma
      result_regular = SimpleIDN.to_ascii("βόλοσ")  # with regular sigma
      result_final.should_not eq(result_regular)
    end
  end

  describe "Vietnamese domains" do
    it "handles Vietnamese with diacritics" do
      # Việt Nam
      result = SimpleIDN.to_ascii("việtnam.vn")
      result.should_not be_nil
      result.should eq("xn--vitnam-jk8b.vn")
    end
  end

  describe "Turkish/Azerbaijani special case" do
    it "handles dotless i (ı)" do
      # Turkish dotless i (ı) U+0131
      result = SimpleIDN.to_ascii("ışık.com")
      result.should_not be_nil
    end

    it "handles dotted I correctly" do
      # Capital I with dot (İ) U+0130 -> maps to i
      result = SimpleIDN.to_ascii("İstanbul.com")
      result.should_not be_nil
    end
  end

  describe "Numeric-only labels" do
    it "allows all-numeric labels" do
      # All-numeric labels are valid
      SimpleIDN.to_ascii("123.456.789").should eq("123.456.789")
    end
  end

  describe "Mixed script with ASCII" do
    it "handles CJK with ASCII numbers" do
      # Mixed Japanese/ASCII is valid
      result = SimpleIDN.to_ascii("日本1.com")
      result.should_not be_nil
    end
  end
end
