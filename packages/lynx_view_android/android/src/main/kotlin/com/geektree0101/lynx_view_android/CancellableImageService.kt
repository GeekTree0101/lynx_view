package com.geektree0101.lynx_view_android

import android.content.Context
import com.facebook.common.executors.UiThreadImmediateExecutorService
import com.facebook.common.references.CloseableReference
import com.facebook.datasource.BaseDataSubscriber
import com.facebook.datasource.DataSource
import com.facebook.drawee.backends.pipeline.Fresco
import com.facebook.imagepipeline.image.CloseableImage
import com.facebook.imagepipeline.image.CloseableStaticBitmap
import com.lynx.service.image.FrescoReleasableImage
import com.lynx.service.image.LynxImageService
import com.lynx.service.image.utils.ImageUtils
import com.lynx.tasm.image.ImageContent
import com.lynx.tasm.image.ImageErrorCodeUtils
import com.lynx.tasm.image.model.AnimationListener
import com.lynx.tasm.image.model.ImageInfo
import com.lynx.tasm.image.model.ImageLoadListener
import com.lynx.tasm.image.model.ImageRequestInfo
import com.lynx.tasm.service.ILynxImageService
import com.lynx.tasm.service.ILynxImageServiceExtension
import com.lynx.tasm.service.IServiceProvider
import java.util.concurrent.ConcurrentHashMap

/**
 * Makes a scrolled-past `<image>` request actually stop.
 *
 * Lynx releases an image request when the `<image>` moves on — a recycled list
 * cell gets a new `src`, the element goes away — by calling [releaseImage]
 * with the same [ImageRequestInfo] it fetched with. The stock
 * `LynxImageService` (lynx-service-image 4.0.0) subscribes to the Fresco
 * `DataSource` it starts and never keeps it, so [releaseImage] has nothing to
 * close: in a long image list every cell flung past keeps downloading and
 * decoding behind the ones on screen.
 *
 * This wraps the stock service and takes over only the network path of
 * [fetchImage]: it keeps the `DataSource` and closes it on [releaseImage],
 * which cancels the fetch in Fresco. Everything else goes to the stock
 * service unchanged — memory-cache hits, animated images (it wires their loop
 * events), prefetch, background images. The success and failure reports
 * follow the stock subscriber line for line; keep the two in step when Lynx
 * is upgraded.
 *
 * Only acts while [LynxViewPlugin.isImageRequestCancellationEnabled]; read per
 * request, so turning it off sends the next request through the stock path.
 */
internal class CancellableImageService(
    private val base: LynxImageService,
) : ILynxImageService by base, ILynxImageServiceExtension by base {

    private val inFlight =
        ConcurrentHashMap<ImageRequestInfo, DataSource<CloseableReference<CloseableImage>>>()

    // Registered under the same key as the stock service — Lynx looks the
    // image service up by this class.
    override fun getServiceClass(): Class<out IServiceProvider> = ILynxImageService::class.java

    override fun fetchImage(
        info: ImageRequestInfo,
        listener: ImageLoadListener,
        animationListener: AnimationListener?,
        context: Context,
    ) {
        if (!LynxViewPlugin.isImageRequestCancellationEnabled()) {
            base.fetchImage(info, listener, animationListener, context)
            return
        }
        val request = ImageUtils.getFrescoImageRequest(info)
        val pipeline = Fresco.getImagePipeline()
        // Already decoded: the stock service answers synchronously from the
        // memory cache, and there is nothing in flight to cancel.
        if (request == null || pipeline.isInBitmapMemoryCache(request)) {
            base.fetchImage(info, listener, animationListener, context)
            return
        }
        val dataSource = pipeline.fetchDecodedImage(request, info.callerContext)
        inFlight.put(info, dataSource)?.close()
        dataSource.subscribe(
            object : BaseDataSubscriber<CloseableReference<CloseableImage>>() {
                override fun onNewResultImpl(
                    source: DataSource<CloseableReference<CloseableImage>>,
                ) {
                    if (source.isFinished) inFlight.remove(info, source)
                    val reference = source.result ?: return
                    try {
                        val image = reference.get()
                        if (image is CloseableStaticBitmap) {
                            listener.onSuccess(
                                ImageContent(FrescoReleasableImage(reference.clone())),
                                info,
                                ImageInfo(image.width, image.height, false),
                            )
                        } else {
                            // Animated: the stock service builds the drawable
                            // and its loop events. The decode is cached now, so
                            // asking it again costs no second download.
                            base.fetchImage(info, listener, animationListener, context)
                        }
                    } catch (error: Throwable) {
                        listener.onFailure(ImageErrorCodeUtils.checkImageException(error), error)
                    } finally {
                        CloseableReference.closeSafely(reference)
                    }
                }

                override fun onFailureImpl(source: DataSource<CloseableReference<CloseableImage>>) {
                    inFlight.remove(info, source)
                    val cause = source.failureCause
                    listener.onFailure(ImageErrorCodeUtils.checkImageException(cause), cause)
                }

                override fun onCancellation(source: DataSource<CloseableReference<CloseableImage>>) {
                    inFlight.remove(info, source)
                }
            },
            UiThreadImmediateExecutorService.getInstance(),
        )
    }

    override fun releaseImage(info: ImageRequestInfo) {
        // Closing a running DataSource cancels it; a finished one is already
        // gone from the map.
        inFlight.remove(info)?.close()
        base.releaseImage(info)
    }

    /** Test-only: requests still running. */
    internal fun inFlightCountForTesting(): Int = inFlight.size
}
