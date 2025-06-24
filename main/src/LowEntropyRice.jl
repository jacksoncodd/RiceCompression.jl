# module RiceCompression

# export rice_encode, rice_decode

# function encode_unary(quotient::Int)
#     # Unary encoding for the quotient
#     unary = fill(true, quotient)  # Create a vector of `true` of length quotient
#     return vcat(unary, false)      # Append a `false` to signify the end of unary encoding
# end

# function encode_binary(remainder::Int, k::Int)
#     # Binary encoding for the remainder
#     binary = Bool[]
#     for i in k-1:-1:0
#         push!(binary, isone((remainder >> i) & 1))
#     end
#     return binary
# end

# function rice_encode(data::Vector{Int}, k::Int)
#     # Ensure k is a positive integer
#     if k <= 0
#         throw(ArgumentError("k must be a positive integer"))
#     end

#     # Calculate the Rice parameter
#     rice_param = 2^k

#     # Initialize the encoded array
#     encoded = Bool[]

#     for value in data
#         quotient = div(value, rice_param)
#         remainder = value % rice_param

#         # Append unary and binary encodings to the encoded array
#         append!(encoded, encode_unary(quotient))
#         append!(encoded, encode_binary(remainder, k))
#     end

#     return encoded
# end

# function decode_unary(encoded::Vector{Bool}, start::Int)
#     i = start

#     # Decode unary part
#     quotient = 0
#     while i <= length(encoded) && encoded[i]
#         quotient += 1
#         i += 1
#     end

#     if i > length(encoded) || encoded[i] != false
#         throw(ArgumentError("Invalid unary encoding"))
#     end

#     # Move to the next part (after the unary terminator)
#     i += 1

#     return quotient, i
# end

# function decode_binary(encoded::Vector{Bool}, start::Int, k::Int)
#     remainder = 0
#     for j in 0:k-1
#         if start + j > length(encoded)
#             throw(ArgumentError("Invalid binary encoding"))
#         end
#         remainder = (remainder << 1) | (encoded[start + j] ? 1 : 0)
#     end

#     return remainder, start + k
# end

# function rice_decode(encoded::Vector{Bool}, k::Int)
#     # Ensure k is a positive integer
#     if k <= 0
#         throw(ArgumentError("k must be a positive integer"))
#     end

#     # Calculate the Rice parameter
#     rice_param = 2^k

#     # Initialize the decoded array
#     decoded = Int[]

#     i = 1
#     while i <= length(encoded)
#         # Decode unary part
#         quotient, next_pos = decode_unary(encoded, i)

#         # Decode binary part
#         remainder, next_pos = decode_binary(encoded, next_pos, k)

#         # Calculate the original value
#         value = quotient * rice_param + remainder
#         push!(decoded, value)

#         i = next_pos
#     end

#     return decoded
# end

# end  # module

# Source for Rice Algorithm: https://michaeldipperstein.github.io/rice.html

module LowEntropyRice

export rice_encode, rice_decode

using Base: summarysize
using TestItemRunner


# """
#     encode_unary(input::Int)::BitVector

# Encodes the integer using unary coding: `input` 1s followed by a 0.
# """
# function unary_encode(input::Int)::BitVector
#     return BitVector(vcat(fill(true, input), false))
# end


"""
    encode_binary(input::Int, k::Int)::BitVector

Encodes the integer using k bits in binary (MSB first).
"""
function binary_encode(input::Int, k::Int)::BitVector
    bits = BitVector()
    for i in k-1:-1:0
        diff = ((input<0) ? ~(input<<1) : (input<<1))
        push!(bits, (diff >> i) & 1 == 1)
    end
    return bits
end


"""
    encode_value(input::Int, k::Int, divisor::Int, encoded::BitVector)

Encodes the given value using Rice compression.
"""
function encode_value(value::Int, k::Int, encoded::BitVector)

    # println("Encoding: ", value)
    append!(encoded, binary_encode(value, k))
end


"""
    rice_encode(data::Vector{Int}, k::Int)::BitVector

Encodes an array of integers using Rice coding with parameter k.
Returns a BitVector to optimize space usage.
"""
function rice_encode(data::Vector{Int})::BitVector
    encoded = BitVector()  # Initialize an empty BitVector
    k = ndigits(data[1], base = 2) - 1

    #Encode the k value
    append!(encoded, unary_encode(k))

    #Encode the initial entry in the BitVector
    encode_value(data[1], k, encoded)

    for i in 2:length(data)
        #Encode the difference between this and the last entry
        encode_value(data[i]-data[i-1], k, encoded)
    end
    return encoded  # Explicitly convert to BitVector
end


# """
#     decode_unary(encoded::BitVector, pos::Int)::Tuple{Int, Int}

# Decodes the unary-coded integer starting at `pos`.
# Returns the decoded integer and the updated position.
# """
# function unary_decode(encoded::BitVector, pos::Int)::Tuple{Int, Int}
#     output = 0
#     while pos <= length(encoded) && encoded[pos]
#         output += 1
#         pos += 1
#     end
#     return output, pos + 1  # Skip the terminating 0
# end


"""
    decode_binary(encoded::BitVector, pos::Int, k::Int)::Tuple{Int, Int}

Decodes a k-bit binary integer starting at `pos`.
Returns the decoded integer and the updated position.
"""
function binary_decode(encoded::BitVector, pos::Int, k::Int)::Tuple{Int, Int}
    output = 0
    for _ in 1:k
        output = (output << 1) | (encoded[pos] ? 1 : 0)
        pos += 1
    end
    if ((output & 1) == 0)
		output = output>>1
    else
		output = ~(output>>1)
    end
    return output, pos
end


"""
    encode_value(pos::Int, k::Int, divisor::Int, encoded::BitVector)::Tuple{Int, Int}

Encodes the given value using Rice compression.
"""
function decode_value(pos::Int, k::Int, encoded::BitVector)::Tuple{Int, Int}
    value, pos = binary_decode(encoded, pos, k)
    return value, pos
end


"""
    rice_decode(encoded::BitVector, k::Int)::Vector{Int}

Decodes a Rice-coded bit stream into its original integer array.
"""
function rice_decode(encoded::BitVector)::Vector{Int}
    decoded = Int[]
    pos = 1

    #Decode the k value
    k, pos = unary_decode(encoded, pos)

    #Decode the initial value
    initial, pos = decode_value(pos, k, encoded)
    push!(decoded, initial)
    last = initial

    while pos <= length(encoded)
        #Solve for each entry by adding the difference to the previous entry
        difference, pos = decode_value(pos, k, encoded)
        current = last + difference
        push!(decoded, current)
        last = current
    end

    return decoded
end

end  # module



# Testing the implementation
using ..RiceCompression

# Test array
data = Int[100, 101, 102, 103, 104, 200, 205, 208, 300, 306, 500, 502, 510, 1603, 1600, 1603, 1600]

# Encoding
compressed = RiceCompression.rice_encode(data)

# Decoding
decoded = RiceCompression.rice_decode(compressed)

println("Original Data: ", data)
println("Size of original data (bytes): ", summarysize(data))
println("Compressed Data: ", compressed)
println("Size of compressed data (bytes): ", summarysize(compressed))
println("Decoded Data: ", decoded)
println("Size of decoded data (bytes): ", summarysize(decoded))
println("Match: ", data == decoded)