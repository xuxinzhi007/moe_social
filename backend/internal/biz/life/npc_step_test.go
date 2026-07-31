package lifebiz

import (
	"math"
	"testing"

	"backend/model"
)

func TestNpcStepMovesAlongStableHeading(t *testing.T) {
	e := &model.LifeEntity{ID: 3, Age: 12, PositionX: 640, PositionY: 360}
	startX, startY := e.PositionX, e.PositionY
	npcStep(e, 20)
	dx := e.PositionX - startX
	dy := e.PositionY - startY
	dist := math.Hypot(dx, dy)
	if dist < 15 || dist > 25 {
		t.Fatalf("step distance = %.2f, want ~20", dist)
	}
}

func TestNpcStepKeepsHeadingAcrossNearbyAges(t *testing.T) {
	a := &model.LifeEntity{ID: 5, Age: 18, PositionX: 200, PositionY: 200}
	b := &model.LifeEntity{ID: 5, Age: 19, PositionX: 200, PositionY: 200}
	npcStep(a, 20)
	npcStep(b, 20)
	// 同 sector（Age/6 相同）时朝向接近，位移方向夹角应较小。
	vaX, vaY := a.PositionX-200, a.PositionY-200
	vbX, vbY := b.PositionX-200, b.PositionY-200
	dot := vaX*vbX + vaY*vbY
	na := math.Hypot(vaX, vaY)
	nb := math.Hypot(vbX, vbY)
	if na < 1 || nb < 1 {
		t.Fatal("expected movement")
	}
	cos := dot / (na * nb)
	if cos < 0.7 {
		t.Fatalf("heading cosine=%.3f, want similar direction within sector", cos)
	}
}
