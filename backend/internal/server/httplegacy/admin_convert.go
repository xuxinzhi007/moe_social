package httplegacy

import (
	"strconv"
	"strings"

	"backend/internal/legacy/types"
	"backend/rpc/pb/moe"
)

func parseAdminPathID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, strconv.ErrSyntax
	}
	return strconv.ParseUint(raw, 10, 64)
}

func adminPageOrDefault(page, def int) int {
	if page <= 0 {
		return def
	}
	return page
}

func adminPageSizeOrDefault(pageSize, def int) int {
	if pageSize <= 0 {
		return def
	}
	return pageSize
}

func rpcAdminPostReportToTypes(r *moe.AdminPostReportItem) types.AdminPostReportItem {
	if r == nil {
		return types.AdminPostReportItem{}
	}
	return types.AdminPostReportItem{
		Id:                 r.GetId(),
		PostId:             r.GetPostId(),
		ReporterUserId:     r.GetReporterUserId(),
		Reason:             r.GetReason(),
		CreatedAt:          r.GetCreatedAt(),
		PostContentPreview: r.GetPostContentPreview(),
	}
}
