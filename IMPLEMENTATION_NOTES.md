# Stumply feature implementation batch

This batch is based on GitHub `main` commit 6aea4abbfec7845bc1b35688876ad7cc0ac18cc5.

## Included
- Event-sourced scoring engine hardening.
- Safe ball removal/correction primitive with event re-numbering.
- Correct bowler run-concession handling for byes/leg-byes.
- No-ball/wide validation.
- Detailed persistent player aggregate fields.
- Player directory/search UI and repository stream.
- Existing squad/Playing XI flow remains the source of match squad selection.

## Critical backend fix still required
`functions/src/index.ts` currently emits `innings_complete` but checks for `completed` before finalizing a match. Change the check to `innings_complete` and implement second-innings/result-aware finalization before production deployment.

## Remaining product integrations
The repo already contains entry points for tournaments, analytics, streaming, feed, PRO and store. The next implementation batches should connect these to authoritative match event data rather than creating parallel/fake statistics.

## Validation
Run from `apps/mobile`:

    flutter pub get
    flutter analyze
    flutter test

Run from `packages/scoring_engine`:

    dart test

Run from `functions`:

    npm install
    npm run build

Do not deploy Firebase rules/functions until the Firebase project in `.firebaserc` has been verified as the Stumply project.
