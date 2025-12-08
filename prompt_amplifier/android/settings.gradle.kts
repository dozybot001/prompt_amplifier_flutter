pluginManagement {
    val flutterSdkPath = try {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
    } catch (e: Exception) {
        null
    }

    val flutterPubCache = try {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.pub-cache")
    } catch (e: Exception) {
        null
    }

    repositories {
        // --- 这里强制优先使用阿里云 ---
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // ---------------------------
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS) // 关键：强制使用这里的配置
    repositories {
        // --- 这里也要加阿里云 ---
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // ---------------------
        google()
        mavenCentral()
    }
}

include(":app")