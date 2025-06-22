@echo off
"C:\\Users\\Patricio Arias\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\cmake.exe" ^
  "-HC:\\src\\flutter\\packages\\flutter_tools\\gradle\\src\\main\\groovy" ^
  "-DCMAKE_SYSTEM_NAME=Android" ^
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ^
  "-DCMAKE_SYSTEM_VERSION=29" ^
  "-DANDROID_PLATFORM=android-29" ^
  "-DANDROID_ABI=x86_64" ^
  "-DCMAKE_ANDROID_ARCH_ABI=x86_64" ^
  "-DANDROID_NDK=C:\\Users\\Patricio Arias\\AppData\\Local\\Android\\sdk\\ndk\\27.0.12077973" ^
  "-DCMAKE_ANDROID_NDK=C:\\Users\\Patricio Arias\\AppData\\Local\\Android\\sdk\\ndk\\27.0.12077973" ^
  "-DCMAKE_TOOLCHAIN_FILE=C:\\Users\\Patricio Arias\\AppData\\Local\\Android\\sdk\\ndk\\27.0.12077973\\build\\cmake\\android.toolchain.cmake" ^
  "-DCMAKE_MAKE_PROGRAM=C:\\Users\\Patricio Arias\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\ninja.exe" ^
  "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=C:\\Users\\Patricio Arias\\Desktop\\controlgestion\\controlgestionagro\\android\\app\\build\\intermediates\\cxx\\Debug\\355m3c32\\obj\\x86_64" ^
  "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=C:\\Users\\Patricio Arias\\Desktop\\controlgestion\\controlgestionagro\\android\\app\\build\\intermediates\\cxx\\Debug\\355m3c32\\obj\\x86_64" ^
  "-DCMAKE_BUILD_TYPE=Debug" ^
  "-BC:\\Users\\Patricio Arias\\Desktop\\controlgestion\\controlgestionagro\\android\\app\\.cxx\\Debug\\355m3c32\\x86_64" ^
  -GNinja ^
  -Wno-dev ^
  --no-warn-unused-cli
