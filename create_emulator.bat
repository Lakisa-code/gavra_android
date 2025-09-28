@echo off
rem create_emulator.bat - create and start an Android AVD (Windows cmd)
rem Usage: open cmd.exe, cd to project root, run create_emulator.bat

setlocal EnableDelayedExpansion

:: Try to read SDK path from android/local.properties if it exists
set "ANDROID_SDK_ROOT="
if exist "android\local.properties" (
  for /f "usebackq tokens=1* delims==" %%a in ("android\local.properties") do (
    if /I "%%a"=="sdk.dir" (
      set "tmp=%%b"
      rem Replace double backslashes with single backslashes (common in local.properties)
      set "tmp=!tmp:\=\!"
      set "ANDROID_SDK_ROOT=!tmp!"
    )
  )
)

:: Fallback to the previous hardcoded default if not found
if not defined ANDROID_SDK_ROOT (
  set "ANDROID_SDK_ROOT=C:\Android\Sdk"
)

:: Add common SDK tool paths for this session only
set "PATH=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin;%ANDROID_SDK_ROOT%\tools\bin;%ANDROID_SDK_ROOT%\platform-tools;%ANDROID_SDK_ROOT%\emulator;%PATH%"

echo Using ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%
echo.

echo === Locate sdkmanager ===
if exist "%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" (
  set "SDKMANAGER=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat"
) else if exist "%ANDROID_SDK_ROOT%\tools\bin\sdkmanager.bat" (
  set "SDKMANAGER=%ANDROID_SDK_ROOT%\tools\bin\sdkmanager.bat"
) else (
  echo ERROR: sdkmanager not found in "%ANDROID_SDK_ROOT%".
  echo Install Android SDK Command-line Tools (Android Studio -> SDK Manager -> SDK Tools -> "Android SDK Command-line Tools").
  pause
  exit /b 2
)

echo SDKMANAGER=%SDKMANAGER%
echo.

echo === Accept licenses (may prompt) ===
echo y | "%SDKMANAGER%" --licenses
echo.

echo === Install required packages (platform-tools, emulator, android-33, system image) ===
echo y | "%SDKMANAGER%" "platform-tools" "platforms;android-33" "emulator" "system-images;android-33;google_apis;x86_64"
echo.

echo === Locate avdmanager ===
if exist "%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\avdmanager.bat" (
  set "AVDMANAGER=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\avdmanager.bat"
) else if exist "%ANDROID_SDK_ROOT%\tools\bin\avdmanager.bat" (
  set "AVDMANAGER=%ANDROID_SDK_ROOT%\tools\bin\avdmanager.bat"
) else (
  echo ERROR: avdmanager not found in "%ANDROID_SDK_ROOT%".
  pause
  exit /b 3
)

echo AVDMANAGER=%AVDMANAGER%
echo.

echo === Create AVD Pixel_3a_API_33_x86_64 (force) ===
"%AVDMANAGER%" create avd -n Pixel_3a_API_33_x86_64 -k "system-images;android-33;google_apis;x86_64" -d "pixel_3a" --force
echo.

echo === List AVDs ===
if exist "%ANDROID_SDK_ROOT%\emulator\emulator.exe" (
  "%ANDROID_SDK_ROOT%\emulator\emulator.exe" -list-avds
) else (
  echo emulator not found in "%ANDROID_SDK_ROOT%\emulator".
)
echo.

echo === Start emulator (background) ===
if exist "%ANDROID_SDK_ROOT%\emulator\emulator.exe" (
  start "" "%ANDROID_SDK_ROOT%\emulator\emulator.exe" -avd Pixel_3a_API_33_x86_64 -netspeed full -netdelay none
) else (
  echo Cannot start emulator: emulator executable not found.
  pause
  exit /b 4
)
echo.

echo === Wait for emulator to appear in adb (up to ~1 minute) ===
set "FOUND=0"
for /L %%i in (1,1,12) do (
  "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" devices | findstr /R /C:"emulator-[0-9]*" >nul
  if not errorlevel 1 (
    set "FOUND=1"
    echo Emulator is online.
    goto :afteradb
  )
  echo Waiting for emulator... (%%i/12)
  timeout /t 5 /nobreak >nul
)
:afteradb
if "!FOUND!"=="1" (
  echo === adb devices ===
  "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" devices
  echo Emulator should be ready. You can run 'flutter devices' or 'adb shell' now.
) else (
  echo Emulator did not appear within the timeout. Check virtualization support (WHPX/VirtualMachinePlatform) and emulator logs.
  echo === adb devices (current) ===
  "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" devices
)

echo.
echo Done. Press any key to exit.
pause >nul
endlocal
exit /b 0
