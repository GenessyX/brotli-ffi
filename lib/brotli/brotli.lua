local ffi = require "ffi"
local C = ffi.C
local ffi_new = ffi.new
local ffi_typeof = ffi.typeof
local bit = require "bit"
local rshift = bit.rshift
require "brotli_bindings"
local brotlienc = ffi.load("brotlienc")
local brotlidec = ffi.load("brotlidec")

local arr_uint8_t = ffi_typeof("uint8_t[?]")
local pptr_uint8_t = ffi_typeof("uint8_t*[1]")
local pptr_const_uint8_t = ffi_typeof("const uint8_t*[1]")
local ptr_size_t = ffi_typeof("size_t[1]")

local BROTLI_TRUE = 1
local BROTLI_FALSE = 0
local BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT = 2
local BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT = 3
local BROTLI_DEFAULT_QUALITY = 11
local BROTLI_DEFAULT_WINDOW = 22
local BROTLI_DEFAULT_MODE = C.BROTLI_MODE_GENERIC
local BROTLI_DEFAULT_LGBLOCK = 0


local _M = {}
_M.__index = _M

local compressor = {}
compressor.__index = compressor
function compressor:new(options)
    options = options or {}
    options.lgwin = options.lgwin or BROTLI_DEFAULT_WINDOW
    options.quality = options.quality or BROTLI_DEFAULT_QUALITY
    options.mode = options.mode or BROTLI_DEFAULT_MODE
    options.lgblock = options.lgblock or BROTLI_DEFAULT_LGBLOCK

    local enc = brotlienc.BrotliEncoderCreateInstance(nil, nil, nil)
    if not enc then
        error("Could not instantiate brotliencoder")
    end
    enc = ffi.gc(enc, brotlienc.BrotliEncoderDestroyInstance)

    brotlienc.BrotliEncoderSetParameter(enc, brotlienc.BROTLI_PARAM_MODE, options.mode)
    brotlienc.BrotliEncoderSetParameter(enc, brotlienc.BROTLI_PARAM_QUALITY, options.quality)
    brotlienc.BrotliEncoderSetParameter(enc, brotlienc.BROTLI_PARAM_LGWIN, options.lgwin)
    brotlienc.BrotliEncoderSetParameter(enc, brotlienc.BROTLI_PARAM_LGBLOCK, options.lgblock)
    local _compressor = { _encoder = enc, options = options }
    setmetatable(_compressor, self)
    return _compressor
end

function compressor:_compress(data, operation)
    local original_output_size = math.ceil(#data + rshift(#data, 2) + 10240)
    local available_out = ffi_new(ptr_size_t)
    available_out[0] = original_output_size
    local output_buffer = ffi_new(arr_uint8_t, available_out[0])
    local ptr_to_output_buffer = ffi_new(pptr_uint8_t, output_buffer)
    local input_size = ffi_new(ptr_size_t, #data)
    local input_buffer = ffi_new(arr_uint8_t, #data + 1, data)
    local ptr_to_input_buffer = ffi_new(pptr_const_uint8_t, input_buffer)
    local rc = brotlienc.BrotliEncoderCompressStream(
        self._encoder,
        operation,
        input_size,
        ptr_to_input_buffer,
        available_out,
        ptr_to_output_buffer,
        nil
    )
    if rc ~= BROTLI_TRUE then
        error("Error encountered compressing data.")
    end

    local size_of_output = original_output_size - available_out[0]
    return ffi.string(output_buffer, size_of_output)
end

function compressor:compress_full(input, options)
    local options = options or {}
    local quality = options.quality or self.options.quality
    local lgwin = options.lgwin or self.options.lgwin
    local mode = options.mode or self.options.mode
    local input_size = #input
    local n = brotlienc.BrotliEncoderMaxCompressedSize(input_size)
    local encoded_size = ffi_new(ptr_size_t, n)
    local encoded_buffer = ffi_new(arr_uint8_t, n)
    local ret = brotlienc.BrotliEncoderCompress(
        quality, lgwin, mode, input_size, input, encoded_size, encoded_buffer)

    assert(ret == BROTLI_TRUE)

    return ffi.string(encoded_buffer, encoded_size[0])
end

function compressor:compress(data)
    return self:_compress(data, brotlienc.BROTLI_OPERATION_PROCESS)
end

function compressor:flush()
    local chunks = {}
    table.insert(chunks, self:_compress("", brotlienc.BROTLI_OPERATION_FLUSH))
    while brotlienc.BrotliEncoderHasMoreOutput(self._encoder) == BROTLI_TRUE do
        table.insert(chunks, self:_compress("", brotlienc.BROTLI_OPERATION_FLUSH))
    end
    return table.concat(chunks)
end

function compressor:finish()
    local chunks = ""
    while brotlienc.BrotliEncoderIsFinished(self._encoder) == BROTLI_FALSE do
        chunks = chunks .. self:_compress("", brotlienc.BROTLI_OPERATION_FINISH)
    end
    return chunks
end

function _M:compress(data)
    local _compressor = compressor:new()
    local compressed_data = _compressor:_compress(data, brotlienc.BROTLI_OPERATION_FINISH)
    assert(brotlienc.BrotliEncoderIsFinished(_compressor._encoder) == BROTLI_TRUE)
    assert(brotlienc.BrotliEncoderHasMoreOutput(_compressor._encoder) == BROTLI_FALSE)
    return compressed_data
end


local decompressor = {}
decompressor.__index = decompressor
function decompressor:new(dictionary)
    local _dictionary, _dictionary_size
    local dec = brotlidec.BrotliDecoderCreateInstance(nil, nil, nil)
    if not dec then
        error("Could not instantiate brotlidecoder")
    end
    dec = ffi.gc(dec, brotlidec.BrotliDecoderDestroyInstance)

    if dictionary then
        _dictionary_size = #_dictionary
        _dictionary = ffi_new(arr_uint8_t, _dictionary_size, dictionary)
        brotlidec.BrotliDecoderSetCustomDictionary(
            dec,
            _dictionary_size,
            _dictionary
        )
    end

    local _decompressor = { _decoder = dec, _dictionary = _dictionary, _dictionary_size = _dictionary_size }
    setmetatable(_decompressor, self)
    return _decompressor
end

function decompressor:decompress(data)
    local chunks = ""
    local available_in = ffi_new(ptr_size_t, #data)
    local input_buffer = ffi_new(arr_uint8_t, #data + 1, data)
    local next_in = ffi_new(pptr_const_uint8_t, input_buffer)

    while true do
        local buffer_size = 5 * #data
        local available_out = ffi_new(ptr_size_t, buffer_size)
        local output_buffer = ffi_new(arr_uint8_t, buffer_size)
        local next_out = ffi_new(pptr_uint8_t, output_buffer)
        local rc = brotlidec.BrotliDecoderDecompressStream(
            self._decoder,
            available_in,
            next_in,
            available_out,
            next_out,
            nil
        )
        if rc == BROTLI_FALSE then
            local error_code = brotlidec.BrotliDecoderGetErrorCode(self._decoder)
            local error_message = brotlidec.BrotliDecoderErrorString(error_code)
            error("Decompression error: " .. ffi.string(error_message))
        end
        local chunk = ffi.string(output_buffer, buffer_size - available_out[0])
        chunks = chunks .. chunk
        if rc == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT then
            assert(available_in[0] == 0)
            break
        elseif rc == BROTLI_TRUE then
            break
        else
            assert(rc == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT)
        end
    end
    
    return chunks
end

function decompressor:is_finished()
    return brotlidec.BrotliDecoderIsFinished(self._decoder) == BROTLI_TRUE
end

function decompressor:finish()
    assert(brotlidec.BrotliDecoderHasMoreOutput(self._decoder) == false)
    if not self:is_finished() then
        error("Decompression error: incomplete compressed stream.")
    end
    return ""
end

function _M:decompress(data)
    local d = decompressor:new()
    local decompressed_data = decompressor:decompress(data)
    d:finish()
    return decompressed_data
end


_M.decompressor = decompressor
_M.compressor = compressor

return _M
