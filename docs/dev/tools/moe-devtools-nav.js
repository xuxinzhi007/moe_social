/**
 * 各工具页共用：与 docs/dev/devtools.html 互跳、新标签打开。
 * 在页面底部引入：<script src="moe-devtools-nav.js" data-current="feishu"></script>
 */
(function () {
  const script = document.currentScript;
  const current = script?.dataset?.current || "";

  const TOOLS = [
    { id: "feishu", label: "飞书命令", href: "feishu-export.html" },
    { id: "rpc", label: "RPC 监控", href: "rpc-monitor.html" },
    { id: "memory", label: "记忆监控", href: "../memory-system-dashboard.html" },
    { id: "deploy", label: "运维部署", href: "deploy-ops.html", agent: "http://127.0.0.1:9100/" },
  ];

  const hub = "../devtools.html";

  function isEmbedded() {
    try {
      return window.parent !== window;
    } catch (_) {
      return false;
    }
  }

  function openInHub(tabId) {
    const url = new URL(hub, window.location.href);
    url.searchParams.set("tab", tabId);
    if (isEmbedded()) {
      window.parent.postMessage({ type: "moe-devtools-switch", tab: tabId }, "*");
    } else {
      window.location.href = url.href;
    }
  }

  function openNewTab(tool) {
    const url = tool.agent && tool.id === "deploy" ? tool.agent : new URL(tool.href, window.location.href).href;
    window.open(url, "_blank", "noopener");
  }

  document.querySelectorAll("[data-devtools-tab]").forEach((el) => {
    el.addEventListener("click", (e) => {
      const tab = el.getAttribute("data-devtools-tab");
      if (!tab) return;
      e.preventDefault();
      openInHub(tab);
    });
  });

  document.querySelectorAll("[data-devtools-newtab]").forEach((el) => {
    el.addEventListener("click", (e) => {
      const tab = el.getAttribute("data-devtools-newtab");
      const tool = TOOLS.find((t) => t.id === tab);
      if (!tool) return;
      e.preventDefault();
      openNewTab(tool);
    });
  });

  window.MoeDevtoolsNav = { TOOLS, openInHub, openNewTab, isEmbedded };
})();
