# Isodi

Isodi is a library for isometric games.

Isodi combines 2D and 3D in a way to make it possible to create good looking games without the need to create
a special model for every object.

The library uses Raylib to render by default, but it's designed so it shouldn't be hard to bind it to another library.

**Note:** Isodi is currently in early development, most features aren't implemented. Use with care.

## Documentation

Isodi is still in early development, so the documentation may be incomplete. It aims to be compatible with DDox,
meaning you can build the documentation using `dub build -b=ddox`

## Testing

* `dub test` to run general raylib tests.
* `dub run -c=headless-unittest -b=unittest` to run headless tests.
