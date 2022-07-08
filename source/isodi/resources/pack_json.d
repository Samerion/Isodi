/// This module implements pack loading.
///
/// See_Also:
///     `isodi.resources.pack`
module isodi.resources.pack_json;

import raylib;
import rcdata.json;

import std.conv;
import std.file;
import std.path;
import std.array;
import std.string;
import std.algorithm;

import isodi.utils;
import isodi.skeleton;
import isodi.exception;
import isodi.resources.pack;
import isodi.resources.loader;


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
                options[path.strip("/").stripExtension] = json.save;
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

    const grassOptions = pack.fileOptions["block"];
    assert(!grassOptions.interpolate);
    assert(grassOptions.tileSize == 32);
    assert(grassOptions.sideArea == [0, 32, 128, 96]);

}

/// Parse a bone set from a JSON string.
BoneUV[BoneType] parseBoneSet(string json, BoneType delegate(wstring) @safe bonePicker) @trusted {

    auto parser = JSONParser(json);
    BoneUV[BoneType] result;

    // Get each
    foreach (key; parser.getObject) {

        // Get the bone type
        const type = bonePicker(key);

        // Load the value
        const uv = cast(RectangleI) parser.get!(int[4]);

        // Save the UV
        result[type] = BoneUV(uv);
        // TODO support variants

    }

    return result;

}

unittest {

    auto pack = new Pack();
    auto boneSet = parseBoneSet(q{
        {
            "torso": [1, 1, 56, 16],
            "head": [1, 18, 40, 14],
            "thigh": [43, 18, 20, 12],
            "abdomen": [1, 33, 31, 7],
            "upper-arm": [43, 31, 20, 13],
            "lower-leg": [1, 41, 12, 9],
            "hips": [1, 52, 40, 6],
            "hand": [43, 45, 20, 3],
            "forearm": [51, 49, 12, 9],
            "foot": [11, 59, 52, 4]
        }
    }, bone => pack.boneType("model", bone.to!string));

    assert(boneSet[BoneType(0)] == BoneUV(RectangleI(1, 1, 56, 16)));

    const forearm = pack.boneType("model", "forearm");
    assert(boneSet[forearm] == BoneUV(RectangleI(51, 49, 12, 9)));

}

Bone[] parseSkeleton(BoneType delegate(wstring) @safe bonePicker, string json) {

    auto parser = JSONParser(json);
    return parseSkeletonImpl(bonePicker, parser, 0, 0);

}

Bone[] parseSkeletonImpl(BoneType delegate(wstring) @safe bonePicker, ref JSONParser parser, size_t parent,
size_t index, float divisor = 1) @trusted
do {

    auto result = [Bone(index, BoneType.init, parent, MatrixIdentity)];
    size_t childIndex = index + 1;

    foreach (key; parser.getObject) {

        switch (key) {

            case "name":
                result[0].type = bonePicker(parser.getString);
                break;

            case "matrix":
                result[0].transform = Matrix(parser.get!(float[16]).tupleof);
                break;

            case "transform":

                // Get the transform matrix
                auto rhs = parser.parseTransforms;

                // Reduce the translations
                rhs.m12 /= divisor;
                rhs.m13 /= divisor;
                rhs.m14 /= divisor;

                result[0].transform = mul(
                    result[0].transform,
                    rhs,
                );
                break;

            case "vector":
                result[0].vector = Vector3(parser.get!(float[3]).tupleof) / divisor;
                break;

            case "children":
                foreach (child; parser.getArray) {

                    // Add the child
                    const ret = parseSkeletonImpl(bonePicker, parser, index, childIndex, divisor);
                    result ~= ret;

                    // Advance the index
                    childIndex += ret.length;

                }
                break;

            case "divisor":

                // TODO It would be nice to remove those restrictions
                enforce!PackException(result[0].transform == MatrixIdentity,
                    "`divisor` must precede `matrix` & `transform` fields");
                enforce!PackException(result[0].vector == Vector3.init,
                    "`divisor` must precede the `vector` field");

                divisor = parser.get!float;
                break;

            default:
                throw new PackException(format!"Unknown key '%s' on line %s"(key, parser.lineNumber));

        }

    }

    return result;

}

/// Parse a JSON transform list.
///
/// Available transforms:
/// * `["translate", float x, float y, float z]`
/// * `["rotate", float angle, float x, float y, float z]`; angle in degrees, x,y,z multiplier
/// * `["rotateX", float angle]`, `["rotateY", float]`, `["rotateZ", float]`; angle in degrees
/// * `["scale", float x, float y, float z]`
Matrix parseTransforms(ref JSONParser parser) @trusted {

    auto result = MatrixIdentity;

    enum TransformType {
        translate,
        rotate,
        rotateX,
        rotateY,
        rotateZ,
        scale,
    }

    // Get each option in the array
    foreach (_; parser.getArray) {

        TransformType type;
        float[4] values;

        // Run the transform
        foreach (i; parser.getArray) {

            // First entry: transform type
            if (i == 0) {

                // Set the type
                type = parser.get!string.to!TransformType;
                continue;

            }

            assert(i < 5, format!"Too many arguments for '%s'"(type));

            // Other entries, set vector value
            values[i-1] = parser.get!float;

        }

        // Perform the transform
        with (TransformType) {

            const rhs = type.predSwitch(
                translate, MatrixTranslate(values.tupleof[0..3]),
                rotate,    MatrixRotate(Vector3(values.tupleof[1..4]), values[0] * 180 / PI),
                rotateX,   MatrixRotateX(values[0] * 180 / PI),
                rotateY,   MatrixRotateY(values[0] * 180 / PI),
                rotateZ,   MatrixRotateZ(values[0] * 180 / PI),
                scale,     MatrixScale(values.tupleof[0..3]),
            );

            result = mul(result, rhs);

        }

    }

    return result;

}
