-- Account-owned support cases. Every read and mutation rechecks ownership/ACL.
-- A ticket revision and its timeline entry commit together; the unique revision
-- rolls back concurrent claims/replies instead of silently overwriting a case.
local C, Db, E = LightRpSupportConfig, LightRP.db, LightRpEvents
local Support = LightRP.module("support", {})
local requests, subscriptions, createAt, lastRequest = {}, {}, {}, {}
local ownerWrites = {}
-- A second session or an admin reopening a case shares the owner's quota.
-- Hold this across yielding database calls and always release it on failure.
local function withOwnerWrite(owner, fn)
    if ownerWrites[owner] then return nil,"Another report is being saved for this account. Please retry." end
    ownerWrites[owner]=true
    local ok,result,why=pcall(fn)
    ownerWrites[owner]=nil
    if not ok then error(result,0) end
    return result,why
end
local closed = { resolved=true, closed=true }
local categories = {}; for _,name in ipairs(C.categories) do categories[name]=true end
local statuses = { open=true, in_progress=true, waiting_player=true, resolved=true, closed=true }
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_support_tickets (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, reporter_id VARCHAR(128) NOT NULL,
 character_key VARCHAR(64) NOT NULL, reporter_name VARCHAR(96) NOT NULL,
 subject VARCHAR(120) NOT NULL, category VARCHAR(20) NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'open',
 priority VARCHAR(12) NOT NULL DEFAULT 'normal', assignee_id VARCHAR(128) NOT NULL DEFAULT '',
 assignee_name VARCHAR(96) NOT NULL DEFAULT '', reported_id VARCHAR(128) NOT NULL DEFAULT '',
 reported_name VARCHAR(96) NOT NULL DEFAULT '', x DOUBLE NOT NULL DEFAULT 0, y DOUBLE NOT NULL DEFAULT 0,
 z DOUBLE NOT NULL DEFAULT 0, bucket INT NOT NULL DEFAULT 0, revision INT NOT NULL DEFAULT 1,
 public_revision INT NOT NULL DEFAULT 1, request_key VARCHAR(96) NOT NULL, legacy_id BIGINT NULL,
 created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 public_updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), resolved_at TIMESTAMP(3) NULL,
 UNIQUE KEY support_request (reporter_id, request_key), UNIQUE KEY support_legacy (legacy_id),
 KEY support_owner (reporter_id, status, id), KEY support_queue (status, updated_at), KEY support_assigned (assignee_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_support_messages (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, ticket_id BIGINT NOT NULL, revision INT NOT NULL,
 actor_id VARCHAR(128) NOT NULL, actor_name VARCHAR(96) NOT NULL, actor_role VARCHAR(12) NOT NULL,
 kind VARCHAR(20) NOT NULL, body TEXT NOT NULL, internal TINYINT NOT NULL DEFAULT 0,
 request_key VARCHAR(96) NOT NULL, created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 UNIQUE KEY support_revision (ticket_id, revision), UNIQUE KEY support_message_request (ticket_id, actor_id, request_key),
 KEY support_timeline (ticket_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_support_reads (
 ticket_id BIGINT NOT NULL, reader_id VARCHAR(128) NOT NULL, scope VARCHAR(8) NOT NULL,
 revision INT NOT NULL DEFAULT 0, PRIMARY KEY(ticket_id, reader_id, scope)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

function Support.allowed(player, right)
    local permission=C.permissions[right]
    return permission~=nil and LightRP.staff.allowed(player,permission)
end
function Support.identity(player)
    local c=LightRP.characters.get(player)
    return c and c.identifier and c, c and c.identifier
end
local function same(player,c) return c~=nil and LightRP.characters.get(player)==c and GetPlayerName(player)~=nil end
local function text(value,max,min)
    if type(value)~="string" then return nil end
    value=value:gsub("\r\n","\n"):gsub("[%z\1-\8\11\12\14-\31\127]",""):match("^%s*(.-)%s*$")
    local length=utf8.len(value)
    if not length or length<(min or 1) or length>max then return nil end
    return value
end
Support.text=text
local function number(value) local n=tonumber(value); return n and n==math.floor(n) and n>0 and n<9007199254740991 and n end
local function token(value) return type(value)=="string" and #value>=8 and #value<=96 and value:match("^[%w:_%-]+$") and value or nil end
local function rows(sql,values)
    local ok,result=Db.read(sql,values)
    if not ok then error("Support storage is unavailable. Please retry; your draft is still here.",0) end
    return result
end
local function first(sql,values) return rows(sql,values)[1] end
local TICKET_FIELDS="t.*, UNIX_TIMESTAMP(t.created_at)*1000 AS created_ms, UNIX_TIMESTAMP(t.updated_at)*1000 AS updated_ms, UNIX_TIMESTAMP(t.public_updated_at)*1000 AS public_ms, UNIX_TIMESTAMP(t.resolved_at)*1000 AS resolved_ms"
local function get(id) return first("SELECT "..TICKET_FIELDS.." FROM lightrp_support_tickets t WHERE t.id=?",{id}) end
local function staffScope(player,p) return p.scope=="staff" and Support.allowed(player,"view") and Support.allowed(player,"reports") end
local function canRead(player,c,t,staff) return t and same(player,c) and ((staff and Support.allowed(player,"reports") and Support.allowed(player,"view")) or t.reporter_id==c.identifier) end
local function playerFor(identifier)
    for _,id in ipairs(GetPlayers()) do local c=Support.identity(id); if c and c.identifier==identifier then return id,c end end
end
Support.playerFor=playerFor
local function view(t,staff,reader)
    local reporter=playerFor(t.reporter_id)
    local assignee=t.assignee_id~="" and playerFor(t.assignee_id) or nil
    local revision=tonumber(staff and t.revision or t.public_revision)
    local result={id=tonumber(t.id),subject=t.subject,category=t.category,status=t.status,priority=t.priority,
        reporter=t.reporter_name,character=t.character_key,reporterOnline=reporter~=nil,reporterPlayer=reporter,
        assignee=t.assignee_name~="" and t.assignee_name or nil,assigneeOnline=assignee~=nil,
        assignedToMe=t.assignee_id==reader,reported=t.reported_name~="" and t.reported_name or nil,
        revision=revision,createdAt=tonumber(t.created_ms),updatedAt=tonumber(staff and t.updated_ms or t.public_ms),
        resolvedAt=tonumber(t.resolved_ms),unread=revision>tonumber(t.read_revision or 0)}
    if staff then
        result.owner=t.reporter_id
        result.position={x=tonumber(t.x),y=tonumber(t.y),z=tonumber(t.z),bucket=tonumber(t.bucket)}
    end
    return result
end
local function summary(player,c,staff)
    local predicate=staff and "1=1" or "reporter_id=?"
    local values=staff and {} or {c.identifier}
    local r=first("SELECT COUNT(*) AS total, SUM(status='open') AS unassigned, SUM(status='in_progress') AS progress, SUM(status='waiting_player') AS waiting, SUM(status IN ('resolved','closed')) AS finished FROM lightrp_support_tickets WHERE "..predicate,values)
    return {total=tonumber(r.total) or 0,open=tonumber(r.unassigned) or 0,progress=tonumber(r.progress) or 0,waiting=tonumber(r.waiting) or 0,finished=tonumber(r.finished) or 0}
end
function Support.list(player,p)
    local c=Support.identity(player); if not c then return nil,"Your account is still loading." end
    local staff=staffScope(player,p)
    if p.scope=="staff" and not staff then return nil,"You do not have access to staff reports." end
    local where,values={"1=1"},{}
    local function add(sql,value) where[#where+1]=sql;values[#values+1]=value end
    if not staff then add("t.reporter_id=?",c.identifier) end
    if p.filter=="active" or not p.filter then where[#where+1]="t.status NOT IN ('resolved','closed')"
    elseif p.filter=="finished" then where[#where+1]="t.status IN ('resolved','closed')"
    elseif statuses[p.filter] then add("t.status=?",p.filter)
    elseif p.filter~="all" then return nil,"Unknown ticket filter." end
    if p.mine and staff then add("t.assignee_id=?",c.identifier) end
    local search=text(p.search,80)
    if search then
        local id=number(search:gsub("^#",""))
        if id then add("t.id=?",id)
        else search=search:gsub("[%%_]",""); where[#where+1]="(t.subject LIKE ? OR t.reporter_name LIKE ?)";values[#values+1]="%"..search.."%";values[#values+1]="%"..search.."%" end
    end
    local page=math.min(number(p.page) or 1,10000)
    local count=first("SELECT COUNT(*) AS n FROM lightrp_support_tickets t WHERE "..table.concat(where," AND "),values)
    local queryValues={c.identifier,staff and "staff" or "player"};for _,v in ipairs(values) do queryValues[#queryValues+1]=v end
    local result=rows("SELECT "..TICKET_FIELDS..", COALESCE(r.revision,0) AS read_revision FROM lightrp_support_tickets t LEFT JOIN lightrp_support_reads r ON r.ticket_id=t.id AND r.reader_id=? AND r.scope=? WHERE "..table.concat(where," AND ").." ORDER BY t.updated_at DESC,t.id DESC LIMIT "..C.pageSize.." OFFSET "..((page-1)*C.pageSize),queryValues)
    local totals=summary(player,c,staff)
    if not same(player,c) or (staff and not staffScope(player,p)) then return nil,"Your access changed. Reopen the panel." end
    local list={};for _,t in ipairs(result) do list[#list+1]=view(t,staff,c.identifier) end
    subscriptions[player]={character=c,scope=staff and "staff" or "player"}
    return {tickets=list,page=page,pageSize=C.pageSize,total=tonumber(count.n),summary=totals,categories=C.categories,maxOpen=C.maxOpenTickets}
end
function Support.detail(player,p)
    local c=Support.identity(player);local id=number(p.ticket)
    if not c or not id then return nil,"Invalid ticket." end
    local staff=staffScope(player,p)
    if p.scope=="staff" and not staff then return nil,"Staff access denied." end
    local t=get(id);if not canRead(player,c,t,staff) then return nil,"Ticket not found or access denied." end
    local before=number(p.before)
    local values={id};local predicate="ticket_id=?"..(staff and "" or " AND internal=0")
    if before then predicate=predicate.." AND id<?";values[#values+1]=before end
    local messages=rows("SELECT id,revision,actor_name,actor_role,kind,body,internal,UNIX_TIMESTAMP(created_at)*1000 AS at FROM lightrp_support_messages WHERE "..predicate.." ORDER BY id DESC LIMIT 51",values)
    if not canRead(player,c,t,staff) then return nil,"Your access changed." end
    local history={};local more=#messages>50
    for i=math.min(50,#messages),1,-1 do local m=messages[i];history[#history+1]={id=tonumber(m.id),revision=tonumber(m.revision),author=m.actor_name,role=m.actor_role,kind=m.kind,body=m.body,internal=tonumber(m.internal)==1,at=tonumber(m.at)} end
    return {ticket=view(t,staff,c.identifier),messages=history,hasOlder=more,
        canManage=staff and (t.assignee_id==c.identifier or Support.allowed(player,"assign")),canAssign=staff and Support.allowed(player,"assign"),
        canReopen=closed[t.status] and t.resolved_ms~=nil and tonumber(t.resolved_ms)>=(GetUnixTime()-C.reopenDays*86400)*1000 or false}
end
function Support.notify(t,internal,actor)
    for _,id in ipairs(GetPlayers()) do
        local c=Support.identity(id)
        local staff=Support.allowed(id,"view") and Support.allowed(id,"reports")
        local owner=c and c.identifier==t.reporter_id
        if c and (staff or (owner and not internal)) then
            TriggerClientEvent(E.net.support,id,{kind="changed",ticket=tonumber(t.id),internal=internal==true})
            if id~=actor then
                LightRP.notice(id,{kind=staff and "staff" or "message",title="Support #"..t.id,
                    body=internal and "A staff note was added." or (t.assignee_name~="" and "Handled by "..t.assignee_name.." · " or "")..t.status:gsub("_"," "),durationMs=7000})
            end
        end
    end
end
local function create(player,p)
    local c=Support.identity(player);local request=token(p.mutation)
    if not c or not request then return nil,"Your account is loading or the request is invalid." end
    local existing=first("SELECT id FROM lightrp_support_tickets WHERE reporter_id=? AND request_key=?",{c.identifier,request})
    if existing then return {ticketId=tonumber(existing.id)} end
    local subject,body=text(p.subject,120,4),text(p.body,2000,10)
    if not subject or not body or not categories[p.category] then return nil,"Choose a category, a subject (4–120 characters) and a description (10–2000 characters)." end
    local now=LightRP.nowMs()
    if createAt[c.identifier] and now-createAt[c.identifier]<C.createCooldownMs then return nil,"Please wait a minute before opening another report." end
    local count=first("SELECT COUNT(*) AS n FROM lightrp_support_tickets WHERE reporter_id=? AND status NOT IN ('resolved','closed')",{c.identifier})
    if tonumber(count.n)>=C.maxOpenTickets then return nil,"You already have "..C.maxOpenTickets.." active tickets. Reply to an existing case." end
    local target=p.reportedPlayer and number(p.reportedPlayer);local reported=target and Support.identity(target)
    if target and (not reported or target==player) then return nil,"Choose another connected player or leave the field empty." end
    local pos=Open77.players.position(player) or {x=0,y=0,z=0,bucket=0}
    if not same(player,c) then return nil,"Your account changed." end
    local name=LightRP.characters.displayName(player)
    local ok=Db.transaction({
        {query=[[INSERT INTO lightrp_support_tickets (reporter_id,character_key,reporter_name,subject,category,reported_id,reported_name,x,y,z,bucket,request_key)
          VALUES (?,?,?,?,?,?,?,?,?,?,?,?)]],values={c.identifier,c.key,name,subject,p.category,reported and reported.identifier or "",reported and LightRP.characters.displayName(target) or "",pos.x,pos.y,pos.z,pos.bucket or 0,request}},
        {query=[[INSERT INTO lightrp_support_messages (ticket_id,revision,actor_id,actor_name,actor_role,kind,body,request_key)
          SELECT id,1,reporter_id,reporter_name,'player','created',?,request_key FROM lightrp_support_tickets WHERE reporter_id=? AND request_key=?]],values={body,c.identifier,request}},
    })
    if not ok then return nil,"The report could not be saved. Retry without closing your draft." end
    createAt[c.identifier]=now
    local t=first("SELECT "..TICKET_FIELDS.." FROM lightrp_support_tickets t WHERE reporter_id=? AND request_key=?",{c.identifier,request})
    Support.notify(t,false,player)
    return {ticketId=tonumber(t.id)}
end
function Support.create(player,p)
    local c=Support.identity(player)
    if not c then return nil,"Your account is still loading." end
    return withOwnerWrite(c.identifier,function() return create(player,p) end)
end
local function mutate(player,p)
    local c=Support.identity(player);local id=number(p.ticket);local request=token(p.mutation)
    if not c or not id or not request then return nil,"Invalid ticket request." end
    local staff=staffScope(player,p);if p.scope=="staff" and not staff then return nil,"Staff access denied." end
    local t=get(id);if not canRead(player,c,t,staff) then return nil,"Ticket not found or access denied." end
    local duplicate=first("SELECT id FROM lightrp_support_messages WHERE ticket_id=? AND actor_id=? AND request_key=?",{id,c.identifier,request})
    if duplicate then return {ticketId=id} end
    if tonumber(p.revision)~=tonumber(staff and t.revision or t.public_revision) then return nil,"This ticket changed. Refresh it before sending your action." end
    local operation=p.action
    local body=text(p.body,2000)
    local internal=false;local status,assigned,name,priority=t.status,t.assignee_id,t.assignee_name,t.priority
    local own=t.reporter_id==c.identifier
    local manages=staff and (assigned==c.identifier or Support.allowed(player,"assign"))
    if operation=="reply" or operation=="note" then
        if closed[status] then return nil,"Reopen the ticket before replying." end
        if not body then return nil,"Write a message (up to 2000 characters)." end
        if operation=="note" then if not staff then return nil,"Staff notes are private." end;internal=true
        elseif not staff then if not own then return nil,"Access denied." end; status=assigned~="" and "in_progress" or "open" end
    elseif operation=="claim" then
        if not staff or closed[status] then return nil,"This ticket cannot be claimed." end
        if assigned~="" and assigned~=c.identifier then return nil,"Another admin already owns this case. Ask for a transfer." end
        assigned,name,status=c.identifier,GetPlayerName(player) or "Staff","in_progress";body="Case taken by "..name.."."
    elseif operation=="release" then
        if not manages or closed[status] then return nil,"Only the assigned admin or a supervisor can release this case." end
        assigned,name,status="","","open";body="Case returned to the staff queue."
    elseif operation=="assign" then
        if not staff or not Support.allowed(player,"assign") or closed[status] then return nil,"Assignment permission required." end
        local target=number(p.assignee);local a=target and Support.identity(target)
        if not a or not Support.allowed(target,"view") or not Support.allowed(target,"reports") then return nil,"Choose a connected support admin." end
        assigned,name,status=a.identifier,GetPlayerName(target) or "Staff","in_progress";body="Case assigned to "..name.."."
    elseif operation=="priority" then
        if not staff or (p.priority~="normal" and p.priority~="urgent") then return nil,"Invalid priority." end
        priority=p.priority;body="Priority changed to "..priority.."."
    elseif operation=="waiting" or operation=="resolve" then
        if not manages or closed[status] then return nil,"Claim the case before changing its status." end
        if not body or not text(body,2000,4) then return nil,"Explain what is needed or how the issue was resolved." end
        status=operation=="waiting" and "waiting_player" or "resolved"
    elseif operation=="close" then
        if not ((not staff and own) or manages) then return nil,"You cannot close this case." end
        if status=="closed" then return nil,"This case is already closed." end
        if not body or not text(body,2000,4) then return nil,"Add a short closing reason." end
        status="closed"
    elseif operation=="reopen" then
        if not ((not staff and own) or staff) or not closed[status] then return nil,"Only a finished case can be reopened." end
        if not t.resolved_ms or tonumber(t.resolved_ms)<(GetUnixTime()-C.reopenDays*86400)*1000 then return nil,"This case is too old to reopen. Please create a new report." end
        local count=first("SELECT COUNT(*) AS n FROM lightrp_support_tickets WHERE reporter_id=? AND status NOT IN ('resolved','closed')",{t.reporter_id})
        if tonumber(count.n)>=C.maxOpenTickets then return nil,"Too many active tickets for this player." end
        if not body or not text(body,2000,4) then return nil,"Explain why the issue needs more help." end
        status="open";assigned="";name=""
    else return nil,"Unknown report action." end
    if not canRead(player,c,t,staff) then return nil,"Your access changed." end
    local revision=tonumber(t.revision)+1
    local ok=Db.transaction({
        {query=[[INSERT INTO lightrp_support_messages (ticket_id,revision,actor_id,actor_name,actor_role,kind,body,internal,request_key) VALUES (?,?,?,?,?,?,?,?,?)]],
            values={id,revision,c.identifier,staff and (GetPlayerName(player) or "Staff") or LightRP.characters.displayName(player),staff and "staff" or "player",operation,body,internal and 1 or 0,request}},
        {query=[[UPDATE lightrp_support_tickets SET status=?,assignee_id=?,assignee_name=?,priority=?,revision=?,public_revision=?,updated_at=CURRENT_TIMESTAMP(3),
            public_updated_at=IF(?=1,public_updated_at,CURRENT_TIMESTAMP(3)),resolved_at=IF(?=1,CURRENT_TIMESTAMP(3),NULL) WHERE id=? AND revision=?]],
            values={status,assigned,name,priority,revision,internal and tonumber(t.public_revision) or revision,internal and 1 or 0,closed[status] and 1 or 0,id,tonumber(t.revision)}},
    })
    if not ok then return nil,"The ticket changed or storage refused the update. Refresh and retry; your message is still here." end
    t=get(id);Support.notify(t,internal,player)
    return {ticketId=id}
end
function Support.read(player,p)
    local c=Support.identity(player);local id=number(p.ticket);local revision=number(p.revision)
    if not c or not id or not revision then return nil,"Invalid read receipt." end
    local staff=staffScope(player,p);local t=get(id)
    if not canRead(player,c,t,staff) then return nil,"Ticket not found or access denied." end
    local maximum=tonumber(staff and t.revision or t.public_revision)
    if revision>maximum then return nil,"Invalid read receipt." end
    local ok=Db.run([[INSERT INTO lightrp_support_reads (ticket_id,reader_id,scope,revision) VALUES (?,?,?,?)
        ON DUPLICATE KEY UPDATE revision=GREATEST(revision,VALUES(revision))]],{id,c.identifier,staff and "staff" or "player",revision})
    return ok and {read=true} or nil,ok and nil or "Read status could not be saved."
end
function Support.open(player,scope,draft)
    if scope=="staff" and not Support.allowed(player,"view") then return false,"Staff access denied." end
    if not Support.identity(player) then return false,"Your account is still loading." end
    TriggerClientEvent(E.net.support,player,{kind="open",scope=scope or "player",body=draft})
    return true
end
function Support.onDisconnected(player) requests[player],subscriptions[player],lastRequest[player]=nil,nil,nil end
function Support.onCharacterLoaded(player) subscriptions[player]=nil end
function Support.onDatabaseReady()
    -- Preserve historical /report entries and their handled flag. Both imports
    -- are idempotent, including a restart between the ticket and timeline rows.
    local ok=Db.transaction({
        {query=[[INSERT IGNORE INTO lightrp_support_tickets (reporter_id,character_key,reporter_name,subject,category,status,request_key,legacy_id,created_at,updated_at,public_updated_at,resolved_at)
          SELECT identifier,'default',reporter,LEFT(message,120),'other',IF(handled=1,'resolved','open'),CONCAT('legacy:',id),id,created_at,created_at,created_at,IF(handled=1,created_at,NULL) FROM lightrp_reports]]},
        {query=[[INSERT IGNORE INTO lightrp_support_messages (ticket_id,revision,actor_id,actor_name,actor_role,kind,body,request_key,created_at)
          SELECT t.id,1,t.reporter_id,t.reporter_name,'player','created',r.message,CONCAT('legacy:',r.id),r.created_at FROM lightrp_support_tickets t JOIN lightrp_reports r ON t.legacy_id=r.id]]},
    })
    if not ok then LightRP.log("Legacy report migration failed; original reports are preserved. Retry after storage recovery.") end
end
function Support.mutate(player,p)
    if p.action~="reopen" then return mutate(player,p) end
    local id=number(p.ticket);local c=Support.identity(player)
    local t=id and get(id)
    if not canRead(player,c,t,staffScope(player,p)) then return nil,"Ticket not found or access denied." end
    return withOwnerWrite(t.reporter_id,function() return mutate(player,p) end)
end
local handlers={list=Support.list,detail=Support.detail,create=Support.create,mutate=Support.mutate,read=Support.read}
function Support.handle(player,p)
    if type(p)~="table" or not token(p.request) then return end
    local c=Support.identity(player)
    local function reply(ok,data,message) if same(player,c) then TriggerClientEvent(E.net.support,player,{kind="response",request=p.request,ok=ok,data=data,error=message}) end end
    if not c then return end
    if not Db.ready then return reply(false,nil,"Support storage is unavailable. Please retry shortly.") end
    if requests[player] or LightRP.nowMs()-(lastRequest[player] or -1000)<150 then return reply(false,nil,"Please wait a moment and retry.") end
    requests[player]=c;lastRequest[player]=LightRP.nowMs()
    local handler=handlers[p.operation] or (LightRP.admin and LightRP.admin.handlers[p.operation])
    local called,data,message=pcall(function() if not handler then return nil,"Unknown support request." end; return handler(player,p) end)
    if requests[player]==c then requests[player]=nil end
    if not called then LightRP.log("support request %s failed: %s",tostring(p.operation),tostring(data));return reply(false,nil,"Support storage could not answer. Your draft has been kept.") end
    reply(data~=nil,data,message)
end
RegisterNetEvent(E.net.support,function(p) Support.handle(source,p) end)
LightRP.command("report",{usage="/report [message]"},function(player,args)
    local draft=text(LightRP.joinArgs(args),2000)
    local ok,why=Support.open(player,"player",draft)
    return ok,ok and "Your private support desk is open." or why
end)
LightRP.command("reports",{},function(player) return Support.open(player,"player") end)
