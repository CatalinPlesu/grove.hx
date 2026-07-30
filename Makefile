SCHEMAT ?= schemat
# Schemat 0.5.3 cannot parse Steel's "\0" escape.
SCHEMAT_FLAGS = --ignore src/adapters/git/porcelain.scm --ignore src/domain/path.scm

.PHONY: format lint test

format:
	$(SCHEMAT) $(SCHEMAT_FLAGS) '**/*.scm'
	uv run --locked ruff check --fix tests
	uv run --locked ruff format tests

lint:
	$(SCHEMAT) --check $(SCHEMAT_FLAGS) '**/*.scm'
	uv run --locked ruff format --check tests
	uv run --locked ruff check tests

test:
	uv run --locked pytest -n auto tests
