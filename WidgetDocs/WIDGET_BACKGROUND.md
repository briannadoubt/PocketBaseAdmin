# Displaying the right widget background | Apple Developer Documentation
Group your widget’s background views and mark them as removable to ensure your widget appears correctly for each context and platform.

## [Overview](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background#Overview)

Widgets appear differently based on their context, including their background view, for example:

* In the [`vibrant`](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/vibrant) appearance, the system removes the background of your widget or renders it with semi-translucent appearance.

* In StandBy on iPhone, the system removes the background of your widget.

To make sure your widget appears correctly, mark your background views as removable for every widget size.

To mark your background views as removable:

1. Add the [`containerBackground(_:for:)`](https://developer.apple.com/documentation/SwiftUI/View/containerBackground(_:for:)) modifier to your background views to define the background appearance of your widget and tell WidgetKit that it can remove the view where applicable.

2. Move code that declares any background color or views inside the `containerBackground(for:)` view modifier and pass [`widget`](https://developer.apple.com/documentation/SwiftUI/ContainerBackgroundPlacement/widget) to it. This makes sure WidgetKit automatically removes the background as needed.

⠀
The following code snippet from the [Emoji Rangers: Supporting Live Activities, interactivity, and animations](https://developer.apple.com/documentation/widgetkit/emoji-rangers-supporting-live-activities-interactivity-and-animations) sample code project defines a `gameBackground` color for the widget’s container background to make sure WidgetKit renders it with or without the background color as applicable.

```
var body: some View {
    switch family {
    // Logic for additional widget sizes.
    case .accessoryRectangular:
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading) {
                Text(entry.hero.name)
                    .font(.headline)
                    .widgetAccentable()
                Text("Level \(entry.hero.level)")
                Text(entry.hero.fullHealthDate, style: .timer)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Avatar(hero: entry.hero, includeBackground: false)
        }
        .containerBackground(for: .widget) {
            Color.gameBackground
        }
  // Logic for additional widget sizes.
}
```

Marking background views as removable by defining a background container so you can use the same layout and views for your widget across contexts. For example, if you support the rectangular accessory widget size as shown in the code snippet above, WidgetKit renders it with a rich, full-color background in the Smart Stack on Apple Watch and without a background as a watch complication or on the Lock Screen of iPhone and iPad.

On Apple Watch, rectangular widgets in the Smart Stack use a default dark material background. By adding a container background, the widget renders with a background that visually ties it to your app and makes it more recognizable to people.

To detect whether a widget appears with or without a background, use the [`showsWidgetContainerBackground`](https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/showsWidgetContainerBackground) environment variable.

### [Explicitly opt out of background removal](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background#Explicitly-opt-out-of-background-removal)

Some widgets don’t have distinct foreground content, and background removal can negatively impact their functionality. For example, a widget might display a photo or map that takes up the entirety of the widget’s bounds. Removing the photo or map removes the functionality of the widget. If this case applies to your widget, set the [`containerBackgroundRemovable(_:)`](https://developer.apple.com/documentation/SwiftUI/WidgetConfiguration/containerBackgroundRemovable(_:)) modifier to `false` for your widget configuration.

### [Set the background color of accessory widgets](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background#Set-the-background-color-of-accessory-widgets)

Depending on your accessory widget or complication, you may need to set a consistent background for your accessory widget. Use [`AccessoryWidgetBackground`](https://developer.apple.com/documentation/widgetkit/accessorywidgetbackground) to draw a consistent background for your widget, as shown in the following example. It creates a view that’s similar to the circular Lock Screen widget that the Calendar app offers:

```
ZStack {
     AccessoryWidgetBackground()
     VStack {
        Text(“MON”)
        Text(“6”)
         .font(.title)
    }
}
```

[Displaying the right widget background | Apple Developer Documentation](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
