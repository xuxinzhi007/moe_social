package processmem

import (
	"os"
	"runtime"
)

// Snapshot 当前 OS 进程的 Go 运行时与 RSS 快照（管理台展示用）。
type Snapshot struct {
	PID        int
	GoAllocMB  float64
	GoSysMB    float64
	RSSMB      float64
	Goroutines int
	NumCPU     int
}

// Current 采样本进程。
func Current() Snapshot {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	return Snapshot{
		PID:        os.Getpid(),
		GoAllocMB:  float64(ms.Alloc) / 1024 / 1024,
		GoSysMB:    float64(ms.Sys) / 1024 / 1024,
		RSSMB:      readRSSMB(),
		Goroutines: runtime.NumGoroutine(),
		NumCPU:     runtime.NumCPU(),
	}
}
