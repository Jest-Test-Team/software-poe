# Software POE — Mobile (Flutter)

Review-only companion app: browse the review queue, inspect evidence/uncertainty flags, and record accept/reject decisions.

Platform folders (android/, ios/) are not committed. Generate them once:

```bash
cd mobile
flutter create . --platforms=android,ios
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://<choreo-gateway> \
  --dart-define=API_KEY=<key> \
  --dart-define=TENANT_ID=synthetic-lab
```
