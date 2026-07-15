package handlers

import (
	"crypto/subtle"
	"net/http"

	"github.com/gin-gonic/gin"
)

// APIKeyMiddleware enforces X-API-Key locally. In Choreo the managed API key
// sits in front of this service; set API_KEY empty there to avoid double auth.
func APIKeyMiddleware(key string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if key == "" {
			c.Next()
			return
		}
		provided := c.GetHeader("X-API-Key")
		if subtle.ConstantTimeCompare([]byte(provided), []byte(key)) != 1 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"errors": []string{"invalid api key"}})
			return
		}
		c.Next()
	}
}
