module UIntRice

using Statistics

export rice_encode, rice_decode

"""
    write(value::UInt, bits_to_go::UInt, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array{UInt8}, Int, Int}

Encodes the integer using k bits in binary (MSB first).
"""
function write(value::Int, bits_to_go::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}
    while(bits_to_go >= buffer)
        bits_to_go -= buffer
        encoded[pos] = encoded[pos] | (value >> bits_to_go)
        value = value & ((1 << bits_to_go)-1)
        append!(encoded, 0)
        buffer = 8
        pos += 1
    end
    if(bits_to_go > 0)
        encoded[pos] = encoded[pos] | (value << (buffer - bits_to_go))
        buffer -= bits_to_go
    end
    return encoded, pos, buffer
end


"""
    encode_value(value::UInt, k::UInt, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array{UInt8}, Int, Int}

Encodes the given value using Rice compression.
"""
function encode_value(value::Int, fs::Int, encoded::Array{UInt8}, pos::Int, buffer::Int)::Tuple{Array, Int, Int}
    q = value >> fs
    unary = ((1 << q)-1) << 1
    encoded, pos, buffer = write(unary, q+1, encoded, pos, buffer)
    encoded, pos, buffer = write(value & ((1 << fs) -1), fs, encoded, pos, buffer)
    return encoded, pos, buffer
end

"""
    unsign(value::Int)::UInt

Converts a positive or negative integer into an unsigned integer for Rice Compression
"""
function unsign(value::Int)::Int
    return ((value<0) ? ~(value<<1) : (value<<1))
end



function encode_block(data::Vector{Int},encoded::Array{UInt8}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Array, Int, Int, Int}
    pixelsum = 0.0
    diff::Array{Int} = zeros(Int, thisblock)
    fs = 0
    bbits = 1 << fsbits	
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
	while psum>0
        psum >>= 1
        fs += 1
    end
    if fs > fsmax
        encoded, pos, buffer = write(fsmax + 1, fsbits, encoded, pos, buffer)
        for x in diff
            encoded, pos, buffer = write(x, bbits, encoded, pos, buffer)
        end
    else
        encoded, pos, buffer = write(fs, fsbits, encoded, pos, buffer)
        for x in diff
            encoded, pos, buffer = encode_value(x, fs, encoded, pos, buffer)
        end
    end
    return encoded, pos, buffer, lastpix
end


"""
    rice_encode(data::Vector{Int})::BitVector

Encodes an array of integers using Rice coding.
Returns a BitVector to optimize space usage.
"""
function rice_encode(data::Vector{Int})::Array{UInt8}
    encoded::Array{UInt8} = zeros(UInt8, 1)
    pos = 1
    buffer = 8
    nx = length(data)
    fsbits = 5
    fsmax = 25
    nblock = 8
    bbits = 1 << fsbits

    #Encode the initial entry
    lastpix = data[1]
    encoded, pos, buffer = write(lastpix, bbits, encoded, pos, buffer)

    thisblock = nblock
    i = 0
    while(i <= nx)
        if (nx-i < nblock) 
            thisblock = nx-i
        end
	    encoded, pos, buffer, lastpix = encode_block(data[i+1:i+thisblock], encoded, pos, buffer, lastpix, thisblock, fsmax, fsbits)
        i += nblock
    end

    return encoded
end


"""
    unary_decode(encoded::BitVector, pos::Int)::Tuple{Int, Int}

Decodes the unary-coded integer starting at `pos`.
Returns the decoded integer and the updated position.
"""
function unary_decode(encoded::Vector{UInt8}, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
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
    binary_decode(encoded::BitVector, pos::Int, k::Int)::Tuple{Int, Int}

Decodes a k-bit binary integer starting at `pos`.
Returns the decoded integer and the updated position.
"""
function binary_decode(encoded::Vector{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
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
    decode_value(pos::Int, k::Int, encoded::BitVector)::Tuple{Int, Int}

Decodes a value using Rice compression.
"""
function decode_value(encoded::Vector{UInt8}, fs::Int, pos::Int, buffer::Int)::Tuple{Int, Int, Int}
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

function decode_block(encoded::Vector{UInt8}, decoded::Vector{Int}, pos::Int, buffer::Int, lastpix::Int, thisblock::Int, fsmax::Int, fsbits::Int)::Tuple{Int, Int, Int}
    fs, pos, buffer = binary_decode(encoded, fsbits, pos, buffer)
    if(fs > fsmax)
        for _ in 1:thisblock
            diff, pos, buffer = binary_decode(encoded, bbits, pos, buffer)
            lastpix += diff
            push!(decoded, lastpix)
        end
    else
        for _ in 1:thisblock
            diff, pos, buffer = decode_value(encoded, fs, pos, buffer)
            lastpix += diff
            push!(decoded, lastpix)
        end
    end
    
    return pos, buffer, lastpix
end

"""
    rice_decode(encoded::BitVector, k::Int)::Vector{Int}

Decodes a Rice-coded bit stream into its original integer array.
"""
function rice_decode(encoded::Vector{UInt8}, npix::Int)::Vector{Int}
    decoded = Int[]
    pos = 1
    buffer = 8
    nx = npix
    fsbits = 5
    fsmax = 25
    nblock = 8
    bbits = 1 << fsbits

    #Decode the initial value
    initial, pos, buffer = binary_decode(encoded, bbits, pos, buffer)
    # push!(decoded, initial)
    lastpix = initial

    thisblock = nblock
    i = 0
    while(i <= nx)
        if (nx-i < nblock) 
            thisblock = nx-i
        end
	    pos, buffer, lastpix = decode_block(encoded, decoded, pos, buffer, lastpix, thisblock, fsmax, fsbits)
        i += nblock
    end

    return decoded
end

end  # module