local brotli = require "brotli"
local bit = require "bit"

local buffer_size = 2 ^ 16 + 1
local f_name = "test.css"

local f = io.open(f_name)
local f_size = f:seek("end")
f:close()

local f = io.open(f_name)
if not f then
    error("no such file")
end

local contents = string.rep("0", f_size)

local compressor = brotli.compressor:new({ quality = 11})
local result = ""
local cursor = 0
local i = 1
while true do
    local chunk = f:read(buffer_size)
    -- local chunk = string.sub(contents, cursor, cursor + buffer_size)
    local compressed_chunk
    if not chunk then
        compressed_chunk = compressor:finish()
    else
        compressed_chunk = compressor:compress(chunk)
    end
    
    result = result .. compressed_chunk
    
    if not chunk then
        break
    end
    print(i, cursor, "/", f_size)
    if #compressed_chunk > 0 then
        print(cursor, #compressed_chunk)
    end
    cursor = cursor + #chunk
    i = i + 1
end

print("#result: ", #result)
f:close()

local o = io.open(f_name .. ".br", "wb")
if not o then
    error("no such file")
end
o:write(result)
o:close()

os.execute("sleep 5")
os.execute("sleep 5")
