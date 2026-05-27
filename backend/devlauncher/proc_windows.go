//go:build windows

package devlauncher

import (
	"os/exec"
	"strconv"
	"syscall"
)

func procSysAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP}
}

func stopProcessTree(pid int) {
	_ = exec.Command("taskkill", "/F", "/T", "/PID", strconv.Itoa(pid)).Run()
}
