package lifebiz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"backend/internal/platform/moelog"
)

var lifeUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 4096,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

type lifeMember struct {
	conn      *websocket.Conn
	writeMu   sync.Mutex
	done      chan struct{}
	worldName string // 已订阅的世界名，空字符串表示尚未订阅
}

// writeText 线程安全地写入一条文本消息
func (m *lifeMember) writeText(data []byte) bool {
	if m == nil {
		return false
	}
	m.writeMu.Lock()
	defer m.writeMu.Unlock()
	if m.conn == nil {
		return false
	}
	_ = m.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
	if err := m.conn.WriteMessage(websocket.TextMessage, data); err != nil {
		moelog.Errorf("life ws write: %v", err)
		return false
	}
	return true
}

// writeJSON 序列化并写入
func (m *lifeMember) writeJSON(v interface{}) bool {
	data, err := json.Marshal(v)
	if err != nil {
		return false
	}
	return m.writeText(data)
}

// LifeWSHub 管理所有 /ws/life WebSocket 连接，支持按世界广播
type LifeWSHub struct {
	mu      sync.RWMutex
	members map[string]*lifeMember // connID -> member
	engine  *LifeEngine            // 注入引擎，用于获取世界快照
}

// NewLifeWSHub 创建连接管理器
func NewLifeWSHub() *LifeWSHub {
	return &LifeWSHub{members: make(map[string]*lifeMember)}
}

// SetEngine 注入引擎（引擎创建后调用）
func (h *LifeWSHub) SetEngine(e *LifeEngine) {
	h.engine = e
}

// ServeHTTP 处理 WebSocket 升级和连接（阻塞直到连接断开）
func (h *LifeWSHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	conn, err := lifeUpgrader.Upgrade(w, r, nil)
	if err != nil {
		moelog.Errorf("life ws upgrade: %v", err)
		return
	}

	id := fmt.Sprintf("life-%d", time.Now().UnixNano())
	member := &lifeMember{conn: conn, done: make(chan struct{})}

	h.mu.Lock()
	h.members[id] = member
	h.mu.Unlock()

	defer func() {
		h.mu.Lock()
		delete(h.members, id)
		h.mu.Unlock()
		conn.Close()
	}()

	moelog.Infof("life ws: client connected id=%s", id)

	// 读循环：等待客户端发送 subscribe 消息，之后继续监听断开
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				moelog.Errorf("life ws read: %v", err)
			}
			break
		}

		// 处理客户端消息
		var req map[string]interface{}
		if err := json.Unmarshal(message, &req); err != nil {
			continue
		}
		msgType, _ := req["type"].(string)

		switch msgType {
		case "subscribe":
			world, _ := req["world"].(string)
			if world == "" {
				world = "default"
			}
			h.mu.Lock()
			member.worldName = world
			h.mu.Unlock()

			// 发送当前世界快照（state_snapshot）
			h.sendSnapshot(member, world)

			moelog.Infof("life ws: client id=%s subscribed world=%s total=%d",
				id, world, h.GetMemberCount(world))

		case "ping":
			member.writeJSON(map[string]interface{}{"type": "pong"})
		}
	}

	if member.worldName != "" {
		moelog.Infof("life ws: client disconnected id=%s world=%s total=%d",
			id, member.worldName, h.GetMemberCount(member.worldName))
	} else {
		moelog.Infof("life ws: client disconnected id=%s (unsubscribed)", id)
	}
}

// sendSnapshot 向新订阅的客户端发送当前世界状态快照
func (h *LifeWSHub) sendSnapshot(m *lifeMember, worldID string) {
	if h.engine == nil {
		return
	}
	snap := h.engine.GetWorldCache().Get(worldID)
	if snap == nil {
		// 世界尚未初始化，发送空快照
		m.writeJSON(map[string]interface{}{
			"type":          "state_snapshot",
			"world_id":      worldID,
			"tick":          0,
			"summary":       WorldSummary{},
			"entities":      []interface{}{},
			"relationships": []interface{}{},
		})
		return
	}

	// 将快照中的实体转换为广播格式
	entities := make([]EntityDiff, 0, len(snap.Entities))
	for _, e := range snap.Entities {
		if e == nil {
			continue
		}
		entities = append(entities, EntityDiff{
			ID:            e.ID,
			Name:          e.Name,
			Emoji:         e.Emoji,
			Hunger:        e.Hunger,
			Energy:        e.Energy,
			Mood:          e.Mood,
			CurrentAction: LifeAction(e.CurrentAction),
			PositionX:     e.PositionX,
			PositionY:     e.PositionY,
		})
	}

	relationships := make([]RelationshipDiff, 0, len(snap.Relationships))
	for _, rel := range snap.Relationships {
		if rel == nil {
			continue
		}
		relationships = append(relationships, RelationshipDiff{
			EntityID:     rel.EntityID,
			TargetID:     rel.TargetID,
			RelationType: rel.RelationType,
			Affinity:     rel.Affinity,
		})
	}

	m.writeJSON(map[string]interface{}{
		"type":          "state_snapshot",
		"world_id":      worldID,
		"tick":          snap.TickCount,
		"summary":       snap.Summary,
		"entities":      entities,
		"relationships": relationships,
	})
}

// BroadcastState 广播状态更新到匹配 WorldID 的所有连接
// 签名匹配 BroadcastFunc: func(TickBroadcast)
func (h *LifeWSHub) BroadcastState(msg TickBroadcast) {
	worldID := msg.WorldID
	data, err := json.Marshal(msg)
	if err != nil {
		moelog.Errorf("life ws broadcast marshal: %v", err)
		return
	}

	h.mu.RLock()
	members := make([]*lifeMember, 0)
	for _, m := range h.members {
		if m.worldName == worldID {
			members = append(members, m)
		}
	}
	h.mu.RUnlock()

	for _, m := range members {
		go func(member *lifeMember) {
			member.writeText(data)
		}(m)
	}
}

// GetMemberCount 返回指定世界的当前连接数
func (h *LifeWSHub) GetMemberCount(worldID string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	count := 0
	for _, m := range h.members {
		if m.worldName == worldID {
			count++
		}
	}
	return count
}
