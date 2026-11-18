import SwiftUI
import WidgetKit

// The widget extension's entry point, apart from the views so the screenshot tool can draw them
// with an entry point of its own.

@main
struct GraphitreeWidgets: WidgetBundle {
    var body: some Widget {
        UsageBarsWidget()
        UsageRingsWidget()
    }
}
