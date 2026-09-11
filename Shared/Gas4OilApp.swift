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
    
    var body: some Scene {
        WindowGroup {
            if Device.isiOS {
                MainTabView()
#if os(iOS)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        Managers.backgroundTask.scheduleTask(.refreshStationList, earliestBeginDate: Date(timeIntervalSinceNow: 15*60))
                    }
#endif
            } else {
                MainTabView()
                    .frame(minWidth: 560, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
            }
        }
    }
}
