local ffi = require "ffi"
local C = ffi.C
local ffi_new = ffi.new
local ffi_typeof = ffi.typeof
local bit = require "bit"
local rshift = bit.rshift

ffi.cdef [[
void free(void *ptr);

typedef enum BrotliEncoderMode {
    BROTLI_MODE_GENERIC = 0,
    BROTLI_MODE_TEXT = 1,
    BROTLI_MODE_FONT = 2
} BrotliEncoderMode;

typedef enum BrotliEncoderOperation {
    BROTLI_OPERATION_PROCESS = 0,
    BROTLI_OPERATION_FLUSH = 1,
    BROTLI_OPERATION_FINISH = 2,
    BROTLI_OPERATION_EMIT_METADATA = 3
} BrotliEncoderOperation;

typedef enum BrotliEncoderParameter {
    BROTLI_PARAM_MODE = 0,
    BROTLI_PARAM_QUALITY = 1,
    BROTLI_PARAM_LGWIN = 2,
    BROTLI_PARAM_LGBLOCK = 3,
    BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING = 4,
    BROTLI_PARAM_SIZE_HINT = 5
} BrotliEncoderParameter;

typedef void* (*brotli_alloc_func)(void* opaque, size_t size);
typedef void (*brotli_free_func)(void* opaque, void* address);

typedef struct BrotliEncoderStateStruct BrotliEncoderState;

BrotliEncoderState* BrotliEncoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

int BrotliEncoderSetParameter(
    BrotliEncoderState* state, BrotliEncoderParameter param, uint32_t value);

int BrotliEncoderCompressStream(
    BrotliEncoderState* state, BrotliEncoderOperation op, size_t* available_in,
    const uint8_t** next_in, size_t* available_out, uint8_t** next_out,
    size_t* total_out);

size_t BrotliEncoderMaxCompressedSize(size_t input_size);

int BrotliEncoderCompress(
    int quality, int lgwin, BrotliEncoderMode mode, 
    size_t input_size, const uint8_t input_buffer[],
    size_t* encoded_size, uint8_t encoded_buffer[]);

int BrotliEncoderIsFinished(BrotliEncoderState* state);

int BrotliEncoderHasMoreOutput(BrotliEncoderState* state);

void BrotliEncoderDestroyInstance(BrotliEncoderState* state);

uint32_t BrotliEncoderVersion(void);
]]

local arr_uint8_t = ffi_typeof("uint8_t[?]")
local pptr_uint8_t = ffi_typeof("uint8_t*[1]")
local pptr_const_uint8_t = ffi_typeof("const uint8_t*[1]")
local ptr_size_t = ffi_typeof("size_t[1]")

local _BUFFER_SIZE = 65536
local BROTLI_TRUE = 1
local BROTLI_FALSE = 0
local BROTLI_DEFAULT_QUALITY = 11
local BROTLI_DEFAULT_WINDOW = 22
local BROTLI_DEFAULT_MODE = C.BROTLI_MODE_GENERIC
local BROTLI_DEFAULT_LGBLOCK = 0

local brotlienc = ffi.load("brotlienc")

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
    local input_buffer = ffi_new(arr_uint8_t, #data, data)
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

_M.compressor = compressor

return _M
