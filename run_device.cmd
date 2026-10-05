@echo off
set "TEMP=D:\temp"
set "TMP=D:\temp"
set "GRADLE_USER_HOME=D:\.gradle"
set "PATH=C:\Users\ARITRA~1\development\flutter\bin;%PATH%"
echo ==============================================
echo ORCUS ARMOURY FLUTTER RUNNER (HIGH PERFORMANCE)
echo Using TEMP=%TEMP%
echo Using GRADLE_USER_HOME=%GRADLE_USER_HOME%
echo ==============================================

if "%1"=="build" (
    if "%2"=="debug" (
        echo Building DEBUG APK...
        C:\Users\ARITRA~1\development\flutter\bin\flutter.bat build apk --debug --android-skip-build-dependency-validation
    ) else (
        echo Building RELEASE APK (AOT Optimized)...
        C:\Users\ARITRA~1\development\flutter\bin\flutter.bat build apk --release --android-skip-build-dependency-validation
    )
) else if "%1"=="debug" (
    echo Running in DEBUG (JIT) mode on physical device...
    C:\Users\ARITRA~1\development\flutter\bin\flutter.bat run -d 10a35497 --android-skip-build-dependency-validation
) else if "%1"=="profile" (
    echo Running in PROFILE mode for DevTools telemetry...
    C:\Users\ARITRA~1\development\flutter\bin\flutter.bat run --profile -d 10a35497 --android-skip-build-dependency-validation
) else (
    echo Running in RELEASE mode (Native AOT 60/120 FPS)...
    echo (Pass 'debug' as argument if you need Hot Reload: run_device.cmd debug)
    C:\Users\ARITRA~1\development\flutter\bin\flutter.bat run --release -d 10a35497 --android-skip-build-dependency-validation
)
