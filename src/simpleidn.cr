require "./simpleidn/version"
require "./simpleidn/lib_icu"

module SimpleIDN
  class ConversionError < Exception; end

  extend self

  # Convert a domain to ASCII (Punycode).
  #
  # If `transitional` is true, it uses transitional processing (e.g., ß -> ss).
  # If `transitional` is false (default), it uses nontransitional processing (e.g., ß -> xn--zca).
  #
  # Returns `nil` if the domain is nil or invalid per IDNA2008 rules.
  # Raises `ConversionError` if an ICU system error occurs (e.g., memory allocation failure).
  def to_ascii(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    process_domain(domain, transitional) do |label, idna, info, err|
      convert_label_to_ascii(label, idna, info, err)
    end
  end

  # Convert a domain to Unicode.
  #
  # If `transitional` is true, it uses transitional processing.
  #
  # Returns `nil` if the domain is nil or invalid per IDNA2008 rules.
  # Raises `ConversionError` if an ICU system error occurs (e.g., memory allocation failure).
  def to_unicode(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    process_domain(domain, transitional) do |label, idna, info, err|
      convert_label_to_unicode(label, idna, info, err)
    end
  end

  private def process_domain(domain : String, transitional : Bool, &)
    # Split by dots, process each label, rejoin
    labels = domain.split('.')

    # Options: Use STD3 rules, Check BiDi, Check ContextJ, Check ContextO
    options = LibICU::UIDNA_USE_STD3_RULES |
              LibICU::UIDNA_CHECK_BIDI |
              LibICU::UIDNA_CHECK_CONTEXTJ |
              LibICU::UIDNA_CHECK_CONTEXTO

    # If NOT transitional, set the NONTRANSITIONAL flag.
    if !transitional
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_ASCII
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_UNICODE
    end

    err = LibICU::UErrorCode::U_ZERO_ERROR
    idna = LibICU.uidna_openUTS46(options.to_u32, pointerof(err))

    if err != LibICU::UErrorCode::U_ZERO_ERROR
      raise ConversionError.new("ICU uidna_openUTS46 failed with error code #{err.value}")
    end

    begin
      info = LibICU::UIDNAInfo.new
      info.size = sizeof(LibICU::UIDNAInfo).to_i16

      results = labels.map do |label|
        # Pass through special labels that start with _ or are special chars like *, @
        if should_pass_through?(label)
          label
        else
          info.errors = 0
          err = LibICU::UErrorCode::U_ZERO_ERROR
          result = yield(label, idna, pointerof(info), pointerof(err))
          return nil if result.nil?
          result
        end
      end

      results.join(".")
    ensure
      LibICU.uidna_close(idna) if idna
    end
  end

  # Labels that should be passed through without IDNA processing
  private def should_pass_through?(label : String) : Bool
    return true if label.empty?
    return true if label.starts_with?('_')
    return true if label == "*"
    return true if label == "@"
    false
  end

  private def convert_label_to_ascii(label : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*)
    capacity = 256
    dest = Slice(UInt8).new(capacity)

    len = LibICU.uidna_nameToASCII_UTF8(idna, label.to_unsafe, label.bytesize, dest.to_unsafe, capacity, info, err)

    # Check for buffer overflow
    if (err.value.value == 15) || (len > capacity)
      err.value = LibICU::UErrorCode::U_ZERO_ERROR
      info.value.errors = 0
      capacity = len + 1
      dest = Slice(UInt8).new(capacity)
      len = LibICU.uidna_nameToASCII_UTF8(idna, label.to_unsafe, label.bytesize, dest.to_unsafe, capacity, info, err)
    end

    # Check for ICU system error (not IDNA validation error)
    if err.value.value > 0
      raise ConversionError.new("ICU uidna_nameToASCII_UTF8 failed with error code #{err.value.value}")
    end

    # Check for IDNA validation error
    if info.value.errors > 0
      return nil
    end

    String.new(dest[0, len])
  end

  private def convert_label_to_unicode(label : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*)
    capacity = 256
    dest = Slice(UInt8).new(capacity)

    len = LibICU.uidna_nameToUnicode_UTF8(idna, label.to_unsafe, label.bytesize, dest.to_unsafe, capacity, info, err)

    # Check for buffer overflow
    if (err.value.value == 15) || (len > capacity)
      err.value = LibICU::UErrorCode::U_ZERO_ERROR
      info.value.errors = 0
      capacity = len + 1
      dest = Slice(UInt8).new(capacity)
      len = LibICU.uidna_nameToUnicode_UTF8(idna, label.to_unsafe, label.bytesize, dest.to_unsafe, capacity, info, err)
    end

    # Check for ICU system error (not IDNA validation error)
    if err.value.value > 0
      raise ConversionError.new("ICU uidna_nameToUnicode_UTF8 failed with error code #{err.value.value}")
    end

    # Check for IDNA validation error
    if info.value.errors > 0
      return nil
    end

    String.new(dest[0, len])
  end
end
