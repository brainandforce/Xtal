#---Helper functions used to print common features (e.g. basis vectors)----------------------------#
"""
    Electrum.subscript_string(x::Number) -> String

Produces a string representation of a number in subscript format.
"""
function subscript_string(x::Number)
    str = collect(string(x))
    for (n,c) in enumerate(str)
        ('0' <= c <= '9') && (str[n] = c + 0x2050)
        (c === '-') && (str[n] = '₋')
        (c === '+') && (str[n] = '₊')
    end
    return String(str)
end

"""
    Electrum.vector_string(v::AbstractVector{<:Real}; brackets=true) -> String

Prints a representation of a vector as a string. The numbers use the standard C float (`%f`)
formatting.
"""
function vector_string(v::AbstractVector{<:Real}; brackets=true)
    # Format the numbers within a vector
    tostr(x, n) = lpad(@sprintf("%f ", x), n)
    return "["^brackets * join(tostr.(v, 11)) * "]"^brackets
end

"""
    Electrum.basis_string(
        M::AbstractMatrix{<:Real};
        pad=2,
        brackets=true,
        letters=true,
        length=true,
        unit=""
    ) -> Vector{String}

Creates an array of strings that represent the basis vectors of a crystal lattice given by `M`.
Several options exist to control the formatting of the output:
  * `pad` is the number of spaces used to indent the output (2 by default).
  * `brackets` adds square brackets to delimit the vector.
  * `letters` assigns letter labels to each basis vector.
  * `length` appends the lengths of the basis vector to the end of each string.
  * `unit` appends a unit to the lengths. This parameter is ignored if `length` is set to `false`.

# Example
```
julia> M = 3.5 * [0 1 1; 1 0 1; 1 1 0]
3×3 Matrix{Float64}:
 0.0  3.5  3.5
 3.5  0.0  3.5
 3.5  3.5  0.0

julia> Electrum.basis_string(M, letters=true, length=true, unit="Å")
3-element Vector{String}:
 "  a: [  0.000000  3.500000  3.500000 ]   (4.949747 Å)"
 "  b: [  3.500000  0.000000  3.500000 ]   (4.949747 Å)"
 "  c: [  3.500000  3.500000  0.000000 ]   (4.949747 Å)"
```
"""
function basis_string(
    M::AbstractMatrix{<:Real};
    pad=2,
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
        " "^pad * string(Char(0x60 + n), ':', ' ')^letters *
        vector_string(M[:,n]; brackets) *
        ("   (" * tostr(norm(M[:,n]), 0))^length * " "^!isempty(unit) * unit * ")"
        for n in axes(M,2)
    ]
end

basis_string(b::RealBasis, kwargs...) = basis_string(matrix(b), unit="Å", kwargs...)
basis_string(b::ReciprocalBasis, kwargs...) = basis_string(matrix(b), unit="Å⁻¹", kwargs...)

"""
    Electrum.printbasis([io::IO = stdout], b; kwargs...)

Prints the result of `basis_string()` to `io`.

# Examples
```jldoctest
julia> M = 3.5 * [0 1 1; 1 0 1; 1 1 0]
3×3 Matrix{Float64}:
 0.0  3.5  3.5
 3.5  0.0  3.5
 3.5  3.5  0.0

julia> Electrum.printbasis(stdout, M)
  a: [  0.000000  3.500000  3.500000 ]   (4.949747)
  b: [  3.500000  0.000000  3.500000 ]   (4.949747)
  c: [  3.500000  3.500000  0.000000 ]   (4.949747)
```
"""
function printbasis(io::IO, M::AbstractMatrix{<:Real}; letters=true, unit="", pad=0)
    s = basis_string(M; letters, unit)
    print(io, join(" "^pad .* s, "\n"))
end

printbasis(io::IO, b::RealBasis; kwargs...) = printbasis(io, matrix(b), unit="Å"; kwargs...)
printbasis(io::IO, b::ReciprocalBasis; kw...) = printbasis(io, matrix(b), unit="Å⁻¹"; kw...)
printbasis(io::IO, a; kwargs...) = printbasis(io, basis(a); kwargs...)
printbasis(a; kwargs...) = printbasis(stdout, a; kwargs...)

"""
    atom_string(a::AbstractAtomPosition; name=true, num=true)

Generates a string describing an atom position.
"""
function atom_string(a::AbstractAtomPosition; name=true, num=true)
    # Format the numbers within a vector
    tostr(x) = lpad(@sprintf("%f", x), 10)
    return string(
        rpad(string(a.atom.num), 4)^num,
        rpad(a.atom.name, 6)^name,
        vector_string(a.pos),
        "  Å"^(a isa CartesianAtomPosition),
        "  (occupancy $(a.occ))"^(a.occ != 1)
    )
end

"""
    Electrum.formula_string(l::AtomList; reduce=true, show_ones=false) -> String
    Electrum.formula_string(l::AbstractCrystal; kwargs...) -> String

Prints a string which represents the chemical formula of the atoms within an `AtomList` or 
`AbstractCrystal`.

By default, the formula is reduced by common factors of the atom counts. This may be disabled by
setting `reduce=false`. Ones are also eliminated from the formula string; this may be disabled by
setting `show_ones=true`.
"""
function formula_string(l::AbstractAtomList; reduce=true, show_ones=false)
    # If there are only dummy atoms, 
    all(isdummy, l) && return "no formula"
    counts = [x.second for x in atomcounts(l)]
    counts = div.(counts, gcd(counts)^reduce)
    return join(
        [
            # Print only if the count is not 1 and/or show_ones is true
            n * subscript_string(c)^(!isone(c) || show_ones)
            for (n,c) in zip(name.(atomtypes(l)), counts)
        ]
    )
end

formula_string(l::AbstractCrystal; kwargs...) = formula_string(PeriodicAtomList(l); kwargs...)

#---Actual show methods----------------------------------------------------------------------------#

# These are what you see when something is returned in the REPL.
# To define these methods for a type, just overload show(::IO, ::MIME"text/plain", ::T)
# To get the result as a string, just use repr("text/plain", x)

#---Types from lattices.jl (RealBasis, ReciprocalBasis)--------------------------------------------#

function Base.show(io::IO, ::MIME"text/plain", b::AbstractBasis)
    println(io, typeof(b), ":")
    printbasis(io, b, pad=2)
end

#---Types from atoms.jl (AtomPosition, AtomList)---------------------------------------------------#

function Base.show(io::IO, ::MIME"text/plain", a::AbstractAtomPosition; kwargs...)
    println(io, typeof(a), ":")
    print(io, "  ", atom_string(a; kwargs...))
end

function Base.show(io::IO, ::MIME"text/plain", l::AbstractAtomList; kwargs...)
    # Print type name
    print(io, typeof(l), " (", formula_string(l), "):\n")
    # Print atomic positions
    print(io, "  ", length(l), " atomic positions:")
    for atom in l
        print(io, "\n    ", atom_string(atom; kwargs...))
    end
    # Print basis vectors
    if l isa PeriodicAtomList
        println("\n  defined in terms of basis vectors:")
        printbasis(io, l, pad=2)
    end
end

#---Types from data/realspace.jl-------------------------------------------------------------------#

function Base.show(io::IO, ::MIME"text/plain", g::RealSpaceDataGrid)
    dimstring = join(string.(size(g)), "×") * " "
    println(io, dimstring, typeof(g), " with real space basis vectors:")
    printbasis(io, g)
    @printf(io, "\nCell volume: %16.10f Å", volume(g))
    @printf(io, "\nVoxel size:  %16.10f Å", voxelsize(g))
end

#---Types from data/reciprocalspace.jl-------------------------------------------------------------#

function Base.summary(io::IO, k::KPointList)
    print(io, length(k), "-element ", typeof(k), ":")
end

function Base.show(io::IO, ::MIME"text/plain", k::KPointList)
    summary(io, k)
    for n in eachindex(k)
        print(io, "\n ", k.points[n], " (weight ", k.weights[n], ")")
    end
end

function Base.show(io::IO, ::MIME"text/plain", g::HKLData)
    dimstring = join(string.(size(g)), "×") * " "
    println(io, dimstring, typeof(g), " with reciprocal space basis vectors:")
    printbasis(io, g)
    print(io, "\nSpatial frequency ranges:")
    for n in 1:length(basis(g))
        print(io, "\n  ", '`' + n, ":", )
        sz = size(g)[n]
        @printf(
            io, "%12.6f Å⁻¹ to %.6f Å⁻¹",
            -div(sz-1, 2) * lengths(basis(g))[n],
            div(sz, 2) * lengths(basis(g))[n],
        )
    end
end

function Base.show(io::IO, ::MIME"text/plain", wf::ReciprocalWavefunction)
    println(io,
        typeof(wf), " with ",
        string(nspin(wf)), " spin", "s"^(nspin(wf) != 1), ", ",
        string(nkpt(wf)), " k-point", "s"^(nkpt(wf) != 1), ", and ",
        string(nband(wf)), " band", "s"^(nband(wf) != 1)
    )
    println(io, "Reciprocal space basis vectors:")
    print(io, join(basis_string(basis(wf)), "\n"))
end

#---Types from data/atomic.jl----------------------------------------------------------------------#

function Base.show(
    io::IO,
    ::MIME"text/plain",
    s::SphericalHarmonic{Lmax};
    showto = 3
) where Lmax
    # Don't include generated second type parameter
    print(io, "SphericalHarmonic{$Lmax}", ":\n", " "^13)
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

#---Types from crystals.jl-------------------------------------------------------------------------#

function Base.show(io::IO, ::MIME"text/plain", xtal::Crystal{D}) where D
    println(io, typeof(xtal), " (", formula_string(xtal), ", space group ", xtal.sgno, "): ")
    # Print basis vectors
    println(io, "\n  Primitive basis vectors:")
    printbasis(io, xtal, pad=2, unit="Å")
    if xtal.transform != SMatrix{D,D,Float64}(LinearAlgebra.I)
        println(io, "\n\n  Conventional basis vectors:")
        printbasis(io, basis(xtal) * xtal.transform, pad=2, unit="Å")
    end
    # TODO: Add in more info about atomic positions, space group
    println(io, "\n\n  ", length(xtal.atoms), " atomic positions:")
    print(io, "    Num   ", "Name  ", "Position")
    for atom in xtal.atoms
        print(io, "\n    ", atom_string(atom, name=true, num=true))
    end
end

function Base.show(io::IO, ::MIME"text/plain", x::CrystalWithDatasets)
    println(io, typeof(x), " containing:\n")
    show(io, MIME("text/plain"), x.xtal)
    print("\n\nand a ")
    show(io, MIME("text/plain"), x.data)
end

#---Other internal types---------------------------------------------------------------------------#

function Base.show(io::IO, ::MIME"text/plain", h::ABINITHeader)  
    println(io, "abinit ", repr(h.codvsn)[3:end-1], " header (version ", h.headform, "):")
    for name in fieldnames(ABINITHeader)[3:end]
        print(io, "  ", rpad(string(name) * ":", 18))
        x = getfield(h, name)
        if typeof(x) <: Union{<:Number,<:SVector}
            println(io, x)
        elseif typeof(x) <: SMatrix
            println(io, replace(repr("text/plain", x), "\n " => "\n" * " "^21))
        elseif typeof(x) <: AbstractArray
            sizestr = if length(size(x)) == 1
                lpad(string(length(x), "-element "), 12)
            else    
                join(string.(size(x)), "×") * " "
            end
            println(io, sizestr, typeof(x), "...")
        else
            println(io, typeof(x), "...")
        end
    end
end
