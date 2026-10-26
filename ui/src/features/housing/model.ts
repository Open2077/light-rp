export interface Point { x:number; y:number; z:number; heading:number }
export interface Resident { name:string; identifier:string; key:string }
export interface Person extends Resident { id:number }
export interface Interior {
  id:string; revision:number; label:string; slots:number; weight:number; ready:boolean;
  points:Partial<Record<"spawn"|"exit"|"stash"|"wardrobe",Point>>;
}
export interface Home {
  id:number; revision:number; label:string; kind:"apartment"|"house"; entrance:Point;
  price:number; rent:number; rentDays:number; enabled:boolean; available:boolean;
  owned:boolean; hasKey:boolean; locked:boolean; near:boolean; resale:number;
  mode?:"purchase"|"rent"|"assigned"; expires?:number; keys?:Resident[]; occupants?:number;
  templateLabel:string; templateId?:string; tenant?:Resident & {mode:string;expires?:number};
}
export interface HousingState {
  counts?:{properties:number;mine:number;nearby:number;available:number;templates:number;recovery:number};
  pages?:Partial<Record<"properties"|"templates"|"players"|"recovery",{page:number;pages:number;total:number}>>;
  defaults?:{slots:number;weight:number;rentDays:number}; maxInteriorRadius?:number; resaleFraction?:number;
  properties:Home[]; templates:Interior[]; players:Person[]; admin:boolean; canAdmin:boolean; now:number;
  recovery:{id:string;label:string;entrance:Point;endedAt:number;near:boolean;reason:string}[];
  inside?:{propertyId?:number;phase:string;label:string};
}
export interface HousingResult { message:string; id?:number|string; close?:boolean }
export const credits=(n:number)=>`${new Intl.NumberFormat("en-US").format(n)} €$`;
export const coordinates=(p?:Point)=>p?`${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)} · ${p.heading.toFixed(0)}°`:"Not captured";
export const expiry=(seconds?:number)=>seconds?new Date(seconds*1000).toLocaleString():"No expiry";
