/// This module implements pack loading.
///
/// See_Also:
///     `isodi.resources.pack`
module isodi.resources.pack_json;

import rcdata.json;

import std.conv;
import std.file;
import std.path;
import std.array;
import std.string;
import std.algorithm;

import isodi.utils;
import isodi.exception;
import isodi.resources.pack;


@safe:


/// Read the pack directly from the JSON parser.
///
/// Note, this will not fill out the `path` property of the `Pack` struct, which is required to read resources.
/// Use the other overload to fill it automatically.
///
/// Params:
///     json = `JSONParser` instance to fetch data from.
/// Throws: `rcdata.json.JSONException` on type mismatch or type error
Pack getPack(ref JSONParser json) @trusted {

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
        foreach (ancestorPath; path.Ancestors) {

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
/// Throws: `rcdata.json.JSONException` on type mismatch or type error
Pack getPack(string filename) {

    // It might be a directory
    if (filename.isDir) {

        // Read pack.json by default
        filename = filename.buildPath("pack.json");

    }

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
    assert(!rootOptions.interpolate);
    assert(rootOptions.tileSize == 32);

    const grassOptions = pack.fileOptions["cells/grass"];
    assert(!grassOptions.interpolate);
    assert(grassOptions.tileSize == 32);
    assert(grassOptions.tileArea == [0, 32, 128, 96]);

}
