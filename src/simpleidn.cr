require "./simpleidn/version"
require "./simpleidn/lib_icu"

module SimpleIDN
  class ConversionError < Exception; end
  class InitializationError < Exception; end

  extend self

  # Initialize global IDNA instances
  private def self.init_idna(transitional : Bool) : LibICU::UIDNA
    options = LibICU::UIDNA_USE_STD3_RULES |
              LibICU::UIDNA_CHECK_BIDI |
              LibICU::UIDNA_CHECK_CONTEXTJ |
              LibICU::UIDNA_CHECK_CONTEXTO

    if !transitional
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_ASCII
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_UNICODE
    end

    err = LibICU::UErrorCode::U_ZERO_ERROR
    idna = LibICU.uidna_openUTS46(options.to_u32, pointerof(err))

    if err != LibICU::UErrorCode::U_ZERO_ERROR
      raise InitializationError.new("ICU uidna_openUTS46 failed with error code #{err.value}")
    end

    idna
  end

  # Eagerly initialize instances for transitional (true) and non-transitional (false) modes
  @@idna_nontransitional : LibICU::UIDNA = init_idna(false)
  @@idna_transitional : LibICU::UIDNA = init_idna(true)

  # Cleanup on exit
  at_exit do
    LibICU.uidna_close(@@idna_nontransitional)
    LibICU.uidna_close(@@idna_transitional)
  end

  # Convert a domain to ASCII (Punycode).
  def to_ascii(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    idna = transitional ? @@idna_transitional : @@idna_nontransitional

    process_domain(domain, idna) do |label, current_idna, info, err|
      convert_label_to_ascii(label, current_idna, info, err)
    end
  end

  # Convert a domain to Unicode.
  def to_unicode(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    idna = transitional ? @@idna_transitional : @@idna_nontransitional

    process_domain(domain, idna) do |label, current_idna, info, err|
      convert_label_to_unicode(label, current_idna, info, err)
    end
  end

  private def process_domain(domain : String, idna : LibICU::UIDNA, &)
    # Split by dots, process each label, rejoin
    labels = domain.split('.')

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
