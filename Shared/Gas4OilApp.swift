//
//  Gas4OilApp.swift
//  Shared
//
//  Created by Aitor Sola on 3/3/22.
//

import SwiftUI

@main
struct Gas4OilApp: App {
    
#if os(iOS)
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
#endif
    
    /// `.system` by default, so a fresh install follows the device until the user says otherwise.
    @AppStorage(ThemePreference.storageKey) private var appearance: ThemePreference = .system
    
    var body: some Scene {
        WindowGroup {
            if Device.isiOS {
                MainTabView()
#if os(iOS)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        Managers.backgroundTask.scheduleTask(.refreshStationList, earliestBeginDate: Date(timeIntervalSinceNow: 15*60))
                    }
#endif
                    .preferredColorScheme(appearance.colorScheme)
            } else {
                MainTabView()
                    .frame(minWidth: 560, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
                    .preferredColorScheme(appearance.colorScheme)
            }
        }
    }
}
