import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
export type Scope = "player" | "staff";
export const key = () => `desk:${Date.now().toString(36)}:${Math.random().toString(36).slice(2,12)}`;
export interface Wire { kind: string; request?: string; ok?: boolean; data?: unknown; error?: string; ticket?: number; body?: string }
let queue = Promise.resolve();
/** Serialize reads and writes so focus changes and polling never eat the server's action budget. */
export function request<T>(operation: string, payload: Record<string, unknown> = {}): Promise<T> {
  const task = queue.then(() => new Promise<T>((resolve, reject) => {
    const id = key();
    const stop = on<Wire>(PAGE_EVENTS.support, reply => {
      if (reply.kind !== "response" || reply.request !== id) return;
      clearTimeout(timer); stop();
      if (reply.ok) resolve(reply.data as T); else reject(new Error(reply.error || "The server refused this request."));
    });
    const timer = window.setTimeout(() => { stop(); reject(new Error("The server has not answered. Your draft is kept. Refresh before retrying.")); }, 12000);
    emit(PAGE_EVENTS.support, { ...payload, operation, request: id });
  }));
  queue = task.then(() => undefined, () => undefined).then(() => new Promise(resolve => setTimeout(resolve, 190)));
  return task;
}
export interface Ticket {
  id:number; subject:string; category:string; status:string; priority:string; reporter:string; character:string;
  reporterOnline:boolean; reporterPlayer?:number; assignee?:string; assigneeOnline:boolean; assignedToMe:boolean;
  reported?:string; revision:number; createdAt:number; updatedAt:number; resolvedAt?:number; unread:boolean;
  owner?:string; position?:{x:number;y:number;z:number;bucket:number};
}
export interface Message { id:number;revision:number;author:string;role:string;kind:string;body:string;internal:boolean;at:number }
export interface Detail { ticket:Ticket; messages:Message[];hasOlder:boolean;canManage:boolean;canAssign:boolean;canReopen:boolean }
export interface TicketList { tickets:Ticket[];page:number;pageSize:number;total:number;summary:{total:number;open:number;progress:number;waiting:number;finished:number};categories:string[];maxOpen:number }
export interface Job {name:string;label:string;grade:number;gradeLabel:string}
export interface Person {id:number;account:string;character:string;name:string;accountName:string;status:string;job:Job;gang:Job;life:string;playtimeMs:number}
export interface Role {name:string;label:string;grades:{value:number;label:string}[]}
export interface Overview {players:Person[];staff:{id:number;name:string}[];permissions:Record<string,boolean>;jobs:Role[];gangs:Role[];database:boolean}
export interface Audit {id:number;actor_name:string;target_name:string;action:string;reason:string;detail:string;outcome:string;at:number}
export interface Profile extends Person {firstName?:string;lastName?:string;birthDate?:string;origin?:string;story?:string;money?:{cash:number;bank:number;number:string};position?:{x:number;y:number;z:number;bucket:number};history:Audit[];canReturn:boolean;needs?:{food:number;drink:number}}
export const list = <T,>(v:T[]|undefined):T[] => Array.isArray(v) ? v : [];
export const label = (value:string) => ({open:"Waiting for staff",in_progress:"In progress",waiting_player:"Waiting for player",resolved:"Resolved",closed:"Closed"}[value] || value.replaceAll("_"," "));
export const date = (at:number) => Number.isFinite(at) ? new Date(at).toLocaleString([], {month:"short",day:"numeric",hour:"2-digit",minute:"2-digit"}) : "—";
/** A placed table as the staff desk lists it (server/modules/board_games_admin.lua): flat, scalars only. */
export interface PlacedTable {
  id:string; kind:string; title:string; owner:string; inventory:string; online?:number;
  x:number; y:number; z:number; bucket:number; revision:number; placedAt?:number; distance?:number;
  seated:string; seatedCount:number; phase:string; stakes?:number; resolving?:string; busy?:boolean;
}
export interface TableList { tables:PlacedTable[]; page:number; pageSize:number; total:number; pendingReturns:number; canTeleport:boolean; canDelete:boolean }
/** A hidden Maneki-neko as the staff desk lists it (server/modules/maneki.lua): flat, scalars only. */
export interface ManekiSpot {
  id:string; x:number; y:number; z:number; bucket:number; yaw:number; scale:number;
  district:string; placedBy:string; placedAt:number; finds:number; distance?:number;
}
export interface ManekiList { spots:ManekiSpot[]; page:number; pageSize:number; total:number; cats:number; finders:number; mine:number; editing:boolean; canEdit:boolean; canTeleport:boolean }
/** A world event out now, as the staff desk lists it (server/modules/staff_events.lua). */
export interface LiveEvent {
  id:string; kind:"boss"|"psycho"|"gang"; title:string; boss:string; location:string; phase:string; health:number; fighters:number;
  enemies:number; endsInMs?:number; by:string; pay:boolean; silent?:boolean; night?:boolean; distance?:number;
}
export interface EventSpot { id:string; name:string; district:string; by:string; distance?:number }
export interface EventNight { preset:string; label:string; round:number; rounds:number; phase:"intro"|"live"|"break"|"done"; nextInMs?:number; won:number; played:number; live:number; by:string }
export interface EventsView {
  live:LiveEvent[]; bosses:{id:string;title:string;location:string}[]; psychos:{id:string;label:string}[]; crews:{id:string;label:string}[];
  levels:{id:string;label:string;blurb:string}[]; presets:{id:string;label:string;blurb:string;rounds:number;min:number}[]; spots:EventSpot[];
  night?:EventNight|null; maxLive:number; maxRounds:number; random:{enabled:boolean;nextInMs?:number};
  minutes:{default:number;min:number;max:number}; radius:{default:number;min:number;max:number}; canPay:boolean; inCity:boolean;
}
export interface DeskResult { accepted:boolean; outcome:string; message:string }
