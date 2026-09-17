package moewiring

import (
	"time"

	"backend/internal/platform/appdb"
	"backend/internal/platform/moelog"
	lifeapp "backend/internal/service/life"
	"backend/pkg/conf"
)

// LifeAPIInProcessEnabled reports whether the life engine should run in-process.
func LifeAPIInProcessEnabled() bool {
	return conf.LifeEngineEnabled() || conf.DomainInProcess("life")
}

// NewAPILifeService creates the life AppService when the feature flag is on.
func NewAPILifeService() (*lifeapp.AppService, error) {
	if !LifeAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	tick, flush := conf.LifeIntervals()
	tickSec, flushSec := int(tick/time.Second), int(flush/time.Second)
	// 打的是**真正交给引擎的那两个整数**，不是 conf 返回的 Duration：
	// 这样启动日志同时证明了「配置读到了」和「秒数换算没写错」。
	moelog.Infof("life: engine intervals tick=%ds flush=%ds (moe.life_tick_seconds / life_flush_seconds)", tickSec, flushSec)
	return lifeapp.New(db, lifeapp.Config{
		TickInterval:  tickSec,
		FlushInterval: flushSec,
	}), nil
}
