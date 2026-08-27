package arenabiz

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"backend/model"
)

const (
	DefaultStarCrystals   = 6280
	DefaultTowerFloor     = 1
	DefaultTowerNode      = 2
	FormationSize         = 3
	SingleSummonCost      = 300
	TenSummonCost         = 2700
	TowerClearReward      = 120
	TowerWinShardBonus    = 4
	HomeGiftCost          = 80
	HomeGiftBondGain      = 5
	MaxDeckCards          = 24
	MaxHeroBond           = 100
	MaxSelectedTowerNodes = 5
)

// Rarity 与客户端 ArenaRarity 对齐。
type Rarity string

const (
	RarityR   Rarity = "r"
	RaritySR  Rarity = "sr"
	RaritySSR Rarity = "ssr"
)

// OwnedHero 已拥有英雄（含养成数值）。
type OwnedHero struct {
	HeroID   string `json:"hero_id"`
	Shards   int    `json:"shards"`
	Bond     int    `json:"bond"`
	Level    int    `json:"level"`
	Stars    int    `json:"stars"`
	Power    int    `json:"power"`
	Favorite int    `json:"favorite"`
	SkinID   string `json:"skin_id"`
}

// DeckCard 持久化牌组条目。
type DeckCard struct {
	Name           string `json:"name"`
	Description    string `json:"description"`
	Cost           int    `json:"cost"`
	Icon           string `json:"icon"`
	Color          int    `json:"color"`
	Damage         int    `json:"damage"`
	SourceHeroID   string `json:"source_hero_id"`
	SourceHeroName string `json:"source_hero_name"`
	Targeting      string `json:"targeting"`
}

// Progress 会话级可持久化进度。
type Progress struct {
	RestBuffReady     bool `json:"rest_buff_ready"`
	BondBuffReady     bool `json:"bond_buff_ready"`
	SelectedTowerNode int  `json:"selected_tower_node"`
}

// State DTO。
type State struct {
	UserID            string      `json:"user_id"`
	StarCrystals      int         `json:"star_crystals"`
	TowerFloor        int         `json:"tower_floor"`
	FormationHeroIDs  []string    `json:"formation_hero_ids"`
	OwnedHeroes       []OwnedHero `json:"owned_heroes"`
	Deck              []DeckCard  `json:"deck"`
	RestBuffReady     bool        `json:"rest_buff_ready"`
	BondBuffReady     bool        `json:"bond_buff_ready"`
	SelectedTowerNode int         `json:"selected_tower_node"`
	UpdatedAt         string      `json:"updated_at,omitempty"`
}

// SummonPull 单次抽卡结果。
type SummonPull struct {
	HeroID string `json:"hero_id"`
	IsNew  bool   `json:"is_new"`
	Shards int    `json:"shards"`
}

// SummonResult 召唤回包。
type SummonResult struct {
	State   *State       `json:"state"`
	Pulls   []SummonPull `json:"pulls"`
	Message string       `json:"message"`
}

// ClearTowerResult 通关回包。
type ClearTowerResult struct {
	State         *State `json:"state"`
	CrystalReward int    `json:"crystal_reward"`
}

// ProfileRepo 存档仓储。
type ProfileRepo interface {
	GetByUserID(ctx context.Context, userID string) (*model.ArenaProfile, error)
	Save(ctx context.Context, p *model.ArenaProfile) error
}

// Usecase 星辉远征业务。
type Usecase struct {
	repo ProfileRepo
	rng  *rand.Rand
}

// NewUsecase 创建用例。
func NewUsecase(repo ProfileRepo) *Usecase {
	return &Usecase{
		repo: repo,
		rng:  rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// NewUsecaseWithRand 注入随机源（单测）。
func NewUsecaseWithRand(repo ProfileRepo, rng *rand.Rand) *Usecase {
	return &Usecase{repo: repo, rng: rng}
}

type heroDef struct {
	ID       string
	Rarity   Rarity
	Level    int
	Stars    int
	Power    int
	Favorite int
}

var heroCatalog = []heroDef{
	{ID: "lanxing", Rarity: RaritySSR, Level: 42, Stars: 3, Power: 19600, Favorite: 72},
	{ID: "tutu", Rarity: RaritySSR, Level: 38, Stars: 3, Power: 17200, Favorite: 64},
	{ID: "maoying", Rarity: RaritySR, Level: 36, Stars: 2, Power: 14600, Favorite: 52},
	{ID: "huhuo", Rarity: RaritySR, Level: 34, Stars: 2, Power: 13900, Favorite: 58},
	{ID: "linglan", Rarity: RaritySR, Level: 30, Stars: 1, Power: 10100, Favorite: 41},
	{ID: "yuebai", Rarity: RarityR, Level: 28, Stars: 1, Power: 9200, Favorite: 36},
	{ID: "taoyin", Rarity: RaritySR, Level: 32, Stars: 2, Power: 12400, Favorite: 46},
	{ID: "xueli", Rarity: RaritySSR, Level: 40, Stars: 3, Power: 18800, Favorite: 66},
	{ID: "ziyuan", Rarity: RaritySR, Level: 35, Stars: 2, Power: 15100, Favorite: 55},
}

var defaultFormation = []string{"lanxing", "tutu", "maoying"}

var shardValue = map[Rarity]int{
	RarityR:   8,
	RaritySR:  18,
	RaritySSR: 40,
}

func heroByID(id string) (heroDef, bool) {
	for _, h := range heroCatalog {
		if h.ID == id {
			return h, true
		}
	}
	return heroDef{}, false
}

func newOwnedFromCatalog(id string) OwnedHero {
	h, ok := heroByID(id)
	if !ok {
		return OwnedHero{HeroID: id}
	}
	return OwnedHero{
		HeroID:   id,
		Shards:   0,
		Bond:     0,
		Level:    h.Level,
		Stars:    h.Stars,
		Power:    h.Power,
		Favorite: h.Favorite,
	}
}

func normalizeOwned(list []OwnedHero) []OwnedHero {
	out := make([]OwnedHero, 0, len(list))
	for _, h := range list {
		def, ok := heroByID(h.HeroID)
		if !ok {
			continue
		}
		if h.Level <= 0 {
			h.Level = def.Level
		}
		if h.Stars <= 0 {
			h.Stars = def.Stars
		}
		if h.Power <= 0 {
			h.Power = def.Power
		}
		if h.Favorite <= 0 {
			h.Favorite = def.Favorite
		}
		if h.Bond < 0 {
			h.Bond = 0
		}
		if h.Bond > MaxHeroBond {
			h.Bond = MaxHeroBond
		}
		out = append(out, h)
	}
	return out
}

func defaultProgress() Progress {
	return Progress{SelectedTowerNode: DefaultTowerNode}
}

// EnsureProfile 确保用户有存档。
func (u *Usecase) EnsureProfile(ctx context.Context, userID string) (*model.ArenaProfile, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return nil, fmt.Errorf("arena: empty user_id")
	}
	p, err := u.repo.GetByUserID(ctx, userID)
	if err == nil && p != nil {
		return p, nil
	}
	owned := make([]OwnedHero, 0, len(defaultFormation))
	for _, id := range defaultFormation {
		owned = append(owned, newOwnedFromCatalog(id))
	}
	now := time.Now()
	p = &model.ArenaProfile{
		UserID:          userID,
		StarCrystals:    DefaultStarCrystals,
		TowerFloor:      DefaultTowerFloor,
		FormationJSON:   mustJSON(defaultFormation),
		OwnedHeroesJSON: mustJSON(owned),
		DeckJSON:        "[]",
		ProgressJSON:    mustJSON(defaultProgress()),
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena ensure: %w", err)
	}
	return p, nil
}

// GetState 读取存档 DTO。
func (u *Usecase) GetState(ctx context.Context, userID string) (*State, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	return toState(p), nil
}

// SetFormation 设置出战阵容。
func (u *Usecase) SetFormation(ctx context.Context, userID string, heroIDs []string) (*State, error) {
	if len(heroIDs) != FormationSize {
		return nil, fmt.Errorf("arena formation: need %d heroes", FormationSize)
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
	ownedSet := map[string]struct{}{}
	for _, h := range owned {
		ownedSet[h.HeroID] = struct{}{}
	}
	seen := map[string]struct{}{}
	clean := make([]string, 0, FormationSize)
	for _, id := range heroIDs {
		id = strings.TrimSpace(id)
		if id == "" {
			return nil, fmt.Errorf("arena formation: empty hero_id")
		}
		if _, ok := heroByID(id); !ok {
			return nil, fmt.Errorf("arena formation: unknown hero %s", id)
		}
		if _, ok := ownedSet[id]; !ok {
			return nil, fmt.Errorf("arena formation: hero not owned %s", id)
		}
		if _, dup := seen[id]; dup {
			return nil, fmt.Errorf("arena formation: duplicate hero %s", id)
		}
		seen[id] = struct{}{}
		clean = append(clean, id)
	}
	p.FormationJSON = mustJSON(clean)
	p.OwnedHeroesJSON = mustJSON(owned)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena formation: %w", err)
	}
	return toState(p), nil
}

// Summon 单抽或十连。
func (u *Usecase) Summon(ctx context.Context, userID string, count int) (*SummonResult, error) {
	if count != 1 && count != 10 {
		return nil, fmt.Errorf("arena summon: count must be 1 or 10")
	}
	cost := SingleSummonCost
	if count == 10 {
		cost = TenSummonCost
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if p.StarCrystals < cost {
		return nil, fmt.Errorf("arena summon: insufficient crystals")
	}
	owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
	ownedIndex := map[string]int{}
	for i, h := range owned {
		ownedIndex[h.HeroID] = i
	}

	pulls := make([]SummonPull, 0, count)
	for i := 0; i < count; i++ {
		pulls = append(pulls, u.pullOnce(&owned, ownedIndex, nil))
	}
	if count == 10 && !hasSROrAbove(pulls) {
		minSR := RaritySR
		pulls[len(pulls)-1] = u.pullOnce(&owned, ownedIndex, &minSR)
	}

	p.StarCrystals -= cost
	p.OwnedHeroesJSON = mustJSON(owned)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena summon: %w", err)
	}

	newCount := 0
	shards := 0
	for _, pull := range pulls {
		if pull.IsNew {
			newCount++
		}
		shards += pull.Shards
	}
	msg := fmt.Sprintf("本次获得 %d 个英雄碎片。", shards)
	if newCount > 0 {
		msg = fmt.Sprintf("获得 %d 名新英雄，重复角色转化为 %d 个碎片。", newCount, shards)
	}
	return &SummonResult{State: toState(p), Pulls: pulls, Message: msg}, nil
}

// HomeGift 送礼。
func (u *Usecase) HomeGift(ctx context.Context, userID, heroID string) (*State, error) {
	heroID = strings.TrimSpace(heroID)
	if heroID == "" {
		return nil, fmt.Errorf("arena gift: empty hero_id")
	}
	if _, ok := heroByID(heroID); !ok {
		return nil, fmt.Errorf("arena gift: unknown hero %s", heroID)
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if p.StarCrystals < HomeGiftCost {
		return nil, fmt.Errorf("arena gift: insufficient crystals")
	}
	owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
	idx := -1
	for i := range owned {
		if owned[i].HeroID == heroID {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("arena gift: hero not owned %s", heroID)
	}
	p.StarCrystals -= HomeGiftCost
	owned[idx].Bond += HomeGiftBondGain
	if owned[idx].Bond > MaxHeroBond {
		owned[idx].Bond = MaxHeroBond
	}
	prog := decodeProgress(p.ProgressJSON)
	prog.BondBuffReady = true
	p.OwnedHeroesJSON = mustJSON(owned)
	p.ProgressJSON = mustJSON(prog)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena gift: %w", err)
	}
	return toState(p), nil
}

// HomeTrain 训练：挂下场生命 buff。
func (u *Usecase) HomeTrain(ctx context.Context, userID string) (*State, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	prog := decodeProgress(p.ProgressJSON)
	prog.RestBuffReady = true
	p.ProgressJSON = mustJSON(prog)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena train: %w", err)
	}
	return toState(p), nil
}

// SaveMeta 保存爬塔节点 / 可选清空战斗 buff。
func (u *Usecase) SaveMeta(ctx context.Context, userID string, selectedTowerNode *int, clearBuffs bool) (*State, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	prog := decodeProgress(p.ProgressJSON)
	if selectedTowerNode != nil {
		node := *selectedTowerNode
		if node < 0 || node >= MaxSelectedTowerNodes {
			return nil, fmt.Errorf("arena meta: invalid tower node")
		}
		prog.SelectedTowerNode = node
	}
	if clearBuffs {
		prog.RestBuffReady = false
		prog.BondBuffReady = false
	}
	p.ProgressJSON = mustJSON(prog)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena meta: %w", err)
	}
	return toState(p), nil
}

// SetSkin 切换已拥有英雄的整卡皮肤。
func (u *Usecase) SetSkin(ctx context.Context, userID, heroID, skinID string) (*State, error) {
	heroID = strings.TrimSpace(heroID)
	skinID = strings.TrimSpace(skinID)
	if heroID == "" || skinID == "" {
		return nil, fmt.Errorf("arena skin: hero_id and skin_id required")
	}
	if _, ok := heroByID(heroID); !ok {
		return nil, fmt.Errorf("arena skin: unknown hero %s", heroID)
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
	idx := -1
	for i := range owned {
		if owned[i].HeroID == heroID {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("arena skin: hero not owned %s", heroID)
	}
	owned[idx].SkinID = skinID
	p.OwnedHeroesJSON = mustJSON(owned)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena skin: %w", err)
	}
	return toState(p), nil
}

// SaveDeck 保存牌组。
func (u *Usecase) SaveDeck(ctx context.Context, userID string, deck []DeckCard) (*State, error) {
	clean, err := sanitizeDeck(deck)
	if err != nil {
		return nil, err
	}
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	p.DeckJSON = mustJSON(clean)
	p.UpdatedAt = time.Now()
	if err := u.repo.Save(ctx, p); err != nil {
		return nil, fmt.Errorf("arena deck: %w", err)
	}
	return toState(p), nil
}

// ClearTower 通关结算。
func (u *Usecase) ClearTower(ctx context.Context, userID string, won bool, bonusHeroID string, deck []DeckCard) (*ClearTowerResult, error) {
	p, err := u.EnsureProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	reward := 0
	if won {
		reward = TowerClearReward
		p.StarCrystals += reward
		p.TowerFloor++
		bonusHeroID = strings.TrimSpace(bonusHeroID)
		owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
		if bonusHeroID != "" {
			for i := range owned {
				if owned[i].HeroID == bonusHeroID {
					owned[i].Shards += TowerWinShardBonus
					break
				}
			}
		}
		p.OwnedHeroesJSON = mustJSON(owned)
		if len(deck) > 0 {
			clean, err := sanitizeDeck(deck)
			if err != nil {
				return nil, err
			}
			p.DeckJSON = mustJSON(clean)
		}
		p.UpdatedAt = time.Now()
		if err := u.repo.Save(ctx, p); err != nil {
			return nil, fmt.Errorf("arena tower clear: %w", err)
		}
	}
	return &ClearTowerResult{State: toState(p), CrystalReward: reward}, nil
}

func sanitizeDeck(deck []DeckCard) ([]DeckCard, error) {
	if len(deck) > MaxDeckCards {
		return nil, fmt.Errorf("arena deck: too many cards")
	}
	out := make([]DeckCard, 0, len(deck))
	for _, c := range deck {
		name := strings.TrimSpace(c.Name)
		if name == "" {
			return nil, fmt.Errorf("arena deck: empty card name")
		}
		targeting := strings.TrimSpace(c.Targeting)
		if targeting == "" {
			targeting = "single_enemy"
		}
		out = append(out, DeckCard{
			Name:           name,
			Description:    strings.TrimSpace(c.Description),
			Cost:           c.Cost,
			Icon:           strings.TrimSpace(c.Icon),
			Color:          c.Color,
			Damage:         c.Damage,
			SourceHeroID:   strings.TrimSpace(c.SourceHeroID),
			SourceHeroName: strings.TrimSpace(c.SourceHeroName),
			Targeting:      targeting,
		})
	}
	return out, nil
}

func (u *Usecase) pullOnce(owned *[]OwnedHero, ownedIndex map[string]int, minRarity *Rarity) SummonPull {
	hero := u.randomHero(minRarity)
	idx, ok := ownedIndex[hero.ID]
	if !ok {
		*owned = append(*owned, newOwnedFromCatalog(hero.ID))
		ownedIndex[hero.ID] = len(*owned) - 1
		return SummonPull{HeroID: hero.ID, IsNew: true, Shards: 0}
	}
	shards := shardValue[hero.Rarity]
	(*owned)[idx].Shards += shards
	return SummonPull{HeroID: hero.ID, IsNew: false, Shards: shards}
}

func (u *Usecase) randomHero(minRarity *Rarity) heroDef {
	roll := u.rng.Float64()
	rarity := RarityR
	if roll < 0.08 {
		rarity = RaritySSR
	} else if roll < 0.38 {
		rarity = RaritySR
	}
	if minRarity != nil && *minRarity == RaritySR && rarity == RarityR {
		rarity = RaritySR
	}
	pool := make([]heroDef, 0, 4)
	for _, h := range heroCatalog {
		if h.Rarity == rarity {
			pool = append(pool, h)
		}
	}
	if len(pool) == 0 {
		return heroCatalog[0]
	}
	return pool[u.rng.Intn(len(pool))]
}

func hasSROrAbove(pulls []SummonPull) bool {
	for _, p := range pulls {
		h, ok := heroByID(p.HeroID)
		if ok && h.Rarity != RarityR {
			return true
		}
	}
	return false
}

func toState(p *model.ArenaProfile) *State {
	if p == nil {
		return nil
	}
	formation := decodeStrings(p.FormationJSON)
	if len(formation) == 0 {
		formation = append([]string{}, defaultFormation...)
	}
	owned := normalizeOwned(decodeOwned(p.OwnedHeroesJSON))
	deck := decodeDeck(p.DeckJSON)
	prog := decodeProgress(p.ProgressJSON)
	updated := ""
	if !p.UpdatedAt.IsZero() {
		updated = p.UpdatedAt.UTC().Format(time.RFC3339)
	}
	return &State{
		UserID:            p.UserID,
		StarCrystals:      p.StarCrystals,
		TowerFloor:        p.TowerFloor,
		FormationHeroIDs:  formation,
		OwnedHeroes:       owned,
		Deck:              deck,
		RestBuffReady:     prog.RestBuffReady,
		BondBuffReady:     prog.BondBuffReady,
		SelectedTowerNode: prog.SelectedTowerNode,
		UpdatedAt:         updated,
	}
}

func decodeOwned(raw string) []OwnedHero {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var out []OwnedHero
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil
	}
	return out
}

func decodeDeck(raw string) []DeckCard {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var out []DeckCard
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil
	}
	return out
}

func decodeProgress(raw string) Progress {
	prog := defaultProgress()
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return prog
	}
	_ = json.Unmarshal([]byte(raw), &prog)
	if prog.SelectedTowerNode < 0 || prog.SelectedTowerNode >= MaxSelectedTowerNodes {
		prog.SelectedTowerNode = DefaultTowerNode
	}
	return prog
}

func decodeStrings(raw string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var out []string
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil
	}
	return out
}

func mustJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}
