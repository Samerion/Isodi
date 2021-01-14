module isodi.internal;

import std.string;
import std.concurrency;

package:

/// Iterate on file ancestors, starting from and including the requested file and ending on the root.
auto deepAncestors(string path) {

    auto dir = path;

    return new Generator!string({

        while (dir.length) {

            // Remove trailing slashes
            dir = dir.stripRight("/");

            // Yield the content
            yield(dir);

            // Get the position on which the segment ends
            auto segmentEnd = dir.lastIndexOf("/");

            // Stop if this is the last segment
            if (segmentEnd == -1) break;

            // Remove last path segment
            dir = dir[0 .. segmentEnd];

        }

        // Push empty path
        yield("");

    });

}

/// Iterate on file ancestors starting from root, ending on and including the file itself.
auto ancestors(wstring dir) {

    wstring current;

    return new Generator!wstring({

        yield(""w);

        // Check each value
        foreach (ch; dir) {

            // Encountered a path separator
            if (ch == '/' || ch == '\\') {

                // Yield the current values
                yield(current);
                current ~= "/";

            }

            // Add the character
            else current ~= ch;

        }

        // Yield the full path
        if (current.length && current[$-1] != '/') yield(current);

    });

}
