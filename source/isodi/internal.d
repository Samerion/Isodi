module isodi.internal;

import std.string;
import std.concurrency;

package:

/// Iterate on file ancestors, starting from and including the file and ending on the root.
auto deepAncestors(string dir) {

    return new Generator!string({

        while (dir.length) {

            // Yield the content
            yield(dir);

            // Remove last path segment
            dir = dir[0 .. dir.stripRight("/").lastIndexOf("/")];

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
