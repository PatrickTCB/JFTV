//
//  JFTVApp.swift
//  JFTV
//
//  Created by Chad Mueller on 2026-03-19.
//

import SwiftUI
import CoreText

@main
struct JFTVApp: App {
    @State private var appState: AppState

    init() {
        #if DEBUG
        // Before anything reads a setting, a sign-in or a file: a harness run on a real
        // Apple TV keeps the host app's own launch off the real stores too.
        HarnessIsolation.activateFromEnvironmentIfRequested()
        #endif
        Self.registerCustomFonts()
        // When the viewer has turned sync on, pull synced preferences from iCloud before
        // AppState reads its defaults, so this Apple TV adopts the household lineup
        // instead of overwriting it. A no-op while sync is off (the default).
        PreferenceSync.shared.bootstrap()
        let state = AppState()
        #if DEBUG
        state.runPreferenceSyncProbeIfRequested()
        #endif
        _appState = State(initialValue: state)
        // Now Playing only surfaces for an app with an active .playback session.
        NowPlayingInfoService.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }

    private static func registerCustomFonts() {
        let fonts = ["DMMono-Regular", "DMMono-Medium", "VT323-Regular"]
        for name in fonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("[JFTV] Font file \(name).ttf not found in bundle")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
