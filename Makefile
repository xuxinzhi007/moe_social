.PHONY: help \
	backend-gen backend-check backend-dev backend-migrate

help:
	@echo "Backend:"
	@echo "  make backend-gen     - regenerate proto/OpenAPI artifacts"
	@echo "  make backend-check   - run backend checks"
	@echo "  make backend-dev     - start backend service"
	@echo "  make backend-migrate - run database migrations"

backend-gen:
	$(MAKE) -C backend gen

backend-check:
	$(MAKE) -C backend check

backend-dev:
	$(MAKE) -C backend moe-social

backend-migrate:
	$(MAKE) -C backend db-migrate
