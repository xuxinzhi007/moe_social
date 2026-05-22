package runner

import (
	"context"
	"fmt"
	"strings"
)

// JobRequest parameters for creating a job.
type JobRequest struct {
	Type    string
	Params  map[string]string
}

// ResolveCommand maps job type to a CommandSpec.
func (p *Platform) ResolveCommand(req JobRequest) (CommandSpec, error) {
	t := strings.TrimSpace(strings.ToLower(req.Type))
	params := req.Params
	if params == nil {
		params = map[string]string{}
	}

	switch t {
	case "env_inspect":
		return p.EnvInspectCommand(), nil
	case "backend_build_linux":
		return p.BuildLinuxCommand(), nil
	case "backend_build_local":
		return p.BuildLocalCommand(), nil
	case "docker_ps":
		return p.ComposePs(), nil
	case "docker_up":
		return p.ComposeUp(), nil
	case "docker_stop":
		return p.ComposeStop(), nil
	case "docker_down":
		return p.ComposeDown(), nil
	case "docker_restart":
		return p.ComposeRestart(params["service"]), nil
	case "docker_logs":
		tail := 100
		if v := params["tail"]; v != "" {
			fmt.Sscanf(v, "%d", &tail)
		}
		return p.DockerLogs(params["service"], tail), nil
	case "flutter_pub_get":
		return p.FlutterPubGet(), nil
	case "flutter_build_apk":
		return p.FlutterBuildAPK(params["version"]), nil
	case "flutter_doctor":
		return p.FlutterDoctor(), nil
	case "remote_inspect":
		return CommandSpec{}, fmt.Errorf("remote_inspect 仅能在云平台 (cloud) 执行")
	case "git_tags":
		return p.GitTags(), nil
	default:
		return CommandSpec{}, fmt.Errorf("unknown job type: %s", req.Type)
	}
}

// IsGitHubJob returns true if type is handled by GitHub client not shell.
func IsGitHubJob(jobType string) bool {
	switch strings.TrimSpace(strings.ToLower(jobType)) {
	case "github_list_workflows", "github_trigger_apk":
		return true
	default:
		return false
	}
}

// AllowedJobTypes for API validation.
var AllowedJobTypes = []string{
	"env_inspect",
	"backend_build_linux",
	"backend_build_local",
	"backend_upload_binaries",
	"backend_release_pipeline",
	"docker_ps",
	"docker_up",
	"docker_stop",
	"docker_down",
	"docker_restart",
	"docker_logs",
	"flutter_pub_get",
	"flutter_build_apk",
	"flutter_doctor",
	"remote_inspect",
	"git_tags",
	"github_list_workflows",
	"github_trigger_apk",
}

func Allowed(typeName string) bool {
	t := strings.TrimSpace(strings.ToLower(typeName))
	for _, a := range AllowedJobTypes {
		if a == t {
			return true
		}
	}
	return false
}

// RunGitTagsCapture runs git tag and returns output.
func (p *Platform) RunGitTagsCapture(ctx context.Context) ([]string, error) {
	spec := p.GitTags()
	out, code, err := RunCapture(ctx, spec)
	if err != nil {
		return nil, err
	}
	if code != 0 {
		return nil, fmt.Errorf("git tag exit %d", code)
	}
	var tags []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			tags = append(tags, line)
		}
	}
	return tags, nil
}
