// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WelcomTalk",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "WelcomShared",
            targets: ["WelcomShared"]
        ),
    ],
    targets: [
        .target(
            name: "WelcomShared",
            path: "WelcomTalk",
            exclude: [
                "Assets.xcassets",
                "ContentView.swift",
                "Persistence.swift",
                "Services",
                "Utils",
                "Views",
                "ViewModels/SessionViewModel.swift",
                "WelcomTalk.entitlements",
                "WelcomTalk.xcdatamodeld",
                "WelcomTalkApp.swift",
            ],
            sources: [
                "Models/Session.swift",
                "Models/Note.swift",
                "Models/LogEntry.swift",
                "Models/ModificationRequest.swift",
                "Models/SessionRating.swift",
                "Models/User.swift",
                "Models/ScheduledMeeting.swift",
                "ViewModels/SessionSummaryViewModel.swift",
            ]
        ),
    ]
)