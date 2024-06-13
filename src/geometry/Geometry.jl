"""
    Electrum.Geometry

The submodule responsible for the definitions of geometric primitives related to crystal structures.
This includes coordinate systems, lattices, atomic positions, and more.
"""
module Geometry

using LinearAlgebra
using StaticArrays, LengthFreeStaticMatrices
using CliffordNumbers

import Base: @propagate_inbounds

# Traits for 
include("traits.jl")
export BySpace, ByRealSpace, ByReciprocalSpace, ByCoordinate, ByFractionalCoordinate,
    ByOrthonormalCoordinate
# Vectors specifying the space and coordinate system
include("points.jl")
export AbstractPoint, SinglePoint, PeriodicPoint
include("lattices.jl")
export LatticeBasis, RealLattice, ReciprocalLattice
export lattice, dual_lattice

end
