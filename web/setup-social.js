'use strict';
const copyButton = document.querySelector('#copy-sql');
const field = document.querySelector('#sql');
const statusLine = document.querySelector('#status');
const project = 'https://mwuagoxsbsayftvmyitb.supabase.co';
const publishableKey = 'sb_publishable_3kCnkWCGWzr9qSnvwZFHmA_NvONwGVV';
fetch('setup-social.sql').then(response => {
  if (!response.ok) throw new Error('SQL unavailable');
  return response.text();
}).then(sql => {
  field.value = sql;
  copyButton.disabled = false;
  copyButton.textContent = '1. Copy setup SQL';
}).catch(() => {copyButton.textContent = 'Reload to load the setup script';});
copyButton.addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(field.value);
    copyButton.textContent = 'Copied — paste into Supabase SQL Editor';
  } catch (_) {
    field.closest('details').open = true;
    field.focus();field.select();
    copyButton.textContent = 'Script selected — press Ctrl+C or Copy';
  }
});
document.querySelector('#check-status').addEventListener('click', async () => {
  const button = document.querySelector('#check-status');
  button.disabled = true;statusLine.textContent = 'Checking the database setup…';
  try {
    const response = await fetch(project + '/rest/v1/rpc/lasu_health', {method:'POST', headers:{apikey:publishableKey,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(15000)});
    const value = await response.json();
    statusLine.textContent = response.ok && value.service === 'Inside LASU Supabase social' && value.version === 1
      ? 'Database setup found. Finish the email URL setting below, then test two player accounts in the game.'
      : 'The setup is not ready yet. Run the copied SQL in the INSIDE LASU project, then check again. If it failed, send Codex the error text.';
  } catch (_) {statusLine.textContent = 'Could not reach Supabase. Check your internet connection and project status, then retry. This does not change your project.';}
  finally {button.disabled = false;}
});
