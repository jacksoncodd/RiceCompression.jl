module BasicRiceCompression

export rice_encode, rice_decode


"""
    unary_encode(input::Int)::BitVector

Encodes the integer using unary coding: `input` 1s followed by a 0.
"""
function unary_encode(input::Int)::BitVector
    return BitVector(vcat(fill(true, input), false))
end


"""
    binary_encode(input::Int, k::Int)::BitVector

Encodes the integer using k bits in binary (MSB first).
"""
function binary_encode(input::Int, k::Int)::BitVector
    bits = BitVector()
    for i in k-1:-1:0
        push!(bits, (input >> i) & 1 == 1)
    end
    return bits
end


"""
    encode_value(input::Int, k::Int, encoded::BitVector)

Encodes the given value using Rice compression.
"""
function encode_value(value::Int, k::Int, encoded::BitVector)
    append!(encoded, unary_encode(value >> k))
    append!(encoded, binary_encode(value & ((1 << k) -1), k))
end


"""
    rice_encode(data::Vector{Int})::BitVector

Encodes an array of integers using Rice coding.
Returns a BitVector to optimize space usage.
"""
function rice_encode(data::Vector{Int})::BitVector
    encoded = BitVector()  # Initialize an empty BitVector
    k = ndigits(data[1], base = 2) - 1

    append!(encoded, unary_encode(k))

    encode_value.(data, k, Ref(encoded))
    return encoded  # Explicitly convert to BitVector
end


"""
    unary_decode(encoded::BitVector, pos::Int)::Tuple{Int, Int}

Decodes the unary-coded integer starting at `pos`.
Returns the decoded integer and the updated position.
"""
function unary_decode(encoded::BitVector, pos::Int)::Tuple{Int, Int}
    output = 0
    while pos <= length(encoded) && encoded[pos]
        output += 1
        pos += 1
    end
    return output, pos + 1  # Skip the terminating 0
end


"""
    binary_decode(encoded::BitVector, pos::Int, k::Int)::Tuple{Int, Int}

Decodes a k-bit binary integer starting at `pos`.
Returns the decoded integer and the updated position.
"""
function binary_decode(encoded::BitVector, pos::Int, k::Int)::Tuple{Int, Int}
    output = 0
    for _ in 1:k
        output = (output << 1) | (encoded[pos] ? 1 : 0)
        pos += 1
    end
    return output, pos
end


"""
    decode_value(pos::Int, k::Int, encoded::BitVector)::Tuple{Int, Int}

Decodes a value using Rice compression.
"""
function decode_value(pos::Int, k::Int, encoded::BitVector)::Tuple{Int, Int}
    q, pos = unary_decode(encoded, pos)
    r, pos = binary_decode(encoded, pos, k)
    value = q << k | r
    return value, pos
end


"""
    rice_decode(encoded::BitVector, k::Int)::Vector{Int}

Decodes a Rice-coded bit stream into its original integer array.
"""
function rice_decode(encoded::BitVector)::Vector{Int}
    decoded = Int[]
    pos = 1
    k, pos = unary_decode(encoded, pos)

    while pos <= length(encoded)
        value, pos = decode_value(pos, k, encoded)
        push!(decoded, value)
    end

    return decoded
end

end  # module