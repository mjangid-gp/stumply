import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onValueWritten } from 'firebase-functions/v2/database';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';

export { sendRegistrationOtp, registerWithEmailOtp } from './email-otp';

admin.initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

// ─── Live scoring: validate ball events and update Firestore ───
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
    const eventsSnap = await admin
      .database()
      .ref(`liveMatches/${matchId}/events`)
      .orderByChild('sequence')
      .get();

    const events: Record<string, unknown>[] = [];
    eventsSnap.forEach((child) => {
      events.push(child.val() as Record<string, unknown>);
    });

    const innings = computeInningsState(events, match.totalOvers ?? 20);
    await matchRef.update({
      liveScore: innings,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.database().ref(`liveMatches/${matchId}/state`).set(innings);

    if (innings.status === 'completed') {
      await finalizeMatch(db, matchId, match, innings);
    }
  }
);

interface InningsState {
  totalRuns: number;
  wickets: number;
  overs: number;
  ballsInOver: number;
  runRate: number;
  status: string;
  result?: string;
}

function computeInningsState(
  events: Record<string, unknown>[],
  totalOvers: number
): InningsState {
  let runs = 0;
  let wickets = 0;
  let overs = 0;
  let ballsInOver = 0;

  for (const e of events) {
    runs += (e.runsOffBat as number) + (e.extraRuns as number ?? 0);
    if (e.wicketType) wickets++;
    const isLegal = e.extraType !== 'wide' && e.extraType !== 'noBall';
    if (isLegal) {
      ballsInOver++;
      if (ballsInOver === 6) {
        overs++;
        ballsInOver = 0;
      }
    }
  }

  const totalBalls = overs * 6 + ballsInOver;
  const runRate = totalBalls > 0 ? runs / (totalBalls / 6) : 0;
  const maxWickets = 10;
  const status =
    wickets >= maxWickets || totalBalls >= totalOvers * 6
      ? 'innings_complete'
      : 'in_progress';

  return { totalRuns: runs, wickets, overs, ballsInOver, runRate, status };
}

async function finalizeMatch(
  db: admin.firestore.Firestore,
  matchId: string,
  match: admin.firestore.DocumentData,
  innings: InningsState
) {
  await db.collection('matches').doc(matchId).update({
    status: 'completed',
    result: innings.result ?? 'Match completed',
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const playerIds = [
    ...(match.teamAPlayers ?? []),
    ...(match.teamBPlayers ?? []),
  ] as string[];

  for (const playerId of playerIds) {
    await updatePlayerStats(db, playerId, matchId);
  }
}

async function updatePlayerStats(
  db: admin.firestore.Firestore,
  playerId: string,
  matchId: string
) {
  const playerRef = db.collection('players').doc(playerId);
  await playerRef.set(
    {
      matchesPlayed: admin.firestore.FieldValue.increment(1),
      lastMatchId: matchId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

// ─── Tournament points table update ───
export const onMatchCompleted = onDocumentWritten(
  'matches/{matchId}',
  async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();
    if (!after || after.status !== 'completed' || before?.status === 'completed') {
      return;
    }
    if (!after.tournamentId) return;

    const db = admin.firestore();
    const tournamentRef = db.collection('tournaments').doc(after.tournamentId);
    const tournament = (await tournamentRef.get()).data();
    if (!tournament) return;

    const pointsTable = computePointsTable(
      tournament.pointsTable ?? {},
      after
    );
    await tournamentRef.update({ pointsTable, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  }
);

function computePointsTable(
  current: Record<string, unknown>,
  match: admin.firestore.DocumentData
): Record<string, unknown> {
  const table = { ...current };
  const winnerId = match.winnerId as string;
  const loserId = match.loserId as string;
  const isTie = match.isTie as boolean;

  const updateTeam = (teamId: string, won: boolean, tied: boolean) => {
    const entry = (table[teamId] as Record<string, number>) ?? {
      played: 0, won: 0, lost: 0, tied: 0, points: 0,
      runsScored: 0, runsConceded: 0, oversFaced: 0, oversBowled: 0,
    };
    entry.played++;
    if (tied) { entry.tied++; entry.points += 1; }
    else if (won) { entry.won++; entry.points += 2; }
    else { entry.lost++; }
    table[teamId] = entry;
  };

  if (isTie) {
    updateTeam(match.teamAId, false, true);
    updateTeam(match.teamBId, false, true);
  } else {
    updateTeam(winnerId, true, false);
    updateTeam(loserId, false, false);
  }
  return table;
}

// ─── Callable: generate tournament fixtures ───
export const generateFixtures = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { tournamentId, teamIds, format } = request.data as {
    tournamentId: string;
    teamIds: string[];
    format: 'round_robin' | 'knockout';
  };

  if (!tournamentId || !teamIds?.length) {
    throw new HttpsError('invalid-argument', 'Missing tournamentId or teamIds');
  }

  const fixtures = format === 'knockout'
    ? generateKnockout(teamIds)
    : generateRoundRobin(teamIds);

  const db = admin.firestore();
  const batch = db.batch();
  fixtures.forEach((f, i) => {
    const ref = db.collection('matches').doc();
    batch.set(ref, {
      ...f,
      tournamentId,
      status: 'scheduled',
      createdBy: request.auth!.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      matchNumber: i + 1,
    });
  });
  await batch.commit();
  return { fixtureCount: fixtures.length };
});

function generateRoundRobin(teamIds: string[]) {
  const teams = [...teamIds];
  if (teams.length % 2 !== 0) teams.push('BYE');
  const n = teams.length;
  const fixtures = [];
  let roundTeams = [...teams];
  for (let round = 0; round < n - 1; round++) {
    for (let i = 0; i < n / 2; i++) {
      const home = roundTeams[i];
      const away = roundTeams[n - 1 - i];
      if (home !== 'BYE' && away !== 'BYE') {
        fixtures.push({ round: round + 1, teamAId: home, teamBId: away, homeTeamId: home, awayTeamId: away });
      }
    }
    const last = roundTeams.pop()!;
    roundTeams.splice(1, 0, last);
  }
  return fixtures;
}

function generateKnockout(teamIds: string[]) {
  const fixtures = [];
  let round = 1;
  let current = [...teamIds];
  while (current.length > 1) {
    if (current.length % 2 !== 0) current.push('BYE');
    const next = [];
    for (let i = 0; i < current.length; i += 2) {
      const home = current[i];
      const away = current[i + 1];
      if (home !== 'BYE' && away !== 'BYE') {
        fixtures.push({ round, teamAId: home, teamBId: away, isKnockout: true });
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

// ─── Callable: search index placeholder ───
export const searchEntities = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { query, type } = request.data as { query: string; type?: string };
  const db = admin.firestore();
  const collections = type ? [type] : ['players', 'teams', 'tournaments', 'grounds'];
  const results: Record<string, unknown>[] = [];

  for (const col of collections) {
    const snap = await db.collection(col)
      .where('searchTerms', 'array-contains', query.toLowerCase())
      .limit(10)
      .get();
    snap.docs.forEach((d) => results.push({ id: d.id, type: col, ...d.data() }));
  }
  return { results };
});

// ─── User onboarding: create player profile on signup ───
export const onUserCreated = onDocumentWritten('users/{userId}', async (event) => {
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
    stats: { matches: 0, runs: 0, wickets: 0, catches: 0 },
    badges: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    searchTerms: [(after.displayName ?? 'player').toLowerCase()],
  });
});
