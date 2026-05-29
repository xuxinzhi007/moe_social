package main

import (
	"flag"
	"log"
)

var configFile = flag.String("f", "etc/moe.yaml", "the config file")

func main() {
	flag.Parse()
	log.Fatalf("standalone rpc binary removed; use: make moe-social")
}
