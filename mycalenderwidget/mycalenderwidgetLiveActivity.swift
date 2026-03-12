//
//  mycalenderwidgetLiveActivity.swift
//  mycalenderwidget
//
//  Created by tanakamiki on 2026/03/13.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct mycalenderwidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct mycalenderwidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: mycalenderwidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension mycalenderwidgetAttributes {
    fileprivate static var preview: mycalenderwidgetAttributes {
        mycalenderwidgetAttributes(name: "World")
    }
}

extension mycalenderwidgetAttributes.ContentState {
    fileprivate static var smiley: mycalenderwidgetAttributes.ContentState {
        mycalenderwidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: mycalenderwidgetAttributes.ContentState {
         mycalenderwidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: mycalenderwidgetAttributes.preview) {
   mycalenderwidgetLiveActivity()
} contentStates: {
    mycalenderwidgetAttributes.ContentState.smiley
    mycalenderwidgetAttributes.ContentState.starEyes
}
