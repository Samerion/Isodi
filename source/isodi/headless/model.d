module isodi.headless.model;

import isodi.model;
import isodi.display;


@safe:


///
final class HeadlessModel : Model {

    this(Display display, const string type = "") {

        super(display, type);

    }

    override void changeVariant(string id, string variant) {

    }

}
