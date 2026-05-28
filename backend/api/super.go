package main

import (
	"flag"
	"log"

	apirun "backend/api/runserver"
)

var configFile = flag.String("f", "etc/moe.yaml", "the config file")

func main() {
	flag.Parse()

	server, err := apirun.Start(apirun.Options{ConfigFile: *configFile})
	if err != nil {
		log.Fatal(err)
	}
	defer server.Stop()
	server.Start()
}
