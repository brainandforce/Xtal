"""
    Electrum.Geometry.LatticeBasis{S<:BySpace,D,T<:Real} <: StaticMatrix{D,D,T}

A crystal lattice, specified by a square matrix whose columns are the lattice basis vectors.
"""
struct LatticeBasis{S<:BySpace,D,T<:Real} <: StaticMatrix{D,D,T}
    matrix::LSMatrix{D,D,T}
end

"""
    RealLattice{D,T} (alias for Electrum.LatticeBasis{ByRealSpace,D,T})

Represents a the basis vectors of a lattice in real space, with lengths given in units of bohr.

For more information about this type, see [`Electrum.LatticeBasis`](@ref Electrum.LatticeBasis).
"""
const RealLattice{D,T} = LatticeBasis{ByRealSpace,D,T} where T<:Real

"""
    ReciprocalLattice{D,T} (alias for Electrum.LatticeBasis{ByReciprocalSpace,D,T})

Represents a the basis vectors of a lattice in reciprocal space, with lengths given in units of 
radians per bohr (rad*bohr⁻¹).

For more information about this type, see [`Electrum.LatticeBasis`](@ref Electrum.LatticeBasis).
"""
const ReciprocalLattice{D,T} = LatticeBasis{ByReciprocalSpace,D,T} where T<:Real

LatticeBasis{S,D}(M::AbstractMatrix{T}) where {S,D,T} = LatticeBasis{S,D,T}(M)
LatticeBasis{S}(M::StaticMatrix{D,D,T}) where {S,D,T} = LatticeBasis{S,D,T}(M)

#---Traits-----------------------------------------------------------------------------------------#

BySpace(::Type{<:LatticeBasis{S}}) where S = S()
ByCoordinate(::Type{<:LatticeBasis}) = ByOrthonormalCoordinate()

#---StaticMatrix interface-------------------------------------------------------------------------#

Base.Tuple(b::LatticeBasis) = Tuple(b.matrix)
Base.getindex(b::LatticeBasis, i::Int) = getindex(Tuple(b), i)

#---Conversion semantics---------------------------------------------------------------------------#

# Convert between real and reciprocal space representations
Base.convert(T::Type{<:ReciprocalLattice}, b::RealLattice) = T(2π * inv(transpose(b.matrix)))
Base.convert(T::Type{<:RealLattice}, b::ReciprocalLattice) = T(transpose(2π * inv(b.matrix)))
# Constructors can perform this conversion too
(T::Type{<:LatticeBasis})(b::LatticeBasis) = convert(T, b)

#---Get lattice from another data structure--------------------------------------------------------#
"""
    lattice(x)

Returns the `RealLattice` or `ReciprocalLattice` object associated with a data structure. By
default, this returns `getproperty(x, :lattice)`, so any data structure containing a field named
`lattice` will automatically implement this function.

Although `lattice(x)` should always return an `Electrum.Geometry.LatticeBasis`, the exact return 
type varies: not only can the numeric type vary, some data strucutres may store a real space
lattice, and others may store a reciprocal space lattice, allowing for the lattice's `BySpace` trait 
to propagate to the data structure.

For predictable results, use `convert(T, basis(x))` where `T` is the desired type.
"""
lattice(x) = x.lattice::LatticeBasis

#---Lattice duality--------------------------------------------------------------------------------#
"""
    dual_lattice(b::RealLattice{D}) -> ReciprocalLattice{D}
    dual_lattice(b::ReciprocalLattice{D}) -> RealLattice{D}

Generates the dual lattice of `b`, which satisfies the relationship:
    dual_lattice(b) * b == b * dual_lattice(b) == 2π * LinearAlgebra.I()

Note the factor of 2π: some work uses conventions where the dual lattice is simply defined as the
lattice generated by the matrix inverse.
"""
dual_lattice(b::LatticeBasis{S,D,T}) where {S,D,T} = convert(LatticeBasis{inv(S),D}, b)

#---Multiplication rules for coordinate types------------------------------------------------------#

function Base.:*(l::LatticeBasis{S,D}, p::SinglePoint{S,ByFractionalCoordinate,D}) where {S,D}
    return SinglePoint{S,ByOrthonormalCoordinate,D}(SMatrix(l) * SVector(p))
end

function Base.:\(l::LatticeBasis{S,D}, p::SinglePoint{S,ByOrthonormalCoordinate,D}) where {S,D}
    return SinglePoint{S,ByFractionalCoordinate,D}(SMatrix(l) \ SVector(p))
end

#---Gram matrix type-------------------------------------------------------------------------------#
#=
"""
    GramMatrix{S<:BySpace,D,T<:Real} <: StaticMatrix{D,D,T}

The Gram matrix (or Gramian) of a lattice `b`, generated from the product `b' * b`. Its entries
represent the dot products of the lattice basis vectors with themselves.
"""
struct GramMatrix{S<:BySpace,D,T<:Real} <: StaticMatrix{D,D,T}
    matrix::LSMatrix{D,D,T}
    function GramMatrix{S,D,T}(x) where {S,D,T}
        @assert issymmetric(x) "The Gram matrix is symmetric, but the input is not."
        return new(x)
    end
end

const RealGramMatrix{D,T} = GramMatrix{ByRealSpace,D,T<:Real}
const ReciprocalGramMatrix{D,T} = GramMatrix{ByReciprocalSpace,D,T<:Real}

GramMatrix{S,D}(M::AbstractMatrix{T}) = GramMatrix{S,D,T}(M)
GramMatrix{S}(M::StaticMatrix{D,T}) = GramMatrix{S,D,T}(M)

GramMatrix(M::LatticeBasis{S,D,T}) where {S,D,T} = GramMatrix{S,D,T}(M' * M)
=#
