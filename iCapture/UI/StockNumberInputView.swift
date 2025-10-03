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
    @State private var isValidStockNumber = false

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
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(stockNumber.isEmpty ? Color.gray.opacity(0.3) :
                                           (isValidStockNumber ? Color.green : Color.red), lineWidth: 1)
                            )
                            .onChange(of: stockNumber) {
                                validateStockNumber()
                                clearValidationError()
                            }

                        // Validation status indicator
                        if !stockNumber.isEmpty {
                            HStack {
                                Image(systemName: isValidStockNumber ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isValidStockNumber ? .green : .red)
                                    .font(.caption)

                                Text(isValidStockNumber ? "Valid stock number" : getValidationMessage())
                                    .font(.caption)
                                    .foregroundColor(isValidStockNumber ? .green : .red)

                                Spacer()
                            }
                            .padding(.horizontal, 4)
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
        isValidStockNumber && !sessionManager.isSessionActive
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

    // MARK: - Validation

    private func validateStockNumber() {
        let trimmedStockNumber = stockNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic validation rules
        guard !trimmedStockNumber.isEmpty else {
            isValidStockNumber = false
            return
        }

        // Stock number should be 3-20 characters
        guard trimmedStockNumber.count >= 3 && trimmedStockNumber.count <= 20 else {
            isValidStockNumber = false
            return
        }

        // Stock number should contain only alphanumeric characters and common separators
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard trimmedStockNumber.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            isValidStockNumber = false
            return
        }

        // Stock number should not start or end with special characters
        let firstChar = trimmedStockNumber.first!
        let lastChar = trimmedStockNumber.last!
        guard firstChar.isLetter || firstChar.isNumber,
              lastChar.isLetter || lastChar.isNumber else {
            isValidStockNumber = false
            return
        }

        // Stock number should contain at least one letter or number
        let hasAlphanumeric = trimmedStockNumber.contains { $0.isLetter || $0.isNumber }
        guard hasAlphanumeric else {
            isValidStockNumber = false
            return
        }

        isValidStockNumber = true
    }

    private func getValidationMessage() -> String {
        let trimmedStockNumber = stockNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedStockNumber.isEmpty {
            return "Stock number is required"
        } else if trimmedStockNumber.count < 3 {
            return "Stock number must be at least 3 characters"
        } else if trimmedStockNumber.count > 20 {
            return "Stock number must be 20 characters or less"
        } else if trimmedStockNumber.rangeOfCharacter(
            from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.")).inverted
        ) != nil {
            return "Stock number can only contain letters, numbers, and - _ ."
        } else if !(trimmedStockNumber.first!.isLetter || trimmedStockNumber.first!.isNumber) ||
                  !(trimmedStockNumber.last!.isLetter || trimmedStockNumber.last!.isNumber) {
            return "Stock number must start and end with a letter or number"
        } else if !trimmedStockNumber.contains(where: { $0.isLetter || $0.isNumber }) {
            return "Stock number must contain at least one letter or number"
        }

        return ""
    }
}

// MARK: - Preview
#Preview {
    StockNumberInputView(
        sessionManager: SessionManager(),
        isPresented: .constant(true)
    )
}
