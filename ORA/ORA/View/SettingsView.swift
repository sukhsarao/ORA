import SwiftUI

/// Main settings screen for appearance and account management.
struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @ObservedObject private var themeManager: ThemeManager
    @StateObject private var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirm = false

    init(themeManager: ThemeManager) {
        self._themeManager = ObservedObject(wrappedValue: themeManager)
        _vm = StateObject(wrappedValue: SettingsViewModel(themeManager: themeManager))
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $vm.theme) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    ThemePreviewRow()
                }

                // MARK: - Account Section
                Section("Account") {
                    if let name = auth.currentUser?.username, !name.isEmpty {
                        HStack {
                            Text("Signed in as")
                            Spacer()
                            Text(name).foregroundStyle(.secondary)
                        }
                    }
                    // Logout section
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // Update theme when selection changes
        .onChange(of: vm.theme) { _, newValue in
            themeManager.setThemeMode(newValue)
        }

        // Logout confirmation alert
        .alert("Log out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) {
                auth.logout()
                dismiss()
            }
        } message: {
            Text("You can log back in anytime.")
        }
    }
}

/// Small row to preview the theme colors and highlight bar.
struct ThemePreviewRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(AppColor.circleOne).frame(width: 28, height: 28)
            Circle().fill(AppColor.circleTwo).frame(width: 28, height: 28)
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.primary.opacity(0.25))
                .frame(height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColor.primary)
                        .frame(width: 80, height: 12),
                    alignment: .leading
                )
        }
        .padding(.vertical, 6)
    }
}

// Preview
#Preview {
    SettingsView(themeManager: ThemeManager())
        .environmentObject(AuthManager())
}
