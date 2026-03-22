allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build directory එක setup කිරීම
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
    
    // 🔥 1. Namespace සහ compileSdkVersion Fix කිරීම
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
            
            android.compileSdkVersion(34)
        }
    }

    // 🔥 2. අර Android 36 Error එක හදන (Force Downgrade) කෑල්ල Kotlin විදියට!
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.activity" && requested.name == "activity") {
                useVersion("1.9.3")
            }
            if (requested.group == "androidx.navigationevent" && requested.name == "navigationevent-android") {
                useVersion("1.0.0")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}