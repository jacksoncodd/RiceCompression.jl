using Base: summarysize

# Testing the implementation
# using ..HighEntropyRice
# using ..BasicRiceCompression
# using ..StandardRice
using ..UIntRice
using FITSFiles

# FITSFiles.info("ZIMAGE")
# file = FITSFiles.fits("data/file009.fits")


# Test array
data = Int[100, 101, 102, 103, 104, 200, 205, 208, 300, 306, 500, 502, 510, 1603, 1600, 500, 497]


# Encoding
compressed = UIntRice.rice_encode(data)

# Decoding
decoded = UIntRice.rice_decode(compressed, length(data))

println("Original Data: ", data)
println("Size of original data (bytes): ", summarysize(data))
println("Compressed Data: ", compressed)
println("Size of compressed data (bytes): ", summarysize(compressed))
println("Decoded Data: ", decoded)
println("Size of decoded data (bytes): ", summarysize(decoded))
println("Match: ", data == decoded)

