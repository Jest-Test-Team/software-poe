# Source — Software POE

建議先實作 `ingest -> validate -> calculate -> explain -> review` 的垂直切片。不要先建立大型平台或黑箱模型。

該垂直切片已實作，程式碼位置：

- `services/gateway-api/` — ingest + validate（Go, gin/gorm/swagger）
- `services/analysis-engine/` — calculate + explain（Python FastAPI + Julia worker）
- `services/review-api/` — review（Rust, axum）
- `frontend/`、`mobile/` — 人工覆核介面
- `sdk/` — python / typescript / go / julia 客戶端

詳見 `docs/implementation-plan.md`。
