module UIntRice

using Statistics

export rice_encode, rice_decode

"""
    write(value::Int, bit_length::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}

Encodes the integer using bit_length bits in binary (MSB first).
"""
function write(value::Int, bit_length::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}
    while(bit_length >= buffer)
        bit_length -= buffer
        encoded[pos] = encoded[pos] | (value >> bit_length)
        value = value & ((1 << bit_length)-1)
        append!(encoded, 0)
        buffer = 8
        pos += 1
    end
    if(bit_length > 0)
        encoded[pos] = encoded[pos] | (value << (buffer - bit_length))
        buffer -= bit_length
    end
    return encoded, pos, buffer
end


"""
    encode_value(value::Int, fs::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}

Encodes the given value using Rice compression.
"""
function encode_value(value::Int, fs::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}
    q = value >> fs
    encoded, pos, buffer = write(((1 << q)-1) << 1, q+1, encoded, pos, buffer)
    encoded, pos, buffer = write(value & ((1 << fs) -1), fs, encoded, pos, buffer)
    return encoded, pos, buffer
end

"""
    unsign(value::Int)::Int

Converts a positive or negative integer into a positive integer for Rice Compression
"""
function unsign(value::Int)::Int
    return ((value<0) ? ~(value<<1) : (value<<1))
end


"""
    encode_block(data::Vector{Int}, encoded::Array{UInt8}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Array, Int, Int, Int}

Encodes a block of integers with size thisblock using rice compression
"""
function encode_block(data::Vector{Int}, encoded::Array{UInt8}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Array, Int, Int, Int}
    pixelsum = 0.0
    diff::Array{Int} = zeros(Int, thisblock)
    fs = 0
    bbits = 1 << fsbits	

    #Calculate the average pixel difference within the block
    for j in 1:thisblock
	    nextpix = data[j]
	    pdiff = nextpix - lastpix
	    diff[j] = ((pdiff<0) ? ~(pdiff<<1) : (pdiff<<1))
	    pixelsum += diff[j]
	    lastpix = nextpix
    end
    dpsum = (pixelsum - (thisblock/2) - 1)/thisblock;
	if (dpsum < 0) 
        dpsum = 0.0
    end
	psum = (trunc(UInt,dpsum)) >> 1

    #Calculate fs based on the average pixel difference
	while psum>0
        psum >>= 1
        fs += 1
    end

    #High entropy case when fs > fsmax, encode pixel differences directly
    if fs > fsmax
        println("High Entropy Engaged")
        encoded, pos, buffer = write(fsmax + 1, fsbits, encoded, pos, buffer)
        for x in diff
            encoded, pos, buffer = write(x, bbits, encoded, pos, buffer)
            println("encoded ", x)
        end
    #Standard case, encode differences using rice compression
    else
        encoded, pos, buffer = write(fs, fsbits, encoded, pos, buffer)
        for x in diff
            encoded, pos, buffer = encode_value(x, fs, encoded, pos, buffer)
        end
    end
    return encoded, pos, buffer, lastpix
end


"""
    rice_encode(data::Vector{Int}, fsbits::Int = 5, fsmax::Int = 25, nblock::Int = 32)::Array{UInt8}

Encodes an array of integers using Rice coding.
fsbits: Number of bits to store fs values in
fsmax: Maximum value for fs. Must be less than 2^fsbits
nblock: Encoding block size. Smaller values result in better rice encoding but more fs values stored
Returns an Array of unsigned integers.
"""
function rice_encode(data::Matrix{Int16},
                        fsbits::Int = 5,
                        fsmax::Int = 25,
                        nblock::Int = 8)::Array{UInt8}
    
    data_array::Array{Int} = []
    encoded::Array{UInt8} = zeros(UInt8, 1)
    pos = 1
    buffer = 8
    nx = length(data)
    dims = size(data)
    bbits = 1 << fsbits
    println(dims)
    for i in 1:dims[1]
        for j in 1:dims[2]
            push!(data_array, data[i,j])
        end
    end

    #Encode the initial entry
    lastpix = data_array[1]
    encoded, pos, buffer = write(lastpix, bbits, encoded, pos, buffer)

    #Encode pixel differences one block at a time
    thisblock = nblock
    i = 0
    while(i <= nx)
        if (nx-i < nblock) 
            thisblock = nx-i
        end
	    encoded, pos, buffer, lastpix = encode_block(data_array[i+1:i+thisblock], encoded, pos, buffer, lastpix, thisblock, fsmax, fsbits)
        i += nblock
    end

    return encoded
end


"""
    unary_decode(encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Int, Int, Int}

Decodes the unary-coded integer starting at element `pos`, bit `buffer`.
Returns the decoded integer and the updated position.
"""
function unary_decode(encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
    value = 0
    bit = 1
    while(bit == 1)
        if(buffer <= 0)
            pos += 1
            buffer = 8
        end
        if(pos > length(encoded))
            return value, pos, buffer
        end
        buffer -= 1
        bit = (encoded[pos] >> buffer) & 1
        value += bit
    end
    if(buffer <= 0)
        pos += 1
        buffer = 8
    end
    return value, pos, buffer
end


"""
    binary_decode(encoded::Array{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}

Decodes a fs-bit binary integer starting at element `pos`, bit `buffer`.
Returns the decoded integer and the updated position.
"""
function binary_decode(encoded::Array{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
    output = 0
    bits_to_go = fs
    while(bits_to_go >= buffer)
        if(pos > length(encoded))
            return output, pos, buffer
        end
        bits_to_go -= buffer
        bits = encoded[pos] & ((1 << buffer) - 1)
        output = output | (bits << bits_to_go) 
        pos += 1
        buffer = 8
    end
    if(bits_to_go > 0)
        if(pos > length(encoded))
            return output, pos, buffer
        end
        bits = (encoded[pos] >> (buffer - bits_to_go)) & ((1 << bits_to_go) - 1)
        output = output | bits
        buffer -= bits_to_go
    end
    return output, pos, buffer
end


"""
    decode_value(encoded::Array{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}

Decodes a value using Rice compression with the given fs value.
"""
function decode_value(encoded::Array{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
    q, pos, buffer = unary_decode(encoded, pos, buffer)
    r, pos, buffer = binary_decode(encoded, fs, pos, buffer)
    value = q << fs | r
    return resign(value), pos, buffer
end

"""
    resign(value::Int)::Int

Reverses the unsign function to return a positive or negative integer
"""
function resign(value::Int)::Int
    if ((value & 1) == 0)
		value = value>>1;
	else
		value = ~(value>>1);
    end
    return value
end


"""
    decode_block(encoded::Array{UInt8}, decoded::Vector{Int}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Int, Int, Int}

Decodes the values of a block length thisblock
"""
function decode_block(encoded::Array{UInt8}, decoded::Vector{Int}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Int, Int, Int}
    #Decode the fs value
    fs, pos, buffer = binary_decode(encoded, fsbits, pos, buffer)
    bbits = 1 << fsbits	

    #High entropy case, values written directly in binary
    if(fs > fsmax)
        println("High Entropy decode")
        for _ in 1:thisblock
            diff, pos, buffer = binary_decode(encoded, bbits, pos, buffer)
            println(resign(diff))
            lastpix += resign(diff)
            push!(decoded, lastpix)
        end
    #Standard case, decode from rice compression
    else
        for _ in 1:thisblock
            diff, pos, buffer = decode_value(encoded, fs, pos, buffer)
            lastpix += diff
            push!(decoded, lastpix)
        end
    end
    
    return pos, buffer, lastpix
end


function arrange(vector::Vector{Int}, dims::Tuple{Int, Int})::Matrix{Int}
    decoded::Matrix{Int} = zeros(Int, dims)
    for i in 0:dims[1]-1
        for j in 1:dims[2]
            decoded[i+1,j] = vector[i*dims[2] + j]
        end
    end
    return decoded
end


"""
    rice_decode(encoded::Array{UInt8}, nx::Int, fsbits::Int = 5, fsmax::Int = 25, nblock::Int = 8)::Vector{Int}

nx: Number of pixels in original image
fsbits: Number of bits fs values were stored in
fsmax: Maximum value for fs. Must be less than 2^fsbits
nblock: Encoding block size. Smaller values result in better rice encoding but more fs values stored
Decodes a Rice-coded UInt8 array into its original integer array.
"""
function rice_decode(encoded::Array{UInt8}, 
                                dims::Tuple{Int,Int},
                                fsbits::Int = 5,
                                fsmax::Int = 25,
                                nblock::Int = 8)::Matrix{Int}
    
    decoded_array = Int[]
    pos = 1
    buffer = 8
    bbits = 1 << fsbits
    nx = dims[1] * dims[2]

    #Decode the initial value
    initial, pos, buffer = binary_decode(encoded, bbits, pos, buffer)
    lastpix = initial

    #Decode values one block at a time
    thisblock = nblock
    i = 0
    while(i <= nx)
        if (nx-i < nblock) 
            thisblock = nx-i
        end
	    pos, buffer, lastpix = decode_block(encoded, decoded_array, pos, buffer, lastpix, thisblock, fsmax, fsbits)
        i += nblock
    end

    return arrange(decoded_array, dims)
end

end  # module