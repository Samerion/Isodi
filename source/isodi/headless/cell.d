module isodi.headless.cell;

import isodi.cell;
import isodi.display;
import isodi.position;

///
final class HeadlessCell : Cell {

    this(Display display, const Position position, const string type) {

        super(display, position, type);

    }

}
