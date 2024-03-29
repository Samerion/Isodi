/// Intermediate module for binding rendering libraries to Isodi.
///
/// All functions in this module should be implemented by the bindings.
module isodi.bind;

import isodi.anchor;
import isodi.position;

public {
    import isodi.cell;
    import isodi.model;
    import isodi.anchor;
    import isodi.display;
    import isodi.pack_list;
}

/// Defines type of a log message
enum LogType {

    info,     /// General information, usually white.
    success,  /// An operation (eg. test) has succeeded, usually green.
    error,    /// An operation (eg. test) has failed, usually red.

}


@safe:


/// Put text in color using ANSI codes on POSIX platforms.
///
/// On other platforms, this just returns the original string.
string colorText(string text, LogType type) {

    version (Posix) {

        import std.format : format;

        string fString() {

            // Posix platforms
            with (LogType)
            final switch (type) {

                case info: return "%s";
                case success: return "\033[32m%s\033[0m";
                case error: return "\033[91m%s\033[0m";

            }

        }

        return fString.format(text);

    }

    else return text;

}

/// Interface of Isodi renderer bindings. Implement the functions to match behavior of your renderer.
interface Bindings {

    /// An instance of a binding object.
    static Bindings inst;

    /// Output the given text to log.
    ///
    /// This is renderer dependent, because some renderers supply their own logging functionality, for example,
    /// $(LINK2 https://godotengine.org, Godot Engine).
    ///
    /// Params:
    ///     text = Text to output.
    ///     type = Type of the log message.
    void log(string text, LogType type = LogType.info);

    /// Create an instance of the `Display` in order to fit the needs of the renderer.
    Display createDisplay();

    /// Create a pack list to manage packs.
    PackList createPackList();

    /// Create a cell.
    Cell createCell(Display display, const Position position, const string type);

    /// Create an anchor
    Anchor createAnchor(Display);

    /// Create a model
    Model createModel(Display, const string type);

    /// Register a binding object
    mixin template Register(T) {

        static this() {

            import isodi.bind : Bindings;
            Bindings.inst = new T;

        }

    }

    /// Register a constructor.
    mixin template Constructor(BaseType, Extension) {

        import std.traits : Parameters;

        private enum Name = "create" ~ __traits(identifier, BaseType);
        private alias ParamTypes = Parameters!(__traits(getMember, Bindings, Name));

        mixin("BaseType " ~ Name ~ q{ (ParamTypes args) {

            return new Extension(args);

        }});

    }

}

/// Helper for calling renderer bindings.
alias Renderer = Bindings.inst;
