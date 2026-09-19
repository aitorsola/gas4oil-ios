//
//  Gas4OilApp.swift
//  Shared
//
//  Created by Aitor Sola on 3/3/22.
//

import SwiftUI

#if os(macOS)

@main
struct Gas4OilApp: App {
    
    private let model = MacAppModel.shared
    
    init() {
        model.start()
    }
    
    var body: some Scene {
        Window("Gas4Oil", id: MacWindowID.main) {
            MacRootView(model: model)
                .frame(minWidth: 1000, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            MacCommands(model: model)
            SidebarCommands()
            ToolbarCommands()
        }
        
        WindowGroup(id: MacWindowID.station, for: Station.ID.self) { $stationID in
            MacStationWindow(model: model, stationID: stationID)
        }
        .defaultSize(width: 820, height: 520)
        
        Settings {
            MacSettingsView(model: model)
        }
        
        MenuBarExtra(isInserted: model.menuBarBinding) {
            MacMenuBarView(model: model)
        } label: {
            Label(model.menuBarTitle, systemImage: "fuelpump.fill")
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

#else

@main
struct Gas4OilApp: App {
    
#if os(iOS)
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
#endif
    
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
#if os(macOS)
                    .onChange(of: appearance, initial: true) { _, preference in
                        NSApp.appearance = preference.appKitAppearance
                    }
#endif
            }
        }
    }
}

#endif
