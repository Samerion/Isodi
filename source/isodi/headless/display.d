module isodi.headless.display;

import isodi.display;


@safe:


///
final class HeadlessDisplay : Display {

    override void reloadResources() {

        packs.clearCache();

    }

}
