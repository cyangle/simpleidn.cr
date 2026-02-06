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

  # Base IDNA options (always applied)
  private BASE_UIDNA_OPTIONS = LibICU::UIDNA_CHECK_BIDI |
                               LibICU::UIDNA_CHECK_CONTEXTJ |
                               LibICU::UIDNA_CHECK_CONTEXTO

  # Validation profiles for different domain name types
  private struct Profile
    getter strict : Bool
    getter allow_trailing_dot : Bool
    getter require_trailing_dot : Bool
    getter max_length : Int32

    def initialize(@strict = true, @allow_trailing_dot = false, @require_trailing_dot = false, @max_length = MAX_HOSTNAME_LENGTH)
    end
  end

  # Pre-defined immutable profiles to avoid repeated allocations
  @@profile_hostname = Profile.new(strict: true, allow_trailing_dot: false)
  @@profile_permissive = Profile.new(strict: false, allow_trailing_dot: false)
  @@profile_dns = Profile.new(strict: false, allow_trailing_dot: true)
  @@profile_fqdn = Profile.new(strict: false, allow_trailing_dot: true, require_trailing_dot: true, max_length: 254)

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

    idna : LibICU::UIDNA = select_idna(transitional, strict)
    profile = strict ? @@profile_hostname : @@profile_permissive

    process_domain(domain, idna, to_ascii: true, profile: profile)
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

    idna : LibICU::UIDNA = select_idna(transitional, strict)
    profile = strict ? @@profile_hostname : @@profile_permissive

    process_domain(domain, idna, to_ascii: false, profile: profile)
  end

  # Specialized methods for Hostname (RFC 1123)
  def to_ascii_hostname(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: true)
    process_domain(domain, idna, to_ascii: true, profile: @@profile_hostname)
  end

  def to_unicode_hostname(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: true)
    process_domain(domain, idna, to_ascii: false, profile: @@profile_hostname)
  end

  # Specialized methods for DNS Name (Permissive, allows _, *)
  def to_ascii_dns(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: false)
    process_domain(domain, idna, to_ascii: true, profile: @@profile_dns)
  end

  def to_unicode_dns(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: false)
    process_domain(domain, idna, to_ascii: false, profile: @@profile_dns)
  end

  # Specialized methods for FQDN (DNS Name with trailing dot)
  def to_ascii_fqdn(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: false)
    process_domain(domain, idna, to_ascii: true, profile: @@profile_fqdn)
  end

  def to_unicode_fqdn(domain : String?, transitional : Bool = false) : String?
    return nil if domain.nil?
    idna : LibICU::UIDNA = select_idna(transitional, strict: false)
    process_domain(domain, idna, to_ascii: false, profile: @@profile_fqdn)
  end

  private def process_domain(domain : String, idna : LibICU::UIDNA, to_ascii : Bool, profile : Profile) : String?
    info : LibICU::UIDNAInfo = LibICU::UIDNAInfo.new
    info.size = sizeof(LibICU::UIDNAInfo).to_i16
    info.errors = 0
    err : LibICU::UErrorCode = LibICU::UErrorCode::U_ZERO_ERROR

    result : String? = if to_ascii
      convert_string_to_ascii(domain, idna, pointerof(info), pointerof(err), profile)
    else
      convert_string_to_unicode(domain, idna, pointerof(info), pointerof(err), profile)
    end

    return nil if result.nil?

    # Validate total length
    if to_ascii && result.bytesize > profile.max_length
      return nil
    end

    result
  end

  private def convert_string_to_ascii(string : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*, profile : Profile) : String?
    convert_string(info, err, "uidna_nameToASCII_UTF8", profile) do |dest_ptr, capacity|
      LibICU.uidna_nameToASCII_UTF8(idna, string.to_unsafe, string.bytesize, dest_ptr, capacity, info, err)
    end
  end

  private def convert_string_to_unicode(string : String, idna : LibICU::UIDNA, info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*, profile : Profile) : String?
    convert_string(info, err, "uidna_nameToUnicode_UTF8", profile) do |dest_ptr, capacity|
      LibICU.uidna_nameToUnicode_UTF8(idna, string.to_unsafe, string.bytesize, dest_ptr, capacity, info, err)
    end
  end

  private def convert_string(info : LibICU::UIDNAInfo*, err : LibICU::UErrorCode*, function_name : String, profile : Profile, &)
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

    # Check for IDNA validation error (including UIDNA_ERROR_EMPTY_LABEL)
    if info.value.errors > 0
      return nil
    end

    res = String.new(dest[0, len])

    # Handle trailing dot based on profile
    if res.ends_with?('.')
      return nil unless profile.allow_trailing_dot
    elsif profile.require_trailing_dot
      res = res + "."
    end

    res
  end

  # Validates a hostname according to strict rules (e.g., JSON Schema).
  #
  # Rejects:
  # - Empty strings
  # - Leading dots (e.g. ".example.com")
  # - Trailing dots (e.g. "example.com.")
  # - Consecutive dots (e.g. "example..com")
  #
  # Parameters:
  # - `hostname`: The hostname to validate
  # - `transitional`: Use transitional processing (IDNA2003)
  #
  def valid_hostname?(hostname : String?, transitional : Bool = false) : Bool
    to_ascii_hostname(hostname, transitional: transitional) != nil
  end

  def valid_dns_name?(domain : String?, transitional : Bool = false) : Bool
    to_ascii_dns(domain, transitional: transitional) != nil
  end

  def valid_fqdn?(domain : String?, transitional : Bool = false) : Bool
    to_ascii_fqdn(domain, transitional: transitional) != nil
  end
end
