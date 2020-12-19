module isodi.raylib.bind;

import isodi.bind;
import isodi.raylib.internal;

/// Raylib bindings for Isodi.
class RaylibBinds : Bindings {

    mixin Bindings.Register!RaylibBinds;

    /// Logging implementation. Simply wraps `writeln` and, on Posix platforms, add ANSI escape codes.
    void log(string text, LogType type) {

        import std.stdio : writeln;
        import std.format : format;

        text.colorText(type).writeln;

    }

}
