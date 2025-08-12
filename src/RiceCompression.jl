module RiceCompression

export encode, decode, Rice

abstract type CompressionType end
abstract type Rice <: CompressionType end

"""
    write!(encoded::Array{UInt8}, value::Integer, bit_length::Integer, pos::Integer, buffer::UInt8)

Encodes the integer using bit_length bits in binary (MSB first).
"""
function write!(encoded::Array{UInt8}, value::Integer, bit_length::Integer, pos::Integer, buffer::UInt8)
    while(bit_length >= buffer)
        bit_length -= buffer
        encoded[pos] = encoded[pos] | (value >> bit_length)
        value = value & ((1 << bit_length)-1)
        buffer::UInt8 = 8
        pos += 1
    end
    if(bit_length > 0)
        encoded[pos] = encoded[pos] | (value << (buffer - bit_length))
        buffer -= bit_length
    end
    return encoded, pos, buffer
end


"""
    encode_value!(encoded::Array{UInt8}, value::Integer, fs::Integer, pos::Integer, buffer::UInt8)

Encodes the given value using Rice compression.
"""
function encode_value!(encoded::Array{UInt8}, value::Integer, fs::Integer, pos::Integer, buffer::UInt8)
    #Calculate the quotient
    q = value >> fs
    #Encode quotient
    for _ in 1:q
        encoded, pos, buffer = write!(encoded, 1, 1, pos, buffer)
    end
    encoded, pos, buffer = write!(encoded, 0, 1, pos, buffer)
    #Encode remainder
    encoded, pos, buffer = write!(encoded, value & ((1 << fs) -1), fs, pos, buffer)
    return encoded, pos, buffer
end

"""
    unsign(value::Int)

Converts a positive or negative integer into a positive integer for Rice Compression
"""
function unsign(value::Integer)
    return ((value<0) ? ~(value<<1) : (value<<1))
end

"""
    calc_fs(data::Vector{<:Integer}, lastpix::Integer)

Calculates an appropriate fs value based on the average difference between adjacent pixels.
"""
function calc_fs(data::Vector{<:Integer}, lastpix::Integer)
    fs = 0
    pixelsum = 0.0
    size = length(data)
    diff = zeros(Int, size)

    for j in eachindex(data)
	    nextpix = data[j]
	    pdiff = nextpix - lastpix
	    diff[j] = ((pdiff<0) ? ~(pdiff<<1) : (pdiff<<1))
	    pixelsum += diff[j]
	    lastpix = nextpix
    end
    dpsum = (pixelsum - (size/2) - 1)/size;
	if (dpsum < 0) 
        dpsum = 0.0
    end
	psum = (trunc(UInt,dpsum)) >> 1

    #Calculate fs based on the average pixel difference
	while psum>0
        psum >>= 1
        fs += 1
    end
    return fs, lastpix, diff
end

"""
    encode(::Type{Rice}, data::AbstractVector{<:Integer})

Encodes a vector of integers using the Rice compression algorithm.
"""
function encode(::Type{Rice}, data::AbstractVector{<:Integer})

    #Assign constants based on Int type
    typelen = sizeof(eltype(data))*8
    fsmax = typelen - 2
    fsbits = ndigits(typelen, base = 2) - 1
    bbits = 1 << fsbits

    #Initialize encoding variables
    encoded::Array{UInt8} = zeros(UInt8, sizeof(eltype(data))*length(data)*2)
    pos = 1
    buffer::UInt8 = 8

    #Encode the initial entry
    lastpix = data[1]
    encoded, pos, buffer = write!(encoded, lastpix, bbits, pos, buffer)

    fs, lastpix, diff = calc_fs(data, lastpix)

    #High entropy case when fs > fsmax, encode pixel differences directly
    if fs > fsmax
        encoded, pos, buffer = write!(encoded, fsmax + 1, fsbits, pos, buffer)
        for x in diff
            encoded, pos, buffer = write!(encoded, x, bbits, pos, buffer)
        end

    #Standard case, encode differences using rice compression
    else
        encoded, pos, buffer = write!(encoded, fs, fsbits, pos, buffer)
        for x in diff
            encoded, pos, buffer = encode_value!(encoded, x, fs, pos, buffer)
        end
    end
    return encoded[1:pos]
end

"""
    unary_decode!(encoded::Array{UInt8}, pos::Integer, buffer::UInt8)

Decodes the unary-coded integer starting at element `pos`, bit `buffer`.
Returns the decoded integer and the updated position.
"""
function unary_decode!(encoded::Array{UInt8}, pos::Integer, buffer::UInt8)
    value = 0
    bit = 1
    while(bit == 1)
        if(buffer <= 0)
            pos += 1
            buffer::UInt8 = 8
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
    binary_decode!(encoded::Array{UInt8}, fs::Integer, pos::Integer, buffer::UInt8)

Decodes a fs-bit binary integer starting at element `pos`, bit `buffer`.
Returns the decoded integer and the updated position.
"""
function binary_decode!(encoded::Array{UInt8}, fs::Integer, pos::Integer, buffer::UInt8)
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
        buffer::UInt8 = 8
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
    decode_value!(encoded::Array{UInt8}, fs::Integer, pos::Integer, buffer::UInt8)

Decodes a value using Rice compression with the given fs value.
"""
function decode_value!(encoded::Array{UInt8}, fs::Integer, pos::Integer, buffer::UInt8)
    q, pos, buffer = unary_decode!(encoded, pos, buffer)
    r, pos, buffer = binary_decode!(encoded, fs, pos, buffer)
    value = q << fs | r
    return resign(value), pos, buffer
end

"""
    resign(value::Integer)

Reverses the unsign function to return a positive or negative integer
"""
function resign(value::Integer)
    if ((value & 1) == 0)
		value = value>>1;
	else
		value = ~(value>>1);
    end
    return value
end


"""
    decode(::Type{Rice}, encoded::Array{UInt8}, nx::Integer, type::Type)

Decodes a Rice-coded UInt8 array into its original integer array.
"""
function decode(::Type{Rice}, encoded::Array{UInt8}, nx::Integer, type::Type)
    #Assign constants based on Int type
    typelen = sizeof(type)*8
    fsmax = typelen - 2
    fsbits = ndigits(typelen, base = 2) - 1
    bbits = 1 << fsbits

    #Initialize decoding variables
    decoded = zeros(type, nx)
    pos = 1
    buffer::UInt8 = 8

    #Decode the initial value
    initial, pos, buffer = binary_decode!(encoded, bbits, pos, buffer)
    lastpix = initial

    #Decode the fs value
    fs, pos, buffer = binary_decode!(encoded, fsbits, pos, buffer)

    #High entropy case, values written directly in binary
    if(fs > fsmax)
        for i in 1:nx
            diff, pos, buffer = binary_decode!(encoded, bbits, pos, buffer)
            println(resign(diff))
            lastpix += resign(diff)
            decoded[i] = lastpix
        end
    #Standard case, decode from rice compression
    else
        for i in 1:nx
            diff, pos, buffer = decode_value!(encoded, fs, pos, buffer)
            lastpix += diff
            decoded[i] = lastpix
        end
    end
    
    return decoded
end

end  # module