/// This module implements basic pack loading.
///
/// See_Also:
///     `isodi.pack`
module isodi.pack_json;

import std;  // Too many imports, stopped making sense to list them. Sorry.
import rcjson;

import isodi.pack;
import isodi.exceptions;

/// Iterate on file ancestors starting from root, ending on and including the file itself.
private auto ancestors(wstring dir) {

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

/// Iterate on file ancestors, starting from and including the file and ending on the root.
private auto deepAncestors(string dir) {

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

/// Read the pack directly from the JSON parser.
///
/// Note, this will not fill out the `path` property of the `Pack` struct, which is required to read resources.
/// Use the other overload to fill it automatically.
///
/// Params:
///     json = `JSONParser` instance to fetch data from.
/// Throws: `rcjson.JSONException` on type mismatch or type error
Pack getPack(ref JSONParser json) {

    JSONParser[wstring] options;

    auto pack = json.getStruct!Pack((ref Pack obj, wstring key) {

        // Global options
        if (key == "options") {

            // Alias to fileOptions[""]
            options[""] = json.save;
            json.skipValue();

        }

        // Local options
        else if (key == "fileOptions") {

            // Check each path
            foreach (path; json.getObject) {

                // Save the state
                options[path.strip("/")] = json.save;
                json.skipValue();

            }

        }

        // Unknown field, crash instead
        else enforce!PackException(0, key.format!"Unknown pack key \"%s\"");

    });

    // Handle inheritance — iterate on items sorted by length
    foreach (path; options.byKey.array.sort!`a.length < b.length`) {

        ResourceOptions builder;

        // Get all ancestors of this item
        foreach (ancestorPath; path.ancestors) {

            // If the ancestor exists
            if (auto p = ancestorPath in options) {

                // Restore state
                auto state = *p;

                // Update the struct
                builder = state.updateStruct(builder);

            }

        }

        // Save it
        pack.fileOptions[path.to!string] = builder;

    }

    // Before ending, make sure at least the root resource exists
    pack.fileOptions.require("", ResourceOptions());

    return pack;

}

/// Read the pack data from a JSON file.
/// Params:
///     filename = Name of the file to read from.
/// Throws: `rcjson.JSONException` on type mismatch or type error
Pack getPack(string filename) {

    // Get the pack
    auto json = filename.readText.JSONParser();
    auto pack = json.getPack;
    pack.path = filename.dirName;
    return pack;

}

unittest {

    // Load the pack
    auto pack = getPack("res/samerion-retro/pack.json");

    // Access properties
    assert(pack.name == "SamerionRetro");

    // Check the options of
    const rootOptions = pack.fileOptions[""];
    assert(!rootOptions.filter);
    assert(rootOptions.tileSize == 128);

    const grassOptions = pack.fileOptions["cells/grass"];
    assert(!grassOptions.filter);
    assert(grassOptions.tileSize == 128);
    assert(grassOptions.decorationWeight == 20);

}

/// Read options of the given resource.
/// Params:
///     pack = Pack to read from.
///     path = Relative path to the resource.
/// Returns: A pointer to the resource's options.
ResourceOptions* getOptions(Pack pack, string path) {

    /// Search for the closest matching resource
    foreach (file; path.stripRight("/").deepAncestors) {

        // Return the first one found
        if (auto p = file in pack.fileOptions) return p;

    }

    assert(0, pack.name.format!"Internal error: Root options missing for pack %s");

}

///
unittest {

    // Load the pack
    auto pack = getPack("res/samerion-retro/pack.json");

    // Check root options
    const rootOptions = pack.getOptions("");
    assert(!rootOptions.filter);
    assert(rootOptions.tileSize == 128);

    // Check if getOptions correctly handles resources that don't have any options set directly
    assert(pack.getOptions("cells/grass") is pack.getOptions("cells/grass/not-existing"));

}
