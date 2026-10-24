import SwiftUI

struct KeypadButton: View {
    let digit: String
    let subtext: String
    let action: (String) -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            action(digit)
        }) {
            VStack(spacing: 2) {
                Text(digit)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.cvTextPrimary)
                
                if !subtext.isEmpty {
                    Text(subtext)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.cvTextSecondary)
                        .tracking(1.5)
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .frame(width: 76, height: 76)
            .background(Color.cvSurface)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.cvBorder, lineWidth: 1)
            )
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if let onLongPress = onLongPress {
                        let feedback = UIImpactFeedbackGenerator(style: .heavy)
                        feedback.impactOccurred()
                        onLongPress()
                    }
                }
        )
    }
}
