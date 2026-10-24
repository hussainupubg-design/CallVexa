import SwiftUI

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var background: Color = .cvSurface
    var cornerRadius: CGFloat = 16
    var border: Color = .cvBorder
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

extension View {
    func cvCard(
        padding: CGFloat = 16,
        background: Color = .cvSurface,
        cornerRadius: CGFloat = 16,
        border: Color = .cvBorder
    ) -> some View {
        modifier(CardModifier(padding: padding, background: background, cornerRadius: cornerRadius, border: border))
    }
    
    func cvBackground() -> some View {
        self.background(Color.cvBackground.ignoresSafeArea())
    }
}
