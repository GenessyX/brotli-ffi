Name
===
brotli-ffi - Google [Brotli](https://github.com/google/brotli) ffi bindings for Lua. 

Installation
===
To install `brotli-ffi` you need to install
[Brotli](https://github.com/google/brotli#build-instructions)
with shared libraries firtst.
Then you can install `brotli-ffi` by running `luarocks install brotli-ffi`

Synopsis
====
* Simple usage
```lua
local brotli = require "brotli"
local txt = string.rep("ABCD", 1000)
print("Uncompressed size:", #txt)
local compressed = brotli:compress(txt)
print("Compressed size:", #txt)
local txt2 = brotli:decompress(compressed)
assert(txt == txt2)
```

* Advanced usage (streams)
1. Compression
```lua
local brotli = require "brotli"
local buffer_size = 32 * 1024
local compressor = brotli.compressor:new({ quality = 11 })
local f_name = "test.html"
local f = io.open(f_name, "rb")
local o = io.open(f_name .. ".br", "wb")
while true do
    local chunk = f:read(buffer_size)
    local compressed_chunk
    if chunk then
        compressed_chunk = compressor:compress(chunk)
    else
        compressed_chunk = compressor:finish()
    end
    o:write(compressed_chunk)
    if not chunk then
        break
    end
end
f:close()
o:close()
```
2. Decompression
```lua
local brotli = require "brotli"
local buffer_size = 32 * 1024
local decompressor = brotli.decompressor:new()
local f_name = "test.html"
local f = io.open(f_name .. ".br", "rb")
local o = io.open(f_name, "wb")
while true do
    local compressed_chunk = f:read(buffer_size)
    local chunk
    if compressed_chunk then
        chunk = decompressor:decompress(compressed_chunk)
    else
        chunk = decompressor:finish()
    end
    o:write(chunk)
    if not compressed_chunk then
        break
    end
end
f:close()
o:close()
```
