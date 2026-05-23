//go:build !windows

package main

import (
	"os"
	"syscall"
	"time"
)

func procSysAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setpgid: true}
}

func stopProcessTree(pid int) {
	_ = syscall.Kill(-pid, syscall.SIGTERM)
	time.Sleep(200 * time.Millisecond)
	_ = syscall.Kill(-pid, syscall.SIGKILL)
	// Fallback if the process is not a group leader.
	proc, err := os.FindProcess(pid)
	if err != nil {
		return
	}
	_ = proc.Kill()
}
