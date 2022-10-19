[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>
[![Donate via Bitcoin](https://img.shields.io/badge/Donate-Bitcoin-green.svg)](bitcoin:37fsp7qQKU8XoHZGRQvVzQVP8FrEJ73cSJ)<br>
[![Donate via Paypal](https://img.shields.io/badge/Donate-Paypal-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)

This is just a wrapper for mass-executing git scripts across mulitiple repos.

I.e. go to the root directory and run `lua path/to/git.lua status` to see everything's status.
I.e. go to the root directory and run `lua path/to/git.lua pull` to pull everything.

For pull, for a few of the common responses, I tried to format them to be one line per repo.
Maybe more in the future?

### Depends on:

- [lua-ext](https://github.com/thenumbernine/lua-ext)
- luafilesystem 
