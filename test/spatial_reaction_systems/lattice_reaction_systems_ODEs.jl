### Preparations ###

# Fetch packages.
using OrdinaryDiffEq
using Random, Statistics, SparseArrays, Test

# Fetch test networks.
include("../spatial_test_networks.jl")

# Sets rnd number.
using StableRNGs
rng = StableRNG(12345)

### Tests Simulations Don't Error ###
for grid in [small_2d_grid, short_path, small_directed_cycle, 
             small_1d_cartesian_grid, small_2d_cartesian_grid, small_3d_cartesian_grid,
             small_1d_regular_grid, small_2d_regular_grid, small_3d_regular_grid,
             random_2d_regular_grid]
    # Non-stiff case
    for srs in [Vector{TransportReaction}(), SIR_srs_1, SIR_srs_2]
        lrs = LatticeReactionSystem(SIR_system, srs, grid)
        u0_1 = [:S => 999.0, :I => 1.0, :R => 0.0]
        u0_2 = [:S => 500.0 .+ 500.0 * rand_v_vals(lrs.lattice), :I => 1.0, :R => 0.0]
        u0_3 = [
            :S => 950.0,
            :I => 50 * rand_v_vals(lrs.lattice),
            :R => 50 * rand_v_vals(lrs.lattice),
        ]
        u0_4 = [
            :S => 500.0 .+ 500.0 * rand_v_vals(lrs.lattice),
            :I => 50 * rand_v_vals(lrs.lattice),
            :R => 50 * rand_v_vals(lrs.lattice),
        ]
        u0_5 = make_u0_matrix(u0_3, vertices(lrs.lattice),
                              map(s -> Symbol(s.f), species(lrs.rs)))
        for u0 in [u0_1, u0_2, u0_3, u0_4, u0_5]
            p1 = [:α => 0.1 / 1000, :β => 0.01]
            p2 = [:α => 0.1 / 1000, :β => 0.02 * rand_v_vals(lrs.lattice)]
            p3 = [
                :α => 0.1 / 2000 * rand_v_vals(lrs.lattice),
                :β => 0.02 * rand_v_vals(lrs.lattice),
            ]
            p4 = make_u0_matrix(p1, vertices(lrs.lattice), Symbol.(parameters(lrs.rs)))
            for pV in [p1, p2, p3, p4]
                pE_1 = map(sp -> sp => 0.01, spatial_param_syms(lrs))
                pE_2 = map(sp -> sp => 0.01, spatial_param_syms(lrs))
                pE_3 = map(sp -> sp => rand_e_vals(lrs.lattice, 0.01),
                           spatial_param_syms(lrs))
                pE_4 = make_u0_matrix(pE_3, edges(lrs.lattice), spatial_param_syms(lrs))
                for pE in [pE_1, pE_2, pE_3, pE_4]
                    oprob = ODEProblem(lrs, u0, (0.0, 500.0), (pV, pE))
                    @test SciMLBase.successful_retcode(solve(oprob, Tsit5()))

                    oprob = ODEProblem(lrs, u0, (0.0, 10.0), (pV, pE); jac = false)
                    @test SciMLBase.successful_retcode(solve(oprob, Tsit5()))
                end
            end
        end
    end

    # Stiff case
    for srs in [Vector{TransportReaction}(), brusselator_srs_1, brusselator_srs_2]
        lrs = LatticeReactionSystem(brusselator_system, srs, grid)
        u0_1 = [:X => 1.0, :Y => 20.0]
        u0_2 = [:X => rand_v_vals(lrs.lattice, 10.0), :Y => 2.0]
        u0_3 = [:X => rand_v_vals(lrs.lattice, 20), :Y => rand_v_vals(lrs.lattice, 10)]
        u0_4 = make_u0_matrix(u0_3, vertices(lrs.lattice),
                              map(s -> Symbol(s.f), species(lrs.rs)))
        for u0 in [u0_1, u0_2, u0_3, u0_4]
            p1 = [:A => 1.0, :B => 4.0]
            p2 = [:A => 0.5 .+ rand_v_vals(lrs.lattice, 0.5), :B => 4.0]
            p3 = [
                :A => 0.5 .+ rand_v_vals(lrs.lattice, 0.5),
                :B => 4.0 .+ rand_v_vals(lrs.lattice, 1.0),
            ]
            p4 = make_u0_matrix(p2, vertices(lrs.lattice), Symbol.(parameters(lrs.rs)))
            for pV in [p1, p2, p3, p4]
                pE_1 = map(sp -> sp => 0.2, spatial_param_syms(lrs))
                pE_2 = map(sp -> sp => rand(rng), spatial_param_syms(lrs))
                pE_3 = map(sp -> sp => rand_e_vals(lrs.lattice, 0.2),
                           spatial_param_syms(lrs))
                pE_4 = make_u0_matrix(pE_3, edges(lrs.lattice), spatial_param_syms(lrs))
                for pE in [pE_1, pE_2, pE_3, pE_4]
                    oprob = ODEProblem(lrs, u0, (0.0, 10.0), (pV, pE))
                    @test SciMLBase.successful_retcode(solve(oprob, QNDF()))

                    oprob = ODEProblem(lrs, u0, (0.0, 10.0), (pV, pE); sparse = false)
                    @test SciMLBase.successful_retcode(solve(oprob, QNDF()))
                end
            end
        end
    end
end

### Tests Simulation Correctness ###

# Checks that non-spatial brusselator simulation is identical to all on an unconnected lattice.
let
    lrs = LatticeReactionSystem(brusselator_system, brusselator_srs_1, unconnected_graph)
    u0 = [:X => 2.0 + 2.0 * rand(rng), :Y => 10.0 + 10.0 * rand(rng)]
    pV = brusselator_p
    pE = [:dX => 0.2]
    oprob_nonspatial = ODEProblem(brusselator_system, u0, (0.0, 100.0), pV)
    oprob_spatial = ODEProblem(lrs, u0, (0.0, 100.0), (pV, pE))
    sol_nonspatial = solve(oprob_nonspatial, QNDF(); abstol = 1e-12, reltol = 1e-12)
    sol_spatial = solve(oprob_spatial, QNDF(); abstol = 1e-12, reltol = 1e-12)

    for i in 1:nv(unconnected_graph)
        @test all(isapprox.(sol_nonspatial.u[end],
                            sol_spatial.u[end][((i - 1) * 2 + 1):((i - 1) * 2 + 2)]))
    end
end

# Compares Jacobian and forcing functions of spatial system to analytically computed on.
let
    # Creates LatticeReactionNetwork ODEProblem.
    rs = @reaction_network begin
        pX, 0 --> X
        d, X --> 0
        pY*X, 0 --> Y
        d, Y --> 0
    end
    tr = @transport_reaction D X
    lattice = path_graph(3)
    lrs = LatticeReactionSystem(rs, [tr], lattice);

    D_vals = [0.2, 0.2, 0.3, 0.3]
    u0 = [:X => [1.0, 2.0, 3.0], :Y => 1.0]
    ps = [:pX => [2.0, 2.5, 3.0], :pY => 0.5, :d => 0.1, :D => D_vals]
    oprob = ODEProblem(lrs, u0, (0.0, 0.0), ps; jac=true, sparse=true)

    # Creates manual f and jac functions.
    function f_manual!(du, u, p, t)
        X1, Y1, X2, Y2, X3, Y3 = u
        pX, d, pY = p
        pX1, pX2, pX3 = pX
        pY, = pY
        d, = d
        D1, D2, D3, D4 = D_vals
        du[1] = pX1 - d*X1 - D1*X1 + D2*X2
        du[2] = pY*X1 - d*Y1
        du[3] = pX2 - d*X2 + D1*X1 - (D2+D3)*X2 + D4*X3 
        du[4] = pY*X2 - d*Y2
        du[5] = pX3 - d*X3 + D3*X2 - D4*X3 
        du[6] = pY*X3 - d*Y3
    end
    function jac_manual!(J, u, p, t)
        X1, Y1, X2, Y2, X3, Y3 = u
        pX, d, pY = p
        pX1, pX2, pX3 = pX
        pY, = pY
        d, = d
        D1, D2, D3, D4 = D_vals

        J .= 0.0

        J[1,1] = - d - D1
        J[1,2] = 0
        J[2,1] = pY
        J[2,2] = - d

        J[3,3] = - d - D2 - D3
        J[3,4] = 0
        J[4,3] = pY
        J[4,4] = - d

        J[5,5] = - d - D4
        J[5,6] = 0
        J[6,5] = pY
        J[6,6] = - d

        J[1,3] = D1
        J[3,1] = D2
        J[3,5] = D3
        J[5,3] = D4
    end

    # Sets test input values.
    u = rand(rng, 6)
    p = [rand(rng, 3), rand(rng, 1), rand(rng, 1)]

    # Tests forcing function.
    du1 = fill(0.0, 6)
    du2 = fill(0.0, 6)
    oprob.f(du1, u, p, 0.0)
    f_manual!(du2, u, p, 0.0)
    @test du1 ≈ du2

    # Tests Jacobian.
    J1 = deepcopy(oprob.f.jac_prototype)
    J2 = deepcopy(oprob.f.jac_prototype)
    oprob.f.jac(J1, u, p, 0.0)
    jac_manual!(J2, u, p, 0.0)
    @test J1 ≈ J2
end

# Checks that result becomes homogeneous on a connected lattice.
let
    lrs = LatticeReactionSystem(binding_system, binding_srs, undirected_cycle)
    u0 = [
        :X => 1.0 .+ rand_v_vals(lrs.lattice),
        :Y => 2.0 * rand_v_vals(lrs.lattice),
        :XY => 0.5,
    ]
    oprob = ODEProblem(lrs, u0, (0.0, 1000.0), binding_p; tstops = 0.1:0.1:1000.0)
    ss = solve(oprob, Tsit5()).u[end]

    @test all(isapprox.(ss[1:3:end], ss[1]))
    @test all(isapprox.(ss[2:3:end], ss[2]))
    @test all(isapprox.(ss[3:3:end], ss[3]))
end

# Checks that various combinations of jac and sparse gives the same result.
let
    lrs = LatticeReactionSystem(brusselator_system, brusselator_srs_1, small_2d_grid)
    u0 = [:X => rand_v_vals(lrs.lattice, 10), :Y => rand_v_vals(lrs.lattice, 10)]
    pV = brusselator_p
    pE = [:dX => 0.2]
    oprob = ODEProblem(lrs, u0, (0.0, 50.0), (pV, pE); jac = false, sparse = false)
    oprob_sparse = ODEProblem(lrs, u0, (0.0, 50.0), (pV, pE); jac = false, sparse = true)
    oprob_jac = ODEProblem(lrs, u0, (0.0, 50.0), (pV, pE); jac = true, sparse = false)
    oprob_sparse_jac = ODEProblem(lrs, u0, (0.0, 50.0), (pV, pE); jac = true, sparse = true)

    ss = solve(oprob, Rosenbrock23(); abstol = 1e-10, reltol = 1e-10).u[end]
    @test all(isapprox.(ss,
                        solve(oprob_sparse, Rosenbrock23(); abstol = 1e-10, reltol = 1e-10).u[end];
                        rtol = 0.0001))
    @test all(isapprox.(ss,
                        solve(oprob_jac, Rosenbrock23(); abstol = 1e-10, reltol = 1e-10).u[end];
                        rtol = 0.0001))
    @test all(isapprox.(ss,
                        solve(oprob_sparse_jac, Rosenbrock23(); abstol = 1e-10, reltol = 1e-10).u[end];
                        rtol = 0.0001))
end

# Checks that, when non directed graphs are provided, the parameters are re-ordered correctly.
let 
    # Create the same lattice (one as digraph, one not). Algorithm depends on Graphs.jl reordering edges, hence the jumbled order.
    lattice_1 = SimpleGraph(5)
    lattice_2 = SimpleDiGraph(5)

    add_edge!(lattice_1, 5, 2)
    add_edge!(lattice_1, 1, 4)
    add_edge!(lattice_1, 1, 3)
    add_edge!(lattice_1, 4, 3)
    add_edge!(lattice_1, 4, 5)

    add_edge!(lattice_2, 4, 1)
    add_edge!(lattice_2, 3, 4)
    add_edge!(lattice_2, 5, 4)
    add_edge!(lattice_2, 5, 2)
    add_edge!(lattice_2, 4, 3)
    add_edge!(lattice_2, 4, 5)
    add_edge!(lattice_2, 3, 1)
    add_edge!(lattice_2, 2, 5)
    add_edge!(lattice_2, 1, 4)
    add_edge!(lattice_2, 1, 3)

    lrs_1 = LatticeReactionSystem(SIR_system, SIR_srs_2, lattice_1)
    lrs_2 = LatticeReactionSystem(SIR_system, SIR_srs_2, lattice_2)

    u0 = [:S => 990.0, :I => 20.0 * rand_v_vals(lrs_1.lattice), :R => 0.0]
    pV = [:α => 0.1 / 1000, :β => 0.01]

    pE_1 = [:dS => [1.3, 1.4, 2.5, 3.4, 4.5], :dI => 0.01, :dR => 0.02]
    pE_2 = [:dS => [1.3, 1.4, 2.5, 1.3, 3.4, 1.4, 3.4, 4.5, 2.5, 4.5], :dI => 0.01, :dR => 0.02]
    ss_1 = solve(ODEProblem(lrs_1, u0, (0.0, 500.0), (pV, pE_1)), Tsit5()).u[end]
    ss_2 = solve(ODEProblem(lrs_2, u0, (0.0, 500.0), (pV, pE_2)), Tsit5()).u[end]
    @test all(isapprox.(ss_1, ss_2))
end

### Test Transport Reaction Types ###

# Compares where spatial reactions are created with/without the macro.
let
    @parameters dS dI
    @unpack S, I = SIR_system
    tr_1 = TransportReaction(dS, S)
    tr_2 = TransportReaction(dI, I)
    tr_macros_1 = @transport_reaction dS S
    tr_macros_2 = @transport_reaction dI I

    lrs_1 = LatticeReactionSystem(SIR_system, [tr_1, tr_2], small_2d_grid)
    lrs_2 = LatticeReactionSystem(SIR_system, [tr_macros_1, tr_macros_2], small_2d_grid)
    u0 = [:S => 990.0, :I => 20.0 * rand_v_vals(lrs_1.lattice), :R => 0.0]
    pV = [:α => 0.1 / 1000, :β => 0.01]
    pE = [:dS => 0.01, :dI => 0.01]
    ss_1 = solve(ODEProblem(lrs_1, u0, (0.0, 500.0), (pV, pE)), Tsit5()).u[end]
    ss_2 = solve(ODEProblem(lrs_2, u0, (0.0, 500.0), (pV, pE)), Tsit5()).u[end]
    @test all(isapprox.(ss_1, ss_2))
end

# Tries non-trivial diffusion rates.
let 
    SIR_tr_S_alt = @transport_reaction dS1+dS2 S
    SIR_tr_I_alt = @transport_reaction dI1*dI2 I
    SIR_tr_R_alt = @transport_reaction log(dR1)+dR2 R
    SIR_srs_2_alt = [SIR_tr_S_alt, SIR_tr_I_alt, SIR_tr_R_alt]
    lrs_1 = LatticeReactionSystem(SIR_system, SIR_srs_2, small_2d_grid)
    lrs_2 = LatticeReactionSystem(SIR_system, SIR_srs_2_alt, small_2d_grid)

    u0 = [:S => 990.0, :I => 20.0 * rand_v_vals(lrs_1.lattice), :R => 0.0]
    pV = [:α => 0.1 / 1000, :β => 0.01]
    pE_1 = [:dS => 0.01, :dI => 0.01, :dR => 0.01]
    pE_2 = [:dS1 => 0.005, :dS1 => 0.005, :dI1 => 2, :dI2 => 0.005, :dR1 => 1.010050167084168, :dR2 => 1.0755285551056204e-16]

    ss_1 = solve(ODEProblem(lrs_1, u0, (0.0, 500.0), (pV, pE_1)), Tsit5()).u[end]
    ss_2 = solve(ODEProblem(lrs_2, u0, (0.0, 500.0), (pV, pE_2)), Tsit5()).u[end]
    @test all(isapprox.(ss_1, ss_2))
end

# Tries various ways of creating TransportReactions.
let
    CuH_Amination_system_alt_1 = @reaction_network begin
        @species Newspecies1(t) Newspecies2(t)
        @parameters dCuoAc [edgeparameter=true] dLigand dSilane dStyrene dCu_ELigand
        10.0^kp1, CuoAc + Ligand --> CuoAcLigand
        10.0^kp2, CuoAcLigand + Silane --> CuHLigand + SilaneOAc
        10.0^k1, CuHLigand + Styrene --> AlkylCuLigand
        10.0^k_1, AlkylCuLigand --> CuHLigand + Styrene
        10.0^k2, AlkylCuLigand + Amine_E --> AlkylAmine + Cu_ELigand
        10.0^k_2, AlkylAmine + Cu_ELigand --> AlkylCuLigand + Amine_E
        10.0^k3, Cu_ELigand + Silane --> CuHLigand + E_Silane
        10.0^kam, CuHLigand + Amine_E --> Amine + Cu_ELigand
        10.0^kdc, CuHLigand + CuHLigand --> Decomposition
    end
    @unpack dLigand, dSilane, Silane = CuH_Amination_system_alt_1
    @parameters dAmine_E dNewspecies1
    @variables t
    @species Ligand(t) Amine_E(t) Newspecies1(t) 
    tr_alt_1_1 = TransportReaction(dLigand, Ligand)
    tr_alt_1_2 = TransportReaction(dSilane, Silane)
    tr_alt_1_3 = TransportReaction(dAmine_E, Amine_E)
    tr_alt_1_4 = TransportReaction(dNewspecies1, Newspecies1)
    tr_alt_1_5 = @transport_reaction dDecomposition Decomposition
    tr_alt_1_6 = @transport_reaction dCu_ELigand Cu_ELigand
    tr_alt_1_7 = @transport_reaction dNewspecies2 Newspecies2
    CuH_Amination_srs_alt_1 = [tr_alt_1_1, tr_alt_1_2, tr_alt_1_3, tr_alt_1_4, tr_alt_1_5, tr_alt_1_6, tr_alt_1_7]
    lrs_1 = LatticeReactionSystem(CuH_Amination_system_alt_1, CuH_Amination_srs_alt_1, small_2d_grid)

    CuH_Amination_system_alt_2 = @reaction_network begin
        @species Newspecies1(t) Newspecies2(t)
        @parameters dCuoAc [edgeparameter=true] dLigand dSilane dStyrene dCu_ELigand
        10.0^kp1, CuoAc + Ligand --> CuoAcLigand
        10.0^kp2, CuoAcLigand + Silane --> CuHLigand + SilaneOAc
        10.0^k1, CuHLigand + Styrene --> AlkylCuLigand
        10.0^k_1, AlkylCuLigand --> CuHLigand + Styrene
        10.0^k2, AlkylCuLigand + Amine_E --> AlkylAmine + Cu_ELigand
        10.0^k_2, AlkylAmine + Cu_ELigand --> AlkylCuLigand + Amine_E
        10.0^k3, Cu_ELigand + Silane --> CuHLigand + E_Silane
        10.0^kam, CuHLigand + Amine_E --> Amine + Cu_ELigand
        10.0^kdc, CuHLigand + CuHLigand --> Decomposition
    end
    @unpack Decomposition, dCu_ELigand, Cu_ELigand  = CuH_Amination_system_alt_2
    @parameters dNewspecies2 dDecomposition
    @variables t
    @species Newspecies2(t) 
    tr_alt_2_1 = @transport_reaction dLigand Ligand
    tr_alt_2_2 = @transport_reaction dSilane Silane
    tr_alt_2_3 = @transport_reaction dAmine_E Amine_E
    tr_alt_2_4 = @transport_reaction dNewspecies1 Newspecies1
    tr_alt_2_5 = TransportReaction(dDecomposition, Decomposition)
    tr_alt_2_6 = TransportReaction(dCu_ELigand, Cu_ELigand)
    tr_alt_2_7 = TransportReaction(dNewspecies2, Newspecies2)
    CuH_Amination_srs_alt_2 = [tr_alt_2_1, tr_alt_2_2, tr_alt_2_3, tr_alt_2_4, tr_alt_2_5, tr_alt_2_6, tr_alt_2_7]
    lrs_2 = LatticeReactionSystem(CuH_Amination_system_alt_2, CuH_Amination_srs_alt_2, small_2d_grid)
    
    u0 = [CuH_Amination_u0; :Newspecies1 => 0.1; :Newspecies2 => 0.1]
    pV = [CuH_Amination_p; :dLigand => 0.01; :dSilane => 0.01; :dCu_ELigand =>  0.009; :dStyrene => -10000.0]
    pE = [:dAmine_E => 0.011, :dNewspecies1 =>  0.013, :dDecomposition =>  0.015, :dNewspecies2 =>  0.016, :dCuoAc => -10000.0]

    ss_1 = solve(ODEProblem(lrs_1, u0, (0.0, 500.0), (pV, pE)), Tsit5()).u[end]
    ss_2 = solve(ODEProblem(lrs_2, u0, (0.0, 500.0), (pV, pE)), Tsit5()).u[end]
    @test all(isequal.(ss_1, ss_2))
end

### Tests Special Cases ###

# Create network with various combinations of graph/di-graph and parameters.
let
    lrs_digraph = LatticeReactionSystem(SIR_system, SIR_srs_2, complete_digraph(3))
    lrs_graph = LatticeReactionSystem(SIR_system, SIR_srs_2, complete_graph(3))
    u0 = [:S => 990.0, :I => 20.0 * rand_v_vals(lrs_digraph.lattice), :R => 0.0]
    pV = SIR_p
    pE_digraph_1 = [:dS => [0.10, 0.12, 0.10, 0.14, 0.12, 0.14], :dI => 0.01, :dR => 0.01]
    pE_digraph_2 = [[0.10, 0.12, 0.10, 0.14, 0.12, 0.14], 0.01, 0.01]
    pE_digraph_3 = [0.10 0.12 0.10 0.14 0.12 0.14; 0.01 0.01 0.01 0.01 0.01 0.01; 0.01 0.01 0.01 0.01 0.01 0.01]
    pE_graph_1 = [:dS => [0.10, 0.12, 0.14], :dI => 0.01, :dR => 0.01]
    pE_graph_2 = [[0.10, 0.12, 0.14], 0.01, 0.01]
    pE_graph_3 = [0.10 0.12 0.14; 0.01 0.01 0.01; 0.01 0.01 0.01]
    oprob_digraph_1 = ODEProblem(lrs_digraph, u0, (0.0, 500.0), (pV, pE_digraph_1))
    oprob_digraph_2 = ODEProblem(lrs_digraph, u0, (0.0, 500.0), (pV, pE_digraph_2))
    oprob_digraph_3 = ODEProblem(lrs_digraph, u0, (0.0, 500.0), (pV, pE_digraph_3))
    oprob_graph_11 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_digraph_1))
    oprob_graph_12 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_graph_1))
    oprob_graph_21 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_digraph_2))
    oprob_graph_22 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_graph_2))
    oprob_graph_31 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_digraph_3))
    oprob_graph_32 = ODEProblem(lrs_graph, u0, (0.0, 500.0), (pV, pE_graph_3))
    sim_end_digraph_1 = solve(oprob_digraph_1, Tsit5()).u[end]
    sim_end_digraph_2 = solve(oprob_digraph_2, Tsit5()).u[end]
    sim_end_digraph_3 = solve(oprob_digraph_3, Tsit5()).u[end]
    sim_end_graph_11 = solve(oprob_graph_11, Tsit5()).u[end]
    sim_end_graph_12 = solve(oprob_graph_12, Tsit5()).u[end]
    sim_end_graph_21 = solve(oprob_graph_21, Tsit5()).u[end]
    sim_end_graph_22 = solve(oprob_graph_22, Tsit5()).u[end]
    sim_end_graph_31 = solve(oprob_graph_31, Tsit5()).u[end]
    sim_end_graph_32 = solve(oprob_graph_32, Tsit5()).u[end]

    @test all(sim_end_digraph_1 .== sim_end_digraph_2 .== sim_end_digraph_3 .==
              sim_end_graph_11 .== sim_end_graph_12 .== sim_end_graph_21 .==
              sim_end_graph_22 .== sim_end_graph_31 .== sim_end_graph_32)
end

# Creates networks where some species or parameters have no effect on the system.
let
    binding_system_alt = @reaction_network begin
        @species X(t) Y(t) XY(t) Z(t) V(t) W(t)
        @parameters k1 k2 dX [edgeparameter = true] dXY [edgeparameter = true] dZ [edgeparameter = true] dV [edgeparameter = true] p1 p2
        (k1, k2), X + Y <--> XY
    end
    @unpack dX, dXY, dZ, dV, X, XY, Z, V = binding_system_alt
    binding_srs_alt = [
        TransportReaction(dX, X),
        TransportReaction(dXY, XY),
        TransportReaction(dZ, Z),
        TransportReaction(dV, V),
    ]
    lrs_alt = LatticeReactionSystem(binding_system_alt, binding_srs_alt, small_2d_grid)
    u0_alt = [
        :X => 1.0,
        :Y => 2.0 * rand_v_vals(lrs_alt.lattice),
        :XY => 0.5,
        :Z => 2.0 * rand_v_vals(lrs_alt.lattice),
        :V => 0.5,
        :W => 1.0,
    ]
    p_alt = [
        :k1 => 2.0,
        :k2 => 0.1 .+ rand_v_vals(lrs_alt.lattice),
        :dX => 1.0 .+ rand_e_vals(lrs_alt.lattice),
        :dXY => 3.0,
        :dZ => rand_e_vals(lrs_alt.lattice),
        :dV => 0.2,
        :p1 => 1.0,
        :p2 => rand_v_vals(lrs_alt.lattice),
    ]
    oprob_alt = ODEProblem(lrs_alt, u0_alt, (0.0, 10.0), p_alt)
    ss_alt = solve(oprob_alt, Tsit5()).u[end]

    binding_srs_main = [TransportReaction(dX, X), TransportReaction(dXY, XY)]
    lrs = LatticeReactionSystem(binding_system, binding_srs_main, small_2d_grid)
    u0 = u0_alt[1:3]
    p = p_alt[1:4]
    oprob = ODEProblem(lrs, u0, (0.0, 10.0), p)
    ss = solve(oprob, Tsit5()).u[end]

    for i in 1:25
        @test isapprox(ss_alt[((i - 1) * 6 + 1):((i - 1) * 6 + 3)],
                       ss[((i - 1) * 3 + 1):((i - 1) * 3 + 3)]) < 1e-3
    end
end

# Provides initial conditions and parameters in various different ways.
let
    lrs = LatticeReactionSystem(SIR_system, SIR_srs_2, very_small_2d_grid)
    u0_1 = [:S => 990.0, :I => [1.0, 3.0, 2.0, 5.0], :R => 0.0]
    u0_2 = [990.0, [1.0, 3.0, 2.0, 5.0], 0.0]
    u0_3 = [990.0 990.0 990.0 990.0; 1.0 3.0 2.0 5.0; 0.0 0.0 0.0 0.0]
    pV_1 = [:α => 0.1 / 1000, :β => [0.01, 0.02, 0.01, 0.03]]
    pV_2 = [0.1 / 1000, [0.01, 0.02, 0.01, 0.03]]
    pV_3 = [0.1/1000 0.1/1000 0.1/1000 0.1/1000; 0.01 0.02 0.01 0.03]
    pE_1 = [:dS => [0.01, 0.02, 0.03, 0.04], :dI => 0.01, :dR => 0.01]
    pE_2 = [[0.01, 0.02, 0.03, 0.04], :0.01, 0.01]
    pE_3 = [0.01 0.02 0.03 0.04; 0.01 0.01 0.01 0.01; 0.01 0.01 0.01 0.01]

    p1 = [
        :α => 0.1 / 1000,
        :β => [0.01, 0.02, 0.01, 0.03],
        :dS => [0.01, 0.02, 0.03, 0.04],
        :dI => 0.01,
        :dR => 0.01,
    ]
    ss_1_1 = solve(ODEProblem(lrs, u0_1, (0.0, 1.0), p1), Tsit5()).u[end]
    for u0 in [u0_1, u0_2, u0_3], pV in [pV_1, pV_2, pV_3], pE in [pE_1, pE_2, pE_3]
        ss = solve(ODEProblem(lrs, u0, (0.0, 1.0), (pV, pE)), Tsit5()).u[end]
        @test all(isequal.(ss, ss_1_1))
    end
end

# Confirms parameters can be provided in [pV; pE] and (pV, pE) form.
let
    lrs = LatticeReactionSystem(SIR_system, SIR_srs_2, small_2d_grid)
    u0 = [:S => 990.0, :I => 20.0 * rand_v_vals(lrs.lattice), :R => 0.0]
    p1 = ([:α => 0.1 / 1000, :β => 0.01], [:dS => 0.01, :dI => 0.01, :dR => 0.01])
    p2 = [:α => 0.1 / 1000, :β => 0.01, :dS => 0.01, :dI => 0.01, :dR => 0.01]
    oprob1 = ODEProblem(lrs, u0, (0.0, 500.0), p1; jac = false)
    oprob2 = ODEProblem(lrs, u0, (0.0, 500.0), p2; jac = false)

    @test all(isapprox.(solve(oprob1, Tsit5()).u[end], solve(oprob2, Tsit5()).u[end]))
end

### Compare to Hand-written Functions ###

# Compares the brusselator for a line of cells.
let
    function spatial_brusselator_f(du, u, p, t)
        # Non-spatial
        for i in 1:2:(length(u) - 1)
            du[i] = p[1] + 0.5 * (u[i]^2) * u[i + 1] - u[i] - p[2] * u[i]
            du[i + 1] = p[2] * u[i] - 0.5 * (u[i]^2) * u[i + 1]
        end

        # Spatial
        du[1] += p[3] * (u[3] - u[1])
        du[end - 1] += p[3] * (u[end - 3] - u[end - 1])
        for i in 3:2:(length(u) - 3)
            du[i] += p[3] * (u[i - 2] + u[i + 2] - 2u[i])
        end
    end
    function spatial_brusselator_jac(J, u, p, t)
        J .= 0
        # Non-spatial
        for i in 1:2:(length(u) - 1)
            J[i, i] = u[i] * u[i + 1] - 1 - p[2]
            J[i, i + 1] = 0.5 * (u[i]^2)
            J[i + 1, i] = p[2] - u[i] * u[i + 1]
            J[i + 1, i + 1] = -0.5 * (u[i]^2)
        end

        # Spatial
        J[1, 1] -= p[3]
        J[1, 3] += p[3]
        J[end - 1, end - 1] -= p[3]
        J[end - 1, end - 3] += p[3]
        for i in 3:2:(length(u) - 3)
            J[i, i] -= 2 * p[3]
            J[i, i - 2] += p[3]
            J[i, i + 2] += p[3]
        end
    end
    function spatial_brusselator_jac_sparse(J, u, p, t)
        # Spatial
        J.nzval .= 0.0
        J.nzval[7:6:(end - 9)] .= -2p[3]
        J.nzval[1] = -p[3]
        J.nzval[end - 3] = -p[3]
        J.nzval[3:3:(end - 4)] .= p[3]

        # Non-spatial
        for i in 1:1:Int64(lenth(u) / 2 - 1)
            j = 6(i - 1) + 1
            J.nzval[j] = u[i] * u[i + 1] - 1 - p[2]
            J.nzval[j + 1] = 0.5 * (u[i]^2)
            J.nzval[j + 3] = p[2] - u[i] * u[i + 1]
            J.nzval[j + 4] = -0.5 * (u[i]^2)
        end
        J.nzval[end - 3] = u[end - 1] * u[end] - 1 - p[end - 1]
        J.nzval[end - 2] = 0.5 * (u[end - 1]^2)
        J.nzval[end - 1] = p[2] - u[end - 1] * u[end]
        J.nzval[end] = -0.5 * (u[end - 1]^2)
    end
    function make_jac_prototype(u0)
        jac_prototype_pre = zeros(length(u0), length(u0))
        for i in 1:2:(length(u0) - 1)
            jac_prototype_pre[i, i] = 1
            jac_prototype_pre[i + 1, i] = 1
            jac_prototype_pre[i, i + 1] = 1
            jac_prototype_pre[i + 1, i + 1] = 1
        end
        for i in 3:2:(length(u0) - 1)
            jac_prototype_pre[i - 2, i] = 1
            jac_prototype_pre[i, i - 2] = 1
        end
        return sparse(jac_prototype_pre)
    end

    u0 = 2 * rand(rng, 10000)
    p = [1.0, 4.0, 0.1]
    tspan = (0.0, 100.0)

    ofun_hw_dense = ODEFunction(spatial_brusselator_f; jac = spatial_brusselator_jac)
    ofun_hw_sparse = ODEFunction(spatial_brusselator_f; jac = spatial_brusselator_jac,
                                 jac_prototype = make_jac_prototype(u0))

    lrs = LatticeReactionSystem(brusselator_system, brusselator_srs_1,
                                path_graph(Int64(length(u0) / 2)))
    u0V = [:X => u0[1:2:(end - 1)], :Y => u0[2:2:end]]
    pV = [:A => p[1], :B => p[2]]
    pE = [:dX => p[3]]
    ofun_aut_dense = ODEProblem(lrs, u0V, tspan, (pV, pE); jac = true, sparse = false).f
    ofun_aut_sparse = ODEProblem(lrs, u0V, tspan, (pV, pE); jac = true, sparse = true).f

    du_hw_dense = deepcopy(u0)
    du_hw_sparse = deepcopy(u0)
    du_aut_dense = deepcopy(u0)
    du_aut_sparse = deepcopy(u0)

    ofun_hw_dense(du_hw_dense, u0, p, 0.0)
    ofun_hw_sparse(du_hw_sparse, u0, p, 0.0)
    ofun_aut_dense(du_aut_dense, u0, p, 0.0)
    ofun_aut_sparse(du_aut_sparse, u0, p, 0.0)

    @test isapprox(du_hw_dense, du_aut_dense)
    @test isapprox(du_hw_sparse, du_aut_sparse)

    J_hw_dense = deepcopy(zeros(length(u0), length(u0)))
    J_hw_sparse = deepcopy(make_jac_prototype(u0))
    J_aut_dense = deepcopy(zeros(length(u0), length(u0)))
    J_aut_sparse = deepcopy(make_jac_prototype(u0))

    ofun_hw_dense.jac(J_hw_dense, u0, p, 0.0)
    ofun_hw_sparse.jac(J_hw_sparse, u0, p, 0.0)
    ofun_aut_dense.jac(J_aut_dense, u0, p, 0.0)
    ofun_aut_sparse.jac(J_aut_sparse, u0, p, 0.0)

    @test isapprox(J_hw_dense, J_aut_dense)
    @test isapprox(J_hw_sparse, J_aut_sparse)
end
