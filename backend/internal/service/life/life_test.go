package lifeapp

import (
	"testing"
	"time"
)

func TestEngineConfigOverridesIntervals(t *testing.T) {
	config := engineConfig(Config{
		TickInterval:  300,
		FlushInterval: 300,
	})

	if config.TickInterval != 5*time.Minute {
		t.Fatalf("TickInterval = %s, want %s", config.TickInterval, 5*time.Minute)
	}
	if config.FlushInterval != 5*time.Minute {
		t.Fatalf("FlushInterval = %s, want %s", config.FlushInterval, 5*time.Minute)
	}
}

func TestEngineConfigKeepsDefaultsForUnsetIntervals(t *testing.T) {
	config := engineConfig(Config{})

	if config.TickInterval != 5*time.Second {
		t.Fatalf("TickInterval = %s, want %s", config.TickInterval, 5*time.Second)
	}
	if config.FlushInterval != 5*time.Second {
		t.Fatalf("FlushInterval = %s, want %s", config.FlushInterval, 5*time.Second)
	}
}
