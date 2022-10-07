"""
    vector_string(v::AbstractVector{<:Real}; brackets=true) -> String

Prints a representation of a vector as a string.
"""
function vector_string(v::AbstractVector{<:Real}; brackets=true)
    # Format the numbers within a vector
    tostr(x, n) = lpad(@sprintf("%f", x), n)
    return "["^brackets * join(tostr.(v, 10)) *" ]"^brackets
end

"""
    basis_string(M::AbstractMatrix{<:Real}; letters=true) -> Vector{String}

Prints each basis vector with an associated letter.
"""
function basis_string(
    M::AbstractMatrix{<:Real};
    pad="  ",
    brackets=true,
    letters=true,
    length=true,
    unit=""
)
    # Format the numbers within a vector
    tostr(x, n) = lpad(@sprintf("%f", x), n)
    # Letters are generated by incrementing up from character 0x60
    # Char(0x61) = 'a', Char(0x62) = 'b'...
    # Letters should work up to 26 dimensions, but who's gonna deal with 26D crystals?
    # Bosonic string theorists, maybe?
    return [
        pad * string(Char(0x60 + n), ':', ' ')^letters *
        vector_string(M[:,n], brackets=brackets) *
        ("   (" * tostr(norm(M[:,n]), 0))^length * " "^!isempty(unit) * unit * ")"
        for n in 1:size(M)[2]
    ]
end

basis_string(b::AbstractBasis; kwargs...) = basis_string(matrix(b); kwargs...)

function printbasis(io::IO, M::AbstractMatrix{<:Real}; letters=true, unit="", pad=0)
    s = basis_string(M, letters=letters, unit=unit)
    print(io, join(" "^pad .* s, "\n"))
end

printbasis(io::IO, b::AbstractBasis; kwargs...) = 
    printbasis(io::IO, matrix(b), letters=true, pad=0; kwargs...)
printbasis(io::IO, a::AtomList; kwargs...) = 
    printbasis(io, basis(a), letters=true, pad=0; kwargs...)
printbasis(io::IO, g::RealSpaceDataGrid{D,T} where {D,T}; kwargs...) =
    printbasis(io, basis(g), letters=true, pad=0; kwargs...)

"""
    atom_string(a::AtomPosition; name=true, num=true)

Generates a string describing an atom position.
"""
function atom_string(a::AtomPosition; name=true, num=true, entrysz=4)
    # Format the numbers within a vector
    tostr(x) = lpad(@sprintf("%f", x), 10)
    return rpad(string(a.num), entrysz)^num * rpad(a.name, entrysz)^name * vector_string(a.pos)
end

# TODO: make this work with occupancy information, since we'll probably need that
function formula_string(v::Vector{AtomPosition{D}}, reduce=true) where D
    # Number of each type of atoms is stored in this vector
    atomcount = zeros(Int, size(ELEMENTS)...)
    # Get all atomic numbers in the 
    atomnos = [a.num for a in v]
    # Get all of the types of atoms
    for atom in atomnos
        # Skip dummy atoms
        atom = 0 && continue
        # Increment the atom counts
        atomcount[atom] += 1
    end
    # Create output string
    str = ""
    # Loop through all the atom counts
    for (atom, ct) in enumerate(atomcounts)
        # Skip any zeros
        ct = 0 && continue
        str *= ELEMENT_LOOKUP[atom] * string(ct) * space
    end
    return str
end

"""
    formula_string(a::AtomList; reduce=true) -> String

Generates a string giving the atomic formula for an `AtomicPosition`. By default, common factors
will be reduced.
"""
formula_string(a::AtomList{D}; reduce=true) where D = formula_string(a.coord, reduce=reduce)

function Base.show(io::IO, ::MIME"text/plain", b::AbstractBasis)
    println(io, typeof(b), ":")
    printbasis(io, b, pad=2)
end

function Base.show(io::IO, ::MIME"text/plain", b::RealBasis)
    println(io, typeof(b), ":")
    printbasis(io, b, pad=2, unit="Å")
end

function Base.show(io::IO, ::MIME"text/plain", b::ReciprocalBasis)
    println(io, typeof(b), ":")
    printbasis(io, b, pad=2, unit="Å⁻¹")
end

function Base.show(io::IO, ::MIME"text/plain", a::AtomPosition; name=true, num=true)
    println(io, typeof(a), ":")
    println(io, "  ", atom_string(a, name=name, num=num))
end

function Base.show(io::IO, ::MIME"text/plain", a::AtomList; name=true, num=true, letters=true)
    # Print type name
    println(io, typeof(a), ":")
    # Print atomic positions
    println(io, "  Atomic positions:")
    for atom in a.coord
        println(io, "    ", atom_string(atom, name=name, num=num))
    end
    # Print basis vectors
    println("  defined in terms of basis vectors:")
    printbasis(io, basis(a), pad=2)
end

function Base.show(io::IO, ::MIME"text/plain", g::RealSpaceDataGrid{D,T}) where {D,T}
    dimstring = join(string.(gridsize(g)), "×") * " "
    println(io, dimstring, typeof(g), " with basis vectors:")
    print(join(basis_string(basis(g), unit="Å"), "\n"))
    println("\nCell volume: ", volume(g), " Å³")
    print("Voxel size: ", voxelsize(g), " Å³")
end

# ReciprocalWavefunction{D,T}
function Base.show(io::IO, ::MIME"text/plain", wf::ReciprocalWavefunction{D,T}) where {D,T}
    println(io,
        typeof(wf), " with ",
        string(nspin(wf)), " spins",
        string(nkpt(wf)), " k-points and ",
        string(nband(wf)), " bands"
    )
end

function Base.show(io::IO, ::MIME"text/plain", l::AbstractLattice{D}) where D
    println(io, typeof(l), ":\n\n  Primitive basis vectors:")
    printbasis(io, l.prim, unit="Å" * "⁻¹"^(l isa ReciprocalLattice))
    println(io, "\n\n  Conventional basis vectors:")
    printbasis(io, l.conv, unit="Å" * "⁻¹"^(l isa ReciprocalLattice))
end

# TODO: Get rid of direct struct access
# Use methods to get the data instead.
function Base.show(io::IO, ::MIME"text/plain", xtal::Crystal{D}) where D
    println(io, typeof(xtal), " (space group ", xtal.sgno, "): ")
    # Print basis vectors
    println(io, "\n  Primitive basis vectors:")
    printbasis(io, xtal.latt.prim, pad=2, unit="Å")
    println(io, "\n\n  Conventional basis vectors:")
    printbasis(io, xtal.latt.conv, pad=2, unit="Å")
    # Add in more info about atomic positions, space group
    println(io, "\n\n  Generating set of atomic positions:")
    println(io, "    Num   ", "Name  ", "Position")
    for atom in xtal.gen.coord
        println(io, "    ", atom_string(atom, name=true, num=true, entrysz=6))
    end
    # Determine what basis the atomic coordinates are given in.
    # If the basis is zero, assume Cartesian coordinates in Å
    if basis(xtal.gen) == zeros(BasisVectors{D})
        println("  in Cartesian coordinates (assumed to be in units of Å)")
        return nothing
    end
    gen_primbasis = xtal.gen.basis == xtal.latt.prim
    gen_convbasis = xtal.gen.basis == xtal.latt.conv 
    # If both bases are identical, don't specify primitive or conventional
    if gen_primbasis && gen_convbasis
        print("  with respect to crystal basis")
    elseif gen_primbasis
        print(io, "  with respect to primitive basis")
    elseif gen_convbasis
        print(io, "  with respect to conventional basis")
    else
        println(io, "basis:")
        printbasis(io, xtal.gen.basis, pad=2)
    end
end

# CrystalWithDatasets{D,K,V}
function Base.show(io::IO, ::MIME"text/plain", x::CrystalWithDatasets{D,K,V}) where {D,K,V}
    println(io, typeof(x), " containing:\n")
    show(io, MIME("text/plain"), x.xtal)
    print("\n\nand a ")
    show(io, MIME("text/plain"), x.data)
end

function Base.show(
    io::IO,
    ::MIME"text/plain",
    s::SphericalComponents{Lmax};
    showto = 3
) where Lmax
    # Don't include generated second type parameter
    print(io, "SphericalComponents{$Lmax}", ":\n", " "^13)
    # Only print up to l=3 components by default (kw showto)
    Lmax_eff = min(showto, Lmax)
    for m = -Lmax_eff:Lmax_eff
        print(io, rpad("m = $m", 12))
    end
    for l in 0:Lmax_eff
        print(io, "\n", rpad("l = $l:", 8))
        for m = -Lmax_eff:Lmax_eff
            if abs(m) <= l
                print(io, lpad(@sprintf("%6f", s[l,m]), 12))
            else
                print(io, " "^12)
            end
        end
    end
    if showto < Lmax
        print(io, "\n(higher order components omitted for brevity)")
    end
end
