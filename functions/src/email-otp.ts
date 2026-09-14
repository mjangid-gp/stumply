import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as nodemailer from 'nodemailer';

const smtpUser = defineSecret('SMTP_USER');
const smtpPassword = defineSecret('SMTP_PASSWORD');

const OTP_EXPIRY_MS = 10 * 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60 * 1000;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function hashOtp(email: string, otp: string): string {
  return crypto.createHash('sha256').update(`${email}:${otp}:stumply`).digest('hex');
}

function generateOtp(): string {
  return String(crypto.randomInt(100000, 999999));
}

function validatePassword(password: string): void {
  if (password.length < 8) {
    throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');
  }
  if (!/[A-Z]/.test(password)) {
    throw new HttpsError('invalid-argument', 'Password must include an uppercase letter.');
  }
  if (!/[a-z]/.test(password)) {
    throw new HttpsError('invalid-argument', 'Password must include a lowercase letter.');
  }
  if (!/[0-9]/.test(password)) {
    throw new HttpsError('invalid-argument', 'Password must include a number.');
  }
  if (!/[!@#$%^&*(),.?":{}|<>_\-+=[\]\\;/`~]/.test(password)) {
    throw new HttpsError('invalid-argument', 'Password must include a special character.');
  }
}

function getMailer(user: string, pass: string) {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: { user, pass },
  });
}

async function emailExists(email: string): Promise<boolean> {
  try {
    await admin.auth().getUserByEmail(email);
    return true;
  } catch (error: unknown) {
    const code = (error as { code?: string }).code;
    if (code === 'auth/user-not-found') return false;
    throw error;
  }
}

export const sendRegistrationOtp = onCall(
  { secrets: [smtpUser, smtpPassword], region: 'asia-south1' },
  async (request) => {
    const email = normalizeEmail((request.data?.email as string) ?? '');
    const displayName = ((request.data?.displayName as string) ?? '').trim();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Valid email is required.');
    }
    if (!displayName) {
      throw new HttpsError('invalid-argument', 'Name is required.');
    }

    if (await emailExists(email)) {
      throw new HttpsError('already-exists', 'An account with this email already exists.');
    }

    const db = admin.firestore();
    const ref = db.collection('emailVerificationOtps').doc(email);
    const existing = await ref.get();
    const now = Date.now();

    if (existing.exists) {
      const data = existing.data()!;
      const lastSent = data.lastSentAt?.toMillis?.() ?? 0;
      if (now - lastSent < RESEND_COOLDOWN_MS) {
        throw new HttpsError(
          'resource-exhausted',
          'Please wait a minute before requesting another OTP.'
        );
      }
    }

    const otp = generateOtp();
    const transporter = getMailer(smtpUser.value(), smtpPassword.value());

    await transporter.sendMail({
      from: `Stumply <${smtpUser.value()}>`,
      to: email,
      subject: 'Your Stumply verification code',
      text: `Hi ${displayName},\n\nYour Stumply verification code is: ${otp}\n\nThis code expires in 10 minutes.\n\nIf you did not request this, ignore this email.`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px">
          <h2 style="color:#1B4332">Stumply</h2>
          <p>Hi ${displayName},</p>
          <p>Use this code to verify your email and create your account:</p>
          <p style="font-size:32px;font-weight:bold;letter-spacing:6px;color:#1B4332">${otp}</p>
          <p style="color:#666">Expires in 10 minutes. Do not share this code.</p>
        </div>
      `,
    });

    await ref.set({
      otpHash: hashOtp(email, otp),
      displayName,
      expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_EXPIRY_MS),
      attempts: 0,
      lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, expiresInSeconds: OTP_EXPIRY_MS / 1000 };
  }
);

export const registerWithEmailOtp = onCall(
  { region: 'asia-south1' },
  async (request) => {
    const email = normalizeEmail((request.data?.email as string) ?? '');
    const password = (request.data?.password as string) ?? '';
    const displayName = ((request.data?.displayName as string) ?? '').trim();
    const otp = ((request.data?.otp as string) ?? '').trim();

    if (!email || !otp || !displayName) {
      throw new HttpsError('invalid-argument', 'Email, name, and OTP are required.');
    }
    validatePassword(password);

    if (await emailExists(email)) {
      throw new HttpsError('already-exists', 'An account with this email already exists.');
    }

    const db = admin.firestore();
    const ref = db.collection('emailVerificationOtps').doc(email);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError('not-found', 'OTP expired or not sent. Request a new code.');
    }

    const data = snap.data()!;
    const attempts = (data.attempts as number) ?? 0;
    if (attempts >= MAX_VERIFY_ATTEMPTS) {
      await ref.delete();
      throw new HttpsError('resource-exhausted', 'Too many attempts. Request a new OTP.');
    }

    const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
    if (Date.now() > expiresAt) {
      await ref.delete();
      throw new HttpsError('deadline-exceeded', 'OTP expired. Request a new code.');
    }

    if (data.otpHash !== hashOtp(email, otp)) {
      await ref.update({ attempts: attempts + 1 });
      throw new HttpsError('permission-denied', 'Invalid OTP. Please try again.');
    }

    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
      emailVerified: true,
    });

    await db.collection('users').doc(userRecord.uid).set({
      displayName,
      email,
      role: 'player',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await ref.delete();

    const token = await admin.auth().createCustomToken(userRecord.uid);
    return { token };
  }
);
