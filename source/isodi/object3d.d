///
module isodi.object3d;

import std.stdio;
import std.string;

public {

    import isodi.bind;
    import isodi.display;
    import isodi.position;
    import isodi.resource;

}

/// Represents an object that can be drawn on a 3D space.
abstract class Object3D {

    /// Display this object is connected to.
    Display display;

    /// Get the current position of the object.
    abstract const(Position) position() const;

    /// Get the current visual position of the object.
    abstract const(Position) visualPosition() const;

    /// Params:
    ///     display = Display to connect to.
    this(Display display) {

        this.display = display;

    }

    /// Add a basic implementation for the position as a property, includes a setter.
    mixin template Implement() {

        private Position _position;

        /// Get the current position of the object.
        ///
        /// This returns a const value, use `positionRef` to get a reference.
        override const(Position) position() const { return _position; }

        /// Ditto
        override const(Position) visualPosition() const { return position; }

        /// Get a reference to the position value.
        ref Position positionRef() { return _position; }

        /// Set the new position.
        Position position(Position value) { return _position = value; }

    }

    ///
    static unittest {

        class Example : Object3D {

            mixin Object3D.Implement;

            this() {
                super(null);
            }

        }

        auto ex = new Example;
        assert(ex.position == .position(0, 0));

        ex.positionRef.x += 1;
        assert(ex.position == .position(1, 0));

        ex.position = .position(2, 2);
        assert(ex.position == .position(2, 2));

    }

    /// Implement the position as a const property. `_position` and `_visualPosition` must be set in constructor.
    mixin template ImplementConst() {

        private const Position _position;
        override const(Position) position() const { return _position; }

        private Position _visualPosition;

        /// Get the position the cell is displayed on.
        override const(Position) visualPosition() const {

            return _visualPosition;

        }

        /// Set an offset for the visual position.
        ///
        /// $(B Note:) Mind that depth is initialized to 1 by default, which might cause unwanted effects. If you don't
        /// want to offset it, use `positionOff`.
        const(Position) offset(Position value) {

            return _visualPosition = Position(
                _position.x + value.x,
                _position.y + value.y,
                _position.layer + value.layer,
                Height(
                    _position.height.top + value.height.top,
                    _position.height.depth + value.height.depth,
                )
            );

        }

        /// Reset the offset
        void resetOffset() {

            _visualPosition = _position;

        }

    }

}
