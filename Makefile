.PHONY: help build up down restart logs clean install-php install-node

YELLOW := \033[1;33m
GREEN := \033[1;32m
RED := \033[1;31m
NC := \033[0m 

help:
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build:
	@echo "$(GREEN)Building containers...$(NC)"
	docker-compose build

up:
	@echo "$(GREEN)Starting services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "PHP App: http://localhost:8080"
	@echo "WhatsApp Bot: http://localhost:3000"
	@echo "Caddy: http://localhost"

down: ## Stop semua services
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker-compose down

restart:
	@echo "$(YELLOW)Restarting services...$(NC)"
	docker-compose restart

logs:
	docker-compose logs -f

logs-app:
	docker-compose logs -f app

logs-bot:
	docker-compose logs -f whatsapp-bot

logs-db:
	docker-compose logs -f db

ps:
	docker-compose ps

shell-app:
	docker-compose exec app bash

shell-bot:
	docker-compose exec whatsapp-bot sh

shell-db:
	docker-compose exec db mysql -u appuser -p newdb

clean: 
	@echo "$(RED)WARNING: This will remove all containers, volumes, and networks!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "$(GREEN)Cleanup completed!$(NC)"; \
	fi

install-php:
	docker-compose exec app composer install

install-node:
	docker-compose exec whatsapp-bot npm install

migrate:
	docker-compose exec app php artisan migrate

fresh: down build up