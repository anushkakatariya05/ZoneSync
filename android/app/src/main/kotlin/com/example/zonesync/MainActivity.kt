package com.example.zonesync

import android.content.Intent
import android.provider.Settings
import android.app.NotificationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "zonesync/dnd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(DndPlugin())

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            val notificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                "requestDndAccess" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DND_SETTINGS_ERROR", e.message, null)
                    }
                }

                "hasDndAccess" -> {
                    result.success(
                        notificationManager.isNotificationPolicyAccessGranted
                    )
                }

                "setDndOn" -> {
                    if (!notificationManager.isNotificationPolicyAccessGranted) {
                        result.error("NO_DND_ACCESS", "Grant DND access first", null)
                    } else {
                        try {
                            notificationManager.setInterruptionFilter(
                                NotificationManager.INTERRUPTION_FILTER_NONE
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("DND_ON_ERROR", e.message, null)
                        }
                    }
                }

                "setDndOff" -> {
                    if (!notificationManager.isNotificationPolicyAccessGranted) {
                        result.error("NO_DND_ACCESS", "Grant DND access first", null)
                    } else {
                        try {
                            notificationManager.setInterruptionFilter(
                                NotificationManager.INTERRUPTION_FILTER_ALL
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("DND_OFF_ERROR", e.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
