# Maclippy — common CLI actions.
# Day-to-day dev is Xcode (⌘R); CI runs xcodebuild/swiftlint directly.

PROJECT      := Maclippy.xcodeproj
SCHEME       := Maclippy
CONFIG       := Debug
DERIVED_DATA := build
APP          := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Maclippy.app
RELEASE_APP  := $(DERIVED_DATA)/Build/Products/Release/Maclippy.app
INSTALL_DIR  := $(HOME)/Applications

.PHONY: help build check release run lint install clean open inc-ver

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[1m%-9s\033[0m %s\n", $$1, $$2}'

build: ## Build (Debug, ad-hoc signed)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) -destination 'platform=macOS' build

check: ## Run Reformat over docs/fixtures and report diffs
	@swiftc -O -parse-as-library -o $(DERIVED_DATA)/reformat-check \
		$(wildcard Maclippy/Support/Reformat*.swift) \
		Tools/reformat-check.swift
	@$(DERIVED_DATA)/reformat-check

release: CONFIG := Release
release: build ## Build (Release, ad-hoc signed)

run: build ## Build, then launch (appears in the menu bar)
	open $(APP)

install: release ## Build Release, replace ~/Applications copy, relaunch
	@# Ask only if it is running: `tell application ... to quit` launches the app
	@# in order to quit it, which leaves a process behind when it was not running.
	@pgrep -x Maclippy >/dev/null && osascript -e 'tell application "Maclippy" to quit' || true
	@# Swapping the bundle while the old process tears down makes the relaunch
	@# fail with LaunchServices -600, so wait for the exit and force it if late.
	@for _ in $$(seq 1 50); do \
		pgrep -x Maclippy >/dev/null || break; \
		sleep 0.1; \
	done; \
	pkill -x Maclippy 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/Maclippy.app"
	cp -R "$(RELEASE_APP)" "$(INSTALL_DIR)/Maclippy.app"
	open "$(INSTALL_DIR)/Maclippy.app"
	@echo "Installed and launched $(INSTALL_DIR)/Maclippy.app"

lint: ## Run SwiftLint --strict (brew install swiftlint)
	@command -v swiftlint >/dev/null && swiftlint lint --strict || \
		echo "swiftlint not installed — run: brew install swiftlint"

clean: ## Remove build artifacts
	rm -rf $(DERIVED_DATA)

inc-ver: ## Bump CURRENT_PROJECT_VERSION (build number) by 1
	agvtool next-version

open: ## Open the project in Xcode
	open $(PROJECT)
