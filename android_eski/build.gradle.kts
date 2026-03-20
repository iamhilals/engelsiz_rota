allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    // Android Studio ve Flutter'ın en güncel standart sürümleri:
    id("com.android.application") version "8.1.0" apply false
    id("com.android.library") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    
    // Firebase bağlantısını sağlayan ana eklenti:
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// Projenin derleme klasörlerini yöneten kısım (Buralara dokunmuyoruz):
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}