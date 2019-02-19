module SumOfSquares

using LinearAlgebra

import Reexport

# MultivariatePolynomials extension

using MultivariatePolynomials
const MP = MultivariatePolynomials
using SemialgebraicSets
export @set
Reexport.@reexport using MultivariateMoments

include("matpoly.jl")
include("sosdec.jl")
include("certificate.jl")

# MOI extension

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

using PolyJuMP
export Poly

include("attributes.jl")
include("diagonally_dominant.jl")
include("psd2x2.jl")
include("sos_polynomial.jl")
include("copositive_inner.jl")

# Bridges
const MOIB = MOI.Bridges

# Variable Bridges
abstract type AbstractVariableBridge end
include("sos_variable_bridge.jl")
include("copositive_inner_variable_bridge.jl")

# Constraint Bridges
include("sos_polynomial_bridge.jl")
include("sos_polynomial_in_semialgebraic_set_bridge.jl")
include("diagonally_dominant_bridge.jl")
include("psd2x2_bridge.jl")
include("scaled_diagonally_dominant_bridge.jl")

# JuMP extension

Reexport.@reexport using JuMP

include("utilities.jl")
include("variable.jl")
include("constraint.jl")

function setdefaults!(data::PolyJuMP.Data)
    PolyJuMP.setdefault!(data, PolyJuMP.NonNegPoly, SOSCone)
    PolyJuMP.setdefault!(data, PolyJuMP.PosDefPolyMatrix, SOSMatrixCone)
end

export SOSModel
function SOSModel(args...; kwargs...)
    model = Model(args...; kwargs...)
    setpolymodule!(model, SumOfSquares)
    model
end

end # module
