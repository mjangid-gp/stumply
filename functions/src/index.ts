import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onValueWritten } from 'firebase-functions/v2/database';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';

export { sendRegistrationOtp, registerWithEmailOtp } from './email-otp';

admin.initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

interface InningsState {
  inningsNumber: number;
  totalRuns: number;
  wickets: number;
  overs: number;
  ballsInOver: number;
  legalBalls: number;
  runRate: number;
  status: 'in_progress' | 'innings_break' | 'completed';
}

interface MatchState extends InningsState {
  currentInnings: number;
  target?: number;
  result?: string;
  winnerId?: string | null;
  loserId?: string | null;
  isTie?: boolean;
  firstInnings?: InningsState;
  secondInnings?: InningsState;
}

// ─── Live scoring ────────────────────────────────────────────────────────────
//
// The match is rebuilt from the complete RTDB ball-event history.
//
// Important:
// 1. End of innings 1 is NOT the end of the match.
// 2. A chase completes immediately when score >= target.
// 3. The second innings completes when all out or all overs are used.
// 4. The old implementation produced "innings_complete" but only checked for
//    "completed", so finalizeMatch() could never run.

export const onBallEventWritten = onValueWritten(
  '/liveMatches/{matchId}/events/{seq}',
  async (event) => {
    const matchId = event.params.matchId;
    const ballData = event.data.after.val();

    if (!ballData) return;

    const db = admin.firestore();
    const matchRef = db.collection('matches').doc(matchId);
    const matchSnap = await matchRef.get();

    if (!matchSnap.exists) return;

    const match = matchSnap.data()!;

    // A completed match should not be reopened by a late/duplicate event.
    if (match.status === 'completed') return;

    const eventsSnap = await admin
      .database()
      .ref(`liveMatches/${matchId}/events`)
      .orderByChild('sequence')
      .get();

    const events: Record<string, unknown>[] = [];

    eventsSnap.forEach((child) => {
      const value = child.val();

      if (value && typeof value === 'object') {
        events.push(value as Record<string, unknown>);
      }
    });

    events.sort(
      (a, b) => Number(a.sequence ?? 0) - Number(b.sequence ?? 0),
    );

    const state = computeMatchState(
      events,
      Number(match.totalOvers ?? 20),
      match,
    );

    await matchRef.update({
      liveScore: state,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin
      .database()
      .ref(`liveMatches/${matchId}/state`)
      .set(state);

    if (state.status === 'completed') {
      await finalizeMatch(db, matchId, match, state);
    }
  },
);

function computeMatchState(
  events: Record<string, unknown>[],
  totalOvers: number,
  match: admin.firestore.DocumentData,
): MatchState {
  const grouped = new Map<number, Record<string, unknown>[]>();

  for (const event of events) {
    const inningsNumber = Number(event.inningsNumber ?? 1);

    if (!grouped.has(inningsNumber)) {
      grouped.set(inningsNumber, []);
    }

    grouped.get(inningsNumber)!.push(event);
  }

  const firstEvents = grouped.get(1) ?? [];
  const firstInnings = calculateInningsState(
    firstEvents,
    1,
    totalOvers,
  );

  // First innings is still running.
  if (!isInningsComplete(firstInnings, totalOvers)) {
    return {
      ...firstInnings,
      currentInnings: 1,
      status: 'in_progress',
      firstInnings,
    };
  }

  // First innings has ended, but second innings has not started yet.
  const secondEvents = grouped.get(2) ?? [];

  if (secondEvents.length === 0) {
    return {
      ...firstInnings,
      currentInnings: 2,
      status: 'innings_break',
      target: firstInnings.totalRuns + 1,
      firstInnings,
    };
  }

  const secondInnings = calculateInningsState(
    secondEvents,
    2,
    totalOvers,
  );

  const target = firstInnings.totalRuns + 1;

  // ── Successful chase ──────────────────────────────────────────────────────
  if (secondInnings.totalRuns >= target) {
    const battingTeamId = battingTeamForSecondInnings(match);
    const defendingTeamId = otherTeamId(match, battingTeamId);

    return {
      ...secondInnings,
      currentInnings: 2,
      status: 'completed',
      target,
      result:
        `${displayTeamName(match, battingTeamId)} won by ` +
        `${Math.max(0, 10 - secondInnings.wickets)} wickets`,
      winnerId: battingTeamId,
      loserId: defendingTeamId,
      isTie: false,
      firstInnings,
      secondInnings,
    };
  }

  // ── Second innings ended without reaching the target ───────────────────────
  if (isInningsComplete(secondInnings, totalOvers)) {
    const battingTeamId = battingTeamForSecondInnings(match);
    const defendingTeamId = otherTeamId(match, battingTeamId);

    if (secondInnings.totalRuns === firstInnings.totalRuns) {
      return {
        ...secondInnings,
        currentInnings: 2,
        status: 'completed',
        target,
        result: 'Match tied',
        winnerId: null,
        loserId: null,
        isTie: true,
        firstInnings,
        secondInnings,
      };
    }

    return {
      ...secondInnings,
      currentInnings: 2,
      status: 'completed',
      target,
      result:
        `${displayTeamName(match, defendingTeamId)} won by ` +
        `${firstInnings.totalRuns - secondInnings.totalRuns} runs`,
      winnerId: defendingTeamId,
      loserId: battingTeamId,
      isTie: false,
      firstInnings,
      secondInnings,
    };
  }

  // Second innings is still running.
  return {
    ...secondInnings,
    currentInnings: 2,
    status: 'in_progress',
    target,
    firstInnings,
    secondInnings,
  };
}

function calculateInningsState(
  events: Record<string, unknown>[],
  inningsNumber: number,
  totalOvers: number,
): InningsState {
  let runs = 0;
  let wickets = 0;
  let legalBalls = 0;

  for (const event of events) {
    const runsOffBat = Number(event.runsOffBat ?? 0);
    const extraRuns = Number(event.extraRuns ?? 0);

    runs += runsOffBat + extraRuns;

    const wicketType = event.wicketType;
    if (wicketType && wicketType !== 'retiredOut') {
      wickets++;
    }

    const extraType = event.extraType;
    const isLegal =
      extraType !== 'wide' &&
      extraType !== 'noBall';

    if (isLegal) {
      legalBalls++;
    }
  }

  const overs = Math.floor(legalBalls / 6);
  const ballsInOver = legalBalls % 6;
  const runRate =
    legalBalls > 0 ? runs / (legalBalls / 6) : 0;

  return {
    inningsNumber,
    totalRuns: runs,
    wickets,
    overs,
    ballsInOver,
    legalBalls,
    runRate,
    status: isInningsCompleteByValues(
      wickets,
      legalBalls,
      totalOvers,
    )
      ? 'innings_break'
      : 'in_progress',
  };
}

function isInningsComplete(
  innings: InningsState,
  totalOvers: number,
): boolean {
  return isInningsCompleteByValues(
    innings.wickets,
    innings.legalBalls,
    totalOvers,
  );
}

function isInningsCompleteByValues(
  wickets: number,
  legalBalls: number,
  totalOvers: number,
): boolean {
  return wickets >= 10 || legalBalls >= totalOvers * 6;
}

// ─── Team / toss helpers ─────────────────────────────────────────────────────

function battingTeamForSecondInnings(
  match: admin.firestore.DocumentData,
): string | null {
  const teamAId = match.teamAId as string | undefined;
  const teamBId = match.teamBId as string | undefined;
  const tossWinnerId = match.tossWinnerId as string | undefined;
  const tossDecision = match.tossDecision as string | undefined;

  if (!teamAId || !teamBId) return null;

  if (!tossWinnerId || !tossDecision) {
    // Fallback for old matches that don't have toss metadata.
    return teamBId;
  }

  if (tossDecision === 'bat') {
    return tossWinnerId === teamAId ? teamBId : teamAId;
  }

  // Toss winner chose to bowl, therefore they bat second.
  return tossWinnerId;
}

function otherTeamId(
  match: admin.firestore.DocumentData,
  teamId: string | null,
): string | null {
  if (!teamId) return null;

  const teamAId = match.teamAId as string | undefined;
  const teamBId = match.teamBId as string | undefined;

  if (teamId === teamAId) return teamBId ?? null;
  if (teamId === teamBId) return teamAId ?? null;

  return null;
}

function displayTeamName(
  match: admin.firestore.DocumentData,
  teamId: string | null,
): string {
  if (teamId === match.teamAId) {
    return (match.teamAName as string | undefined) ?? 'Team A';
  }

  if (teamId === match.teamBId) {
    return (match.teamBName as string | undefined) ?? 'Team B';
  }

  return 'Batting team';
}

// ─── Match finalization ──────────────────────────────────────────────────────

async function finalizeMatch(
  db: admin.firestore.Firestore,
  matchId: string,
  match: admin.firestore.DocumentData,
  state: MatchState,
) {
  const matchRef = db.collection('matches').doc(matchId);
  const currentSnap = await matchRef.get();

  if (!currentSnap.exists) return;

  const current = currentSnap.data()!;

  // Prevent duplicate processing if multiple RTDB events trigger this
  // function close together.
  if (current.status === 'completed') return;

  await matchRef.update({
    status: 'completed',
    result: state.result ?? 'Match completed',
    winnerId: state.winnerId ?? null,
    loserId: state.loserId ?? null,
    isTie: state.isTie ?? false,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    liveScore: state,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const playerIds = [
    ...(match.teamAPlayers ?? []),
    ...(match.teamBPlayers ?? []),
  ] as string[];

  for (const playerId of [...new Set(playerIds)]) {
    await updatePlayerStats(db, playerId, matchId);
  }
}

async function updatePlayerStats(
  db: admin.firestore.Firestore,
  playerId: string,
  matchId: string,
) {
  await db.collection('players').doc(playerId).set(
    {
      matchesPlayed: admin.firestore.FieldValue.increment(1),
      lastMatchId: matchId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

// ─── Tournament points table update ──────────────────────────────────────────

export const onMatchCompleted = onDocumentWritten(
  'matches/{matchId}',
  async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();

    if (
      !after ||
      after.status !== 'completed' ||
      before?.status === 'completed'
    ) {
      return;
    }

    if (!after.tournamentId) return;

    const db = admin.firestore();
    const tournamentRef = db
      .collection('tournaments')
      .doc(after.tournamentId);

    const tournament = (await tournamentRef.get()).data();
    if (!tournament) return;

    const pointsTable = computePointsTable(
      tournament.pointsTable ?? {},
      after,
    );

    await tournamentRef.update({
      pointsTable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

function computePointsTable(
  current: Record<string, unknown>,
  match: admin.firestore.DocumentData,
): Record<string, unknown> {
  const table = { ...current };

  const winnerId = match.winnerId as string | null;
  const loserId = match.loserId as string | null;
  const isTie = match.isTie as boolean;

  const updateTeam = (
    teamId: string,
    won: boolean,
    tied: boolean,
  ) => {
    const existing = table[teamId];

    const entry: Record<string, number> =
      existing && typeof existing === 'object'
        ? { ...(existing as Record<string, number>) }
        : {
            played: 0,
            won: 0,
            lost: 0,
            tied: 0,
            points: 0,
            runsScored: 0,
            runsConceded: 0,
            oversFaced: 0,
            oversBowled: 0,
          };

    entry.played++;

    if (tied) {
      entry.tied++;
      entry.points += 1;
    } else if (won) {
      entry.won++;
      entry.points += 2;
    } else {
      entry.lost++;
    }

    table[teamId] = entry;
  };

  if (isTie) {
    updateTeam(match.teamAId, false, true);
    updateTeam(match.teamBId, false, true);
  } else if (winnerId && loserId) {
    updateTeam(winnerId, true, false);
    updateTeam(loserId, false, false);
  }

  return table;
}

// ─── Tournament fixture generation ───────────────────────────────────────────

export const generateFixtures = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login required');
  }

  const { tournamentId, teamIds, format } = request.data as {
    tournamentId: string;
    teamIds: string[];
    format: 'round_robin' | 'knockout';
  };

  if (!tournamentId || !teamIds?.length) {
    throw new HttpsError(
      'invalid-argument',
      'Missing tournamentId or teamIds',
    );
  }

  const fixtures =
    format === 'knockout'
      ? generateKnockout(teamIds)
      : generateRoundRobin(teamIds);

  const db = admin.firestore();
  const batch = db.batch();

  fixtures.forEach((fixture, index) => {
    const ref = db.collection('matches').doc();

    batch.set(ref, {
      ...fixture,
      tournamentId,
      status: 'scheduled',
      createdBy: request.auth!.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      matchNumber: index + 1,
    });
  });

  await batch.commit();

  return { fixtureCount: fixtures.length };
});

function generateRoundRobin(teamIds: string[]) {
  const teams = [...teamIds];

  if (teams.length % 2 !== 0) {
    teams.push('BYE');
  }

  const n = teams.length;
  const fixtures: Record<string, unknown>[] = [];
  let roundTeams = [...teams];

  for (let round = 0; round < n - 1; round++) {
    for (let i = 0; i < n / 2; i++) {
      const home = roundTeams[i];
      const away = roundTeams[n - 1 - i];

      if (home !== 'BYE' && away !== 'BYE') {
        fixtures.push({
          round: round + 1,
          teamAId: home,
          teamBId: away,
          homeTeamId: home,
          awayTeamId: away,
        });
      }
    }

    const last = roundTeams.pop()!;
    roundTeams.splice(1, 0, last);
  }

  return fixtures;
}

function generateKnockout(teamIds: string[]) {
  const fixtures: Record<string, unknown>[] = [];
  let round = 1;
  let current = [...teamIds];

  while (current.length > 1) {
    if (current.length % 2 !== 0) {
      current.push('BYE');
    }

    const next: string[] = [];

    for (let i = 0; i < current.length; i += 2) {
      const home = current[i];
      const away = current[i + 1];

      if (home !== 'BYE' && away !== 'BYE') {
        fixtures.push({
          round,
          teamAId: home,
          teamBId: away,
          isKnockout: true,
        });

        next.push(`TBD_R${round}_${i}`);
      } else {
        next.push(home === 'BYE' ? away : home);
      }
    }

    current = next;
    round++;
  }

  return fixtures;
}

// ─── Search ──────────────────────────────────────────────────────────────────

export const searchEntities = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login required');
  }

  const { query, type } = request.data as {
    query: string;
    type?: string;
  };

  const db = admin.firestore();
  const collections = type
    ? [type]
    : ['players', 'teams', 'tournaments', 'grounds'];

  const results: Record<string, unknown>[] = [];

  for (const collection of collections) {
    const snapshot = await db
      .collection(collection)
      .where(
        'searchTerms',
        'array-contains',
        query.toLowerCase(),
      )
      .limit(10)
      .get();

    snapshot.docs.forEach((doc) => {
      results.push({
        id: doc.id,
        type: collection,
        ...doc.data(),
      });
    });
  }

  return { results };
});

// ─── User onboarding ─────────────────────────────────────────────────────────

export const onUserCreated = onDocumentWritten(
  'users/{userId}',
  async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();

    if (!after || before) return;

    const db = admin.firestore();
    const userId = event.params.userId;

    await db.collection('players').doc(userId).set({
      userId,
      displayName: after.displayName ?? 'Player',
      city: after.city ?? '',
      battingStyle: after.battingStyle ?? 'right',
      bowlingStyle: after.bowlingStyle ?? 'none',
      stats: {
        matches: 0,
        runs: 0,
        wickets: 0,
        catches: 0,
      },
      badges: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      searchTerms: [
        (after.displayName ?? 'player').toLowerCase(),
      ],
    });
  },
);
