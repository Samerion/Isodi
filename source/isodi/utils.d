module isodi.utils;

import raylib;
import core.stdc.stdlib;

import std.string;
import std.random;
import std.functional;


@safe:


/// Integer vector.
///
/// Note: Internally this might be later translated to a float anyway, so it might not be precise.
struct Vector2I {

    align (4):
    int x, y;

    Vector2I opBinary(string op)(Vector2I vec) const => Vector2I(
        mixin("x" ~ op ~ "vec.x"),
        mixin("y" ~ op ~ "vec.y"),
    );

    /// Get hash of the position.
    size_t toHash() const nothrow @nogc => y + 0x9e3779b9 + (x << 6) + (x >>> 2);
    // Taken from https://github.com/dlang/phobos/blob/master/std/typecons.d#L1234
    // Which in turn takes from https://www.boost.org/doc/libs/1_55_0/doc/html/hash/reference.html#boost.hash_combine

}

struct RectangleI {

    align (4):
    int x, y;
    int width, height;

    /// Convert the rectangle to a shader rectangle relative to texture size.
    Rectangle toShader(Vector2 textureSize) @nogc const => Rectangle(
        x / textureSize.x,
        y / textureSize.y,
        width  / textureSize.x,
        height / textureSize.y,
    );

}

/// Perform a reinterpret cast.
///
/// Note: Using `cast()` for reinterpret casts is not legal for values, per spec. DMD does allow that, but LDC segfaults.
To reinterpret(To, From)(From from)
in {
    static assert(From.sizeof == To.sizeof, "From and To type size mismatch");
}
do {

    union Union {
        From before;
        To after;
    }

    // Write the value to the union and read as the target
    return Union(from).after;

}

/// Make a simple struct out of a static array. Used to apply `.tupleof` on the arrays in DMD 2.099.
auto structof(T, size_t size)(T[size] value) {

    struct StructOf {
        static foreach (i; 0..size) {
            mixin(format!"T t%s;"(i));
        }
    }
    return value.reinterpret!StructOf;

}

/// Multiplying matrices the proper way
Matrix mul(Matrix[] ms...) @trusted @nogc nothrow {

    auto result = ms[0];

    foreach (m; ms[1..$]) {

        result = MatrixMultiply(result, m);

    }

    return result;

}

/// Assign a single chunk of values to an array, assuming the array is made up of fixed size chunks.
void assignChunk(T)(T[] range, size_t index, T[] values...) @nogc pure {

    foreach (i, value; values) {

        range[values.length * index + i] = value;

    }

}

///
@system
unittest {

    int[6] foo;

    foreach (i; 0 .. foo.length/2) {

        foo[].assignChunk(i, 1, 2);

    }

    assert(foo == [1, 2, 1, 2, 1, 2]);

}

/// Assign a single chunk of values to an array, altering the array first.
template assignChunk(alias fun) {

    void assignChunk(T, U)(T[] range, size_t index, U[] values...) @nogc pure {

        alias funnier = unaryFun!fun;

        foreach (i, value; values) {

            range[values.length * index + i] = funnier(value);

        }

    }

}

///
@system
unittest {

    int[6] foo;

    foreach (i; 0 .. foo.length/2) {

        foo[].assignChunk!(a => cast(int) i*2 + a)(i, 1, 2);

    }

    assert(foo == [1, 2, 3, 4, 5, 6]);

}

/// Assign multiple copies of the same value to the array, indexing it by chunks of the same size.
void assign(T)(T[] range, size_t index, size_t count, T value) @nogc pure {

    const start = count * index;
    range[start .. start + count] = value;

}

/// Iterate on file ancestors, starting from and including the requested file and ending on the root.
struct DeepAncestors {

    const string path;

    int opApply(scope int delegate(string) @trusted dg) {

        auto dir = path[];

        while (dir.length) {

            // Remove trailing slashes
            dir = dir.stripRight("/");

            // Yield the content
            auto result = dg(dir);
            if (result) return result;

            // Get the position on which the segment ends
            auto segmentEnd = dir.lastIndexOf("/");

            // Stop if this is the last segment
            if (segmentEnd == -1) break;

            // Remove last path segment
            dir = dir[0 .. segmentEnd];

        }

        // Push empty path
        return dg("");

    }

}

/// Iterate on file ancestors starting from root, ending on and including the file itself.
struct Ancestors {

    const wstring path;

    int opApply(int delegate(wstring) @trusted dg) {

        wstring current;

        auto result = dg(""w);
        if (result) return result;

        // Check each value
        foreach (ch; path) {

            // Encountered a path separator
            if (ch == '/' || ch == '\\') {

                // Yield the current values
                result = dg(current);
                if (result) return result;
                current ~= "/";

            }

            // Add the character
            else current ~= ch;

        }

        // Yield the full path
        if (current.length && current[$-1] != '/') {

            result = dg(current);
            return result;

        }

        return 0;

    }

}

/// Get a random number in inclusive range.
T randomNumber(T, RNG)(T min, T max, ref RNG rng) @trusted
in (min <= max, "minimum value must be lesser or equal to max")
do {

    import std.conv;

    // This is a copy-paste from https://github.com/dlang/phobos/blob/v2.100.0/std/random.d#L2218
    // but made @nogc

    auto upperDist = unsigned(max - min) + 1u;
    assert(upperDist != 0);

    alias UpperType = typeof(upperDist);
    static assert(UpperType.min == 0);

    UpperType offset, rnum, bucketFront;
    do {

        rnum = uniform!UpperType(rng);
        offset = rnum % upperDist;
        bucketFront = rnum - offset;
    }

    // While we're in an unfair bucket...
    while (bucketFront > (UpperType.max - (upperDist - 1)));

    return cast(T) (min + offset);

}

/// Generate a random variant in the given atlas.
/// Param:
///     atlasSize = Size of the atlas used.
///     resultSize = Expected size of the result
///     seed = Seed to use
/// Returns: Offset of the variant texture in the given atlas.
Vector2I randomVariant(Vector2I atlasSize, Vector2I resultSize, ulong seed) @nogc {

    auto rng = Mt19937_64(seed);

    // Get the grid dimensions
    const gridSize = atlasSize / resultSize;

    // Get the variant number
    const tileVariantCount = gridSize.x * gridSize.y;
    assert(tileVariantCount > 0, "Invalid atlasSize or resultSize, all parameters must be positive");

    const variant = randomNumber(0, tileVariantCount-1, rng);

    // Get the offset
    return resultSize * Vector2I(
        variant % gridSize.x,
        variant / gridSize.x,
    );

}

/// Awful workaround to get writefln in @nogc :D
/// Yes, it does allocate in the GC.
package debug template writefln(T...) {

    void writefln(Args...)(Args args) @nogc @system {

        // We can GC-allocate in writeln, no need to care about that
        scope auto fundebug = delegate {

            import io = std.stdio;
            io.writefln!T(args);

        };
        (cast(void delegate() @nogc) fundebug)();

    }

}
