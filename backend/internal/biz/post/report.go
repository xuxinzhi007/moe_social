package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// Report 提交帖子举报。
func Report(ctx context.Context, st PostStore, postIDStr, reporterIDStr, reason string) error {
	if st == nil {
		return gorm.ErrInvalidDB
	}
	if strings.TrimSpace(postIDStr) == "" {
		return ErrInvalidPostID
	}
	if strings.TrimSpace(reporterIDStr) == "" {
		return ErrEmptyReporterID
	}
	if strings.TrimSpace(reason) == "" {
		return ErrEmptyReason
	}

	postID, err := strconv.ParseUint(strings.TrimSpace(postIDStr), 10, 32)
	if err != nil || postID == 0 {
		return ErrInvalidPostID
	}
	reporterID, err := strconv.ParseUint(strings.TrimSpace(reporterIDStr), 10, 32)
	if err != nil || reporterID == 0 {
		return ErrInvalidUserID
	}

	st = st.WithContext(ctx)
	if _, err := st.GetPost(ctx, uint(postID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrPostNotFound
		}
		return err
	}

	rep := model.PostReport{
		PostID:         uint(postID),
		ReporterUserID: uint(reporterID),
		Reason:         strings.TrimSpace(reason),
	}
	return st.CreatePostReport(ctx, &rep)
}
