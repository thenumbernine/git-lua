[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

Recursive git command issuer. Parallelized. One-line-summary.

This is a wrapper for mass-executing git scripts across mulitiple repos.

Example of a `git.sh pull`
```
✅ /home/chris/Projects/lua/template
✅ /home/chris/Projects/lua/symmath
✅ /home/chris/Projects/lua/tensor
✅ /home/chris/Projects/lua/tetrid-attack
✅ /home/chris/Projects/lua/thirteen
✅ /home/chris/Projects/lua/texatlas
✅ /home/chris/Projects/lua/threadmanager
✅ /home/chris/Projects/lua/thread
✅ /home/chris/Projects/lua/tracking-youtube
💡 /home/chris/Projects/lua/tiletangentspace ... There is no tracking information for the current branch.
✅ /home/chris/Projects/lua/url
✅ /home/chris/Projects/lua/vec
✅ /home/chris/Projects/lua/vk
⬇️  /home/chris/Projects/lua/vec-ffi ... 2 files changed, 29 insertions(+), 17 deletions(-)
✅ /home/chris/Projects/lua/webserver
⬇️  /home/chris/Projects/lua/volume-renderer ... 5 files changed, 873 insertions(+), 393 deletions(-)
💡 /home/chris/Projects/lua/webserver-old ... There is no tracking information for the current branch.
💡 /home/chris/Projects/lua/website ... There is no tracking information for the current branch.
✅ /home/chris/Projects/lua/wii-luajit
✅ /home/chris/Projects/lua/websocket
✅ /home/chris/Projects/lua/wii-sdl-luajit
💡 /home/chris/Projects/lua/world-maps ... There is no tracking information for the current branch.
💡 /home/chris/Projects/lua/youtube-to-album ... There is no tracking information for the current branch.
✅ /home/chris/Projects/lua/zeckendorff
✅ /home/chris/Projects/lua/zeta2d
✅ /home/chris/Projects/lua/zeta3d
✅ /home/chris/Projects/lua/zip
✅ /home/chris/Projects/other/dkjson
❌ /home/chris/Projects/other/luafun ... fatal: unable to connect to github.com:
github.com[0: 20.205.243.166]: errno=Connection timed out
```

Timed running `git.sh status` across 74 repos:
```
$ time git/git.sh status > /dev/null

real    0m0.365s
user    0m0.496s
sys    0m0.307s
```


I.e. go to the root directory and run `luajit path/to/git.sh status` to see everything's status.

I.e. go to the root directory and run `luajit path/to/git.sh pull` to pull everything.

`sequential.lua` - runs sequentially

`parallel-shell.lua` - runs in parallel using `&` shell execution (sorry Windows).

`parallel-threads.lua` - runs in parallel using multithreading via my [lua-thread](http://github.com/thenumbernine/lua-thread) library.


### Depends on:

- [`lua-ext`](https://github.com/thenumbernine/lua-ext)
- [`lua-threadmanager`](https://github.com/thenumbernine/lua-threadmanager) for the shell based parallelized version.
- [`lua-thread`](https://github.com/thenumbernine/lua-thread) for the thread-based parallelized version.
