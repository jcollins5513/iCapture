//
//  AuthManager.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Combine
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // For now, we'll use a simple mock authentication
    // In Milestone 7, this will be replaced with Firebase Auth
    private let mockUsers = [
        "admin": "password123",
        "demo": "demo123",
        "test": "test123"
    ]

    init() {
        // Check if user was previously authenticated
        checkStoredAuth()
    }

    private func checkStoredAuth() {
        // For now, check UserDefaults for stored authentication
        if let storedUser = UserDefaults.standard.string(forKey: "authenticated_user") {
            currentUser = storedUser
            isAuthenticated = true
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Mock authentication logic
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

    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "authenticated_user")
    }

    func clearError() {
        errorMessage = nil
    }
}
