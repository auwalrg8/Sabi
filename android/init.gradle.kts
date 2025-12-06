// Init script to patch breez_sdk and contacts_service with missing Android config
// Run this with: gradle --init-script=init.gradle.kts

settingsEvaluated { settings ->
    val breezProject = settings.findProject(":breez_sdk")
    if (breezProject != null) {
        breezProject.afterEvaluate { project ->
            project.extensions.configure(com.android.build.gradle.LibraryExtension::class) {
                compileSdk = 34
                namespace = "com.breez.sdk"
            }
        }
    }
    
    val contactsProject = settings.findProject(":contacts_service")
    if (contactsProject != null) {
        contactsProject.afterEvaluate { project ->
            try {
                project.extensions.configure(com.android.build.gradle.LibraryExtension::class) {
                    namespace = "com.example.contacts_service"
                }
            } catch (e: Exception) {
                println("Note: Could not configure contacts_service namespace")
            }
        }
    }
}
