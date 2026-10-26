-- Actual inventory + economy, transactional SQL model. Never touches live data.
local noop = function() end
local function clone(v) if type(v) ~= "table" then return v end local t = {}; for k,x in pairs(v) do t[k]=clone(x) end return t end
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
local encoded, serial = {}, 0
json = { encode = function(v) serial=serial+1; local k=tostring(serial); encoded[k]=clone(v); return k end,
    decode = function(k) if k=="{}" then return {} end assert(encoded[k], "invalid JSON"); return clone(encoded[k]) end }
local state = { wallets = {}, inventories = {}, migrations = {}, ledger = {} }
local chars = {}; for i=1,5 do chars[i]={identifier="cash-test-"..i,key="default",status="active"} end
state.wallets["AAA-BBB"]={account_number="AAA-BBB",identifier=chars[1].identifier,character_key="default",owner_name="Test",cash=12345,bank=1500}
state.wallets["CCC-DDD"]={account_number="CCC-DDD",identifier=chars[2].identifier,character_key="default",owner_name="Test",cash=50,bank=1500}
local fail, yieldDb, failRead = false, false, false
local db = {ready=true,schema=noop,query=function() return {} end}
function db.read(sql,p)
    if failRead then return false,"database_error" end
    if sql:find("lightrp_inventories",1,true) then return true,state.inventories[p[1]] and {clone(state.inventories[p[1]])} or {} end
    if sql:find("lightrp_cash_migrations",1,true) then return true,state.migrations[p[1]] and {clone(state.migrations[p[1]])} or {} end
    if sql:find("lightrp_wallets",1,true) then
        for _,w in pairs(state.wallets) do if w.identifier==p[1] and w.character_key==p[2] then return true,{clone(w)} end end
        return true,{}
    end
    error("unmodelled read: "..sql)
end
function db.single(sql,p)
    if sql:find("SELECT 1",1,true) then return state.wallets[p[1]] and {x=1} end
    local ok,rows=db.read(sql,p); return ok and rows[1]
end
local function apply(s,sql,p)
    if sql:find("INSERT INTO lightrp_inventories",1,true) then s.inventories[p[1]]={items=p[6],slots=p[4],max_weight=p[5]}
    elseif sql:find("INSERT INTO lightrp_cash_migrations",1,true) then
        assert(not s.migrations[p[1]],"duplicate migration")
        s.migrations[p[1]]={account_number=p[1],inventory_id=p[2],legacy_cash=p[3],inventory_before=p[4],slots_before=p[5]}
    elseif sql:find("INSERT INTO lightrp_wallets",1,true) then s.wallets[p[1]]={account_number=p[1],identifier=p[2],character_key=p[3],owner_name=p[4],cash=p[5],bank=p[6]}
    elseif sql:find("SET cash = 0",1,true) then s.wallets[p[1]].cash=0
    elseif sql:find("SET bank = ?",1,true) then s.wallets[p[2]].bank=p[1]
    elseif sql:find("INSERT INTO lightrp_transactions",1,true) then s.ledger[#s.ledger+1]=clone(p)
    elseif sql:find("SET owner_name",1,true) then s.wallets[p[2]].owner_name=p[1]
    else error("unmodelled write: "..sql) end
end
function db.run(sql,p) if fail then return false end apply(state,sql,p);return true,1 end
function db.transaction(writes)
    local draft=clone(state)
    for _,q in ipairs(writes) do apply(draft,q.query,q.values) end
    if yieldDb then coroutine.yield("sql") end
    if fail then return false,"database_error" end
    state=draft; return true
end
LightRP={db=db,module=function(n,t) LightRP[n]=t;return t end,command=noop,log=noop,state=noop,stateProvider=noop,
    eachModule=noop,notice=noop,result=noop,action=noop,interaction=noop,removeInteraction=noop,dialog=noop,nowMs=function() return 1000 end,
    characters={get=function(id) return chars[id] end,displayName=function() return "Test" end}}
local positions={[1]={x=0,y=0,z=0,bucket=0},[2]={x=1,y=0,z=0,bucket=0}}
Open77={players={position=function(id) return positions[id] end,positions=function() return positions end},vehicles={}}
GetPlayers=function() return {1,2} end; GetPlayerName=function() return "Test" end
TriggerClientEvent=noop;AddEventHandler=noop;CreateThread=noop;Wait=function() coroutine.yield("wait") end
dofile("server/modules/inventory.lua"); dofile("server/modules/economy.lua")
local I,M=LightRP.inventory,LightRP.money
local function load(id) I.onCharacterLoaded(id,chars[id]); M.onCharacterLoaded(id,chars[id]) end
local function reload(id) I.onDisconnected(id);M.onDisconnected(id);load(id) end
local function slot(inv,name) for k,v in pairs(inv.items) do if v.name==name then return k end end end
load(1);load(2)
local a,b=I.player(1),I.player(2)
assert(M.get(1).cash==12345 and I.cashOf(a)==12345 and state.wallets["AAA-BBB"].cash==0)
assert(state.migrations["AAA-BBB"].legacy_cash==12345)
assert(I.cashOf({items=json.decode(state.migrations["AAA-BBB"].inventory_before)})==0,"recovery snapshot is pre-migration")
assert(I.weightOf(a)==4.5,"cash weighs nothing")
reload(1);a=I.player(1);assert(M.get(1).cash==12345,"reconnect cannot mint twice")
assert(M.deposit(1,345));assert(I.cashOf(a)==12000 and M.get(1).bank==1845)
assert(M.withdraw(1,500));assert(I.cashOf(a)==12500 and M.get(1).bank==1345)
assert(M.pay(1,2,500));assert(I.cashOf(a)==12000 and I.cashOf(b)==550)
assert(I.give(1,slot(a,"cash"),100));assert(I.cashOf(a)==11900 and I.cashOf(b)==650)
assert(I.move(1,a.id,slot(a,"cash"),a.id,9,900));assert(a.items[9].count==900 and M.get(1).cash==11900)
assert(I.move(1,a.id,9,a.id,slot(a,"cash"),900));assert(not a.items[9])
local stash={id="stash:test",kind="stash",label="Storage",slots=12,maxWeight=0,items={},viewers={},persistent=true}
I.registry[stash.id]=stash
assert(I.move(1,a.id,slot(a,"cash"),stash.id,1,10000));assert(M.get(1).cash==1900 and I.cashOf(stash)==10000)
assert(not M.removeCash(1,2000),"cannot spend stored cash")
assert(I.move(1,stash.id,1,a.id,slot(a,"cash"),10000));assert(M.get(1).cash==11900)
local dropped,pile=I.drop(1,slot(a,"cash"),900);assert(dropped and I.cashOf(pile)==900 and M.get(1).cash==11000)
positions[2].bucket=1
assert(not I.move(2,pile.id,slot(pile,"cash"),b.id,slot(b,"cash"),900),"cash cannot be picked up across routing buckets")
positions[2].bucket=0
assert(I.move(2,pile.id,slot(pile,"cash"),b.id,slot(b,"cash"),900));assert(M.get(2).cash==1550 and not I.get(pile.id))
local original,bank=a.items,M.get(1).bank
fail=true;assert(not M.withdraw(1,100) and a.items==original and M.get(1).bank==bank)
assert(not I.give(1,slot(a,"cash"),100) and a.items==original and M.get(2).cash==1550)
assert(not I.move(1,a.id,slot(a,"cash"),stash.id,1,100) and a.items==original and I.cashOf(stash)==0)
fail=false
assert(I.trade(1,"buy",{{name="water",count=1}},"cash",20,"Shop"));assert(M.get(1).cash==10980)
assert(I.trade(1,"sell",{{name="water",count=1}},"cash",10,"Shop"));assert(M.get(1).cash==10990)
assert(M.addCash(1,10,"salary"));assert(M.get(1).cash==11000)
-- Paid fuel cans use the same draft for cash AND the delivered item.
LightRP.refueling={canCommit=function() return true end}
assert(I.completeFuelCan(1,{kind="can",pay="cash",price=20,pump={name="Test pump"}}))
assert(M.get(1).cash==10980 and I.count(a.id,"jerrycan")==1)
assert(M.addCash(1,20,"test_refund"))
-- External commerce writes (vehicle purchases) and bank-only operations.
assert(M.exchange(1,"cash",-50,{query="UPDATE lightrp_wallets SET owner_name = ? WHERE account_number = ?",values={"Test","AAA-BBB"}},noop,"vehicle_purchase"))
assert(M.get(1).cash==10950)
yieldDb=true
local co=coroutine.create(function() assert(M.withdraw(1,25)) end)
assert(coroutine.resume(co));assert(a.busy and M.get(1).busy)
assert(not I.drop(1,slot(a,"cash"),1) and not M.deposit(1,1) and not I.addItem(a.id,"cash",1))
assert(coroutine.resume(co));yieldDb=false;assert(not a.busy and not M.get(1).busy)
-- Failed migration is retryable; full inventories get a persisted recovery slot.
local id="player:"..chars[3].identifier.."#default"
local full={};for i=1,LightRpConfig.inventory.player.slots do full[i]={name="phone",count=1} end
state.inventories[id]={items=json.encode(full),slots=LightRpConfig.inventory.player.slots}
state.wallets["EEE-FFF"]={account_number="EEE-FFF",identifier=chars[3].identifier,character_key="default",owner_name="Test",cash=800,bank=0}
fail=true;load(3);assert(not M.get(3) and not state.migrations["EEE-FFF"] and state.wallets["EEE-FFF"].cash==800)
fail=false;load(3);assert(M.get(3).cash==800 and I.player(3).slots==LightRpConfig.inventory.player.slots+1)
reload(3);assert(M.get(3).cash==800 and I.player(3).slots==LightRpConfig.inventory.player.slots+1)
load(4);assert(M.get(4).cash==LightRpConfig.economy.startingCash,"new characters receive physical starting cash once")
reload(4);assert(M.get(4).cash==LightRpConfig.economy.startingCash)
failRead=true;load(5);assert(not I.player(5) and not M.get(5),"failed reads never look like an empty new inventory")
failRead=false
for _,bad in ipairs({-1,0,0/0,math.huge,1.5,1000000001}) do assert(not I.addItem(a.id,"cash",bad)) end
-- Cash in a full bag can be spent to free its slot before delivery.
local saved,slots=a.items,a.slots
a.items={[1]={name="cash",count=20}};a.slots=1
assert(I.trade(1,"buy",{{name="phone",count=1}},"cash",20,"Shop"));assert(a.items[1].name=="phone" and M.get(1).cash==0)
bank=M.get(1).bank;assert(not M.withdraw(1,1) and M.get(1).bank==bank,"full inventory never loses a withdrawal")
assert(I.trade(1,"sell",{{name="phone",count=1}},"cash",10,"Shop"));assert(a.items[1].name=="cash" and M.get(1).cash==10)
a.items,a.slots=saved,slots
-- Disconnect while committing: the old cache must never overwrite SQL.
yieldDb=true;co=coroutine.create(function() assert(M.addCash(1,1)) end)
assert(coroutine.resume(co));I.onDisconnected(1);M.onDisconnected(1)
assert(coroutine.resume(co));yieldDb=false;assert(not I.get(a.id))
load(1);assert(I.cashOf(I.player(1))==10976,"committed cash survives reconnect")
print("PASS: cash migration + backup + retries; new/reconnecting characters; zero weight; split/merge/give/pay/drop/storage; cash/bank/shop/external payments; rollback; locks; full bags; disconnect; invalid quantities")
