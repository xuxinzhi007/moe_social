package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListMemories(ctx context.Context, in *adminv1.AdminListMemoriesReq) (*adminv1.AdminListMemoriesResp, error) {
	out, err := adminbiz.ListMemories(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteMemory(ctx context.Context, in *adminv1.AdminDeleteMemoryReq) (*adminv1.AdminDeleteMemoryResp, error) {
	out, err := adminbiz.DeleteMemory(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetMemoryStats(ctx context.Context, in *adminv1.AdminGetMemoryStatsReq) (*adminv1.AdminGetMemoryStatsResp, error) {
	out, err := adminbiz.GetMemoryStats(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetMemoryHealth(ctx context.Context, in *adminv1.AdminGetMemoryHealthReq) (*adminv1.AdminGetMemoryHealthResp, error) {
	out, err := adminbiz.GetMemoryHealth(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) RebuildMemoryEmbeddings(ctx context.Context, in *adminv1.AdminRebuildMemoryEmbeddingsReq) (*adminv1.AdminRebuildMemoryEmbeddingsResp, error) {
	out, err := adminbiz.RebuildMemoryEmbeddings(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ExportLearningDataset(ctx context.Context, in *adminv1.AdminExportLearningDatasetReq) (*adminv1.AdminExportLearningDatasetResp, error) {
	out, err := adminbiz.ExportLearningDataset(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
