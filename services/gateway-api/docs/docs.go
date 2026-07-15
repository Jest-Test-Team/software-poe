// Package docs registers the Swagger spec served at /swagger/index.html.
// Hand-maintained; regenerate with `swag init` if handlers change shape.
package docs

import "github.com/swaggo/swag"

const docTemplate = `{
  "swagger": "2.0",
  "info": {
    "title": "{{.Title}}",
    "description": "{{escape .Description}}",
    "version": "{{.Version}}"
  },
  "host": "{{.Host}}",
  "basePath": "{{.BasePath}}",
  "paths": {
    "/v1/software-poe/events": {
      "post": {
        "summary": "Ingest one evidence event",
        "consumes": ["application/json"],
        "produces": ["application/json"],
        "parameters": [{
          "name": "event", "in": "body", "required": true,
          "schema": { "$ref": "#/definitions/Event" }
        }],
        "responses": {
          "202": { "description": "Accepted for validation and analysis" },
          "400": { "description": "Schema validation errors" },
          "401": { "description": "Invalid API key" },
          "403": { "description": "Unknown tenant" }
        }
      }
    },
    "/v1/software-poe/assessments": {
      "get": {
        "summary": "List explainable assessments (proxied to review-api)",
        "parameters": [{ "name": "tenant_id", "in": "query", "required": true, "type": "string" }],
        "responses": { "200": { "description": "Assessment list" } }
      }
    },
    "/v1/software-poe/assessments/{id}/review": {
      "post": {
        "summary": "Record a human review decision (proxied to review-api)",
        "parameters": [
          { "name": "id", "in": "path", "required": true, "type": "string" },
          { "name": "review", "in": "body", "required": true, "schema": { "$ref": "#/definitions/Review" } }
        ],
        "responses": { "200": { "description": "Review recorded" } }
      }
    }
  },
  "definitions": {
    "Event": {
      "type": "object",
      "required": ["tenant_id", "project", "source", "observed_at", "metric", "value", "schema_version"],
      "properties": {
        "tenant_id": { "type": "string" },
        "project": { "type": "string", "enum": ["software-poe"] },
        "source": { "type": "string" },
        "observed_at": { "type": "string", "format": "date-time" },
        "metric": { "type": "string" },
        "value": { "type": "number" },
        "unit": { "type": "string" },
        "evidence_ref": { "type": "string" },
        "schema_version": { "type": "string", "enum": ["0.1.0"] },
        "attributes": { "type": "object" }
      }
    },
    "Review": {
      "type": "object",
      "required": ["reviewer", "decision"],
      "properties": {
        "reviewer": { "type": "string" },
        "decision": { "type": "string", "enum": ["accepted", "rejected"] },
        "annotation": { "type": "string" }
      }
    }
  }
}`

var SwaggerInfo = &swag.Spec{
	Version:          "0.1.0",
	Host:             "",
	BasePath:         "/",
	Title:            "Software POE Gateway API",
	Description:      "Synthetic-data, human-review-oriented ingestion gateway.",
	InfoInstanceName: "swagger",
	SwaggerTemplate:  docTemplate,
}

func init() {
	swag.Register(SwaggerInfo.InstanceName(), SwaggerInfo)
}
