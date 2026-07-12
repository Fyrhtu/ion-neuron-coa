MACROFORGE_SRC := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MACROFORGE_INSTALL_DIR ?= /mnt/c/Ascension/Launcher/resources/ascension-live/Interface/AddOns/MacroForge

# Back-compat aliases for older env vars / docs
NEURON_SRC := $(MACROFORGE_SRC)
NEURON_INSTALL_DIR ?= $(MACROFORGE_INSTALL_DIR)

# Core MacroForge install excludes LoD companion (shipped as sibling AddOn).
RSYNC_EXCLUDES := \
	--exclude='.git' \
	--exclude='.github' \
	--exclude='.idea' \
	--exclude='.env' \
	--exclude='.libcache' \
	--exclude='.luarc.json' \
	--exclude='.push-batches' \
	--exclude='.push-text' \
	--exclude='dist' \
	--exclude='README.md' \
	--exclude='pkgmeta.yaml' \
	--exclude='LICENSE' \
	--exclude='shell.nix' \
	--exclude='Makefile' \
	--exclude='MacroForge_GUI'

VERSION := $(shell grep '^## Version:' MacroForge.toc | sed 's/.*: //')
ADDON_NAME := MacroForge
GUI_SRC := $(MACROFORGE_SRC)/MacroForge_GUI
DIST_DIR := dist
DIST_NAME := $(ADDON_NAME)-$(VERSION)
STAGING := $(DIST_DIR)/$(ADDON_NAME)
STAGING_GUI := $(DIST_DIR)/MacroForge_GUI

.PHONY: all install symlink watch clean package version

all: install

version:
	@echo $(VERSION)

package:
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(STAGING)" "$(STAGING_GUI)"
	rsync -a $(RSYNC_EXCLUDES) "$(MACROFORGE_SRC)/" "$(STAGING)/"
	rsync -a --exclude='.git' "$(GUI_SRC)/" "$(STAGING_GUI)/"
	@cd "$(DIST_DIR)" && zip -qr "$(DIST_NAME).zip" "$(ADDON_NAME)" MacroForge_GUI
	@echo "Created $(DIST_DIR)/$(DIST_NAME).zip (MacroForge + MacroForge_GUI)"
	@echo "Install: unzip into World of Warcraft/Interface/AddOns/"

install:
	@test -n "$(MACROFORGE_INSTALL_DIR)" || (echo "MACROFORGE_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(MACROFORGE_INSTALL_DIR)"
	@mkdir -p "$(dir $(MACROFORGE_INSTALL_DIR))/MacroForge_GUI"
	rsync -a --delete $(RSYNC_EXCLUDES) "$(MACROFORGE_SRC)/" "$(MACROFORGE_INSTALL_DIR)/"
	rsync -a --delete --exclude='.git' "$(GUI_SRC)/" "$(dir $(MACROFORGE_INSTALL_DIR))/MacroForge_GUI/"
	@echo "Installed MacroForge to $(MACROFORGE_INSTALL_DIR)"
	@echo "Installed MacroForge_GUI to $(dir $(MACROFORGE_INSTALL_DIR))/MacroForge_GUI"

symlink:
	@test -n "$(MACROFORGE_INSTALL_DIR)" || (echo "MACROFORGE_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(dir $(MACROFORGE_INSTALL_DIR))"
	@ln -sfn "$(MACROFORGE_SRC)" "$(MACROFORGE_INSTALL_DIR)"
	@ln -sfn "$(GUI_SRC)" "$(dir $(MACROFORGE_INSTALL_DIR))/MacroForge_GUI"
	@echo "Symlinked $(MACROFORGE_INSTALL_DIR) -> $(MACROFORGE_SRC)"
	@echo "Symlinked MacroForge_GUI -> $(GUI_SRC)"

watch:
	@test -n "$(MACROFORGE_INSTALL_DIR)" || (echo "MACROFORGE_INSTALL_DIR is not set" && exit 1)
	@$(MAKE) install
	@echo "Watching $(MACROFORGE_SRC) for changes..."
	@while inotifywait -r -e modify,create,delete,move \
		--exclude '(\.git|dist|\.idea|\.libcache)' \
		"$(MACROFORGE_SRC)" >/dev/null; do \
		$(MAKE) install; \
	done

clean:
	@test -n "$(MACROFORGE_INSTALL_DIR)" || (echo "MACROFORGE_INSTALL_DIR is not set" && exit 1)
	@if [ -L "$(MACROFORGE_INSTALL_DIR)" ]; then \
		rm "$(MACROFORGE_INSTALL_DIR)"; \
		echo "Removed symlink $(MACROFORGE_INSTALL_DIR)"; \
	elif [ -d "$(MACROFORGE_INSTALL_DIR)" ]; then \
		rm -rf "$(MACROFORGE_INSTALL_DIR)"; \
		echo "Removed $(MACROFORGE_INSTALL_DIR)"; \
	else \
		echo "Nothing to clean at $(MACROFORGE_INSTALL_DIR)"; \
	fi
	@GUI_INSTALL="$(dir $(MACROFORGE_INSTALL_DIR))/MacroForge_GUI"; \
	if [ -L "$$GUI_INSTALL" ]; then rm "$$GUI_INSTALL"; \
	elif [ -d "$$GUI_INSTALL" ]; then rm -rf "$$GUI_INSTALL"; fi
