import SwiftUI

/// ABOUT: the version line and where the source code comes from.
///
/// tvOS has no web browser, so the repository is a line to read and open on a phone
/// or computer, not a link.
struct SettingsAboutView: View {
    let focus: FocusState<SettingsFocus?>.Binding

    static let firstRowID = "about_version"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Focusable so the remote has somewhere to land; select does nothing.
            SettingsToggleRow(
                title: "VERSION",
                subtitle: "The build number tells two submissions of one version apart",
                detail: appVersionLabel,
                detailIsProminent: true,
                isOn: true,
                isFocused: isFocused("about_version"),
                showToggle: false
            ) {}
            .settingsRow("about_version", focus: focus)
            .accessibilityLabel("App version \(appVersionLabel)")

            SettingsSectionHeader(title: "SOURCE CODE")
                .padding(.top, 24)

            SettingsToggleRow(
                title: "THIS APP IS A FORK",
                subtitle: "Built on Nostalgex by Chad Mueller (MIT), unaffiliated with the original. Open it on a phone or computer.",
                detail: "github.com/chadMueller/Nostalgex",
                detailIsProminent: true,
                isOn: true,
                isFocused: isFocused("about_source"),
                showToggle: false
            ) {}
            .settingsRow("about_source", focus: focus)
            .accessibilityLabel("Source code, this app is a fork built on Nostalgex by Chad Mueller under the MIT license, github.com/chadMueller/Nostalgex")
        }
    }

    private func isFocused(_ id: String) -> Bool {
        focus.wrappedValue == .row(id)
    }

    /// Marketing version plus build, e.g. "1.0.10 (17)". Both matter: the build number
    /// is what distinguishes two submissions of the same version.
    private var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
