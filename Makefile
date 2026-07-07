.PHONY: help \
	rn-setup rn-dev rn-dev-tunnel rn-reset rn-check rn-prebuild \
	backend-gen backend-check backend-dev backend-migrate

help:
	@echo "React Native migration:"
	@echo "  make rn-setup        - install app-rn dependencies"
	@echo "  make rn-dev          - start Expo in LAN mode"
	@echo "  make rn-dev-tunnel   - start Expo in tunnel mode and clear cache"
	@echo "  make rn-reset        - clear Expo cache"
	@echo "  make rn-check        - run TypeScript typecheck"
	@echo "  make rn-prebuild     - generate native folders when needed"
	@echo ""
	@echo "Backend:"
	@echo "  make backend-gen     - regenerate proto/OpenAPI artifacts"
	@echo "  make backend-check   - run backend checks"
	@echo "  make backend-dev     - start backend service"
	@echo "  make backend-migrate - run database migrations"

rn-setup:
	cd app-rn && npm install

rn-dev:
	cd app-rn && npm start

rn-dev-tunnel:
	cd app-rn && npx expo start --tunnel -c

rn-check:
	cd app-rn && npm run typecheck

rn-prebuild:
	cd app-rn && npx expo prebuild

rn-reset:
ifeq ($(OS),Windows_NT)
	@if exist app-rn\.expo rmdir /s /q app-rn\.expo
else
	rm -rf app-rn/.expo
endif

backend-gen:
	$(MAKE) -C backend gen

backend-check:
	$(MAKE) -C backend check

backend-dev:
	$(MAKE) -C backend moe-social

backend-migrate:
	$(MAKE) -C backend db-migrate
