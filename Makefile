ENV ?= dev
REPO ?= repo-api-service
PROJECT_NAME ?= $(REPO)
DOCKER_CONFIG_DIR := $(CURDIR)\.docker-config
INFRA_BASE_URL ?=
REPO_API_SERVICE_URL ?=
REPO_FRONTEND_URL ?=
REPO_WORKER_URL ?=

BASE_COMPOSE := $(REPO)/docker-compose.yml
ENV_COMPOSE := $(REPO)/docker-compose.$(ENV).yml
ENV_FILE_FLAGS := --env-file infra-base/env/.env.base --env-file infra-base/env/.env.networking
ifneq ($(wildcard infra-base/env/.env.secrets),)
ENV_FILE_FLAGS += --env-file infra-base/env/.env.secrets
endif

COMPOSE_FILES := -f $(BASE_COMPOSE)
ifneq ($(wildcard $(ENV_COMPOSE)),)
COMPOSE_FILES += -f $(ENV_COMPOSE)
endif

DOCKER := set DOCKER_CONFIG=$(DOCKER_CONFIG_DIR)&& docker
DC := $(DOCKER) compose $(ENV_FILE_FLAGS) --project-directory $(REPO) $(COMPOSE_FILES) -p $(PROJECT_NAME)-$(ENV)

.PHONY: help init clone-repos clone-infra-base clone-repo-api-service clone-repo-frontend clone-repo-worker setup run up run-fg stop down restart clear clean logs ps config validate pull build gitleaks
.PHONY: run-dev run-ci run-prod stop-dev stop-ci stop-prod clear-dev clear-ci clear-prod

help:
	@echo "Available targets:"
	@echo "  make init                 Clone repos, create local secrets file, and create shared Docker networks"
	@echo "  make clone-repos          Clone missing child repos when URLs are provided"
	@echo "  make setup                Prepare the local Docker environment"
	@echo "  make run                  Start the stack in detached mode (ENV=dev by default)"
	@echo "  make run-fg               Start the stack in the foreground"
	@echo "  make stop                 Stop and remove the stack"
	@echo "  make restart              Restart the stack"
	@echo "  make clear                Stop the stack and remove volumes/orphans"
	@echo "  make logs                 Follow container logs"
	@echo "  make ps                   Show running services"
	@echo "  make config               Render the merged compose config"
	@echo "  make validate             Validate the merged compose config"
	@echo "  make pull                 Pull the latest container images"
	@echo "  make build                Build images if the stack later adds build steps"
	@echo "  make gitleaks             Run a Dockerized gitleaks scan on the workspace files"
	@echo ""
	@echo "Environment-aware usage:"
	@echo "  make init INFRA_BASE_URL=<url> REPO_API_SERVICE_URL=<url>"
	@echo "  make run ENV=prod"
	@echo "  make run REPO=repo-frontend"
	@echo "  make stop ENV=ci"
	@echo "  make clear ENV=dev"

init: clone-repos
	@if not exist ".docker-config" mkdir ".docker-config"
	@if not exist "infra-base\env\.env.secrets" (if exist "infra-base\env\.env.secrets.example" (copy /Y "infra-base\env\.env.secrets.example" "infra-base\env\.env.secrets" >NUL && echo "Created infra-base\env\.env.secrets from example. Update it with real local secrets.") else (echo "Skipping local secrets file creation. Missing infra-base\env\.env.secrets.example."))
	-@$(DOCKER) network create app-network >NUL 2>&1
	-@$(DOCKER) network create monitoring-network >NUL 2>&1
	@echo "Shared Docker networks are ready."

clone-repos: clone-infra-base clone-repo-api-service clone-repo-frontend clone-repo-worker

clone-infra-base:
	@if exist "infra-base\\.git" (echo "infra-base already exists.") else (if "$(INFRA_BASE_URL)"=="" (echo "Skipping infra-base clone. Set INFRA_BASE_URL to enable it.") else (git clone "$(INFRA_BASE_URL)" infra-base))

clone-repo-api-service:
	@if exist "repo-api-service\\.git" (echo "repo-api-service already exists.") else (if "$(REPO_API_SERVICE_URL)"=="" (echo "Skipping repo-api-service clone. Set REPO_API_SERVICE_URL to enable it.") else (git clone "$(REPO_API_SERVICE_URL)" repo-api-service))

clone-repo-frontend:
	@if exist "repo-frontend\\.git" (echo "repo-frontend already exists.") else (if "$(REPO_FRONTEND_URL)"=="" (echo "Skipping repo-frontend clone. Set REPO_FRONTEND_URL to enable it.") else (git clone "$(REPO_FRONTEND_URL)" repo-frontend))

clone-repo-worker:
	@if exist "repo-worker\\.git" (echo "repo-worker already exists.") else (if "$(REPO_WORKER_URL)"=="" (echo "Skipping repo-worker clone. Set REPO_WORKER_URL to enable it.") else (git clone "$(REPO_WORKER_URL)" repo-worker))

setup: init
	@$(DOCKER) compose version >NUL
	@echo "Docker Compose is available."

run: setup
	$(DC) up -d

up: run

run-fg: setup
	$(DC) up

stop:
	$(DC) down

down: stop

restart:
	$(DC) restart

clear:
	$(DC) down --volumes --remove-orphans

clean: clear

logs:
	$(DC) logs -f

ps:
	$(DC) ps

config:
	$(DC) config

validate:
	$(DC) config --quiet

pull:
	$(DC) pull

build:
	$(DC) build

gitleaks:
	@$(DOCKER) run --rm -v "$(CURDIR):/repo" zricethezav/gitleaks:latest dir /repo --config /repo/.gitleaks.toml --no-banner

run-dev:
	@$(MAKE) run ENV=dev

run-ci:
	@$(MAKE) run ENV=ci

run-prod:
	@$(MAKE) run ENV=prod

stop-dev:
	@$(MAKE) stop ENV=dev

stop-ci:
	@$(MAKE) stop ENV=ci

stop-prod:
	@$(MAKE) stop ENV=prod

clear-dev:
	@$(MAKE) clear ENV=dev

clear-ci:
	@$(MAKE) clear ENV=ci

clear-prod:
	@$(MAKE) clear ENV=prod
