.PHONY: help build release clean run test install

help:
	@echo "Whale Build Commands:"
	@echo ""
	@echo "  make build       - Build debug version"
	@echo "  make release     - Build release version (dist/Whale.app, .dmg, .zip)"
	@echo "  make run         - Build and run debug version"
	@echo "  make test        - Run unit tests"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make install     - Install release to /Applications"
	@echo ""

build:
	@echo "🏗️  Building debug version..."
	@xcodebuild build \
		-project Whale.xcodeproj \
		-scheme Whale \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO

release:
	@./scripts/build-release.sh

run:
	@echo "🚀 Building and running..."
	@xcodebuild build \
		-project Whale.xcodeproj \
		-scheme Whale \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO && \
	open build/Build/Products/Debug/Whale.app

test:
	@echo "🧪 Running tests..."
	@xcodebuild test \
		-project Whale.xcodeproj \
		-scheme Whale \
		-destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO

clean:
	@echo "🧹 Cleaning..."
	@rm -rf build/
	@rm -rf dist/
	@rm -rf DerivedData/
	@echo "✅ Clean complete"

install:
	@if [ ! -d "dist/Whale.app" ]; then \
		echo "❌ No release build found. Run 'make release' first."; \
		exit 1; \
	fi
	@echo "📦 Installing to /Applications..."
	@sudo cp -R dist/Whale.app /Applications/
	@echo "✅ Installed to /Applications/Whale.app"
