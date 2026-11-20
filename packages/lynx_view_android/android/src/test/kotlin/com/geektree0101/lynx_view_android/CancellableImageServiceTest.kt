package com.geektree0101.lynx_view_android

import android.content.Context
import com.lynx.service.image.LynxImageService
import com.lynx.tasm.image.model.AnimationListener
import com.lynx.tasm.image.model.ImageLoadListener
import com.lynx.tasm.image.model.ImageRequestInfo
import com.lynx.tasm.service.ILynxImageService
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class CancellableImageServiceTest {
    private lateinit var base: LynxImageService
    private lateinit var service: CancellableImageService

    @BeforeTest
    fun setUp() {
        LynxViewPlugin.resetForTesting()
        base = mock(LynxImageService::class.java)
        service = CancellableImageService(base)
    }

    @AfterTest
    fun tearDown() {
        LynxViewPlugin.resetForTesting()
    }

    @Test
    fun `cancellation is off by default`() {
        assertFalse(LynxViewPlugin.isImageRequestCancellationEnabled())
    }

    @Test
    fun `off, a fetch goes to the stock service unchanged`() {
        val info = mock(ImageRequestInfo::class.java)
        val listener = mock(ImageLoadListener::class.java)
        val animation = mock(AnimationListener::class.java)
        val context = mock(Context::class.java)

        service.fetchImage(info, listener, animation, context)

        verify(base).fetchImage(info, listener, animation, context)
        assertEquals(0, service.inFlightCountForTesting())
    }

    @Test
    fun `release always reaches the stock service`() {
        val info = mock(ImageRequestInfo::class.java)
        LynxViewPlugin.setImageRequestCancellationEnabled(true)

        service.releaseImage(info)

        verify(base).releaseImage(info)
    }

    @Test
    fun `registers under the image service key`() {
        assertEquals(ILynxImageService::class.java, service.serviceClass)
    }

    @Test
    fun `the switch follows the last call`() {
        LynxViewPlugin.setImageRequestCancellationEnabled(true)
        assertEquals(true, LynxViewPlugin.isImageRequestCancellationEnabled())
        LynxViewPlugin.setImageRequestCancellationEnabled(false)
        assertEquals(false, LynxViewPlugin.isImageRequestCancellationEnabled())
    }
}
