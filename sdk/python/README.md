# software-poe (Python SDK)

Client for the Software POE gateway: validate + ingest evidence events, list assessments, record reviews.

```python
from software_poe import Client, Event

client = Client("https://<choreo-gateway>", api_key="...")
client.ingest(Event(
    tenant_id="synthetic-lab",
    source="synthetic-fixture",
    observed_at="2026-07-11T08:00:00Z",
    metric="intent_fulfillment_ratio",
    value=0.42,
))
for a in client.assessments(tenant_id="synthetic-lab"):
    print(a["summary"], a["uncertainty"])
```
