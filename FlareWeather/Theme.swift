import SwiftUI

/// Design System Colors
extension Color {
    // Primary background color - soft warm gray
    static let primaryBackground = Color(hex: "#f5f5f7")
    
    // Alternate background (cards) - pure white for light mode
    static let altBackground = Color(hex: "#ffffff")
    
    // Dark mode background - rich dark blue-gray
    static let darkBackground = Color(hex: "#2d3040")
    
    // Dark mode text color
    static let darkText = Color(hex: "#f5f5f7")
    
    // Muted text, icons (light mode) - subtle blue-gray
    static let muted = Color(hex: "#697797")
    
    // Dark mode card background - elevated surface
    static let darkCardBackground = Color(hex: "#3a3d4d")
    
    // Dark mode muted color
    static let darkMuted = Color(hex: "#98989d")
    
    // Helper to create Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Typography Styles
/// Premium typography - Merriweather for headers, SF Pro for body
extension Font {
    // Serif headers using Merriweather
    static let interTitle = Font.custom("Merriweather", size: 26).weight(.bold)
    static let interHeadline = Font.custom("Merriweather", size: 17).weight(.regular)
    // System font for body text
    static let interBody = Font.system(size: 15, weight: .regular, design: .default)
    static let interCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let interSmall = Font.system(size: 11, weight: .medium, design: .default)
}

/// View Modifiers for consistent styling
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        colorScheme == .dark
                            ? AnyShapeStyle(Color.adaptiveCardBackground)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(hex: "#697797").opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .shadow(
                color: colorScheme == .dark 
                    ? Color.black.opacity(0.4)
                    : Color.black.opacity(0.06),
                radius: colorScheme == .dark ? 20 : 16,
                x: 0,
                y: colorScheme == .dark ? 8 : 6
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.adaptiveText)
            )
            .foregroundColor(Color.adaptiveBackground)
            .font(.interBody.weight(.semibold))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(colorScheme == .dark 
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05))
            )
            .foregroundColor(Color.adaptiveText)
            .font(.interBody.weight(.medium))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    /// Subtle card entrance animation - slides up and fades in
    func cardEnterAnimation(delay: Double = 0.0) -> some View {
        self.modifier(CardEnterAnimationModifier(delay: delay))
    }
}

/// Card entrance animation modifier
struct CardEnterAnimationModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .scaleEffect(isVisible ? 1 : 0.97)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

/// Subtle divider for clean separations
struct SubtleDivider: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark 
                ? Color.white.opacity(0.06) 
                : Color.black.opacity(0.04))
            .frame(height: 0.5)
    }
}

// Custom TextField style to fix placeholder color
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
    }
}

// Helper to set placeholder text color
extension View {
    func placeholderColor(_ color: Color) -> some View {
        self.onAppear {
            // Set UITextField placeholder color
            UITextField.appearance().attributedPlaceholder = NSAttributedString(
                string: "",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor(color)]
            )
        }
    }
}

// Dark mode support
extension Color {
    // Adapt colors for dark mode
    static var adaptiveBackground: Color {
        Color(light: primaryBackground, dark: darkBackground)
    }
    
    static var adaptiveText: Color {
        Color(light: Color(hex: "#1c1c1e"), dark: Color(hex: "#ffffff"))
    }
    
    // Cards use darker pink (#7A6B62) in dark mode to match light mode pink (#E7D6CA)
    static var adaptiveCardBackground: Color {
        Color(light: altBackground, dark: darkCardBackground)
    }
    
    // Adaptive muted color - for secondary text/icons
    // In dark mode: soft gray
    // In light mode: muted gray
    static var adaptiveMuted: Color {
        Color(light: muted, dark: darkMuted)
    }
    
    // Adaptive accent color - for buttons, links, highlights
    static var adaptiveAccent: Color {
        Color(light: Color(hex: "#1c1c1e"), dark: Color(hex: "#ffffff"))
    }
    
    // MARK: - Risk Level Colors (Premium, refined palette)
    
    // Low risk - elegant green
    static var riskLow: Color {
        Color(light: Color(hex: "#34c759"), dark: Color(hex: "#30d158"))
    }
    static var riskLowBackground: Color {
        Color(light: Color(hex: "#34c759").opacity(0.12), dark: Color(hex: "#30d158").opacity(0.18))
    }
    
    // Moderate risk - refined amber
    static var riskModerate: Color {
        Color(light: Color(hex: "#ff9500"), dark: Color(hex: "#ffcc00"))
    }
    static var riskModerateBackground: Color {
        Color(light: Color(hex: "#ff9500").opacity(0.12), dark: Color(hex: "#ffcc00").opacity(0.18))
    }
    
    // High risk - refined red
    static var riskHigh: Color {
        Color(light: Color(hex: "#ff3b30"), dark: Color(hex: "#ff453a"))
    }
    static var riskHighBackground: Color {
        Color(light: Color(hex: "#ff3b30").opacity(0.12), dark: Color(hex: "#ff453a").opacity(0.18))
    }
    
    // Helper initializer for light/dark mode colors
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

