package com.example.sabi_wallet

import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // Set up working directory for Breez SDK before Flutter initializes
        // The FileProvider in AndroidManifest.xml + Breez file paths configuration
        // will handle the storage.sql location issue
        try {
            val appDir = getFilesDir().absolutePath
            val dir = File(appDir)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            System.setProperty("user.dir", appDir)
            println("✅ Breez SDK working directory configured: $appDir")
        } catch (e: Exception) {
            println("❌ Failed to set working directory: ${e.message}")
        }
        
        super.onCreate(savedInstanceState)
    }
    
    /**
     * Override onBackPressed to move app to background instead of killing it.
     * This keeps the app running and maintains wallet connections.
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Move task to back (minimize) instead of finishing the activity
        moveTaskToBack(true)
    }
}
