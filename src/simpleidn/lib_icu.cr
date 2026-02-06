# ICU library bindings for IDNA support
#
# ICU uses versioned symbol names (e.g., uidna_openUTS46_74 for ICU 74.x).
# This file uses Crystal compile-time macros to automatically detect the
# installed ICU version and generate the correct symbol names.
#
# The version is detected via pkg-config at compile time.

{% begin %}
  # Get ICU major version at compile time using pkg-config
  {% icu_version = `pkg-config --modversion icu-uc 2>/dev/null || echo "0"`.strip.split(".")[0] %}

  # Fallback: try to parse from header if pkg-config fails
  {% if icu_version == "0" || icu_version == "" %}
    {% icu_version = `grep -oP 'U_ICU_VERSION_SUFFIX _\\K[0-9]+' /usr/include/unicode/uvernum.h 2>/dev/null || echo "74"`.strip %}
  {% end %}

  @[Link("icuuc")]
  @[Link("icui18n")]
  @[Link("icudata")]
  lib LibICU
    # Detected ICU version: {{ icu_version }}

    # Error codes
    enum UErrorCode
      U_ZERO_ERROR = 0
      # U_FAILURE(x) is x > 0
    end

    # UBool is int8_t
    alias UBool = Int8

    # Options for uidna_openUTS46
    # See /usr/include/unicode/uidna.h for documentation
    UIDNA_DEFAULT                    = 0
    UIDNA_USE_STD3_RULES             = 2
    UIDNA_CHECK_BIDI                 = 4
    UIDNA_CHECK_CONTEXTJ             = 8
    UIDNA_NONTRANSITIONAL_TO_ASCII   = 0x10
    UIDNA_NONTRANSITIONAL_TO_UNICODE = 0x20
    UIDNA_CHECK_CONTEXTO             = 0x40

    # Opaque UIDNA struct
    type UIDNA = Void*

    # UIDNAInfo structure - must match /usr/include/unicode/uidna.h
    struct UIDNAInfo
      size : Int16
      is_transitional_different : UBool
      reserved_b3 : UBool
      errors : UInt32
      reserved_i2 : Int32
      reserved_i3 : Int32
    end

    # UIDNAInfo errors (bitmask)
    UIDNA_ERROR_EMPTY_LABEL            =      1
    UIDNA_ERROR_LABEL_TOO_LONG         =      2
    UIDNA_ERROR_DOMAIN_NAME_TOO_LONG   =      4
    UIDNA_ERROR_LEADING_HYPHEN         =      8
    UIDNA_ERROR_TRAILING_HYPHEN        =   0x10
    UIDNA_ERROR_HYPHEN_3_4             =   0x20
    UIDNA_ERROR_LEADING_COMBINING_MARK =   0x40
    UIDNA_ERROR_DISALLOWED             =   0x80
    UIDNA_ERROR_PUNYCODE               =  0x100
    UIDNA_ERROR_LABEL_HAS_DOT          =  0x200
    UIDNA_ERROR_INVALID_ACE_LABEL      =  0x400
    UIDNA_ERROR_BIDI                   =  0x800
    UIDNA_ERROR_CONTEXTJ               = 0x1000
    UIDNA_ERROR_CONTEXTO_PUNCTUATION   = 0x2000
    UIDNA_ERROR_CONTEXTO_DIGITS        = 0x4000

    # ICU IDNA functions with dynamically versioned symbols
    # Symbol names are generated at compile time based on detected ICU version

    fun uidna_openUTS46 = uidna_openUTS46_{{ icu_version.id }}(
      options : UInt32,
      pErrorCode : UErrorCode*
    ) : UIDNA

    fun uidna_close = uidna_close_{{ icu_version.id }}(idna : UIDNA) : Void

    fun uidna_nameToASCII_UTF8 = uidna_nameToASCII_UTF8_{{ icu_version.id }}(
      idna : UIDNA,
      name : UInt8*,
      length : Int32,
      dest : UInt8*,
      capacity : Int32,
      pInfo : UIDNAInfo*,
      pErrorCode : UErrorCode*
    ) : Int32

    fun uidna_nameToUnicode_UTF8 = uidna_nameToUnicodeUTF8_{{ icu_version.id }}(
      idna : UIDNA,
      name : UInt8*,
      length : Int32,
      dest : UInt8*,
      capacity : Int32,
      pInfo : UIDNAInfo*,
      pErrorCode : UErrorCode*
    ) : Int32
  end
{% end %}
