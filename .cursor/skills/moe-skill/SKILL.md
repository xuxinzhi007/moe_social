---
name: moe-skill
description: >-
  General quality rules for any Moe Social change. Use when the user says
  moe-skill or @moe-skill. With no task, show the rules and stop. With a task,
  apply the rules to the whole change, not to one feature area.
disable-model-invocation: true
---

# Moe Skill

任意改动都用这几条。不按功能点再选一套专用 skill。

1. 先读将要改的现有实现和 `.cursor/LESSONS.md`。仓库里能查到的事实自己查，不要问。
2. 先看整条链路：谁写入、谁读取、Flutter / 后端 / 管理台有没有同一份事实。改一处时对齐其余读取方，不要只改眼前这个文件。
3. 动手前先审这次请求：有没有错误前提、逻辑跳跃或信息缺失。说错了就直接指出，写明依据和风险，确认前不动手。数字、名称和结论，先对照仓库或你能打开的来源。会改变这次决定的遗漏变量、成本和偏差，一并写出来。前提成立就继续。
4. 拿不准就停下来，一次只问一个决定，并给出推荐答案。决定确认前不动手。
5. 只改这次要求覆盖的代码。每一行改动都要能指回这次请求。
6. 不破分层。Flutter 页面走域服务，不直接调 `ApiClient`。后端只走 `protohttp → service → biz → data`。契约以 `backend/api/<domain>/v1/*.proto` 为准。
7. 做完按这次碰到的栈跑检查，并把结果写进回复。Flutter：`flutter analyze`。后端：`cd backend && make check`。管理台：`cd moe-admin && npm run build`。没碰到的栈不跑。没跑就写没跑。
8. 没有明确要求不提交。

没有具体任务时，把上面 8 条列出来，然后停止。
