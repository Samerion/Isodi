module isodi.raylib.internal;

import isodi.bind;

/// Put text in color using ANSI codes on POSIX platforms.
///
/// On other platforms, this just returns the original string.
static string colorText(string text, LogType type) {

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
