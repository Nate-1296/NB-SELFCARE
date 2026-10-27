package com.nb.selfcare.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime

class ReminderSpecTest {

    private fun spec(
        minutesOfDay: Int,
        daysMask: Int = 0x7F,
        intervalMinutes: Int? = null,
        windowEndMinutes: Int = 21 * 60,
    ) = ReminderSpec(1, "t", "b", minutesOfDay, daysMask, intervalMinutes, windowEndMinutes)

    // 2026-10-26 es lunes.
    private val mondayMorning = LocalDateTime.of(2026, 10, 26, 6, 0)

    @Test
    fun `aparición diaria del mismo día si aún no pasó`() {
        assertEquals(LocalDateTime.of(2026, 10, 26, 7, 30), spec(7 * 60 + 30).nextOccurrence(mondayMorning))
    }

    @Test
    fun `si ya pasó la hora, salta al día siguiente`() {
        val after = LocalDateTime.of(2026, 10, 26, 8, 0)
        assertEquals(LocalDateTime.of(2026, 10, 27, 7, 30), spec(7 * 60 + 30).nextOccurrence(after))
    }

    @Test
    fun `respeta la máscara de días (solo sábado)`() {
        val saturdayOnly = 1 shl 5
        assertEquals(
            LocalDateTime.of(2026, 10, 31, 9, 0),
            spec(9 * 60, daysMask = saturdayOnly).nextOccurrence(mondayMorning),
        )
    }

    @Test
    fun `la hidratación se repite cada intervalo dentro de la ventana`() {
        val water = spec(11 * 60, intervalMinutes = 120, windowEndMinutes = 21 * 60)
        assertEquals(LocalDateTime.of(2026, 10, 26, 13, 0), water.nextOccurrence(LocalDateTime.of(2026, 10, 26, 11, 0)))
        assertEquals(LocalDateTime.of(2026, 10, 27, 11, 0), water.nextOccurrence(LocalDateTime.of(2026, 10, 26, 21, 5)))
    }

    @Test
    fun `sin días activos no se programa nada`() {
        assertNull(spec(9 * 60, daysMask = 0).nextOccurrence(mondayMorning))
    }
}
