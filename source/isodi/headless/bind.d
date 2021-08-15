module isodi.raylib.bind;

import isodi.bind;
import isodi.internal;

import isodi.headless.cell;
import isodi.headless.model;
import isodi.headless.anchor;
import isodi.headless.display;
import isodi.headless.pack_list;


@safe:


/// Headless bindings for Isodi.
class HeadlessBinds : Bindings {

    mixin Register!HeadlessBinds;
    mixin Constructor!(Display,  HeadlessDisplay);
    mixin Constructor!(PackList, HeadlessPackList);
    mixin Constructor!(Cell,     HeadlessCell);
    mixin Constructor!(Anchor,   HeadlessAnchor);
    mixin Constructor!(Model,    HeadlessModel);

    /// Logging implementation. Simply wraps `writeln` and, on Posix platforms, add ANSI escape codes.
    void log(string text, LogType type) {

        import std.stdio : writeln;
        import std.format : format;

        text.colorText(type).writeln;

    }

}
