//
//  AuthManager.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Combine
import SwiftUI
import FirebaseAuth

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Configuration
    private let useFirebaseAuth = false // Set to true when Firebase is configured

    // Mock authentication for development
    private let mockUsers = [
        "admin": "password123",
        "demo": "demo123",
        "test": "test123"
    ]

    init() {
        // Check if user was previously authenticated
        checkStoredAuth()

        // Set up Firebase Auth state listener if using Firebase
        if useFirebaseAuth {
            setupFirebaseAuthListener()
        }
    }

    private func checkStoredAuth() {
        if useFirebaseAuth {
            // Firebase will handle authentication state
            if let user = Auth.auth().currentUser {
                currentUser = user.email ?? user.uid
                isAuthenticated = true
            }
        } else {
            // Check UserDefaults for stored authentication (mock mode)
            if let storedUser = UserDefaults.standard.string(forKey: "authenticated_user") {
                currentUser = storedUser
                isAuthenticated = true
            }
        }
    }

    private func setupFirebaseAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.currentUser = user.email ?? user.uid
                    self?.isAuthenticated = true
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        if useFirebaseAuth {
            // Firebase authentication
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                        return
                    }

                    if let user = result?.user {
                        self.currentUser = user.email ?? user.uid
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                }
            }
        } else {
            // Mock authentication logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }

                if let storedPassword = self.mockUsers[email], storedPassword == password {
                    self.currentUser = email
                    self.isAuthenticated = true
                    UserDefaults.standard.set(email, forKey: "authenticated_user")
                    self.isLoading = false
                } else {
                    self.errorMessage = "Invalid email or password"
                    self.isLoading = false
                }
            }
        }
    }

    func signOut() {
        if useFirebaseAuth {
            // Firebase sign out
            do {
                try Auth.auth().signOut()
                // The auth state listener will handle updating the UI
            } catch {
                print("Error signing out: \(error)")
                // Fallback to manual sign out
                currentUser = nil
                isAuthenticated = false
            }
        } else {
            // Mock sign out
            currentUser = nil
            isAuthenticated = false
            UserDefaults.standard.removeObject(forKey: "authenticated_user")
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
