package com.example.zonesync

import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DndPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(
        binding: FlutterPlugin.FlutterPluginBinding
    ) {
        context = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "zonesync/dnd_background"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val manager = context.getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager

        when (call.method) {
            "hasDndAccess" ->
                result.success(manager.isNotificationPolicyAccessGranted)

            "setDndOn" ->
                result.success(setDnd(manager, true))

            "setDndOff" ->
                result.success(setDnd(manager, false))

            else -> result.notImplemented()
        }
    }

    private fun setDnd(
        manager: NotificationManager,
        enabled: Boolean
    ): Boolean {
        if (!manager.isNotificationPolicyAccessGranted) return false

        val prefs = context.getSharedPreferences(
            "zonesync_dnd_prefs",
            Context.MODE_PRIVATE
        )

        return try {
            if (enabled) {
                if (!prefs.getBoolean("changed_by_app", false) &&
                    manager.currentInterruptionFilter !=
                    NotificationManager.INTERRUPTION_FILTER_NONE
                ) {
                    prefs.edit()
                        .putInt(
                            "previous_filter",
                            manager.currentInterruptionFilter
                        )
                        .putBoolean("changed_by_app", true)
                        .commit()
                }

                if (prefs.getBoolean("changed_by_app", false)) {
                    manager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_NONE
                    )
                }
            } else if (prefs.getBoolean("changed_by_app", false)) {
                val previous = prefs.getInt(
                    "previous_filter",
                    NotificationManager.INTERRUPTION_FILTER_ALL
                )

                manager.setInterruptionFilter(previous)

                prefs.edit()
                    .remove("previous_filter")
                    .putBoolean("changed_by_app", false)
                    .commit()
            }

            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onDetachedFromEngine(
        binding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel.setMethodCallHandler(null)
    }
}