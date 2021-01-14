module isodi.raylib.internal;

import raylib;

public import std.typecons;

import isodi.bind;
import isodi.position;

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

/// Convert position to Vector3
inout(Vector3) toVector3(inout(Position) position, uint cellSize, Flag!"center" center = No.center) {

    return Vector3(position.toTuple3(cellSize, center).expand);

}

/// Get a Vector3 from given position.
auto toTuple3(inout(Position) position, uint cellSize, Flag!"center" center = No.center) {

    alias Ret = Tuple!(float, float, float);

    // Center the position
    if (center) {

        return Ret(
            (position.x + 0.5) * cellSize,
            -position.height.top * cellSize,
            (position.y + 0.5) * cellSize,
        );

    }

    // Align to corner instead.
    else {

        return Ret(
            position.x * cellSize,
            -position.height.top * cellSize,
            position.y * cellSize + cellSize,
        );

    }

}
