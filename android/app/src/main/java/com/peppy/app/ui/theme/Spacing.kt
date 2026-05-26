package com.peppy.app.ui.theme

import androidx.compose.ui.unit.dp

// peppy Design System v2 — Spacing
// 4px base scale

object Spacing {
    val space1 = 4.dp    // Tightest gap
    val space2 = 8.dp    // Inline siblings
    val space3 = 12.dp   // Compact stack
    val space4 = 16.dp   // Default — body gap, card padding (mobile)
    val space5 = 20.dp   // Mobile screen edge padding
    val space6 = 24.dp   // Section gaps inside a card
    val space8 = 32.dp   // Between unrelated sections
    val space10 = 40.dp  // Block separator
    val space12 = 48.dp  // Hero vertical rhythm

    // Aliases for backward compatibility
    val xs = space1
    val sm = space2
    val md = space4
    val lg = space6
    val xl = space8
    val xxl = space12
}

// peppy Design System v2 — Corner Radius
object CornerRadius {
    val sm = 8.dp     // Inputs, chips, tags
    val md = 16.dp    // Cards, list rows, modals
    val lg = 20.dp    // Hero cards, bottom sheets
    val pill = 999.dp // All buttons, all toggles, avatars
}
