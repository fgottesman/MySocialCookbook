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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send token to backend
        // Use a default user ID for now or grab from Supabase if logged in
        // Ideally we pass the token to MessagingManager
        // Assuming SupabaseManager and MessagingManager are defined elsewhere
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
    }
}
