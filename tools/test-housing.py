"""Real housing + inventory + economy modules against isolated MySQL.

Run from any directory: python tools/test-housing.py.
The live database is never selected or modified. Connection settings are read
from server.env without printing credentials. Requires pymysql and lupa.
"""
from pathlib import Path
import decimal
import json
import os
import pymysql
from lupa.lua54 import LuaRuntime, lua_type

root = Path(__file__).resolve().parents[1]
setting = next(x for x in (root / 'server.env').read_text(encoding='utf-8-sig').splitlines()
               if x.startswith('OP77_DATABASE_CONNECTION=')).split('=', 1)[1].strip().strip('"')
cfg = dict(x.split('=', 1) for x in setting.split(';') if '=' in x)
cfg = {k.strip().lower(): v.strip() for k, v in cfg.items()}
name = 'open77_housing_test_' + str(os.getpid())
conn = pymysql.connect(host=cfg.get('server', 'localhost'), port=int(cfg.get('port', 3306)),
                       user=cfg.get('user id', cfg.get('user', 'root')), password=cfg.get('password', ''),
                       autocommit=True, cursorclass=pymysql.cursors.DictCursor)
lua = LuaRuntime(unpack_returned_tuples=True)

def to_lua(value):
    if isinstance(value, dict): return lua.table_from({k: to_lua(v) for k, v in value.items()})
    if isinstance(value, (list, tuple)): return lua.table_from([to_lua(v) for v in value])
    if isinstance(value, decimal.Decimal): return float(value)
    return value

def from_lua(value):
    if lua_type(value) != 'table': return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [from_lua(value[i]) for i in range(1, len(keys) + 1)]
    return {str(k): from_lua(v) for k, v in value.items()}

def execute(sql, values=None):
    args = [values[i] for i in range(1, len(values) + 1)] if values is not None else []
    with conn.cursor() as cur:
        cur.execute(sql.replace('%', '%%').replace('?', '%s') if args else sql, args or None)
        return cur.rowcount, cur.fetchall() if cur.description else []

def run(sql, values=None):
    try: return True, execute(sql, values)[0]
    except Exception as exc: print('SQL write failed:', type(exc).__name__, str(exc)); return False, 'database_error'

def read(sql, values=None):
    try: return True, to_lua(execute(sql, values)[1])
    except Exception as exc: print('SQL read failed:', type(exc).__name__, str(exc)); return False, 'database_error'

def transaction(queries):
    conn.begin()
    try:
        for i in range(1, len(queries) + 1):
            q = queries[i]; execute(q['query'], q['values'])
            if lua.globals().sql_fail_after == i:
                raise RuntimeError('injected write failure')
        conn.commit()
        return True
    except Exception as exc:
        conn.rollback()
        if str(exc) != 'injected write failure': print('SQL transaction failed:', type(exc).__name__, str(exc))
        return False, 'database_error'

created = False
try:
    assert name.startswith('open77_housing_test_') and name.removeprefix('open77_housing_test_').isdigit()
    with conn.cursor() as cur: cur.execute(f'CREATE DATABASE `{name}` CHARACTER SET utf8mb4')
    created = True
    conn.select_db(name)
    g = lua.globals()
    g.sql_run, g.sql_read, g.sql_transaction = run, read, transaction
    g.json_encode = lambda value: json.dumps(from_lua(value), ensure_ascii=False, separators=(',', ':'))
    g.json_ascii_encode = lambda value: json.dumps(from_lua(value), ensure_ascii=True, separators=(',', ':'))
    g.json_decode = lambda value: to_lua(json.loads(value))
    os.chdir(root / 'resources/gamemodes/op77_lightrp')
    lua.execute(Path('tests/housing_test.lua').read_text(encoding='utf-8'))
finally:
    if created:
        with conn.cursor() as cur: cur.execute(f'DROP DATABASE `{name}`')
    conn.close()
