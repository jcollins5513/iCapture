//
//  AuthView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingDemoInfo = false
    @State private var showingDeveloperOptions = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // App logo/title
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("iCapture")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Vehicle Photo Capture System")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Login form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.white)

                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        authManager.clearError()
                        authManager.signIn(email: email, password: password)
                    }, label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    })
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 40)

                // Demo credentials info
                HStack(spacing: 20) {
                    Button(action: {
                        showingDemoInfo.toggle()
                    }, label: {
                        Text("Demo Credentials")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    })
                    .sheet(isPresented: $showingDemoInfo) {
                        DemoCredentialsView()
                    }

                    Button(action: {
                        showingDeveloperOptions.toggle()
                    }, label: {
                        Text("Developer Options")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    })
                    .sheet(isPresented: $showingDeveloperOptions) {
                        DeveloperOptionsView()
                    }
                }

                Spacer()
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct DemoCredentialsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Demo Credentials")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 16) {
                    CredentialRow(email: "admin", password: "password123", role: "Administrator")
                    CredentialRow(email: "demo", password: "demo123", role: "Demo User")
                    CredentialRow(email: "test", password: "test123", role: "Test User")
                }
                .padding(.horizontal)

                Text("These are mock credentials for development. " +
                     "In production, Firebase Auth will handle real authentication.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Demo Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CredentialRow: View {
    let email: String
    let password: String
    let role: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(role)
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                VStack(alignment: .leading) {
                    Text("Email: \(email)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Password: \(password)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Copy") {
                    UIPasteboard.general.string = "\(email)\n\(password)"
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DeveloperOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    @State private var showingQATesting = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Developer Options")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Reset Options")
                        .font(.headline)

                    Button("Reset Onboarding") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)

                    Text("This will show the onboarding flow again on next app launch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 16) {
                    Text("QA Testing")
                        .font(.headline)

                    Button("Open QA Testing Tools") {
                        showingQATesting = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.blue)

                    Text("Access performance monitoring and QA testing tools for device testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Storage Options")
                        .font(.headline)

                    Button("Clear All User Data") {
                        // This would clear all stored data
                        UserDefaults.standard.removeObject(forKey: "authenticated_user")
                        UserDefaults.standard.removeObject(forKey: "frameBoxRect")
                        UserDefaults.standard.removeObject(forKey: "roiConfiguration")
                        UserDefaults.standard.removeObject(forKey: "motionConfiguration")
                        UserDefaults.standard.removeObject(forKey: "currentSession")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                    Text("This will clear all stored settings and return the app to its initial state.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("Developer Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingQATesting) {
            QATestingView()
        }
        .alert("Reset Onboarding", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset the onboarding flow and show it again on next app launch.")
        }
    }
}

#Preview {
    AuthView(authManager: AuthManager())
}
