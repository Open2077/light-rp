"""Execute the real Lua support/admin modules against an isolated MySQL database.
Uses local server.env credentials without printing them; never writes the game DB.
Requires pymysql and lupa (Lua 5.4). Run from the LightRP repository root.
"""
from pathlib import Path
import os, decimal
import pymysql
from lupa.lua54 import LuaRuntime

root=Path(__file__).resolve().parents[1]
setting=next(x for x in (root/'server.env').read_text(encoding='utf-8-sig').splitlines() if x.startswith('OP77_DATABASE_CONNECTION=')).split('=',1)[1].strip().strip('"')
cfg={k.strip().lower():v.strip() for k,v in (x.split('=',1) for x in setting.split(';') if '=' in x)}
db_name='open77_support_test_'+str(os.getpid())
conn=pymysql.connect(host=cfg.get('server','localhost'),port=int(cfg.get('port','3306')),user=cfg.get('user id',cfg.get('user','root')),password=cfg.get('password',''),autocommit=True,cursorclass=pymysql.cursors.DictCursor)
lua=LuaRuntime(unpack_returned_tuples=True)
def to_lua(v):
    if isinstance(v,dict): return lua.table_from({k:to_lua(x) for k,x in v.items()})
    if isinstance(v,(list,tuple)): return lua.table_from([to_lua(x) for x in v])
    if isinstance(v,decimal.Decimal): return float(v)
    return v
def execute(sql,values=None):
    args=[values[i] for i in range(1,len(values)+1)] if values is not None else []
    with conn.cursor() as cur:
        cur.execute(sql.replace('%','%%').replace('?','%s') if args else sql,args or None)
        return cur.rowcount,cur.fetchall() if cur.description else []
def run(sql,values=None):
    try: return True,execute(sql,values)[0]
    except Exception as e: print('SQL update failed:',type(e).__name__,str(e)); return False,'database_error'
def read(sql,values=None):
    try: return True,to_lua(execute(sql,values)[1])
    except Exception as e: print('SQL read failed:',type(e).__name__,str(e)); return False,'database_error'
def transaction(queries):
    conn.begin()
    try:
        for i in range(1,len(queries)+1): execute(queries[i]['query'],queries[i]['values'])
        conn.commit();return True
    except Exception as e:
        conn.rollback();print('SQL transaction rolled back:',type(e).__name__);return False,'database_error'
created=False
try:
    assert db_name.startswith('open77_support_test_') and db_name.removeprefix('open77_support_test_').isdigit()
    with conn.cursor() as cur: cur.execute(f'CREATE DATABASE `{db_name}` CHARACTER SET utf8mb4')
    created=True
    conn.select_db(db_name)
    lua.globals().sql_run=run;lua.globals().sql_read=read;lua.globals().sql_transaction=transaction
    os.chdir(root/'resources/gamemodes/op77_lightrp')
    lua.execute(Path('tests/support_test.lua').read_text(encoding='utf-8'))
finally:
    if created:
        with conn.cursor() as cur: cur.execute(f'DROP DATABASE `{db_name}`')
    conn.close()
