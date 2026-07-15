# Software POE — Web frontend

Next.js app deployed on Vercel (Git integration, root directory `frontend/`).

Environment variables (Vercel project settings):

- `NEXT_PUBLIC_API_BASE_URL` — Choreo gateway URL
- `NEXT_PUBLIC_API_KEY` — Choreo-managed API key
- `NEXT_PUBLIC_TENANT_ID` — defaults to `synthetic-lab`

```bash
npm install
npm run dev   # http://localhost:3000, expects gateway on :8081
```
