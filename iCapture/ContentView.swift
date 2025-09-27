//
//  ContentView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                CameraView(authManager: authManager)
            } else {
                AuthView(authManager: authManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
