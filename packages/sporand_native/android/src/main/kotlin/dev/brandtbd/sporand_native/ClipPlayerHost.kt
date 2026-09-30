package dev.brandtbd.sporand_native

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * Scheduled clip playback on the playback device (brief §5, scheduled
 * source): a media3 ExoPlayer prepared in advance and started with
 * `Handler.postAtTime` on the uptime clock (the input clock base).
 *
 * Pigeon runs the suspend functions on Dispatchers.Main, so every player
 * call happens on the main looper, ExoPlayer's application thread.
 */
class ClipPlayerHost(private val context: Context) : ClipPlayerApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cacheDir = File(context.cacheDir, "sporand_clips")
    private var player: ExoPlayer? = null
    private var pendingStart: Runnable? = null
    private var pendingContinuation: CancellableContinuation<Long>? = null

    override suspend fun prefetch(clipRef: String, clipUrl: String): PreloadResultMessage {
        val started = SystemClock.uptimeMillis()
        val ok = withContext(Dispatchers.IO) {
            runCatching { download(clipUrl, cacheFile(clipRef)) }.isSuccess
        }
        return PreloadResultMessage(
            ok = ok,
            preloadMs = SystemClock.uptimeMillis() - started,
            errorCode = if (ok) null else "clip_load_failed",
        )
    }

    override suspend fun prepare(clip: ClipSourceMessage): PreloadResultMessage {
        val started = SystemClock.uptimeMillis()
        releasePlayer()
        val cached = clip.clipRef?.let(::cacheFile)?.takeIf { it.exists() }
        val item = MediaItem.Builder()
            .setUri(cached?.let(Uri::fromFile) ?: Uri.parse(clip.clipUrl))
            .setClippingConfiguration(
                // Full-track playback is impossible by construction (licensing).
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(clip.snippetStartMs)
                    .setEndPositionMs(clip.snippetStartMs + clip.snippetDurationMs)
                    .build(),
            )
            .build()
        val exo = ExoPlayer.Builder(context).build().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_GAME)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                /* handleAudioFocus= */ true,
            )
            playWhenReady = false
            setMediaItem(item)
        }
        player = exo
        val errorCode = suspendCancellableCoroutine<String?> { cont ->
            val listener = object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (playbackState == Player.STATE_READY) {
                        exo.removeListener(this)
                        if (cont.isActive) cont.resume(null)
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    exo.removeListener(this)
                    if (cont.isActive) cont.resume("clip_load_failed")
                }
            }
            exo.addListener(listener)
            exo.prepare()
            cont.invokeOnCancellation { exo.removeListener(listener) }
        }
        if (errorCode != null) releasePlayer()
        return PreloadResultMessage(
            ok = errorCode == null,
            preloadMs = SystemClock.uptimeMillis() - started,
            errorCode = errorCode,
        )
    }

    override suspend fun playAt(startAtMonoUs: Long): PlaybackStartedMessage {
        val exo = player ?: throw NativeBridgeError("not_prepared", "prepare() was not called")
        val startedUs = suspendCancellableCoroutine<Long> { cont ->
            val start = Runnable {
                pendingStart = null
                pendingContinuation = null
                val nowUs = SystemClock.uptimeMillis() * 1000L
                exo.play()
                if (cont.isActive) cont.resume(nowUs)
            }
            pendingStart = start
            pendingContinuation = cont
            // postAtTime is scheduled on SystemClock.uptimeMillis(), the same
            // clock as InputClockApi; a time in the past runs immediately.
            mainHandler.postAtTime(start, startAtMonoUs / 1000L)
            cont.invokeOnCancellation { mainHandler.removeCallbacks(start) }
        }
        return PlaybackStartedMessage(
            audioStartMonoUs = startedUs,
            // No public API reports the AudioTrack latency; brief §5 allows 0.
            outputLatencyMs = 0L,
            outputRoute = currentRoute(),
        )
    }

    override fun stop() {
        releasePlayer()
    }

    override fun dispose() {
        releasePlayer()
        cacheDir.deleteRecursively()
    }

    private fun releasePlayer() {
        pendingStart?.let(mainHandler::removeCallbacks)
        pendingStart = null
        pendingContinuation?.let {
            if (it.isActive) it.resumeWithException(NativeBridgeError("stopped", "playback stopped"))
        }
        pendingContinuation = null
        player?.release()
        player = null
    }

    private fun currentRoute(): OutputRouteMessage {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices: List<AudioDeviceInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val attributes = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_GAME)
                    .build()
                audio.getAudioDevicesForAttributes(attributes)
            } else {
                // Before API 33 only the available outputs are known; prefer
                // the one Android routes media to first.
                audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
            }
        val types = devices.map { it.type }.toSet()
        return when {
            types.any { it in BLUETOOTH_TYPES } -> OutputRouteMessage.BLUETOOTH
            types.any { it in WIRED_TYPES } -> OutputRouteMessage.WIRED
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER in types -> OutputRouteMessage.SPEAKER
            else -> OutputRouteMessage.OTHER
        }
    }

    private fun download(url: String, target: File) {
        if (!url.startsWith("https://")) throw IOException("invalid clip url")
        cacheDir.mkdirs()
        val partial = File(target.path + ".part")
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 15_000
        try {
            if (connection.responseCode !in 200..299) {
                throw IOException("HTTP ${connection.responseCode}")
            }
            connection.inputStream.use { input ->
                partial.outputStream().use { output -> input.copyTo(output) }
            }
            if (!partial.renameTo(target)) throw IOException("cannot store clip")
        } finally {
            connection.disconnect()
            partial.delete()
        }
    }

    /** clip_ref is an opaque URL-safe token, so it is a safe file name. */
    private fun cacheFile(clipRef: String): File =
        File(cacheDir, clipRef.filter { it.isLetterOrDigit() || it == '_' || it == '-' } + ".clip")

    private companion object {
        val BLUETOOTH_TYPES = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            26, // TYPE_BLE_HEADSET (API 31)
            27, // TYPE_BLE_SPEAKER (API 31)
        )
        val WIRED_TYPES = setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
        )
    }
}
