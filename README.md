# simpleidn.cr

> [!CAUTION]
> **Experimental Implementation:** This project is almost 100% vibe-coded.
> While it passes an extensive suite of unit and third-party integration tests,
> the internal logic may not follow traditional patterns. Use at your own risk.

This is a Crystal port of the Ruby library [simpleidn](https://github.com/mmriis/simpleidn).

It provides easy conversion from punycode ACE strings to unicode strings and vice versa using IDNA2008 (UTS #46) conformant processing.

> [!IMPORTANT]
> **Breaking Change in v0.6.0:** The `strict` parameter was added with a default value of `true`.
> This enforces RFC 1123 hostname validation, which **rejects** wildcards (`*`), underscores (`_`), and at-symbols (`@`).
> See [Strict Mode](#strict-mode-hostname-vs-dns-record-validation) and [Migration Guide](#migrating-from-v05x) for details.

## Requirements

This library requires **ICU** (International Components for Unicode) to be installed on your system.

### Installing ICU

**Ubuntu/Debian:**
```bash
sudo apt-get install libicu-dev
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install libicu-devel
```

**Arch Linux:**
```bash
sudo pacman -S icu
```

**macOS (Homebrew):**
```bash
brew install icu4c
# You may need to set PKG_CONFIG_PATH:
export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c/lib/pkgconfig:$PKG_CONFIG_PATH"
```

**Alpine Linux:**
```bash
apk add icu-dev
```

### Verifying ICU Installation

```bash
pkg-config --modversion icu-uc
# Should output version like: 74.2
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     simpleidn:
       github: cyangle/simpleidn.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "simpleidn"

# Convert to ASCII (Punycode)
SimpleIDN.to_ascii("møllerriis.com")
# => "xn--mllerriis-l8a.com"

# Convert to Unicode
SimpleIDN.to_unicode("xn--mllerriis-l8a.com")
# => "møllerriis.com"

# Handle mapped characters (UTS #46)
SimpleIDN.to_ascii("Faß.de")
# => "xn--fa-hia.de" (preserves ß in IDNA2008 nontransitional mode)

SimpleIDN.to_unicode("xn--fa-hia.de")
# => "faß.de"

# Transitional processing (IDNA2003 compatibility)
SimpleIDN.to_ascii("faß.de", transitional: true)
# => "fass.de" (ß maps to ss in transitional mode)
```

### Additional Examples

```crystal
# International domain names
SimpleIDN.to_ascii("日本語.jp")          # => "xn--wgv71a119e.jp"
SimpleIDN.to_ascii("россия.рф")          # => "xn--h1alffa9f.xn--p1ai"
SimpleIDN.to_ascii("münchen.de")         # => "xn--mnchen-3ya.de"
SimpleIDN.to_ascii("ελληνικά.gr")        # => "xn--hxargifdar.gr"

# Unicode normalization is handled automatically
SimpleIDN.to_ascii("café.com")           # => "xn--caf-dma.com"
SimpleIDN.to_ascii("cafe\u0301.com")     # => "xn--caf-dma.com" (same result)

# Invalid hostnames return nil (RFC 1123 validation)
SimpleIDN.to_ascii("-invalid.com")       # => nil (starts with hyphen)
SimpleIDN.to_ascii("invalid-.com")       # => nil (ends with hyphen)
SimpleIDN.to_ascii("*.example.com")      # => nil (wildcard not allowed in strict mode)
SimpleIDN.to_ascii("_dmarc.example.com") # => nil (underscore not allowed in strict mode)
SimpleIDN.to_unicode("xn---")            # => nil (invalid punycode)

# For DNS records (wildcards, SRV, DMARC), use strict: false
SimpleIDN.to_ascii("*.example.com", strict: false)      # => "*.example.com"
SimpleIDN.to_ascii("_dmarc.example.com", strict: false) # => "_dmarc.example.com"
```

## Strict Mode (Hostname vs DNS Record Validation)

The `strict` parameter controls whether RFC 1123 hostname rules are enforced:

| Mode | Characters `*`, `_`, `@` | Use Case |
|------|--------------------------|----------|
| `strict: true` (default) | **Rejected** | RFC 1123 hostname validation (JSON Schema, web forms) |
| `strict: false` | **Allowed** | DNS records (SRV, DMARC, DKIM, wildcards) |

### Why Two Modes?

**Hostnames** (RFC 1123) and **DNS domain names** (RFC 1035) have different character rules:

- **Hostnames** must follow the LDH rule (Letters, Digits, Hyphens only)
- **DNS records** can contain underscores (`_dmarc`, `_tcp`), wildcards (`*`), and other characters

This library defaults to strict hostname validation to comply with [JSON Schema draft 2020-12](https://json-schema.org/draft/2020-12/json-schema-validation#section-7.3.3) `hostname` and `idn-hostname` format requirements.

### Strict Mode Examples

```crystal
# Default: strict=true (RFC 1123 hostname validation)
SimpleIDN.to_ascii("example.com")        # => "example.com" (valid)
SimpleIDN.to_ascii("my-host.com")        # => "my-host.com" (valid)
SimpleIDN.to_ascii("münchen.de")         # => "xn--mnchen-3ya.de" (valid IDN)
SimpleIDN.to_ascii("*.example.com")      # => nil (rejected: wildcard)
SimpleIDN.to_ascii("_dmarc.example.com") # => nil (rejected: underscore)
SimpleIDN.to_ascii("@")                  # => nil (rejected: at-symbol)

# Non-strict: strict=false (permissive DNS mode)
SimpleIDN.to_ascii("*.example.com", strict: false)      # => "*.example.com"
SimpleIDN.to_ascii("_dmarc.example.com", strict: false) # => "_dmarc.example.com"
SimpleIDN.to_ascii("_sip._tcp.example.com", strict: false) # => "_sip._tcp.example.com"
SimpleIDN.to_ascii("@", strict: false)                  # => "@"

# Mix IDN with DNS labels (non-strict mode)
SimpleIDN.to_ascii("_dmarc.münchen.de", strict: false)
# => "_dmarc.xn--mnchen-3ya.de"

SimpleIDN.to_unicode("_dmarc.xn--mnchen-3ya.de", strict: false)
# => "_dmarc.münchen.de"
```

### Combining Parameters

Both `strict` and `transitional` parameters can be combined:

```crystal
# All four combinations are supported:
SimpleIDN.to_ascii("faß.de")                                    # strict=true, transitional=false
SimpleIDN.to_ascii("faß.de", transitional: true)                # strict=true, transitional=true
SimpleIDN.to_ascii("*.faß.de", strict: false)                   # strict=false, transitional=false
SimpleIDN.to_ascii("*.faß.de", transitional: true, strict: false) # strict=false, transitional=true
```

## Hostname Length Limits

The library enforces RFC 1035 length limits:

| Limit | Value | Constant |
|-------|-------|----------|
| Maximum label length | 63 bytes | `SimpleIDN::MAX_LABEL_LENGTH` |
| Maximum hostname length | 253 bytes | `SimpleIDN::MAX_HOSTNAME_LENGTH` |

```crystal
# Labels exceeding 63 bytes are rejected
SimpleIDN.to_ascii("a" * 64)  # => nil

# Hostnames exceeding 253 bytes are rejected
long_hostname = "a" * 63 + "." + "b" * 63 + "." + "c" * 63 + "." + "d" * 62  # 254 bytes
SimpleIDN.to_ascii(long_hostname)  # => nil

# Access constants
SimpleIDN::MAX_LABEL_LENGTH    # => 63
SimpleIDN::MAX_HOSTNAME_LENGTH # => 253
```

## Performance & Lifecycle

This library is optimized for high-performance applications:

- **Global Instances**: ICU IDNA instances (`UIDNA`) are initialized once when the module is loaded and reused throughout the application's lifecycle. Four instances are created to cover all combinations of `strict` and `transitional` modes.
- **Thread Safety**: The reused `UIDNA` instances are immutable and thread-safe, making this library safe for concurrent use in multi-threaded Crystal applications.
- **Fail-Fast Initialization**: If the ICU library cannot be initialized (e.g., system error), the application will raise `SimpleIDN::InitializationError` immediately upon startup, preventing runtime failures later.
- **Automatic Cleanup**: An `at_exit` handler ensures that ICU resources are properly released when the application shuts down.

> [!WARNING]
> **Testing Caveat:** When writing specs, ensure that `require "simpleidn"` happens **before** `require "spec"`.
> This is critical because `at_exit` handlers run in reverse order of registration. If `spec` is required first, the IDNA instances might be closed by the cleanup handler *before* the tests finish running, causing segmentation faults.
>
> **Correct `spec_helper.cr`:**
> ```crystal
> require "../src/simpleidn" # Must be first!
> require "spec"
> ```

## Features

- **IDNA2008 Conformant**: Uses ICU's UTS #46 implementation with nontransitional processing by default
- **JSON Schema 2020-12 Compatible**: Default strict mode validates hostnames per RFC 1123 (`hostname` format) and RFC 5890 (`idn-hostname` format)
- **Full Unicode Support**: Handles all scripts including CJK, Arabic, Hebrew, Cyrillic, Greek, Thai, etc.
- **Unicode Normalization**: Automatically normalizes combining characters (NFC)
- **STD3 Rules**: Enforces standard hostname rules in strict mode (no spaces, control characters, underscores, etc.)
- **BiDi Support**: Correctly handles bidirectional text (Arabic, Hebrew)
- **CONTEXTJ/CONTEXTO**: Validates context-dependent characters (ZWNJ, ZWJ)
- **Transitional Mode**: Optional IDNA2003-compatible transitional processing
- **DNS Record Support**: Non-strict mode allows wildcards, underscores, and other DNS-specific labels

## API Reference

### `SimpleIDN.to_ascii(domain, transitional, strict) : String?`

```crystal
def to_ascii(domain : String?, transitional : Bool = false, strict : Bool = true) : String?
```

Converts an internationalized domain name to ASCII (Punycode) form.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `domain` | `String?` | - | The domain name to convert (can be nil) |
| `transitional` | `Bool` | `false` | Use transitional processing (IDNA2003 compatibility) |
| `strict` | `Bool` | `true` | Enforce RFC 1123 hostname rules (reject `*`, `_`, `@`) |

**Returns:** ASCII domain name, or `nil` if domain is `nil` or invalid

**Raises:** `SimpleIDN::ConversionError` if an ICU system error occurs

### `SimpleIDN.to_unicode(domain, transitional, strict) : String?`

```crystal
def to_unicode(domain : String?, transitional : Bool = false, strict : Bool = true) : String?
```

Converts an ASCII (Punycode) domain name to Unicode form.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `domain` | `String?` | - | The domain name to convert (can be nil) |
| `transitional` | `Bool` | `false` | Use transitional processing |
| `strict` | `Bool` | `true` | Enforce RFC 1123 hostname rules (reject `*`, `_`, `@`) |

**Returns:** Unicode domain name, or `nil` if domain is `nil` or invalid

**Raises:** `SimpleIDN::ConversionError` if an ICU system error occurs

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SimpleIDN::MAX_LABEL_LENGTH` | `63` | Maximum bytes per label (RFC 1035) |
| `SimpleIDN::MAX_HOSTNAME_LENGTH` | `253` | Maximum bytes for hostname (RFC 1035) |

### Error Handling

The library distinguishes between two types of errors:

| Error Type | Behavior | Example |
|------------|----------|---------|
| **Invalid domain** | Returns `nil` | `"-invalid.com"`, `"xn---"`, `"*.example.com"` (strict mode) |
| **ICU system error** | Raises `ConversionError` | Memory allocation failure, malformed input |

```crystal
# Invalid domains return nil
result = SimpleIDN.to_ascii("-invalid.com")
if result.nil?
  puts "Domain is invalid"
end

# System errors raise exceptions (rare)
begin
  SimpleIDN.to_ascii(domain)
rescue SimpleIDN::ConversionError => e
  puts "ICU error: #{e.message}"
end
```

## Migrating from v0.5.x

### Breaking Change: `strict` Parameter

In v0.6.0, the `strict` parameter was added with a default value of `true`. This means:

| v0.5.x Behavior | v0.6.0 Behavior (strict=true) |
|-----------------|-------------------------------|
| `"*.example.com"` → `"*.example.com"` | `"*.example.com"` → `nil` |
| `"_dmarc.example.com"` → `"_dmarc.example.com"` | `"_dmarc.example.com"` → `nil` |
| `"@"` → `"@"` | `"@"` → `nil` |

### How to Restore Previous Behavior

If your application relies on the old behavior (passing through wildcards, underscores, etc.), add `strict: false`:

```crystal
# Before (v0.5.x)
SimpleIDN.to_ascii("*.example.com")
SimpleIDN.to_ascii("_dmarc.example.com")

# After (v0.6.0) - to restore previous behavior
SimpleIDN.to_ascii("*.example.com", strict: false)
SimpleIDN.to_ascii("_dmarc.example.com", strict: false)
```

### Recommended Migration Strategy

1. **For hostname validation** (web forms, JSON Schema): Use the new default (`strict: true`)
2. **For DNS record handling** (zone files, DNS APIs): Explicitly use `strict: false`

## IDNA2008 vs IDNA2003

This library defaults to **IDNA2008 nontransitional** processing:

| Character | IDNA2003 (transitional) | IDNA2008 (nontransitional) |
|-----------|------------------------|---------------------------|
| ß (German Eszett) | Maps to "ss" | Preserved as ß |
| ς (Greek final sigma) | Maps to σ | Preserved as ς |
| ZWJ/ZWNJ | Generally removed | Context-validated |

Use `transitional: true` for IDNA2003-compatible behavior when needed.

## Development

To run tests:
```bash
crystal spec
```

To format the code:
```bash
crystal tool format
```

## Contributing

1. Fork it (<https://github.com/cyangle/simpleidn.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Chao Yang](https://github.com/cyangle) - creator and maintainer
