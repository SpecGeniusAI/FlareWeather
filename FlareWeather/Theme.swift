import SwiftUI

/// Design System Colors
extension Color {
    // Primary background color
    static let primaryBackground = Color(hex: "#F1F1EF")
    
    // Alternate background (cards, panels, section breaks)
    static let altBackground = Color(hex: "#E7D6CA")
    
    // Dark mode background
    static let darkBackground = Color(hex: "#000000")
    
    // Dark mode text color
    static let darkText = Color(hex: "#F1F1EF")
    
    // Muted text, icons, borders (light mode)
    static let muted = Color(hex: "#888576")
    
    // Dark mode card background - darker pink matching light mode pink (#E7D6CA)
    static let darkCardBackground = Color(hex: "#7A6B62")
    
    // Dark mode muted color - white for text/icons in dark mode
    static let darkMuted = Color.white
    
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
/// Using system fonts that match Inter's characteristics
extension Font {
    static let interTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let interHeadline = Font.system(size: 20, weight: .semibold, design: .default)
    static let interBody = Font.system(size: 16, weight: .regular, design: .default)
    static let interCaption = Font.system(size: 14, weight: .regular, design: .default)
    static let interSmall = Font.system(size: 12, weight: .regular, design: .default)
}

/// View Modifiers for consistent styling
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.adaptiveCardBackground)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 18, x: 0, y: 14)
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.03 : 0.25), Color.black.opacity(0.04)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.18),
                                    Color.white.opacity(colorScheme == .dark ? 0.01 : 0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 0.6)
                        .padding(.leading, 0.6)
                        .blendMode(.plusLighter)
                }
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.darkCardBackground : Color.adaptiveCardBackground)
            .foregroundColor(colorScheme == .dark ? .white : .black) // White in dark mode, black in light mode
            .font(.interBody.weight(.medium))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.clear)
            .foregroundColor(Color.adaptiveText) // White in dark mode, black in light mode
            .font(.interBody.weight(.medium))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.adaptiveMuted, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
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
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
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
        Color(light: .black, dark: .white)
    }
    
    // Cards use darker pink (#7A6B62) in dark mode to match light mode pink (#E7D6CA)
    static var adaptiveCardBackground: Color {
        Color(light: altBackground, dark: darkCardBackground)
    }
    
    // Adaptive muted color - for text/icons on backgrounds
    // In dark mode: white for all text
    // In light mode: muted greenish-gray
    static var adaptiveMuted: Color {
        Color(light: muted, dark: .white)
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

