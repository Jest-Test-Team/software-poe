package models

import (
	"time"

	"gorm.io/datatypes"
)

type Event struct {
	ID            string         `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"event_id"`
	TenantID      string         `json:"tenant_id"`
	Project       string         `json:"project"`
	Source        string         `json:"source"`
	ObservedAt    time.Time      `json:"observed_at"`
	IngestedAt    time.Time      `gorm:"autoCreateTime" json:"ingested_at"`
	Metric        string         `json:"metric"`
	Value         float64        `json:"value"`
	Unit          string         `json:"unit,omitempty"`
	EvidenceRef   string         `json:"evidence_ref,omitempty"`
	SchemaVersion string         `json:"schema_version"`
	Attributes    datatypes.JSON `json:"attributes,omitempty"`
}

func (Event) TableName() string { return "events" }

type AnalysisJob struct {
	ID      int64  `gorm:"primaryKey"`
	EventID string `gorm:"type:uuid"`
	Status  string `gorm:"default:pending"`
}

func (AnalysisJob) TableName() string { return "analysis_jobs" }

type AuditEntry struct {
	ID          int64  `gorm:"primaryKey"`
	TenantID    string
	Actor       string
	Action      string
	ObjectType  string
	ObjectID    string
	PayloadHash string
}

func (AuditEntry) TableName() string { return "audit_entries" }
