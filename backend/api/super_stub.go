//go:build !hybrid

package main

import (
	"flag"
	"log"
)

var configFile = flag.String("f", "etc/moe.yaml", "the config file")

func main() {
	flag.Parse()
	log.Fatalf("moe-social-api (go-zero rest) removed in default build; use: make moe-social  OR  go build -tags hybrid -o moe-social-api ./api")
}
