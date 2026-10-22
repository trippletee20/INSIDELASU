import {finishCallback,profile,gameURL,clearSession} from './client.js';
try{await finishCallback();try{await profile();location.replace(gameURL);}catch(error){if(/username|Finish choosing/i.test(error.message)){location.replace(new URL('../auth.html',location.href));}else throw error;}}
catch(error){clearSession();document.querySelector('#title').textContent='Let’s get you back in';document.querySelector('#notice').textContent=error.message||'Sign-in could not finish. Please retry.';document.querySelector('#continue').hidden=false;}
