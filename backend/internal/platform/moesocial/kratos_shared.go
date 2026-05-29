package moesocial

import (
	"fmt"
	"net"
	"strings"
	"time"

	"backend/internal/server"
	apirun "backend/internal/platform/wiring"
	"backend/utils"
)

func pilotDepsFromAPI(res *apirun.StartResult) server.PilotDeps {
	d := server.PilotDeps{
		MoeAdmin: res.Svc.MoeAdmin,
		AdminApp: res.Svc.AdminApp,
		Svc:      res.Svc,
	}
	if db := utils.GetDB(); db != nil {
		d.DB = db
	}
	return d
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
