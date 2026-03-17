import SwiftUI

/// The main profile view showing the user’s avatar, stats, and memories.
struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager          // User authentication & profile info
    @EnvironmentObject var memories: MemoryStore      // User's memories
    @EnvironmentObject var theme: ThemeManager        // Theme (light/dark) management
    @Environment(\.colorScheme) private var scheme    // Current system color scheme

    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showAdd = false

    private var pinsCount: Int { auth.currentUser?.pinnedCafes.count ?? 0 }
    private var savedCount: Int { auth.currentUser?.savedCafes.count ?? 0 }

    var body: some View {
        ZStack {
            // Background visual effect
            ORABackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {

                    // Top header with Add Memory and Settings buttons
                    ORAHeader(
                        onAddMemory: { showAdd = true },
                        onSettings: { showSettings = true }
                    )

                    // Profile row: Avatar + stats
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 5) {
                            AvatarWithEditButton(
                                size: 78,
                                imageURL: auth.currentUser?.profilePhotoUrl.flatMap(URL.init(string:)),
                                onEdit: { showEditProfile = true }
                            )

                            VStack(alignment: .leading, spacing: 13) {
                                // Username
                                Text(auth.currentUser?.username ?? "Username")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppColor.primary)

                                // Stats row
                                HStack(spacing: 0) {
                                    ProfileStat(number: memories.items.count, label: "memos")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ProfileStat(number: savedCount, label: "saved")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ProfileStat(number: pinsCount, label: "pins")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 20)
                    }

                    // Display memories grid or empty state
                    if !memories.items.isEmpty {
                        MemoriesGrid(
                            memories: memories.items,
                            cellSize: 125,
                            spacing: 6,
                            outerPadding: 10
                        ) { mem in
                            Task {
                                do {
                                    // Delete memory both remotely and locally
                                    try await MemoryService.shared.deleteMemory(
                                        docId: mem.id,
                                        imageUrl: mem.imageUrl,
                                        cafeId: mem.cafeId
                                    )
                                    if let idx = memories.items.firstIndex(where: { $0.id == mem.id }) {
                                        _ = await MainActor.run { memories.items.remove(at: idx) }
                                    }
                                } catch {
                                    print("Delete failed:", error)
                                }
                            }
                        }
                    } else {
                        // Show empty state when no memories
                        EmptyMemoriesView(onAdd: { showAdd = true })
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        // Start/stop Firestore listener
        .onAppear { memories.startListening() }
        .onDisappear { memories.stopListening() }
        .onChange(of: auth.currentUser?.id) { oldValue, newValue in
            guard oldValue != newValue else { return }
            memories.stopListening()
            memories.startListening()
        }
        // Modal sheets
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView(themeManager: theme) }
        }
        // Show edit page
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
        }
        // Add memoery page
        .sheet(isPresented: $showAdd) {
            NavigationStack { AddMemorySheet() }
                .environmentObject(memories)
        }
        .navigationBarBackButtonHidden(true)
    }
}
