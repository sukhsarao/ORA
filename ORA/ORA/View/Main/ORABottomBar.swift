import SwiftUI


/// Custom bottom tab bar for the ORA app using SF Symbols.
/// Highlights the selected tab and allows switching via taps.
struct ORABottomBar: View {
    /// Binding to the current selected tab, controlled by the parent (ORAMainView)...
    @Binding var selection: ORATab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            //loop through every tab in the enum..
            ForEach(ORATab.allCases, id: \.self) { tab in
                Spacer(minLength: 0)

                Button {
                    selection = tab
                } label: {
                    ZStack {
                        // Changes the highlighted section in the bar based on the selected tab
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppColor.primary.opacity(scheme == .dark ? 0.80 : 0.92))
                                .frame(width: 70, height: 48)
                                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(scheme == .dark ? 0.10 : 0.22), lineWidth: 0.5)
                                )
                        }
                        // Icons for the tab
                        Image(systemName: tab.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .symbolVariant(selection == tab ? .fill : .none)
                            .foregroundStyle(selection == tab ? Color.white
                                                             : Color.primary.opacity(0.7))
                            .frame(width: 70, height: 48)
                            .contentShape(Rectangle())
                            .accessibilityLabel(tab.label)      //HIGs - aaccessibility feature designed for people who are blind or have low vision..
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(barGlassBackground.ignoresSafeArea(edges: .bottom))
    }
    
    /// Background for the tab bar with glassy gradient effect.
    private var barGlassBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    AppColor.circleOne.opacity(scheme == .dark ? 0.18 : 0.10),
                    AppColor.circleTwo.opacity(scheme == .dark ? 0.22 : 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(Color.white.opacity(scheme == .dark ? 0.06 : 0.30))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
