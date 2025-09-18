# GitSync Makefile
# Provides convenient targets for building the app

.PHONY: help build build-release build-debug clean setup install-deps test lint format

# Default target
help:
	@echo "GitSync Build Targets:"
	@echo "  build         - Build app (tries release, falls back to debug)"
	@echo "  build-release - Build app in release mode only"
	@echo "  build-debug   - Build app in debug mode only"
	@echo "  clean         - Clean build artifacts"
	@echo "  setup         - Setup development environment"
	@echo "  install-deps  - Install dependencies"
	@echo "  test          - Run tests"
	@echo "  lint          - Run linter"
	@echo "  format        - Format code"

# Detect platform
UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
    BUILD_SCRIPT = ./build.sh
endif
ifeq ($(UNAME),Darwin)
    BUILD_SCRIPT = ./build.sh
endif
ifeq ($(OS),Windows_NT)
    BUILD_SCRIPT = build.bat
endif

# Check if FVM or Flutter is available
FLUTTER_CMD := $(shell command -v fvm >/dev/null 2>&1 && echo "fvm flutter" || echo "flutter")

# Main build target - implements the requirement
build:
	@echo "Running build script with fallback to debug..."
	$(BUILD_SCRIPT)

# Build release only
build-release:
	@echo "Building release version..."
	$(FLUTTER_CMD) build apk --release --split-per-abi

# Build debug only
build-debug:
	@echo "Building debug version..."
	$(FLUTTER_CMD) build apk --debug

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(BUILD_SCRIPT) --clean

# Setup development environment
setup:
	@echo "Setting up development environment..."
	@command -v fvm >/dev/null 2>&1 || (echo "FVM not found, please install it"; exit 1)
	fvm install
	fvm flutter pub get
	@command -v cargo >/dev/null 2>&1 && (cargo install flutter_rust_bridge_codegen || echo "Warning: Failed to install flutter_rust_bridge_codegen") || echo "Cargo not found, skipping Rust setup"

# Install dependencies
install-deps:
	@echo "Installing dependencies..."
	$(FLUTTER_CMD) pub get
	@command -v flutter_rust_bridge_codegen >/dev/null 2>&1 && flutter_rust_bridge_codegen generate || echo "Skipping Rust bridge generation"

# Run tests
test:
	@echo "Running tests..."
	$(FLUTTER_CMD) test

# Run linter
lint:
	@echo "Running linter..."
	$(FLUTTER_CMD) analyze

# Format code
format:
	@echo "Formatting code..."
	$(FLUTTER_CMD) format lib/ test/