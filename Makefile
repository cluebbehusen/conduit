.PHONY: lint format format-check build clean test

# Lint Swift files
lint:
	swiftlint lint --strict

# Format Swift files in place
format:
	swiftformat .

# Check formatting without modifying files
format-check:
	swiftformat . --lint

# Run both format and lint
check: format-check lint

# Build the project
build:
	xcodebuild -scheme conduit -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# Run tests
test:
	xcodebuild test -scheme conduit -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -only-testing:conduitTests

# Clean build artifacts
clean:
	xcodebuild clean -scheme conduit
	rm -rf ~/Library/Developer/Xcode/DerivedData/conduit-*
