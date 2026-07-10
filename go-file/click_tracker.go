package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const maxClickLog = 200

type clickEvent struct {
	Time      string `json:"time"`
	PagePath  string `json:"page_path"`
	PageURL   string `json:"page_url,omitempty"`
	Tag       string `json:"tag"`
	ID        string `json:"id,omitempty"`
	Classes   string `json:"classes,omitempty"`
	Text      string `json:"text,omitempty"`
	Href      string `json:"href,omitempty"`
	DOMPath   string `json:"dom_path,omitempty"`
	ClientX   int    `json:"client_x,omitempty"`
	ClientY   int    `json:"client_y,omitempty"`
	ClientIP  string `json:"client_ip,omitempty"`
	UserAgent string `json:"user_agent,omitempty"`
}

type clickTrackerState struct {
	mu     sync.RWMutex
	events []clickEvent
}

var clickTracker = clickTrackerState{
	events: make([]clickEvent, 0, 64),
}

func recordClickEvent(evt clickEvent) {
	clickTracker.mu.Lock()
	clickTracker.events = append(clickTracker.events, evt)
	if len(clickTracker.events) > maxClickLog {
		clickTracker.events = clickTracker.events[len(clickTracker.events)-maxClickLog:]
	}
	clickTracker.mu.Unlock()

	dash.mu.Lock()
	dash.pushEvent(dashboardEvent{
		Time:       evt.Time,
		Type:       "page_click",
		Method:     "click",
		Transport:  "browser",
		ClientIP:   evt.ClientIP,
		Path:       evt.PagePath,
		Success:    true,
		DurationMS: 0,
		Detail:     summarizeClick(evt),
	})
	dash.mu.Unlock()
}

func recentClickEvents(limit int) []clickEvent {
	clickTracker.mu.RLock()
	defer clickTracker.mu.RUnlock()

	if limit <= 0 || limit > maxClickLog {
		limit = 20
	}
	if limit > len(clickTracker.events) {
		limit = len(clickTracker.events)
	}

	out := make([]clickEvent, 0, limit)
	for i := len(clickTracker.events) - 1; i >= 0 && len(out) < limit; i-- {
		out = append(out, clickTracker.events[i])
	}
	return out
}

func summarizeClick(evt clickEvent) string {
	var parts []string
	if evt.Tag != "" {
		parts = append(parts, evt.Tag)
	}
	if evt.ID != "" {
		parts = append(parts, "#"+evt.ID)
	}
	if evt.Classes != "" {
		parts = append(parts, "."+strings.ReplaceAll(evt.Classes, " ", "."))
	}
	if evt.Text != "" {
		parts = append(parts, fmt.Sprintf("text=%q", evt.Text))
	}
	if evt.Href != "" {
		parts = append(parts, fmt.Sprintf("href=%q", evt.Href))
	}
	if len(parts) == 0 {
		return "page click"
	}
	return strings.Join(parts, " ")
}

func workspaceViewHTML(relPath string) ([]byte, error) {
	path, err := safePath(relPath)
	if err != nil {
		return nil, err
	}

	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		return nil, fmt.Errorf("path is a directory")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	ext := strings.ToLower(filepath.Ext(path))
	if ext != ".html" && ext != ".htm" {
		return data, nil
	}
	return injectClickTracker(data, filepath.ToSlash(relPath)), nil
}

func injectClickTracker(data []byte, relPath string) []byte {
	snippet := fmt.Sprintf(`
<script>
(function () {
    const PAGE_PATH = %q;

    function trimText(value) {
        return (value || "").replace(/\s+/g, " ").trim().slice(0, 120);
    }

    function domPath(el) {
        const parts = [];
        let node = el;
        while (node && node.nodeType === 1 && parts.length < 6) {
            let part = node.tagName.toLowerCase();
            if (node.id) {
                part += "#" + node.id;
                parts.unshift(part);
                break;
            }
            if (node.classList && node.classList.length) {
                part += "." + Array.from(node.classList).slice(0, 3).join(".");
            }
            parts.unshift(part);
            node = node.parentElement;
        }
        return parts.join(" > ");
    }

    function post(payload) {
        const body = JSON.stringify(payload);
        if (navigator.sendBeacon) {
            const blob = new Blob([body], { type: "application/json" });
            navigator.sendBeacon("/api/page-events/click", blob);
            return;
        }
        fetch("/api/page-events/click", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body,
            keepalive: true
        }).catch(() => {});
    }

    document.addEventListener("click", function (event) {
        const target = event.target && event.target.closest
            ? event.target.closest("[data-track-click],button,a,input,label,summary,[role='button'],[onclick]")
            : event.target;
        if (!target) return;
        post({
            page_path: PAGE_PATH,
            page_url: location.href,
            tag: (target.tagName || "").toLowerCase(),
            id: target.id || "",
            classes: target.className && typeof target.className === "string" ? trimText(target.className) : "",
            text: trimText(target.innerText || target.textContent || target.value || ""),
            href: target.getAttribute && target.getAttribute("href") || "",
            dom_path: domPath(target),
            client_x: Math.round(event.clientX || 0),
            client_y: Math.round(event.clientY || 0)
        });
    }, true);
})();
</script>`, relPath)

	lower := bytes.ToLower(data)
	idx := bytes.LastIndex(lower, []byte("</body>"))
	if idx >= 0 {
		out := make([]byte, 0, len(data)+len(snippet))
		out = append(out, data[:idx]...)
		out = append(out, snippet...)
		out = append(out, data[idx:]...)
		return out
	}
	return append(data, []byte(snippet)...)
}

func registerClickTrackerRoutes(r *gin.Engine) {
	r.GET("/workspace/view", func(c *gin.Context) {
		rel := strings.TrimSpace(c.Query("path"))
		if rel == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "path required"})
			return
		}

		data, err := workspaceViewHTML(rel)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		ext := strings.ToLower(filepath.Ext(rel))
		if ext == ".html" || ext == ".htm" {
			c.Data(http.StatusOK, "text/html; charset=utf-8", data)
			return
		}
		c.Data(http.StatusOK, "application/octet-stream", data)
	})

	r.POST("/api/page-events/click", func(c *gin.Context) {
		var req struct {
			PagePath string `json:"page_path"`
			PageURL  string `json:"page_url"`
			Tag      string `json:"tag"`
			ID       string `json:"id"`
			Classes  string `json:"classes"`
			Text     string `json:"text"`
			Href     string `json:"href"`
			DOMPath  string `json:"dom_path"`
			ClientX  int    `json:"client_x"`
			ClientY  int    `json:"client_y"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid click payload"})
			return
		}

		recordClickEvent(clickEvent{
			Time:      time.Now().Format(time.RFC3339),
			PagePath:  strings.TrimSpace(req.PagePath),
			PageURL:   strings.TrimSpace(req.PageURL),
			Tag:       strings.ToLower(strings.TrimSpace(req.Tag)),
			ID:        strings.TrimSpace(req.ID),
			Classes:   strings.TrimSpace(req.Classes),
			Text:      strings.TrimSpace(req.Text),
			Href:      strings.TrimSpace(req.Href),
			DOMPath:   strings.TrimSpace(req.DOMPath),
			ClientX:   req.ClientX,
			ClientY:   req.ClientY,
			ClientIP:  c.ClientIP(),
			UserAgent: c.Request.UserAgent(),
		})

		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	r.GET("/api/page-events", func(c *gin.Context) {
		limit := 20
		if raw := strings.TrimSpace(c.Query("limit")); raw != "" {
			_, _ = fmt.Sscanf(raw, "%d", &limit)
		}
		events := recentClickEvents(limit)
		c.JSON(http.StatusOK, gin.H{
			"events": events,
			"count":  len(events),
		})
	})
}

func toolGetRecentClickEvents(limit int) (string, bool) {
	items := recentClickEvents(limit)
	b, err := json.MarshalIndent(items, "", "  ")
	if err != nil {
		return err.Error(), true
	}
	return string(b), false
}
