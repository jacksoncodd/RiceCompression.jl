using Base: summarysize

# Testing the implementation
using ..RiceCompression
using FITSFiles
using Test

@testset "Simple Cases" begin
    
    #Trivial Case
    data::Vector = Int16[0]

    compressed = RiceCompression.encode(RiceCompression.Rice,data)
    decoded = RiceCompression.decode(RiceCompression.Rice,compressed, length(data), eltype(data))

    @test data == decoded

    #Small Vector
    # data = rand(1:1000, 65)
    data = Int16[112, 112, 113, 113, 112, 112, 113, 113, 113, 113, 112, 112, 112, 114, 114, 114, 113, 113, 112, 112, 112, 112, 111, 111, 112, 112, 112, 114, 115, 115, 115, 115]

    compressed = RiceCompression.encode(RiceCompression.Rice,data)
    println(compressed)
    decoded = RiceCompression.decode(RiceCompression.Rice,compressed, length(data), eltype(data))

    @test data == decoded
end

@testset "Low Entropy Test" begin
    data::Vector = zeros(Int16,64)

    compressed = RiceCompression.encode(RiceCompression.Rice,data)
    @test compressed == UInt8[0x00, 0x00, 0x00, 0x00]

    for i in eachindex(data) 
        data[i] = 50
    end

    compressed = RiceCompression.encode(RiceCompression.Rice,data)
    @test compressed == UInt8[0x00, 0x32, 0x00, 0x00]
end

@testset "High Entropy Test" begin
    data = zeros(Int32, 6)
    data[2] = 1<<31 -1
    data[4] = 1<<31 -1
    data[6] = 1<<31 -1

    compressed = RiceCompression.encode(RiceCompression.Rice,data)
    decoded = RiceCompression.decode(RiceCompression.Rice,compressed, length(data),eltype(data))

    @test data == decoded
end

@testset "Type Testing" begin
    data = rand(0:63, 32)

    #Int8
    data_Int8 = zeros(Int8, 32)
    for i in eachindex(data_Int8)
        data_Int8[i] = data[i]
    end
    compressed_Int8 = RiceCompression.encode(RiceCompression.Rice,data_Int8)
    decoded_Int8 = RiceCompression.decode(RiceCompression.Rice,compressed_Int8, length(data_Int8), eltype(data_Int8))

    @test data_Int8 == decoded_Int8
    @test eltype(decoded_Int8) == Int8

    #Int16
    data_Int16 = zeros(Int16, 32)
    for i in eachindex(data_Int16)  
        data_Int16[i] = data[i]
    end
    compressed_Int16 = RiceCompression.encode(RiceCompression.Rice,data_Int16)
    decoded_Int16 = RiceCompression.decode(RiceCompression.Rice,compressed_Int16, length(data_Int16), eltype(data_Int16))

    @test data_Int16 == decoded_Int16
    @test eltype(decoded_Int16) == Int16

    #Int32
    data_Int32 = zeros(Int32, 32)
    for i in eachindex(data_Int32)  
        data_Int32[i] = data[i]
    end
    compressed_Int32 = RiceCompression.encode(RiceCompression.Rice,data_Int32)
    decoded_Int32 = RiceCompression.decode(RiceCompression.Rice,compressed_Int32, length(data_Int32), eltype(data_Int32))

    @test data_Int32 == decoded_Int32
    @test eltype(decoded_Int32) == Int32

    #Int128
    data_Int128 = zeros(Int128, 32)
    for i in eachindex(data_Int128)  
        data_Int128[i] = data[i]
    end
    compressed_Int128 = RiceCompression.encode(RiceCompression.Rice,data_Int128)
    decoded_Int128 = RiceCompression.decode(RiceCompression.Rice,compressed_Int128, length(data_Int128), eltype(data_Int128))

    @test data_Int128 == decoded_Int128
    @test eltype(decoded_Int128) == Int128
end

@testset "FITS Input" begin
    
    file = FITSFiles.fits("data/m13.fits")
    data = file[1].data
    rs = reshape(data, :)

    compressed = RiceCompression.encode(RiceCompression.Rice,rs)

    # Decoding
    decoded = reshape(RiceCompression.decode(RiceCompression.Rice,compressed, length(data), eltype(data)), size(data))

    @test data == decoded

    # comp_file = FITSFiles.fits("data/m13_rice.fits")
    # comp_data = file[1].data
    # compressed = reshape(comp_data, :)

    # # Decoding
    # decoded = reshape(RiceCompression.decode(RiceCompression.Rice,compressed, length(data), eltype(data)), size(data))

    # @test data == decoded

end

@testset "Multi Threading" begin

    file = FITSFiles.fits("data/m13.fits")
    data = file[1].data
    rs = reshape(data, :)

    data_split = []
    decoded = zeros(eltype(data), size(data))
    n = 0
    while n < length(rs)
        m = n + 256
        m = min(m, length(rs))
        append!(data_split, [rs[n+1:m]])
        n = m
    end

    Threads.@threads for i in eachindex(data_split)
        compressed = RiceCompression.encode(RiceCompression.Rice,data_split[i])
        output = RiceCompression.decode(RiceCompression.Rice,compressed, length(data_split[i]), eltype(data_split[i]))
        for j in eachindex(output)
            decoded[(i-1)*256 + j] = output[j]
        end
    end

    @test data == reshape(decoded, size(data))

end




