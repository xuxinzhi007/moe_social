# Moe Social Flutter Web 自动化测试工具链

.PHONY: install serve serve-release test test-smoke test-e2e report clean

install:
	npm install

# 启动 Flutter Web（使用 HTML 渲染器，便于 Playwright 测试）
serve:
	cd .. && flutter run -d chrome --web-port 9900 --web-define=flutterWebRenderer=html

# 发布构建 + 静态服务
serve-release:
	cd .. && flutter build web --release --web-define=flutterWebRenderer=html
	cd ../build/web && python3 -m http.server 9900

# 运行全部测试
test:
	npx playwright test specs

# 仅冒烟测试（遍历所有页面）
test-smoke:
	npx playwright test specs/smoke.spec.ts

# 仅 E2E 功能测试
test-e2e:
	npx playwright test specs/e2e.spec.ts

# 打开 HTML 报告
report:
	npx playwright show-report

# 清理产物
clean:
	rm -rf playwright-report test-results
