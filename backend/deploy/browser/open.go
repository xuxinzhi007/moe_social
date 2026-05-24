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

// ShouldOpen returns false when MOE_DEPLOY_NO_BROWSER=1 (CI / headless).
func ShouldOpen() bool {
	return os.Getenv("MOE_DEPLOY_NO_BROWSER") != "1"
}
