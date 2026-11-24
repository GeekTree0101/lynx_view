package com.geektree0101.lynx_view_android

import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import androidx.coordinatorlayout.widget.CoordinatorLayout
import com.google.android.material.appbar.AppBarLayout
import com.lynx.tasm.BehaviorClassWarmer
import com.lynx.tasm.behavior.Behavior
import com.lynx.tasm.behavior.LynxContext
import com.lynx.tasm.behavior.render.IRendererHost
import com.lynx.tasm.behavior.shadow.ShadowNode
import com.lynx.tasm.behavior.ui.LynxFlattenUI
import com.lynx.tasm.behavior.ui.LynxUI
import com.lynx.tasm.event.LynxDetailEvent
import com.lynx.tasm.utils.PixelUtils

/**
 * Wraps XElement's `<scroll-coordinator>` so its `offset` event also fires while a finger
 * drags the header.
 *
 * XElement 4.0.0 on Android emits `offset` only from an `AppBarLayout.OnOffsetChangedListener`,
 * and on a real device that listener stays silent during touch-driven scrolling — events arrive
 * only for flings and programmatic scrolls (`setFoldExpanded`). A template that folds its own
 * app bar from this event therefore lags the finger, or does not move at all. iOS has its own
 * UIScrollView-based implementation and is not affected.
 *
 * Rather than subclassing `LynxUIScrollCoordinator` (which would need the annotation processor
 * for the generated `$$PropsSetter`), this delegates every factory call to XElement's own
 * behavior and, once the UI exists, watches the `AppBarLayout` every frame: whenever its vertical
 * offset changed since the last frame, the same `{offset, height}` event XElement would have sent
 * is sent, in dip, from the UI thread. Movement through any code path is caught — nested
 * pre-scroll, fling, programmatic.
 *
 * XElement's own listener keeps running, so a fling may deliver each offset twice. Receivers
 * treat the event as "paint this offset", which is idempotent.
 */
internal class DragOffsetScrollCoordinatorBehavior(
    private val original: Behavior,
) : Behavior(original.name, original.supportUIFlatten()) {

    override fun supportCreateAsync(): Boolean = original.supportCreateAsync()
    override fun needProcessDirection(): Boolean = original.needProcessDirection()
    override fun supportFragmentLayerRenderer(): Boolean = original.supportFragmentLayerRenderer()

    override fun createUI(context: LynxContext): LynxUI<*>? = attach(original.createUI(context))
    override fun createUIWithParams(context: LynxContext, param: Any?): LynxUI<*>? =
        attach(original.createUIWithParams(context, param))
    override fun createUIFiber(context: LynxContext): LynxUI<*>? = attach(original.createUIFiber(context))

    override fun createFlattenUI(context: LynxContext): LynxFlattenUI? = original.createFlattenUI(context)
    override fun createFlattenUIWithParams(context: LynxContext, param: Any?): LynxFlattenUI? =
        original.createFlattenUIWithParams(context, param)
    override fun createFlattenUIFiber(context: LynxContext): LynxFlattenUI? = original.createFlattenUIFiber(context)
    override fun createShadowNode(): ShadowNode? = original.createShadowNode()
    override fun createClassWarmer(): BehaviorClassWarmer? = original.createClassWarmer()
    override fun createPlatformRendererHost(context: LynxContext): IRendererHost? =
        original.createPlatformRendererHost(context)

    private fun attach(ui: LynxUI<*>?): LynxUI<*>? {
        val root = ui?.view as? ViewGroup ?: return ui
        val appBar = findAppBar(root, depth = 0) ?: return ui
        DragOffsetEmitter(ui, appBar).install()
        return ui
    }

    private fun findAppBar(group: ViewGroup, depth: Int): AppBarLayout? {
        for (i in 0 until group.childCount) {
            val child = group.getChildAt(i)
            if (child is AppBarLayout) return child
            if (depth < 2 && child is ViewGroup) findAppBar(child, depth + 1)?.let { return it }
        }
        return null
    }

    companion object {
        const val ELEMENT_NAME = "scroll-coordinator"

        /** Replaces XElement's `<scroll-coordinator>` behavior in [behaviors]; others pass through. */
        fun wrap(behaviors: List<Behavior>): List<Behavior> = behaviors.map {
            if (it.name == ELEMENT_NAME) DragOffsetScrollCoordinatorBehavior(it) else it
        }
    }
}

/**
 * Per-frame watcher on one `AppBarLayout`. Installed when the view attaches to a window and
 * removed when it detaches; the UI's own lifecycle owns the view, so nothing else to release.
 */
private class DragOffsetEmitter(
    private val ui: LynxUI<*>,
    private val appBar: AppBarLayout,
) : ViewTreeObserver.OnPreDrawListener, View.OnAttachStateChangeListener {

    private var lastOffset = Int.MIN_VALUE

    fun install() {
        appBar.addOnAttachStateChangeListener(this)
        if (appBar.isAttachedToWindow) onViewAttachedToWindow(appBar)
    }

    override fun onViewAttachedToWindow(v: View) {
        appBar.viewTreeObserver.addOnPreDrawListener(this)
    }

    override fun onViewDetachedFromWindow(v: View) {
        appBar.viewTreeObserver.removeOnPreDrawListener(this)
    }

    override fun onPreDraw(): Boolean {
        val behavior = (appBar.layoutParams as? CoordinatorLayout.LayoutParams)?.behavior
            as? AppBarLayout.Behavior ?: return true
        // ViewOffsetBehavior keeps the applied vertical offset (≤ 0 while collapsing).
        val offset = behavior.topAndBottomOffset
        if (offset == lastOffset) return true
        lastOffset = offset
        val range = appBar.totalScrollRange
        if (range <= 0) return true
        val context = ui.lynxContext ?: return true
        // Same shape and units as XElement's own `offset` event: dip integers, offset ≥ 0.
        val event = LynxDetailEvent(ui.sign, "offset")
        event.addDetail("offset", PixelUtils.pxToDip((-offset).toFloat()).toInt())
        event.addDetail("height", PixelUtils.pxToDip(range.toFloat()).toInt())
        context.eventEmitter.sendCustomEvent(event)
        return true
    }
}
