local ffi = require("ffi")

local bindings = ffi.cdef [[
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
    
    typedef enum {
        BROTLI_DECODER_RESULT_ERROR = 0,
        BROTLI_DECODER_RESULT_SUCCESS = 1,
        BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT = 2,
        BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT = 3
      } BrotliDecoderResult;
    
    typedef struct BrotliDecoderStateStruct BrotliDecoderState;
    
    BrotliDecoderState* BrotliDecoderCreateInstance(
        brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);
    
    void BrotliDecoderDestroyInstance(BrotliDecoderState* state);
    
    BrotliDecoderResult BrotliDecoderDecompressStream(
      BrotliDecoderState* state, 
      size_t* available_in, const uint8_t** next_in,
      size_t* available_out, uint8_t** next_out,
      size_t* total_out);
    
    int BrotliDecoderIsUsed(const BrotliDecoderState* state);
    
    int BrotliDecoderIsFinished(const BrotliDecoderState* state);
    
    // typedef enum BrotliDecoderErrorCode {
    // } BrotliDecoderErrorCode;
    
    uint32_t BrotliDecoderGetErrorCode(const BrotliDecoderState* s);
    
    const char* BrotliDecoderErrorString(uint32_t c);
    
    bool BrotliDecoderHasMoreOutput(const BrotliDecoderState* s);
    
    uint32_t BrotliDecoderVersion(void);
]]

return bindings
