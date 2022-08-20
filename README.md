[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KYWUWS86GSFGL)

This is just a wrapper for mass-executing git scripts across mulitiple repos.

I.e. go to the root directory and run `lua path/to/git.lua status` to see everything's status.
I.e. go to the root directory and run `lua path/to/git.lua pull` to pull everything.

For pull, for a few of the common responses, I tried to format them to be one line per repo.
Maybe more in the future?

### Depends on:

- [lua-ext](https://github.com/thenumbernine/lua-ext)
- luafilesystem 
