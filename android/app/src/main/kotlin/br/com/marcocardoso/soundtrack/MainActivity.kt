package br.com.marcocardoso.soundtrack

import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceFragmentActivity() {
    private var documentChannel: DocumentChannel? = null
    private var systemStatusChannel: SystemStatusChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        disposeChannels()
        documentChannel = DocumentChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        systemStatusChannel = SystemStatusChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        disposeChannels()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        disposeChannels()
        super.onDestroy()
    }

    private fun disposeChannels() {
        documentChannel?.dispose()
        documentChannel = null
        systemStatusChannel?.dispose()
        systemStatusChannel = null
    }
}
