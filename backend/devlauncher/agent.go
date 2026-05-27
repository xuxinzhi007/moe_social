package devlauncher

import (
	"fmt"
	"log"
	"path/filepath"

	"backend/devports"
)

const deployAgentBinName = "moe-deploy-agent"

// StartDeployAgent builds and runs deploy-agent (config auto-seeded from example on first run).
// Returns the managed process; caller should StopManaged on shutdown.
func StartDeployAgent(root string) (*ManagedProcess, error) {
	devBin := filepath.Join(root, ".dev")
	bin, err := BuildDevBinary(root, devBin, deployAgentBinName, "./cmd/deploy-agent")
	if err != nil {
		return nil, fmt.Errorf("build deploy-agent: %w", err)
	}
	proc, err := StartProcess("agent", root, bin, "-f", "deploy/config.yaml")
	if err != nil {
		return nil, fmt.Errorf("start deploy-agent: %w", err)
	}
	log.Printf("deploy-agent ready — %s (config: deploy/config.yaml)", devports.AgentURL())
	return proc, nil
}
