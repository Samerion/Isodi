module isodi.raylib.bind;

import isodi.bind;

import isodi.raylib.cell;
import isodi.raylib.display;
import isodi.raylib.internal;
import isodi.raylib.pack_list;

/// Raylib bindings for Isodi.
class RaylibBinds : Bindings {

    mixin Register!RaylibBinds;
    mixin Constructor!(Display,  RaylibDisplay);
    mixin Constructor!(PackList, RaylibPackList);
    mixin Constructor!(Cell,     RaylibCell);

    /// Logging implementation. Simply wraps `writeln` and, on Posix platforms, add ANSI escape codes.
    void log(string text, LogType type) {

        import std.stdio : writeln;
        import std.format : format;

        text.colorText(type).writeln;

    }

}
