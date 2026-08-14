# marcustack: orchestration layer for the personal-site stack.
# See doc/v01.md for the plan and doc/TODO.md for the PR queue.

# Default: list available recipes
default:
    @just --list

# Run the bats test suite
test:
    bats test/

# Lint shell scripts (extend paths as they appear)
lint:
    shellcheck scripts/lib/*.sh scripts/pipeline.sh

# Wipe build outputs and run history
clean:
    rm -rf _build/ runs/

# Deploy the gallery pipeline (not yet implemented)
deploy:
    @echo "deploy: not yet implemented. See doc/v01.md and doc/TODO.md."
    @exit 1
# Run the full pre-commit gate
check: lint test

# Install the pinned normpic release
install-normpic:
    uv tool install --force \
      "git+https://github.com/marcus-grant/normpic@$(grep -A2 '\[normpic\]' config.toml | grep version | cut -d'"' -f2)"

# Run the gallery pipeline
pipeline:
    bash scripts/pipeline.sh
