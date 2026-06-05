package com.moe.auto

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ScriptParserTest {
    @Test
    fun parse_demo_script_actions() {
        val json = """
            {
              "id": "t",
              "name": "测试",
              "version": 1,
              "loop": 2,
              "steps": [
                { "action": "wait", "ms": 100 },
                { "action": "tap", "x": 0.5, "y": 0.5 },
                { "action": "home" }
              ]
            }
        """.trimIndent()

        val script = ScriptParser.parse(json)
        assertEquals("t", script.id)
        assertEquals(2, script.loop)
        assertEquals(3, script.steps.size)
        assertTrue(script.steps[0] is ScriptStep.Wait)
        assertTrue(script.steps[1] is ScriptStep.Tap)
        assertTrue(script.steps[2] is ScriptStep.Home)
    }

    @Test
    fun parse_swipe_and_launch() {
        val json = """
            {
              "id": "s",
              "name": "滑动",
              "steps": [
                { "action": "swipe", "x1": 0.1, "y1": 0.8, "x2": 0.1, "y2": 0.2, "duration_ms": 300 },
                { "action": "launch", "package": "com.android.settings" }
              ]
            }
        """.trimIndent()

        val script = ScriptParser.parse(json)
        val swipe = script.steps[0] as ScriptStep.Swipe
        assertEquals(0.1f, swipe.x1, 0.001f)
        assertEquals(300L, swipe.durationMs)
        val launch = script.steps[1] as ScriptStep.Launch
        assertEquals("com.android.settings", launch.packageName)
    }
}
