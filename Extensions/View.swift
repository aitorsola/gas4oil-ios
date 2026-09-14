//
//  View.swift
//  Gas4Oil (iOS)
//
//  Created by Aitor Sola on 27/3/22.
//

import SwiftUI

extension View {
    
#if canImport(UIKit)
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
    }
#endif

    /// Contrasting text for labels drawn on a `.tint(.primary)` prominent button.
    func invertedForeground() -> some View {
        modifier(InvertedForeground())
    }

    /// Prominent button filled with the primary colour. macOS ignores the label colour
    /// of `.borderedProminent`, so it gets its own style there.
    @ViewBuilder
    func primaryButtonStyle() -> some View {
#if os(macOS)
        buttonStyle(PrimaryButtonStyle())
#else
        buttonStyle(.borderedProminent)
#endif
    }
}

#if os(macOS)
private struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .invertedForeground()
            .padding(.horizontal, 14)
            .padding(.vertical, controlSize == .large ? 10 : 6)
            .background(Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.3),
                        in: Capsule())
            .contentShape(Capsule())
    }
}
#endif

private struct InvertedForeground: ViewModifier {

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
    }
}

#if canImport(UIKit)
struct CornerRadiusStyle: ViewModifier {
    var radius: CGFloat
    var corners: UIRectCorner
    
    struct CornerRadiusShape: Shape {
        
        var radius = CGFloat.infinity
        var corners = UIRectCorner.allCorners
        
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}
#endif
