# One-time setup: enable auto Firebase deploy on push to main
#
# 1. Generate a CI token:
#      firebase login:ci
# 2. Add GitHub secret:
#      Repo -> Settings -> Secrets -> Actions -> New secret
#      Name: FIREBASE_TOKEN
#      Value: <token from step 1>
# 3. Push to main branch — deploy-firebase.yml runs automatically

Write-Host @"

GitHub Actions Firebase deploy setup
====================================

1. Run:  firebase login:ci
   Copy the token it prints.

2. Open your GitHub repo -> Settings -> Secrets and variables -> Actions
   Add secret:  FIREBASE_TOKEN = <paste token>

3. Push to main. Workflow deploys:
   - Firestore rules
   - Realtime Database rules
   - Cloud Functions (requires Blaze plan)
   - Firebase Hosting (admin panel)

Note: The mobile APK is NOT auto-deployed. Rebuild with:
  cd apps/mobile && flutter build apk --release

"@ -ForegroundColor Cyan
