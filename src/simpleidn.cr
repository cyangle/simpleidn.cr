require "./simpleidn/version"
require "./simpleidn/lib_icu"

module SimpleIDN
  class ConversionError < Exception; end

  class InitializationError < Exception; end

  # Constants
  private INITIAL_BUFFER_CAPACITY = 256

  private DEFAULT_UIDNA_OPTIONS = LibICU::UIDNA_USE_STD3_RULES |
                                  LibICU::UIDNA_CHECK_BIDI |
                                  LibICU::UIDNA_CHECK_CONTEXTJ |
                                  LibICU::UIDNA_CHECK_CONTEXTO

  extend self

  # Initialize global IDNA instances
  private def self.init_idna(transitional : Bool) : LibICU::UIDNA
    options : Int32 = DEFAULT_UIDNA_OPTIONS

    if !transitional
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_ASCII
      options |= LibICU::UIDNA_NONTRANSITIONAL_TO_UNICODE
    end

    err : LibICU::UErrorCode = LibICU::UErrorCode::U_ZERO_ERROR
    idna : LibICU::UIDNA = LibICU.uidna_openUTS46(options.to_u32, pointerof(err))

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

    idna : LibICU::UIDNA = transitional ? @@idna_transitional : @@idna_nontransitional

    process_domain(domain, idna, to_ascii: true)
  end

  # Convert a domain to Unicode.
  def to_unicode(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    idna : LibICU::UIDNA = transitional ? @@idna_transitional : @@idna_nontransitional

    process_domain(domain, idna, to_ascii: false)
  end

  private def process_domain(domain : String, idna : LibICU::UIDNA, to_ascii : Bool) : String?
    # Split by dots, process each label, rejoin
    labels : Array(String) = domain.split('.')

    info : LibICU::UIDNAInfo = LibICU::UIDNAInfo.new
    info.size = sizeof(LibICU::UIDNAInfo).to_i16

    results : Array(String) = labels.map do |label|
      # Pass through special labels that start with _ or are special chars like *, @
      if should_pass_through?(label)
        label
      else
        info.errors = 0
        err : LibICU::UErrorCode = LibICU::UErrorCode::U_ZERO_ERROR

        result : String? = if to_ascii
          convert_label_to_ascii(label, idna, pointerof(info), pointerof(err))
        else
          convert_label_to_unicode(label, idna, pointerof(info), pointerof(err))
        end

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

  private def convert_label_to_ascii(label : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*) : String?
    convert_label(info, err, "uidna_nameToASCII_UTF8") do |dest_ptr, capacity|
      LibICU.uidna_nameToASCII_UTF8(idna, label.to_unsafe, label.bytesize, dest_ptr, capacity, info, err)
    end
  end

  private def convert_label_to_unicode(label : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*) : String?
    convert_label(info, err, "uidna_nameToUnicode_UTF8") do |dest_ptr, capacity|
      LibICU.uidna_nameToUnicode_UTF8(idna, label.to_unsafe, label.bytesize, dest_ptr, capacity, info, err)
    end
  end

  private def convert_label(info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*, function_name : String, &)
    capacity : Int32 = INITIAL_BUFFER_CAPACITY
    dest : Slice(UInt8) = Slice(UInt8).new(capacity)

    len : Int32 = yield(dest.to_unsafe, capacity)

    # Check for buffer overflow
    if (err.value.value == 15) || (len > capacity)
      err.value = LibICU::UErrorCode::U_ZERO_ERROR
      info.value.errors = 0
      capacity = len + 1
      dest = Slice(UInt8).new(capacity)
      len = yield(dest.to_unsafe, capacity)
    end

    # Check for ICU system error (not IDNA validation error)
    if err.value.value > 0
      raise ConversionError.new("ICU #{function_name} failed with error code #{err.value.value}")
    end

    # Check for IDNA validation error
    if info.value.errors > 0
      return nil
    end

    String.new(dest[0, len])
  end
end
