# simpleidn.cr

> [!CAUTION]
> **Experimental Implementation:** This project is almost 100% vibe-coded.
> While it passes an extensive suite of unit and third-party integration tests,
> the internal logic may not follow traditional patterns. Use at your own risk.

This is a Crystal port of the Ruby library [simpleidn](https://github.com/mmriis/simpleidn).

It provides easy conversion from punycode ACE strings to unicode strings and vice versa using IDNA2008 (UTS #46) conformant processing.

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

# Wildcards and special DNS labels are preserved
SimpleIDN.to_ascii("*.example.com")      # => "*.example.com"
SimpleIDN.to_ascii("_dmarc.example.com") # => "_dmarc.example.com"

# Unicode normalization is handled automatically
SimpleIDN.to_ascii("café.com")           # => "xn--caf-dma.com"
SimpleIDN.to_ascii("cafe\u0301.com")     # => "xn--caf-dma.com" (same result)

# Invalid domains return nil
SimpleIDN.to_ascii("-invalid.com")       # => nil (starts with hyphen)
SimpleIDN.to_unicode("xn---")            # => nil (invalid punycode)
```

## Performance & Lifecycle

This library is optimized for high-performance applications:

- **Global Instances**: ICU IDNA instances (`UIDNA`) are initialized once when the module is loaded and reused throughout the application's lifecycle.
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
- **Full Unicode Support**: Handles all scripts including CJK, Arabic, Hebrew, Cyrillic, Greek, Thai, etc.
- **Unicode Normalization**: Automatically normalizes combining characters (NFC)
- **STD3 Rules**: Enforces standard hostname rules (no spaces, control characters, etc.)
- **BiDi Support**: Correctly handles bidirectional text (Arabic, Hebrew)
- **CONTEXTJ/CONTEXTO**: Validates context-dependent characters (ZWNJ, ZWJ)
- **Transitional Mode**: Optional IDNA2003-compatible transitional processing

## API Reference

### `SimpleIDN.to_ascii(domain : String?, transitional : Bool = false) : String?`

Converts an internationalized domain name to ASCII (Punycode) form.

- **domain**: The domain name to convert (can be nil)
- **transitional**: If true, use transitional processing (IDNA2003 compatibility)
- **Returns**: ASCII domain name, or `nil` if domain is `nil` or invalid per IDNA2008 rules
- **Raises**: `SimpleIDN::ConversionError` if an ICU system error occurs

### `SimpleIDN.to_unicode(domain : String?, transitional : Bool = false) : String?`

Converts an ASCII (Punycode) domain name to Unicode form.

- **domain**: The domain name to convert (can be nil)
- **transitional**: If true, use transitional processing
- **Returns**: Unicode domain name, or `nil` if domain is `nil` or invalid per IDNA2008 rules
- **Raises**: `SimpleIDN::ConversionError` if an ICU system error occurs

### Error Handling

The library distinguishes between two types of errors:

| Error Type | Behavior | Example |
|------------|----------|---------|
| **Invalid domain** | Returns `nil` | `"-invalid.com"`, `"xn---"` |
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
