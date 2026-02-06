# simpleidn.cr

> [!CAUTION]
> **Experimental Implementation:** This project is almost 100% vibe-coded.
> While it passes an extensive suite of unit and third-party integration tests,
> the internal logic may not follow traditional patterns. Use at your own risk.

This is a Crystal port of the Ruby library [simpleidn](https://github.com/mmriis/simpleidn).
It provides easy conversion from punycode ACE strings to unicode strings and vice versa using IDNA2008 (UTS #46) conformant processing.

> [!TIP]
> **New in v0.8.0:** This release introduces specialized methods (`*_hostname`, `*_dns`, `*_fqdn`) to handle the nuances of strict hostnames vs. DNS records. The generic `to_ascii` methods are now deprecated to encourage explicit intent.

## Features

- **IDNA2008 Conformant**: Uses ICU's UTS #46 implementation (nontransitional by default).
- **Type-Safe API**: Specialized methods for Hostnames, DNS records, and FQDNs.
- **JSON Schema Compatible**: Validates `hostname` and `idn-hostname` formats (RFC 1123/5890).
- **Full Unicode Support**: CJK, Emoji, BiDi (Arabic/Hebrew), ContextJ/ContextO rules.
- **High Performance**: Reuses global, thread-safe ICU instances.

## Installation

1.  Add to `shard.yml`:
    ```yaml
    dependencies:
      simpleidn:
        github: cyangle/simpleidn.cr
    ```
2.  Run `shards install`

## Requirements

Requires **ICU** (International Components for Unicode) installed on your system.

*   **Ubuntu/Debian:** `sudo apt-get install libicu-dev`
*   **Fedora/RHEL:** `sudo dnf install libicu-devel`
*   **macOS:** `brew install icu4c`
*   **Alpine:** `apk add icu-dev`

Verify with: `pkg-config --modversion icu-uc`

## Usage

```crystal
require "simpleidn"
```

### 1. Standard Hostnames (Strict)
Use for URLs, email domains, and user input. Enforces RFC 1123 rules (Letters, Digits, Hyphens). Rejects wildcards, underscores, and trailing dots.

```crystal
SimpleIDN.to_ascii_hostname("münchen.de")      # => "xn--mnchen-3ya.de"
SimpleIDN.to_unicode_hostname("xn--mnchen-3ya.de") # => "münchen.de"

# Validation
SimpleIDN.valid_hostname?("münchen.de")       # => true
SimpleIDN.valid_hostname?("*.example.com")    # => false (Wildcard rejected)
```

### 2. DNS Records (Permissive)
Use for DNS management (SRV, DMARC, TXT records). Allows wildcards (`*`), underscores (`_`), and trailing dots.

```crystal
SimpleIDN.to_ascii_dns("_sip._tcp.example.com") # => "_sip._tcp.example.com"
SimpleIDN.to_ascii_dns("*.example.com")         # => "*.example.com"

# Validation
SimpleIDN.valid_dns_name?("_dmarc.example.com") # => true
```

### 3. Fully Qualified Domain Names (FQDN)
Ensures the domain ends with a trailing dot (`.`). Useful for absolute DNS resolution.

```crystal
SimpleIDN.to_ascii_fqdn("example.com")      # => "example.com."
SimpleIDN.to_ascii_fqdn("example.com.")     # => "example.com."

# Validation
SimpleIDN.valid_fqdn?("example.com.")       # => true
SimpleIDN.valid_fqdn?("example.com")        # => false (Missing dot)
```

## API Reference

### Comparison Table

| Method Suffix | Strictness | Allowed Chars | Trailing Dot | Max Length | Use Case |
|---|---|---|---|---|---|
| `_hostname` | Strict | LDH (a-z, 0-9, -) | **Rejected** | 253 | URLs, Emails |
| `_dns` | Permissive | LDH + `_`, `*`, `@` | Allowed | 253 | DNS Records |
| `_fqdn` | Permissive | LDH + `_`, `*`, `@` | **Required** | 254 | Absolute DNS |

### Validation Predicates
*   `valid_hostname?(domain)`
*   `valid_dns_name?(domain)`
*   `valid_fqdn?(domain)`

### Legacy Methods (Deprecated)
*   `SimpleIDN.to_ascii(domain, transitional, strict)`
*   `SimpleIDN.to_unicode(domain, transitional, strict)`

*Use the specialized methods above instead.*

## Core Concepts

### IDNA2008 vs IDNA2003
Defaults to **Nontransitional** (IDNA2008).
*   **Nontransitional**: `ß` -> `ß`, `ς` -> `ς` (Default)
*   **Transitional**: `ß` -> `ss`, `ς` -> `σ` (Pass `transitional: true`)

### Strict Mode & JSON Schema
For [JSON Schema](https://json-schema.org/understanding-json-schema/reference/string.html#resource-identifiers) compliance:
*   **`idn-hostname`**: Use `SimpleIDN.valid_hostname?(str)`
*   **`hostname`**: Use `SimpleIDN.valid_hostname?(str)` **and** `str.ascii_only?`.

## Performance & Lifecycle

*   **Global, Thread-Safe**: Uses global, immutable `UIDNA` instances. Safe for high-concurrency use.
*   **Memory**: ~3.2 MB overhead (ICU data tables). Zero per-request allocation cost beyond string result.
*   **Safety**: Uses `at_exit` to clean up ICU resources.

> [!WARNING]
> **Testing Caveat:** When running specs, `require "simpleidn"` **before** `require "spec"` to prevent premature cleanup segfaults.

## Migration Guide

### Upgrading to v0.8.0
1.  Replace `SimpleIDN.to_ascii(domain)` with `SimpleIDN.to_ascii_hostname(domain)` for standard usage.
2.  Replace `SimpleIDN.to_ascii(domain, strict: false)` with `SimpleIDN.to_ascii_dns(domain)`.
3.  Use `SimpleIDN.to_ascii_fqdn(domain)` if you need absolute domain names.

## Development

```bash
crystal spec        # Run tests
crystal tool format # Format code
```

## Contributing

1. Fork & Branch (`git checkout -b feature/cool-thing`)
2. Commit & Push
3. Create PR

## Contributors

- [Chao Yang](https://github.com/cyangle) - creator/maintainer
