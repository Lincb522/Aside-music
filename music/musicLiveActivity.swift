//
//  musicLiveActivity.swift
//  music
//
//  Created by linchengbo on 2026/2/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct musicAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct musicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: musicAttributes.self) { context in
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

extension musicAttributes {
    fileprivate static var preview: musicAttributes {
        musicAttributes(name: "World")
    }
}

extension musicAttributes.ContentState {
    fileprivate static var smiley: musicAttributes.ContentState {
        musicAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: musicAttributes.ContentState {
         musicAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: musicAttributes.preview) {
   musicLiveActivity()
} contentStates: {
    musicAttributes.ContentState.smiley
    musicAttributes.ContentState.starEyes
}
