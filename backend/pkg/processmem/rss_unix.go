//go:build unix

package processmem

import (
	"runtime"
	"syscall"
)

func readRSSMB() float64 {
	var ru syscall.Rusage
	if err := syscall.Getrusage(syscall.RUSAGE_SELF, &ru); err != nil {
		return 0
	}
	// darwin: Maxrss 为字节；linux: 千字节
	if runtime.GOOS == "darwin" {
		return float64(ru.Maxrss) / 1024 / 1024
	}
	return float64(ru.Maxrss) / 1024
}
