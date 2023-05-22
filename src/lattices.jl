"""
    Electrum.lattice_sanity_check(M::AbstractMatrix)

Runs checks on a matrix intended to represent basis vectors of a crystal unit cell. Returns nothing,
but warns if the cell vectors form a left-handed coordinate system, and throws an `AssertionError`
if the cell vectors are not linearly independent.
"""
@inline function lattice_sanity_check(M::AbstractMatrix)
    # Skip this check for lattices that are zero (meaning unspecified basis)
    iszero(M) && return nothing
    iszero(det(M)) && @warn "matrix determinant is zero."
    det(M) < 0 && @warn "cell vectors form a left-handed coordinate system."
    return nothing
end

"""
    Electrum.LatticeBasis{S<:Union{ByRealSpace,ByReciprocalSpace},D,T} <: StaticMatrix{D,D,T}

Represents the basis vectors of a `D`-dimensional lattice in real space (when `S === ByRealSpace`)
or in reciprocal space (when `S === ByReciprocalSpace`). The units of `LatticeBasis{ByRealSpace}`
are bohr, and those of `LatticeBasis{ByReciprocalSpace}` are rad*bohr⁻¹. File import and export
methods will take this into account.

For convenience, the type aliases `RealBasis = LatticeBasis{ByRealSpace}` and 
`ReciprocalBasis = LatticeBasis{ByReciprocalSpace}` are provided and exported.

# Internals

In order to avoid the presence of an extraneous type parameter, the backing `vectors` field of a
`LatticeBasis` is not an `SMatrix{D,D,T}` (as this is not a concrete type), but an 
`SVector{D,SVector{D,T}}`. However, the property `matrix` is defined so that it returns an
`SMatrix{D,D,T}`. The `vectors` property is private, and will not be revealed during REPL tab
completion.
"""
struct LatticeBasis{S<:Union{ByRealSpace,ByReciprocalSpace},D,T<:Real} <: StaticMatrix{D,D,T}
    vectors::SVector{D,SVector{D,T}}
    function LatticeBasis{S,D,T}(M::StaticMatrix) where {S,D,T}
        lattice_sanity_check(M)
        return new(SVector{D}(eachcol(M)))
    end
end

# Needed to resolve ambiguity with StaticArrays generic constructor
function LatticeBasis{S,D,T}(::StaticArray) where {S,D,T} 
    throw(DimensionMismatch("Input must be a square matrix."))
end

"""
    RealBasis{D,T}

Represents a lattice defined in `D`-dimensional real space, in units of bohr.

For further information, see `Electrum.LatticeBasis`.
"""
const RealBasis = LatticeBasis{ByRealSpace}

"""
    ReciprocalBasis{D,T}

Represents a lattice defined in `D`-dimensional reciprocal space, in units of rad*bohr⁻¹.

For further information, see `Electrum.LatticeBasis`.
"""
const ReciprocalBasis = LatticeBasis{ByReciprocalSpace}

const AbstractBasis = LatticeBasis{S} where S<:Union{ByRealSpace,ByReciprocalSpace}

DataSpace(::Type{<:LatticeBasis{S,D}}) where {S,D} = S{D}()

LatticeBasis{S,D,T}(t::Tuple) where {S,D,T} = LatticeBasis{S,D,T}(SMatrix{D,D}(t))
LatticeBasis{S,D,T}(M::AbstractMatrix) where {S,D,T} = LatticeBasis{S,D,T}(SMatrix{D,D}(M))
#=
LatticeBasis{S,D}(M::AbstractMatrix{T}) where {S,D,T} = LatticeBasis{S,D,T}(M)
=#
LatticeBasis{S}(M::StaticMatrix{D,D,T}) where {S,D,T} = LatticeBasis{S,D,T}(M)

#---Matrix property--------------------------------------------------------------------------------#

function Base.getproperty(b::LatticeBasis, s::Symbol)
    s === :matrix && return hcat(getfield(b, :vectors)...)
    return getfield(b, s)
end

Base.propertynames(::LatticeBasis; private = false) = private ? (:vectors, :matrix) : (:matrix)

#---Custom indexing and iteration------------------------------------------------------------------#

# Really only for resolving method ambiguities
Base.getindex(b::LatticeBasis, i::Int) = getindex(b.matrix, i)
Base.getindex(b::LatticeBasis, i::Int...) = getindex(b.matrix, i...)
# Iterate through the column vectors, not through individual elements
# Base.iterate(b::LatticeBasis{S,D}, i = 1) where {S,D} = i in 1:D ? (b[i], i+1) : nothing

#---Conversion semantics---------------------------------------------------------------------------#

# Convert between real and reciprocal space representations
Base.convert(T::Type{<:ReciprocalBasis}, b::RealBasis) = T(2π * inv(transpose(b.matrix)))
Base.convert(T::Type{<:RealBasis}, b::ReciprocalBasis) = T(transpose(2π * inv(b.matrix)))
# Constructors can perform this conversion too
(T::Type{<:LatticeBasis})(b::LatticeBasis) = convert(T, b)
# Conversion to Tuple (needed for StaticArrays.jl)
Tuple(b::LatticeBasis) = Tuple(b.matrix)

#---Mathematical operations------------------------------------------------------------------------#

Base.:(==)(a::LatticeBasis{S,D}, b::LatticeBasis{S,D}) where {S,D} = a.matrix == b.matrix

Base.inv(b::RealBasis) = convert(ReciprocalBasis, b)
Base.inv(b::ReciprocalBasis) = convert(RealBasis, b)

#= Scalars
Base.:*(s::Real, b::LatticeBasis) = typeof(b)(s .* b.vectors)
Base.:*(b::LatticeBasis, s::Real) = s * b
Base.:/(b::LatticeBasis, s::Real) = typeof(b)(b.vectors ./ s)

# Vectors
Base.:*(b::LatticeBasis{S,D}, v::AbstractVector) where {S,D} = b.matrix * SVector{D}(v)
Base.:*(v::AbstractVector, b::LatticeBasis{S,D}) where {S,D} = b.matrix * SVector{D}(v)
Base.:/(v::AbstractVector, b::LatticeBasis{S,D}) where {S,D} = SVector{D}(v) / b.matrix
=#
Base.:\(b::LatticeBasis{S,D}, v::Vector) where {S,D} = b.matrix \ SVector{D}(v)

# Matrices
function Base.:*(
    b::LatticeBasis{S,D},
    M::Union{StaticMatrix{D,D,T},Matrix{T}}
) where {S,D,T<:Integer}
    return LatticeBasis{S,D,promote_type(eltype(b), eltype(M))}(b.matrix * M)
end

LinearAlgebra.det(b::LatticeBasis) = det(b.matrix)

#---Unit cell metrics------------------------------------------------------------------------------#
"""
    lengths(b::LatticeBasis{S,D}) -> SVector{D}

Returns the lengths of the basis vectors. The units correspond to the type of the basis vectors: for
`RealBasis` the units are bohr, and for `ReciprocalBasis` the units are rad*bohr⁻¹.
"""
lengths(b::LatticeBasis{S,D}) where {S,D} = SVector{D}(norm(v) for v in b)

"""
    volume(b::LatticeBasis) -> Real

Returns the volume of a unit cell defined by a matrix. This volume does not carry the sign (negative
for cells that do not follow the right hand rule). The units correspond to the type of the basis 
vectors: for `RealBasis` the units are bohr³, and for `ReciprocalBasis` the units are rad³*bohr⁻³.
"""
volume(b::LatticeBasis) = abs(det(b))

"""
    Electrum.generate_pairs(D::Integer) -> Vector{NTuple{2,Int}}

Generate pairs of integers up to `D` in ascending order.
"""
function generate_pairs(D::Integer)
    out = Vector{NTuple{2,Int}}(undef, Int(D*(D-1)/2))
    c = 0
    for a = 1:D
        for b = (a+1):D
            c += 1 
            out[c] = (a,b)
        end
    end
    return out
end

"""
    Electrum.generate_pairs(::Type{Val{D}}) -> SVector{D*(D-1)/2, NTuple{2,Int}}

Generate pairs of integers up to `D` in ascending order in an `SVector`.
"""
function generate_pairs(::Type{Val{D}}) where D
    N = Int(D*(D-1)/2)
    return SVector{N,NTuple{2,Int}}(generate_pairs(D))
end

"""
    angles_cos(b::LatticeBasis{S,D}) -> SVector{binomial(D,2)}

Generates the cosines of the unit cell angles.

The angles are generated in the correct order [α, β, γ] for 3-dimensional cells. This is achieved by
reversing the output of `Electrum.generate_pairs()`. For crystals with more spatial dimensions,
this may lead to unexpected results.
"""
function angles_cos(b::LatticeBasis{S,D}) where {S,D}
    M = b.matrix
    L = binomial(D,2)
    dimpairs = reverse(generate_pairs(size(M,1)))
    return SVector{L}([dot(M[:,a], M[:,b])/(norm(M[:,a])*norm(M[:,b])) for (a,b) in dimpairs])
end

"""
    angles_rad(b::LatticeBasis{S,D}) -> SVector{binomial(D,2)}

Returns the angles (in radians) between each pair of basis vectors.

The angles are generated in the correct order [α, β, γ] for 3-dimensional cells. This is achieved by
reversing the output of `Electrum.generate_pairs()`. For crystals with more spatial dimensions,
this may lead to unexpected results.
"""
angles_rad(b::LatticeBasis) = acos.(angles_cos(b))

"""
    angles_deg(b::LatticeBasis{S,D}) -> SVector{binomial(D,2)}

Returns the angles (in degrees) between each pair of basis vectors.

The angles are generated in the correct order [α, β, γ] for 3-dimensional cells. This is achieved by
reversing the output of `Electrum.generate_pairs()`. For crystals with more spatial dimensions,
this may lead to unexpected results.
"""
angles_deg(b::LatticeBasis) = acosd.(angles_cos(b))

#---Advanced linear algebra (such as matrix decompositions)----------------------------------------#

LinearAlgebra.isdiag(b::LatticeBasis) = isdiag(b.matrix)
LinearAlgebra.qr(b::LatticeBasis) = qr(b.matrix)

"""
    gram(b::LatticeBasis{S,D}) -> SMatrix{D,D}

Returns the Gram matrix associated with a set of basis vectors. The entries of this matrix are the
dot products associated with all possible combinations of basis vectors.
"""
gram(b::LatticeBasis) = b.matrix' * b.matrix

"""
    triangularize(l::T) where T<:LatticeBasis -> T

Converts a set of basis vectors to an upper triangular form using QR decomposition.
"""
function triangularize(b::T) where T<:LatticeBasis
    R = qr(b).R
    return T(R * diagm(sign.(diag(R))))
end

"""
    triangularize(l::T, sc::AbstractMatrix{<:Integer}) where T<:LatticeBasis -> T

Converts a set of basis vectors to an upper triangular form using QR decomposition, with an included
conversion to a larger supercell. The resulting matrix that describes the basis vectors will have
only positive values along the diagonal, and therefore, is always right-handed (regardless of the
transformation matrix used).

LAMMPS expects that basis vectors are given in this format.
"""
function triangularize(b::T, sc::AbstractMatrix{<:Integer}) where T<:LatticeBasis
    det(sc) < 0 && @warn string(
        "The transformation matrix has a negative determinant.\n",
        "However, this function always returns a right-handed basis."
    )
    det(sc) == 0 && error("supplied transformation matrix is singular")
    # Convert the matrix to upper triangular form using QR decomposition
    # Q is the orthogonal matrix, R is the upper triangular matrix (only need R)
    R = SMatrix{length(b),length(b),Float64}(qr(b.matrix * sc).R)
    # Ensure the diagonal elements are positive
    return T(R * diagm(sign.(diag(R))))
end

#---Maximum HKL index determination for wavefunction reading---------------------------------------#

# TODO: Update and document this function a bit more.
# It works, but that really isn't enough for me.
# I think this was pulled directly from the WaveTrans source code
function maxHKLindex(M::AbstractMatrix{<:Real}, ecut::Real; c = 2)
    # I think the parts below convert a set of basis vectors into their reciprocals
    #----------------------------------------------------------------------------------------------#
    cosines = cell_angles_cos(M)
    crosses = [cross(M[:,a], M[:,b]) for (a,b) in zip([2,3,1], [3,1,2])]
    triples = [dot(M[:,n], crosses[n])/(norm(crosses[n])*norm(M[:,n])) for n in 1:3]
    sines = hcat([[sqrt(1-c^2), sqrt(1-c^2) ,t] for (c,t) in zip(cosines, triples)]...)
    #----------------------------------------------------------------------------------------------#
    nbmax = sqrt(c*ecut) ./ [norm(M[:,a])*sines[a,b] for a in 1:3, b in 1:3] .+ 1
    return floor.(Int, vec(maximum(nbmax, dims=1)))
end

"""
    Electrum.maxHKLindex(b::LatticeBasis, ecut::Real; prim=true, c = CVASP)

Determines the maximum integer values of the reciprocal lattice vectors needed to store data out to
a specific energy cutoff for a 3D lattice.

By default, the energy cutoff is assumed to be in units of eV, the reciprocal lattice vector lengths
are assumed to be in angstroms, and the value of c (2m/ħ^2) is taken from VASP's default
value (which is incorrect!). Different values of c may be used for different units.

The functionality implemented here was taken from WaveTrans:
https://www.andrew.cmu.edu/user/feenstra/wavetrans/
"""
# Assume that the basis vectors are defined in reciprocal space (??)
maxHKLindex(b::ReciprocalBasis, ecut::Real; c = 2) = maxHKLindex(b.matrix, ecut; c)
maxHKLindex(b::RealBasis, ecut::Real; c = 2) = maxHKLindex(ReciprocalBasis(b), ecut; c)

