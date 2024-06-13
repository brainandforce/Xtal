"""
    AbstractPointCloud{P<:AbstractPoint} <: AbstractVector{V}

Supertype for all representations of point clouds using elements of type `P`.
"""
abstract type AbstractPointCloud{P<:AbstractPoint} <: AbstractVector{P}
end

"""
    PointCloud{S,C,D,T} <: AbstractPointCloud{SinglePoint{S,C,D,T}}

Represents a set of points in space.
"""
struct PointCloud{S,C,D,T} <: AbstractPointCloud{SinglePoint{S,C,D,T}}
    points::Vector{SinglePoint{S,C,D,T}}
end

"""
    PeriodicPointCloud{S,D,T} <: AbstractPointCloud{PeriodicPoint{S,D,T}}

Represents equivalence classes of points within a lattice related by translational symmetry.
"""
struct PeriodicPointCloud{S,D,T} <: AbstractPointCloud{PeriodicPoint{S,D,T}}
    basis::LatticeBasis{S,D,T}
    points::Vector{PeriodicPoint{S,D,T}}
end

function PeriodicPointCloud(
    basis::LatticeBasis{S,D},
    points::AbstractVector{PeriodicPoint{S,D}}
) where {S,D}
    T = promote_type(eltype(basis), eltype(points))
    return PeriodicPointCloud{S,D,T}(basis, points)
end
