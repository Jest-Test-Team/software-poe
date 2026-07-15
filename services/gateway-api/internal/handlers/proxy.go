package handlers

import (
	"log"
	"net/http/httputil"
	"net/url"

	"github.com/gin-gonic/gin"
)

// NewProxy returns a gin handler reverse-proxying to the given base URL,
// preserving the incoming path and query.
func NewProxy(target string) gin.HandlerFunc {
	u, err := url.Parse(target)
	if err != nil {
		log.Fatalf("invalid proxy target %q: %v", target, err)
	}
	proxy := httputil.NewSingleHostReverseProxy(u)
	return func(c *gin.Context) {
		proxy.ServeHTTP(c.Writer, c.Request)
	}
}
