#!/usr/bin/env python3
"""Run the migration and access-control cases against real, disposable PostgreSQL."""
import json
import os
from pathlib import Path
import subprocess
import time
import uuid
ROOT=Path(__file__).resolve().parents[1]
ENV=os.environ.copy()
ENV.setdefault('DOCKER_CONFIG',str(ROOT/'test-results/docker-config'))
NAME='lasu-pg-test-'+uuid.uuid4().hex[:10]
def docker(*args,input=None):
 return subprocess.check_output(['docker',*args],input=input,text=True,env=ENV,stderr=subprocess.STDOUT).strip()
def sql(source):
 return docker('exec','-i',NAME,'psql','-XAtq','-v','ON_ERROR_STOP=1','-U','postgres',input=source)
A='11111111-1111-4111-8111-111111111111'; B='22222222-2222-4222-8222-222222222222'; E='33333333-3333-4333-8333-333333333333'
checks=0
def check(ok,title):
 global checks
 checks+=1
 assert ok,title
def api(who,route,payload=None):
 data=json.dumps(payload or {}).replace("'","''")
 return json.loads(sql(f"set role authenticated; set request.jwt.claim.sub='{who}'; select public.lasu_api('{route}','{data}'::jsonb);"))
try:
 docker('run','-d','--name',NAME,'--tmpfs','/var/lib/postgresql/data','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine')
 for _ in range(60):
  try:
   docker('exec',NAME,'pg_isready','-U','postgres');break
  except subprocess.CalledProcessError: time.sleep(.5)
 else: raise AssertionError('PostgreSQL did not start')
 sql("""create role anon;create role authenticated;
 create schema auth;create table auth.users(id uuid primary key,email text);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 insert into auth.users values ('%s','a@example.test'),('%s','b@example.test'),('%s','e@example.test');"""%(A,B,E))
 migration=(ROOT/'supabase/migrations/001_campus_social.sql').read_text()
 sql(migration);sql(migration) # repeatable installation, no destructive resets
 check(json.loads(sql('set role anon;select public.lasu_health();'))['version']==1,'public health works without exposing data')
 for role in ('anon','authenticated'):
  for table in ('profiles','messages','relationships','blocks','presence','reports'):
   check(sql(f"select has_table_privilege('{role}','inside_lasu.{table}','select');")=='f','no raw table reads')
   check(sql(f"select has_table_privilege('{role}','inside_lasu.{table}','insert');")=='f','no raw table writes')
  check(sql(f"select has_schema_privilege('{role}','inside_lasu','usage');")=='f','dedicated schema is inaccessible')
 check(sql("select has_function_privilege('anon','public.lasu_api(text,jsonb)','execute');")=='f','anonymous cannot call private API')
 check('error' in api('', '/inbox'),'missing identity denied')
 for user,name in ((A,'alice'),(B,'bob'),(E,'eve')): check(api(user,'/profile',{'username':name})['username']==name,'claim unique profile')
 check(api(A,'/profile',{'username':'changed'})['username']=='alice','profile cannot be renamed to impersonate')
 check(api(A,'/users',{'q':'bo'})['users']==[{'username':'bob'}],'username search')
 check(api(A,'/messages/send',{'to':'bob','body':'Private notes <b>literal</b>'})['ok'],'send real private message')
 check(api(B,'/messages/read',{'to':'alice'})['messages'][0]['body']=='Private notes <b>literal</b>','recipient reads own conversation')
 check(api(E,'/messages/read',{'to':'alice'})['messages']==[],'outsider cannot read conversation')
 check('error' in api(A,'/messages/send',{'to':'bob','body':'x'*1001}),'message size enforced')
 check(api(A,'/relationship',{'to':'bob','kind':'Reading partners'})['ok'],'invite partner')
 relation=api(B,'/inbox')['relationships'][0]
 check(relation['status']=='pending','request starts pending')
 for user in (A,E): check('error' in api(user,'/relationship/respond',{'id':relation['id'],'status':'accepted'}),'sender and outsider cannot accept')
 check(api(B,'/relationship/respond',{'id':relation['id'],'status':'accepted'})['ok'],'recipient accepts')
 check(api(A,'/inbox')['relationships'][0]['status']=='accepted','mutual relationship visible')
 position={'location':'library:0:1','x':900,'y':1,'z':3,'yaw':0}
 api(A,'/presence',position)
 check(api(B,'/presence',position)['peers'][0]['username']=='alice','public room presence works')
 api(A,'/presence',{'location':'private:hostel:42'})
 check(api(B,'/presence',position)['peers']==[],'private room hidden')
 check('error' in api(A,'/presence',dict(position,x='NaN')),'nonfinite position denied')
 check(api(B,'/report',{'to':'alice','reason':'Test moderation report'})['ok'],'reports saved')
 check(api(B,'/block',{'to':'alice'})['ok'],'blocking works')
 check('error' in api(A,'/messages/send',{'to':'bob','body':'not allowed'}),'block prevents messages')
 check(api(A,'/users',{'q':'bo'})['users']==[],'blocked search excluded')
 check(api(A,'/inbox')['relationships']==[],'block ends relationship')
 check(api(B,'/blocks')['users']==[{'username':'alice'}],'owner sees block list')
 check(api(A,'/blocks')['users']==[],'block list private')
 api(B,'/unblock',{'to':'alice'})
 for i in range(19): api(A,'/messages/send',{'to':'bob','body':'Rate limit fixture '+str(i)})
 check('error' in api(A,'/messages/send',{'to':'bob','body':'over limit'}),'per-user message rate enforced')
 check(api(A,'/account/delete')['ok'],'account deletion works')
 check(sql('select count(*) from inside_lasu.messages;')=='0','account deletion removes messages')
 check('error' in api(A,'/inbox'),'deleted identity cannot access data')
 print(f'SUPABASE DATABASE PASSED: {checks} checks, real PostgreSQL migration, permissions, message isolation, mutual relationships, block/unblock, presence privacy, limits and deletion')
finally:
 subprocess.run(['docker','rm','-f',NAME],env=ENV,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
