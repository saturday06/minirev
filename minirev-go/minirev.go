package main

import (
	"log"
	"net/http"
	"net/http/httputil"
)

func main() {
	http.DefaultTransport.(*http.Transport).MaxIdleConnsPerHost = 500
	director := func(request *http.Request) {
		request.URL.Scheme = "http"
		request.URL.Host = ":8080"
	}
	rp := httputil.ReverseProxy{
		Director: director,
	}
	server := http.Server{
		Addr:    ":3333",
		Handler: &rp,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err.Error())
	}
	return
}
