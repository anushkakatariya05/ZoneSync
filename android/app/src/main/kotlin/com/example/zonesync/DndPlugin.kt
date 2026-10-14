
package com.example.zonesync

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DndPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "zonesync/dnd"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setDndOn" -> {
                result.success(DndHelper.setDnd(context, true))
            }

            "setDndOff" -> {
                result.success(DndHelper.setDnd(context, false))
            }

            "hasDndAccess" -> {
                val manager = context.getSystemService(
                    Context.NOTIFICATION_SERVICE
                ) as android.app.NotificationManager
                result.success(manager.isNotificationPolicyAccessGranted)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
