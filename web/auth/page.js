import {emailAuth, googleEnabled, startGoogle, profile, resume, resend, gameURL} from './client.js';
const $ = id => document.getElementById(id);
let mode = 'signin';let busy = false;
function notice(text,error=false){$('notice').textContent=text;$('notice').classList.toggle('error',error);}
async function run(task){if(busy)return;busy=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);try{await task();}catch(error){notice(error.message||'Could not connect. Please retry.',true);}finally{busy=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}}
async function enter(){try{await profile();location.assign(gameURL);}catch(error){if(/username|Finish choosing/i.test(error.message)){$('signin').hidden=true;$('username-step').hidden=false;notice('You’re signed in. Pick your campus username.');}else throw error;}}
$('google').addEventListener('click',()=>run(async()=>{notice('Opening Google…');location.assign(await startGoogle());}));
$('mode').addEventListener('click',()=>{mode=mode==='signin'?'signup':'signin';$('submit').textContent=mode==='signup'?'Create account':'Sign in';$('mode').textContent=mode==='signup'?'Already have an account? Sign in':'New here? Create an account';$('password').autocomplete=mode==='signup'?'new-password':'current-password';notice('');});
$('email-form').addEventListener('submit',event=>{event.preventDefault();run(async()=>{notice(mode==='signup'?'Creating your account…':'Signing in…');const result=await emailAuth(mode,$('email').value,$('password').value);$('password').value='';if(result.confirmation){notice('Check your email to confirm your account, then return and sign in. Check spam too.');$('resend').hidden=false;return;}await enter();});});
$('username-form').addEventListener('submit',event=>{event.preventDefault();run(async()=>{notice('Saving username…');await profile($('username').value.trim().toLowerCase());location.assign(gameURL);});});
$('resend').addEventListener('click',()=>run(async()=>{if(!$('email').validity.valid||!$('email').value)throw new Error('Enter your email address first.');await resend($('email').value);notice('Confirmation requested. Check your email; delivery limits may apply.');}));
googleEnabled().then(enabled=>{$('google-status').textContent=enabled?'No new password needed.':'Google sign-in needs the campus owner’s provider setup. Email sign-in works below.';}).catch(()=>{$('google-status').textContent='Unable to check Google availability. Please retry if needed.';});
run(async()=>{if(await resume())await enter();});
