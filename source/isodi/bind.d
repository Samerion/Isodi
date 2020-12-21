/// Intermediate module for binding rendering libraries to Isodi.
///
/// All functions in this module should be implemented by the bindings.
module isodi.bind;

public import isodi.display;

/// Defines type of a log message
enum LogType {

    info,     /// General information, usually white.
    success,  /// An operation (eg. test) has succeeded, usually green.
    error,    /// An operation (eg. test) has failed, usually red.

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
    ///
    /// Some renderers may want to bind events to method calls of `Display`.
    Display createDisplay();

    /// Register a binding object
    mixin template Register(T) {

        static this() {

            import isodi.bind : Bindings;
            Bindings.inst = new T;

        }

    }

}

/// Helper for calling renderer bindings.
alias Renderer = Bindings.inst;
