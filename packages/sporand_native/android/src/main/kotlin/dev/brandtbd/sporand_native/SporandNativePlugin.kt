package dev.brandtbd.sporand_native

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers the Pigeon host APIs of this package (auto-registered through
 * GeneratedPluginRegistrant; no MainActivity changes are needed).
 */
class SporandNativePlugin : FlutterPlugin {
    private var clipPlayer: ClipPlayerHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        InputClockApi.setUp(binding.binaryMessenger, InputClockHost())
        val player = ClipPlayerHost(binding.applicationContext)
        clipPlayer = player
        ClipPlayerApi.setUp(binding.binaryMessenger, player)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        InputClockApi.setUp(binding.binaryMessenger, null)
        ClipPlayerApi.setUp(binding.binaryMessenger, null)
        clipPlayer?.dispose()
        clipPlayer = null
    }
}
