struct SOSPolynomialBridge{T, F <: MOI.AbstractVectorFunction,
                           DT <: AbstractSemialgebraicSet,
                           VB <: AbstractVariableBridge,
                           BT <: PolyJuMP.AbstractPolynomialBasis,
                           MT <: AbstractMonomial,
                           MVT <: AbstractVector{MT}} <: MOIB.AbstractBridge
    variable_bridge::VB
    certificate_monomials::MVT
    zero_constraint::MOI.ConstraintIndex{F, PolyJuMP.ZeroPolynomialSet{DT, BT, MT, MVT}}
end

function SOSPolynomialBridge{T, F, DT, VB, BT, MT, MVT}(
    model::MOI.ModelLike, f::MOI.AbstractVectorFunction,
    s::SOSPolynomialSet{<:AbstractAlgebraicSet}) where {
        # Need to specify types to avoid ambiguity with the default constructor
        T, F <: MOI.AbstractVectorFunction, DT <: AbstractSemialgebraicSet,
        VB <: AbstractVariableBridge, BT <: PolyJuMP.AbstractPolynomialBasis,
        MT <: AbstractMonomial, MVT <: AbstractVector{MT}
    }
    @assert MOI.output_dimension(f) == length(s.monomials)
    p = polynomial(collect(MOIU.eachscalar(f)), s.monomials)
    # FIXME convert needed because the coefficient type of `r` is `Any` otherwise if `domain` is `AlgebraicSet`
    r = convert(typeof(p), rem(p, ideal(s.domain)))
    X = monomials_half_newton_polytope(monomials(r), s.newton_polytope)
    Q, variable_bridge = add_variable_bridge(
        VB, model, matrix_cone(matrix_cone_type(typeof(s.cone)), length(X)))
    g = build_gram_matrix(Q, X)
    q = r - g
    set = PolyJuMP.ZeroPolynomialSet(s.domain, s.basis, monomials(q))
    coefs = MOIU.vectorize(coefficients(q))
    zero_constraint = MOI.add_constraint(model, coefs, set)
    return SOSPolynomialBridge{T, F, DT, VB, BT, MT, MVT}(
        variable_bridge, X, zero_constraint)
end

function MOI.supports_constraint(::Type{SOSPolynomialBridge{T}},
                                 ::Type{<:MOI.AbstractVectorFunction},
                                 ::Type{<:SOSPolynomialSet{<:AbstractAlgebraicSet}}) where T
    return true
end
function MOIB.added_constraint_types(::Type{SOSPolynomialBridge{T, F, DT, VB, BT, MT, MVT}}) where {T, F, DT, VB, BT, MT, MVT}
    added = [(F, PolyJuMP.ZeroPolynomialSet{DT, BT, MT, MVT})]
    append!(added, MOIB.added_constraint_types(VB))
    return added
end
function MOIB.concrete_bridge_type(::Type{<:SOSPolynomialBridge{T}},
                                   F::Type{<:MOI.AbstractVectorFunction},
                                   ::Type{<:SOSPolynomialSet{DT, CT, <:PolyJuMP.MonomialBasis, MT, MVT}}) where {T, DT<:AbstractAlgebraicSet, CT, MT, MVT}
    # promotes VectorOfVariables into VectorAffineFunction, it should be enough
    # for most use cases
    G = MOIU.promote_operation(-, T, F, MOI.VectorOfVariables)
    VB = variable_bridge_type(matrix_cone_type(CT), T)
    return SOSPolynomialBridge{T, G, DT, VB, PolyJuMP.MonomialBasis, MT, MVT}
end

# Attributes, Bridge acting as an model
function MOI.get(::SOSPolynomialBridge{T, F, DT, BT, MT, MVT},
                 ::MOI.NumberOfConstraints{F, PolyJuMP.ZeroPolynomialSet{DT, BT, MT, MVT}}) where {T, F, DT, BT, MT, MVT}
    return 1
end
function MOI.get(b::SOSPolynomialBridge{T, F, DT, BT, MT, MVT},
                 ::MOI.ListOfConstraintIndices{F, PolyJuMP.ZeroPolynomialSet{DT, BT, MT, MVT}}) where {T, F, DT, BT, MT, MVT}
    return [b.zero_constraint]
end

# Indices
function MOI.delete(model::MOI.ModelLike, bridge::SOSPolynomialBridge)
    # First delete the constraints in which the Gram matrix appears
    MOI.delete(model, bridge.zero_constraint)
    # Now we delete the Gram matrix
    MOI.delete(model, bridge.variable_bridge)
end

# Attributes, Bridge acting as a constraint
function MOI.get(model::MOI.ModelLike,
                 attr::MOI.ConstraintDual,
                 bridge::SOSPolynomialBridge)
    return MOI.get(model, attr, bridge.zero_constraint)
end
function MOI.get(::MOI.ModelLike, ::CertificateMonomials,
                 bridge::SOSPolynomialBridge)
    return bridge.certificate_monomials
end
function MOI.get(model::MOI.ModelLike,
                 attr::GramMatrixAttribute,
                 bridge::SOSPolynomialBridge)
    return build_gram_matrix(MOI.get(model, attr, bridge.variable_bridge),
                             bridge.certificate_monomials)
end
function MOI.get(model::MOI.ModelLike,
                 attr::MomentMatrixAttribute,
                 bridge::SOSPolynomialBridge)
    return build_moment_matrix(MOI.get(model, attr, bridge.variable_bridge),
                               bridge.certificate_monomials)
end
