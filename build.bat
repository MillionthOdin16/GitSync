@echo off
setlocal enabledelayedexpansion

REM GitSync Build Script for Windows
REM This script attempts to build the app in release mode first,
REM and falls back to debug mode if the release build fails.

REM Variables
set "FLUTTER_CMD="
set "CLEAN_BUILD=false"
set "FORCE_DEBUG=false"

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :setup
if "%~1"=="--clean" (
    set "CLEAN_BUILD=true"
    shift
    goto :parse_args
)
if "%~1"=="--debug" (
    set "FORCE_DEBUG=true"
    shift
    goto :parse_args
)
if "%~1"=="--help" goto :help
if "%~1"=="-h" goto :help
echo [ERROR] Unknown option: %~1
exit /b 1

:help
echo Usage: %0 [options]
echo Options:
echo   --clean    Clean build artifacts before building
echo   --debug    Force debug build (skip release attempt)
echo   --help     Show this help message
exit /b 0

:setup
echo [INFO] Starting GitSync build process...

REM Check if FVM is available
where fvm >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Using FVM to manage Flutter version...
    fvm flutter --version >nul 2>&1
    if !errorlevel! neq 0 (
        echo [WARNING] FVM Flutter not properly configured, installing...
        fvm install
    )
    set "FLUTTER_CMD=fvm flutter"
) else (
    REM Check if Flutter is available
    where flutter >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO] Using system Flutter...
        set "FLUTTER_CMD=flutter"
    ) else (
        echo [ERROR] Neither FVM nor Flutter found. Please install Flutter or FVM.
        exit /b 1
    )
)

REM Verify Flutter installation
echo [INFO] Flutter version:
%FLUTTER_CMD% --version

REM Clean if requested
if "%CLEAN_BUILD%"=="true" (
    echo [INFO] Cleaning build artifacts...
    %FLUTTER_CMD% clean
    
    REM Clean Rust build if cargo is available
    where cargo >nul 2>&1
    if !errorlevel! equ 0 (
        if exist "rust" (
            echo [INFO] Cleaning Rust build artifacts...
            pushd rust
            cargo clean
            popd
        )
    )
)

REM Install dependencies
echo [INFO] Installing Flutter dependencies...
%FLUTTER_CMD% pub get

REM Install Rust dependencies if needed
where cargo >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Installing Rust dependencies...
    where flutter_rust_bridge_codegen >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO] flutter_rust_bridge_codegen already installed
    ) else (
        echo [WARNING] flutter_rust_bridge_codegen not found, attempting to install...
        cargo install flutter_rust_bridge_codegen
    )
    
    REM Generate Rust bridge code
    where flutter_rust_bridge_codegen >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO] Generating Rust bridge code...
        flutter_rust_bridge_codegen generate
    ) else (
        echo [WARNING] Skipping Rust bridge generation - flutter_rust_bridge_codegen not available
    )
) else (
    echo [WARNING] Cargo not found, skipping Rust setup
)

REM Build process
if "%FORCE_DEBUG%"=="true" (
    echo [INFO] Forcing debug build as requested...
    %FLUTTER_CMD% build apk --debug
    if !errorlevel! equ 0 (
        echo [SUCCESS] Debug build completed successfully!
    ) else (
        echo [ERROR] Debug build failed!
        exit /b 1
    )
) else (
    REM Try release build first
    echo [INFO] Attempting release build...
    %FLUTTER_CMD% build apk --release --split-per-abi
    if !errorlevel! equ 0 (
        echo [SUCCESS] Release build completed successfully!
        echo [INFO] APK files should be available in: build\app\outputs\flutter-apk\
    ) else (
        echo [WARNING] Release build failed, falling back to debug build...
        %FLUTTER_CMD% build apk --debug
        if !errorlevel! equ 0 (
            echo [SUCCESS] Debug build completed successfully!
            echo [INFO] Debug APK available in: build\app\outputs\flutter-apk\
        ) else (
            echo [ERROR] Both release and debug builds failed!
            exit /b 1
        )
    )
)

REM Show build outputs
if exist "build\app\outputs\flutter-apk" (
    echo [INFO] Generated APK files:
    dir /b "build\app\outputs\flutter-apk\*.apk" 2>nul || echo [WARNING] No APK files found
)

echo [SUCCESS] Build process completed!
exit /b 0