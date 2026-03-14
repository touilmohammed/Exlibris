# Exlibris Project Guidelines

## Build / Lint / Test Commands

| Task | Command | Notes |
|------|---------|-------|
| Install dependencies | `pip install -r exlibris_api/requirements.txt` | Run from project root. |
| Lint Python code | `flake8 exlibris_api/` | Enforces PEP‑8 and custom rules. |
| Format code | `black exlibris_api/` | Keeps formatting consistent. |
| Run all tests | `pytest -q` | Executes tests in `exlibris_api/tests/` if present. |
| Run a single test | `pytest -q path/to/test_file.py::TestClass::test_method` | Replace with actual path and names. |
| Check type hints | `mypy exlibris_api/` | Ensures static typing correctness. |
| Run Docker build (if applicable) | `docker compose up --build` | Builds the API and app containers. |
| Run Docker container tests | `docker compose run --rm api pytest -q` | Execute tests inside the API service container. |
| Lint Dockerfiles | `hadolint Dockerfile` | Ensure best practices for container images. |
| Check security vulnerabilities | `bandit -r exlibris_api/` | Scan for common Python security issues. |

## Code Style Guidelines

### Imports
- Import from standard library first, then third‑party, finally local modules.
- Use absolute imports; avoid relative ones unless for subpackages.
- Keep import block sorted alphabetically and grouped by the rule above.

### Formatting
- Use `black` with line‑length 88 (default). No manual line breaks.
- Docstrings use Google style or reST; include short description, parameters, return type.

### Types & Typing
- All public functions and classes must have explicit type hints.
- Prefer `typing.Protocol` for interfaces; use `TypedDict` for dict structures.
- Avoid `Any`; if unavoidable, document the reason.

### Naming Conventions
- Modules: snake_case.py
- Classes: CamelCase
- Functions/Methods: snake_case
- Constants: UPPER_SNAKE_CASE
- Variables: snake_case, avoid single‑letter names except in comprehensions.

### Error Handling
- Raise custom exceptions derived from `Exception` for domain errors.
- Use `try/except` sparingly; surface errors to callers unless you can recover.
- Log errors with `logging.getLogger(__name__)` before re‑raising.

### Logging
- Configure a root logger in `main.py` with `logging.basicConfig(level=logging.INFO)`.
- Use structured logging where possible; include request IDs for tracing.

### Testing
- Tests live in `exlibris_api/tests/` mirroring package structure.
- Use fixtures for common setup; keep tests deterministic.
- Avoid hard‑coded file paths; use `tempfile` or pytest's `tmp_path`.
- Run tests with coverage: `pytest --cov=exlibris_api -q`.

### Documentation
- Generate API docs with `sphinx-build -b html docs/ _build/html`.
- Keep README up‑to‑date with installation and usage examples.

## Cursor Rules (if any)
- None found in `.cursor/rules/`.

## Copilot Instructions
- See `.github/copilot-instructions.md` if present. If not, default to:
  ```markdown
  # Copilot Guidance for Exlibris
  - Suggest type hints for new functions.
  - Prefer `black` compatible formatting.
  - Avoid generating code that writes to the filesystem without confirmation.
  ```

## Miscellaneous
- Keep `__init__.py` files minimal; expose only public API.
- Use environment variables via `.env.local`; load with `python-dotenv` in main.
- Commit messages should follow the Conventional Commits style.
- Ensure CI pipeline runs `pytest`, `flake8`, and `mypy` on every push.
- Add a pre‑commit hook to run black, flake8, and mypy automatically.
- Use `tox` for multi‑Python version testing if needed.

---

**End of AGENTS.md**