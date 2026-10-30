package mediabiz

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const (
	defaultComfyURL        = "http://127.0.0.1:8188"
	defaultComfyCheckpoint = "meinamix_v12Final.safetensors"
	defaultComfyTimeout    = 180 * time.Second
	defaultDrawNegative    = "cartoon, anime, illustration, painting, drawing, lowres, bad anatomy, bad hands, extra fingers, missing fingers, blurry, watermark, text, deformed, oversaturated"
	defaultAnimeNegative   = "realistic, photorealistic, 3d, bad anatomy, bad hands, extra fingers, missing fingers, worst quality, low quality, blurry, watermark, text, deformed, ugly"
	maxPromptRunes         = 2000
	minDrawEdge            = 512
	maxDrawEdge            = 768
	maxDrawSteps           = 40
	maxDrawCFG             = 7
)

var (
	// ErrEmptyPrompt 提示词为空。
	ErrEmptyPrompt = errors.New("empty prompt")
	// ErrPromptTooLong 提示词超过上限。
	ErrPromptTooLong = errors.New("prompt too long")
	// ErrBadDrawSize 宽高不在允许范围。
	ErrBadDrawSize = errors.New("bad draw size")
	// ErrBadDrawSteps 步数不在允许范围。
	ErrBadDrawSteps = errors.New("bad draw steps")
	// ErrBadDrawCFG CFG 不在允许范围。
	ErrBadDrawCFG = errors.New("bad draw cfg")
	// ErrComfyUnavailable 本机 ComfyUI 没有正常返回图片。
	ErrComfyUnavailable = errors.New("comfy unavailable")
	// ErrUnknownCheckpoint 请求的底模不在本机 ComfyUI 里。
	ErrUnknownCheckpoint = errors.New("unknown checkpoint")
)

// DrawRequest 是一次文生图请求。Style 支持 "anime"（动漫，默认）或 "realistic"（写实）。
type DrawRequest struct {
	Prompt     string  `json:"prompt"`
	Negative   string  `json:"negative"`
	Style      string  `json:"style"`
	Width      int     `json:"width"`
	Height     int     `json:"height"`
	Steps      int     `json:"steps"`
	CFG        float64 `json:"cfg"`
	Seed       int64   `json:"seed"`
	Checkpoint string  `json:"checkpoint"`
	Prefix     string  `json:"-"`
}

// GenerateAndStore 调用本机 ComfyUI，并把图片写入该用户的 gen 目录。
func GenerateAndStore(ctx context.Context, cfg ImageConfig, userFolder string, in DrawRequest) (ImageInfo, error) {
	in = in.normalized(cfg.Comfy)
	if err := in.validate(); err != nil {
		return ImageInfo{}, err
	}
	data, err := newComfyClient(cfg.Comfy).Draw(ctx, in)
	if err != nil {
		return ImageInfo{}, err
	}
	info, err := SaveGeneratedImage(ctx, cfg, userFolder, "gen.png", data)
	if err != nil {
		return ImageInfo{}, err
	}
	info.StorageURL = storageURL(cfg, info.Filename)
	return info, nil
}

func storageURL(cfg ImageConfig, key string) string {
	store, err := NewBlobStore(cfg)
	if err != nil {
		return ""
	}
	folder, filename, ok := SplitImageKey(key)
	if !ok {
		return ""
	}
	linker, ok := store.(interface {
		ObjectURL(folder, filename string) string
	})
	if !ok {
		return ""
	}
	return linker.ObjectURL(folder, filename)
}

func (in DrawRequest) normalized(cfg ComfyConfig) DrawRequest {
	in.Prompt = strings.TrimSpace(in.Prompt)
	in.Negative = strings.TrimSpace(in.Negative)
	in.Style = strings.ToLower(strings.TrimSpace(in.Style))
	chosen := strings.TrimSpace(in.Checkpoint)
	if chosen == "" {
		if in.Style == "anime" {
			chosen = defaultComfyCheckpoint
		} else if in.Style == "realistic" {
			chosen = "Realistic_Vision_V5.1_fp16-no-ema.safetensors"
		} else {
			chosen = strings.TrimSpace(cfg.Checkpoint)
		}
	}
	if chosen == "" {
		chosen = defaultComfyCheckpoint
	}
	in.Checkpoint = filepath.Base(chosen)

	isAnime := in.Style == "anime" ||
		strings.Contains(strings.ToLower(in.Checkpoint), "meina") ||
		strings.Contains(strings.ToLower(in.Checkpoint), "anime") ||
		strings.Contains(strings.ToLower(in.Checkpoint), "anything") ||
		strings.Contains(strings.ToLower(in.Checkpoint), "counterfeit")

	if isAnime && !strings.Contains(strings.ToLower(in.Prompt), "anime") {
		in.Prompt = "masterpiece, best quality, anime style, 2d illustration, " + in.Prompt
	}

	if in.Negative == "" {
		if isAnime {
			in.Negative = defaultAnimeNegative
		} else {
			in.Negative = defaultDrawNegative
		}
	}
	if in.Width == 0 {
		in.Width = minDrawEdge
	}
	if in.Height == 0 {
		in.Height = 768
	}
	if in.Steps == 0 {
		in.Steps = 25
	}
	if in.CFG == 0 {
		if isAnime {
			in.CFG = 6.5
		} else {
			in.CFG = 5
		}
	}
	if strings.TrimSpace(in.Prefix) == "" {
		in.Prefix = fmt.Sprintf("moe_%d", time.Now().UnixNano())
	}
	return in
}

func (in DrawRequest) validate() error {
	if in.Prompt == "" {
		return ErrEmptyPrompt
	}
	if utf8.RuneCountInString(in.Prompt) > maxPromptRunes || utf8.RuneCountInString(in.Negative) > maxPromptRunes {
		return ErrPromptTooLong
	}
	if !validEdge(in.Width) || !validEdge(in.Height) {
		return ErrBadDrawSize
	}
	if in.Steps < 1 || in.Steps > maxDrawSteps {
		return ErrBadDrawSteps
	}
	if in.CFG < 1 || in.CFG > maxDrawCFG {
		return ErrBadDrawCFG
	}
	if !validCheckpointName(in.Checkpoint) {
		return ErrUnknownCheckpoint
	}
	return nil
}

func validCheckpointName(name string) bool {
	if name == "" || name != filepath.Base(name) || strings.Contains(name, "..") {
		return false
	}
	switch strings.ToLower(filepath.Ext(name)) {
	case ".safetensors", ".ckpt":
		return true
	default:
		return false
	}
}

func validEdge(n int) bool {
	return n >= minDrawEdge && n <= maxDrawEdge && n%64 == 0
}

type comfyClient struct {
	base    string
	timeout time.Duration
	http    *http.Client
}

var comfyMu sync.Mutex

func newComfyClient(cfg ComfyConfig) *comfyClient {
	base := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if base == "" {
		base = defaultComfyURL
	}
	timeout := time.Duration(cfg.TimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = defaultComfyTimeout
	}
	return &comfyClient{
		base:    base,
		timeout: timeout,
		http:    &http.Client{Timeout: timeout},
	}
}

// Draw 提交写实工作流并等这一张图完成。同一进程同时只跑一张，避免 8GB 显存叠两张。
func (c *comfyClient) Draw(ctx context.Context, in DrawRequest) ([]byte, error) {
	comfyMu.Lock()
	defer comfyMu.Unlock()

	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()

	names, err := c.Checkpoints(ctx)
	if err != nil {
		return nil, err
	}
	in.Checkpoint = pickCheckpointForRequest(names, in)
	if !containsString(names, in.Checkpoint) {
		return nil, fmt.Errorf("%w: %s", ErrUnknownCheckpoint, in.Checkpoint)
	}
	promptID, err := c.submit(ctx, in)
	if err != nil {
		return nil, err
	}
	image, err := c.waitImage(ctx, promptID)
	if err != nil {
		c.drop(context.Background(), promptID)
		return nil, err
	}
	return c.download(ctx, image)
}

// Checkpoints 返回本机 ComfyUI 已安装的底模文件名。
func (c *comfyClient) Checkpoints(ctx context.Context) ([]string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.base+"/object_info/CheckpointLoaderSimple", nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrComfyUnavailable, err.Error())
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%w: checkpoints status %d", ErrComfyUnavailable, resp.StatusCode)
	}
	names := checkpointNames(raw)
	if len(names) == 0 {
		return nil, fmt.Errorf("%w: no checkpoints", ErrComfyUnavailable)
	}
	return names, nil
}

func checkpointNames(raw []byte) []string {
	var doc map[string]any
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil
	}
	node, _ := doc["CheckpointLoaderSimple"].(map[string]any)
	if node == nil {
		node = doc
	}
	input, _ := node["input"].(map[string]any)
	required, _ := input["required"].(map[string]any)
	ckpt, _ := required["ckpt_name"].([]any)
	if len(ckpt) == 0 {
		return nil
	}
	list, _ := ckpt[0].([]any)
	names := make([]string, 0, len(list))
	for _, item := range list {
		name, _ := item.(string)
		if validCheckpointName(name) {
			names = append(names, name)
		}
	}
	return names
}

func containsString(list []string, want string) bool {
	for _, item := range list {
		if item == want {
			return true
		}
	}
	return false
}

// pickCheckpointForRequest 当请求指定了 style（anime / realistic）且未显式指定具体底模，
// 或指定的底模不在已安装列表中时，自动从本机 ComfyUI 已安装的底模里挑选最匹配的模型（如 MeinaMix vs Realistic_Vision）。
func pickCheckpointForRequest(installed []string, in DrawRequest) string {
	style := strings.ToLower(strings.TrimSpace(in.Style))
	if style == "anime" {
		if isAnimeCheckpointName(in.Checkpoint) && containsString(installed, in.Checkpoint) {
			return in.Checkpoint
		}
		for _, name := range installed {
			if isAnimeCheckpointName(name) {
				return name
			}
		}
	} else if style == "realistic" {
		if isRealisticCheckpointName(in.Checkpoint) && containsString(installed, in.Checkpoint) {
			return in.Checkpoint
		}
		for _, name := range installed {
			if isRealisticCheckpointName(name) {
				return name
			}
		}
	}
	if containsString(installed, in.Checkpoint) {
		return in.Checkpoint
	}
	if len(installed) > 0 && in.Style != "" {
		return installed[0]
	}
	return in.Checkpoint
}

func isAnimeCheckpointName(name string) bool {
	lower := strings.ToLower(name)
	for _, kw := range []string{"meina", "anime", "anything", "counterfeit", "pastel", "abyss", "toon", "2d"} {
		if strings.Contains(lower, kw) {
			return true
		}
	}
	return false
}

func isRealisticCheckpointName(name string) bool {
	lower := strings.ToLower(name)
	for _, kw := range []string{"realistic", "chillout", "majicmix", "photoreal", "real"} {
		if strings.Contains(lower, kw) {
			return true
		}
	}
	return false
}

// ListCheckpoints 列出本机 ComfyUI 底模。
func ListCheckpoints(ctx context.Context, cfg ComfyConfig) ([]string, error) {
	return newComfyClient(cfg).Checkpoints(ctx)
}

func (c *comfyClient) submit(ctx context.Context, in DrawRequest) (string, error) {
	seed := in.Seed
	if seed == 0 {
		seed = rand.Int63()
	}
	body, err := json.Marshal(map[string]any{
		"client_id": "moe-social",
		"prompt":    realisticGraph(in, seed),
	})
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base+"/prompt", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("%w: %s", ErrComfyUnavailable, err.Error())
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("%w: prompt status %d", ErrComfyUnavailable, resp.StatusCode)
	}
	var out struct {
		PromptID   string         `json:"prompt_id"`
		NodeErrors map[string]any `json:"node_errors"`
	}
	if err := json.Unmarshal(raw, &out); err != nil || out.PromptID == "" || len(out.NodeErrors) > 0 {
		return "", fmt.Errorf("%w: prompt rejected", ErrComfyUnavailable)
	}
	return out.PromptID, nil
}

func realisticGraph(in DrawRequest, seed int64) map[string]any {
	clipStop := -1
	if in.Style == "anime" || isAnimeCheckpointName(in.Checkpoint) {
		clipStop = -2
	}
	return map[string]any{
		"4": map[string]any{
			"class_type": "CheckpointLoaderSimple",
			"inputs":     map[string]any{"ckpt_name": in.Checkpoint},
		},
		"10": map[string]any{
			"class_type": "CLIPSetLastLayer",
			"inputs": map[string]any{
				"clip":               []any{"4", 1},
				"stop_at_clip_layer": clipStop,
			},
		},
		"6": map[string]any{
			"class_type": "CLIPTextEncode",
			"inputs":     map[string]any{"text": in.Prompt, "clip": []any{"10", 0}},
		},
		"7": map[string]any{
			"class_type": "CLIPTextEncode",
			"inputs":     map[string]any{"text": in.Negative, "clip": []any{"10", 0}},
		},
		"5": map[string]any{
			"class_type": "EmptyLatentImage",
			"inputs":     map[string]any{"width": in.Width, "height": in.Height, "batch_size": 1},
		},
		"3": map[string]any{
			"class_type": "KSampler",
			"inputs": map[string]any{
				"seed": seed, "steps": in.Steps, "cfg": in.CFG,
				"sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1,
				"model": []any{"4", 0}, "positive": []any{"6", 0}, "negative": []any{"7", 0}, "latent_image": []any{"5", 0},
			},
		},
		"8": map[string]any{
			"class_type": "VAEDecode",
			"inputs":     map[string]any{"samples": []any{"3", 0}, "vae": []any{"4", 2}},
		},
		"9": map[string]any{
			"class_type": "SaveImage",
			"inputs":     map[string]any{"filename_prefix": in.Prefix, "images": []any{"8", 0}},
		},
	}
}

type comfyImage struct {
	Filename  string `json:"filename"`
	Subfolder string `json:"subfolder"`
	Type      string `json:"type"`
}

func (c *comfyClient) waitImage(ctx context.Context, promptID string) (comfyImage, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		image, done, failed, err := c.history(ctx, promptID)
		if err != nil {
			return comfyImage{}, err
		}
		if failed {
			return comfyImage{}, fmt.Errorf("%w: generation failed", ErrComfyUnavailable)
		}
		if done {
			return image, nil
		}
		select {
		case <-ctx.Done():
			return comfyImage{}, fmt.Errorf("%w: %s", ErrComfyUnavailable, ctx.Err().Error())
		case <-ticker.C:
		}
	}
}

func (c *comfyClient) history(ctx context.Context, promptID string) (comfyImage, bool, bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.base+"/history/"+url.PathEscape(promptID), nil)
	if err != nil {
		return comfyImage{}, false, false, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return comfyImage{}, false, false, fmt.Errorf("%w: %s", ErrComfyUnavailable, err.Error())
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode != http.StatusOK {
		return comfyImage{}, false, false, fmt.Errorf("%w: history status %d", ErrComfyUnavailable, resp.StatusCode)
	}
	var doc map[string]struct {
		Outputs map[string]struct {
			Images []comfyImage `json:"images"`
		} `json:"outputs"`
		Status struct {
			Completed bool   `json:"completed"`
			StatusStr string `json:"status_str"`
		} `json:"status"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		return comfyImage{}, false, false, fmt.Errorf("%w: bad history", ErrComfyUnavailable)
	}
	item, ok := doc[promptID]
	if !ok {
		return comfyImage{}, false, false, nil
	}
	if item.Status.Completed && item.Status.StatusStr != "" && item.Status.StatusStr != "success" {
		return comfyImage{}, false, true, nil
	}
	for _, output := range item.Outputs {
		if len(output.Images) > 0 && output.Images[0].Filename != "" {
			return output.Images[0], true, false, nil
		}
	}
	if item.Status.Completed {
		return comfyImage{}, false, true, nil
	}
	return comfyImage{}, false, false, nil
}

func (c *comfyClient) download(ctx context.Context, image comfyImage) ([]byte, error) {
	q := url.Values{}
	q.Set("filename", image.Filename)
	q.Set("subfolder", image.Subfolder)
	if image.Type == "" {
		image.Type = "output"
	}
	q.Set("type", image.Type)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.base+"/view?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrComfyUnavailable, err.Error())
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 30<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK || len(data) == 0 {
		return nil, fmt.Errorf("%w: empty image", ErrComfyUnavailable)
	}
	return data, nil
}

func (c *comfyClient) drop(ctx context.Context, promptID string) {
	body, _ := json.Marshal(map[string]any{"delete": []string{promptID}})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base+"/queue", bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return
	}
	resp.Body.Close()
}
