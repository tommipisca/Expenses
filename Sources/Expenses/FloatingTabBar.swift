import SwiftUI

/// Barra delle schede a isola (come in ExamsTrack): l'evidenziazione scorre sulla scheda scelta.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    /// Numero da mostrare su una scheda (es. spese da confermare sul Mese); 0 = niente.
    var badges: [AppTab: Int] = [:]
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                let badge = badges[tab, default: 0]
                Button {
                    guard tab != selection else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                            .overlay(alignment: .topTrailing) {
                                if badge > 0 {
                                    Text("\(badge)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5).frame(minWidth: 16, minHeight: 16)
                                        .background(Theme.danger, in: Capsule())
                                        .offset(x: 12, y: -8)
                                }
                            }
                        Text(tab.title)
                            .font(.ui(.caption2, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.elevated)
                                .matchedGeometryEffect(id: "selected", in: highlight)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(badge > 0 ? "\(tab.title), \(badge) da confermare" : tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        // Le etichette crescono con il testo di sistema, ma entro un limite che non sfonda l'isola.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        }
        // Su iPad l'isola resta compatta al centro invece di allungarsi su tutto lo schermo.
        .frame(maxWidth: 480)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct FloatingTabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Spazio occupato dall'isola sopra il bordo inferiore sicuro.
    var floatingTabBarHeight: CGFloat {
        get { self[FloatingTabBarHeightKey.self] }
        set { self[FloatingTabBarHeightKey.self] = newValue }
    }
}

/// Spazio in fondo al contenuto scorrevole pari all'isola: si può scorrere fino a vedere
/// l'ultimo elemento sopra l'isola, senza scorrimento in più se la pagina è corta.
private struct FloatingTabBarClearance: ViewModifier {
    @Environment(\.floatingTabBarHeight) private var height

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, height, for: .scrollContent)
            .contentMargins(.bottom, height, for: .scrollIndicators)
    }
}

extension View {
    func floatingTabBarClearance() -> some View {
        modifier(FloatingTabBarClearance())
    }
}
