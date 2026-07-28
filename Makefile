.PHONY: format lint test

format:
	uv run --locked ruff check --fix tests
	uv run --locked ruff format tests

lint:
	uv run --locked ruff format --check tests
	uv run --locked ruff check tests

test:
	uv run --locked pytest -n auto tests
