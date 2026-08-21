package com.geektree0101.lynx_view_android

import com.lynx.react.bridge.JavaOnlyArray
import com.lynx.react.bridge.JavaOnlyMap
import com.lynx.react.bridge.ReadableType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

internal class LynxValueTest {
    @Test
    fun `leaves pass through untouched`() {
        assertEquals("s", toLynxValue("s"))
        assertEquals(1, toLynxValue(1))
        assertEquals(2.5, toLynxValue(2.5))
        assertEquals(true, toLynxValue(true))
        assertNull(toLynxValue(null))
    }

    @Test
    fun `a flat map becomes a JavaOnlyMap Lynx can read`() {
        val converted = assertIs<JavaOnlyMap>(toLynxValue(mapOf("id" to 7, "ok" to true)))

        assertEquals(ReadableType.Int, converted.getType("id"))
        assertEquals(7, converted.getInt("id"))
        assertEquals(ReadableType.Boolean, converted.getType("ok"))
    }

    @Test
    fun `a nested map is rebuilt, not handed over as a plain Map`() {
        val converted = assertIs<JavaOnlyMap>(
            toLynxValue(mapOf("result" to mapOf("status" to 200))),
        )

        // getType is where Lynx rejects a foreign value; a raw LinkedHashMap
        // here is exactly what threw before this conversion existed.
        assertEquals(ReadableType.Map, converted.getType("result"))
        assertEquals(200, converted.getMap("result")!!.getInt("status"))
    }

    @Test
    fun `a nested list is rebuilt as a JavaOnlyArray`() {
        val converted = assertIs<JavaOnlyMap>(
            toLynxValue(mapOf("icons" to listOf("plus", "close"))),
        )

        assertEquals(ReadableType.Array, converted.getType("icons"))
        val icons = converted.getArray("icons")!!
        assertEquals(2, icons.size())
        assertEquals("plus", icons.getString(0))
    }

    @Test
    fun `maps inside lists inside maps are all rebuilt`() {
        val converted = assertIs<JavaOnlyMap>(
            toLynxValue(mapOf("items" to listOf(mapOf("mall" to "coupang")))),
        )

        val items = converted.getArray("items")!!
        assertEquals(ReadableType.Map, items.getType(0))
        assertEquals("coupang", items.getMap(0).getString("mall"))
    }

    @Test
    fun `a bridge reply envelope survives the conversion`() {
        // The shape that reached sendEvent on a real screen and threw:
        // "Invalid value {body={items=[], status=failed}, status=200} for key
        // result contained in JavaOnlyMap".
        val reply = mapOf(
            "id" to "1",
            "ok" to true,
            "result" to mapOf(
                "status" to 200,
                "body" to mapOf("status" to "failed", "items" to emptyList<Any?>()),
            ),
        )

        val converted = assertIs<JavaOnlyMap>(toLynxValue(reply))

        assertEquals(ReadableType.Map, converted.getType("result"))
        val result = converted.getMap("result")!!
        assertEquals(200, result.getInt("status"))
        assertEquals(ReadableType.Map, result.getType("body"))
        assertEquals(ReadableType.Array, result.getMap("body")!!.getType("items"))
    }

    @Test
    fun `null values inside a map are preserved`() {
        val converted = assertIs<JavaOnlyMap>(toLynxValue(mapOf("error" to null)))

        assertEquals(ReadableType.Null, converted.getType("error"))
    }

    @Test
    fun `a top level list becomes a JavaOnlyArray`() {
        val converted = assertIs<JavaOnlyArray>(toLynxValue(listOf(1, "two")))

        assertEquals(2, converted.size)
        assertEquals(1, converted.getInt(0))
        assertEquals("two", converted.getString(1))
    }
}
