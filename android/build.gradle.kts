import com.android.build.gradle.BaseExtension
import org.gradle.api.JavaVersion
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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

// 插件子工程仍写 Java 8 时会触发「源值/目标值 8 已过时」；统一到 17 与 app 模块一致。
// 必须放在 evaluationDependsOn(":app") 之前注册 afterEvaluate，否则部分子项目已评估完会报错。
subprojects {
    afterEvaluate {
        // AGP 8+ requires namespace for every Android module.
        // Older third-party plugins may miss it.
        // Fill only when missing, to keep explicitly configured modules untouched.
        extensions.findByName("android")?.let { androidExt ->
            val getter = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "setNamespace" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == String::class.java
            }
            val current = getter?.invoke(androidExt) as? String
            if (setter != null && current.isNullOrBlank()) {
                val fallbackNamespace = "moe.social.plugin.${project.name.replace('-', '_')}"
                setter.invoke(androidExt, fallbackNamespace)
            }
        }

        extensions.findByType<BaseExtension>()?.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
