# simpleidn.cr

> [!CAUTION]
> **Experimental Implementation:** This project is almost 100% vibe-coded.
> While it passes an extensive suite of unit and third-party integration tests,
> the internal logic may not follow traditional patterns. Use at your own risk.

This is a Crystal port of the Ruby library [simpleidn](https://github.com/mmriis/simpleidn).
It provides easy conversion from punycode ACE strings to unicode strings and vice versa using IDNA2008 (UTS #46) conformant processing.

> [!IMPORTANT]
> **Breaking Change in v0.6.0:** The `strict` parameter defaults to `true`, enforcing RFC 1123 hostname rules.
> This means wildcards (`*`) and underscores (`_`) are rejected by default. See [Migration Guide](#migrating-from-v05x).

## Features

- **IDNA2008 Conformant**: Uses ICU's UTS #46 implementation (nontransitional by default).
- **JSON Schema Compatible**: Validates `hostname` and `idn-hostname` formats (RFC 1123/5890).
- **Full Unicode Support**: CJK, Emoji, BiDi (Arabic/Hebrew), ContextJ/ContextO rules.
- **DNS Record Support**: Optional non-strict mode for wildcards (`*`), underscores (`_`), and SRV records.
- **High Performance**: Reuses global, thread-safe ICU instances.

## Requirements

Requires **ICU** (International Components for Unicode) installed on your system.

### Installing ICU

*   **Ubuntu/Debian:** `sudo apt-get install libicu-dev`
*   **Fedora/RHEL:** `sudo dnf install libicu-devel`
*   **Arch:** `sudo pacman -S icu`
*   **macOS:** `brew install icu4c` (Set `PKG_CONFIG_PATH` if needed)
*   **Alpine:** `apk add icu-dev`

Verify with: `pkg-config --modversion icu-uc`

## Installation

1.  Add to `shard.yml`:
    ```yaml
    dependencies:
      simpleidn:
        github: cyangle/simpleidn.cr
    ```
2.  Run `shards install`

## Usage

```crystal
require "simpleidn"

# --- Basic Conversion ---
SimpleIDN.to_ascii("møllerriis.com")       # => "xn--mllerriis-l8a.com"
SimpleIDN.to_unicode("xn--mllerriis-l8a.com") # => "møllerriis.com"

# --- IDNA2008 Mapping ---
SimpleIDN.to_ascii("Faß.de")               # => "xn--fa-hia.de" (ß preserved)

# --- Transitional (IDNA2003) ---
SimpleIDN.to_ascii("faß.de", transitional: true) # => "fass.de" (ß -> ss)

# --- Validation ---
SimpleIDN.valid_hostname?("münchen.de")    # => true
SimpleIDN.valid_hostname?("-invalid")      # => false
```

## API Reference

### 1. `SimpleIDN.to_ascii(domain, transitional, strict)`
Converts internationalized domain names to ASCII (Punycode).

| Param | Default | Description |
|---|---|---|
| `domain` | - | Domain string (can be nil) |
| `transitional` | `false` | Use IDNA2003 mapping (e.g., ß -> ss) |
| `strict` | `true` | Enforce RFC 1123 (No wildcards/underscores) |

**Returns:** ASCII string or `nil` if invalid.

### 2. `SimpleIDN.to_unicode(domain, transitional, strict)`
Converts Punycode to Unicode. Parameters behave same as `to_ascii`.

### 3. `SimpleIDN.valid_hostname?(hostname, transitional, strict, allow_trailing_dot)`
Validates that a string is a valid hostname (structural + IDNA checks).

| Param | Default | Description |
|---|---|---|
| `hostname` | - | String to check |
| `strict` | `true` | Reject `*`, `_`, `@` (RFC 1123) |
| `allow_trailing_dot`| `false` | Allow single trailing dot (DNS root) |

#### JSON Schema Validation Recommendations
For [JSON Schema](https://json-schema.org/understanding-json-schema/reference/string.html#resource-identifiers) formats:
*   **`idn-hostname`**: Use `SimpleIDN.valid_hostname?(str)`
*   **`hostname`**: Use `SimpleIDN.valid_hostname?(str)` **and** ensure the string is ASCII only (e.g., `str.ascii_only?`).

### Error Handling
*   **Invalid Domain**: Returns `nil` (e.g., `SimpleIDN.to_ascii("*.com")` in strict mode).
*   **System Error**: Raises `SimpleIDN::ConversionError` (ICU failures).

## Core Concepts & Configuration

### Strict Mode (Hostname vs DNS)
Defaults to `strict: true` (RFC 1123).

| Mode | Allowed Chars | Use Case |
|---|---|---|
| `strict: true` | LDH (Letters, Digits, Hyphens) | Hostnames, URLs, Email domains |
| `strict: false`| LDH + `*`, `_`, `@` | DNS Records (SRV, DMARC, Wildcards) |

```crystal
SimpleIDN.to_ascii("*.example.com")                 # => nil (Strict)
SimpleIDN.to_ascii("*.example.com", strict: false)  # => "*.example.com"
```

### IDNA2008 vs IDNA2003 (Transitional)
Defaults to **Nontransitional** (IDNA2008).
*   **Nontransitional**: `ß` -> `ß`, `ς` -> `ς`
*   **Transitional**: `ß` -> `ss`, `ς` -> `σ` (Use `transitional: true`)

### Hostname Length Limits
Enforces RFC 1035 limits:
*   Label limit: 63 bytes (`SimpleIDN::MAX_LABEL_LENGTH`)
*   Hostname limit: 253 bytes (`SimpleIDN::MAX_HOSTNAME_LENGTH`)

## Performance & Lifecycle

*   **Global, Thread-Safe**: Uses 4 global, immutable `UIDNA` instances (one for each config permutation). These are **thread-safe and lock-free** (per ICU `uidna_openUTS46` documentation), allowing high-concurrency usage without mutex contention.
*   **Memory Footprint**: Adds approximately **~3.2 MB** RSS overhead compared to a "Hello World" application. This is almost entirely due to loading shared ICU libraries (`libicudata`, `libicuuc`) and data tables. Instantiating all 4 modes upfront costs effectively zero additional memory due to shared backing data.
*   **No Memory Leaks**: Stable memory usage under load (verified with 100k+ iterations), relying on standard GC for wrapper objects.
*   **Fail-Fast**: Raises `InitializationError` on startup if ICU is broken.
*   **Cleanup**: Uses `at_exit` to free resources.

> [!WARNING]
> **Testing Caveat (Critical):**
> When running specs, you **MUST** require `simpleidn` *before* `spec`.
>
> **Correct `spec_helper.cr`:**
> ```crystal
> require "../src/simpleidn" # MUST be first
> require "spec"
> ```
> If inverted, the cleanup handler runs too early, causing segfaults during tests.

## Migrating from v0.5.x
v0.6.0 introduces `strict: true` by default.
*   **Old Behavior**: `SimpleIDN.to_ascii("*.com")` worked.
*   **New Behavior**: Returns `nil`.
*   **Fix**: Add `strict: false` for DNS record handling.

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
