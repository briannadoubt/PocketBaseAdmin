# Optimizing your widget for accented rendering mode and Liquid Glass | Apple Developer Documentation
Make your widget feel at home on Apple platforms and Liquid Glass by using accented rendering mode.

## [Overview](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass#Overview)

iPhone, iPad, Mac, and Apple Watch use Liquid Glass, a dynamic, adaptive material that also applies to widgets. When a person chooses a tinted or clear appearance for their Home Screen, the system:

* Renders your widget in the [`accented`](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/accented) rendering mode

* Tints primary and accented content white in iOS and macOS

* Tints primary content white and accented content in the color of the watch face in watchOS

* Tints opaque images with a single white color

* Maintains opacity for transparent content and gradients, and tints them white

* Removes the background and replaces it with a themed glass or tinted color effect

By already supporting the [`accented`](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/accented) rendering mode, some widgets don’t need any further adjustments. However, you might need to update your widget to keep its text readable and make it look at home with Liquid Glass; for example, if your widget includes images, gradients, or transparent content.

### [Support Liquid Glass](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass#Support-Liquid-Glass)

To update your widget to support Liquid Glass:

1. Add the [`widgetRenderingMode`](https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/widgetRenderingMode) environment variable and conditionally update your widget layout for each rendering mode as explained in the previous section.

2. Display full-color images, page, or partially transparent content only for the [`fullColor`](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/fullcolor) rendering mode.

3. Adjust your widget’s layout as needed for the [`accented`](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/accented) rendering mode.

4. Group your views into a primary and an accent group using the [`widgetAccentable(_:)`](https://developer.apple.com/documentation/SwiftUI/View/widgetAccentable(_:)) view modifier. Views you don’t mark as acceptable are part of the primary group.

5. Configure the rendering of any image using the [`WidgetAccentedRenderingMode`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode) view modifier.

⠀
### [Choose rendering modes for images and views](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass#Choose-rendering-modes-for-images-and-views)

Using the `WidgetAccentedRenderingMode` view modifier, conditionally render images and views as needed:

* [`accented`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/accented)
* Tints the image to the accent color. In iOS and macOS, primary and accent colors are white, causing the image to be a solid white color. In watchOS, the accent color matches the color on the watch face.

* [`desaturated`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/desaturated)
* Desaturates the image in iOS, macOS, and watchOS.

* [`accentedDesaturated`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/accenteddesaturated)
* Combines [`accented`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/accented) and [`desaturated`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/desaturated) accented rendering modes. In iOS and macOS, the image appears a little whiter compared to the `desaturated` rendering. In watchOS, the desaturated image takes on the color of the watch face.

* [`fullColor`](https://developer.apple.com/documentation/widgetkit/widgetaccentedrenderingmode/fullcolor)
* Renders the image in full color, without modifications in iOS and macOS. In watchOS, the system ignores this rendering mode to make sure the widget blends in with the watch face.

To learn more about Liquid Glass and how to design and develop interfaces that work well with the material, refer to [Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass) and [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass).

[Optimizing your widget for accented rendering mode and Liquid Glass | Apple Developer Documentation](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)
