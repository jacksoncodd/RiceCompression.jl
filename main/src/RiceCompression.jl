using Base: summarysize

# Testing the implementation
using ..HighEntropyRice
using ..BasicRiceCompression
using ..StandardRice


# Test array
data = Int[100, 101, 102, 103, 104, 200, 205, 208, 300, 306, 500, 502, 510, 1603, 1600, 500, 437]

# Encoding
compressed = StandardRice.rice_encode(data)

# Decoding
decoded = StandardRice.rice_decode(compressed)

println("Original Data: ", data)
println("Size of original data (bytes): ", summarysize(data))
println("Compressed Data: ", compressed)
println("Size of compressed data (bytes): ", summarysize(compressed))
println("Decoded Data: ", decoded)
println("Size of decoded data (bytes): ", summarysize(decoded))
println("Match: ", data == decoded)