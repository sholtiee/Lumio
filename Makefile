export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
BUILD_DIR := build
APP := $(BUILD_DIR)/Build/Products/Debug/Lumio.app

.PHONY: project build test run release strings icon snapshots clean

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project Lumio.xcodeproj -scheme Lumio -configuration Debug -derivedDataPath $(BUILD_DIR) -quiet build

test: project
	xcodebuild -project Lumio.xcodeproj -scheme Lumio -derivedDataPath $(BUILD_DIR) -quiet test

run: build
	-pkill -x Lumio; sleep 1
	open $(APP)

release: project
	xcodebuild -project Lumio.xcodeproj -scheme Lumio -configuration Release -derivedDataPath $(BUILD_DIR) -quiet build
	@echo "→ $(BUILD_DIR)/Build/Products/Release/Lumio.app"

# Regenerate Localizable.xcstrings from the last build's extracted keys + scripts/ru.json.
strings: build
	python3 scripts/make-strings.py

icon:
	swift scripts/make-icon.swift

# Renders the menu bar panel and Settings (light/dark) to build/snapshots for UI review.
snapshots: build
	-pkill -x Lumio; sleep 1
	LUMIO_SNAPSHOT_DIR=$(CURDIR)/build/snapshots $(APP)/Contents/MacOS/Lumio
	@echo "→ build/snapshots"

clean:
	rm -rf $(BUILD_DIR) Lumio.xcodeproj
