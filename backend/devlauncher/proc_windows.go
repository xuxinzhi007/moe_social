//go:build windows

package devlauncher

import (
	"os"
	"syscall"
)

func procSysAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{}
}

func stopProcessTree(pid int) {
	proc, err := os.FindProcess(pid)
	if err != nil {
		return
	}
	_ = proc.Kill()
}
