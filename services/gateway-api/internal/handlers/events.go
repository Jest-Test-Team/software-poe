package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"github.com/Jest-Test-Team/software-poe/services/gateway-api/internal/models"
)

var allowedMetrics = map[string]bool{
	"intent_fulfillment_ratio": true,
	"slo_gap":                  true,
	"cost_estimate_error":      true,
	"unused_capability_ratio":  true,
	"incident_delta":           true,
}

const schemaVersion = "0.1.0"

type Handler struct{ db *gorm.DB }

func New(db *gorm.DB) *Handler { return &Handler{db: db} }

type eventRequest struct {
	TenantID      string                 `json:"tenant_id"`
	Project       string                 `json:"project"`
	Source        string                 `json:"source"`
	ObservedAt    string                 `json:"observed_at"`
	Metric        string                 `json:"metric"`
	Value         *float64               `json:"value"`
	Unit          string                 `json:"unit"`
	EvidenceRef   string                 `json:"evidence_ref"`
	SchemaVersion string                 `json:"schema_version"`
	Attributes    map[string]interface{} `json:"attributes"`
}

// validate mirrors schemas/event.schema.json.
func (r *eventRequest) validate() []string {
	var errs []string
	if r.TenantID == "" {
		errs = append(errs, "tenant_id is required")
	}
	if r.Project != "software-poe" {
		errs = append(errs, "project must be 'software-poe'")
	}
	if r.Source == "" {
		errs = append(errs, "source is required")
	}
	if _, err := time.Parse(time.RFC3339, r.ObservedAt); err != nil {
		errs = append(errs, "observed_at must be an RFC3339 date-time")
	}
	if !allowedMetrics[r.Metric] {
		errs = append(errs, "metric must be one of the registered metric IDs")
	}
	if r.Value == nil {
		errs = append(errs, "value is required")
	}
	if r.SchemaVersion != schemaVersion {
		errs = append(errs, "schema_version must be '"+schemaVersion+"'")
	}
	for k, v := range r.Attributes {
		switch v.(type) {
		case string, float64, bool, nil:
		default:
			errs = append(errs, "attributes."+k+" must be a scalar")
		}
	}
	return errs
}

// IngestEvent godoc
// @Summary  Ingest one evidence event
// @Accept   json
// @Produce  json
// @Param    event body eventRequest true "Evidence event"
// @Success  202 {object} map[string]string
// @Failure  400 {object} map[string]interface{}
// @Router   /v1/software-poe/events [post]
func (h *Handler) IngestEvent(c *gin.Context) {
	var req eventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"errors": []string{"invalid JSON body"}})
		return
	}
	if errs := req.validate(); len(errs) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"errors": errs})
		return
	}

	var tenantCount int64
	h.db.Raw(`SELECT count(*) FROM tenants WHERE id = ?`, req.TenantID).Scan(&tenantCount)
	if tenantCount == 0 {
		c.JSON(http.StatusForbidden, gin.H{"errors": []string{"unknown tenant"}})
		return
	}

	observedAt, _ := time.Parse(time.RFC3339, req.ObservedAt)
	canonical, _ := json.Marshal(req)
	sum := sha256.Sum256(canonical)
	payloadHash := "sha256:" + hex.EncodeToString(sum[:])

	attrs, _ := json.Marshal(req.Attributes)
	if req.Attributes == nil {
		attrs = []byte(`{}`)
	}
	event := models.Event{
		TenantID:      req.TenantID,
		Project:       req.Project,
		Source:        req.Source,
		ObservedAt:    observedAt,
		Metric:        req.Metric,
		Value:         *req.Value,
		Unit:          req.Unit,
		EvidenceRef:   req.EvidenceRef,
		SchemaVersion: req.SchemaVersion,
		Attributes:    datatypes.JSON(attrs),
	}
	if event.EvidenceRef == "" {
		event.EvidenceRef = payloadHash
	}

	err := h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&event).Error; err != nil {
			return err
		}
		if err := tx.Create(&models.AnalysisJob{EventID: event.ID, Status: "pending"}).Error; err != nil {
			return err
		}
		return tx.Create(&models.AuditEntry{
			TenantID:    event.TenantID,
			Actor:       event.Source,
			Action:      "ingest",
			ObjectType:  "event",
			ObjectID:    event.ID,
			PayloadHash: payloadHash,
		}).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"errors": []string{"storage failure"}})
		return
	}

	c.JSON(http.StatusAccepted, gin.H{
		"event_id":     event.ID,
		"evidence_ref": event.EvidenceRef,
		"status":       "accepted-for-analysis",
	})
}
