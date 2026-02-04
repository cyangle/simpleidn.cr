# simpleidn.cr

This is a Crystal port of the Ruby library [simpleidn](https://github.com/mmriis/simpleidn).

It provides easy conversion from punycode ACE strings to unicode strings and vice versa.

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
# => "xn--fa-hia.de" (ss maps to ss)

SimpleIDN.to_unicode("xn--fa-hia.de")
# => "fass.de"
```

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
