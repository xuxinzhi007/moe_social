package checkinv1

import "backend/rpc/pb/moe"

func GetCheckInStatusRequestFromMoe(in *moe.GetCheckInStatusReq) *GetCheckInStatusRequest {
	if in == nil {
		return &GetCheckInStatusRequest{}
	}
	return &GetCheckInStatusRequest{UserId: in.GetUserId()}
}

func GetCheckInStatusReplyToMoe(out *GetCheckInStatusReply) *moe.GetCheckInStatusResp {
	if out == nil {
		return &moe.GetCheckInStatusResp{}
	}
	return &moe.GetCheckInStatusResp{Status: CheckInStatusToMoe(out.GetStatus())}
}

func CheckInRequestFromMoe(in *moe.CheckInReq) *CheckInRequest {
	if in == nil {
		return &CheckInRequest{}
	}
	return &CheckInRequest{UserId: in.GetUserId()}
}

func CheckInReplyToMoe(out *CheckInReply) *moe.CheckInResp {
	if out == nil {
		return &moe.CheckInResp{}
	}
	return &moe.CheckInResp{
		ExpGained:       out.GetExpGained(),
		NewLevel:        out.GetNewLevel(),
		ConsecutiveDays: out.GetConsecutiveDays(),
		LevelUp:         out.GetLevelUp(),
		SpecialReward:   out.GetSpecialReward(),
		NewAchievements: AchievementUnlocksToMoe(out.GetNewAchievements()),
	}
}

func GetCheckInHistoryRequestFromMoe(in *moe.GetCheckInHistoryReq) *GetCheckInHistoryRequest {
	if in == nil {
		return &GetCheckInHistoryRequest{}
	}
	return &GetCheckInHistoryRequest{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetCheckInHistoryReplyToMoe(out *GetCheckInHistoryReply) *moe.GetCheckInHistoryResp {
	if out == nil {
		return &moe.GetCheckInHistoryResp{}
	}
	return &moe.GetCheckInHistoryResp{
		Records: CheckInRecordsToMoe(out.GetRecords()),
		Total:   out.GetTotal(),
	}
}

func GetExpLogsRequestFromMoe(in *moe.GetExpLogsReq) *GetExpLogsRequest {
	if in == nil {
		return &GetExpLogsRequest{}
	}
	return &GetExpLogsRequest{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetExpLogsReplyToMoe(out *GetExpLogsReply) *moe.GetExpLogsResp {
	if out == nil {
		return &moe.GetExpLogsResp{}
	}
	return &moe.GetExpLogsResp{
		Logs:  ExpLogRecordsToMoe(out.GetLogs()),
		Total: out.GetTotal(),
	}
}

func GetUserLevelRequestFromMoe(in *moe.GetUserLevelReq) *GetUserLevelRequest {
	if in == nil {
		return &GetUserLevelRequest{}
	}
	return &GetUserLevelRequest{UserId: in.GetUserId()}
}

func GetUserLevelReplyToMoe(out *GetUserLevelReply) *moe.GetUserLevelResp {
	if out == nil {
		return &moe.GetUserLevelResp{}
	}
	return &moe.GetUserLevelResp{LevelInfo: UserLevelInfoToMoe(out.GetLevelInfo())}
}

func CheckInStatusFromMoe(s *moe.CheckInStatus) *CheckInStatus {
	if s == nil {
		return nil
	}
	return &CheckInStatus{
		HasCheckedToday: s.GetHasCheckedToday(),
		ConsecutiveDays: s.GetConsecutiveDays(),
		TodayReward:     s.GetTodayReward(),
		NextDayReward:   s.GetNextDayReward(),
		CanCheckIn:      s.GetCanCheckIn(),
	}
}

func CheckInStatusToMoe(s *CheckInStatus) *moe.CheckInStatus {
	if s == nil {
		return nil
	}
	return &moe.CheckInStatus{
		HasCheckedToday: s.GetHasCheckedToday(),
		ConsecutiveDays: s.GetConsecutiveDays(),
		TodayReward:     s.GetTodayReward(),
		NextDayReward:   s.GetNextDayReward(),
		CanCheckIn:      s.GetCanCheckIn(),
	}
}

func UserLevelInfoFromMoe(i *moe.UserLevelInfo) *UserLevelInfo {
	if i == nil {
		return nil
	}
	return &UserLevelInfo{
		Level: i.GetLevel(), Experience: i.GetExperience(), TotalExp: i.GetTotalExp(),
		NextLevelExp: i.GetNextLevelExp(), LevelTitle: i.GetLevelTitle(),
		BadgeUrl: i.GetBadgeUrl(), Progress: i.GetProgress(),
	}
}

func UserLevelInfoToMoe(i *UserLevelInfo) *moe.UserLevelInfo {
	if i == nil {
		return nil
	}
	return &moe.UserLevelInfo{
		Level: i.GetLevel(), Experience: i.GetExperience(), TotalExp: i.GetTotalExp(),
		NextLevelExp: i.GetNextLevelExp(), LevelTitle: i.GetLevelTitle(),
		BadgeUrl: i.GetBadgeUrl(), Progress: i.GetProgress(),
	}
}

func CheckInRecordsFromMoe(rec []*moe.CheckInRecord) []*CheckInRecord {
	if len(rec) == 0 {
		return nil
	}
	out := make([]*CheckInRecord, 0, len(rec))
	for _, r := range rec {
		if r == nil {
			continue
		}
		out = append(out, &CheckInRecord{
			CheckInDate: r.GetCheckInDate(), ConsecutiveDays: r.GetConsecutiveDays(),
			ExpReward: r.GetExpReward(), IsSpecialReward: r.GetIsSpecialReward(),
			SpecialRewardDesc: r.GetSpecialRewardDesc(),
		})
	}
	return out
}

func CheckInRecordsToMoe(rec []*CheckInRecord) []*moe.CheckInRecord {
	if len(rec) == 0 {
		return nil
	}
	out := make([]*moe.CheckInRecord, 0, len(rec))
	for _, r := range rec {
		if r == nil {
			continue
		}
		out = append(out, &moe.CheckInRecord{
			CheckInDate: r.GetCheckInDate(), ConsecutiveDays: r.GetConsecutiveDays(),
			ExpReward: r.GetExpReward(), IsSpecialReward: r.GetIsSpecialReward(),
			SpecialRewardDesc: r.GetSpecialRewardDesc(),
		})
	}
	return out
}

func ExpLogRecordsFromMoe(logs []*moe.ExpLogRecord) []*ExpLogRecord {
	if len(logs) == 0 {
		return nil
	}
	out := make([]*ExpLogRecord, 0, len(logs))
	for _, l := range logs {
		if l == nil {
			continue
		}
		out = append(out, &ExpLogRecord{
			Id: l.GetId(), ExpChange: l.GetExpChange(), Source: l.GetSource(),
			Description: l.GetDescription(), CreatedAt: l.GetCreatedAt(),
		})
	}
	return out
}

func ExpLogRecordsToMoe(logs []*ExpLogRecord) []*moe.ExpLogRecord {
	if len(logs) == 0 {
		return nil
	}
	out := make([]*moe.ExpLogRecord, 0, len(logs))
	for _, l := range logs {
		if l == nil {
			continue
		}
		out = append(out, &moe.ExpLogRecord{
			Id: l.GetId(), ExpChange: l.GetExpChange(), Source: l.GetSource(),
			Description: l.GetDescription(), CreatedAt: l.GetCreatedAt(),
		})
	}
	return out
}

func AchievementUnlocksFromMoe(items []*moe.AchievementUnlock) []*AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &AchievementUnlock{
			BadgeId: u.GetBadgeId(), Name: u.GetName(), ExpGranted: u.GetExpGranted(),
			LevelUp: u.GetLevelUp(), NewLevel: u.GetNewLevel(),
		})
	}
	return out
}

func AchievementUnlocksToMoe(items []*AchievementUnlock) []*moe.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &moe.AchievementUnlock{
			BadgeId: u.GetBadgeId(), Name: u.GetName(), ExpGranted: u.GetExpGranted(),
			LevelUp: u.GetLevelUp(), NewLevel: u.GetNewLevel(),
		})
	}
	return out
}
