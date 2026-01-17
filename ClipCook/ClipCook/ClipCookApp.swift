//
//  MySocialCookbookApp.swift
//  MySocialCookbook
//
//  Created by Freddy Gottesman on 1/4/26.
//

import SwiftUI
import UIKit // Required for UIApplicationDelegate
import Supabase
import Auth
import RevenueCat


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize RevenueCat with production API key
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_qjuZvQLNyznQVDHfhCiqSCnxeeO")

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send token to backend
        if let user = SupabaseManager.shared.client.auth.currentUser {
             MessagingManager.shared.registerDevice(token: deviceToken, userId: user.id.uuidString)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error)")
    }
}

@main
struct MySocialCookbookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure all UIKit appearance using centralized configuration
        // This prevents tab bar color flashing and ensures consistent theming
        UIKitAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth redirects
                    if url.scheme == "mysocialcookbook" {
                        SupabaseManager.shared.client.auth.handle(url)
                        print("Successfully handled auth callback")
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Clear the badge count when the app is opened
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
}
