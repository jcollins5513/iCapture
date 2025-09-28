//
//  StockNumberInputView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct StockNumberInputView: View {
    @ObservedObject var sessionManager: SessionManager
    @Binding var isPresented: Bool

    @State private var stockNumber = ""
    @State private var notes = ""
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Start New Session")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter the stock number for the vehicle you're capturing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Input form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stock Number")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter stock number", text: $stockNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: stockNumber) { _ in
                                clearValidationError()
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Add any notes about this session", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }

                    // Validation error
                    if showingValidationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(validationMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)

                // Session info
                if sessionManager.isSessionActive {
                    VStack(spacing: 12) {
                        Text("Current Session")
                            .font(.headline)
                            .foregroundColor(.orange)

                        if let summary = sessionManager.getSessionSummary() {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("End current session before starting a new one")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: startSession) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Session")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canStartSession ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canStartSession)

                    if sessionManager.isSessionActive {
                        Button(action: endCurrentSession) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("End Current Session")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var canStartSession: Bool {
        return !stockNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sessionManager.isSessionActive
    }

    // MARK: - Actions

    private func startSession() {
        let trimmedStockNumber = stockNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try sessionManager.startSession(
                stockNumber: trimmedStockNumber,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            isPresented = false
        } catch {
            showValidationError(error.localizedDescription)
        }
    }

    private func endCurrentSession() {
        do {
            try sessionManager.endSession()
        } catch {
            showValidationError("Failed to end current session: \(error.localizedDescription)")
        }
    }

    private func showValidationError(_ message: String) {
        validationMessage = message
        showingValidationError = true
    }

    private func clearValidationError() {
        showingValidationError = false
        validationMessage = ""
    }
}

// MARK: - Preview
#Preview {
    StockNumberInputView(
        sessionManager: SessionManager(),
        isPresented: .constant(true)
    )
}
