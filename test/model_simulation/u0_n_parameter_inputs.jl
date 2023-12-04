#! format: off

### Fetch Packages and Reaction Networks ###

# Fetch packages.
using Catalyst, OrdinaryDiffEq, Random, Test
using ModelingToolkit: get_states, get_ps

# Sets rnd number.
using StableRNGs
rng = StableRNG(12345)

# Fetch test networks.
include("../test_networks.jl")

### Run Tests ###

# Tests various ways to input u0 and p for various functions.
let
    test_network = reaction_networks_standard[7]
    test_osys = convert(ODESystem, test_network)
    @parameters p1 p2 p3 k1 k2 k3 v1 K1 d1 d2 d3 d4 d5
    @variables t
    @species X1(t) X2(t) X3(t) X4(t) X5(t) X6(t) X(t)

    for factor = [1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3]
        u0_1 = factor*rand(rng,length(get_states(test_network)))
        u0_2 = [X1=>u0_1[1], X2=>u0_1[2], X3=>u0_1[3], X4=>u0_1[4], X5=>u0_1[5]]
        u0_3 = [X2=>u0_1[2], X5=>u0_1[5], X4=>u0_1[4], X3=>u0_1[3], X1=>u0_1[1]]
        p_1 = 0.01 .+ factor*rand(rng,length(get_ps(test_network)))
        p_2 = [p1=>p_1[1], p2=>p_1[2], p3=>p_1[3], k1=>p_1[4], k2=>p_1[5], k3=>p_1[6],
            v1=>p_1[7], K1=>p_1[8], d1=>p_1[9], d2=>p_1[10], d3=>p_1[11], d4=>p_1[12],
            d5=>p_1[13]]
        p_3 = [k2=>p_1[5], k3=>p_1[6], v1=>p_1[7], d5=>p_1[13], p2=>p_1[2], p1=>p_1[1],
            d2=>p_1[10], K1=>p_1[8], d1=>p_1[9], d4=>p_1[12], d3=>p_1[11], p3=>p_1[3],
            k1=>p_1[4]]

        sols = []
        push!(sols,solve(ODEProblem(test_osys,u0_1,(0.,10.),p_1),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_1,(0.,10.),p_2),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_1,(0.,10.),p_3),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_2,(0.,10.),p_1),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_2,(0.,10.),p_2),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_2,(0.,10.),p_3),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_3,(0.,10.),p_1),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_3,(0.,10.),p_2),Rosenbrock23()))
        push!(sols,solve(ODEProblem(test_osys,u0_3,(0.,10.),p_3),Rosenbrock23()))

        ends = map(sol -> sol.u[end],sols)
        for i in 1:length(u0_1)
            @test abs(maximum(getindex.(ends,1))-minimum(first.(getindex.(ends,1)))) < 1e-5
        end

        u0_1 = rand(rng,1:Int64(factor*100),length(get_states(test_network)))
        u0_2 = [X1=>u0_1[1], X2=>u0_1[2], X3=>u0_1[3], X4=>u0_1[4], X5=>u0_1[5]]
        u0_3 = [X2=>u0_1[2], X5=>u0_1[5], X4=>u0_1[4], X3=>u0_1[3], X1=>u0_1[1]]

        discrete_probs = []
        push!(discrete_probs,DiscreteProblem(test_network,u0_1,(0.,1.),p_1))
        push!(discrete_probs,DiscreteProblem(test_network,u0_1,(0.,1.),p_2))
        push!(discrete_probs,DiscreteProblem(test_network,u0_1,(0.,1.),p_3))
        push!(discrete_probs,DiscreteProblem(test_network,u0_2,(0.,1.),p_1))
        push!(discrete_probs,DiscreteProblem(test_network,u0_2,(0.,1.),p_2))
        push!(discrete_probs,DiscreteProblem(test_network,u0_2,(0.,1.),p_3))
        push!(discrete_probs,DiscreteProblem(test_network,u0_3,(0.,1.),p_1))
        push!(discrete_probs,DiscreteProblem(test_network,u0_3,(0.,1.),p_2))
        push!(discrete_probs,DiscreteProblem(test_network,u0_3,(0.,1.),p_3))

        for i in 2:9
            @test discrete_probs[1].p == discrete_probs[i].p
            @test discrete_probs[1].u0 == discrete_probs[i].u0
        end
    end
end

# Tests uding mix of symbols and symbolics in input.
let
    test_network = @reaction_network begin 
        (p1, d1), 0 ↔ X1 
        (p2, d2), 0 ↔ X2 
    end
    @unpack p1, d1, p2, d2, X1, X2 = test_network
    u0_1 = [X1 => 0.7, X2 => 3.6]
    u0_2 = [:X1 => 0.7, X2 => 3.6]
    u0_3 = [:X1 => 0.7, :X2 => 3.6]
    p_1 = [p1 => 1.2, d1 => 4.0, p2 => 2.5, d2 =>0.1]
    p_2 = [:p1 => 1.2, d1 => 4.0, :p2 => 2.5, d2 =>0.1]
    p_3 = [:p1 => 1.2, :d1 => 4.0, :p2 => 2.5, :d2 =>0.1]

    ss_base = solve(ODEProblem(test_network, u0_1, (0.0, 10.0), p_1), Tsit5())[end]
    for u0 in [u0_1, u0_2, u0_3], p in [p_1, p_2, p_3]
        @test ss_base == solve(ODEProblem(test_network, u0, (0.0, 10.0), p), Tsit5())[end]
    end
end