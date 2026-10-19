import org.gradle.api.JavaVersion
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Custom build dir relocation
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Put each module output inside the shared build dir
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (project.name != "app") {
        project.evaluationDependsOn(":app")

        afterEvaluate {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                val setNamespace = android.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 }
                if (getNamespace != null && setNamespace != null) {
                    val currentNamespace = getNamespace.invoke(android)
                    if (currentNamespace == null) {
                        setNamespace.invoke(android, "com.example.${project.name.replace("-", "_")}")
                    }
                }

                android.compileSdkVersion(35)
                android.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                android.compileOptions.targetCompatibility = JavaVersion.VERSION_17

                // Fix AGP 8 compatibility: remove legacy package="..." from dependency AndroidManifest.xml
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=")) {
                        val updatedContent = content.replace(Regex("""package="[^"]*""""), "")
                        manifestFile.writeText(updatedContent)
                    }
                }
            }
        }

        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_17)
            }
        }

        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}

// ✅ Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
