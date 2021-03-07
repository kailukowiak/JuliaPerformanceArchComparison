##
using BenchmarkTools
using Random
##
function mysum(x)
    ans = 0
    for i ∈ x
        ans += i
    end
    return ans
end
##
Random.seed!(42)
x = rand(10^7)
##
@benchmark mysum(x)