# ClipCook Design Tokens

## Overview
ClipCook uses a centralized design token system to ensure consistent theming across the app. All colors, spacing, and typography are defined in `DesignTokens.swift` - this is the single source of truth.

## Theme: Midnight Rose

The app uses a sophisticated dark theme combining deep navy backgrounds with warm rose gold accents.

### Color Palette

#### Primary Colors
- **Primary (Rose Gold)**: `DesignTokens.Colors.primary` - `#E8C4B8`
  - Use for: Primary actions, selected states, accents
  - Examples: Tab bar selection, buttons, links

- **Secondary (Dusty Rose)**: `DesignTokens.Colors.secondary` - `#D4A5A5`
  - Use for: Secondary elements, unselected states
  - Examples: Unselected tab bar items, secondary text

#### Background Colors
- **Background (Midnight Navy)**: `DesignTokens.Colors.background` - `#0F1A2B`
  - Use for: Main app background, view backgrounds
  - Examples: Screen backgrounds, list backgrounds

- **Surface (Deep Navy)**: `DesignTokens.Colors.surface` - `#1A2A3D`
  - Use for: Elevated surfaces, cards, modals
  - Examples: Recipe cards, bottom sheets, popovers

#### Text Colors
- **Text Primary (White)**: `DesignTokens.Colors.textPrimary` - `Color.white`
  - Use for: Primary text, headings
  - Examples: Titles, body text, labels

- **Text Secondary (Dusty Rose)**: `DesignTokens.Colors.textSecondary` - `#D4A5A5`
  - Use for: Secondary text, subtitles, metadata
  - Examples: Timestamps, captions, helper text

#### Gradients
- **Gradient Start (Midnight Navy)**: `DesignTokens.Colors.gradientStart` - `#0F1A2B`
- **Gradient End (Deeper Navy)**: `DesignTokens.Colors.gradientEnd` - `#0A1220`
  - Use for: Background gradients, overlay effects
  - Example:
    ```swift
    LinearGradient(
        colors: [DesignTokens.Colors.gradientStart, DesignTokens.Colors.gradientEnd],
        startPoint: .top,
        endPoint: .bottom
    )
    ```

## Usage Guidelines

### ✅ DO:
```swift
// Use design tokens for all colors
Text("Recipe Title")
    .foregroundColor(DesignTokens.Colors.textPrimary)
    .background(DesignTokens.Colors.background)

// Use for tints and accents
.tint(DesignTokens.Colors.primary)

// Use for borders and dividers
Rectangle()
    .fill(DesignTokens.Colors.surface)
```

### ❌ DON'T:
```swift
// Don't hardcode hex colors
Text("Recipe Title")
    .foregroundColor(Color(hex: "E8C4B8"))  // BAD!

// Don't use RGB values directly
.background(Color(red: 0.91, green: 0.77, blue: 0.72))  // BAD!

// Don't use color literals
.foregroundColor(#colorLiteral(red: 0.91, green: 0.77, blue: 0.72, alpha: 1))  // BAD!
```

## UIKit Integration

For UIKit components (navigation bars, tab bars, etc.), use the `UIKitAppearance` helper:

```swift
// This is already configured in ClipCookApp.swift
UIKitAppearance.configure()

// To bridge SwiftUI colors to UIKit:
UIColor(DesignTokens.Colors.primary)
```

## Consistency Checks

Before committing UI changes, verify:
1. ✓ All colors come from `DesignTokens.Colors`
2. ✓ No hardcoded hex values (search for `#[0-9A-Fa-f]{6}`)
3. ✓ No RGB color constructors (search for `Color(red:`)
4. ✓ No color literals (search for `#colorLiteral`)

## Adding New Colors

If you need a new color:

1. **Check if it can be derived** from existing tokens first
   ```swift
   // Example: Semi-transparent primary
   DesignTokens.Colors.primary.opacity(0.5)
   ```

2. **If truly unique**, add to `DesignTokens.swift`:
   ```swift
   static let newColorName = Color(hex: "HEXCODE")  // Brief description
   ```

3. **Document** the use case in this file

4. **Update UIKitAppearance.swift** if needed for UIKit components

## Accessibility

All color combinations have been validated for WCAG AA contrast ratios:
- Text Primary on Background: ✓ AAA
- Text Secondary on Background: ✓ AA
- Primary on Background: ✓ AA

## Theme Consistency

The Midnight Rose theme should feel:
- **Premium**: Sophisticated dark backgrounds with luxurious rose gold accents
- **Warm**: Rose tones add warmth to the dark palette
- **Modern**: Clean, minimal design with intentional use of color
- **Cohesive**: Every screen should feel part of the same family

## Questions?

If you're unsure which color to use:
1. Check similar existing UI elements
2. Refer to Figma designs (if available)
3. Ask in design review
4. Default to primary colors (background, textPrimary, primary accent)
