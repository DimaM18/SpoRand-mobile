package dev.brandtbd.sporand_native

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers the Pigeon host APIs of this package (auto-registered through
 * GeneratedPluginRegistrant; no MainActivity changes are needed). The input
 * clock lives in the mobile_kit_clock plugin.
 */
class SporandNativePlugin : FlutterPlugin {
    private var clipPlayer: ClipPlayerHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val player = ClipPlayerHost(binding.applicationContext)
        clipPlayer = player
        ClipPlayerApi.setUp(binding.binaryMessenger, player)
        MusicAppApi.setUp(binding.binaryMessenger, MusicAppHost(binding.applicationContext))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ClipPlayerApi.setUp(binding.binaryMessenger, null)
        MusicAppApi.setUp(binding.binaryMessenger, null)
        clipPlayer?.dispose()
        clipPlayer = null
    }
}
