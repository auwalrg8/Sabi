// Init script to patch breez_sdk with missing Android config
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
}
