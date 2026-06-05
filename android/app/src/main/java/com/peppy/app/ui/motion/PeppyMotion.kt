package com.peppy.app.ui.motion

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.TweenSpec
import androidx.compose.animation.core.tween

object PeppyMotion {
    const val FAST = 180
    const val NORMAL = 240
    const val SLOW = 400

    val EaseOut = CubicBezierEasing(0.0f, 0.0f, 0.2f, 1.0f)
    val EaseInOut = CubicBezierEasing(0.42f, 0.0f, 0.58f, 1.0f)

    fun <T> fastTween(): TweenSpec<T> = tween(FAST, easing = EaseOut)
    fun <T> normalTween(): TweenSpec<T> = tween(NORMAL, easing = EaseOut)
    fun <T> slowTween(): TweenSpec<T> = tween(SLOW, easing = EaseOut)
}
