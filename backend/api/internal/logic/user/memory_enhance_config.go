package user

import (
	"backend/pkg/memory"
	"backend/pkg/memory/embed"
)

func loadMemoryEnhanceConfig() memory.EnhanceConfig {
	hc, rc, gc := embed.LoadEnhanceConfig()
	ec := memory.DefaultEnhanceConfig()
	ec.Hybrid = memory.HybridConfig{
		VectorWeight:  hc.VectorWeight,
		KeywordWeight: hc.KeywordWeight,
	}
	ec.Rerank = memory.RerankConfig{
		Enabled:    rc.Enabled,
		TopK:       rc.TopK,
		MMRLambda:  rc.MMRLambda,
		RecencyMax: 0.15,
		ConfBoost:  0.1,
	}
	ec.Graph = memory.GraphConfig{
		Enabled:   gc.Enabled,
		Hops:      gc.Hops,
		Boost:     gc.Boost,
		MaxExpand: gc.MaxExpand,
	}
	return ec
}
