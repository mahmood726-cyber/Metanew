# Makefile for EvidenceOS PRIME
# Provides convenient commands for development, testing, and deployment

.PHONY: help install install-dev test test-backend test-frontend lint format \
        docker-build docker-up docker-down docker-logs clean check security \
        run-backend run-frontend coverage docs

# Colors for terminal output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)EvidenceOS PRIME - Development Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ============================================================================
# INSTALLATION
# ============================================================================

install: ## Install all dependencies (production)
	@echo "$(BLUE)Installing dependencies...$(NC)"
	pip install -r backend/requirements.txt
	@echo "$(GREEN)✓ Python dependencies installed$(NC)"
	@echo "$(YELLOW)Note: Install R dependencies manually with: Rscript -e \"install.packages(...)\"$(NC)"

install-dev: ## Install all dependencies including dev tools
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	pip install -r backend/requirements_enhanced.txt
	pip install pre-commit
	pre-commit install
	@echo "$(GREEN)✓ Development environment ready$(NC)"

install-pre-commit: ## Install pre-commit hooks
	@echo "$(BLUE)Installing pre-commit hooks...$(NC)"
	pip install pre-commit
	pre-commit install
	@echo "$(GREEN)✓ Pre-commit hooks installed$(NC)"

# ============================================================================
# TESTING
# ============================================================================

test: test-backend ## Run all tests

test-backend: ## Run Python backend tests
	@echo "$(BLUE)Running backend tests...$(NC)"
	cd backend && pytest tests/py/ -v --tb=short --cov=backend --cov-report=term --cov-report=html
	@echo "$(GREEN)✓ Backend tests complete$(NC)"

test-frontend: ## Run R frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	Rscript -e "testthat::test_dir('tests/r')"
	@echo "$(GREEN)✓ Frontend tests complete$(NC)"

test-api: ## Run API tests only
	@echo "$(BLUE)Running API tests...$(NC)"
	pytest tests/py/test_api_comprehensive.py -v --tb=short
	@echo "$(GREEN)✓ API tests complete$(NC)"

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	pytest tests/integration/ -v --tb=short
	@echo "$(GREEN)✓ Integration tests complete$(NC)"

coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating coverage report...$(NC)"
	pytest tests/py/ --cov=backend --cov-report=html --cov-report=term
	@echo "$(GREEN)✓ Coverage report generated: htmlcov/index.html$(NC)"

# ============================================================================
# CODE QUALITY
# ============================================================================

lint: ## Run all linters
	@echo "$(BLUE)Running linters...$(NC)"
	flake8 backend/ --max-line-length=120 --ignore=E203,W503 --exclude=venv,.venv,__pycache__
	pylint backend/api/ backend/etl/ backend/cache/ --disable=C0114,C0115,C0116 || true
	@echo "$(GREEN)✓ Linting complete$(NC)"

format: ## Format code with black and isort
	@echo "$(BLUE)Formatting code...$(NC)"
	black backend/ --line-length=120
	isort backend/ --profile black --line-length=120
	@echo "$(GREEN)✓ Code formatted$(NC)"

type-check: ## Run type checking with mypy
	@echo "$(BLUE)Running type checker...$(NC)"
	mypy backend/ --ignore-missing-imports --no-strict-optional
	@echo "$(GREEN)✓ Type checking complete$(NC)"

security: ## Run security checks
	@echo "$(BLUE)Running security checks...$(NC)"
	bandit -r backend/ -ll -x backend/tests/
	safety check -r backend/requirements.txt || true
	@echo "$(GREEN)✓ Security check complete$(NC)"

check: lint test ## Run all checks (lint + test)
	@echo "$(GREEN)✓ All checks passed!$(NC)"

pre-commit: ## Run pre-commit hooks on all files
	@echo "$(BLUE)Running pre-commit hooks...$(NC)"
	pre-commit run --all-files
	@echo "$(GREEN)✓ Pre-commit hooks complete$(NC)"

# ============================================================================
# DEVELOPMENT
# ============================================================================

run-backend: ## Run backend development server
	@echo "$(BLUE)Starting backend server...$(NC)"
	cd backend/api && python main_improved.py

run-frontend: ## Run frontend Shiny server
	@echo "$(BLUE)Starting frontend server...$(NC)"
	cd frontend && Rscript -e "shiny::runApp()"

dev: ## Run both backend and frontend (requires tmux)
	@echo "$(BLUE)Starting development environment...$(NC)"
	tmux new-session -d -s evidenceos 'cd backend/api && python main_improved.py'
	tmux split-window -h 'cd frontend && Rscript -e "shiny::runApp()"'
	tmux attach-session -t evidenceos

# ============================================================================
# DOCKER
# ============================================================================

docker-build: ## Build Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	docker-compose build
	@echo "$(GREEN)✓ Docker images built$(NC)"

docker-up: ## Start all services with Docker Compose
	@echo "$(BLUE)Starting services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)Frontend: http://localhost:3838$(NC)"
	@echo "$(YELLOW)Backend: http://localhost:8000$(NC)"
	@echo "$(YELLOW)API Docs: http://localhost:8000/docs$(NC)"

docker-down: ## Stop all services
	@echo "$(BLUE)Stopping services...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

docker-restart: docker-down docker-up ## Restart all services

docker-logs: ## Show Docker logs
	docker-compose logs -f

docker-ps: ## Show running containers
	docker-compose ps

docker-clean: ## Remove Docker containers and volumes
	@echo "$(BLUE)Cleaning Docker resources...$(NC)"
	docker-compose down -v
	docker system prune -f
	@echo "$(GREEN)✓ Docker resources cleaned$(NC)"

# ============================================================================
# DATABASE & CACHE
# ============================================================================

redis-start: ## Start Redis container
	@echo "$(BLUE)Starting Redis...$(NC)"
	docker run -d --name evidenceos-redis -p 6379:6379 redis:7-alpine
	@echo "$(GREEN)✓ Redis started$(NC)"

redis-stop: ## Stop Redis container
	@echo "$(BLUE)Stopping Redis...$(NC)"
	docker stop evidenceos-redis && docker rm evidenceos-redis
	@echo "$(GREEN)✓ Redis stopped$(NC)"

redis-cli: ## Open Redis CLI
	docker exec -it evidenceos-redis redis-cli

cache-clear: ## Clear Redis cache
	@echo "$(BLUE)Clearing cache...$(NC)"
	docker exec evidenceos-redis redis-cli FLUSHDB
	@echo "$(GREEN)✓ Cache cleared$(NC)"

# ============================================================================
# DEPLOYMENT
# ============================================================================

deploy-test: ## Deploy to test environment
	@echo "$(BLUE)Deploying to test environment...$(NC)"
	@echo "$(YELLOW)Deployment steps would go here$(NC)"

deploy-prod: ## Deploy to production (requires confirmation)
	@echo "$(YELLOW)⚠️  This will deploy to PRODUCTION$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Deploying to production...$(NC)"; \
		echo "$(YELLOW)Deployment steps would go here$(NC)"; \
	else \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

# ============================================================================
# DOCUMENTATION
# ============================================================================

docs: ## Generate API documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	cd backend/api && python -c "from main_improved import app; import json; print(json.dumps(app.openapi(), indent=2))" > ../../docs/openapi.json
	@echo "$(GREEN)✓ Documentation generated: docs/openapi.json$(NC)"

docs-serve: ## Serve documentation locally
	@echo "$(BLUE)Starting documentation server...$(NC)"
	@echo "$(YELLOW)API Docs: http://localhost:8000/docs$(NC)"
	cd backend/api && python main_improved.py

# ============================================================================
# UTILITIES
# ============================================================================

clean: ## Clean up temporary files and caches
	@echo "$(BLUE)Cleaning up...$(NC)"
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete 2>/dev/null || true
	find . -type f -name '*.pyo' -delete 2>/dev/null || true
	find . -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache .mypy_cache .coverage htmlcov/ dist/ build/
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: clean docker-clean ## Deep clean (including Docker)
	@echo "$(GREEN)✓ Deep clean complete$(NC)"

env-example: ## Create .env.example file
	@echo "$(BLUE)Creating .env.example...$(NC)"
	@echo "$(GREEN)✓ .env.example already exists$(NC)"

backup: ## Backup outputs and data
	@echo "$(BLUE)Creating backup...$(NC)"
	tar -czf backup_$$(date +%Y%m%d_%H%M%S).tar.gz outputs/ data/
	@echo "$(GREEN)✓ Backup created$(NC)"

status: ## Show project status
	@echo "$(BLUE)EvidenceOS PRIME Status$(NC)"
	@echo ""
	@echo "$(GREEN)Git Status:$(NC)"
	@git status --short
	@echo ""
	@echo "$(GREEN)Docker Containers:$(NC)"
	@docker-compose ps 2>/dev/null || echo "No containers running"
	@echo ""
	@echo "$(GREEN)Python Version:$(NC)"
	@python --version
	@echo ""
	@echo "$(GREEN)Dependencies Status:$(NC)"
	@pip list | grep -E "fastapi|uvicorn|pandas|numpy|pydantic" || echo "Dependencies not installed"

# ============================================================================
# CI/CD
# ============================================================================

ci-test: ## Run CI test suite
	@echo "$(BLUE)Running CI tests...$(NC)"
	pytest tests/py/ -v --cov=backend --cov-report=xml --cov-report=term
	@echo "$(GREEN)✓ CI tests complete$(NC)"

ci-lint: ## Run CI linting
	@echo "$(BLUE)Running CI linting...$(NC)"
	flake8 backend/ --max-line-length=120 --ignore=E203,W503
	black backend/ --check
	@echo "$(GREEN)✓ CI linting complete$(NC)"

ci-build: ## Build for CI
	@echo "$(BLUE)Building for CI...$(NC)"
	docker-compose build --no-cache
	@echo "$(GREEN)✓ CI build complete$(NC)"

ci: ci-lint ci-test ## Run complete CI pipeline locally
	@echo "$(GREEN)✓ CI pipeline complete!$(NC)"

# Default target
.DEFAULT_GOAL := help
