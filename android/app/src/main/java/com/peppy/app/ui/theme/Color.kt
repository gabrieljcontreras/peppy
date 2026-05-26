package com.peppy.app.ui.theme

import androidx.compose.ui.graphics.Color

// peppy Design System v2 — Professional Direction
// Three roles: Rust (brand), Ink (foreground), Cream (background)

// Rust scale (brand accent)
val Rust100 = Color(0xFFF7DDCB)
val Rust300 = Color(0xFFE5A487)
val Rust500 = Color(0xFFC76B3E)  // Primary brand color
val Rust700 = Color(0xFF98512E)  // Hover/pressed states
val Rust900 = Color(0xFF663520)

// Ink scale (text, dark buttons)
val Ink100 = Color(0xFFE5E7EB)   // Borders, dividers
val Ink300 = Color(0xFFBFC1C7)
val Ink500 = Color(0xFF777A82)   // Secondary text
val Ink700 = Color(0xFF4A4D54)
val Ink900 = Color(0xFF1E2026)   // Primary text, headlines

// Cream scale (backgrounds)
val Cream50 = Color(0xFFFCFAF5)  // Card backgrounds
val Cream100 = Color(0xFFFAF7F0) // Default page background
val Cream200 = Color(0xFFF3EDDF) // Elevated surfaces

// Semantic colors
val Success = Color(0xFF4E8C5B)
val Warning = Color(0xFFD9A04A)
val Danger = Color(0xFFC24B3F)

// ============================================
// Light Mode Aliases (default)
// ============================================
val LightPrimary = Rust500
val LightPrimaryContainer = Rust100
val LightOnPrimary = Cream100
val LightOnPrimaryContainer = Ink900

val LightBackground = Cream100
val LightSurface = Cream50
val LightSurfaceVariant = Cream200
val LightOnBackground = Ink900
val LightOnSurface = Ink900
val LightOnSurfaceVariant = Ink500

val LightOutline = Ink100
val LightOutlineVariant = Ink100

val LightError = Danger
val LightOnError = Cream100

// ============================================
// Dark Mode Colors
// Per design system: Cream inverts to deep ink,
// rust desaturates slightly, text inverts to warm off-white
// ============================================
val RustDark = Color(0xFFD4805A)  // Slightly desaturated rust for dark mode

val DarkPrimary = RustDark
val DarkPrimaryContainer = Rust900
val DarkOnPrimary = Cream100
val DarkOnPrimaryContainer = Cream100

val DarkBackground = Color(0xFF121214)  // Deep ink background
val DarkSurface = Color(0xFF1A1A1E)     // Slightly elevated surface
val DarkSurfaceVariant = Color(0xFF242428)  // Card backgrounds
val DarkOnBackground = Color(0xFFF5F3EE)  // Warm off-white text
val DarkOnSurface = Color(0xFFF5F3EE)
val DarkOnSurfaceVariant = Color(0xFFA0A3AA)  // Secondary text

val DarkOutline = Color(0xFF3A3A3E)
val DarkOutlineVariant = Color(0xFF2A2A2E)

val DarkError = Color(0xFFE57373)  // Lighter red for dark mode
val DarkOnError = Color(0xFF121214)

// Legacy aliases (for backward compatibility, use light mode values)
val Primary = LightPrimary
val PrimaryContainer = LightPrimaryContainer
val OnPrimary = LightOnPrimary
val OnPrimaryContainer = LightOnPrimaryContainer
val Background = LightBackground
val Surface = LightSurface
val SurfaceVariant = LightSurfaceVariant
val OnBackground = LightOnBackground
val OnSurface = LightOnSurface
val OnSurfaceVariant = LightOnSurfaceVariant
val Outline = LightOutline
val OutlineVariant = LightOutlineVariant
val Error = LightError
val OnError = LightOnError