package com.hienao.windtorrent

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LOG_CHANNEL = "com.windtorrent/log"
    private val THEME_CHANNEL = "com.windtorrent/theme"

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(newBase.withStoredThemeMode())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyApplicationNightMode(readStoredThemeMode(this))
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "log" -> {
                    val level = call.argument<String>("level") ?: "debug"
                    val tag = call.argument<String>("tag") ?: "WindTorrent"
                    val message = call.argument<String>("message") ?: ""
                    
                    val priority = when (level) {
                        "debug" -> Log.DEBUG
                        "info" -> Log.INFO
                        "warn" -> Log.WARN
                        "error" -> Log.ERROR
                        else -> Log.DEBUG
                    }
                    
                    Log.println(priority, tag, message)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THEME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode") ?: THEME_MODE_SYSTEM
                    if (!isSupportedThemeMode(mode)) {
                        result.error("invalid_theme_mode", "Unsupported theme mode: $mode", null)
                        return@setMethodCallHandler
                    }

                    storeThemeMode(mode)
                    applyApplicationNightMode(mode)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun Context.withStoredThemeMode(): Context {
        val mode = readStoredThemeMode(this)
        if (mode == THEME_MODE_SYSTEM) return this

        val nightMode = when (mode) {
            THEME_MODE_DARK -> Configuration.UI_MODE_NIGHT_YES
            THEME_MODE_LIGHT -> Configuration.UI_MODE_NIGHT_NO
            else -> return this
        }
        val config = Configuration(resources.configuration)
        config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or nightMode
        return createConfigurationContext(config)
    }

    private fun storeThemeMode(mode: String) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_THEME_MODE, mode)
            .apply()
    }

    private fun readStoredThemeMode(context: Context): String {
        val mode = context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_THEME_MODE, THEME_MODE_SYSTEM) ?: THEME_MODE_SYSTEM
        return if (isSupportedThemeMode(mode)) mode else THEME_MODE_SYSTEM
    }

    private fun applyApplicationNightMode(mode: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val uiModeManager = getSystemService(UiModeManager::class.java)
        val nightMode = when (mode) {
            THEME_MODE_DARK -> UiModeManager.MODE_NIGHT_YES
            THEME_MODE_LIGHT -> UiModeManager.MODE_NIGHT_NO
            else -> UiModeManager.MODE_NIGHT_AUTO
        }
        uiModeManager.setApplicationNightMode(nightMode)
    }

    private fun isSupportedThemeMode(mode: String): Boolean {
        return mode == THEME_MODE_SYSTEM || mode == THEME_MODE_LIGHT || mode == THEME_MODE_DARK
    }

    companion object {
        private const val PREFS_NAME = "windwalker_settings"
        private const val KEY_THEME_MODE = "appThemeMode"
        private const val THEME_MODE_SYSTEM = "system"
        private const val THEME_MODE_LIGHT = "light"
        private const val THEME_MODE_DARK = "dark"
    }
}
