include("../src/RiceCompression.jl")
using .RiceCompression

using Base: summarysize

@show methods(RiceCompression.rice_encode)

# Let's give it a run
data = Int[10, 20, 30, 40]
# @show typeof(data)

k = 2

compressed = RiceCompression.rice_encode(data, k)
decoded = RiceCompression.rice_decode(compressed, k)

println("Original data: ", data)
println("Size of original data (bytes): ", summarysize(data))
println("Compressed data: ", compressed)
println("Size of encoded array (bytes): ", summarysize(compressed))
println("Decoded data: ", decoded)
println("Size of decoded data (bytes): ", summarysize(decoded))
println("Match: ", data == decoded)

# Test with a different dataset
data2 = Int[6,7,8,7,5,10,12,14,11,9,8,7,4,5,6,7,8,9,10,11,12,13,14,15]

k2 = 2

compressed2 = RiceCompression.rice_encode(data2, k2)
decoded2 = RiceCompression.rice_decode(compressed2, k2)

println("Original data 2: ", data2)
println("Size of original data 2 (bytes): ", summarysize(data2))
println("Compressed data 2: ", compressed2)
println("Size of compressed data 2 (bytes): ", summarysize(compressed2))
println("Decoded data 2: ", decoded2)
println("Size of decoded data 2 (bytes): ", summarysize(decoded2))
println("Match: ", data2 == decoded2)


