import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultTriviaCategoryIDs") private var defaultCategoryIDs = TriviaCategory.defaultEnabled.map(\.id).joined(separator: ",")

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.sunriseBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Trivia Categories")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            VStack(spacing: 0) {
                                ForEach(TriviaCategory.allCases) { category in
                                    Toggle(category.title, isOn: binding(for: category))
                                        .tint(AppTheme.accent)
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 18)

                                    if category != TriviaCategory.allCases.last {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                            .floatingCard()
                        }

                        Text("New alarms use these categories by default. Existing alarms keep their own selected categories.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .floatingCard()
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(.clear)
        .preferredColorScheme(.light)
    }

    private var selectedIDs: Set<String> {
        get {
            let ids = defaultCategoryIDs.split(separator: ",").map(String.init)
            return ids.isEmpty ? Set(TriviaCategory.defaultEnabled.map(\.id)) : Set(ids)
        }
        nonmutating set {
            defaultCategoryIDs = newValue.sorted().joined(separator: ",")
        }
    }

    private func binding(for category: TriviaCategory) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(category.id) },
            set: { isSelected in
                var ids = selectedIDs
                if isSelected {
                    ids.insert(category.id)
                } else {
                    ids.remove(category.id)
                }
                if !ids.isEmpty {
                    selectedIDs = ids
                }
            }
        )
    }
}
