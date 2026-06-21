# tasks — developer task runner
# Zero third-party deps; standard library + bash only.

PYTHON ?= python3
TASKS  := ./tasks.py

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: ## Run the end-to-end test suite
	bash tests/test_tasks_e2e.sh

.PHONY: compile
compile: ## Byte-compile (syntax check)
	$(PYTHON) -m py_compile tasks.py

.PHONY: smoke
smoke: ## Quick functional smoke test in a temp dir
	@tmp=$$(mktemp -d); cp tasks.py $$tmp/; cd $$tmp; \
		$(PYTHON) tasks.py init >/dev/null; \
		$(PYTHON) tasks.py new feature "Smoke" --prio P1 >/dev/null; \
		$(PYTHON) tasks.py new task "Do thing" --under F-0001 >/dev/null; \
		$(PYTHON) tasks.py start T-0001 >/dev/null; \
		$(PYTHON) tasks.py done T-0001 >/dev/null; \
		$(PYTHON) tasks.py validate >/dev/null && echo "  smoke OK"; \
		rm -rf $$tmp

.PHONY: check
check: compile test ## Syntax check + full test suite (the gate)

.PHONY: version
version: ## Print the tool version
	@$(TASKS) version
