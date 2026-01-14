require "icu"
require "./simpleidn/version"
require "./simpleidn/uts46mapping"

# Monkey-patch String#to_uchars to handle surrogate pairs correctly via Crystal's built-in to_utf16
# The implementation in icu.cr shard (v1.0.0) naively calls Char#ord.to_u16 which overflows for codepoints > 0xFFFF.
class String
  def to_uchars
    utf16 = self.to_utf16
    ICU::UChars.new(utf16.to_unsafe, utf16.size)
  end
end

# Monkey-patch ICU::UChars#to_s to handle UTF-16 decoding correctly using Crystal's built-in String.from_utf16
struct ICU::UChars
  def to_s(size : Int? = nil)
    s = size || @slice.size
    String.from_utf16(@slice[0, s])
  end
end

# Monkey-patch ICU::Normalizer#normalize to pass correct UTF-16 length to ICU
class ICU::Normalizer
  def normalize(text : String) : String
    src = text.to_uchars
    # Allocate destination buffer. src.size * 3 is usually sufficient.
    dest = ICU::UChars.new(src.size * 3)

    ustatus = LibICU::UErrorCode::UZeroError
    # Use src.size (UTF-16 length) instead of text.size (codepoint count)
    size = LibICU.unorm2_normalize(@unorm, src, src.size, dest, dest.size, pointerof(ustatus))
    ICU.check_error!(ustatus)

    dest.to_s(size)
  end
end

module SimpleIDN
  class ConversionError < Exception; end

  module Punycode
    INITIAL_N    =       0x80
    INITIAL_BIAS =         72
    DELIMITER    =       0x2D
    BASE         =         36
    DAMP         =        700
    TMIN         =          1
    TMAX         =         26
    SKEW         =         38
    MAXINT       = 0x7FFFFFFF
    ASCII_MAX    =       0x7F

    EMPTY = ""

    extend self

    def decode_digit(cp)
      if cp >= 48 && cp <= 57
        cp - 22
      elsif cp >= 65 && cp <= 90
        cp - 65
      elsif cp >= 97 && cp <= 122
        cp - 97
      else
        BASE
      end
    end

    def encode_digit(d)
      d + 22 + 75 * (d < 26 ? 1 : 0)
    end

    def adapt(delta, numpoints, firsttime)
      delta = firsttime ? (delta // DAMP) : (delta >> 1)
      delta += (delta // numpoints)

      k = 0
      while delta > (((BASE - TMIN) * TMAX) // 2)
        delta //= BASE - TMIN
        k += BASE
      end
      k + (BASE - TMIN + 1) * delta // (delta + SKEW)
    end

    def decode(input : String)
      input_codepoints = input.codepoints.to_a
      output = [] of Int32

      n = INITIAL_N
      i = 0
      bias = INITIAL_BIAS

      basic = input_codepoints.rindex(DELIMITER) || 0

      input_codepoints[0...basic].each do |char|
        raise ConversionError.new("Illegal input >= 0x80") if char > ASCII_MAX
        output << char
      end

      ic = basic > 0 ? basic + 1 : 0
      while ic < input_codepoints.size
        oldi = i
        w = 1
        k = BASE
        loop do
          raise ConversionError.new("punycode_bad_input(1)") if ic >= input_codepoints.size

          digit = decode_digit(input_codepoints[ic])
          ic += 1

          raise ConversionError.new("punycode_bad_input(2)") if digit >= BASE

          raise ConversionError.new("punycode_overflow(1)") if digit > (MAXINT - i) // w

          i += digit * w
          t = k <= bias ? TMIN : k >= bias + TMAX ? TMAX : k - bias
          break if digit < t
          raise ConversionError.new("punycode_overflow(2)") if w > MAXINT // (BASE - t)

          w *= BASE - t
          k += BASE
        end

        out_len = output.size + 1
        bias = adapt(i - oldi, out_len, oldi == 0)

        raise ConversionError.new("punycode_overflow(3)") if (i // out_len) > MAXINT - n

        n += (i // out_len)
        i %= out_len

        output.insert(i, n)
        i += 1
      end

      String.build do |str|
        output.each { |c| str << c.chr }
      end
    end

    def encode(input : String)
      input_codepoints = input.codepoints.to_a
      output = [] of Int32

      n = INITIAL_N
      delta = 0
      bias = INITIAL_BIAS

      # Handle basic code points
      input_codepoints.each do |char|
        output << char if char <= ASCII_MAX
      end

      h = b = output.size

      output << DELIMITER if b > 0

      while h < input_codepoints.size
        m = MAXINT

        input_codepoints.each do |char|
          m = char if char >= n && char < m
        end

        raise ConversionError.new("punycode_overflow (1)") if m - n > ((MAXINT - delta) // (h + 1))

        delta += (m - n) * (h + 1)
        n = m

        input_codepoints.each do |char|
          if char < n
            delta += 1
            raise ConversionError.new("punycode_overflow(2)") if delta > MAXINT
          end

          next unless char == n

          q = delta
          k = BASE
          loop do
            t = k <= bias ? TMIN : k >= bias + TMAX ? TMAX : k - bias
            break if q < t
            output << encode_digit(t + (q - t) % (BASE - t))
            q = (q - t) // (BASE - t)
            k += BASE
          end
          output << encode_digit(q)
          bias = adapt(delta, h + 1, h == b)
          delta = 0
          h += 1
        end

        delta += 1
        n += 1
      end

      String.build do |str|
        output.each { |c| str << c.chr }
      end
    end
  end

  ACE_PREFIX         = "xn--"
  ASCII_MAX          = 0x7F
  DOT                = '.'
  LABEL_SEPARATOR_RE = /[\x{002e}\x{ff0e}\x{3002}\x{ff61}]/

  # Normalized TRANSITIONAL to Array(Int32)
  TRANSITIONAL = {
    0x00DF => [0x0073, 0x0073],
    0x03C2 => [0x03C3],
    0x200C => [] of Int32,
    0x200D => [] of Int32,
  }

  extend self

  def uts46map(str : String, transitional : Bool = false)
    mapped = str.codepoints.to_a.map do |cp|
      res = SimpleIDN::UTS64MAPPING.fetch(cp) { [cp] }

      if transitional
        if res.size == 1
          val = res[0]
          if TRANSITIONAL.has_key?(val)
            TRANSITIONAL[val]
          else
            res
          end
        else
          res
        end
      else
        res
      end
    end.flatten

    built_str = String.build do |io|
      mapped.each { |cp| io << cp.chr }
    end
    ICU::Normalizer::NFC.new.normalize(built_str)
  end

  def to_ascii(domain : String?, transitional : Bool = false)
    return nil if domain.nil?
    mapped_domain = uts46map(domain, transitional)
    domain_array = mapped_domain.split(LABEL_SEPARATOR_RE)
    out = [] of String
    content = false

    domain_array.each do |s|
      if s.empty? && !content
        next
      end
      content = true

      use_punycode = s.codepoints.any? { |cp| cp > ASCII_MAX }
      out << (use_punycode ? ACE_PREFIX + Punycode.encode(s) : s)
    end

    if out.empty? && !mapped_domain.empty?
      out = [DOT.to_s]
    end

    out.join(DOT)
  end

  def to_unicode(domain : String?, transitional : Bool = false)
    return nil if domain.nil?
    mapped_domain = uts46map(domain, transitional)
    domain_array = mapped_domain.split(LABEL_SEPARATOR_RE)
    out = [] of String
    content = false

    domain_array.each do |s|
      if s.empty? && !content
        next
      end
      content = true

      if s.starts_with?(ACE_PREFIX)
        out << Punycode.decode(s[ACE_PREFIX.size..-1])
      else
        out << s
      end
    end

    if out.empty? && !mapped_domain.empty?
      out = [DOT.to_s]
    end

    out.join(DOT)
  end
end
