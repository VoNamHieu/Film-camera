//
//  Film_cameraApp.swift
//  Film camera
//
//  Created by mac on 17/12/25.
//

import SwiftUI

@main
struct Film_cameraApp: App {

    init() {
        // ★ Preload all LUTs on app startup to eliminate UI jank
        RenderEngine.shared.preloadAllLUTs()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
