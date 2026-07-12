NEURON_SRC := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NEURON_INSTALL_DIR ?= /home/george/Games/AscensionLinux/resources/client/Interface/AddOns/Neuron

# Core Neuron install excludes LoD companion (shipped as sibling AddOn).
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
	--exclude='Neuron_GUI'

VERSION := $(shell grep '^## Version:' Neuron.toc | sed 's/.*: //')
ADDON_NAME := Neuron
GUI_SRC := $(NEURON_SRC)/Neuron_GUI
DIST_DIR := dist
DIST_NAME := $(ADDON_NAME)-$(VERSION)
STAGING := $(DIST_DIR)/$(ADDON_NAME)
STAGING_GUI := $(DIST_DIR)/Neuron_GUI

.PHONY: all install symlink watch clean package version

all: install

version:
	@echo $(VERSION)

package:
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(STAGING)" "$(STAGING_GUI)"
	rsync -a $(RSYNC_EXCLUDES) "$(NEURON_SRC)/" "$(STAGING)/"
	rsync -a --exclude='.git' "$(GUI_SRC)/" "$(STAGING_GUI)/"
	@cd "$(DIST_DIR)" && zip -qr "$(DIST_NAME).zip" "$(ADDON_NAME)" Neuron_GUI
	@echo "Created $(DIST_DIR)/$(DIST_NAME).zip (Neuron + Neuron_GUI)"
	@echo "Install: unzip into World of Warcraft/Interface/AddOns/"

install:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(NEURON_INSTALL_DIR)"
	@mkdir -p "$(dir $(NEURON_INSTALL_DIR))/Neuron_GUI"
	rsync -a --delete $(RSYNC_EXCLUDES) "$(NEURON_SRC)/" "$(NEURON_INSTALL_DIR)/"
	rsync -a --delete --exclude='.git' "$(GUI_SRC)/" "$(dir $(NEURON_INSTALL_DIR))/Neuron_GUI/"
	@echo "Installed Neuron to $(NEURON_INSTALL_DIR)"
	@echo "Installed Neuron_GUI to $(dir $(NEURON_INSTALL_DIR))/Neuron_GUI"

symlink:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(dir $(NEURON_INSTALL_DIR))"
	@ln -sfn "$(NEURON_SRC)" "$(NEURON_INSTALL_DIR)"
	@ln -sfn "$(GUI_SRC)" "$(dir $(NEURON_INSTALL_DIR))/Neuron_GUI"
	@echo "Symlinked $(NEURON_INSTALL_DIR) -> $(NEURON_SRC)"
	@echo "Symlinked Neuron_GUI -> $(GUI_SRC)"

watch:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@$(MAKE) install
	@echo "Watching $(NEURON_SRC) for changes..."
	@while inotifywait -r -e modify,create,delete,move \
		--exclude '(\.git|dist|\.idea|\.libcache)' \
		"$(NEURON_SRC)" >/dev/null; do \
		$(MAKE) install; \
	done

clean:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@if [ -L "$(NEURON_INSTALL_DIR)" ]; then \
		rm "$(NEURON_INSTALL_DIR)"; \
		echo "Removed symlink $(NEURON_INSTALL_DIR)"; \
	elif [ -d "$(NEURON_INSTALL_DIR)" ]; then \
		rm -rf "$(NEURON_INSTALL_DIR)"; \
		echo "Removed $(NEURON_INSTALL_DIR)"; \
	else \
		echo "Nothing to clean at $(NEURON_INSTALL_DIR)"; \
	fi
	@GUI_INSTALL="$(dir $(NEURON_INSTALL_DIR))/Neuron_GUI"; \
	if [ -L "$$GUI_INSTALL" ]; then rm "$$GUI_INSTALL"; \
	elif [ -d "$$GUI_INSTALL" ]; then rm -rf "$$GUI_INSTALL"; fi
