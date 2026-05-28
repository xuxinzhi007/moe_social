//go:build hybrid

package main

import (
	"flag"
	"log"

	apirun "backend/api/runserver"

	"github.com/zeromicro/go-zero/rest"
)

var configFile = flag.String("f", "etc/moe.yaml", "the config file")

func main() {
	flag.Parse()

	server, err := apirun.Start(apirun.Options{ConfigFile: *configFile})
	if err != nil {
		log.Fatal(err)
	}
	srv, ok := server.(*rest.Server)
	if !ok || srv == nil {
		log.Fatal("hybrid api: expected *rest.Server")
	}
	defer srv.Stop()
	srv.Start()
}
