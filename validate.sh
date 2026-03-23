#!/usr/bin/env bash
# validate.sh  -  Validate all compose stacks render without errors

set -euo pipefail

ENVS=("dev" "ci" "prod")
PROJECTS=("repo-api-service" "repo-frontend" "repo-worker")
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOCKER_CONFIG="$ROOT_DIR/.docker-config"
mkdir -p "$DOCKER_CONFIG"

ENV_FILES=(
  "--env-file" "$ROOT_DIR/infra-base/env/.env.base"
  "--env-file" "$ROOT_DIR/infra-base/env/.env.networking"
)

if [[ -f "$ROOT_DIR/infra-base/env/.env.secrets" ]]; then
  ENV_FILES+=("--env-file" "$ROOT_DIR/infra-base/env/.env.secrets")
fi

echo "Validating all compose stacks..."
echo ""

ERRORS=0

for project in "${PROJECTS[@]}"; do
  PROJECT_DIR="$ROOT_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project - directory not found"
    continue
  fi

  for env in "${ENVS[@]}"; do
    OVERRIDE="$PROJECT_DIR/docker-compose.${env}.yml"
    BASE="$PROJECT_DIR/docker-compose.yml"

    if [[ ! -f "$OVERRIDE" ]]; then
      continue
    fi

    echo -n "  [$project] ENV=$env -> "

    if docker compose \
        "${ENV_FILES[@]}" \
        -f "$BASE" \
        -f "$OVERRIDE" \
        --project-directory "$PROJECT_DIR" \
        config --quiet 2>&1; then
      echo "OK"
    else
      echo "FAILED"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "$ERRORS stack(s) failed validation."
  exit 1
else
  echo "All stacks valid."
fi
