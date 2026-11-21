package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** One Arabic count rule for the Wird, the digest and the task card minutes (owner rule 2026-11-21). */
class ArabicCountTest {
    private fun pages(n: Int) = ArabicCount.phrase(n, "صفحة", "صفحتان", "صفحات", "صفحة واحدة")
    private fun minutes(n: Int) = ArabicCount.phrase(n, "دقيقة", "دقيقتان", "دقائق", "دقيقة واحدة")
    private fun overdue(n: Int) = ArabicCount.phrase(n, "مهمة متأخرة", "مهمتان متأخرتان", "مهام متأخرة", "مهمة متأخرة واحدة")

    @Test
    fun one_noSingularDigit_singularPlusWahida() {
        assertEquals("صفحة واحدة", pages(1))
        assertEquals("دقيقة واحدة", minutes(1))
        assertEquals("مهمة متأخرة واحدة", overdue(1))
    }

    @Test
    fun two_dual_noDigit() {
        assertEquals("صفحتان", pages(2))
        assertEquals("دقيقتان", minutes(2))
        assertEquals("مهمتان متأخرتان", overdue(2))
    }

    @Test
    fun threeToTen_digitPlusPlural() {
        assertEquals("٣ صفحات", pages(3))
        assertEquals("٥ دقائق", minutes(5))
        assertEquals("١٠ صفحات", pages(10))
        assertEquals("٧ مهام متأخرة", overdue(7))
    }

    @Test
    fun elevenPlus_digitPlusSingular() {
        assertEquals("١١ صفحة", pages(11))
        assertEquals("١٥ دقيقة", minutes(15))
        assertEquals("٦٠ دقيقة", minutes(60))
        assertEquals("١٢ مهمة متأخرة", overdue(12))
    }

    @Test
    fun noLatinDigits() {
        for (n in listOf(0, 1, 2, 3, 10, 11, 99, 120)) {
            assertFalse(pages(n).any { it in '0'..'9' })
        }
    }
}
