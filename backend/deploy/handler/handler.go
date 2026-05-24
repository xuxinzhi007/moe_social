package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	deploycfg "backend/deploy/config"
	"backend/deploy/github"
	"backend/deploy/runner"
	"backend/deploy/store"
)

// Handler serves Deploy Agent HTTP API.
type Handler struct {
	Cfg      *deploycfg.Config
	Registry *runner.Registry
	Store    *store.Store
	GitHub   *github.Client
}

// New creates an API handler.
func New(cfg *deploycfg.Config) *Handler {
	gh := github.NewClient(
		cfg.GitHub.Owner,
		cfg.GitHub.Repo,
		cfg.GitHub.Token,
		cfg.GitHub.WorkflowID,
	)
	return &Handler{
		Cfg:      cfg,
		Registry: runner.NewRegistry(cfg),
		Store:    store.NewStore(80),
		GitHub:   gh,
	}
}

// RegisterRoutes mounts handlers on mux.
func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/deploy/health", h.withCORS(h.health))
	mux.HandleFunc("/api/deploy/agent", h.withCORS(h.agentMeta))
	mux.HandleFunc("/api/deploy/shutdown", h.withCORS(h.auth(h.shutdownAgent)))
	mux.HandleFunc("/api/deploy/info", h.withCORS(h.info))
	mux.HandleFunc("/api/deploy/session", h.withCORS(h.auth(h.session)))
	mux.HandleFunc("/api/deploy/ssh-check", h.withCORS(h.auth(h.sshCheck)))
	mux.HandleFunc("/api/deploy/remote-check", h.withCORS(h.auth(h.remoteCheck)))
	mux.HandleFunc("/api/deploy/remote-config", h.withCORS(h.auth(h.remoteConfig)))
	mux.HandleFunc("/api/deploy/targets", h.withCORS(h.auth(h.targets)))
	mux.HandleFunc("/api/deploy/host", h.withCORS(h.auth(h.host)))
	mux.HandleFunc("/api/deploy/status", h.withCORS(h.auth(h.status)))
	mux.HandleFunc("/api/deploy/releases", h.withCORS(h.auth(h.releases)))
	mux.HandleFunc("/api/deploy/jobs", h.withCORS(h.auth(h.jobsRoot)))
	mux.HandleFunc("/api/deploy/jobs/", h.withCORS(h.auth(h.jobByID)))
	mux.HandleFunc("/api/deploy/build-cache", h.withCORS(h.auth(h.buildCache)))
}

func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) info(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	cloud := h.Cfg.TargetByID("cloud")
	cloudCompose := cloud.ComposeFile
	if cloudCompose == "" {
		cloudCompose = h.Cfg.ComposeFile
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"auth": map[string]any{
			"mode":        "deploy_token",
			"description": "非 Moe App 账号登录：在页面填写 deploy/config.yaml 中的 token，保存后即可操作",
			"ssh_note":    "云平台：config.yaml 配置 identity_file 或 password；推荐 ssh-copy-id 后只用密钥",
		},
		"paths": map[string]string{
			"workspace":    h.Cfg.WorkspaceAbs(),
			"backend":      h.Cfg.BackendAbs(),
			"compose":      h.Cfg.ComposeFileAbs(),
			"build_cache":  h.Cfg.BuildCacheAbs(),
		},
		"cloud_deploy": map[string]any{
			"backend_dir":  cloud.BackendDir,
			"compose_file": cloudCompose,
			"compose_path": strings.TrimRight(cloud.BackendDir, "/") + "/" + cloudCompose,
			"host":         cloud.Host,
			"containers":   []string{"moe-social-api", "moe-social-rpc"},
		},
		"default_target": h.Cfg.DefaultTarget(),
	})
}

func (h *Handler) session(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":       true,
		"authenticated": true,
		"message":       "Deploy Token 有效",
	})
}

func (h *Handler) sshCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 45*time.Second)
	defer cancel()
	targetID := r.URL.Query().Get("target")
	if targetID == "" {
		targetID = "cloud"
	}
	res := runner.ProbeSSH(ctx, h.Cfg, targetID)
	writeJSON(w, http.StatusOK, map[string]any{
		"success": res.OK,
		"probe":   res,
		"target":  h.Cfg.TargetByID(targetID),
	})
}

func (h *Handler) targets(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	list := h.Cfg.NormalizeTargets()
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"targets": list,
		"default_target": h.Cfg.DefaultTarget(),
	})
}

func (h *Handler) host(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()
	targetID := r.URL.Query().Get("target")
	t := h.Cfg.TargetByID(targetID)
	info := h.Registry.InspectHost(ctx, targetID, h.Cfg)
	payload := map[string]any{
		"success":        true,
		"target":         t,
		"host":           info,
		"resolved_paths": map[string]string{
			"workspace": h.Cfg.WorkspaceAbs(),
			"backend":   h.Cfg.BackendAbs(),
			"compose":   h.Cfg.ComposeFileAbs(),
		},
		"github_enabled": h.GitHub.Enabled(),
	}
	if t.IsSSH() {
		check, _ := runner.RunRemoteCheck(ctx, h.Cfg, targetID)
		payload["remote_check"] = check
	}
	writeJSON(w, http.StatusOK, payload)
}

func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 120*time.Second)
	defer cancel()
	targetID := r.URL.Query().Get("target")
	if targetID == "" {
		targetID = "cloud"
	}
	t := h.Cfg.TargetByID(targetID)
	if t.IsSSH() {
		check, _ := runner.RunRemoteCheck(ctx, h.Cfg, targetID)
		if !check.OK {
			writeJSON(w, http.StatusOK, map[string]any{
				"success":      false,
				"message":      check.Message,
				"remote_check": check,
				"target":       t,
				"output":       check.RawOutput,
			})
			return
		}
	}
	spec, err := h.Registry.ComposePsSpec(targetID, h.Cfg)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]any{
			"success": false,
			"message": err.Error(),
		})
		return
	}
	out, code, err := runner.RunCapture(ctx, spec)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":   err == nil,
		"target":    h.Cfg.TargetByID(targetID),
		"exit_code": code,
		"output":    out,
		"command":   runner.DisplayCommand(spec),
	})
}

func (h *Handler) releases(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	tags, _ := h.Registry.Local.RunGitTagsCapture(ctx)
	resp := map[string]any{
		"success": true,
		"tags":    tags,
	}
	if h.GitHub.Enabled() {
		if rel, err := h.GitHub.LatestRelease(ctx); err == nil {
			resp["github_latest"] = rel
		}
		if runs, err := h.GitHub.ListWorkflowRuns(ctx, 5); err == nil {
			resp["workflow_runs"] = runs
		}
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) jobsRoot(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.listJobs(w, r)
	case http.MethodPost:
		h.createJob(w, r)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (h *Handler) jobByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/api/deploy/jobs/")
	id = strings.Trim(id, "/")
	if id == "" {
		http.Error(w, "missing job id", http.StatusBadRequest)
		return
	}
	j, ok := h.Store.Get(id)
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "job": j})
}

func (h *Handler) listJobs(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"jobs":    h.Store.List(),
	})
}

type createJobBody struct {
	Type   string            `json:"type"`
	Target string            `json:"target"`
	Params map[string]string `json:"params"`
}

func (h *Handler) createJob(w http.ResponseWriter, r *http.Request) {
	var body createJobBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if !runner.Allowed(body.Type) {
		http.Error(w, "unknown job type", http.StatusBadRequest)
		return
	}

	targetID := strings.TrimSpace(body.Target)
	if targetID == "" {
		targetID = h.Cfg.DefaultTarget()
	}
	targetID = runner.SuggestedTarget(body.Type, targetID)
	id := uuid.NewString()
	job := &store.Job{
		ID:        id,
		Type:      body.Type,
		Target:    targetID,
		Status:    store.StatusPending,
		CreatedAt: time.Now(),
		Params:    body.Params,
	}
	h.Store.Add(job)

	go h.runJob(id, body)

	writeJSON(w, http.StatusAccepted, map[string]any{
		"success": true,
		"job_id":  id,
		"message": "job started",
	})
}

func (h *Handler) runJob(id string, body createJobBody) {
	now := time.Now()
	h.Store.Update(id, func(j *store.Job) {
		j.Status = store.StatusRunning
		j.StartedAt = &now
	})

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(h.Cfg.JobTimeoutSeconds)*time.Second)
	defer cancel()

	jobType := strings.TrimSpace(strings.ToLower(body.Type))

	if runner.IsGitHubJob(jobType) {
		h.runGitHubJob(ctx, id, body)
		return
	}

	targetID := strings.TrimSpace(body.Target)
	if targetID == "" {
		targetID = h.Cfg.DefaultTarget()
	}
	targetID = runner.SuggestedTarget(body.Type, targetID)
	req := runner.JobRequest{Type: body.Type, Params: body.Params}

	if runner.IsPipelineJob(jobType) {
		h.Store.Update(id, func(j *store.Job) {
			j.Target = "local+cloud"
			j.Command = "backend_release_pipeline"
		})
		sink := func(line string) { h.Store.AppendLog(id, line) }
		code, err := h.Registry.RunReleasePipeline(ctx, h.Cfg, req, sink)
		errMsg := ""
		if err != nil {
			errMsg = err.Error()
		} else if code != 0 {
			errMsg = fmt.Sprintf("exit code %d", code)
		}
		h.finishJob(id, code, "backend_release_pipeline", errMsg)
		return
	}

	if runner.IsUploadJob(jobType) {
		h.Store.Update(id, func(j *store.Job) {
			j.Target = targetID
			j.Command = "sftp upload (backend_upload_binaries)"
		})
		sink := func(line string) { h.Store.AppendLog(id, line) }
		code, err := h.Registry.RunBackendUpload(ctx, targetID, h.Cfg, req, sink)
		errMsg := ""
		if err != nil {
			errMsg = err.Error()
		} else if code != 0 {
			errMsg = fmt.Sprintf("exit code %d", code)
		}
		h.finishJob(id, code, "backend_upload_binaries", errMsg)
		return
	}

	spec, err := h.Registry.ResolveCommand(targetID, h.Cfg, req)
	if err != nil {
		h.finishJob(id, -1, "", err.Error())
		return
	}
	h.Store.Update(id, func(j *store.Job) {
		j.Target = targetID
	})
	h.Store.Update(id, func(j *store.Job) {
		j.Command = runner.DisplayCommand(spec)
	})

	sink := func(line string) { h.Store.AppendLog(id, line) }
	code, err := runner.Execute(ctx, spec, sink)
	errMsg := ""
	if err != nil {
		errMsg = err.Error()
	} else if code != 0 {
		errMsg = fmt.Sprintf("exit code %d", code)
	}
	h.finishJob(id, code, runner.DisplayCommand(spec), errMsg)
}

func (h *Handler) runGitHubJob(ctx context.Context, id string, body createJobBody) {
	jobType := strings.TrimSpace(strings.ToLower(body.Type))
	h.Store.AppendLog(id, "GitHub API job: "+jobType+"\n")

	if !h.GitHub.Enabled() {
		h.finishJob(id, 1, "github api", "github token not configured in deploy/config.yaml")
		return
	}

	switch jobType {
	case "github_list_workflows":
		runs, err := h.GitHub.ListWorkflowRuns(ctx, 10)
		if err != nil {
			h.finishJob(id, 1, "github", err.Error())
			return
		}
		b, _ := json.MarshalIndent(runs, "", "  ")
		h.Store.AppendLog(id, string(b)+"\n")
		h.finishJob(id, 0, "github list workflows", "")
	case "github_trigger_apk":
		ref := "main"
		if body.Params != nil {
			if v := strings.TrimSpace(body.Params["ref"]); v != "" {
				ref = v
			}
		}
		h.Store.AppendLog(id, "Dispatch workflow ref="+ref+"\n")
		if err := h.GitHub.TriggerWorkflow(ctx, ref); err != nil {
			h.finishJob(id, 1, "github dispatch", err.Error())
			return
		}
		h.Store.AppendLog(id, "Workflow dispatch accepted. Check GitHub Actions.\n")
		h.finishJob(id, 0, "github_trigger_apk", "")
	default:
		h.finishJob(id, 1, "", "unknown github job")
	}
}

func (h *Handler) finishJob(id string, code int, cmd, errMsg string) {
	end := time.Now()
	h.Store.Update(id, func(j *store.Job) {
		j.ExitCode = code
		if cmd != "" {
			j.Command = cmd
		}
		j.EndedAt = &end
		if errMsg != "" {
			j.Error = errMsg
			j.Status = store.StatusFailed
		} else if code == 0 {
			j.Status = store.StatusSucceeded
		} else {
			j.Status = store.StatusFailed
			if j.Error == "" {
				j.Error = "command failed"
			}
		}
	})
}

func (h *Handler) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := deploycfg.TokenFromRequest(
			r.Header.Get("X-Deploy-Token"),
			r.URL.Query().Get("token"),
		)
		if token == "" || token != h.Cfg.Token {
			writeJSON(w, http.StatusUnauthorized, map[string]any{
				"success": false,
				"message": "invalid or missing deploy token",
			})
			return
		}
		next(w, r)
	}
}

func (h *Handler) withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Deploy-Token, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
