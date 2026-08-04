import Lynx
import UIKit

/// Hosts a `LynxView` and keeps Lynx's viewport in sync with the size Flutter
/// gives the platform view.
///
/// A Flutter platform view is created before its final size is known — the
/// factory hands us a frame that is usually zero and the real bounds arrive
/// later, on layout. Lynx does not observe that on its own: whatever viewport
/// it laid out against at load time is what percentage sizes, `flex`, `vh`
/// and scrollable extents are all resolved from. Left alone, templates lay
/// out against a zero viewport, which is why `flex: 1` collapses and a
/// `scroll-view` has no scrollable region even though its content clearly
/// overflows.
///
/// So the container forwards its bounds to `updateViewport(...)` whenever they
/// change, which is the hook Lynx exposes for exactly this.
final class LynxContainerView: UIView {
    let lynxView: LynxView

    private var lastReportedSize: CGSize = .zero

    init(lynxView: LynxView) {
        self.lynxView = lynxView
        super.init(frame: .zero)
        lynxView.layoutWidthMode = .exact
        lynxView.layoutHeightMode = .exact
        addSubview(lynxView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        lynxView.frame = bounds

        // A zero size means Flutter has not placed us yet; reporting it would
        // make Lynx lay the template out against nothing.
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard bounds.size != lastReportedSize else { return }

        lastReportedSize = bounds.size
        lynxView.updateViewport(
            withPreferredLayoutWidth: bounds.width,
            preferredLayoutHeight: bounds.height
        )
    }
}
