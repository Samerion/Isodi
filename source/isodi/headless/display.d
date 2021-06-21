module isodi.headless.display;

import isodi.display;

///
final class HeadlessDisplay : Display {

    override void reloadResources() {

        packs.clearCache();

    }

}
