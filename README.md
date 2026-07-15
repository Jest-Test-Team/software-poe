# Software POE

**中文名稱：** 軟體使用後評估  
**建築學來源：** Post-Occupancy Evaluation（使用後評估）

## 核心問題

> 架構承諾、ADR 假設與非功能需求是否在正式營運後真正實現？

## Problem statement

部署完成後，團隊通常只觀測 uptime、latency 與 error rate，缺少「設計意圖 vs. 實際結果」的長期問責。

## Inputs

- ADR 與設計假設
- SLO/SLI
- OpenTelemetry traces/metrics/logs
- 雲端帳單
- 事故與變更紀錄
- 功能使用率


## Outputs

- Architecture Performance Gap
- 未實現 ADR 清單
- 過度設計元件
- 設計假設失效時間線


## Primary metrics

| Metric ID | 初始用途 |
|---|---|
| `intent_fulfillment_ratio` | 建立 baseline、趨勢與 review trigger；正式公式見後續 metric registry。 |
| `slo_gap` | 建立 baseline、趨勢與 review trigger；正式公式見後續 metric registry。 |
| `cost_estimate_error` | 建立 baseline、趨勢與 review trigger；正式公式見後續 metric registry。 |
| `unused_capability_ratio` | 建立 baseline、趨勢與 review trigger；正式公式見後續 metric registry。 |
| `incident_delta` | 建立 baseline、趨勢與 review trigger；正式公式見後續 metric registry。 |


## MVP scope

1. 匯入 ADR YAML
2. 接收每日 KPI snapshot
3. 比較 expected/actual
4. 產生 gap report 與 review queue


## Out of scope for MVP

- 自動執行高風險變更
- 以單一分數取代專業審查
- 未經授權蒐集個人、員工、病患或客戶敏感資料
- 宣稱已建立普遍適用的因果關係

## Repository contract

- `project.yaml`：machine-readable project manifest
- `api/openapi.yaml`：最小 ingestion / assessment API
- `schemas/event.schema.json`：事件資料契約
- `docs/architecture.md`：邊界、資料流與 implementation slices
- `docs/threat-model.md`：安全、隱私與濫用風險
- `docs/implementation-plan.md`：實作計畫（stack、部署、發佈）
- `examples/sample-event.json`：合成資料範例

## Implementation layout

- `services/`：3 個後端服務（Go gateway、Python+Julia analysis、Rust review），各含 Dockerfile，部署於 Choreo；資料庫為 Neon (Postgres)
- `frontend/`：Next.js（Vercel）
- `mobile/`：Flutter 覆核用 companion app
- `sdk/`：python（PyPI `software-poe`）、typescript（npm `@dennislee928/software-poe`）、go、julia（`SoftwarePOE.jl`）
- `tests/robot/`：Robot Framework 黑箱測試
- `.github/workflows/`：CI、Robot、四種套件發佈

### Local development

```bash
docker compose up -d --build   # postgres + 3 services；gateway 於 :8081（X-API-Key: local-dev-key）
cd frontend && npm install && npm run dev
```

## First implementation milestone

先完成 **single-tenant, synthetic-data, read-only analysis**。在證據追溯、權限、資料保留與人工覆核尚未建立前，不進入真實組織或個人資料環境。
