# encoding: utf-8
require "../spec_helper"
require "../test_vectors"

describe "SimpleIDN.to_ascii_hostname" do
  describe "Josefsson Test Vectors" do
    it "passes all test cases" do
      TESTCASES_JOSEFSSON.each do |testcase, vector|
        SimpleIDN.to_ascii_hostname(vector[0].as(String)).should eq(vector[1].as(String))
      end
    end
  end

  describe "IDNA2008 Conformance (Basic)" do
    it "preserves simple ASCII domains" do
      SimpleIDN.to_ascii_hostname("example.com").should eq("example.com")
    end

    it "lowercases ASCII domains" do
      SimpleIDN.to_ascii_hostname("EXAMPLE.COM").should eq("example.com")
      SimpleIDN.to_ascii_hostname("www.eXample.cOm").should eq("www.example.com")
    end
  end

  describe "German ß (Eszett) handling" do
    it "converts faß.de to xn--fa-hia.de (nontransitional)" do
      SimpleIDN.to_ascii_hostname("faß.de").should eq("xn--fa-hia.de")
    end

    it "converts faß.de to fass.de (transitional)" do
      SimpleIDN.to_ascii_hostname("faß.de", transitional: true).should eq("fass.de")
    end

    it "converts Faß.de with case folding" do
      SimpleIDN.to_ascii_hostname("Faß.de").should eq("xn--fa-hia.de")
    end

    it "handles capital ẞ (U+1E9E)" do
      SimpleIDN.to_ascii_hostname("FAẞ.de").should eq("xn--fa-hia.de")
    end
  end

  describe "Greek final sigma handling" do
    it "handles βόλος with final sigma" do
      SimpleIDN.to_ascii_hostname("βόλος").should eq("xn--nxasmm1c")
    end

    it "handles βόλοσ with regular sigma" do
      SimpleIDN.to_ascii_hostname("βόλοσ").should eq("xn--nxasmq6b")
    end

    it "handles Greek domain with .com" do
      SimpleIDN.to_ascii_hostname("βόλος.com").should eq("xn--nxasmm1c.com")
    end
  end

  describe "German umlaut handling" do
    it "converts bücher.de to punycode" do
      SimpleIDN.to_ascii_hostname("bücher.de").should eq("xn--bcher-kva.de")
    end

    it "handles capital Bücher" do
      SimpleIDN.to_ascii_hostname("Bücher.de").should eq("xn--bcher-kva.de")
    end

    it "handles combining diaeresis" do
      SimpleIDN.to_ascii_hostname("bu\u0308cher.de").should eq("xn--bcher-kva.de")
    end

    it "handles ÖBB" do
      SimpleIDN.to_ascii_hostname("öbb").should eq("xn--bb-eka")
      SimpleIDN.to_ascii_hostname("ÖBB").should eq("xn--bb-eka")
    end
  end

  describe "Unicode normalization (NFC)" do
    it "normalizes combining characters" do
      SimpleIDN.to_ascii_hostname("a\u0308.com").should eq(SimpleIDN.to_ascii_hostname("ä.com"))
    end

    it "handles precomposed vs decomposed é" do
      SimpleIDN.to_ascii_hostname("café.com").should eq(SimpleIDN.to_ascii_hostname("cafe\u0301.com"))
    end
  end

  describe "BiDi (Bidirectional) domain handling" do
    it "handles Hebrew domains" do
      SimpleIDN.to_ascii_hostname("שלום").should_not be_nil
    end

    it "handles Arabic domains" do
      SimpleIDN.to_ascii_hostname("مثال").should_not be_nil
    end
  end

  describe "Label length limits (RFC 1035)" do
    it "handles maximum label length (63 chars ASCII)" do
      long_label = "a" * 63
      SimpleIDN.to_ascii_hostname(long_label).should eq(long_label)
    end

    it "rejects labels exceeding 63 characters in ASCII form" do
      too_long_label = "a" * 64
      SimpleIDN.to_ascii_hostname(too_long_label).should be_nil
    end

    it "accepts 62-character ASCII label" do
      label = "a" * 62
      SimpleIDN.to_ascii_hostname(label).should eq(label)
    end

    it "rejects unicode labels that produce punycode > 63 bytes" do
      long_unicode = "a" * 50 + "ä" * 10
      result = SimpleIDN.to_ascii_hostname(long_unicode)
      result.should be_nil
    end

    it "accepts unicode labels that produce punycode <= 63 bytes" do
      short_unicode = "münchen"
      result = SimpleIDN.to_ascii_hostname(short_unicode)
      result.should eq("xn--mnchen-3ya")
    end

    it "allows exactly 63-byte punycode label" do
      label_59 = "a" * 59
      SimpleIDN.to_ascii_hostname(label_59).should eq(label_59)
    end
  end

  describe "Hostname length limits (RFC 1035)" do
    it "accepts hostname of exactly 253 bytes" do
      label_63 = "a" * 63
      label_61 = "a" * 61
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_61}"
      SimpleIDN.to_ascii_hostname(hostname).should eq(hostname)
    end

    it "rejects hostname of 254 bytes" do
      label_63 = "a" * 63
      label_62 = "a" * 62
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_62}"
      SimpleIDN.to_ascii_hostname(hostname).should be_nil
    end

    it "rejects hostname of 255 bytes" do
      label_63 = "a" * 63
      hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_63}"
      SimpleIDN.to_ascii_hostname(hostname).should be_nil
    end
  end

  describe "Strict mode behavior (Hostname)" do
    it "rejects * in strict mode" do
      SimpleIDN.to_ascii_hostname("*.hello.com").should be_nil
    end

    it "rejects @ in strict mode" do
      SimpleIDN.to_ascii_hostname("@.hello.com").should be_nil
    end

    it "rejects leading _ in strict mode" do
      SimpleIDN.to_ascii_hostname("_something.example.org").should be_nil
    end

    it "rejects @ (standalone)" do
      SimpleIDN.to_ascii_hostname("@").should be_nil
    end

    it "rejects underscore-prefixed labels" do
      SimpleIDN.to_ascii_hostname("_dmarc.example.com").should be_nil
      SimpleIDN.to_ascii_hostname("_tcp.example.com").should be_nil
    end

    it "rejects wildcard labels" do
      SimpleIDN.to_ascii_hostname("*.example.com").should be_nil
    end
  end

  describe "Special characters and scripts" do
    it "encodes emoji" do
      SimpleIDN.to_ascii_hostname("❤️.com").should_not be_nil
    end

    it "handles Japanese hiragana" do
      SimpleIDN.to_ascii_hostname("そのスピードで").should eq("xn--d9juau41awczczp")
    end

    it "handles Chinese" do
      SimpleIDN.to_ascii_hostname("他们为什么不说中文").should eq("xn--ihqwcrb4cv8a8dqg056pqjye")
    end

    it "handles Cyrillic" do
      SimpleIDN.to_ascii_hostname("почемужеонинеговорятпорусски").should eq("xn--b1abfaaepdrnnbgefbadotcwatmq2g4l")
    end

    it "handles Arabic" do
      SimpleIDN.to_ascii_hostname("ليهمابتكلموشعربي؟").should eq("xn--egbpdaj6bu4bxfgehfvwxn")
    end

    it "handles Hebrew" do
      SimpleIDN.to_ascii_hostname("למההםפשוטלאמדבריםעברית").should eq("xn--4dbcagdahymbxekheh6e0a7fei0b")
    end

    it "handles Korean Hangul" do
      SimpleIDN.to_ascii_hostname("예제").should_not be_nil
    end

    it "handles Hindi (Devanagari)" do
      hindi = "यहलोगहिन्दीक्योंनहींबोलसकतेहैं"
      SimpleIDN.to_ascii_hostname(hindi).should eq("xn--i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd")
    end

    it "handles Maltese" do
      SimpleIDN.to_ascii_hostname("bonġusaħħa").should eq("xn--bonusaa-5bb1da")
    end

    it "handles Thai" do
      SimpleIDN.to_ascii_hostname("ไทย.com").should eq("xn--o3cw4h.com")
    end

    it "handles Vietnamese" do
      SimpleIDN.to_ascii_hostname("việtnam.vn").should eq("xn--vitnam-jk8b.vn")
    end

    it "handles Turkish dotless i" do
      SimpleIDN.to_ascii_hostname("ışık.com").should_not be_nil
    end

    it "handles Turkish dotted I" do
      SimpleIDN.to_ascii_hostname("İstanbul.com").should_not be_nil
    end

    it "handles Numeric-only labels" do
      SimpleIDN.to_ascii_hostname("123.456.789").should eq("123.456.789")
    end

    it "handles Mixed script (CJK + ASCII)" do
      SimpleIDN.to_ascii_hostname("日本1.com").should_not be_nil
    end
  end

  describe "Hyphen rules (STD3)" do
    it "rejects labels starting with hyphen" do
      SimpleIDN.to_ascii_hostname("-example.com").should be_nil
    end

    it "rejects labels ending with hyphen" do
      SimpleIDN.to_ascii_hostname("example-.com").should be_nil
    end

    it "allows hyphens in the middle" do
      SimpleIDN.to_ascii_hostname("my-example.com").should eq("my-example.com")
    end

    it "rejects non-ACE labels with hyphens in positions 3-4" do
      SimpleIDN.to_ascii_hostname("ab--cd.com").should be_nil
    end
  end

  describe "Full-width ASCII compatibility" do
    it "converts full-width letters to ASCII" do
      SimpleIDN.to_ascii_hostname("\uFF41\uFF42\uFF43.com").should eq("abc.com")
    end

    it "converts full-width digits to ASCII" do
      SimpleIDN.to_ascii_hostname("\uFF11\uFF12\uFF13.com").should eq("123.com")
    end
  end

  describe "Invalid characters" do
    it "rejects control characters" do
      SimpleIDN.to_ascii_hostname("exam\u0000ple.com").should be_nil
    end

    it "rejects ASCII control characters" do
      SimpleIDN.to_ascii_hostname("exam\u0007ple.com").should be_nil
    end

    it "rejects space characters in labels" do
      SimpleIDN.to_ascii_hostname("exam ple.com").should be_nil
    end

    it "rejects prohibited symbols" do
      SimpleIDN.to_ascii_hostname("exam\uFFFDple.com").should be_nil
    end
  end

  describe "ContextJ/ContextO validation" do
    it "handles valid ZWNJ in proper context" do
      valid_zwnj = "a\u094D\u200Cb"
      SimpleIDN.to_ascii_hostname(valid_zwnj).should eq("xn--ab-fsf604u")
    end

    it "rejects invalid ZWNJ without proper context" do
      SimpleIDN.to_ascii_hostname("a\u200Cb").should be_nil
    end

    it "rejects invalid ZWJ without proper context" do
      SimpleIDN.to_ascii_hostname("a\u200Db").should be_nil
    end

    it "rejects MIDDLE DOT with no preceding 'l'" do
      SimpleIDN.to_ascii_hostname("a\u00B7l").should be_nil
    end

    it "rejects MIDDLE DOT with nothing preceding" do
      SimpleIDN.to_ascii_hostname("\u00B7l").should be_nil
    end

    it "rejects MIDDLE DOT with no following 'l'" do
      SimpleIDN.to_ascii_hostname("l\u00B7a").should be_nil
    end

    it "rejects MIDDLE DOT with nothing following" do
      SimpleIDN.to_ascii_hostname("l\u00B7").should be_nil
    end

    it "rejects Greek KERAIA not followed by Greek" do
      SimpleIDN.to_ascii_hostname("α\u0375S").should be_nil
    end

    it "rejects Greek KERAIA not followed by anything" do
      SimpleIDN.to_ascii_hostname("α\u0375").should be_nil
    end

    it "rejects Hebrew GERESH not preceded by anything" do
      SimpleIDN.to_ascii_hostname("\u05F3\u05D1").should be_nil
    end

    it "rejects Hebrew GERSHAYIM not preceded by anything" do
      SimpleIDN.to_ascii_hostname("\u05F4\u05D1").should be_nil
    end

    it "rejects KATAKANA MIDDLE DOT with no Hiragana, Katakana, or Han" do
      SimpleIDN.to_ascii_hostname("def\u30FBabc").should be_nil
    end

    it "rejects KATAKANA MIDDLE DOT with no other characters" do
      SimpleIDN.to_ascii_hostname("\u30FB").should be_nil
    end
  end

  describe "Compatibility with json_schemer hostname validation" do
    it "validates simple ASCII hostname" do
      SimpleIDN.to_ascii_hostname("example.com").should eq("example.com")
    end

    it "validates hostname with hyphens" do
      SimpleIDN.to_ascii_hostname("my-example.com").should eq("my-example.com")
    end

    it "rejects hostname starting with hyphen" do
      SimpleIDN.to_ascii_hostname("-invalid.com").should be_nil
    end

    it "rejects hostname ending with hyphen" do
      SimpleIDN.to_ascii_hostname("invalid-.com").should be_nil
    end

    it "validates uppercase hostname (case folding)" do
      SimpleIDN.to_ascii_hostname("EXAMPLE.COM").should eq("example.com")
    end

    it "validates IDN hostname" do
      SimpleIDN.to_ascii_hostname("münchen.de").should eq("xn--mnchen-3ya.de")
    end

    it "rejects hostname with invalid characters" do
      SimpleIDN.to_ascii_hostname("exam ple.com").should be_nil
    end

    it "rejects hostname with control characters" do
      SimpleIDN.to_ascii_hostname("exam\u0000ple.com").should be_nil
    end

    it "rejects invalid characters (e.g. @)" do
      SimpleIDN.to_ascii_hostname("invalid@.com").should be_nil
    end

    it "converts Cyrillic IDN" do
      SimpleIDN.to_ascii_hostname("россия.рф").should eq("xn--h1alffa9f.xn--p1ai")
    end

    it "rejects IDN with leading hyphen" do
      SimpleIDN.to_ascii_hostname("-münchen.de").should be_nil
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
        ascii = SimpleIDN.to_ascii_hostname(domain)
        next if ascii.nil?
        unicode = SimpleIDN.to_unicode_hostname(ascii)
        next if unicode.nil?
        ascii2 = SimpleIDN.to_ascii_hostname(unicode)
        ascii2.should eq(ascii)
      end
    end
  end

  describe "Transitional combinations" do
    it "supports transitional=true" do
      # ß maps to ss in transitional mode
      SimpleIDN.to_ascii_hostname("faß.de", transitional: true).should eq("fass.de")
    end

    it "supports transitional=false" do
      # ß is preserved in nontransitional mode
      SimpleIDN.to_ascii_hostname("faß.de").should eq("xn--fa-hia.de")
    end
  end

  describe "Edge cases" do
    it "returns nil for empty string" do
      SimpleIDN.to_ascii_hostname("").should be_nil
    end

    it "handles nil" do
      SimpleIDN.to_ascii_hostname(nil).should be_nil
    end

    it "returns nil for single dot" do
      SimpleIDN.to_ascii_hostname(".").should be_nil
    end

    it "returns nil for multiple dots" do
      SimpleIDN.to_ascii_hostname("a..b").should be_nil
    end

    it "returns nil for trailing dot (FQDN)" do
      SimpleIDN.to_ascii_hostname("example.com.").should be_nil
    end

    it "should handle issue 8" do
      SimpleIDN.to_ascii_hostname("verm├Âgensberater").should eq("xn--vermgensberater-6jb1778m")
    end
  end
end
