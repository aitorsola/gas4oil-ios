//
//  StateView.swift
//  Gas4Oil
//

import SwiftUI

struct StateView: View {
    
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: Metrics.circle, height: Metrics.circle)
                Image(systemName: icon)
                    .font(.customSize(Metrics.icon, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text(title)
                .font(Metrics.titleFont)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metrics.titleSpacing)
            if let message {
                Text(message)
                    .font(Metrics.messageFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let actionTitle, let action {
                actionButton(actionTitle, action)
                    .padding(.top, Metrics.actionSpacing)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: Metrics.maxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func actionButton(_ title: String, _ action: @escaping () -> Void) -> some View {
#if os(macOS)
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
#else
        Button(action: action) {
            Text(title)
                .font(.customSize(17, weight: .semibold))
                .padding(.horizontal, 18)
                .invertedForeground()
        }
        .primaryButtonStyle()
        .controlSize(.large)
        .tint(.primary)
#endif
    }
    
    private enum Metrics {
#if os(macOS)
        static let circle: CGFloat = 60
        static let icon: CGFloat = 25
        static let titleFont = Font.title2.weight(.semibold)
        static let messageFont = Font.body
        static let titleSpacing: CGFloat = 14
        static let actionSpacing: CGFloat = 18
        static let maxWidth: CGFloat? = 460
#else
        static let circle: CGFloat = 84
        static let icon: CGFloat = 34
        static let titleFont = Font.customSize(22, weight: .bold)
        static let messageFont = Font.customSize(14)
        static let titleSpacing: CGFloat = 18
        static let actionSpacing: CGFloat = 24
        static let maxWidth: CGFloat? = nil
#endif
    }
}

extension StateView {
    
    init(error: G4OError, retry: @escaping () -> Void) {
        self.init(icon: error.icon,
                  title: error.title,
                  message: error.errorDescription,
                  actionTitle: "common.retry".translated,
                  action: retry)
    }
}
