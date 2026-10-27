-- Deterministic server-authoritative rules. No engine dependencies or input mutation.
LightRPBoardRules = {}
local R = LightRPBoardRules
-- A callback lives only on private analysis snapshots. Deep copies and square
-- scans cooperate, including validation of the final chosen move. Never store it.
local function copy(t,work)
 if type(t)~='table' then return t end
 work=work or rawget(t,'_cooperate')
 local n={}
 for k,v in pairs(t) do if work then work() end;n[k]=copy(v,work) end
 return n
end
-- Board cells and history entries are immutable. Search branches copy rows,
-- then copy only a piece they actually change; old game snapshots stay intact.
local function fork(s)
 local n={} for k,v in pairs(s) do n[k]=v end
 n.board={}
 for r=1,s.rows or s.size do
  if s._cooperate then s._cooperate() end
  n.board[r]=table.move(s.board[r],1,s.cols or s.size,1,{})
 end
 local captured=s.captured or {};n.captured=table.move(captured,1,#captured,1,{})
 return n
end
local function cooperate(yieldFn)
 if not yieldFn then return nil end
 local ticks=0
 return function()
  ticks=ticks+1
  if ticks>=320 then ticks=0;yieldFn() end
 end
end
local function snapshot(s,work)
 local n=copy(s,work);n._cooperate=work;return n
end
local function other(s) return s=='white' and 'black' or 'white' end
local function inside(s,r,c) return r>=1 and c>=1 and r<=(s.rows or s.size) and c<=(s.cols or s.size) end
local function at(s,r,c) if s._cooperate then s._cooperate() end;return inside(s,r,c) and s.board[r][c] or false end
local function piece(id,side,kind) return {id=id,side=side,kind=kind} end
function R.new(kind)
 if kind~='chess' and kind~='checkers' and kind~='connect4' then return nil,'Unknown game.' end
 local s={kind=kind,size=kind=='chess' and 8 or (kind=='checkers' and 10 or 7),board={},turn='white',status='playing',captured={},ply=0,halfmove=0}
 s.rows=kind=='connect4' and 6 or s.size; s.cols=s.size
 for r=1,s.rows do s.board[r]={} for c=1,s.cols do s.board[r][c]=false end end
 local id=0
 local function put(r,c,side,k) id=id+1 s.board[r][c]=piece(id,side,k) end
 if kind=='chess' then
  local back={'rook','knight','bishop','queen','king','bishop','knight','rook'}
  for c=1,8 do put(1,c,'black',back[c]) put(2,c,'black','pawn') put(7,c,'white','pawn') put(8,c,'white',back[c]) end
 elseif kind=='checkers' then
  for r=1,10 do for c=1,10 do if (r+c)%2==1 and (r<=4 or r>=7) then put(r,c,r<=4 and 'black' or 'white','man') end end end
 end
 return s
end
local function clear(s,fr,fc,tr,tc)
 local dr=tr==fr and 0 or (tr>fr and 1 or -1) local dc=tc==fc and 0 or (tc>fc and 1 or -1)
 local r,c=fr+dr,fc+dc
 while r~=tr or c~=tc do if at(s,r,c) then return false end r=r+dr c=c+dc end return true
end
local function attacked(s,r,c,by)
 for fr=1,8 do for fc=1,8 do local p=at(s,fr,fc)
 if p and p.side==by then local dr,dc=r-fr,c-fc local ar,ac=math.abs(dr),math.abs(dc)
  if p.kind=='pawn' and dr==(by=='white' and -1 or 1) and ac==1 then return true
  elseif p.kind=='knight' and ar*ac==2 then return true
  elseif p.kind=='king' and math.max(ar,ac)==1 then return true
  elseif ((p.kind=='rook' and (dr==0 or dc==0)) or (p.kind=='bishop' and ar==ac) or (p.kind=='queen' and (dr==0 or dc==0 or ar==ac))) and ar+ac>0 and clear(s,fr,fc,r,c) then return true end
 end end end return false
end
local function check(s,side)
 for r=1,8 do for c=1,8 do local p=at(s,r,c) if p and p.side==side and p.kind=='king' then return attacked(s,r,c,other(side)) end end end return true
end
local function take(s,r,c,side)
 local p=at(s,r,c) if p then p=copy(p,s._cooperate);p.capturedBy=side s.captured[#s.captured+1]=p s.board[r][c]=false end
end
local function chessMove(s,fr,fc,tr,tc,promotion)
 local p=at(s,fr,fc) local dest=at(s,tr,tc) local dr,dc=tr-fr,tc-fc local ar,ac=math.abs(dr),math.abs(dc)
 if dest and (dest.side==p.side or dest.kind=='king') then return nil end
 local ep,castle=false,false local valid=false
 if p.kind=='pawn' then
  local dir=p.side=='white' and -1 or 1 local home=p.side=='white' and 7 or 2
  valid=dc==0 and not dest and (dr==dir or (fr==home and dr==2*dir and not at(s,fr+dir,fc)))
  if ac==1 and dr==dir then
   valid=dest and true or false
   if not dest and s.enPassant and s.enPassant.row==tr and s.enPassant.col==tc then local victim=at(s,fr,tc) ep=victim and victim.kind=='pawn' and victim.side~=p.side valid=ep end
  end
 elseif p.kind=='knight' then valid=ar*ac==2
 elseif p.kind=='bishop' then valid=ar==ac and clear(s,fr,fc,tr,tc)
 elseif p.kind=='rook' then valid=(dr==0 or dc==0) and clear(s,fr,fc,tr,tc)
 elseif p.kind=='queen' then valid=(dr==0 or dc==0 or ar==ac) and clear(s,fr,fc,tr,tc)
 elseif p.kind=='king' then
  valid=math.max(ar,ac)==1
  if dr==0 and ac==2 and fc==5 and fr==(p.side=='white' and 8 or 1) and not p.moved and not check(s,p.side) then
   local rookCol=dc>0 and 8 or 1 local rook=at(s,fr,rookCol) local step=dc>0 and 1 or -1
   castle=rook and rook.kind=='rook' and rook.side==p.side and not rook.moved and clear(s,fr,fc,fr,rookCol) and not attacked(s,fr,fc+step,other(p.side)) and not attacked(s,tr,tc,other(p.side))
   valid=castle and true or false
  end
 end
 if not valid then return nil end
 local n=fork(s) local moving=copy(n.board[fr][fc],s._cooperate) n.enPassant=nil
 take(n,tr,tc,p.side) if ep then take(n,fr,tc,p.side) end
 n.board[tr][tc]=moving n.board[fr][fc]=false moving.moved=true
 if castle then local rc=dc>0 and 8 or 1 local target=dc>0 and 6 or 4 n.board[fr][target]=copy(n.board[fr][rc],s._cooperate) n.board[fr][rc]=false n.board[fr][target].moved=true end
 if p.kind=='pawn' then
  if ar==2 then n.enPassant={row=(fr+tr)/2,col=fc} end
  if tr==1 or tr==8 then local k=promotion or 'queen' if k~='queen' and k~='rook' and k~='bishop' and k~='knight' then return nil end moving.kind=k end
 end
 if check(n,p.side) then return nil end
 n.halfmove=(p.kind=='pawn' or dest or ep) and 0 or (s.halfmove or 0)+1
 n.turn=other(s.turn) n.ply=(s.ply or 0)+1 return n
end
local function chessLegal(s)
 for r=1,8 do for c=1,8 do local p=at(s,r,c) if p and p.side==s.turn then for tr=1,8 do for tc=1,8 do if r~=tr or c~=tc then if chessMove(s,r,c,tr,tc) then return true end end end end end end end return false
end
local dirs={{1,1},{1,-1},{-1,1},{-1,-1}}
-- Captured men stay as blockers until the entire international-draughts sequence ends.
local function jumps(s,r,c,taken)
 local out={} local p=at(s,r,c)
 for _,d in ipairs(dirs) do local rr,cc=r+d[1],c+d[2] local victim
  while inside(s,rr,cc) do local q=at(s,rr,cc)
   if q then
    if victim or q.side==p.side or taken[q.id] then break end victim={row=rr,col=cc,id=q.id}
   elseif victim then out[#out+1]={row=rr,col=cc,victim=victim} if p.kind~='king' then break end
   elseif p.kind~='king' then break end
   if p.kind~='king' and not victim then break end
   rr=rr+d[1] cc=cc+d[2]
  end
 end return out
end
local function maxJumps(s,r,c,taken)
 local best=0
 for _,j in ipairs(jumps(s,r,c,taken)) do local n=fork(s) n.board[j.row][j.col]=n.board[r][c] n.board[r][c]=false local t=copy(taken) t[j.victim.id]=true best=math.max(best,1+maxJumps(n,j.row,j.col,t)) end
 return best
end
local function maxForSide(s)
 local best=0 for r=1,10 do for c=1,10 do local p=at(s,r,c) if p and p.side==s.turn then best=math.max(best,maxJumps(s,r,c,{})) end end end return best
end
local function draughtsLegal(s)
 for r=1,10 do for c=1,10 do local p=at(s,r,c) if p and p.side==s.turn then
  if #jumps(s,r,c,{})>0 then return true end
  for _,d in ipairs(dirs) do if (p.kind=='king' or d[1]==(p.side=='white' and -1 or 1)) and inside(s,r+d[1],c+d[2]) and not at(s,r+d[1],c+d[2]) then return true end end
 end end end return false
end
local function draughtsMove(s,fr,fc,tr,tc,requiredOverride)
 local p=at(s,fr,fc) if at(s,tr,tc) then return nil end
 if s.chain and (s.chain.row~=fr or s.chain.col~=fc) then return nil end
 local taken=s.chain and s.chain.taken or {} local required=s.chain and s.chain.remaining or requiredOverride or maxForSide(s) local chosen
 if required>0 then
  for _,j in ipairs(jumps(s,fr,fc,taken)) do if j.row==tr and j.col==tc then
   local tmp=fork(s) tmp.board[tr][tc]=tmp.board[fr][fc] tmp.board[fr][fc]=false local t=copy(taken) t[j.victim.id]=true
   if 1+maxJumps(tmp,tr,tc,t)==required then chosen=j end
  end end
  if not chosen then return nil end
 else
  local dr,dc=tr-fr,tc-fc
  if math.abs(dr)~=math.abs(dc) or (p.kind~='king' and (math.abs(dr)~=1 or dr~=(p.side=='white' and -1 or 1))) or not clear(s,fr,fc,tr,tc) then return nil end
 end
 local n=fork(s) n.board[tr][tc]=n.board[fr][fc] n.board[fr][fc]=false
 if chosen then local t=copy(taken) t[chosen.victim.id]=true
  if required>1 then n.chain={row=tr,col=tc,taken=t,remaining=required-1} return n end
  for r=1,10 do for c=1,10 do local q=at(n,r,c) if q and t[q.id] then take(n,r,c,p.side) end end end
 end
 n.chain=nil
 if (p.side=='white' and tr==1) or (p.side=='black' and tr==10) then n.board[tr][tc]=copy(n.board[tr][tc],s._cooperate);n.board[tr][tc].kind='king' end
 n.turn=other(s.turn) n.ply=(s.ply or 0)+1
 if not draughtsLegal(n) then n.status='won' n.winner=p.side end
 return n
end
local function positionKey(s)
 local parts={s.turn}
 for r=1,8 do for c=1,8 do local p=at(s,r,c) parts[#parts+1]=p and (p.side..p.kind) or '.' end end
 for _,side in ipairs({'white','black'}) do local row=side=='white' and 8 or 1 local king=at(s,row,5)
  for _,col in ipairs({1,8}) do local rook=at(s,row,col) parts[#parts+1]=(king and king.kind=='king' and king.side==side and not king.moved and rook and rook.kind=='rook' and rook.side==side and not rook.moved) and side..col or '-' end
 end
 -- En-passant only distinguishes positions when an actual legal capture exists.
 if s.enPassant then local ep=s.enPassant local fr=ep.row+(s.turn=='white' and 1 or -1)
  for _,fc in ipairs({ep.col-1,ep.col+1}) do local p=at(s,fr,fc) if p and p.side==s.turn and p.kind=='pawn' and chessMove(s,fr,fc,ep.row,ep.col) then parts[#parts+1]='ep'..ep.row..','..ep.col break end end
 end
 return table.concat(parts,'|')
end
local function insufficient(s)
 local minor={} local bishopColor
 for r=1,8 do for c=1,8 do local p=at(s,r,c) if p and p.kind~='king' then
  if p.kind~='bishop' and p.kind~='knight' then return false end
  minor[#minor+1]=p.kind
  if p.kind=='bishop' then local color=(r+c)%2 if bishopColor~=nil and bishopColor~=color then return false end bishopColor=color end
 end end end
 if #minor<=1 then return true end
 for _,kind in ipairs(minor) do if kind~='bishop' then return false end end return true
end
local function connectMove(s,col)
 if type(col)~='number' or col~=math.floor(col) or col<1 or col>7 or at(s,1,col) then return nil end
 local row=6 while at(s,row,col) do row=row-1 end
 local n=fork(s);n.ply=(s.ply or 0)+1
 n.board[row][col]=piece(n.ply,s.turn,'disc')
 n.lastMove={fromRow=0,fromCol=col,toRow=row,toCol=col}
 for _,d in ipairs({{1,0},{0,1},{1,1},{1,-1}}) do
  local count=1
  for _,sign in ipairs({-1,1}) do local r,c=row+d[1]*sign,col+d[2]*sign
   while inside(n,r,c) and at(n,r,c) and at(n,r,c).side==s.turn do count=count+1;r=r+d[1]*sign;c=c+d[2]*sign end
  end
  if count>=4 then n.status='won';n.winner=s.turn;break end
 end
 n.turn=other(s.turn)
 if n.status=='playing' then local full=true for c=1,7 do if not at(n,1,c) then full=false end end if full then n.status='draw' end end
 return n
end
function R.move(s,fr,fc,tr,tc,promotion)
 if type(s)~='table' or s.status~='playing' then return nil,'The game has ended.' end
 if s.kind=='connect4' then local n=connectMove(s,tc);if not n then return nil,'This column is full or invalid.' end return n end
 for _,v in ipairs({fr,fc,tr,tc}) do if type(v)~='number' or v~=math.floor(v) then return nil,'Invalid square.' end end
 if not fr or not fc or not tr or not tc or not inside(s,fr,fc) or not inside(s,tr,tc) or (fr==tr and fc==tc) then return nil,'Invalid square.' end
 local p=at(s,fr,fc) if not p or p.side~=s.turn then return nil,'That is not your piece.' end
 local n=s.kind=='chess' and chessMove(s,fr,fc,tr,tc,promotion) or (s.kind=='checkers' and draughtsMove(s,fr,fc,tr,tc))
 if not n then return nil,'Illegal move.' end
 if s.kind=='chess' then
  n.check=check(n,n.turn)
  if not chessLegal(n) then n.status=n.check and 'won' or 'draw' if n.check then n.winner=s.turn end
  elseif n.halfmove>=100 or insufficient(n) then n.status='draw' end
  n.positions=copy(s.positions or {[positionKey(s)]=1},s._cooperate)
  local key=positionKey(n) n.positions[key]=(n.positions[key] or 0)+1
  if n.status=='playing' and n.positions[key]>=3 then n.status='draw' end
 end
 return n
end
-- Enumerate geometry first, then validate with the same rule functions as live play.
-- Search states omit historical repetition/capture lists to keep analysis copies small.
local knightSteps={{1,2},{1,-2},{-1,2},{-1,-2},{2,1},{2,-1},{-2,1},{-2,-1}}
local rays={{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
local function candidates(s)
 local out={} if s.status~='playing' then return out end
 local function add(fr,fc,tr,tc,promotion)
  if inside(s,tr,tc) then out[#out+1]={fromRow=fr,fromCol=fc,toRow=tr,toCol=tc,promotion=promotion} end
 end
 if s.kind=='connect4' then
  for _,c in ipairs({4,3,5,2,6,1,7}) do if not at(s,1,c) then local r=6 while at(s,r,c) do r=r-1 end add(0,c,r,c) end end
  return out
 end
 for r=1,s.rows or s.size do for c=1,s.cols or s.size do local p=at(s,r,c)
  if p and p.side==s.turn and (not s.chain or (s.chain.row==r and s.chain.col==c)) then
   if s.kind=='checkers' then
    for _,j in ipairs(jumps(s,r,c,s.chain and s.chain.taken or {})) do add(r,c,j.row,j.col) end
    for _,d in ipairs(dirs) do local rr,cc=r+d[1],c+d[2]
     while inside(s,rr,cc) and not at(s,rr,cc) do add(r,c,rr,cc);if p.kind~='king' then break end;rr=rr+d[1];cc=cc+d[2] end
    end
   elseif p.kind=='pawn' then
    local dir=p.side=='white' and -1 or 1
    for _,dc in ipairs({0,-1,1}) do local tr=r+dir
     if tr==1 or tr==8 then for _,promotion in ipairs({'queen','rook','bishop','knight'}) do add(r,c,tr,c+dc,promotion) end
     else add(r,c,tr,c+dc) end
    end
    add(r,c,r+dir*2,c)
   elseif p.kind=='knight' then for _,d in ipairs(knightSteps) do add(r,c,r+d[1],c+d[2]) end
   elseif p.kind=='king' then
    for _,d in ipairs(rays) do add(r,c,r+d[1],c+d[2]) end add(r,c,r,c+2);add(r,c,r,c-2)
   else
    for index,d in ipairs(rays) do
     if p.kind=='queen' or (p.kind=='rook' and index<=4) or (p.kind=='bishop' and index>4) then
      local rr,cc=r+d[1],c+d[2]
      while inside(s,rr,cc) do add(r,c,rr,cc);if at(s,rr,cc) then break end;rr=rr+d[1];cc=cc+d[2] end
     end
    end
   end
  end
 end end
 return out
end
local function successors(s,limit)
 local out={} local required=s.kind=='checkers' and (s.chain and s.chain.remaining or maxForSide(s)) or nil
 for _,m in ipairs(candidates(s)) do
  local n
  if s.kind=='chess' then n=chessMove(s,m.fromRow,m.fromCol,m.toRow,m.toCol,m.promotion)
  elseif s.kind=='checkers' then n=draughtsMove(s,m.fromRow,m.fromCol,m.toRow,m.toCol,required)
  elseif s.kind=='connect4' then n=connectMove(s,m.toCol) end
  if n then out[#out+1]={state=n,move=m};if limit and #out>=limit then break end end
 end
 return out
end
function R.legalMoves(s,yieldFn)
 if type(s)~='table' or s.status~='playing' then return {} end
 local analysis=yieldFn and snapshot(s,cooperate(yieldFn)) or s
 local moves={} for _,candidate in ipairs(successors(analysis)) do moves[#moves+1]=candidate.move end return moves
end
local values={pawn=100,knight=320,bishop=330,rook=500,queen=900,king=20000,man=100,disc=10}
local function evaluate(s,side)
 if s.status=='won' then return s.winner==side and 1000000 or -1000000 end
 if s.status=='draw' then return 0 end
 local score=0
 for r=1,s.rows or s.size do for c=1,s.cols or s.size do local p=at(s,r,c)
  if p and not (s.chain and s.chain.taken[p.id]) then
   local value=values[p.kind] or 0
   if s.kind=='checkers' then value=p.kind=='king' and 300 or 100+(p.side=='white' and 10-r or r)*3 end
   if s.kind=='connect4' then value=10+(4-math.abs(4-c))*2 end
   score=score+(p.side==side and value or -value)
  end
 end end
 -- Reward open Connect Four windows, with larger values for immediate threats.
 if s.kind=='connect4' then
  for r=1,6 do for c=1,7 do for _,d in ipairs({{1,0},{0,1},{1,1},{1,-1}}) do
   if inside(s,r+d[1]*3,c+d[2]*3) then
    local own,opp=0,0
    for i=0,3 do local p=at(s,r+d[1]*i,c+d[2]*i) if p then if p.side==side then own=own+1 else opp=opp+1 end end end
    if opp==0 then score=score+({[0]=0,2,12,120,1000000})[own] end
    if own==0 then score=score-({[0]=0,2,12,150,1000000})[opp] end
   end
  end end end
 end
 return score
end
function R.aiMove(s,yieldFn)
 if type(s)~='table' or s.status~='playing' then return nil,'The game has ended.' end
 local work=cooperate(yieldFn)
 local analysis=snapshot(s,work);analysis.positions=nil;analysis.captured={}
 local side=s.turn
 local roots=successors(analysis)
 if #roots==0 then return nil,'No legal moves.' end
 -- Rank all legal moves; examine at most 12 roots and 8 replies each.
 for i,c in ipairs(roots) do c.score=evaluate(c.state,side);c.order=i end
 -- Lua cannot yield from a table.sort comparator. Stable insertion sort is
 -- small here and keeps even sorting inside the same cooperative slices.
 for i=2,#roots do
  local value,j=roots[i],i-1
  while j>=1 and roots[j].score<value.score do
   if work then work() end;roots[j+1]=roots[j];j=j-1
  end
  roots[j+1]=value
 end
 local best,bestScore=roots[1],-math.huge
 local rootLimit=s.kind=='connect4' and 7 or 12
 for i=1,math.min(#roots,rootLimit) do local candidate=roots[i] local n=candidate.state local score=candidate.score
  if n.status=='playing' then
   local replies=successors(n,s.kind=='connect4' and 7 or 8)
   if #replies==0 and n.kind=='chess' then score=check(n,n.turn) and (n.turn==side and -1000000 or 1000000) or 0
   elseif #replies>0 then
    local sameTurn=n.turn==side;score=sameTurn and -math.huge or math.huge
    for _,reply in ipairs(replies) do local value=evaluate(reply.state,side)
     -- Penalize hanging chess pieces even when the bounded reply list omits a capture.
     if reply.state.kind=='chess' and check(reply.state,side) then value=value-35 end
     if sameTurn then score=math.max(score,value) else score=math.min(score,value) end
    end
   end
  end
  if score>bestScore then bestScore=score;best=candidate end
 end
 local m=best.move
 local nextState,reason=R.move(snapshot(s,work),m.fromRow,m.fromCol,m.toRow,m.toCol,m.promotion)
 if not nextState then return nil,reason end
 nextState._cooperate=nil
 return nextState,m
end
