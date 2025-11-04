.PHONY: help build up down restart logs logs-app logs-bot logs-db ps shell-app shell-bot shell-db clean install-php install-node migrate fresh

YELLOW := \033[1;33m
GREEN  := \033[1;32m
RED    := \033[1;31m
NC     := \033[0m 

DOCKER := sudo docker compose

help:
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build:
	@echo "$(GREEN)Building containers...$(NC)"
	$(DOCKER) build

up:
	@echo "$(GREEN)Starting services...$(NC)"
	$(DOCKER) up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "PHP App: http://localhost:8080"
	@echo "WhatsApp Bot: http://localhost:3000"
	@echo "Caddy: http://localhost"

down:
	@echo "$(YELLOW)Stopping services...$(NC)"
	$(DOCKER) down

restart:
	@echo "$(YELLOW)Restarting services...$(NC)"
	$(DOCKER) restart

logs:
	$(DOCKER) logs -f

logs-app:
	$(DOCKER) logs -f app

logs-bot:
	$(DOCKER) logs -f whatsapp-bot

logs-db:
	$(DOCKER) logs -f db

ps:
	$(DOCKER) ps

shell-app:
	$(DOCKER) exec app bash

shell-bot:
	$(DOCKER) exec whatsapp-bot sh

shell-db:
	$(DOCKER) exec db mysql -u appuser -p newdb

clean:
	@echo "$(RED)WARNING: This will remove all containers, volumes, and networks!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER) down -v; \
		echo "$(GREEN)Cleanup completed!$(NC)"; \
	fi

install-php:
	$(DOCKER) exec app composer install

install-node:
	$(DOCKER) exec whatsapp-bot npm install

migrate:
	$(DOCKER) exec app php artisan migrate

seed:
	$(DOCKER) exec app php artisan db:seed

rebuild: 
	@echo "$(GREEN)Rebuilding and syncing...$(NC)"
	@$(MAKE) build
	@$(MAKE) up
	@sleep 3
	@echo "$(GREEN) Rebuild complete!$(NC)"

fresh:
	$(MAKE) down
	$(MAKE) build
	$(MAKE) up