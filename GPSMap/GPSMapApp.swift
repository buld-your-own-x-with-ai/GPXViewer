//
//  GPSMapApp.swift
//  GPSMap
//
//  Created by i on 2025/9/7.
//

import SwiftUI

@main
struct GPSMapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
}
