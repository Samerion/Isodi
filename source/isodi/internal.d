module isodi.internal;

import std.string;

package:

/// Iterate on file ancestors, starting from and including the requested file and ending on the root.
struct DeepAncestors {

    const string path;

    int opApply(int delegate(string) dg) {

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

    int opApply(int delegate(wstring) dg) {

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
