# Supporting additional widget sizes | Apple Developer Documentation
Offer widgets in additional contexts by adding support for various widget sizes.

## [Overview](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes#Overview)

After you add a widget extension to your app and create your first widget, add code to declare additional widgets your app supports using the [`supportedFamilies(_:)`](https://developer.apple.com/documentation/SwiftUI/WidgetConfiguration/supportedFamilies(_:)) property modifier. The sizes you use depend on the devices your app supports. If your app supports more than one platform, make sure to conditionally declare supported widget families.

The following example from the [Emoji Rangers: Supporting Live Activities, interactivity, and animations](https://developer.apple.com/documentation/widgetkit/emoji-rangers-supporting-live-activities-interactivity-and-animations) sample code project shows how you declare several widgets sizes in your [`Widget`](https://developer.apple.com/documentation/SwiftUI/Widget) implementation. The app supports accessory widgets in both watchOS and iOS and [`WidgetFamily.systemSmall`](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemsmall) and [`WidgetFamily.systemMedium`](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemmedium) widgets in iOS. Note the usage of the `#if os(watchOS)` macro to make sure you declare the correct supported widget families for each platform.

```
public var body: some WidgetConfiguration {
    makeWidgetConfiguration()
        .configurationDisplayName("Ranger Detail")
        .description("See your favorite ranger.")
#if os(watchOS)
        .supportedFamilies([.accessoryCircular,
                            .accessoryRectangular, .accessoryInline])
#else
        .supportedFamilies([.accessoryCircular,
                            .accessoryRectangular, .accessoryInline,
                            .systemSmall, .systemMedium, .systemLarge])
#endif
}
```

### [Update SwiftUI views to support additional sizes](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes#Update-SwiftUI-views-to-support-additional-sizes)

After you’ve declared support for additional widget sizes in your [`Widget`](https://developer.apple.com/documentation/SwiftUI/Widget), update the views of your widget to support the additional family sizes. In your view code:

1. Use the [`widgetFamily`](https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/widgetFamily) environment variable to detect different widget families.

2. Construct the view for each size and include code to handle appearances like vibrant and Dark Mode, as applicable. To learn more, see [Preparing widgets for additional platforms, contexts, and appearances](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).

⠀
The following example shows an abbreviated code snippet from the [Emoji Rangers: Supporting Live Activities, interactivity, and animations](https://developer.apple.com/documentation/widgetkit/emoji-rangers-supporting-live-activities-interactivity-and-animations) sample code project. It conditionally returns the right SwiftUI view for each widget family.

```
struct EmojiRangerWidgetEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryCircular:
            // Code to construct the view for the circular accessory widget or watch complication.
        case .accessoryRectangular:
            // Code to construct the view for the rectangular accessory widget or watch complication.
        case .accessoryInline:
            // Code to construct the view for the inline accessory widget or watch complication.
        case .systemSmall:
            // Code to construct the view for the small widget.
        case .systemLarge:
            // Code to construct the view for the large widget.
        case .systemMedium
            // Code to construct the view for the medium widget.
        default:
            // Code to construct the view for other widgets, for example, the extra large widget.
        }
    }
}
```

[Supporting additional widget sizes | Apple Developer Documentation](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes)
