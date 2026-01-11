package com.gavra013.gavra_android

import android.app.Notification
import android.content.Context
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * NotificationListenerService koji sluša za dolazne notifikacije 
 * i pali ekran kada stigne push notifikacija od Gavra aplikacije.
 * 
 * NAPOMENA: Korisnik mora da odobri pristup notifikacijama u Settings!
 */
class GavraNotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "GavraNotificationListener"
        private const val GAVRA_PACKAGE = "com.gavra013.gavra_android"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        if (sbn == null) return
        
        // Reaguj samo na notifikacije od Gavra aplikacije
        if (sbn.packageName == GAVRA_PACKAGE) {
            Log.d(TAG, "📱 Gavra notification detected, waking screen...")
            wakeScreen()
        }
    }
    
    private fun wakeScreen() {
        try {
            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "gavra:notification_wake_lock"
            )
            
            // Wake screen for 10 seconds
            wakeLock.acquire(10 * 1000L)
            Log.d(TAG, "✅ Screen wake lock acquired for notification")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to wake screen: ${e.message}")
        }
    }
}
