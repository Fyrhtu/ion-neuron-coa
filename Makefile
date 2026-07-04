NEURON_SRC := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NEURON_INSTALL_DIR ?= /home/george/Games/AscensionLinux/resources/client/Interface/AddOns/Neuron

RSYNC_EXCLUDES := \
	--exclude='.git' \
	--exclude='.github' \
	--exclude='.idea' \
	--exclude='.env' \
	--exclude='.libcache' \
	--exclude='.luarc.json' \
	--exclude='dist' \
	--exclude='README.md' \
	--exclude='pkgmeta.yaml' \
	--exclude='LICENSE' \
	--exclude='shell.nix' \
	--exclude='Makefile'

VERSION := $(shell grep '^## Version:' Neuron.toc | sed 's/.*: //')
ADDON_NAME := Neuron
DIST_DIR := dist
DIST_NAME := $(ADDON_NAME)-$(VERSION)
STAGING := $(DIST_DIR)/$(ADDON_NAME)

.PHONY: all install symlink watch clean package version

all: install

version:
	@echo $(VERSION)

package:
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(STAGING)"
	rsync -a $(RSYNC_EXCLUDES) "$(NEURON_SRC)/" "$(STAGING)/"
	@cd "$(DIST_DIR)" && zip -qr "$(DIST_NAME).zip" "$(ADDON_NAME)"
	@echo "Created $(DIST_DIR)/$(DIST_NAME).zip"
	@echo "Install: unzip into World of Warcraft/Interface/AddOns/"

install:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(NEURON_INSTALL_DIR)"
	rsync -a --delete $(RSYNC_EXCLUDES) "$(NEURON_SRC)/" "$(NEURON_INSTALL_DIR)/"
	@echo "Installed Neuron to $(NEURON_INSTALL_DIR)"

symlink:
	@test -n "$(NEURON_INSTALL_DIR)" || (echo "NEURON_INSTALL_DIR is not set" && exit 1)
	@mkdir -p "$(dir $(NEURON_INSTALL_DIR))"
	@ln -sfn "$(NEURON_SRC)" "$(NEURON_INSTALL_DIR)"
	@echo "Symlinked $(NEURON_INSTALL_DIR) -> $(NEURON_SRC)"

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