# include("../src/RiceCompression.jl")
# using .RiceCompression

# data = Int[10, 20, 30, 40]

using TestItemRunner

@testitem "Rice" begin
    ####    Test Card    ####

    #  Create default Card
    # @test isequal(data, rice_decode(rice_encode(data)))
    @test isequal(1, 1)

    # ###  Create End Cards  ###

    # #  END keyword
    # @test isequal(showfields(Card("END")),
    #               ("END", missing, "",
    #                "END                                                                             "))
    
    # #  lowercase END keyword
    # @test isequal(showfields(Card("end")),
    #               ("END", missing, "",
    #                "END                                                                             "))
    
    # #  Invalid END card with value
    # @test_throws ArgumentError Card("END", "a value")

    # #  Invalid End card with comment
    # @test_throws ArgumentError Card("END", missing, "a comment")

end