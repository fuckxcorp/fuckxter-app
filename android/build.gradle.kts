run {
    val pluginsFile = rootProject.file("../.flutter-plugins-dependencies")
    if (pluginsFile.exists()) {
        val paths = Regex(""""path"\s*:\s*"([^"]+)"""")
            .findAll(pluginsFile.readText())
            .map { it.groupValues[1] }
            .toSet()
        for (path in paths) {
            val gradleFile = file("$path/android/build.gradle")
            if (!gradleFile.exists()) continue
            val original = gradleFile.readText()
            var updated = Regex("""compileSdk(?:Version)?\s+(\d+)""").replace(original) { match ->
                val version = match.groupValues[1].toInt()
                if (version < 36) match.value.replace(match.groupValues[1], "36") else match.value
            }
            updated = updated.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
            updated = updated.replace("JavaVersion.VERSION_1_8", "JavaVersion.VERSION_17")
            if (!updated.contains("jvmTarget") && updated.contains("com.android.library")) {
                updated += """

tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}
"""
            }
            if (updated != original) gradleFile.writeText(updated)
            val javaDir = file("$path/android/src/main/java")
            if (javaDir.exists()) {
                javaDir.walkTopDown().forEach { source ->
                    if (source.isFile && source.name == "FlutterAvifPlugin.java") {
                        source.delete()
                    }
                }
            }
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
