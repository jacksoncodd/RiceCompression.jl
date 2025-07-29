using Base: summarysize

# Testing the implementation
# using ..HighEntropyRice
# using ..BasicRiceCompression
# using ..StandardRice
using ..RiceCompression
using FITSFiles
using Test

# @testset "Rice Compression" begin

#     #Test 1 element array
#     data = zeros(Int, 1)

#     compressed = UIntRice.rice_encode(data)
#     decoded = UIntRice.rice_decode(compressed, length(data))

#     @test isequal(data, decoded)

#     #Test large array of zeros
#     data = zeros(Int, 100)

#     compressed = UIntRice.rice_encode(data)
#     decoded = UIntRice.rice_decode(compressed, length(data))

#     @test isequal(data, decoded)

#     #Test large array with random entries
#     for i in 1:100
#         data[i] = rand(0:1000)
#     end

#     compressed = UIntRice.rice_encode(data)
#     decoded = UIntRice.rice_decode(compressed, length(data))

#     @test isequal(data, decoded)

#     #Test high entropy case
#     # data = [0, 1 << 31, 0, 1 << 31]

#     # compressed = UIntRice.rice_encode(data)
#     # decoded = UIntRice.rice_decode(compressed, length(data))

#     # @test isequal(data, decoded)

# end

file = FITSFiles.fits("data/m13.fits")
# # cards = file[1].cards
# # println(cards)
data = file[1].data
# println(file)


# Test array
# data2::Matrix{Int} = zeros(Int, 10, 10)
# for i in 1:10
#     for j in 1:10
#         data2[i,j] = rand(0:1000)
#     end
# end

# Encoding
rs = reshape(data, :)

compressed = RiceCompression.encode(RiceCompression.Rice,rs)
println("Size of original data (bytes): ", summarysize(data))
println("Size of compressed data (bytes): ", summarysize(compressed))

# Decoding
decoded = reshape(RiceCompression.decode(RiceCompression.Rice,compressed, length(data), eltype(data)), size(data))
println("Size of decoded data (bytes): ", summarysize(decoded))
println("Match: ", data == decoded)



