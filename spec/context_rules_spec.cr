require "./spec_helper"

describe SimpleIDN do
  describe "ContextJ/ContextO validation (IDNA2008)" do
    # MIDDLE DOT (·) U+00B7
    # Rule: Must be preceded by 'l' (U+006C) and followed by 'l' (U+006C)
    it "rejects MIDDLE DOT with no preceding 'l'" do
      # "a·l" -> punycode "xn--al-0ea"
      SimpleIDN.to_ascii("a\u00B7l").should be_nil
    end

    it "rejects MIDDLE DOT with nothing preceding" do
      # "·l" -> punycode "xn--l-fda"
      SimpleIDN.to_ascii("\u00B7l").should be_nil
    end

    it "rejects MIDDLE DOT with no following 'l'" do
      # "l·a" -> punycode "xn--la-0ea"
      SimpleIDN.to_ascii("l\u00B7a").should be_nil
    end

    it "rejects MIDDLE DOT with nothing following" do
      # "l·" -> punycode "xn--l-gda"
      SimpleIDN.to_ascii("l\u00B7").should be_nil
    end

    # Greek KERAIA (͵) U+0375
    # Rule: Must be preceded by a Greek script character
    it "rejects Greek KERAIA not followed by Greek" do
      # "α͵S" -> punycode "xn--S-jib3p" (S is not Greek)
      SimpleIDN.to_ascii("α\u0375S").should be_nil
    end

    it "rejects Greek KERAIA not followed by anything" do
      # "α͵" -> punycode "xn--wva3j"
      SimpleIDN.to_ascii("α\u0375").should be_nil
    end

    # Hebrew GERESH (׳) U+05F3
    # Rule: Must be preceded by a Hebrew script character
    it "rejects Hebrew GERESH not preceded by anything" do
      # "׳ב" -> punycode "xn--5db1e"
      SimpleIDN.to_ascii("\u05F3\u05D1").should be_nil
    end

    # Hebrew GERSHAYIM (״) U+05F4
    # Rule: Must be preceded by a Hebrew script character
    it "rejects Hebrew GERSHAYIM not preceded by anything" do
      # "״ב" -> punycode "xn--5db3e"
      SimpleIDN.to_ascii("\u05F4\u05D1").should be_nil
    end

    # KATAKANA MIDDLE DOT (・) U+30FB
    # Rule: Must contain at least one Katakana, Hiragana, or Han char
    it "rejects KATAKANA MIDDLE DOT with no Hiragana, Katakana, or Han" do
      # "def・abc" -> punycode "xn--defabc-k64e"
      SimpleIDN.to_ascii("def\u30FBabc").should be_nil
    end

    it "rejects KATAKANA MIDDLE DOT with no other characters" do
      # "・" -> punycode "xn--vek"
      SimpleIDN.to_ascii("\u30FB").should be_nil
    end
  end
end
