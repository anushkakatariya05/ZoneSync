package com.example.zonesync_dnd

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ZoneSyncDndPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val PREFS_NAME = "zonesync_dnd_prefs"
        private const val KEY_PREVIOUS_FILTER = "previous_filter"
        private const val KEY_CHANGED_BY_APP = "changed_by_app"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // Separate channel so it doesn't overwrite MainActivity's UI handler.
        channel = MethodChannel(
            binding.binaryMessenger,
            "zonesync/dnd_background"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = context.getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager

        when (call.method) {
            "requestDndAccess" -> {
                try {
                    val intent = Intent(
                        Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("DND_SETTINGS_ERROR", e.message, null)
                }
            }

            "hasDndAccess" -> {
                result.success(manager.isNotificationPolicyAccessGranted)
            }

            "setDndOn" -> result.success(setDnd(manager, true))
            "setDndOff" -> result.success(setDnd(manager, false))

            else -> result.notImplemented()
        }
    }

    private fun setDnd(
        manager: NotificationManager,
        enabled: Boolean
    ): Boolean {
        if (!manager.isNotificationPolicyAccessGranted) return false

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        return try {
            if (enabled) {
                if (!prefs.getBoolean(KEY_CHANGED_BY_APP, false) &&
                    manager.currentInterruptionFilter !=
                    NotificationManager.INTERRUPTION_FILTER_NONE
                ) {
                    prefs.edit()
                        .putInt(
                            KEY_PREVIOUS_FILTER,
                            manager.currentInterruptionFilter
                        )
                        .putBoolean(KEY_CHANGED_BY_APP, true)
                        .apply()

                    manager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_NONE
                    )
                }
            } else if (prefs.getBoolean(KEY_CHANGED_BY_APP, false)) {
                val previousFilter = prefs.getInt(
                    KEY_PREVIOUS_FILTER,
                    NotificationManager.INTERRUPTION_FILTER_ALL
                )

                manager.setInterruptionFilter(previousFilter)
                prefs.edit()
                    .remove(KEY_PREVIOUS_FILTER)
                    .putBoolean(KEY_CHANGED_BY_APP, false)
                    .apply()
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}