SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

LATEST_ISO := $(shell ls -t release/*.iso 2>/dev/null | head -n1)
LATEST_MASTER_ISO := $(shell ls -t release/*x86_64-master.iso 2>/dev/null | head -n1)

ISO ?= $(LATEST_ISO)
VERSION ?=
LOCAL ?= 0
NO_CACHE ?= 0
NO_BOOT_OFFER ?= 0
REUSE ?= 0

BUILD_FLAGS :=
ifeq ($(NO_CACHE),1)
BUILD_FLAGS += --no-cache
endif
ifeq ($(NO_BOOT_OFFER),1)
BUILD_FLAGS += --no-boot-offer
endif
ifeq ($(LOCAL),1)
BUILD_FLAGS += --local-source
endif

.PHONY: help doctor list-isos latest latest-master build build-local boot boot-reuse sign upload release release-no-make rclone-config vm

help: ## Show available targets and common variables
	@printf "\nLeenium ISO Makefile\n\n"
	@printf "Usage:\n"
	@printf "  make <target> [VAR=value]\n\n"
	@printf "Common variables:\n"
	@printf "  ISO=%s\n" "$(if $(ISO),$(ISO),release/<iso-name>.iso)"
	@printf "  VERSION=%s\n" "$(if $(VERSION),$(VERSION),2026.03.20)"
	@printf "  LOCAL=1           Build against LEENIUM_PATH via --local-source\n"
	@printf "  NO_CACHE=1        Disable the daily package cache\n"
	@printf "  NO_BOOT_OFFER=1   Skip the post-build boot prompt\n"
	@printf "  REUSE=1           Reuse the existing VM disk for boot\n\n"
	@printf "Targets:\n"
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf "\nExamples:\n"
	@printf "  make build\n"
	@printf "  make build NO_CACHE=1 NO_BOOT_OFFER=1\n"
	@printf "  make build-local LEENIUM_PATH=/path/to/installer\n"
	@printf "  make boot ISO=release/leenium-2026.03.19-x86_64-master.iso REUSE=1\n"
	@printf "  make sign ISO=release/leenium-2026.03.19-x86_64-master.iso\n"
	@printf "  make release VERSION=2026.03.20\n\n"

doctor: ## Print tooling and path information used by the workflow
	@printf "repo:                %s\n" "$(CURDIR)"
	@printf "latest iso:          %s\n" "$(if $(LATEST_ISO),$(LATEST_ISO),<none>)"
	@printf "latest master iso:   %s\n" "$(if $(LATEST_MASTER_ISO),$(LATEST_MASTER_ISO),<none>)"
	@printf "docker:              %s\n" "$$(command -v docker || echo missing)"
	@printf "git:                 %s\n" "$$(command -v git || echo missing)"
	@printf "gum:                 %s\n" "$$(command -v gum || echo missing)"
	@printf "qemu-system-x86_64:  %s\n" "$$(command -v qemu-system-x86_64 || echo missing)"
	@printf "rclone:              %s\n" "$$(command -v rclone || echo missing)"
	@printf "LEENIUM_PATH:        %s\n" "$${LEENIUM_PATH:-<unset>}"
	@printf "LEENIUM_INSTALLER_REPO: %s\n" "$${LEENIUM_INSTALLER_REPO:-<default>}"
	@printf "LEENIUM_INSTALLER_REF:  %s\n" "$${LEENIUM_INSTALLER_REF:-master}"

list-isos: ## List built ISOs in release/ from newest to oldest
	@ls -1t release/*.iso 2>/dev/null || { echo "No ISOs found in release/"; exit 1; }

latest: ## Print the newest ISO path
	@printf "%s\n" "$(if $(LATEST_ISO),$(LATEST_ISO),)"
	@test -n "$(LATEST_ISO)" || { echo "No ISOs found in release/"; exit 1; }

latest-master: ## Print the newest master ISO path
	@printf "%s\n" "$(if $(LATEST_MASTER_ISO),$(LATEST_MASTER_ISO),)"
	@test -n "$(LATEST_MASTER_ISO)" || { echo "No master ISO found in release/"; exit 1; }

build: ## Build the ISO with optional LOCAL=1, NO_CACHE=1, and NO_BOOT_OFFER=1
	./bin/leenium-iso-make $(BUILD_FLAGS)

build-local: ## Build against a local installer checkout; requires LEENIUM_PATH
	$(MAKE) build LOCAL=1 $(if $(filter 1,$(NO_CACHE)),NO_CACHE=1,) $(if $(filter 1,$(NO_BOOT_OFFER)),NO_BOOT_OFFER=1,)

boot: ## Boot ISO=<path>; defaults to the newest ISO, set REUSE=1 to keep VM disk
	@test -n "$(ISO)" || { echo "Set ISO=<path> or build an ISO first."; exit 1; }
	./bin/leenium-iso-boot "$(ISO)" $(if $(filter 1,$(REUSE)),reuse,)

boot-reuse: ## Boot the newest ISO and reuse the existing VM disk
	$(MAKE) boot REUSE=1

sign: ## Sign ISO=<path>; defaults to the newest ISO
	@test -n "$(ISO)" || { echo "Set ISO=<path> or build an ISO first."; exit 1; }
	./bin/leenium-iso-sign "$(ISO)"

upload: ## Upload ISO=<path>; defaults to the newest ISO
	@test -n "$(ISO)" || { echo "Set ISO=<path> or build an ISO first."; exit 1; }
	./bin/leenium-iso-upload "$(ISO)"

release: ## Build, sign, and upload a release; requires VERSION=<release-version>
	@test -n "$(VERSION)" || { echo "Set VERSION=<release-version>"; exit 1; }
	./bin/leenium-iso-release "$(VERSION)"

release-no-make: ## Sign and upload using the newest master ISO copy; requires VERSION=<release-version>
	@test -n "$(VERSION)" || { echo "Set VERSION=<release-version>"; exit 1; }
	./bin/leenium-iso-release --no-make "$(VERSION)"

rclone-config: ## Open the helper for configuring rclone
	./bin/leenium-iso-rclone-config

vm: ## Run the general Leenium VM helper
	./bin/leenium-vm
