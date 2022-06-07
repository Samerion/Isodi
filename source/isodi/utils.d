module isodi.utils;

import std.functional;
import core.stdc.stdlib;


@safe:



/// Malloc an array and return it.
T[] mallocArray(T)(size_t count) @system @nogc {

    // TODO check mallocArray for safety, specifically against signal 6

    auto ptr = cast(T*) malloc(T.sizeof * count);
    return ptr[0..count];

}

/// Assign a single chunk of values to an array, assuming the array is made up of fixed size chunks.
void assign(T)(T[] range, size_t index, T[] values...) @nogc pure {

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
