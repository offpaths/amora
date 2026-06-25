import SwiftUI

enum AmoraTheme {
    static let background = Color(red: 0.969, green: 0.949, blue: 0.914)
    static let surface = Color(red: 1.000, green: 0.992, blue: 0.973)
    static let ink = Color(red: 0.129, green: 0.102, blue: 0.090)
    static let muted = Color(red: 0.455, green: 0.420, blue: 0.388)
    static let oxblood = Color(red: 0.431, green: 0.122, blue: 0.169)
    static let brass = Color(red: 0.475, green: 0.341, blue: 0.125)
    static let olive = Color(red: 0.325, green: 0.420, blue: 0.306)
    static let border = Color(red: 0.890, green: 0.847, blue: 0.792)
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AmoraTheme.background.ignoresSafeArea())
            .foregroundStyle(AmoraTheme.ink)
    }
}

extension View {
    func amoraScreen() -> some View {
        modifier(ScreenBackground())
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(AmoraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AmoraTheme.border, lineWidth: 1)
            }
    }
}

struct PillLabel: View {
    let text: String
    var tint: Color = AmoraTheme.muted

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10))
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
            .clipShape(Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(AmoraTheme.surface)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(AmoraTheme.surface)
            .background(AmoraTheme.oxblood)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.72 : 1)
    }
}

struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(AmoraTheme.ink)
            .background(AmoraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AmoraTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FlowBadges: View {
    let badges: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(badges, id: \.self) { badge in
                PillLabel(text: badge, tint: AmoraTheme.olive)
            }
        }
    }
}

struct ItineraryNumber: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.caption.weight(.bold))
            .foregroundStyle(AmoraTheme.surface)
            .frame(width: 28, height: 28)
            .background(AmoraTheme.ink)
            .clipShape(Circle())
    }
}

struct StopIllustrationPanel: View {
    let systemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AmoraTheme.brass.opacity(0.12))
            HStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(AmoraTheme.brass.opacity(0.16))
                    .offset(x: -10, y: 22)
                Spacer()
                Image(systemName: systemImage)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(AmoraTheme.oxblood)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AmoraTheme.olive.opacity(0.18))
                    .offset(x: 8, y: -20)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}
