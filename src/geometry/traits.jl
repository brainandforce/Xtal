#---Data space traits------------------------------------------------------------------------------#
"""
    BySpace

Supertype encomapssing the trait types `ByRealSpace` and `ByReciprocalSpace`, which describe whether
a geometric object exists in real space or reciprocal space.
"""
abstract type BySpace
end

"""
    ByRealSpace <: BySpace

Trait type for real space data, such as atomic coordinates.
"""
struct ByRealSpace <: BySpace
end

"""
    ByReciprocalSpace <: BySpace

Trait type for real space data, such as k-points.
"""
struct ByReciprocalSpace <: BySpace
end

"""
    inv(::BySpace)
    inv(::Type{<:BySpace})

Returns the inverse trait for a `BySpace` instance or type: the inverse of `ByRealSpace()` is
`ByReciprocalSpace()`.
"""
Base.inv(::ByRealSpace) = ByReciprocalSpace()
Base.inv(::ByReciprocalSpace) = ByRealSpace()
Base.inv(::Type{T}) where T<:BySpace = typeof(inv(T()))

#---Coordinate system traits-----------------------------------------------------------------------#
"""
    ByCoordinate

Supertype encompassing the trait types `ByCartesianCoordinate` and `ByFractionalCoordinate`, which
describe the coordinate system which the coefficients of geometric objects reference.
"""
abstract type ByCoordinate
end

"""
    ByFractionalCoordinate <: ByCoordinate

Trait type for data using a fractional coordinate system, where the coordinates reference the unit
cell of some lattice. The units associated with this trait are those associated with the lattice
the coordinates are defined with respect to.
"""
struct ByFractionalCoordinate <: ByCoordinate
end

"""
    ByOrthonormalCoordinate <: ByCoordinate

Trait type for data using an orthonormal coordinate system, with all coordinates in units of bohr
for [`ByRealSpace`](@ref) data or rad*bohr⁻¹ for [`ByReciprocalSpace`](@ref) data.
"""
struct ByOrthonormalCoordinate <: ByCoordinate
end

#---Get traits associated with objects-------------------------------------------------------------#
"""
    BySpace(T::Type)
    BySpace(x::T)

Returns the `BySpace` trait associated with a type `T` or a instance `x::T`.
"""
BySpace(::Type) = error("No BySpace trait is associated with this type.")
BySpace(::T) where T = BySpace(T)

"""
    ByCoordinate(T::Type)
    ByCoordinate(x::T)

Returns the `ByCoordinate` trait associated with a type `T` or a instance `x::T`.
"""
ByCoordinate(::Type) = error("No ByCoordinate trait is associated with this type.")
ByCoordinate(::T) where T = ByCoordinate(T)
