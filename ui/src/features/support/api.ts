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
