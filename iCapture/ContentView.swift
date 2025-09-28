//
//  ContentView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if onboardingManager.shouldShowOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .onDisappear {
                        onboardingManager.completeOnboarding()
                    }
            } else if authManager.isAuthenticated {
                CameraView(authManager: authManager)
            } else {
                AuthView(authManager: authManager)
            }
        }
        .onAppear {
            showOnboarding = onboardingManager.shouldShowOnboarding
        }
    }
}

#Preview {
    ContentView()
}
