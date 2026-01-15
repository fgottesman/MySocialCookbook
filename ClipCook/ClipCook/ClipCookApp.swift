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
        // Initialize RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_BddOAgtqxNNXhxQAiTlQmnXGrYl")
        
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

    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Configure global navigation bar appearance for Midnight Rose theme
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color(hex: "0F1A2B"))
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color(hex: "E8C4B8")) // Rose gold for back buttons
        
        // Configure global tab bar appearance for Midnight Rose theme
        // (Consolidated here - runs ONCE at launch, not on each tab switch)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "0F1A2B"))
        
        // Unselected tab items
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: "D4A5A5").opacity(0.5))
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "D4A5A5").opacity(0.5))
        ]
        
        // Selected tab items (rose gold)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "E8C4B8"))
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "E8C4B8"))
        ]
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
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
