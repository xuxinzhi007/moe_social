package runner

import (
	"context"
	"fmt"
	"os/exec"
	"runtime"
	"sync"
)

type linuxBuildTarget struct {
	out string
	pkg string
}

var linuxBuildTargets = []linuxBuildTarget{
	{out: "api/moe-social-api", pkg: "./api"},
	{out: "rpc/moe-social-rpc", pkg: "./rpc"},
}

// runLinuxCrossBuild compiles api+rpc for linux/amd64 without shell env-var syntax.
func runLinuxCrossBuild(ctx context.Context, dir string, sink LogSink) (exitCode int, err error) {
	env := BuildProcessEnv(dir)
	env = append(env, "CGO_ENABLED=0", "GOOS=linux", "GOARCH=amd64", "LANG=C", "LC_ALL=C")

	if sink != nil {
		if runtime.GOOS == "windows" && useGitBashOnWindows() {
			sink("# 本机: go 交叉编译（PATH 来自 Git Bash；临时目录已校正为系统 TEMP）\n")
		} else if runtime.GOOS == "windows" {
			sink("# 本机: go 交叉编译（不经过 make；临时目录使用系统 TEMP）\n")
		}
		if runtime.GOOS == "windows" {
			if td := envMapGet(env, "TMPDIR"); td != "" {
				sink(fmt.Sprintf("# TMPDIR=%s\n", td))
			}
		}
	}

	for i, t := range linuxBuildTargets {
		if sink != nil {
			sink(fmt.Sprintf("$ [%d/%d] GOOS=linux GOARCH=amd64 go build -o %s %s\n", i+1, len(linuxBuildTargets), t.out, t.pkg))
		}
		code, runErr := runSingleGoBuild(ctx, dir, env, t.out, t.pkg, sink)
		if runErr != nil {
			return -1, runErr
		}
		if code != 0 {
			return code, nil
		}
	}
	if sink != nil {
		sink("Done.\n")
	}
	return 0, nil
}

func runSingleGoBuild(ctx context.Context, dir string, env []string, out, pkg string, sink LogSink) (int, error) {
	cmd := exec.CommandContext(ctx, "go", "build", "-o", out, pkg)
	cmd.Dir = dir
	cmd.Env = env

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return -1, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return -1, err
	}

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		pipeLines(commandOutputReader(stdout), sink)
	}()
	go func() {
		defer wg.Done()
		pipeLines(commandOutputReader(stderr), sink)
	}()

	if err := cmd.Start(); err != nil {
		return -1, err
	}
	wg.Wait()

	waitErr := cmd.Wait()
	if waitErr == nil {
		return 0, nil
	}
	if ee, ok := waitErr.(*exec.ExitError); ok {
		return ee.ExitCode(), nil
	}
	return -1, waitErr
}
