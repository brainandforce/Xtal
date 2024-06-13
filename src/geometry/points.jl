#---Abstract types---------------------------------------------------------------------------------#
"""
    Electrum.Geometry.AbstractPoint{S<:BySpace,C<:ByCoordinate,D,T<:Real} <: StaticVector{D,T}

Represents a `D`-dimensional point, or family of points, in the space given by `S` relative to the
coordinate system given by `C` with element type `T`.

The [`BarePoint`](@ref) abstract subtype contains data structures which *only* contain coordinate
information. In general, subtypes of this type can contain arbitrary data associated with the point.
This can be used to implement broader data types, like atomic positions.

# Implementation

By specifying a field `coordinate::NTuple{D,T}` for a subtype of this type `P`, the `StaticVector`
interface is automatically defined: `Base.getindex(::P, ::Int)` and `Base.Tuple(::P)` have default
definitions referencing this field.
"""
abstract type AbstractPoint{S<:BySpace,C<:ByCoordinate,D,T<:Real} <: StaticVector{D,T}
end

#---Default implementations------------------------------------------------------------------------#

BySpace(::Type{<:AbstractPoint{S}}) where S = S()
ByCoordinate(::Type{<:AbstractPoint{<:Any,C}}) where C = C()

Base.Tuple(p::AbstractPoint) = p.coordinate
@propagate_inbounds Base.getindex(p::AbstractPoint, i::Int) = getindex(Tuple(p), i)

"""
    Electrum.Geometry.BarePoint{S,C,D,T} <: AbstractPoint{S,C,D,T}

A data structure which only contains coordinate information. These can be used directly, but they
can also be incorporated into other `Electrum.Geometry.AbstractPoint` subtypes that include
additional data.
"""
abstract type BarePoint{S<:BySpace,C<:ByCoordinate,D,T<:Real} <: AbstractPoint{S,C,D,T}
end

#---Individual points------------------------------------------------------------------------------#
"""
    Electrum.Geometry.SinglePoint{S,C,D,T} <: BarePoint{S,C,D,T}

Represents a single point in the `D`-dimensional space defined by `S` relative to a coordinate
system described by `C` with element type `T`. The distance units are assumed to be bohr if
`S === ByRealSpace`, or rad*bohr⁻¹ if `S === ByReciprocalSpace`.
"""
struct SinglePoint{S<:BySpace,C<:ByCoordinate,D,T<:Real} <: BarePoint{S,C,D,T}
    coordinate::NTuple{D,T}
end

const RealSinglePoint{C,D,T} = SinglePoint{ByRealSpace,C,D,T}
const ReciprocalSinglePoint{C,D,T} = SinglePoint{ByReciprocalSpace,C,D,T}

SinglePoint{S,C,D}(v::AbstractVector{T}) where {S,C,D,T} = SinglePoint{S,C,D,T}(v)
SinglePoint{S,C}(v::StaticVector{D,T}) where {S,C,D,T} = SinglePoint{S,C,D,T}(Tuple(v))

#---Families of points related by lattice translations---------------------------------------------#
"""
    Electrum.Geometry.PeriodicPoint{S,D,T} <: BarePoint{S,ByFractionalCoordinate,D,T}

Represents an equivalence class of points within a `D`-dimensional lattice over the translational
symmetries of a lattice.

The lattice itself is not provided by this type: in general, data structures utilizing this type
should also include the lattice the coordinates are defined with respect to.
"""
struct PeriodicPoint{S<:BySpace,D,T<:Real} <: BarePoint{S,ByFractionalCoordinate,D,T}
    coordinate::NTuple{D,T}
end

const RealPeriodicPoint{D,T} = PeriodicPoint{ByRealSpace,D,T}
const ReciprocalPeriodicPoint{D,T} = PeriodicPoint{ByReciprocalSpace,D,T}

PeriodicPoint{S,D}(v::AbstractVector{T}) where {S,D,T} = PeriodicPoint{S,D,T}(v)
PeriodicPoint{S}(v::StaticVector{D,T}) where {S,D,T} = PeriodicPoint{S,D,T}(Tuple(v))

# Equivalence of points
# Try to ensure that numerical stability issues won't arise here when subtracting floats
Base.:(==)(p::PeriodicPoint{S,D}, q::PeriodicPoint{S,D}) where {S,D} = iszero((p-q) - floor.(p-q))

#---Conversion between single points and periodic points-------------------------------------------#
"""
    SinglePoint(
        p::PeriodicPoint{S,D},
        [offset::StaticVector{D,<:Integer} = zero(SVector{D,Bool})]
    )

Constructs a `SinglePoint{S,ByFractionalCoordinate,D}` from `p`. The `offset` vector can be
specified to change the integer portion of the coordinates: if not specified, it defaults to zero.
"""
function SinglePoint(
    p::PeriodicPoint{S,D},
    offset::StaticVector{D,<:Integer} = zero(SVector{D,Bool})
) where {S,D}
    return SinglePoint{S,ByFractionalCoordinate,D}(p + (offset - floor.(p)))
end

"""
    PeriodicPoint(p::SinglePoint{S,ByFractionalCoordinate})

Generates the equivalence class of lattice points corresponding to a single point `p`.
"""
PeriodicPoint(p::SinglePoint{S,ByFractionalCoordinate}) where S = PeriodicPoint{S}(p)
