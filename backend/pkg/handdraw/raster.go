// Package handdraw 将手绘卡片 JSON 栅格化为 PNG（与 Flutter HandDrawCardPainter 对齐）。
package handdraw

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
)

type cardJSON struct {
	V  int         `json:"v"`
	Bg int64       `json:"bg"`
	S  []strokeJSON `json:"s"`
}

type strokeJSON struct {
	C int64       `json:"c"`
	W float64     `json:"w"`
	P [][]float64 `json:"p"`
	E any         `json:"e"`
}

// RasterPNG 将手绘 JSON 渲染为 PNG 字节。默认宽 360、高 480（3:4）。
func RasterPNG(raw string, width int) ([]byte, error) {
	raw = trimJSON(raw)
	if raw == "" {
		return nil, fmt.Errorf("empty hand draw card")
	}
	var data cardJSON
	if err := json.Unmarshal([]byte(raw), &data); err != nil {
		return nil, fmt.Errorf("parse hand draw card: %w", err)
	}
	if width <= 0 {
		width = 360
	}
	height := width * 4 / 3
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	bg := argbToRGBA(data.Bg, 0xFFF5F7FA)
	fillRect(img, bg)

	shortSide := width
	if height < shortSide {
		shortSide = height
	}

	for _, stroke := range data.S {
		if len(stroke.P) == 0 {
			continue
		}
		sw := stroke.W * float64(shortSide)
		if sw < 1.5 {
			sw = 1.5
		}
		if sw > 36 {
			sw = 36
		}
		erase := isErase(stroke.E)
		strokeColor := argbToRGBA(stroke.C, 0xFF7F7FD5)
		if erase {
			strokeColor = bg
		}
		pts := stroke.P
		if len(pts) == 1 {
			x, y := normToPixel(pts[0], width, height)
			drawDot(img, x, y, sw, strokeColor)
			continue
		}
		for i := 0; i < len(pts)-1; i++ {
			x0, y0 := normToPixel(pts[i], width, height)
			x1, y1 := normToPixel(pts[i+1], width, height)
			drawLine(img, x0, y0, x1, y1, sw, strokeColor)
		}
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func trimJSON(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\n' || s[0] == '\t') {
		s = s[1:]
	}
	return s
}

func isErase(v any) bool {
	switch t := v.(type) {
	case bool:
		return t
	case float64:
		return t != 0
	case int:
		return t != 0
	default:
		return false
	}
}

func argbToRGBA(argb int64, fallback uint32) color.RGBA {
	if argb == 0 {
		argb = int64(fallback)
	}
	u := uint32(argb)
	a := uint8((u >> 24) & 0xFF)
	r := uint8((u >> 16) & 0xFF)
	g := uint8((u >> 8) & 0xFF)
	b := uint8(u & 0xFF)
	if a == 0 {
		a = 0xFF
	}
	return color.RGBA{R: r, G: g, B: b, A: a}
}

func normToPixel(p []float64, w, h int) (int, int) {
	if len(p) < 2 {
		return 0, 0
	}
	x := int(math.Round(p[0] * float64(w)))
	y := int(math.Round(p[1] * float64(h)))
	if x < 0 {
		x = 0
	}
	if y < 0 {
		y = 0
	}
	if x >= w {
		x = w - 1
	}
	if y >= h {
		y = h - 1
	}
	return x, y
}

func fillRect(img *image.RGBA, c color.RGBA) {
	bounds := img.Bounds()
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			img.SetRGBA(x, y, c)
		}
	}
}

func drawDot(img *image.RGBA, cx, cy int, width float64, c color.RGBA) {
	r := int(math.Ceil(width / 2))
	for dy := -r; dy <= r; dy++ {
		for dx := -r; dx <= r; dx++ {
			if dx*dx+dy*dy <= r*r {
				img.SetRGBA(cx+dx, cy+dy, c)
			}
		}
	}
}

func drawLine(img *image.RGBA, x0, y0, x1, y1 int, width float64, c color.RGBA) {
	dx := float64(x1 - x0)
	dy := float64(y1 - y0)
	steps := int(math.Max(math.Abs(dx), math.Abs(dy)))
	if steps < 1 {
		steps = 1
	}
	r := width / 2
	for i := 0; i <= steps; i++ {
		t := float64(i) / float64(steps)
		x := int(math.Round(float64(x0) + dx*t))
		y := int(math.Round(float64(y0) + dy*t))
		drawDot(img, x, y, width, c)
		_ = r
	}
}
