package com.geektree0101.lynx_view_android

import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import androidx.coordinatorlayout.widget.CoordinatorLayout
import com.google.android.material.appbar.AppBarLayout
import com.lynx.tasm.BehaviorClassWarmer
import com.lynx.tasm.behavior.Behavior
import com.lynx.tasm.behavior.LynxContext
import com.lynx.tasm.behavior.render.IRendererHost
import com.lynx.tasm.behavior.shadow.ShadowNode
import com.lynx.tasm.behavior.ui.LynxFlattenUI
import com.lynx.tasm.behavior.ui.LynxUI
import com.scwang.smart.refresh.layout.SmartRefreshLayout
import com.scwang.smart.refresh.layout.listener.ScrollBoundaryDecider

/**
 * Wraps XElement's `<refresh>` so a pull-to-refresh can only start when the content is at its
 * true top — the way iOS's `<refresh>` behaves, where the refresh control rides the content's
 * own scroll view and only its overscroll at offset 0 opens it.
 *
 * On Android XElement's `<refresh>` is a `SmartRefreshLayout`. It opens a pull from two paths:
 * touch, when the content "cannot scroll up", and nested scrolling, when a child hands up
 * unconsumed downward `dy`. Around a `<scroll-coordinator>` (CoordinatorLayout + AppBarLayout +
 * per-page RecyclerViews, `android-nested-scroll-as-child`) the hand-off between the header and
 * the inner list leaks `dy` while the content is nowhere near the top, so the refresh header
 * (a blank band) is pushed in mid-page and the frame tears. Seen on a Galaxy M23 with the
 * header collapsed on a middle section after a slow reverse drag.
 *
 * Both paths consult the layout's `ScrollBoundaryDecider`. XElement leaves the default. This
 * one answers `canRefresh` only when every `AppBarLayout` in the content sits at offset 0 and no
 * visible descendant can still scroll up. Load-more is never used by XElement here.
 */
internal class TrueTopRefreshBehavior(
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
        (ui?.view as? SmartRefreshLayout)?.setScrollBoundaryDecider(TrueTopDecider)
        return ui
    }

    companion object {
        const val ELEMENT_NAME = "refresh"

        /** Replaces XElement's `<refresh>` behavior in [behaviors]; others pass through. */
        fun wrap(behaviors: List<Behavior>): List<Behavior> = behaviors.map {
            if (it.name == ELEMENT_NAME) TrueTopRefreshBehavior(it) else it
        }
    }
}

private object TrueTopDecider : ScrollBoundaryDecider {
    private const val MAX_DEPTH = 14
    private val rect = Rect()

    override fun canRefresh(content: View): Boolean = atTrueTop(content, 0)

    override fun canLoadMore(content: View): Boolean = false

    /** False as soon as anything visible under [view] is still scrolled down. */
    private fun atTrueTop(view: View, depth: Int): Boolean {
        if (view.visibility != View.VISIBLE || view.width == 0 || view.height == 0) return true
        // Views laid out off screen (other viewpager pages) do not count.
        if (!view.getGlobalVisibleRect(rect)) return true
        if (view is AppBarLayout) {
            val behavior = (view.layoutParams as? CoordinatorLayout.LayoutParams)?.behavior
                as? AppBarLayout.Behavior
            if (behavior != null && behavior.topAndBottomOffset != 0) return false
        }
        if (view.canScrollVertically(-1)) return false
        if (depth >= MAX_DEPTH || view !is ViewGroup) return true
        for (i in 0 until view.childCount) {
            if (!atTrueTop(view.getChildAt(i), depth + 1)) return false
        }
        return true
    }
}
