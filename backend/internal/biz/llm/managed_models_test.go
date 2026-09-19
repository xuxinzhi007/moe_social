package llmbiz_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	aiv1 "backend/api/ai/v1"
	aibiz "backend/internal/biz/ai"
	llmbiz "backend/internal/biz/llm"
	aidata "backend/internal/data/ai"
	llmdata "backend/internal/data/llm"
	"backend/internal/platform/apicomm"
	llmapp "backend/internal/service/llm"
	"backend/model"
	"backend/pkg/conf"
	"backend/pkg/llminference"
	kerrors "github.com/go-kratos/kratos/v2/errors"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type upstream struct {
	sync.Mutex
	models                           map[string]llminference.ModelInfo
	creates, deletes, shows, chats   int
	uncertainCreate, uncertainDelete bool
	started, proceed                 chan struct{}
	lastBody                         map[string]any
	lastAuth, lastCookie             string
}

func evidence() llminference.ModelInfo {
	return llminference.ModelInfo{Modelfile: "FROM /models/blobs/sha256-" + strings.Repeat("a", 64), Template: "{{ .System }} {{ .Prompt }}", Parameters: "temperature 0.7"}
}
func newUpstream(t *testing.T) (*upstream, *httptest.Server) {
	t.Helper()
	u := &upstream{models: map[string]llminference.ModelInfo{"base:latest": evidence()}}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := map[string]any{}
		if r.Body != nil && r.Method != http.MethodGet {
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, "bad JSON", 400)
				return
			}
		}
		name, _ := body["model"].(string)
		u.Lock()
		u.lastBody = body
		u.lastAuth = r.Header.Get("Authorization")
		u.lastCookie = r.Header.Get("Cookie")
		var response any
		status := 200
		uncertain := false
		var started, proceed chan struct{}
		switch r.URL.Path {
		case "/api/tags":
			items := []map[string]string{}
			for name := range u.models {
				items = append(items, map[string]string{"name": name})
			}
			response = map[string]any{"models": items}
		case "/api/show":
			u.shows++
			if info, ok := u.models[name]; ok {
				response = info
			} else {
				status = 404
				response = map[string]string{"error": "not found"}
			}
		case "/api/create":
			u.creates++
			info := evidence()
			info.System, _ = body["system"].(string)
			u.models[name] = info
			uncertain = u.uncertainCreate
			started, proceed = u.started, u.proceed
			response = map[string]string{"status": "success"}
		case "/api/delete":
			u.deletes++
			delete(u.models, name)
			uncertain = u.uncertainDelete
		case "/api/chat":
			u.chats++
			response = map[string]any{"message": map[string]string{"role": "assistant", "content": "hello"}, "done": true}
		default:
			status = 404
			response = map[string]string{"error": "bad path"}
		}
		u.Unlock()
		if started != nil {
			close(started)
			<-proceed
		}
		if uncertain {
			connection, _, err := w.(http.Hijacker).Hijack()
			if err == nil {
				_ = connection.Close()
			}
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		if response != nil {
			_ = json.NewEncoder(w).Encode(response)
		}
	}))
	t.Cleanup(server.Close)
	return u, server
}
func testDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "models.db")), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	if err = db.AutoMigrate(&model.AiUserConfig{}, &model.LLMManagedModel{}); err != nil {
		t.Fatal(err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	return db
}
func seed(t *testing.T, db *gorm.DB, owner uint, agents ...string) {
	t.Helper()
	cards := []map[string]any{}
	for _, agent := range agents {
		cards = append(cards, map[string]any{"id": agent, "name": "same display name", "model_name": "base:latest", "system_prompt": "prompt", "is_public": true, "created_by_user_id": "999"})
	}
	raw, err := json.Marshal(cards)
	if err != nil {
		t.Fatal(err)
	}
	if err = db.Create(&model.AiUserConfig{UserID: owner, AgentsJSON: string(raw), ProviderProfilesJSON: "[]", LorebooksJSON: "[]"}).Error; err != nil {
		t.Fatal(err)
	}
}
func user(id int) context.Context {
	return context.WithValue(context.Background(), "userId", strconv.Itoa(id))
}
func newService(db *gorm.DB, url string, limits conf.ModelManagement) *llmapp.AppService {
	return llmapp.New(db, llmapp.Deps{Inference: llminference.ConfigFrom(url, "ollama", 5, "base:latest", "upstream-secret"), ModelManagement: limits, UserID: apicomm.UserIDUint})
}
func create(agent, request string) llmbiz.CreateAgentInput {
	return llmbiz.CreateAgentInput{AgentID: agent, RequestID: request, Name: "FORGED-UPSTREAM-NAME", BaseModel: "base:latest", SystemPrompt: "prompt"}
}
func requireCode(t *testing.T, err error, code int) {
	t.Helper()
	if err == nil || int(kerrors.Code(err)) != code {
		t.Fatalf("want %d, got %v", code, err)
	}
}

func TestManagedOwnershipIdempotenceAndPublicProjection(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "card")
	seed(t, db, 2, "card")
	s := newService(db, server.URL, conf.ModelManagement{})
	first, err := s.UpsertManagedModel(user(1), create("card", "r1"))
	if err != nil || first.State != "ready" || !first.BindingApplied {
		t.Fatalf("create: %+v %v", first, err)
	}
	second, err := s.UpsertManagedModel(user(2), create("card", "r1"))
	if err != nil {
		t.Fatal(err)
	}
	if first.ModelName == second.ModelName || !strings.HasPrefix(first.ModelName, "moe-user-") {
		t.Fatal("names not isolated")
	}
	replay, err := s.UpsertManagedModel(user(1), create("card", "r1"))
	if err != nil || replay.ModelName != first.ModelName {
		t.Fatal(replay, err)
	}
	changed := create("card", "r1")
	changed.SystemPrompt = "different"
	_, err = s.UpsertManagedModel(user(1), changed)
	requireCode(t, err, 409)
	u.Lock()
	creates := u.creates
	u.Unlock()
	if creates != 2 {
		t.Fatalf("replayed write: %d", creates)
	}
	anonymous, err := s.ListModels(context.Background())
	if err != nil || len(anonymous) != 1 || anonymous[0] != "base:latest" {
		t.Fatal(anonymous, err)
	}
	own, err := s.ListModels(user(1))
	if err != nil || len(own) != 2 {
		t.Fatal(own, err)
	}
	for _, name := range []string{second.ModelName, "moe-user-guessed:latest"} {
		_, err = s.Chat(user(1), llmbiz.PlatformChatInput{Model: name})
		requireCode(t, err, 403)
	}
	_, err = s.UpsertManagedModel(context.Background(), create("card", "r2"))
	requireCode(t, err, 401)
	_, err = s.UpsertManagedModel(user(1), create("absent", "r2"))
	requireCode(t, err, 404)
	resources := aibiz.NewResourcesUsecase(aidata.NewStore(db))
	// Public projection does not require a users table or expose the private reference.
	projected, err := resources.ListPublicAgents(context.Background(), &aiv1.ListPublicAiAgentsReq{})
	if err != nil {
		t.Fatal(err)
	}
	for _, item := range projected.Items {
		if strings.Contains(item.PayloadJson, "moe-user-") || !strings.Contains(item.PayloadJson, "base:latest") {
			t.Fatal(item.PayloadJson)
		}
	}
	forged := fmt.Sprintf(`{"id":"card","model_name":%q}`, second.ModelName)
	_, err = resources.Upsert(user(1), "agents", &aiv1.UpsertAiResourceReq{UserId: "1", PayloadJson: forged})
	requireCode(t, err, 403)
	configBytes, _ := json.Marshal(s.ConfigAPIPayload())
	if strings.Contains(string(configBytes), "upstream-secret") || strings.Contains(string(configBytes), server.URL) {
		t.Fatal("config leaked secrets/address")
	}
}

func TestConcurrentQuotaAndSharedCoordinator(t *testing.T) {
	_, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a", "b")
	seed(t, db, 2, "c")
	limits := conf.ModelManagement{UserQuota: 1, GlobalQuota: 1, WriteConcurrency: 4}
	s1, s2 := newService(db, server.URL, limits), newService(db, server.URL, limits)
	results := make(chan error, 3)
	var wg sync.WaitGroup
	for i, input := range []struct {
		owner int
		agent string
	}{{1, "a"}, {1, "b"}, {2, "c"}} {
		wg.Add(1)
		go func(i int, owner int, agent string) {
			defer wg.Done()
			s := s1
			if i%2 == 1 {
				s = s2
			}
			_, err := s.UpsertManagedModel(user(owner), create(agent, "r1"))
			results <- err
		}(i, input.owner, input.agent)
	}
	wg.Wait()
	close(results)
	ok, limited := 0, 0
	for err := range results {
		if err == nil {
			ok++
		} else if kerrors.Code(err) == 429 {
			limited++
		} else {
			t.Fatal(err)
		}
	}
	if ok != 1 || limited != 2 {
		t.Fatalf("success=%d limited=%d", ok, limited)
	}
}

func TestBindingSnapshotAndBusyWrite(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a", "b")
	u.started = make(chan struct{})
	u.proceed = make(chan struct{})
	s1, s2 := newService(db, server.URL, conf.ModelManagement{}), newService(db, server.URL, conf.ModelManagement{})
	result := make(chan llmbiz.ManagedModelView, 1)
	errs := make(chan error, 1)
	go func() { view, err := s1.UpsertManagedModel(user(1), create("a", "r1")); result <- view; errs <- err }()
	<-u.started
	_, err := s2.UpsertManagedModel(user(1), create("b", "r2"))
	requireCode(t, err, 429)
	resources := aibiz.NewResourcesUsecase(aidata.NewStore(db))
	_, err = resources.Upsert(user(1), "agents", &aiv1.UpsertAiResourceReq{UserId: "1", PayloadJson: `{"id":"a","model_name":"base:latest","system_prompt":"edited later"}`})
	if err != nil {
		t.Fatal(err)
	}
	close(u.proceed)
	view := <-result
	if err = <-errs; err != nil || view.State != "ready" || view.BindingApplied {
		t.Fatal(view, err)
	}
	var cfg model.AiUserConfig
	if err = db.Where("user_id = ?", 1).First(&cfg).Error; err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(cfg.AgentsJSON, "edited later") || strings.Contains(cfg.AgentsJSON, view.ModelName) {
		t.Fatal(cfg.AgentsJSON)
	}
}

func TestUnknownRecoveryRestartAndDelete(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	u.uncertainCreate = true
	view, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil || view.State != "unknown" {
		t.Fatal(view, err)
	}
	_, err = s.UpsertManagedModel(user(1), create("a", "r2"))
	requireCode(t, err, 409)
	_, err = s.DeleteManagedModel(user(1), "a", "delete-1")
	requireCode(t, err, 409)
	replay, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil || replay.State != "unknown" {
		t.Fatal(replay, err)
	}
	// Simulate a restart between upstream success and local persistence.
	if err = db.Model(&model.LLMManagedModel{}).Where("owner_id = ?", 1).Update("state", "pending").Error; err != nil {
		t.Fatal(err)
	}
	s = newService(db, server.URL, conf.ModelManagement{})
	local, err := s.GetManagedModel(user(1), "a")
	if err != nil || local.State != "unknown" {
		t.Fatal(local, err)
	}
	ready, err := s.ReconcileManagedModel(user(1), "a")
	if err != nil || ready.State != "ready" || !ready.BindingApplied {
		t.Fatal(ready, err)
	}
	resources := aibiz.NewResourcesUsecase(aidata.NewStore(db))
	_, err = resources.Delete(user(1), "agents", &aiv1.DeleteAiResourceReq{UserId: "1", Id: "a"})
	if err != nil {
		t.Fatal(err)
	}
	list, err := s.ListManagedModels(user(1))
	if err != nil || len(list) != 1 {
		t.Fatal(list, err)
	}
	u.Lock()
	u.uncertainDelete = true
	u.Unlock()
	deleting, err := s.DeleteManagedModel(user(1), "a", "delete-1")
	if err != nil || deleting.State != "unknown" {
		t.Fatal(deleting, err)
	}
	deleted, err := s.ReconcileManagedModel(user(1), "a")
	if err != nil || deleted.State != "deleted" {
		t.Fatal(deleted, err)
	}
	_, err = s.DeleteManagedModel(user(1), "a", "delete-1")
	if err != nil {
		t.Fatal(err)
	}
	u.Lock()
	deletes, creates := u.deletes, u.creates
	u.Unlock()
	if deletes != 1 || creates != 1 {
		t.Fatalf("blind retry creates=%d deletes=%d", creates, deletes)
	}
}

func TestReconcileRequiresEvidenceAndEndpointScope(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	u.uncertainCreate = true
	view, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil {
		t.Fatal(err)
	}
	u.Lock()
	info := u.models[view.ModelName]
	info.Modelfile = "FROM base:latest"
	u.models[view.ModelName] = info
	u.Unlock()
	unknown, err := s.ReconcileManagedModel(user(1), "a")
	if err != nil || unknown.State != "unknown" {
		t.Fatal(unknown, err)
	}
	_, err = s.Chat(user(1), llmbiz.PlatformChatInput{Model: view.ModelName})
	requireCode(t, err, 403)
	different := newService(db, server.URL+"/different", conf.ModelManagement{})
	_, err = different.ReconcileManagedModel(user(1), "a")
	requireCode(t, err, 409)
	_, err = different.DeleteManagedModel(user(1), "a", "d1")
	requireCode(t, err, 409)
}

func TestRawAuthorizationAndSanitization(t *testing.T) {
	u, server := newUpstream(t)
	s := newService(nil, server.URL, conf.ModelManagement{})
	raw := `{"model":"base:latest","messages":[{"role":"user","content":"hi","images":["secret"]}],"options":{"temperature":0.5,"num_predict":999999,"num_gpu":900},"metadata":{"secret":true},"think":true}`
	req := httptest.NewRequest(http.MethodPost, "/chat", strings.NewReader(raw))
	req.Header.Set("Authorization", "Bearer SITE-JWT")
	req.Header.Set("Cookie", "secret=cookie")
	if err := s.ForwardChatRaw(httptest.NewRecorder(), req); err != nil {
		t.Fatal(err)
	}
	u.Lock()
	body, auth, cookie := u.lastBody, u.lastAuth, u.lastCookie
	u.Unlock()
	options := body["options"].(map[string]any)
	if options["num_predict"] != float64(4096) || options["num_gpu"] != nil || body["metadata"] != nil || body["think"] != false {
		t.Fatal(body)
	}
	if auth != "Bearer upstream-secret" || cookie != "" {
		t.Fatalf("headers %q %q", auth, cookie)
	}
	for _, name := range []string{"moe-user-forged:latest", "other-base"} {
		req := httptest.NewRequest(http.MethodPost, "/chat", strings.NewReader(fmt.Sprintf(`{"model":%q,"messages":[{"role":"user","content":"x"}]}`, name)))
		err := s.ForwardChatRaw(httptest.NewRecorder(), req)
		requireCode(t, err, 403)
	}
	req = httptest.NewRequest(http.MethodPost, "/show", strings.NewReader(strings.Repeat("x", (1<<20)+1)))
	requireCode(t, s.ForwardShowRaw(httptest.NewRecorder(), req), 413)
	_, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	requireCode(t, err, 503)
}

func TestStoreFailureIsNotSuccess(t *testing.T) {
	_, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	if err = sqlDB.Close(); err != nil {
		t.Fatal(err)
	}
	_, err = s.UpsertManagedModel(user(1), create("a", "r1"))
	requireCode(t, err, 503)
	_, err = s.ListManagedModels(user(1))
	requireCode(t, err, 503)
}

func TestQuotaReleasedOnlyAfterConfirmedDelete(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a", "b")
	s := newService(db, server.URL, conf.ModelManagement{UserQuota: 1})
	first, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil {
		t.Fatal(err)
	}
	_, err = s.UpsertManagedModel(user(1), create("b", "r2"))
	requireCode(t, err, 429)
	u.Lock()
	u.uncertainDelete = true
	u.Unlock()
	_, err = s.DeleteManagedModel(user(1), "a", "d1")
	if err != nil {
		t.Fatal(err)
	}
	_, err = s.UpsertManagedModel(user(1), create("b", "r2"))
	requireCode(t, err, 429)
	_, err = s.ReconcileManagedModel(user(1), "a")
	if err != nil {
		t.Fatal(err)
	}
	next, err := s.UpsertManagedModel(user(1), create("b", "r2"))
	if err != nil || next.State != "ready" {
		t.Fatal(next, err)
	}
	// A confirmed deletion also clears only the matching card binding.
	var cfg model.AiUserConfig
	if err = db.Where("user_id = ?", 1).First(&cfg).Error; err != nil {
		t.Fatal(err)
	}
	if strings.Contains(cfg.AgentsJSON, first.ModelName) {
		t.Fatal(cfg.AgentsJSON)
	}
}

func TestDelayedRequestCannotOverwriteNewIntent(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	_, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil {
		t.Fatal(err)
	}
	changed := create("a", "r2")
	changed.SystemPrompt = "new prompt"
	_, err = s.UpsertManagedModel(user(1), changed)
	if err != nil {
		t.Fatal(err)
	}
	replay, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil || replay.RequestID != "r2" {
		t.Fatal(replay, err)
	}
	u.Lock()
	creates := u.creates
	u.Unlock()
	if creates != 2 {
		t.Fatal("old request re-executed")
	}
	changed.RequestID = "r1"
	_, err = s.UpsertManagedModel(user(1), changed)
	requireCode(t, err, 409)
}

func TestSuccessfulUpstreamWithFailedPersistenceStaysUnknown(t *testing.T) {
	_, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	if err := db.Callback().Update().Before("gorm:update").Register("fail_ready", func(tx *gorm.DB) {
		if row, ok := tx.Statement.Dest.(*model.LLMManagedModel); ok && row.State == "ready" {
			tx.AddError(fmt.Errorf("injected DB failure"))
		}
	}); err != nil {
		t.Fatal(err)
	}
	_, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	requireCode(t, err, 503)
	view, err := s.GetManagedModel(user(1), "a")
	if err != nil || view.State != "unknown" || view.BindingApplied {
		t.Fatal(view, err)
	}
	var cfg model.AiUserConfig
	if err = db.Where("user_id = ?", 1).First(&cfg).Error; err != nil {
		t.Fatal(err)
	}
	if strings.Contains(cfg.AgentsJSON, view.ModelName) {
		t.Fatal("binding transaction did not roll back")
	}
}

func TestOpenAIRawAndWrappedErrors(t *testing.T) {
	var received map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			http.Error(w, "wrong path", 404)
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			http.Error(w, "bad request", 400)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"ok"}}]}`))
	}))
	defer server.Close()
	s := llmapp.New(nil, llmapp.Deps{Inference: llminference.ConfigFrom(server.URL+"/v1", "openai", 2, "base:latest", "")})
	req := httptest.NewRequest(http.MethodPost, "/chat", strings.NewReader(`{"model":"base:latest","messages":[{"role":"user","content":"hi"}],"max_tokens":123,"metadata":{"secret":true}}`))
	recorder := httptest.NewRecorder()
	if err := s.ForwardChatRaw(recorder, req); err != nil {
		t.Fatal(err)
	}
	if received["max_tokens"] != float64(123) || received["metadata"] != nil || received["options"] != nil || !strings.Contains(recorder.Body.String(), "choices") {
		t.Fatal(received, recorder.Body.String())
	}
	requireCode(t, s.ForwardShowRaw(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/show", strings.NewReader(`{"model":"base:latest"}`))), 400)
	_, err := llmbiz.ExecutePlatformChat(context.Background(), llmbiz.PlatformChatDeps{Inference: llminference.ConfigFrom(server.URL, "ollama", 2, "base:latest", ""), ChatComplete: func(_ context.Context, _ string, _ []llminference.Message, opts llminference.ChatOptions) (string, error) {
		if opts.RepeatPenalty != 1.2 {
			t.Error("lost repeat penalty")
		}
		return "", &llminference.UpstreamError{StatusCode: 503, Message: "offline"}
	}}, llmbiz.PlatformChatInput{RepeatPenalty: 1.2})
	requireCode(t, err, 503)
}

func TestUniqueOwnerAgentConstraint(t *testing.T) {
	db := testDB(t)
	row := model.LLMManagedModel{OwnerID: 1, AgentID: "a", ManagedName: "moe-user-one", State: "unknown"}
	if err := db.Create(&row).Error; err != nil {
		t.Fatal(err)
	}
	row.ID = 0
	row.ManagedName = "moe-user-two"
	if err := db.Create(&row).Error; err == nil {
		t.Fatal("missing unique owner+agent constraint")
	}
	store := llmdata.NewStore(db)
	rows, err := store.List(context.Background(), 1)
	if err != nil || len(rows) != 1 {
		t.Fatal(rows, err)
	}
}

// 已确认创建成功的模型重查时必须保持 ready：Ollama 可能不回 blob 层证据，
// 把它降级成 unknown 会让一个健康模型变得不可用。上游真的消失了才算失败。
func TestReconcileKeepsConfirmedReadyModel(t *testing.T) {
	u, server := newUpstream(t)
	db := testDB(t)
	seed(t, db, 1, "a")
	s := newService(db, server.URL, conf.ModelManagement{})
	view, err := s.UpsertManagedModel(user(1), create("a", "r1"))
	if err != nil || view.State != "ready" {
		t.Fatal(view, err)
	}

	u.Lock()
	info := u.models[view.ModelName]
	info.Modelfile = "FROM base:latest" // 去掉 sha256 层证据
	u.models[view.ModelName] = info
	u.Unlock()
	kept, err := s.ReconcileManagedModel(user(1), "a")
	if err != nil || kept.State != "ready" || !kept.BindingApplied {
		t.Fatalf("重查不应降级已确认模型: %v %v", kept, err)
	}
	if _, err = s.Chat(user(1), llmbiz.PlatformChatInput{Model: view.ModelName}); err != nil {
		t.Fatalf("ready 模型应可对话: %v", err)
	}

	u.Lock()
	delete(u.models, view.ModelName)
	u.Unlock()
	gone, err := s.ReconcileManagedModel(user(1), "a")
	if err != nil {
		t.Fatal(err)
	}
	if gone.State != "failed" || !gone.Retryable {
		t.Fatalf("上游模型消失后应可重建: %v", gone)
	}
	_, err = s.Chat(user(1), llmbiz.PlatformChatInput{Model: view.ModelName})
	requireCode(t, err, 403)
}
