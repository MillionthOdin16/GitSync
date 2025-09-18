#!/bin/bash

# GitSync Build Script
# This script attempts to build the app in release mode first,
# and falls back to debug mode if the release build fails.

set -e  # Exit on any command failure initially

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to setup Flutter environment
setup_flutter() {
    log_info "Setting up Flutter environment..."
    
    # Check if FVM is available
    if command_exists fvm; then
        log_info "Using FVM to manage Flutter version..."
        if ! fvm flutter --version >/dev/null 2>&1; then
            log_warning "FVM Flutter not properly configured, installing..."
            fvm install
        fi
        FLUTTER_CMD="fvm flutter"
    elif command_exists flutter; then
        log_info "Using system Flutter..."
        FLUTTER_CMD="flutter"
    else
        log_error "Neither FVM nor Flutter found. Please install Flutter or FVM."
        exit 1
    fi
    
    # Verify Flutter installation
    log_info "Flutter version:"
    $FLUTTER_CMD --version
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing Flutter dependencies..."
    $FLUTTER_CMD pub get
    
    # Install Rust dependencies if needed
    if command_exists cargo; then
        log_info "Installing Rust dependencies..."
        if command_exists flutter_rust_bridge_codegen; then
            log_info "flutter_rust_bridge_codegen already installed"
        else
            log_warning "flutter_rust_bridge_codegen not found, attempting to install..."
            cargo install flutter_rust_bridge_codegen || log_warning "Failed to install flutter_rust_bridge_codegen"
        fi
        
        # Generate Rust bridge code
        if command_exists flutter_rust_bridge_codegen; then
            log_info "Generating Rust bridge code..."
            flutter_rust_bridge_codegen generate
        else
            log_warning "Skipping Rust bridge generation - flutter_rust_bridge_codegen not available"
        fi
    else
        log_warning "Cargo not found, skipping Rust setup"
    fi
}

# Function to attempt release build
try_release_build() {
    log_info "Attempting release build..."
    set +e  # Don't exit on error for this function
    
    # Try building release APK
    $FLUTTER_CMD build apk --release --split-per-abi
    local release_result=$?
    
    set -e  # Re-enable exit on error
    return $release_result
}

# Function to attempt debug build
try_debug_build() {
    log_info "Attempting debug build..."
    $FLUTTER_CMD build apk --debug
}

# Function to clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    $FLUTTER_CMD clean
    
    # Clean Rust build if cargo is available
    if command_exists cargo && [ -d "rust" ]; then
        log_info "Cleaning Rust build artifacts..."
        (cd rust && cargo clean) || log_warning "Failed to clean Rust artifacts"
    fi
}

# Main build function
main() {
    log_info "Starting GitSync build process..."
    
    # Parse command line arguments
    CLEAN_BUILD=false
    FORCE_DEBUG=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --debug)
                FORCE_DEBUG=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --clean    Clean build artifacts before building"
                echo "  --debug    Force debug build (skip release attempt)"
                echo "  --help     Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Clean if requested
    if [ "$CLEAN_BUILD" = true ]; then
        clean_build
    fi
    
    # Setup environment
    setup_flutter
    install_dependencies
    
    # Build process
    if [ "$FORCE_DEBUG" = true ]; then
        log_info "Forcing debug build as requested..."
        try_debug_build
        log_success "Debug build completed successfully!"
    else
        # Try release build first
        if try_release_build; then
            log_success "Release build completed successfully!"
            log_info "APK files should be available in: build/app/outputs/flutter-apk/"
        else
            log_warning "Release build failed, falling back to debug build..."
            try_debug_build
            log_success "Debug build completed successfully!"
            log_info "Debug APK available in: build/app/outputs/flutter-apk/"
        fi
    fi
    
    # Show build outputs
    if [ -d "build/app/outputs/flutter-apk" ]; then
        log_info "Generated APK files:"
        ls -la build/app/outputs/flutter-apk/*.apk 2>/dev/null || log_warning "No APK files found"
    fi
    
    log_success "Build process completed!"
}

# Run main function with all arguments
main "$@"