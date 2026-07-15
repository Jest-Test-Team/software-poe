// Package softwarepoe is the Go client SDK for Software POE
// (post-occupancy evaluation for software architecture).
// It mirrors schemas/event.schema.json version 0.1.0.
package softwarepoe

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	SchemaVersion = "0.1.0"
	Project       = "software-poe"
)

// Metrics is the registered metric ID set.
var Metrics = map[string]bool{
	"intent_fulfillment_ratio": true,
	"slo_gap":                  true,
	"cost_estimate_error":      true,
	"unused_capability_ratio":  true,
	"incident_delta":           true,
}

type Event struct {
	TenantID      string         `json:"tenant_id"`
	Project       string         `json:"project"`
	Source        string         `json:"source"`
	ObservedAt    string         `json:"observed_at"`
	Metric        string         `json:"metric"`
	Value         float64        `json:"value"`
	Unit          string         `json:"unit,omitempty"`
	EvidenceRef   string         `json:"evidence_ref,omitempty"`
	SchemaVersion string         `json:"schema_version"`
	Attributes    map[string]any `json:"attributes,omitempty"`
}

// Validate checks the event against the 0.1.0 contract. Zero-valued
// Project/SchemaVersion fields are filled with the supported constants.
func (e *Event) Validate() []string {
	if e.Project == "" {
		e.Project = Project
	}
	if e.SchemaVersion == "" {
		e.SchemaVersion = SchemaVersion
	}
	var errs []string
	if e.TenantID == "" {
		errs = append(errs, "tenant_id is required")
	}
	if e.Project != Project {
		errs = append(errs, "project must be '"+Project+"'")
	}
	if e.Source == "" {
		errs = append(errs, "source is required")
	}
	if _, err := time.Parse(time.RFC3339, e.ObservedAt); err != nil {
		errs = append(errs, "observed_at must be an RFC3339 date-time")
	}
	if !Metrics[e.Metric] {
		errs = append(errs, "metric must be a registered metric ID")
	}
	if e.SchemaVersion != SchemaVersion {
		errs = append(errs, "schema_version must be '"+SchemaVersion+"'")
	}
	for k, v := range e.Attributes {
		switch v.(type) {
		case string, float64, int, bool, nil:
		default:
			errs = append(errs, "attributes."+k+" must be a scalar")
		}
	}
	return errs
}

type Assessment struct {
	AssessmentID        string   `json:"assessment_id"`
	TenantID            string   `json:"tenant_id"`
	Status              string   `json:"status"`
	Summary             string   `json:"summary"`
	Uncertainty         float64  `json:"uncertainty"`
	GapDetected         bool     `json:"gap_detected"`
	MissingData         bool     `json:"missing_data"`
	StaleEvidence       bool     `json:"stale_evidence"`
	RuleVersion         *string  `json:"rule_version"`
	EvidenceRefs        []string `json:"evidence_refs"`
	HumanReviewRequired bool     `json:"human_review_required"`
	CreatedAt           string   `json:"created_at"`
}

type Client struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewClient(baseURL, apiKey string) *Client {
	return &Client{
		baseURL: baseURL,
		apiKey:  apiKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *Client) do(method, path string, body any, out any) error {
	var reader io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(buf)
	}
	req, err := http.NewRequest(method, c.baseURL+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		msg, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("http %d: %s", resp.StatusCode, msg)
	}
	if out == nil {
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

type IngestResponse struct {
	EventID     string `json:"event_id"`
	EvidenceRef string `json:"evidence_ref"`
	Status      string `json:"status"`
}

func (c *Client) Ingest(event *Event) (*IngestResponse, error) {
	if errs := event.Validate(); len(errs) > 0 {
		return nil, fmt.Errorf("invalid event: %v", errs)
	}
	var out IngestResponse
	if err := c.do(http.MethodPost, "/v1/software-poe/events", event, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) Assessments(tenantID, status string) ([]Assessment, error) {
	q := url.Values{"tenant_id": {tenantID}}
	if status != "" {
		q.Set("status", status)
	}
	var out []Assessment
	if err := c.do(http.MethodGet, "/v1/software-poe/assessments?"+q.Encode(), nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

type ReviewRequest struct {
	Reviewer   string `json:"reviewer"`
	Decision   string `json:"decision"`
	Annotation string `json:"annotation,omitempty"`
}

func (c *Client) Review(assessmentID, tenantID string, review ReviewRequest) error {
	q := url.Values{"tenant_id": {tenantID}}
	path := "/v1/software-poe/assessments/" + assessmentID + "/review?" + q.Encode()
	return c.do(http.MethodPost, path, review, nil)
}
