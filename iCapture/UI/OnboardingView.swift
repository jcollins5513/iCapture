//
//  OnboardingView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var showFrameBoxSetup = false

    private let onboardingPages = [
        OnboardingPage(
            title: "Welcome to iCapture",
            subtitle: "Hands-free vehicle photo capture system",
            description: "Capture professional vehicle photos automatically as drivers rotate " +
                         "their cars in front of your mounted iPhone.",
            imageName: "camera.viewfinder",
            primaryColor: .blue
        ),
        OnboardingPage(
            title: "Setup Your Frame Box",
            subtitle: "Define the capture area",
            description: "Position and resize the yellow frame box to capture the vehicle area. " +
                         "The system will automatically detect when vehicles enter this zone.",
            imageName: "rectangle.and.pencil.and.ellipsis",
            primaryColor: .yellow
        ),
        OnboardingPage(
            title: "Automatic Capture",
            subtitle: "Smart trigger system",
            description: "Photos are captured automatically when vehicles stop in the frame or " +
                         "every 5 seconds during rotation. No manual intervention needed.",
            imageName: "camera.fill",
            primaryColor: .green
        ),
        OnboardingPage(
            title: "Session Management",
            subtitle: "Organized by stock number",
            description: "Each capture session is tied to a vehicle stock number. All photos " +
                         "and videos are automatically organized and exported.",
            imageName: "folder.fill",
            primaryColor: .purple
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [onboardingPages[currentPage].primaryColor.opacity(0.8), Color.black.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom controls
                VStack(spacing: 20) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }

                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.white)
                        }

                        Spacer()

                        if currentPage < onboardingPages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                        } else {
                            Button("Get Started") {
                                completeOnboarding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showFrameBoxSetup) {
            FrameBoxSetupWizard(isPresented: $showFrameBoxSetup)
        }
    }

    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")

        // Show frame box setup wizard
        showFrameBoxSetup = true
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let primaryColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }

            Spacer()
        }
    }
}

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    @Published var shouldShowOnboarding: Bool

    init() {
        // Check if onboarding has been completed
        self.shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        shouldShowOnboarding = false
    }

    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
        shouldShowOnboarding = true
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
