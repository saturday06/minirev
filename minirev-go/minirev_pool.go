package main

import (
	"log"
	"net/http"
	"net/http/httputil"
	"sync"
)

type pool struct {
	p sync.Pool
}

func (p pool) Get() []byte {
	return p.p.Get().([]byte)
}

func (p pool) Put(b []byte) {
	p.p.Put(b)
}

func main() {
	http.DefaultTransport.(*http.Transport).MaxIdleConnsPerHost = 500
	director := func(request *http.Request) {
		request.URL.Scheme = "http"
		request.URL.Host = ":8080"
	}
	rp := httputil.ReverseProxy{
		Director: director,
		BufferPool: pool{p: sync.Pool{
			New: func() interface{} {
				return make([]byte, 8*1024)
			},
		}},
	}
	server := http.Server{
		Addr:    ":3334",
		Handler: &rp,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err.Error())
	}
	return
}
