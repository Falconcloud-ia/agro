package com.example.controlgestionagro

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

object AlarmService {
    private const val DART_ENTRYPOINT = "backgroundCallbackDispatcher"

    fun startFlutterEngine(context: Context) {
        val loader = FlutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)

        val flutterEngine = FlutterEngine(context)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), DART_ENTRYPOINT)
        )
    }
}
