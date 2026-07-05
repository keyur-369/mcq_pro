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
    // Workaround for older plugins (like flutter_windowmanager) missing a namespace
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val namespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                    val namespace = namespaceMethod.invoke(androidExt)
                    if (namespace == null) {
                        val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespaceMethod.invoke(androidExt, "com.example.${project.name.replace('-', '_')}")
                    }
                } catch (e: Exception) {
                    // Ignore exceptions
                }
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
