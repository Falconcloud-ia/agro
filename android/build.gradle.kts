// build.gradle.kts – Archivo de nivel raíz para Android

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Estas líneas se deben colocar dentro del bloque de dependencies
        // y con la sintaxis de Kotlin DSL.
        // Si aún recibes "Unresolved reference: classpath", verifica que este archivo se
        // encuentre en la ruta "android/build.gradle.kts" y no en otro lugar.
        classpath("com.android.tools.build:gradle:8.1.1")
        classpath("com.google.gms:google-services:4.3.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
