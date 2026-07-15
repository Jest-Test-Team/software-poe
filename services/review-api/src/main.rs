//! Software POE review-api: list explainable assessments and record human
//! review decisions. Sits behind the gateway; tenant scoping is mandatory.

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};
use uuid::Uuid;

#[derive(Clone)]
struct AppState {
    pool: PgPool,
}

#[derive(Serialize)]
struct Assessment {
    assessment_id: Uuid,
    tenant_id: String,
    status: String,
    summary: String,
    uncertainty: f64,
    gap_detected: bool,
    missing_data: bool,
    stale_evidence: bool,
    rule_version: Option<String>,
    evidence_refs: Vec<String>,
    human_review_required: bool,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
struct ListParams {
    tenant_id: String,
    status: Option<String>,
}

#[derive(Deserialize)]
struct ReviewRequest {
    reviewer: String,
    decision: String,
    annotation: Option<String>,
}

type ApiError = (StatusCode, Json<serde_json::Value>);

fn err(status: StatusCode, msg: &str) -> ApiError {
    (status, Json(serde_json::json!({ "errors": [msg] })))
}

fn row_to_assessment(row: &sqlx::postgres::PgRow) -> Assessment {
    Assessment {
        assessment_id: row.get("id"),
        tenant_id: row.get("tenant_id"),
        status: row.get("status"),
        summary: row.get("summary"),
        uncertainty: row.get("uncertainty"),
        gap_detected: row.get("gap_detected"),
        missing_data: row.get("missing_data"),
        stale_evidence: row.get("stale_evidence"),
        rule_version: row.get("rule_version"),
        evidence_refs: row.get("evidence_refs"),
        human_review_required: row.get("human_review_required"),
        created_at: row.get("created_at"),
    }
}

async fn list_assessments(
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<Vec<Assessment>>, ApiError> {
    let rows = sqlx::query(
        r#"SELECT id, tenant_id, status, summary, uncertainty, gap_detected,
                  missing_data, stale_evidence, rule_version, evidence_refs,
                  human_review_required, created_at
           FROM assessments
           WHERE tenant_id = $1 AND ($2::text IS NULL OR status = $2)
           ORDER BY created_at DESC LIMIT 200"#,
    )
    .bind(&params.tenant_id)
    .bind(&params.status)
    .fetch_all(&state.pool)
    .await
    .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "query failure"))?;

    Ok(Json(rows.iter().map(row_to_assessment).collect()))
}

async fn get_assessment(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Query(params): Query<ListParams>,
) -> Result<Json<Assessment>, ApiError> {
    let row = sqlx::query(
        r#"SELECT id, tenant_id, status, summary, uncertainty, gap_detected,
                  missing_data, stale_evidence, rule_version, evidence_refs,
                  human_review_required, created_at
           FROM assessments WHERE id = $1 AND tenant_id = $2"#,
    )
    .bind(id)
    .bind(&params.tenant_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "query failure"))?
    .ok_or_else(|| err(StatusCode::NOT_FOUND, "assessment not found for tenant"))?;

    Ok(Json(row_to_assessment(&row)))
}

async fn review_assessment(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Query(params): Query<ListParams>,
    Json(req): Json<ReviewRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    if req.reviewer.trim().is_empty() {
        return Err(err(StatusCode::BAD_REQUEST, "reviewer is required"));
    }
    if req.decision != "accepted" && req.decision != "rejected" {
        return Err(err(StatusCode::BAD_REQUEST, "decision must be 'accepted' or 'rejected'"));
    }

    let mut tx = state
        .pool
        .begin()
        .await
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "tx failure"))?;

    let updated = sqlx::query(
        r#"UPDATE assessments SET status = $1, updated_at = now()
           WHERE id = $2 AND tenant_id = $3 AND status = 'review-required'
           RETURNING id"#,
    )
    .bind(&req.decision)
    .bind(id)
    .bind(&params.tenant_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "update failure"))?;

    if updated.is_none() {
        return Err(err(
            StatusCode::CONFLICT,
            "assessment not found for tenant or not awaiting review",
        ));
    }

    let review_id: Uuid = sqlx::query(
        r#"INSERT INTO reviews (assessment_id, reviewer, decision, annotation)
           VALUES ($1, $2, $3, $4) RETURNING id"#,
    )
    .bind(id)
    .bind(&req.reviewer)
    .bind(&req.decision)
    .bind(&req.annotation)
    .fetch_one(&mut *tx)
    .await
    .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "insert failure"))?
    .get("id");

    sqlx::query(
        r#"INSERT INTO audit_entries (tenant_id, actor, action, object_type, object_id, payload_hash)
           VALUES ($1, $2, 'review', 'assessment', $3, 'sha256:review')"#,
    )
    .bind(&params.tenant_id)
    .bind(&req.reviewer)
    .bind(id.to_string())
    .execute(&mut *tx)
    .await
    .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "audit failure"))?;

    tx.commit()
        .await
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "commit failure"))?;

    Ok(Json(serde_json::json!({
        "review_id": review_id,
        "assessment_id": id,
        "status": req.decision,
    })))
}

async fn healthz() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "status": "ok" }))
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL is required");
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("connect to postgres");

    let app = Router::new()
        .route("/healthz", get(healthz))
        .route("/v1/software-poe/assessments", get(list_assessments))
        .route("/v1/software-poe/assessments/{id}", get(get_assessment))
        .route("/v1/software-poe/assessments/{id}/review", post(review_assessment))
        .with_state(AppState { pool });

    let port = std::env::var("PORT").unwrap_or_else(|_| "8083".into());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .expect("bind");
    tracing::info!("review-api listening on :{port}");
    axum::serve(listener, app).await.expect("server error");
}
