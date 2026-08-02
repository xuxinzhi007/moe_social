package petbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"time"

	"backend/model"
)

// ProfileRepo 养成档案仓储。
type ProfileRepo interface {
	GetByUserID(ctx context.Context, userID string) (*model.PetProfile, error)
	Save(ctx context.Context, p *model.PetProfile) error
	ListFriends(ctx context.Context, userID string) ([]model.PetFriendship, error)
	UpsertFriend(ctx context.Context, f *model.PetFriendship) error
}

// Usecase 养成业务。
type Usecase struct {
	repo ProfileRepo
}

type feedEffect struct {
	hunger float64
	mood   float64
}

var feedEffects = map[string]feedEffect{
	"":             {hunger: 18, mood: 4},
	"home_meal":    {hunger: 18, mood: 4},
	"fruit_yogurt": {hunger: 12, mood: 10},
	"energy_soup":  {hunger: 24, mood: 5},
}

// NewUsecase 创建养成用例。
func NewUsecase(repo ProfileRepo) *Usecase {
	return &Usecase{repo: repo}
}

// FurnitureSlot 家具摆放。
type FurnitureSlot struct {
	ID       string  `json:"id"`
	X        float64 `json:"x"`
	Y        float64 `json:"y"`
	Scene    string  `json:"scene"`
	Rotation int     `json:"rotation"` // 角度（度）
	Scale    float64 `json:"scale"`    // 相对尺寸，默认 1
}

// RoomBoundary 房间内不可通行的墙壁/固定结构矩形，坐标均为归一化值。
type RoomBoundary struct {
	ID     string  `json:"id"`
	Scene  string  `json:"scene"`
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

// EnsureProfile 确保用户有宠物档案。
func (u *Usecase) EnsureProfile(ctx context.Context, userID string) (*model.PetProfile, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return nil, fmt.Errorf("pet: empty user_id")
	}
	p, err := u.repo.GetByUserID(ctx, userID)
	if err == nil && p != nil {
		return p, nil
	}
	p = &model.PetProfile{
		UserID:   userID,
		Name:     "小萌",
		Species:  "bunny",
		Hunger:   80,
		Energy:   80,
		Mood:     70,
		Coins:    120,
		AgeYears: 1,
		Virtue:   12,
		Intel:    12,
		Sport:    12,
		Art:      12,
		Labor:    12,
		TopID:    "top_basic",
		BottomID: "bottom_basic",
		ShoesID:  "shoes_basic",
		SceneID:  "living",
		FurnitureJSON: mustJSON([]FurnitureSlot{
			{ID: "bed_basic", X: 0.22, Y: 0.62, Scene: "living"},
			{ID: "lamp_basic", X: 0.78, Y: 0.55, Scene: "living"},
			{ID: "rug_basic", X: 0.5, Y: 0.78, Scene: "living"},
		}),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet ensure: %w", err)
	}
	return p, nil
}

// Feed 喂食。
func (u *Usecase) Feed(ctx context.Context, userID, itemID string) (*model.PetProfile, error) {
	effect, ok := feedEffects[strings.TrimSpace(itemID)]
	if !ok {
		return nil, fmt.Errorf("pet feed: unsupported item")
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.Hunger = math.Min(100, p.Hunger+effect.hunger)
	p.Mood = math.Min(100, p.Mood+effect.mood)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet feed: %w", err)
	}
	return p, nil
}

// Pet 陪伴。
func (u *Usecase) Pet(ctx context.Context, userID string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.Mood = math.Min(100, p.Mood+14)
	p.Energy = math.Min(100, p.Energy+6)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet pet: %w", err)
	}
	return p, nil
}

// Dress 穿戴；ids 全量覆盖（允许 hat 为空表示不戴帽）。outfitJSON 为换衣间拖放布局。
func (u *Usecase) Dress(ctx context.Context, userID, hat, top, bottom, shoes, outfitJSON string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.HatID = hat
	if top != "" {
		p.TopID = top
	}
	if bottom != "" {
		p.BottomID = bottom
	}
	if shoes != "" {
		p.ShoesID = shoes
	}
	if strings.TrimSpace(outfitJSON) != "" {
		p.OutfitJSON = outfitJSON
	}
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet dress: %w", err)
	}
	return p, nil
}

// SetScene 切换场景。
func (u *Usecase) SetScene(ctx context.Context, userID, scene string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	switch scene {
	case "living", "yard", "bedroom":
		p.SceneID = scene
	default:
		return nil, fmt.Errorf("pet: invalid scene")
	}
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet scene: %w", err)
	}
	return p, nil
}

// PlaceFurniture 布置家具 JSON。
func (u *Usecase) PlaceFurniture(ctx context.Context, userID string, slots []FurnitureSlot) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.FurnitureJSON = mustJSON(slots)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet furniture: %w", err)
	}
	return p, nil
}

// SaveRoomBoundaries 覆盖保存房间阻挡区。边界独立于家具，不能混入 FurnitureJSON。
func (u *Usecase) SaveRoomBoundaries(ctx context.Context, userID string, boundaries []RoomBoundary) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	clean := make([]RoomBoundary, 0, len(boundaries))
	seen := make(map[string]struct{}, len(boundaries))
	for _, item := range boundaries {
		if item.ID == "" || item.Scene == "" || item.Width <= 0 || item.Height <= 0 {
			continue
		}
		if _, ok := seen[item.ID]; ok {
			continue
		}
		seen[item.ID] = struct{}{}
		item.X = math.Max(0.04, math.Min(0.96, item.X))
		item.Y = math.Max(0.12, math.Min(0.94, item.Y))
		item.Width = math.Max(0.03, math.Min(0.90, item.Width))
		item.Height = math.Max(0.03, math.Min(0.80, item.Height))
		clean = append(clean, item)
	}
	p.RoomLayoutJSON = mustJSON(clean)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet room layout: %w", err)
	}
	return p, nil
}

// Study 上课（P1）。
func (u *Usecase) Study(ctx context.Context, userID, subject string) (*model.PetProfile, string, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, "", err
	}
	if p.AgeYears < 3 {
		return nil, "", fmt.Errorf("pet: 需满 3 岁上学")
	}
	if p.Energy < 15 {
		return nil, "", fmt.Errorf("pet: 精力不足")
	}
	p.Energy -= 12
	msg := "上课完成"
	switch subject {
	case "virtue":
		p.Virtue += 3
		msg = "德育课 +3"
	case "intel":
		p.Intel += 3
		msg = "智育课 +3"
	case "sport":
		p.Sport += 3
		msg = "体育课 +3"
	case "art":
		p.Art += 3
		msg = "美育课 +3"
	case "labor":
		p.Labor += 3
		msg = "劳育课 +3"
	default:
		return nil, "", fmt.Errorf("pet: unknown subject")
	}
	p.Mood = math.Min(100, p.Mood+2)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, "", fmt.Errorf("pet study: %w", err)
	}
	return p, msg, nil
}

// Work 打工（P1）。
func (u *Usecase) Work(ctx context.Context, userID string) (*model.PetProfile, string, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, "", err
	}
	if p.AgeYears < 3 {
		return nil, "", fmt.Errorf("pet: 需满 3 岁打工")
	}
	avg := (p.Virtue + p.Intel + p.Sport + p.Art + p.Labor) / 5
	if avg < 15 {
		return nil, "", fmt.Errorf("pet: 能力不足，先去上学")
	}
	if p.Energy < 20 {
		return nil, "", fmt.Errorf("pet: 太累了")
	}
	pay := 20 + avg
	p.Coins += pay
	p.Energy -= 18
	p.Hunger = math.Max(0, p.Hunger-8)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, "", fmt.Errorf("pet work: %w", err)
	}
	return p, fmt.Sprintf("打工赚到 %d 币", pay), nil
}

// AgeUp 长大一岁（调试/推进）。
func (u *Usecase) AgeUp(ctx context.Context, userID string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.AgeYears++
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet age: %w", err)
	}
	return p, nil
}

// AddFriend 加好友（P2）。
func (u *Usecase) AddFriend(ctx context.Context, userID, friendID string) error {
	friendID = strings.TrimSpace(friendID)
	if friendID == "" || friendID == userID {
		return fmt.Errorf("pet: invalid friend")
	}
	if _, err := u.EnsureProfile(ctx, userID); err != nil {
		return err
	}
	return u.repo.UpsertFriend(ctx, &model.PetFriendship{
		UserID:    userID,
		FriendID:  friendID,
		Status:    "accepted",
		CreatedAt: time.Now(),
	})
}

// Marry 结婚（P2，简化：对方 ID）。
func (u *Usecase) Marry(ctx context.Context, userID, spouseID string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if p.AgeYears < 22 {
		return nil, fmt.Errorf("pet: 需满 22 岁结婚")
	}
	spouseID = strings.TrimSpace(spouseID)
	if spouseID == "" {
		return nil, fmt.Errorf("pet: empty spouse")
	}
	p.SpouseUserID = spouseID
	p.UpdatedAt = time.Now()
	_ = u.repo.UpsertFriend(ctx, &model.PetFriendship{
		UserID: userID, FriendID: spouseID, Status: "married", CreatedAt: time.Now(),
	})
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet marry: %w", err)
	}
	return p, nil
}

// HaveBaby 生子简化（P2）。
func (u *Usecase) HaveBaby(ctx context.Context, userID string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if p.SpouseUserID == "" {
		return nil, fmt.Errorf("pet: 需要先结婚")
	}
	p.HasBaby = true
	p.Coins = int(math.Max(0, float64(p.Coins-50)))
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet baby: %w", err)
	}
	return p, nil
}

// Adventure 轻冒险（P3）。
func (u *Usecase) Adventure(ctx context.Context, userID string) (*model.PetProfile, string, bool, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, "", false, err
	}
	if p.Energy < 25 {
		return nil, "", false, fmt.Errorf("pet: 精力不足，无法冒险")
	}
	p.Energy -= 20
	power := p.Sport + p.Labor + int(p.Mood/10)
	win := power >= 28
	loot := ""
	if win {
		gain := 30 + p.Sport
		p.Coins += gain
		p.Mood = math.Min(100, p.Mood+8)
		loot = fmt.Sprintf("胜利！获得 %d 币与材料", gain)
	} else {
		p.Mood = math.Max(0, p.Mood-6)
		loot = "惜败，回去休息一下再来"
	}
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, "", false, fmt.Errorf("pet adventure: %w", err)
	}
	return p, loot, win, nil
}

// BuySoft 软通货购买（P4 占位）。
func (u *Usecase) BuySoft(ctx context.Context, userID, itemID string) (*model.PetProfile, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	price := 40
	if p.Coins < price {
		return nil, fmt.Errorf("pet: 硬币不足")
	}
	p.Coins -= price
	switch {
	case strings.HasPrefix(itemID, "hat_"):
		p.HatID = itemID
	case strings.HasPrefix(itemID, "top_"):
		p.TopID = itemID
	default:
		// 家具：追加
		var slots []FurnitureSlot
		_ = json.Unmarshal([]byte(p.FurnitureJSON), &slots)
		slots = append(slots, FurnitureSlot{ID: itemID, X: 0.4, Y: 0.65, Scene: p.SceneID})
		p.FurnitureJSON = mustJSON(slots)
	}
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("pet buy: %w", err)
	}
	return p, nil
}

func mustJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}
