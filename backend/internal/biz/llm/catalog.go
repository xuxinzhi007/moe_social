package llmbiz

import (
	"fmt"

	"backend/pkg/localmodels"
)

// CatalogItem HTTP 层可用的本地模型目录项。
type CatalogItem struct {
	ID           string
	Name         string
	Filename     string
	SizeBytes    int64
	Sha256       string
	Description  string
	ParametersB  float64
	Recommended  bool
	DownloadPath string
}

// LoadLocalCatalog 加载本地 GGUF 目录。
func LoadLocalCatalog(storageDir string, entries []localmodels.CatalogEntry) ([]CatalogItem, error) {
	items, err := localmodels.LoadCatalog(storageDir, entries)
	if err != nil {
		return nil, err
	}
	out := make([]CatalogItem, 0, len(items))
	for _, item := range items {
		out = append(out, CatalogItem{
			ID:           item.ID,
			Name:         item.Name,
			Filename:     item.Filename,
			SizeBytes:    item.SizeBytes,
			Sha256:       item.Sha256,
			Description:  item.Description,
			ParametersB:  item.ParametersB,
			Recommended:  item.Recommended,
			DownloadPath: fmt.Sprintf("/api/llm/local-models/%s/download", item.ID),
		})
	}
	return out, nil
}
