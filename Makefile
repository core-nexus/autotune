SHELL := /usr/bin/env bash

SCRIPTS_DIR := scripts
SCRIPTS := $(wildcard $(SCRIPTS_DIR)/*.sh) $(wildcard $(SCRIPTS_DIR)/lib/*.sh)
BATS_FILES := $(wildcard test/*.bats)

.PHONY: help test lint shellcheck bats check

help:
	@echo "Targets:"
	@echo "  make lint        Run shellcheck (with -x to follow sourced libs)"
	@echo "  make test        Run the bats suite under test/"
	@echo "  make check       Lint + test (CI entry point)"

lint shellcheck:
	@cd $(SCRIPTS_DIR) && shellcheck -x $(notdir $(filter $(SCRIPTS_DIR)/%.sh,$(wildcard $(SCRIPTS_DIR)/*.sh)))

test bats:
	@bats $(BATS_FILES)

check: lint test
