# Isodi

Isodi is a library for isometric games.

Isodi combines 2D and 3D in a way to make it possible to create good looking games without the need to create
a special model for every object.

The library uses Raylib to render by default, but it's designed so it shouldn't be hard to bind it to another library.

**Note:** Isodi is currently in early development, most features aren't implemented. Use with care.

## Building

Building is done using [DUB](https://dub.pm). Use `dub add isodi` in your project to use Isodi as a dependency, then add
`"libs": ["raylib"]` to your DUB config. You must also install Raylib 4 in your system.

By default Isodi will build with full feature set. You can specify `"subconfigurations": {"isodi": "mini-tilemap"}` to
only include a minimal tilemap loader. This might come in handy when writing headless servers using Isodi maps.
