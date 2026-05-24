package browser

import (
	"os"
	"os/exec"
	"runtime"
)

// Open launches the system default browser (best-effort).
func Open(url string) error {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", "", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	return cmd.Start()
}

// ShouldOpen is true only when MOE_DEPLOY_OPEN_BROWSER=1.
// deploy-agent 默认不弹浏览器；需要时：MOE_DEPLOY_OPEN_BROWSER=1 make deploy-agent
func ShouldOpen() bool {
	if os.Getenv("MOE_DEPLOY_NO_BROWSER") == "1" {
		return false
	}
	return os.Getenv("MOE_DEPLOY_OPEN_BROWSER") == "1"
}
