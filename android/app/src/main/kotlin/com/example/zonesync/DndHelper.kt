
package com.example.zonesync

import android.app.NotificationManager
import android.content.Context

object DndHelper {

    private const val PREFS_NAME = "zonesync_dnd_prefs"
    private const val KEY_PREVIOUS_FILTER = "previous_filter"
    private const val KEY_CHANGED_BY_APP = "changed_by_app"

    fun setDnd(context: Context, enabled: Boolean): Boolean {
        val manager = context.getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager

        if (!manager.isNotificationPolicyAccessGranted) {
            return false
        }

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        if (enabled) {
            // Save the original setting only when ZoneSync takes control.
            if (!prefs.getBoolean(KEY_CHANGED_BY_APP, false)) {
                val previousFilter = manager.currentInterruptionFilter

                if (previousFilter != NotificationManager.INTERRUPTION_FILTER_NONE) {
                    prefs.edit()
                        .putInt(KEY_PREVIOUS_FILTER, previousFilter)
                        .putBoolean(KEY_CHANGED_BY_APP, true)
                        .apply()

                    manager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_NONE
                    )
                }
            }
        } else {
            // Restore only if ZoneSync changed the setting.
            if (prefs.getBoolean(KEY_CHANGED_BY_APP, false)) {
                val previousFilter = prefs.getInt(
                    KEY_PREVIOUS_FILTER,
                    NotificationManager.INTERRUPTION_FILTER_ALL
                )

                manager.setInterruptionFilter(previousFilter)

                prefs.edit()
                    .putBoolean(KEY_CHANGED_BY_APP, false)
                    .remove(KEY_PREVIOUS_FILTER)
                    .apply()
            }
        }

        return true
    }
}
