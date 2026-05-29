package adminbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	adminv1 "backend/api/admin/v1"
	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

// ListFollows Admin 关注列表。
func ListFollows(ctx context.Context, db *gorm.DB, in *adminv1.AdminListFollowsReq) (*adminv1.AdminListFollowsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := db.WithContext(ctx).Model(&model.Follow{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		id, err := strconv.ParseUint(uid, 10, 64)
		if err != nil {
			return nil, ErrInvalidFollowUserID
		}
		q = q.Where("follower_id = ? OR following_id = ?", id, id)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		userIDs, err := followKeywordUserIDs(db.WithContext(ctx), kw)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrListFollows, err)
		}
		if len(userIDs) == 0 {
			return &adminv1.AdminListFollowsResp{Items: nil, Total: 0}, nil
		}
		q = q.Where("follower_id IN ? OR following_id IN ?", userIDs, userIDs)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListFollows, err)
	}
	var rows []model.Follow
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListFollows, err)
	}

	items := make([]*adminv1.AdminFollowItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, &adminv1.AdminFollowItem{
			Id:            strconv.FormatUint(uint64(row.ID), 10),
			FollowerId:    fmt.Sprint(row.FollowerID),
			FollowerName:  adminUserDisplayName(db, row.FollowerID),
			FollowingId:   fmt.Sprint(row.FollowingID),
			FollowingName: adminUserDisplayName(db, row.FollowingID),
			CreatedAt:     row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &adminv1.AdminListFollowsResp{Items: items, Total: int32(total)}, nil
}

func followKeywordUserIDs(db *gorm.DB, kw string) ([]uint, error) {
	kw = strings.TrimSpace(kw)
	if kw == "" {
		return nil, nil
	}
	like := "%" + kw + "%"
	q := db.Model(&model.User{}).Where("username LIKE ? OR email LIKE ?", like, like)
	if id, err := strconv.ParseUint(kw, 10, 64); err == nil {
		q = q.Or("id = ?", id)
	}
	var ids []uint
	if err := q.Pluck("id", &ids).Error; err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		if id, err := strconv.ParseUint(kw, 10, 64); err == nil {
			return []uint{uint(id)}, nil
		}
	}
	return ids, nil
}

// ListPosts Admin 动态列表。
func ListPosts(ctx context.Context, db *gorm.DB, in *adminv1.AdminListPostsReq) (*adminv1.AdminListPostsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := db.WithContext(ctx).Model(&model.Post{})
	if in.GetIncludeDeleted() {
		q = q.Unscoped()
	}
	if st := strings.TrimSpace(in.GetModerationStatus()); st != "" {
		q = q.Where("moderation_status = ?", st)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		q = q.Where("content LIKE ?", "%"+kw+"%")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPosts, err)
	}

	var rows []model.Post
	offset := int((page - 1) * pageSize)
	if err := q.
		Select(`id, user_id, content, images, hand_draw_thumb_url, moderation_status, mood_tag, likes, comments, created_at, updated_at, deleted_at, (CASE WHEN hand_draw_card IS NOT NULL AND hand_draw_card <> '' THEN 1 ELSE 0 END) AS has_hand_draw`).
		Preload("TopicTags").
		Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPosts, err)
	}

	userMap := map[uint]model.User{}
	if len(rows) > 0 {
		userIDs := make([]uint, 0, len(rows))
		for _, p := range rows {
			userIDs = append(userIDs, p.UserID)
		}
		var users []model.User
		_ = db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	posts := make([]*adminv1.Post, len(rows))
	for i, post := range rows {
		posts[i] = postModelToAdminV1ForList(post, userMap[post.UserID], false)
	}
	return &adminv1.AdminListPostsResp{Posts: posts, Total: int32(total)}, nil
}

// ListComments Admin 评论列表。
func ListComments(ctx context.Context, db *gorm.DB, in *adminv1.AdminListCommentsReq) (*adminv1.AdminListCommentsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.Comment{}).Unscoped()
	if pid := strings.TrimSpace(in.GetPostId()); pid != "" {
		if n, err := strconv.ParseUint(pid, 10, 64); err == nil && n > 0 {
			q = q.Where("post_id = ?", n)
		}
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		q = q.Where("content LIKE ?", "%"+kw+"%")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListComments, err)
	}

	var rows []model.Comment
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListComments, err)
	}

	userMap := map[uint]model.User{}
	if len(rows) > 0 {
		userIDs := make([]uint, 0, len(rows))
		for _, c := range rows {
			userIDs = append(userIDs, c.UserID)
		}
		var users []model.User
		_ = db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	comments := make([]*adminv1.Comment, 0, len(rows))
	for _, c := range rows {
		username := "未知用户"
		avatar := "https://picsum.photos/150"
		if u, ok := userMap[c.UserID]; ok {
			if u.Username != "" {
				username = u.Username
			} else if u.Email != "" {
				username = u.Email
			}
			if u.Avatar != "" {
				avatar = u.Avatar
			}
		}
		comments = append(comments, &adminv1.Comment{
			Id:         strconv.FormatUint(uint64(c.ID), 10),
			PostId:     strconv.FormatUint(uint64(c.PostID), 10),
			UserId:     strconv.FormatUint(uint64(c.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    c.Content,
			Likes:      int32(c.Likes),
			CreatedAt:  utils.FormatAPIDateTime(c.CreatedAt),
			ParentId:   strconv.FormatUint(uint64(c.ParentID), 10),
		})
	}
	return &adminv1.AdminListCommentsResp{Comments: comments, Total: int32(total)}, nil
}

// ListGroups Admin 社区列表。
func ListGroups(ctx context.Context, db *gorm.DB, in *adminv1.AdminListGroupsReq) (*adminv1.AdminListGroupsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.Group{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListGroups, err)
	}

	var rows []model.Group
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListGroups, err)
	}

	groups := make([]*adminv1.Group, len(rows))
	for i, group := range rows {
		creatorName := adminUserDisplayName(db, group.CreatorID)
		groups[i] = &adminv1.Group{
			Id:          uint64(group.ID),
			Name:        group.Name,
			Description: group.Description,
			Avatar:      group.Avatar,
			Cover:       group.Cover,
			CreatorId:   uint64(group.CreatorID),
			CreatorName: creatorName,
			MemberCount: int32(group.MemberCount),
			IsPublic:    group.IsPublic,
			Status:      group.Status,
			CreatedAt:   group.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}
	return &adminv1.AdminListGroupsResp{Groups: groups, Total: int32(total)}, nil
}

// ListFriendRequests Admin 好友申请列表。
func ListFriendRequests(ctx context.Context, db *gorm.DB, in *adminv1.AdminListFriendRequestsReq) (*adminv1.AdminListFriendRequestsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := db.WithContext(ctx).Model(&model.FriendRequest{})
	if st := strings.TrimSpace(in.GetStatus()); st != "" {
		q = q.Where("status = ?", st)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListFriendRequests, err)
	}
	var rows []model.FriendRequest
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListFriendRequests, err)
	}

	kw := strings.ToLower(strings.TrimSpace(in.GetKeyword()))
	items := make([]*adminv1.AdminFriendRequestItem, 0, len(rows))
	for _, row := range rows {
		fromName := adminUserDisplayName(db, row.FromUserID)
		toName := adminUserDisplayName(db, row.ToUserID)
		if kw != "" {
			match := strings.Contains(strings.ToLower(fromName), kw) ||
				strings.Contains(strings.ToLower(toName), kw) ||
				strings.Contains(fmt.Sprint(row.FromUserID), kw) ||
				strings.Contains(fmt.Sprint(row.ToUserID), kw)
			if !match {
				continue
			}
		}
		items = append(items, &adminv1.AdminFriendRequestItem{
			Id:           strconv.FormatUint(uint64(row.ID), 10),
			FromUserId:   fmt.Sprint(row.FromUserID),
			FromUserName: fromName,
			ToUserId:     fmt.Sprint(row.ToUserID),
			ToUserName:   toName,
			Status:       row.Status,
			CreatedAt:    row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &adminv1.AdminListFriendRequestsResp{Items: items, Total: int32(total)}, nil
}

// ListPostReports Admin 举报列表。
func ListPostReports(ctx context.Context, db *gorm.DB, in *adminv1.AdminListPostReportsReq) (*adminv1.AdminListPostReportsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.PostReport{})
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPostReports, err)
	}

	var rows []model.PostReport
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPostReports, err)
	}

	postMap := map[uint]model.Post{}
	userMap := map[uint]model.User{}
	if len(rows) > 0 {
		postIDs := make([]uint, 0, len(rows))
		userIDs := make([]uint, 0, len(rows)*2)
		for _, r := range rows {
			postIDs = append(postIDs, r.PostID)
			userIDs = append(userIDs, r.ReporterUserID)
		}
		var posts []model.Post
		_ = db.WithContext(ctx).Unscoped().
			Select(`id, user_id, content, images, hand_draw_thumb_url, (CASE WHEN hand_draw_card IS NOT NULL AND hand_draw_card <> '' THEN 1 ELSE 0 END) AS has_hand_draw`).
			Where("id IN ?", postIDs).Find(&posts).Error
		for _, p := range posts {
			postMap[p.ID] = p
			userIDs = append(userIDs, p.UserID)
		}
		var users []model.User
		_ = db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	reports := make([]*adminv1.AdminPostReportItem, len(rows))
	for i, r := range rows {
		post := postMap[r.PostID]
		reporter := userMap[r.ReporterUserID]
		author := userMap[post.UserID]
		var images []string
		if post.Images != "" {
			_ = json.Unmarshal([]byte(post.Images), &images)
		}
		reports[i] = &adminv1.AdminPostReportItem{
			Id:                 strconv.FormatUint(uint64(r.ID), 10),
			PostId:             strconv.FormatUint(uint64(r.PostID), 10),
			ReporterUserId:     strconv.FormatUint(uint64(r.ReporterUserID), 10),
			Reason:             r.Reason,
			CreatedAt:          r.CreatedAt.Format("2006-01-02 15:04:05"),
			PostContentPreview: previewContent(post.Content),
			PostContent:        post.Content,
			ReporterUserName:   adminUserLabel(reporter),
			ReporterUserAvatar: adminUserAvatar(reporter),
			PostAuthorId:       strconv.FormatUint(uint64(post.UserID), 10),
			PostAuthorName:     adminUserLabel(author),
			PostAuthorAvatar:   adminUserAvatar(author),
			PostImages:         images,
			HandDrawThumbUrl:   post.HandDrawThumbURL,
			HasHandDraw:        post.HasHandDraw || post.HandDrawThumbURL != "" || post.HandDrawCard != "",
		}
	}
	return &adminv1.AdminListPostReportsResp{Reports: reports, Total: int32(total)}, nil
}

// ListMemories Admin 记忆列表。
func ListMemories(ctx context.Context, db *gorm.DB, in *adminv1.AdminListMemoriesReq) (*adminv1.AdminListMemoriesResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := db.WithContext(ctx).Model(&model.UserMemory{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	if mt := strings.TrimSpace(in.GetMemoryType()); mt != "" {
		q = q.Where("memory_type = ?", mt)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("`key` LIKE ? OR `value` LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListMemories, err)
	}
	var rows []model.UserMemory
	offset := int((page - 1) * pageSize)
	if err := q.Order("updated_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListMemories, err)
	}
	names := loadMemoryUsernames(db.WithContext(ctx), rows)
	items := make([]*adminv1.AdminMemoryItem, len(rows))
	for i, row := range rows {
		items[i] = memoryToAdminProto(row, names[row.UserID])
	}
	return &adminv1.AdminListMemoriesResp{Items: items, Total: int32(total)}, nil
}

func loadMemoryUsernames(db *gorm.DB, rows []model.UserMemory) map[uint]string {
	out := make(map[uint]string)
	if db == nil || len(rows) == 0 {
		return out
	}
	ids := make([]uint, 0, len(rows))
	seen := map[uint]struct{}{}
	for _, row := range rows {
		if _, ok := seen[row.UserID]; ok {
			continue
		}
		seen[row.UserID] = struct{}{}
		ids = append(ids, row.UserID)
	}
	var users []model.User
	if err := db.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return out
	}
	for _, u := range users {
		out[u.ID] = u.Username
	}
	return out
}
