import SwiftUI

/// SUPPORT NOSTALGEX: the RATE row.
struct SettingsSupportView: View {
    @Environment(AppState.self) var appState
    @Environment(\.openURL) private var openURL
    let focus: FocusState<SettingsFocus?>.Binding

    static let firstRowID = "rate"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsToggleRow(
                title: "RATE NOSTALGEX",
                subtitle: appState.hasTappedRate ? "Thanks for rating. Rate again anytime" : "Opens the App Store on your Apple TV",
                isOn: true,
                isFocused: isFocused("rate"),
                showToggle: false
            ) {
                rateTapped()
            }
            .settingsRow("rate", focus: focus)
            .accessibilityHint("Opens Nostalgex in the App Store to leave a star rating")
        }
    }

    private func isFocused(_ id: String) -> Bool {
        focus.wrappedValue == .row(id)
    }

    private func rateTapped() {
        appState.recordRatingTapped()
        openURL(AppStoreLink.productPage)
    }
}
