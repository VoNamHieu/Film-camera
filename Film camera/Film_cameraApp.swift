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
        // ★★★ FIX: Only preload LUTs if RenderEngine initializes successfully ★★★
        if RenderEngine.isAvailable {
            RenderEngine.shared.preloadAllLUTs()
            print("✅ Film_cameraApp: RenderEngine ready, preloading LUTs")
        } else {
            print("⚠️ Film_cameraApp: RenderEngine unavailable - check Metal shaders")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
