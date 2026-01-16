//
//  UIKitAppearance.swift
//  MySocialCookbook
//
//  Centralized UIKit appearance configuration to prevent color flashing
//  and ensure consistent theming across the app.
//

import SwiftUI
import UIKit

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

        // Use DesignTokens for single source of truth
        navAppearance.backgroundColor = UIColor(DesignTokens.Colors.background)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(DesignTokens.Colors.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(DesignTokens.Colors.textPrimary)
        ]

        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tint color for back buttons and bar button items
        UINavigationBar.appearance().tintColor = UIColor(DesignTokens.Colors.primary)
    }

    // MARK: - Tab Bar Configuration

    private static func configureTabBar() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()

        // Background color from DesignTokens
        tabAppearance.backgroundColor = UIColor(DesignTokens.Colors.background)

        // Unselected state - dusty rose with opacity
        let unselectedColor = UIColor(DesignTokens.Colors.secondary).withAlphaComponent(0.5)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor
        ]

        // Selected state - rose gold
        let selectedColor = UIColor(DesignTokens.Colors.primary)
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
        UISwitch.appearance().onTintColor = UIColor(DesignTokens.Colors.primary)

        // Configure segmented controls
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(DesignTokens.Colors.primary)

        // Configure text field cursors
        UITextField.appearance().tintColor = UIColor(DesignTokens.Colors.primary)
        UITextView.appearance().tintColor = UIColor(DesignTokens.Colors.primary)

        // Configure slider
        UISlider.appearance().minimumTrackTintColor = UIColor(DesignTokens.Colors.primary)

        // Configure page control
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(DesignTokens.Colors.primary)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(DesignTokens.Colors.secondary).withAlphaComponent(0.3)
    }
}

// MARK: - UIColor Extension for DesignTokens Bridge

extension UIColor {
    /// Convenience initializer to bridge SwiftUI Color to UIColor
    /// This ensures consistent color conversion across UIKit components
    convenience init(_ designColor: Color) {
        // Get UIColor from SwiftUI Color
        let uiColor = UIColor(designColor)
        self.init(cgColor: uiColor.cgColor)
    }
}