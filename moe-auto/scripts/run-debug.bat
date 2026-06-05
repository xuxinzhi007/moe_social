@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0.."

if not exist local.properties (
  if defined ANDROID_HOME (
    set "SDK_DIR=!ANDROID_HOME!"
  ) else if exist "%LOCALAPPDATA%\Android\Sdk" (
    set "SDK_DIR=%LOCALAPPDATA%\Android\Sdk"
  ) else (
    echo Copy local.properties.example to local.properties and set sdk.dir
    exit /b 1
  )
  set "SDK_DIR=!SDK_DIR:\=/!"
  echo sdk.dir=!SDK_DIR!> local.properties
  echo Created local.properties -^> !SDK_DIR!
)

echo ==^> Unit tests
call gradlew.bat :app:testDebugUnitTest --no-daemon
if errorlevel 1 exit /b 1

echo ==^> Build Debug APK
call gradlew.bat :app:assembleDebug --no-daemon
if errorlevel 1 exit /b 1

set "ADB="
if defined ANDROID_HOME set "ADB=!ANDROID_HOME!\platform-tools\adb.exe"
if not exist "!ADB!" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "!ADB!" where adb >nul 2>&1 && set "ADB=adb"

if not exist "!ADB!" (
  echo adb not found. APK built:
  echo   app\build\outputs\apk\debug\app-debug.apk
  exit /b 0
)

"!ADB!" devices | findstr /R "device$" >nul
if errorlevel 1 (
  echo No device connected. APK built:
  echo   app\build\outputs\apk\debug\app-debug.apk
  exit /b 0
)

echo ==^> Install
call gradlew.bat :app:installDebug --no-daemon
if errorlevel 1 exit /b 1

echo ==^> Launch
"!ADB!" shell am start -n com.moe.auto/.MainActivity

echo.
echo Enable Moe Auto accessibility on phone, then run a script in the app.
endlocal
