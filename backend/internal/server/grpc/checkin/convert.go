package checkingrpc

import (
	checkinv1 "backend/api/checkin/v1"
	moerpc "backend/rpc/pb/moe"
)

func userLevelToProto(in *moerpc.UserLevelInfo) *checkinv1.UserLevelInfo {
	if in == nil {
		return nil
	}
	return &checkinv1.UserLevelInfo{
		Level: in.GetLevel(), Experience: in.GetExperience(), TotalExp: in.GetTotalExp(),
		NextLevelExp: in.GetNextLevelExp(), LevelTitle: in.GetLevelTitle(),
		BadgeUrl: in.GetBadgeUrl(), Progress: in.GetProgress(),
	}
}

func checkInStatusToProto(in *moerpc.CheckInStatus) *checkinv1.CheckInStatus {
	if in == nil {
		return nil
	}
	return &checkinv1.CheckInStatus{
		HasCheckedToday: in.GetHasCheckedToday(), ConsecutiveDays: in.GetConsecutiveDays(),
		TodayReward: in.GetTodayReward(), NextDayReward: in.GetNextDayReward(),
		CanCheckIn: in.GetCanCheckIn(),
	}
}

func checkInRecordsToProto(rows []*moerpc.CheckInRecord) []*checkinv1.CheckInRecord {
	out := make([]*checkinv1.CheckInRecord, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &checkinv1.CheckInRecord{
			CheckInDate: row.GetCheckInDate(), ConsecutiveDays: row.GetConsecutiveDays(),
			ExpReward: row.GetExpReward(), IsSpecialReward: row.GetIsSpecialReward(),
			SpecialRewardDesc: row.GetSpecialRewardDesc(),
		})
	}
	return out
}

func expLogsToProto(rows []*moerpc.ExpLogRecord) []*checkinv1.ExpLogRecord {
	out := make([]*checkinv1.ExpLogRecord, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &checkinv1.ExpLogRecord{
			Id: row.GetId(), ExpChange: row.GetExpChange(), Source: row.GetSource(),
			Description: row.GetDescription(), CreatedAt: row.GetCreatedAt(),
		})
	}
	return out
}

func achievementUnlocksToProto(rows []*moerpc.AchievementUnlock) []*checkinv1.AchievementUnlock {
	out := make([]*checkinv1.AchievementUnlock, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &checkinv1.AchievementUnlock{
			BadgeId: row.GetBadgeId(), Name: row.GetName(), ExpGranted: row.GetExpGranted(),
			LevelUp: row.GetLevelUp(), NewLevel: row.GetNewLevel(),
		})
	}
	return out
}
