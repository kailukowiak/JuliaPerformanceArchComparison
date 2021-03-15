### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ 340883b6-84ed-11eb-0142-f59cf6156b77
begin
	using BenchmarkTools
	using Random
	using DataFrames
	using CSV
	using PlutoUI
	using Plots
	using StatsPlots
end

# ╔═╡ 1b5a5134-84ed-11eb-2f45-076ca2ffa530
md"# Julia Performance Comparison 

## Comparing M1 Rosetta 2 and ThinkPad with POP!_OS Environments

Quick, not super scientific comparison of the performance comparisons between Julia running on Apple's new silicon, `M1`, `Rosetta 2` and native julia on `x86` on a ThinkPad X1 Extreme Gen1 on Windows and POP!_OS. 

This notebook was roughtly inspired by the excelent benchmarking from [this](https://github.com/mitmath/18S096/blob/409bf1c1cbc8ed0f70afeb0f885ddc382f5138be/lectures/lecture1/Boxes-and-registers.ipynb) notebook and the excelent [Micro-Benchmarks](https://julialang.org/benchmarks/).

If you have a platform you'd like to test (e.g., 2019 MBP 13 Inch) make a copy of this notebook, save it with the computer name, run it and make a PR.

## Setup

### Add Modules"

# ╔═╡ 4c7b49e4-84ed-11eb-14d5-1d52010ac2db
function system_stats()
    println("System Archeticture is $(Sys.ARCH)")
    println("System CPU name is $(Sys.CPU_NAME)")
    println("Systemn OS is $(Sys.MACHINE)")
    println("System Kernel is $(Sys.KERNEL)")
    println("System Memory is $(Sys.free_memory()*10e-9) Gb") # TODO Error
end

# ╔═╡ 4fac50ea-84ed-11eb-23c0-935f3fdb4f9f
with_terminal() do
	system_stats()
end

# ╔═╡ 898ba794-850c-11eb-2645-816d8f70eff9
with_terminal() do
	versioninfo(verbose=true)
end

# ╔═╡ c939869e-84ed-11eb-2c8b-3727009f9643
df =  DataFrame(func = String[], seconds = Float64[])

# ╔═╡ f0cfbfc0-8506-11eb-1f73-4de8037e90c2
md"## Sum Test

A simple `sum` operation over a large array.

## UDF Testing

I found some interesting differences between well written (for my at least) Julia functions and ones with type instability. Starting off with type unstable ones:"

# ╔═╡ ffd74506-8506-11eb-0022-f9a29f51f8c8
function mysum(x)
    ans = 0
    for i ∈ x
        ans += i
    end
    return ans
end

# ╔═╡ 0b2ef40a-8507-11eb-0541-35a82a345cc9
begin
	Random.seed!(42)
	x = rand(10^7)
end

# ╔═╡ 14d8756a-8507-11eb-08c1-a776b6b940ca
@benchmark mysum($x)

# ╔═╡ 1cdd1374-8507-11eb-3ae8-5109e8587a84
md"The `@benchmark` macro is great, however it actually contains more info than we need. Generally, the min time for any execution is the best representative of the over all performance as longer execution times are usually caused by competing resources (other programs). To get around this I'm goign to use `@bellapsed` instead which only returns the min time."

# ╔═╡ 2b357cae-8507-11eb-1445-839a6a188610
push!(df, ("mysum", @belapsed mysum($x)))

# ╔═╡ 4146e4c4-8507-11eb-3b3c-df8d3d73c664
with_terminal() do
	@code_warntype mysum(x)
end

# ╔═╡ 5479446c-8507-11eb-06c0-a1f25a880a25
with_terminal() do
	@code_llvm mysum(x)
end

# ╔═╡ 6079ac5a-8507-11eb-0768-8b68659d3c6e
md"We can see we have type instability, lets fix it."

# ╔═╡ 93998d46-8507-11eb-0427-c5344ace950d
function mysum_ts(x)
    ans = zero(eltype(x))
    for i ∈ x
        ans += i
    end
    return ans
end

# ╔═╡ 7d26d6a2-8507-11eb-2c9d-3b3177f6254d
push!(df, ("mysum_ts", @belapsed mysum_ts($x)))

# ╔═╡ 7d1102b4-8507-11eb-0724-b3736789a9d6
with_terminal() do
	@code_warntype mysum_ts(x)
end

# ╔═╡ bd1258ea-8507-11eb-0044-3d3aa12607ea
md"Finally, we can get very close to Julia's native `sum` by adding single instruction, multiple distpatch
(SIMD) which allows for the CPU to perform the same operation on multiple input data points, almost as a form of parralelism. "

# ╔═╡ ba1cf492-8507-11eb-09e0-11e38b463e26
function mysum_simd(x)
    ans = zero(eltype(x))
    @simd for i ∈ x
        ans += i
    end
    return ans
end

# ╔═╡ c6b27706-8507-11eb-21fd-8d48e5d897f7
push!(df, ("mysum_simd", @belapsed mysum_simd($x)))

# ╔═╡ e27e9ecc-8507-11eb-340d-e30b2dc4a6d9
X = rand(1_000, 1_000)

# ╔═╡ e4a7bbb4-8507-11eb-24d7-e51ed7405490
push!(df, ("inv", @belapsed inv($X)))

# ╔═╡ fd04bca4-8507-11eb-3254-f178eee7eae4
push!(df, ("matmul", @belapsed $X * $X))

# ╔═╡ 0ddc1ea2-8508-11eb-2742-0740b7b15a05
md"## Micro-Benchmarks

### Recursib Fibonacci 

Let's see how Julia performs on other algorithms."

# ╔═╡ 061cd2ea-8508-11eb-24d7-9b00183e11b8
fib(n) = n < 2 ? n : fib(n-1) + fib(n-2)

# ╔═╡ 133c6a76-8508-11eb-0b6e-f19fc978e7d9
push!(df, ("fib", @belapsed fib($20)))

# ╔═╡ 27f41ad8-8508-11eb-0829-b93730409e2f
md"### Quick Sort"

# ╔═╡ 2e5c1542-8508-11eb-0162-eb67c2b76c3b
function qsort!(a,lo,hi)
    i, j = lo, hi
    while i < hi
        pivot = a[(lo+hi)>>>1]
        while i <= j
            while a[i] < pivot; i += 1; end
            while a[j] > pivot; j -= 1; end
            if i <= j
                a[i], a[j] = a[j], a[i]
                i, j = i+1, j-1
            end
        end
        if lo < j; qsort!(a,lo,j); end
        lo, j = i, hi
    end
    return a
end

# ╔═╡ 34418026-8508-11eb-0ef4-1bcb713ef479
sortperf(n) = qsort!(rand(n), 1, n)

# ╔═╡ 34ff4dd6-8508-11eb-0156-b3bfecf6c38e
push!(df, ("quicksort", @belapsed sortperf(1000)))

# ╔═╡ 526bc716-8508-11eb-3366-35a0ca0d4da4
begin
	df[:, "arch"] .= Sys.ARCH
	df[:, "machine"] .= Sys.MACHINE
	df[:, "kernel"] .= Sys.KERNEL
	df[:, "julia_version"] .= VERSION
	df
end

# ╔═╡ 6193a84c-8508-11eb-1554-8bd0e700cab2
CSV.write(pwd() * "/data/" * Sys.MACHINE * "performance.csv", df)

# ╔═╡ ccfe62ca-850d-11eb-1e5e-d3da5e794736
csv_files = readdir("data/")

# ╔═╡ a30bef54-850e-11eb-3fca-49a5afed98ae
dfs = DataFrame.(CSV.File.("data/" .* csv_files))

# ╔═╡ 16690c66-850f-11eb-292a-edbe1d4f95dc
benchs = vcat(dfs...)

# ╔═╡ 393655fc-8533-11eb-17b4-49ae548ab264
groupedbar(benchs.func, benchs.seconds, group = benchs.machine, yscale=:log)

# ╔═╡ Cell order:
# ╟─1b5a5134-84ed-11eb-2f45-076ca2ffa530
# ╠═340883b6-84ed-11eb-0142-f59cf6156b77
# ╠═4c7b49e4-84ed-11eb-14d5-1d52010ac2db
# ╠═4fac50ea-84ed-11eb-23c0-935f3fdb4f9f
# ╠═898ba794-850c-11eb-2645-816d8f70eff9
# ╠═c939869e-84ed-11eb-2c8b-3727009f9643
# ╠═f0cfbfc0-8506-11eb-1f73-4de8037e90c2
# ╠═ffd74506-8506-11eb-0022-f9a29f51f8c8
# ╠═0b2ef40a-8507-11eb-0541-35a82a345cc9
# ╠═14d8756a-8507-11eb-08c1-a776b6b940ca
# ╠═1cdd1374-8507-11eb-3ae8-5109e8587a84
# ╠═2b357cae-8507-11eb-1445-839a6a188610
# ╠═4146e4c4-8507-11eb-3b3c-df8d3d73c664
# ╠═5479446c-8507-11eb-06c0-a1f25a880a25
# ╟─6079ac5a-8507-11eb-0768-8b68659d3c6e
# ╠═93998d46-8507-11eb-0427-c5344ace950d
# ╠═7d26d6a2-8507-11eb-2c9d-3b3177f6254d
# ╠═7d1102b4-8507-11eb-0724-b3736789a9d6
# ╠═bd1258ea-8507-11eb-0044-3d3aa12607ea
# ╠═ba1cf492-8507-11eb-09e0-11e38b463e26
# ╠═c6b27706-8507-11eb-21fd-8d48e5d897f7
# ╠═e27e9ecc-8507-11eb-340d-e30b2dc4a6d9
# ╠═e4a7bbb4-8507-11eb-24d7-e51ed7405490
# ╠═fd04bca4-8507-11eb-3254-f178eee7eae4
# ╠═0ddc1ea2-8508-11eb-2742-0740b7b15a05
# ╠═061cd2ea-8508-11eb-24d7-9b00183e11b8
# ╠═133c6a76-8508-11eb-0b6e-f19fc978e7d9
# ╠═27f41ad8-8508-11eb-0829-b93730409e2f
# ╠═2e5c1542-8508-11eb-0162-eb67c2b76c3b
# ╠═34418026-8508-11eb-0ef4-1bcb713ef479
# ╠═34ff4dd6-8508-11eb-0156-b3bfecf6c38e
# ╠═526bc716-8508-11eb-3366-35a0ca0d4da4
# ╠═6193a84c-8508-11eb-1554-8bd0e700cab2
# ╠═ccfe62ca-850d-11eb-1e5e-d3da5e794736
# ╠═a30bef54-850e-11eb-3fca-49a5afed98ae
# ╠═16690c66-850f-11eb-292a-edbe1d4f95dc
# ╠═393655fc-8533-11eb-17b4-49ae548ab264
