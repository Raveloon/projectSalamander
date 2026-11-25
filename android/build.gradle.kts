allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val project = this
    
    project.plugins.withId("com.android.library") {
        val extension = project.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
        if (extension != null) {
            if (extension.namespace == null) {
                extension.namespace = when (project.name) {
                    "ar_flutter_plugin" -> "io.carius.lars.ar_flutter_plugin"
                    else -> "com.projectsalamander.fix.${project.name.replace("-", "_")}"
                }
            }
            extension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }

    project.tasks.configureEach {
        if (name.startsWith("process") && name.endsWith("Manifest")) {
            doFirst {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=")) {
                        manifestFile.writeText(content.replace(Regex("""package="[a-zA-Z0-9._]+""""), ""))
                    }
                }
            }
        }
    }

    project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(file("../build"))
}