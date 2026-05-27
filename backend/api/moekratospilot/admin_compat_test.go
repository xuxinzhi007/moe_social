package moekratospilot

import (
	"encoding/json"
	"testing"

	"backend/api/internal/types"
)

func TestAdminListRuntimesRespJSONShape(t *testing.T) {
	resp := types.AdminListMoeRuntimesResp{
		BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
		Data:     types.AdminListMoeRuntimesData{Items: []types.MoeAgentRuntimeItem{}},
	}
	b, err := json.Marshal(resp)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "message", "data"} {
		if _, ok := m[key]; !ok {
			t.Fatalf("missing top-level %q", key)
		}
	}
}
