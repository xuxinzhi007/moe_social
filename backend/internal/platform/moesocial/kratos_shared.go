package moesocial

import (
	"fmt"
	"net"
	"strings"
	"time"

	"backend/internal/platform/appdb"
	apirun "backend/internal/platform/wiring"
	"backend/internal/server"
)

func httpServerDepsFromAPI(res *apirun.StartResult) server.HTTPServerDeps {
	deps := server.HTTPServerDepsFromServiceContext(res.Svc)
	if db, err := appdb.Open(); err == nil {
		deps.Ops.DB = db
	}
	return deps
}

func waitTCPListen(addr string, timeoutSec int) error {
	addr = strings.Replace(addr, "0.0.0.0", "127.0.0.1", 1)
	deadline := time.Now().Add(time.Duration(timeoutSec) * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 200*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("tcp not listening on %s within %ds", addr, timeoutSec)
}
