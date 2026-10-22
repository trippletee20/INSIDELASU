/* Lightweight account client: no engine, no third-party SDK or privileged keys. */
export const config = Object.freeze({
  url: 'https://mwuagoxsbsayftvmyitb.supabase.co',
  key: 'sb_publishable_3kCnkWCGWzr9qSnvwZFHmA_NvONwGVV',
});
export const root = new URL('../', import.meta.url);
export const callbackURL = new URL('auth/callback.html', root).href;
export const gameURL = new URL('play/index.html?v=modern-v018', root).href;
const SESSION = 'lasu.social.session';
const VERIFIER = 'lasu.oauth.verifier';
export async function api(path, body, accessToken, method = 'POST') {
  const response = await fetch(config.url + path, {
    method, cache: 'no-store', signal: AbortSignal.timeout(15000),
    headers: {apikey: config.key, 'Content-Type': 'application/json', ...(accessToken ? {Authorization: 'Bearer ' + accessToken} : {})},
    ...(body === undefined ? {} : {body: JSON.stringify(body)}),
  });
  const value = response.status === 204 ? {} : await response.json();
  if (!response.ok) throw new Error(value.msg || value.error_description || value.message || 'Could not complete sign-in. Please retry.');
  return value;
}
export function saveSession(session, username = '') {
  if (!session.access_token || !session.refresh_token) throw new Error('Sign-in did not return a valid session.');
  const safe = {access_token: session.access_token, refresh_token: session.refresh_token,
    expires_at: session.expires_at || Math.floor(Date.now() / 1000) + (session.expires_in || 3600), username};
  // Per-tab only; never put account tokens in URLs, localStorage or game saves.
  sessionStorage.setItem(SESSION, JSON.stringify(safe));
  return safe;
}
export function session() {
  try {return JSON.parse(sessionStorage.getItem(SESSION) || 'null');} catch (_) {sessionStorage.removeItem(SESSION);return null;}
}
export function clearSession() {sessionStorage.removeItem(SESSION);}
export async function rpc(route, payload, current = session()) {
  if (!current?.access_token) throw new Error('Please sign in first.');
  const result = await api('/rest/v1/rpc/lasu_api', {route, payload}, current.access_token);
  if (result.error) throw new Error(result.error);
  return result;
}
export async function profile(username = '') {
  const current = session();
  if (!current) throw new Error('Please sign in first.');
  // Verify even an implicit email callback's token with Auth before accepting it.
  await api('/auth/v1/user', undefined, current.access_token, 'GET');
  const result = await rpc('/profile', {username}, current);
  saveSession(current, result.username);
  return result.username;
}
export async function googleEnabled() {
  const settings = await api('/auth/v1/settings', undefined, null, 'GET');
  return !!settings.external?.google;
}
export async function startGoogle() {
  if (!await googleEnabled()) throw new Error('Google sign-in has not been enabled by the campus owner yet. Use email below for now.');
  const bytes = crypto.getRandomValues(new Uint8Array(48));
  const verifier = btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier)));
  const challenge = btoa(String.fromCharCode(...digest)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  sessionStorage.setItem(VERIFIER, verifier);
  const url = new URL(config.url + '/auth/v1/authorize');
  url.search = new URLSearchParams({provider: 'google', redirect_to: callbackURL, code_challenge: challenge, code_challenge_method: 's256'});
  return url.href;
}
export async function finishCallback(href = location.href) {
  const url = new URL(href);
  const fragment = new URLSearchParams(url.hash.slice(1));
  // Scrub tokens/errors/codes from the browser address before any network work.
  history.replaceState(null, '', location.pathname);
  const error = url.searchParams.get('error_description') || fragment.get('error_description');
  if (error) throw new Error(error + ' Return to sign-in or request a new confirmation email.');
  let value;
  if (url.searchParams.has('code')) {
    const verifier = sessionStorage.getItem(VERIFIER);
    sessionStorage.removeItem(VERIFIER);
    if (!verifier) throw new Error('This sign-in started in another browser or tab. Return to sign-in here; your email may already be confirmed.');
    value = await api('/auth/v1/token?grant_type=pkce', {auth_code: url.searchParams.get('code'), code_verifier: verifier});
  } else if (fragment.has('access_token') && fragment.has('refresh_token')) {
    value = {access_token: fragment.get('access_token'), refresh_token: fragment.get('refresh_token'), expires_in: Number(fragment.get('expires_in') || 3600)};
  } else {
    throw new Error('No sign-in session was returned. If your email is confirmed, return to sign-in with your email and password.');
  }
  saveSession(value);
  return value;
}
export async function emailAuth(mode, email, password) {
  if (password.length < 10) throw new Error('Use a password of at least 10 characters.');
  const route = mode === 'signup' ? '/auth/v1/signup?redirect_to=' + encodeURIComponent(callbackURL) : '/auth/v1/token?grant_type=password';
  const value = await api(route, {email: email.trim(), password});
  if (!value.access_token) return {confirmation: true};
  saveSession(value);
  return value;
}
export async function resend(email) {
  await api('/auth/v1/resend?redirect_to=' + encodeURIComponent(callbackURL), {type: 'signup', email: email.trim()});
}
export async function resume() {
  let current = session();
  if (!current) return null;
  if (current.expires_at <= Date.now()/1000 + 60) {
    try {current = saveSession(await api('/auth/v1/token?grant_type=refresh_token', {refresh_token: current.refresh_token}), current.username);}
    catch (_) {clearSession();return null;}
  }
  return current;
}
