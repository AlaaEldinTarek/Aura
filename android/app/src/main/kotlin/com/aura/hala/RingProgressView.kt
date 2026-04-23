package com.aura.hala

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.View

/**
 * Custom view that draws a circular progress ring.
 * Used by FocusModeService overlay for the countdown timer.
 */
class RingProgressView(context: Context) : View(context) {

    private var progressColor: Int = 0xFFB5821B.toInt()
    private var bgColor: Int = 0x1AFFFFFF
    var strokeWidth: Float = 8f
    private var progress: Float = 0f // 0.0 to 1.0

    private val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }

    private val rect = RectF()

    fun setColors(progressColor: Int, bgColor: Int) {
        this.progressColor = progressColor
        this.bgColor = bgColor
        progressPaint.color = progressColor
        bgPaint.color = bgColor
        invalidate()
    }

    fun setProgressColor(color: Int) {
        this.progressColor = color
        progressPaint.color = color
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val padding = strokeWidth / 2f + 4f
        rect.set(padding, padding, width - padding, height - padding)

        progressPaint.strokeWidth = strokeWidth
        bgPaint.strokeWidth = strokeWidth

        // Background ring
        canvas.drawArc(rect, 0f, 360f, false, bgPaint)

        // Progress arc (starts from top, goes clockwise)
        if (progress > 0f) {
            val sweepAngle = 360f * progress
            canvas.drawArc(rect, -90f, sweepAngle, false, progressPaint)
        }
    }

    fun setProgress(p: Float) {
        progress = p.coerceIn(0f, 1f)
        invalidate()
    }
}
