import SwiftUI

// MARK: - Glass Effect Modifier for iOS 26+

extension View {
    /// Applies a glass effect to the view.
    /// - Parameters:
    ///   - shape: The shape to apply the glass effect in
    ///   - interactive: Whether the glass should respond to user interactions (iOS 26+ only)
    /// - Returns: A view with the glass effect applied
    @ViewBuilder
    func glassedEffect<S: Shape>(in shape: S = Capsule(), interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background {
                shape.glassed()
            }
        }
    }
}

// MARK: - Fallback Glass Effect for older iOS versions

extension Shape {
    /// Creates a glass-like appearance for older iOS versions using materials and gradients
    func glassed() -> some View {
        self
            .fill(.ultraThinMaterial)
            .overlay {
                self.fill(
                    .linearGradient(
                        colors: [
                            .primary.opacity(0.08),
                            .primary.opacity(0.05),
                            .primary.opacity(0.01),
                            .clear,
                            .clear,
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                self.stroke(.primary.opacity(0.2), lineWidth: 0.7)
            }
    }
}
