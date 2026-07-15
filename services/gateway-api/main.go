// Software POE gateway-api: ingestion endpoint + reverse proxy to
// analysis-engine and review-api. See docs/implementation-plan.md §2.1.
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"

	_ "github.com/Jest-Test-Team/software-poe/services/gateway-api/docs"
	"github.com/Jest-Test-Team/software-poe/services/gateway-api/internal/handlers"
	"github.com/Jest-Test-Team/software-poe/services/gateway-api/internal/store"
)

// @title           Software POE Gateway API
// @version         0.1.0
// @description     Synthetic-data, human-review-oriented ingestion gateway.
// @BasePath        /
func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is required")
	}

	db, err := store.Open(dsn)
	if err != nil {
		log.Fatalf("db open: %v", err)
	}
	if dir := os.Getenv("MIGRATIONS_DIR"); dir != "" {
		if err := store.Migrate(db, dir); err != nil {
			log.Fatalf("migrate: %v", err)
		}
	}

	r := gin.Default()
	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	api := r.Group("/", handlers.APIKeyMiddleware(os.Getenv("API_KEY")))
	h := handlers.New(db)
	api.POST("/v1/software-poe/events", h.IngestEvent)

	if reviewURL := os.Getenv("REVIEW_API_URL"); reviewURL != "" {
		p := handlers.NewProxy(reviewURL)
		api.GET("/v1/software-poe/assessments", p)
		api.GET("/v1/software-poe/assessments/:id", p)
		api.POST("/v1/software-poe/assessments/:id/review", p)
	}
	if analysisURL := os.Getenv("ANALYSIS_API_URL"); analysisURL != "" {
		p := handlers.NewProxy(analysisURL)
		api.Any("/internal/analysis/*path", p)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	log.Printf("gateway-api listening on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
