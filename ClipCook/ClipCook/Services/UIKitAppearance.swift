//
//  UIKitAppearance.swift
//  MySocialCookbook
//
//  Centralized UIKit appearance configuration to prevent color flashing
//  and ensure consistent theming across the app.
//

import SwiftUI
import UIKit

// MARK: - UIKit Color Constants (matching DesignTokens)
private enum UIKitColors {
    static let background = UIColor(hex: "0F1A2B")      // Midnight Navy
    static let surface = UIColor(hex: "1A2A3D")         // Deep Navy
    static let primary = UIColor(hex: "E8C4B8")         // Rose Gold
    static let secondary = UIColor(hex: "D4A5A5")       // Dusty Rose
    static let textPrimary = UIColor.white
}

struct UIKitAppearance {
    /// Configure all UIKit appearance proxies at app launch
    /// This ensures consistent theming and prevents tab bar color flashing
    static func configure() {
        configureNavigationBar()
        configureTabBar()
        configureControls()
    }

    // MARK: - Navigation Bar Configuration

    private static func configureNavigationBar() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()

        navAppearance.backgroundColor = UIKitColors.background
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIKitColors.textPrimary
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIKitColors.textPrimary
        ]

        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tint color for back buttons and bar button items
        UINavigationBar.appearance().tintColor = UIKitColors.primary
    }

    // MARK: - Tab Bar Configuration

    private static func configureTabBar() {
        // iOS 26+: Let Liquid Glass handle the floating tab bar appearance
        // Forcing opaque configuration creates a grey gap behind the floating pill
        if #available(iOS 26.0, *) {
            UITabBar.appearance().tintColor = UIKitColors.primary
            return
        }

        // Pre-iOS 26: Use opaque tab bar configuration
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()

        // Background color
        tabAppearance.backgroundColor = UIKitColors.background

        // Unselected state - dusty rose with opacity
        let unselectedColor = UIKitColors.secondary.withAlphaComponent(0.5)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor
        ]

        // Selected state - rose gold
        let selectedColor = UIKitColors.primary
        tabAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]

        // Apply to all tab bar states to prevent flashing
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Ensure tab bar is opaque to prevent transparency issues
        if #available(iOS 15.0, *) {
            UITabBar.appearance().isTranslucent = false
        }
    }

    // MARK: - Control Configuration

    private static func configureControls() {
        // Configure switches with rose gold accent
        UISwitch.appearance().onTintColor = UIKitColors.primary

        // Configure segmented controls
        UISegmentedControl.appearance().selectedSegmentTintColor = UIKitColors.primary

        // Configure text field cursors
        UITextField.appearance().tintColor = UIKitColors.primary
        UITextView.appearance().tintColor = UIKitColors.primary

        // Configure slider
        UISlider.appearance().minimumTrackTintColor = UIKitColors.primary

        // Configure page control
        UIPageControl.appearance().currentPageIndicatorTintColor = UIKitColors.primary
        UIPageControl.appearance().pageIndicatorTintColor = UIKitColors.secondary.withAlphaComponent(0.3)
    }
}

// MARK: - UIColor Hex Initializer
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

