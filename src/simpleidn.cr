require "./simpleidn/version"
require "./simpleidn/lib_icu"

module SimpleIDN
  class ConversionError < Exception; end

  class InitializationError < Exception; end

  # Constants
  private INITIAL_BUFFER_CAPACITY = 256

  # RFC 1035/5890: Maximum hostname/domain name length in bytes (ASCII octets)
  # This is the presentation format limit (without trailing dot)
  MAX_HOSTNAME_LENGTH = 253

  # RFC 1035: Maximum label length in bytes (ASCII octets)
  MAX_LABEL_LENGTH = 63

  # Base IDNA options (always applied)
  private BASE_UIDNA_OPTIONS = LibICU::UIDNA_CHECK_BIDI |
                               LibICU::UIDNA_CHECK_CONTEXTJ |
                               LibICU::UIDNA_CHECK_CONTEXTO

  extend self

  # IDNA instance configuration
  # We need 4 instances to cover all combinations:
  # - strict (with STD3) vs non-strict (without STD3)
  # - transitional vs non-transitional

  private def self.init_idna(transitional : Bool, strict : Bool) : LibICU::UIDNA
    options : Int32 = BASE_UIDNA_OPTIONS

    # STD3 rules enforce hostname character restrictions (LDH rule)
    # When strict=true, characters like _, *, @ are rejected
    if strict
      options |= LibICU::UIDNA_USE_STD3_RULES
    end

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

  # Eagerly initialize all 4 IDNA instances
  # Naming: @@idna_{strict|permissive}_{nontransitional|transitional}
  @@idna_strict_nontransitional : LibICU::UIDNA = init_idna(transitional: false, strict: true)
  @@idna_strict_transitional : LibICU::UIDNA = init_idna(transitional: true, strict: true)
  @@idna_permissive_nontransitional : LibICU::UIDNA = init_idna(transitional: false, strict: false)
  @@idna_permissive_transitional : LibICU::UIDNA = init_idna(transitional: true, strict: false)

  # Cleanup on exit
  at_exit do
    LibICU.uidna_close(@@idna_strict_nontransitional)
    LibICU.uidna_close(@@idna_strict_transitional)
    LibICU.uidna_close(@@idna_permissive_nontransitional)
    LibICU.uidna_close(@@idna_permissive_transitional)
  end

  # Select the appropriate IDNA instance based on options
  private def select_idna(transitional : Bool, strict : Bool) : LibICU::UIDNA
    if strict
      transitional ? @@idna_strict_transitional : @@idna_strict_nontransitional
    else
      transitional ? @@idna_permissive_transitional : @@idna_permissive_nontransitional
    end
  end

  # Convert a domain to ASCII (Punycode).
  #
  # Parameters:
  # - `domain`: The domain name to convert (can be nil)
  # - `transitional`: If true, use transitional processing (IDNA2003 compatibility, e.g., ß -> ss)
  # - `strict`: If true (default), enforce RFC 1123 hostname rules (LDH characters only).
  #   When strict=true, labels containing `_`, `*`, `@`, or other non-LDH characters are rejected.
  #   When strict=false, these characters are allowed (for DNS records like SRV, DMARC, wildcards).
  #
  # Returns:
  # - ASCII domain name, or `nil` if domain is `nil` or invalid
  #
  # Raises:
  # - `SimpleIDN::ConversionError` if an ICU system error occurs
  def to_ascii(domain : String?, transitional : Bool = false, strict : Bool = true) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    idna : LibICU::UIDNA = select_idna(transitional, strict)

    process_domain(domain, idna, to_ascii: true)
  end

  # Convert a domain to Unicode.
  #
  # Parameters:
  # - `domain`: The domain name to convert (can be nil)
  # - `transitional`: If true, use transitional processing
  # - `strict`: If true (default), enforce RFC 1123 hostname rules (LDH characters only).
  #   When strict=true, labels containing `_`, `*`, `@`, or other non-LDH characters are rejected.
  #   When strict=false, these characters are allowed (for DNS records like SRV, DMARC, wildcards).
  #
  # Returns:
  # - Unicode domain name, or `nil` if domain is `nil` or invalid
  #
  # Raises:
  # - `SimpleIDN::ConversionError` if an ICU system error occurs
  def to_unicode(domain : String?, transitional : Bool = false, strict : Bool = true) : String?
    return nil if domain.nil?
    return domain if domain.empty?

    idna : LibICU::UIDNA = select_idna(transitional, strict)

    process_domain(domain, idna, to_ascii: false)
  end

  private def process_domain(domain : String, idna : LibICU::UIDNA, to_ascii : Bool) : String?
    # Split by dots, process each label, rejoin
    labels : Array(String) = domain.split('.')

    info : LibICU::UIDNAInfo = LibICU::UIDNAInfo.new
    info.size = sizeof(LibICU::UIDNAInfo).to_i16

    results : Array(String) = labels.map do |label|
      # Empty labels are passed through (handles trailing dots, consecutive dots)
      if label.empty?
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

    final_result : String = results.join(".")

    # Validate total hostname length for ASCII conversion
    # RFC 1035: hostname must not exceed 253 ASCII characters (presentation format)
    if to_ascii && final_result.bytesize > MAX_HOSTNAME_LENGTH
      return nil
    end

    final_result
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

  # Validates a hostname according to strict rules (e.g., JSON Schema).
  #
  # Unlike `to_ascii`, this method rejects:
  # - Empty strings
  # - Leading dots (e.g. ".example.com")
  # - Trailing dots (e.g. "example.com.") - unless allow_trailing_dot: true
  # - Consecutive dots (e.g. "example..com")
  #
  # Parameters:
  # - `hostname`: The hostname to validate
  # - `transitional`: Use transitional processing (IDNA2003)
  # - `strict`: Enforce RFC 1123 rules (no _, *, @)
  # - `allow_trailing_dot`: Allow a single trailing dot (DNS root)
  #
  def valid_hostname?(hostname : String?, transitional : Bool = false, strict : Bool = true, allow_trailing_dot : Bool = false) : Bool
    return false if hostname.nil? || hostname.empty?

    return false unless valid_domain_structure?(hostname, allow_trailing_dot)

    # Perform IDNA conversion/validation
    # strict=true enforces RFC 1123 (no *, _, @)
    ascii = to_ascii(hostname, transitional: transitional, strict: strict)
    return false if ascii.nil?

    # Check resulting ASCII string for remaining validity issues
    # to_ascii preserves dots, so we need to ensure the result is clean
    # (though basic dot checks above catch most structural issues)

    # Check for leading/trailing/consecutive dots in the ASCII result
    # This catches cases where Unicode dots (e.g. 。) were normalized to ASCII dots
    valid_domain_structure?(ascii, allow_trailing_dot)
  end

  private def valid_domain_structure?(domain : String, allow_trailing_dot : Bool) : Bool
    # Check for leading dots
    return false if domain.starts_with?('.')

    # Check for consecutive dots
    return false if domain.includes?("..")

    # Check for trailing dot
    if domain.ends_with?('.')
      return false unless allow_trailing_dot
      return false if domain == "." # Single dot is not a valid hostname
    end

    true
  end
end
