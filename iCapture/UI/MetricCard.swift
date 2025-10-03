//
//  MetricCard.swift
//  iCapture
//
//  Created by Justin Collins on 10/2/25.
//

import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)

            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.12))
                .frame(height: 4)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.001))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    MetricCard(title: "Memory Usage", value: "512 MB", color: .green)
        .padding()
        .background(Color.gray.opacity(0.1))
}
