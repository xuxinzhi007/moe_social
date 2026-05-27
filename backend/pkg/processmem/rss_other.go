//go:build !unix

package processmem

func readRSSMB() float64 {
	return 0
}
