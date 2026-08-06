package runserver

import (
	"fmt"
	"log"
	"strings"

	"backend/internal/platform/apiconfig"
)

type wireReporter struct {
	domains []domainWire
	notes   []string
}

type domainWire struct {
	name  string
	route string
	warn  string
}

func newWireReporter() *wireReporter {
	return &wireReporter{}
}

func (r *wireReporter) note(msg string) {
	if strings.TrimSpace(msg) == "" {
		return
	}
	r.notes = append(r.notes, msg)
}

func (r *wireReporter) domain(name, route string) {
	r.domains = append(r.domains, domainWire{name: name, route: route})
}

func (r *wireReporter) domainWarn(name, route, warn string) {
	r.domains = append(r.domains, domainWire{name: name, route: route, warn: warn})
}

func logWireSummary(r *wireReporter, c *apiconfig.Config) {
	if r == nil {
		return
	}
	var inProcess, other, warns []string
	for _, d := range r.domains {
		if d.warn != "" {
			warns = append(warns, fmt.Sprintf("  ! %s: %s (route=%s)", d.name, d.warn, d.route))
			continue
		}
		switch d.route {
		case "in_process", "kratos_http":
			inProcess = append(inProcess, d.name)
		case "none", "":
			other = append(other, d.name)
		default:
			other = append(other, fmt.Sprintf("%s(%s)", d.name, d.route))
		}
	}

	log.Print("── HTTP 域装配 ──")
	if len(inProcess) > 0 {
		log.Printf("  进程内: %s", strings.Join(inProcess, ", "))
	}
	if len(other) > 0 {
		log.Printf("  其它路由: %s", strings.Join(other, ", "))
	}
	for _, w := range warns {
		log.Print(w)
	}
	for _, n := range r.notes {
		log.Printf("  · %s", n)
	}
	if c != nil {
		log.Printf("  图片: dir=%s public=%s max=%d",
			c.Image.LocalDir, c.Image.PublicBaseUrl, c.Image.MaxBytes)
	}
}
