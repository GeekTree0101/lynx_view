package com.geektree0101.lynx_view_android

import com.lynx.tasm.LynxViewBuilder
import com.lynx.tasm.behavior.Behavior
import com.lynx.tasm.base.LLog

/**
 * Registers XElement's elements (`<input>`, `<textarea>`, `<svg>`, `<overlay>`,
 * ...) with each [LynxViewBuilder].
 *
 * Lynx's core registers only its own built-in elements; everything else lives
 * in XElement, and — unlike iOS, where registration happens through a section
 * the loader scans — Android requires the host to hand the behaviors to the
 * builder explicitly:
 *
 *     viewBuilder.addBehaviors(new XElementBehaviors().create())
 *
 * Adding the Maven dependency alone does nothing. Without this call a template
 * using `<input>` compiles, renders an empty box, and never takes focus.
 *
 * Resolved reflectively so the plugin keeps working when a host app excludes
 * the XElement artifact: the classes are simply absent and nothing is
 * registered, rather than the plugin failing to load.
 */
internal object XElementSupport {

    private const val BEHAVIORS_CLASS = "com.lynx.xelement.XElementBehaviors"

    /** Resolved once — a missing artifact should not cost a lookup per view. */
    private val behaviors: List<Behavior>? by lazy { loadBehaviors() }

    fun addBehaviorsIfPresent(builder: LynxViewBuilder) {
        val resolved = behaviors ?: return
        builder.addBehaviors(resolved)
    }

    private fun loadBehaviors(): List<Behavior>? {
        return try {
            val clazz = Class.forName(BEHAVIORS_CLASS)
            val instance = clazz.getDeclaredConstructor().newInstance()
            @Suppress("UNCHECKED_CAST")
            (clazz.getMethod("create").invoke(instance) as? List<Behavior>)
        } catch (_: ClassNotFoundException) {
            // XElement was excluded by the host app. Expected; not an error.
            null
        } catch (e: Exception) {
            // Present but unusable — worth saying so, since the symptom
            // otherwise looks like "the element silently does nothing".
            LLog.w("lynx_view", "XElement found but its behaviors could not be created: $e")
            null
        }
    }

    /** Test-only: whether XElement resolved in this process. */
    internal fun isAvailableForTesting(): Boolean = behaviors != null
}
