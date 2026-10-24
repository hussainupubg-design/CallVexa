import SwiftUI

// MARK: - Premium Button Styles

enum ButtonVariant {
    case primary
    case secondary
    case danger
    case success
    case ghost
}

struct CallVexaButton: View {
    let title: String
    var icon: String? = nil
    var variant: ButtonVariant = .primary
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary: return Color.cvPrimary
        case .secondary: return Color.cvSurfaceElevated
        case .danger: return Color.cvRed
        case .success: return Color.cvGreen
        case .ghost: return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary, .danger, .success: return .white
        case .secondary: return Color.cvTextPrimary
        case .ghost: return Color.cvPrimaryLight
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary: return Color.cvPrimaryLight.opacity(0.4)
        case .secondary: return Color.cvBorder
        case .danger: return Color.cvRed.opacity(0.5)
        case .success: return Color.cvGreen.opacity(0.5)
        case .ghost: return Color.clear
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let text: String
    var color: Color = .cvPrimary
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 0.8)
            )
    }
}

// MARK: - Text Field

struct CallVexaTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.cvTextMuted)
                    .frame(width: 20)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.cvTextPrimary)
                    .font(.system(size: 15))
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.cvTextPrimary)
                    .font(.system(size: 15))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.cvTextMuted)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cvSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cvBorder, lineWidth: 1)
        )
    }
}

// MARK: - Page Header

struct PageHeaderView<RightContent: View>: View {
    let title: String
    let subtitle: String?
    let rightContent: RightContent
    
    init(title: String, subtitle: String? = nil, @ViewBuilder rightContent: () -> RightContent) {
        self.title = title
        self.subtitle = subtitle
        self.rightContent = rightContent()
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.cvTextPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.cvTextSecondary)
                }
            }
            
            Spacer()
            
            rightContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

extension PageHeaderView where RightContent == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, rightContent: { EmptyView() })
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.cvTextMuted)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cvTextPrimary)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.cvTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Attribution Footer

struct AttributionFooter: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("CallVexa")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.cvPrimaryLight)
            Text("•")
                .foregroundColor(.cvTextMuted)
            Text("Made by Hussain")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.cvTextSecondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}
