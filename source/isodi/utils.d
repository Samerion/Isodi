module isodi.utils;

import core.stdc.stdlib;

import std.string;
import std.functional;


@safe:



/// Malloc an array and return it.
T[] mallocArray(T)(size_t count) @system @nogc {

    // TODO check mallocArray for safety, specifically against signal 6

    auto ptr = cast(T*) malloc(T.sizeof * count);
    return ptr[0..count];

}

/// Assign a single chunk of values to an array, assuming the array is made up of fixed size chunks.
void assign(T)(T[] range, size_t index, T[] values...) @nogc pure {

    // TODO: rename to assignChunk

    foreach (i, value; values) {

        range[values.length * index + i] = value;

    }

}

///
@system
unittest {

    int[6] foo;

    foreach (i; 0 .. foo.length/3) {

        foo[].assign(i, 1, 2);

    }

    assert(foo == [1, 2, 1, 2, 1, 2]);

}

/// Assign a single chunk of values to an array, altering the array first.
template assign(alias fun) {

    void assign(T)(T[] range, size_t index, T[] values...) @nogc pure {

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

    foreach (i; 0 .. foo.length/3) {

        foo[].assign!(a => cast(int) i*2 + a)(i, 1, 2);

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
