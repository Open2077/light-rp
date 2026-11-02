const __vite__mapDeps=(i,m=__vite__mapDeps,d=(m.f||(m.f=["./chunk-MockPanel.js","./chunk-mock.js"])))=>i.map(i=>d[i]);
(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const a of document.querySelectorAll('link[rel="modulepreload"]'))s(a);new MutationObserver(a=>{for(const c of a)if(c.type==="childList")for(const u of c.addedNodes)u.tagName==="LINK"&&u.rel==="modulepreload"&&s(u)}).observe(document,{childList:!0,subtree:!0});function t(a){const c={};return a.integrity&&(c.integrity=a.integrity),a.referrerPolicy&&(c.referrerPolicy=a.referrerPolicy),a.crossOrigin==="use-credentials"?c.credentials="include":a.crossOrigin==="anonymous"?c.credentials="omit":c.credentials="same-origin",c}function s(a){if(a.ep)return;a.ep=!0;const c=t(a);fetch(a.href,c)}})();const fy="modulepreload",py=function(n,e){return new URL(n,e).href},fg={},dp=function(e,t,s){let a=Promise.resolve();if(t&&t.length>0){let u=function(g){return Promise.all(g.map(v=>Promise.resolve(v).then(x=>({status:"fulfilled",value:x}),x=>({status:"rejected",reason:x}))))};const d=document.getElementsByTagName("link"),f=document.querySelector("meta[property=csp-nonce]"),p=f?.nonce||f?.getAttribute("nonce");a=u(t.map(g=>{if(g=py(g,s),g in fg)return;fg[g]=!0;const v=g.endsWith(".css"),x=v?'[rel="stylesheet"]':"";if(!!s)for(let E=d.length-1;E>=0;E--){const _=d[E];if(_.href===g&&(!v||_.rel==="stylesheet"))return}else if(document.querySelector(`link[href="${g}"]${x}`))return;const w=document.createElement("link");if(w.rel=v?"stylesheet":fy,v||(w.as="script"),w.crossOrigin="",w.href=g,p&&w.setAttribute("nonce",p),document.head.appendChild(w),v)return new Promise((E,_)=>{w.addEventListener("load",E),w.addEventListener("error",()=>_(new Error(`Unable to preload CSS for ${g}`)))})}))}function c(u){const d=new Event("vite:preloadError",{cancelable:!0});if(d.payload=u,window.dispatchEvent(d),!d.defaultPrevented)throw u}return a.then(u=>{for(const d of u||[])d.status==="rejected"&&c(d.reason);return e().catch(c)})};function my(n){return n&&n.__esModule&&Object.prototype.hasOwnProperty.call(n,"default")?n.default:n}var vh={exports:{}},Ho={},xh={exports:{}},ht={};/**
 * @license React
 * react.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var pg;function gy(){if(pg)return ht;pg=1;var n=Symbol.for("react.element"),e=Symbol.for("react.portal"),t=Symbol.for("react.fragment"),s=Symbol.for("react.strict_mode"),a=Symbol.for("react.profiler"),c=Symbol.for("react.provider"),u=Symbol.for("react.context"),d=Symbol.for("react.forward_ref"),f=Symbol.for("react.suspense"),p=Symbol.for("react.memo"),g=Symbol.for("react.lazy"),v=Symbol.iterator;function x(O){return O===null||typeof O!="object"?null:(O=v&&O[v]||O["@@iterator"],typeof O=="function"?O:null)}var y={isMounted:function(){return!1},enqueueForceUpdate:function(){},enqueueReplaceState:function(){},enqueueSetState:function(){}},w=Object.assign,E={};function _(O,le,we){this.props=O,this.context=le,this.refs=E,this.updater=we||y}_.prototype.isReactComponent={},_.prototype.setState=function(O,le){if(typeof O!="object"&&typeof O!="function"&&O!=null)throw Error("setState(...): takes an object of state variables to update or a function which returns an object of state variables.");this.updater.enqueueSetState(this,O,le,"setState")},_.prototype.forceUpdate=function(O){this.updater.enqueueForceUpdate(this,O,"forceUpdate")};function M(){}M.prototype=_.prototype;function L(O,le,we){this.props=O,this.context=le,this.refs=E,this.updater=we||y}var A=L.prototype=new M;A.constructor=L,w(A,_.prototype),A.isPureReactComponent=!0;var R=Array.isArray,k=Object.prototype.hasOwnProperty,D={current:null},U={key:!0,ref:!0,__self:!0,__source:!0};function $(O,le,we){var K,fe={},Te=null,Ae=null;if(le!=null)for(K in le.ref!==void 0&&(Ae=le.ref),le.key!==void 0&&(Te=""+le.key),le)k.call(le,K)&&!U.hasOwnProperty(K)&&(fe[K]=le[K]);var Ie=arguments.length-2;if(Ie===1)fe.children=we;else if(1<Ie){for(var Ue=Array(Ie),rt=0;rt<Ie;rt++)Ue[rt]=arguments[rt+2];fe.children=Ue}if(O&&O.defaultProps)for(K in Ie=O.defaultProps,Ie)fe[K]===void 0&&(fe[K]=Ie[K]);return{$$typeof:n,type:O,key:Te,ref:Ae,props:fe,_owner:D.current}}function te(O,le){return{$$typeof:n,type:O.type,key:le,ref:O.ref,props:O.props,_owner:O._owner}}function T(O){return typeof O=="object"&&O!==null&&O.$$typeof===n}function P(O){var le={"=":"=0",":":"=2"};return"$"+O.replace(/[=:]/g,function(we){return le[we]})}var re=/\/+/g;function J(O,le){return typeof O=="object"&&O!==null&&O.key!=null?P(""+O.key):le.toString(36)}function ae(O,le,we,K,fe){var Te=typeof O;(Te==="undefined"||Te==="boolean")&&(O=null);var Ae=!1;if(O===null)Ae=!0;else switch(Te){case"string":case"number":Ae=!0;break;case"object":switch(O.$$typeof){case n:case e:Ae=!0}}if(Ae)return Ae=O,fe=fe(Ae),O=K===""?"."+J(Ae,0):K,R(fe)?(we="",O!=null&&(we=O.replace(re,"$&/")+"/"),ae(fe,le,we,"",function(rt){return rt})):fe!=null&&(T(fe)&&(fe=te(fe,we+(!fe.key||Ae&&Ae.key===fe.key?"":(""+fe.key).replace(re,"$&/")+"/")+O)),le.push(fe)),1;if(Ae=0,K=K===""?".":K+":",R(O))for(var Ie=0;Ie<O.length;Ie++){Te=O[Ie];var Ue=K+J(Te,Ie);Ae+=ae(Te,le,we,Ue,fe)}else if(Ue=x(O),typeof Ue=="function")for(O=Ue.call(O),Ie=0;!(Te=O.next()).done;)Te=Te.value,Ue=K+J(Te,Ie++),Ae+=ae(Te,le,we,Ue,fe);else if(Te==="object")throw le=String(O),Error("Objects are not valid as a React child (found: "+(le==="[object Object]"?"object with keys {"+Object.keys(O).join(", ")+"}":le)+"). If you meant to render a collection of children, use an array instead.");return Ae}function ve(O,le,we){if(O==null)return O;var K=[],fe=0;return ae(O,K,"","",function(Te){return le.call(we,Te,fe++)}),K}function V(O){if(O._status===-1){var le=O._result;le=le(),le.then(function(we){(O._status===0||O._status===-1)&&(O._status=1,O._result=we)},function(we){(O._status===0||O._status===-1)&&(O._status=2,O._result=we)}),O._status===-1&&(O._status=0,O._result=le)}if(O._status===1)return O._result.default;throw O._result}var de={current:null},z={transition:null},ue={ReactCurrentDispatcher:de,ReactCurrentBatchConfig:z,ReactCurrentOwner:D};function oe(){throw Error("act(...) is not supported in production builds of React.")}return ht.Children={map:ve,forEach:function(O,le,we){ve(O,function(){le.apply(this,arguments)},we)},count:function(O){var le=0;return ve(O,function(){le++}),le},toArray:function(O){return ve(O,function(le){return le})||[]},only:function(O){if(!T(O))throw Error("React.Children.only expected to receive a single React element child.");return O}},ht.Component=_,ht.Fragment=t,ht.Profiler=a,ht.PureComponent=L,ht.StrictMode=s,ht.Suspense=f,ht.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED=ue,ht.act=oe,ht.cloneElement=function(O,le,we){if(O==null)throw Error("React.cloneElement(...): The argument must be a React element, but you passed "+O+".");var K=w({},O.props),fe=O.key,Te=O.ref,Ae=O._owner;if(le!=null){if(le.ref!==void 0&&(Te=le.ref,Ae=D.current),le.key!==void 0&&(fe=""+le.key),O.type&&O.type.defaultProps)var Ie=O.type.defaultProps;for(Ue in le)k.call(le,Ue)&&!U.hasOwnProperty(Ue)&&(K[Ue]=le[Ue]===void 0&&Ie!==void 0?Ie[Ue]:le[Ue])}var Ue=arguments.length-2;if(Ue===1)K.children=we;else if(1<Ue){Ie=Array(Ue);for(var rt=0;rt<Ue;rt++)Ie[rt]=arguments[rt+2];K.children=Ie}return{$$typeof:n,type:O.type,key:fe,ref:Te,props:K,_owner:Ae}},ht.createContext=function(O){return O={$$typeof:u,_currentValue:O,_currentValue2:O,_threadCount:0,Provider:null,Consumer:null,_defaultValue:null,_globalName:null},O.Provider={$$typeof:c,_context:O},O.Consumer=O},ht.createElement=$,ht.createFactory=function(O){var le=$.bind(null,O);return le.type=O,le},ht.createRef=function(){return{current:null}},ht.forwardRef=function(O){return{$$typeof:d,render:O}},ht.isValidElement=T,ht.lazy=function(O){return{$$typeof:g,_payload:{_status:-1,_result:O},_init:V}},ht.memo=function(O,le){return{$$typeof:p,type:O,compare:le===void 0?null:le}},ht.startTransition=function(O){var le=z.transition;z.transition={};try{O()}finally{z.transition=le}},ht.unstable_act=oe,ht.useCallback=function(O,le){return de.current.useCallback(O,le)},ht.useContext=function(O){return de.current.useContext(O)},ht.useDebugValue=function(){},ht.useDeferredValue=function(O){return de.current.useDeferredValue(O)},ht.useEffect=function(O,le){return de.current.useEffect(O,le)},ht.useId=function(){return de.current.useId()},ht.useImperativeHandle=function(O,le,we){return de.current.useImperativeHandle(O,le,we)},ht.useInsertionEffect=function(O,le){return de.current.useInsertionEffect(O,le)},ht.useLayoutEffect=function(O,le){return de.current.useLayoutEffect(O,le)},ht.useMemo=function(O,le){return de.current.useMemo(O,le)},ht.useReducer=function(O,le,we){return de.current.useReducer(O,le,we)},ht.useRef=function(O){return de.current.useRef(O)},ht.useState=function(O){return de.current.useState(O)},ht.useSyncExternalStore=function(O,le,we){return de.current.useSyncExternalStore(O,le,we)},ht.useTransition=function(){return de.current.useTransition()},ht.version="18.3.1",ht}var mg;function hp(){return mg||(mg=1,xh.exports=gy()),xh.exports}/**
 * @license React
 * react-jsx-runtime.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var gg;function _y(){if(gg)return Ho;gg=1;var n=hp(),e=Symbol.for("react.element"),t=Symbol.for("react.fragment"),s=Object.prototype.hasOwnProperty,a=n.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED.ReactCurrentOwner,c={key:!0,ref:!0,__self:!0,__source:!0};function u(d,f,p){var g,v={},x=null,y=null;p!==void 0&&(x=""+p),f.key!==void 0&&(x=""+f.key),f.ref!==void 0&&(y=f.ref);for(g in f)s.call(f,g)&&!c.hasOwnProperty(g)&&(v[g]=f[g]);if(d&&d.defaultProps)for(g in f=d.defaultProps,f)v[g]===void 0&&(v[g]=f[g]);return{$$typeof:e,type:d,key:x,ref:y,props:v,_owner:a.current}}return Ho.Fragment=t,Ho.jsx=u,Ho.jsxs=u,Ho}var _g;function vy(){return _g||(_g=1,vh.exports=_y()),vh.exports}var l=vy(),q=hp();const Qc=my(q);var Ec={},yh={exports:{}},Gn={},Sh={exports:{}},Mh={};/**
 * @license React
 * scheduler.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var vg;function xy(){return vg||(vg=1,(function(n){function e(z,ue){var oe=z.length;z.push(ue);e:for(;0<oe;){var O=oe-1>>>1,le=z[O];if(0<a(le,ue))z[O]=ue,z[oe]=le,oe=O;else break e}}function t(z){return z.length===0?null:z[0]}function s(z){if(z.length===0)return null;var ue=z[0],oe=z.pop();if(oe!==ue){z[0]=oe;e:for(var O=0,le=z.length,we=le>>>1;O<we;){var K=2*(O+1)-1,fe=z[K],Te=K+1,Ae=z[Te];if(0>a(fe,oe))Te<le&&0>a(Ae,fe)?(z[O]=Ae,z[Te]=oe,O=Te):(z[O]=fe,z[K]=oe,O=K);else if(Te<le&&0>a(Ae,oe))z[O]=Ae,z[Te]=oe,O=Te;else break e}}return ue}function a(z,ue){var oe=z.sortIndex-ue.sortIndex;return oe!==0?oe:z.id-ue.id}if(typeof performance=="object"&&typeof performance.now=="function"){var c=performance;n.unstable_now=function(){return c.now()}}else{var u=Date,d=u.now();n.unstable_now=function(){return u.now()-d}}var f=[],p=[],g=1,v=null,x=3,y=!1,w=!1,E=!1,_=typeof setTimeout=="function"?setTimeout:null,M=typeof clearTimeout=="function"?clearTimeout:null,L=typeof setImmediate<"u"?setImmediate:null;typeof navigator<"u"&&navigator.scheduling!==void 0&&navigator.scheduling.isInputPending!==void 0&&navigator.scheduling.isInputPending.bind(navigator.scheduling);function A(z){for(var ue=t(p);ue!==null;){if(ue.callback===null)s(p);else if(ue.startTime<=z)s(p),ue.sortIndex=ue.expirationTime,e(f,ue);else break;ue=t(p)}}function R(z){if(E=!1,A(z),!w)if(t(f)!==null)w=!0,V(k);else{var ue=t(p);ue!==null&&de(R,ue.startTime-z)}}function k(z,ue){w=!1,E&&(E=!1,M($),$=-1),y=!0;var oe=x;try{for(A(ue),v=t(f);v!==null&&(!(v.expirationTime>ue)||z&&!P());){var O=v.callback;if(typeof O=="function"){v.callback=null,x=v.priorityLevel;var le=O(v.expirationTime<=ue);ue=n.unstable_now(),typeof le=="function"?v.callback=le:v===t(f)&&s(f),A(ue)}else s(f);v=t(f)}if(v!==null)var we=!0;else{var K=t(p);K!==null&&de(R,K.startTime-ue),we=!1}return we}finally{v=null,x=oe,y=!1}}var D=!1,U=null,$=-1,te=5,T=-1;function P(){return!(n.unstable_now()-T<te)}function re(){if(U!==null){var z=n.unstable_now();T=z;var ue=!0;try{ue=U(!0,z)}finally{ue?J():(D=!1,U=null)}}else D=!1}var J;if(typeof L=="function")J=function(){L(re)};else if(typeof MessageChannel<"u"){var ae=new MessageChannel,ve=ae.port2;ae.port1.onmessage=re,J=function(){ve.postMessage(null)}}else J=function(){_(re,0)};function V(z){U=z,D||(D=!0,J())}function de(z,ue){$=_(function(){z(n.unstable_now())},ue)}n.unstable_IdlePriority=5,n.unstable_ImmediatePriority=1,n.unstable_LowPriority=4,n.unstable_NormalPriority=3,n.unstable_Profiling=null,n.unstable_UserBlockingPriority=2,n.unstable_cancelCallback=function(z){z.callback=null},n.unstable_continueExecution=function(){w||y||(w=!0,V(k))},n.unstable_forceFrameRate=function(z){0>z||125<z?console.error("forceFrameRate takes a positive int between 0 and 125, forcing frame rates higher than 125 fps is not supported"):te=0<z?Math.floor(1e3/z):5},n.unstable_getCurrentPriorityLevel=function(){return x},n.unstable_getFirstCallbackNode=function(){return t(f)},n.unstable_next=function(z){switch(x){case 1:case 2:case 3:var ue=3;break;default:ue=x}var oe=x;x=ue;try{return z()}finally{x=oe}},n.unstable_pauseExecution=function(){},n.unstable_requestPaint=function(){},n.unstable_runWithPriority=function(z,ue){switch(z){case 1:case 2:case 3:case 4:case 5:break;default:z=3}var oe=x;x=z;try{return ue()}finally{x=oe}},n.unstable_scheduleCallback=function(z,ue,oe){var O=n.unstable_now();switch(typeof oe=="object"&&oe!==null?(oe=oe.delay,oe=typeof oe=="number"&&0<oe?O+oe:O):oe=O,z){case 1:var le=-1;break;case 2:le=250;break;case 5:le=1073741823;break;case 4:le=1e4;break;default:le=5e3}return le=oe+le,z={id:g++,callback:ue,priorityLevel:z,startTime:oe,expirationTime:le,sortIndex:-1},oe>O?(z.sortIndex=oe,e(p,z),t(f)===null&&z===t(p)&&(E?(M($),$=-1):E=!0,de(R,oe-O))):(z.sortIndex=le,e(f,z),w||y||(w=!0,V(k))),z},n.unstable_shouldYield=P,n.unstable_wrapCallback=function(z){var ue=x;return function(){var oe=x;x=ue;try{return z.apply(this,arguments)}finally{x=oe}}}})(Mh)),Mh}var xg;function yy(){return xg||(xg=1,Sh.exports=xy()),Sh.exports}/**
 * @license React
 * react-dom.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var yg;function Sy(){if(yg)return Gn;yg=1;var n=hp(),e=yy();function t(i){for(var r="https://reactjs.org/docs/error-decoder.html?invariant="+i,o=1;o<arguments.length;o++)r+="&args[]="+encodeURIComponent(arguments[o]);return"Minified React error #"+i+"; visit "+r+" for the full message or use the non-minified dev environment for full errors and additional helpful warnings."}var s=new Set,a={};function c(i,r){u(i,r),u(i+"Capture",r)}function u(i,r){for(a[i]=r,i=0;i<r.length;i++)s.add(r[i])}var d=!(typeof window>"u"||typeof window.document>"u"||typeof window.document.createElement>"u"),f=Object.prototype.hasOwnProperty,p=/^[:A-Z_a-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD][:A-Z_a-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD\-.0-9\u00B7\u0300-\u036F\u203F-\u2040]*$/,g={},v={};function x(i){return f.call(v,i)?!0:f.call(g,i)?!1:p.test(i)?v[i]=!0:(g[i]=!0,!1)}function y(i,r,o,h){if(o!==null&&o.type===0)return!1;switch(typeof r){case"function":case"symbol":return!0;case"boolean":return h?!1:o!==null?!o.acceptsBooleans:(i=i.toLowerCase().slice(0,5),i!=="data-"&&i!=="aria-");default:return!1}}function w(i,r,o,h){if(r===null||typeof r>"u"||y(i,r,o,h))return!0;if(h)return!1;if(o!==null)switch(o.type){case 3:return!r;case 4:return r===!1;case 5:return isNaN(r);case 6:return isNaN(r)||1>r}return!1}function E(i,r,o,h,m,S,b){this.acceptsBooleans=r===2||r===3||r===4,this.attributeName=h,this.attributeNamespace=m,this.mustUseProperty=o,this.propertyName=i,this.type=r,this.sanitizeURL=S,this.removeEmptyString=b}var _={};"children dangerouslySetInnerHTML defaultValue defaultChecked innerHTML suppressContentEditableWarning suppressHydrationWarning style".split(" ").forEach(function(i){_[i]=new E(i,0,!1,i,null,!1,!1)}),[["acceptCharset","accept-charset"],["className","class"],["htmlFor","for"],["httpEquiv","http-equiv"]].forEach(function(i){var r=i[0];_[r]=new E(r,1,!1,i[1],null,!1,!1)}),["contentEditable","draggable","spellCheck","value"].forEach(function(i){_[i]=new E(i,2,!1,i.toLowerCase(),null,!1,!1)}),["autoReverse","externalResourcesRequired","focusable","preserveAlpha"].forEach(function(i){_[i]=new E(i,2,!1,i,null,!1,!1)}),"allowFullScreen async autoFocus autoPlay controls default defer disabled disablePictureInPicture disableRemotePlayback formNoValidate hidden loop noModule noValidate open playsInline readOnly required reversed scoped seamless itemScope".split(" ").forEach(function(i){_[i]=new E(i,3,!1,i.toLowerCase(),null,!1,!1)}),["checked","multiple","muted","selected"].forEach(function(i){_[i]=new E(i,3,!0,i,null,!1,!1)}),["capture","download"].forEach(function(i){_[i]=new E(i,4,!1,i,null,!1,!1)}),["cols","rows","size","span"].forEach(function(i){_[i]=new E(i,6,!1,i,null,!1,!1)}),["rowSpan","start"].forEach(function(i){_[i]=new E(i,5,!1,i.toLowerCase(),null,!1,!1)});var M=/[\-:]([a-z])/g;function L(i){return i[1].toUpperCase()}"accent-height alignment-baseline arabic-form baseline-shift cap-height clip-path clip-rule color-interpolation color-interpolation-filters color-profile color-rendering dominant-baseline enable-background fill-opacity fill-rule flood-color flood-opacity font-family font-size font-size-adjust font-stretch font-style font-variant font-weight glyph-name glyph-orientation-horizontal glyph-orientation-vertical horiz-adv-x horiz-origin-x image-rendering letter-spacing lighting-color marker-end marker-mid marker-start overline-position overline-thickness paint-order panose-1 pointer-events rendering-intent shape-rendering stop-color stop-opacity strikethrough-position strikethrough-thickness stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin stroke-miterlimit stroke-opacity stroke-width text-anchor text-decoration text-rendering underline-position underline-thickness unicode-bidi unicode-range units-per-em v-alphabetic v-hanging v-ideographic v-mathematical vector-effect vert-adv-y vert-origin-x vert-origin-y word-spacing writing-mode xmlns:xlink x-height".split(" ").forEach(function(i){var r=i.replace(M,L);_[r]=new E(r,1,!1,i,null,!1,!1)}),"xlink:actuate xlink:arcrole xlink:role xlink:show xlink:title xlink:type".split(" ").forEach(function(i){var r=i.replace(M,L);_[r]=new E(r,1,!1,i,"http://www.w3.org/1999/xlink",!1,!1)}),["xml:base","xml:lang","xml:space"].forEach(function(i){var r=i.replace(M,L);_[r]=new E(r,1,!1,i,"http://www.w3.org/XML/1998/namespace",!1,!1)}),["tabIndex","crossOrigin"].forEach(function(i){_[i]=new E(i,1,!1,i.toLowerCase(),null,!1,!1)}),_.xlinkHref=new E("xlinkHref",1,!1,"xlink:href","http://www.w3.org/1999/xlink",!0,!1),["src","href","action","formAction"].forEach(function(i){_[i]=new E(i,1,!1,i.toLowerCase(),null,!0,!0)});function A(i,r,o,h){var m=_.hasOwnProperty(r)?_[r]:null;(m!==null?m.type!==0:h||!(2<r.length)||r[0]!=="o"&&r[0]!=="O"||r[1]!=="n"&&r[1]!=="N")&&(w(r,o,m,h)&&(o=null),h||m===null?x(r)&&(o===null?i.removeAttribute(r):i.setAttribute(r,""+o)):m.mustUseProperty?i[m.propertyName]=o===null?m.type===3?!1:"":o:(r=m.attributeName,h=m.attributeNamespace,o===null?i.removeAttribute(r):(m=m.type,o=m===3||m===4&&o===!0?"":""+o,h?i.setAttributeNS(h,r,o):i.setAttribute(r,o))))}var R=n.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED,k=Symbol.for("react.element"),D=Symbol.for("react.portal"),U=Symbol.for("react.fragment"),$=Symbol.for("react.strict_mode"),te=Symbol.for("react.profiler"),T=Symbol.for("react.provider"),P=Symbol.for("react.context"),re=Symbol.for("react.forward_ref"),J=Symbol.for("react.suspense"),ae=Symbol.for("react.suspense_list"),ve=Symbol.for("react.memo"),V=Symbol.for("react.lazy"),de=Symbol.for("react.offscreen"),z=Symbol.iterator;function ue(i){return i===null||typeof i!="object"?null:(i=z&&i[z]||i["@@iterator"],typeof i=="function"?i:null)}var oe=Object.assign,O;function le(i){if(O===void 0)try{throw Error()}catch(o){var r=o.stack.trim().match(/\n( *(at )?)/);O=r&&r[1]||""}return`
`+O+i}var we=!1;function K(i,r){if(!i||we)return"";we=!0;var o=Error.prepareStackTrace;Error.prepareStackTrace=void 0;try{if(r)if(r=function(){throw Error()},Object.defineProperty(r.prototype,"props",{set:function(){throw Error()}}),typeof Reflect=="object"&&Reflect.construct){try{Reflect.construct(r,[])}catch(ie){var h=ie}Reflect.construct(i,[],r)}else{try{r.call()}catch(ie){h=ie}i.call(r.prototype)}else{try{throw Error()}catch(ie){h=ie}i()}}catch(ie){if(ie&&h&&typeof ie.stack=="string"){for(var m=ie.stack.split(`
`),S=h.stack.split(`
`),b=m.length-1,F=S.length-1;1<=b&&0<=F&&m[b]!==S[F];)F--;for(;1<=b&&0<=F;b--,F--)if(m[b]!==S[F]){if(b!==1||F!==1)do if(b--,F--,0>F||m[b]!==S[F]){var j=`
`+m[b].replace(" at new "," at ");return i.displayName&&j.includes("<anonymous>")&&(j=j.replace("<anonymous>",i.displayName)),j}while(1<=b&&0<=F);break}}}finally{we=!1,Error.prepareStackTrace=o}return(i=i?i.displayName||i.name:"")?le(i):""}function fe(i){switch(i.tag){case 5:return le(i.type);case 16:return le("Lazy");case 13:return le("Suspense");case 19:return le("SuspenseList");case 0:case 2:case 15:return i=K(i.type,!1),i;case 11:return i=K(i.type.render,!1),i;case 1:return i=K(i.type,!0),i;default:return""}}function Te(i){if(i==null)return null;if(typeof i=="function")return i.displayName||i.name||null;if(typeof i=="string")return i;switch(i){case U:return"Fragment";case D:return"Portal";case te:return"Profiler";case $:return"StrictMode";case J:return"Suspense";case ae:return"SuspenseList"}if(typeof i=="object")switch(i.$$typeof){case P:return(i.displayName||"Context")+".Consumer";case T:return(i._context.displayName||"Context")+".Provider";case re:var r=i.render;return i=i.displayName,i||(i=r.displayName||r.name||"",i=i!==""?"ForwardRef("+i+")":"ForwardRef"),i;case ve:return r=i.displayName||null,r!==null?r:Te(i.type)||"Memo";case V:r=i._payload,i=i._init;try{return Te(i(r))}catch{}}return null}function Ae(i){var r=i.type;switch(i.tag){case 24:return"Cache";case 9:return(r.displayName||"Context")+".Consumer";case 10:return(r._context.displayName||"Context")+".Provider";case 18:return"DehydratedFragment";case 11:return i=r.render,i=i.displayName||i.name||"",r.displayName||(i!==""?"ForwardRef("+i+")":"ForwardRef");case 7:return"Fragment";case 5:return r;case 4:return"Portal";case 3:return"Root";case 6:return"Text";case 16:return Te(r);case 8:return r===$?"StrictMode":"Mode";case 22:return"Offscreen";case 12:return"Profiler";case 21:return"Scope";case 13:return"Suspense";case 19:return"SuspenseList";case 25:return"TracingMarker";case 1:case 0:case 17:case 2:case 14:case 15:if(typeof r=="function")return r.displayName||r.name||null;if(typeof r=="string")return r}return null}function Ie(i){switch(typeof i){case"boolean":case"number":case"string":case"undefined":return i;case"object":return i;default:return""}}function Ue(i){var r=i.type;return(i=i.nodeName)&&i.toLowerCase()==="input"&&(r==="checkbox"||r==="radio")}function rt(i){var r=Ue(i)?"checked":"value",o=Object.getOwnPropertyDescriptor(i.constructor.prototype,r),h=""+i[r];if(!i.hasOwnProperty(r)&&typeof o<"u"&&typeof o.get=="function"&&typeof o.set=="function"){var m=o.get,S=o.set;return Object.defineProperty(i,r,{configurable:!0,get:function(){return m.call(this)},set:function(b){h=""+b,S.call(this,b)}}),Object.defineProperty(i,r,{enumerable:o.enumerable}),{getValue:function(){return h},setValue:function(b){h=""+b},stopTracking:function(){i._valueTracker=null,delete i[r]}}}}function yt(i){i._valueTracker||(i._valueTracker=rt(i))}function pt(i){if(!i)return!1;var r=i._valueTracker;if(!r)return!0;var o=r.getValue(),h="";return i&&(h=Ue(i)?i.checked?"true":"false":i.value),i=h,i!==o?(r.setValue(i),!0):!1}function B(i){if(i=i||(typeof document<"u"?document:void 0),typeof i>"u")return null;try{return i.activeElement||i.body}catch{return i.body}}function _n(i,r){var o=r.checked;return oe({},r,{defaultChecked:void 0,defaultValue:void 0,value:void 0,checked:o??i._wrapperState.initialChecked})}function ft(i,r){var o=r.defaultValue==null?"":r.defaultValue,h=r.checked!=null?r.checked:r.defaultChecked;o=Ie(r.value!=null?r.value:o),i._wrapperState={initialChecked:h,initialValue:o,controlled:r.type==="checkbox"||r.type==="radio"?r.checked!=null:r.value!=null}}function _t(i,r){r=r.checked,r!=null&&A(i,"checked",r,!1)}function tt(i,r){_t(i,r);var o=Ie(r.value),h=r.type;if(o!=null)h==="number"?(o===0&&i.value===""||i.value!=o)&&(i.value=""+o):i.value!==""+o&&(i.value=""+o);else if(h==="submit"||h==="reset"){i.removeAttribute("value");return}r.hasOwnProperty("value")?it(i,r.type,o):r.hasOwnProperty("defaultValue")&&it(i,r.type,Ie(r.defaultValue)),r.checked==null&&r.defaultChecked!=null&&(i.defaultChecked=!!r.defaultChecked)}function Lt(i,r,o){if(r.hasOwnProperty("value")||r.hasOwnProperty("defaultValue")){var h=r.type;if(!(h!=="submit"&&h!=="reset"||r.value!==void 0&&r.value!==null))return;r=""+i._wrapperState.initialValue,o||r===i.value||(i.value=r),i.defaultValue=r}o=i.name,o!==""&&(i.name=""),i.defaultChecked=!!i._wrapperState.initialChecked,o!==""&&(i.name=o)}function it(i,r,o){(r!=="number"||B(i.ownerDocument)!==i)&&(o==null?i.defaultValue=""+i._wrapperState.initialValue:i.defaultValue!==""+o&&(i.defaultValue=""+o))}var I=Array.isArray;function C(i,r,o,h){if(i=i.options,r){r={};for(var m=0;m<o.length;m++)r["$"+o[m]]=!0;for(o=0;o<i.length;o++)m=r.hasOwnProperty("$"+i[o].value),i[o].selected!==m&&(i[o].selected=m),m&&h&&(i[o].defaultSelected=!0)}else{for(o=""+Ie(o),r=null,m=0;m<i.length;m++){if(i[m].value===o){i[m].selected=!0,h&&(i[m].defaultSelected=!0);return}r!==null||i[m].disabled||(r=i[m])}r!==null&&(r.selected=!0)}}function Q(i,r){if(r.dangerouslySetInnerHTML!=null)throw Error(t(91));return oe({},r,{value:void 0,defaultValue:void 0,children:""+i._wrapperState.initialValue})}function me(i,r){var o=r.value;if(o==null){if(o=r.children,r=r.defaultValue,o!=null){if(r!=null)throw Error(t(92));if(I(o)){if(1<o.length)throw Error(t(93));o=o[0]}r=o}r==null&&(r=""),o=r}i._wrapperState={initialValue:Ie(o)}}function Se(i,r){var o=Ie(r.value),h=Ie(r.defaultValue);o!=null&&(o=""+o,o!==i.value&&(i.value=o),r.defaultValue==null&&i.defaultValue!==o&&(i.defaultValue=o)),h!=null&&(i.defaultValue=""+h)}function pe(i){var r=i.textContent;r===i._wrapperState.initialValue&&r!==""&&r!==null&&(i.value=r)}function Ze(i){switch(i){case"svg":return"http://www.w3.org/2000/svg";case"math":return"http://www.w3.org/1998/Math/MathML";default:return"http://www.w3.org/1999/xhtml"}}function ke(i,r){return i==null||i==="http://www.w3.org/1999/xhtml"?Ze(r):i==="http://www.w3.org/2000/svg"&&r==="foreignObject"?"http://www.w3.org/1999/xhtml":i}var Be,vt=(function(i){return typeof MSApp<"u"&&MSApp.execUnsafeLocalFunction?function(r,o,h,m){MSApp.execUnsafeLocalFunction(function(){return i(r,o,h,m)})}:i})(function(i,r){if(i.namespaceURI!=="http://www.w3.org/2000/svg"||"innerHTML"in i)i.innerHTML=r;else{for(Be=Be||document.createElement("div"),Be.innerHTML="<svg>"+r.valueOf().toString()+"</svg>",r=Be.firstChild;i.firstChild;)i.removeChild(i.firstChild);for(;r.firstChild;)i.appendChild(r.firstChild)}});function Ce(i,r){if(r){var o=i.firstChild;if(o&&o===i.lastChild&&o.nodeType===3){o.nodeValue=r;return}}i.textContent=r}var He={animationIterationCount:!0,aspectRatio:!0,borderImageOutset:!0,borderImageSlice:!0,borderImageWidth:!0,boxFlex:!0,boxFlexGroup:!0,boxOrdinalGroup:!0,columnCount:!0,columns:!0,flex:!0,flexGrow:!0,flexPositive:!0,flexShrink:!0,flexNegative:!0,flexOrder:!0,gridArea:!0,gridRow:!0,gridRowEnd:!0,gridRowSpan:!0,gridRowStart:!0,gridColumn:!0,gridColumnEnd:!0,gridColumnSpan:!0,gridColumnStart:!0,fontWeight:!0,lineClamp:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,tabSize:!0,widows:!0,zIndex:!0,zoom:!0,fillOpacity:!0,floodOpacity:!0,stopOpacity:!0,strokeDasharray:!0,strokeDashoffset:!0,strokeMiterlimit:!0,strokeOpacity:!0,strokeWidth:!0},at=["Webkit","ms","Moz","O"];Object.keys(He).forEach(function(i){at.forEach(function(r){r=r+i.charAt(0).toUpperCase()+i.substring(1),He[r]=He[i]})});function st(i,r,o){return r==null||typeof r=="boolean"||r===""?"":o||typeof r!="number"||r===0||He.hasOwnProperty(i)&&He[i]?(""+r).trim():r+"px"}function Ge(i,r){i=i.style;for(var o in r)if(r.hasOwnProperty(o)){var h=o.indexOf("--")===0,m=st(o,r[o],h);o==="float"&&(o="cssFloat"),h?i.setProperty(o,m):i[o]=m}}var mt=oe({menuitem:!0},{area:!0,base:!0,br:!0,col:!0,embed:!0,hr:!0,img:!0,input:!0,keygen:!0,link:!0,meta:!0,param:!0,source:!0,track:!0,wbr:!0});function lt(i,r){if(r){if(mt[i]&&(r.children!=null||r.dangerouslySetInnerHTML!=null))throw Error(t(137,i));if(r.dangerouslySetInnerHTML!=null){if(r.children!=null)throw Error(t(60));if(typeof r.dangerouslySetInnerHTML!="object"||!("__html"in r.dangerouslySetInnerHTML))throw Error(t(61))}if(r.style!=null&&typeof r.style!="object")throw Error(t(62))}}function Ct(i,r){if(i.indexOf("-")===-1)return typeof r.is=="string";switch(i){case"annotation-xml":case"color-profile":case"font-face":case"font-face-src":case"font-face-uri":case"font-face-format":case"font-face-name":case"missing-glyph":return!1;default:return!0}}var G=null;function Fe(i){return i=i.target||i.srcElement||window,i.correspondingUseElement&&(i=i.correspondingUseElement),i.nodeType===3?i.parentNode:i}var ce=null,_e=null,Le=null;function je(i){if(i=Ao(i)){if(typeof ce!="function")throw Error(t(280));var r=i.stateNode;r&&(r=Ol(r),ce(i.stateNode,i.type,r))}}function gt(i){_e?Le?Le.push(i):Le=[i]:_e=i}function $t(){if(_e){var i=_e,r=Le;if(Le=_e=null,je(i),r)for(i=0;i<r.length;i++)je(r[i])}}function vn(i,r){return i(r)}function xt(){}var dn=!1;function ci(i,r,o){if(dn)return i(r,o);dn=!0;try{return vn(i,r,o)}finally{dn=!1,(_e!==null||Le!==null)&&(xt(),$t())}}function Cs(i,r){var o=i.stateNode;if(o===null)return null;var h=Ol(o);if(h===null)return null;o=h[r];e:switch(r){case"onClick":case"onClickCapture":case"onDoubleClick":case"onDoubleClickCapture":case"onMouseDown":case"onMouseDownCapture":case"onMouseMove":case"onMouseMoveCapture":case"onMouseUp":case"onMouseUpCapture":case"onMouseEnter":(h=!h.disabled)||(i=i.type,h=!(i==="button"||i==="input"||i==="select"||i==="textarea")),i=!h;break e;default:i=!1}if(i)return null;if(o&&typeof o!="function")throw Error(t(231,r,typeof o));return o}var Zr=!1;if(d)try{var Zn={};Object.defineProperty(Zn,"passive",{get:function(){Zr=!0}}),window.addEventListener("test",Zn,Zn),window.removeEventListener("test",Zn,Zn)}catch{Zr=!1}function oo(i,r,o,h,m,S,b,F,j){var ie=Array.prototype.slice.call(arguments,3);try{r.apply(o,ie)}catch(ye){this.onError(ye)}}var Ns=!1,fr=null,es=!1,Qr=null,Jr={onError:function(i){Ns=!0,fr=i}};function xl(i,r,o,h,m,S,b,F,j){Ns=!1,fr=null,oo.apply(Jr,arguments)}function yl(i,r,o,h,m,S,b,F,j){if(xl.apply(this,arguments),Ns){if(Ns){var ie=fr;Ns=!1,fr=null}else throw Error(t(198));es||(es=!0,Qr=ie)}}function ts(i){var r=i,o=i;if(i.alternate)for(;r.return;)r=r.return;else{i=r;do r=i,(r.flags&4098)!==0&&(o=r.return),i=r.return;while(i)}return r.tag===3?o:null}function Sl(i){if(i.tag===13){var r=i.memoizedState;if(r===null&&(i=i.alternate,i!==null&&(r=i.memoizedState)),r!==null)return r.dehydrated}return null}function Ml(i){if(ts(i)!==i)throw Error(t(188))}function N(i){var r=i.alternate;if(!r){if(r=ts(i),r===null)throw Error(t(188));return r!==i?null:i}for(var o=i,h=r;;){var m=o.return;if(m===null)break;var S=m.alternate;if(S===null){if(h=m.return,h!==null){o=h;continue}break}if(m.child===S.child){for(S=m.child;S;){if(S===o)return Ml(m),i;if(S===h)return Ml(m),r;S=S.sibling}throw Error(t(188))}if(o.return!==h.return)o=m,h=S;else{for(var b=!1,F=m.child;F;){if(F===o){b=!0,o=m,h=S;break}if(F===h){b=!0,h=m,o=S;break}F=F.sibling}if(!b){for(F=S.child;F;){if(F===o){b=!0,o=S,h=m;break}if(F===h){b=!0,h=S,o=m;break}F=F.sibling}if(!b)throw Error(t(189))}}if(o.alternate!==h)throw Error(t(190))}if(o.tag!==3)throw Error(t(188));return o.stateNode.current===o?i:r}function W(i){return i=N(i),i!==null?ee(i):null}function ee(i){if(i.tag===5||i.tag===6)return i;for(i=i.child;i!==null;){var r=ee(i);if(r!==null)return r;i=i.sibling}return null}var ne=e.unstable_scheduleCallback,X=e.unstable_cancelCallback,Re=e.unstable_shouldYield,Oe=e.unstable_requestPaint,Pe=e.unstable_now,qe=e.unstable_getCurrentPriorityLevel,et=e.unstable_ImmediatePriority,nt=e.unstable_UserBlockingPriority,Ye=e.unstable_NormalPriority,bt=e.unstable_LowPriority,Dt=e.unstable_IdlePriority,It=null,Vt=null;function Mt(i){if(Vt&&typeof Vt.onCommitFiberRoot=="function")try{Vt.onCommitFiberRoot(It,i,void 0,(i.current.flags&128)===128)}catch{}}var Ve=Math.clz32?Math.clz32:Qn,sn=Math.log,Et=Math.LN2;function Qn(i){return i>>>=0,i===0?32:31-(sn(i)/Et|0)|0}var wi=64,hn=4194304;function ns(i){switch(i&-i){case 1:return 1;case 2:return 2;case 4:return 4;case 8:return 8;case 16:return 16;case 32:return 32;case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:return i&4194240;case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:return i&130023424;case 134217728:return 134217728;case 268435456:return 268435456;case 536870912:return 536870912;case 1073741824:return 1073741824;default:return i}}function Ut(i,r){var o=i.pendingLanes;if(o===0)return 0;var h=0,m=i.suspendedLanes,S=i.pingedLanes,b=o&268435455;if(b!==0){var F=b&~m;F!==0?h=ns(F):(S&=b,S!==0&&(h=ns(S)))}else b=o&~m,b!==0?h=ns(b):S!==0&&(h=ns(S));if(h===0)return 0;if(r!==0&&r!==h&&(r&m)===0&&(m=h&-h,S=r&-r,m>=S||m===16&&(S&4194240)!==0))return r;if((h&4)!==0&&(h|=o&16),r=i.entangledLanes,r!==0)for(i=i.entanglements,r&=h;0<r;)o=31-Ve(r),m=1<<o,h|=i[o],r&=~m;return h}function Bi(i,r){switch(i){case 1:case 2:case 4:return r+250;case 8:case 16:case 32:case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:return r+5e3;case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:return-1;case 134217728:case 268435456:case 536870912:case 1073741824:return-1;default:return-1}}function lo(i,r){for(var o=i.suspendedLanes,h=i.pingedLanes,m=i.expirationTimes,S=i.pendingLanes;0<S;){var b=31-Ve(S),F=1<<b,j=m[b];j===-1?((F&o)===0||(F&h)!==0)&&(m[b]=Bi(F,r)):j<=r&&(i.expiredLanes|=F),S&=~F}}function wn(i){return i=i.pendingLanes&-1073741825,i!==0?i:i&1073741824?1073741824:0}function ea(){var i=wi;return wi<<=1,(wi&4194240)===0&&(wi=64),i}function co(i){for(var r=[],o=0;31>o;o++)r.push(i);return r}function Rs(i,r,o){i.pendingLanes|=r,r!==536870912&&(i.suspendedLanes=0,i.pingedLanes=0),i=i.eventTimes,r=31-Ve(r),i[r]=o}function Dx(i,r){var o=i.pendingLanes&~r;i.pendingLanes=r,i.suspendedLanes=0,i.pingedLanes=0,i.expiredLanes&=r,i.mutableReadLanes&=r,i.entangledLanes&=r,r=i.entanglements;var h=i.eventTimes;for(i=i.expirationTimes;0<o;){var m=31-Ve(o),S=1<<m;r[m]=0,h[m]=-1,i[m]=-1,o&=~S}}function Bu(i,r){var o=i.entangledLanes|=r;for(i=i.entanglements;o;){var h=31-Ve(o),m=1<<h;m&r|i[h]&r&&(i[h]|=r),o&=~m}}var kt=0;function Wp(i){return i&=-i,1<i?4<i?(i&268435455)!==0?16:536870912:4:1}var $p,Hu,Xp,qp,Yp,Vu=!1,El=[],Ps=null,ks=null,Ls=null,uo=new Map,ho=new Map,Ds=[],Ix="mousedown mouseup touchcancel touchend touchstart auxclick dblclick pointercancel pointerdown pointerup dragend dragstart drop compositionend compositionstart keydown keypress keyup input textInput copy cut paste click change contextmenu reset submit".split(" ");function Kp(i,r){switch(i){case"focusin":case"focusout":Ps=null;break;case"dragenter":case"dragleave":ks=null;break;case"mouseover":case"mouseout":Ls=null;break;case"pointerover":case"pointerout":uo.delete(r.pointerId);break;case"gotpointercapture":case"lostpointercapture":ho.delete(r.pointerId)}}function fo(i,r,o,h,m,S){return i===null||i.nativeEvent!==S?(i={blockedOn:r,domEventName:o,eventSystemFlags:h,nativeEvent:S,targetContainers:[m]},r!==null&&(r=Ao(r),r!==null&&Hu(r)),i):(i.eventSystemFlags|=h,r=i.targetContainers,m!==null&&r.indexOf(m)===-1&&r.push(m),i)}function Ux(i,r,o,h,m){switch(r){case"focusin":return Ps=fo(Ps,i,r,o,h,m),!0;case"dragenter":return ks=fo(ks,i,r,o,h,m),!0;case"mouseover":return Ls=fo(Ls,i,r,o,h,m),!0;case"pointerover":var S=m.pointerId;return uo.set(S,fo(uo.get(S)||null,i,r,o,h,m)),!0;case"gotpointercapture":return S=m.pointerId,ho.set(S,fo(ho.get(S)||null,i,r,o,h,m)),!0}return!1}function Zp(i){var r=pr(i.target);if(r!==null){var o=ts(r);if(o!==null){if(r=o.tag,r===13){if(r=Sl(o),r!==null){i.blockedOn=r,Yp(i.priority,function(){Xp(o)});return}}else if(r===3&&o.stateNode.current.memoizedState.isDehydrated){i.blockedOn=o.tag===3?o.stateNode.containerInfo:null;return}}}i.blockedOn=null}function wl(i){if(i.blockedOn!==null)return!1;for(var r=i.targetContainers;0<r.length;){var o=Wu(i.domEventName,i.eventSystemFlags,r[0],i.nativeEvent);if(o===null){o=i.nativeEvent;var h=new o.constructor(o.type,o);G=h,o.target.dispatchEvent(h),G=null}else return r=Ao(o),r!==null&&Hu(r),i.blockedOn=o,!1;r.shift()}return!0}function Qp(i,r,o){wl(i)&&o.delete(r)}function Fx(){Vu=!1,Ps!==null&&wl(Ps)&&(Ps=null),ks!==null&&wl(ks)&&(ks=null),Ls!==null&&wl(Ls)&&(Ls=null),uo.forEach(Qp),ho.forEach(Qp)}function po(i,r){i.blockedOn===r&&(i.blockedOn=null,Vu||(Vu=!0,e.unstable_scheduleCallback(e.unstable_NormalPriority,Fx)))}function mo(i){function r(m){return po(m,i)}if(0<El.length){po(El[0],i);for(var o=1;o<El.length;o++){var h=El[o];h.blockedOn===i&&(h.blockedOn=null)}}for(Ps!==null&&po(Ps,i),ks!==null&&po(ks,i),Ls!==null&&po(Ls,i),uo.forEach(r),ho.forEach(r),o=0;o<Ds.length;o++)h=Ds[o],h.blockedOn===i&&(h.blockedOn=null);for(;0<Ds.length&&(o=Ds[0],o.blockedOn===null);)Zp(o),o.blockedOn===null&&Ds.shift()}var ta=R.ReactCurrentBatchConfig,Tl=!0;function Ox(i,r,o,h){var m=kt,S=ta.transition;ta.transition=null;try{kt=1,Gu(i,r,o,h)}finally{kt=m,ta.transition=S}}function jx(i,r,o,h){var m=kt,S=ta.transition;ta.transition=null;try{kt=4,Gu(i,r,o,h)}finally{kt=m,ta.transition=S}}function Gu(i,r,o,h){if(Tl){var m=Wu(i,r,o,h);if(m===null)ld(i,r,h,bl,o),Kp(i,h);else if(Ux(m,i,r,o,h))h.stopPropagation();else if(Kp(i,h),r&4&&-1<Ix.indexOf(i)){for(;m!==null;){var S=Ao(m);if(S!==null&&$p(S),S=Wu(i,r,o,h),S===null&&ld(i,r,h,bl,o),S===m)break;m=S}m!==null&&h.stopPropagation()}else ld(i,r,h,null,o)}}var bl=null;function Wu(i,r,o,h){if(bl=null,i=Fe(h),i=pr(i),i!==null)if(r=ts(i),r===null)i=null;else if(o=r.tag,o===13){if(i=Sl(r),i!==null)return i;i=null}else if(o===3){if(r.stateNode.current.memoizedState.isDehydrated)return r.tag===3?r.stateNode.containerInfo:null;i=null}else r!==i&&(i=null);return bl=i,null}function Jp(i){switch(i){case"cancel":case"click":case"close":case"contextmenu":case"copy":case"cut":case"auxclick":case"dblclick":case"dragend":case"dragstart":case"drop":case"focusin":case"focusout":case"input":case"invalid":case"keydown":case"keypress":case"keyup":case"mousedown":case"mouseup":case"paste":case"pause":case"play":case"pointercancel":case"pointerdown":case"pointerup":case"ratechange":case"reset":case"resize":case"seeked":case"submit":case"touchcancel":case"touchend":case"touchstart":case"volumechange":case"change":case"selectionchange":case"textInput":case"compositionstart":case"compositionend":case"compositionupdate":case"beforeblur":case"afterblur":case"beforeinput":case"blur":case"fullscreenchange":case"focus":case"hashchange":case"popstate":case"select":case"selectstart":return 1;case"drag":case"dragenter":case"dragexit":case"dragleave":case"dragover":case"mousemove":case"mouseout":case"mouseover":case"pointermove":case"pointerout":case"pointerover":case"scroll":case"toggle":case"touchmove":case"wheel":case"mouseenter":case"mouseleave":case"pointerenter":case"pointerleave":return 4;case"message":switch(qe()){case et:return 1;case nt:return 4;case Ye:case bt:return 16;case Dt:return 536870912;default:return 16}default:return 16}}var Is=null,$u=null,Al=null;function em(){if(Al)return Al;var i,r=$u,o=r.length,h,m="value"in Is?Is.value:Is.textContent,S=m.length;for(i=0;i<o&&r[i]===m[i];i++);var b=o-i;for(h=1;h<=b&&r[o-h]===m[S-h];h++);return Al=m.slice(i,1<h?1-h:void 0)}function Cl(i){var r=i.keyCode;return"charCode"in i?(i=i.charCode,i===0&&r===13&&(i=13)):i=r,i===10&&(i=13),32<=i||i===13?i:0}function Nl(){return!0}function tm(){return!1}function Jn(i){function r(o,h,m,S,b){this._reactName=o,this._targetInst=m,this.type=h,this.nativeEvent=S,this.target=b,this.currentTarget=null;for(var F in i)i.hasOwnProperty(F)&&(o=i[F],this[F]=o?o(S):S[F]);return this.isDefaultPrevented=(S.defaultPrevented!=null?S.defaultPrevented:S.returnValue===!1)?Nl:tm,this.isPropagationStopped=tm,this}return oe(r.prototype,{preventDefault:function(){this.defaultPrevented=!0;var o=this.nativeEvent;o&&(o.preventDefault?o.preventDefault():typeof o.returnValue!="unknown"&&(o.returnValue=!1),this.isDefaultPrevented=Nl)},stopPropagation:function(){var o=this.nativeEvent;o&&(o.stopPropagation?o.stopPropagation():typeof o.cancelBubble!="unknown"&&(o.cancelBubble=!0),this.isPropagationStopped=Nl)},persist:function(){},isPersistent:Nl}),r}var na={eventPhase:0,bubbles:0,cancelable:0,timeStamp:function(i){return i.timeStamp||Date.now()},defaultPrevented:0,isTrusted:0},Xu=Jn(na),go=oe({},na,{view:0,detail:0}),zx=Jn(go),qu,Yu,_o,Rl=oe({},go,{screenX:0,screenY:0,clientX:0,clientY:0,pageX:0,pageY:0,ctrlKey:0,shiftKey:0,altKey:0,metaKey:0,getModifierState:Zu,button:0,buttons:0,relatedTarget:function(i){return i.relatedTarget===void 0?i.fromElement===i.srcElement?i.toElement:i.fromElement:i.relatedTarget},movementX:function(i){return"movementX"in i?i.movementX:(i!==_o&&(_o&&i.type==="mousemove"?(qu=i.screenX-_o.screenX,Yu=i.screenY-_o.screenY):Yu=qu=0,_o=i),qu)},movementY:function(i){return"movementY"in i?i.movementY:Yu}}),nm=Jn(Rl),Bx=oe({},Rl,{dataTransfer:0}),Hx=Jn(Bx),Vx=oe({},go,{relatedTarget:0}),Ku=Jn(Vx),Gx=oe({},na,{animationName:0,elapsedTime:0,pseudoElement:0}),Wx=Jn(Gx),$x=oe({},na,{clipboardData:function(i){return"clipboardData"in i?i.clipboardData:window.clipboardData}}),Xx=Jn($x),qx=oe({},na,{data:0}),im=Jn(qx),Yx={Esc:"Escape",Spacebar:" ",Left:"ArrowLeft",Up:"ArrowUp",Right:"ArrowRight",Down:"ArrowDown",Del:"Delete",Win:"OS",Menu:"ContextMenu",Apps:"ContextMenu",Scroll:"ScrollLock",MozPrintableKey:"Unidentified"},Kx={8:"Backspace",9:"Tab",12:"Clear",13:"Enter",16:"Shift",17:"Control",18:"Alt",19:"Pause",20:"CapsLock",27:"Escape",32:" ",33:"PageUp",34:"PageDown",35:"End",36:"Home",37:"ArrowLeft",38:"ArrowUp",39:"ArrowRight",40:"ArrowDown",45:"Insert",46:"Delete",112:"F1",113:"F2",114:"F3",115:"F4",116:"F5",117:"F6",118:"F7",119:"F8",120:"F9",121:"F10",122:"F11",123:"F12",144:"NumLock",145:"ScrollLock",224:"Meta"},Zx={Alt:"altKey",Control:"ctrlKey",Meta:"metaKey",Shift:"shiftKey"};function Qx(i){var r=this.nativeEvent;return r.getModifierState?r.getModifierState(i):(i=Zx[i])?!!r[i]:!1}function Zu(){return Qx}var Jx=oe({},go,{key:function(i){if(i.key){var r=Yx[i.key]||i.key;if(r!=="Unidentified")return r}return i.type==="keypress"?(i=Cl(i),i===13?"Enter":String.fromCharCode(i)):i.type==="keydown"||i.type==="keyup"?Kx[i.keyCode]||"Unidentified":""},code:0,location:0,ctrlKey:0,shiftKey:0,altKey:0,metaKey:0,repeat:0,locale:0,getModifierState:Zu,charCode:function(i){return i.type==="keypress"?Cl(i):0},keyCode:function(i){return i.type==="keydown"||i.type==="keyup"?i.keyCode:0},which:function(i){return i.type==="keypress"?Cl(i):i.type==="keydown"||i.type==="keyup"?i.keyCode:0}}),e1=Jn(Jx),t1=oe({},Rl,{pointerId:0,width:0,height:0,pressure:0,tangentialPressure:0,tiltX:0,tiltY:0,twist:0,pointerType:0,isPrimary:0}),sm=Jn(t1),n1=oe({},go,{touches:0,targetTouches:0,changedTouches:0,altKey:0,metaKey:0,ctrlKey:0,shiftKey:0,getModifierState:Zu}),i1=Jn(n1),s1=oe({},na,{propertyName:0,elapsedTime:0,pseudoElement:0}),r1=Jn(s1),a1=oe({},Rl,{deltaX:function(i){return"deltaX"in i?i.deltaX:"wheelDeltaX"in i?-i.wheelDeltaX:0},deltaY:function(i){return"deltaY"in i?i.deltaY:"wheelDeltaY"in i?-i.wheelDeltaY:"wheelDelta"in i?-i.wheelDelta:0},deltaZ:0,deltaMode:0}),o1=Jn(a1),l1=[9,13,27,32],Qu=d&&"CompositionEvent"in window,vo=null;d&&"documentMode"in document&&(vo=document.documentMode);var c1=d&&"TextEvent"in window&&!vo,rm=d&&(!Qu||vo&&8<vo&&11>=vo),am=" ",om=!1;function lm(i,r){switch(i){case"keyup":return l1.indexOf(r.keyCode)!==-1;case"keydown":return r.keyCode!==229;case"keypress":case"mousedown":case"focusout":return!0;default:return!1}}function cm(i){return i=i.detail,typeof i=="object"&&"data"in i?i.data:null}var ia=!1;function u1(i,r){switch(i){case"compositionend":return cm(r);case"keypress":return r.which!==32?null:(om=!0,am);case"textInput":return i=r.data,i===am&&om?null:i;default:return null}}function d1(i,r){if(ia)return i==="compositionend"||!Qu&&lm(i,r)?(i=em(),Al=$u=Is=null,ia=!1,i):null;switch(i){case"paste":return null;case"keypress":if(!(r.ctrlKey||r.altKey||r.metaKey)||r.ctrlKey&&r.altKey){if(r.char&&1<r.char.length)return r.char;if(r.which)return String.fromCharCode(r.which)}return null;case"compositionend":return rm&&r.locale!=="ko"?null:r.data;default:return null}}var h1={color:!0,date:!0,datetime:!0,"datetime-local":!0,email:!0,month:!0,number:!0,password:!0,range:!0,search:!0,tel:!0,text:!0,time:!0,url:!0,week:!0};function um(i){var r=i&&i.nodeName&&i.nodeName.toLowerCase();return r==="input"?!!h1[i.type]:r==="textarea"}function dm(i,r,o,h){gt(h),r=Il(r,"onChange"),0<r.length&&(o=new Xu("onChange","change",null,o,h),i.push({event:o,listeners:r}))}var xo=null,yo=null;function f1(i){Nm(i,0)}function Pl(i){var r=la(i);if(pt(r))return i}function p1(i,r){if(i==="change")return r}var hm=!1;if(d){var Ju;if(d){var ed="oninput"in document;if(!ed){var fm=document.createElement("div");fm.setAttribute("oninput","return;"),ed=typeof fm.oninput=="function"}Ju=ed}else Ju=!1;hm=Ju&&(!document.documentMode||9<document.documentMode)}function pm(){xo&&(xo.detachEvent("onpropertychange",mm),yo=xo=null)}function mm(i){if(i.propertyName==="value"&&Pl(yo)){var r=[];dm(r,yo,i,Fe(i)),ci(f1,r)}}function m1(i,r,o){i==="focusin"?(pm(),xo=r,yo=o,xo.attachEvent("onpropertychange",mm)):i==="focusout"&&pm()}function g1(i){if(i==="selectionchange"||i==="keyup"||i==="keydown")return Pl(yo)}function _1(i,r){if(i==="click")return Pl(r)}function v1(i,r){if(i==="input"||i==="change")return Pl(r)}function x1(i,r){return i===r&&(i!==0||1/i===1/r)||i!==i&&r!==r}var Ti=typeof Object.is=="function"?Object.is:x1;function So(i,r){if(Ti(i,r))return!0;if(typeof i!="object"||i===null||typeof r!="object"||r===null)return!1;var o=Object.keys(i),h=Object.keys(r);if(o.length!==h.length)return!1;for(h=0;h<o.length;h++){var m=o[h];if(!f.call(r,m)||!Ti(i[m],r[m]))return!1}return!0}function gm(i){for(;i&&i.firstChild;)i=i.firstChild;return i}function _m(i,r){var o=gm(i);i=0;for(var h;o;){if(o.nodeType===3){if(h=i+o.textContent.length,i<=r&&h>=r)return{node:o,offset:r-i};i=h}e:{for(;o;){if(o.nextSibling){o=o.nextSibling;break e}o=o.parentNode}o=void 0}o=gm(o)}}function vm(i,r){return i&&r?i===r?!0:i&&i.nodeType===3?!1:r&&r.nodeType===3?vm(i,r.parentNode):"contains"in i?i.contains(r):i.compareDocumentPosition?!!(i.compareDocumentPosition(r)&16):!1:!1}function xm(){for(var i=window,r=B();r instanceof i.HTMLIFrameElement;){try{var o=typeof r.contentWindow.location.href=="string"}catch{o=!1}if(o)i=r.contentWindow;else break;r=B(i.document)}return r}function td(i){var r=i&&i.nodeName&&i.nodeName.toLowerCase();return r&&(r==="input"&&(i.type==="text"||i.type==="search"||i.type==="tel"||i.type==="url"||i.type==="password")||r==="textarea"||i.contentEditable==="true")}function y1(i){var r=xm(),o=i.focusedElem,h=i.selectionRange;if(r!==o&&o&&o.ownerDocument&&vm(o.ownerDocument.documentElement,o)){if(h!==null&&td(o)){if(r=h.start,i=h.end,i===void 0&&(i=r),"selectionStart"in o)o.selectionStart=r,o.selectionEnd=Math.min(i,o.value.length);else if(i=(r=o.ownerDocument||document)&&r.defaultView||window,i.getSelection){i=i.getSelection();var m=o.textContent.length,S=Math.min(h.start,m);h=h.end===void 0?S:Math.min(h.end,m),!i.extend&&S>h&&(m=h,h=S,S=m),m=_m(o,S);var b=_m(o,h);m&&b&&(i.rangeCount!==1||i.anchorNode!==m.node||i.anchorOffset!==m.offset||i.focusNode!==b.node||i.focusOffset!==b.offset)&&(r=r.createRange(),r.setStart(m.node,m.offset),i.removeAllRanges(),S>h?(i.addRange(r),i.extend(b.node,b.offset)):(r.setEnd(b.node,b.offset),i.addRange(r)))}}for(r=[],i=o;i=i.parentNode;)i.nodeType===1&&r.push({element:i,left:i.scrollLeft,top:i.scrollTop});for(typeof o.focus=="function"&&o.focus(),o=0;o<r.length;o++)i=r[o],i.element.scrollLeft=i.left,i.element.scrollTop=i.top}}var S1=d&&"documentMode"in document&&11>=document.documentMode,sa=null,nd=null,Mo=null,id=!1;function ym(i,r,o){var h=o.window===o?o.document:o.nodeType===9?o:o.ownerDocument;id||sa==null||sa!==B(h)||(h=sa,"selectionStart"in h&&td(h)?h={start:h.selectionStart,end:h.selectionEnd}:(h=(h.ownerDocument&&h.ownerDocument.defaultView||window).getSelection(),h={anchorNode:h.anchorNode,anchorOffset:h.anchorOffset,focusNode:h.focusNode,focusOffset:h.focusOffset}),Mo&&So(Mo,h)||(Mo=h,h=Il(nd,"onSelect"),0<h.length&&(r=new Xu("onSelect","select",null,r,o),i.push({event:r,listeners:h}),r.target=sa)))}function kl(i,r){var o={};return o[i.toLowerCase()]=r.toLowerCase(),o["Webkit"+i]="webkit"+r,o["Moz"+i]="moz"+r,o}var ra={animationend:kl("Animation","AnimationEnd"),animationiteration:kl("Animation","AnimationIteration"),animationstart:kl("Animation","AnimationStart"),transitionend:kl("Transition","TransitionEnd")},sd={},Sm={};d&&(Sm=document.createElement("div").style,"AnimationEvent"in window||(delete ra.animationend.animation,delete ra.animationiteration.animation,delete ra.animationstart.animation),"TransitionEvent"in window||delete ra.transitionend.transition);function Ll(i){if(sd[i])return sd[i];if(!ra[i])return i;var r=ra[i],o;for(o in r)if(r.hasOwnProperty(o)&&o in Sm)return sd[i]=r[o];return i}var Mm=Ll("animationend"),Em=Ll("animationiteration"),wm=Ll("animationstart"),Tm=Ll("transitionend"),bm=new Map,Am="abort auxClick cancel canPlay canPlayThrough click close contextMenu copy cut drag dragEnd dragEnter dragExit dragLeave dragOver dragStart drop durationChange emptied encrypted ended error gotPointerCapture input invalid keyDown keyPress keyUp load loadedData loadedMetadata loadStart lostPointerCapture mouseDown mouseMove mouseOut mouseOver mouseUp paste pause play playing pointerCancel pointerDown pointerMove pointerOut pointerOver pointerUp progress rateChange reset resize seeked seeking stalled submit suspend timeUpdate touchCancel touchEnd touchStart volumeChange scroll toggle touchMove waiting wheel".split(" ");function Us(i,r){bm.set(i,r),c(r,[i])}for(var rd=0;rd<Am.length;rd++){var ad=Am[rd],M1=ad.toLowerCase(),E1=ad[0].toUpperCase()+ad.slice(1);Us(M1,"on"+E1)}Us(Mm,"onAnimationEnd"),Us(Em,"onAnimationIteration"),Us(wm,"onAnimationStart"),Us("dblclick","onDoubleClick"),Us("focusin","onFocus"),Us("focusout","onBlur"),Us(Tm,"onTransitionEnd"),u("onMouseEnter",["mouseout","mouseover"]),u("onMouseLeave",["mouseout","mouseover"]),u("onPointerEnter",["pointerout","pointerover"]),u("onPointerLeave",["pointerout","pointerover"]),c("onChange","change click focusin focusout input keydown keyup selectionchange".split(" ")),c("onSelect","focusout contextmenu dragend focusin keydown keyup mousedown mouseup selectionchange".split(" ")),c("onBeforeInput",["compositionend","keypress","textInput","paste"]),c("onCompositionEnd","compositionend focusout keydown keypress keyup mousedown".split(" ")),c("onCompositionStart","compositionstart focusout keydown keypress keyup mousedown".split(" ")),c("onCompositionUpdate","compositionupdate focusout keydown keypress keyup mousedown".split(" "));var Eo="abort canplay canplaythrough durationchange emptied encrypted ended error loadeddata loadedmetadata loadstart pause play playing progress ratechange resize seeked seeking stalled suspend timeupdate volumechange waiting".split(" "),w1=new Set("cancel close invalid load scroll toggle".split(" ").concat(Eo));function Cm(i,r,o){var h=i.type||"unknown-event";i.currentTarget=o,yl(h,r,void 0,i),i.currentTarget=null}function Nm(i,r){r=(r&4)!==0;for(var o=0;o<i.length;o++){var h=i[o],m=h.event;h=h.listeners;e:{var S=void 0;if(r)for(var b=h.length-1;0<=b;b--){var F=h[b],j=F.instance,ie=F.currentTarget;if(F=F.listener,j!==S&&m.isPropagationStopped())break e;Cm(m,F,ie),S=j}else for(b=0;b<h.length;b++){if(F=h[b],j=F.instance,ie=F.currentTarget,F=F.listener,j!==S&&m.isPropagationStopped())break e;Cm(m,F,ie),S=j}}}if(es)throw i=Qr,es=!1,Qr=null,i}function jt(i,r){var o=r[pd];o===void 0&&(o=r[pd]=new Set);var h=i+"__bubble";o.has(h)||(Rm(r,i,2,!1),o.add(h))}function od(i,r,o){var h=0;r&&(h|=4),Rm(o,i,h,r)}var Dl="_reactListening"+Math.random().toString(36).slice(2);function wo(i){if(!i[Dl]){i[Dl]=!0,s.forEach(function(o){o!=="selectionchange"&&(w1.has(o)||od(o,!1,i),od(o,!0,i))});var r=i.nodeType===9?i:i.ownerDocument;r===null||r[Dl]||(r[Dl]=!0,od("selectionchange",!1,r))}}function Rm(i,r,o,h){switch(Jp(r)){case 1:var m=Ox;break;case 4:m=jx;break;default:m=Gu}o=m.bind(null,r,o,i),m=void 0,!Zr||r!=="touchstart"&&r!=="touchmove"&&r!=="wheel"||(m=!0),h?m!==void 0?i.addEventListener(r,o,{capture:!0,passive:m}):i.addEventListener(r,o,!0):m!==void 0?i.addEventListener(r,o,{passive:m}):i.addEventListener(r,o,!1)}function ld(i,r,o,h,m){var S=h;if((r&1)===0&&(r&2)===0&&h!==null)e:for(;;){if(h===null)return;var b=h.tag;if(b===3||b===4){var F=h.stateNode.containerInfo;if(F===m||F.nodeType===8&&F.parentNode===m)break;if(b===4)for(b=h.return;b!==null;){var j=b.tag;if((j===3||j===4)&&(j=b.stateNode.containerInfo,j===m||j.nodeType===8&&j.parentNode===m))return;b=b.return}for(;F!==null;){if(b=pr(F),b===null)return;if(j=b.tag,j===5||j===6){h=S=b;continue e}F=F.parentNode}}h=h.return}ci(function(){var ie=S,ye=Fe(o),Ee=[];e:{var xe=bm.get(i);if(xe!==void 0){var ze=Xu,$e=i;switch(i){case"keypress":if(Cl(o)===0)break e;case"keydown":case"keyup":ze=e1;break;case"focusin":$e="focus",ze=Ku;break;case"focusout":$e="blur",ze=Ku;break;case"beforeblur":case"afterblur":ze=Ku;break;case"click":if(o.button===2)break e;case"auxclick":case"dblclick":case"mousedown":case"mousemove":case"mouseup":case"mouseout":case"mouseover":case"contextmenu":ze=nm;break;case"drag":case"dragend":case"dragenter":case"dragexit":case"dragleave":case"dragover":case"dragstart":case"drop":ze=Hx;break;case"touchcancel":case"touchend":case"touchmove":case"touchstart":ze=i1;break;case Mm:case Em:case wm:ze=Wx;break;case Tm:ze=r1;break;case"scroll":ze=zx;break;case"wheel":ze=o1;break;case"copy":case"cut":case"paste":ze=Xx;break;case"gotpointercapture":case"lostpointercapture":case"pointercancel":case"pointerdown":case"pointermove":case"pointerout":case"pointerover":case"pointerup":ze=sm}var Xe=(r&4)!==0,Kt=!Xe&&i==="scroll",Y=Xe?xe!==null?xe+"Capture":null:xe;Xe=[];for(var H=ie,Z;H!==null;){Z=H;var Ne=Z.stateNode;if(Z.tag===5&&Ne!==null&&(Z=Ne,Y!==null&&(Ne=Cs(H,Y),Ne!=null&&Xe.push(To(H,Ne,Z)))),Kt)break;H=H.return}0<Xe.length&&(xe=new ze(xe,$e,null,o,ye),Ee.push({event:xe,listeners:Xe}))}}if((r&7)===0){e:{if(xe=i==="mouseover"||i==="pointerover",ze=i==="mouseout"||i==="pointerout",xe&&o!==G&&($e=o.relatedTarget||o.fromElement)&&(pr($e)||$e[is]))break e;if((ze||xe)&&(xe=ye.window===ye?ye:(xe=ye.ownerDocument)?xe.defaultView||xe.parentWindow:window,ze?($e=o.relatedTarget||o.toElement,ze=ie,$e=$e?pr($e):null,$e!==null&&(Kt=ts($e),$e!==Kt||$e.tag!==5&&$e.tag!==6)&&($e=null)):(ze=null,$e=ie),ze!==$e)){if(Xe=nm,Ne="onMouseLeave",Y="onMouseEnter",H="mouse",(i==="pointerout"||i==="pointerover")&&(Xe=sm,Ne="onPointerLeave",Y="onPointerEnter",H="pointer"),Kt=ze==null?xe:la(ze),Z=$e==null?xe:la($e),xe=new Xe(Ne,H+"leave",ze,o,ye),xe.target=Kt,xe.relatedTarget=Z,Ne=null,pr(ye)===ie&&(Xe=new Xe(Y,H+"enter",$e,o,ye),Xe.target=Z,Xe.relatedTarget=Kt,Ne=Xe),Kt=Ne,ze&&$e)t:{for(Xe=ze,Y=$e,H=0,Z=Xe;Z;Z=aa(Z))H++;for(Z=0,Ne=Y;Ne;Ne=aa(Ne))Z++;for(;0<H-Z;)Xe=aa(Xe),H--;for(;0<Z-H;)Y=aa(Y),Z--;for(;H--;){if(Xe===Y||Y!==null&&Xe===Y.alternate)break t;Xe=aa(Xe),Y=aa(Y)}Xe=null}else Xe=null;ze!==null&&Pm(Ee,xe,ze,Xe,!1),$e!==null&&Kt!==null&&Pm(Ee,Kt,$e,Xe,!0)}}e:{if(xe=ie?la(ie):window,ze=xe.nodeName&&xe.nodeName.toLowerCase(),ze==="select"||ze==="input"&&xe.type==="file")var Ke=p1;else if(um(xe))if(hm)Ke=v1;else{Ke=g1;var Qe=m1}else(ze=xe.nodeName)&&ze.toLowerCase()==="input"&&(xe.type==="checkbox"||xe.type==="radio")&&(Ke=_1);if(Ke&&(Ke=Ke(i,ie))){dm(Ee,Ke,o,ye);break e}Qe&&Qe(i,xe,ie),i==="focusout"&&(Qe=xe._wrapperState)&&Qe.controlled&&xe.type==="number"&&it(xe,"number",xe.value)}switch(Qe=ie?la(ie):window,i){case"focusin":(um(Qe)||Qe.contentEditable==="true")&&(sa=Qe,nd=ie,Mo=null);break;case"focusout":Mo=nd=sa=null;break;case"mousedown":id=!0;break;case"contextmenu":case"mouseup":case"dragend":id=!1,ym(Ee,o,ye);break;case"selectionchange":if(S1)break;case"keydown":case"keyup":ym(Ee,o,ye)}var Je;if(Qu)e:{switch(i){case"compositionstart":var ot="onCompositionStart";break e;case"compositionend":ot="onCompositionEnd";break e;case"compositionupdate":ot="onCompositionUpdate";break e}ot=void 0}else ia?lm(i,o)&&(ot="onCompositionEnd"):i==="keydown"&&o.keyCode===229&&(ot="onCompositionStart");ot&&(rm&&o.locale!=="ko"&&(ia||ot!=="onCompositionStart"?ot==="onCompositionEnd"&&ia&&(Je=em()):(Is=ye,$u="value"in Is?Is.value:Is.textContent,ia=!0)),Qe=Il(ie,ot),0<Qe.length&&(ot=new im(ot,i,null,o,ye),Ee.push({event:ot,listeners:Qe}),Je?ot.data=Je:(Je=cm(o),Je!==null&&(ot.data=Je)))),(Je=c1?u1(i,o):d1(i,o))&&(ie=Il(ie,"onBeforeInput"),0<ie.length&&(ye=new im("onBeforeInput","beforeinput",null,o,ye),Ee.push({event:ye,listeners:ie}),ye.data=Je))}Nm(Ee,r)})}function To(i,r,o){return{instance:i,listener:r,currentTarget:o}}function Il(i,r){for(var o=r+"Capture",h=[];i!==null;){var m=i,S=m.stateNode;m.tag===5&&S!==null&&(m=S,S=Cs(i,o),S!=null&&h.unshift(To(i,S,m)),S=Cs(i,r),S!=null&&h.push(To(i,S,m))),i=i.return}return h}function aa(i){if(i===null)return null;do i=i.return;while(i&&i.tag!==5);return i||null}function Pm(i,r,o,h,m){for(var S=r._reactName,b=[];o!==null&&o!==h;){var F=o,j=F.alternate,ie=F.stateNode;if(j!==null&&j===h)break;F.tag===5&&ie!==null&&(F=ie,m?(j=Cs(o,S),j!=null&&b.unshift(To(o,j,F))):m||(j=Cs(o,S),j!=null&&b.push(To(o,j,F)))),o=o.return}b.length!==0&&i.push({event:r,listeners:b})}var T1=/\r\n?/g,b1=/\u0000|\uFFFD/g;function km(i){return(typeof i=="string"?i:""+i).replace(T1,`
`).replace(b1,"")}function Ul(i,r,o){if(r=km(r),km(i)!==r&&o)throw Error(t(425))}function Fl(){}var cd=null,ud=null;function dd(i,r){return i==="textarea"||i==="noscript"||typeof r.children=="string"||typeof r.children=="number"||typeof r.dangerouslySetInnerHTML=="object"&&r.dangerouslySetInnerHTML!==null&&r.dangerouslySetInnerHTML.__html!=null}var hd=typeof setTimeout=="function"?setTimeout:void 0,A1=typeof clearTimeout=="function"?clearTimeout:void 0,Lm=typeof Promise=="function"?Promise:void 0,C1=typeof queueMicrotask=="function"?queueMicrotask:typeof Lm<"u"?function(i){return Lm.resolve(null).then(i).catch(N1)}:hd;function N1(i){setTimeout(function(){throw i})}function fd(i,r){var o=r,h=0;do{var m=o.nextSibling;if(i.removeChild(o),m&&m.nodeType===8)if(o=m.data,o==="/$"){if(h===0){i.removeChild(m),mo(r);return}h--}else o!=="$"&&o!=="$?"&&o!=="$!"||h++;o=m}while(o);mo(r)}function Fs(i){for(;i!=null;i=i.nextSibling){var r=i.nodeType;if(r===1||r===3)break;if(r===8){if(r=i.data,r==="$"||r==="$!"||r==="$?")break;if(r==="/$")return null}}return i}function Dm(i){i=i.previousSibling;for(var r=0;i;){if(i.nodeType===8){var o=i.data;if(o==="$"||o==="$!"||o==="$?"){if(r===0)return i;r--}else o==="/$"&&r++}i=i.previousSibling}return null}var oa=Math.random().toString(36).slice(2),Hi="__reactFiber$"+oa,bo="__reactProps$"+oa,is="__reactContainer$"+oa,pd="__reactEvents$"+oa,R1="__reactListeners$"+oa,P1="__reactHandles$"+oa;function pr(i){var r=i[Hi];if(r)return r;for(var o=i.parentNode;o;){if(r=o[is]||o[Hi]){if(o=r.alternate,r.child!==null||o!==null&&o.child!==null)for(i=Dm(i);i!==null;){if(o=i[Hi])return o;i=Dm(i)}return r}i=o,o=i.parentNode}return null}function Ao(i){return i=i[Hi]||i[is],!i||i.tag!==5&&i.tag!==6&&i.tag!==13&&i.tag!==3?null:i}function la(i){if(i.tag===5||i.tag===6)return i.stateNode;throw Error(t(33))}function Ol(i){return i[bo]||null}var md=[],ca=-1;function Os(i){return{current:i}}function zt(i){0>ca||(i.current=md[ca],md[ca]=null,ca--)}function Ft(i,r){ca++,md[ca]=i.current,i.current=r}var js={},Tn=Os(js),jn=Os(!1),mr=js;function ua(i,r){var o=i.type.contextTypes;if(!o)return js;var h=i.stateNode;if(h&&h.__reactInternalMemoizedUnmaskedChildContext===r)return h.__reactInternalMemoizedMaskedChildContext;var m={},S;for(S in o)m[S]=r[S];return h&&(i=i.stateNode,i.__reactInternalMemoizedUnmaskedChildContext=r,i.__reactInternalMemoizedMaskedChildContext=m),m}function zn(i){return i=i.childContextTypes,i!=null}function jl(){zt(jn),zt(Tn)}function Im(i,r,o){if(Tn.current!==js)throw Error(t(168));Ft(Tn,r),Ft(jn,o)}function Um(i,r,o){var h=i.stateNode;if(r=r.childContextTypes,typeof h.getChildContext!="function")return o;h=h.getChildContext();for(var m in h)if(!(m in r))throw Error(t(108,Ae(i)||"Unknown",m));return oe({},o,h)}function zl(i){return i=(i=i.stateNode)&&i.__reactInternalMemoizedMergedChildContext||js,mr=Tn.current,Ft(Tn,i),Ft(jn,jn.current),!0}function Fm(i,r,o){var h=i.stateNode;if(!h)throw Error(t(169));o?(i=Um(i,r,mr),h.__reactInternalMemoizedMergedChildContext=i,zt(jn),zt(Tn),Ft(Tn,i)):zt(jn),Ft(jn,o)}var ss=null,Bl=!1,gd=!1;function Om(i){ss===null?ss=[i]:ss.push(i)}function k1(i){Bl=!0,Om(i)}function zs(){if(!gd&&ss!==null){gd=!0;var i=0,r=kt;try{var o=ss;for(kt=1;i<o.length;i++){var h=o[i];do h=h(!0);while(h!==null)}ss=null,Bl=!1}catch(m){throw ss!==null&&(ss=ss.slice(i+1)),ne(et,zs),m}finally{kt=r,gd=!1}}return null}var da=[],ha=0,Hl=null,Vl=0,ui=[],di=0,gr=null,rs=1,as="";function _r(i,r){da[ha++]=Vl,da[ha++]=Hl,Hl=i,Vl=r}function jm(i,r,o){ui[di++]=rs,ui[di++]=as,ui[di++]=gr,gr=i;var h=rs;i=as;var m=32-Ve(h)-1;h&=~(1<<m),o+=1;var S=32-Ve(r)+m;if(30<S){var b=m-m%5;S=(h&(1<<b)-1).toString(32),h>>=b,m-=b,rs=1<<32-Ve(r)+m|o<<m|h,as=S+i}else rs=1<<S|o<<m|h,as=i}function _d(i){i.return!==null&&(_r(i,1),jm(i,1,0))}function vd(i){for(;i===Hl;)Hl=da[--ha],da[ha]=null,Vl=da[--ha],da[ha]=null;for(;i===gr;)gr=ui[--di],ui[di]=null,as=ui[--di],ui[di]=null,rs=ui[--di],ui[di]=null}var ei=null,ti=null,Gt=!1,bi=null;function zm(i,r){var o=mi(5,null,null,0);o.elementType="DELETED",o.stateNode=r,o.return=i,r=i.deletions,r===null?(i.deletions=[o],i.flags|=16):r.push(o)}function Bm(i,r){switch(i.tag){case 5:var o=i.type;return r=r.nodeType!==1||o.toLowerCase()!==r.nodeName.toLowerCase()?null:r,r!==null?(i.stateNode=r,ei=i,ti=Fs(r.firstChild),!0):!1;case 6:return r=i.pendingProps===""||r.nodeType!==3?null:r,r!==null?(i.stateNode=r,ei=i,ti=null,!0):!1;case 13:return r=r.nodeType!==8?null:r,r!==null?(o=gr!==null?{id:rs,overflow:as}:null,i.memoizedState={dehydrated:r,treeContext:o,retryLane:1073741824},o=mi(18,null,null,0),o.stateNode=r,o.return=i,i.child=o,ei=i,ti=null,!0):!1;default:return!1}}function xd(i){return(i.mode&1)!==0&&(i.flags&128)===0}function yd(i){if(Gt){var r=ti;if(r){var o=r;if(!Bm(i,r)){if(xd(i))throw Error(t(418));r=Fs(o.nextSibling);var h=ei;r&&Bm(i,r)?zm(h,o):(i.flags=i.flags&-4097|2,Gt=!1,ei=i)}}else{if(xd(i))throw Error(t(418));i.flags=i.flags&-4097|2,Gt=!1,ei=i}}}function Hm(i){for(i=i.return;i!==null&&i.tag!==5&&i.tag!==3&&i.tag!==13;)i=i.return;ei=i}function Gl(i){if(i!==ei)return!1;if(!Gt)return Hm(i),Gt=!0,!1;var r;if((r=i.tag!==3)&&!(r=i.tag!==5)&&(r=i.type,r=r!=="head"&&r!=="body"&&!dd(i.type,i.memoizedProps)),r&&(r=ti)){if(xd(i))throw Vm(),Error(t(418));for(;r;)zm(i,r),r=Fs(r.nextSibling)}if(Hm(i),i.tag===13){if(i=i.memoizedState,i=i!==null?i.dehydrated:null,!i)throw Error(t(317));e:{for(i=i.nextSibling,r=0;i;){if(i.nodeType===8){var o=i.data;if(o==="/$"){if(r===0){ti=Fs(i.nextSibling);break e}r--}else o!=="$"&&o!=="$!"&&o!=="$?"||r++}i=i.nextSibling}ti=null}}else ti=ei?Fs(i.stateNode.nextSibling):null;return!0}function Vm(){for(var i=ti;i;)i=Fs(i.nextSibling)}function fa(){ti=ei=null,Gt=!1}function Sd(i){bi===null?bi=[i]:bi.push(i)}var L1=R.ReactCurrentBatchConfig;function Co(i,r,o){if(i=o.ref,i!==null&&typeof i!="function"&&typeof i!="object"){if(o._owner){if(o=o._owner,o){if(o.tag!==1)throw Error(t(309));var h=o.stateNode}if(!h)throw Error(t(147,i));var m=h,S=""+i;return r!==null&&r.ref!==null&&typeof r.ref=="function"&&r.ref._stringRef===S?r.ref:(r=function(b){var F=m.refs;b===null?delete F[S]:F[S]=b},r._stringRef=S,r)}if(typeof i!="string")throw Error(t(284));if(!o._owner)throw Error(t(290,i))}return i}function Wl(i,r){throw i=Object.prototype.toString.call(r),Error(t(31,i==="[object Object]"?"object with keys {"+Object.keys(r).join(", ")+"}":i))}function Gm(i){var r=i._init;return r(i._payload)}function Wm(i){function r(Y,H){if(i){var Z=Y.deletions;Z===null?(Y.deletions=[H],Y.flags|=16):Z.push(H)}}function o(Y,H){if(!i)return null;for(;H!==null;)r(Y,H),H=H.sibling;return null}function h(Y,H){for(Y=new Map;H!==null;)H.key!==null?Y.set(H.key,H):Y.set(H.index,H),H=H.sibling;return Y}function m(Y,H){return Y=qs(Y,H),Y.index=0,Y.sibling=null,Y}function S(Y,H,Z){return Y.index=Z,i?(Z=Y.alternate,Z!==null?(Z=Z.index,Z<H?(Y.flags|=2,H):Z):(Y.flags|=2,H)):(Y.flags|=1048576,H)}function b(Y){return i&&Y.alternate===null&&(Y.flags|=2),Y}function F(Y,H,Z,Ne){return H===null||H.tag!==6?(H=hh(Z,Y.mode,Ne),H.return=Y,H):(H=m(H,Z),H.return=Y,H)}function j(Y,H,Z,Ne){var Ke=Z.type;return Ke===U?ye(Y,H,Z.props.children,Ne,Z.key):H!==null&&(H.elementType===Ke||typeof Ke=="object"&&Ke!==null&&Ke.$$typeof===V&&Gm(Ke)===H.type)?(Ne=m(H,Z.props),Ne.ref=Co(Y,H,Z),Ne.return=Y,Ne):(Ne=mc(Z.type,Z.key,Z.props,null,Y.mode,Ne),Ne.ref=Co(Y,H,Z),Ne.return=Y,Ne)}function ie(Y,H,Z,Ne){return H===null||H.tag!==4||H.stateNode.containerInfo!==Z.containerInfo||H.stateNode.implementation!==Z.implementation?(H=fh(Z,Y.mode,Ne),H.return=Y,H):(H=m(H,Z.children||[]),H.return=Y,H)}function ye(Y,H,Z,Ne,Ke){return H===null||H.tag!==7?(H=Tr(Z,Y.mode,Ne,Ke),H.return=Y,H):(H=m(H,Z),H.return=Y,H)}function Ee(Y,H,Z){if(typeof H=="string"&&H!==""||typeof H=="number")return H=hh(""+H,Y.mode,Z),H.return=Y,H;if(typeof H=="object"&&H!==null){switch(H.$$typeof){case k:return Z=mc(H.type,H.key,H.props,null,Y.mode,Z),Z.ref=Co(Y,null,H),Z.return=Y,Z;case D:return H=fh(H,Y.mode,Z),H.return=Y,H;case V:var Ne=H._init;return Ee(Y,Ne(H._payload),Z)}if(I(H)||ue(H))return H=Tr(H,Y.mode,Z,null),H.return=Y,H;Wl(Y,H)}return null}function xe(Y,H,Z,Ne){var Ke=H!==null?H.key:null;if(typeof Z=="string"&&Z!==""||typeof Z=="number")return Ke!==null?null:F(Y,H,""+Z,Ne);if(typeof Z=="object"&&Z!==null){switch(Z.$$typeof){case k:return Z.key===Ke?j(Y,H,Z,Ne):null;case D:return Z.key===Ke?ie(Y,H,Z,Ne):null;case V:return Ke=Z._init,xe(Y,H,Ke(Z._payload),Ne)}if(I(Z)||ue(Z))return Ke!==null?null:ye(Y,H,Z,Ne,null);Wl(Y,Z)}return null}function ze(Y,H,Z,Ne,Ke){if(typeof Ne=="string"&&Ne!==""||typeof Ne=="number")return Y=Y.get(Z)||null,F(H,Y,""+Ne,Ke);if(typeof Ne=="object"&&Ne!==null){switch(Ne.$$typeof){case k:return Y=Y.get(Ne.key===null?Z:Ne.key)||null,j(H,Y,Ne,Ke);case D:return Y=Y.get(Ne.key===null?Z:Ne.key)||null,ie(H,Y,Ne,Ke);case V:var Qe=Ne._init;return ze(Y,H,Z,Qe(Ne._payload),Ke)}if(I(Ne)||ue(Ne))return Y=Y.get(Z)||null,ye(H,Y,Ne,Ke,null);Wl(H,Ne)}return null}function $e(Y,H,Z,Ne){for(var Ke=null,Qe=null,Je=H,ot=H=0,mn=null;Je!==null&&ot<Z.length;ot++){Je.index>ot?(mn=Je,Je=null):mn=Je.sibling;var wt=xe(Y,Je,Z[ot],Ne);if(wt===null){Je===null&&(Je=mn);break}i&&Je&&wt.alternate===null&&r(Y,Je),H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt,Je=mn}if(ot===Z.length)return o(Y,Je),Gt&&_r(Y,ot),Ke;if(Je===null){for(;ot<Z.length;ot++)Je=Ee(Y,Z[ot],Ne),Je!==null&&(H=S(Je,H,ot),Qe===null?Ke=Je:Qe.sibling=Je,Qe=Je);return Gt&&_r(Y,ot),Ke}for(Je=h(Y,Je);ot<Z.length;ot++)mn=ze(Je,Y,ot,Z[ot],Ne),mn!==null&&(i&&mn.alternate!==null&&Je.delete(mn.key===null?ot:mn.key),H=S(mn,H,ot),Qe===null?Ke=mn:Qe.sibling=mn,Qe=mn);return i&&Je.forEach(function(Ys){return r(Y,Ys)}),Gt&&_r(Y,ot),Ke}function Xe(Y,H,Z,Ne){var Ke=ue(Z);if(typeof Ke!="function")throw Error(t(150));if(Z=Ke.call(Z),Z==null)throw Error(t(151));for(var Qe=Ke=null,Je=H,ot=H=0,mn=null,wt=Z.next();Je!==null&&!wt.done;ot++,wt=Z.next()){Je.index>ot?(mn=Je,Je=null):mn=Je.sibling;var Ys=xe(Y,Je,wt.value,Ne);if(Ys===null){Je===null&&(Je=mn);break}i&&Je&&Ys.alternate===null&&r(Y,Je),H=S(Ys,H,ot),Qe===null?Ke=Ys:Qe.sibling=Ys,Qe=Ys,Je=mn}if(wt.done)return o(Y,Je),Gt&&_r(Y,ot),Ke;if(Je===null){for(;!wt.done;ot++,wt=Z.next())wt=Ee(Y,wt.value,Ne),wt!==null&&(H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt);return Gt&&_r(Y,ot),Ke}for(Je=h(Y,Je);!wt.done;ot++,wt=Z.next())wt=ze(Je,Y,ot,wt.value,Ne),wt!==null&&(i&&wt.alternate!==null&&Je.delete(wt.key===null?ot:wt.key),H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt);return i&&Je.forEach(function(hy){return r(Y,hy)}),Gt&&_r(Y,ot),Ke}function Kt(Y,H,Z,Ne){if(typeof Z=="object"&&Z!==null&&Z.type===U&&Z.key===null&&(Z=Z.props.children),typeof Z=="object"&&Z!==null){switch(Z.$$typeof){case k:e:{for(var Ke=Z.key,Qe=H;Qe!==null;){if(Qe.key===Ke){if(Ke=Z.type,Ke===U){if(Qe.tag===7){o(Y,Qe.sibling),H=m(Qe,Z.props.children),H.return=Y,Y=H;break e}}else if(Qe.elementType===Ke||typeof Ke=="object"&&Ke!==null&&Ke.$$typeof===V&&Gm(Ke)===Qe.type){o(Y,Qe.sibling),H=m(Qe,Z.props),H.ref=Co(Y,Qe,Z),H.return=Y,Y=H;break e}o(Y,Qe);break}else r(Y,Qe);Qe=Qe.sibling}Z.type===U?(H=Tr(Z.props.children,Y.mode,Ne,Z.key),H.return=Y,Y=H):(Ne=mc(Z.type,Z.key,Z.props,null,Y.mode,Ne),Ne.ref=Co(Y,H,Z),Ne.return=Y,Y=Ne)}return b(Y);case D:e:{for(Qe=Z.key;H!==null;){if(H.key===Qe)if(H.tag===4&&H.stateNode.containerInfo===Z.containerInfo&&H.stateNode.implementation===Z.implementation){o(Y,H.sibling),H=m(H,Z.children||[]),H.return=Y,Y=H;break e}else{o(Y,H);break}else r(Y,H);H=H.sibling}H=fh(Z,Y.mode,Ne),H.return=Y,Y=H}return b(Y);case V:return Qe=Z._init,Kt(Y,H,Qe(Z._payload),Ne)}if(I(Z))return $e(Y,H,Z,Ne);if(ue(Z))return Xe(Y,H,Z,Ne);Wl(Y,Z)}return typeof Z=="string"&&Z!==""||typeof Z=="number"?(Z=""+Z,H!==null&&H.tag===6?(o(Y,H.sibling),H=m(H,Z),H.return=Y,Y=H):(o(Y,H),H=hh(Z,Y.mode,Ne),H.return=Y,Y=H),b(Y)):o(Y,H)}return Kt}var pa=Wm(!0),$m=Wm(!1),$l=Os(null),Xl=null,ma=null,Md=null;function Ed(){Md=ma=Xl=null}function wd(i){var r=$l.current;zt($l),i._currentValue=r}function Td(i,r,o){for(;i!==null;){var h=i.alternate;if((i.childLanes&r)!==r?(i.childLanes|=r,h!==null&&(h.childLanes|=r)):h!==null&&(h.childLanes&r)!==r&&(h.childLanes|=r),i===o)break;i=i.return}}function ga(i,r){Xl=i,Md=ma=null,i=i.dependencies,i!==null&&i.firstContext!==null&&((i.lanes&r)!==0&&(Bn=!0),i.firstContext=null)}function hi(i){var r=i._currentValue;if(Md!==i)if(i={context:i,memoizedValue:r,next:null},ma===null){if(Xl===null)throw Error(t(308));ma=i,Xl.dependencies={lanes:0,firstContext:i}}else ma=ma.next=i;return r}var vr=null;function bd(i){vr===null?vr=[i]:vr.push(i)}function Xm(i,r,o,h){var m=r.interleaved;return m===null?(o.next=o,bd(r)):(o.next=m.next,m.next=o),r.interleaved=o,os(i,h)}function os(i,r){i.lanes|=r;var o=i.alternate;for(o!==null&&(o.lanes|=r),o=i,i=i.return;i!==null;)i.childLanes|=r,o=i.alternate,o!==null&&(o.childLanes|=r),o=i,i=i.return;return o.tag===3?o.stateNode:null}var Bs=!1;function Ad(i){i.updateQueue={baseState:i.memoizedState,firstBaseUpdate:null,lastBaseUpdate:null,shared:{pending:null,interleaved:null,lanes:0},effects:null}}function qm(i,r){i=i.updateQueue,r.updateQueue===i&&(r.updateQueue={baseState:i.baseState,firstBaseUpdate:i.firstBaseUpdate,lastBaseUpdate:i.lastBaseUpdate,shared:i.shared,effects:i.effects})}function ls(i,r){return{eventTime:i,lane:r,tag:0,payload:null,callback:null,next:null}}function Hs(i,r,o){var h=i.updateQueue;if(h===null)return null;if(h=h.shared,(St&2)!==0){var m=h.pending;return m===null?r.next=r:(r.next=m.next,m.next=r),h.pending=r,os(i,o)}return m=h.interleaved,m===null?(r.next=r,bd(h)):(r.next=m.next,m.next=r),h.interleaved=r,os(i,o)}function ql(i,r,o){if(r=r.updateQueue,r!==null&&(r=r.shared,(o&4194240)!==0)){var h=r.lanes;h&=i.pendingLanes,o|=h,r.lanes=o,Bu(i,o)}}function Ym(i,r){var o=i.updateQueue,h=i.alternate;if(h!==null&&(h=h.updateQueue,o===h)){var m=null,S=null;if(o=o.firstBaseUpdate,o!==null){do{var b={eventTime:o.eventTime,lane:o.lane,tag:o.tag,payload:o.payload,callback:o.callback,next:null};S===null?m=S=b:S=S.next=b,o=o.next}while(o!==null);S===null?m=S=r:S=S.next=r}else m=S=r;o={baseState:h.baseState,firstBaseUpdate:m,lastBaseUpdate:S,shared:h.shared,effects:h.effects},i.updateQueue=o;return}i=o.lastBaseUpdate,i===null?o.firstBaseUpdate=r:i.next=r,o.lastBaseUpdate=r}function Yl(i,r,o,h){var m=i.updateQueue;Bs=!1;var S=m.firstBaseUpdate,b=m.lastBaseUpdate,F=m.shared.pending;if(F!==null){m.shared.pending=null;var j=F,ie=j.next;j.next=null,b===null?S=ie:b.next=ie,b=j;var ye=i.alternate;ye!==null&&(ye=ye.updateQueue,F=ye.lastBaseUpdate,F!==b&&(F===null?ye.firstBaseUpdate=ie:F.next=ie,ye.lastBaseUpdate=j))}if(S!==null){var Ee=m.baseState;b=0,ye=ie=j=null,F=S;do{var xe=F.lane,ze=F.eventTime;if((h&xe)===xe){ye!==null&&(ye=ye.next={eventTime:ze,lane:0,tag:F.tag,payload:F.payload,callback:F.callback,next:null});e:{var $e=i,Xe=F;switch(xe=r,ze=o,Xe.tag){case 1:if($e=Xe.payload,typeof $e=="function"){Ee=$e.call(ze,Ee,xe);break e}Ee=$e;break e;case 3:$e.flags=$e.flags&-65537|128;case 0:if($e=Xe.payload,xe=typeof $e=="function"?$e.call(ze,Ee,xe):$e,xe==null)break e;Ee=oe({},Ee,xe);break e;case 2:Bs=!0}}F.callback!==null&&F.lane!==0&&(i.flags|=64,xe=m.effects,xe===null?m.effects=[F]:xe.push(F))}else ze={eventTime:ze,lane:xe,tag:F.tag,payload:F.payload,callback:F.callback,next:null},ye===null?(ie=ye=ze,j=Ee):ye=ye.next=ze,b|=xe;if(F=F.next,F===null){if(F=m.shared.pending,F===null)break;xe=F,F=xe.next,xe.next=null,m.lastBaseUpdate=xe,m.shared.pending=null}}while(!0);if(ye===null&&(j=Ee),m.baseState=j,m.firstBaseUpdate=ie,m.lastBaseUpdate=ye,r=m.shared.interleaved,r!==null){m=r;do b|=m.lane,m=m.next;while(m!==r)}else S===null&&(m.shared.lanes=0);Sr|=b,i.lanes=b,i.memoizedState=Ee}}function Km(i,r,o){if(i=r.effects,r.effects=null,i!==null)for(r=0;r<i.length;r++){var h=i[r],m=h.callback;if(m!==null){if(h.callback=null,h=o,typeof m!="function")throw Error(t(191,m));m.call(h)}}}var No={},Vi=Os(No),Ro=Os(No),Po=Os(No);function xr(i){if(i===No)throw Error(t(174));return i}function Cd(i,r){switch(Ft(Po,r),Ft(Ro,i),Ft(Vi,No),i=r.nodeType,i){case 9:case 11:r=(r=r.documentElement)?r.namespaceURI:ke(null,"");break;default:i=i===8?r.parentNode:r,r=i.namespaceURI||null,i=i.tagName,r=ke(r,i)}zt(Vi),Ft(Vi,r)}function _a(){zt(Vi),zt(Ro),zt(Po)}function Zm(i){xr(Po.current);var r=xr(Vi.current),o=ke(r,i.type);r!==o&&(Ft(Ro,i),Ft(Vi,o))}function Nd(i){Ro.current===i&&(zt(Vi),zt(Ro))}var Xt=Os(0);function Kl(i){for(var r=i;r!==null;){if(r.tag===13){var o=r.memoizedState;if(o!==null&&(o=o.dehydrated,o===null||o.data==="$?"||o.data==="$!"))return r}else if(r.tag===19&&r.memoizedProps.revealOrder!==void 0){if((r.flags&128)!==0)return r}else if(r.child!==null){r.child.return=r,r=r.child;continue}if(r===i)break;for(;r.sibling===null;){if(r.return===null||r.return===i)return null;r=r.return}r.sibling.return=r.return,r=r.sibling}return null}var Rd=[];function Pd(){for(var i=0;i<Rd.length;i++)Rd[i]._workInProgressVersionPrimary=null;Rd.length=0}var Zl=R.ReactCurrentDispatcher,kd=R.ReactCurrentBatchConfig,yr=0,qt=null,rn=null,fn=null,Ql=!1,ko=!1,Lo=0,D1=0;function bn(){throw Error(t(321))}function Ld(i,r){if(r===null)return!1;for(var o=0;o<r.length&&o<i.length;o++)if(!Ti(i[o],r[o]))return!1;return!0}function Dd(i,r,o,h,m,S){if(yr=S,qt=r,r.memoizedState=null,r.updateQueue=null,r.lanes=0,Zl.current=i===null||i.memoizedState===null?O1:j1,i=o(h,m),ko){S=0;do{if(ko=!1,Lo=0,25<=S)throw Error(t(301));S+=1,fn=rn=null,r.updateQueue=null,Zl.current=z1,i=o(h,m)}while(ko)}if(Zl.current=tc,r=rn!==null&&rn.next!==null,yr=0,fn=rn=qt=null,Ql=!1,r)throw Error(t(300));return i}function Id(){var i=Lo!==0;return Lo=0,i}function Gi(){var i={memoizedState:null,baseState:null,baseQueue:null,queue:null,next:null};return fn===null?qt.memoizedState=fn=i:fn=fn.next=i,fn}function fi(){if(rn===null){var i=qt.alternate;i=i!==null?i.memoizedState:null}else i=rn.next;var r=fn===null?qt.memoizedState:fn.next;if(r!==null)fn=r,rn=i;else{if(i===null)throw Error(t(310));rn=i,i={memoizedState:rn.memoizedState,baseState:rn.baseState,baseQueue:rn.baseQueue,queue:rn.queue,next:null},fn===null?qt.memoizedState=fn=i:fn=fn.next=i}return fn}function Do(i,r){return typeof r=="function"?r(i):r}function Ud(i){var r=fi(),o=r.queue;if(o===null)throw Error(t(311));o.lastRenderedReducer=i;var h=rn,m=h.baseQueue,S=o.pending;if(S!==null){if(m!==null){var b=m.next;m.next=S.next,S.next=b}h.baseQueue=m=S,o.pending=null}if(m!==null){S=m.next,h=h.baseState;var F=b=null,j=null,ie=S;do{var ye=ie.lane;if((yr&ye)===ye)j!==null&&(j=j.next={lane:0,action:ie.action,hasEagerState:ie.hasEagerState,eagerState:ie.eagerState,next:null}),h=ie.hasEagerState?ie.eagerState:i(h,ie.action);else{var Ee={lane:ye,action:ie.action,hasEagerState:ie.hasEagerState,eagerState:ie.eagerState,next:null};j===null?(F=j=Ee,b=h):j=j.next=Ee,qt.lanes|=ye,Sr|=ye}ie=ie.next}while(ie!==null&&ie!==S);j===null?b=h:j.next=F,Ti(h,r.memoizedState)||(Bn=!0),r.memoizedState=h,r.baseState=b,r.baseQueue=j,o.lastRenderedState=h}if(i=o.interleaved,i!==null){m=i;do S=m.lane,qt.lanes|=S,Sr|=S,m=m.next;while(m!==i)}else m===null&&(o.lanes=0);return[r.memoizedState,o.dispatch]}function Fd(i){var r=fi(),o=r.queue;if(o===null)throw Error(t(311));o.lastRenderedReducer=i;var h=o.dispatch,m=o.pending,S=r.memoizedState;if(m!==null){o.pending=null;var b=m=m.next;do S=i(S,b.action),b=b.next;while(b!==m);Ti(S,r.memoizedState)||(Bn=!0),r.memoizedState=S,r.baseQueue===null&&(r.baseState=S),o.lastRenderedState=S}return[S,h]}function Qm(){}function Jm(i,r){var o=qt,h=fi(),m=r(),S=!Ti(h.memoizedState,m);if(S&&(h.memoizedState=m,Bn=!0),h=h.queue,Od(n0.bind(null,o,h,i),[i]),h.getSnapshot!==r||S||fn!==null&&fn.memoizedState.tag&1){if(o.flags|=2048,Io(9,t0.bind(null,o,h,m,r),void 0,null),pn===null)throw Error(t(349));(yr&30)!==0||e0(o,r,m)}return m}function e0(i,r,o){i.flags|=16384,i={getSnapshot:r,value:o},r=qt.updateQueue,r===null?(r={lastEffect:null,stores:null},qt.updateQueue=r,r.stores=[i]):(o=r.stores,o===null?r.stores=[i]:o.push(i))}function t0(i,r,o,h){r.value=o,r.getSnapshot=h,i0(r)&&s0(i)}function n0(i,r,o){return o(function(){i0(r)&&s0(i)})}function i0(i){var r=i.getSnapshot;i=i.value;try{var o=r();return!Ti(i,o)}catch{return!0}}function s0(i){var r=os(i,1);r!==null&&Ri(r,i,1,-1)}function r0(i){var r=Gi();return typeof i=="function"&&(i=i()),r.memoizedState=r.baseState=i,i={pending:null,interleaved:null,lanes:0,dispatch:null,lastRenderedReducer:Do,lastRenderedState:i},r.queue=i,i=i.dispatch=F1.bind(null,qt,i),[r.memoizedState,i]}function Io(i,r,o,h){return i={tag:i,create:r,destroy:o,deps:h,next:null},r=qt.updateQueue,r===null?(r={lastEffect:null,stores:null},qt.updateQueue=r,r.lastEffect=i.next=i):(o=r.lastEffect,o===null?r.lastEffect=i.next=i:(h=o.next,o.next=i,i.next=h,r.lastEffect=i)),i}function a0(){return fi().memoizedState}function Jl(i,r,o,h){var m=Gi();qt.flags|=i,m.memoizedState=Io(1|r,o,void 0,h===void 0?null:h)}function ec(i,r,o,h){var m=fi();h=h===void 0?null:h;var S=void 0;if(rn!==null){var b=rn.memoizedState;if(S=b.destroy,h!==null&&Ld(h,b.deps)){m.memoizedState=Io(r,o,S,h);return}}qt.flags|=i,m.memoizedState=Io(1|r,o,S,h)}function o0(i,r){return Jl(8390656,8,i,r)}function Od(i,r){return ec(2048,8,i,r)}function l0(i,r){return ec(4,2,i,r)}function c0(i,r){return ec(4,4,i,r)}function u0(i,r){if(typeof r=="function")return i=i(),r(i),function(){r(null)};if(r!=null)return i=i(),r.current=i,function(){r.current=null}}function d0(i,r,o){return o=o!=null?o.concat([i]):null,ec(4,4,u0.bind(null,r,i),o)}function jd(){}function h0(i,r){var o=fi();r=r===void 0?null:r;var h=o.memoizedState;return h!==null&&r!==null&&Ld(r,h[1])?h[0]:(o.memoizedState=[i,r],i)}function f0(i,r){var o=fi();r=r===void 0?null:r;var h=o.memoizedState;return h!==null&&r!==null&&Ld(r,h[1])?h[0]:(i=i(),o.memoizedState=[i,r],i)}function p0(i,r,o){return(yr&21)===0?(i.baseState&&(i.baseState=!1,Bn=!0),i.memoizedState=o):(Ti(o,r)||(o=ea(),qt.lanes|=o,Sr|=o,i.baseState=!0),r)}function I1(i,r){var o=kt;kt=o!==0&&4>o?o:4,i(!0);var h=kd.transition;kd.transition={};try{i(!1),r()}finally{kt=o,kd.transition=h}}function m0(){return fi().memoizedState}function U1(i,r,o){var h=$s(i);if(o={lane:h,action:o,hasEagerState:!1,eagerState:null,next:null},g0(i))_0(r,o);else if(o=Xm(i,r,o,h),o!==null){var m=In();Ri(o,i,h,m),v0(o,r,h)}}function F1(i,r,o){var h=$s(i),m={lane:h,action:o,hasEagerState:!1,eagerState:null,next:null};if(g0(i))_0(r,m);else{var S=i.alternate;if(i.lanes===0&&(S===null||S.lanes===0)&&(S=r.lastRenderedReducer,S!==null))try{var b=r.lastRenderedState,F=S(b,o);if(m.hasEagerState=!0,m.eagerState=F,Ti(F,b)){var j=r.interleaved;j===null?(m.next=m,bd(r)):(m.next=j.next,j.next=m),r.interleaved=m;return}}catch{}finally{}o=Xm(i,r,m,h),o!==null&&(m=In(),Ri(o,i,h,m),v0(o,r,h))}}function g0(i){var r=i.alternate;return i===qt||r!==null&&r===qt}function _0(i,r){ko=Ql=!0;var o=i.pending;o===null?r.next=r:(r.next=o.next,o.next=r),i.pending=r}function v0(i,r,o){if((o&4194240)!==0){var h=r.lanes;h&=i.pendingLanes,o|=h,r.lanes=o,Bu(i,o)}}var tc={readContext:hi,useCallback:bn,useContext:bn,useEffect:bn,useImperativeHandle:bn,useInsertionEffect:bn,useLayoutEffect:bn,useMemo:bn,useReducer:bn,useRef:bn,useState:bn,useDebugValue:bn,useDeferredValue:bn,useTransition:bn,useMutableSource:bn,useSyncExternalStore:bn,useId:bn,unstable_isNewReconciler:!1},O1={readContext:hi,useCallback:function(i,r){return Gi().memoizedState=[i,r===void 0?null:r],i},useContext:hi,useEffect:o0,useImperativeHandle:function(i,r,o){return o=o!=null?o.concat([i]):null,Jl(4194308,4,u0.bind(null,r,i),o)},useLayoutEffect:function(i,r){return Jl(4194308,4,i,r)},useInsertionEffect:function(i,r){return Jl(4,2,i,r)},useMemo:function(i,r){var o=Gi();return r=r===void 0?null:r,i=i(),o.memoizedState=[i,r],i},useReducer:function(i,r,o){var h=Gi();return r=o!==void 0?o(r):r,h.memoizedState=h.baseState=r,i={pending:null,interleaved:null,lanes:0,dispatch:null,lastRenderedReducer:i,lastRenderedState:r},h.queue=i,i=i.dispatch=U1.bind(null,qt,i),[h.memoizedState,i]},useRef:function(i){var r=Gi();return i={current:i},r.memoizedState=i},useState:r0,useDebugValue:jd,useDeferredValue:function(i){return Gi().memoizedState=i},useTransition:function(){var i=r0(!1),r=i[0];return i=I1.bind(null,i[1]),Gi().memoizedState=i,[r,i]},useMutableSource:function(){},useSyncExternalStore:function(i,r,o){var h=qt,m=Gi();if(Gt){if(o===void 0)throw Error(t(407));o=o()}else{if(o=r(),pn===null)throw Error(t(349));(yr&30)!==0||e0(h,r,o)}m.memoizedState=o;var S={value:o,getSnapshot:r};return m.queue=S,o0(n0.bind(null,h,S,i),[i]),h.flags|=2048,Io(9,t0.bind(null,h,S,o,r),void 0,null),o},useId:function(){var i=Gi(),r=pn.identifierPrefix;if(Gt){var o=as,h=rs;o=(h&~(1<<32-Ve(h)-1)).toString(32)+o,r=":"+r+"R"+o,o=Lo++,0<o&&(r+="H"+o.toString(32)),r+=":"}else o=D1++,r=":"+r+"r"+o.toString(32)+":";return i.memoizedState=r},unstable_isNewReconciler:!1},j1={readContext:hi,useCallback:h0,useContext:hi,useEffect:Od,useImperativeHandle:d0,useInsertionEffect:l0,useLayoutEffect:c0,useMemo:f0,useReducer:Ud,useRef:a0,useState:function(){return Ud(Do)},useDebugValue:jd,useDeferredValue:function(i){var r=fi();return p0(r,rn.memoizedState,i)},useTransition:function(){var i=Ud(Do)[0],r=fi().memoizedState;return[i,r]},useMutableSource:Qm,useSyncExternalStore:Jm,useId:m0,unstable_isNewReconciler:!1},z1={readContext:hi,useCallback:h0,useContext:hi,useEffect:Od,useImperativeHandle:d0,useInsertionEffect:l0,useLayoutEffect:c0,useMemo:f0,useReducer:Fd,useRef:a0,useState:function(){return Fd(Do)},useDebugValue:jd,useDeferredValue:function(i){var r=fi();return rn===null?r.memoizedState=i:p0(r,rn.memoizedState,i)},useTransition:function(){var i=Fd(Do)[0],r=fi().memoizedState;return[i,r]},useMutableSource:Qm,useSyncExternalStore:Jm,useId:m0,unstable_isNewReconciler:!1};function Ai(i,r){if(i&&i.defaultProps){r=oe({},r),i=i.defaultProps;for(var o in i)r[o]===void 0&&(r[o]=i[o]);return r}return r}function zd(i,r,o,h){r=i.memoizedState,o=o(h,r),o=o==null?r:oe({},r,o),i.memoizedState=o,i.lanes===0&&(i.updateQueue.baseState=o)}var nc={isMounted:function(i){return(i=i._reactInternals)?ts(i)===i:!1},enqueueSetState:function(i,r,o){i=i._reactInternals;var h=In(),m=$s(i),S=ls(h,m);S.payload=r,o!=null&&(S.callback=o),r=Hs(i,S,m),r!==null&&(Ri(r,i,m,h),ql(r,i,m))},enqueueReplaceState:function(i,r,o){i=i._reactInternals;var h=In(),m=$s(i),S=ls(h,m);S.tag=1,S.payload=r,o!=null&&(S.callback=o),r=Hs(i,S,m),r!==null&&(Ri(r,i,m,h),ql(r,i,m))},enqueueForceUpdate:function(i,r){i=i._reactInternals;var o=In(),h=$s(i),m=ls(o,h);m.tag=2,r!=null&&(m.callback=r),r=Hs(i,m,h),r!==null&&(Ri(r,i,h,o),ql(r,i,h))}};function x0(i,r,o,h,m,S,b){return i=i.stateNode,typeof i.shouldComponentUpdate=="function"?i.shouldComponentUpdate(h,S,b):r.prototype&&r.prototype.isPureReactComponent?!So(o,h)||!So(m,S):!0}function y0(i,r,o){var h=!1,m=js,S=r.contextType;return typeof S=="object"&&S!==null?S=hi(S):(m=zn(r)?mr:Tn.current,h=r.contextTypes,S=(h=h!=null)?ua(i,m):js),r=new r(o,S),i.memoizedState=r.state!==null&&r.state!==void 0?r.state:null,r.updater=nc,i.stateNode=r,r._reactInternals=i,h&&(i=i.stateNode,i.__reactInternalMemoizedUnmaskedChildContext=m,i.__reactInternalMemoizedMaskedChildContext=S),r}function S0(i,r,o,h){i=r.state,typeof r.componentWillReceiveProps=="function"&&r.componentWillReceiveProps(o,h),typeof r.UNSAFE_componentWillReceiveProps=="function"&&r.UNSAFE_componentWillReceiveProps(o,h),r.state!==i&&nc.enqueueReplaceState(r,r.state,null)}function Bd(i,r,o,h){var m=i.stateNode;m.props=o,m.state=i.memoizedState,m.refs={},Ad(i);var S=r.contextType;typeof S=="object"&&S!==null?m.context=hi(S):(S=zn(r)?mr:Tn.current,m.context=ua(i,S)),m.state=i.memoizedState,S=r.getDerivedStateFromProps,typeof S=="function"&&(zd(i,r,S,o),m.state=i.memoizedState),typeof r.getDerivedStateFromProps=="function"||typeof m.getSnapshotBeforeUpdate=="function"||typeof m.UNSAFE_componentWillMount!="function"&&typeof m.componentWillMount!="function"||(r=m.state,typeof m.componentWillMount=="function"&&m.componentWillMount(),typeof m.UNSAFE_componentWillMount=="function"&&m.UNSAFE_componentWillMount(),r!==m.state&&nc.enqueueReplaceState(m,m.state,null),Yl(i,o,m,h),m.state=i.memoizedState),typeof m.componentDidMount=="function"&&(i.flags|=4194308)}function va(i,r){try{var o="",h=r;do o+=fe(h),h=h.return;while(h);var m=o}catch(S){m=`
Error generating stack: `+S.message+`
`+S.stack}return{value:i,source:r,stack:m,digest:null}}function Hd(i,r,o){return{value:i,source:null,stack:o??null,digest:r??null}}function Vd(i,r){try{console.error(r.value)}catch(o){setTimeout(function(){throw o})}}var B1=typeof WeakMap=="function"?WeakMap:Map;function M0(i,r,o){o=ls(-1,o),o.tag=3,o.payload={element:null};var h=r.value;return o.callback=function(){cc||(cc=!0,sh=h),Vd(i,r)},o}function E0(i,r,o){o=ls(-1,o),o.tag=3;var h=i.type.getDerivedStateFromError;if(typeof h=="function"){var m=r.value;o.payload=function(){return h(m)},o.callback=function(){Vd(i,r)}}var S=i.stateNode;return S!==null&&typeof S.componentDidCatch=="function"&&(o.callback=function(){Vd(i,r),typeof h!="function"&&(Gs===null?Gs=new Set([this]):Gs.add(this));var b=r.stack;this.componentDidCatch(r.value,{componentStack:b!==null?b:""})}),o}function w0(i,r,o){var h=i.pingCache;if(h===null){h=i.pingCache=new B1;var m=new Set;h.set(r,m)}else m=h.get(r),m===void 0&&(m=new Set,h.set(r,m));m.has(o)||(m.add(o),i=ty.bind(null,i,r,o),r.then(i,i))}function T0(i){do{var r;if((r=i.tag===13)&&(r=i.memoizedState,r=r!==null?r.dehydrated!==null:!0),r)return i;i=i.return}while(i!==null);return null}function b0(i,r,o,h,m){return(i.mode&1)===0?(i===r?i.flags|=65536:(i.flags|=128,o.flags|=131072,o.flags&=-52805,o.tag===1&&(o.alternate===null?o.tag=17:(r=ls(-1,1),r.tag=2,Hs(o,r,1))),o.lanes|=1),i):(i.flags|=65536,i.lanes=m,i)}var H1=R.ReactCurrentOwner,Bn=!1;function Dn(i,r,o,h){r.child=i===null?$m(r,null,o,h):pa(r,i.child,o,h)}function A0(i,r,o,h,m){o=o.render;var S=r.ref;return ga(r,m),h=Dd(i,r,o,h,S,m),o=Id(),i!==null&&!Bn?(r.updateQueue=i.updateQueue,r.flags&=-2053,i.lanes&=~m,cs(i,r,m)):(Gt&&o&&_d(r),r.flags|=1,Dn(i,r,h,m),r.child)}function C0(i,r,o,h,m){if(i===null){var S=o.type;return typeof S=="function"&&!dh(S)&&S.defaultProps===void 0&&o.compare===null&&o.defaultProps===void 0?(r.tag=15,r.type=S,N0(i,r,S,h,m)):(i=mc(o.type,null,h,r,r.mode,m),i.ref=r.ref,i.return=r,r.child=i)}if(S=i.child,(i.lanes&m)===0){var b=S.memoizedProps;if(o=o.compare,o=o!==null?o:So,o(b,h)&&i.ref===r.ref)return cs(i,r,m)}return r.flags|=1,i=qs(S,h),i.ref=r.ref,i.return=r,r.child=i}function N0(i,r,o,h,m){if(i!==null){var S=i.memoizedProps;if(So(S,h)&&i.ref===r.ref)if(Bn=!1,r.pendingProps=h=S,(i.lanes&m)!==0)(i.flags&131072)!==0&&(Bn=!0);else return r.lanes=i.lanes,cs(i,r,m)}return Gd(i,r,o,h,m)}function R0(i,r,o){var h=r.pendingProps,m=h.children,S=i!==null?i.memoizedState:null;if(h.mode==="hidden")if((r.mode&1)===0)r.memoizedState={baseLanes:0,cachePool:null,transitions:null},Ft(ya,ni),ni|=o;else{if((o&1073741824)===0)return i=S!==null?S.baseLanes|o:o,r.lanes=r.childLanes=1073741824,r.memoizedState={baseLanes:i,cachePool:null,transitions:null},r.updateQueue=null,Ft(ya,ni),ni|=i,null;r.memoizedState={baseLanes:0,cachePool:null,transitions:null},h=S!==null?S.baseLanes:o,Ft(ya,ni),ni|=h}else S!==null?(h=S.baseLanes|o,r.memoizedState=null):h=o,Ft(ya,ni),ni|=h;return Dn(i,r,m,o),r.child}function P0(i,r){var o=r.ref;(i===null&&o!==null||i!==null&&i.ref!==o)&&(r.flags|=512,r.flags|=2097152)}function Gd(i,r,o,h,m){var S=zn(o)?mr:Tn.current;return S=ua(r,S),ga(r,m),o=Dd(i,r,o,h,S,m),h=Id(),i!==null&&!Bn?(r.updateQueue=i.updateQueue,r.flags&=-2053,i.lanes&=~m,cs(i,r,m)):(Gt&&h&&_d(r),r.flags|=1,Dn(i,r,o,m),r.child)}function k0(i,r,o,h,m){if(zn(o)){var S=!0;zl(r)}else S=!1;if(ga(r,m),r.stateNode===null)sc(i,r),y0(r,o,h),Bd(r,o,h,m),h=!0;else if(i===null){var b=r.stateNode,F=r.memoizedProps;b.props=F;var j=b.context,ie=o.contextType;typeof ie=="object"&&ie!==null?ie=hi(ie):(ie=zn(o)?mr:Tn.current,ie=ua(r,ie));var ye=o.getDerivedStateFromProps,Ee=typeof ye=="function"||typeof b.getSnapshotBeforeUpdate=="function";Ee||typeof b.UNSAFE_componentWillReceiveProps!="function"&&typeof b.componentWillReceiveProps!="function"||(F!==h||j!==ie)&&S0(r,b,h,ie),Bs=!1;var xe=r.memoizedState;b.state=xe,Yl(r,h,b,m),j=r.memoizedState,F!==h||xe!==j||jn.current||Bs?(typeof ye=="function"&&(zd(r,o,ye,h),j=r.memoizedState),(F=Bs||x0(r,o,F,h,xe,j,ie))?(Ee||typeof b.UNSAFE_componentWillMount!="function"&&typeof b.componentWillMount!="function"||(typeof b.componentWillMount=="function"&&b.componentWillMount(),typeof b.UNSAFE_componentWillMount=="function"&&b.UNSAFE_componentWillMount()),typeof b.componentDidMount=="function"&&(r.flags|=4194308)):(typeof b.componentDidMount=="function"&&(r.flags|=4194308),r.memoizedProps=h,r.memoizedState=j),b.props=h,b.state=j,b.context=ie,h=F):(typeof b.componentDidMount=="function"&&(r.flags|=4194308),h=!1)}else{b=r.stateNode,qm(i,r),F=r.memoizedProps,ie=r.type===r.elementType?F:Ai(r.type,F),b.props=ie,Ee=r.pendingProps,xe=b.context,j=o.contextType,typeof j=="object"&&j!==null?j=hi(j):(j=zn(o)?mr:Tn.current,j=ua(r,j));var ze=o.getDerivedStateFromProps;(ye=typeof ze=="function"||typeof b.getSnapshotBeforeUpdate=="function")||typeof b.UNSAFE_componentWillReceiveProps!="function"&&typeof b.componentWillReceiveProps!="function"||(F!==Ee||xe!==j)&&S0(r,b,h,j),Bs=!1,xe=r.memoizedState,b.state=xe,Yl(r,h,b,m);var $e=r.memoizedState;F!==Ee||xe!==$e||jn.current||Bs?(typeof ze=="function"&&(zd(r,o,ze,h),$e=r.memoizedState),(ie=Bs||x0(r,o,ie,h,xe,$e,j)||!1)?(ye||typeof b.UNSAFE_componentWillUpdate!="function"&&typeof b.componentWillUpdate!="function"||(typeof b.componentWillUpdate=="function"&&b.componentWillUpdate(h,$e,j),typeof b.UNSAFE_componentWillUpdate=="function"&&b.UNSAFE_componentWillUpdate(h,$e,j)),typeof b.componentDidUpdate=="function"&&(r.flags|=4),typeof b.getSnapshotBeforeUpdate=="function"&&(r.flags|=1024)):(typeof b.componentDidUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(r.flags|=4),typeof b.getSnapshotBeforeUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(r.flags|=1024),r.memoizedProps=h,r.memoizedState=$e),b.props=h,b.state=$e,b.context=j,h=ie):(typeof b.componentDidUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(r.flags|=4),typeof b.getSnapshotBeforeUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(r.flags|=1024),h=!1)}return Wd(i,r,o,h,S,m)}function Wd(i,r,o,h,m,S){P0(i,r);var b=(r.flags&128)!==0;if(!h&&!b)return m&&Fm(r,o,!1),cs(i,r,S);h=r.stateNode,H1.current=r;var F=b&&typeof o.getDerivedStateFromError!="function"?null:h.render();return r.flags|=1,i!==null&&b?(r.child=pa(r,i.child,null,S),r.child=pa(r,null,F,S)):Dn(i,r,F,S),r.memoizedState=h.state,m&&Fm(r,o,!0),r.child}function L0(i){var r=i.stateNode;r.pendingContext?Im(i,r.pendingContext,r.pendingContext!==r.context):r.context&&Im(i,r.context,!1),Cd(i,r.containerInfo)}function D0(i,r,o,h,m){return fa(),Sd(m),r.flags|=256,Dn(i,r,o,h),r.child}var $d={dehydrated:null,treeContext:null,retryLane:0};function Xd(i){return{baseLanes:i,cachePool:null,transitions:null}}function I0(i,r,o){var h=r.pendingProps,m=Xt.current,S=!1,b=(r.flags&128)!==0,F;if((F=b)||(F=i!==null&&i.memoizedState===null?!1:(m&2)!==0),F?(S=!0,r.flags&=-129):(i===null||i.memoizedState!==null)&&(m|=1),Ft(Xt,m&1),i===null)return yd(r),i=r.memoizedState,i!==null&&(i=i.dehydrated,i!==null)?((r.mode&1)===0?r.lanes=1:i.data==="$!"?r.lanes=8:r.lanes=1073741824,null):(b=h.children,i=h.fallback,S?(h=r.mode,S=r.child,b={mode:"hidden",children:b},(h&1)===0&&S!==null?(S.childLanes=0,S.pendingProps=b):S=gc(b,h,0,null),i=Tr(i,h,o,null),S.return=r,i.return=r,S.sibling=i,r.child=S,r.child.memoizedState=Xd(o),r.memoizedState=$d,i):qd(r,b));if(m=i.memoizedState,m!==null&&(F=m.dehydrated,F!==null))return V1(i,r,b,h,F,m,o);if(S){S=h.fallback,b=r.mode,m=i.child,F=m.sibling;var j={mode:"hidden",children:h.children};return(b&1)===0&&r.child!==m?(h=r.child,h.childLanes=0,h.pendingProps=j,r.deletions=null):(h=qs(m,j),h.subtreeFlags=m.subtreeFlags&14680064),F!==null?S=qs(F,S):(S=Tr(S,b,o,null),S.flags|=2),S.return=r,h.return=r,h.sibling=S,r.child=h,h=S,S=r.child,b=i.child.memoizedState,b=b===null?Xd(o):{baseLanes:b.baseLanes|o,cachePool:null,transitions:b.transitions},S.memoizedState=b,S.childLanes=i.childLanes&~o,r.memoizedState=$d,h}return S=i.child,i=S.sibling,h=qs(S,{mode:"visible",children:h.children}),(r.mode&1)===0&&(h.lanes=o),h.return=r,h.sibling=null,i!==null&&(o=r.deletions,o===null?(r.deletions=[i],r.flags|=16):o.push(i)),r.child=h,r.memoizedState=null,h}function qd(i,r){return r=gc({mode:"visible",children:r},i.mode,0,null),r.return=i,i.child=r}function ic(i,r,o,h){return h!==null&&Sd(h),pa(r,i.child,null,o),i=qd(r,r.pendingProps.children),i.flags|=2,r.memoizedState=null,i}function V1(i,r,o,h,m,S,b){if(o)return r.flags&256?(r.flags&=-257,h=Hd(Error(t(422))),ic(i,r,b,h)):r.memoizedState!==null?(r.child=i.child,r.flags|=128,null):(S=h.fallback,m=r.mode,h=gc({mode:"visible",children:h.children},m,0,null),S=Tr(S,m,b,null),S.flags|=2,h.return=r,S.return=r,h.sibling=S,r.child=h,(r.mode&1)!==0&&pa(r,i.child,null,b),r.child.memoizedState=Xd(b),r.memoizedState=$d,S);if((r.mode&1)===0)return ic(i,r,b,null);if(m.data==="$!"){if(h=m.nextSibling&&m.nextSibling.dataset,h)var F=h.dgst;return h=F,S=Error(t(419)),h=Hd(S,h,void 0),ic(i,r,b,h)}if(F=(b&i.childLanes)!==0,Bn||F){if(h=pn,h!==null){switch(b&-b){case 4:m=2;break;case 16:m=8;break;case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:m=32;break;case 536870912:m=268435456;break;default:m=0}m=(m&(h.suspendedLanes|b))!==0?0:m,m!==0&&m!==S.retryLane&&(S.retryLane=m,os(i,m),Ri(h,i,m,-1))}return uh(),h=Hd(Error(t(421))),ic(i,r,b,h)}return m.data==="$?"?(r.flags|=128,r.child=i.child,r=ny.bind(null,i),m._reactRetry=r,null):(i=S.treeContext,ti=Fs(m.nextSibling),ei=r,Gt=!0,bi=null,i!==null&&(ui[di++]=rs,ui[di++]=as,ui[di++]=gr,rs=i.id,as=i.overflow,gr=r),r=qd(r,h.children),r.flags|=4096,r)}function U0(i,r,o){i.lanes|=r;var h=i.alternate;h!==null&&(h.lanes|=r),Td(i.return,r,o)}function Yd(i,r,o,h,m){var S=i.memoizedState;S===null?i.memoizedState={isBackwards:r,rendering:null,renderingStartTime:0,last:h,tail:o,tailMode:m}:(S.isBackwards=r,S.rendering=null,S.renderingStartTime=0,S.last=h,S.tail=o,S.tailMode=m)}function F0(i,r,o){var h=r.pendingProps,m=h.revealOrder,S=h.tail;if(Dn(i,r,h.children,o),h=Xt.current,(h&2)!==0)h=h&1|2,r.flags|=128;else{if(i!==null&&(i.flags&128)!==0)e:for(i=r.child;i!==null;){if(i.tag===13)i.memoizedState!==null&&U0(i,o,r);else if(i.tag===19)U0(i,o,r);else if(i.child!==null){i.child.return=i,i=i.child;continue}if(i===r)break e;for(;i.sibling===null;){if(i.return===null||i.return===r)break e;i=i.return}i.sibling.return=i.return,i=i.sibling}h&=1}if(Ft(Xt,h),(r.mode&1)===0)r.memoizedState=null;else switch(m){case"forwards":for(o=r.child,m=null;o!==null;)i=o.alternate,i!==null&&Kl(i)===null&&(m=o),o=o.sibling;o=m,o===null?(m=r.child,r.child=null):(m=o.sibling,o.sibling=null),Yd(r,!1,m,o,S);break;case"backwards":for(o=null,m=r.child,r.child=null;m!==null;){if(i=m.alternate,i!==null&&Kl(i)===null){r.child=m;break}i=m.sibling,m.sibling=o,o=m,m=i}Yd(r,!0,o,null,S);break;case"together":Yd(r,!1,null,null,void 0);break;default:r.memoizedState=null}return r.child}function sc(i,r){(r.mode&1)===0&&i!==null&&(i.alternate=null,r.alternate=null,r.flags|=2)}function cs(i,r,o){if(i!==null&&(r.dependencies=i.dependencies),Sr|=r.lanes,(o&r.childLanes)===0)return null;if(i!==null&&r.child!==i.child)throw Error(t(153));if(r.child!==null){for(i=r.child,o=qs(i,i.pendingProps),r.child=o,o.return=r;i.sibling!==null;)i=i.sibling,o=o.sibling=qs(i,i.pendingProps),o.return=r;o.sibling=null}return r.child}function G1(i,r,o){switch(r.tag){case 3:L0(r),fa();break;case 5:Zm(r);break;case 1:zn(r.type)&&zl(r);break;case 4:Cd(r,r.stateNode.containerInfo);break;case 10:var h=r.type._context,m=r.memoizedProps.value;Ft($l,h._currentValue),h._currentValue=m;break;case 13:if(h=r.memoizedState,h!==null)return h.dehydrated!==null?(Ft(Xt,Xt.current&1),r.flags|=128,null):(o&r.child.childLanes)!==0?I0(i,r,o):(Ft(Xt,Xt.current&1),i=cs(i,r,o),i!==null?i.sibling:null);Ft(Xt,Xt.current&1);break;case 19:if(h=(o&r.childLanes)!==0,(i.flags&128)!==0){if(h)return F0(i,r,o);r.flags|=128}if(m=r.memoizedState,m!==null&&(m.rendering=null,m.tail=null,m.lastEffect=null),Ft(Xt,Xt.current),h)break;return null;case 22:case 23:return r.lanes=0,R0(i,r,o)}return cs(i,r,o)}var O0,Kd,j0,z0;O0=function(i,r){for(var o=r.child;o!==null;){if(o.tag===5||o.tag===6)i.appendChild(o.stateNode);else if(o.tag!==4&&o.child!==null){o.child.return=o,o=o.child;continue}if(o===r)break;for(;o.sibling===null;){if(o.return===null||o.return===r)return;o=o.return}o.sibling.return=o.return,o=o.sibling}},Kd=function(){},j0=function(i,r,o,h){var m=i.memoizedProps;if(m!==h){i=r.stateNode,xr(Vi.current);var S=null;switch(o){case"input":m=_n(i,m),h=_n(i,h),S=[];break;case"select":m=oe({},m,{value:void 0}),h=oe({},h,{value:void 0}),S=[];break;case"textarea":m=Q(i,m),h=Q(i,h),S=[];break;default:typeof m.onClick!="function"&&typeof h.onClick=="function"&&(i.onclick=Fl)}lt(o,h);var b;o=null;for(ie in m)if(!h.hasOwnProperty(ie)&&m.hasOwnProperty(ie)&&m[ie]!=null)if(ie==="style"){var F=m[ie];for(b in F)F.hasOwnProperty(b)&&(o||(o={}),o[b]="")}else ie!=="dangerouslySetInnerHTML"&&ie!=="children"&&ie!=="suppressContentEditableWarning"&&ie!=="suppressHydrationWarning"&&ie!=="autoFocus"&&(a.hasOwnProperty(ie)?S||(S=[]):(S=S||[]).push(ie,null));for(ie in h){var j=h[ie];if(F=m?.[ie],h.hasOwnProperty(ie)&&j!==F&&(j!=null||F!=null))if(ie==="style")if(F){for(b in F)!F.hasOwnProperty(b)||j&&j.hasOwnProperty(b)||(o||(o={}),o[b]="");for(b in j)j.hasOwnProperty(b)&&F[b]!==j[b]&&(o||(o={}),o[b]=j[b])}else o||(S||(S=[]),S.push(ie,o)),o=j;else ie==="dangerouslySetInnerHTML"?(j=j?j.__html:void 0,F=F?F.__html:void 0,j!=null&&F!==j&&(S=S||[]).push(ie,j)):ie==="children"?typeof j!="string"&&typeof j!="number"||(S=S||[]).push(ie,""+j):ie!=="suppressContentEditableWarning"&&ie!=="suppressHydrationWarning"&&(a.hasOwnProperty(ie)?(j!=null&&ie==="onScroll"&&jt("scroll",i),S||F===j||(S=[])):(S=S||[]).push(ie,j))}o&&(S=S||[]).push("style",o);var ie=S;(r.updateQueue=ie)&&(r.flags|=4)}},z0=function(i,r,o,h){o!==h&&(r.flags|=4)};function Uo(i,r){if(!Gt)switch(i.tailMode){case"hidden":r=i.tail;for(var o=null;r!==null;)r.alternate!==null&&(o=r),r=r.sibling;o===null?i.tail=null:o.sibling=null;break;case"collapsed":o=i.tail;for(var h=null;o!==null;)o.alternate!==null&&(h=o),o=o.sibling;h===null?r||i.tail===null?i.tail=null:i.tail.sibling=null:h.sibling=null}}function An(i){var r=i.alternate!==null&&i.alternate.child===i.child,o=0,h=0;if(r)for(var m=i.child;m!==null;)o|=m.lanes|m.childLanes,h|=m.subtreeFlags&14680064,h|=m.flags&14680064,m.return=i,m=m.sibling;else for(m=i.child;m!==null;)o|=m.lanes|m.childLanes,h|=m.subtreeFlags,h|=m.flags,m.return=i,m=m.sibling;return i.subtreeFlags|=h,i.childLanes=o,r}function W1(i,r,o){var h=r.pendingProps;switch(vd(r),r.tag){case 2:case 16:case 15:case 0:case 11:case 7:case 8:case 12:case 9:case 14:return An(r),null;case 1:return zn(r.type)&&jl(),An(r),null;case 3:return h=r.stateNode,_a(),zt(jn),zt(Tn),Pd(),h.pendingContext&&(h.context=h.pendingContext,h.pendingContext=null),(i===null||i.child===null)&&(Gl(r)?r.flags|=4:i===null||i.memoizedState.isDehydrated&&(r.flags&256)===0||(r.flags|=1024,bi!==null&&(oh(bi),bi=null))),Kd(i,r),An(r),null;case 5:Nd(r);var m=xr(Po.current);if(o=r.type,i!==null&&r.stateNode!=null)j0(i,r,o,h,m),i.ref!==r.ref&&(r.flags|=512,r.flags|=2097152);else{if(!h){if(r.stateNode===null)throw Error(t(166));return An(r),null}if(i=xr(Vi.current),Gl(r)){h=r.stateNode,o=r.type;var S=r.memoizedProps;switch(h[Hi]=r,h[bo]=S,i=(r.mode&1)!==0,o){case"dialog":jt("cancel",h),jt("close",h);break;case"iframe":case"object":case"embed":jt("load",h);break;case"video":case"audio":for(m=0;m<Eo.length;m++)jt(Eo[m],h);break;case"source":jt("error",h);break;case"img":case"image":case"link":jt("error",h),jt("load",h);break;case"details":jt("toggle",h);break;case"input":ft(h,S),jt("invalid",h);break;case"select":h._wrapperState={wasMultiple:!!S.multiple},jt("invalid",h);break;case"textarea":me(h,S),jt("invalid",h)}lt(o,S),m=null;for(var b in S)if(S.hasOwnProperty(b)){var F=S[b];b==="children"?typeof F=="string"?h.textContent!==F&&(S.suppressHydrationWarning!==!0&&Ul(h.textContent,F,i),m=["children",F]):typeof F=="number"&&h.textContent!==""+F&&(S.suppressHydrationWarning!==!0&&Ul(h.textContent,F,i),m=["children",""+F]):a.hasOwnProperty(b)&&F!=null&&b==="onScroll"&&jt("scroll",h)}switch(o){case"input":yt(h),Lt(h,S,!0);break;case"textarea":yt(h),pe(h);break;case"select":case"option":break;default:typeof S.onClick=="function"&&(h.onclick=Fl)}h=m,r.updateQueue=h,h!==null&&(r.flags|=4)}else{b=m.nodeType===9?m:m.ownerDocument,i==="http://www.w3.org/1999/xhtml"&&(i=Ze(o)),i==="http://www.w3.org/1999/xhtml"?o==="script"?(i=b.createElement("div"),i.innerHTML="<script><\/script>",i=i.removeChild(i.firstChild)):typeof h.is=="string"?i=b.createElement(o,{is:h.is}):(i=b.createElement(o),o==="select"&&(b=i,h.multiple?b.multiple=!0:h.size&&(b.size=h.size))):i=b.createElementNS(i,o),i[Hi]=r,i[bo]=h,O0(i,r,!1,!1),r.stateNode=i;e:{switch(b=Ct(o,h),o){case"dialog":jt("cancel",i),jt("close",i),m=h;break;case"iframe":case"object":case"embed":jt("load",i),m=h;break;case"video":case"audio":for(m=0;m<Eo.length;m++)jt(Eo[m],i);m=h;break;case"source":jt("error",i),m=h;break;case"img":case"image":case"link":jt("error",i),jt("load",i),m=h;break;case"details":jt("toggle",i),m=h;break;case"input":ft(i,h),m=_n(i,h),jt("invalid",i);break;case"option":m=h;break;case"select":i._wrapperState={wasMultiple:!!h.multiple},m=oe({},h,{value:void 0}),jt("invalid",i);break;case"textarea":me(i,h),m=Q(i,h),jt("invalid",i);break;default:m=h}lt(o,m),F=m;for(S in F)if(F.hasOwnProperty(S)){var j=F[S];S==="style"?Ge(i,j):S==="dangerouslySetInnerHTML"?(j=j?j.__html:void 0,j!=null&&vt(i,j)):S==="children"?typeof j=="string"?(o!=="textarea"||j!=="")&&Ce(i,j):typeof j=="number"&&Ce(i,""+j):S!=="suppressContentEditableWarning"&&S!=="suppressHydrationWarning"&&S!=="autoFocus"&&(a.hasOwnProperty(S)?j!=null&&S==="onScroll"&&jt("scroll",i):j!=null&&A(i,S,j,b))}switch(o){case"input":yt(i),Lt(i,h,!1);break;case"textarea":yt(i),pe(i);break;case"option":h.value!=null&&i.setAttribute("value",""+Ie(h.value));break;case"select":i.multiple=!!h.multiple,S=h.value,S!=null?C(i,!!h.multiple,S,!1):h.defaultValue!=null&&C(i,!!h.multiple,h.defaultValue,!0);break;default:typeof m.onClick=="function"&&(i.onclick=Fl)}switch(o){case"button":case"input":case"select":case"textarea":h=!!h.autoFocus;break e;case"img":h=!0;break e;default:h=!1}}h&&(r.flags|=4)}r.ref!==null&&(r.flags|=512,r.flags|=2097152)}return An(r),null;case 6:if(i&&r.stateNode!=null)z0(i,r,i.memoizedProps,h);else{if(typeof h!="string"&&r.stateNode===null)throw Error(t(166));if(o=xr(Po.current),xr(Vi.current),Gl(r)){if(h=r.stateNode,o=r.memoizedProps,h[Hi]=r,(S=h.nodeValue!==o)&&(i=ei,i!==null))switch(i.tag){case 3:Ul(h.nodeValue,o,(i.mode&1)!==0);break;case 5:i.memoizedProps.suppressHydrationWarning!==!0&&Ul(h.nodeValue,o,(i.mode&1)!==0)}S&&(r.flags|=4)}else h=(o.nodeType===9?o:o.ownerDocument).createTextNode(h),h[Hi]=r,r.stateNode=h}return An(r),null;case 13:if(zt(Xt),h=r.memoizedState,i===null||i.memoizedState!==null&&i.memoizedState.dehydrated!==null){if(Gt&&ti!==null&&(r.mode&1)!==0&&(r.flags&128)===0)Vm(),fa(),r.flags|=98560,S=!1;else if(S=Gl(r),h!==null&&h.dehydrated!==null){if(i===null){if(!S)throw Error(t(318));if(S=r.memoizedState,S=S!==null?S.dehydrated:null,!S)throw Error(t(317));S[Hi]=r}else fa(),(r.flags&128)===0&&(r.memoizedState=null),r.flags|=4;An(r),S=!1}else bi!==null&&(oh(bi),bi=null),S=!0;if(!S)return r.flags&65536?r:null}return(r.flags&128)!==0?(r.lanes=o,r):(h=h!==null,h!==(i!==null&&i.memoizedState!==null)&&h&&(r.child.flags|=8192,(r.mode&1)!==0&&(i===null||(Xt.current&1)!==0?an===0&&(an=3):uh())),r.updateQueue!==null&&(r.flags|=4),An(r),null);case 4:return _a(),Kd(i,r),i===null&&wo(r.stateNode.containerInfo),An(r),null;case 10:return wd(r.type._context),An(r),null;case 17:return zn(r.type)&&jl(),An(r),null;case 19:if(zt(Xt),S=r.memoizedState,S===null)return An(r),null;if(h=(r.flags&128)!==0,b=S.rendering,b===null)if(h)Uo(S,!1);else{if(an!==0||i!==null&&(i.flags&128)!==0)for(i=r.child;i!==null;){if(b=Kl(i),b!==null){for(r.flags|=128,Uo(S,!1),h=b.updateQueue,h!==null&&(r.updateQueue=h,r.flags|=4),r.subtreeFlags=0,h=o,o=r.child;o!==null;)S=o,i=h,S.flags&=14680066,b=S.alternate,b===null?(S.childLanes=0,S.lanes=i,S.child=null,S.subtreeFlags=0,S.memoizedProps=null,S.memoizedState=null,S.updateQueue=null,S.dependencies=null,S.stateNode=null):(S.childLanes=b.childLanes,S.lanes=b.lanes,S.child=b.child,S.subtreeFlags=0,S.deletions=null,S.memoizedProps=b.memoizedProps,S.memoizedState=b.memoizedState,S.updateQueue=b.updateQueue,S.type=b.type,i=b.dependencies,S.dependencies=i===null?null:{lanes:i.lanes,firstContext:i.firstContext}),o=o.sibling;return Ft(Xt,Xt.current&1|2),r.child}i=i.sibling}S.tail!==null&&Pe()>Sa&&(r.flags|=128,h=!0,Uo(S,!1),r.lanes=4194304)}else{if(!h)if(i=Kl(b),i!==null){if(r.flags|=128,h=!0,o=i.updateQueue,o!==null&&(r.updateQueue=o,r.flags|=4),Uo(S,!0),S.tail===null&&S.tailMode==="hidden"&&!b.alternate&&!Gt)return An(r),null}else 2*Pe()-S.renderingStartTime>Sa&&o!==1073741824&&(r.flags|=128,h=!0,Uo(S,!1),r.lanes=4194304);S.isBackwards?(b.sibling=r.child,r.child=b):(o=S.last,o!==null?o.sibling=b:r.child=b,S.last=b)}return S.tail!==null?(r=S.tail,S.rendering=r,S.tail=r.sibling,S.renderingStartTime=Pe(),r.sibling=null,o=Xt.current,Ft(Xt,h?o&1|2:o&1),r):(An(r),null);case 22:case 23:return ch(),h=r.memoizedState!==null,i!==null&&i.memoizedState!==null!==h&&(r.flags|=8192),h&&(r.mode&1)!==0?(ni&1073741824)!==0&&(An(r),r.subtreeFlags&6&&(r.flags|=8192)):An(r),null;case 24:return null;case 25:return null}throw Error(t(156,r.tag))}function $1(i,r){switch(vd(r),r.tag){case 1:return zn(r.type)&&jl(),i=r.flags,i&65536?(r.flags=i&-65537|128,r):null;case 3:return _a(),zt(jn),zt(Tn),Pd(),i=r.flags,(i&65536)!==0&&(i&128)===0?(r.flags=i&-65537|128,r):null;case 5:return Nd(r),null;case 13:if(zt(Xt),i=r.memoizedState,i!==null&&i.dehydrated!==null){if(r.alternate===null)throw Error(t(340));fa()}return i=r.flags,i&65536?(r.flags=i&-65537|128,r):null;case 19:return zt(Xt),null;case 4:return _a(),null;case 10:return wd(r.type._context),null;case 22:case 23:return ch(),null;case 24:return null;default:return null}}var rc=!1,Cn=!1,X1=typeof WeakSet=="function"?WeakSet:Set,We=null;function xa(i,r){var o=i.ref;if(o!==null)if(typeof o=="function")try{o(null)}catch(h){Yt(i,r,h)}else o.current=null}function Zd(i,r,o){try{o()}catch(h){Yt(i,r,h)}}var B0=!1;function q1(i,r){if(cd=Tl,i=xm(),td(i)){if("selectionStart"in i)var o={start:i.selectionStart,end:i.selectionEnd};else e:{o=(o=i.ownerDocument)&&o.defaultView||window;var h=o.getSelection&&o.getSelection();if(h&&h.rangeCount!==0){o=h.anchorNode;var m=h.anchorOffset,S=h.focusNode;h=h.focusOffset;try{o.nodeType,S.nodeType}catch{o=null;break e}var b=0,F=-1,j=-1,ie=0,ye=0,Ee=i,xe=null;t:for(;;){for(var ze;Ee!==o||m!==0&&Ee.nodeType!==3||(F=b+m),Ee!==S||h!==0&&Ee.nodeType!==3||(j=b+h),Ee.nodeType===3&&(b+=Ee.nodeValue.length),(ze=Ee.firstChild)!==null;)xe=Ee,Ee=ze;for(;;){if(Ee===i)break t;if(xe===o&&++ie===m&&(F=b),xe===S&&++ye===h&&(j=b),(ze=Ee.nextSibling)!==null)break;Ee=xe,xe=Ee.parentNode}Ee=ze}o=F===-1||j===-1?null:{start:F,end:j}}else o=null}o=o||{start:0,end:0}}else o=null;for(ud={focusedElem:i,selectionRange:o},Tl=!1,We=r;We!==null;)if(r=We,i=r.child,(r.subtreeFlags&1028)!==0&&i!==null)i.return=r,We=i;else for(;We!==null;){r=We;try{var $e=r.alternate;if((r.flags&1024)!==0)switch(r.tag){case 0:case 11:case 15:break;case 1:if($e!==null){var Xe=$e.memoizedProps,Kt=$e.memoizedState,Y=r.stateNode,H=Y.getSnapshotBeforeUpdate(r.elementType===r.type?Xe:Ai(r.type,Xe),Kt);Y.__reactInternalSnapshotBeforeUpdate=H}break;case 3:var Z=r.stateNode.containerInfo;Z.nodeType===1?Z.textContent="":Z.nodeType===9&&Z.documentElement&&Z.removeChild(Z.documentElement);break;case 5:case 6:case 4:case 17:break;default:throw Error(t(163))}}catch(Ne){Yt(r,r.return,Ne)}if(i=r.sibling,i!==null){i.return=r.return,We=i;break}We=r.return}return $e=B0,B0=!1,$e}function Fo(i,r,o){var h=r.updateQueue;if(h=h!==null?h.lastEffect:null,h!==null){var m=h=h.next;do{if((m.tag&i)===i){var S=m.destroy;m.destroy=void 0,S!==void 0&&Zd(r,o,S)}m=m.next}while(m!==h)}}function ac(i,r){if(r=r.updateQueue,r=r!==null?r.lastEffect:null,r!==null){var o=r=r.next;do{if((o.tag&i)===i){var h=o.create;o.destroy=h()}o=o.next}while(o!==r)}}function Qd(i){var r=i.ref;if(r!==null){var o=i.stateNode;switch(i.tag){case 5:i=o;break;default:i=o}typeof r=="function"?r(i):r.current=i}}function H0(i){var r=i.alternate;r!==null&&(i.alternate=null,H0(r)),i.child=null,i.deletions=null,i.sibling=null,i.tag===5&&(r=i.stateNode,r!==null&&(delete r[Hi],delete r[bo],delete r[pd],delete r[R1],delete r[P1])),i.stateNode=null,i.return=null,i.dependencies=null,i.memoizedProps=null,i.memoizedState=null,i.pendingProps=null,i.stateNode=null,i.updateQueue=null}function V0(i){return i.tag===5||i.tag===3||i.tag===4}function G0(i){e:for(;;){for(;i.sibling===null;){if(i.return===null||V0(i.return))return null;i=i.return}for(i.sibling.return=i.return,i=i.sibling;i.tag!==5&&i.tag!==6&&i.tag!==18;){if(i.flags&2||i.child===null||i.tag===4)continue e;i.child.return=i,i=i.child}if(!(i.flags&2))return i.stateNode}}function Jd(i,r,o){var h=i.tag;if(h===5||h===6)i=i.stateNode,r?o.nodeType===8?o.parentNode.insertBefore(i,r):o.insertBefore(i,r):(o.nodeType===8?(r=o.parentNode,r.insertBefore(i,o)):(r=o,r.appendChild(i)),o=o._reactRootContainer,o!=null||r.onclick!==null||(r.onclick=Fl));else if(h!==4&&(i=i.child,i!==null))for(Jd(i,r,o),i=i.sibling;i!==null;)Jd(i,r,o),i=i.sibling}function eh(i,r,o){var h=i.tag;if(h===5||h===6)i=i.stateNode,r?o.insertBefore(i,r):o.appendChild(i);else if(h!==4&&(i=i.child,i!==null))for(eh(i,r,o),i=i.sibling;i!==null;)eh(i,r,o),i=i.sibling}var xn=null,Ci=!1;function Vs(i,r,o){for(o=o.child;o!==null;)W0(i,r,o),o=o.sibling}function W0(i,r,o){if(Vt&&typeof Vt.onCommitFiberUnmount=="function")try{Vt.onCommitFiberUnmount(It,o)}catch{}switch(o.tag){case 5:Cn||xa(o,r);case 6:var h=xn,m=Ci;xn=null,Vs(i,r,o),xn=h,Ci=m,xn!==null&&(Ci?(i=xn,o=o.stateNode,i.nodeType===8?i.parentNode.removeChild(o):i.removeChild(o)):xn.removeChild(o.stateNode));break;case 18:xn!==null&&(Ci?(i=xn,o=o.stateNode,i.nodeType===8?fd(i.parentNode,o):i.nodeType===1&&fd(i,o),mo(i)):fd(xn,o.stateNode));break;case 4:h=xn,m=Ci,xn=o.stateNode.containerInfo,Ci=!0,Vs(i,r,o),xn=h,Ci=m;break;case 0:case 11:case 14:case 15:if(!Cn&&(h=o.updateQueue,h!==null&&(h=h.lastEffect,h!==null))){m=h=h.next;do{var S=m,b=S.destroy;S=S.tag,b!==void 0&&((S&2)!==0||(S&4)!==0)&&Zd(o,r,b),m=m.next}while(m!==h)}Vs(i,r,o);break;case 1:if(!Cn&&(xa(o,r),h=o.stateNode,typeof h.componentWillUnmount=="function"))try{h.props=o.memoizedProps,h.state=o.memoizedState,h.componentWillUnmount()}catch(F){Yt(o,r,F)}Vs(i,r,o);break;case 21:Vs(i,r,o);break;case 22:o.mode&1?(Cn=(h=Cn)||o.memoizedState!==null,Vs(i,r,o),Cn=h):Vs(i,r,o);break;default:Vs(i,r,o)}}function $0(i){var r=i.updateQueue;if(r!==null){i.updateQueue=null;var o=i.stateNode;o===null&&(o=i.stateNode=new X1),r.forEach(function(h){var m=iy.bind(null,i,h);o.has(h)||(o.add(h),h.then(m,m))})}}function Ni(i,r){var o=r.deletions;if(o!==null)for(var h=0;h<o.length;h++){var m=o[h];try{var S=i,b=r,F=b;e:for(;F!==null;){switch(F.tag){case 5:xn=F.stateNode,Ci=!1;break e;case 3:xn=F.stateNode.containerInfo,Ci=!0;break e;case 4:xn=F.stateNode.containerInfo,Ci=!0;break e}F=F.return}if(xn===null)throw Error(t(160));W0(S,b,m),xn=null,Ci=!1;var j=m.alternate;j!==null&&(j.return=null),m.return=null}catch(ie){Yt(m,r,ie)}}if(r.subtreeFlags&12854)for(r=r.child;r!==null;)X0(r,i),r=r.sibling}function X0(i,r){var o=i.alternate,h=i.flags;switch(i.tag){case 0:case 11:case 14:case 15:if(Ni(r,i),Wi(i),h&4){try{Fo(3,i,i.return),ac(3,i)}catch(Xe){Yt(i,i.return,Xe)}try{Fo(5,i,i.return)}catch(Xe){Yt(i,i.return,Xe)}}break;case 1:Ni(r,i),Wi(i),h&512&&o!==null&&xa(o,o.return);break;case 5:if(Ni(r,i),Wi(i),h&512&&o!==null&&xa(o,o.return),i.flags&32){var m=i.stateNode;try{Ce(m,"")}catch(Xe){Yt(i,i.return,Xe)}}if(h&4&&(m=i.stateNode,m!=null)){var S=i.memoizedProps,b=o!==null?o.memoizedProps:S,F=i.type,j=i.updateQueue;if(i.updateQueue=null,j!==null)try{F==="input"&&S.type==="radio"&&S.name!=null&&_t(m,S),Ct(F,b);var ie=Ct(F,S);for(b=0;b<j.length;b+=2){var ye=j[b],Ee=j[b+1];ye==="style"?Ge(m,Ee):ye==="dangerouslySetInnerHTML"?vt(m,Ee):ye==="children"?Ce(m,Ee):A(m,ye,Ee,ie)}switch(F){case"input":tt(m,S);break;case"textarea":Se(m,S);break;case"select":var xe=m._wrapperState.wasMultiple;m._wrapperState.wasMultiple=!!S.multiple;var ze=S.value;ze!=null?C(m,!!S.multiple,ze,!1):xe!==!!S.multiple&&(S.defaultValue!=null?C(m,!!S.multiple,S.defaultValue,!0):C(m,!!S.multiple,S.multiple?[]:"",!1))}m[bo]=S}catch(Xe){Yt(i,i.return,Xe)}}break;case 6:if(Ni(r,i),Wi(i),h&4){if(i.stateNode===null)throw Error(t(162));m=i.stateNode,S=i.memoizedProps;try{m.nodeValue=S}catch(Xe){Yt(i,i.return,Xe)}}break;case 3:if(Ni(r,i),Wi(i),h&4&&o!==null&&o.memoizedState.isDehydrated)try{mo(r.containerInfo)}catch(Xe){Yt(i,i.return,Xe)}break;case 4:Ni(r,i),Wi(i);break;case 13:Ni(r,i),Wi(i),m=i.child,m.flags&8192&&(S=m.memoizedState!==null,m.stateNode.isHidden=S,!S||m.alternate!==null&&m.alternate.memoizedState!==null||(ih=Pe())),h&4&&$0(i);break;case 22:if(ye=o!==null&&o.memoizedState!==null,i.mode&1?(Cn=(ie=Cn)||ye,Ni(r,i),Cn=ie):Ni(r,i),Wi(i),h&8192){if(ie=i.memoizedState!==null,(i.stateNode.isHidden=ie)&&!ye&&(i.mode&1)!==0)for(We=i,ye=i.child;ye!==null;){for(Ee=We=ye;We!==null;){switch(xe=We,ze=xe.child,xe.tag){case 0:case 11:case 14:case 15:Fo(4,xe,xe.return);break;case 1:xa(xe,xe.return);var $e=xe.stateNode;if(typeof $e.componentWillUnmount=="function"){h=xe,o=xe.return;try{r=h,$e.props=r.memoizedProps,$e.state=r.memoizedState,$e.componentWillUnmount()}catch(Xe){Yt(h,o,Xe)}}break;case 5:xa(xe,xe.return);break;case 22:if(xe.memoizedState!==null){K0(Ee);continue}}ze!==null?(ze.return=xe,We=ze):K0(Ee)}ye=ye.sibling}e:for(ye=null,Ee=i;;){if(Ee.tag===5){if(ye===null){ye=Ee;try{m=Ee.stateNode,ie?(S=m.style,typeof S.setProperty=="function"?S.setProperty("display","none","important"):S.display="none"):(F=Ee.stateNode,j=Ee.memoizedProps.style,b=j!=null&&j.hasOwnProperty("display")?j.display:null,F.style.display=st("display",b))}catch(Xe){Yt(i,i.return,Xe)}}}else if(Ee.tag===6){if(ye===null)try{Ee.stateNode.nodeValue=ie?"":Ee.memoizedProps}catch(Xe){Yt(i,i.return,Xe)}}else if((Ee.tag!==22&&Ee.tag!==23||Ee.memoizedState===null||Ee===i)&&Ee.child!==null){Ee.child.return=Ee,Ee=Ee.child;continue}if(Ee===i)break e;for(;Ee.sibling===null;){if(Ee.return===null||Ee.return===i)break e;ye===Ee&&(ye=null),Ee=Ee.return}ye===Ee&&(ye=null),Ee.sibling.return=Ee.return,Ee=Ee.sibling}}break;case 19:Ni(r,i),Wi(i),h&4&&$0(i);break;case 21:break;default:Ni(r,i),Wi(i)}}function Wi(i){var r=i.flags;if(r&2){try{e:{for(var o=i.return;o!==null;){if(V0(o)){var h=o;break e}o=o.return}throw Error(t(160))}switch(h.tag){case 5:var m=h.stateNode;h.flags&32&&(Ce(m,""),h.flags&=-33);var S=G0(i);eh(i,S,m);break;case 3:case 4:var b=h.stateNode.containerInfo,F=G0(i);Jd(i,F,b);break;default:throw Error(t(161))}}catch(j){Yt(i,i.return,j)}i.flags&=-3}r&4096&&(i.flags&=-4097)}function Y1(i,r,o){We=i,q0(i)}function q0(i,r,o){for(var h=(i.mode&1)!==0;We!==null;){var m=We,S=m.child;if(m.tag===22&&h){var b=m.memoizedState!==null||rc;if(!b){var F=m.alternate,j=F!==null&&F.memoizedState!==null||Cn;F=rc;var ie=Cn;if(rc=b,(Cn=j)&&!ie)for(We=m;We!==null;)b=We,j=b.child,b.tag===22&&b.memoizedState!==null?Z0(m):j!==null?(j.return=b,We=j):Z0(m);for(;S!==null;)We=S,q0(S),S=S.sibling;We=m,rc=F,Cn=ie}Y0(i)}else(m.subtreeFlags&8772)!==0&&S!==null?(S.return=m,We=S):Y0(i)}}function Y0(i){for(;We!==null;){var r=We;if((r.flags&8772)!==0){var o=r.alternate;try{if((r.flags&8772)!==0)switch(r.tag){case 0:case 11:case 15:Cn||ac(5,r);break;case 1:var h=r.stateNode;if(r.flags&4&&!Cn)if(o===null)h.componentDidMount();else{var m=r.elementType===r.type?o.memoizedProps:Ai(r.type,o.memoizedProps);h.componentDidUpdate(m,o.memoizedState,h.__reactInternalSnapshotBeforeUpdate)}var S=r.updateQueue;S!==null&&Km(r,S,h);break;case 3:var b=r.updateQueue;if(b!==null){if(o=null,r.child!==null)switch(r.child.tag){case 5:o=r.child.stateNode;break;case 1:o=r.child.stateNode}Km(r,b,o)}break;case 5:var F=r.stateNode;if(o===null&&r.flags&4){o=F;var j=r.memoizedProps;switch(r.type){case"button":case"input":case"select":case"textarea":j.autoFocus&&o.focus();break;case"img":j.src&&(o.src=j.src)}}break;case 6:break;case 4:break;case 12:break;case 13:if(r.memoizedState===null){var ie=r.alternate;if(ie!==null){var ye=ie.memoizedState;if(ye!==null){var Ee=ye.dehydrated;Ee!==null&&mo(Ee)}}}break;case 19:case 17:case 21:case 22:case 23:case 25:break;default:throw Error(t(163))}Cn||r.flags&512&&Qd(r)}catch(xe){Yt(r,r.return,xe)}}if(r===i){We=null;break}if(o=r.sibling,o!==null){o.return=r.return,We=o;break}We=r.return}}function K0(i){for(;We!==null;){var r=We;if(r===i){We=null;break}var o=r.sibling;if(o!==null){o.return=r.return,We=o;break}We=r.return}}function Z0(i){for(;We!==null;){var r=We;try{switch(r.tag){case 0:case 11:case 15:var o=r.return;try{ac(4,r)}catch(j){Yt(r,o,j)}break;case 1:var h=r.stateNode;if(typeof h.componentDidMount=="function"){var m=r.return;try{h.componentDidMount()}catch(j){Yt(r,m,j)}}var S=r.return;try{Qd(r)}catch(j){Yt(r,S,j)}break;case 5:var b=r.return;try{Qd(r)}catch(j){Yt(r,b,j)}}}catch(j){Yt(r,r.return,j)}if(r===i){We=null;break}var F=r.sibling;if(F!==null){F.return=r.return,We=F;break}We=r.return}}var K1=Math.ceil,oc=R.ReactCurrentDispatcher,th=R.ReactCurrentOwner,pi=R.ReactCurrentBatchConfig,St=0,pn=null,Jt=null,yn=0,ni=0,ya=Os(0),an=0,Oo=null,Sr=0,lc=0,nh=0,jo=null,Hn=null,ih=0,Sa=1/0,us=null,cc=!1,sh=null,Gs=null,uc=!1,Ws=null,dc=0,zo=0,rh=null,hc=-1,fc=0;function In(){return(St&6)!==0?Pe():hc!==-1?hc:hc=Pe()}function $s(i){return(i.mode&1)===0?1:(St&2)!==0&&yn!==0?yn&-yn:L1.transition!==null?(fc===0&&(fc=ea()),fc):(i=kt,i!==0||(i=window.event,i=i===void 0?16:Jp(i.type)),i)}function Ri(i,r,o,h){if(50<zo)throw zo=0,rh=null,Error(t(185));Rs(i,o,h),((St&2)===0||i!==pn)&&(i===pn&&((St&2)===0&&(lc|=o),an===4&&Xs(i,yn)),Vn(i,h),o===1&&St===0&&(r.mode&1)===0&&(Sa=Pe()+500,Bl&&zs()))}function Vn(i,r){var o=i.callbackNode;lo(i,r);var h=Ut(i,i===pn?yn:0);if(h===0)o!==null&&X(o),i.callbackNode=null,i.callbackPriority=0;else if(r=h&-h,i.callbackPriority!==r){if(o!=null&&X(o),r===1)i.tag===0?k1(J0.bind(null,i)):Om(J0.bind(null,i)),C1(function(){(St&6)===0&&zs()}),o=null;else{switch(Wp(h)){case 1:o=et;break;case 4:o=nt;break;case 16:o=Ye;break;case 536870912:o=Dt;break;default:o=Ye}o=og(o,Q0.bind(null,i))}i.callbackPriority=r,i.callbackNode=o}}function Q0(i,r){if(hc=-1,fc=0,(St&6)!==0)throw Error(t(327));var o=i.callbackNode;if(Ma()&&i.callbackNode!==o)return null;var h=Ut(i,i===pn?yn:0);if(h===0)return null;if((h&30)!==0||(h&i.expiredLanes)!==0||r)r=pc(i,h);else{r=h;var m=St;St|=2;var S=tg();(pn!==i||yn!==r)&&(us=null,Sa=Pe()+500,Er(i,r));do try{J1();break}catch(F){eg(i,F)}while(!0);Ed(),oc.current=S,St=m,Jt!==null?r=0:(pn=null,yn=0,r=an)}if(r!==0){if(r===2&&(m=wn(i),m!==0&&(h=m,r=ah(i,m))),r===1)throw o=Oo,Er(i,0),Xs(i,h),Vn(i,Pe()),o;if(r===6)Xs(i,h);else{if(m=i.current.alternate,(h&30)===0&&!Z1(m)&&(r=pc(i,h),r===2&&(S=wn(i),S!==0&&(h=S,r=ah(i,S))),r===1))throw o=Oo,Er(i,0),Xs(i,h),Vn(i,Pe()),o;switch(i.finishedWork=m,i.finishedLanes=h,r){case 0:case 1:throw Error(t(345));case 2:wr(i,Hn,us);break;case 3:if(Xs(i,h),(h&130023424)===h&&(r=ih+500-Pe(),10<r)){if(Ut(i,0)!==0)break;if(m=i.suspendedLanes,(m&h)!==h){In(),i.pingedLanes|=i.suspendedLanes&m;break}i.timeoutHandle=hd(wr.bind(null,i,Hn,us),r);break}wr(i,Hn,us);break;case 4:if(Xs(i,h),(h&4194240)===h)break;for(r=i.eventTimes,m=-1;0<h;){var b=31-Ve(h);S=1<<b,b=r[b],b>m&&(m=b),h&=~S}if(h=m,h=Pe()-h,h=(120>h?120:480>h?480:1080>h?1080:1920>h?1920:3e3>h?3e3:4320>h?4320:1960*K1(h/1960))-h,10<h){i.timeoutHandle=hd(wr.bind(null,i,Hn,us),h);break}wr(i,Hn,us);break;case 5:wr(i,Hn,us);break;default:throw Error(t(329))}}}return Vn(i,Pe()),i.callbackNode===o?Q0.bind(null,i):null}function ah(i,r){var o=jo;return i.current.memoizedState.isDehydrated&&(Er(i,r).flags|=256),i=pc(i,r),i!==2&&(r=Hn,Hn=o,r!==null&&oh(r)),i}function oh(i){Hn===null?Hn=i:Hn.push.apply(Hn,i)}function Z1(i){for(var r=i;;){if(r.flags&16384){var o=r.updateQueue;if(o!==null&&(o=o.stores,o!==null))for(var h=0;h<o.length;h++){var m=o[h],S=m.getSnapshot;m=m.value;try{if(!Ti(S(),m))return!1}catch{return!1}}}if(o=r.child,r.subtreeFlags&16384&&o!==null)o.return=r,r=o;else{if(r===i)break;for(;r.sibling===null;){if(r.return===null||r.return===i)return!0;r=r.return}r.sibling.return=r.return,r=r.sibling}}return!0}function Xs(i,r){for(r&=~nh,r&=~lc,i.suspendedLanes|=r,i.pingedLanes&=~r,i=i.expirationTimes;0<r;){var o=31-Ve(r),h=1<<o;i[o]=-1,r&=~h}}function J0(i){if((St&6)!==0)throw Error(t(327));Ma();var r=Ut(i,0);if((r&1)===0)return Vn(i,Pe()),null;var o=pc(i,r);if(i.tag!==0&&o===2){var h=wn(i);h!==0&&(r=h,o=ah(i,h))}if(o===1)throw o=Oo,Er(i,0),Xs(i,r),Vn(i,Pe()),o;if(o===6)throw Error(t(345));return i.finishedWork=i.current.alternate,i.finishedLanes=r,wr(i,Hn,us),Vn(i,Pe()),null}function lh(i,r){var o=St;St|=1;try{return i(r)}finally{St=o,St===0&&(Sa=Pe()+500,Bl&&zs())}}function Mr(i){Ws!==null&&Ws.tag===0&&(St&6)===0&&Ma();var r=St;St|=1;var o=pi.transition,h=kt;try{if(pi.transition=null,kt=1,i)return i()}finally{kt=h,pi.transition=o,St=r,(St&6)===0&&zs()}}function ch(){ni=ya.current,zt(ya)}function Er(i,r){i.finishedWork=null,i.finishedLanes=0;var o=i.timeoutHandle;if(o!==-1&&(i.timeoutHandle=-1,A1(o)),Jt!==null)for(o=Jt.return;o!==null;){var h=o;switch(vd(h),h.tag){case 1:h=h.type.childContextTypes,h!=null&&jl();break;case 3:_a(),zt(jn),zt(Tn),Pd();break;case 5:Nd(h);break;case 4:_a();break;case 13:zt(Xt);break;case 19:zt(Xt);break;case 10:wd(h.type._context);break;case 22:case 23:ch()}o=o.return}if(pn=i,Jt=i=qs(i.current,null),yn=ni=r,an=0,Oo=null,nh=lc=Sr=0,Hn=jo=null,vr!==null){for(r=0;r<vr.length;r++)if(o=vr[r],h=o.interleaved,h!==null){o.interleaved=null;var m=h.next,S=o.pending;if(S!==null){var b=S.next;S.next=m,h.next=b}o.pending=h}vr=null}return i}function eg(i,r){do{var o=Jt;try{if(Ed(),Zl.current=tc,Ql){for(var h=qt.memoizedState;h!==null;){var m=h.queue;m!==null&&(m.pending=null),h=h.next}Ql=!1}if(yr=0,fn=rn=qt=null,ko=!1,Lo=0,th.current=null,o===null||o.return===null){an=1,Oo=r,Jt=null;break}e:{var S=i,b=o.return,F=o,j=r;if(r=yn,F.flags|=32768,j!==null&&typeof j=="object"&&typeof j.then=="function"){var ie=j,ye=F,Ee=ye.tag;if((ye.mode&1)===0&&(Ee===0||Ee===11||Ee===15)){var xe=ye.alternate;xe?(ye.updateQueue=xe.updateQueue,ye.memoizedState=xe.memoizedState,ye.lanes=xe.lanes):(ye.updateQueue=null,ye.memoizedState=null)}var ze=T0(b);if(ze!==null){ze.flags&=-257,b0(ze,b,F,S,r),ze.mode&1&&w0(S,ie,r),r=ze,j=ie;var $e=r.updateQueue;if($e===null){var Xe=new Set;Xe.add(j),r.updateQueue=Xe}else $e.add(j);break e}else{if((r&1)===0){w0(S,ie,r),uh();break e}j=Error(t(426))}}else if(Gt&&F.mode&1){var Kt=T0(b);if(Kt!==null){(Kt.flags&65536)===0&&(Kt.flags|=256),b0(Kt,b,F,S,r),Sd(va(j,F));break e}}S=j=va(j,F),an!==4&&(an=2),jo===null?jo=[S]:jo.push(S),S=b;do{switch(S.tag){case 3:S.flags|=65536,r&=-r,S.lanes|=r;var Y=M0(S,j,r);Ym(S,Y);break e;case 1:F=j;var H=S.type,Z=S.stateNode;if((S.flags&128)===0&&(typeof H.getDerivedStateFromError=="function"||Z!==null&&typeof Z.componentDidCatch=="function"&&(Gs===null||!Gs.has(Z)))){S.flags|=65536,r&=-r,S.lanes|=r;var Ne=E0(S,F,r);Ym(S,Ne);break e}}S=S.return}while(S!==null)}ig(o)}catch(Ke){r=Ke,Jt===o&&o!==null&&(Jt=o=o.return);continue}break}while(!0)}function tg(){var i=oc.current;return oc.current=tc,i===null?tc:i}function uh(){(an===0||an===3||an===2)&&(an=4),pn===null||(Sr&268435455)===0&&(lc&268435455)===0||Xs(pn,yn)}function pc(i,r){var o=St;St|=2;var h=tg();(pn!==i||yn!==r)&&(us=null,Er(i,r));do try{Q1();break}catch(m){eg(i,m)}while(!0);if(Ed(),St=o,oc.current=h,Jt!==null)throw Error(t(261));return pn=null,yn=0,an}function Q1(){for(;Jt!==null;)ng(Jt)}function J1(){for(;Jt!==null&&!Re();)ng(Jt)}function ng(i){var r=ag(i.alternate,i,ni);i.memoizedProps=i.pendingProps,r===null?ig(i):Jt=r,th.current=null}function ig(i){var r=i;do{var o=r.alternate;if(i=r.return,(r.flags&32768)===0){if(o=W1(o,r,ni),o!==null){Jt=o;return}}else{if(o=$1(o,r),o!==null){o.flags&=32767,Jt=o;return}if(i!==null)i.flags|=32768,i.subtreeFlags=0,i.deletions=null;else{an=6,Jt=null;return}}if(r=r.sibling,r!==null){Jt=r;return}Jt=r=i}while(r!==null);an===0&&(an=5)}function wr(i,r,o){var h=kt,m=pi.transition;try{pi.transition=null,kt=1,ey(i,r,o,h)}finally{pi.transition=m,kt=h}return null}function ey(i,r,o,h){do Ma();while(Ws!==null);if((St&6)!==0)throw Error(t(327));o=i.finishedWork;var m=i.finishedLanes;if(o===null)return null;if(i.finishedWork=null,i.finishedLanes=0,o===i.current)throw Error(t(177));i.callbackNode=null,i.callbackPriority=0;var S=o.lanes|o.childLanes;if(Dx(i,S),i===pn&&(Jt=pn=null,yn=0),(o.subtreeFlags&2064)===0&&(o.flags&2064)===0||uc||(uc=!0,og(Ye,function(){return Ma(),null})),S=(o.flags&15990)!==0,(o.subtreeFlags&15990)!==0||S){S=pi.transition,pi.transition=null;var b=kt;kt=1;var F=St;St|=4,th.current=null,q1(i,o),X0(o,i),y1(ud),Tl=!!cd,ud=cd=null,i.current=o,Y1(o),Oe(),St=F,kt=b,pi.transition=S}else i.current=o;if(uc&&(uc=!1,Ws=i,dc=m),S=i.pendingLanes,S===0&&(Gs=null),Mt(o.stateNode),Vn(i,Pe()),r!==null)for(h=i.onRecoverableError,o=0;o<r.length;o++)m=r[o],h(m.value,{componentStack:m.stack,digest:m.digest});if(cc)throw cc=!1,i=sh,sh=null,i;return(dc&1)!==0&&i.tag!==0&&Ma(),S=i.pendingLanes,(S&1)!==0?i===rh?zo++:(zo=0,rh=i):zo=0,zs(),null}function Ma(){if(Ws!==null){var i=Wp(dc),r=pi.transition,o=kt;try{if(pi.transition=null,kt=16>i?16:i,Ws===null)var h=!1;else{if(i=Ws,Ws=null,dc=0,(St&6)!==0)throw Error(t(331));var m=St;for(St|=4,We=i.current;We!==null;){var S=We,b=S.child;if((We.flags&16)!==0){var F=S.deletions;if(F!==null){for(var j=0;j<F.length;j++){var ie=F[j];for(We=ie;We!==null;){var ye=We;switch(ye.tag){case 0:case 11:case 15:Fo(8,ye,S)}var Ee=ye.child;if(Ee!==null)Ee.return=ye,We=Ee;else for(;We!==null;){ye=We;var xe=ye.sibling,ze=ye.return;if(H0(ye),ye===ie){We=null;break}if(xe!==null){xe.return=ze,We=xe;break}We=ze}}}var $e=S.alternate;if($e!==null){var Xe=$e.child;if(Xe!==null){$e.child=null;do{var Kt=Xe.sibling;Xe.sibling=null,Xe=Kt}while(Xe!==null)}}We=S}}if((S.subtreeFlags&2064)!==0&&b!==null)b.return=S,We=b;else e:for(;We!==null;){if(S=We,(S.flags&2048)!==0)switch(S.tag){case 0:case 11:case 15:Fo(9,S,S.return)}var Y=S.sibling;if(Y!==null){Y.return=S.return,We=Y;break e}We=S.return}}var H=i.current;for(We=H;We!==null;){b=We;var Z=b.child;if((b.subtreeFlags&2064)!==0&&Z!==null)Z.return=b,We=Z;else e:for(b=H;We!==null;){if(F=We,(F.flags&2048)!==0)try{switch(F.tag){case 0:case 11:case 15:ac(9,F)}}catch(Ke){Yt(F,F.return,Ke)}if(F===b){We=null;break e}var Ne=F.sibling;if(Ne!==null){Ne.return=F.return,We=Ne;break e}We=F.return}}if(St=m,zs(),Vt&&typeof Vt.onPostCommitFiberRoot=="function")try{Vt.onPostCommitFiberRoot(It,i)}catch{}h=!0}return h}finally{kt=o,pi.transition=r}}return!1}function sg(i,r,o){r=va(o,r),r=M0(i,r,1),i=Hs(i,r,1),r=In(),i!==null&&(Rs(i,1,r),Vn(i,r))}function Yt(i,r,o){if(i.tag===3)sg(i,i,o);else for(;r!==null;){if(r.tag===3){sg(r,i,o);break}else if(r.tag===1){var h=r.stateNode;if(typeof r.type.getDerivedStateFromError=="function"||typeof h.componentDidCatch=="function"&&(Gs===null||!Gs.has(h))){i=va(o,i),i=E0(r,i,1),r=Hs(r,i,1),i=In(),r!==null&&(Rs(r,1,i),Vn(r,i));break}}r=r.return}}function ty(i,r,o){var h=i.pingCache;h!==null&&h.delete(r),r=In(),i.pingedLanes|=i.suspendedLanes&o,pn===i&&(yn&o)===o&&(an===4||an===3&&(yn&130023424)===yn&&500>Pe()-ih?Er(i,0):nh|=o),Vn(i,r)}function rg(i,r){r===0&&((i.mode&1)===0?r=1:(r=hn,hn<<=1,(hn&130023424)===0&&(hn=4194304)));var o=In();i=os(i,r),i!==null&&(Rs(i,r,o),Vn(i,o))}function ny(i){var r=i.memoizedState,o=0;r!==null&&(o=r.retryLane),rg(i,o)}function iy(i,r){var o=0;switch(i.tag){case 13:var h=i.stateNode,m=i.memoizedState;m!==null&&(o=m.retryLane);break;case 19:h=i.stateNode;break;default:throw Error(t(314))}h!==null&&h.delete(r),rg(i,o)}var ag;ag=function(i,r,o){if(i!==null)if(i.memoizedProps!==r.pendingProps||jn.current)Bn=!0;else{if((i.lanes&o)===0&&(r.flags&128)===0)return Bn=!1,G1(i,r,o);Bn=(i.flags&131072)!==0}else Bn=!1,Gt&&(r.flags&1048576)!==0&&jm(r,Vl,r.index);switch(r.lanes=0,r.tag){case 2:var h=r.type;sc(i,r),i=r.pendingProps;var m=ua(r,Tn.current);ga(r,o),m=Dd(null,r,h,i,m,o);var S=Id();return r.flags|=1,typeof m=="object"&&m!==null&&typeof m.render=="function"&&m.$$typeof===void 0?(r.tag=1,r.memoizedState=null,r.updateQueue=null,zn(h)?(S=!0,zl(r)):S=!1,r.memoizedState=m.state!==null&&m.state!==void 0?m.state:null,Ad(r),m.updater=nc,r.stateNode=m,m._reactInternals=r,Bd(r,h,i,o),r=Wd(null,r,h,!0,S,o)):(r.tag=0,Gt&&S&&_d(r),Dn(null,r,m,o),r=r.child),r;case 16:h=r.elementType;e:{switch(sc(i,r),i=r.pendingProps,m=h._init,h=m(h._payload),r.type=h,m=r.tag=ry(h),i=Ai(h,i),m){case 0:r=Gd(null,r,h,i,o);break e;case 1:r=k0(null,r,h,i,o);break e;case 11:r=A0(null,r,h,i,o);break e;case 14:r=C0(null,r,h,Ai(h.type,i),o);break e}throw Error(t(306,h,""))}return r;case 0:return h=r.type,m=r.pendingProps,m=r.elementType===h?m:Ai(h,m),Gd(i,r,h,m,o);case 1:return h=r.type,m=r.pendingProps,m=r.elementType===h?m:Ai(h,m),k0(i,r,h,m,o);case 3:e:{if(L0(r),i===null)throw Error(t(387));h=r.pendingProps,S=r.memoizedState,m=S.element,qm(i,r),Yl(r,h,null,o);var b=r.memoizedState;if(h=b.element,S.isDehydrated)if(S={element:h,isDehydrated:!1,cache:b.cache,pendingSuspenseBoundaries:b.pendingSuspenseBoundaries,transitions:b.transitions},r.updateQueue.baseState=S,r.memoizedState=S,r.flags&256){m=va(Error(t(423)),r),r=D0(i,r,h,o,m);break e}else if(h!==m){m=va(Error(t(424)),r),r=D0(i,r,h,o,m);break e}else for(ti=Fs(r.stateNode.containerInfo.firstChild),ei=r,Gt=!0,bi=null,o=$m(r,null,h,o),r.child=o;o;)o.flags=o.flags&-3|4096,o=o.sibling;else{if(fa(),h===m){r=cs(i,r,o);break e}Dn(i,r,h,o)}r=r.child}return r;case 5:return Zm(r),i===null&&yd(r),h=r.type,m=r.pendingProps,S=i!==null?i.memoizedProps:null,b=m.children,dd(h,m)?b=null:S!==null&&dd(h,S)&&(r.flags|=32),P0(i,r),Dn(i,r,b,o),r.child;case 6:return i===null&&yd(r),null;case 13:return I0(i,r,o);case 4:return Cd(r,r.stateNode.containerInfo),h=r.pendingProps,i===null?r.child=pa(r,null,h,o):Dn(i,r,h,o),r.child;case 11:return h=r.type,m=r.pendingProps,m=r.elementType===h?m:Ai(h,m),A0(i,r,h,m,o);case 7:return Dn(i,r,r.pendingProps,o),r.child;case 8:return Dn(i,r,r.pendingProps.children,o),r.child;case 12:return Dn(i,r,r.pendingProps.children,o),r.child;case 10:e:{if(h=r.type._context,m=r.pendingProps,S=r.memoizedProps,b=m.value,Ft($l,h._currentValue),h._currentValue=b,S!==null)if(Ti(S.value,b)){if(S.children===m.children&&!jn.current){r=cs(i,r,o);break e}}else for(S=r.child,S!==null&&(S.return=r);S!==null;){var F=S.dependencies;if(F!==null){b=S.child;for(var j=F.firstContext;j!==null;){if(j.context===h){if(S.tag===1){j=ls(-1,o&-o),j.tag=2;var ie=S.updateQueue;if(ie!==null){ie=ie.shared;var ye=ie.pending;ye===null?j.next=j:(j.next=ye.next,ye.next=j),ie.pending=j}}S.lanes|=o,j=S.alternate,j!==null&&(j.lanes|=o),Td(S.return,o,r),F.lanes|=o;break}j=j.next}}else if(S.tag===10)b=S.type===r.type?null:S.child;else if(S.tag===18){if(b=S.return,b===null)throw Error(t(341));b.lanes|=o,F=b.alternate,F!==null&&(F.lanes|=o),Td(b,o,r),b=S.sibling}else b=S.child;if(b!==null)b.return=S;else for(b=S;b!==null;){if(b===r){b=null;break}if(S=b.sibling,S!==null){S.return=b.return,b=S;break}b=b.return}S=b}Dn(i,r,m.children,o),r=r.child}return r;case 9:return m=r.type,h=r.pendingProps.children,ga(r,o),m=hi(m),h=h(m),r.flags|=1,Dn(i,r,h,o),r.child;case 14:return h=r.type,m=Ai(h,r.pendingProps),m=Ai(h.type,m),C0(i,r,h,m,o);case 15:return N0(i,r,r.type,r.pendingProps,o);case 17:return h=r.type,m=r.pendingProps,m=r.elementType===h?m:Ai(h,m),sc(i,r),r.tag=1,zn(h)?(i=!0,zl(r)):i=!1,ga(r,o),y0(r,h,m),Bd(r,h,m,o),Wd(null,r,h,!0,i,o);case 19:return F0(i,r,o);case 22:return R0(i,r,o)}throw Error(t(156,r.tag))};function og(i,r){return ne(i,r)}function sy(i,r,o,h){this.tag=i,this.key=o,this.sibling=this.child=this.return=this.stateNode=this.type=this.elementType=null,this.index=0,this.ref=null,this.pendingProps=r,this.dependencies=this.memoizedState=this.updateQueue=this.memoizedProps=null,this.mode=h,this.subtreeFlags=this.flags=0,this.deletions=null,this.childLanes=this.lanes=0,this.alternate=null}function mi(i,r,o,h){return new sy(i,r,o,h)}function dh(i){return i=i.prototype,!(!i||!i.isReactComponent)}function ry(i){if(typeof i=="function")return dh(i)?1:0;if(i!=null){if(i=i.$$typeof,i===re)return 11;if(i===ve)return 14}return 2}function qs(i,r){var o=i.alternate;return o===null?(o=mi(i.tag,r,i.key,i.mode),o.elementType=i.elementType,o.type=i.type,o.stateNode=i.stateNode,o.alternate=i,i.alternate=o):(o.pendingProps=r,o.type=i.type,o.flags=0,o.subtreeFlags=0,o.deletions=null),o.flags=i.flags&14680064,o.childLanes=i.childLanes,o.lanes=i.lanes,o.child=i.child,o.memoizedProps=i.memoizedProps,o.memoizedState=i.memoizedState,o.updateQueue=i.updateQueue,r=i.dependencies,o.dependencies=r===null?null:{lanes:r.lanes,firstContext:r.firstContext},o.sibling=i.sibling,o.index=i.index,o.ref=i.ref,o}function mc(i,r,o,h,m,S){var b=2;if(h=i,typeof i=="function")dh(i)&&(b=1);else if(typeof i=="string")b=5;else e:switch(i){case U:return Tr(o.children,m,S,r);case $:b=8,m|=8;break;case te:return i=mi(12,o,r,m|2),i.elementType=te,i.lanes=S,i;case J:return i=mi(13,o,r,m),i.elementType=J,i.lanes=S,i;case ae:return i=mi(19,o,r,m),i.elementType=ae,i.lanes=S,i;case de:return gc(o,m,S,r);default:if(typeof i=="object"&&i!==null)switch(i.$$typeof){case T:b=10;break e;case P:b=9;break e;case re:b=11;break e;case ve:b=14;break e;case V:b=16,h=null;break e}throw Error(t(130,i==null?i:typeof i,""))}return r=mi(b,o,r,m),r.elementType=i,r.type=h,r.lanes=S,r}function Tr(i,r,o,h){return i=mi(7,i,h,r),i.lanes=o,i}function gc(i,r,o,h){return i=mi(22,i,h,r),i.elementType=de,i.lanes=o,i.stateNode={isHidden:!1},i}function hh(i,r,o){return i=mi(6,i,null,r),i.lanes=o,i}function fh(i,r,o){return r=mi(4,i.children!==null?i.children:[],i.key,r),r.lanes=o,r.stateNode={containerInfo:i.containerInfo,pendingChildren:null,implementation:i.implementation},r}function ay(i,r,o,h,m){this.tag=r,this.containerInfo=i,this.finishedWork=this.pingCache=this.current=this.pendingChildren=null,this.timeoutHandle=-1,this.callbackNode=this.pendingContext=this.context=null,this.callbackPriority=0,this.eventTimes=co(0),this.expirationTimes=co(-1),this.entangledLanes=this.finishedLanes=this.mutableReadLanes=this.expiredLanes=this.pingedLanes=this.suspendedLanes=this.pendingLanes=0,this.entanglements=co(0),this.identifierPrefix=h,this.onRecoverableError=m,this.mutableSourceEagerHydrationData=null}function ph(i,r,o,h,m,S,b,F,j){return i=new ay(i,r,o,F,j),r===1?(r=1,S===!0&&(r|=8)):r=0,S=mi(3,null,null,r),i.current=S,S.stateNode=i,S.memoizedState={element:h,isDehydrated:o,cache:null,transitions:null,pendingSuspenseBoundaries:null},Ad(S),i}function oy(i,r,o){var h=3<arguments.length&&arguments[3]!==void 0?arguments[3]:null;return{$$typeof:D,key:h==null?null:""+h,children:i,containerInfo:r,implementation:o}}function lg(i){if(!i)return js;i=i._reactInternals;e:{if(ts(i)!==i||i.tag!==1)throw Error(t(170));var r=i;do{switch(r.tag){case 3:r=r.stateNode.context;break e;case 1:if(zn(r.type)){r=r.stateNode.__reactInternalMemoizedMergedChildContext;break e}}r=r.return}while(r!==null);throw Error(t(171))}if(i.tag===1){var o=i.type;if(zn(o))return Um(i,o,r)}return r}function cg(i,r,o,h,m,S,b,F,j){return i=ph(o,h,!0,i,m,S,b,F,j),i.context=lg(null),o=i.current,h=In(),m=$s(o),S=ls(h,m),S.callback=r??null,Hs(o,S,m),i.current.lanes=m,Rs(i,m,h),Vn(i,h),i}function _c(i,r,o,h){var m=r.current,S=In(),b=$s(m);return o=lg(o),r.context===null?r.context=o:r.pendingContext=o,r=ls(S,b),r.payload={element:i},h=h===void 0?null:h,h!==null&&(r.callback=h),i=Hs(m,r,b),i!==null&&(Ri(i,m,b,S),ql(i,m,b)),b}function vc(i){if(i=i.current,!i.child)return null;switch(i.child.tag){case 5:return i.child.stateNode;default:return i.child.stateNode}}function ug(i,r){if(i=i.memoizedState,i!==null&&i.dehydrated!==null){var o=i.retryLane;i.retryLane=o!==0&&o<r?o:r}}function mh(i,r){ug(i,r),(i=i.alternate)&&ug(i,r)}function ly(){return null}var dg=typeof reportError=="function"?reportError:function(i){console.error(i)};function gh(i){this._internalRoot=i}xc.prototype.render=gh.prototype.render=function(i){var r=this._internalRoot;if(r===null)throw Error(t(409));_c(i,r,null,null)},xc.prototype.unmount=gh.prototype.unmount=function(){var i=this._internalRoot;if(i!==null){this._internalRoot=null;var r=i.containerInfo;Mr(function(){_c(null,i,null,null)}),r[is]=null}};function xc(i){this._internalRoot=i}xc.prototype.unstable_scheduleHydration=function(i){if(i){var r=qp();i={blockedOn:null,target:i,priority:r};for(var o=0;o<Ds.length&&r!==0&&r<Ds[o].priority;o++);Ds.splice(o,0,i),o===0&&Zp(i)}};function _h(i){return!(!i||i.nodeType!==1&&i.nodeType!==9&&i.nodeType!==11)}function yc(i){return!(!i||i.nodeType!==1&&i.nodeType!==9&&i.nodeType!==11&&(i.nodeType!==8||i.nodeValue!==" react-mount-point-unstable "))}function hg(){}function cy(i,r,o,h,m){if(m){if(typeof h=="function"){var S=h;h=function(){var ie=vc(b);S.call(ie)}}var b=cg(r,h,i,0,null,!1,!1,"",hg);return i._reactRootContainer=b,i[is]=b.current,wo(i.nodeType===8?i.parentNode:i),Mr(),b}for(;m=i.lastChild;)i.removeChild(m);if(typeof h=="function"){var F=h;h=function(){var ie=vc(j);F.call(ie)}}var j=ph(i,0,!1,null,null,!1,!1,"",hg);return i._reactRootContainer=j,i[is]=j.current,wo(i.nodeType===8?i.parentNode:i),Mr(function(){_c(r,j,o,h)}),j}function Sc(i,r,o,h,m){var S=o._reactRootContainer;if(S){var b=S;if(typeof m=="function"){var F=m;m=function(){var j=vc(b);F.call(j)}}_c(r,b,i,m)}else b=cy(o,r,i,m,h);return vc(b)}$p=function(i){switch(i.tag){case 3:var r=i.stateNode;if(r.current.memoizedState.isDehydrated){var o=ns(r.pendingLanes);o!==0&&(Bu(r,o|1),Vn(r,Pe()),(St&6)===0&&(Sa=Pe()+500,zs()))}break;case 13:Mr(function(){var h=os(i,1);if(h!==null){var m=In();Ri(h,i,1,m)}}),mh(i,1)}},Hu=function(i){if(i.tag===13){var r=os(i,134217728);if(r!==null){var o=In();Ri(r,i,134217728,o)}mh(i,134217728)}},Xp=function(i){if(i.tag===13){var r=$s(i),o=os(i,r);if(o!==null){var h=In();Ri(o,i,r,h)}mh(i,r)}},qp=function(){return kt},Yp=function(i,r){var o=kt;try{return kt=i,r()}finally{kt=o}},ce=function(i,r,o){switch(r){case"input":if(tt(i,o),r=o.name,o.type==="radio"&&r!=null){for(o=i;o.parentNode;)o=o.parentNode;for(o=o.querySelectorAll("input[name="+JSON.stringify(""+r)+'][type="radio"]'),r=0;r<o.length;r++){var h=o[r];if(h!==i&&h.form===i.form){var m=Ol(h);if(!m)throw Error(t(90));pt(h),tt(h,m)}}}break;case"textarea":Se(i,o);break;case"select":r=o.value,r!=null&&C(i,!!o.multiple,r,!1)}},vn=lh,xt=Mr;var uy={usingClientEntryPoint:!1,Events:[Ao,la,Ol,gt,$t,lh]},Bo={findFiberByHostInstance:pr,bundleType:0,version:"18.3.1",rendererPackageName:"react-dom"},dy={bundleType:Bo.bundleType,version:Bo.version,rendererPackageName:Bo.rendererPackageName,rendererConfig:Bo.rendererConfig,overrideHookState:null,overrideHookStateDeletePath:null,overrideHookStateRenamePath:null,overrideProps:null,overridePropsDeletePath:null,overridePropsRenamePath:null,setErrorHandler:null,setSuspenseHandler:null,scheduleUpdate:null,currentDispatcherRef:R.ReactCurrentDispatcher,findHostInstanceByFiber:function(i){return i=W(i),i===null?null:i.stateNode},findFiberByHostInstance:Bo.findFiberByHostInstance||ly,findHostInstancesForRefresh:null,scheduleRefresh:null,scheduleRoot:null,setRefreshHandler:null,getCurrentFiber:null,reconcilerVersion:"18.3.1-next-f1338f8080-20240426"};if(typeof __REACT_DEVTOOLS_GLOBAL_HOOK__<"u"){var Mc=__REACT_DEVTOOLS_GLOBAL_HOOK__;if(!Mc.isDisabled&&Mc.supportsFiber)try{It=Mc.inject(dy),Vt=Mc}catch{}}return Gn.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED=uy,Gn.createPortal=function(i,r){var o=2<arguments.length&&arguments[2]!==void 0?arguments[2]:null;if(!_h(r))throw Error(t(200));return oy(i,r,null,o)},Gn.createRoot=function(i,r){if(!_h(i))throw Error(t(299));var o=!1,h="",m=dg;return r!=null&&(r.unstable_strictMode===!0&&(o=!0),r.identifierPrefix!==void 0&&(h=r.identifierPrefix),r.onRecoverableError!==void 0&&(m=r.onRecoverableError)),r=ph(i,1,!1,null,null,o,!1,h,m),i[is]=r.current,wo(i.nodeType===8?i.parentNode:i),new gh(r)},Gn.findDOMNode=function(i){if(i==null)return null;if(i.nodeType===1)return i;var r=i._reactInternals;if(r===void 0)throw typeof i.render=="function"?Error(t(188)):(i=Object.keys(i).join(","),Error(t(268,i)));return i=W(r),i=i===null?null:i.stateNode,i},Gn.flushSync=function(i){return Mr(i)},Gn.hydrate=function(i,r,o){if(!yc(r))throw Error(t(200));return Sc(null,i,r,!0,o)},Gn.hydrateRoot=function(i,r,o){if(!_h(i))throw Error(t(405));var h=o!=null&&o.hydratedSources||null,m=!1,S="",b=dg;if(o!=null&&(o.unstable_strictMode===!0&&(m=!0),o.identifierPrefix!==void 0&&(S=o.identifierPrefix),o.onRecoverableError!==void 0&&(b=o.onRecoverableError)),r=cg(r,null,i,1,o??null,m,!1,S,b),i[is]=r.current,wo(i),h)for(i=0;i<h.length;i++)o=h[i],m=o._getVersion,m=m(o._source),r.mutableSourceEagerHydrationData==null?r.mutableSourceEagerHydrationData=[o,m]:r.mutableSourceEagerHydrationData.push(o,m);return new xc(r)},Gn.render=function(i,r,o){if(!yc(r))throw Error(t(200));return Sc(null,i,r,!1,o)},Gn.unmountComponentAtNode=function(i){if(!yc(i))throw Error(t(40));return i._reactRootContainer?(Mr(function(){Sc(null,null,i,!1,function(){i._reactRootContainer=null,i[is]=null})}),!0):!1},Gn.unstable_batchedUpdates=lh,Gn.unstable_renderSubtreeIntoContainer=function(i,r,o,h){if(!yc(o))throw Error(t(200));if(i==null||i._reactInternals===void 0)throw Error(t(38));return Sc(i,r,o,!1,h)},Gn.version="18.3.1-next-f1338f8080-20240426",Gn}var Sg;function My(){if(Sg)return yh.exports;Sg=1;function n(){if(!(typeof __REACT_DEVTOOLS_GLOBAL_HOOK__>"u"||typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE!="function"))try{__REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE(n)}catch(e){console.error(e)}}return n(),yh.exports=Sy(),yh.exports}var Mg;function Ey(){if(Mg)return Ec;Mg=1;var n=My();return Ec.createRoot=n.createRoot,Ec.hydrateRoot=n.hydrateRoot,Ec}var wy=Ey();const Eg=n=>{let e;const t=new Set,s=(p,g)=>{const v=typeof p=="function"?p(e):p;if(!Object.is(v,e)){const x=e;e=g??(typeof v!="object"||v===null)?v:Object.assign({},e,v),t.forEach(y=>y(e,x))}},a=()=>e,d={setState:s,getState:a,getInitialState:()=>f,subscribe:p=>(t.add(p),()=>t.delete(p))},f=e=n(s,a,d);return d},Ty=(n=>n?Eg(n):Eg),by=n=>n;function Ay(n,e=by){const t=Qc.useSyncExternalStore(n.subscribe,Qc.useCallback(()=>e(n.getState()),[n,e]),()=>e(n.getInitialState()));return Qc.useDebugValue(t),t}const Cy=n=>{const e=Ty(n),t=s=>Ay(e,s);return Object.assign(t,e),t},Ny=(n=>Cy),wg=n=>Symbol.iterator in n,Tg=n=>"entries"in n,bg=(n,e)=>{const t=n instanceof Map?n:new Map(n.entries()),s=e instanceof Map?e:new Map(e.entries());if(t.size!==s.size)return!1;for(const[a,c]of t)if(!s.has(a)||!Object.is(c,s.get(a)))return!1;return!0},Ry=(n,e)=>{const t=n[Symbol.iterator](),s=e[Symbol.iterator]();let a=t.next(),c=s.next();for(;!a.done&&!c.done;){if(!Object.is(a.value,c.value))return!1;a=t.next(),c=s.next()}return!!a.done&&!!c.done};function Py(n,e){return Object.is(n,e)?!0:typeof n!="object"||n===null||typeof e!="object"||e===null||Object.getPrototypeOf(n)!==Object.getPrototypeOf(e)?!1:wg(n)&&wg(e)?Tg(n)&&Tg(e)?bg(n,e):Ry(n,e):bg({entries:()=>Object.entries(n)},{entries:()=>Object.entries(e)})}function ky(n){const e=Qc.useRef(void 0);return t=>{const s=n(t);return Py(e.current,s)?e.current:e.current=s}}const Or=280,av=/^[a-z0-9_]{3,16}$/,Vo=160,Ag=32,ff={ringtone:"aurora",volume:.7,dnd:!1,accent:"sao",intensity:.8,theme:"light",style:"cyberpunk"},fp=/^\d{3}-\d{4}$/,Ea=500,Eh=2,Jc=15,Ly=6,Ss=n=>String(Math.max(0,Math.floor(n))).padStart(2,"0");function Wa(n){const e=new Date(n);return`${Ss(e.getHours())}:${Ss(e.getMinutes())}`}const ov=864e5;function vi(n){const e=new Date(n);return e.setHours(0,0,0,0),e.getTime()}const lv=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],cv=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function pf(n,e=Date.now()){const t=Math.round((vi(e)-vi(n))/ov);if(t<=0)return"Today";if(t===1)return"Yesterday";const s=new Date(n);return`${lv[s.getDay()]} ${s.getDate()} ${cv[s.getMonth()]}`}function uv(n,e=Date.now()){const t=Math.round((vi(e)-vi(n))/ov);if(t<=0)return Wa(n);if(t===1)return"Yesterday";const s=new Date(n);return t<7?lv[s.getDay()]:`${s.getDate()} ${cv[s.getMonth()]}`}function Tu(n,e=Date.now()){const t=Math.max(0,(e-n)/1e3);return t<50?"now":t<3600?`${Math.round(t/60)} min ago`:t<6*3600?`${Math.round(t/3600)} h ago`:uv(n,e)}function pp(n){const e=Math.max(0,Math.floor(n)),t=Math.floor(e/3600),s=Math.floor(e%3600/60),a=e%60;return t>0?`${t}:${Ss(s)}:${Ss(a)}`:`${s}:${Ss(a)}`}function mp(n){const e=n.replace(/\D/g,"").slice(0,7);return e.length>3?`${e.slice(0,3)}-${e.slice(3)}`:e}function Dy(n){const e=n.replace(/[^\p{L}\p{N} ]/gu," ").trim().split(/\s+/).filter(Boolean);return e.length===0?"#":e.length===1?e[0].slice(0,2).toUpperCase():(e[0][0]+e[e.length-1][0]).toUpperCase()}function eu(n){let e=0;for(let t=0;t<n.length;t++)e=e*31+n.charCodeAt(t)>>>0;return e%360}function Iy(n,e){return n.find(t=>t.number===e)}function Fi(n,e,t){return Iy(n,e)?.name??(t&&t!==e?t:e)}function Cg(n,e,t){return Math.min(t,Math.max(e,n))}async function dv(n){try{if(navigator.clipboard?.writeText)return await navigator.clipboard.writeText(n),!0}catch{}try{const e=document.createElement("textarea");e.value=n,e.setAttribute("readonly",""),e.style.position="fixed",e.style.opacity="0",document.body.appendChild(e),e.select();const t=document.execCommand("copy");return e.remove(),t}catch{return!1}}let Ng=1;const hv="nl.recentsSeenAt";function Uy(){try{const n=Number(localStorage.getItem(hv));if(Number.isFinite(n)&&n>0)return n}catch{}return Date.now()-864e5}let Fy=1;const Rg=n=>n.app;function Oy(n,e){const t=n.filter(s=>s.id!==e.id);return[e,...t].sort((s,a)=>a.updatedAt-s.updatedAt)}const jy={posts:[],hasMore:!1,loading:!1,loadingMore:!1,rev:0};function Pg(n,e){let t=null;const s=a=>{a&&(n[a.id]&&(t??={...n},t[a.id]={cred:a.cred,echoes:a.echoes,replies:a.replies,credded:a.credded,echoed:a.echoed}),s(a.echoOf))};return e.forEach(s),t??n}function wc(n,e){return n.some(t=>t.id===e||t.echoOf?.id===e)?n.filter(t=>t.id!==e&&!(t.echoOf?.id===e&&!t.body)).map(t=>t.echoOf?.id===e?{...t,echoOf:null,echoGone:!0}:t):n}function kg(n,e,t){let s=null;for(const a of e)a.kind!=="text"||a.at<t||n[a.id]||(s??={...n},s[a.id]=1);return s??n}const he=Ny()((n,e)=>({state:null,phase:"closed",openSeq:0,implantFlow:!1,implantAutoStart:!1,menu:null,cursor:0,row:0,stack:[],callView:!1,navDir:"fwd",dial:"",threadCache:{},pending:[],talkers:{},toasts:[],clock:null,toggleKey:"F2",ended:null,keyboard:!1,settingsDraft:{},seenToday:{},dayStart:vi(Date.now()),recentsSeenAt:Uy(),feeds:{},screamThreads:{},profiles:{},pings:null,postLive:{},postGone:{},freshPosts:[],composeCtx:{},applyState(t){const s=e().state,a=s?.line?.number!==t.line?.number,c=e().phase,u=s?.implant?.installed===!1&&t.implant?.installed!==!1&&!e().implantFlow&&(c==="open"||c==="opening"),d=new Set((t.threads??[]).map(f=>f.id));n(f=>({state:{...t,settings:{...ff,...t.settings??{}},contacts:t.contacts??[],threads:t.threads??[],recents:t.recents??[],apps:t.apps??[],social:t.social??null},threadCache:{},...a?{feeds:{},screamThreads:{},profiles:{},pings:null,postLive:{},postGone:{},freshPosts:[],composeCtx:{}}:{},pending:[],settingsDraft:{},seenToday:a?{}:f.seenToday,stack:a?[]:f.stack.filter(p=>!("threadId"in p)||d.has(p.threadId)),menu:a?null:f.menu,callView:!!t.call&&(t.call.phase==="incoming"||f.callView),...u?{phase:"opening",openSeq:f.openSeq+1}:{}}))},applyPatch(t){const s=e().state;if(!s)return;const a={...s};Object.keys(t).forEach(u=>{t[u]!==void 0&&(a[u]=t[u])}),t.settings&&(a.settings={...ff,...t.settings});const c=new Set(a.threads.map(u=>u.id));n(u=>({state:a,settingsDraft:t.settings?{}:u.settingsDraft,stack:t.threads?u.stack.filter(d=>!("threadId"in d)||c.has(d.threadId)):u.stack}))},openUi(t){const s=e(),a=s.phase==="closed"||s.phase==="closing",c={};a&&(c.phase="opening",c.openSeq=s.openSeq+1,c.implantFlow=!1),c.implantAutoStart=t?.install===!0;const u=t?.app;if(u&&u!=="home"){let d=[],f=null;u==="messages"?(f="messages",d=[{app:"messages",screen:"list"}],typeof t.threadId=="number"&&d.push({app:"messages",screen:"thread",threadId:t.threadId})):u==="phone"?(f="phone",d=[{app:"phone",tab:t.number?"dial":"recents"}],t.number&&(c.dial=t.number)):u==="contacts"?(f="contacts",d=[{app:"contacts",screen:"list",filter:"all"}],t.number&&d.push({app:"contacts",screen:"edit",number:t.number})):u==="social"?(f="social",d=[{app:"social",screen:"feed",mode:"pulse"}],t.screen==="thread"&&typeof t.postId=="number"?d.push({app:"social",screen:"thread",postId:t.postId}):t.screen==="profile"&&t.handle?d.push({app:"social",screen:"profile",handle:t.handle}):t.screen==="tag"&&t.tag?d.push({app:"social",screen:"tag",tag:t.tag}):t.screen==="compose"?d.push({app:"social",screen:"compose"}):t.screen==="pings"?d.push({app:"social",screen:"pings"}):t.screen==="heat"?d.push({app:"social",screen:"heat"}):t.screen==="edit"&&d.push({app:"social",screen:"edit"})):u==="settings"?(f="settings",d=[{app:"settings",section:"sound"}]):u==="status"?(f="status",d=[{app:"status"}]):f=`app:${u}`,Object.assign(c,{menu:f,stack:d,callView:!1,row:0})}else if(u==="home")Object.assign(c,{menu:null,stack:[],callView:!1});else if(a){const d=s.state?.call;c.callView=!!d}n(c)},setPhase(t){n(t==="closed"?{phase:t,implantFlow:!1}:{phase:t})},closeUi(){const t=e().phase;t==="closed"||t==="closing"||n({phase:"closing"})},setImplantFlow(t){n({implantFlow:t})},implantOnline(t){const s=e();if(s.phase==="closed"||s.phase==="closing")return;const a=s.state?{...s.state,implant:t??{...s.state.implant,installed:!0,installedAt:Date.now()}}:s.state;n({state:a,implantFlow:!1,phase:"opening",openSeq:s.openSeq+1,menu:null,stack:[],callView:!1})},setMenu(t){n({menu:t,row:0,stack:[],callView:!1})},setCursor(t){n({cursor:t})},setRow(t){n({row:t})},resetView(t){n(t?{stack:[t],menu:Rg(t),callView:!1,navDir:"fwd"}:{stack:[],navDir:"back"})},pushView(t){n(s=>({stack:[...s.stack,t],menu:Rg(t),callView:!1,navDir:"fwd"}))},replaceTop(t){n(s=>({stack:[...s.stack.slice(0,-1),t]}))},back(){const t=e(),s=t.state?.call;return t.callView&&s&&s.phase!=="incoming"?(n({callView:!1}),!0):t.stack.length>1?(n({stack:t.stack.slice(0,-1),navDir:"back"}),!0):t.stack.length===1?(n({stack:[]}),!0):t.menu?(n({menu:null}),!0):!1},setCallView(t){n({callView:t})},setDial(t){n({dial:t})},threadLoading(t,s){n(a=>{const c=a.threadCache[t],u=c??{messages:[],members:[],hasMore:!1,loading:!1,loadingMore:!1,rev:0,lastOp:"load"};return{threadCache:{...a.threadCache,[t]:{...u,loading:s?u.loading:!c,loadingMore:s}}}})},threadLoaded(t){n(s=>{const a=s.threadCache[t.threadId],c=t.messages??[];let u;if(t.prepend&&a){const f=new Set(a.messages.map(p=>p.id));u=[...c.filter(p=>!f.has(p.id)),...a.messages]}else u=c;const d=new Set(u.map(f=>f.id));return{threadCache:{...s.threadCache,[t.threadId]:{messages:u,members:t.members??a?.members??[],hasMore:!!t.hasMore,loading:!1,loadingMore:!1,rev:(a?.rev??0)+1,lastOp:t.prepend?"prepend":"load"}},pending:s.pending.filter(f=>f.serverId==null||!d.has(f.serverId)),seenToday:kg(s.seenToday,c,s.dayStart)}})},messageArrived({message:t,summary:s}){n(a=>{const c=a.state?{...a.state,threads:s?Oy(a.state.threads,s):a.state.threads}:a.state,u=a.threadCache[t.threadId];let d=a.threadCache;return u&&!u.messages.some(f=>f.id===t.id)&&(d={...a.threadCache,[t.threadId]:{...u,messages:[...u.messages,t],members:s?.members??u.members,rev:u.rev+1,lastOp:"append"}}),{state:c,threadCache:d,pending:a.pending.filter(f=>f.serverId!==t.id),seenToday:kg(a.seenToday,[t],a.dayStart)}})},messageUpdated(t){n(s=>{const a=s.threadCache[t.threadId];return!a||!a.messages.some(c=>c.id===t.id)?{}:{threadCache:{...s.threadCache,[t.threadId]:{...a,messages:a.messages.map(c=>c.id===t.id?t:c),rev:a.rev+1,lastOp:"update"}}}})},setUnread(t,s){n(a=>a.state?{state:{...a.state,threads:a.state.threads.map(c=>c.id===t?{...c,unread:s}:c)}}:{})},addPending(t){n(s=>({pending:[...s.pending,t]}))},pendingSent(t,s){n(a=>({pending:Object.values(a.threadCache).some(u=>u.messages.some(d=>d.id===s))?a.pending.filter(u=>u.tempId!==t):a.pending.map(u=>u.tempId===t?{...u,serverId:s}:u)}))},pendingFailed(t){n(s=>({pending:s.pending.map(a=>a.tempId===t?{...a,failed:!0}:a)}))},dropPending(t){n(s=>({pending:s.pending.filter(a=>a.tempId!==t)}))},setCall(t){n(s=>{const a=s.state?.call??null,c=s.state?{...s.state,call:t}:s.state;let u=s.callView;return t?(t.phase==="incoming"||!a||a.id!==t.id||a.phase==="incoming")&&(u=!0):u=!1,{state:c,callView:u,talkers:t?s.talkers:{}}})},setTalkers(t){n({talkers:t??{}})},pushToast(t){n(s=>{const a={...t,id:t.id??`t${Ng}`,at:t.at??Date.now(),key:Ng++,born:Date.now()};return{toasts:[...s.toasts.filter(u=>u.id!==a.id),a].slice(-3)}})},dismissToast(t){n(s=>({toasts:s.toasts.filter(a=>a.key!==t)}))},setClock(t){n({clock:t})},setToggleKey(t){n({toggleKey:t})},setEnded(t){n({ended:t?{...t,key:Fy++}:null})},setKeyboard(t){n({keyboard:t})},setSettingsDraft(t){n(s=>({settingsDraft:{...s.settingsDraft,...t}}))},replaceSettingsDraft(t){n({settingsDraft:t})},markRecentsSeen(){const t=Date.now();try{localStorage.setItem(hv,String(t))}catch{}n({recentsSeenAt:t})},setSocialUnread(t){n(s=>s.state?.social?{state:{...s.state,social:{...s.state.social,unread:Math.max(0,t)}}}:{})},setSocialHandle(t){n(s=>{const a=s.state?.social?.handle;if(!s.state?.social||!a||a===t)return{};const{[a]:c,...u}=s.profiles;return{state:{...s.state,social:{...s.state.social,handle:t}},profiles:u,stack:s.stack.map(d=>d.app==="social"&&d.screen==="profile"&&d.handle===a?{...d,handle:t}:d)}})},feedLoading(t,s){n(a=>{const c=a.feeds[t];return{feeds:{...a.feeds,[t]:{...c??jy,loading:s?!!c?.loading:!c,loadingMore:s}}}})},feedLoaded(t,s,a,c){n(u=>{const d=u.feeds[t];let f=s;if(c&&d){const v=new Set(d.posts.map(x=>x.id));f=[...d.posts,...s.filter(x=>!v.has(x.id))]}const p=s[0]?.id??0,g=t==="pulse"&&!c?u.freshPosts.filter(v=>v.id>p):u.freshPosts;return{feeds:{...u.feeds,[t]:{posts:f,hasMore:a,loading:!1,loadingMore:!1,rev:(d?.rev??0)+1}},postLive:Pg(u.postLive,s),freshPosts:g}})},feedFailed(t){n(s=>{const a=s.feeds[t];return a?{feeds:{...s.feeds,[t]:{...a,loading:!1,loadingMore:!1}}}:{}})},prependPosts(t,s){n(a=>{const c=a.feeds[t];if(!c)return{};const u=s.filter(d=>!c.posts.some(f=>f.id===d.id));return u.length?{feeds:{...a.feeds,[t]:{...c,posts:[...u,...c.posts],rev:c.rev+1}}}:{}})},screamThreadLoading(t){n(s=>{const a=s.screamThreads[t];return{screamThreads:{...s.screamThreads,[t]:a?{...a,loading:!a.post}:{post:null,parents:[],replies:[],loading:!0,missing:!1}}}})},screamThreadLoaded(t,s){n(a=>{const c=a.screamThreads[t];return s?{screamThreads:{...a.screamThreads,[t]:{...s,loading:!1,missing:!1}},postLive:Pg(a.postLive,[...s.post?[s.post]:[],...s.parents,...s.replies])}:{screamThreads:{...a.screamThreads,[t]:{post:c?.post??null,parents:c?.parents??[],replies:c?.replies??[],loading:!1,missing:!c?.post}}}})},addReply(t,s){n(a=>{const c=a.screamThreads[t],u=a.postLive[t],d=c?.post??Object.values(a.feeds).flatMap(f=>f.posts).find(f=>f.id===t);return{screamThreads:c&&!c.replies.some(f=>f.id===s.id)?{...a.screamThreads,[t]:{...c,replies:[...c.replies,s]}}:a.screamThreads,postLive:{...a.postLive,[t]:{...u,replies:(u?.replies??d?.replies??0)+1}}}})},setProfile(t){n(s=>({profiles:{...s.profiles,[t.handle]:t}}))},pingsLoading(t){n(s=>({pings:{pings:s.pings?.pings??[],hasMore:s.pings?.hasMore??!1,loading:t?!!s.pings?.loading:!s.pings,loadingMore:t}}))},pingsLoaded(t,s,a){n(c=>{const u=c.pings?.pings??[],d=new Set(u.filter(g=>!g.read).map(g=>g.id)),f=t.map(g=>d.has(g.id)?{...g,read:!1}:g);return{pings:{pings:a?[...u,...f.filter(g=>!u.some(v=>v.id===g.id))]:f,hasMore:s,loading:!1,loadingMore:!1}}})},pingsSeen(){n(t=>t.pings?{pings:{...t.pings,pings:t.pings.pings.map(s=>s.read?s:{...s,read:!0})}}:{})},setPostLive(t,s){n(a=>({postLive:{...a.postLive,[t]:{...a.postLive[t],...s}}}))},removePost(t){n(s=>{const a={};for(const[u,d]of Object.entries(s.feeds)){const f=wc(d.posts,t);a[u]=f===d.posts?d:{...d,posts:f,rev:d.rev+1}}const c={};for(const[u,d]of Object.entries(s.screamThreads)){if(Number(u)===t)continue;const f=d.post?.echoOf?.id===t?{...d.post,echoOf:null,echoGone:!0}:d.post;c[Number(u)]={...d,post:f,parents:wc(d.parents,t),replies:wc(d.replies,t)}}return{feeds:a,screamThreads:c,postGone:{...s.postGone,[t]:1},freshPosts:wc(s.freshPosts,t)}})},pushFresh(t){n(s=>s.freshPosts.some(a=>a.id===t.id)||s.feeds.pulse?.posts.some(a=>a.id===t.id)?{}:{freshPosts:[t,...s.freshPosts].slice(0,50)})},takeFresh(){const t=e().freshPosts;return n({freshPosts:[]}),t},rememberPost(t){n(s=>({composeCtx:{...s.composeCtx,[t.id]:t}}))}})),gp=n=>({...ff,...n.state?.settings??{},...n.settingsDraft}),_p=n=>n.stack[n.stack.length-1]??null,be=()=>he.getState(),fv=n=>n.state?.implant?.installed===!1,mf=n=>!!n.state?.ready&&(fv(n)||n.implantFlow),gf=n=>fv(n)||n.implantFlow,eo=()=>he(ky(gp));function zy(n){const e=he(t=>t.postLive[n.id]);return e?{...n,...e}:n}const kn=[];function By({children:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=()=>{const s=e.current;if(!s)return;const a=window.innerWidth,c=window.innerHeight,u=Math.min(a/1920,c/1080),d=(a-1920*u)/2,f=(c-1080*u)/2;s.style.transform=`translate(${d}px, ${f}px) scale(${u})`,document.documentElement.style.setProperty("--stage-scale",String(u))};return t(),window.addEventListener("resize",t),()=>window.removeEventListener("resize",t)},[]),l.jsx("div",{ref:e,className:"nl-stage",children:n})}function Hy(){const n=eo();q.useEffect(()=>{const e=document.documentElement;e.dataset.accent=n.accent,e.dataset.theme=n.theme==="dark"?"dark":"light",e.dataset.style=n.style==="sao"?"sao":"cyberpunk";const t=Math.min(1,Math.max(.3,Number.isFinite(n.intensity)?n.intensity:.8));e.style.setProperty("--intensity",t.toFixed(2))},[n.accent,n.intensity,n.theme,n.style]),q.useEffect(()=>{const e=window.matchMedia?.("(prefers-reduced-motion: reduce)"),t=()=>{document.documentElement.dataset.motion=e?.matches?"reduced":"full"};return t(),e?.addEventListener?.("change",t),()=>e?.removeEventListener?.("change",t)},[])}function sr(){return document.documentElement.dataset.motion==="reduced"}const Vy=new Set(["contacts","threads","recents","apps","members","participants","messages","numbers","actions","posts","parents","replies","profiles","pings","tags","districts","hot"]);function Gy(n){if(Array.isArray(n))return n;if(n&&typeof n=="object"){const e=Object.entries(n);if(e.length===0)return[];if(e.every(([t])=>/^\d+$/.test(t)))return e.sort((t,s)=>Number(t[0])-Number(s[0])).map(([,t])=>t)}return[]}function Qo(n,e){if(e>8||n===null||typeof n!="object")return n;if(Array.isArray(n))return n.map(s=>Qo(s,e+1));const t={};for(const[s,a]of Object.entries(n))t[s]=Vy.has(s)&&a!==null&&typeof a=="object"?Gy(a).map(c=>Qo(c,e+1)):Qo(a,e+1);return t}function Lg(n){return!!n&&typeof n=="object"&&typeof n.id=="number"}function Dg(n){return Qo(n,0)}function Wy(n,e){if(n==="nl:talkers")return e;if(n==="nl:call"&&!Lg(e))return null;const t=Qo(e,0);return n==="nl:state"&&t&&typeof t=="object"&&"call"in t&&!Lg(t.call)&&(t.call=null),t}const Ig=new Map,bu=()=>window.Open77;function Un(n,e){let t=Ig.get(n);if(!t){const s=new Set;Ig.set(n,s),t=s,bu()?.on(n,a=>{const c=Wy(n,a);for(const u of s)try{u(c)}catch(d){console.error(`[neuralink] handler ${n} failed`,d)}})}return t.add(e),()=>{t?.delete(e)}}function Au(n,e){try{bu()?.emit(n,e)}catch(t){console.error(`[neuralink] emit ${n} failed`,t)}}function $y(n){Au("nl:sound",{name:n})}let Ug=!1;function Xy(){Ug||(Ug=!0,bu()?.ready())}class Sn extends Error{constructor(e){super(e),this.slug=e,this.name="RequestError"}}function Fg(n){const e=n.trim();if(e.startsWith('"')||e.startsWith("{"))try{const t=JSON.parse(e);if(typeof t=="string")return t;if(t&&typeof t=="object")return pv(t)}catch{}return e}function pv(n){if(n instanceof Sn)return n.slug;if(n instanceof Error)return n.message?Fg(n.message):"unknown";if(typeof n=="string")return Fg(n);if(n&&typeof n=="object"){const e=n;for(const t of[e.reason,e.error,e.message])if(typeof t=="string"&&t)return t}return"unknown"}async function to(n,e){const t=bu();if(!t?.invoke)throw new Sn("unavailable");let s;try{s=await t.invoke("nl:request",{op:n,args:e})}catch(c){throw new Sn(pv(c))}const a=s;if(a&&typeof a=="object"&&"ok"in a){if(a.ok)return Dg(a.data??{});throw new Sn(a.reason??a.error??"unknown")}return Dg(s??{})}function mv(){return!!window.__neuralinkMock}let Og=0;function Me(n){const e=gp(be());if(n==="chime"&&e.dnd)return;const t=Math.max(0,Math.min(1,e.volume));if(!(t<=.001)){if(n==="tick"){const s=performance.now();if(s-Og<60)return;Og=s}mv()&&console.debug(`[neuralink] sound ${n}`),Au("nl:sound",{name:`ui:${n}`,volume:t})}}function qy(){const n=eo().style!=="sao";return q.useEffect(()=>{if(!n)return;const e=window.setTimeout(()=>Me("glitch"),90);return()=>window.clearTimeout(e)},[n]),l.jsxs("div",{className:"linkstart","aria-hidden":!0,children:[l.jsx("span",{className:"linkstart__flash"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--a"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--b"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--c"}),l.jsx("span",{className:"linkstart__cross"}),l.jsx("div",{className:"linkstart__band",children:l.jsxs("svg",{width:"100%",height:"100%",children:[l.jsx("defs",{children:l.jsx("pattern",{id:"nl-hex",width:"28",height:"48.5",patternUnits:"userSpaceOnUse",patternTransform:"scale(1.1)",children:l.jsx("path",{d:"M14 0 L28 8.08 L28 24.25 L14 32.33 L0 24.25 L0 8.08 Z M14 32.33 L14 48.5",fill:"none",stroke:"currentColor",strokeWidth:"1.1"})})}),l.jsx("rect",{width:"100%",height:"100%",fill:"url(#nl-hex)"})]})}),l.jsxs("div",{className:"linkstart__text",children:[l.jsx("span",{className:"linkstart__word label",children:n?"Neural-Link":"Link start"}),l.jsx("span",{className:"linkstart__sub mono",children:n?"kiroshi nl-77 · synapse handshake ok":"neural handshake · ok"})]})]})}const Yy=90,wh=960,Go=540;function Ky({running:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=e.current;if(!t||!n||sr())return;const s=t.getContext("2d",{alpha:!0});if(!s)return;const a=()=>Number(getComputedStyle(document.documentElement).getPropertyValue("--intensity"))||.8,c=()=>getComputedStyle(document.documentElement).getPropertyValue("--holo-rgb").trim()||"0, 229, 255";let u=a(),d=c();const f=w=>({x:40+Math.random()*880,y:w?Math.random()*Go:Go+10,vx:(Math.random()-.5)*.12,vy:-(.08+Math.random()*.28),r:.5+Math.random()*1.5,a:.15+Math.random()*.5,tw:Math.random()*Math.PI*2,hue:Math.random()<.72?0:1}),p=Array.from({length:Yy},()=>f(!0));let g=0,v=performance.now(),x=0;const y=w=>{g=requestAnimationFrame(y);const E=Math.min(50,w-v)/16.67;v=w,++x%120===0&&(u=a(),d=c()),s.clearRect(0,0,wh,Go);for(const _ of p){_.x+=_.vx*E,_.y+=_.vy*E,_.tw+=.03*E,_.y<-10&&Object.assign(_,f(!1));const M=_.a*(.55+.45*Math.sin(_.tw))*u;s.fillStyle=_.hue===0?`rgba(${d}, ${M.toFixed(3)})`:`rgba(255, 255, 255, ${(M*.9).toFixed(3)})`,s.beginPath(),s.arc(_.x,_.y,_.r,0,Math.PI*2),s.fill()}};return g=requestAnimationFrame(y),()=>{cancelAnimationFrame(g),s.clearRect(0,0,wh,Go)}},[n]),l.jsx("canvas",{ref:e,className:"particles",width:wh,height:Go,"aria-hidden":!0})}const ri={x:0,y:0,t:0};let gv=0,_v=0,vv=0;function Zy(n,e){gv=n,_v=e,vv=performance.now()}function Qy(n,e){ri.t+=n;const t=Math.min(1,Math.max(0,(performance.now()-vv-2500)/2500)),s=Math.sin(ri.t*.31)*.16+Math.sin(ri.t*.73)*.04,a=Math.sin(ri.t*.23+1.3)*.1,c=gv*(1-t*.6)+s*t,u=_v*(1-t*.6)+a*t,d=1-Math.exp(-n*4.2);ri.x+=(c-ri.x)*d,ri.y+=(u-ri.y)*d}const Tc=960,Th=540,Jy=86,eS=3;function jg(n,e){const t=document.createElement("canvas");t.width=t.height=e;const s=t.getContext("2d"),a=s.createRadialGradient(e/2,e/2,0,e/2,e/2,e/2);return a.addColorStop(0,"rgba(255,255,255,1)"),a.addColorStop(.18,`rgba(${n},0.95)`),a.addColorStop(.45,`rgba(${n},0.28)`),a.addColorStop(1,`rgba(${n},0)`),s.fillStyle=a,s.fillRect(0,0,e,e),t}function tS({running:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=e.current;if(!t||!n||sr())return;const s=t.getContext("2d",{alpha:!0});if(!s)return;const a=jg("46,230,245",32),c=jg("255,59,72",32),u=Math.random,d=Array.from({length:Jy},()=>{let E=u()*2-1;E=Math.sign(E)*Math.pow(Math.abs(E),.6);const _=u()*2-1,M=.25+Math.hypot(E+.4,_*.6)*.75;return{x:E,y:_,z:.25+u()*.75,vx:(u()-.5)*.012,vy:(u()-.5)*.01,ph:u()*6.28,fire:0,sx:0,sy:0,a:0,wake:M}}),f=[];d.forEach((E,_)=>{const M=d.map((L,A)=>({j:A,d:(L.x-E.x)**2+((L.y-E.y)*.6)**2+(L.z-E.z)**2})).filter(L=>L.j!==_).sort((L,A)=>L.d-A.d).slice(0,eS);for(const L of M)f.some(([A,R])=>A===L.j&&R===_||A===_&&R===L.j)||f.push([_,L.j])});const p=[];let g=0,v=performance.now(),x=0,y=0;const w=E=>{const _=Math.min(.05,Math.max(0,(E-v)/1e3));v=E,y+=_,s.clearRect(0,0,Tc,Th);const M=ri.x,L=ri.y;for(const A of d){A.x+=A.vx*_,A.y+=A.vy*_,(A.x<-1.15||A.x>1.15)&&(A.vx*=-1),(A.y<-1.15||A.y>1.15)&&(A.vy*=-1),A.fire=Math.max(0,A.fire-_*1.8),A.wake>0&&y>=A.wake&&(A.wake=0,A.fire=1);const R=A.z;A.sx=(.5+A.x*.5)*Tc-M*22*R,A.sy=(.5+A.y*.5)*Th-L*13*R;const k=Math.abs(A.sx/Tc-.5)*2;A.a=(.25+.75*Math.min(1,Math.max(0,(k-.12)/.5)))*(.35+.65*R)}s.lineWidth=.6;for(const[A,R]of f){const k=d[A],D=d[R],U=Math.min(k.a,D.a)*.28+Math.max(k.fire,D.fire)*.35;U<.02||(s.strokeStyle=`rgba(46,230,245,${U.toFixed(3)})`,s.beginPath(),s.moveTo(k.sx,k.sy),s.lineTo(D.sx,D.sy),s.stroke())}for(const A of d){const R=(3+A.z*5)*(1+A.fire*1.6)*(.85+.15*Math.sin(ri.t*2+A.ph));s.globalAlpha=Math.min(1,A.a*(.55+A.fire)),s.drawImage(A.fire>.5?c:a,A.sx-R,A.sy-R,R*2,R*2)}if(x-=_,x<=0&&p.length<26){x=.05+u()*.12;const[A,R]=f[Math.floor(u()*f.length)],k=u()<.5;p.push({from:k?A:R,to:k?R:A,t:0,speed:.6+u()*.9,red:u()<.16})}for(let A=p.length-1;A>=0;A--){const R=p[A];R.t+=_*R.speed;const k=d[R.from],D=d[R.to];if(R.t>=1){if(D.fire=Math.max(D.fire,R.red?1:.7),p.splice(A,1),u()<.35&&p.length<26){const J=f.filter(([ve,V])=>ve===R.to||V===R.to),ae=J[Math.floor(u()*J.length)];ae&&p.push({from:R.to,to:ae[0]===R.to?ae[1]:ae[0],t:0,speed:R.speed,red:R.red})}continue}const U=k.sx+(D.sx-k.sx)*R.t,$=k.sy+(D.sy-k.sy)*R.t,te=Math.min(k.a,D.a)+.25,T=R.red?7:5.5;s.globalAlpha=Math.min(1,te),s.drawImage(R.red?c:a,U-T,$-T,T*2,T*2),s.globalAlpha=Math.min(1,te*.4);const P=k.sx+(D.sx-k.sx)*Math.max(0,R.t-.06),re=k.sy+(D.sy-k.sy)*Math.max(0,R.t-.06);s.drawImage(R.red?c:a,P-T*.7,re-T*.7,T*1.4,T*1.4)}s.globalAlpha=1,g=requestAnimationFrame(w)};return g=requestAnimationFrame(w),()=>cancelAnimationFrame(g)},[n]),l.jsx("canvas",{ref:e,className:"neural-field",width:Tc,height:Th,"aria-hidden":!0})}const nS=2;function iS(n,e){const t=Math.max(30,(e.x-n.x)*.5);return`M${n.x.toFixed(1)},${n.y.toFixed(1)} C${(n.x+t).toFixed(1)},${n.y.toFixed(1)} ${(e.x-t).toFixed(1)},${e.y.toFixed(1)} ${e.x.toFixed(1)},${e.y.toFixed(1)}`}function sS(){const n=q.useRef(null);return q.useEffect(()=>{const e=n.current;if(!e)return;const t=Array.from(e.querySelectorAll(".syn"));let s=0;const a=performance.now(),c=u=>{s=requestAnimationFrame(c);const d=document.querySelector(".nl-stage");if(!d)return;const f=d.getBoundingClientRect(),p=f.width/1920||1,g=(A,R)=>({x:(A-f.left)/p,y:(R-f.top)/p}),v=A=>{const R=document.querySelector(A);return R?R.getBoundingClientRect():null},x=v(".column .rb.is-selected .rb__disc"),y=v(".subpanel__head"),w=v(".subpanel .slab.is-active"),E=v(".tilt--window .nl3d__face")??v(".tilt--call .nl3d__face"),_=[null,null];x&&y&&(_[0]=[g(x.right+2,x.top+x.height/2),g(y.left-2,y.top+y.height/2)]);const M=w??(y?null:x);if(M&&E){const A=Math.min(E.bottom-90*p,Math.max(E.top+90*p,M.top+M.height/2));_[1]=[g(M.right+2,M.top+M.height/2),g(E.left+4,A)]}const L=(u-a)/1e3;_.forEach((A,R)=>{const k=t[R];if(!k)return;if(!A){k.style.opacity="0";return}k.style.opacity="1";const D=iS(A[0],A[1]),U=k.querySelectorAll("path");U.forEach(re=>re.setAttribute("d",D));const $=U[1],te=$.getTotalLength();k.querySelectorAll("circle.syn__dot").forEach((re,J)=>{const ae=(L*(.55+J*.17)+J*.5)%1,ve=$.getPointAtLength(ae*te);re.setAttribute("cx",ve.x.toFixed(1)),re.setAttribute("cy",ve.y.toFixed(1)),re.setAttribute("opacity",Math.sin(ae*Math.PI).toFixed(2))});const[T,P]=k.querySelectorAll("circle.syn__end");T?.setAttribute("cx",A[0].x.toFixed(1)),T?.setAttribute("cy",A[0].y.toFixed(1)),P?.setAttribute("cx",A[1].x.toFixed(1)),P?.setAttribute("cy",A[1].y.toFixed(1))})};return sr()?c(performance.now()):s=requestAnimationFrame(c),()=>cancelAnimationFrame(s)},[]),l.jsxs("svg",{ref:n,className:"synapse",width:1920,height:1080,viewBox:"0 0 1920 1080","aria-hidden":!0,children:[l.jsx("defs",{children:l.jsx("filter",{id:"syn-bloom",x:"-20%",y:"-50%",width:"140%",height:"200%",children:l.jsx("feGaussianBlur",{stdDeviation:"4"})})}),Array.from({length:nS},(e,t)=>l.jsxs("g",{className:`syn syn--${t}`,style:{opacity:0},children:[l.jsx("path",{className:"syn__bloom",filter:"url(#syn-bloom)"}),l.jsx("path",{className:"syn__core"}),l.jsx("path",{className:"syn__flow"}),l.jsx("circle",{className:"syn__end",r:3.2}),l.jsx("circle",{className:"syn__end",r:3.2}),l.jsx("circle",{className:"syn__dot",r:4}),l.jsx("circle",{className:"syn__dot",r:3})]},t))]})}/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const rS=n=>n.replace(/([a-z0-9])([A-Z])/g,"$1-$2").toLowerCase(),xv=(...n)=>n.filter((e,t,s)=>!!e&&e.trim()!==""&&s.indexOf(e)===t).join(" ").trim();/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */var aS={xmlns:"http://www.w3.org/2000/svg",width:24,height:24,viewBox:"0 0 24 24",fill:"none",stroke:"currentColor",strokeWidth:2,strokeLinecap:"round",strokeLinejoin:"round"};/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const oS=q.forwardRef(({color:n="currentColor",size:e=24,strokeWidth:t=2,absoluteStrokeWidth:s,className:a="",children:c,iconNode:u,...d},f)=>q.createElement("svg",{ref:f,...aS,width:e,height:e,stroke:n,strokeWidth:s?Number(t)*24/Number(e):t,className:xv("lucide",a),...d},[...u.map(([p,g])=>q.createElement(p,g)),...Array.isArray(c)?c:[c]]));/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const ge=(n,e)=>{const t=q.forwardRef(({className:s,...a},c)=>q.createElement(oS,{ref:c,iconNode:e,className:xv(`lucide-${rS(n)}`,s),...a}));return t.displayName=`${n}`,t};/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const lS=[["path",{d:"M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2",key:"169zse"}]],uu=ge("Activity",lS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const cS=[["rect",{x:"2",y:"4",width:"20",height:"16",rx:"2",key:"izxlao"}],["path",{d:"M10 4v4",key:"pp8u80"}],["path",{d:"M2 8h20",key:"d11cs7"}],["path",{d:"M6 4v4",key:"1svtjw"}]],yv=ge("AppWindow",cS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const uS=[["path",{d:"m12 19-7-7 7-7",key:"1l729n"}],["path",{d:"M19 12H5",key:"x3x0zl"}]],dS=ge("ArrowLeft",uS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const hS=[["path",{d:"m5 12 7-7 7 7",key:"hav0vg"}],["path",{d:"M12 19V5",key:"x0mq9r"}]],fS=ge("ArrowUp",hS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const pS=[["circle",{cx:"12",cy:"12",r:"4",key:"4exip2"}],["path",{d:"M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8",key:"7n84p3"}]],Sv=ge("AtSign",pS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const mS=[["rect",{width:"20",height:"12",x:"2",y:"6",rx:"2",key:"9lu3g6"}],["circle",{cx:"12",cy:"12",r:"2",key:"1c9p78"}],["path",{d:"M6 12h.01M18 12h.01",key:"113zkx"}]],gS=ge("Banknote",mS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const _S=[["path",{d:"M10.268 21a2 2 0 0 0 3.464 0",key:"vwvbt9"}],["path",{d:"M17 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 .258-1.742",key:"178tsu"}],["path",{d:"m2 2 20 20",key:"1ooewy"}],["path",{d:"M8.668 3.01A6 6 0 0 1 18 8c0 2.687.77 4.653 1.707 6.05",key:"1hqiys"}]],vS=ge("BellOff",_S);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const xS=[["path",{d:"M10.268 21a2 2 0 0 0 3.464 0",key:"vwvbt9"}],["path",{d:"M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326",key:"11g9vi"}]],_f=ge("Bell",xS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const yS=[["circle",{cx:"18.5",cy:"17.5",r:"3.5",key:"15x4ox"}],["circle",{cx:"5.5",cy:"17.5",r:"3.5",key:"1noe27"}],["circle",{cx:"15",cy:"5",r:"1",key:"19l28e"}],["path",{d:"M12 17.5V14l-3-3 4-3 2 3h2",key:"1npguv"}]],SS=ge("Bike",yS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const MS=[["path",{d:"M15 13a3 3 0 1 0-6 0",key:"10j68g"}],["path",{d:"M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20",key:"k3hazp"}],["circle",{cx:"12",cy:"8",r:"2",key:"1822b1"}]],sl=ge("BookUser",MS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const ES=[["path",{d:"M12 8V4H8",key:"hb8ula"}],["rect",{width:"16",height:"12",x:"4",y:"8",rx:"2",key:"enze0r"}],["path",{d:"M2 14h2",key:"vft8re"}],["path",{d:"M20 14h2",key:"4cs60a"}],["path",{d:"M15 13v2",key:"1xurst"}],["path",{d:"M9 13v2",key:"rq6x2g"}]],wS=ge("Bot",ES);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const TS=[["path",{d:"M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16",key:"jecpp"}],["rect",{width:"20",height:"14",x:"2",y:"6",rx:"2",key:"i6l2r4"}]],bS=ge("Briefcase",TS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const AS=[["path",{d:"M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z",key:"1b4qmf"}],["path",{d:"M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2",key:"i71pzd"}],["path",{d:"M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2",key:"10jefs"}],["path",{d:"M10 6h4",key:"1itunk"}],["path",{d:"M10 10h4",key:"tcdvrf"}],["path",{d:"M10 14h4",key:"kelpxr"}],["path",{d:"M10 18h4",key:"1ulq68"}]],CS=ge("Building2",AS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const NS=[["path",{d:"M8 2v4",key:"1cmpym"}],["path",{d:"M16 2v4",key:"4m81vk"}],["rect",{width:"18",height:"18",x:"3",y:"4",rx:"2",key:"1hopcy"}],["path",{d:"M3 10h18",key:"8toen8"}],["path",{d:"M8 14h.01",key:"6423bh"}],["path",{d:"M12 14h.01",key:"1etili"}],["path",{d:"M16 14h.01",key:"1gbofw"}],["path",{d:"M8 18h.01",key:"lrp35t"}],["path",{d:"M12 18h.01",key:"mhygvu"}],["path",{d:"M16 18h.01",key:"kzsmim"}]],RS=ge("CalendarDays",NS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const PS=[["path",{d:"M8 2v4",key:"1cmpym"}],["path",{d:"M16 2v4",key:"4m81vk"}],["rect",{width:"18",height:"18",x:"3",y:"4",rx:"2",key:"1hopcy"}],["path",{d:"M3 10h18",key:"8toen8"}]],kS=ge("Calendar",PS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const LS=[["path",{d:"M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z",key:"1tc9qg"}],["circle",{cx:"12",cy:"13",r:"3",key:"1vg3eu"}]],DS=ge("Camera",LS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const IS=[["path",{d:"m21 8-2 2-1.5-3.7A2 2 0 0 0 15.646 5H8.4a2 2 0 0 0-1.903 1.257L5 10 3 8",key:"1imjwt"}],["path",{d:"M7 14h.01",key:"1qa3f1"}],["path",{d:"M17 14h.01",key:"7oqj8z"}],["rect",{width:"18",height:"8",x:"3",y:"10",rx:"2",key:"a7itu8"}],["path",{d:"M5 18v2",key:"ppbyun"}],["path",{d:"M19 18v2",key:"gy7782"}]],US=ge("CarFront",IS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const FS=[["path",{d:"M10 2h4",key:"n1abiw"}],["path",{d:"m21 8-2 2-1.5-3.7A2 2 0 0 0 15.646 5H8.4a2 2 0 0 0-1.903 1.257L5 10 3 8",key:"1imjwt"}],["path",{d:"M7 14h.01",key:"1qa3f1"}],["path",{d:"M17 14h.01",key:"7oqj8z"}],["rect",{width:"18",height:"8",x:"3",y:"10",rx:"2",key:"a7itu8"}],["path",{d:"M5 18v2",key:"ppbyun"}],["path",{d:"M19 18v2",key:"gy7782"}]],OS=ge("CarTaxiFront",FS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const jS=[["path",{d:"M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2",key:"5owen"}],["circle",{cx:"7",cy:"17",r:"2",key:"u2ysq9"}],["path",{d:"M9 17h6",key:"r8uit2"}],["circle",{cx:"17",cy:"17",r:"2",key:"axvx0g"}]],zS=ge("Car",jS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const BS=[["path",{d:"M20 6 9 17l-5-5",key:"1gmf2c"}]],vp=ge("Check",BS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const HS=[["path",{d:"m9 18 6-6-6-6",key:"mthhwq"}]],VS=ge("ChevronRight",HS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const GS=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["circle",{cx:"12",cy:"10",r:"3",key:"ilqhr7"}],["path",{d:"M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662",key:"154egf"}]],WS=ge("CircleUser",GS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const $S=[["path",{d:"M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242",key:"1pljnt"}],["path",{d:"M16 17H7",key:"pygtm1"}],["path",{d:"M17 21H9",key:"1u2q02"}]],XS=ge("CloudFog",$S);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const qS=[["path",{d:"M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 .5 8.973",key:"1cez44"}],["path",{d:"m13 12-3 5h4l-3 5",key:"1t22er"}]],YS=ge("CloudLightning",qS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const KS=[["path",{d:"M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242",key:"1pljnt"}],["path",{d:"M16 14v6",key:"1j4efv"}],["path",{d:"M8 14v6",key:"17c4r9"}],["path",{d:"M12 16v6",key:"c8a4gj"}]],ZS=ge("CloudRain",KS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const QS=[["path",{d:"M12 2v2",key:"tus03m"}],["path",{d:"m4.93 4.93 1.41 1.41",key:"149t6j"}],["path",{d:"M20 12h2",key:"1q8mjw"}],["path",{d:"m19.07 4.93-1.41 1.41",key:"1shlcs"}],["path",{d:"M15.947 12.65a4 4 0 0 0-5.925-4.128",key:"dpwdj0"}],["path",{d:"M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z",key:"s09mg5"}]],JS=ge("CloudSun",QS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const e2=[["path",{d:"M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z",key:"p7xjir"}]],t2=ge("Cloud",e2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const n2=[["path",{d:"M16 2v2",key:"scm5qe"}],["path",{d:"M7 22v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2",key:"1waht3"}],["path",{d:"M8 2v2",key:"pbkmx"}],["circle",{cx:"12",cy:"11",r:"3",key:"itu57m"}],["rect",{x:"3",y:"4",width:"18",height:"18",rx:"2",key:"12vinp"}]],i2=ge("Contact",n2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const s2=[["rect",{width:"14",height:"14",x:"8",y:"8",rx:"2",ry:"2",key:"17jyea"}],["path",{d:"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2",key:"zix9uf"}]],Mv=ge("Copy",s2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const r2=[["rect",{width:"16",height:"16",x:"4",y:"4",rx:"2",key:"14l7u7"}],["rect",{width:"6",height:"6",x:"9",y:"9",rx:"1",key:"5aljv4"}],["path",{d:"M15 2v2",key:"13l42r"}],["path",{d:"M15 20v2",key:"15mkzm"}],["path",{d:"M2 15h2",key:"1gxd5l"}],["path",{d:"M2 9h2",key:"1bbxkp"}],["path",{d:"M20 15h2",key:"19e6y8"}],["path",{d:"M20 9h2",key:"19tzq7"}],["path",{d:"M9 2v2",key:"165o2o"}],["path",{d:"M9 20v2",key:"i2bqo8"}]],xp=ge("Cpu",r2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const a2=[["rect",{width:"20",height:"14",x:"2",y:"5",rx:"2",key:"ynyp8z"}],["line",{x1:"2",x2:"22",y1:"10",y2:"10",key:"1b3vmo"}]],o2=ge("CreditCard",a2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const l2=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["line",{x1:"22",x2:"18",y1:"12",y2:"12",key:"l9bcsi"}],["line",{x1:"6",x2:"2",y1:"12",y2:"12",key:"13hhkx"}],["line",{x1:"12",x2:"12",y1:"6",y2:"2",key:"10w3f3"}],["line",{x1:"12",x2:"12",y1:"22",y2:"18",key:"15g9kq"}]],c2=ge("Crosshair",l2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const u2=[["path",{d:"M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z",key:"1vdc57"}],["path",{d:"M5 21h14",key:"11awu3"}]],d2=ge("Crown",u2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const h2=[["path",{d:"M10 5a2 2 0 0 0-1.344.519l-6.328 5.74a1 1 0 0 0 0 1.481l6.328 5.741A2 2 0 0 0 10 19h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z",key:"1yo7s0"}],["path",{d:"m12 9 6 6",key:"anjzzh"}],["path",{d:"m18 9-6 6",key:"1fp51s"}]],f2=ge("Delete",h2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const p2=[["circle",{cx:"12",cy:"12",r:"1",key:"41hilf"}],["circle",{cx:"19",cy:"12",r:"1",key:"1wjl8i"}],["circle",{cx:"5",cy:"12",r:"1",key:"1pcz8c"}]],m2=ge("Ellipsis",p2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const g2=[["path",{d:"M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4",key:"1nerag"}],["path",{d:"M14 13.12c0 2.38 0 6.38-1 8.88",key:"o46ks0"}],["path",{d:"M17.29 21.02c.12-.6.43-2.3.5-3.02",key:"ptglia"}],["path",{d:"M2 12a10 10 0 0 1 18-6",key:"ydlgp0"}],["path",{d:"M2 16h.01",key:"1gqxmh"}],["path",{d:"M21.8 16c.2-2 .131-5.354 0-6",key:"drycrb"}],["path",{d:"M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2",key:"1tidbn"}],["path",{d:"M8.65 22c.21-.66.45-1.32.57-2",key:"13wd9y"}],["path",{d:"M9 6.8a6 6 0 0 1 9 5.2v2",key:"1fr1j5"}]],_2=ge("Fingerprint",g2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const v2=[["path",{d:"M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z",key:"i9b6wo"}],["line",{x1:"4",x2:"4",y1:"22",y2:"15",key:"1cm3nv"}]],x2=ge("Flag",v2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const y2=[["path",{d:"M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z",key:"96xj49"}]],Cu=ge("Flame",y2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const S2=[["line",{x1:"6",x2:"10",y1:"11",y2:"11",key:"1gktln"}],["line",{x1:"8",x2:"8",y1:"9",y2:"13",key:"qnk9ow"}],["line",{x1:"15",x2:"15.01",y1:"12",y2:"12",key:"krot7o"}],["line",{x1:"18",x2:"18.01",y1:"10",y2:"10",key:"1lcuu1"}],["path",{d:"M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z",key:"mfqc10"}]],M2=ge("Gamepad2",S2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const E2=[["path",{d:"m14.5 12.5-8 8a2.119 2.119 0 1 1-3-3l8-8",key:"15492f"}],["path",{d:"m16 16 6-6",key:"vzrcl6"}],["path",{d:"m8 8 6-6",key:"18bi4p"}],["path",{d:"m9 7 8 8",key:"5jnvq1"}],["path",{d:"m21 11-8-8",key:"z4y7zo"}]],w2=ge("Gavel",E2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const T2=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["path",{d:"M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20",key:"13o1zl"}],["path",{d:"M2 12h20",key:"9i4pu4"}]],b2=ge("Globe",T2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const A2=[["rect",{width:"18",height:"18",x:"3",y:"3",rx:"2",key:"afitv7"}],["path",{d:"M3 9h18",key:"1pudct"}],["path",{d:"M3 15h18",key:"5xshup"}],["path",{d:"M9 3v18",key:"fh3hqa"}],["path",{d:"M15 3v18",key:"14nvp0"}]],Ev=ge("Grid3x3",A2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const C2=[["line",{x1:"4",x2:"20",y1:"9",y2:"9",key:"4lhtct"}],["line",{x1:"4",x2:"20",y1:"15",y2:"15",key:"vyu0kd"}],["line",{x1:"10",x2:"8",y1:"3",y2:"21",key:"1ggp8o"}],["line",{x1:"16",x2:"14",y1:"3",y2:"21",key:"weycgp"}]],rl=ge("Hash",C2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const N2=[["path",{d:"M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",key:"c3ymky"}],["path",{d:"M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27",key:"1uw2ng"}]],R2=ge("HeartPulse",N2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const P2=[["path",{d:"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8",key:"1357e3"}],["path",{d:"M3 3v5h5",key:"1xhq8a"}],["path",{d:"M12 7v5l4 2",key:"1fdv2h"}]],yp=ge("History",P2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const k2=[["path",{d:"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",key:"5wwlr5"}],["path",{d:"M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",key:"1d0kgt"}]],L2=ge("House",k2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const D2=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["path",{d:"M12 16v-4",key:"1dtifu"}],["path",{d:"M12 8h.01",key:"e9boi3"}]],Sp=ge("Info",D2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const I2=[["line",{x1:"3",x2:"21",y1:"22",y2:"22",key:"j8o0r"}],["line",{x1:"6",x2:"6",y1:"18",y2:"11",key:"10tf0k"}],["line",{x1:"10",x2:"10",y1:"18",y2:"11",key:"54lgf6"}],["line",{x1:"14",x2:"14",y1:"18",y2:"11",key:"380y"}],["line",{x1:"18",x2:"18",y1:"18",y2:"11",key:"1kevvc"}],["polygon",{points:"12 2 20 7 4 7",key:"jkujk7"}]],U2=ge("Landmark",I2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const F2=[["path",{d:"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4",key:"1uf3rs"}],["polyline",{points:"16 17 21 12 16 7",key:"1gabdz"}],["line",{x1:"21",x2:"9",y1:"12",y2:"12",key:"1uyos4"}]],zg=ge("LogOut",F2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const O2=[["path",{d:"M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0",key:"1r0f0z"}],["circle",{cx:"12",cy:"10",r:"3",key:"ilqhr7"}]],ll=ge("MapPin",O2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const j2=[["path",{d:"M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z",key:"169xi5"}],["path",{d:"M15 5.764v15",key:"1pn4in"}],["path",{d:"M9 3.236v15",key:"1uimfh"}]],z2=ge("Map",j2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const B2=[["path",{d:"m3 11 18-5v12L3 14v-3z",key:"n962bs"}],["path",{d:"M11.6 16.8a3 3 0 1 1-5.8-1.6",key:"1yl0tm"}]],$r=ge("Megaphone",B2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const H2=[["path",{d:"M7.9 20A9 9 0 1 0 4 16.1L2 22Z",key:"vv11sd"}]],Nu=ge("MessageCircle",H2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const V2=[["path",{d:"M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",key:"1lielz"}],["path",{d:"M12 7v6",key:"lw1j43"}],["path",{d:"M9 10h6",key:"9gxzsh"}]],du=ge("MessageSquarePlus",V2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const G2=[["path",{d:"M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",key:"1lielz"}]],Zi=ge("MessageSquare",G2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const W2=[["line",{x1:"2",x2:"22",y1:"2",y2:"22",key:"a6p6uj"}],["path",{d:"M18.89 13.23A7.12 7.12 0 0 0 19 12v-2",key:"80xlxr"}],["path",{d:"M5 10v2a7 7 0 0 0 12 5",key:"p2k8kg"}],["path",{d:"M15 9.34V5a3 3 0 0 0-5.68-1.33",key:"1gzdoj"}],["path",{d:"M9 9v3a3 3 0 0 0 5.12 2.12",key:"r2i35w"}],["line",{x1:"12",x2:"12",y1:"19",y2:"22",key:"x3vr5v"}]],vf=ge("MicOff",W2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const $2=[["path",{d:"M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z",key:"131961"}],["path",{d:"M19 10v2a7 7 0 0 1-14 0v-2",key:"1vc78b"}],["line",{x1:"12",x2:"12",y1:"19",y2:"22",key:"x3vr5v"}]],wv=ge("Mic",$2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const X2=[["path",{d:"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z",key:"a7tn18"}]],q2=ge("Moon",X2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const Y2=[["path",{d:"M9 18V5l12-2v13",key:"1jmyc2"}],["circle",{cx:"6",cy:"18",r:"3",key:"fqmcym"}],["circle",{cx:"18",cy:"16",r:"3",key:"1hluhg"}]],K2=ge("Music",Y2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const Z2=[["path",{d:"M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2",key:"7pis2x"}],["path",{d:"M18 14h-8",key:"sponae"}],["path",{d:"M15 18h-5",key:"95g1m2"}],["path",{d:"M10 6h8v4h-8V6Z",key:"smlsk5"}]],Q2=ge("Newspaper",Z2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const J2=[["path",{d:"M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z",key:"1a0edw"}],["path",{d:"M12 22V12",key:"d0xqtd"}],["polyline",{points:"3.29 7 12 12 20.71 7",key:"ousv84"}],["path",{d:"m7.5 4.27 9 5.15",key:"1c824w"}]],eM=ge("Package",J2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const tM=[["circle",{cx:"13.5",cy:"6.5",r:".5",fill:"currentColor",key:"1okk4w"}],["circle",{cx:"17.5",cy:"10.5",r:".5",fill:"currentColor",key:"f64h9f"}],["circle",{cx:"8.5",cy:"7.5",r:".5",fill:"currentColor",key:"fotxhn"}],["circle",{cx:"6.5",cy:"12.5",r:".5",fill:"currentColor",key:"qy21gx"}],["path",{d:"M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z",key:"12rzf8"}]],Tv=ge("Palette",tM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const nM=[["path",{d:"M12 20h9",key:"t2du7b"}],["path",{d:"M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z",key:"1ykcvy"}]],al=ge("PenLine",nM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const iM=[["path",{d:"M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",key:"1a8usu"}],["path",{d:"m15 5 4 4",key:"1mk7zo"}]],bv=ge("Pencil",iM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const sM=[["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}],["path",{d:"M14.05 2a9 9 0 0 1 8 7.94",key:"vmijpz"}],["path",{d:"M14.05 6A5 5 0 0 1 18 10",key:"13nbpp"}]],cl=ge("PhoneCall",sM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const rM=[["polyline",{points:"16 2 16 8 22 8",key:"1ygljm"}],["line",{x1:"22",x2:"16",y1:"2",y2:"8",key:"1xzwqn"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],aM=ge("PhoneIncoming",rM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const oM=[["line",{x1:"22",x2:"16",y1:"2",y2:"8",key:"1xzwqn"}],["line",{x1:"16",x2:"22",y1:"2",y2:"8",key:"13zxdn"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],Ru=ge("PhoneMissed",oM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const lM=[["path",{d:"M10.68 13.31a16 16 0 0 0 3.41 2.6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7 2 2 0 0 1 1.72 2v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.42 19.42 0 0 1-3.33-2.67m-2.67-3.34a19.79 19.79 0 0 1-3.07-8.63A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91",key:"z86iuo"}],["line",{x1:"22",x2:"2",y1:"2",y2:"22",key:"11kh81"}]],Pu=ge("PhoneOff",lM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const cM=[["polyline",{points:"22 8 22 2 16 2",key:"1g204g"}],["line",{x1:"16",x2:"22",y1:"8",y2:"2",key:"1ggias"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],uM=ge("PhoneOutgoing",cM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const dM=[["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],Ji=ge("Phone",dM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const hM=[["path",{d:"m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z",key:"wa1lgi"}],["path",{d:"m8.5 8.5 7 7",key:"rvfmvr"}]],fM=ge("Pill",hM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const pM=[["polygon",{points:"6 3 20 12 6 21 6 3",key:"1oa8hb"}]],mM=ge("Play",pM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const gM=[["path",{d:"M5 12h14",key:"1ays0h"}],["path",{d:"M12 5v14",key:"s699le"}]],_M=ge("Plus",gM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const vM=[["path",{d:"M12 2v10",key:"mnfbl"}],["path",{d:"M18.4 6.6a9 9 0 1 1-12.77.04",key:"obofu9"}]],xM=ge("Power",vM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const yM=[["path",{d:"M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z",key:"rib7q0"}],["path",{d:"M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z",key:"1ymkrd"}]],Mp=ge("Quote",yM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const SM=[["path",{d:"M4.9 19.1C1 15.2 1 8.8 4.9 4.9",key:"1vaf9d"}],["path",{d:"M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5",key:"u1ii0m"}],["circle",{cx:"12",cy:"12",r:"2",key:"1c9p78"}],["path",{d:"M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5",key:"1j5fej"}],["path",{d:"M19.1 4.9C23 8.8 23 15.1 19.1 19",key:"10b0cb"}]],ku=ge("Radio",SM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const MM=[["path",{d:"M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8",key:"v9h5vc"}],["path",{d:"M21 3v5h-5",key:"1q7to0"}],["path",{d:"M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16",key:"3uifl3"}],["path",{d:"M8 16H3v5",key:"1cv678"}]],Av=ge("RefreshCw",MM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const EM=[["path",{d:"m2 9 3-3 3 3",key:"1ltn5i"}],["path",{d:"M13 18H7a2 2 0 0 1-2-2V6",key:"1r6tfw"}],["path",{d:"m22 15-3 3-3-3",key:"4rnwn2"}],["path",{d:"M11 6h6a2 2 0 0 1 2 2v10",key:"2f72bc"}]],Ep=ge("Repeat2",EM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const wM=[["path",{d:"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8",key:"1p45f6"}],["path",{d:"M21 3v5h-5",key:"1q7to0"}]],TM=ge("RotateCw",wM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const bM=[["path",{d:"M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z",key:"1c8476"}],["path",{d:"M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7",key:"1ydtos"}],["path",{d:"M7 3v4a1 1 0 0 0 1 1h7",key:"t51u73"}]],Cv=ge("Save",bM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const AM=[["circle",{cx:"11",cy:"11",r:"8",key:"4ej97u"}],["path",{d:"m21 21-4.3-4.3",key:"1qie3q"}]],cr=ge("Search",AM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const CM=[["path",{d:"M3.714 3.048a.498.498 0 0 0-.683.627l2.843 7.627a2 2 0 0 1 0 1.396l-2.842 7.627a.498.498 0 0 0 .682.627l18-8.5a.5.5 0 0 0 0-.904z",key:"117uat"}],["path",{d:"M6 12h16",key:"s4cdu5"}]],NM=ge("SendHorizontal",CM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const RM=[["path",{d:"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z",key:"1qme2f"}],["circle",{cx:"12",cy:"12",r:"3",key:"1v7zrd"}]],wp=ge("Settings",RM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const PM=[["circle",{cx:"18",cy:"5",r:"3",key:"gq8acd"}],["circle",{cx:"6",cy:"12",r:"3",key:"w7nqdw"}],["circle",{cx:"18",cy:"19",r:"3",key:"1xt0gg"}],["line",{x1:"8.59",x2:"15.42",y1:"13.51",y2:"17.49",key:"47mynk"}],["line",{x1:"15.41",x2:"8.59",y1:"6.51",y2:"10.49",key:"1n3mei"}]],kM=ge("Share2",PM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const LM=[["path",{d:"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",key:"oel41y"}],["path",{d:"M12 8v4",key:"1got3b"}],["path",{d:"M12 16h.01",key:"1drbdi"}]],DM=ge("ShieldAlert",LM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const IM=[["path",{d:"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",key:"oel41y"}]],UM=ge("Shield",IM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const FM=[["path",{d:"M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z",key:"hou9p0"}],["path",{d:"M3 6h18",key:"d0wm0j"}],["path",{d:"M16 10a4 4 0 0 1-8 0",key:"1ltviw"}]],OM=ge("ShoppingBag",FM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const jM=[["circle",{cx:"8",cy:"21",r:"1",key:"jimo8o"}],["circle",{cx:"19",cy:"21",r:"1",key:"13723u"}],["path",{d:"M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12",key:"9zh506"}]],zM=ge("ShoppingCart",jM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const BM=[["path",{d:"M2 20h.01",key:"4haj6o"}],["path",{d:"M7 20v-4",key:"j294jx"}],["path",{d:"M12 20v-8",key:"i3yub9"}],["path",{d:"M17 20V8",key:"1tkaf5"}],["path",{d:"M22 4v16",key:"sih9yq"}]],HM=ge("Signal",BM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const VM=[["path",{d:"M7 18v-6a5 5 0 1 1 10 0v6",key:"pcx96s"}],["path",{d:"M5 21a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-1a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2z",key:"1b4s83"}],["path",{d:"M21 12h1",key:"jtio3y"}],["path",{d:"M18.5 4.5 18 5",key:"g5sp9y"}],["path",{d:"M2 12h1",key:"1uaihz"}],["path",{d:"M12 2v1",key:"11qlp1"}],["path",{d:"m4.929 4.929.707.707",key:"1i51kw"}],["path",{d:"M12 12v6",key:"3ahymv"}]],GM=ge("Siren",VM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const WM=[["path",{d:"m12.5 17-.5-1-.5 1h1z",key:"3me087"}],["path",{d:"M15 22a1 1 0 0 0 1-1v-1a2 2 0 0 0 1.56-3.25 8 8 0 1 0-11.12 0A2 2 0 0 0 8 20v1a1 1 0 0 0 1 1z",key:"1o5pge"}],["circle",{cx:"15",cy:"12",r:"1",key:"1tmaij"}],["circle",{cx:"9",cy:"12",r:"1",key:"1vctgf"}]],$M=ge("Skull",WM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const XM=[["path",{d:"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",key:"r04s7s"}]],Ms=ge("Star",XM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const qM=[["path",{d:"M11 2v2",key:"1539x4"}],["path",{d:"M5 2v2",key:"1yf1q8"}],["path",{d:"M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1",key:"rb5t3r"}],["path",{d:"M8 15a6 6 0 0 0 12 0v-3",key:"x18d4x"}],["circle",{cx:"20",cy:"10",r:"2",key:"ts1r5v"}]],YM=ge("Stethoscope",qM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const KM=[["circle",{cx:"12",cy:"12",r:"4",key:"4exip2"}],["path",{d:"M12 2v2",key:"tus03m"}],["path",{d:"M12 20v2",key:"1lh1kg"}],["path",{d:"m4.93 4.93 1.41 1.41",key:"149t6j"}],["path",{d:"m17.66 17.66 1.41 1.41",key:"ptbguv"}],["path",{d:"M2 12h2",key:"1t8f8n"}],["path",{d:"M20 12h2",key:"1q8mjw"}],["path",{d:"m6.34 17.66-1.41 1.41",key:"1m8zz5"}],["path",{d:"m19.07 4.93-1.41 1.41",key:"1shlcs"}]],ZM=ge("Sun",KM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const QM=[["path",{d:"M3 6h18",key:"d0wm0j"}],["path",{d:"M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6",key:"4alrt4"}],["path",{d:"M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",key:"v07s0e"}],["line",{x1:"10",x2:"10",y1:"11",y2:"17",key:"1uufr5"}],["line",{x1:"14",x2:"14",y1:"11",y2:"17",key:"xtxkd"}]],hu=ge("Trash2",QM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const JM=[["path",{d:"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3",key:"wmoenq"}],["path",{d:"M12 9v4",key:"juzpu7"}],["path",{d:"M12 17h.01",key:"p32p05"}]],Tp=ge("TriangleAlert",JM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const eE=[["path",{d:"M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2",key:"wrbu53"}],["path",{d:"M15 18H9",key:"1lyqi6"}],["path",{d:"M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14",key:"lysw3i"}],["circle",{cx:"17",cy:"18",r:"2",key:"332jqn"}],["circle",{cx:"7",cy:"18",r:"2",key:"19iecd"}]],tE=ge("Truck",eE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const nE=[["polyline",{points:"4 7 4 4 20 4 20 7",key:"1nosan"}],["line",{x1:"9",x2:"15",y1:"20",y2:"20",key:"swin9y"}],["line",{x1:"12",x2:"12",y1:"4",y2:"20",key:"1tx1rr"}]],iE=ge("Type",nE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const sE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["polyline",{points:"16 11 18 13 22 9",key:"1pwet4"}]],rE=ge("UserCheck",sE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const aE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"22",x2:"16",y1:"11",y2:"11",key:"1shjgl"}]],oE=ge("UserMinus",aE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const lE=[["path",{d:"M11.5 15H7a4 4 0 0 0-4 4v2",key:"15lzij"}],["path",{d:"M21.378 16.626a1 1 0 0 0-3.004-3.004l-4.01 4.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z",key:"1817ys"}],["circle",{cx:"10",cy:"7",r:"4",key:"e45bow"}]],bp=ge("UserPen",lE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const cE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"19",x2:"19",y1:"8",y2:"14",key:"1bvyxn"}],["line",{x1:"22",x2:"16",y1:"11",y2:"11",key:"1shjgl"}]],Qi=ge("UserPlus",cE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const uE=[["circle",{cx:"12",cy:"8",r:"5",key:"1hypcn"}],["path",{d:"M20 21a8 8 0 0 0-16 0",key:"rfgkzh"}]],no=ge("UserRound",uE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const dE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"17",x2:"22",y1:"8",y2:"13",key:"3nzzx3"}],["line",{x1:"22",x2:"17",y1:"8",y2:"13",key:"1swrse"}]],hE=ge("UserX",dE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const fE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["path",{d:"M22 21v-2a4 4 0 0 0-3-3.87",key:"kshegd"}],["path",{d:"M16 3.13a4 4 0 0 1 0 7.75",key:"1da9ce"}]],Ln=ge("Users",fE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const pE=[["path",{d:"M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2",key:"cjf0a3"}],["path",{d:"M7 2v20",key:"1473qp"}],["path",{d:"M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7",key:"j28e5"}]],mE=ge("Utensils",pE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const gE=[["path",{d:"M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z",key:"uqj9uw"}],["path",{d:"M16 9a5 5 0 0 1 0 6",key:"1q6k2b"}],["path",{d:"M19.364 18.364a9 9 0 0 0 0-12.728",key:"ijwkga"}]],Nv=ge("Volume2",gE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const _E=[["path",{d:"M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1",key:"18etb6"}],["path",{d:"M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4",key:"xoc0q4"}]],vE=ge("Wallet",_E);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const xE=[["path",{d:"M12.8 19.6A2 2 0 1 0 14 16H2",key:"148xed"}],["path",{d:"M17.5 8a2.5 2.5 0 1 1 2 4H2",key:"1u4tom"}],["path",{d:"M9.8 4.4A2 2 0 1 1 11 8H2",key:"75valh"}]],yE=ge("Wind",xE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const SE=[["path",{d:"M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z",key:"cbrjhi"}]],ME=ge("Wrench",SE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const EE=[["path",{d:"M18 6 6 18",key:"1bl5f8"}],["path",{d:"m6 6 12 12",key:"d8bk6v"}]],io=ge("X",EE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const wE=[["path",{d:"M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z",key:"1xq2db"}]],Ap=ge("Zap",wE);function Rv({weather:n,size:e=22}){const t=(n??"").toLowerCase(),s={size:e,strokeWidth:1.9};return/storm|thunder|lightning/.test(t)?l.jsx(YS,{...s}):/rain|drizzle|shower/.test(t)?l.jsx(ZS,{...s}):/fog|mist|haze|smog|pollution/.test(t)?l.jsx(XS,{...s}):/sand|dust|wind/.test(t)?l.jsx(yE,{...s}):/overcast|cloud/.test(t)?/partly|few/.test(t)?l.jsx(JS,{...s}):l.jsx(t2,{...s}):/night|moon/.test(t)?l.jsx(q2,{...s}):l.jsx(ZM,{...s})}function fu({children:n,cut:e=16,depth:t=5,tone:s="holo",className:a,faceClassName:c,style:u}){const d=q.useRef(null),f=q.useRef(0),p=v=>{const x=d.current;if(!x)return;const{clientX:y,clientY:w}=v;f.current||(f.current=requestAnimationFrame(()=>{f.current=0;const E=x.getBoundingClientRect(),_=Math.max(-1,Math.min(1,(y-E.left)/E.width*2-1)),M=Math.max(-1,Math.min(1,(w-E.top)/E.height*2-1));x.style.setProperty("--lx",_.toFixed(3)),x.style.setProperty("--ly",M.toFixed(3)),x.style.setProperty("--gx",`${((_+1)*50).toFixed(1)}%`),x.style.setProperty("--gy",`${((M+1)*50).toFixed(1)}%`)}))},g=()=>{const v=d.current;v&&(v.style.setProperty("--lx","0"),v.style.setProperty("--ly","0"),v.classList.remove("is-hover"))};return l.jsxs("div",{ref:d,className:["nl3d",`nl3d--${s}`,a].filter(Boolean).join(" "),style:{...u,"--nl-c":`${e}px`},onPointerMove:p,onPointerEnter:()=>d.current?.classList.add("is-hover"),onPointerLeave:g,children:[l.jsx("div",{className:"nl3d__bloom","aria-hidden":!0}),l.jsx("div",{className:"nl3d__depth","aria-hidden":!0,children:Array.from({length:t},(v,x)=>l.jsx("i",{style:{"--k":x+1,"--n":t}},x))}),l.jsx("div",{className:["nl3d__face",c].filter(Boolean).join(" "),children:n}),l.jsx("div",{className:"nl3d__glint","aria-hidden":!0}),l.jsx("div",{className:"nl3d__halo","aria-hidden":!0}),l.jsxs("div",{className:"nl3d__corners","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})]})}const Bg={AppWindow:yv,Banknote:gS,Bike:SS,Bot:wS,Briefcase:bS,Building2:CS,Calendar:kS,Camera:DS,Car:zS,CarFront:US,CarTaxiFront:OS,Cpu:xp,CreditCard:o2,Crosshair:c2,Gamepad2:M2,Gavel:w2,Globe:b2,HeartPulse:R2,Home:L2,Landmark:U2,Map:z2,MapPin:ll,Music:K2,Newspaper:Q2,Package:eM,Pill:fM,Radio:ku,Shield:UM,ShieldAlert:DM,ShoppingBag:OM,ShoppingCart:zM,Siren:GM,Skull:$M,Star:Ms,Stethoscope:YM,Truck:tE,Utensils:mE,Wallet:vE,Wrench:ME,Zap:Ap};function TE(n){return n.trim().split(/[-_\s]+/).filter(Boolean).map(e=>e[0].toUpperCase()+e.slice(1)).join("")}let pu=null,Hg=null;function bE(){return Hg??=dp(()=>import("./chunk-lucideAll.js"),[],import.meta.url).then(n=>pu=n.icons).catch(()=>pu={}),Hg}function AE({name:n,size:e=30,strokeWidth:t=1.9}){const s=TE(n||"app-window"),[,a]=q.useState(0),c=Bg[s]??pu?.[s];q.useEffect(()=>{!Bg[s]&&!pu&&bE().then(()=>a(d=>d+1))},[s]);const u=c??yv;return l.jsx(u,{size:e,strokeWidth:t})}const Ks=30,en=18;function Lu(n){return(n?.threads??[]).reduce((e,t)=>e+(t.unread>0?t.unread:0),0)}function Du(n,e){return(n?.recents??[]).filter(t=>t.direction==="in"&&t.status==="missed"&&t.at>e).length}function Pv(n,e,t){const s=[];t&&s.push({id:"call",label:"Call",icon:l.jsx(cl,{size:Ks,strokeWidth:1.9})}),s.push({id:"status",label:"Status",icon:l.jsx(no,{size:Ks,strokeWidth:1.9})},{id:"phone",label:"Phone",icon:l.jsx(Ji,{size:Ks,strokeWidth:1.9}),badge:e},{id:"messages",label:"Messages",icon:l.jsx(Zi,{size:Ks,strokeWidth:1.9}),badge:Lu(n)},{id:"contacts",label:"Contacts",icon:l.jsx(sl,{size:Ks,strokeWidth:1.9})},{id:"social",label:"Screamsheet",icon:l.jsx($r,{size:Ks,strokeWidth:1.9}),badge:n?.social?.unread??0},{id:"settings",label:"Settings",icon:l.jsx(wp,{size:Ks,strokeWidth:1.9})});for(const a of n?.apps??[])s.push({id:`app:${a.id}`,label:a.label,icon:l.jsx(AE,{name:a.icon,size:Ks}),color:a.color,appId:a.id});return s}function kv(n,e,t){switch(n){case"status":return[{id:"identity",label:"Identity",hint:e?.line?.number??"No line",icon:l.jsx(i2,{size:en}),view:{app:"status"}}];case"phone":return[{id:"dial",label:"Keypad",hint:"Dial a number",icon:l.jsx(Ev,{size:en}),view:{app:"phone",tab:"dial"}},{id:"recents",label:"Recents",hint:`${e?.recents.length??0} calls`,icon:l.jsx(yp,{size:en}),badge:t,view:{app:"phone",tab:"recents"}},{id:"favorites",label:"Favorites",hint:`${e?.contacts.filter(s=>s.favorite).length??0} linked`,icon:l.jsx(Ms,{size:en}),view:{app:"phone",tab:"favorites"}}];case"messages":return[{id:"inbox",label:"Inbox",hint:`${e?.threads.length??0} threads`,icon:l.jsx(Zi,{size:en}),badge:Lu(e),view:{app:"messages",screen:"list"}},{id:"new",label:"New message",hint:"Number or contact",icon:l.jsx(du,{size:en}),view:{app:"messages",screen:"new"}},{id:"group",label:"New group",hint:"2 to 15 members",icon:l.jsx(Ln,{size:en}),view:{app:"messages",screen:"group-new"}}];case"contacts":return[{id:"all",label:"All contacts",hint:`${e?.contacts.length??0} saved`,icon:l.jsx(sl,{size:en}),view:{app:"contacts",screen:"list",filter:"all"}},{id:"fav",label:"Favorites",hint:`${e?.contacts.filter(s=>s.favorite).length??0} starred`,icon:l.jsx(Ms,{size:en}),view:{app:"contacts",screen:"list",filter:"favorites"}},{id:"add",label:"Add contact",hint:"Name and number",icon:l.jsx(Qi,{size:en}),view:{app:"contacts",screen:"edit"}}];case"social":{const s=e?.social?.unread??0,a=e?.social?.handle??"";return[{id:"pulse",label:"Pulse",hint:"Everyone, live",icon:l.jsx(ku,{size:en}),view:{app:"social",screen:"feed",mode:"pulse"}},{id:"crew",label:"Crew",hint:"People you follow",icon:l.jsx(Ln,{size:en}),view:{app:"social",screen:"feed",mode:"crew"}},{id:"hot",label:"Hot",hint:"Best of the last 24 h",icon:l.jsx(Cu,{size:en}),view:{app:"social",screen:"feed",mode:"hot"}},{id:"compose",label:"Compose",hint:"Scream to the city",icon:l.jsx(al,{size:en}),view:{app:"social",screen:"compose"}},{id:"pings",label:"Pings",hint:s?`${s} new`:"Cred, echoes, replies",icon:l.jsx(_f,{size:en}),badge:s,view:{app:"social",screen:"pings"}},{id:"heat",label:"Net Heat",hint:"Trending tags and districts",icon:l.jsx(uu,{size:en}),view:{app:"social",screen:"heat"}},{id:"me",label:"My profile",hint:a?`@${a}`:"Your screams",icon:l.jsx(WS,{size:en}),view:{app:"social",screen:"profile",handle:a}}]}case"settings":return[{id:"sound",label:"Sound",hint:"Ringtone, volume, DND",icon:l.jsx(Nv,{size:en}),view:{app:"settings",section:"sound"}},{id:"display",label:"Hologram",hint:"Accent, intensity",icon:l.jsx(Tv,{size:en}),view:{app:"settings",section:"display"}},{id:"about",label:"System",hint:"Neural-Link OS",icon:l.jsx(xp,{size:en}),view:{app:"settings",section:"about"}}];default:return[]}}const CE={status:{title:"Status",icon:l.jsx(no,{size:22})},phone:{title:"Phone",icon:l.jsx(Ji,{size:22})},messages:{title:"Messages",icon:l.jsx(Zi,{size:22})},contacts:{title:"Contacts",icon:l.jsx(sl,{size:22})},social:{title:"Screamsheet",icon:l.jsx($r,{size:22})},settings:{title:"Settings",icon:l.jsx(wp,{size:22})},about:{title:"About",icon:l.jsx(Sp,{size:22})}};function Vg(n,e){return!e||e.app!==n.view.app?!1:e.app==="phone"&&n.view.app==="phone"?e.tab===n.view.tab:e.app==="settings"&&n.view.app==="settings"?e.section===n.view.section:e.app==="contacts"&&n.view.app==="contacts"?n.view.screen==="edit"?e.screen==="edit"&&e.id==null:e.screen==="list"&&e.filter===n.view.filter:e.app==="messages"&&n.view.app==="messages"?e.screen===n.view.screen:e.app==="social"&&n.view.app==="social"?e.screen==="feed"&&n.view.screen==="feed"?e.mode===n.view.mode:e.screen==="profile"&&n.view.screen==="profile"?e.handle===n.view.handle:e.screen==="compose"?n.view.screen==="compose"&&e.replyTo==null&&e.quoteOf==null:e.screen===n.view.screen:e.app===n.view.app}function Lv(){const[n,e]=q.useState(97.4);return q.useEffect(()=>{const t=window.setInterval(()=>e(s=>Math.max(94,Math.min(99.9,s+(Math.random()-.5)*1.2))),2400);return()=>window.clearInterval(t)},[]),n}function NE(){const n=he(g=>g.state?.line??null),e=he(g=>g.clock),t=he(g=>g.state),s=he(g=>g.recentsSeenAt),a=Lv(),[c,u]=q.useState(!1),d=Lu(t),f=Du(t,s),p=async()=>{if(!n)return;const g=await dv(n.number);Me(g?"select":"error"),u(g),window.setTimeout(()=>u(!1),1400)};return l.jsx("div",{className:"tilt tilt--card",children:l.jsx(fu,{cut:16,depth:6,children:l.jsxs("aside",{className:"card nl-hit",children:[l.jsxs("div",{className:"card__top",children:[l.jsx("span",{className:"card__brand mono",children:"NEURAL-LINK"}),l.jsx("span",{className:"card__fw mono",children:"OS 2.7.7"})]}),l.jsx("div",{className:"card__name",children:n?.name??"Unlinked"}),l.jsxs("button",{type:"button",className:"card__num",onClick:p,disabled:!n,title:"Copy number",children:[l.jsx("span",{className:"mono",children:n?.number??"---- ----"}),l.jsx(Mv,{size:14,strokeWidth:2.4}),l.jsx("span",{className:`card__copied ${c?"is-on":""}`,children:"Copied"})]}),l.jsxs("div",{className:"card__bar",children:[l.jsx("span",{className:"card__bar-label label",children:"Sync"}),l.jsxs("span",{className:"card__bar-track",children:[l.jsx("span",{className:"card__bar-fill",style:{transform:`scaleX(${n?a/100:.08})`}}),l.jsx("span",{className:"card__bar-seg","aria-hidden":!0})]}),l.jsx("span",{className:"card__bar-val mono",children:n?`${a.toFixed(1)}%`:"0%"})]}),l.jsxs("div",{className:"card__row",children:[l.jsxs("div",{className:"card__time",children:[l.jsx("span",{className:"mono card__clock",children:e?`${Ss(e.hours)}:${Ss(e.minutes)}`:"--:--"}),l.jsx("span",{className:"card__city label",children:"Night City"})]}),l.jsxs("div",{className:"card__weather",children:[l.jsx(Rv,{weather:e?.weather,size:26}),l.jsx("span",{children:e?.weather??"No data"})]})]}),l.jsxs("div",{className:"card__foot",children:[l.jsx("span",{className:`card__signal ${n?"":"is-off"}`,"aria-label":"link quality",children:[0,1,2,3,4].map(g=>l.jsx("i",{style:{"--i":g}},g))}),l.jsxs("span",{className:"card__stat",title:"Unread messages",children:[l.jsx(Zi,{size:15})," ",l.jsx("b",{className:"mono",children:d})]}),l.jsxs("span",{className:`card__stat ${f?"is-alert":""}`,title:"Missed calls",children:[l.jsx(Ru,{size:15})," ",l.jsx("b",{className:"mono",children:f})]})]})]})})})}function Gg({icon:n,label:e,selected:t,cursor:s,badge:a,tone:c="glass",size:u,pulse:d,disabled:f,labelSide:p="left",className:g,style:v,color:x,onClick:y,dataCol:w}){const E={...v};return u&&(E["--size"]=`${u}px`),x&&(E["--app-color"]=x),l.jsxs("button",{type:"button",className:["rb",`rb--${c}`,t&&"is-selected",s&&"is-cursor",d&&"is-pulse",x&&"has-color",g].filter(Boolean).join(" "),style:E,disabled:f,"aria-label":e,"aria-pressed":t,"data-col":w,onClick:y,children:[l.jsx("span",{className:"rb__ring","aria-hidden":!0,children:l.jsx("svg",{viewBox:"0 0 100 100",children:l.jsx("circle",{cx:"50",cy:"50",r:"47"})})}),l.jsxs("span",{className:"rb__rim","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"rb__disc",children:l.jsx("span",{className:"rb__icon",children:n})}),a!=null&&a!==0&&a!==""&&l.jsx("span",{className:"rb__badge mono",children:typeof a=="number"&&a>99?"99+":a}),e&&p!=="none"&&l.jsx("span",{className:`rb__label rb__label--${p} label`,children:e})]})}const bh={unknown_number:"No neural line answers to that number.",unavailable:"Line unreachable. They are offline.",busy:"Line busy. Try again later.",in_call:"You are already in a call.",not_member:"You are not a member of this group.",not_owner:"Only the group owner can do that.",group_full:"This group is full.",invalid_body:"Messages must be 1 to 500 characters.",invalid_name:"That name is not valid.",invalid_number:"Numbers look like 555-0123.",rate_limited:"Too fast. Wait a moment.",no_line:"No neural line assigned yet.",database_unavailable:"Neural network storage is offline. Try again soon.",self:"You cannot do that with your own number.",handle_taken:"That handle is already taken.",invalid_handle:"Handles are 3 to 16 lowercase letters, digits or underscores.",unknown_handle:"No citizen answers to that handle.",unknown_post:"That scream is gone.",not_author:"Only the author can do that.",not_installed:"No Neural-Link implant detected.",ripperdoc_required:"Visit a ripperdoc to have a Neural-Link installed.",timeout:"The link timed out. Try again.",no_action:"That offer is no longer open.",already_answered:"Already answered.",unknown_message:"That message is gone.",map_unavailable:"The map did not take the pin.",unknown_recipient:"No neural line answers to that number.",gig_closed:"That job is closed.",gig_full:"The crew is full.",unknown:"Something went wrong on the link."};function On(n){return n?bh[n]??bh.unknown:bh.unknown}const RE={hangup:"Call ended",declined:"Call declined",busy:"Line busy",unavailable:"Unreachable",missed:"Missed call",no_answer:"No answer",dropped:"Link dropped"};function PE(n){return RE[n]??"Call ended"}let Dv=1;function so(n){Me("error"),be().pushToast({id:`local-err-${Dv++}`,kind:"error",title:"Neural-Link",body:On(n),at:Date.now()})}function Iv(n,e){be().pushToast({id:`local-info-${Dv++}`,kind:"info",title:n,body:e,at:Date.now()})}async function Tt(n,e,t={}){try{return await to(n,e)}catch(s){const a=s instanceof Sn?s.slug:"unknown";t.quiet||so(a);return}}async function Hr(n,e){try{return await to(n,e)}catch(t){throw t instanceof Sn?t:new Sn("unknown")}}function Vr(){const n=be();n.phase==="closed"||n.phase==="closing"||(document.activeElement?.blur?.(),Me("close"),n.closeUi(),Au("nl:close",{}))}function Oa(){be().back()?Me("back"):Vr()}function Mn(n,e="push"){const t=be();e==="reset"?t.resetView(n):t.pushView(n),Me("select")}function $a(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"messages",screen:"list"}),be().pushView({app:"messages",screen:"thread",threadId:n}),Me("select"),mu(n)}function mu(n){const e=be();e.threadLoading(n,!1),e.setUnread(n,0),Tt("threads.open",{threadId:n}).then(t=>{if(t===void 0){const s=be().threadCache[n];s?.loading&&be().threadLoaded({threadId:n,messages:s.messages,members:s.members,hasMore:!1})}})}function kE(n){const e=be(),t=e.threadCache[n];if(!t||!t.hasMore||t.loadingMore||t.loading)return;const s=t.messages[0];s&&(e.threadLoading(n,!0),Tt("threads.more",{threadId:n,beforeId:s.id},{quiet:!0}).then(a=>{if(a===void 0){const c=be().threadCache[n];c&&be().threadLoaded({threadId:n,messages:[],members:c.members,hasMore:c.hasMore,prepend:!0})}}))}async function LE(n){const e=await Tt("threads.direct",{number:n});e&&$a(e.threadId,"reset")}let DE=-1;async function Uv(n,e){const t=be(),s=DE--;t.addPending({tempId:s,threadId:n,body:e,at:Date.now(),failed:!1}),Me("send");try{const a=await to("messages.send",{threadId:n,body:e});return be().pendingSent(s,a.id),!0}catch(a){return be().pendingFailed(s),so(a instanceof Sn?a.slug:"unknown"),!1}}function IE(n){const e=be().pending.find(t=>t.tempId===n);e&&(be().dropPending(n),Uv(e.threadId,e.body))}async function Es(n){return be().state?.call?(so("in_call"),!1):(Me("select"),await Tt("call.dial",{number:n})!==void 0)}async function Fv(n){return be().state?.call?(so("in_call"),!1):(Me("select"),await Tt("call.group",{threadId:n})!==void 0)}let Wg,Jo={};function Gr(n,e=450){be().setSettingsDraft(n),Jo={...Jo,...n},window.clearTimeout(Wg),Wg=window.setTimeout(UE,e)}async function UE(){const n=Jo;if(Jo={},Object.keys(n).length===0)return;const e=await Tt("settings.save",n),t=be(),s={...t.settingsDraft};for(const a of Object.keys(n))a in Jo||delete s[a];e&&t.state&&t.applyPatch({settings:e}),be().replaceSettingsDraft(s)}const FE=n=>`#${n}`,Cp=n=>`@${n}`;function ul(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"social",screen:"feed",mode:"pulse"}),be().pushView({app:"social",screen:"thread",postId:n}),Me("select")}function rr(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"social",screen:"feed",mode:"pulse"}),be().pushView({app:"social",screen:"profile",handle:n}),Me("select")}function Ov(n){Mn({app:"social",screen:"tag",tag:n.replace(/^#/,"").toLowerCase()})}function jv(n,e){be().rememberPost(n),Mn(e==="reply"?{app:"social",screen:"compose",replyTo:n.id}:{app:"social",screen:"compose",quoteOf:n.id})}async function el(n,e=!1){const t=be(),s=t.feeds[n];if(e&&(!s||!s.hasMore||s.loading||s.loadingMore))return;const a=e?s?.posts[s.posts.length-1]?.id:void 0;t.feedLoading(n,e);let c;if(n.startsWith("#"))c=await Tt("social.tag",{tag:n.slice(1),beforeId:a},{quiet:e});else if(n.startsWith("@")){const u=await Tt("social.profile",{handle:n.slice(1),beforeId:a},{quiet:!0});u&&be().setProfile(u.profile),c=u}else c=await Tt("social.feed",{mode:n,beforeId:a},{quiet:e});c?be().feedLoaded(n,c.posts??[],!!c.hasMore,e):be().feedFailed(n)}function $g(n,e=!1){return el(Cp(n),e)}async function zv(n){be().screamThreadLoading(n);const e=await Tt("social.thread",{postId:n},{quiet:!0});be().screamThreadLoaded(n,e?{post:e.post,parents:e.parents??[],replies:e.replies??[]}:null)}let Ah=null;function xf(n=!1){return n?Xg(!0):(Ah??=Xg(!1).finally(()=>{Ah=null}),Ah)}async function Xg(n){const e=be(),t=e.pings;if(n&&(!t||!t.hasMore||t.loading||t.loadingMore))return;const s=n?t?.pings[t.pings.length-1]?.id:void 0;e.pingsLoading(n);const a=await Tt("social.pings",{beforeId:s},{quiet:n});a&&!n&&be().setSocialUnread(0),be().pingsLoaded(a?.pings??t?.pings??[],a?!!a.hasMore:!1,n&&!!a)}const za=new Set;async function OE(n){const e=`cred:${n.id}`;if(za.has(e))return;za.add(e);const t={credded:n.credded,cred:n.cred},s=!n.credded;be().setPostLive(n.id,{credded:s,cred:Math.max(0,n.cred+(s?1:-1))}),Me(s?"select":"back");try{const a=await to("social.cred",{postId:n.id});be().setPostLive(n.id,{credded:a.credded,cred:a.cred})}catch(a){be().setPostLive(n.id,t),so(a instanceof Sn?a.slug:"unknown")}finally{za.delete(e)}}async function jE(n){const e=`echo:${n.id}`;if(za.has(e))return;za.add(e);const t={echoed:n.echoed,echoes:n.echoes},s=!n.echoed;be().setPostLive(n.id,{echoed:s,echoes:Math.max(0,n.echoes+(s?1:-1))}),Me(s?"select":"back");try{const a=await to("social.echo",{postId:n.id,district:be().clock?.district});be().setPostLive(n.id,{echoed:a.echoed,echoes:a.echoes})}catch(a){be().setPostLive(n.id,t),so(a instanceof Sn?a.slug:"unknown")}finally{za.delete(e)}}async function zE(n,e={}){const t=await Tt("social.post",{body:n,replyTo:e.replyTo,quoteOf:e.quoteOf,district:be().clock?.district});if(!t?.post)return null;Me("send");const s=be();if(e.replyTo!=null)s.addReply(e.replyTo,t.post);else{s.prependPosts("pulse",[t.post]),s.prependPosts("crew",[t.post]);const a=s.state?.social?.handle;a&&s.prependPosts(Cp(a),[t.post])}return t.post}async function BE(n){if(await Tt("social.delete",{postId:n})===void 0)return;Me("back");const e=be();e.removePost(n);const t=e.stack[e.stack.length-1];t?.app==="social"&&t.screen==="thread"&&t.postId===n&&e.back()}async function HE(n,e){await Tt("social.report",{postId:n,reason:e})!==void 0&&(Me("select"),Iv("Screamsheet","Report filed. The sysops will take a look."))}async function qg(n,e){const t=await Tt("social.follow",{handle:n,follow:e});if(!t)return;Me(t.followed?"select":"back");const s=be(),a=s.profiles[n];a&&s.setProfile({...a,followed:t.followed,followers:t.followers}),s.feeds.crew&&el("crew")}function Np(n){return!n||n.dataset?.nlIgnore?!1:n instanceof HTMLTextAreaElement?!n.readOnly:n instanceof HTMLInputElement?["text","search","tel","number","email","url","password",""].includes(n.type)&&!n.readOnly:n.isContentEditable===!0}let Yg=!1,Kg;function VE(){window.clearTimeout(Kg),Kg=window.setTimeout(()=>{const n=Np(document.activeElement);n!==Yg&&(Yg=n,Au("nl:typing",{active:n}))},0)}function Zg(){const n=document.activeElement;Np(n)&&n.blur()}const tl=[];function dr(n,e=!0){q.useEffect(()=>{if(e)return tl.push(n),()=>{const t=tl.lastIndexOf(n);t>=0&&tl.splice(t,1)}},[n,e])}function GE(n){be().resetView(n),Me("select")}function WE(n){const e=be();if(n==="call"){e.setMenu(null),e.setCallView(!0),Me("select");return}n.startsWith("app:")||(e.setMenu(e.menu===n?null:n),Me(e.menu===n?"back":"select"))}function Qg(n){const e=be(),t=n.target;if(Np(t)){n.key==="Escape"&&(n.preventDefault(),t.blur());return}if(e.phase==="closed"||e.phase==="closing"||!e.state)return;if(mf(e)){n.key==="Escape"&&(n.preventDefault(),Vr());return}if(n.key==="Escape"){n.preventDefault(),Oa();return}if(e.stack.length>0||e.callView){for(let u=tl.length-1;u>=0;u--)if(tl[u](n)){n.preventDefault();return}(n.key==="ArrowLeft"||n.key==="Backspace")&&(n.preventDefault(),Oa());return}if(n.key==="Backspace"){n.preventDefault(),Oa();return}const a=Du(e.state,e.recentsSeenAt);if(e.menu){const u=kv(e.menu,e.state,a);if(u.length===0)return;if(n.key==="ArrowDown"||n.key==="ArrowUp"){n.preventDefault();const d=n.key==="ArrowDown"?1:-1;e.setRow((e.row+d+u.length)%u.length),Me("tick")}else if(n.key==="Enter"||n.key==="ArrowRight"){n.preventDefault();const d=u[Math.min(e.row,u.length-1)];d&&GE(d.view)}else n.key==="ArrowLeft"&&(n.preventDefault(),Oa());return}const c=Pv(e.state,a,!!e.state.call);if(n.key==="ArrowDown"||n.key==="ArrowUp"){n.preventDefault();const u=n.key==="ArrowDown"?1:-1;e.setCursor((e.cursor+u+c.length)%c.length),Me("tick")}else if(n.key==="Enter"||n.key==="ArrowRight"){n.preventDefault();const u=c[Math.min(e.cursor,c.length-1)];u&&document.querySelector(`[data-col="${CSS.escape(u.id)}"]`)?.click()}}function $E(){q.useEffect(()=>{const n=()=>VE();return document.addEventListener("focusin",n),document.addEventListener("focusout",n),window.addEventListener("keydown",Qg),()=>{document.removeEventListener("focusin",n),document.removeEventListener("focusout",n),window.removeEventListener("keydown",Qg)}},[])}function Kr(n,e,t,s){return a=>{if(n===0)return!1;if(a.key==="ArrowDown"||a.key==="ArrowUp"){const c=a.key==="ArrowDown"?1:-1,u=e<0?c>0?0:n-1:(e+c+n)%n;return t(u),Me("tick"),requestAnimationFrame(()=>document.querySelector(".is-kbd")?.scrollIntoView({block:"nearest"})),!0}return a.key==="Enter"&&e>=0&&e<n?(s(e),!0):!1}}const Xi={x:560,btn:80,gap:16,closeBtn:54,closeGap:34};function XE(n){const e=Xi.btn+Xi.gap,t=n*e-Xi.gap+Xi.closeGap+Xi.closeBtn,s=Math.round(540-t/2);return{top:s,height:t,centers:Array.from({length:n},(a,c)=>s+c*e+Xi.btn/2)}}function qE({items:n,layout:e}){const t=he(d=>d.menu),s=he(d=>d.callView),a=he(d=>d.cursor),c=he(d=>d.state?.call??null),u=async d=>{Me("select"),he.getState().setMenu(null),await Tt("apps.launch",{id:d})};return l.jsxs("nav",{className:"column nl-hit",style:{top:e.top,left:Xi.x},"aria-label":"Neural-Link menu",children:[l.jsx("span",{className:"column__spine","aria-hidden":!0,style:{height:e.height}}),n.map((d,f)=>{const p=d.id==="call"?s:d.id===t,g=d.id==="call";return l.jsx("div",{className:"column__slot",style:{"--i":f},children:l.jsx(Gg,{icon:d.icon,label:g?c?.phase==="incoming"?"Incoming":"In call":d.label,selected:p,cursor:a===f,badge:d.badge,tone:g?"ok":"glass",pulse:g,color:d.color,className:g?"rb--call":void 0,onClick:()=>{he.getState().setCursor(f),d.appId?u(d.appId):WE(d.id)},dataCol:d.id})},d.id)}),l.jsx("div",{className:"column__slot column__slot--close",style:{"--i":n.length,marginTop:Xi.closeGap-Xi.gap},children:l.jsx(Gg,{icon:l.jsx(xM,{size:22,strokeWidth:2.2}),label:"Disconnect",size:Xi.closeBtn,tone:"danger",onClick:Vr})})]})}function YE({icon:n,label:e,hint:t,badge:s,active:a,cursor:c,danger:u,chevron:d=!0,index:f=0,style:p,onClick:g}){return l.jsxs("button",{type:"button",className:["slab",a&&"is-active",c&&"is-cursor",u&&"is-danger"].filter(Boolean).join(" "),style:{...p,"--i":f},onClick:g,children:[n&&l.jsx("span",{className:"slab__icon",children:n}),l.jsxs("span",{className:"slab__text",children:[l.jsx("span",{className:"slab__label label",children:e}),t&&l.jsx("span",{className:"slab__hint",children:t})]}),s?l.jsx("span",{className:"slab__badge mono",children:s>99?"99+":s}):null,d&&l.jsx(VS,{className:"slab__chev",size:18,strokeWidth:2.4})]})}function Rp({children:n,className:e,style:t,corners:s=!0,sheen:a=!0,tag:c,flicker:u=!0}){return l.jsxs("div",{className:["holo",u&&"holo--flicker",e].filter(Boolean).join(" "),style:t,children:[l.jsxs("div",{className:"holo__fx","aria-hidden":!0,children:[l.jsx("span",{className:"holo__scan"}),a&&l.jsx("span",{className:"holo__sheen"})]}),s&&l.jsxs("div",{className:"holo__corners","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),c&&l.jsx("span",{className:"holo__tag mono","aria-hidden":!0,children:c}),n]})}function KE({y:n,side:e="left"}){return l.jsx("span",{className:`pointer pointer--${e}`,style:{transform:`translateY(${n}px)`},"aria-hidden":!0})}const br={x:690,w:340,head:64,row:62,foot:34};function ZE({anchorY:n,missed:e}){const t=he(y=>y.menu),s=he(y=>y.state),a=he(y=>y.row),c=he(y=>y.stack[0]??null),u=he(_p),d=kv(t,s,e);if(!t||d.length===0)return null;const f=CE[t]??{title:t,icon:null},p=br.head+d.length*br.row+br.foot,g=Cg(Math.round(n-br.head-br.row/2+6),70,1010-p),v=Cg(n-g-11,18,p-30),x=String(["status","phone","messages","contacts","settings","social"].indexOf(t)+1).padStart(2,"0");return l.jsx("div",{className:"tilt tilt--panel",style:{left:br.x,top:g,width:br.w},children:l.jsx(fu,{cut:12,depth:3,className:"nl3d--board",children:l.jsxs("section",{className:"subpanel nl-hit","aria-label":f.title,children:[l.jsx(KE,{y:v}),l.jsxs("header",{className:"subpanel__head",children:[l.jsx("span",{className:"subpanel__icon",children:f.icon}),l.jsx("span",{className:"subpanel__title label",children:f.title}),l.jsxs("span",{className:"subpanel__tag mono",children:["NL//",x]})]}),l.jsx("div",{className:"subpanel__rows",children:d.map((y,w)=>l.jsx(YE,{index:w,icon:y.icon,label:y.label,hint:y.hint,badge:y.badge,active:Vg(y,c)&&!!u,cursor:a===w,onClick:()=>{const E=he.getState();if(E.setRow(w),Vg(y,c)&&E.stack.length===1){E.resetView(null),Me("back");return}E.resetView(y.view),Me("select")}},y.id))}),l.jsxs("footer",{className:"subpanel__foot mono","aria-hidden":!0,children:[l.jsx("span",{children:"↑↓ select"}),l.jsx("span",{children:"⏎ open"}),l.jsx("span",{children:"esc back"})]})]})})})}function ln({icon:n,title:e,subtitle:t,tag:s,actions:a,children:c,footer:u,canBack:d,className:f,bodyClass:p}){return l.jsxs(Rp,{className:["win",f].filter(Boolean).join(" "),tag:s,children:[l.jsxs("header",{className:"win__head",children:[d?l.jsx("button",{type:"button",className:"win__back","aria-label":"Back",onClick:Oa,children:l.jsx(dS,{size:20,strokeWidth:2.4})}):null,l.jsx("span",{className:"win__icon",children:n}),l.jsxs("div",{className:"win__titles",children:[l.jsx("div",{className:"win__title label",children:e}),t&&l.jsx("div",{className:"win__sub",children:t})]}),l.jsxs("div",{className:"win__actions",children:[a,!d&&l.jsx("button",{type:"button",className:"icon-btn win__close","aria-label":"Close window",onClick:Oa,children:l.jsx(io,{size:18,strokeWidth:2.4})})]})]}),l.jsx("div",{className:"win__rule","aria-hidden":!0}),l.jsx("div",{className:["win__body",p].filter(Boolean).join(" "),children:c}),u&&l.jsx("footer",{className:"win__foot",children:u})]})}function Ht({name:n,seed:e,size:t=44,online:s,group:a,owner:c,level:u,ring:d="none",className:f}){const p=eu(e??n),g={"--size":`${t}px`,"--hue":p,"--level":u??0};return l.jsxs("span",{className:["avatar",`avatar--${d}`,u?"is-talking":"",f].filter(Boolean).join(" "),style:g,children:[l.jsx("span",{className:"avatar__voice","aria-hidden":!0}),l.jsx("span",{className:"avatar__disc",children:a?l.jsx(Ln,{size:Math.round(t*.46),strokeWidth:2.1}):l.jsx("span",{className:"avatar__ini",children:Dy(n)})}),s!=null&&l.jsx("span",{className:`avatar__dot ${s?"is-on":""}`,"aria-label":s?"online":"offline"}),c&&l.jsx("span",{className:"avatar__crown","aria-label":"owner",children:l.jsx(d2,{size:12,strokeWidth:2.6})})]})}function Ot({tone:n="plain",icon:e,small:t,block:s,className:a,children:c,onPointerEnter:u,...d}){return l.jsxs("button",{type:"button",className:["btn",`btn--${n}`,t&&"btn--sm",s&&"btn--block",a].filter(Boolean).join(" "),onPointerEnter:u,...d,children:[e,c!=null&&l.jsx("span",{children:c})]})}function Zt({label:n,tone:e,className:t,children:s,...a}){return l.jsx("button",{type:"button","aria-label":n,title:n,className:["icon-btn",e&&`icon-btn--${e}`,t].filter(Boolean).join(" "),...a,children:s})}const zi=q.forwardRef(function({label:e,icon:t,error:s,counter:a,className:c,...u},d){const f=q.useId(),p=typeof u.value=="string"?u.value.length:0;return l.jsxs("label",{className:["field",s&&"has-error",c].filter(Boolean).join(" "),htmlFor:f,children:[e&&l.jsx("span",{className:"field__label label",children:e}),l.jsxs("span",{className:"field__box",children:[t&&l.jsx("span",{className:"field__icon",children:t}),l.jsx("input",{id:f,ref:d,autoComplete:"off",spellCheck:!1,...u}),a&&u.maxLength?l.jsxs("span",{className:"field__count mono",children:[p,"/",u.maxLength]}):null]}),s&&l.jsx("span",{className:"field__error",children:s})]})}),QE=q.forwardRef(function({className:e,...t},s){return l.jsx("textarea",{ref:s,className:["area",e].filter(Boolean).join(" "),spellCheck:!1,...t})});function Pp({checked:n,onChange:e,label:t,hint:s}){return l.jsxs("button",{type:"button",role:"switch","aria-checked":n,className:`toggle ${n?"is-on":""}`,onClick:()=>{Me("select"),e(!n)},children:[l.jsxs("span",{className:"toggle__text",children:[l.jsx("span",{className:"label",children:t}),s&&l.jsx("span",{className:"toggle__hint",children:s})]}),l.jsx("span",{className:"toggle__track",children:l.jsx("span",{className:"toggle__knob"})})]})}function Bv({value:n,min:e=0,max:t=1,step:s=.01,onInput:a,onCommit:c,label:u,display:d}){const f=(n-e)/(t-e)*100;return l.jsxs("label",{className:"slider",children:[l.jsxs("span",{className:"slider__head",children:[l.jsx("span",{className:"label",children:u}),l.jsx("span",{className:"slider__val mono",children:d??`${Math.round(f)}%`})]}),l.jsxs("span",{className:"slider__wrap",style:{"--pct":`${f}%`},children:[l.jsx("span",{className:"slider__track",children:l.jsx("span",{className:"slider__fill"})}),l.jsx("span",{className:"slider__ticks","aria-hidden":!0,children:Array.from({length:11},(p,g)=>l.jsx("i",{},g))}),l.jsx("input",{type:"range",min:e,max:t,step:s,value:n,onChange:p=>a(Number(p.target.value)),onPointerUp:p=>c?.(Number(p.target.value)),onKeyUp:p=>c?.(Number(p.target.value))})]})]})}function Iu({value:n,options:e,onChange:t}){const s=Math.max(0,e.findIndex(a=>a.id===n));return l.jsxs("div",{className:"seg",style:{"--n":e.length,"--idx":s},children:[l.jsx("span",{className:"seg__thumb","aria-hidden":!0}),e.map(a=>l.jsxs("button",{type:"button",className:`seg__opt ${a.id===n?"is-on":""}`,onClick:()=>{a.id!==n&&(Me("select"),t(a.id))},children:[a.icon,l.jsx("span",{className:"label",children:a.label}),a.badge?l.jsx("span",{className:"seg__badge mono",children:a.badge}):null]},a.id))]})}function Kn({icon:n,title:e,body:t,action:s}){return l.jsxs("div",{className:"empty",children:[l.jsxs("span",{className:"empty__icon",children:[n,l.jsx("span",{className:"empty__orbit","aria-hidden":!0})]}),l.jsx("div",{className:"empty__title label",children:e}),t&&l.jsx("div",{className:"empty__body",children:t}),s]})}function Ei({text:n="Syncing"}){return l.jsxs("div",{className:"loader",children:[l.jsxs("span",{className:"loader__hex","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:n})]})}function En({children:n,aside:e}){return l.jsxs("div",{className:"sect",children:[l.jsx("span",{className:"sect__mark","aria-hidden":!0}),l.jsx("span",{className:"sect__text label",children:n}),l.jsx("span",{className:"sect__line","aria-hidden":!0}),e]})}function JE({canBack:n}){const e=he(y=>y.state),t=he(y=>y.clock),s=he(y=>y.seenToday),a=he(y=>y.state?.recents??kn),c=he(y=>y.state?.threads??kn),[u,d]=q.useState(!1),f=e?.line??null,p=q.useMemo(()=>{const y=vi(Date.now()),w=a.filter(E=>E.at>=y);return{calls:w.filter(E=>E.status==="answered").length,missed:w.filter(E=>E.direction==="in"&&E.status==="missed").length,talk:w.reduce((E,_)=>E+(_.duration||0),0),messages:Math.max(Object.keys(s).length,c.filter(E=>E.last&&E.last.kind==="text"&&E.last.at>=y).length)}},[a,s,c]),g=e?.contacts??[],v=g.filter(y=>y.online).length,x=async()=>{if(!f)return;const y=await dv(f.number);Me(y?"select":"error"),d(y),window.setTimeout(()=>d(!1),1500)};return l.jsx(ln,{icon:l.jsx(_2,{size:22}),title:"Status",subtitle:"Neural identity",tag:"NL//01-ID",canBack:n,children:l.jsxs("div",{className:"status nl-scroll",children:[l.jsxs("div",{className:"status__id",children:[l.jsxs("div",{className:"status__avatar",children:[l.jsx(Ht,{name:f?.name??"?",seed:f?.number??"x",size:112,ring:"sel"}),l.jsx("svg",{className:"status__orbit",viewBox:"0 0 140 140","aria-hidden":!0,children:l.jsx("circle",{cx:"70",cy:"70",r:"66"})})]}),l.jsxs("div",{className:"status__who",children:[l.jsx("div",{className:"status__name",children:f?.name??"No line assigned"}),l.jsxs("div",{className:"status__numrow",children:[l.jsx("span",{className:"status__num mono",children:f?.number??"--- ----"}),l.jsx(Ot,{small:!0,tone:"ghost",icon:l.jsx(Mv,{size:15}),onClick:x,disabled:!f,children:u?"Copied":"Copy"})]}),l.jsxs("div",{className:"status__chips",children:[l.jsxs("span",{className:`pill ${f?"pill--ok":"pill--danger"}`,children:[l.jsx(HM,{size:13})," ",f?"Linked":"Offline"]}),l.jsxs("span",{className:"pill",children:[l.jsx(Ln,{size:13})," ",v,"/",g.length," contacts online"]})]})]}),l.jsxs("div",{className:"status__clock",children:[l.jsx("div",{className:"status__time mono",children:t?`${Ss(t.hours)}:${Ss(t.minutes)}`:"--:--"}),l.jsxs("div",{className:"status__weather",children:[l.jsx(Rv,{weather:t?.weather,size:22})," ",t?.weather??"Weather unavailable"]}),l.jsx("div",{className:"status__city label",children:"Night City · NCT"})]})]}),l.jsx(En,{children:"Neural sync"}),l.jsx(ew,{linked:!!f,online:v,total:g.length}),l.jsx(En,{children:"Today"}),l.jsxs("div",{className:"stats",children:[l.jsx(bc,{icon:l.jsx(Zi,{size:20}),value:p.messages,label:"Messages"}),l.jsx(bc,{icon:l.jsx(Ji,{size:20}),value:p.calls,label:"Calls"}),l.jsx(bc,{icon:l.jsx(Ru,{size:20}),value:p.missed,label:"Missed",alert:p.missed>0}),l.jsx(bc,{icon:l.jsx(uu,{size:20}),value:Lu(e),label:"Unread"})]}),l.jsx(En,{aside:l.jsxs("span",{className:"mono status__sync",children:[v," online"]}),children:"Neural network"}),l.jsxs("div",{className:"netlist",children:[g.length===0&&l.jsx("span",{className:"netlist__none",children:"No contacts linked yet."}),[...g].sort((y,w)=>Number(w.online)-Number(y.online)||y.name.localeCompare(w.name)).map((y,w)=>l.jsxs("span",{className:`netlist__c ${y.online?"is-on":""}`,style:{"--i":w},title:`${y.name} · ${y.number}`,children:[l.jsx(Ht,{name:y.name,seed:y.number,size:46,online:y.online}),l.jsx("span",{children:y.name.split(" ")[0]})]},y.id))]})]})})}function bc({icon:n,value:e,label:t,alert:s}){return l.jsxs("div",{className:`stat ${s?"is-alert":""}`,children:[l.jsx("span",{className:"stat__icon",children:n}),l.jsx("span",{className:"stat__val mono",children:e}),l.jsx("span",{className:"stat__label label",children:t})]})}function ew({linked:n,online:e,total:t}){const s=Lv(),[a,c]=q.useState([0,0,0]);q.useEffect(()=>{const f=window.setInterval(()=>c(p=>p.map(g=>Math.max(-6,Math.min(6,g+(Math.random()-.5)*3)))),1600);return()=>window.clearInterval(f)},[]);const u=n?1:.12,d=[["Cortex link",s],["Bandwidth",64+(t?e/t*26:8)+a[0]],["Synaptic latency",88+a[1]*.8],["Firewall (ICE)",74+a[2]]];return l.jsx("div",{className:"nsync",children:d.map(([f,p],g)=>{const v=Math.max(0,Math.min(99,Math.round(p*u)));return l.jsxs("div",{className:"nsync__row",style:{"--i":g},children:[l.jsx("span",{className:"nsync__label label",children:f}),l.jsxs("span",{className:"nsync__track",children:[l.jsx("span",{className:"nsync__fill",style:{transform:`scaleX(${v/100})`}}),l.jsx("span",{className:"nsync__ticks","aria-hidden":!0})]}),l.jsxs("span",{className:"nsync__val mono",children:[l.jsx("i",{"aria-hidden":!0}),v]})]},f)})})}function tw({tab:n,canBack:e}){const t=he(u=>u.state),s=he(u=>u.recentsSeenAt),a=Du(t,s),c=u=>he.getState().replaceTop({app:"phone",tab:u});return q.useEffect(()=>{n==="recents"&&he.getState().markRecentsSeen()},[n,t?.recents]),l.jsxs(ln,{icon:l.jsx(Ji,{size:22}),title:"Phone",subtitle:t?.line?`Your line ${t.line.number}`:"No line",tag:"NL//02-TEL",canBack:e,bodyClass:"phone",children:[l.jsx(Iu,{value:n,onChange:c,options:[{id:"dial",label:"Keypad",icon:l.jsx(Ev,{size:16})},{id:"recents",label:"Recents",icon:l.jsx(yp,{size:16}),badge:a},{id:"favorites",label:"Favorites",icon:l.jsx(Ms,{size:16})}]}),l.jsxs("div",{className:"phone__pane",children:[n==="dial"&&l.jsx(iw,{}),n==="recents"&&l.jsx(rw,{}),n==="favorites"&&l.jsx(aw,{})]},n)]})}const nw=[["1",""],["2","ABC"],["3","DEF"],["4","GHI"],["5","JKL"],["6","MNO"],["7","PQRS"],["8","TUV"],["9","WXYZ"],["*",""],["0","+"],["#",""]];function iw(){const n=he(y=>y.dial),e=he(y=>y.state?.contacts??kn),t=he(y=>!!y.state?.call),[s,a]=q.useState(null),c=y=>he.getState().setDial(mp(y)),u=fp.test(n),d=u?e.find(y=>y.number===n):void 0,f=q.useMemo(()=>{const y=n.replace(/\D/g,"");return!y||u?[]:e.filter(w=>w.number.replace(/\D/g,"").startsWith(y)).slice(0,3)},[n,e,u]),p=y=>{if(!/\d/.test(y)){Me("tick");return}Me("tick"),a(y),window.setTimeout(()=>a(w=>w===y?null:w),140),c(he.getState().dial+y)},g=()=>{Me("back"),c(he.getState().dial.replace(/\D/g,"").slice(0,-1))},v=async()=>{u&&await Es(n)&&c("")},x=q.useCallback(y=>/^\d$/.test(y.key)?(p(y.key),!0):y.key==="Backspace"?(g(),!0):y.key==="Enter"?(v(),!0):!1,[n]);return dr(x),l.jsxs("div",{className:"dial",children:[l.jsxs("div",{className:"dial__display",children:[l.jsx("input",{className:"dial__input mono",value:n,placeholder:"555-0000",inputMode:"numeric",onChange:y=>c(y.target.value),onKeyDown:y=>{y.key==="Enter"&&(y.preventDefault(),v())},"aria-label":"Number"}),l.jsxs("div",{className:"dial__who",children:[d?l.jsxs(l.Fragment,{children:[l.jsx(Ht,{name:d.name,seed:d.number,size:22,online:d.online})," ",d.name]}):u?"Unknown number":f.length?"":"Enter a 7-digit number",f.map(y=>l.jsxs("button",{type:"button",className:"dial__sugg",onClick:()=>{Me("select"),c(y.number)},children:[y.name," ",l.jsx("span",{className:"mono",children:y.number})]},y.id))]}),l.jsx(Zt,{label:"Delete digit",onClick:g,disabled:!n,className:"dial__bs",children:l.jsx(f2,{size:22})})]}),l.jsx("div",{className:"dial__grid",children:nw.map(([y,w],E)=>l.jsxs("button",{type:"button",className:`dial__key ${s===y?"is-pressed":""}`,style:{"--i":E},onClick:()=>p(y),children:[l.jsx("span",{className:"dial__digit",children:y}),l.jsx("span",{className:"dial__letters mono",children:w})]},y))}),l.jsxs("div",{className:"dial__actions",children:[u&&!d&&l.jsx(Ot,{tone:"ghost",small:!0,icon:l.jsx(Qi,{size:16}),onClick:()=>Mn({app:"contacts",screen:"edit",number:n},"reset"),children:"Save"}),l.jsxs("button",{type:"button",className:`callbtn ${u&&!t?"":"is-off"}`,disabled:!u||t,onClick:v,"aria-label":"Call",children:[l.jsx("span",{className:"callbtn__glow","aria-hidden":!0}),l.jsx(cl,{size:30,strokeWidth:2.2})]})]})]})}function sw({r:n}){return n.direction==="in"&&n.status==="missed"?l.jsx(Ru,{size:18}):n.status==="declined"||n.status==="busy"||n.status==="unavailable"?l.jsx(Pu,{size:18}):n.direction==="in"?l.jsx(aM,{size:18}):l.jsx(uM,{size:18})}const Jg={answered:"",missed:"Missed",declined:"Declined",busy:"Busy",unavailable:"Unreachable"};function rw(){const n=he(u=>u.state?.recents??kn),e=he(u=>u.state?.contacts??kn),[t,s]=q.useState(!1),[a,c]=q.useState(-1);return dr(q.useMemo(()=>Kr(n.length,a,c,u=>{const d=n[u];d&&Es(d.number)}),[n,a])),n.length===0?l.jsx(Kn,{icon:l.jsx(yp,{size:30}),title:"No recent calls",body:"Calls you make and receive appear here."}):l.jsxs("div",{className:"recents",children:[l.jsxs("div",{className:"recents__bar",children:[l.jsxs("span",{className:"label recents__count",children:[n.length," calls"]}),t?l.jsxs("span",{className:"recents__confirm",children:[l.jsx("span",{children:"Clear all recents?"}),l.jsx(Ot,{small:!0,tone:"danger",onClick:async()=>{s(!1),await Tt("recents.clear",{})&&Me("back")},children:"Clear"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>s(!1),children:"Cancel"})]}):l.jsx(Ot,{small:!0,tone:"ghost",icon:l.jsx(hu,{size:15}),onClick:()=>s(!0),children:"Clear all"})]}),l.jsx("div",{className:"list nl-scroll",children:n.map((u,d)=>{const f=u.direction==="in"&&u.status==="missed",p=Fi(e,u.number,u.name),g=e.find(v=>v.number===u.number);return l.jsxs("button",{type:"button",className:`lrow ${f?"is-missed":""} ${a===d?"is-kbd":""}`,style:{"--i":Math.min(d,14)},onClick:()=>void Es(u.number),title:`Call ${p}`,children:[l.jsx("span",{className:`lrow__kind ${f?"is-missed":u.status!=="answered"?"is-dim":""}`,children:l.jsx(sw,{r:u})}),l.jsxs("span",{className:"lrow__main",children:[l.jsx("span",{className:"lrow__title",children:p}),l.jsxs("span",{className:"lrow__sub",children:[p!==u.number&&l.jsx("span",{className:"mono",children:u.number}),l.jsxs("span",{children:[u.direction==="in"?"Incoming":"Outgoing",Jg[u.status]?` · ${Jg[u.status]}`:"",u.status==="answered"&&u.duration>0?` · ${pp(u.duration)}`:""]})]})]}),l.jsxs("span",{className:"lrow__side",children:[l.jsx("span",{className:"lrow__time",children:Tu(u.at)}),!g&&l.jsx("span",{className:"lrow__tag label",children:"Unknown"})]}),l.jsx("span",{className:"lrow__call",children:l.jsx(cl,{size:18})})]},u.id)})})]})}function aw(){const n=he(a=>a.state?.contacts??kn),e=q.useMemo(()=>n.filter(a=>a.favorite).sort((a,c)=>a.name.localeCompare(c.name)),[n]),[t,s]=q.useState(-1);return dr(q.useMemo(()=>Kr(e.length,t,s,a=>{const c=e[a];c&&Es(c.number)}),[e,t])),e.length===0?l.jsx(Kn,{icon:l.jsx(Ms,{size:30}),title:"No favorites",body:"Star a contact to pin it here.",action:l.jsx(Ot,{tone:"ghost",small:!0,onClick:()=>Mn({app:"contacts",screen:"list",filter:"all"},"reset"),children:"Open contacts"})}):l.jsx("div",{className:"favs nl-scroll",children:e.map((a,c)=>l.jsxs("button",{type:"button",className:`fav ${t===c?"is-kbd":""}`,style:{"--i":c},onClick:()=>void Es(a.number),children:[l.jsx(Ht,{name:a.name,seed:a.number,size:78,online:a.online}),l.jsx("span",{className:"fav__name",children:a.name}),l.jsx("span",{className:"fav__num mono",children:a.number}),l.jsxs("span",{className:"fav__call",children:[l.jsx(cl,{size:15})," Call"]})]},a.id))})}function Hv(n){return n.kind==="direct"?n.members.find(e=>!e.isMe)??null:null}function ow(n){return n.last?n.last.kind==="system"?n.last.body:n.last.mine?`You: ${n.last.body}`:n.kind==="group"?`${n.last.sender.split(" ")[0]}: ${n.last.body}`:n.last.body:"No messages yet"}function lw({canBack:n}){const e=he(f=>f.state?.threads??kn),[t,s]=q.useState(""),[a,c]=q.useState(-1),u=q.useMemo(()=>{const f=t.trim().toLowerCase();return f?e.filter(p=>p.title.toLowerCase().includes(f)||(p.last?.body.toLowerCase().includes(f)??!1)||p.members.some(g=>g.name.toLowerCase().includes(f)||g.number.includes(f))):e},[e,t]);dr(q.useMemo(()=>Kr(u.length,a,c,f=>{const p=u[f];p&&$a(p.id)}),[u,a]));const d=e.reduce((f,p)=>f+p.unread,0);return l.jsx(ln,{icon:l.jsx(Zi,{size:22}),title:"Messages",subtitle:d?`${d} unread`:`${e.length} threads`,tag:"NL//03-MSG",canBack:n,actions:l.jsxs(l.Fragment,{children:[l.jsx(Zt,{label:"New group",onClick:()=>Mn({app:"messages",screen:"group-new"}),children:l.jsx(Ln,{size:18})}),l.jsx(Zt,{label:"New message",tone:"sel",onClick:()=>Mn({app:"messages",screen:"new"}),children:l.jsx(du,{size:18})})]}),children:l.jsxs("div",{className:"msgs",children:[l.jsx(zi,{icon:l.jsx(cr,{size:16}),placeholder:"Search messages and people",value:t,onChange:f=>{s(f.target.value),c(-1)},className:"msgs__search"}),e.length===0?l.jsx(Kn,{icon:l.jsx(Zi,{size:30}),title:"No conversations",body:"Start a thread with a number or a contact.",action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(du,{size:16}),onClick:()=>Mn({app:"messages",screen:"new"}),children:"New message"})}):u.length===0?l.jsx(Kn,{icon:l.jsx(cr,{size:30}),title:"No match",body:`Nothing for "${t}".`}):l.jsx("div",{className:"list nl-scroll",children:u.map((f,p)=>{const g=Hv(f);return l.jsxs("button",{type:"button",className:`trow ${f.unread?"is-unread":""} ${a===p?"is-kbd":""}`,style:{"--i":Math.min(p,14)},onClick:()=>$a(f.id),children:[l.jsx(Ht,{name:f.title,seed:g?.number??`g${f.id}`,size:48,group:f.kind==="group",online:g?g.online:null}),l.jsxs("span",{className:"trow__main",children:[l.jsxs("span",{className:"trow__top",children:[l.jsx("span",{className:"trow__title",children:f.title}),f.kind==="group"&&l.jsxs("span",{className:"trow__count mono",children:[l.jsx(Ln,{size:12})," ",f.members.length]})]}),l.jsx("span",{className:`trow__prev ${f.last?.kind==="system"?"is-system":""}`,children:ow(f)})]}),l.jsxs("span",{className:"trow__side",children:[l.jsx("span",{className:"trow__time",children:f.last?uv(f.last.at):""}),f.unread>0&&l.jsx("span",{className:"badge mono",children:f.unread>99?"99+":f.unread})]})]},f.id)})})]})})}function dl({mode:n,exclude:e=[],selected:t=[],max:s=15,onPick:a,onChange:c,pickLabel:u="Select"}){const d=he(k=>k.state?.contacts??kn),f=he(k=>k.state?.line?.number),[p,g]=q.useState(""),[v,x]=q.useState(""),[y,w]=q.useState(null),E=q.useMemo(()=>{const k=p.trim().toLowerCase();return[...d].filter(D=>!e.includes(D.number)&&D.number!==f).filter(D=>!k||D.name.toLowerCase().includes(k)||D.number.includes(k)).sort((D,U)=>Number(U.online)-Number(D.online)||D.name.localeCompare(U.name))},[d,p,e,f]),_=n==="multi"&&t.length>=s,[M,L]=q.useState(-1),A=k=>{if(n==="single"){Me("select"),a?.(k);return}if(t.includes(k)){Me("back"),c?.(t.filter(D=>D!==k));return}if(_){Me("error");return}Me("select"),c?.([...t,k])};dr(q.useMemo(()=>Kr(E.length,M,L,k=>{const D=E[k];D&&A(D.number)}),[E,M,t]));const R=()=>{if(!fp.test(v)){w("Numbers look like 555-0123."),Me("error");return}if(v===f){w("That is your own number."),Me("error");return}if(e.includes(v)){w("Already included."),Me("error");return}w(null),A(v),x("")};return l.jsxs("div",{className:"picker",children:[n==="multi"&&t.length>0&&l.jsxs("div",{className:"chips",children:[t.map(k=>l.jsxs("span",{className:"chip",children:[l.jsx("span",{children:Fi(d,k)}),l.jsx("button",{type:"button","aria-label":"Remove",onClick:()=>A(k),children:l.jsx(io,{size:13,strokeWidth:2.6})})]},k)),l.jsxs("span",{className:"chips__count mono",children:[t.length,"/",s]})]}),l.jsxs("div",{className:"picker__row",children:[l.jsx(zi,{icon:l.jsx(cr,{size:16}),placeholder:"Search contacts",value:p,onChange:k=>g(k.target.value)}),l.jsx(zi,{icon:l.jsx(rl,{size:16}),placeholder:"555-0000",inputMode:"numeric",value:v,error:y,className:"picker__raw",onChange:k=>{x(mp(k.target.value)),w(null)},onKeyDown:k=>{k.key==="Enter"&&(k.preventDefault(),R())}}),l.jsx(Zt,{label:n==="multi"?"Add number":u,tone:"sel",onClick:R,disabled:v.length===0,children:l.jsx(_M,{size:18,strokeWidth:2.6})})]}),l.jsxs("div",{className:"picker__list nl-scroll",children:[E.length===0&&l.jsx("div",{className:"picker__none",children:d.length===0?"No contacts yet. Type a number above.":"No match."}),E.map((k,D)=>{const U=t.includes(k.number);return l.jsxs("button",{type:"button",className:`prow ${U?"is-on":""} ${M===D?"is-kbd":""}`,style:{"--i":Math.min(D,12)},disabled:n==="multi"&&_&&!U,onClick:()=>A(k.number),children:[l.jsx(Ht,{name:k.name,seed:k.number,size:36,online:k.online}),l.jsxs("span",{className:"prow__text",children:[l.jsx("span",{className:"prow__name",children:k.name}),l.jsx("span",{className:"prow__num mono",children:k.number})]}),n==="multi"?l.jsx("span",{className:`check ${U?"is-on":""}`,children:U&&l.jsx(vp,{size:14,strokeWidth:3})}):l.jsx("span",{className:"prow__pick label",children:u})]},k.id)})]})]})}const e_=n=>Array.isArray(n)?n:n&&typeof n=="object"?Object.values(n):[];function cw(n){return n.input==="contact"?l.jsx(kM,{size:14}):n.style==="danger"?l.jsx(io,{size:14}):n.style==="primary"?l.jsx(vp,{size:14}):null}function uw({m:n}){const e=n.meta,[t,s]=q.useState(null),[a,c]=q.useState(null);if(!e)return null;const u=e_(e.actions),d=e_(e.card?.lines),f=e.location,p=async(v,x)=>{if(t)return;if(v.input==="contact"&&!x){Me("select"),c(v);return}s(v.id),Me("select");const y=await Tt("messages.action",{messageId:n.id,action:v.id,...x?{value:x}:{}});s(null),y&&x&&c(null)},g=async()=>{if(!f)return;Me("select"),await Tt("map.pin",{x:f.x,y:f.y,z:f.z,...f.label?{label:f.label}:{}})&&Iv("Waypoint set",f.label??"Pinned on your map.")};return l.jsxs("div",{className:"rich",onClick:v=>v.stopPropagation(),children:[e.card&&l.jsxs("div",{className:"rich__card",children:[e.card.tag&&l.jsx("span",{className:"rich__tag mono",children:e.card.tag}),l.jsx("b",{className:"rich__title",children:e.card.title}),e.card.subtitle&&l.jsx("span",{className:"rich__sub",children:e.card.subtitle}),d.length>0&&l.jsx("ul",{className:"rich__lines",children:d.map((v,x)=>l.jsx("li",{children:v},x))})]}),f&&l.jsxs("button",{type:"button",className:"btn btn--sm btn--ghost rich__pin",onClick:()=>{g()},children:[l.jsx(ll,{size:14})," ",l.jsx("span",{children:f.label?`Pin ${f.label}`:"Pin on map"})]}),e.resolved?l.jsx("span",{className:`rich__resolved rich__resolved--${e.resolved.tone??"dim"} mono`,children:e.resolved.label}):u.length>0&&l.jsx("div",{className:"rich__actions",children:u.map(v=>l.jsxs("button",{type:"button",disabled:t!==null,className:`btn btn--sm ${v.style==="primary"?"btn--ok":v.style==="danger"?"btn--danger":"btn--ghost"} ${a?.id===v.id?"is-on":""}`,onClick:()=>{a?.id===v.id?c(null):p(v)},children:[cw(v)," ",l.jsx("span",{children:t===v.id?"…":v.label})]},v.id))}),a&&!e.resolved&&l.jsxs("div",{className:"rich__picker",children:[l.jsxs("span",{className:"label",children:[a.label,": pick a contact or type a number"]}),l.jsx(dl,{mode:"single",onPick:v=>{p(a,v)},pickLabel:"Send"})]})]})}const Ch=10*6e4;function dw(n,e,t){const s=[];let a=null;n.forEach((c,u)=>{const d=n[u+1];if(!a||vi(a.at)!==vi(c.at)?s.push({kind:"day",key:`d${c.id}`,label:pf(c.at)}):c.at-a.at>Ch&&s.push({kind:"time",key:`t${c.id}`,label:Wa(c.at)}),c.kind==="system")s.push({kind:"system",key:`s${c.id}`,m:c});else{const f=!!a&&a.kind==="text"&&a.sender.number===c.sender.number&&c.at-a.at<=Ch&&vi(a.at)===vi(c.at),p=!!d&&d.kind==="text"&&d.sender.number===c.sender.number&&d.at-c.at<=Ch&&vi(d.at)===vi(c.at);s.push({kind:"msg",key:`m${c.id}`,m:c,first:!f,last:!p,showName:t&&!c.mine&&!f})}a=c});for(const c of e)s.push({kind:"pending",key:`p${c.tempId}`,p:c});return s}function hw({threadId:n,canBack:e}){const t=he(k=>k.state?.threads.find(D=>D.id===n)??null),s=he(k=>k.threadCache[n]),a=he(k=>k.pending),c=he(k=>k.state?.contacts??kn),u=he(k=>!!k.state?.call),d=q.useMemo(()=>a.filter(k=>k.threadId===n&&!(s?.messages.some(D=>D.id===k.serverId)??!1)),[a,n,s]),f=q.useRef(null),p=q.useRef(null),g=q.useRef(null),[v,x]=q.useState(!0);q.useEffect(()=>{he.getState().threadCache[n]||mu(n)},[n]);const y=t?.kind==="group",w=q.useMemo(()=>dw(s?.messages??[],d,y),[s?.messages,d,y]);q.useLayoutEffect(()=>{const k=f.current;!k||!s||(s.lastOp==="prepend"&&p.current?(k.scrollTop=k.scrollHeight-p.current.h+p.current.t,p.current=null):s.lastOp==="load"&&(k.scrollTop=k.scrollHeight))},[s?.rev]),q.useEffect(()=>{const k=f.current;if(!k||!s||s.lastOp!=="append")return;const D=s.messages[s.messages.length-1];(v||D?.mine)&&k.scrollTo({top:k.scrollHeight,behavior:"smooth"})},[s?.rev]),q.useEffect(()=>{const k=f.current;k&&d.length&&k.scrollTo({top:k.scrollHeight,behavior:"smooth"})},[d.length]);const E=k=>g.current!=null&&!g.current.has(k)&&s?.lastOp==="append";q.useEffect(()=>{if(!(!s||s.loading)){g.current??=new Set;for(const k of s.messages)g.current.add(k.id)}});const _=()=>{const k=f.current;if(!k)return;const D=k.scrollHeight-k.scrollTop-k.clientHeight<140;D!==v&&x(D),k.scrollTop<60&&s?.hasMore&&!s.loadingMore&&!s.loading&&(p.current={h:k.scrollHeight,t:k.scrollTop},kE(n))};if(!t)return l.jsx(ln,{icon:l.jsx(Zi,{size:22}),title:"Thread",tag:"NL//03-MSG",canBack:e,children:l.jsx(Kn,{icon:l.jsx(Tp,{size:30}),title:"Thread unavailable",body:"You are no longer part of this conversation."})});const M=Hv(t),L=M?c.find(k=>k.number===M.number):void 0,A=t.members.filter(k=>!k.isMe&&k.online).length,R=y?`${t.members.length} members · ${A} online`:M?`${M.number}${M.online?" · online":" · offline"}`:"";return l.jsxs(ln,{className:"win--thread",icon:l.jsx(Ht,{name:t.title,seed:M?.number??`g${t.id}`,size:40,group:y,online:M?M.online:null}),title:t.title,subtitle:R,tag:`THR-${String(t.id).padStart(4,"0")}`,canBack:e,actions:l.jsxs(l.Fragment,{children:[M&&!L&&l.jsx(Zt,{label:"Save contact",onClick:()=>Mn({app:"contacts",screen:"edit",number:M.number}),children:l.jsx(Qi,{size:18})}),l.jsx(Zt,{label:y?"Group call":"Call",tone:"ok",disabled:u,onClick:()=>{y?Fv(t.id):M&&Es(M.number)},children:y?l.jsx(Ln,{size:18}):l.jsx(Ji,{size:18})}),y&&l.jsx(Zt,{label:"Group info",onClick:()=>Mn({app:"messages",screen:"group-info",threadId:t.id}),children:l.jsx(Sp,{size:18})})]}),bodyClass:"thread",footer:l.jsx(pw,{threadId:n}),children:[l.jsx("div",{className:"thread__scroll nl-scroll",ref:f,onScroll:_,children:!s||s.loading?l.jsx(Ei,{text:"Decrypting thread"}):l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"thread__head",children:s.loadingMore?l.jsx(Ei,{text:"Loading older"}):s.hasMore?l.jsx("span",{className:"thread__more mono",children:"scroll up for older"}):l.jsxs("span",{className:"thread__start",children:[l.jsx(Ht,{name:t.title,seed:M?.number??`g${t.id}`,size:58,group:y}),l.jsx("span",{className:"label",children:y?"Group created":"Start of the conversation"}),l.jsx("span",{className:"mono",children:"end-to-end neural encryption"})]})}),w.length===0&&l.jsx("div",{className:"thread__empty",children:"Say hello."}),w.map(k=>{switch(k.kind){case"day":return l.jsx("div",{className:"tdiv",children:l.jsx("span",{className:"label",children:k.label})},k.key);case"time":return l.jsx("div",{className:"tdiv tdiv--time",children:l.jsx("span",{className:"mono",children:k.label})},k.key);case"system":return l.jsx("div",{className:`sysmsg ${E(k.m.id)?"is-new":""}`,children:l.jsx("span",{children:k.m.body})},k.key);case"msg":return l.jsxs(q.Fragment,{children:[k.showName&&l.jsx("div",{className:"bname",style:{"--hue":fw(k.m.sender.number)},children:k.m.sender.name}),l.jsxs("div",{className:`bubble-row ${k.m.mine?"is-mine":""} ${k.first?"is-first":""} ${k.last?"is-last":""} ${E(k.m.id)?"is-new":""}`,children:[y&&!k.m.mine&&l.jsx("span",{className:"bubble-row__av",children:k.last&&l.jsx(Ht,{name:k.m.sender.name,seed:k.m.sender.number,size:30})}),l.jsxs("div",{className:`bubble ${k.m.meta?"bubble--rich":""}`,children:[l.jsx("span",{className:"bubble__text",children:k.m.body}),k.m.meta&&l.jsx(uw,{m:k.m}),l.jsx("span",{className:"bubble__time mono",children:Wa(k.m.at)})]})]})]},k.key);case"pending":return l.jsx("div",{className:`bubble-row is-mine is-first is-last is-pending ${k.p.failed?"is-failed":""}`,children:l.jsxs("div",{className:"bubble",children:[l.jsx("span",{className:"bubble__text",children:k.p.body}),l.jsx("span",{className:"bubble__time mono",children:k.p.failed?l.jsxs("button",{type:"button",className:"bubble__retry",onClick:()=>IE(k.p.tempId),children:[l.jsx(TM,{size:12})," Retry"]}):l.jsxs("span",{className:"bubble__dots",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})})]})},k.key)}return null})]})}),!v&&l.jsx("button",{type:"button",className:"thread__jump",onClick:()=>f.current?.scrollTo({top:f.current.scrollHeight,behavior:"smooth"}),children:"Latest"})]})}function fw(n){let e=0;for(let t=0;t<n.length;t++)e=e*31+n.charCodeAt(t)>>>0;return e%360}function pw({threadId:n}){const[e,t]=q.useState(""),s=q.useRef(null),a=e.length,c=e.trim().length>0&&a<=Ea,u=q.useCallback(()=>{const f=s.current;f&&(f.style.height="auto",f.style.height=`${Math.min(124,f.scrollHeight)}px`)},[]);q.useLayoutEffect(u,[e,u]);const d=()=>{if(!c)return;const f=e.replace(/\s+$/,"");t(""),Uv(n,f)};return l.jsxs("div",{className:"composer",children:[l.jsxs("div",{className:"composer__box",children:[l.jsx("textarea",{ref:s,className:"composer__input",rows:1,value:e,maxLength:Ea,placeholder:"Neural message…",spellCheck:!1,onChange:f=>t(f.target.value.slice(0,Ea)),onKeyDown:f=>{f.key==="Enter"&&!f.shiftKey&&!f.nativeEvent.isComposing&&(f.preventDefault(),d())}}),l.jsxs("span",{className:`composer__count mono ${a>Ea-50?"is-warn":""} ${a>=Ea?"is-max":""}`,children:[a,"/",Ea]})]}),l.jsx("button",{type:"button",className:`composer__send ${c?"is-ready":""}`,disabled:!c,onClick:d,"aria-label":"Send",children:l.jsx(NM,{size:22,strokeWidth:2.2})})]})}function mw({canBack:n}){const[e,t]=q.useState(!1),[s,a]=q.useState(null),c=async u=>{if(!e){t(!0),a(null);try{const d=await Hr("threads.direct",{number:u});$a(d.threadId,"reset")}catch(d){Me("error"),a(On(d instanceof Sn?d.slug:"unknown")),t(!1)}}};return l.jsx(ln,{icon:l.jsx(du,{size:22}),title:"New message",subtitle:"Choose who to reach",tag:"NL//03-NEW",canBack:n,children:l.jsxs("div",{className:"form",children:[s&&l.jsx("div",{className:"form__error",children:s}),l.jsx(dl,{mode:"single",onPick:c,pickLabel:"Message"})]})})}function gw({canBack:n}){const[e,t]=q.useState(""),[s,a]=q.useState([]),[c,u]=q.useState(!1),[d,f]=q.useState(null),p=e.trim().length>=1&&e.trim().length<=32,g=s.length>=Eh&&s.length<=Jc,v=async()=>{if(!p||!g||c){Me("error");return}u(!0),f(null);try{const y=await Hr("groups.create",{title:e.trim(),numbers:s});$a(y.threadId,"reset")}catch(y){Me("error"),f(On(y instanceof Sn?y.slug:"unknown")),u(!1)}},x=Eh-s.length;return l.jsx(ln,{icon:l.jsx(Ln,{size:22}),title:"New group",subtitle:`${s.length} selected · ${Eh} to ${Jc} members`,tag:"NL//03-GRP",canBack:n,footer:l.jsxs("div",{className:"form__bar",children:[l.jsx("span",{className:"form__hint",children:p?x>0?`Add ${x} more member${x>1?"s":""}.`:"Ready to link.":"Give the group a name."}),l.jsx(Ot,{tone:"sel",icon:l.jsx(Ln,{size:17}),onClick:v,disabled:!p||!g||c,children:c?"Creating…":"Create group"})]}),children:l.jsxs("div",{className:"form",children:[l.jsx(zi,{label:"Group name",icon:l.jsx(iE,{size:16}),placeholder:"Afterlife Crew",value:e,maxLength:32,counter:!0,onChange:y=>t(y.target.value)}),d&&l.jsx("div",{className:"form__error",children:d}),l.jsx(dl,{mode:"multi",selected:s,onChange:a,max:Jc})]})})}function _w({threadId:n,canBack:e}){const t=he(te=>te.state?.threads.find(T=>T.id===n)??null),s=he(te=>te.threadCache[n]?.members),a=he(te=>!!te.state?.call),[c,u]=q.useState(!1),[d,f]=q.useState(t?.title??""),[p,g]=q.useState(!1),[v,x]=q.useState(!1),[y,w]=q.useState(null),[E,_]=q.useState(null);if(q.useEffect(()=>{c||f(t?.title??"")},[t?.title,c]),!t)return l.jsx(ln,{icon:l.jsx(Ln,{size:22}),title:"Group",canBack:e,children:l.jsx("div",{className:"form",children:l.jsx("div",{className:"form__error",children:"This group is no longer available."})})});const M=[...t.members.length?t.members:s??[]].sort((te,T)=>Number(T.owner)-Number(te.owner)||Number(T.isMe)-Number(te.isMe)||Number(T.online)-Number(te.online)||te.name.localeCompare(T.name)),L=t.isOwner,A=M.length-1>=Jc,R=te=>{Me("error"),_(On(te instanceof Sn?te.slug:"unknown"))},k=async()=>{const te=d.trim();if(!te||te===t.title){u(!1);return}try{await Hr("groups.rename",{threadId:n,title:te}),Me("select"),u(!1),_(null)}catch(T){R(T)}},D=async te=>{try{await Hr("groups.add",{threadId:n,number:te}),Me("select"),g(!1),_(null)}catch(T){R(T)}},U=async te=>{w(null);try{await Hr("groups.remove",{threadId:n,number:te}),Me("back"),_(null)}catch(T){R(T)}},$=async()=>{await Tt("groups.leave",{threadId:n})&&(Me("back"),he.getState().resetView({app:"messages",screen:"list"}))};return l.jsx(ln,{icon:l.jsx(Ln,{size:22}),title:"Group info",subtitle:`${M.length} members${L?" · you own this group":""}`,tag:`GRP-${String(n).padStart(4,"0")}`,canBack:e,children:l.jsxs("div",{className:"ginfo nl-scroll",children:[l.jsxs("div",{className:"ginfo__hero",children:[l.jsx(Ht,{name:t.title,seed:`g${t.id}`,size:84,group:!0,ring:"sel"}),c?l.jsxs("div",{className:"ginfo__rename",children:[l.jsx(zi,{value:d,maxLength:32,counter:!0,onChange:te=>f(te.target.value),onKeyDown:te=>{te.key==="Enter"&&(te.preventDefault(),k())}}),l.jsx(Zt,{label:"Save name",tone:"sel",onClick:k,children:l.jsx(vp,{size:18})}),l.jsx(Zt,{label:"Cancel",onClick:()=>u(!1),children:l.jsx(io,{size:18})})]}):l.jsxs("div",{className:"ginfo__title",children:[l.jsx("span",{children:t.title}),l.jsx(Zt,{label:"Rename group",onClick:()=>u(!0),children:l.jsx(bv,{size:16})})]}),l.jsxs("div",{className:"ginfo__actions",children:[l.jsx(Ot,{tone:"ok",icon:l.jsx(Ji,{size:17}),disabled:a,onClick:()=>void Fv(n),children:"Group call"}),l.jsx(Ot,{tone:"ghost",icon:l.jsx(Qi,{size:17}),disabled:A,onClick:()=>g(te=>!te),children:p?"Close":"Add member"})]})]}),E&&l.jsx("div",{className:"form__error",children:E}),p&&l.jsxs("div",{className:"ginfo__add",children:[l.jsx(En,{children:"Add a member"}),l.jsx(dl,{mode:"single",exclude:M.map(te=>te.number),onPick:D,pickLabel:"Add"})]}),l.jsx(En,{aside:l.jsxs("span",{className:"mono ginfo__online",children:[M.filter(te=>te.online).length," online"]}),children:"Members"}),l.jsx("div",{className:"ginfo__members",children:M.map((te,T)=>l.jsxs("div",{className:"mrow",style:{"--i":Math.min(T,14)},children:[l.jsx(Ht,{name:te.name,seed:te.number,size:40,online:te.online,owner:te.owner}),l.jsxs("span",{className:"mrow__main",children:[l.jsxs("span",{className:"mrow__name",children:[te.name,te.isMe&&l.jsx("span",{className:"mrow__me label",children:"You"})]}),l.jsxs("span",{className:"mrow__num mono",children:[te.number,te.owner?" · owner":""]})]}),L&&!te.isMe&&(y===te.number?l.jsxs("span",{className:"mrow__confirm",children:[l.jsx(Ot,{small:!0,tone:"danger",onClick:()=>U(te.number),children:"Remove"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>w(null),children:"Keep"})]}):l.jsx(Zt,{label:`Remove ${te.name}`,tone:"danger",onClick:()=>w(te.number),children:l.jsx(oE,{size:17})}))]},te.number))}),l.jsx("div",{className:"ginfo__leave",children:v?l.jsxs(l.Fragment,{children:[l.jsxs("span",{children:["Leave “",t.title,"”? You will stop receiving its messages."]}),l.jsx(Ot,{tone:"danger",icon:l.jsx(zg,{size:16}),onClick:$,children:"Leave group"}),l.jsx(Ot,{tone:"ghost",onClick:()=>x(!1),children:"Cancel"})]}):l.jsx(Ot,{tone:"danger",icon:l.jsx(zg,{size:16}),onClick:()=>x(!0),children:"Leave group"})})]})})}const vw=n=>{const e=n.trim()[0]?.toUpperCase()??"#";return/[A-Z]/.test(e)?e:"#"};function xw({filter:n,canBack:e}){const t=he(E=>E.state?.contacts??kn),s=he(E=>!!E.state?.call),[a,c]=q.useState(""),[u,d]=q.useState(-1),f=q.useRef(null),p=q.useMemo(()=>{const E=a.trim().toLowerCase();return t.filter(_=>n==="all"||_.favorite).filter(_=>!E||_.name.toLowerCase().includes(E)||_.number.includes(E)).sort((_,M)=>_.name.localeCompare(M.name,void 0,{sensitivity:"base"}))},[t,a,n]),g=q.useMemo(()=>{const E=[];return p.forEach((_,M)=>{const L=vw(_.name),A=E[E.length-1];A&&A.letter===L?A.items.push({c:_,idx:M}):E.push({letter:L,items:[{c:_,idx:M}]})}),E},[p]),v=g.map(E=>E.letter);dr(q.useMemo(()=>Kr(p.length,u,d,E=>{const _=p[E];_&&Es(_.number)}),[p,u]));const x=E=>he.getState().replaceTop({app:"contacts",screen:"list",filter:E}),y=async E=>{Me("select"),await Tt("contacts.save",{id:E.id,name:E.name,number:E.number,favorite:!E.favorite})},w=E=>{Me("tick"),f.current?.querySelector(`[data-letter="${E}"]`)?.scrollIntoView({block:"start",behavior:"smooth"})};return l.jsx(ln,{icon:l.jsx(sl,{size:22}),title:"Contacts",subtitle:`${t.length} saved · ${t.filter(E=>E.online).length} online`,tag:"NL//04-DIR",canBack:e,actions:l.jsx(Zt,{label:"Add contact",tone:"sel",onClick:()=>Mn({app:"contacts",screen:"edit"}),children:l.jsx(Qi,{size:18})}),children:l.jsxs("div",{className:"contacts",children:[l.jsxs("div",{className:"contacts__bar",children:[l.jsx(Iu,{value:n,onChange:x,options:[{id:"all",label:"All"},{id:"favorites",label:"Favorites",icon:l.jsx(Ms,{size:14})}]}),l.jsx(zi,{icon:l.jsx(cr,{size:16}),placeholder:"Search",value:a,onChange:E=>{c(E.target.value),d(-1)}})]}),p.length===0?t.length===0?l.jsx(Kn,{icon:l.jsx(sl,{size:30}),title:"No contacts",body:"Save the numbers you meet in Night City.",action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(Qi,{size:16}),onClick:()=>Mn({app:"contacts",screen:"edit"}),children:"Add contact"})}):l.jsx(Kn,{icon:n==="favorites"?l.jsx(Ms,{size:30}):l.jsx(cr,{size:30}),title:n==="favorites"&&!a?"No favorites":"No match",body:n==="favorites"&&!a?"Tap the star on a contact to pin it.":void 0}):l.jsxs("div",{className:"contacts__body",children:[l.jsx("div",{className:"list nl-scroll",ref:f,children:g.map(E=>l.jsxs("div",{className:"csec",children:[l.jsx("div",{className:"csec__letter label","data-letter":E.letter,children:E.letter}),E.items.map(({c:_,idx:M})=>l.jsxs("div",{className:`crow ${u===M?"is-kbd":""}`,style:{"--i":Math.min(M,14)},children:[l.jsx(Ht,{name:_.name,seed:_.number,size:44,online:_.online}),l.jsxs("span",{className:"crow__main",children:[l.jsx("span",{className:"crow__name",children:_.name}),l.jsxs("span",{className:"crow__num mono",children:[_.number,l.jsx("span",{className:`crow__state ${_.online?"is-on":""}`,children:_.online?"online":"offline"})]})]}),l.jsxs("span",{className:"crow__acts",children:[l.jsx(Zt,{label:_.favorite?"Unstar":"Star",className:`star ${_.favorite?"is-on":""}`,onClick:()=>y(_),children:l.jsx(Ms,{size:17})}),l.jsx(Zt,{label:"Message",onClick:()=>void LE(_.number),children:l.jsx(Zi,{size:17})}),l.jsx(Zt,{label:"Call",tone:"ok",disabled:s,onClick:()=>void Es(_.number),children:l.jsx(Ji,{size:17})}),l.jsx(Zt,{label:"Edit",onClick:()=>Mn({app:"contacts",screen:"edit",id:_.id}),children:l.jsx(bv,{size:16})})]})]},_.id))]},E.letter))}),v.length>1&&l.jsx("div",{className:"alpha","aria-label":"Index",children:v.map(E=>l.jsx("button",{type:"button",className:"alpha__l mono",onClick:()=>w(E),children:E},E))})]})]})})}function yw({id:n,number:e,canBack:t}){const s=he(D=>n!=null?D.state?.contacts.find(U=>U.id===n):void 0),a=he(D=>D.state?.line?.number),[c,u]=q.useState(s?.name??""),[d,f]=q.useState(s?.number??e??""),[p,g]=q.useState(s?.favorite??!1),[v,x]=q.useState(null),[y,w]=q.useState(!1),[E,_]=q.useState(!1),M=c.trim().length>=1&&c.trim().length<=32,L=fp.test(d),A=()=>{he.getState().back()||he.getState().resetView(null)},R=async()=>{if(!M){x(On("invalid_name")),Me("error");return}if(!L){x(On("invalid_number")),Me("error");return}if(d===a){x(On("self")),Me("error");return}w(!0),x(null);try{await Hr("contacts.save",{id:s?.id,name:c.trim(),number:d,favorite:p}),Me("select"),A()}catch(D){Me("error"),x(On(D instanceof Sn?D.slug:"unknown")),w(!1)}},k=async()=>{s&&await Tt("contacts.delete",{id:s.id})&&(Me("back"),A())};return l.jsx(ln,{icon:s?l.jsx(bp,{size:22}):l.jsx(Qi,{size:22}),title:s?"Edit contact":"New contact",subtitle:s?s.number:"Save a neural line",tag:"NL//04-EDT",canBack:t,footer:l.jsxs("div",{className:"form__bar",children:[s?E?l.jsxs("span",{className:"form__confirm",children:[l.jsxs("span",{children:["Delete ",s.name,"?"]}),l.jsx(Ot,{small:!0,tone:"danger",onClick:k,children:"Delete"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>_(!1),children:"Keep"})]}):l.jsx(Ot,{tone:"danger",icon:l.jsx(hu,{size:16}),onClick:()=>_(!0),children:"Delete"}):l.jsx("span",{}),l.jsx(Ot,{tone:"sel",icon:l.jsx(Cv,{size:17}),onClick:R,disabled:y,children:y?"Saving…":"Save"})]}),children:l.jsxs("div",{className:"form form--contact",children:[l.jsx("div",{className:"form__hero",children:l.jsx(Ht,{name:c||"?",seed:d||"new",size:96,ring:"sel"})}),l.jsx(zi,{label:"Name",icon:l.jsx(no,{size:16}),placeholder:"Jackie Welles",value:c,maxLength:32,counter:!0,onChange:D=>{u(D.target.value),x(null)},onKeyDown:D=>{D.key==="Enter"&&(D.preventDefault(),R())}}),l.jsx(zi,{label:"Number",icon:l.jsx(rl,{size:16}),placeholder:"555-0000",inputMode:"numeric",value:d,error:d.length>0&&d.length===8&&!L?On("invalid_number"):null,onChange:D=>{f(mp(D.target.value)),x(null)},onKeyDown:D=>{D.key==="Enter"&&(D.preventDefault(),R())}}),l.jsx(Pp,{checked:p,onChange:g,label:"Favorite",hint:"Pin to the phone's favorites"}),v&&l.jsx("div",{className:"form__error",children:v}),l.jsxs("div",{className:"form__note",children:[l.jsx(Ms,{size:14})," Contacts are stored on your neural line and follow you across sessions."]})]})})}const Sw=[{id:"aurora",label:"Holocall",hint:"The implant's own ring"},{id:"link",label:"Rockerboy",hint:"Kerry's private line"},{id:"pulse",label:"Landline",hint:"An old corded phone"},{id:"silent",label:"Silent",hint:"Vibration only"}],Mw=[{id:"cyberpunk",label:"Night City",hint:"Navy glass, cut corners, red selection"},{id:"sao",label:"Aincrad",hint:"The original holographic glass"}],Ew=[{id:"sao",label:"Aincrad",hint:"White glass, gold selection"},{id:"cyan",label:"Netrunner",hint:"Ice cyan, magenta edges"},{id:"magenta",label:"Kabuki",hint:"Neon magenta, cyan edges"}];function ww({section:n,canBack:e}){const t=s=>he.getState().replaceTop({app:"settings",section:s});return l.jsxs(ln,{icon:l.jsx(wp,{size:22}),title:"Settings",subtitle:"Neural-Link preferences",tag:"NL//05-CFG",canBack:e,bodyClass:"settings",children:[l.jsx(Iu,{value:n,onChange:t,options:[{id:"sound",label:"Sound",icon:l.jsx(Nv,{size:15})},{id:"display",label:"Hologram",icon:l.jsx(Tv,{size:15})},{id:"about",label:"System",icon:l.jsx(xp,{size:15})}]}),l.jsxs("div",{className:"settings__pane nl-scroll",children:[n==="sound"&&l.jsx(Tw,{}),n==="display"&&l.jsx(bw,{}),n==="about"&&l.jsx(Cw,{})]},n)]})}function Tw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Ringtone"}),l.jsx("div",{className:"rings",children:Sw.map((e,t)=>l.jsxs("div",{className:`ring-opt ${n.ringtone===e.id?"is-on":""}`,style:{"--i":t},children:[l.jsxs("button",{type:"button",className:"ring-opt__main",onClick:()=>{Me("select"),Gr({ringtone:e.id},0)},children:[l.jsx("span",{className:"ring-opt__radio"}),l.jsxs("span",{className:"ring-opt__text",children:[l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{children:e.hint})]})]}),e.id!=="silent"&&l.jsx("button",{type:"button",className:"ring-opt__play","aria-label":`Preview ${e.label}`,onClick:()=>$y(`preview:${e.id}`),children:l.jsx(mM,{size:16})})]},e.id))}),l.jsx(En,{children:"Levels"}),l.jsx(Bv,{label:"Volume",value:n.volume,onInput:e=>Gr({volume:e}),onCommit:()=>Me("select")}),l.jsx(Pp,{checked:n.dnd,onChange:e=>Gr({dnd:e},0),label:"Do not disturb",hint:"No ringtone, silent notifications"}),n.dnd&&l.jsxs("div",{className:"form__note",children:[l.jsx(vS,{size:14})," Calls still reach you; the ringtone and notification sounds are muted."]})]})}function bw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Interface"}),l.jsx("div",{className:"accents",children:Mw.map(e=>l.jsxs("button",{type:"button",className:`accent accent--style-${e.id} ${n.style===e.id?"is-on":""}`,onClick:()=>{Me("select"),Gr({style:e.id},0)},children:[l.jsxs("span",{className:"accent__swatch",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{className:"accent__hint",children:e.hint})]},e.id))}),n.style==="sao"&&l.jsx(Aw,{}),l.jsx(En,{children:"Hologram"}),l.jsx(Bv,{label:"Intensity",min:.3,max:1,value:n.intensity,onInput:e=>Gr({intensity:e}),display:`${Math.round(n.intensity*100)}%`}),l.jsx("div",{className:"form__note",children:"Glow, scanlines and ambient particles follow this level."})]})}function Aw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Theme"}),l.jsx(Pp,{checked:n.theme==="dark",onChange:e=>Gr({theme:e?"dark":"light"},0),label:"Dark mode",hint:"Smoked black glass, light text"}),l.jsx(En,{children:"Accent"}),l.jsx("div",{className:"accents",children:Ew.map(e=>l.jsxs("button",{type:"button",className:`accent accent--${e.id} ${n.accent===e.id?"is-on":""}`,onClick:()=>{Me("select"),Gr({accent:e.id},0)},children:[l.jsxs("span",{className:"accent__swatch",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{className:"accent__hint",children:e.hint})]},e.id))})]})}function Cw(){const n=he(s=>s.state?.line??null),e=he(s=>s.state?.apps.length??0),t=[["System","Neural-Link OS 2.7.7"],["Firmware","Kiroshi Optics / NL-77 bridge"],["Line",n?`${n.number} · ${n.name}`:"Not assigned"],["Third-party apps",String(e)],["Encryption","Quantum-sealed, end-to-end"],["Manufacturer","Zetatech for Open//77"]];return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"System"}),l.jsx("dl",{className:"about",children:t.map(([s,a])=>l.jsxs("div",{children:[l.jsx("dt",{className:"label",children:s}),l.jsx("dd",{className:"mono",children:a})]},s))}),l.jsx("div",{className:"form__note",children:"Press Esc to go back a level. Close the link from the bottom of the column."})]})}const Nw=/([#@][A-Za-z0-9_]+)/g,Rw=["Spam","Harassment","Doxxing","Impersonation"];function Mi(n){return n<1e3?String(Math.max(0,n)):n<1e4?`${(n/1e3).toFixed(1).replace(/\.0$/,"")}k`:`${Math.round(n/1e3)}k`}const Wr=n=>e=>{e.stopPropagation(),n()};function kp({text:n,className:e}){const t=n.split(Nw);return l.jsx("span",{className:e,children:t.map((s,a)=>{if(a%2===0)return s;const c=s.slice(1).toLowerCase();return s[0]==="#"?l.jsx("button",{type:"button",className:"stoken stoken--tag",onClick:Wr(()=>Ov(c)),children:s},a):av.test(c)?l.jsx("button",{type:"button",className:"stoken stoken--handle",onClick:Wr(()=>rr(c)),children:s},a):s})})}function Vv({district:n}){return n?l.jsxs("span",{className:"sdistrict mono",children:[l.jsx(ll,{size:11,strokeWidth:2.4}),n]}):null}function Pw({a:n,big:e}){return l.jsxs(l.Fragment,{children:[l.jsx("button",{type:"button",className:"scream__name",onClick:Wr(()=>rr(n.handle)),children:n.name}),l.jsxs("span",{className:`scream__handle mono ${e?"is-big":""}`,children:["@",n.handle]})]})}function Ba({post:n,index:e=0,variant:t="feed",kbd:s,rail:a}){const c=he(f=>!!f.postGone[n.id]),u=he(f=>n.echoOf?!!f.postGone[n.echoOf.id]:!1),d=!n.body&&(!!n.echoOf||!!n.echoGone);return c?null:d?!n.echoOf||u?null:l.jsx(t_,{post:n.echoOf,echoedBy:n.author,index:e,variant:t,kbd:s,rail:a}):l.jsx(t_,{post:n,index:e,variant:t,kbd:s,rail:a})}function t_({post:n,echoedBy:e,index:t,variant:s,kbd:a,rail:c}){const u=zy(n),d=he(g=>g.state?.social?.handle),f=he(g=>n.echoOf?!!g.postGone[n.echoOf.id]:!1),p=s==="focus";return l.jsxs("article",{className:`scream scream--${s} ${a?"is-kbd":""} ${c?"has-rail":""}`,style:{"--i":Math.min(t,14)},onClick:p?void 0:()=>ul(u.id),children:[e&&l.jsxs("div",{className:"scream__echoed label",children:[l.jsx(Ep,{size:14,strokeWidth:2.4}),e.handle===d?"You echoed":l.jsxs(l.Fragment,{children:[l.jsxs("button",{type:"button",onClick:Wr(()=>rr(e.handle)),children:["@",e.handle]})," echoed"]})]}),l.jsxs("div",{className:"scream__grid",children:[l.jsxs("div",{className:"scream__side",children:[l.jsx("button",{type:"button",className:"scream__av",onClick:Wr(()=>rr(u.author.handle)),"aria-label":`@${u.author.handle}`,children:l.jsx(Ht,{name:u.author.name,seed:u.author.seed,size:p?56:46,online:u.author.online})}),c&&l.jsx("span",{className:"scream__rail","aria-hidden":!0})]}),l.jsxs("div",{className:"scream__main",children:[l.jsxs("div",{className:"scream__top",children:[l.jsx("span",{className:"scream__who",children:l.jsx(Pw,{a:u.author,big:p})}),!p&&l.jsx("span",{className:"scream__time",title:`${pf(u.at)} ${Wa(u.at)}`,children:Tu(u.at)}),l.jsx(Vv,{district:u.district})]}),u.replyTo&&l.jsxs("div",{className:"scream__replying",children:["Replying to ",l.jsxs("button",{type:"button",className:"stoken stoken--handle",onClick:Wr(()=>rr(u.replyTo.handle)),children:["@",u.replyTo.handle]})]}),u.body&&l.jsx(kp,{text:u.body,className:"scream__body"}),u.echoOf&&!f?l.jsx(Gv,{post:u.echoOf}):(u.echoGone||f)&&l.jsx("div",{className:"sembed sembed--gone",children:"This scream was deleted."}),p&&l.jsxs("div",{className:"scream__meta",children:[l.jsxs("span",{className:"mono",children:[Wa(u.at)," · ",pf(u.at)]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.cred)})," Street Cred"]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.echoes)})," ",u.echoes===1?"Echo":"Echoes"]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.replies)})," ",u.replies===1?"Reply":"Replies"]})]}),l.jsx(kw,{post:u})]})]})]})}function kw({post:n}){const[e,t]=q.useState(0),[s,a]=q.useState(""),c=q.useRef(null),u=()=>{n.credded||t(f=>f+1),OE(n)},d=()=>{if(s){a("");return}const f=c.current,p=f?.closest(".nl-scroll")?.getBoundingClientRect(),g=f?.getBoundingClientRect(),v=Number(getComputedStyle(document.documentElement).getPropertyValue("--stage-scale"))||1;a(p&&g&&p.bottom-g.bottom<190*v?"up":"down"),Me("select")};return l.jsxs("div",{className:"sacts",onClick:f=>f.stopPropagation(),children:[l.jsxs("button",{type:"button",className:"sact sact--reply",onClick:()=>jv(n,"reply"),"aria-label":"Reply",children:[l.jsx("span",{className:"sact__icon",children:l.jsx(Nu,{size:17,strokeWidth:2.2})}),l.jsx("span",{className:"sact__count mono",children:n.replies?Mi(n.replies):""})]}),l.jsxs("button",{type:"button",className:`sact sact--echo ${n.echoed?"is-on":""}`,onClick:()=>void jE(n),"aria-pressed":n.echoed,"aria-label":"Echo",children:[l.jsx("span",{className:"sact__icon",children:l.jsx(Ep,{size:18,strokeWidth:2.2})}),l.jsx("span",{className:"sact__count mono",children:n.echoes?Mi(n.echoes):""})]}),l.jsxs("button",{type:"button",className:`sact sact--cred ${n.credded?"is-on":""}`,onClick:u,"aria-pressed":n.credded,"aria-label":"Street Cred",children:[l.jsxs("span",{className:"sact__icon",children:[l.jsx(Ap,{size:17,strokeWidth:2.2}),e>0&&l.jsx(Lw,{},e)]}),l.jsx("span",{className:"sact__label label",children:"Cred"}),l.jsx("span",{className:"sact__count mono",children:Mi(n.cred)})]}),l.jsxs("div",{className:"sact-more",ref:c,children:[l.jsx("button",{type:"button",className:`sact sact--more ${s?"is-on":""}`,onClick:d,"aria-label":"More",children:l.jsx("span",{className:"sact__icon",children:l.jsx(m2,{size:18,strokeWidth:2.4})})}),s&&l.jsx(Dw,{post:n,up:s==="up",onClose:()=>a(""),anchor:c})]})]})}function Lw(){return l.jsxs("span",{className:"credburst","aria-hidden":!0,children:[l.jsx("span",{className:"credburst__flash"}),l.jsx("span",{className:"credburst__ring"}),l.jsx("span",{className:"credburst__ring credburst__ring--2"}),Array.from({length:10},(n,e)=>l.jsx("i",{style:{"--a":`${e*36+e%2*14}deg`,"--d":`${24+e%3*7}px`}},e)),l.jsx("span",{className:"credburst__text",children:"+CRED"})]})}function Dw({post:n,up:e,onClose:t,anchor:s}){const[a,c]=q.useState("");return q.useEffect(()=>{const u=d=>{s.current?.contains(d.target)||t()};return document.addEventListener("pointerdown",u),()=>document.removeEventListener("pointerdown",u)},[s,t]),l.jsxs("div",{className:`smenu ${e?"is-up":""}`,role:"menu",children:[a===""&&l.jsxs(l.Fragment,{children:[l.jsxs("button",{type:"button",className:"smenu__item",onClick:()=>{t(),jv(n,"quote")},children:[l.jsx(Mp,{size:16})," Quote"]}),n.mine&&l.jsxs("button",{type:"button",className:"smenu__item is-danger",onClick:()=>{Me("select"),c("delete")},children:[l.jsx(hu,{size:16})," Delete"]}),!n.mine&&l.jsxs("button",{type:"button",className:"smenu__item",onClick:()=>{Me("select"),c("report")},children:[l.jsx(x2,{size:16})," Report"]})]}),a==="delete"&&l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"smenu__head label",children:"Delete this scream?"}),l.jsxs("button",{type:"button",className:"smenu__item is-danger",onClick:()=>{t(),BE(n.id)},children:[l.jsx(hu,{size:16})," Delete for good"]}),l.jsx("button",{type:"button",className:"smenu__item",onClick:()=>{Me("back"),c("")},children:"Keep it"})]}),a==="report"&&l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"smenu__head label",children:"Report for"}),Rw.map(u=>l.jsx("button",{type:"button",className:"smenu__item",onClick:()=>{t(),HE(n.id,u.toLowerCase())},children:u},u))]})]})}function Gv({post:n,static:e}){return l.jsxs("div",{className:`sembed ${e?"is-static":""}`,onClick:e?void 0:Wr(()=>ul(n.id)),children:[l.jsxs("div",{className:"sembed__top",children:[l.jsx(Ht,{name:n.author.name,seed:n.author.seed,size:24}),l.jsx("span",{className:"sembed__name",children:n.author.name}),l.jsxs("span",{className:"sembed__handle mono",children:["@",n.author.handle]}),l.jsx("span",{className:"sembed__time",children:Tu(n.at)}),l.jsx(Vv,{district:n.district})]}),n.body?l.jsx(kp,{text:n.body,className:"sembed__body"}):l.jsxs("span",{className:"sembed__body is-echo",children:["Echo of @",n.echoOf?.author.handle??"deleted"]})]})}const Iw=n=>!n.body&&n.echoOf?n.echoOf.id:n.id,Wv=q.forwardRef(function({posts:e,hasMore:t,loadingMore:s,onMore:a,head:c,empty:u,className:d},f){const[p,g]=q.useState(-1);dr(q.useMemo(()=>Kr(e.length,p,g,x=>{const y=e[x];y&&ul(Iw(y))}),[e,p]));const v=x=>{const y=x.currentTarget;t&&!s&&y.scrollHeight-y.scrollTop-y.clientHeight<260&&a()};return l.jsxs("div",{className:["screams nl-scroll",d].filter(Boolean).join(" "),ref:f,onScroll:v,children:[c,e.length===0&&!t?u:e.map((x,y)=>l.jsx(Ba,{post:x,index:y,kbd:p===y},x.id)),s?l.jsx(Ei,{text:"Pulling older screams"}):t?l.jsx("button",{type:"button",className:"screams__more label",onClick:a,children:"Load more"}):e.length>0?l.jsx("div",{className:"screams__end mono",children:"// end of the sheet"}):null]})}),Uw={pulse:{sub:"Pulse · every citizen, live",empty:["The sheet is blank","Nobody has screamed yet. Be the first."]},crew:{sub:"Crew · people you follow",empty:["Your crew is quiet","Follow citizens from their profile to fill this feed."]},hot:{sub:"Hot · best of the last 24 h",empty:["Nothing is burning","Give Street Cred to the screams that matter."]}};function n_({mode:n,tag:e,canBack:t}){const s=e!=null?FE(e):n??"pulse",a=he(w=>w.feeds[s]),c=he(w=>s==="pulse"?w.freshPosts:kn),u=q.useRef(null),[d,f]=q.useState(!1);q.useEffect(()=>{be().feeds[s]||el(s)},[s]);const p=async()=>{Me("select"),f(!0),s==="pulse"&&be().takeFresh(),await el(s),f(!1),u.current?.scrollTo({top:0,behavior:"smooth"})},g=()=>{const w=be();w.prependPosts("pulse",w.takeFresh()),Me("select"),u.current?.scrollTo({top:0,behavior:"smooth"})},v=w=>be().replaceTop({app:"social",screen:"feed",mode:w}),x=e==null?Uw[n??"pulse"]:null,y=a?.posts.length??0;return l.jsxs(ln,{icon:e!=null?l.jsx(rl,{size:22}):l.jsx($r,{size:22}),title:e!=null?`#${e}`:"Screamsheet",subtitle:x?x.sub:`${y}${a?.hasMore?"+":""} screams on this tag`,tag:e!=null?"NL//06-TAG":"NL//06-SCR",canBack:t,bodyClass:"sfeed",actions:l.jsxs(l.Fragment,{children:[l.jsx(Zt,{label:"Search",onClick:()=>Mn({app:"social",screen:"heat",search:!0}),children:l.jsx(cr,{size:18})}),l.jsx(Zt,{label:"Refresh",className:d?"is-spinning":"",onClick:()=>void p(),children:l.jsx(Av,{size:18})}),l.jsx(Zt,{label:"Compose",tone:"sel",onClick:()=>Mn({app:"social",screen:"compose"}),children:l.jsx(al,{size:18})})]}),children:[e==null&&l.jsx(Iu,{value:n??"pulse",onChange:v,options:[{id:"pulse",label:"Pulse",icon:l.jsx(ku,{size:16}),badge:c.length||void 0},{id:"crew",label:"Crew",icon:l.jsx(Ln,{size:16})},{id:"hot",label:"Hot",icon:l.jsx(Cu,{size:16})}]}),l.jsxs("div",{className:"sfeed__pane",children:[c.length>0&&l.jsxs("button",{type:"button",className:"sfresh",onClick:g,children:[l.jsx(fS,{size:16,strokeWidth:2.6}),l.jsx("span",{className:"sfresh__avs",children:c.slice(0,3).map(w=>l.jsx(Ht,{name:w.author.name,seed:w.author.seed,size:24},w.id))}),l.jsxs("span",{className:"label",children:[c.length," new scream",c.length>1?"s":""]})]}),!a||a.loading?l.jsx(Ei,{text:"Tuning in"}):l.jsx(Wv,{ref:u,posts:a.posts,hasMore:a.hasMore,loadingMore:a.loadingMore,onMore:()=>void el(s,!0),empty:x?l.jsx(Kn,{icon:l.jsx($r,{size:30}),title:x.empty[0],body:x.empty[1],action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(al,{size:16}),onClick:()=>Mn({app:"social",screen:"compose"}),children:"Scream"})}):l.jsx(Kn,{icon:l.jsx(rl,{size:30}),title:"No screams",body:`Nothing tagged #${e} yet.`})})]},s)]})}const i_=260;function Fw({len:n}){const t=2*Math.PI*13,s=Math.min(1,n/Or),a=n>Or?"is-over":n>=i_?"is-warn":"";return l.jsxs("span",{className:`cring ${a}`,title:`${n}/${Or}`,children:[l.jsxs("svg",{viewBox:"0 0 34 34","aria-hidden":!0,children:[l.jsx("circle",{className:"cring__track",cx:"17",cy:"17",r:13}),l.jsx("circle",{className:"cring__fill",cx:"17",cy:"17",r:13,style:{strokeDasharray:t,strokeDashoffset:t*(1-s)}})]}),n>=i_&&l.jsx("span",{className:"cring__left mono",children:Or-n})]})}function $v({replyTo:n,quoteOf:e,autoFocus:t,compact:s,onSent:a}){const c=he(M=>M.clock?.district),u=he(M=>M.state?.line?.name??"Me"),d=he(M=>{const L=M.state?.social?.handle;return L&&M.profiles[L]?.seed||M.state?.line?.number||L||"me"}),[f,p]=q.useState(""),[g,v]=q.useState(!1),x=q.useRef(null),y=f.length,w=f.trim().length>0&&y<=Or&&!g,E=q.useCallback(()=>{const M=x.current;M&&(M.style.height="auto",M.style.height=`${Math.min(s?120:220,Math.max(s?44:120,M.scrollHeight))}px`)},[s]);q.useLayoutEffect(E,[f,E]),q.useEffect(()=>{t&&x.current?.focus()},[t]);const _=async()=>{if(!w)return;v(!0);const M=await zE(f.trim(),{replyTo:n,quoteOf:e});v(!1),M&&(p(""),a?.(M))};return l.jsxs("div",{className:`scomp ${s?"scomp--compact":""}`,children:[l.jsxs("div",{className:"scomp__row",children:[l.jsx(Ht,{name:u,seed:d,size:s?38:46}),l.jsx("div",{className:"scomp__box",children:l.jsx("textarea",{ref:x,className:"scomp__input",rows:s?1:4,value:f,placeholder:n!=null?"Scream your reply…":e!=null?"Add your take…":"What's happening in Night City?",spellCheck:!1,onChange:M=>p(M.target.value.slice(0,Or+120)),onKeyDown:M=>{M.key==="Enter"&&(M.ctrlKey||M.metaKey)&&!M.nativeEvent.isComposing&&(M.preventDefault(),_())}})})]}),l.jsxs("div",{className:"scomp__bar",children:[l.jsxs("span",{className:`scomp__from ${c?"":"is-unknown"}`,children:[l.jsx(ll,{size:14,strokeWidth:2.4}),c?l.jsxs(l.Fragment,{children:["Screaming from ",l.jsx("b",{children:c})]}):"Location unknown"]}),l.jsx("span",{className:"scomp__hint mono",children:"ctrl+enter"}),l.jsx(Fw,{len:y}),l.jsx(Ot,{tone:"sel",small:s,icon:l.jsx($r,{size:16}),disabled:!w,onClick:()=>void _(),children:g?"Sending…":n!=null?"Reply":"Scream"})]})]})}function Ow(n){const e=he(a=>n!=null?a.composeCtx[n]??a.screamThreads[n]?.post??null:null),[t,s]=q.useState(!1);if(q.useEffect(()=>{n==null||be().composeCtx[n]||be().screamThreads[n]?.post||Tt("social.thread",{postId:n},{quiet:!0}).then(a=>{a?.post?be().rememberPost(a.post):s(!0)})},[n]),n!=null)return e??(t?null:void 0)}function jw({replyTo:n,quoteOf:e,canBack:t}){const s=n??e,a=Ow(s),c=n!=null?"reply":e!=null?"quote":"new",u=()=>{const d=be();d.stack.length>1?d.back():d.resetView({app:"social",screen:"feed",mode:"pulse"})};return l.jsxs(ln,{icon:c==="reply"?l.jsx(Nu,{size:22}):c==="quote"?l.jsx(Mp,{size:22}):l.jsx(al,{size:22}),title:c==="reply"?"Reply":c==="quote"?"Quote":"Compose",subtitle:a?`${c==="reply"?"Replying to":"Quoting"} @${a.author.handle}`:`Up to ${Or} characters, #tags and @handles`,tag:"NL//06-NEW",canBack:t,bodyClass:"scompose",children:[s!=null&&l.jsxs("div",{className:"scompose__ctx",children:[l.jsx("span",{className:"scompose__ctxlabel label",children:c==="reply"?"Replying to":"Quoting"}),a?l.jsx(Gv,{post:a,static:!0}):a===null?l.jsx("div",{className:"sembed sembed--gone",children:"This scream was deleted."}):l.jsx(Ei,{text:"Fetching scream"})]}),l.jsx($v,{replyTo:n,quoteOf:e,autoFocus:!0,onSent:u})]})}function zw({postId:n,canBack:e}){const t=he(g=>g.screamThreads[n]),s=he(g=>!!g.postGone[n]),a=he(g=>g.postLive[n]?.replies??g.screamThreads[n]?.post?.replies??0),c=q.useRef(null),u=q.useRef(null),d=q.useRef(!1);q.useEffect(()=>{zv(n)},[n]),q.useLayoutEffect(()=>{d.current||!t?.post||!c.current||!u.current||(d.current=!0,t.parents.length&&(c.current.scrollTop=Math.max(0,u.current.offsetTop-70)))},[t?.post,t?.parents.length]);const f=t?.post,p=()=>requestAnimationFrame(()=>c.current?.scrollTo({top:c.current.scrollHeight,behavior:"smooth"}));return l.jsx(ln,{icon:l.jsx(ku,{size:22}),title:"Scream",subtitle:f?`@${f.author.handle} · ${Mi(a)} ${a===1?"reply":"replies"}`:"Screamsheet",tag:`SCR-${String(n).padStart(5,"0")}`,canBack:e,bodyClass:"sthread",children:s||t?.missing?l.jsx(Kn,{icon:l.jsx(Tp,{size:30}),title:"Scream gone",body:"It was deleted, or it never hit the sheet."}):f?l.jsxs("div",{className:"sthread__scroll nl-scroll",ref:c,children:[t.parents.length>0&&l.jsx("div",{className:"sthread__parents",children:t.parents.map((g,v)=>l.jsx(Ba,{post:g,index:v,variant:"parent",rail:!0},g.id))}),l.jsx("div",{ref:u,className:"sthread__focus",children:l.jsx(Ba,{post:f,variant:"focus"})}),l.jsx("div",{className:"sthread__reply",children:l.jsx($v,{replyTo:f.id,compact:!0,onSent:p})}),l.jsxs(En,{children:["Replies · ",t.replies.length]}),t.replies.length===0?l.jsxs("div",{className:"sthread__none",children:[l.jsx(Nu,{size:18})," No replies yet. Start the noise."]}):t.replies.map((g,v)=>l.jsx(Ba,{post:g,index:v,variant:"reply"},g.id))]}):l.jsx(Ei,{text:"Tracing the thread"})})}const Bw=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Hw(n){const e=eu(n),t=eu(`${n}:cover`),s=Array.from({length:26},(a,c)=>1+((t>>c%12)+c*7)%4);return{style:{"--h1":e,"--h2":(e+55+t%50)%360,"--h3":(e+180+t%70)%360,"--ang":`${t%140+20}deg`,"--gx":`${15+t%70}%`},bars:s,id:`NC-${(eu(`${n}:id`)*7919).toString(16).toUpperCase().padStart(6,"0").slice(-6)}`}}function Xv({seed:n,handle:e}){const t=q.useMemo(()=>Hw(n),[n]);return l.jsxs("div",{className:"pcover",style:t.style,"aria-hidden":!0,children:[l.jsx("span",{className:"pcover__grid"}),l.jsx("span",{className:"pcover__scan"}),l.jsx("span",{className:"pcover__sweep"}),l.jsxs("span",{className:"pcover__id mono",children:[t.id," // @",e]}),l.jsx("span",{className:"pcover__bars",children:t.bars.map((s,a)=>l.jsx("i",{style:{width:s*2}},a))})]})}function Vw({p:n}){const e=new Date(n.joinedAt);return l.jsxs("div",{className:"phead",children:[l.jsx(Xv,{seed:n.seed,handle:n.handle}),l.jsxs("div",{className:"phead__bar",children:[l.jsx("span",{className:"phead__av",children:l.jsx(Ht,{name:n.name,seed:n.seed,size:104,ring:"sel",online:n.online})}),l.jsx("span",{className:"phead__acts",children:n.isMe?l.jsx(Ot,{tone:"ghost",icon:l.jsx(bp,{size:16}),onClick:()=>Mn({app:"social",screen:"edit"}),children:"Edit profile"}):n.followed?l.jsxs(Ot,{className:"phead__unfollow",icon:l.jsx(rE,{size:16}),onClick:()=>void qg(n.handle,!1),children:[l.jsx("span",{className:"is-idle",children:"Following"}),l.jsx("span",{className:"is-hover",children:"Unfollow"})]}):l.jsx(Ot,{tone:"sel",icon:l.jsx(Qi,{size:16}),onClick:()=>void qg(n.handle,!0),children:"Follow"})})]}),l.jsxs("div",{className:"phead__id",children:[l.jsx("div",{className:"phead__name",children:n.name}),l.jsxs("div",{className:"phead__handle",children:[l.jsxs("span",{className:"mono",children:["@",n.handle]}),n.followsMe&&!n.isMe&&l.jsx("span",{className:"phead__chip label",children:"Follows you"}),n.isMe&&l.jsx("span",{className:"phead__chip is-me label",children:"You"})]}),n.bio?l.jsx(kp,{text:n.bio,className:"phead__bio"}):l.jsx("div",{className:"phead__bio is-empty",children:n.isMe?"No bio yet. Tell the city who you are.":"No bio."}),l.jsxs("div",{className:"phead__joined",children:[l.jsx(RS,{size:14})," Joined ",Bw[e.getMonth()]," ",e.getFullYear()]})]}),l.jsxs("div",{className:"pstats",children:[l.jsx(Ac,{value:n.posts,label:"Screams"}),l.jsx(Ac,{value:n.followers,label:"Followers"}),l.jsx(Ac,{value:n.following,label:"Following"}),l.jsx(Ac,{value:n.cred,label:"Street Cred",hot:!0})]})]})}function Ac({value:n,label:e,hot:t}){return l.jsxs("div",{className:`pstat ${t?"is-hot":""}`,children:[l.jsx("span",{className:"pstat__val mono",children:Mi(n)}),l.jsx("span",{className:"pstat__label label",children:e})]})}function Gw({handle:n,canBack:e}){const t=he(d=>d.state?.social?.handle??""),s=n||t,a=he(d=>s?d.profiles[s]:void 0),c=he(d=>s?d.feeds[Cp(s)]:void 0);q.useEffect(()=>{s&&$g(s)},[s]);const u=!a&&c&&!c.loading;return l.jsx(ln,{icon:l.jsx(no,{size:22}),title:a?.name??"Profile",subtitle:s?`@${s}`:"Screamsheet",tag:"NL//06-CIT",canBack:e,bodyClass:"sprofile",actions:a?.isMe?l.jsx(Zt,{label:"Compose",tone:"sel",onClick:()=>Mn({app:"social",screen:"compose"}),children:l.jsx(al,{size:18})}):null,children:!s||u?l.jsx(Kn,{icon:l.jsx(hE,{size:30}),title:"No such citizen",body:s?`Nobody answers to @${s}.`:"Your neural profile is not ready yet."}):!a||!c||c.loading?l.jsx(Ei,{text:"Pulling the file"}):l.jsx(Wv,{posts:c.posts,hasMore:c.hasMore,loadingMore:c.loadingMore,onMore:()=>void $g(s,!0),head:l.jsx(Vw,{p:a}),empty:l.jsxs("div",{className:"sprofile__none",children:[l.jsx($r,{size:18})," ",a.isMe?"You have not screamed yet.":"Silent so far."]})})})}function Ww({canBack:n}){const e=he(D=>D.state?.social?.handle??""),t=he(D=>e?D.profiles[e]:void 0),[s,a]=q.useState(t?.handle??e),[c,u]=q.useState(t?.name??""),[d,f]=q.useState(t?.bio??""),[p,g]=q.useState(!!t),[v,x]=q.useState(null),[y,w]=q.useState(null),[E,_]=q.useState(!1);q.useEffect(()=>{p||Tt("social.me",{}).then(D=>{D&&(be().setProfile(D.profile),be().setSocialUnread(D.unread),a(D.profile.handle),u(D.profile.name),f(D.profile.bio),g(!0))})},[p]);const M=av.test(s),L=c.trim().length>=1&&c.trim().length<=Ag,A=d.length<=Vo,R=async()=>{if(!t)return;if(!M){x(On("invalid_handle")),Me("error");return}if(!L){w(On("invalid_name")),Me("error");return}if(!A)return;const D={};if(s!==t.handle&&(D.handle=s),c.trim()!==t.name&&(D.name=c.trim()),d.trim()!==t.bio&&(D.bio=d.trim()),Object.keys(D).length===0){Me("back"),be().back();return}_(!0),w(null),x(null);try{const U=await Hr("social.update",D),$=be();$.setSocialHandle(U.profile.handle),$.setProfile(U.profile),Me("select"),be().back()||be().resetView(null)}catch(U){Me("error");const $=U instanceof Sn?U.slug:"unknown";$==="handle_taken"||$==="invalid_handle"?x(On($)):w(On($)),_(!1)}},k=D=>{D.key==="Enter"&&(D.preventDefault(),R())};return l.jsx(ln,{icon:l.jsx(bp,{size:22}),title:"Edit profile",subtitle:`@${s||e}`,tag:"NL//06-EDT",canBack:n,bodyClass:"sedit",footer:l.jsxs("div",{className:"form__bar",children:[l.jsx("span",{className:"form__hint",children:"Your handle is how the city tags you."}),l.jsx(Ot,{tone:"sel",icon:l.jsx(Cv,{size:17}),onClick:()=>void R(),disabled:E||!p,children:E?"Saving…":"Save"})]}),children:!p||!t?l.jsx(Ei,{text:"Pulling your file"}):l.jsxs("div",{className:"form sedit__form nl-scroll",children:[l.jsxs("div",{className:"sedit__preview",children:[l.jsx(Xv,{seed:t.seed,handle:s||t.handle}),l.jsx("span",{className:"sedit__av",children:l.jsx(Ht,{name:c||"?",seed:t.seed,size:76,ring:"sel"})})]}),l.jsx(zi,{label:"Handle",icon:l.jsx(Sv,{size:16}),placeholder:"judy_a",value:s,maxLength:16,counter:!0,error:v??(s.length>0&&!M?On("invalid_handle"):null),onChange:D=>{a(D.target.value.toLowerCase().replace(/[^a-z0-9_]/g,"")),x(null)},onKeyDown:k}),l.jsx(zi,{label:"Display name",icon:l.jsx(no,{size:16}),placeholder:"Judy Alvarez",value:c,maxLength:Ag,counter:!0,onChange:D=>{u(D.target.value),w(null)},onKeyDown:k}),l.jsxs("label",{className:"field sedit__bio",children:[l.jsx("span",{className:"field__label label",children:"Bio"}),l.jsx(QE,{value:d,maxLength:Vo,rows:3,placeholder:"Braindance editor. Lizzie's regular. Don't ask about the Mox.",onChange:D=>f(D.target.value)}),l.jsxs("span",{className:`sedit__count mono ${d.length>=Vo?"is-max":d.length>Vo-20?"is-warn":""}`,children:[d.length,"/",Vo]})]}),y&&l.jsx("div",{className:"form__error",children:y})]})})}const s_={cred:{icon:l.jsx(Ap,{size:15,strokeWidth:2.4}),text:"gave you Street Cred"},echo:{icon:l.jsx(Ep,{size:16,strokeWidth:2.4}),text:"echoed your scream"},quote:{icon:l.jsx(Mp,{size:14,strokeWidth:2.4}),text:"quoted your scream"},reply:{icon:l.jsx(Nu,{size:15,strokeWidth:2.4}),text:"replied to you"},mention:{icon:l.jsx(Sv,{size:15,strokeWidth:2.4}),text:"mentioned you"},follow:{icon:l.jsx(Qi,{size:15,strokeWidth:2.4}),text:"started following you"}},r_=n=>n.kind==="follow"||!n.post?rr(n.actor.handle):ul(n.post.id);function $w({canBack:n}){const e=he(d=>d.pings),[t,s]=q.useState(-1),a=e?.pings??[];q.useEffect(()=>(xf(),()=>he.getState().pingsSeen()),[]),dr(q.useMemo(()=>Kr(a.length,t,s,d=>{const f=a[d];f&&r_(f)}),[a,t]));const c=d=>{const f=d.currentTarget;f.scrollHeight-f.scrollTop-f.clientHeight<200&&xf(!0)},u=a.filter(d=>!d.read).length;return l.jsx(ln,{icon:l.jsx(_f,{size:22}),title:"Pings",subtitle:u?`${u} new since last time`:"All caught up",tag:"NL//06-PNG",canBack:n,children:!e||e.loading?l.jsx(Ei,{text:"Listening for pings"}):a.length===0?l.jsx(Kn,{icon:l.jsx(_f,{size:30}),title:"No pings",body:"Scream something. The city will answer."}):l.jsxs("div",{className:"list nl-scroll",onScroll:c,children:[a.map((d,f)=>{const p=s_[d.kind]??s_.mention;return l.jsxs("button",{type:"button",className:`pingrow pingrow--${d.kind} ${d.read?"":"is-new"} ${t===f?"is-kbd":""}`,style:{"--i":Math.min(f,14)},onClick:()=>r_(d),children:[l.jsx("span",{className:"pingrow__kind",children:p.icon}),l.jsx(Ht,{name:d.actor.name,seed:d.actor.seed,size:42,online:d.actor.online}),l.jsxs("span",{className:"pingrow__main",children:[l.jsxs("span",{className:"pingrow__line",children:[l.jsx("b",{children:d.actor.name})," ",l.jsxs("span",{className:"mono",children:["@",d.actor.handle]})," ",p.text]}),d.post&&l.jsx("span",{className:"pingrow__post",children:d.post.body||"Echo"})]}),l.jsx("span",{className:"pingrow__time",children:Tu(d.at)})]},d.id)}),e.loadingMore&&l.jsx(Ei,{text:"Older pings"})]})})}function Xw({search:n,canBack:e}){const[t,s]=q.useState(null),[a,c]=q.useState(!1),[u,d]=q.useState(""),[f,p]=q.useState(null),[g,v]=q.useState(!1),x=q.useRef(0),y=async()=>{const E=await Tt("social.heat",{},{quiet:!0});E?s(E):c(!0)};q.useEffect(()=>{y()},[]),q.useEffect(()=>{const E=u.trim(),_=++x.current;if(E.length<2){p(null),v(!1);return}v(!0);const M=window.setTimeout(async()=>{const L=await Tt("social.search",{q:E},{quiet:!0});_===x.current&&(v(!1),p({q:E,profiles:L?.profiles??[],posts:L?.posts??[]}))},320);return()=>window.clearTimeout(M)},[u]);const w=t?.districts.reduce((E,_)=>E+_.count,0)??0;return l.jsxs(ln,{icon:l.jsx(uu,{size:22}),title:"Net Heat",subtitle:t?`${Mi(w)} screams across the city · last 24 h`:"Night City · last 24 h",tag:"NL//06-HEAT",canBack:e,bodyClass:"sheat",actions:l.jsx(Zt,{label:"Refresh",onClick:()=>{Me("select"),y()},children:l.jsx(Av,{size:18})}),children:[l.jsx(zi,{icon:l.jsx(cr,{size:16}),placeholder:"Search citizens, screams, #tags",value:u,autoFocus:n,onChange:E=>d(E.target.value),className:"sheat__search"}),l.jsx("div",{className:"sheat__scroll nl-scroll",children:u.trim().length>=2?g&&!f?l.jsx(Ei,{text:"Scanning the sheet"}):f&&l.jsx(Kw,{res:f}):t?l.jsxs(l.Fragment,{children:[l.jsx(qw,{list:t.districts}),l.jsx(En,{aside:l.jsxs("span",{className:"mono sheat__aside",children:[t.tags.length," tags"]}),children:"Trending"}),l.jsx(Yw,{list:t.tags}),l.jsx(En,{aside:l.jsx(Cu,{size:16,className:"sheat__flame"}),children:"Hot screams"}),t.hot.length===0?l.jsx("div",{className:"sheat__none",children:"Nothing is burning yet."}):t.hot.map((E,_)=>l.jsx(Ba,{post:E,index:_},E.id))]}):a?l.jsx(Kn,{icon:l.jsx(uu,{size:30}),title:"No signal",body:"The Net Heat feed is offline."}):l.jsx(Ei,{text:"Reading the grid"})})]})}function qw({list:n}){const e=Math.max(1,...n.map(t=>t.count));return l.jsxs("section",{className:"hmap",children:[l.jsxs("header",{className:"hmap__head",children:[l.jsxs("span",{className:"hmap__title label",children:[l.jsx(ll,{size:15,strokeWidth:2.4})," District heat"]}),l.jsxs("span",{className:"hmap__legend mono",children:[l.jsx("i",{className:"is-cold"}),"cold",l.jsx("i",{className:"is-hot"}),"burning"]})]}),n.length===0?l.jsx("div",{className:"sheat__none",children:"The grid is silent."}):l.jsx("div",{className:"hmap__rows",children:n.slice(0,12).map((t,s)=>{const a=t.count/e;return l.jsxs("div",{className:`hbar ${a>.75?"is-burning":a>.4?"is-warm":""}`,style:{"--t":a.toFixed(3),"--i":s},children:[l.jsx("span",{className:"hbar__rank mono",children:String(s+1).padStart(2,"0")}),l.jsx("span",{className:"hbar__name label",children:t.district}),l.jsx("span",{className:"hbar__track",children:l.jsx("span",{className:"hbar__fill",children:l.jsx("span",{className:"hbar__ember"})})}),l.jsx("span",{className:"hbar__count mono",children:Mi(t.count)}),a>.75&&l.jsx(Cu,{className:"hbar__flame",size:15,strokeWidth:2.4})]},t.district)})})]})}function Yw({list:n}){if(n.length===0)return l.jsx("div",{className:"sheat__none",children:"No tag is trending."});const e=Math.max(1,...n.map(t=>t.count));return l.jsx("div",{className:"tcloud",children:n.slice(0,18).map((t,s)=>{const a=t.count/e,c=t.tag.replace(/^#/,"");return l.jsxs("button",{type:"button",className:`tcloud__tag ${a>.66?"is-hot":a>.33?"is-warm":""}`,style:{"--k":a.toFixed(3),"--i":s},onClick:()=>Ov(c),children:[l.jsx(rl,{size:14,strokeWidth:2.6}),l.jsx("span",{children:c}),l.jsx("span",{className:"tcloud__n mono",children:Mi(t.count)})]},c)})})}function Kw({res:n}){return n.profiles.length===0&&n.posts.length===0?l.jsx(Kn,{icon:l.jsx(cr,{size:30}),title:"No match",body:`Nothing for "${n.q}".`}):l.jsxs(l.Fragment,{children:[n.profiles.length>0&&l.jsxs(l.Fragment,{children:[l.jsx(En,{aside:l.jsx("span",{className:"mono sheat__aside",children:n.profiles.length}),children:"Citizens"}),l.jsx("div",{className:"sres__people",children:n.profiles.map((e,t)=>l.jsxs("button",{type:"button",className:"prow sres__person",style:{"--i":t},onClick:()=>rr(e.handle),children:[l.jsx(Ht,{name:e.name,seed:e.seed,size:40,online:e.online}),l.jsxs("span",{className:"prow__text",children:[l.jsx("span",{className:"prow__name",children:e.name}),l.jsxs("span",{className:"prow__num mono",children:["@",e.handle," · ",Mi(e.followers)," followers"]})]}),e.followsMe&&l.jsx("span",{className:"phead__chip label",children:"Follows you"}),l.jsx(no,{size:16,className:"sres__go"})]},e.handle))})]}),n.posts.length>0&&l.jsxs(l.Fragment,{children:[l.jsx(En,{aside:l.jsx("span",{className:"mono sheat__aside",children:n.posts.length}),children:"Screams"}),n.posts.map((e,t)=>l.jsx(Ba,{post:e,index:t},e.id))]})]})}function vs(n){return n.participants.filter(e=>!e.isMe)}function qv(n){const e=vs(n);return e.find(t=>t.state==="connected")??e[0]}function Yv(n,e){if(n.group)return n.group.title;const t=vs(n).filter(a=>a.state!=="left"),s=t.length?t:vs(n);return s.length===0?"Call":s.length===1?Fi(e,s[0].number,s[0].name):`${Fi(e,s[0].number,s[0].name)} +${s.length-1}`}function Kv(n){const[e,t]=q.useState(Date.now());return q.useEffect(()=>{if(n==null)return;t(Date.now());const s=window.setInterval(()=>t(Date.now()),1e3);return()=>window.clearInterval(s)},[n]),n==null?null:pp((e-n)/1e3)}const Zw={ringing:"Ringing…",connected:"Linked",left:"Left"};function Qw({call:n}){const e=he(_=>_.state?.contacts??kn),t=he(_=>_.talkers),s=Kv(n.startedAt),[a,c]=q.useState(!1),u=Yv(n,e),d=n.phase==="outgoing",f=n.participants.filter(_=>_.state!=="left"||!_.isMe),p=n.participants.find(_=>_.isMe),g=p?t[p.lineId]??0:0,v=n.participants.filter(_=>_.state!=="left").length,x=d?0:Math.max(0,...Object.values(t)),y=()=>{Me("back"),Tt("call.hangup",{})},w=()=>{Me("select"),Tt("call.mute",{muted:!n.muted})},E=async _=>{await Tt("call.add",{number:_})&&(Me("select"),c(!1))};return l.jsxs(Rp,{className:`callscreen ${d?"is-outgoing":"is-active"}`,tag:`NL//CALL-${String(n.id).padStart(4,"0")}`,children:[l.jsxs("div",{className:"callscreen__bg","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsxs("header",{className:"callscreen__head",children:[l.jsx("span",{className:"callscreen__kind label",children:n.group?l.jsxs(l.Fragment,{children:[l.jsx(Ln,{size:15})," Group call"]}):d?"Outgoing call":"Neural call"}),l.jsx("div",{className:"callscreen__title",children:u}),l.jsx("div",{className:"callscreen__status",children:d||n.startedAt==null?l.jsxs("span",{className:"linking",children:[l.jsx("span",{className:"label",children:"Linking"}),l.jsxs("span",{className:"linking__dots",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})]}):l.jsxs("span",{className:"callscreen__timer mono",children:[l.jsx("span",{className:"rec-dot"}),s]})})]}),d&&vs(n).length===1?l.jsxs("div",{className:"orbit",children:[l.jsx("span",{className:"orbit__path"}),l.jsx("span",{className:"orbit__sat",style:{"--d":"0s"}}),l.jsx("span",{className:"orbit__sat",style:{"--d":"-0.8s"}}),l.jsx("span",{className:"orbit__sat",style:{"--d":"-1.6s"}}),l.jsx(Ht,{name:u,seed:vs(n)[0].number,size:128,ring:"ringing"})]}):l.jsx("div",{className:`parts parts--n${Math.min(6,f.length)}`,children:f.map((_,M)=>{const L=_.state==="connected"&&!(_.isMe&&n.muted)?t[_.lineId]??0:0,A=_.isMe?"You":Fi(e,_.number,_.name);return l.jsxs("div",{className:`part is-${_.state} ${L>.05?"is-talking":""}`,style:{"--i":M},children:[l.jsx(Ht,{name:_.isMe?p?.name??"You":A,seed:_.number,size:92,level:L,ring:_.state==="ringing"?"ringing":"none"}),l.jsx("span",{className:"part__name",children:A}),l.jsx("span",{className:"part__state mono",children:(_.isMe?n.muted:_.muted)&&_.state==="connected"?l.jsxs(l.Fragment,{children:[l.jsx(vf,{size:12})," muted"]}):Zw[_.state]})]},_.lineId)})}),a&&l.jsxs("div",{className:"callscreen__add",children:[l.jsxs("div",{className:"callscreen__addhead",children:[l.jsxs("span",{className:"label",children:["Add to call · ",v,"/",Ly]}),l.jsx("button",{type:"button",className:"icon-btn","aria-label":"Close",onClick:()=>c(!1),children:l.jsx(io,{size:18})})]}),l.jsx(dl,{mode:"single",exclude:n.participants.filter(_=>_.state!=="left").map(_=>_.number),onPick:E,pickLabel:"Invite"})]}),l.jsx("div",{className:`wave ${x>.05?"is-live":""}`,style:{"--level":x.toFixed(2)},"aria-hidden":!0,children:Array.from({length:32},(_,M)=>l.jsx("i",{style:{"--i":M}},M))}),l.jsxs("footer",{className:"callscreen__controls",children:[l.jsxs("button",{type:"button",className:`cbtn ${n.muted?"cbtn--on":""} ${g>.05?"is-talking":""}`,onClick:w,disabled:d,children:[l.jsx("span",{className:"cbtn__disc",children:n.muted?l.jsx(vf,{size:26}):l.jsx(wv,{size:26})}),l.jsx("span",{className:"label",children:n.muted?"Unmute":"Mute"})]}),l.jsxs("button",{type:"button",className:"cbtn cbtn--danger cbtn--big",onClick:y,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Pu,{size:32})}),l.jsx("span",{className:"label",children:d?"Cancel":"Hang up"})]}),l.jsxs("button",{type:"button",className:`cbtn ${a?"cbtn--on":""}`,onClick:()=>{Me("select"),c(_=>!_)},disabled:!n.canAdd,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Qi,{size:26})}),l.jsx("span",{className:"label",children:"Add"})]})]})]})}function Jw({call:n}){const e=he(d=>d.state?.contacts??kn),t=qv(n),s=n.group?n.group.title:t?Fi(e,t.number,t.name):"Unknown",a=n.group?`${t?Fi(e,t.number,t.name):"Someone"} is calling the group · ${vs(n).length} members`:t&&Fi(e,t.number,t.name)!==t.number?t.number:"Unknown number",c=()=>{Me("select"),Tt("call.accept",{})},u=()=>{Me("back"),Tt("call.decline",{})};return l.jsxs(Rp,{className:"incoming incoming--docked",tag:"NL//CALL-IN",children:[l.jsx("div",{className:"incoming__label label",children:n.group?"Incoming group call":"Incoming neural call"}),l.jsxs("div",{className:"incoming__orb",children:[l.jsx("span",{className:"incoming__wave",style:{"--d":"0s"}}),l.jsx("span",{className:"incoming__wave",style:{"--d":"0.6s"}}),l.jsx("span",{className:"incoming__wave",style:{"--d":"1.2s"}}),l.jsx("span",{className:"incoming__dotring","aria-hidden":!0,children:l.jsx("svg",{viewBox:"0 0 100 100",children:l.jsx("circle",{cx:"50",cy:"50",r:"48"})})}),l.jsx(Ht,{name:s,seed:n.group?`g${n.group.threadId}`:t?.number??"?",size:132,group:!!n.group})]}),l.jsx("div",{className:"incoming__name",children:s}),l.jsx("div",{className:"incoming__sub mono",children:a}),n.group&&l.jsxs("div",{className:"incoming__members",children:[vs(n).slice(0,6).map(d=>l.jsx("span",{className:`incoming__m ${d.state==="connected"?"is-on":""}`,title:d.name,children:l.jsx(Ht,{name:Fi(e,d.number,d.name),seed:d.number,size:30})},d.lineId)),vs(n).length>6&&l.jsxs("span",{className:"incoming__more mono",children:["+",vs(n).length-6]}),l.jsx(Ln,{size:14})]}),l.jsxs("div",{className:"incoming__actions",children:[l.jsxs("button",{type:"button",className:"cbtn cbtn--danger",onClick:u,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Pu,{size:30})}),l.jsx("span",{className:"label",children:"Decline"})]}),l.jsxs("button",{type:"button",className:"cbtn cbtn--ok cbtn--throb",onClick:c,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Ji,{size:30})}),l.jsx("span",{className:"label",children:"Accept"})]})]})]})}function eT(){const n=he(d=>d.state?.call??null),e=he(d=>d.state?.contacts??kn),t=he(d=>d.toggleKey),s=he(d=>d.phase!=="closed"&&d.state!==null);if(!n||n.phase!=="incoming"||s)return null;const a=qv(n),c=n.group?n.group.title:a?Fi(e,a.number,a.name):"Unknown",u=!n.group&&!!a&&c!==a.number;return l.jsxs("div",{className:"inpill",children:[l.jsxs("span",{className:"inpill__icon",children:[l.jsx("span",{className:"inpill__wave",style:{"--d":"0s"}}),l.jsx("span",{className:"inpill__wave",style:{"--d":"0.6s"}}),n.group?l.jsx(Ln,{size:17}):l.jsx(Ji,{size:17})]}),l.jsxs("span",{className:"inpill__text",children:[l.jsx("span",{className:"inpill__label label",children:n.group?"Incoming group call":"Incoming call"}),l.jsxs("span",{className:"inpill__name",children:[c,u&&l.jsx("span",{className:"inpill__num mono",children:a.number})]})]}),l.jsxs("span",{className:"inpill__key",children:[l.jsx("kbd",{className:"mono",children:t}),l.jsx("span",{className:"label",children:"answer"})]})]},n.id)}function tT(n){switch(n.app){case"phone":return"phone";case"settings":return"settings";case"messages":return`messages:${n.screen}:${"threadId"in n?n.threadId:""}`;case"contacts":return n.screen==="edit"?`contacts:edit:${n.id??"new"}`:"contacts:list";case"social":switch(n.screen){case"feed":return"social:feed";case"tag":return`social:tag:${n.tag}`;case"thread":return`social:thread:${n.postId}`;case"compose":return`social:compose:${n.replyTo??""}:${n.quoteOf??""}`;case"profile":return`social:profile:${n.handle}`;default:return`social:${n.screen}`}default:return n.app}}function nT(n,e){switch(n.app){case"status":return l.jsx(JE,{canBack:e});case"phone":return l.jsx(tw,{tab:n.tab,canBack:e});case"messages":switch(n.screen){case"list":return l.jsx(lw,{canBack:e});case"thread":return l.jsx(hw,{threadId:n.threadId,canBack:e});case"new":return l.jsx(mw,{canBack:e});case"group-new":return l.jsx(gw,{canBack:e});case"group-info":return l.jsx(_w,{threadId:n.threadId,canBack:e})}return null;case"contacts":return n.screen==="edit"?l.jsx(yw,{id:n.id,number:n.number,canBack:e}):l.jsx(xw,{filter:n.filter,canBack:e});case"settings":return l.jsx(ww,{section:n.section,canBack:e});case"social":switch(n.screen){case"feed":return l.jsx(n_,{mode:n.mode,canBack:e});case"tag":return l.jsx(n_,{tag:n.tag,canBack:e});case"thread":return l.jsx(zw,{postId:n.postId,canBack:e});case"compose":return l.jsx(jw,{replyTo:n.replyTo,quoteOf:n.quoteOf,canBack:e});case"profile":return l.jsx(Gw,{handle:n.handle,canBack:e});case"edit":return l.jsx(Ww,{canBack:e});case"pings":return l.jsx($w,{canBack:e});case"heat":return l.jsx(Xw,{search:!!n.search,canBack:e})}return null}}function iT(){const n=he(c=>c.stack),e=he(c=>c.callView),t=he(c=>c.state?.call??null),s=he(c=>c.navDir);if(t&&e)return l.jsx("div",{className:"tilt tilt--call",children:l.jsx(fu,{cut:22,depth:7,tone:"ok",className:"nl3d--fill",children:l.jsx("div",{className:"win-enter nl-hit",children:t.phase==="incoming"?l.jsx(Jw,{call:t}):l.jsx(Qw,{call:t})})})},`call-${t.id}-${t.phase==="incoming"?"in":"on"}`);const a=n[n.length-1];return a?l.jsx("div",{className:"tilt tilt--window",children:l.jsx(fu,{cut:22,depth:8,className:"nl3d--fill",children:l.jsx("div",{className:`win-enter win-enter--${s} nl-hit`,children:nT(a,n.length>1)},tT(a))})}):null}const sT=["Cortex handshake","Bio-signature","Line allocation","Network registry"];function rT(){return l.jsxs("div",{className:"sync nl-hit",role:"status","aria-live":"polite",children:[l.jsxs("div",{className:"sync__orb","aria-hidden":!0,children:[l.jsx("span",{className:"sync__ring sync__ring--a"}),l.jsx("span",{className:"sync__ring sync__ring--b"}),l.jsx("span",{className:"sync__ring sync__ring--c"}),l.jsx("span",{className:"sync__core"})]}),l.jsx("div",{className:"sync__title label",children:"Synchronising neural link…"}),l.jsx("div",{className:"sync__bar","aria-hidden":!0,children:l.jsx("span",{})}),l.jsx("ul",{className:"sync__steps mono",children:sT.map((n,e)=>l.jsxs("li",{style:{"--i":e},children:[l.jsx("span",{className:"sync__dot"}),n]},n))}),l.jsxs("button",{type:"button",className:"btn btn--ghost btn--sm sync__close",onClick:Vr,children:[l.jsx(io,{size:16})," ",l.jsx("span",{children:"Close"})]})]})}/**
 * @license
 * Copyright 2010-2024 Three.js Authors
 * SPDX-License-Identifier: MIT
 */const Lp="169",aT=0,a_=1,oT=2,Zv=1,lT=2,gs=3,ur=0,qn=1,Yi=2,ar=0,Ha=1,yf=2,o_=3,l_=4,cT=5,Ir=100,uT=101,dT=102,hT=103,fT=104,pT=200,mT=201,gT=202,_T=203,Sf=204,Mf=205,vT=206,xT=207,yT=208,ST=209,MT=210,ET=211,wT=212,TT=213,bT=214,Ef=0,wf=1,Tf=2,Xa=3,bf=4,Af=5,Cf=6,Nf=7,Qv=0,AT=1,CT=2,or=0,NT=1,RT=2,PT=3,kT=4,LT=5,DT=6,IT=7,Jv=300,qa=301,Ya=302,Rf=303,Pf=304,Uu=306,kf=1e3,jr=1001,Lf=1002,Si=1003,UT=1004,Cc=1005,Di=1006,Nh=1007,zr=1008,ws=1009,ex=1010,tx=1011,ol=1012,Dp=1013,Xr=1014,xs=1015,hl=1016,Ip=1017,Up=1018,Ka=1020,nx=35902,ix=1021,sx=1022,Oi=1023,rx=1024,ax=1025,Va=1026,Za=1027,ox=1028,Fp=1029,lx=1030,Op=1031,jp=1033,tu=33776,nu=33777,iu=33778,su=33779,Df=35840,If=35841,Uf=35842,Ff=35843,Of=36196,jf=37492,zf=37496,Bf=37808,Hf=37809,Vf=37810,Gf=37811,Wf=37812,$f=37813,Xf=37814,qf=37815,Yf=37816,Kf=37817,Zf=37818,Qf=37819,Jf=37820,ep=37821,ru=36492,tp=36494,np=36495,cx=36283,ip=36284,sp=36285,rp=36286,FT=3200,OT=3201,jT=0,zT=1,ir="",$i="srgb",hr="srgb-linear",zp="display-p3",Fu="display-p3-linear",gu="linear",Bt="srgb",_u="rec709",vu="p3",wa=7680,c_=519,BT=512,HT=513,VT=514,ux=515,GT=516,WT=517,$T=518,XT=519,u_=35044,d_="300 es",ys=2e3,xu=2001;class ro{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});const s=this._listeners;s[e]===void 0&&(s[e]=[]),s[e].indexOf(t)===-1&&s[e].push(t)}hasEventListener(e,t){if(this._listeners===void 0)return!1;const s=this._listeners;return s[e]!==void 0&&s[e].indexOf(t)!==-1}removeEventListener(e,t){if(this._listeners===void 0)return;const a=this._listeners[e];if(a!==void 0){const c=a.indexOf(t);c!==-1&&a.splice(c,1)}}dispatchEvent(e){if(this._listeners===void 0)return;const s=this._listeners[e.type];if(s!==void 0){e.target=this;const a=s.slice(0);for(let c=0,u=a.length;c<u;c++)a[c].call(this,e);e.target=null}}}const Nn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"],Rh=Math.PI/180,ap=180/Math.PI;function fl(){const n=Math.random()*4294967295|0,e=Math.random()*4294967295|0,t=Math.random()*4294967295|0,s=Math.random()*4294967295|0;return(Nn[n&255]+Nn[n>>8&255]+Nn[n>>16&255]+Nn[n>>24&255]+"-"+Nn[e&255]+Nn[e>>8&255]+"-"+Nn[e>>16&15|64]+Nn[e>>24&255]+"-"+Nn[t&63|128]+Nn[t>>8&255]+"-"+Nn[t>>16&255]+Nn[t>>24&255]+Nn[s&255]+Nn[s>>8&255]+Nn[s>>16&255]+Nn[s>>24&255]).toLowerCase()}function Xn(n,e,t){return Math.max(e,Math.min(t,n))}function qT(n,e){return(n%e+e)%e}function Ph(n,e,t){return(1-t)*n+t*e}function Wo(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return n/4294967295;case Uint16Array:return n/65535;case Uint8Array:return n/255;case Int32Array:return Math.max(n/2147483647,-1);case Int16Array:return Math.max(n/32767,-1);case Int8Array:return Math.max(n/127,-1);default:throw new Error("Invalid component type.")}}function Wn(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return Math.round(n*4294967295);case Uint16Array:return Math.round(n*65535);case Uint8Array:return Math.round(n*255);case Int32Array:return Math.round(n*2147483647);case Int16Array:return Math.round(n*32767);case Int8Array:return Math.round(n*127);default:throw new Error("Invalid component type.")}}class At{constructor(e=0,t=0){At.prototype.isVector2=!0,this.x=e,this.y=t}get width(){return this.x}set width(e){this.x=e}get height(){return this.y}set height(e){this.y=e}set(e,t){return this.x=e,this.y=t,this}setScalar(e){return this.x=e,this.y=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y)}copy(e){return this.x=e.x,this.y=e.y,this}add(e){return this.x+=e.x,this.y+=e.y,this}addScalar(e){return this.x+=e,this.y+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this}subScalar(e){return this.x-=e,this.y-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this}multiply(e){return this.x*=e.x,this.y*=e.y,this}multiplyScalar(e){return this.x*=e,this.y*=e,this}divide(e){return this.x/=e.x,this.y/=e.y,this}divideScalar(e){return this.multiplyScalar(1/e)}applyMatrix3(e){const t=this.x,s=this.y,a=e.elements;return this.x=a[0]*t+a[3]*s+a[6],this.y=a[1]*t+a[4]*s+a[7],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this}clampLength(e,t){const s=this.length();return this.divideScalar(s||1).multiplyScalar(Math.max(e,Math.min(t,s)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(e){return this.x*e.x+this.y*e.y}cross(e){return this.x*e.y-this.y*e.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const s=this.dot(e)/t;return Math.acos(Xn(s,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,s=this.y-e.y;return t*t+s*s}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this}lerpVectors(e,t,s){return this.x=e.x+(t.x-e.x)*s,this.y=e.y+(t.y-e.y)*s,this}equals(e){return e.x===this.x&&e.y===this.y}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this}rotateAround(e,t){const s=Math.cos(t),a=Math.sin(t),c=this.x-e.x,u=this.y-e.y;return this.x=c*s-u*a+e.x,this.y=c*a+u*s+e.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}}class dt{constructor(e,t,s,a,c,u,d,f,p){dt.prototype.isMatrix3=!0,this.elements=[1,0,0,0,1,0,0,0,1],e!==void 0&&this.set(e,t,s,a,c,u,d,f,p)}set(e,t,s,a,c,u,d,f,p){const g=this.elements;return g[0]=e,g[1]=a,g[2]=d,g[3]=t,g[4]=c,g[5]=f,g[6]=s,g[7]=u,g[8]=p,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(e){const t=this.elements,s=e.elements;return t[0]=s[0],t[1]=s[1],t[2]=s[2],t[3]=s[3],t[4]=s[4],t[5]=s[5],t[6]=s[6],t[7]=s[7],t[8]=s[8],this}extractBasis(e,t,s){return e.setFromMatrix3Column(this,0),t.setFromMatrix3Column(this,1),s.setFromMatrix3Column(this,2),this}setFromMatrix4(e){const t=e.elements;return this.set(t[0],t[4],t[8],t[1],t[5],t[9],t[2],t[6],t[10]),this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const s=e.elements,a=t.elements,c=this.elements,u=s[0],d=s[3],f=s[6],p=s[1],g=s[4],v=s[7],x=s[2],y=s[5],w=s[8],E=a[0],_=a[3],M=a[6],L=a[1],A=a[4],R=a[7],k=a[2],D=a[5],U=a[8];return c[0]=u*E+d*L+f*k,c[3]=u*_+d*A+f*D,c[6]=u*M+d*R+f*U,c[1]=p*E+g*L+v*k,c[4]=p*_+g*A+v*D,c[7]=p*M+g*R+v*U,c[2]=x*E+y*L+w*k,c[5]=x*_+y*A+w*D,c[8]=x*M+y*R+w*U,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[3]*=e,t[6]*=e,t[1]*=e,t[4]*=e,t[7]*=e,t[2]*=e,t[5]*=e,t[8]*=e,this}determinant(){const e=this.elements,t=e[0],s=e[1],a=e[2],c=e[3],u=e[4],d=e[5],f=e[6],p=e[7],g=e[8];return t*u*g-t*d*p-s*c*g+s*d*f+a*c*p-a*u*f}invert(){const e=this.elements,t=e[0],s=e[1],a=e[2],c=e[3],u=e[4],d=e[5],f=e[6],p=e[7],g=e[8],v=g*u-d*p,x=d*f-g*c,y=p*c-u*f,w=t*v+s*x+a*y;if(w===0)return this.set(0,0,0,0,0,0,0,0,0);const E=1/w;return e[0]=v*E,e[1]=(a*p-g*s)*E,e[2]=(d*s-a*u)*E,e[3]=x*E,e[4]=(g*t-a*f)*E,e[5]=(a*c-d*t)*E,e[6]=y*E,e[7]=(s*f-p*t)*E,e[8]=(u*t-s*c)*E,this}transpose(){let e;const t=this.elements;return e=t[1],t[1]=t[3],t[3]=e,e=t[2],t[2]=t[6],t[6]=e,e=t[5],t[5]=t[7],t[7]=e,this}getNormalMatrix(e){return this.setFromMatrix4(e).invert().transpose()}transposeIntoArray(e){const t=this.elements;return e[0]=t[0],e[1]=t[3],e[2]=t[6],e[3]=t[1],e[4]=t[4],e[5]=t[7],e[6]=t[2],e[7]=t[5],e[8]=t[8],this}setUvTransform(e,t,s,a,c,u,d){const f=Math.cos(c),p=Math.sin(c);return this.set(s*f,s*p,-s*(f*u+p*d)+u+e,-a*p,a*f,-a*(-p*u+f*d)+d+t,0,0,1),this}scale(e,t){return this.premultiply(kh.makeScale(e,t)),this}rotate(e){return this.premultiply(kh.makeRotation(-e)),this}translate(e,t){return this.premultiply(kh.makeTranslation(e,t)),this}makeTranslation(e,t){return e.isVector2?this.set(1,0,e.x,0,1,e.y,0,0,1):this.set(1,0,e,0,1,t,0,0,1),this}makeRotation(e){const t=Math.cos(e),s=Math.sin(e);return this.set(t,-s,0,s,t,0,0,0,1),this}makeScale(e,t){return this.set(e,0,0,0,t,0,0,0,1),this}equals(e){const t=this.elements,s=e.elements;for(let a=0;a<9;a++)if(t[a]!==s[a])return!1;return!0}fromArray(e,t=0){for(let s=0;s<9;s++)this.elements[s]=e[s+t];return this}toArray(e=[],t=0){const s=this.elements;return e[t]=s[0],e[t+1]=s[1],e[t+2]=s[2],e[t+3]=s[3],e[t+4]=s[4],e[t+5]=s[5],e[t+6]=s[6],e[t+7]=s[7],e[t+8]=s[8],e}clone(){return new this.constructor().fromArray(this.elements)}}const kh=new dt;function dx(n){for(let e=n.length-1;e>=0;--e)if(n[e]>=65535)return!0;return!1}function yu(n){return document.createElementNS("http://www.w3.org/1999/xhtml",n)}function YT(){const n=yu("canvas");return n.style.display="block",n}const h_={};function au(n){n in h_||(h_[n]=!0,console.warn(n))}function KT(n,e,t){return new Promise(function(s,a){function c(){switch(n.clientWaitSync(e,n.SYNC_FLUSH_COMMANDS_BIT,0)){case n.WAIT_FAILED:a();break;case n.TIMEOUT_EXPIRED:setTimeout(c,t);break;default:s()}}setTimeout(c,t)})}function ZT(n){const e=n.elements;e[2]=.5*e[2]+.5*e[3],e[6]=.5*e[6]+.5*e[7],e[10]=.5*e[10]+.5*e[11],e[14]=.5*e[14]+.5*e[15]}function QT(n){const e=n.elements;e[11]===-1?(e[10]=-e[10]-1,e[14]=-e[14]):(e[10]=-e[10],e[14]=-e[14]+1)}const f_=new dt().set(.8224621,.177538,0,.0331941,.9668058,0,.0170827,.0723974,.9105199),p_=new dt().set(1.2249401,-.2249404,0,-.0420569,1.0420571,0,-.0196376,-.0786361,1.0982735),$o={[hr]:{transfer:gu,primaries:_u,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n,fromReference:n=>n},[$i]:{transfer:Bt,primaries:_u,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n.convertSRGBToLinear(),fromReference:n=>n.convertLinearToSRGB()},[Fu]:{transfer:gu,primaries:vu,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.applyMatrix3(p_),fromReference:n=>n.applyMatrix3(f_)},[zp]:{transfer:Bt,primaries:vu,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.convertSRGBToLinear().applyMatrix3(p_),fromReference:n=>n.applyMatrix3(f_).convertLinearToSRGB()}},JT=new Set([hr,Fu]),Nt={enabled:!0,_workingColorSpace:hr,get workingColorSpace(){return this._workingColorSpace},set workingColorSpace(n){if(!JT.has(n))throw new Error(`Unsupported working color space, "${n}".`);this._workingColorSpace=n},convert:function(n,e,t){if(this.enabled===!1||e===t||!e||!t)return n;const s=$o[e].toReference,a=$o[t].fromReference;return a(s(n))},fromWorkingColorSpace:function(n,e){return this.convert(n,this._workingColorSpace,e)},toWorkingColorSpace:function(n,e){return this.convert(n,e,this._workingColorSpace)},getPrimaries:function(n){return $o[n].primaries},getTransfer:function(n){return n===ir?gu:$o[n].transfer},getLuminanceCoefficients:function(n,e=this._workingColorSpace){return n.fromArray($o[e].luminanceCoefficients)}};function Ga(n){return n<.04045?n*.0773993808:Math.pow(n*.9478672986+.0521327014,2.4)}function Lh(n){return n<.0031308?n*12.92:1.055*Math.pow(n,.41666)-.055}let Ta;class eb{static getDataURL(e){if(/^data:/i.test(e.src)||typeof HTMLCanvasElement>"u")return e.src;let t;if(e instanceof HTMLCanvasElement)t=e;else{Ta===void 0&&(Ta=yu("canvas")),Ta.width=e.width,Ta.height=e.height;const s=Ta.getContext("2d");e instanceof ImageData?s.putImageData(e,0,0):s.drawImage(e,0,0,e.width,e.height),t=Ta}return t.width>2048||t.height>2048?(console.warn("THREE.ImageUtils.getDataURL: Image converted to jpg for performance reasons",e),t.toDataURL("image/jpeg",.6)):t.toDataURL("image/png")}static sRGBToLinear(e){if(typeof HTMLImageElement<"u"&&e instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&e instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&e instanceof ImageBitmap){const t=yu("canvas");t.width=e.width,t.height=e.height;const s=t.getContext("2d");s.drawImage(e,0,0,e.width,e.height);const a=s.getImageData(0,0,e.width,e.height),c=a.data;for(let u=0;u<c.length;u++)c[u]=Ga(c[u]/255)*255;return s.putImageData(a,0,0),t}else if(e.data){const t=e.data.slice(0);for(let s=0;s<t.length;s++)t instanceof Uint8Array||t instanceof Uint8ClampedArray?t[s]=Math.floor(Ga(t[s]/255)*255):t[s]=Ga(t[s]);return{data:t,width:e.width,height:e.height}}else return console.warn("THREE.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),e}}let tb=0;class hx{constructor(e=null){this.isSource=!0,Object.defineProperty(this,"id",{value:tb++}),this.uuid=fl(),this.data=e,this.dataReady=!0,this.version=0}set needsUpdate(e){e===!0&&this.version++}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.images[this.uuid]!==void 0)return e.images[this.uuid];const s={uuid:this.uuid,url:""},a=this.data;if(a!==null){let c;if(Array.isArray(a)){c=[];for(let u=0,d=a.length;u<d;u++)a[u].isDataTexture?c.push(Dh(a[u].image)):c.push(Dh(a[u]))}else c=Dh(a);s.url=c}return t||(e.images[this.uuid]=s),s}}function Dh(n){return typeof HTMLImageElement<"u"&&n instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&n instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&n instanceof ImageBitmap?eb.getDataURL(n):n.data?{data:Array.from(n.data),width:n.width,height:n.height,type:n.data.constructor.name}:(console.warn("THREE.Texture: Unable to serialize Texture."),{})}let nb=0;class Yn extends ro{constructor(e=Yn.DEFAULT_IMAGE,t=Yn.DEFAULT_MAPPING,s=jr,a=jr,c=Di,u=zr,d=Oi,f=ws,p=Yn.DEFAULT_ANISOTROPY,g=ir){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:nb++}),this.uuid=fl(),this.name="",this.source=new hx(e),this.mipmaps=[],this.mapping=t,this.channel=0,this.wrapS=s,this.wrapT=a,this.magFilter=c,this.minFilter=u,this.anisotropy=p,this.format=d,this.internalFormat=null,this.type=f,this.offset=new At(0,0),this.repeat=new At(1,1),this.center=new At(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new dt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=g,this.userData={},this.version=0,this.onUpdate=null,this.isRenderTargetTexture=!1,this.pmremVersion=0}get image(){return this.source.data}set image(e=null){this.source.data=e}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}clone(){return new this.constructor().copy(this)}copy(e){return this.name=e.name,this.source=e.source,this.mipmaps=e.mipmaps.slice(0),this.mapping=e.mapping,this.channel=e.channel,this.wrapS=e.wrapS,this.wrapT=e.wrapT,this.magFilter=e.magFilter,this.minFilter=e.minFilter,this.anisotropy=e.anisotropy,this.format=e.format,this.internalFormat=e.internalFormat,this.type=e.type,this.offset.copy(e.offset),this.repeat.copy(e.repeat),this.center.copy(e.center),this.rotation=e.rotation,this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrix.copy(e.matrix),this.generateMipmaps=e.generateMipmaps,this.premultiplyAlpha=e.premultiplyAlpha,this.flipY=e.flipY,this.unpackAlignment=e.unpackAlignment,this.colorSpace=e.colorSpace,this.userData=JSON.parse(JSON.stringify(e.userData)),this.needsUpdate=!0,this}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.textures[this.uuid]!==void 0)return e.textures[this.uuid];const s={metadata:{version:4.6,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(e).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(s.userData=this.userData),t||(e.textures[this.uuid]=s),s}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(e){if(this.mapping!==Jv)return e;if(e.applyMatrix3(this.matrix),e.x<0||e.x>1)switch(this.wrapS){case kf:e.x=e.x-Math.floor(e.x);break;case jr:e.x=e.x<0?0:1;break;case Lf:Math.abs(Math.floor(e.x)%2)===1?e.x=Math.ceil(e.x)-e.x:e.x=e.x-Math.floor(e.x);break}if(e.y<0||e.y>1)switch(this.wrapT){case kf:e.y=e.y-Math.floor(e.y);break;case jr:e.y=e.y<0?0:1;break;case Lf:Math.abs(Math.floor(e.y)%2)===1?e.y=Math.ceil(e.y)-e.y:e.y=e.y-Math.floor(e.y);break}return this.flipY&&(e.y=1-e.y),e}set needsUpdate(e){e===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(e){e===!0&&this.pmremVersion++}}Yn.DEFAULT_IMAGE=null;Yn.DEFAULT_MAPPING=Jv;Yn.DEFAULT_ANISOTROPY=1;class Qt{constructor(e=0,t=0,s=0,a=1){Qt.prototype.isVector4=!0,this.x=e,this.y=t,this.z=s,this.w=a}get width(){return this.z}set width(e){this.z=e}get height(){return this.w}set height(e){this.w=e}set(e,t,s,a){return this.x=e,this.y=t,this.z=s,this.w=a,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this.w=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setW(e){return this.w=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;case 3:this.w=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w!==void 0?e.w:1,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this.w+=e.w,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this.w+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this.w=e.w+t.w,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this.w+=e.w*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this.w-=e.w,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this.w-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this.w=e.w-t.w,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this.w*=e.w,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this.w*=e,this}applyMatrix4(e){const t=this.x,s=this.y,a=this.z,c=this.w,u=e.elements;return this.x=u[0]*t+u[4]*s+u[8]*a+u[12]*c,this.y=u[1]*t+u[5]*s+u[9]*a+u[13]*c,this.z=u[2]*t+u[6]*s+u[10]*a+u[14]*c,this.w=u[3]*t+u[7]*s+u[11]*a+u[15]*c,this}divideScalar(e){return this.multiplyScalar(1/e)}setAxisAngleFromQuaternion(e){this.w=2*Math.acos(e.w);const t=Math.sqrt(1-e.w*e.w);return t<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=e.x/t,this.y=e.y/t,this.z=e.z/t),this}setAxisAngleFromRotationMatrix(e){let t,s,a,c;const f=e.elements,p=f[0],g=f[4],v=f[8],x=f[1],y=f[5],w=f[9],E=f[2],_=f[6],M=f[10];if(Math.abs(g-x)<.01&&Math.abs(v-E)<.01&&Math.abs(w-_)<.01){if(Math.abs(g+x)<.1&&Math.abs(v+E)<.1&&Math.abs(w+_)<.1&&Math.abs(p+y+M-3)<.1)return this.set(1,0,0,0),this;t=Math.PI;const A=(p+1)/2,R=(y+1)/2,k=(M+1)/2,D=(g+x)/4,U=(v+E)/4,$=(w+_)/4;return A>R&&A>k?A<.01?(s=0,a=.707106781,c=.707106781):(s=Math.sqrt(A),a=D/s,c=U/s):R>k?R<.01?(s=.707106781,a=0,c=.707106781):(a=Math.sqrt(R),s=D/a,c=$/a):k<.01?(s=.707106781,a=.707106781,c=0):(c=Math.sqrt(k),s=U/c,a=$/c),this.set(s,a,c,t),this}let L=Math.sqrt((_-w)*(_-w)+(v-E)*(v-E)+(x-g)*(x-g));return Math.abs(L)<.001&&(L=1),this.x=(_-w)/L,this.y=(v-E)/L,this.z=(x-g)/L,this.w=Math.acos((p+y+M-1)/2),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this.w=t[15],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this.w=Math.min(this.w,e.w),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this.w=Math.max(this.w,e.w),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this.w=Math.max(e.w,Math.min(t.w,this.w)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this.w=Math.max(e,Math.min(t,this.w)),this}clampLength(e,t){const s=this.length();return this.divideScalar(s||1).multiplyScalar(Math.max(e,Math.min(t,s)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z+this.w*e.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this.w+=(e.w-this.w)*t,this}lerpVectors(e,t,s){return this.x=e.x+(t.x-e.x)*s,this.y=e.y+(t.y-e.y)*s,this.z=e.z+(t.z-e.z)*s,this.w=e.w+(t.w-e.w)*s,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z&&e.w===this.w}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this.w=e[t+3],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e[t+3]=this.w,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this.w=e.getW(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}}class ib extends ro{constructor(e=1,t=1,s={}){super(),this.isRenderTarget=!0,this.width=e,this.height=t,this.depth=1,this.scissor=new Qt(0,0,e,t),this.scissorTest=!1,this.viewport=new Qt(0,0,e,t);const a={width:e,height:t,depth:1};s=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Di,depthBuffer:!0,stencilBuffer:!1,resolveDepthBuffer:!0,resolveStencilBuffer:!0,depthTexture:null,samples:0,count:1},s);const c=new Yn(a,s.mapping,s.wrapS,s.wrapT,s.magFilter,s.minFilter,s.format,s.type,s.anisotropy,s.colorSpace);c.flipY=!1,c.generateMipmaps=s.generateMipmaps,c.internalFormat=s.internalFormat,this.textures=[];const u=s.count;for(let d=0;d<u;d++)this.textures[d]=c.clone(),this.textures[d].isRenderTargetTexture=!0;this.depthBuffer=s.depthBuffer,this.stencilBuffer=s.stencilBuffer,this.resolveDepthBuffer=s.resolveDepthBuffer,this.resolveStencilBuffer=s.resolveStencilBuffer,this.depthTexture=s.depthTexture,this.samples=s.samples}get texture(){return this.textures[0]}set texture(e){this.textures[0]=e}setSize(e,t,s=1){if(this.width!==e||this.height!==t||this.depth!==s){this.width=e,this.height=t,this.depth=s;for(let a=0,c=this.textures.length;a<c;a++)this.textures[a].image.width=e,this.textures[a].image.height=t,this.textures[a].image.depth=s;this.dispose()}this.viewport.set(0,0,e,t),this.scissor.set(0,0,e,t)}clone(){return new this.constructor().copy(this)}copy(e){this.width=e.width,this.height=e.height,this.depth=e.depth,this.scissor.copy(e.scissor),this.scissorTest=e.scissorTest,this.viewport.copy(e.viewport),this.textures.length=0;for(let s=0,a=e.textures.length;s<a;s++)this.textures[s]=e.textures[s].clone(),this.textures[s].isRenderTargetTexture=!0;const t=Object.assign({},e.texture.image);return this.texture.source=new hx(t),this.depthBuffer=e.depthBuffer,this.stencilBuffer=e.stencilBuffer,this.resolveDepthBuffer=e.resolveDepthBuffer,this.resolveStencilBuffer=e.resolveStencilBuffer,e.depthTexture!==null&&(this.depthTexture=e.depthTexture.clone()),this.samples=e.samples,this}dispose(){this.dispatchEvent({type:"dispose"})}}class qr extends ib{constructor(e=1,t=1,s={}){super(e,t,s),this.isWebGLRenderTarget=!0}}class fx extends Yn{constructor(e=null,t=1,s=1,a=1){super(null),this.isDataArrayTexture=!0,this.image={data:e,width:t,height:s,depth:a},this.magFilter=Si,this.minFilter=Si,this.wrapR=jr,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}addLayerUpdate(e){this.layerUpdates.add(e)}clearLayerUpdates(){this.layerUpdates.clear()}}class sb extends Yn{constructor(e=null,t=1,s=1,a=1){super(null),this.isData3DTexture=!0,this.image={data:e,width:t,height:s,depth:a},this.magFilter=Si,this.minFilter=Si,this.wrapR=jr,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}}class pl{constructor(e=0,t=0,s=0,a=1){this.isQuaternion=!0,this._x=e,this._y=t,this._z=s,this._w=a}static slerpFlat(e,t,s,a,c,u,d){let f=s[a+0],p=s[a+1],g=s[a+2],v=s[a+3];const x=c[u+0],y=c[u+1],w=c[u+2],E=c[u+3];if(d===0){e[t+0]=f,e[t+1]=p,e[t+2]=g,e[t+3]=v;return}if(d===1){e[t+0]=x,e[t+1]=y,e[t+2]=w,e[t+3]=E;return}if(v!==E||f!==x||p!==y||g!==w){let _=1-d;const M=f*x+p*y+g*w+v*E,L=M>=0?1:-1,A=1-M*M;if(A>Number.EPSILON){const k=Math.sqrt(A),D=Math.atan2(k,M*L);_=Math.sin(_*D)/k,d=Math.sin(d*D)/k}const R=d*L;if(f=f*_+x*R,p=p*_+y*R,g=g*_+w*R,v=v*_+E*R,_===1-d){const k=1/Math.sqrt(f*f+p*p+g*g+v*v);f*=k,p*=k,g*=k,v*=k}}e[t]=f,e[t+1]=p,e[t+2]=g,e[t+3]=v}static multiplyQuaternionsFlat(e,t,s,a,c,u){const d=s[a],f=s[a+1],p=s[a+2],g=s[a+3],v=c[u],x=c[u+1],y=c[u+2],w=c[u+3];return e[t]=d*w+g*v+f*y-p*x,e[t+1]=f*w+g*x+p*v-d*y,e[t+2]=p*w+g*y+d*x-f*v,e[t+3]=g*w-d*v-f*x-p*y,e}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get w(){return this._w}set w(e){this._w=e,this._onChangeCallback()}set(e,t,s,a){return this._x=e,this._y=t,this._z=s,this._w=a,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(e){return this._x=e.x,this._y=e.y,this._z=e.z,this._w=e.w,this._onChangeCallback(),this}setFromEuler(e,t=!0){const s=e._x,a=e._y,c=e._z,u=e._order,d=Math.cos,f=Math.sin,p=d(s/2),g=d(a/2),v=d(c/2),x=f(s/2),y=f(a/2),w=f(c/2);switch(u){case"XYZ":this._x=x*g*v+p*y*w,this._y=p*y*v-x*g*w,this._z=p*g*w+x*y*v,this._w=p*g*v-x*y*w;break;case"YXZ":this._x=x*g*v+p*y*w,this._y=p*y*v-x*g*w,this._z=p*g*w-x*y*v,this._w=p*g*v+x*y*w;break;case"ZXY":this._x=x*g*v-p*y*w,this._y=p*y*v+x*g*w,this._z=p*g*w+x*y*v,this._w=p*g*v-x*y*w;break;case"ZYX":this._x=x*g*v-p*y*w,this._y=p*y*v+x*g*w,this._z=p*g*w-x*y*v,this._w=p*g*v+x*y*w;break;case"YZX":this._x=x*g*v+p*y*w,this._y=p*y*v+x*g*w,this._z=p*g*w-x*y*v,this._w=p*g*v-x*y*w;break;case"XZY":this._x=x*g*v-p*y*w,this._y=p*y*v-x*g*w,this._z=p*g*w+x*y*v,this._w=p*g*v+x*y*w;break;default:console.warn("THREE.Quaternion: .setFromEuler() encountered an unknown order: "+u)}return t===!0&&this._onChangeCallback(),this}setFromAxisAngle(e,t){const s=t/2,a=Math.sin(s);return this._x=e.x*a,this._y=e.y*a,this._z=e.z*a,this._w=Math.cos(s),this._onChangeCallback(),this}setFromRotationMatrix(e){const t=e.elements,s=t[0],a=t[4],c=t[8],u=t[1],d=t[5],f=t[9],p=t[2],g=t[6],v=t[10],x=s+d+v;if(x>0){const y=.5/Math.sqrt(x+1);this._w=.25/y,this._x=(g-f)*y,this._y=(c-p)*y,this._z=(u-a)*y}else if(s>d&&s>v){const y=2*Math.sqrt(1+s-d-v);this._w=(g-f)/y,this._x=.25*y,this._y=(a+u)/y,this._z=(c+p)/y}else if(d>v){const y=2*Math.sqrt(1+d-s-v);this._w=(c-p)/y,this._x=(a+u)/y,this._y=.25*y,this._z=(f+g)/y}else{const y=2*Math.sqrt(1+v-s-d);this._w=(u-a)/y,this._x=(c+p)/y,this._y=(f+g)/y,this._z=.25*y}return this._onChangeCallback(),this}setFromUnitVectors(e,t){let s=e.dot(t)+1;return s<Number.EPSILON?(s=0,Math.abs(e.x)>Math.abs(e.z)?(this._x=-e.y,this._y=e.x,this._z=0,this._w=s):(this._x=0,this._y=-e.z,this._z=e.y,this._w=s)):(this._x=e.y*t.z-e.z*t.y,this._y=e.z*t.x-e.x*t.z,this._z=e.x*t.y-e.y*t.x,this._w=s),this.normalize()}angleTo(e){return 2*Math.acos(Math.abs(Xn(this.dot(e),-1,1)))}rotateTowards(e,t){const s=this.angleTo(e);if(s===0)return this;const a=Math.min(1,t/s);return this.slerp(e,a),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(e){return this._x*e._x+this._y*e._y+this._z*e._z+this._w*e._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let e=this.length();return e===0?(this._x=0,this._y=0,this._z=0,this._w=1):(e=1/e,this._x=this._x*e,this._y=this._y*e,this._z=this._z*e,this._w=this._w*e),this._onChangeCallback(),this}multiply(e){return this.multiplyQuaternions(this,e)}premultiply(e){return this.multiplyQuaternions(e,this)}multiplyQuaternions(e,t){const s=e._x,a=e._y,c=e._z,u=e._w,d=t._x,f=t._y,p=t._z,g=t._w;return this._x=s*g+u*d+a*p-c*f,this._y=a*g+u*f+c*d-s*p,this._z=c*g+u*p+s*f-a*d,this._w=u*g-s*d-a*f-c*p,this._onChangeCallback(),this}slerp(e,t){if(t===0)return this;if(t===1)return this.copy(e);const s=this._x,a=this._y,c=this._z,u=this._w;let d=u*e._w+s*e._x+a*e._y+c*e._z;if(d<0?(this._w=-e._w,this._x=-e._x,this._y=-e._y,this._z=-e._z,d=-d):this.copy(e),d>=1)return this._w=u,this._x=s,this._y=a,this._z=c,this;const f=1-d*d;if(f<=Number.EPSILON){const y=1-t;return this._w=y*u+t*this._w,this._x=y*s+t*this._x,this._y=y*a+t*this._y,this._z=y*c+t*this._z,this.normalize(),this}const p=Math.sqrt(f),g=Math.atan2(p,d),v=Math.sin((1-t)*g)/p,x=Math.sin(t*g)/p;return this._w=u*v+this._w*x,this._x=s*v+this._x*x,this._y=a*v+this._y*x,this._z=c*v+this._z*x,this._onChangeCallback(),this}slerpQuaternions(e,t,s){return this.copy(e).slerp(t,s)}random(){const e=2*Math.PI*Math.random(),t=2*Math.PI*Math.random(),s=Math.random(),a=Math.sqrt(1-s),c=Math.sqrt(s);return this.set(a*Math.sin(e),a*Math.cos(e),c*Math.sin(t),c*Math.cos(t))}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._w===this._w}fromArray(e,t=0){return this._x=e[t],this._y=e[t+1],this._z=e[t+2],this._w=e[t+3],this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._w,e}fromBufferAttribute(e,t){return this._x=e.getX(t),this._y=e.getY(t),this._z=e.getZ(t),this._w=e.getW(t),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}}class se{constructor(e=0,t=0,s=0){se.prototype.isVector3=!0,this.x=e,this.y=t,this.z=s}set(e,t,s){return s===void 0&&(s=this.z),this.x=e,this.y=t,this.z=s,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this}multiplyVectors(e,t){return this.x=e.x*t.x,this.y=e.y*t.y,this.z=e.z*t.z,this}applyEuler(e){return this.applyQuaternion(m_.setFromEuler(e))}applyAxisAngle(e,t){return this.applyQuaternion(m_.setFromAxisAngle(e,t))}applyMatrix3(e){const t=this.x,s=this.y,a=this.z,c=e.elements;return this.x=c[0]*t+c[3]*s+c[6]*a,this.y=c[1]*t+c[4]*s+c[7]*a,this.z=c[2]*t+c[5]*s+c[8]*a,this}applyNormalMatrix(e){return this.applyMatrix3(e).normalize()}applyMatrix4(e){const t=this.x,s=this.y,a=this.z,c=e.elements,u=1/(c[3]*t+c[7]*s+c[11]*a+c[15]);return this.x=(c[0]*t+c[4]*s+c[8]*a+c[12])*u,this.y=(c[1]*t+c[5]*s+c[9]*a+c[13])*u,this.z=(c[2]*t+c[6]*s+c[10]*a+c[14])*u,this}applyQuaternion(e){const t=this.x,s=this.y,a=this.z,c=e.x,u=e.y,d=e.z,f=e.w,p=2*(u*a-d*s),g=2*(d*t-c*a),v=2*(c*s-u*t);return this.x=t+f*p+u*v-d*g,this.y=s+f*g+d*p-c*v,this.z=a+f*v+c*g-u*p,this}project(e){return this.applyMatrix4(e.matrixWorldInverse).applyMatrix4(e.projectionMatrix)}unproject(e){return this.applyMatrix4(e.projectionMatrixInverse).applyMatrix4(e.matrixWorld)}transformDirection(e){const t=this.x,s=this.y,a=this.z,c=e.elements;return this.x=c[0]*t+c[4]*s+c[8]*a,this.y=c[1]*t+c[5]*s+c[9]*a,this.z=c[2]*t+c[6]*s+c[10]*a,this.normalize()}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this}divideScalar(e){return this.multiplyScalar(1/e)}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this}clampLength(e,t){const s=this.length();return this.divideScalar(s||1).multiplyScalar(Math.max(e,Math.min(t,s)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this}lerpVectors(e,t,s){return this.x=e.x+(t.x-e.x)*s,this.y=e.y+(t.y-e.y)*s,this.z=e.z+(t.z-e.z)*s,this}cross(e){return this.crossVectors(this,e)}crossVectors(e,t){const s=e.x,a=e.y,c=e.z,u=t.x,d=t.y,f=t.z;return this.x=a*f-c*d,this.y=c*u-s*f,this.z=s*d-a*u,this}projectOnVector(e){const t=e.lengthSq();if(t===0)return this.set(0,0,0);const s=e.dot(this)/t;return this.copy(e).multiplyScalar(s)}projectOnPlane(e){return Ih.copy(this).projectOnVector(e),this.sub(Ih)}reflect(e){return this.sub(Ih.copy(e).multiplyScalar(2*this.dot(e)))}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const s=this.dot(e)/t;return Math.acos(Xn(s,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,s=this.y-e.y,a=this.z-e.z;return t*t+s*s+a*a}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)+Math.abs(this.z-e.z)}setFromSpherical(e){return this.setFromSphericalCoords(e.radius,e.phi,e.theta)}setFromSphericalCoords(e,t,s){const a=Math.sin(t)*e;return this.x=a*Math.sin(s),this.y=Math.cos(t)*e,this.z=a*Math.cos(s),this}setFromCylindrical(e){return this.setFromCylindricalCoords(e.radius,e.theta,e.y)}setFromCylindricalCoords(e,t,s){return this.x=e*Math.sin(t),this.y=s,this.z=e*Math.cos(t),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this}setFromMatrixScale(e){const t=this.setFromMatrixColumn(e,0).length(),s=this.setFromMatrixColumn(e,1).length(),a=this.setFromMatrixColumn(e,2).length();return this.x=t,this.y=s,this.z=a,this}setFromMatrixColumn(e,t){return this.fromArray(e.elements,t*4)}setFromMatrix3Column(e,t){return this.fromArray(e.elements,t*3)}setFromEuler(e){return this.x=e._x,this.y=e._y,this.z=e._z,this}setFromColor(e){return this.x=e.r,this.y=e.g,this.z=e.b,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){const e=Math.random()*Math.PI*2,t=Math.random()*2-1,s=Math.sqrt(1-t*t);return this.x=s*Math.cos(e),this.y=t,this.z=s*Math.sin(e),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}}const Ih=new se,m_=new pl;class ml{constructor(e=new se(1/0,1/0,1/0),t=new se(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=e,this.max=t}set(e,t){return this.min.copy(e),this.max.copy(t),this}setFromArray(e){this.makeEmpty();for(let t=0,s=e.length;t<s;t+=3)this.expandByPoint(Pi.fromArray(e,t));return this}setFromBufferAttribute(e){this.makeEmpty();for(let t=0,s=e.count;t<s;t++)this.expandByPoint(Pi.fromBufferAttribute(e,t));return this}setFromPoints(e){this.makeEmpty();for(let t=0,s=e.length;t<s;t++)this.expandByPoint(e[t]);return this}setFromCenterAndSize(e,t){const s=Pi.copy(t).multiplyScalar(.5);return this.min.copy(e).sub(s),this.max.copy(e).add(s),this}setFromObject(e,t=!1){return this.makeEmpty(),this.expandByObject(e,t)}clone(){return new this.constructor().copy(this)}copy(e){return this.min.copy(e.min),this.max.copy(e.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(e){return this.isEmpty()?e.set(0,0,0):e.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(e){return this.isEmpty()?e.set(0,0,0):e.subVectors(this.max,this.min)}expandByPoint(e){return this.min.min(e),this.max.max(e),this}expandByVector(e){return this.min.sub(e),this.max.add(e),this}expandByScalar(e){return this.min.addScalar(-e),this.max.addScalar(e),this}expandByObject(e,t=!1){e.updateWorldMatrix(!1,!1);const s=e.geometry;if(s!==void 0){const c=s.getAttribute("position");if(t===!0&&c!==void 0&&e.isInstancedMesh!==!0)for(let u=0,d=c.count;u<d;u++)e.isMesh===!0?e.getVertexPosition(u,Pi):Pi.fromBufferAttribute(c,u),Pi.applyMatrix4(e.matrixWorld),this.expandByPoint(Pi);else e.boundingBox!==void 0?(e.boundingBox===null&&e.computeBoundingBox(),Nc.copy(e.boundingBox)):(s.boundingBox===null&&s.computeBoundingBox(),Nc.copy(s.boundingBox)),Nc.applyMatrix4(e.matrixWorld),this.union(Nc)}const a=e.children;for(let c=0,u=a.length;c<u;c++)this.expandByObject(a[c],t);return this}containsPoint(e){return e.x>=this.min.x&&e.x<=this.max.x&&e.y>=this.min.y&&e.y<=this.max.y&&e.z>=this.min.z&&e.z<=this.max.z}containsBox(e){return this.min.x<=e.min.x&&e.max.x<=this.max.x&&this.min.y<=e.min.y&&e.max.y<=this.max.y&&this.min.z<=e.min.z&&e.max.z<=this.max.z}getParameter(e,t){return t.set((e.x-this.min.x)/(this.max.x-this.min.x),(e.y-this.min.y)/(this.max.y-this.min.y),(e.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(e){return e.max.x>=this.min.x&&e.min.x<=this.max.x&&e.max.y>=this.min.y&&e.min.y<=this.max.y&&e.max.z>=this.min.z&&e.min.z<=this.max.z}intersectsSphere(e){return this.clampPoint(e.center,Pi),Pi.distanceToSquared(e.center)<=e.radius*e.radius}intersectsPlane(e){let t,s;return e.normal.x>0?(t=e.normal.x*this.min.x,s=e.normal.x*this.max.x):(t=e.normal.x*this.max.x,s=e.normal.x*this.min.x),e.normal.y>0?(t+=e.normal.y*this.min.y,s+=e.normal.y*this.max.y):(t+=e.normal.y*this.max.y,s+=e.normal.y*this.min.y),e.normal.z>0?(t+=e.normal.z*this.min.z,s+=e.normal.z*this.max.z):(t+=e.normal.z*this.max.z,s+=e.normal.z*this.min.z),t<=-e.constant&&s>=-e.constant}intersectsTriangle(e){if(this.isEmpty())return!1;this.getCenter(Xo),Rc.subVectors(this.max,Xo),ba.subVectors(e.a,Xo),Aa.subVectors(e.b,Xo),Ca.subVectors(e.c,Xo),Zs.subVectors(Aa,ba),Qs.subVectors(Ca,Aa),Ar.subVectors(ba,Ca);let t=[0,-Zs.z,Zs.y,0,-Qs.z,Qs.y,0,-Ar.z,Ar.y,Zs.z,0,-Zs.x,Qs.z,0,-Qs.x,Ar.z,0,-Ar.x,-Zs.y,Zs.x,0,-Qs.y,Qs.x,0,-Ar.y,Ar.x,0];return!Uh(t,ba,Aa,Ca,Rc)||(t=[1,0,0,0,1,0,0,0,1],!Uh(t,ba,Aa,Ca,Rc))?!1:(Pc.crossVectors(Zs,Qs),t=[Pc.x,Pc.y,Pc.z],Uh(t,ba,Aa,Ca,Rc))}clampPoint(e,t){return t.copy(e).clamp(this.min,this.max)}distanceToPoint(e){return this.clampPoint(e,Pi).distanceTo(e)}getBoundingSphere(e){return this.isEmpty()?e.makeEmpty():(this.getCenter(e.center),e.radius=this.getSize(Pi).length()*.5),e}intersect(e){return this.min.max(e.min),this.max.min(e.max),this.isEmpty()&&this.makeEmpty(),this}union(e){return this.min.min(e.min),this.max.max(e.max),this}applyMatrix4(e){return this.isEmpty()?this:(ds[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(e),ds[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(e),ds[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(e),ds[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(e),ds[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(e),ds[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(e),ds[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(e),ds[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(e),this.setFromPoints(ds),this)}translate(e){return this.min.add(e),this.max.add(e),this}equals(e){return e.min.equals(this.min)&&e.max.equals(this.max)}}const ds=[new se,new se,new se,new se,new se,new se,new se,new se],Pi=new se,Nc=new ml,ba=new se,Aa=new se,Ca=new se,Zs=new se,Qs=new se,Ar=new se,Xo=new se,Rc=new se,Pc=new se,Cr=new se;function Uh(n,e,t,s,a){for(let c=0,u=n.length-3;c<=u;c+=3){Cr.fromArray(n,c);const d=a.x*Math.abs(Cr.x)+a.y*Math.abs(Cr.y)+a.z*Math.abs(Cr.z),f=e.dot(Cr),p=t.dot(Cr),g=s.dot(Cr);if(Math.max(-Math.max(f,p,g),Math.min(f,p,g))>d)return!1}return!0}const rb=new ml,qo=new se,Fh=new se;class Bp{constructor(e=new se,t=-1){this.isSphere=!0,this.center=e,this.radius=t}set(e,t){return this.center.copy(e),this.radius=t,this}setFromPoints(e,t){const s=this.center;t!==void 0?s.copy(t):rb.setFromPoints(e).getCenter(s);let a=0;for(let c=0,u=e.length;c<u;c++)a=Math.max(a,s.distanceToSquared(e[c]));return this.radius=Math.sqrt(a),this}copy(e){return this.center.copy(e.center),this.radius=e.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(e){return e.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(e){return e.distanceTo(this.center)-this.radius}intersectsSphere(e){const t=this.radius+e.radius;return e.center.distanceToSquared(this.center)<=t*t}intersectsBox(e){return e.intersectsSphere(this)}intersectsPlane(e){return Math.abs(e.distanceToPoint(this.center))<=this.radius}clampPoint(e,t){const s=this.center.distanceToSquared(e);return t.copy(e),s>this.radius*this.radius&&(t.sub(this.center).normalize(),t.multiplyScalar(this.radius).add(this.center)),t}getBoundingBox(e){return this.isEmpty()?(e.makeEmpty(),e):(e.set(this.center,this.center),e.expandByScalar(this.radius),e)}applyMatrix4(e){return this.center.applyMatrix4(e),this.radius=this.radius*e.getMaxScaleOnAxis(),this}translate(e){return this.center.add(e),this}expandByPoint(e){if(this.isEmpty())return this.center.copy(e),this.radius=0,this;qo.subVectors(e,this.center);const t=qo.lengthSq();if(t>this.radius*this.radius){const s=Math.sqrt(t),a=(s-this.radius)*.5;this.center.addScaledVector(qo,a/s),this.radius+=a}return this}union(e){return e.isEmpty()?this:this.isEmpty()?(this.copy(e),this):(this.center.equals(e.center)===!0?this.radius=Math.max(this.radius,e.radius):(Fh.subVectors(e.center,this.center).setLength(e.radius),this.expandByPoint(qo.copy(e.center).add(Fh)),this.expandByPoint(qo.copy(e.center).sub(Fh))),this)}equals(e){return e.center.equals(this.center)&&e.radius===this.radius}clone(){return new this.constructor().copy(this)}}const hs=new se,Oh=new se,kc=new se,Js=new se,jh=new se,Lc=new se,zh=new se;class ab{constructor(e=new se,t=new se(0,0,-1)){this.origin=e,this.direction=t}set(e,t){return this.origin.copy(e),this.direction.copy(t),this}copy(e){return this.origin.copy(e.origin),this.direction.copy(e.direction),this}at(e,t){return t.copy(this.origin).addScaledVector(this.direction,e)}lookAt(e){return this.direction.copy(e).sub(this.origin).normalize(),this}recast(e){return this.origin.copy(this.at(e,hs)),this}closestPointToPoint(e,t){t.subVectors(e,this.origin);const s=t.dot(this.direction);return s<0?t.copy(this.origin):t.copy(this.origin).addScaledVector(this.direction,s)}distanceToPoint(e){return Math.sqrt(this.distanceSqToPoint(e))}distanceSqToPoint(e){const t=hs.subVectors(e,this.origin).dot(this.direction);return t<0?this.origin.distanceToSquared(e):(hs.copy(this.origin).addScaledVector(this.direction,t),hs.distanceToSquared(e))}distanceSqToSegment(e,t,s,a){Oh.copy(e).add(t).multiplyScalar(.5),kc.copy(t).sub(e).normalize(),Js.copy(this.origin).sub(Oh);const c=e.distanceTo(t)*.5,u=-this.direction.dot(kc),d=Js.dot(this.direction),f=-Js.dot(kc),p=Js.lengthSq(),g=Math.abs(1-u*u);let v,x,y,w;if(g>0)if(v=u*f-d,x=u*d-f,w=c*g,v>=0)if(x>=-w)if(x<=w){const E=1/g;v*=E,x*=E,y=v*(v+u*x+2*d)+x*(u*v+x+2*f)+p}else x=c,v=Math.max(0,-(u*x+d)),y=-v*v+x*(x+2*f)+p;else x=-c,v=Math.max(0,-(u*x+d)),y=-v*v+x*(x+2*f)+p;else x<=-w?(v=Math.max(0,-(-u*c+d)),x=v>0?-c:Math.min(Math.max(-c,-f),c),y=-v*v+x*(x+2*f)+p):x<=w?(v=0,x=Math.min(Math.max(-c,-f),c),y=x*(x+2*f)+p):(v=Math.max(0,-(u*c+d)),x=v>0?c:Math.min(Math.max(-c,-f),c),y=-v*v+x*(x+2*f)+p);else x=u>0?-c:c,v=Math.max(0,-(u*x+d)),y=-v*v+x*(x+2*f)+p;return s&&s.copy(this.origin).addScaledVector(this.direction,v),a&&a.copy(Oh).addScaledVector(kc,x),y}intersectSphere(e,t){hs.subVectors(e.center,this.origin);const s=hs.dot(this.direction),a=hs.dot(hs)-s*s,c=e.radius*e.radius;if(a>c)return null;const u=Math.sqrt(c-a),d=s-u,f=s+u;return f<0?null:d<0?this.at(f,t):this.at(d,t)}intersectsSphere(e){return this.distanceSqToPoint(e.center)<=e.radius*e.radius}distanceToPlane(e){const t=e.normal.dot(this.direction);if(t===0)return e.distanceToPoint(this.origin)===0?0:null;const s=-(this.origin.dot(e.normal)+e.constant)/t;return s>=0?s:null}intersectPlane(e,t){const s=this.distanceToPlane(e);return s===null?null:this.at(s,t)}intersectsPlane(e){const t=e.distanceToPoint(this.origin);return t===0||e.normal.dot(this.direction)*t<0}intersectBox(e,t){let s,a,c,u,d,f;const p=1/this.direction.x,g=1/this.direction.y,v=1/this.direction.z,x=this.origin;return p>=0?(s=(e.min.x-x.x)*p,a=(e.max.x-x.x)*p):(s=(e.max.x-x.x)*p,a=(e.min.x-x.x)*p),g>=0?(c=(e.min.y-x.y)*g,u=(e.max.y-x.y)*g):(c=(e.max.y-x.y)*g,u=(e.min.y-x.y)*g),s>u||c>a||((c>s||isNaN(s))&&(s=c),(u<a||isNaN(a))&&(a=u),v>=0?(d=(e.min.z-x.z)*v,f=(e.max.z-x.z)*v):(d=(e.max.z-x.z)*v,f=(e.min.z-x.z)*v),s>f||d>a)||((d>s||s!==s)&&(s=d),(f<a||a!==a)&&(a=f),a<0)?null:this.at(s>=0?s:a,t)}intersectsBox(e){return this.intersectBox(e,hs)!==null}intersectTriangle(e,t,s,a,c){jh.subVectors(t,e),Lc.subVectors(s,e),zh.crossVectors(jh,Lc);let u=this.direction.dot(zh),d;if(u>0){if(a)return null;d=1}else if(u<0)d=-1,u=-u;else return null;Js.subVectors(this.origin,e);const f=d*this.direction.dot(Lc.crossVectors(Js,Lc));if(f<0)return null;const p=d*this.direction.dot(jh.cross(Js));if(p<0||f+p>u)return null;const g=-d*Js.dot(zh);return g<0?null:this.at(g/u,c)}applyMatrix4(e){return this.origin.applyMatrix4(e),this.direction.transformDirection(e),this}equals(e){return e.origin.equals(this.origin)&&e.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}}class nn{constructor(e,t,s,a,c,u,d,f,p,g,v,x,y,w,E,_){nn.prototype.isMatrix4=!0,this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],e!==void 0&&this.set(e,t,s,a,c,u,d,f,p,g,v,x,y,w,E,_)}set(e,t,s,a,c,u,d,f,p,g,v,x,y,w,E,_){const M=this.elements;return M[0]=e,M[4]=t,M[8]=s,M[12]=a,M[1]=c,M[5]=u,M[9]=d,M[13]=f,M[2]=p,M[6]=g,M[10]=v,M[14]=x,M[3]=y,M[7]=w,M[11]=E,M[15]=_,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new nn().fromArray(this.elements)}copy(e){const t=this.elements,s=e.elements;return t[0]=s[0],t[1]=s[1],t[2]=s[2],t[3]=s[3],t[4]=s[4],t[5]=s[5],t[6]=s[6],t[7]=s[7],t[8]=s[8],t[9]=s[9],t[10]=s[10],t[11]=s[11],t[12]=s[12],t[13]=s[13],t[14]=s[14],t[15]=s[15],this}copyPosition(e){const t=this.elements,s=e.elements;return t[12]=s[12],t[13]=s[13],t[14]=s[14],this}setFromMatrix3(e){const t=e.elements;return this.set(t[0],t[3],t[6],0,t[1],t[4],t[7],0,t[2],t[5],t[8],0,0,0,0,1),this}extractBasis(e,t,s){return e.setFromMatrixColumn(this,0),t.setFromMatrixColumn(this,1),s.setFromMatrixColumn(this,2),this}makeBasis(e,t,s){return this.set(e.x,t.x,s.x,0,e.y,t.y,s.y,0,e.z,t.z,s.z,0,0,0,0,1),this}extractRotation(e){const t=this.elements,s=e.elements,a=1/Na.setFromMatrixColumn(e,0).length(),c=1/Na.setFromMatrixColumn(e,1).length(),u=1/Na.setFromMatrixColumn(e,2).length();return t[0]=s[0]*a,t[1]=s[1]*a,t[2]=s[2]*a,t[3]=0,t[4]=s[4]*c,t[5]=s[5]*c,t[6]=s[6]*c,t[7]=0,t[8]=s[8]*u,t[9]=s[9]*u,t[10]=s[10]*u,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromEuler(e){const t=this.elements,s=e.x,a=e.y,c=e.z,u=Math.cos(s),d=Math.sin(s),f=Math.cos(a),p=Math.sin(a),g=Math.cos(c),v=Math.sin(c);if(e.order==="XYZ"){const x=u*g,y=u*v,w=d*g,E=d*v;t[0]=f*g,t[4]=-f*v,t[8]=p,t[1]=y+w*p,t[5]=x-E*p,t[9]=-d*f,t[2]=E-x*p,t[6]=w+y*p,t[10]=u*f}else if(e.order==="YXZ"){const x=f*g,y=f*v,w=p*g,E=p*v;t[0]=x+E*d,t[4]=w*d-y,t[8]=u*p,t[1]=u*v,t[5]=u*g,t[9]=-d,t[2]=y*d-w,t[6]=E+x*d,t[10]=u*f}else if(e.order==="ZXY"){const x=f*g,y=f*v,w=p*g,E=p*v;t[0]=x-E*d,t[4]=-u*v,t[8]=w+y*d,t[1]=y+w*d,t[5]=u*g,t[9]=E-x*d,t[2]=-u*p,t[6]=d,t[10]=u*f}else if(e.order==="ZYX"){const x=u*g,y=u*v,w=d*g,E=d*v;t[0]=f*g,t[4]=w*p-y,t[8]=x*p+E,t[1]=f*v,t[5]=E*p+x,t[9]=y*p-w,t[2]=-p,t[6]=d*f,t[10]=u*f}else if(e.order==="YZX"){const x=u*f,y=u*p,w=d*f,E=d*p;t[0]=f*g,t[4]=E-x*v,t[8]=w*v+y,t[1]=v,t[5]=u*g,t[9]=-d*g,t[2]=-p*g,t[6]=y*v+w,t[10]=x-E*v}else if(e.order==="XZY"){const x=u*f,y=u*p,w=d*f,E=d*p;t[0]=f*g,t[4]=-v,t[8]=p*g,t[1]=x*v+E,t[5]=u*g,t[9]=y*v-w,t[2]=w*v-y,t[6]=d*g,t[10]=E*v+x}return t[3]=0,t[7]=0,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromQuaternion(e){return this.compose(ob,e,lb)}lookAt(e,t,s){const a=this.elements;return ii.subVectors(e,t),ii.lengthSq()===0&&(ii.z=1),ii.normalize(),er.crossVectors(s,ii),er.lengthSq()===0&&(Math.abs(s.z)===1?ii.x+=1e-4:ii.z+=1e-4,ii.normalize(),er.crossVectors(s,ii)),er.normalize(),Dc.crossVectors(ii,er),a[0]=er.x,a[4]=Dc.x,a[8]=ii.x,a[1]=er.y,a[5]=Dc.y,a[9]=ii.y,a[2]=er.z,a[6]=Dc.z,a[10]=ii.z,this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const s=e.elements,a=t.elements,c=this.elements,u=s[0],d=s[4],f=s[8],p=s[12],g=s[1],v=s[5],x=s[9],y=s[13],w=s[2],E=s[6],_=s[10],M=s[14],L=s[3],A=s[7],R=s[11],k=s[15],D=a[0],U=a[4],$=a[8],te=a[12],T=a[1],P=a[5],re=a[9],J=a[13],ae=a[2],ve=a[6],V=a[10],de=a[14],z=a[3],ue=a[7],oe=a[11],O=a[15];return c[0]=u*D+d*T+f*ae+p*z,c[4]=u*U+d*P+f*ve+p*ue,c[8]=u*$+d*re+f*V+p*oe,c[12]=u*te+d*J+f*de+p*O,c[1]=g*D+v*T+x*ae+y*z,c[5]=g*U+v*P+x*ve+y*ue,c[9]=g*$+v*re+x*V+y*oe,c[13]=g*te+v*J+x*de+y*O,c[2]=w*D+E*T+_*ae+M*z,c[6]=w*U+E*P+_*ve+M*ue,c[10]=w*$+E*re+_*V+M*oe,c[14]=w*te+E*J+_*de+M*O,c[3]=L*D+A*T+R*ae+k*z,c[7]=L*U+A*P+R*ve+k*ue,c[11]=L*$+A*re+R*V+k*oe,c[15]=L*te+A*J+R*de+k*O,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[4]*=e,t[8]*=e,t[12]*=e,t[1]*=e,t[5]*=e,t[9]*=e,t[13]*=e,t[2]*=e,t[6]*=e,t[10]*=e,t[14]*=e,t[3]*=e,t[7]*=e,t[11]*=e,t[15]*=e,this}determinant(){const e=this.elements,t=e[0],s=e[4],a=e[8],c=e[12],u=e[1],d=e[5],f=e[9],p=e[13],g=e[2],v=e[6],x=e[10],y=e[14],w=e[3],E=e[7],_=e[11],M=e[15];return w*(+c*f*v-a*p*v-c*d*x+s*p*x+a*d*y-s*f*y)+E*(+t*f*y-t*p*x+c*u*x-a*u*y+a*p*g-c*f*g)+_*(+t*p*v-t*d*y-c*u*v+s*u*y+c*d*g-s*p*g)+M*(-a*d*g-t*f*v+t*d*x+a*u*v-s*u*x+s*f*g)}transpose(){const e=this.elements;let t;return t=e[1],e[1]=e[4],e[4]=t,t=e[2],e[2]=e[8],e[8]=t,t=e[6],e[6]=e[9],e[9]=t,t=e[3],e[3]=e[12],e[12]=t,t=e[7],e[7]=e[13],e[13]=t,t=e[11],e[11]=e[14],e[14]=t,this}setPosition(e,t,s){const a=this.elements;return e.isVector3?(a[12]=e.x,a[13]=e.y,a[14]=e.z):(a[12]=e,a[13]=t,a[14]=s),this}invert(){const e=this.elements,t=e[0],s=e[1],a=e[2],c=e[3],u=e[4],d=e[5],f=e[6],p=e[7],g=e[8],v=e[9],x=e[10],y=e[11],w=e[12],E=e[13],_=e[14],M=e[15],L=v*_*p-E*x*p+E*f*y-d*_*y-v*f*M+d*x*M,A=w*x*p-g*_*p-w*f*y+u*_*y+g*f*M-u*x*M,R=g*E*p-w*v*p+w*d*y-u*E*y-g*d*M+u*v*M,k=w*v*f-g*E*f-w*d*x+u*E*x+g*d*_-u*v*_,D=t*L+s*A+a*R+c*k;if(D===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);const U=1/D;return e[0]=L*U,e[1]=(E*x*c-v*_*c-E*a*y+s*_*y+v*a*M-s*x*M)*U,e[2]=(d*_*c-E*f*c+E*a*p-s*_*p-d*a*M+s*f*M)*U,e[3]=(v*f*c-d*x*c-v*a*p+s*x*p+d*a*y-s*f*y)*U,e[4]=A*U,e[5]=(g*_*c-w*x*c+w*a*y-t*_*y-g*a*M+t*x*M)*U,e[6]=(w*f*c-u*_*c-w*a*p+t*_*p+u*a*M-t*f*M)*U,e[7]=(u*x*c-g*f*c+g*a*p-t*x*p-u*a*y+t*f*y)*U,e[8]=R*U,e[9]=(w*v*c-g*E*c-w*s*y+t*E*y+g*s*M-t*v*M)*U,e[10]=(u*E*c-w*d*c+w*s*p-t*E*p-u*s*M+t*d*M)*U,e[11]=(g*d*c-u*v*c-g*s*p+t*v*p+u*s*y-t*d*y)*U,e[12]=k*U,e[13]=(g*E*a-w*v*a+w*s*x-t*E*x-g*s*_+t*v*_)*U,e[14]=(w*d*a-u*E*a-w*s*f+t*E*f+u*s*_-t*d*_)*U,e[15]=(u*v*a-g*d*a+g*s*f-t*v*f-u*s*x+t*d*x)*U,this}scale(e){const t=this.elements,s=e.x,a=e.y,c=e.z;return t[0]*=s,t[4]*=a,t[8]*=c,t[1]*=s,t[5]*=a,t[9]*=c,t[2]*=s,t[6]*=a,t[10]*=c,t[3]*=s,t[7]*=a,t[11]*=c,this}getMaxScaleOnAxis(){const e=this.elements,t=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],s=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],a=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];return Math.sqrt(Math.max(t,s,a))}makeTranslation(e,t,s){return e.isVector3?this.set(1,0,0,e.x,0,1,0,e.y,0,0,1,e.z,0,0,0,1):this.set(1,0,0,e,0,1,0,t,0,0,1,s,0,0,0,1),this}makeRotationX(e){const t=Math.cos(e),s=Math.sin(e);return this.set(1,0,0,0,0,t,-s,0,0,s,t,0,0,0,0,1),this}makeRotationY(e){const t=Math.cos(e),s=Math.sin(e);return this.set(t,0,s,0,0,1,0,0,-s,0,t,0,0,0,0,1),this}makeRotationZ(e){const t=Math.cos(e),s=Math.sin(e);return this.set(t,-s,0,0,s,t,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(e,t){const s=Math.cos(t),a=Math.sin(t),c=1-s,u=e.x,d=e.y,f=e.z,p=c*u,g=c*d;return this.set(p*u+s,p*d-a*f,p*f+a*d,0,p*d+a*f,g*d+s,g*f-a*u,0,p*f-a*d,g*f+a*u,c*f*f+s,0,0,0,0,1),this}makeScale(e,t,s){return this.set(e,0,0,0,0,t,0,0,0,0,s,0,0,0,0,1),this}makeShear(e,t,s,a,c,u){return this.set(1,s,c,0,e,1,u,0,t,a,1,0,0,0,0,1),this}compose(e,t,s){const a=this.elements,c=t._x,u=t._y,d=t._z,f=t._w,p=c+c,g=u+u,v=d+d,x=c*p,y=c*g,w=c*v,E=u*g,_=u*v,M=d*v,L=f*p,A=f*g,R=f*v,k=s.x,D=s.y,U=s.z;return a[0]=(1-(E+M))*k,a[1]=(y+R)*k,a[2]=(w-A)*k,a[3]=0,a[4]=(y-R)*D,a[5]=(1-(x+M))*D,a[6]=(_+L)*D,a[7]=0,a[8]=(w+A)*U,a[9]=(_-L)*U,a[10]=(1-(x+E))*U,a[11]=0,a[12]=e.x,a[13]=e.y,a[14]=e.z,a[15]=1,this}decompose(e,t,s){const a=this.elements;let c=Na.set(a[0],a[1],a[2]).length();const u=Na.set(a[4],a[5],a[6]).length(),d=Na.set(a[8],a[9],a[10]).length();this.determinant()<0&&(c=-c),e.x=a[12],e.y=a[13],e.z=a[14],ki.copy(this);const p=1/c,g=1/u,v=1/d;return ki.elements[0]*=p,ki.elements[1]*=p,ki.elements[2]*=p,ki.elements[4]*=g,ki.elements[5]*=g,ki.elements[6]*=g,ki.elements[8]*=v,ki.elements[9]*=v,ki.elements[10]*=v,t.setFromRotationMatrix(ki),s.x=c,s.y=u,s.z=d,this}makePerspective(e,t,s,a,c,u,d=ys){const f=this.elements,p=2*c/(t-e),g=2*c/(s-a),v=(t+e)/(t-e),x=(s+a)/(s-a);let y,w;if(d===ys)y=-(u+c)/(u-c),w=-2*u*c/(u-c);else if(d===xu)y=-u/(u-c),w=-u*c/(u-c);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+d);return f[0]=p,f[4]=0,f[8]=v,f[12]=0,f[1]=0,f[5]=g,f[9]=x,f[13]=0,f[2]=0,f[6]=0,f[10]=y,f[14]=w,f[3]=0,f[7]=0,f[11]=-1,f[15]=0,this}makeOrthographic(e,t,s,a,c,u,d=ys){const f=this.elements,p=1/(t-e),g=1/(s-a),v=1/(u-c),x=(t+e)*p,y=(s+a)*g;let w,E;if(d===ys)w=(u+c)*v,E=-2*v;else if(d===xu)w=c*v,E=-1*v;else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+d);return f[0]=2*p,f[4]=0,f[8]=0,f[12]=-x,f[1]=0,f[5]=2*g,f[9]=0,f[13]=-y,f[2]=0,f[6]=0,f[10]=E,f[14]=-w,f[3]=0,f[7]=0,f[11]=0,f[15]=1,this}equals(e){const t=this.elements,s=e.elements;for(let a=0;a<16;a++)if(t[a]!==s[a])return!1;return!0}fromArray(e,t=0){for(let s=0;s<16;s++)this.elements[s]=e[s+t];return this}toArray(e=[],t=0){const s=this.elements;return e[t]=s[0],e[t+1]=s[1],e[t+2]=s[2],e[t+3]=s[3],e[t+4]=s[4],e[t+5]=s[5],e[t+6]=s[6],e[t+7]=s[7],e[t+8]=s[8],e[t+9]=s[9],e[t+10]=s[10],e[t+11]=s[11],e[t+12]=s[12],e[t+13]=s[13],e[t+14]=s[14],e[t+15]=s[15],e}}const Na=new se,ki=new nn,ob=new se(0,0,0),lb=new se(1,1,1),er=new se,Dc=new se,ii=new se,g_=new nn,__=new pl;class Ts{constructor(e=0,t=0,s=0,a=Ts.DEFAULT_ORDER){this.isEuler=!0,this._x=e,this._y=t,this._z=s,this._order=a}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get order(){return this._order}set order(e){this._order=e,this._onChangeCallback()}set(e,t,s,a=this._order){return this._x=e,this._y=t,this._z=s,this._order=a,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(e){return this._x=e._x,this._y=e._y,this._z=e._z,this._order=e._order,this._onChangeCallback(),this}setFromRotationMatrix(e,t=this._order,s=!0){const a=e.elements,c=a[0],u=a[4],d=a[8],f=a[1],p=a[5],g=a[9],v=a[2],x=a[6],y=a[10];switch(t){case"XYZ":this._y=Math.asin(Xn(d,-1,1)),Math.abs(d)<.9999999?(this._x=Math.atan2(-g,y),this._z=Math.atan2(-u,c)):(this._x=Math.atan2(x,p),this._z=0);break;case"YXZ":this._x=Math.asin(-Xn(g,-1,1)),Math.abs(g)<.9999999?(this._y=Math.atan2(d,y),this._z=Math.atan2(f,p)):(this._y=Math.atan2(-v,c),this._z=0);break;case"ZXY":this._x=Math.asin(Xn(x,-1,1)),Math.abs(x)<.9999999?(this._y=Math.atan2(-v,y),this._z=Math.atan2(-u,p)):(this._y=0,this._z=Math.atan2(f,c));break;case"ZYX":this._y=Math.asin(-Xn(v,-1,1)),Math.abs(v)<.9999999?(this._x=Math.atan2(x,y),this._z=Math.atan2(f,c)):(this._x=0,this._z=Math.atan2(-u,p));break;case"YZX":this._z=Math.asin(Xn(f,-1,1)),Math.abs(f)<.9999999?(this._x=Math.atan2(-g,p),this._y=Math.atan2(-v,c)):(this._x=0,this._y=Math.atan2(d,y));break;case"XZY":this._z=Math.asin(-Xn(u,-1,1)),Math.abs(u)<.9999999?(this._x=Math.atan2(x,p),this._y=Math.atan2(d,c)):(this._x=Math.atan2(-g,y),this._y=0);break;default:console.warn("THREE.Euler: .setFromRotationMatrix() encountered an unknown order: "+t)}return this._order=t,s===!0&&this._onChangeCallback(),this}setFromQuaternion(e,t,s){return g_.makeRotationFromQuaternion(e),this.setFromRotationMatrix(g_,t,s)}setFromVector3(e,t=this._order){return this.set(e.x,e.y,e.z,t)}reorder(e){return __.setFromEuler(this),this.setFromQuaternion(__,e)}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._order===this._order}fromArray(e){return this._x=e[0],this._y=e[1],this._z=e[2],e[3]!==void 0&&(this._order=e[3]),this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._order,e}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}}Ts.DEFAULT_ORDER="XYZ";class px{constructor(){this.mask=1}set(e){this.mask=(1<<e|0)>>>0}enable(e){this.mask|=1<<e|0}enableAll(){this.mask=-1}toggle(e){this.mask^=1<<e|0}disable(e){this.mask&=~(1<<e|0)}disableAll(){this.mask=0}test(e){return(this.mask&e.mask)!==0}isEnabled(e){return(this.mask&(1<<e|0))!==0}}let cb=0;const v_=new se,Ra=new pl,fs=new nn,Ic=new se,Yo=new se,ub=new se,db=new pl,x_=new se(1,0,0),y_=new se(0,1,0),S_=new se(0,0,1),M_={type:"added"},hb={type:"removed"},Pa={type:"childadded",child:null},Bh={type:"childremoved",child:null};class oi extends ro{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:cb++}),this.uuid=fl(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=oi.DEFAULT_UP.clone();const e=new se,t=new Ts,s=new pl,a=new se(1,1,1);function c(){s.setFromEuler(t,!1)}function u(){t.setFromQuaternion(s,void 0,!1)}t._onChange(c),s._onChange(u),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:e},rotation:{configurable:!0,enumerable:!0,value:t},quaternion:{configurable:!0,enumerable:!0,value:s},scale:{configurable:!0,enumerable:!0,value:a},modelViewMatrix:{value:new nn},normalMatrix:{value:new dt}}),this.matrix=new nn,this.matrixWorld=new nn,this.matrixAutoUpdate=oi.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=oi.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new px,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.userData={}}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(e){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(e),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(e){return this.quaternion.premultiply(e),this}setRotationFromAxisAngle(e,t){this.quaternion.setFromAxisAngle(e,t)}setRotationFromEuler(e){this.quaternion.setFromEuler(e,!0)}setRotationFromMatrix(e){this.quaternion.setFromRotationMatrix(e)}setRotationFromQuaternion(e){this.quaternion.copy(e)}rotateOnAxis(e,t){return Ra.setFromAxisAngle(e,t),this.quaternion.multiply(Ra),this}rotateOnWorldAxis(e,t){return Ra.setFromAxisAngle(e,t),this.quaternion.premultiply(Ra),this}rotateX(e){return this.rotateOnAxis(x_,e)}rotateY(e){return this.rotateOnAxis(y_,e)}rotateZ(e){return this.rotateOnAxis(S_,e)}translateOnAxis(e,t){return v_.copy(e).applyQuaternion(this.quaternion),this.position.add(v_.multiplyScalar(t)),this}translateX(e){return this.translateOnAxis(x_,e)}translateY(e){return this.translateOnAxis(y_,e)}translateZ(e){return this.translateOnAxis(S_,e)}localToWorld(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(this.matrixWorld)}worldToLocal(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(fs.copy(this.matrixWorld).invert())}lookAt(e,t,s){e.isVector3?Ic.copy(e):Ic.set(e,t,s);const a=this.parent;this.updateWorldMatrix(!0,!1),Yo.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?fs.lookAt(Yo,Ic,this.up):fs.lookAt(Ic,Yo,this.up),this.quaternion.setFromRotationMatrix(fs),a&&(fs.extractRotation(a.matrixWorld),Ra.setFromRotationMatrix(fs),this.quaternion.premultiply(Ra.invert()))}add(e){if(arguments.length>1){for(let t=0;t<arguments.length;t++)this.add(arguments[t]);return this}return e===this?(console.error("THREE.Object3D.add: object can't be added as a child of itself.",e),this):(e&&e.isObject3D?(e.removeFromParent(),e.parent=this,this.children.push(e),e.dispatchEvent(M_),Pa.child=e,this.dispatchEvent(Pa),Pa.child=null):console.error("THREE.Object3D.add: object not an instance of THREE.Object3D.",e),this)}remove(e){if(arguments.length>1){for(let s=0;s<arguments.length;s++)this.remove(arguments[s]);return this}const t=this.children.indexOf(e);return t!==-1&&(e.parent=null,this.children.splice(t,1),e.dispatchEvent(hb),Bh.child=e,this.dispatchEvent(Bh),Bh.child=null),this}removeFromParent(){const e=this.parent;return e!==null&&e.remove(this),this}clear(){return this.remove(...this.children)}attach(e){return this.updateWorldMatrix(!0,!1),fs.copy(this.matrixWorld).invert(),e.parent!==null&&(e.parent.updateWorldMatrix(!0,!1),fs.multiply(e.parent.matrixWorld)),e.applyMatrix4(fs),e.removeFromParent(),e.parent=this,this.children.push(e),e.updateWorldMatrix(!1,!0),e.dispatchEvent(M_),Pa.child=e,this.dispatchEvent(Pa),Pa.child=null,this}getObjectById(e){return this.getObjectByProperty("id",e)}getObjectByName(e){return this.getObjectByProperty("name",e)}getObjectByProperty(e,t){if(this[e]===t)return this;for(let s=0,a=this.children.length;s<a;s++){const u=this.children[s].getObjectByProperty(e,t);if(u!==void 0)return u}}getObjectsByProperty(e,t,s=[]){this[e]===t&&s.push(this);const a=this.children;for(let c=0,u=a.length;c<u;c++)a[c].getObjectsByProperty(e,t,s);return s}getWorldPosition(e){return this.updateWorldMatrix(!0,!1),e.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Yo,e,ub),e}getWorldScale(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Yo,db,e),e}getWorldDirection(e){this.updateWorldMatrix(!0,!1);const t=this.matrixWorld.elements;return e.set(t[8],t[9],t[10]).normalize()}raycast(){}traverse(e){e(this);const t=this.children;for(let s=0,a=t.length;s<a;s++)t[s].traverse(e)}traverseVisible(e){if(this.visible===!1)return;e(this);const t=this.children;for(let s=0,a=t.length;s<a;s++)t[s].traverseVisible(e)}traverseAncestors(e){const t=this.parent;t!==null&&(e(t),t.traverseAncestors(e))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale),this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(e){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||e)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,e=!0);const t=this.children;for(let s=0,a=t.length;s<a;s++)t[s].updateMatrixWorld(e)}updateWorldMatrix(e,t){const s=this.parent;if(e===!0&&s!==null&&s.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),t===!0){const a=this.children;for(let c=0,u=a.length;c<u;c++)a[c].updateWorldMatrix(!1,!0)}}toJSON(e){const t=e===void 0||typeof e=="string",s={};t&&(e={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},s.metadata={version:4.6,type:"Object",generator:"Object3D.toJSON"});const a={};a.uuid=this.uuid,a.type=this.type,this.name!==""&&(a.name=this.name),this.castShadow===!0&&(a.castShadow=!0),this.receiveShadow===!0&&(a.receiveShadow=!0),this.visible===!1&&(a.visible=!1),this.frustumCulled===!1&&(a.frustumCulled=!1),this.renderOrder!==0&&(a.renderOrder=this.renderOrder),Object.keys(this.userData).length>0&&(a.userData=this.userData),a.layers=this.layers.mask,a.matrix=this.matrix.toArray(),a.up=this.up.toArray(),this.matrixAutoUpdate===!1&&(a.matrixAutoUpdate=!1),this.isInstancedMesh&&(a.type="InstancedMesh",a.count=this.count,a.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(a.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(a.type="BatchedMesh",a.perObjectFrustumCulled=this.perObjectFrustumCulled,a.sortObjects=this.sortObjects,a.drawRanges=this._drawRanges,a.reservedRanges=this._reservedRanges,a.visibility=this._visibility,a.active=this._active,a.bounds=this._bounds.map(d=>({boxInitialized:d.boxInitialized,boxMin:d.box.min.toArray(),boxMax:d.box.max.toArray(),sphereInitialized:d.sphereInitialized,sphereRadius:d.sphere.radius,sphereCenter:d.sphere.center.toArray()})),a.maxInstanceCount=this._maxInstanceCount,a.maxVertexCount=this._maxVertexCount,a.maxIndexCount=this._maxIndexCount,a.geometryInitialized=this._geometryInitialized,a.geometryCount=this._geometryCount,a.matricesTexture=this._matricesTexture.toJSON(e),this._colorsTexture!==null&&(a.colorsTexture=this._colorsTexture.toJSON(e)),this.boundingSphere!==null&&(a.boundingSphere={center:a.boundingSphere.center.toArray(),radius:a.boundingSphere.radius}),this.boundingBox!==null&&(a.boundingBox={min:a.boundingBox.min.toArray(),max:a.boundingBox.max.toArray()}));function c(d,f){return d[f.uuid]===void 0&&(d[f.uuid]=f.toJSON(e)),f.uuid}if(this.isScene)this.background&&(this.background.isColor?a.background=this.background.toJSON():this.background.isTexture&&(a.background=this.background.toJSON(e).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(a.environment=this.environment.toJSON(e).uuid);else if(this.isMesh||this.isLine||this.isPoints){a.geometry=c(e.geometries,this.geometry);const d=this.geometry.parameters;if(d!==void 0&&d.shapes!==void 0){const f=d.shapes;if(Array.isArray(f))for(let p=0,g=f.length;p<g;p++){const v=f[p];c(e.shapes,v)}else c(e.shapes,f)}}if(this.isSkinnedMesh&&(a.bindMode=this.bindMode,a.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(c(e.skeletons,this.skeleton),a.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){const d=[];for(let f=0,p=this.material.length;f<p;f++)d.push(c(e.materials,this.material[f]));a.material=d}else a.material=c(e.materials,this.material);if(this.children.length>0){a.children=[];for(let d=0;d<this.children.length;d++)a.children.push(this.children[d].toJSON(e).object)}if(this.animations.length>0){a.animations=[];for(let d=0;d<this.animations.length;d++){const f=this.animations[d];a.animations.push(c(e.animations,f))}}if(t){const d=u(e.geometries),f=u(e.materials),p=u(e.textures),g=u(e.images),v=u(e.shapes),x=u(e.skeletons),y=u(e.animations),w=u(e.nodes);d.length>0&&(s.geometries=d),f.length>0&&(s.materials=f),p.length>0&&(s.textures=p),g.length>0&&(s.images=g),v.length>0&&(s.shapes=v),x.length>0&&(s.skeletons=x),y.length>0&&(s.animations=y),w.length>0&&(s.nodes=w)}return s.object=a,s;function u(d){const f=[];for(const p in d){const g=d[p];delete g.metadata,f.push(g)}return f}}clone(e){return new this.constructor().copy(this,e)}copy(e,t=!0){if(this.name=e.name,this.up.copy(e.up),this.position.copy(e.position),this.rotation.order=e.rotation.order,this.quaternion.copy(e.quaternion),this.scale.copy(e.scale),this.matrix.copy(e.matrix),this.matrixWorld.copy(e.matrixWorld),this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrixWorldAutoUpdate=e.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=e.matrixWorldNeedsUpdate,this.layers.mask=e.layers.mask,this.visible=e.visible,this.castShadow=e.castShadow,this.receiveShadow=e.receiveShadow,this.frustumCulled=e.frustumCulled,this.renderOrder=e.renderOrder,this.animations=e.animations.slice(),this.userData=JSON.parse(JSON.stringify(e.userData)),t===!0)for(let s=0;s<e.children.length;s++){const a=e.children[s];this.add(a.clone())}return this}}oi.DEFAULT_UP=new se(0,1,0);oi.DEFAULT_MATRIX_AUTO_UPDATE=!0;oi.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;const Li=new se,ps=new se,Hh=new se,ms=new se,ka=new se,La=new se,E_=new se,Vh=new se,Gh=new se,Wh=new se,$h=new Qt,Xh=new Qt,qh=new Qt;class Ii{constructor(e=new se,t=new se,s=new se){this.a=e,this.b=t,this.c=s}static getNormal(e,t,s,a){a.subVectors(s,t),Li.subVectors(e,t),a.cross(Li);const c=a.lengthSq();return c>0?a.multiplyScalar(1/Math.sqrt(c)):a.set(0,0,0)}static getBarycoord(e,t,s,a,c){Li.subVectors(a,t),ps.subVectors(s,t),Hh.subVectors(e,t);const u=Li.dot(Li),d=Li.dot(ps),f=Li.dot(Hh),p=ps.dot(ps),g=ps.dot(Hh),v=u*p-d*d;if(v===0)return c.set(0,0,0),null;const x=1/v,y=(p*f-d*g)*x,w=(u*g-d*f)*x;return c.set(1-y-w,w,y)}static containsPoint(e,t,s,a){return this.getBarycoord(e,t,s,a,ms)===null?!1:ms.x>=0&&ms.y>=0&&ms.x+ms.y<=1}static getInterpolation(e,t,s,a,c,u,d,f){return this.getBarycoord(e,t,s,a,ms)===null?(f.x=0,f.y=0,"z"in f&&(f.z=0),"w"in f&&(f.w=0),null):(f.setScalar(0),f.addScaledVector(c,ms.x),f.addScaledVector(u,ms.y),f.addScaledVector(d,ms.z),f)}static getInterpolatedAttribute(e,t,s,a,c,u){return $h.setScalar(0),Xh.setScalar(0),qh.setScalar(0),$h.fromBufferAttribute(e,t),Xh.fromBufferAttribute(e,s),qh.fromBufferAttribute(e,a),u.setScalar(0),u.addScaledVector($h,c.x),u.addScaledVector(Xh,c.y),u.addScaledVector(qh,c.z),u}static isFrontFacing(e,t,s,a){return Li.subVectors(s,t),ps.subVectors(e,t),Li.cross(ps).dot(a)<0}set(e,t,s){return this.a.copy(e),this.b.copy(t),this.c.copy(s),this}setFromPointsAndIndices(e,t,s,a){return this.a.copy(e[t]),this.b.copy(e[s]),this.c.copy(e[a]),this}setFromAttributeAndIndices(e,t,s,a){return this.a.fromBufferAttribute(e,t),this.b.fromBufferAttribute(e,s),this.c.fromBufferAttribute(e,a),this}clone(){return new this.constructor().copy(this)}copy(e){return this.a.copy(e.a),this.b.copy(e.b),this.c.copy(e.c),this}getArea(){return Li.subVectors(this.c,this.b),ps.subVectors(this.a,this.b),Li.cross(ps).length()*.5}getMidpoint(e){return e.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(e){return Ii.getNormal(this.a,this.b,this.c,e)}getPlane(e){return e.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(e,t){return Ii.getBarycoord(e,this.a,this.b,this.c,t)}getInterpolation(e,t,s,a,c){return Ii.getInterpolation(e,this.a,this.b,this.c,t,s,a,c)}containsPoint(e){return Ii.containsPoint(e,this.a,this.b,this.c)}isFrontFacing(e){return Ii.isFrontFacing(this.a,this.b,this.c,e)}intersectsBox(e){return e.intersectsTriangle(this)}closestPointToPoint(e,t){const s=this.a,a=this.b,c=this.c;let u,d;ka.subVectors(a,s),La.subVectors(c,s),Vh.subVectors(e,s);const f=ka.dot(Vh),p=La.dot(Vh);if(f<=0&&p<=0)return t.copy(s);Gh.subVectors(e,a);const g=ka.dot(Gh),v=La.dot(Gh);if(g>=0&&v<=g)return t.copy(a);const x=f*v-g*p;if(x<=0&&f>=0&&g<=0)return u=f/(f-g),t.copy(s).addScaledVector(ka,u);Wh.subVectors(e,c);const y=ka.dot(Wh),w=La.dot(Wh);if(w>=0&&y<=w)return t.copy(c);const E=y*p-f*w;if(E<=0&&p>=0&&w<=0)return d=p/(p-w),t.copy(s).addScaledVector(La,d);const _=g*w-y*v;if(_<=0&&v-g>=0&&y-w>=0)return E_.subVectors(c,a),d=(v-g)/(v-g+(y-w)),t.copy(a).addScaledVector(E_,d);const M=1/(_+E+x);return u=E*M,d=x*M,t.copy(s).addScaledVector(ka,u).addScaledVector(La,d)}equals(e){return e.a.equals(this.a)&&e.b.equals(this.b)&&e.c.equals(this.c)}}const mx={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},tr={h:0,s:0,l:0},Uc={h:0,s:0,l:0};function Yh(n,e,t){return t<0&&(t+=1),t>1&&(t-=1),t<1/6?n+(e-n)*6*t:t<1/2?e:t<2/3?n+(e-n)*6*(2/3-t):n}class Pt{constructor(e,t,s){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(e,t,s)}set(e,t,s){if(t===void 0&&s===void 0){const a=e;a&&a.isColor?this.copy(a):typeof a=="number"?this.setHex(a):typeof a=="string"&&this.setStyle(a)}else this.setRGB(e,t,s);return this}setScalar(e){return this.r=e,this.g=e,this.b=e,this}setHex(e,t=$i){return e=Math.floor(e),this.r=(e>>16&255)/255,this.g=(e>>8&255)/255,this.b=(e&255)/255,Nt.toWorkingColorSpace(this,t),this}setRGB(e,t,s,a=Nt.workingColorSpace){return this.r=e,this.g=t,this.b=s,Nt.toWorkingColorSpace(this,a),this}setHSL(e,t,s,a=Nt.workingColorSpace){if(e=qT(e,1),t=Xn(t,0,1),s=Xn(s,0,1),t===0)this.r=this.g=this.b=s;else{const c=s<=.5?s*(1+t):s+t-s*t,u=2*s-c;this.r=Yh(u,c,e+1/3),this.g=Yh(u,c,e),this.b=Yh(u,c,e-1/3)}return Nt.toWorkingColorSpace(this,a),this}setStyle(e,t=$i){function s(c){c!==void 0&&parseFloat(c)<1&&console.warn("THREE.Color: Alpha component of "+e+" will be ignored.")}let a;if(a=/^(\w+)\(([^\)]*)\)/.exec(e)){let c;const u=a[1],d=a[2];switch(u){case"rgb":case"rgba":if(c=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return s(c[4]),this.setRGB(Math.min(255,parseInt(c[1],10))/255,Math.min(255,parseInt(c[2],10))/255,Math.min(255,parseInt(c[3],10))/255,t);if(c=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return s(c[4]),this.setRGB(Math.min(100,parseInt(c[1],10))/100,Math.min(100,parseInt(c[2],10))/100,Math.min(100,parseInt(c[3],10))/100,t);break;case"hsl":case"hsla":if(c=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return s(c[4]),this.setHSL(parseFloat(c[1])/360,parseFloat(c[2])/100,parseFloat(c[3])/100,t);break;default:console.warn("THREE.Color: Unknown color model "+e)}}else if(a=/^\#([A-Fa-f\d]+)$/.exec(e)){const c=a[1],u=c.length;if(u===3)return this.setRGB(parseInt(c.charAt(0),16)/15,parseInt(c.charAt(1),16)/15,parseInt(c.charAt(2),16)/15,t);if(u===6)return this.setHex(parseInt(c,16),t);console.warn("THREE.Color: Invalid hex color "+e)}else if(e&&e.length>0)return this.setColorName(e,t);return this}setColorName(e,t=$i){const s=mx[e.toLowerCase()];return s!==void 0?this.setHex(s,t):console.warn("THREE.Color: Unknown color "+e),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(e){return this.r=e.r,this.g=e.g,this.b=e.b,this}copySRGBToLinear(e){return this.r=Ga(e.r),this.g=Ga(e.g),this.b=Ga(e.b),this}copyLinearToSRGB(e){return this.r=Lh(e.r),this.g=Lh(e.g),this.b=Lh(e.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(e=$i){return Nt.fromWorkingColorSpace(Rn.copy(this),e),Math.round(Xn(Rn.r*255,0,255))*65536+Math.round(Xn(Rn.g*255,0,255))*256+Math.round(Xn(Rn.b*255,0,255))}getHexString(e=$i){return("000000"+this.getHex(e).toString(16)).slice(-6)}getHSL(e,t=Nt.workingColorSpace){Nt.fromWorkingColorSpace(Rn.copy(this),t);const s=Rn.r,a=Rn.g,c=Rn.b,u=Math.max(s,a,c),d=Math.min(s,a,c);let f,p;const g=(d+u)/2;if(d===u)f=0,p=0;else{const v=u-d;switch(p=g<=.5?v/(u+d):v/(2-u-d),u){case s:f=(a-c)/v+(a<c?6:0);break;case a:f=(c-s)/v+2;break;case c:f=(s-a)/v+4;break}f/=6}return e.h=f,e.s=p,e.l=g,e}getRGB(e,t=Nt.workingColorSpace){return Nt.fromWorkingColorSpace(Rn.copy(this),t),e.r=Rn.r,e.g=Rn.g,e.b=Rn.b,e}getStyle(e=$i){Nt.fromWorkingColorSpace(Rn.copy(this),e);const t=Rn.r,s=Rn.g,a=Rn.b;return e!==$i?`color(${e} ${t.toFixed(3)} ${s.toFixed(3)} ${a.toFixed(3)})`:`rgb(${Math.round(t*255)},${Math.round(s*255)},${Math.round(a*255)})`}offsetHSL(e,t,s){return this.getHSL(tr),this.setHSL(tr.h+e,tr.s+t,tr.l+s)}add(e){return this.r+=e.r,this.g+=e.g,this.b+=e.b,this}addColors(e,t){return this.r=e.r+t.r,this.g=e.g+t.g,this.b=e.b+t.b,this}addScalar(e){return this.r+=e,this.g+=e,this.b+=e,this}sub(e){return this.r=Math.max(0,this.r-e.r),this.g=Math.max(0,this.g-e.g),this.b=Math.max(0,this.b-e.b),this}multiply(e){return this.r*=e.r,this.g*=e.g,this.b*=e.b,this}multiplyScalar(e){return this.r*=e,this.g*=e,this.b*=e,this}lerp(e,t){return this.r+=(e.r-this.r)*t,this.g+=(e.g-this.g)*t,this.b+=(e.b-this.b)*t,this}lerpColors(e,t,s){return this.r=e.r+(t.r-e.r)*s,this.g=e.g+(t.g-e.g)*s,this.b=e.b+(t.b-e.b)*s,this}lerpHSL(e,t){this.getHSL(tr),e.getHSL(Uc);const s=Ph(tr.h,Uc.h,t),a=Ph(tr.s,Uc.s,t),c=Ph(tr.l,Uc.l,t);return this.setHSL(s,a,c),this}setFromVector3(e){return this.r=e.x,this.g=e.y,this.b=e.z,this}applyMatrix3(e){const t=this.r,s=this.g,a=this.b,c=e.elements;return this.r=c[0]*t+c[3]*s+c[6]*a,this.g=c[1]*t+c[4]*s+c[7]*a,this.b=c[2]*t+c[5]*s+c[8]*a,this}equals(e){return e.r===this.r&&e.g===this.g&&e.b===this.b}fromArray(e,t=0){return this.r=e[t],this.g=e[t+1],this.b=e[t+2],this}toArray(e=[],t=0){return e[t]=this.r,e[t+1]=this.g,e[t+2]=this.b,e}fromBufferAttribute(e,t){return this.r=e.getX(t),this.g=e.getY(t),this.b=e.getZ(t),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}}const Rn=new Pt;Pt.NAMES=mx;let fb=0;class Ou extends ro{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:fb++}),this.uuid=fl(),this.name="",this.type="Material",this.blending=Ha,this.side=ur,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=Sf,this.blendDst=Mf,this.blendEquation=Ir,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new Pt(0,0,0),this.blendAlpha=0,this.depthFunc=Xa,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=c_,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=wa,this.stencilZFail=wa,this.stencilZPass=wa,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(e){this._alphaTest>0!=e>0&&this.version++,this._alphaTest=e}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(e){if(e!==void 0)for(const t in e){const s=e[t];if(s===void 0){console.warn(`THREE.Material: parameter '${t}' has value of undefined.`);continue}const a=this[t];if(a===void 0){console.warn(`THREE.Material: '${t}' is not a property of THREE.${this.type}.`);continue}a&&a.isColor?a.set(s):a&&a.isVector3&&s&&s.isVector3?a.copy(s):this[t]=s}}toJSON(e){const t=e===void 0||typeof e=="string";t&&(e={textures:{},images:{}});const s={metadata:{version:4.6,type:"Material",generator:"Material.toJSON"}};s.uuid=this.uuid,s.type=this.type,this.name!==""&&(s.name=this.name),this.color&&this.color.isColor&&(s.color=this.color.getHex()),this.roughness!==void 0&&(s.roughness=this.roughness),this.metalness!==void 0&&(s.metalness=this.metalness),this.sheen!==void 0&&(s.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(s.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(s.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(s.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&this.emissiveIntensity!==1&&(s.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(s.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(s.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(s.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(s.shininess=this.shininess),this.clearcoat!==void 0&&(s.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(s.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(s.clearcoatMap=this.clearcoatMap.toJSON(e).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(s.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(e).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(s.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(e).uuid,s.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.dispersion!==void 0&&(s.dispersion=this.dispersion),this.iridescence!==void 0&&(s.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(s.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(s.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(s.iridescenceMap=this.iridescenceMap.toJSON(e).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(s.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(e).uuid),this.anisotropy!==void 0&&(s.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(s.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(s.anisotropyMap=this.anisotropyMap.toJSON(e).uuid),this.map&&this.map.isTexture&&(s.map=this.map.toJSON(e).uuid),this.matcap&&this.matcap.isTexture&&(s.matcap=this.matcap.toJSON(e).uuid),this.alphaMap&&this.alphaMap.isTexture&&(s.alphaMap=this.alphaMap.toJSON(e).uuid),this.lightMap&&this.lightMap.isTexture&&(s.lightMap=this.lightMap.toJSON(e).uuid,s.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(s.aoMap=this.aoMap.toJSON(e).uuid,s.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(s.bumpMap=this.bumpMap.toJSON(e).uuid,s.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(s.normalMap=this.normalMap.toJSON(e).uuid,s.normalMapType=this.normalMapType,s.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(s.displacementMap=this.displacementMap.toJSON(e).uuid,s.displacementScale=this.displacementScale,s.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(s.roughnessMap=this.roughnessMap.toJSON(e).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(s.metalnessMap=this.metalnessMap.toJSON(e).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(s.emissiveMap=this.emissiveMap.toJSON(e).uuid),this.specularMap&&this.specularMap.isTexture&&(s.specularMap=this.specularMap.toJSON(e).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(s.specularIntensityMap=this.specularIntensityMap.toJSON(e).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(s.specularColorMap=this.specularColorMap.toJSON(e).uuid),this.envMap&&this.envMap.isTexture&&(s.envMap=this.envMap.toJSON(e).uuid,this.combine!==void 0&&(s.combine=this.combine)),this.envMapRotation!==void 0&&(s.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(s.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(s.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(s.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(s.gradientMap=this.gradientMap.toJSON(e).uuid),this.transmission!==void 0&&(s.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(s.transmissionMap=this.transmissionMap.toJSON(e).uuid),this.thickness!==void 0&&(s.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(s.thicknessMap=this.thicknessMap.toJSON(e).uuid),this.attenuationDistance!==void 0&&this.attenuationDistance!==1/0&&(s.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(s.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(s.size=this.size),this.shadowSide!==null&&(s.shadowSide=this.shadowSide),this.sizeAttenuation!==void 0&&(s.sizeAttenuation=this.sizeAttenuation),this.blending!==Ha&&(s.blending=this.blending),this.side!==ur&&(s.side=this.side),this.vertexColors===!0&&(s.vertexColors=!0),this.opacity<1&&(s.opacity=this.opacity),this.transparent===!0&&(s.transparent=!0),this.blendSrc!==Sf&&(s.blendSrc=this.blendSrc),this.blendDst!==Mf&&(s.blendDst=this.blendDst),this.blendEquation!==Ir&&(s.blendEquation=this.blendEquation),this.blendSrcAlpha!==null&&(s.blendSrcAlpha=this.blendSrcAlpha),this.blendDstAlpha!==null&&(s.blendDstAlpha=this.blendDstAlpha),this.blendEquationAlpha!==null&&(s.blendEquationAlpha=this.blendEquationAlpha),this.blendColor&&this.blendColor.isColor&&(s.blendColor=this.blendColor.getHex()),this.blendAlpha!==0&&(s.blendAlpha=this.blendAlpha),this.depthFunc!==Xa&&(s.depthFunc=this.depthFunc),this.depthTest===!1&&(s.depthTest=this.depthTest),this.depthWrite===!1&&(s.depthWrite=this.depthWrite),this.colorWrite===!1&&(s.colorWrite=this.colorWrite),this.stencilWriteMask!==255&&(s.stencilWriteMask=this.stencilWriteMask),this.stencilFunc!==c_&&(s.stencilFunc=this.stencilFunc),this.stencilRef!==0&&(s.stencilRef=this.stencilRef),this.stencilFuncMask!==255&&(s.stencilFuncMask=this.stencilFuncMask),this.stencilFail!==wa&&(s.stencilFail=this.stencilFail),this.stencilZFail!==wa&&(s.stencilZFail=this.stencilZFail),this.stencilZPass!==wa&&(s.stencilZPass=this.stencilZPass),this.stencilWrite===!0&&(s.stencilWrite=this.stencilWrite),this.rotation!==void 0&&this.rotation!==0&&(s.rotation=this.rotation),this.polygonOffset===!0&&(s.polygonOffset=!0),this.polygonOffsetFactor!==0&&(s.polygonOffsetFactor=this.polygonOffsetFactor),this.polygonOffsetUnits!==0&&(s.polygonOffsetUnits=this.polygonOffsetUnits),this.linewidth!==void 0&&this.linewidth!==1&&(s.linewidth=this.linewidth),this.dashSize!==void 0&&(s.dashSize=this.dashSize),this.gapSize!==void 0&&(s.gapSize=this.gapSize),this.scale!==void 0&&(s.scale=this.scale),this.dithering===!0&&(s.dithering=!0),this.alphaTest>0&&(s.alphaTest=this.alphaTest),this.alphaHash===!0&&(s.alphaHash=!0),this.alphaToCoverage===!0&&(s.alphaToCoverage=!0),this.premultipliedAlpha===!0&&(s.premultipliedAlpha=!0),this.forceSinglePass===!0&&(s.forceSinglePass=!0),this.wireframe===!0&&(s.wireframe=!0),this.wireframeLinewidth>1&&(s.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!=="round"&&(s.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!=="round"&&(s.wireframeLinejoin=this.wireframeLinejoin),this.flatShading===!0&&(s.flatShading=!0),this.visible===!1&&(s.visible=!1),this.toneMapped===!1&&(s.toneMapped=!1),this.fog===!1&&(s.fog=!1),Object.keys(this.userData).length>0&&(s.userData=this.userData);function a(c){const u=[];for(const d in c){const f=c[d];delete f.metadata,u.push(f)}return u}if(t){const c=a(e.textures),u=a(e.images);c.length>0&&(s.textures=c),u.length>0&&(s.images=u)}return s}clone(){return new this.constructor().copy(this)}copy(e){this.name=e.name,this.blending=e.blending,this.side=e.side,this.vertexColors=e.vertexColors,this.opacity=e.opacity,this.transparent=e.transparent,this.blendSrc=e.blendSrc,this.blendDst=e.blendDst,this.blendEquation=e.blendEquation,this.blendSrcAlpha=e.blendSrcAlpha,this.blendDstAlpha=e.blendDstAlpha,this.blendEquationAlpha=e.blendEquationAlpha,this.blendColor.copy(e.blendColor),this.blendAlpha=e.blendAlpha,this.depthFunc=e.depthFunc,this.depthTest=e.depthTest,this.depthWrite=e.depthWrite,this.stencilWriteMask=e.stencilWriteMask,this.stencilFunc=e.stencilFunc,this.stencilRef=e.stencilRef,this.stencilFuncMask=e.stencilFuncMask,this.stencilFail=e.stencilFail,this.stencilZFail=e.stencilZFail,this.stencilZPass=e.stencilZPass,this.stencilWrite=e.stencilWrite;const t=e.clippingPlanes;let s=null;if(t!==null){const a=t.length;s=new Array(a);for(let c=0;c!==a;++c)s[c]=t[c].clone()}return this.clippingPlanes=s,this.clipIntersection=e.clipIntersection,this.clipShadows=e.clipShadows,this.shadowSide=e.shadowSide,this.colorWrite=e.colorWrite,this.precision=e.precision,this.polygonOffset=e.polygonOffset,this.polygonOffsetFactor=e.polygonOffsetFactor,this.polygonOffsetUnits=e.polygonOffsetUnits,this.dithering=e.dithering,this.alphaTest=e.alphaTest,this.alphaHash=e.alphaHash,this.alphaToCoverage=e.alphaToCoverage,this.premultipliedAlpha=e.premultipliedAlpha,this.forceSinglePass=e.forceSinglePass,this.visible=e.visible,this.toneMapped=e.toneMapped,this.userData=JSON.parse(JSON.stringify(e.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(e){e===!0&&this.version++}onBuild(){console.warn("Material: onBuild() has been removed.")}}class Hp extends Ou{constructor(e){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new Pt(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ts,this.combine=Qv,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.specularMap=e.specularMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.combine=e.combine,this.reflectivity=e.reflectivity,this.refractionRatio=e.refractionRatio,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.fog=e.fog,this}}const tn=new se,Fc=new At;class Ki{constructor(e,t,s=!1){if(Array.isArray(e))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,this.name="",this.array=e,this.itemSize=t,this.count=e!==void 0?e.length/t:0,this.normalized=s,this.usage=u_,this.updateRanges=[],this.gpuType=xs,this.version=0}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.name=e.name,this.array=new e.array.constructor(e.array),this.itemSize=e.itemSize,this.count=e.count,this.normalized=e.normalized,this.usage=e.usage,this.gpuType=e.gpuType,this}copyAt(e,t,s){e*=this.itemSize,s*=t.itemSize;for(let a=0,c=this.itemSize;a<c;a++)this.array[e+a]=t.array[s+a];return this}copyArray(e){return this.array.set(e),this}applyMatrix3(e){if(this.itemSize===2)for(let t=0,s=this.count;t<s;t++)Fc.fromBufferAttribute(this,t),Fc.applyMatrix3(e),this.setXY(t,Fc.x,Fc.y);else if(this.itemSize===3)for(let t=0,s=this.count;t<s;t++)tn.fromBufferAttribute(this,t),tn.applyMatrix3(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}applyMatrix4(e){for(let t=0,s=this.count;t<s;t++)tn.fromBufferAttribute(this,t),tn.applyMatrix4(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}applyNormalMatrix(e){for(let t=0,s=this.count;t<s;t++)tn.fromBufferAttribute(this,t),tn.applyNormalMatrix(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}transformDirection(e){for(let t=0,s=this.count;t<s;t++)tn.fromBufferAttribute(this,t),tn.transformDirection(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}set(e,t=0){return this.array.set(e,t),this}getComponent(e,t){let s=this.array[e*this.itemSize+t];return this.normalized&&(s=Wo(s,this.array)),s}setComponent(e,t,s){return this.normalized&&(s=Wn(s,this.array)),this.array[e*this.itemSize+t]=s,this}getX(e){let t=this.array[e*this.itemSize];return this.normalized&&(t=Wo(t,this.array)),t}setX(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize]=t,this}getY(e){let t=this.array[e*this.itemSize+1];return this.normalized&&(t=Wo(t,this.array)),t}setY(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+1]=t,this}getZ(e){let t=this.array[e*this.itemSize+2];return this.normalized&&(t=Wo(t,this.array)),t}setZ(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+2]=t,this}getW(e){let t=this.array[e*this.itemSize+3];return this.normalized&&(t=Wo(t,this.array)),t}setW(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+3]=t,this}setXY(e,t,s){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),s=Wn(s,this.array)),this.array[e+0]=t,this.array[e+1]=s,this}setXYZ(e,t,s,a){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),s=Wn(s,this.array),a=Wn(a,this.array)),this.array[e+0]=t,this.array[e+1]=s,this.array[e+2]=a,this}setXYZW(e,t,s,a,c){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),s=Wn(s,this.array),a=Wn(a,this.array),c=Wn(c,this.array)),this.array[e+0]=t,this.array[e+1]=s,this.array[e+2]=a,this.array[e+3]=c,this}onUpload(e){return this.onUploadCallback=e,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){const e={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return this.name!==""&&(e.name=this.name),this.usage!==u_&&(e.usage=this.usage),e}}class gx extends Ki{constructor(e,t,s){super(new Uint16Array(e),t,s)}}class _x extends Ki{constructor(e,t,s){super(new Uint32Array(e),t,s)}}class li extends Ki{constructor(e,t,s){super(new Float32Array(e),t,s)}}let pb=0;const gi=new nn,Kh=new oi,Da=new se,si=new ml,Ko=new ml,gn=new se;class As extends ro{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:pb++}),this.uuid=fl(),this.name="",this.type="BufferGeometry",this.index=null,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={}}getIndex(){return this.index}setIndex(e){return Array.isArray(e)?this.index=new(dx(e)?_x:gx)(e,1):this.index=e,this}getAttribute(e){return this.attributes[e]}setAttribute(e,t){return this.attributes[e]=t,this}deleteAttribute(e){return delete this.attributes[e],this}hasAttribute(e){return this.attributes[e]!==void 0}addGroup(e,t,s=0){this.groups.push({start:e,count:t,materialIndex:s})}clearGroups(){this.groups=[]}setDrawRange(e,t){this.drawRange.start=e,this.drawRange.count=t}applyMatrix4(e){const t=this.attributes.position;t!==void 0&&(t.applyMatrix4(e),t.needsUpdate=!0);const s=this.attributes.normal;if(s!==void 0){const c=new dt().getNormalMatrix(e);s.applyNormalMatrix(c),s.needsUpdate=!0}const a=this.attributes.tangent;return a!==void 0&&(a.transformDirection(e),a.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this}applyQuaternion(e){return gi.makeRotationFromQuaternion(e),this.applyMatrix4(gi),this}rotateX(e){return gi.makeRotationX(e),this.applyMatrix4(gi),this}rotateY(e){return gi.makeRotationY(e),this.applyMatrix4(gi),this}rotateZ(e){return gi.makeRotationZ(e),this.applyMatrix4(gi),this}translate(e,t,s){return gi.makeTranslation(e,t,s),this.applyMatrix4(gi),this}scale(e,t,s){return gi.makeScale(e,t,s),this.applyMatrix4(gi),this}lookAt(e){return Kh.lookAt(e),Kh.updateMatrix(),this.applyMatrix4(Kh.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Da).negate(),this.translate(Da.x,Da.y,Da.z),this}setFromPoints(e){const t=[];for(let s=0,a=e.length;s<a;s++){const c=e[s];t.push(c.x,c.y,c.z||0)}return this.setAttribute("position",new li(t,3)),this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new ml);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new se(-1/0,-1/0,-1/0),new se(1/0,1/0,1/0));return}if(e!==void 0){if(this.boundingBox.setFromBufferAttribute(e),t)for(let s=0,a=t.length;s<a;s++){const c=t[s];si.setFromBufferAttribute(c),this.morphTargetsRelative?(gn.addVectors(this.boundingBox.min,si.min),this.boundingBox.expandByPoint(gn),gn.addVectors(this.boundingBox.max,si.max),this.boundingBox.expandByPoint(gn)):(this.boundingBox.expandByPoint(si.min),this.boundingBox.expandByPoint(si.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&console.error('THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Bp);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new se,1/0);return}if(e){const s=this.boundingSphere.center;if(si.setFromBufferAttribute(e),t)for(let c=0,u=t.length;c<u;c++){const d=t[c];Ko.setFromBufferAttribute(d),this.morphTargetsRelative?(gn.addVectors(si.min,Ko.min),si.expandByPoint(gn),gn.addVectors(si.max,Ko.max),si.expandByPoint(gn)):(si.expandByPoint(Ko.min),si.expandByPoint(Ko.max))}si.getCenter(s);let a=0;for(let c=0,u=e.count;c<u;c++)gn.fromBufferAttribute(e,c),a=Math.max(a,s.distanceToSquared(gn));if(t)for(let c=0,u=t.length;c<u;c++){const d=t[c],f=this.morphTargetsRelative;for(let p=0,g=d.count;p<g;p++)gn.fromBufferAttribute(d,p),f&&(Da.fromBufferAttribute(e,p),gn.add(Da)),a=Math.max(a,s.distanceToSquared(gn))}this.boundingSphere.radius=Math.sqrt(a),isNaN(this.boundingSphere.radius)&&console.error('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){const e=this.index,t=this.attributes;if(e===null||t.position===void 0||t.normal===void 0||t.uv===void 0){console.error("THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}const s=t.position,a=t.normal,c=t.uv;this.hasAttribute("tangent")===!1&&this.setAttribute("tangent",new Ki(new Float32Array(4*s.count),4));const u=this.getAttribute("tangent"),d=[],f=[];for(let $=0;$<s.count;$++)d[$]=new se,f[$]=new se;const p=new se,g=new se,v=new se,x=new At,y=new At,w=new At,E=new se,_=new se;function M($,te,T){p.fromBufferAttribute(s,$),g.fromBufferAttribute(s,te),v.fromBufferAttribute(s,T),x.fromBufferAttribute(c,$),y.fromBufferAttribute(c,te),w.fromBufferAttribute(c,T),g.sub(p),v.sub(p),y.sub(x),w.sub(x);const P=1/(y.x*w.y-w.x*y.y);isFinite(P)&&(E.copy(g).multiplyScalar(w.y).addScaledVector(v,-y.y).multiplyScalar(P),_.copy(v).multiplyScalar(y.x).addScaledVector(g,-w.x).multiplyScalar(P),d[$].add(E),d[te].add(E),d[T].add(E),f[$].add(_),f[te].add(_),f[T].add(_))}let L=this.groups;L.length===0&&(L=[{start:0,count:e.count}]);for(let $=0,te=L.length;$<te;++$){const T=L[$],P=T.start,re=T.count;for(let J=P,ae=P+re;J<ae;J+=3)M(e.getX(J+0),e.getX(J+1),e.getX(J+2))}const A=new se,R=new se,k=new se,D=new se;function U($){k.fromBufferAttribute(a,$),D.copy(k);const te=d[$];A.copy(te),A.sub(k.multiplyScalar(k.dot(te))).normalize(),R.crossVectors(D,te);const P=R.dot(f[$])<0?-1:1;u.setXYZW($,A.x,A.y,A.z,P)}for(let $=0,te=L.length;$<te;++$){const T=L[$],P=T.start,re=T.count;for(let J=P,ae=P+re;J<ae;J+=3)U(e.getX(J+0)),U(e.getX(J+1)),U(e.getX(J+2))}}computeVertexNormals(){const e=this.index,t=this.getAttribute("position");if(t!==void 0){let s=this.getAttribute("normal");if(s===void 0)s=new Ki(new Float32Array(t.count*3),3),this.setAttribute("normal",s);else for(let x=0,y=s.count;x<y;x++)s.setXYZ(x,0,0,0);const a=new se,c=new se,u=new se,d=new se,f=new se,p=new se,g=new se,v=new se;if(e)for(let x=0,y=e.count;x<y;x+=3){const w=e.getX(x+0),E=e.getX(x+1),_=e.getX(x+2);a.fromBufferAttribute(t,w),c.fromBufferAttribute(t,E),u.fromBufferAttribute(t,_),g.subVectors(u,c),v.subVectors(a,c),g.cross(v),d.fromBufferAttribute(s,w),f.fromBufferAttribute(s,E),p.fromBufferAttribute(s,_),d.add(g),f.add(g),p.add(g),s.setXYZ(w,d.x,d.y,d.z),s.setXYZ(E,f.x,f.y,f.z),s.setXYZ(_,p.x,p.y,p.z)}else for(let x=0,y=t.count;x<y;x+=3)a.fromBufferAttribute(t,x+0),c.fromBufferAttribute(t,x+1),u.fromBufferAttribute(t,x+2),g.subVectors(u,c),v.subVectors(a,c),g.cross(v),s.setXYZ(x+0,g.x,g.y,g.z),s.setXYZ(x+1,g.x,g.y,g.z),s.setXYZ(x+2,g.x,g.y,g.z);this.normalizeNormals(),s.needsUpdate=!0}}normalizeNormals(){const e=this.attributes.normal;for(let t=0,s=e.count;t<s;t++)gn.fromBufferAttribute(e,t),gn.normalize(),e.setXYZ(t,gn.x,gn.y,gn.z)}toNonIndexed(){function e(d,f){const p=d.array,g=d.itemSize,v=d.normalized,x=new p.constructor(f.length*g);let y=0,w=0;for(let E=0,_=f.length;E<_;E++){d.isInterleavedBufferAttribute?y=f[E]*d.data.stride+d.offset:y=f[E]*g;for(let M=0;M<g;M++)x[w++]=p[y++]}return new Ki(x,g,v)}if(this.index===null)return console.warn("THREE.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;const t=new As,s=this.index.array,a=this.attributes;for(const d in a){const f=a[d],p=e(f,s);t.setAttribute(d,p)}const c=this.morphAttributes;for(const d in c){const f=[],p=c[d];for(let g=0,v=p.length;g<v;g++){const x=p[g],y=e(x,s);f.push(y)}t.morphAttributes[d]=f}t.morphTargetsRelative=this.morphTargetsRelative;const u=this.groups;for(let d=0,f=u.length;d<f;d++){const p=u[d];t.addGroup(p.start,p.count,p.materialIndex)}return t}toJSON(){const e={metadata:{version:4.6,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(e.uuid=this.uuid,e.type=this.type,this.name!==""&&(e.name=this.name),Object.keys(this.userData).length>0&&(e.userData=this.userData),this.parameters!==void 0){const f=this.parameters;for(const p in f)f[p]!==void 0&&(e[p]=f[p]);return e}e.data={attributes:{}};const t=this.index;t!==null&&(e.data.index={type:t.array.constructor.name,array:Array.prototype.slice.call(t.array)});const s=this.attributes;for(const f in s){const p=s[f];e.data.attributes[f]=p.toJSON(e.data)}const a={};let c=!1;for(const f in this.morphAttributes){const p=this.morphAttributes[f],g=[];for(let v=0,x=p.length;v<x;v++){const y=p[v];g.push(y.toJSON(e.data))}g.length>0&&(a[f]=g,c=!0)}c&&(e.data.morphAttributes=a,e.data.morphTargetsRelative=this.morphTargetsRelative);const u=this.groups;u.length>0&&(e.data.groups=JSON.parse(JSON.stringify(u)));const d=this.boundingSphere;return d!==null&&(e.data.boundingSphere={center:d.center.toArray(),radius:d.radius}),e}clone(){return new this.constructor().copy(this)}copy(e){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;const t={};this.name=e.name;const s=e.index;s!==null&&this.setIndex(s.clone(t));const a=e.attributes;for(const p in a){const g=a[p];this.setAttribute(p,g.clone(t))}const c=e.morphAttributes;for(const p in c){const g=[],v=c[p];for(let x=0,y=v.length;x<y;x++)g.push(v[x].clone(t));this.morphAttributes[p]=g}this.morphTargetsRelative=e.morphTargetsRelative;const u=e.groups;for(let p=0,g=u.length;p<g;p++){const v=u[p];this.addGroup(v.start,v.count,v.materialIndex)}const d=e.boundingBox;d!==null&&(this.boundingBox=d.clone());const f=e.boundingSphere;return f!==null&&(this.boundingSphere=f.clone()),this.drawRange.start=e.drawRange.start,this.drawRange.count=e.drawRange.count,this.userData=e.userData,this}dispose(){this.dispatchEvent({type:"dispose"})}}const w_=new nn,Nr=new ab,Oc=new Bp,T_=new se,jc=new se,zc=new se,Bc=new se,Zh=new se,Hc=new se,b_=new se,Vc=new se;class ji extends oi{constructor(e=new As,t=new Hp){super(),this.isMesh=!0,this.type="Mesh",this.geometry=e,this.material=t,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),e.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=e.morphTargetInfluences.slice()),e.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},e.morphTargetDictionary)),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}updateMorphTargets(){const t=this.geometry.morphAttributes,s=Object.keys(t);if(s.length>0){const a=t[s[0]];if(a!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let c=0,u=a.length;c<u;c++){const d=a[c].name||String(c);this.morphTargetInfluences.push(0),this.morphTargetDictionary[d]=c}}}}getVertexPosition(e,t){const s=this.geometry,a=s.attributes.position,c=s.morphAttributes.position,u=s.morphTargetsRelative;t.fromBufferAttribute(a,e);const d=this.morphTargetInfluences;if(c&&d){Hc.set(0,0,0);for(let f=0,p=c.length;f<p;f++){const g=d[f],v=c[f];g!==0&&(Zh.fromBufferAttribute(v,e),u?Hc.addScaledVector(Zh,g):Hc.addScaledVector(Zh.sub(t),g))}t.add(Hc)}return t}raycast(e,t){const s=this.geometry,a=this.material,c=this.matrixWorld;a!==void 0&&(s.boundingSphere===null&&s.computeBoundingSphere(),Oc.copy(s.boundingSphere),Oc.applyMatrix4(c),Nr.copy(e.ray).recast(e.near),!(Oc.containsPoint(Nr.origin)===!1&&(Nr.intersectSphere(Oc,T_)===null||Nr.origin.distanceToSquared(T_)>(e.far-e.near)**2))&&(w_.copy(c).invert(),Nr.copy(e.ray).applyMatrix4(w_),!(s.boundingBox!==null&&Nr.intersectsBox(s.boundingBox)===!1)&&this._computeIntersections(e,t,Nr)))}_computeIntersections(e,t,s){let a;const c=this.geometry,u=this.material,d=c.index,f=c.attributes.position,p=c.attributes.uv,g=c.attributes.uv1,v=c.attributes.normal,x=c.groups,y=c.drawRange;if(d!==null)if(Array.isArray(u))for(let w=0,E=x.length;w<E;w++){const _=x[w],M=u[_.materialIndex],L=Math.max(_.start,y.start),A=Math.min(d.count,Math.min(_.start+_.count,y.start+y.count));for(let R=L,k=A;R<k;R+=3){const D=d.getX(R),U=d.getX(R+1),$=d.getX(R+2);a=Gc(this,M,e,s,p,g,v,D,U,$),a&&(a.faceIndex=Math.floor(R/3),a.face.materialIndex=_.materialIndex,t.push(a))}}else{const w=Math.max(0,y.start),E=Math.min(d.count,y.start+y.count);for(let _=w,M=E;_<M;_+=3){const L=d.getX(_),A=d.getX(_+1),R=d.getX(_+2);a=Gc(this,u,e,s,p,g,v,L,A,R),a&&(a.faceIndex=Math.floor(_/3),t.push(a))}}else if(f!==void 0)if(Array.isArray(u))for(let w=0,E=x.length;w<E;w++){const _=x[w],M=u[_.materialIndex],L=Math.max(_.start,y.start),A=Math.min(f.count,Math.min(_.start+_.count,y.start+y.count));for(let R=L,k=A;R<k;R+=3){const D=R,U=R+1,$=R+2;a=Gc(this,M,e,s,p,g,v,D,U,$),a&&(a.faceIndex=Math.floor(R/3),a.face.materialIndex=_.materialIndex,t.push(a))}}else{const w=Math.max(0,y.start),E=Math.min(f.count,y.start+y.count);for(let _=w,M=E;_<M;_+=3){const L=_,A=_+1,R=_+2;a=Gc(this,u,e,s,p,g,v,L,A,R),a&&(a.faceIndex=Math.floor(_/3),t.push(a))}}}}function mb(n,e,t,s,a,c,u,d){let f;if(e.side===qn?f=s.intersectTriangle(u,c,a,!0,d):f=s.intersectTriangle(a,c,u,e.side===ur,d),f===null)return null;Vc.copy(d),Vc.applyMatrix4(n.matrixWorld);const p=t.ray.origin.distanceTo(Vc);return p<t.near||p>t.far?null:{distance:p,point:Vc.clone(),object:n}}function Gc(n,e,t,s,a,c,u,d,f,p){n.getVertexPosition(d,jc),n.getVertexPosition(f,zc),n.getVertexPosition(p,Bc);const g=mb(n,e,t,s,jc,zc,Bc,b_);if(g){const v=new se;Ii.getBarycoord(b_,jc,zc,Bc,v),a&&(g.uv=Ii.getInterpolatedAttribute(a,d,f,p,v,new At)),c&&(g.uv1=Ii.getInterpolatedAttribute(c,d,f,p,v,new At)),u&&(g.normal=Ii.getInterpolatedAttribute(u,d,f,p,v,new se),g.normal.dot(s.direction)>0&&g.normal.multiplyScalar(-1));const x={a:d,b:f,c:p,normal:new se,materialIndex:0};Ii.getNormal(jc,zc,Bc,x.normal),g.face=x,g.barycoord=v}return g}class gl extends As{constructor(e=1,t=1,s=1,a=1,c=1,u=1){super(),this.type="BoxGeometry",this.parameters={width:e,height:t,depth:s,widthSegments:a,heightSegments:c,depthSegments:u};const d=this;a=Math.floor(a),c=Math.floor(c),u=Math.floor(u);const f=[],p=[],g=[],v=[];let x=0,y=0;w("z","y","x",-1,-1,s,t,e,u,c,0),w("z","y","x",1,-1,s,t,-e,u,c,1),w("x","z","y",1,1,e,s,t,a,u,2),w("x","z","y",1,-1,e,s,-t,a,u,3),w("x","y","z",1,-1,e,t,s,a,c,4),w("x","y","z",-1,-1,e,t,-s,a,c,5),this.setIndex(f),this.setAttribute("position",new li(p,3)),this.setAttribute("normal",new li(g,3)),this.setAttribute("uv",new li(v,2));function w(E,_,M,L,A,R,k,D,U,$,te){const T=R/U,P=k/$,re=R/2,J=k/2,ae=D/2,ve=U+1,V=$+1;let de=0,z=0;const ue=new se;for(let oe=0;oe<V;oe++){const O=oe*P-J;for(let le=0;le<ve;le++){const we=le*T-re;ue[E]=we*L,ue[_]=O*A,ue[M]=ae,p.push(ue.x,ue.y,ue.z),ue[E]=0,ue[_]=0,ue[M]=D>0?1:-1,g.push(ue.x,ue.y,ue.z),v.push(le/U),v.push(1-oe/$),de+=1}}for(let oe=0;oe<$;oe++)for(let O=0;O<U;O++){const le=x+O+ve*oe,we=x+O+ve*(oe+1),K=x+(O+1)+ve*(oe+1),fe=x+(O+1)+ve*oe;f.push(le,we,fe),f.push(we,K,fe),z+=6}d.addGroup(y,z,te),y+=z,x+=de}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new gl(e.width,e.height,e.depth,e.widthSegments,e.heightSegments,e.depthSegments)}}function Qa(n){const e={};for(const t in n){e[t]={};for(const s in n[t]){const a=n[t][s];a&&(a.isColor||a.isMatrix3||a.isMatrix4||a.isVector2||a.isVector3||a.isVector4||a.isTexture||a.isQuaternion)?a.isRenderTargetTexture?(console.warn("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),e[t][s]=null):e[t][s]=a.clone():Array.isArray(a)?e[t][s]=a.slice():e[t][s]=a}}return e}function Fn(n){const e={};for(let t=0;t<n.length;t++){const s=Qa(n[t]);for(const a in s)e[a]=s[a]}return e}function gb(n){const e=[];for(let t=0;t<n.length;t++)e.push(n[t].clone());return e}function vx(n){const e=n.getRenderTarget();return e===null?n.outputColorSpace:e.isXRRenderTarget===!0?e.texture.colorSpace:Nt.workingColorSpace}const _b={clone:Qa,merge:Fn};var vb=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,xb=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`;class bs extends Ou{constructor(e){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=vb,this.fragmentShader=xb,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,e!==void 0&&this.setValues(e)}copy(e){return super.copy(e),this.fragmentShader=e.fragmentShader,this.vertexShader=e.vertexShader,this.uniforms=Qa(e.uniforms),this.uniformsGroups=gb(e.uniformsGroups),this.defines=Object.assign({},e.defines),this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.fog=e.fog,this.lights=e.lights,this.clipping=e.clipping,this.extensions=Object.assign({},e.extensions),this.glslVersion=e.glslVersion,this}toJSON(e){const t=super.toJSON(e);t.glslVersion=this.glslVersion,t.uniforms={};for(const a in this.uniforms){const u=this.uniforms[a].value;u&&u.isTexture?t.uniforms[a]={type:"t",value:u.toJSON(e).uuid}:u&&u.isColor?t.uniforms[a]={type:"c",value:u.getHex()}:u&&u.isVector2?t.uniforms[a]={type:"v2",value:u.toArray()}:u&&u.isVector3?t.uniforms[a]={type:"v3",value:u.toArray()}:u&&u.isVector4?t.uniforms[a]={type:"v4",value:u.toArray()}:u&&u.isMatrix3?t.uniforms[a]={type:"m3",value:u.toArray()}:u&&u.isMatrix4?t.uniforms[a]={type:"m4",value:u.toArray()}:t.uniforms[a]={value:u}}Object.keys(this.defines).length>0&&(t.defines=this.defines),t.vertexShader=this.vertexShader,t.fragmentShader=this.fragmentShader,t.lights=this.lights,t.clipping=this.clipping;const s={};for(const a in this.extensions)this.extensions[a]===!0&&(s[a]=!0);return Object.keys(s).length>0&&(t.extensions=s),t}}class xx extends oi{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new nn,this.projectionMatrix=new nn,this.projectionMatrixInverse=new nn,this.coordinateSystem=ys}copy(e,t){return super.copy(e,t),this.matrixWorldInverse.copy(e.matrixWorldInverse),this.projectionMatrix.copy(e.projectionMatrix),this.projectionMatrixInverse.copy(e.projectionMatrixInverse),this.coordinateSystem=e.coordinateSystem,this}getWorldDirection(e){return super.getWorldDirection(e).negate()}updateMatrixWorld(e){super.updateMatrixWorld(e),this.matrixWorldInverse.copy(this.matrixWorld).invert()}updateWorldMatrix(e,t){super.updateWorldMatrix(e,t),this.matrixWorldInverse.copy(this.matrixWorld).invert()}clone(){return new this.constructor().copy(this)}}const nr=new se,A_=new At,C_=new At;class xi extends xx{constructor(e=50,t=1,s=.1,a=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=e,this.zoom=1,this.near=s,this.far=a,this.focus=10,this.aspect=t,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.fov=e.fov,this.zoom=e.zoom,this.near=e.near,this.far=e.far,this.focus=e.focus,this.aspect=e.aspect,this.view=e.view===null?null:Object.assign({},e.view),this.filmGauge=e.filmGauge,this.filmOffset=e.filmOffset,this}setFocalLength(e){const t=.5*this.getFilmHeight()/e;this.fov=ap*2*Math.atan(t),this.updateProjectionMatrix()}getFocalLength(){const e=Math.tan(Rh*.5*this.fov);return .5*this.getFilmHeight()/e}getEffectiveFOV(){return ap*2*Math.atan(Math.tan(Rh*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(e,t,s){nr.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),t.set(nr.x,nr.y).multiplyScalar(-e/nr.z),nr.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),s.set(nr.x,nr.y).multiplyScalar(-e/nr.z)}getViewSize(e,t){return this.getViewBounds(e,A_,C_),t.subVectors(C_,A_)}setViewOffset(e,t,s,a,c,u){this.aspect=e/t,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=s,this.view.offsetY=a,this.view.width=c,this.view.height=u,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=this.near;let t=e*Math.tan(Rh*.5*this.fov)/this.zoom,s=2*t,a=this.aspect*s,c=-.5*a;const u=this.view;if(this.view!==null&&this.view.enabled){const f=u.fullWidth,p=u.fullHeight;c+=u.offsetX*a/f,t-=u.offsetY*s/p,a*=u.width/f,s*=u.height/p}const d=this.filmOffset;d!==0&&(c+=e*d/this.getFilmWidth()),this.projectionMatrix.makePerspective(c,c+a,t,t-s,e,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.fov=this.fov,t.object.zoom=this.zoom,t.object.near=this.near,t.object.far=this.far,t.object.focus=this.focus,t.object.aspect=this.aspect,this.view!==null&&(t.object.view=Object.assign({},this.view)),t.object.filmGauge=this.filmGauge,t.object.filmOffset=this.filmOffset,t}}const Ia=-90,Ua=1;class yb extends oi{constructor(e,t,s){super(),this.type="CubeCamera",this.renderTarget=s,this.coordinateSystem=null,this.activeMipmapLevel=0;const a=new xi(Ia,Ua,e,t);a.layers=this.layers,this.add(a);const c=new xi(Ia,Ua,e,t);c.layers=this.layers,this.add(c);const u=new xi(Ia,Ua,e,t);u.layers=this.layers,this.add(u);const d=new xi(Ia,Ua,e,t);d.layers=this.layers,this.add(d);const f=new xi(Ia,Ua,e,t);f.layers=this.layers,this.add(f);const p=new xi(Ia,Ua,e,t);p.layers=this.layers,this.add(p)}updateCoordinateSystem(){const e=this.coordinateSystem,t=this.children.concat(),[s,a,c,u,d,f]=t;for(const p of t)this.remove(p);if(e===ys)s.up.set(0,1,0),s.lookAt(1,0,0),a.up.set(0,1,0),a.lookAt(-1,0,0),c.up.set(0,0,-1),c.lookAt(0,1,0),u.up.set(0,0,1),u.lookAt(0,-1,0),d.up.set(0,1,0),d.lookAt(0,0,1),f.up.set(0,1,0),f.lookAt(0,0,-1);else if(e===xu)s.up.set(0,-1,0),s.lookAt(-1,0,0),a.up.set(0,-1,0),a.lookAt(1,0,0),c.up.set(0,0,1),c.lookAt(0,1,0),u.up.set(0,0,-1),u.lookAt(0,-1,0),d.up.set(0,-1,0),d.lookAt(0,0,1),f.up.set(0,-1,0),f.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+e);for(const p of t)this.add(p),p.updateMatrixWorld()}update(e,t){this.parent===null&&this.updateMatrixWorld();const{renderTarget:s,activeMipmapLevel:a}=this;this.coordinateSystem!==e.coordinateSystem&&(this.coordinateSystem=e.coordinateSystem,this.updateCoordinateSystem());const[c,u,d,f,p,g]=this.children,v=e.getRenderTarget(),x=e.getActiveCubeFace(),y=e.getActiveMipmapLevel(),w=e.xr.enabled;e.xr.enabled=!1;const E=s.texture.generateMipmaps;s.texture.generateMipmaps=!1,e.setRenderTarget(s,0,a),e.render(t,c),e.setRenderTarget(s,1,a),e.render(t,u),e.setRenderTarget(s,2,a),e.render(t,d),e.setRenderTarget(s,3,a),e.render(t,f),e.setRenderTarget(s,4,a),e.render(t,p),s.texture.generateMipmaps=E,e.setRenderTarget(s,5,a),e.render(t,g),e.setRenderTarget(v,x,y),e.xr.enabled=w,s.texture.needsPMREMUpdate=!0}}class yx extends Yn{constructor(e,t,s,a,c,u,d,f,p,g){e=e!==void 0?e:[],t=t!==void 0?t:qa,super(e,t,s,a,c,u,d,f,p,g),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(e){this.image=e}}class Sb extends qr{constructor(e=1,t={}){super(e,e,t),this.isWebGLCubeRenderTarget=!0;const s={width:e,height:e,depth:1},a=[s,s,s,s,s,s];this.texture=new yx(a,t.mapping,t.wrapS,t.wrapT,t.magFilter,t.minFilter,t.format,t.type,t.anisotropy,t.colorSpace),this.texture.isRenderTargetTexture=!0,this.texture.generateMipmaps=t.generateMipmaps!==void 0?t.generateMipmaps:!1,this.texture.minFilter=t.minFilter!==void 0?t.minFilter:Di}fromEquirectangularTexture(e,t){this.texture.type=t.type,this.texture.colorSpace=t.colorSpace,this.texture.generateMipmaps=t.generateMipmaps,this.texture.minFilter=t.minFilter,this.texture.magFilter=t.magFilter;const s={uniforms:{tEquirect:{value:null}},vertexShader:`

				varying vec3 vWorldDirection;

				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

				}

				void main() {

					vWorldDirection = transformDirection( position, modelMatrix );

					#include <begin_vertex>
					#include <project_vertex>

				}
			`,fragmentShader:`

				uniform sampler2D tEquirect;

				varying vec3 vWorldDirection;

				#include <common>

				void main() {

					vec3 direction = normalize( vWorldDirection );

					vec2 sampleUV = equirectUv( direction );

					gl_FragColor = texture2D( tEquirect, sampleUV );

				}
			`},a=new gl(5,5,5),c=new bs({name:"CubemapFromEquirect",uniforms:Qa(s.uniforms),vertexShader:s.vertexShader,fragmentShader:s.fragmentShader,side:qn,blending:ar});c.uniforms.tEquirect.value=t;const u=new ji(a,c),d=t.minFilter;return t.minFilter===zr&&(t.minFilter=Di),new yb(1,10,this).update(e,u),t.minFilter=d,u.geometry.dispose(),u.material.dispose(),this}clear(e,t,s,a){const c=e.getRenderTarget();for(let u=0;u<6;u++)e.setRenderTarget(this,u),e.clear(t,s,a);e.setRenderTarget(c)}}const Qh=new se,Mb=new se,Eb=new dt;class Lr{constructor(e=new se(1,0,0),t=0){this.isPlane=!0,this.normal=e,this.constant=t}set(e,t){return this.normal.copy(e),this.constant=t,this}setComponents(e,t,s,a){return this.normal.set(e,t,s),this.constant=a,this}setFromNormalAndCoplanarPoint(e,t){return this.normal.copy(e),this.constant=-t.dot(this.normal),this}setFromCoplanarPoints(e,t,s){const a=Qh.subVectors(s,t).cross(Mb.subVectors(e,t)).normalize();return this.setFromNormalAndCoplanarPoint(a,e),this}copy(e){return this.normal.copy(e.normal),this.constant=e.constant,this}normalize(){const e=1/this.normal.length();return this.normal.multiplyScalar(e),this.constant*=e,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(e){return this.normal.dot(e)+this.constant}distanceToSphere(e){return this.distanceToPoint(e.center)-e.radius}projectPoint(e,t){return t.copy(e).addScaledVector(this.normal,-this.distanceToPoint(e))}intersectLine(e,t){const s=e.delta(Qh),a=this.normal.dot(s);if(a===0)return this.distanceToPoint(e.start)===0?t.copy(e.start):null;const c=-(e.start.dot(this.normal)+this.constant)/a;return c<0||c>1?null:t.copy(e.start).addScaledVector(s,c)}intersectsLine(e){const t=this.distanceToPoint(e.start),s=this.distanceToPoint(e.end);return t<0&&s>0||s<0&&t>0}intersectsBox(e){return e.intersectsPlane(this)}intersectsSphere(e){return e.intersectsPlane(this)}coplanarPoint(e){return e.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(e,t){const s=t||Eb.getNormalMatrix(e),a=this.coplanarPoint(Qh).applyMatrix4(e),c=this.normal.applyMatrix3(s).normalize();return this.constant=-a.dot(c),this}translate(e){return this.constant-=e.dot(this.normal),this}equals(e){return e.normal.equals(this.normal)&&e.constant===this.constant}clone(){return new this.constructor().copy(this)}}const Rr=new Bp,Wc=new se;class Sx{constructor(e=new Lr,t=new Lr,s=new Lr,a=new Lr,c=new Lr,u=new Lr){this.planes=[e,t,s,a,c,u]}set(e,t,s,a,c,u){const d=this.planes;return d[0].copy(e),d[1].copy(t),d[2].copy(s),d[3].copy(a),d[4].copy(c),d[5].copy(u),this}copy(e){const t=this.planes;for(let s=0;s<6;s++)t[s].copy(e.planes[s]);return this}setFromProjectionMatrix(e,t=ys){const s=this.planes,a=e.elements,c=a[0],u=a[1],d=a[2],f=a[3],p=a[4],g=a[5],v=a[6],x=a[7],y=a[8],w=a[9],E=a[10],_=a[11],M=a[12],L=a[13],A=a[14],R=a[15];if(s[0].setComponents(f-c,x-p,_-y,R-M).normalize(),s[1].setComponents(f+c,x+p,_+y,R+M).normalize(),s[2].setComponents(f+u,x+g,_+w,R+L).normalize(),s[3].setComponents(f-u,x-g,_-w,R-L).normalize(),s[4].setComponents(f-d,x-v,_-E,R-A).normalize(),t===ys)s[5].setComponents(f+d,x+v,_+E,R+A).normalize();else if(t===xu)s[5].setComponents(d,v,E,A).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+t);return this}intersectsObject(e){if(e.boundingSphere!==void 0)e.boundingSphere===null&&e.computeBoundingSphere(),Rr.copy(e.boundingSphere).applyMatrix4(e.matrixWorld);else{const t=e.geometry;t.boundingSphere===null&&t.computeBoundingSphere(),Rr.copy(t.boundingSphere).applyMatrix4(e.matrixWorld)}return this.intersectsSphere(Rr)}intersectsSprite(e){return Rr.center.set(0,0,0),Rr.radius=.7071067811865476,Rr.applyMatrix4(e.matrixWorld),this.intersectsSphere(Rr)}intersectsSphere(e){const t=this.planes,s=e.center,a=-e.radius;for(let c=0;c<6;c++)if(t[c].distanceToPoint(s)<a)return!1;return!0}intersectsBox(e){const t=this.planes;for(let s=0;s<6;s++){const a=t[s];if(Wc.x=a.normal.x>0?e.max.x:e.min.x,Wc.y=a.normal.y>0?e.max.y:e.min.y,Wc.z=a.normal.z>0?e.max.z:e.min.z,a.distanceToPoint(Wc)<0)return!1}return!0}containsPoint(e){const t=this.planes;for(let s=0;s<6;s++)if(t[s].distanceToPoint(e)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}}function Mx(){let n=null,e=!1,t=null,s=null;function a(c,u){t(c,u),s=n.requestAnimationFrame(a)}return{start:function(){e!==!0&&t!==null&&(s=n.requestAnimationFrame(a),e=!0)},stop:function(){n.cancelAnimationFrame(s),e=!1},setAnimationLoop:function(c){t=c},setContext:function(c){n=c}}}function wb(n){const e=new WeakMap;function t(d,f){const p=d.array,g=d.usage,v=p.byteLength,x=n.createBuffer();n.bindBuffer(f,x),n.bufferData(f,p,g),d.onUploadCallback();let y;if(p instanceof Float32Array)y=n.FLOAT;else if(p instanceof Uint16Array)d.isFloat16BufferAttribute?y=n.HALF_FLOAT:y=n.UNSIGNED_SHORT;else if(p instanceof Int16Array)y=n.SHORT;else if(p instanceof Uint32Array)y=n.UNSIGNED_INT;else if(p instanceof Int32Array)y=n.INT;else if(p instanceof Int8Array)y=n.BYTE;else if(p instanceof Uint8Array)y=n.UNSIGNED_BYTE;else if(p instanceof Uint8ClampedArray)y=n.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+p);return{buffer:x,type:y,bytesPerElement:p.BYTES_PER_ELEMENT,version:d.version,size:v}}function s(d,f,p){const g=f.array,v=f.updateRanges;if(n.bindBuffer(p,d),v.length===0)n.bufferSubData(p,0,g);else{v.sort((y,w)=>y.start-w.start);let x=0;for(let y=1;y<v.length;y++){const w=v[x],E=v[y];E.start<=w.start+w.count+1?w.count=Math.max(w.count,E.start+E.count-w.start):(++x,v[x]=E)}v.length=x+1;for(let y=0,w=v.length;y<w;y++){const E=v[y];n.bufferSubData(p,E.start*g.BYTES_PER_ELEMENT,g,E.start,E.count)}f.clearUpdateRanges()}f.onUploadCallback()}function a(d){return d.isInterleavedBufferAttribute&&(d=d.data),e.get(d)}function c(d){d.isInterleavedBufferAttribute&&(d=d.data);const f=e.get(d);f&&(n.deleteBuffer(f.buffer),e.delete(d))}function u(d,f){if(d.isInterleavedBufferAttribute&&(d=d.data),d.isGLBufferAttribute){const g=e.get(d);(!g||g.version<d.version)&&e.set(d,{buffer:d.buffer,type:d.type,bytesPerElement:d.elementSize,version:d.version});return}const p=e.get(d);if(p===void 0)e.set(d,t(d,f));else if(p.version<d.version){if(p.size!==d.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");s(p.buffer,d,f),p.version=d.version}}return{get:a,remove:c,update:u}}class _l extends As{constructor(e=1,t=1,s=1,a=1){super(),this.type="PlaneGeometry",this.parameters={width:e,height:t,widthSegments:s,heightSegments:a};const c=e/2,u=t/2,d=Math.floor(s),f=Math.floor(a),p=d+1,g=f+1,v=e/d,x=t/f,y=[],w=[],E=[],_=[];for(let M=0;M<g;M++){const L=M*x-u;for(let A=0;A<p;A++){const R=A*v-c;w.push(R,-L,0),E.push(0,0,1),_.push(A/d),_.push(1-M/f)}}for(let M=0;M<f;M++)for(let L=0;L<d;L++){const A=L+p*M,R=L+p*(M+1),k=L+1+p*(M+1),D=L+1+p*M;y.push(A,R,D),y.push(R,k,D)}this.setIndex(y),this.setAttribute("position",new li(w,3)),this.setAttribute("normal",new li(E,3)),this.setAttribute("uv",new li(_,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new _l(e.width,e.height,e.widthSegments,e.heightSegments)}}var Tb=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,bb=`#ifdef USE_ALPHAHASH
	const float ALPHA_HASH_SCALE = 0.05;
	float hash2D( vec2 value ) {
		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );
	}
	float hash3D( vec3 value ) {
		return hash2D( vec2( hash2D( value.xy ), value.z ) );
	}
	float getAlphaHashThreshold( vec3 position ) {
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);
		float lerpFactor = fract( log2( pixScale ) );
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;
		return clamp( threshold , 1.0e-6, 1.0 );
	}
#endif`,Ab=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,Cb=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,Nb=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,Rb=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,Pb=`#ifdef USE_AOMAP
	float ambientOcclusion = ( texture2D( aoMap, vAoMapUv ).r - 1.0 ) * aoMapIntensity + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif`,kb=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,Lb=`#ifdef USE_BATCHING
	#if ! defined( GL_ANGLE_multi_draw )
	#define gl_DrawID _gl_DrawID
	uniform int _gl_DrawID;
	#endif
	uniform highp sampler2D batchingTexture;
	uniform highp usampler2D batchingIdTexture;
	mat4 getBatchingMatrix( const in float i ) {
		int size = textureSize( batchingTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( batchingTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( batchingTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( batchingTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( batchingTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
	float getIndirectIndex( const in int i ) {
		int size = textureSize( batchingIdTexture, 0 ).x;
		int x = i % size;
		int y = i / size;
		return float( texelFetch( batchingIdTexture, ivec2( x, y ), 0 ).r );
	}
#endif
#ifdef USE_BATCHING_COLOR
	uniform sampler2D batchingColorTexture;
	vec3 getBatchingColor( const in float i ) {
		int size = textureSize( batchingColorTexture, 0 ).x;
		int j = int( i );
		int x = j % size;
		int y = j / size;
		return texelFetch( batchingColorTexture, ivec2( x, y ), 0 ).rgb;
	}
#endif`,Db=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,Ib=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Ub=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,Fb=`float G_BlinnPhong_Implicit( ) {
	return 0.25;
}
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}
vec3 BRDF_BlinnPhong( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in vec3 specularColor, const in float shininess ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( specularColor, 1.0, dotVH );
	float G = G_BlinnPhong_Implicit( );
	float D = D_BlinnPhong( shininess, dotNH );
	return F * ( G * D );
} // validated`,Ob=`#ifdef USE_IRIDESCENCE
	const mat3 XYZ_TO_REC709 = mat3(
		 3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);
	vec3 Fresnel0ToIor( vec3 fresnel0 ) {
		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );
	}
	vec3 IorToFresnel0( vec3 transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );
	}
	float IorToFresnel0( float transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ));
	}
	vec3 evalSensitivity( float OPD, vec3 shift ) {
		float phase = 2.0 * PI * OPD * 1.0e-9;
		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );
		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - pow2( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * pow2( phase ) );
		xyz /= 1.0685e-7;
		vec3 rgb = XYZ_TO_REC709 * xyz;
		return rgb;
	}
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {
		vec3 I;
		float iridescenceIOR = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );
		float sinTheta2Sq = pow2( outsideIOR / iridescenceIOR ) * ( 1.0 - pow2( cosTheta1 ) );
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {
			return vec3( 1.0 );
		}
		float cosTheta2 = sqrt( cosTheta2Sq );
		float R0 = IorToFresnel0( iridescenceIOR, outsideIOR );
		float R12 = F_Schlick( R0, 1.0, cosTheta1 );
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIOR < outsideIOR ) phi12 = PI;
		float phi21 = PI - phi12;
		vec3 baseIOR = Fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) );		vec3 R1 = IorToFresnel0( baseIOR, iridescenceIOR );
		vec3 R23 = F_Schlick( R1, 1.0, cosTheta2 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[ 0 ] < iridescenceIOR ) phi23[ 0 ] = PI;
		if ( baseIOR[ 1 ] < iridescenceIOR ) phi23[ 1 ] = PI;
		if ( baseIOR[ 2 ] < iridescenceIOR ) phi23[ 2 ] = PI;
		float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = pow2( T121 ) * R23 / ( vec3( 1.0 ) - R123 );
		vec3 C0 = R12 + Rs;
		I = C0;
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {
			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;
		}
		return max( I, vec3( 0.0 ) );
	}
#endif`,jb=`#ifdef USE_BUMPMAP
	uniform sampler2D bumpMap;
	uniform float bumpScale;
	vec2 dHdxy_fwd() {
		vec2 dSTdx = dFdx( vBumpMapUv );
		vec2 dSTdy = dFdy( vBumpMapUv );
		float Hll = bumpScale * texture2D( bumpMap, vBumpMapUv ).x;
		float dBx = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdx ).x - Hll;
		float dBy = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdy ).x - Hll;
		return vec2( dBx, dBy );
	}
	vec3 perturbNormalArb( vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection ) {
		vec3 vSigmaX = normalize( dFdx( surf_pos.xyz ) );
		vec3 vSigmaY = normalize( dFdy( surf_pos.xyz ) );
		vec3 vN = surf_norm;
		vec3 R1 = cross( vSigmaY, vN );
		vec3 R2 = cross( vN, vSigmaX );
		float fDet = dot( vSigmaX, R1 ) * faceDirection;
		vec3 vGrad = sign( fDet ) * ( dHdxy.x * R1 + dHdxy.y * R2 );
		return normalize( abs( fDet ) * surf_norm - vGrad );
	}
#endif`,zb=`#if NUM_CLIPPING_PLANES > 0
	vec4 plane;
	#ifdef ALPHA_TO_COVERAGE
		float distanceToPlane, distanceGradient;
		float clipOpacity = 1.0;
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
			distanceGradient = fwidth( distanceToPlane ) / 2.0;
			clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			if ( clipOpacity == 0.0 ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			float unionClipOpacity = 1.0;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
				distanceGradient = fwidth( distanceToPlane ) / 2.0;
				unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			}
			#pragma unroll_loop_end
			clipOpacity *= 1.0 - unionClipOpacity;
		#endif
		diffuseColor.a *= clipOpacity;
		if ( diffuseColor.a == 0.0 ) discard;
	#else
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			bool clipped = true;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;
			}
			#pragma unroll_loop_end
			if ( clipped ) discard;
		#endif
	#endif
#endif`,Bb=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,Hb=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,Vb=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,Gb=`#if defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#elif defined( USE_COLOR )
	diffuseColor.rgb *= vColor;
#endif`,Wb=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR )
	varying vec3 vColor;
#endif`,$b=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec3 vColor;
#endif`,Xb=`#if defined( USE_COLOR_ALPHA )
	vColor = vec4( 1.0 );
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	vColor = vec3( 1.0 );
#endif
#ifdef USE_COLOR
	vColor *= color;
#endif
#ifdef USE_INSTANCING_COLOR
	vColor.xyz *= instanceColor.xyz;
#endif
#ifdef USE_BATCHING_COLOR
	vec3 batchingColor = getBatchingColor( getIndirectIndex( gl_DrawID ) );
	vColor.xyz *= batchingColor.xyz;
#endif`,qb=`#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6
#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )
float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }
highp float rand( const in vec2 uv ) {
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract( sin( sn ) * c );
}
#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif
struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};
struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};
#ifdef USE_ALPHAHASH
	varying vec3 vPosition;
#endif
vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
}
vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );
}
mat3 transposeMat3( const in mat3 m ) {
	mat3 tmp;
	tmp[ 0 ] = vec3( m[ 0 ].x, m[ 1 ].x, m[ 2 ].x );
	tmp[ 1 ] = vec3( m[ 0 ].y, m[ 1 ].y, m[ 2 ].y );
	tmp[ 2 ] = vec3( m[ 0 ].z, m[ 1 ].z, m[ 2 ].z );
	return tmp;
}
bool isPerspectiveMatrix( mat4 m ) {
	return m[ 2 ][ 3 ] == - 1.0;
}
vec2 equirectUv( in vec3 dir ) {
	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;
	return vec2( u, v );
}
vec3 BRDF_Lambert( const in vec3 diffuseColor ) {
	return RECIPROCAL_PI * diffuseColor;
}
vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
}
float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
} // validated`,Yb=`#ifdef ENVMAP_TYPE_CUBE_UV
	#define cubeUV_minMipLevel 4.0
	#define cubeUV_minTileSize 16.0
	float getFace( vec3 direction ) {
		vec3 absDirection = abs( direction );
		float face = - 1.0;
		if ( absDirection.x > absDirection.z ) {
			if ( absDirection.x > absDirection.y )
				face = direction.x > 0.0 ? 0.0 : 3.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		} else {
			if ( absDirection.z > absDirection.y )
				face = direction.z > 0.0 ? 2.0 : 5.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		}
		return face;
	}
	vec2 getUV( vec3 direction, float face ) {
		vec2 uv;
		if ( face == 0.0 ) {
			uv = vec2( direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 1.0 ) {
			uv = vec2( - direction.x, - direction.z ) / abs( direction.y );
		} else if ( face == 2.0 ) {
			uv = vec2( - direction.x, direction.y ) / abs( direction.z );
		} else if ( face == 3.0 ) {
			uv = vec2( - direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 4.0 ) {
			uv = vec2( - direction.x, direction.z ) / abs( direction.y );
		} else {
			uv = vec2( direction.x, direction.y ) / abs( direction.z );
		}
		return 0.5 * ( uv + 1.0 );
	}
	vec3 bilinearCubeUV( sampler2D envMap, vec3 direction, float mipInt ) {
		float face = getFace( direction );
		float filterInt = max( cubeUV_minMipLevel - mipInt, 0.0 );
		mipInt = max( mipInt, cubeUV_minMipLevel );
		float faceSize = exp2( mipInt );
		highp vec2 uv = getUV( direction, face ) * ( faceSize - 2.0 ) + 1.0;
		if ( face > 2.0 ) {
			uv.y += faceSize;
			face -= 3.0;
		}
		uv.x += face * faceSize;
		uv.x += filterInt * 3.0 * cubeUV_minTileSize;
		uv.y += 4.0 * ( exp2( CUBEUV_MAX_MIP ) - faceSize );
		uv.x *= CUBEUV_TEXEL_WIDTH;
		uv.y *= CUBEUV_TEXEL_HEIGHT;
		#ifdef texture2DGradEXT
			return texture2DGradEXT( envMap, uv, vec2( 0.0 ), vec2( 0.0 ) ).rgb;
		#else
			return texture2D( envMap, uv ).rgb;
		#endif
	}
	#define cubeUV_r0 1.0
	#define cubeUV_m0 - 2.0
	#define cubeUV_r1 0.8
	#define cubeUV_m1 - 1.0
	#define cubeUV_r4 0.4
	#define cubeUV_m4 2.0
	#define cubeUV_r5 0.305
	#define cubeUV_m5 3.0
	#define cubeUV_r6 0.21
	#define cubeUV_m6 4.0
	float roughnessToMip( float roughness ) {
		float mip = 0.0;
		if ( roughness >= cubeUV_r1 ) {
			mip = ( cubeUV_r0 - roughness ) * ( cubeUV_m1 - cubeUV_m0 ) / ( cubeUV_r0 - cubeUV_r1 ) + cubeUV_m0;
		} else if ( roughness >= cubeUV_r4 ) {
			mip = ( cubeUV_r1 - roughness ) * ( cubeUV_m4 - cubeUV_m1 ) / ( cubeUV_r1 - cubeUV_r4 ) + cubeUV_m1;
		} else if ( roughness >= cubeUV_r5 ) {
			mip = ( cubeUV_r4 - roughness ) * ( cubeUV_m5 - cubeUV_m4 ) / ( cubeUV_r4 - cubeUV_r5 ) + cubeUV_m4;
		} else if ( roughness >= cubeUV_r6 ) {
			mip = ( cubeUV_r5 - roughness ) * ( cubeUV_m6 - cubeUV_m5 ) / ( cubeUV_r5 - cubeUV_r6 ) + cubeUV_m5;
		} else {
			mip = - 2.0 * log2( 1.16 * roughness );		}
		return mip;
	}
	vec4 textureCubeUV( sampler2D envMap, vec3 sampleDir, float roughness ) {
		float mip = clamp( roughnessToMip( roughness ), cubeUV_m0, CUBEUV_MAX_MIP );
		float mipF = fract( mip );
		float mipInt = floor( mip );
		vec3 color0 = bilinearCubeUV( envMap, sampleDir, mipInt );
		if ( mipF == 0.0 ) {
			return vec4( color0, 1.0 );
		} else {
			vec3 color1 = bilinearCubeUV( envMap, sampleDir, mipInt + 1.0 );
			return vec4( mix( color0, color1, mipF ), 1.0 );
		}
	}
#endif`,Kb=`vec3 transformedNormal = objectNormal;
#ifdef USE_TANGENT
	vec3 transformedTangent = objectTangent;
#endif
#ifdef USE_BATCHING
	mat3 bm = mat3( batchingMatrix );
	transformedNormal /= vec3( dot( bm[ 0 ], bm[ 0 ] ), dot( bm[ 1 ], bm[ 1 ] ), dot( bm[ 2 ], bm[ 2 ] ) );
	transformedNormal = bm * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = bm * transformedTangent;
	#endif
#endif
#ifdef USE_INSTANCING
	mat3 im = mat3( instanceMatrix );
	transformedNormal /= vec3( dot( im[ 0 ], im[ 0 ] ), dot( im[ 1 ], im[ 1 ] ), dot( im[ 2 ], im[ 2 ] ) );
	transformedNormal = im * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = im * transformedTangent;
	#endif
#endif
transformedNormal = normalMatrix * transformedNormal;
#ifdef FLIP_SIDED
	transformedNormal = - transformedNormal;
#endif
#ifdef USE_TANGENT
	transformedTangent = ( modelViewMatrix * vec4( transformedTangent, 0.0 ) ).xyz;
	#ifdef FLIP_SIDED
		transformedTangent = - transformedTangent;
	#endif
#endif`,Zb=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,Qb=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,Jb=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,eA=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,tA="gl_FragColor = linearToOutputTexel( gl_FragColor );",nA=`
const mat3 LINEAR_SRGB_TO_LINEAR_DISPLAY_P3 = mat3(
	vec3( 0.8224621, 0.177538, 0.0 ),
	vec3( 0.0331941, 0.9668058, 0.0 ),
	vec3( 0.0170827, 0.0723974, 0.9105199 )
);
const mat3 LINEAR_DISPLAY_P3_TO_LINEAR_SRGB = mat3(
	vec3( 1.2249401, - 0.2249404, 0.0 ),
	vec3( - 0.0420569, 1.0420571, 0.0 ),
	vec3( - 0.0196376, - 0.0786361, 1.0982735 )
);
vec4 LinearSRGBToLinearDisplayP3( in vec4 value ) {
	return vec4( value.rgb * LINEAR_SRGB_TO_LINEAR_DISPLAY_P3, value.a );
}
vec4 LinearDisplayP3ToLinearSRGB( in vec4 value ) {
	return vec4( value.rgb * LINEAR_DISPLAY_P3_TO_LINEAR_SRGB, value.a );
}
vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,iA=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vec3 cameraToFrag;
		if ( isOrthographic ) {
			cameraToFrag = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToFrag = normalize( vWorldPosition - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vec3 reflectVec = reflect( cameraToFrag, worldNormal );
		#else
			vec3 reflectVec = refract( cameraToFrag, worldNormal, refractionRatio );
		#endif
	#else
		vec3 reflectVec = vReflect;
	#endif
	#ifdef ENVMAP_TYPE_CUBE
		vec4 envColor = textureCube( envMap, envMapRotation * vec3( flipEnvMap * reflectVec.x, reflectVec.yz ) );
	#else
		vec4 envColor = vec4( 0.0 );
	#endif
	#ifdef ENVMAP_BLENDING_MULTIPLY
		outgoingLight = mix( outgoingLight, outgoingLight * envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_MIX )
		outgoingLight = mix( outgoingLight, envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_ADD )
		outgoingLight += envColor.xyz * specularStrength * reflectivity;
	#endif
#endif`,sA=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform float flipEnvMap;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
	
#endif`,rA=`#ifdef USE_ENVMAP
	uniform float reflectivity;
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		varying vec3 vWorldPosition;
		uniform float refractionRatio;
	#else
		varying vec3 vReflect;
	#endif
#endif`,aA=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,oA=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vWorldPosition = worldPosition.xyz;
	#else
		vec3 cameraToVertex;
		if ( isOrthographic ) {
			cameraToVertex = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToVertex = normalize( worldPosition.xyz - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vReflect = reflect( cameraToVertex, worldNormal );
		#else
			vReflect = refract( cameraToVertex, worldNormal, refractionRatio );
		#endif
	#endif
#endif`,lA=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,cA=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,uA=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,dA=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,hA=`#ifdef USE_GRADIENTMAP
	uniform sampler2D gradientMap;
#endif
vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		return vec3( texture2D( gradientMap, coord ).r );
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}`,fA=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,pA=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,mA=`varying vec3 vViewPosition;
struct LambertMaterial {
	vec3 diffuseColor;
	float specularStrength;
};
void RE_Direct_Lambert( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Lambert( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Lambert
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,gA=`uniform bool receiveShadow;
uniform vec3 ambientLightColor;
#if defined( USE_LIGHT_PROBES )
	uniform vec3 lightProbe[ 9 ];
#endif
vec3 shGetIrradianceAt( in vec3 normal, in vec3 shCoefficients[ 9 ] ) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = shCoefficients[ 0 ] * 0.886227;
	result += shCoefficients[ 1 ] * 2.0 * 0.511664 * y;
	result += shCoefficients[ 2 ] * 2.0 * 0.511664 * z;
	result += shCoefficients[ 3 ] * 2.0 * 0.511664 * x;
	result += shCoefficients[ 4 ] * 2.0 * 0.429043 * x * y;
	result += shCoefficients[ 5 ] * 2.0 * 0.429043 * y * z;
	result += shCoefficients[ 6 ] * ( 0.743125 * z * z - 0.247708 );
	result += shCoefficients[ 7 ] * 2.0 * 0.429043 * x * z;
	result += shCoefficients[ 8 ] * 0.429043 * ( x * x - y * y );
	return result;
}
vec3 getLightProbeIrradiance( const in vec3 lightProbe[ 9 ], const in vec3 normal ) {
	vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
	vec3 irradiance = shGetIrradianceAt( worldNormal, lightProbe );
	return irradiance;
}
vec3 getAmbientLightIrradiance( const in vec3 ambientLightColor ) {
	vec3 irradiance = ambientLightColor;
	return irradiance;
}
float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}
float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
	};
	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];
	void getDirectionalLightInfo( const in DirectionalLight directionalLight, out IncidentLight light ) {
		light.color = directionalLight.color;
		light.direction = directionalLight.direction;
		light.visible = true;
	}
#endif
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};
	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];
	void getPointLightInfo( const in PointLight pointLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}
#endif
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};
	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];
	void getSpotLightInfo( const in SpotLight spotLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = getSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= getDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
#endif
#if NUM_RECT_AREA_LIGHTS > 0
	struct RectAreaLight {
		vec3 color;
		vec3 position;
		vec3 halfWidth;
		vec3 halfHeight;
	};
	uniform sampler2D ltc_1;	uniform sampler2D ltc_2;
	uniform RectAreaLight rectAreaLights[ NUM_RECT_AREA_LIGHTS ];
#endif
#if NUM_HEMI_LIGHTS > 0
	struct HemisphereLight {
		vec3 direction;
		vec3 skyColor;
		vec3 groundColor;
	};
	uniform HemisphereLight hemisphereLights[ NUM_HEMI_LIGHTS ];
	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
		float dotNL = dot( normal, hemiLight.direction );
		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
		return irradiance;
	}
#endif`,_A=`#ifdef USE_ENVMAP
	vec3 getIBLIrradiance( const in vec3 normal ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * worldNormal, 1.0 );
			return PI * envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	vec3 getIBLRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 reflectVec = reflect( - viewDir, normal );
			reflectVec = normalize( mix( reflectVec, normal, roughness * roughness) );
			reflectVec = inverseTransformDirection( reflectVec, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * reflectVec, roughness );
			return envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	#ifdef USE_ANISOTROPY
		vec3 getIBLAnisotropyRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 bentNormal = cross( bitangent, viewDir );
				bentNormal = normalize( cross( bentNormal, bitangent ) );
				bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
				return getIBLRadiance( viewDir, bentNormal, roughness );
			#else
				return vec3( 0.0 );
			#endif
		}
	#endif
#endif`,vA=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,xA=`varying vec3 vViewPosition;
struct ToonMaterial {
	vec3 diffuseColor;
};
void RE_Direct_Toon( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 irradiance = getGradientIrradiance( geometryNormal, directLight.direction ) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Toon( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Toon
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,yA=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,SA=`varying vec3 vViewPosition;
struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};
void RE_Direct_BlinnPhong( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong( directLight.direction, geometryViewDir, geometryNormal, material.specularColor, material.specularShininess ) * material.specularStrength;
}
void RE_IndirectDiffuse_BlinnPhong( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_BlinnPhong
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,MA=`PhysicalMaterial material;
material.diffuseColor = diffuseColor.rgb * ( 1.0 - metalnessFactor );
vec3 dxy = max( abs( dFdx( nonPerturbedNormal ) ), abs( dFdy( nonPerturbedNormal ) ) );
float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );
material.roughness = max( roughnessFactor, 0.0525 );material.roughness += geometryRoughness;
material.roughness = min( material.roughness, 1.0 );
#ifdef IOR
	material.ior = ior;
	#ifdef USE_SPECULAR
		float specularIntensityFactor = specularIntensity;
		vec3 specularColorFactor = specularColor;
		#ifdef USE_SPECULAR_COLORMAP
			specularColorFactor *= texture2D( specularColorMap, vSpecularColorMapUv ).rgb;
		#endif
		#ifdef USE_SPECULAR_INTENSITYMAP
			specularIntensityFactor *= texture2D( specularIntensityMap, vSpecularIntensityMapUv ).a;
		#endif
		material.specularF90 = mix( specularIntensityFactor, 1.0, metalnessFactor );
	#else
		float specularIntensityFactor = 1.0;
		vec3 specularColorFactor = vec3( 1.0 );
		material.specularF90 = 1.0;
	#endif
	material.specularColor = mix( min( pow2( ( material.ior - 1.0 ) / ( material.ior + 1.0 ) ) * specularColorFactor, vec3( 1.0 ) ) * specularIntensityFactor, diffuseColor.rgb, metalnessFactor );
#else
	material.specularColor = mix( vec3( 0.04 ), diffuseColor.rgb, metalnessFactor );
	material.specularF90 = 1.0;
#endif
#ifdef USE_CLEARCOAT
	material.clearcoat = clearcoat;
	material.clearcoatRoughness = clearcoatRoughness;
	material.clearcoatF0 = vec3( 0.04 );
	material.clearcoatF90 = 1.0;
	#ifdef USE_CLEARCOATMAP
		material.clearcoat *= texture2D( clearcoatMap, vClearcoatMapUv ).x;
	#endif
	#ifdef USE_CLEARCOAT_ROUGHNESSMAP
		material.clearcoatRoughness *= texture2D( clearcoatRoughnessMap, vClearcoatRoughnessMapUv ).y;
	#endif
	material.clearcoat = saturate( material.clearcoat );	material.clearcoatRoughness = max( material.clearcoatRoughness, 0.0525 );
	material.clearcoatRoughness += geometryRoughness;
	material.clearcoatRoughness = min( material.clearcoatRoughness, 1.0 );
#endif
#ifdef USE_DISPERSION
	material.dispersion = dispersion;
#endif
#ifdef USE_IRIDESCENCE
	material.iridescence = iridescence;
	material.iridescenceIOR = iridescenceIOR;
	#ifdef USE_IRIDESCENCEMAP
		material.iridescence *= texture2D( iridescenceMap, vIridescenceMapUv ).r;
	#endif
	#ifdef USE_IRIDESCENCE_THICKNESSMAP
		material.iridescenceThickness = (iridescenceThicknessMaximum - iridescenceThicknessMinimum) * texture2D( iridescenceThicknessMap, vIridescenceThicknessMapUv ).g + iridescenceThicknessMinimum;
	#else
		material.iridescenceThickness = iridescenceThicknessMaximum;
	#endif
#endif
#ifdef USE_SHEEN
	material.sheenColor = sheenColor;
	#ifdef USE_SHEEN_COLORMAP
		material.sheenColor *= texture2D( sheenColorMap, vSheenColorMapUv ).rgb;
	#endif
	material.sheenRoughness = clamp( sheenRoughness, 0.07, 1.0 );
	#ifdef USE_SHEEN_ROUGHNESSMAP
		material.sheenRoughness *= texture2D( sheenRoughnessMap, vSheenRoughnessMapUv ).a;
	#endif
#endif
#ifdef USE_ANISOTROPY
	#ifdef USE_ANISOTROPYMAP
		mat2 anisotropyMat = mat2( anisotropyVector.x, anisotropyVector.y, - anisotropyVector.y, anisotropyVector.x );
		vec3 anisotropyPolar = texture2D( anisotropyMap, vAnisotropyMapUv ).rgb;
		vec2 anisotropyV = anisotropyMat * normalize( 2.0 * anisotropyPolar.rg - vec2( 1.0 ) ) * anisotropyPolar.b;
	#else
		vec2 anisotropyV = anisotropyVector;
	#endif
	material.anisotropy = length( anisotropyV );
	if( material.anisotropy == 0.0 ) {
		anisotropyV = vec2( 1.0, 0.0 );
	} else {
		anisotropyV /= material.anisotropy;
		material.anisotropy = saturate( material.anisotropy );
	}
	material.alphaT = mix( pow2( material.roughness ), 1.0, pow2( material.anisotropy ) );
	material.anisotropyT = tbn[ 0 ] * anisotropyV.x + tbn[ 1 ] * anisotropyV.y;
	material.anisotropyB = tbn[ 1 ] * anisotropyV.x - tbn[ 0 ] * anisotropyV.y;
#endif`,EA=`struct PhysicalMaterial {
	vec3 diffuseColor;
	float roughness;
	vec3 specularColor;
	float specularF90;
	float dispersion;
	#ifdef USE_CLEARCOAT
		float clearcoat;
		float clearcoatRoughness;
		vec3 clearcoatF0;
		float clearcoatF90;
	#endif
	#ifdef USE_IRIDESCENCE
		float iridescence;
		float iridescenceIOR;
		float iridescenceThickness;
		vec3 iridescenceFresnel;
		vec3 iridescenceF0;
	#endif
	#ifdef USE_SHEEN
		vec3 sheenColor;
		float sheenRoughness;
	#endif
	#ifdef IOR
		float ior;
	#endif
	#ifdef USE_TRANSMISSION
		float transmission;
		float transmissionAlpha;
		float thickness;
		float attenuationDistance;
		vec3 attenuationColor;
	#endif
	#ifdef USE_ANISOTROPY
		float anisotropy;
		float alphaT;
		vec3 anisotropyT;
		vec3 anisotropyB;
	#endif
};
vec3 clearcoatSpecularDirect = vec3( 0.0 );
vec3 clearcoatSpecularIndirect = vec3( 0.0 );
vec3 sheenSpecularDirect = vec3( 0.0 );
vec3 sheenSpecularIndirect = vec3(0.0 );
vec3 Schlick_to_F0( const in vec3 f, const in float f90, const in float dotVH ) {
    float x = clamp( 1.0 - dotVH, 0.0, 1.0 );
    float x2 = x * x;
    float x5 = clamp( x * x2 * x2, 0.0, 0.9999 );
    return ( f - vec3( f90 ) * x5 ) / ( 1.0 - x5 );
}
float V_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {
	float a2 = pow2( alpha );
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	return 0.5 / max( gv + gl, EPSILON );
}
float D_GGX( const in float alpha, const in float dotNH ) {
	float a2 = pow2( alpha );
	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0;
	return RECIPROCAL_PI * a2 / pow2( denom );
}
#ifdef USE_ANISOTROPY
	float V_GGX_SmithCorrelated_Anisotropic( const in float alphaT, const in float alphaB, const in float dotTV, const in float dotBV, const in float dotTL, const in float dotBL, const in float dotNV, const in float dotNL ) {
		float gv = dotNL * length( vec3( alphaT * dotTV, alphaB * dotBV, dotNV ) );
		float gl = dotNV * length( vec3( alphaT * dotTL, alphaB * dotBL, dotNL ) );
		float v = 0.5 / ( gv + gl );
		return saturate(v);
	}
	float D_GGX_Anisotropic( const in float alphaT, const in float alphaB, const in float dotNH, const in float dotTH, const in float dotBH ) {
		float a2 = alphaT * alphaB;
		highp vec3 v = vec3( alphaB * dotTH, alphaT * dotBH, a2 * dotNH );
		highp float v2 = dot( v, v );
		float w2 = a2 / v2;
		return RECIPROCAL_PI * a2 * pow2 ( w2 );
	}
#endif
#ifdef USE_CLEARCOAT
	vec3 BRDF_GGX_Clearcoat( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material) {
		vec3 f0 = material.clearcoatF0;
		float f90 = material.clearcoatF90;
		float roughness = material.clearcoatRoughness;
		float alpha = pow2( roughness );
		vec3 halfDir = normalize( lightDir + viewDir );
		float dotNL = saturate( dot( normal, lightDir ) );
		float dotNV = saturate( dot( normal, viewDir ) );
		float dotNH = saturate( dot( normal, halfDir ) );
		float dotVH = saturate( dot( viewDir, halfDir ) );
		vec3 F = F_Schlick( f0, f90, dotVH );
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
		return F * ( V * D );
	}
#endif
vec3 BRDF_GGX( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material ) {
	vec3 f0 = material.specularColor;
	float f90 = material.specularF90;
	float roughness = material.roughness;
	float alpha = pow2( roughness );
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( f0, f90, dotVH );
	#ifdef USE_IRIDESCENCE
		F = mix( F, material.iridescenceFresnel, material.iridescence );
	#endif
	#ifdef USE_ANISOTROPY
		float dotTL = dot( material.anisotropyT, lightDir );
		float dotTV = dot( material.anisotropyT, viewDir );
		float dotTH = dot( material.anisotropyT, halfDir );
		float dotBL = dot( material.anisotropyB, lightDir );
		float dotBV = dot( material.anisotropyB, viewDir );
		float dotBH = dot( material.anisotropyB, halfDir );
		float V = V_GGX_SmithCorrelated_Anisotropic( material.alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL );
		float D = D_GGX_Anisotropic( material.alphaT, alpha, dotNH, dotTH, dotBH );
	#else
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
	#endif
	return F * ( V * D );
}
vec2 LTC_Uv( const in vec3 N, const in vec3 V, const in float roughness ) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;
	float dotNV = saturate( dot( N, V ) );
	vec2 uv = vec2( roughness, sqrt( 1.0 - dotNV ) );
	uv = uv * LUT_SCALE + LUT_BIAS;
	return uv;
}
float LTC_ClippedSphereFormFactor( const in vec3 f ) {
	float l = length( f );
	return max( ( l * l + f.z ) / ( l + 1.0 ), 0.0 );
}
vec3 LTC_EdgeVectorFormFactor( const in vec3 v1, const in vec3 v2 ) {
	float x = dot( v1, v2 );
	float y = abs( x );
	float a = 0.8543985 + ( 0.4965155 + 0.0145206 * y ) * y;
	float b = 3.4175940 + ( 4.1616724 + y ) * y;
	float v = a / b;
	float theta_sintheta = ( x > 0.0 ) ? v : 0.5 * inversesqrt( max( 1.0 - x * x, 1e-7 ) ) - v;
	return cross( v1, v2 ) * theta_sintheta;
}
vec3 LTC_Evaluate( const in vec3 N, const in vec3 V, const in vec3 P, const in mat3 mInv, const in vec3 rectCoords[ 4 ] ) {
	vec3 v1 = rectCoords[ 1 ] - rectCoords[ 0 ];
	vec3 v2 = rectCoords[ 3 ] - rectCoords[ 0 ];
	vec3 lightNormal = cross( v1, v2 );
	if( dot( lightNormal, P - rectCoords[ 0 ] ) < 0.0 ) return vec3( 0.0 );
	vec3 T1, T2;
	T1 = normalize( V - N * dot( V, N ) );
	T2 = - cross( N, T1 );
	mat3 mat = mInv * transposeMat3( mat3( T1, T2, N ) );
	vec3 coords[ 4 ];
	coords[ 0 ] = mat * ( rectCoords[ 0 ] - P );
	coords[ 1 ] = mat * ( rectCoords[ 1 ] - P );
	coords[ 2 ] = mat * ( rectCoords[ 2 ] - P );
	coords[ 3 ] = mat * ( rectCoords[ 3 ] - P );
	coords[ 0 ] = normalize( coords[ 0 ] );
	coords[ 1 ] = normalize( coords[ 1 ] );
	coords[ 2 ] = normalize( coords[ 2 ] );
	coords[ 3 ] = normalize( coords[ 3 ] );
	vec3 vectorFormFactor = vec3( 0.0 );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 0 ], coords[ 1 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 1 ], coords[ 2 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 2 ], coords[ 3 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 3 ], coords[ 0 ] );
	float result = LTC_ClippedSphereFormFactor( vectorFormFactor );
	return vec3( result );
}
#if defined( USE_SHEEN )
float D_Charlie( float roughness, float dotNH ) {
	float alpha = pow2( roughness );
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;
	float sin2h = max( 1.0 - cos2h, 0.0078125 );
	return ( 2.0 + invAlpha ) * pow( sin2h, invAlpha * 0.5 ) / ( 2.0 * PI );
}
float V_Neubelt( float dotNV, float dotNL ) {
	return saturate( 1.0 / ( 4.0 * ( dotNL + dotNV - dotNL * dotNV ) ) );
}
vec3 BRDF_Sheen( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, vec3 sheenColor, const in float sheenRoughness ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float D = D_Charlie( sheenRoughness, dotNH );
	float V = V_Neubelt( dotNV, dotNL );
	return sheenColor * ( D * V );
}
#endif
float IBLSheenBRDF( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	float r2 = roughness * roughness;
	float a = roughness < 0.25 ? -339.2 * r2 + 161.4 * roughness - 25.9 : -8.48 * r2 + 14.3 * roughness - 9.95;
	float b = roughness < 0.25 ? 44.0 * r2 - 23.7 * roughness + 3.26 : 1.97 * r2 - 3.27 * roughness + 0.72;
	float DG = exp( a * dotNV + b ) + ( roughness < 0.25 ? 0.0 : 0.1 * ( roughness - 0.25 ) );
	return saturate( DG * RECIPROCAL_PI );
}
vec2 DFGApprox( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	const vec4 c0 = vec4( - 1, - 0.0275, - 0.572, 0.022 );
	const vec4 c1 = vec4( 1, 0.0425, 1.04, - 0.04 );
	vec4 r = roughness * c0 + c1;
	float a004 = min( r.x * r.x, exp2( - 9.28 * dotNV ) ) * r.x + r.y;
	vec2 fab = vec2( - 1.04, 1.04 ) * a004 + r.zw;
	return fab;
}
vec3 EnvironmentBRDF( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness ) {
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	return specularColor * fab.x + specularF90 * fab.y;
}
#ifdef USE_IRIDESCENCE
void computeMultiscatteringIridescence( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float iridescence, const in vec3 iridescenceF0, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#else
void computeMultiscattering( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#endif
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	#ifdef USE_IRIDESCENCE
		vec3 Fr = mix( specularColor, iridescenceF0, iridescence );
	#else
		vec3 Fr = specularColor;
	#endif
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + ( 1.0 - Fr ) * 0.047619;	vec3 Fms = FssEss * Favg / ( 1.0 - Ems * Favg );
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}
#if NUM_RECT_AREA_LIGHTS > 0
	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
		vec3 normal = geometryNormal;
		vec3 viewDir = geometryViewDir;
		vec3 position = geometryPosition;
		vec3 lightPos = rectAreaLight.position;
		vec3 halfWidth = rectAreaLight.halfWidth;
		vec3 halfHeight = rectAreaLight.halfHeight;
		vec3 lightColor = rectAreaLight.color;
		float roughness = material.roughness;
		vec3 rectCoords[ 4 ];
		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight;		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
		vec2 uv = LTC_Uv( normal, viewDir, roughness );
		vec4 t1 = texture2D( ltc_1, uv );
		vec4 t2 = texture2D( ltc_2, uv );
		mat3 mInv = mat3(
			vec3( t1.x, 0, t1.y ),
			vec3(    0, 1,    0 ),
			vec3( t1.z, 0, t1.w )
		);
		vec3 fresnel = ( material.specularColor * t2.x + ( vec3( 1.0 ) - material.specularColor ) * t2.y );
		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
		reflectedLight.directDiffuse += lightColor * material.diffuseColor * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
	}
#endif
void RE_Direct_Physical( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	#ifdef USE_CLEARCOAT
		float dotNLcc = saturate( dot( geometryClearcoatNormal, directLight.direction ) );
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance * BRDF_GGX_Clearcoat( directLight.direction, geometryViewDir, geometryClearcoatNormal, material );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularDirect += irradiance * BRDF_Sheen( directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness );
	#endif
	reflectedLight.directSpecular += irradiance * BRDF_GGX( directLight.direction, geometryViewDir, geometryNormal, material );
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Physical( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectSpecular_Physical( const in vec3 radiance, const in vec3 irradiance, const in vec3 clearcoatRadiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	#ifdef USE_CLEARCOAT
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF( geometryClearcoatNormal, geometryViewDir, material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularIndirect += irradiance * material.sheenColor * IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
	#endif
	vec3 singleScattering = vec3( 0.0 );
	vec3 multiScattering = vec3( 0.0 );
	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.iridescence, material.iridescenceFresnel, material.roughness, singleScattering, multiScattering );
	#else
		computeMultiscattering( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.roughness, singleScattering, multiScattering );
	#endif
	vec3 totalScattering = singleScattering + multiScattering;
	vec3 diffuse = material.diffuseColor * ( 1.0 - max( max( totalScattering.r, totalScattering.g ), totalScattering.b ) );
	reflectedLight.indirectSpecular += radiance * singleScattering;
	reflectedLight.indirectSpecular += multiScattering * cosineWeightedIrradiance;
	reflectedLight.indirectDiffuse += diffuse * cosineWeightedIrradiance;
}
#define RE_Direct				RE_Direct_Physical
#define RE_Direct_RectArea		RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular		RE_IndirectSpecular_Physical
float computeSpecularOcclusion( const in float dotNV, const in float ambientOcclusion, const in float roughness ) {
	return saturate( pow( dotNV + ambientOcclusion, exp2( - 16.0 * roughness - 1.0 ) ) - 1.0 + ambientOcclusion );
}`,wA=`
vec3 geometryPosition = - vViewPosition;
vec3 geometryNormal = normal;
vec3 geometryViewDir = ( isOrthographic ) ? vec3( 0, 0, 1 ) : normalize( vViewPosition );
vec3 geometryClearcoatNormal = vec3( 0.0 );
#ifdef USE_CLEARCOAT
	geometryClearcoatNormal = clearcoatNormal;
#endif
#ifdef USE_IRIDESCENCE
	float dotNVi = saturate( dot( normal, geometryViewDir ) );
	if ( material.iridescenceThickness == 0.0 ) {
		material.iridescence = 0.0;
	} else {
		material.iridescence = saturate( material.iridescence );
	}
	if ( material.iridescence > 0.0 ) {
		material.iridescenceFresnel = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.specularColor );
		material.iridescenceF0 = Schlick_to_F0( material.iridescenceFresnel, 1.0, dotNVi );
	}
#endif
IncidentLight directLight;
#if ( NUM_POINT_LIGHTS > 0 ) && defined( RE_Direct )
	PointLight pointLight;
	#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
		pointLight = pointLights[ i ];
		getPointLightInfo( pointLight, geometryPosition, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS )
		pointLightShadow = pointLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getPointShadow( pointShadowMap[ i ], pointLightShadow.shadowMapSize, pointLightShadow.shadowIntensity, pointLightShadow.shadowBias, pointLightShadow.shadowRadius, vPointShadowCoord[ i ], pointLightShadow.shadowCameraNear, pointLightShadow.shadowCameraFar ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SPOT_LIGHTS > 0 ) && defined( RE_Direct )
	SpotLight spotLight;
	vec4 spotColor;
	vec3 spotLightCoord;
	bool inSpotLightMap;
	#if defined( USE_SHADOWMAP ) && NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
		spotLight = spotLights[ i ];
		getSpotLightInfo( spotLight, geometryPosition, directLight );
		#if ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#define SPOT_LIGHT_MAP_INDEX UNROLLED_LOOP_INDEX
		#elif ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		#define SPOT_LIGHT_MAP_INDEX NUM_SPOT_LIGHT_MAPS
		#else
		#define SPOT_LIGHT_MAP_INDEX ( UNROLLED_LOOP_INDEX - NUM_SPOT_LIGHT_SHADOWS + NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#endif
		#if ( SPOT_LIGHT_MAP_INDEX < NUM_SPOT_LIGHT_MAPS )
			spotLightCoord = vSpotLightCoord[ i ].xyz / vSpotLightCoord[ i ].w;
			inSpotLightMap = all( lessThan( abs( spotLightCoord * 2. - 1. ), vec3( 1.0 ) ) );
			spotColor = texture2D( spotLightMap[ SPOT_LIGHT_MAP_INDEX ], spotLightCoord.xy );
			directLight.color = inSpotLightMap ? directLight.color * spotColor.rgb : directLight.color;
		#endif
		#undef SPOT_LIGHT_MAP_INDEX
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		spotLightShadow = spotLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( spotShadowMap[ i ], spotLightShadow.shadowMapSize, spotLightShadow.shadowIntensity, spotLightShadow.shadowBias, spotLightShadow.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_DIR_LIGHTS > 0 ) && defined( RE_Direct )
	DirectionalLight directionalLight;
	#if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
		directionalLight = directionalLights[ i ];
		getDirectionalLightInfo( directionalLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
		directionalLightShadow = directionalLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowIntensity, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_RECT_AREA_LIGHTS > 0 ) && defined( RE_Direct_RectArea )
	RectAreaLight rectAreaLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_RECT_AREA_LIGHTS; i ++ ) {
		rectAreaLight = rectAreaLights[ i ];
		RE_Direct_RectArea( rectAreaLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if defined( RE_IndirectDiffuse )
	vec3 iblIrradiance = vec3( 0.0 );
	vec3 irradiance = getAmbientLightIrradiance( ambientLightColor );
	#if defined( USE_LIGHT_PROBES )
		irradiance += getLightProbeIrradiance( lightProbe, geometryNormal );
	#endif
	#if ( NUM_HEMI_LIGHTS > 0 )
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_HEMI_LIGHTS; i ++ ) {
			irradiance += getHemisphereLightIrradiance( hemisphereLights[ i ], geometryNormal );
		}
		#pragma unroll_loop_end
	#endif
#endif
#if defined( RE_IndirectSpecular )
	vec3 radiance = vec3( 0.0 );
	vec3 clearcoatRadiance = vec3( 0.0 );
#endif`,TA=`#if defined( RE_IndirectDiffuse )
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		vec3 lightMapIrradiance = lightMapTexel.rgb * lightMapIntensity;
		irradiance += lightMapIrradiance;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD ) && defined( ENVMAP_TYPE_CUBE_UV )
		iblIrradiance += getIBLIrradiance( geometryNormal );
	#endif
#endif
#if defined( USE_ENVMAP ) && defined( RE_IndirectSpecular )
	#ifdef USE_ANISOTROPY
		radiance += getIBLAnisotropyRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
	#else
		radiance += getIBLRadiance( geometryViewDir, geometryNormal, material.roughness );
	#endif
	#ifdef USE_CLEARCOAT
		clearcoatRadiance += getIBLRadiance( geometryViewDir, geometryClearcoatNormal, material.clearcoatRoughness );
	#endif
#endif`,bA=`#if defined( RE_IndirectDiffuse )
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,AA=`#if defined( USE_LOGDEPTHBUF )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,CA=`#if defined( USE_LOGDEPTHBUF )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,NA=`#ifdef USE_LOGDEPTHBUF
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,RA=`#ifdef USE_LOGDEPTHBUF
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,PA=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = vec4( mix( pow( sampledDiffuseColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), sampledDiffuseColor.rgb * 0.0773993808, vec3( lessThanEqual( sampledDiffuseColor.rgb, vec3( 0.04045 ) ) ) ), sampledDiffuseColor.w );
	
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,kA=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,LA=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
	#if defined( USE_POINTS_UV )
		vec2 uv = vUv;
	#else
		vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;
	#endif
#endif
#ifdef USE_MAP
	diffuseColor *= texture2D( map, uv );
#endif
#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, uv ).g;
#endif`,DA=`#if defined( USE_POINTS_UV )
	varying vec2 vUv;
#else
	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
		uniform mat3 uvTransform;
	#endif
#endif
#ifdef USE_MAP
	uniform sampler2D map;
#endif
#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,IA=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,UA=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,FA=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,OA=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,jA=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,zA=`#ifdef USE_MORPHTARGETS
	#ifndef USE_INSTANCING_MORPH
		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	#endif
	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;
	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {
		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;
		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );
	}
#endif`,BA=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,HA=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
#ifdef FLAT_SHADED
	vec3 fdx = dFdx( vViewPosition );
	vec3 fdy = dFdy( vViewPosition );
	vec3 normal = normalize( cross( fdx, fdy ) );
#else
	vec3 normal = normalize( vNormal );
	#ifdef DOUBLE_SIDED
		normal *= faceDirection;
	#endif
#endif
#if defined( USE_NORMALMAP_TANGENTSPACE ) || defined( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY )
	#ifdef USE_TANGENT
		mat3 tbn = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn = getTangentFrame( - vViewPosition, normal,
		#if defined( USE_NORMALMAP )
			vNormalMapUv
		#elif defined( USE_CLEARCOAT_NORMALMAP )
			vClearcoatNormalMapUv
		#else
			vUv
		#endif
		);
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	#endif
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	#ifdef USE_TANGENT
		mat3 tbn2 = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn2 = getTangentFrame( - vViewPosition, normal, vClearcoatNormalMapUv );
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn2[0] *= faceDirection;
		tbn2[1] *= faceDirection;
	#endif
#endif
vec3 nonPerturbedNormal = normal;`,VA=`#ifdef USE_NORMALMAP_OBJECTSPACE
	normal = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#ifdef FLIP_SIDED
		normal = - normal;
	#endif
	#ifdef DOUBLE_SIDED
		normal = normal * faceDirection;
	#endif
	normal = normalize( normalMatrix * normal );
#elif defined( USE_NORMALMAP_TANGENTSPACE )
	vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	mapN.xy *= normalScale;
	normal = normalize( tbn * mapN );
#elif defined( USE_BUMPMAP )
	normal = perturbNormalArb( - vViewPosition, normal, dHdxy_fwd(), faceDirection );
#endif`,GA=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,WA=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,$A=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif
#endif`,XA=`#ifdef USE_NORMALMAP
	uniform sampler2D normalMap;
	uniform vec2 normalScale;
#endif
#ifdef USE_NORMALMAP_OBJECTSPACE
	uniform mat3 normalMatrix;
#endif
#if ! defined ( USE_TANGENT ) && ( defined ( USE_NORMALMAP_TANGENTSPACE ) || defined ( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY ) )
	mat3 getTangentFrame( vec3 eye_pos, vec3 surf_norm, vec2 uv ) {
		vec3 q0 = dFdx( eye_pos.xyz );
		vec3 q1 = dFdy( eye_pos.xyz );
		vec2 st0 = dFdx( uv.st );
		vec2 st1 = dFdy( uv.st );
		vec3 N = surf_norm;
		vec3 q1perp = cross( q1, N );
		vec3 q0perp = cross( N, q0 );
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max( dot( T, T ), dot( B, B ) );
		float scale = ( det == 0.0 ) ? 0.0 : inversesqrt( det );
		return mat3( T * scale, B * scale, N );
	}
#endif`,qA=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,YA=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,KA=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,ZA=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,QA=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,JA=`vec3 packNormalToRGB( const in vec3 normal ) {
	return normalize( normal ) * 0.5 + 0.5;
}
vec3 unpackRGBToNormal( const in vec3 rgb ) {
	return 2.0 * rgb.xyz - 1.0;
}
const float PackUpscale = 256. / 255.;const float UnpackDownscale = 255. / 256.;const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4( 1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0 );
const vec2 UnpackFactors2 = vec2( UnpackDownscale, 1.0 / PackFactors.g );
const vec3 UnpackFactors3 = vec3( UnpackDownscale / PackFactors.rg, 1.0 / PackFactors.b );
const vec4 UnpackFactors4 = vec4( UnpackDownscale / PackFactors.rgb, 1.0 / PackFactors.a );
vec4 packDepthToRGBA( const in float v ) {
	if( v <= 0.0 )
		return vec4( 0., 0., 0., 0. );
	if( v >= 1.0 )
		return vec4( 1., 1., 1., 1. );
	float vuf;
	float af = modf( v * PackFactors.a, vuf );
	float bf = modf( vuf * ShiftRight8, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec4( vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af );
}
vec3 packDepthToRGB( const in float v ) {
	if( v <= 0.0 )
		return vec3( 0., 0., 0. );
	if( v >= 1.0 )
		return vec3( 1., 1., 1. );
	float vuf;
	float bf = modf( v * PackFactors.b, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec3( vuf * Inv255, gf * PackUpscale, bf );
}
vec2 packDepthToRG( const in float v ) {
	if( v <= 0.0 )
		return vec2( 0., 0. );
	if( v >= 1.0 )
		return vec2( 1., 1. );
	float vuf;
	float gf = modf( v * 256., vuf );
	return vec2( vuf * Inv255, gf );
}
float unpackRGBAToDepth( const in vec4 v ) {
	return dot( v, UnpackFactors4 );
}
float unpackRGBToDepth( const in vec3 v ) {
	return dot( v, UnpackFactors3 );
}
float unpackRGToDepth( const in vec2 v ) {
	return v.r * UnpackFactors2.r + v.g * UnpackFactors2.g;
}
vec4 pack2HalfToRGBA( const in vec2 v ) {
	vec4 r = vec4( v.x, fract( v.x * 255.0 ), v.y, fract( v.y * 255.0 ) );
	return vec4( r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w );
}
vec2 unpackRGBATo2Half( const in vec4 v ) {
	return vec2( v.x + ( v.y / 255.0 ), v.z + ( v.w / 255.0 ) );
}
float viewZToOrthographicDepth( const in float viewZ, const in float near, const in float far ) {
	return ( viewZ + near ) / ( near - far );
}
float orthographicDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return depth * ( near - far ) - near;
}
float viewZToPerspectiveDepth( const in float viewZ, const in float near, const in float far ) {
	return ( ( near + viewZ ) * far ) / ( ( far - near ) * viewZ );
}
float perspectiveDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return ( near * far ) / ( ( far - near ) * depth - far );
}`,eC=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,tC=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,nC=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,iC=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,sC=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,rC=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,aC=`#if NUM_SPOT_LIGHT_COORDS > 0
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#if NUM_SPOT_LIGHT_MAPS > 0
	uniform sampler2D spotLightMap[ NUM_SPOT_LIGHT_MAPS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform sampler2D pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
	float texture2DCompare( sampler2D depths, vec2 uv, float compare ) {
		return step( compare, unpackRGBAToDepth( texture2D( depths, uv ) ) );
	}
	vec2 texture2DDistribution( sampler2D shadow, vec2 uv ) {
		return unpackRGBATo2Half( texture2D( shadow, uv ) );
	}
	float VSMShadow (sampler2D shadow, vec2 uv, float compare ){
		float occlusion = 1.0;
		vec2 distribution = texture2DDistribution( shadow, uv );
		float hard_shadow = step( compare , distribution.x );
		if (hard_shadow != 1.0 ) {
			float distance = compare - distribution.x ;
			float variance = max( 0.00000, distribution.y * distribution.y );
			float softness_probability = variance / (variance + distance * distance );			softness_probability = clamp( ( softness_probability - 0.3 ) / ( 0.95 - 0.3 ), 0.0, 1.0 );			occlusion = clamp( max( hard_shadow, softness_probability ), 0.0, 1.0 );
		}
		return occlusion;
	}
	float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
		float shadow = 1.0;
		shadowCoord.xyz /= shadowCoord.w;
		shadowCoord.z += shadowBias;
		bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
		bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
		if ( frustumTest ) {
		#if defined( SHADOWMAP_TYPE_PCF )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx0 = - texelSize.x * shadowRadius;
			float dy0 = - texelSize.y * shadowRadius;
			float dx1 = + texelSize.x * shadowRadius;
			float dy1 = + texelSize.y * shadowRadius;
			float dx2 = dx0 / 2.0;
			float dy2 = dy0 / 2.0;
			float dx3 = dx1 / 2.0;
			float dy3 = dy1 / 2.0;
			shadow = (
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy1 ), shadowCoord.z )
			) * ( 1.0 / 17.0 );
		#elif defined( SHADOWMAP_TYPE_PCF_SOFT )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx = texelSize.x;
			float dy = texelSize.y;
			vec2 uv = shadowCoord.xy;
			vec2 f = fract( uv * shadowMapSize + 0.5 );
			uv -= f * texelSize;
			shadow = (
				texture2DCompare( shadowMap, uv, shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( dx, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( 0.0, dy ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + texelSize, shadowCoord.z ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, 0.0 ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 0.0 ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, dy ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( 0.0, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 0.0, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( texture2DCompare( shadowMap, uv + vec2( dx, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( dx, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( mix( texture2DCompare( shadowMap, uv + vec2( -dx, -dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, -dy ), shadowCoord.z ),
						  f.x ),
					 mix( texture2DCompare( shadowMap, uv + vec2( -dx, 2.0 * dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 2.0 * dy ), shadowCoord.z ),
						  f.x ),
					 f.y )
			) * ( 1.0 / 9.0 );
		#elif defined( SHADOWMAP_TYPE_VSM )
			shadow = VSMShadow( shadowMap, shadowCoord.xy, shadowCoord.z );
		#else
			shadow = texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z );
		#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	vec2 cubeToUV( vec3 v, float texelSizeY ) {
		vec3 absV = abs( v );
		float scaleToCube = 1.0 / max( absV.x, max( absV.y, absV.z ) );
		absV *= scaleToCube;
		v *= scaleToCube * ( 1.0 - 2.0 * texelSizeY );
		vec2 planar = v.xy;
		float almostATexel = 1.5 * texelSizeY;
		float almostOne = 1.0 - almostATexel;
		if ( absV.z >= almostOne ) {
			if ( v.z > 0.0 )
				planar.x = 4.0 - v.x;
		} else if ( absV.x >= almostOne ) {
			float signX = sign( v.x );
			planar.x = v.z * signX + 2.0 * signX;
		} else if ( absV.y >= almostOne ) {
			float signY = sign( v.y );
			planar.x = v.x + 2.0 * signY + 2.0;
			planar.y = v.z * signY - 2.0;
		}
		return vec2( 0.125, 0.25 ) * planar + vec2( 0.375, 0.75 );
	}
	float getPointShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		
		float lightToPositionLength = length( lightToPosition );
		if ( lightToPositionLength - shadowCameraFar <= 0.0 && lightToPositionLength - shadowCameraNear >= 0.0 ) {
			float dp = ( lightToPositionLength - shadowCameraNear ) / ( shadowCameraFar - shadowCameraNear );			dp += shadowBias;
			vec3 bd3D = normalize( lightToPosition );
			vec2 texelSize = vec2( 1.0 ) / ( shadowMapSize * vec2( 4.0, 2.0 ) );
			#if defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_PCF_SOFT ) || defined( SHADOWMAP_TYPE_VSM )
				vec2 offset = vec2( - 1, 1 ) * shadowRadius * texelSize.y;
				shadow = (
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxx, texelSize.y ), dp )
				) * ( 1.0 / 9.0 );
			#else
				shadow = texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp );
			#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
#endif`,oC=`#if NUM_SPOT_LIGHT_COORDS > 0
	uniform mat4 spotLightMatrix[ NUM_SPOT_LIGHT_COORDS ];
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform mat4 directionalShadowMatrix[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform mat4 pointShadowMatrix[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
#endif`,lC=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
	vec3 shadowWorldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
	vec4 shadowWorldPosition;
#endif
#if defined( USE_SHADOWMAP )
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * directionalLightShadows[ i ].shadowNormalBias, 0 );
			vDirectionalShadowCoord[ i ] = directionalShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * pointLightShadows[ i ].shadowNormalBias, 0 );
			vPointShadowCoord[ i ] = pointShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
#endif
#if NUM_SPOT_LIGHT_COORDS > 0
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_COORDS; i ++ ) {
		shadowWorldPosition = worldPosition;
		#if ( defined( USE_SHADOWMAP ) && UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
			shadowWorldPosition.xyz += shadowWorldNormal * spotLightShadows[ i ].shadowNormalBias;
		#endif
		vSpotLightCoord[ i ] = spotLightMatrix[ i ] * shadowWorldPosition;
	}
	#pragma unroll_loop_end
#endif`,cC=`float getShadowMask() {
	float shadow = 1.0;
	#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
		directionalLight = directionalLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowIntensity, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_SHADOWS; i ++ ) {
		spotLight = spotLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( spotShadowMap[ i ], spotLight.shadowMapSize, spotLight.shadowIntensity, spotLight.shadowBias, spotLight.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
		pointLight = pointLightShadows[ i ];
		shadow *= receiveShadow ? getPointShadow( pointShadowMap[ i ], pointLight.shadowMapSize, pointLight.shadowIntensity, pointLight.shadowBias, pointLight.shadowRadius, vPointShadowCoord[ i ], pointLight.shadowCameraNear, pointLight.shadowCameraFar ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#endif
	return shadow;
}`,uC=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,dC=`#ifdef USE_SKINNING
	uniform mat4 bindMatrix;
	uniform mat4 bindMatrixInverse;
	uniform highp sampler2D boneTexture;
	mat4 getBoneMatrix( const in float i ) {
		int size = textureSize( boneTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( boneTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( boneTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( boneTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( boneTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
#endif`,hC=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,fC=`#ifdef USE_SKINNING
	mat4 skinMatrix = mat4( 0.0 );
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = bindMatrixInverse * skinMatrix * bindMatrix;
	objectNormal = vec4( skinMatrix * vec4( objectNormal, 0.0 ) ).xyz;
	#ifdef USE_TANGENT
		objectTangent = vec4( skinMatrix * vec4( objectTangent, 0.0 ) ).xyz;
	#endif
#endif`,pC=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,mC=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,gC=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,_C=`#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
uniform float toneMappingExposure;
vec3 LinearToneMapping( vec3 color ) {
	return saturate( toneMappingExposure * color );
}
vec3 ReinhardToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	return saturate( color / ( vec3( 1.0 ) + color ) );
}
vec3 CineonToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	color = max( vec3( 0.0 ), color - 0.004 );
	return pow( ( color * ( 6.2 * color + 0.5 ) ) / ( color * ( 6.2 * color + 1.7 ) + 0.06 ), vec3( 2.2 ) );
}
vec3 RRTAndODTFit( vec3 v ) {
	vec3 a = v * ( v + 0.0245786 ) - 0.000090537;
	vec3 b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
	return a / b;
}
vec3 ACESFilmicToneMapping( vec3 color ) {
	const mat3 ACESInputMat = mat3(
		vec3( 0.59719, 0.07600, 0.02840 ),		vec3( 0.35458, 0.90834, 0.13383 ),
		vec3( 0.04823, 0.01566, 0.83777 )
	);
	const mat3 ACESOutputMat = mat3(
		vec3(  1.60475, -0.10208, -0.00327 ),		vec3( -0.53108,  1.10813, -0.07276 ),
		vec3( -0.07367, -0.00605,  1.07602 )
	);
	color *= toneMappingExposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit( color );
	color = ACESOutputMat * color;
	return saturate( color );
}
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3( 1.6605, - 0.1246, - 0.0182 ),
	vec3( - 0.5876, 1.1329, - 0.1006 ),
	vec3( - 0.0728, - 0.0083, 1.1187 )
);
const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3( 0.6274, 0.0691, 0.0164 ),
	vec3( 0.3293, 0.9195, 0.0880 ),
	vec3( 0.0433, 0.0113, 0.8956 )
);
vec3 agxDefaultContrastApprox( vec3 x ) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return + 15.5 * x4 * x2
		- 40.14 * x4 * x
		+ 31.96 * x4
		- 6.868 * x2 * x
		+ 0.4298 * x2
		+ 0.1191 * x
		- 0.00232;
}
vec3 AgXToneMapping( vec3 color ) {
	const mat3 AgXInsetMatrix = mat3(
		vec3( 0.856627153315983, 0.137318972929847, 0.11189821299995 ),
		vec3( 0.0951212405381588, 0.761241990602591, 0.0767994186031903 ),
		vec3( 0.0482516061458583, 0.101439036467562, 0.811302368396859 )
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3( 1.1271005818144368, - 0.1413297634984383, - 0.14132976349843826 ),
		vec3( - 0.11060664309660323, 1.157823702216272, - 0.11060664309660294 ),
		vec3( - 0.016493938717834573, - 0.016493938717834257, 1.2519364065950405 )
	);
	const float AgxMinEv = - 12.47393;	const float AgxMaxEv = 4.026069;
	color *= toneMappingExposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max( color, 1e-10 );	color = log2( color );
	color = ( color - AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
	color = clamp( color, 0.0, 1.0 );
	color = agxDefaultContrastApprox( color );
	color = AgXOutsetMatrix * color;
	color = pow( max( vec3( 0.0 ), color ), vec3( 2.2 ) );
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp( color, 0.0, 1.0 );
	return color;
}
vec3 NeutralToneMapping( vec3 color ) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= toneMappingExposure;
	float x = min( color.r, min( color.g, color.b ) );
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max( color.r, max( color.g, color.b ) );
	if ( peak < StartCompression ) return color;
	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / ( peak + d - StartCompression );
	color *= newPeak / peak;
	float g = 1. - 1. / ( Desaturation * ( peak - newPeak ) + 1. );
	return mix( color, vec3( newPeak ), g );
}
vec3 CustomToneMapping( vec3 color ) { return color; }`,vC=`#ifdef USE_TRANSMISSION
	material.transmission = transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = thickness;
	material.attenuationDistance = attenuationDistance;
	material.attenuationColor = attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		material.transmission *= texture2D( transmissionMap, vTransmissionMapUv ).r;
	#endif
	#ifdef USE_THICKNESSMAP
		material.thickness *= texture2D( thicknessMap, vThicknessMapUv ).g;
	#endif
	vec3 pos = vWorldPosition;
	vec3 v = normalize( cameraPosition - pos );
	vec3 n = inverseTransformDirection( normal, viewMatrix );
	vec4 transmitted = getIBLVolumeRefraction(
		n, v, material.roughness, material.diffuseColor, material.specularColor, material.specularF90,
		pos, modelMatrix, viewMatrix, projectionMatrix, material.dispersion, material.ior, material.thickness,
		material.attenuationColor, material.attenuationDistance );
	material.transmissionAlpha = mix( material.transmissionAlpha, transmitted.a, material.transmission );
	totalDiffuse = mix( totalDiffuse, transmitted.rgb, material.transmission );
#endif`,xC=`#ifdef USE_TRANSMISSION
	uniform float transmission;
	uniform float thickness;
	uniform float attenuationDistance;
	uniform vec3 attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		uniform sampler2D transmissionMap;
	#endif
	#ifdef USE_THICKNESSMAP
		uniform sampler2D thicknessMap;
	#endif
	uniform vec2 transmissionSamplerSize;
	uniform sampler2D transmissionSamplerMap;
	uniform mat4 modelMatrix;
	uniform mat4 projectionMatrix;
	varying vec3 vWorldPosition;
	float w0( float a ) {
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - a + 3.0 ) - 3.0 ) + 1.0 );
	}
	float w1( float a ) {
		return ( 1.0 / 6.0 ) * ( a *  a * ( 3.0 * a - 6.0 ) + 4.0 );
	}
	float w2( float a ){
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - 3.0 * a + 3.0 ) + 3.0 ) + 1.0 );
	}
	float w3( float a ) {
		return ( 1.0 / 6.0 ) * ( a * a * a );
	}
	float g0( float a ) {
		return w0( a ) + w1( a );
	}
	float g1( float a ) {
		return w2( a ) + w3( a );
	}
	float h0( float a ) {
		return - 1.0 + w1( a ) / ( w0( a ) + w1( a ) );
	}
	float h1( float a ) {
		return 1.0 + w3( a ) / ( w2( a ) + w3( a ) );
	}
	vec4 bicubic( sampler2D tex, vec2 uv, vec4 texelSize, float lod ) {
		uv = uv * texelSize.zw + 0.5;
		vec2 iuv = floor( uv );
		vec2 fuv = fract( uv );
		float g0x = g0( fuv.x );
		float g1x = g1( fuv.x );
		float h0x = h0( fuv.x );
		float h1x = h1( fuv.x );
		float h0y = h0( fuv.y );
		float h1y = h1( fuv.y );
		vec2 p0 = ( vec2( iuv.x + h0x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p1 = ( vec2( iuv.x + h1x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p2 = ( vec2( iuv.x + h0x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		vec2 p3 = ( vec2( iuv.x + h1x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		return g0( fuv.y ) * ( g0x * textureLod( tex, p0, lod ) + g1x * textureLod( tex, p1, lod ) ) +
			g1( fuv.y ) * ( g0x * textureLod( tex, p2, lod ) + g1x * textureLod( tex, p3, lod ) );
	}
	vec4 textureBicubic( sampler2D sampler, vec2 uv, float lod ) {
		vec2 fLodSize = vec2( textureSize( sampler, int( lod ) ) );
		vec2 cLodSize = vec2( textureSize( sampler, int( lod + 1.0 ) ) );
		vec2 fLodSizeInv = 1.0 / fLodSize;
		vec2 cLodSizeInv = 1.0 / cLodSize;
		vec4 fSample = bicubic( sampler, uv, vec4( fLodSizeInv, fLodSize ), floor( lod ) );
		vec4 cSample = bicubic( sampler, uv, vec4( cLodSizeInv, cLodSize ), ceil( lod ) );
		return mix( fSample, cSample, fract( lod ) );
	}
	vec3 getVolumeTransmissionRay( const in vec3 n, const in vec3 v, const in float thickness, const in float ior, const in mat4 modelMatrix ) {
		vec3 refractionVector = refract( - v, normalize( n ), 1.0 / ior );
		vec3 modelScale;
		modelScale.x = length( vec3( modelMatrix[ 0 ].xyz ) );
		modelScale.y = length( vec3( modelMatrix[ 1 ].xyz ) );
		modelScale.z = length( vec3( modelMatrix[ 2 ].xyz ) );
		return normalize( refractionVector ) * thickness * modelScale;
	}
	float applyIorToRoughness( const in float roughness, const in float ior ) {
		return roughness * clamp( ior * 2.0 - 2.0, 0.0, 1.0 );
	}
	vec4 getTransmissionSample( const in vec2 fragCoord, const in float roughness, const in float ior ) {
		float lod = log2( transmissionSamplerSize.x ) * applyIorToRoughness( roughness, ior );
		return textureBicubic( transmissionSamplerMap, fragCoord.xy, lod );
	}
	vec3 volumeAttenuation( const in float transmissionDistance, const in vec3 attenuationColor, const in float attenuationDistance ) {
		if ( isinf( attenuationDistance ) ) {
			return vec3( 1.0 );
		} else {
			vec3 attenuationCoefficient = -log( attenuationColor ) / attenuationDistance;
			vec3 transmittance = exp( - attenuationCoefficient * transmissionDistance );			return transmittance;
		}
	}
	vec4 getIBLVolumeRefraction( const in vec3 n, const in vec3 v, const in float roughness, const in vec3 diffuseColor,
		const in vec3 specularColor, const in float specularF90, const in vec3 position, const in mat4 modelMatrix,
		const in mat4 viewMatrix, const in mat4 projMatrix, const in float dispersion, const in float ior, const in float thickness,
		const in vec3 attenuationColor, const in float attenuationDistance ) {
		vec4 transmittedLight;
		vec3 transmittance;
		#ifdef USE_DISPERSION
			float halfSpread = ( ior - 1.0 ) * 0.025 * dispersion;
			vec3 iors = vec3( ior - halfSpread, ior, ior + halfSpread );
			for ( int i = 0; i < 3; i ++ ) {
				vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, iors[ i ], modelMatrix );
				vec3 refractedRayExit = position + transmissionRay;
		
				vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
				vec2 refractionCoords = ndcPos.xy / ndcPos.w;
				refractionCoords += 1.0;
				refractionCoords /= 2.0;
		
				vec4 transmissionSample = getTransmissionSample( refractionCoords, roughness, iors[ i ] );
				transmittedLight[ i ] = transmissionSample[ i ];
				transmittedLight.a += transmissionSample.a;
				transmittance[ i ] = diffuseColor[ i ] * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance )[ i ];
			}
			transmittedLight.a /= 3.0;
		
		#else
		
			vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix );
			vec3 refractedRayExit = position + transmissionRay;
			vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
			vec2 refractionCoords = ndcPos.xy / ndcPos.w;
			refractionCoords += 1.0;
			refractionCoords /= 2.0;
			transmittedLight = getTransmissionSample( refractionCoords, roughness, ior );
			transmittance = diffuseColor * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance );
		
		#endif
		vec3 attenuatedColor = transmittance * transmittedLight.rgb;
		vec3 F = EnvironmentBRDF( n, v, specularColor, specularF90, roughness );
		float transmittanceFactor = ( transmittance.r + transmittance.g + transmittance.b ) / 3.0;
		return vec4( ( 1.0 - F ) * attenuatedColor, 1.0 - ( 1.0 - transmittedLight.a ) * transmittanceFactor );
	}
#endif`,yC=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_SPECULARMAP
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,SC=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	uniform mat3 mapTransform;
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	uniform mat3 alphaMapTransform;
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	uniform mat3 lightMapTransform;
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	uniform mat3 aoMapTransform;
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	uniform mat3 bumpMapTransform;
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	uniform mat3 normalMapTransform;
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_DISPLACEMENTMAP
	uniform mat3 displacementMapTransform;
	varying vec2 vDisplacementMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	uniform mat3 emissiveMapTransform;
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	uniform mat3 metalnessMapTransform;
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	uniform mat3 roughnessMapTransform;
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	uniform mat3 anisotropyMapTransform;
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	uniform mat3 clearcoatMapTransform;
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform mat3 clearcoatNormalMapTransform;
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform mat3 clearcoatRoughnessMapTransform;
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	uniform mat3 sheenColorMapTransform;
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	uniform mat3 sheenRoughnessMapTransform;
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	uniform mat3 iridescenceMapTransform;
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform mat3 iridescenceThicknessMapTransform;
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SPECULARMAP
	uniform mat3 specularMapTransform;
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	uniform mat3 specularColorMapTransform;
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	uniform mat3 specularIntensityMapTransform;
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,MC=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	vUv = vec3( uv, 1 ).xy;
#endif
#ifdef USE_MAP
	vMapUv = ( mapTransform * vec3( MAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ALPHAMAP
	vAlphaMapUv = ( alphaMapTransform * vec3( ALPHAMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_LIGHTMAP
	vLightMapUv = ( lightMapTransform * vec3( LIGHTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_AOMAP
	vAoMapUv = ( aoMapTransform * vec3( AOMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_BUMPMAP
	vBumpMapUv = ( bumpMapTransform * vec3( BUMPMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_NORMALMAP
	vNormalMapUv = ( normalMapTransform * vec3( NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_DISPLACEMENTMAP
	vDisplacementMapUv = ( displacementMapTransform * vec3( DISPLACEMENTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_EMISSIVEMAP
	vEmissiveMapUv = ( emissiveMapTransform * vec3( EMISSIVEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_METALNESSMAP
	vMetalnessMapUv = ( metalnessMapTransform * vec3( METALNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ROUGHNESSMAP
	vRoughnessMapUv = ( roughnessMapTransform * vec3( ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ANISOTROPYMAP
	vAnisotropyMapUv = ( anisotropyMapTransform * vec3( ANISOTROPYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOATMAP
	vClearcoatMapUv = ( clearcoatMapTransform * vec3( CLEARCOATMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	vClearcoatNormalMapUv = ( clearcoatNormalMapTransform * vec3( CLEARCOAT_NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	vClearcoatRoughnessMapUv = ( clearcoatRoughnessMapTransform * vec3( CLEARCOAT_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCEMAP
	vIridescenceMapUv = ( iridescenceMapTransform * vec3( IRIDESCENCEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	vIridescenceThicknessMapUv = ( iridescenceThicknessMapTransform * vec3( IRIDESCENCE_THICKNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_COLORMAP
	vSheenColorMapUv = ( sheenColorMapTransform * vec3( SHEEN_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	vSheenRoughnessMapUv = ( sheenRoughnessMapTransform * vec3( SHEEN_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULARMAP
	vSpecularMapUv = ( specularMapTransform * vec3( SPECULARMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_COLORMAP
	vSpecularColorMapUv = ( specularColorMapTransform * vec3( SPECULAR_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	vSpecularIntensityMapUv = ( specularIntensityMapTransform * vec3( SPECULAR_INTENSITYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_TRANSMISSIONMAP
	vTransmissionMapUv = ( transmissionMapTransform * vec3( TRANSMISSIONMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_THICKNESSMAP
	vThicknessMapUv = ( thicknessMapTransform * vec3( THICKNESSMAP_UV, 1 ) ).xy;
#endif`,EC=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`;const wC=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,TC=`uniform sampler2D t2D;
uniform float backgroundIntensity;
varying vec2 vUv;
void main() {
	vec4 texColor = texture2D( t2D, vUv );
	#ifdef DECODE_VIDEO_TEXTURE
		texColor = vec4( mix( pow( texColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), texColor.rgb * 0.0773993808, vec3( lessThanEqual( texColor.rgb, vec3( 0.04045 ) ) ) ), texColor.w );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,bC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,AC=`#ifdef ENVMAP_TYPE_CUBE
	uniform samplerCube envMap;
#elif defined( ENVMAP_TYPE_CUBE_UV )
	uniform sampler2D envMap;
#endif
uniform float flipEnvMap;
uniform float backgroundBlurriness;
uniform float backgroundIntensity;
uniform mat3 backgroundRotation;
varying vec3 vWorldDirection;
#include <cube_uv_reflection_fragment>
void main() {
	#ifdef ENVMAP_TYPE_CUBE
		vec4 texColor = textureCube( envMap, backgroundRotation * vec3( flipEnvMap * vWorldDirection.x, vWorldDirection.yz ) );
	#elif defined( ENVMAP_TYPE_CUBE_UV )
		vec4 texColor = textureCubeUV( envMap, backgroundRotation * vWorldDirection, backgroundBlurriness );
	#else
		vec4 texColor = vec4( 0.0, 0.0, 0.0, 1.0 );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,CC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,NC=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,RC=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
varying vec2 vHighPrecisionZW;
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vHighPrecisionZW = gl_Position.zw;
}`,PC=`#if DEPTH_PACKING == 3200
	uniform float opacity;
#endif
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
varying vec2 vHighPrecisionZW;
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#if DEPTH_PACKING == 3200
		diffuseColor.a = opacity;
	#endif
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <logdepthbuf_fragment>
	float fragCoordZ = 0.5 * vHighPrecisionZW[0] / vHighPrecisionZW[1] + 0.5;
	#if DEPTH_PACKING == 3200
		gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );
	#elif DEPTH_PACKING == 3201
		gl_FragColor = packDepthToRGBA( fragCoordZ );
	#elif DEPTH_PACKING == 3202
		gl_FragColor = vec4( packDepthToRGB( fragCoordZ ), 1.0 );
	#elif DEPTH_PACKING == 3203
		gl_FragColor = vec4( packDepthToRG( fragCoordZ ), 0.0, 1.0 );
	#endif
}`,kC=`#define DISTANCE
varying vec3 vWorldPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <worldpos_vertex>
	#include <clipping_planes_vertex>
	vWorldPosition = worldPosition.xyz;
}`,LC=`#define DISTANCE
uniform vec3 referencePosition;
uniform float nearDistance;
uniform float farDistance;
varying vec3 vWorldPosition;
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <clipping_planes_pars_fragment>
void main () {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	float dist = length( vWorldPosition - referencePosition );
	dist = ( dist - nearDistance ) / ( farDistance - nearDistance );
	dist = saturate( dist );
	gl_FragColor = packDepthToRGBA( dist );
}`,DC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,IC=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,UC=`uniform float scale;
attribute float lineDistance;
varying float vLineDistance;
#include <common>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	vLineDistance = scale * lineDistance;
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,FC=`uniform vec3 diffuse;
uniform float opacity;
uniform float dashSize;
uniform float totalSize;
varying float vLineDistance;
#include <common>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	if ( mod( vLineDistance, totalSize ) > dashSize ) {
		discard;
	}
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,OC=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#if defined ( USE_ENVMAP ) || defined ( USE_SKINNING )
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinbase_vertex>
		#include <skinnormal_vertex>
		#include <defaultnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <fog_vertex>
}`,jC=`uniform vec3 diffuse;
uniform float opacity;
#ifndef FLAT_SHADED
	varying vec3 vNormal;
#endif
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		reflectedLight.indirectDiffuse += lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI;
	#else
		reflectedLight.indirectDiffuse += vec3( 1.0 );
	#endif
	#include <aomap_fragment>
	reflectedLight.indirectDiffuse *= diffuseColor.rgb;
	vec3 outgoingLight = reflectedLight.indirectDiffuse;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,zC=`#define LAMBERT
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,BC=`#define LAMBERT
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_lambert_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_lambert_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,HC=`#define MATCAP
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <displacementmap_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
	vViewPosition = - mvPosition.xyz;
}`,VC=`#define MATCAP
uniform vec3 diffuse;
uniform float opacity;
uniform sampler2D matcap;
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	vec3 viewDir = normalize( vViewPosition );
	vec3 x = normalize( vec3( viewDir.z, 0.0, - viewDir.x ) );
	vec3 y = cross( viewDir, x );
	vec2 uv = vec2( dot( x, normal ), dot( y, normal ) ) * 0.495 + 0.5;
	#ifdef USE_MATCAP
		vec4 matcapColor = texture2D( matcap, uv );
	#else
		vec4 matcapColor = vec4( vec3( mix( 0.2, 0.8, uv.y ) ), 1.0 );
	#endif
	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,GC=`#define NORMAL
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	vViewPosition = - mvPosition.xyz;
#endif
}`,WC=`#define NORMAL
uniform float opacity;
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <packing>
#include <uv_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 0.0, 0.0, 0.0, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	gl_FragColor = vec4( packNormalToRGB( normal ), diffuseColor.a );
	#ifdef OPAQUE
		gl_FragColor.a = 1.0;
	#endif
}`,$C=`#define PHONG
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,XC=`#define PHONG
uniform vec3 diffuse;
uniform vec3 emissive;
uniform vec3 specular;
uniform float shininess;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_phong_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_phong_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,qC=`#define STANDARD
varying vec3 vViewPosition;
#ifdef USE_TRANSMISSION
	varying vec3 vWorldPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
#ifdef USE_TRANSMISSION
	vWorldPosition = worldPosition.xyz;
#endif
}`,YC=`#define STANDARD
#ifdef PHYSICAL
	#define IOR
	#define USE_SPECULAR
#endif
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
#ifdef IOR
	uniform float ior;
#endif
#ifdef USE_SPECULAR
	uniform float specularIntensity;
	uniform vec3 specularColor;
	#ifdef USE_SPECULAR_COLORMAP
		uniform sampler2D specularColorMap;
	#endif
	#ifdef USE_SPECULAR_INTENSITYMAP
		uniform sampler2D specularIntensityMap;
	#endif
#endif
#ifdef USE_CLEARCOAT
	uniform float clearcoat;
	uniform float clearcoatRoughness;
#endif
#ifdef USE_DISPERSION
	uniform float dispersion;
#endif
#ifdef USE_IRIDESCENCE
	uniform float iridescence;
	uniform float iridescenceIOR;
	uniform float iridescenceThicknessMinimum;
	uniform float iridescenceThicknessMaximum;
#endif
#ifdef USE_SHEEN
	uniform vec3 sheenColor;
	uniform float sheenRoughness;
	#ifdef USE_SHEEN_COLORMAP
		uniform sampler2D sheenColorMap;
	#endif
	#ifdef USE_SHEEN_ROUGHNESSMAP
		uniform sampler2D sheenRoughnessMap;
	#endif
#endif
#ifdef USE_ANISOTROPY
	uniform vec2 anisotropyVector;
	#ifdef USE_ANISOTROPYMAP
		uniform sampler2D anisotropyMap;
	#endif
#endif
varying vec3 vViewPosition;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <iridescence_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_physical_pars_fragment>
#include <transmission_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <clearcoat_pars_fragment>
#include <iridescence_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <roughnessmap_fragment>
	#include <metalnessmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <clearcoat_normal_fragment_begin>
	#include <clearcoat_normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_physical_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;
	#include <transmission_fragment>
	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;
	#ifdef USE_SHEEN
		float sheenEnergyComp = 1.0 - 0.157 * max3( material.sheenColor );
		outgoingLight = outgoingLight * sheenEnergyComp + sheenSpecularDirect + sheenSpecularIndirect;
	#endif
	#ifdef USE_CLEARCOAT
		float dotNVcc = saturate( dot( geometryClearcoatNormal, geometryViewDir ) );
		vec3 Fcc = F_Schlick( material.clearcoatF0, material.clearcoatF90, dotNVcc );
		outgoingLight = outgoingLight * ( 1.0 - material.clearcoat * Fcc ) + ( clearcoatSpecularDirect + clearcoatSpecularIndirect ) * material.clearcoat;
	#endif
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,KC=`#define TOON
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,ZC=`#define TOON
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <gradientmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_toon_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_toon_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,QC=`uniform float size;
uniform float scale;
#include <common>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <fog_vertex>
}`,JC=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <color_pars_fragment>
#include <map_particle_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_particle_fragment>
	#include <color_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,eN=`#include <common>
#include <batching_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>
void main() {
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,tN=`uniform vec3 color;
uniform float opacity;
#include <common>
#include <packing>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <logdepthbuf_pars_fragment>
#include <shadowmap_pars_fragment>
#include <shadowmask_pars_fragment>
void main() {
	#include <logdepthbuf_fragment>
	gl_FragColor = vec4( color, opacity * ( 1.0 - getShadowMask() ) );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,nN=`uniform float rotation;
uniform vec2 center;
#include <common>
#include <uv_pars_vertex>
#include <fog_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	vec4 mvPosition = modelViewMatrix[ 3 ];
	vec2 scale = vec2( length( modelMatrix[ 0 ].xyz ), length( modelMatrix[ 1 ].xyz ) );
	#ifndef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) scale *= - mvPosition.z;
	#endif
	vec2 alignedPosition = ( position.xy - ( center - vec2( 0.5 ) ) ) * scale;
	vec2 rotatedPosition;
	rotatedPosition.x = cos( rotation ) * alignedPosition.x - sin( rotation ) * alignedPosition.y;
	rotatedPosition.y = sin( rotation ) * alignedPosition.x + cos( rotation ) * alignedPosition.y;
	mvPosition.xy += rotatedPosition;
	gl_Position = projectionMatrix * mvPosition;
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,iN=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,ut={alphahash_fragment:Tb,alphahash_pars_fragment:bb,alphamap_fragment:Ab,alphamap_pars_fragment:Cb,alphatest_fragment:Nb,alphatest_pars_fragment:Rb,aomap_fragment:Pb,aomap_pars_fragment:kb,batching_pars_vertex:Lb,batching_vertex:Db,begin_vertex:Ib,beginnormal_vertex:Ub,bsdfs:Fb,iridescence_fragment:Ob,bumpmap_pars_fragment:jb,clipping_planes_fragment:zb,clipping_planes_pars_fragment:Bb,clipping_planes_pars_vertex:Hb,clipping_planes_vertex:Vb,color_fragment:Gb,color_pars_fragment:Wb,color_pars_vertex:$b,color_vertex:Xb,common:qb,cube_uv_reflection_fragment:Yb,defaultnormal_vertex:Kb,displacementmap_pars_vertex:Zb,displacementmap_vertex:Qb,emissivemap_fragment:Jb,emissivemap_pars_fragment:eA,colorspace_fragment:tA,colorspace_pars_fragment:nA,envmap_fragment:iA,envmap_common_pars_fragment:sA,envmap_pars_fragment:rA,envmap_pars_vertex:aA,envmap_physical_pars_fragment:_A,envmap_vertex:oA,fog_vertex:lA,fog_pars_vertex:cA,fog_fragment:uA,fog_pars_fragment:dA,gradientmap_pars_fragment:hA,lightmap_pars_fragment:fA,lights_lambert_fragment:pA,lights_lambert_pars_fragment:mA,lights_pars_begin:gA,lights_toon_fragment:vA,lights_toon_pars_fragment:xA,lights_phong_fragment:yA,lights_phong_pars_fragment:SA,lights_physical_fragment:MA,lights_physical_pars_fragment:EA,lights_fragment_begin:wA,lights_fragment_maps:TA,lights_fragment_end:bA,logdepthbuf_fragment:AA,logdepthbuf_pars_fragment:CA,logdepthbuf_pars_vertex:NA,logdepthbuf_vertex:RA,map_fragment:PA,map_pars_fragment:kA,map_particle_fragment:LA,map_particle_pars_fragment:DA,metalnessmap_fragment:IA,metalnessmap_pars_fragment:UA,morphinstance_vertex:FA,morphcolor_vertex:OA,morphnormal_vertex:jA,morphtarget_pars_vertex:zA,morphtarget_vertex:BA,normal_fragment_begin:HA,normal_fragment_maps:VA,normal_pars_fragment:GA,normal_pars_vertex:WA,normal_vertex:$A,normalmap_pars_fragment:XA,clearcoat_normal_fragment_begin:qA,clearcoat_normal_fragment_maps:YA,clearcoat_pars_fragment:KA,iridescence_pars_fragment:ZA,opaque_fragment:QA,packing:JA,premultiplied_alpha_fragment:eC,project_vertex:tC,dithering_fragment:nC,dithering_pars_fragment:iC,roughnessmap_fragment:sC,roughnessmap_pars_fragment:rC,shadowmap_pars_fragment:aC,shadowmap_pars_vertex:oC,shadowmap_vertex:lC,shadowmask_pars_fragment:cC,skinbase_vertex:uC,skinning_pars_vertex:dC,skinning_vertex:hC,skinnormal_vertex:fC,specularmap_fragment:pC,specularmap_pars_fragment:mC,tonemapping_fragment:gC,tonemapping_pars_fragment:_C,transmission_fragment:vC,transmission_pars_fragment:xC,uv_pars_fragment:yC,uv_pars_vertex:SC,uv_vertex:MC,worldpos_vertex:EC,background_vert:wC,background_frag:TC,backgroundCube_vert:bC,backgroundCube_frag:AC,cube_vert:CC,cube_frag:NC,depth_vert:RC,depth_frag:PC,distanceRGBA_vert:kC,distanceRGBA_frag:LC,equirect_vert:DC,equirect_frag:IC,linedashed_vert:UC,linedashed_frag:FC,meshbasic_vert:OC,meshbasic_frag:jC,meshlambert_vert:zC,meshlambert_frag:BC,meshmatcap_vert:HC,meshmatcap_frag:VC,meshnormal_vert:GC,meshnormal_frag:WC,meshphong_vert:$C,meshphong_frag:XC,meshphysical_vert:qC,meshphysical_frag:YC,meshtoon_vert:KC,meshtoon_frag:ZC,points_vert:QC,points_frag:JC,shadow_vert:eN,shadow_frag:tN,sprite_vert:nN,sprite_frag:iN},De={common:{diffuse:{value:new Pt(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new dt}},envmap:{envMap:{value:null},envMapRotation:{value:new dt},flipEnvMap:{value:-1},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new dt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new dt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new dt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new dt},normalScale:{value:new At(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new dt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new dt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new dt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new dt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new Pt(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMap:{value:[]},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotShadowMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMap:{value:[]},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null}},points:{diffuse:{value:new Pt(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0},uvTransform:{value:new dt}},sprite:{diffuse:{value:new Pt(16777215)},opacity:{value:1},center:{value:new At(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}}},qi={basic:{uniforms:Fn([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.fog]),vertexShader:ut.meshbasic_vert,fragmentShader:ut.meshbasic_frag},lambert:{uniforms:Fn([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.fog,De.lights,{emissive:{value:new Pt(0)}}]),vertexShader:ut.meshlambert_vert,fragmentShader:ut.meshlambert_frag},phong:{uniforms:Fn([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.fog,De.lights,{emissive:{value:new Pt(0)},specular:{value:new Pt(1118481)},shininess:{value:30}}]),vertexShader:ut.meshphong_vert,fragmentShader:ut.meshphong_frag},standard:{uniforms:Fn([De.common,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.roughnessmap,De.metalnessmap,De.fog,De.lights,{emissive:{value:new Pt(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:ut.meshphysical_vert,fragmentShader:ut.meshphysical_frag},toon:{uniforms:Fn([De.common,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.gradientmap,De.fog,De.lights,{emissive:{value:new Pt(0)}}]),vertexShader:ut.meshtoon_vert,fragmentShader:ut.meshtoon_frag},matcap:{uniforms:Fn([De.common,De.bumpmap,De.normalmap,De.displacementmap,De.fog,{matcap:{value:null}}]),vertexShader:ut.meshmatcap_vert,fragmentShader:ut.meshmatcap_frag},points:{uniforms:Fn([De.points,De.fog]),vertexShader:ut.points_vert,fragmentShader:ut.points_frag},dashed:{uniforms:Fn([De.common,De.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:ut.linedashed_vert,fragmentShader:ut.linedashed_frag},depth:{uniforms:Fn([De.common,De.displacementmap]),vertexShader:ut.depth_vert,fragmentShader:ut.depth_frag},normal:{uniforms:Fn([De.common,De.bumpmap,De.normalmap,De.displacementmap,{opacity:{value:1}}]),vertexShader:ut.meshnormal_vert,fragmentShader:ut.meshnormal_frag},sprite:{uniforms:Fn([De.sprite,De.fog]),vertexShader:ut.sprite_vert,fragmentShader:ut.sprite_frag},background:{uniforms:{uvTransform:{value:new dt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:ut.background_vert,fragmentShader:ut.background_frag},backgroundCube:{uniforms:{envMap:{value:null},flipEnvMap:{value:-1},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new dt}},vertexShader:ut.backgroundCube_vert,fragmentShader:ut.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:ut.cube_vert,fragmentShader:ut.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:ut.equirect_vert,fragmentShader:ut.equirect_frag},distanceRGBA:{uniforms:Fn([De.common,De.displacementmap,{referencePosition:{value:new se},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:ut.distanceRGBA_vert,fragmentShader:ut.distanceRGBA_frag},shadow:{uniforms:Fn([De.lights,De.fog,{color:{value:new Pt(0)},opacity:{value:1}}]),vertexShader:ut.shadow_vert,fragmentShader:ut.shadow_frag}};qi.physical={uniforms:Fn([qi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new dt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new dt},clearcoatNormalScale:{value:new At(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new dt},dispersion:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new dt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new dt},sheen:{value:0},sheenColor:{value:new Pt(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new dt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new dt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new dt},transmissionSamplerSize:{value:new At},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new dt},attenuationDistance:{value:0},attenuationColor:{value:new Pt(0)},specularColor:{value:new Pt(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new dt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new dt},anisotropyVector:{value:new At},anisotropyMap:{value:null},anisotropyMapTransform:{value:new dt}}]),vertexShader:ut.meshphysical_vert,fragmentShader:ut.meshphysical_frag};const $c={r:0,b:0,g:0},Pr=new Ts,sN=new nn;function rN(n,e,t,s,a,c,u){const d=new Pt(0);let f=c===!0?0:1,p,g,v=null,x=0,y=null;function w(L){let A=L.isScene===!0?L.background:null;return A&&A.isTexture&&(A=(L.backgroundBlurriness>0?t:e).get(A)),A}function E(L){let A=!1;const R=w(L);R===null?M(d,f):R&&R.isColor&&(M(R,1),A=!0);const k=n.xr.getEnvironmentBlendMode();k==="additive"?s.buffers.color.setClear(0,0,0,1,u):k==="alpha-blend"&&s.buffers.color.setClear(0,0,0,0,u),(n.autoClear||A)&&(s.buffers.depth.setTest(!0),s.buffers.depth.setMask(!0),s.buffers.color.setMask(!0),n.clear(n.autoClearColor,n.autoClearDepth,n.autoClearStencil))}function _(L,A){const R=w(A);R&&(R.isCubeTexture||R.mapping===Uu)?(g===void 0&&(g=new ji(new gl(1,1,1),new bs({name:"BackgroundCubeMaterial",uniforms:Qa(qi.backgroundCube.uniforms),vertexShader:qi.backgroundCube.vertexShader,fragmentShader:qi.backgroundCube.fragmentShader,side:qn,depthTest:!1,depthWrite:!1,fog:!1})),g.geometry.deleteAttribute("normal"),g.geometry.deleteAttribute("uv"),g.onBeforeRender=function(k,D,U){this.matrixWorld.copyPosition(U.matrixWorld)},Object.defineProperty(g.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),a.update(g)),Pr.copy(A.backgroundRotation),Pr.x*=-1,Pr.y*=-1,Pr.z*=-1,R.isCubeTexture&&R.isRenderTargetTexture===!1&&(Pr.y*=-1,Pr.z*=-1),g.material.uniforms.envMap.value=R,g.material.uniforms.flipEnvMap.value=R.isCubeTexture&&R.isRenderTargetTexture===!1?-1:1,g.material.uniforms.backgroundBlurriness.value=A.backgroundBlurriness,g.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,g.material.uniforms.backgroundRotation.value.setFromMatrix4(sN.makeRotationFromEuler(Pr)),g.material.toneMapped=Nt.getTransfer(R.colorSpace)!==Bt,(v!==R||x!==R.version||y!==n.toneMapping)&&(g.material.needsUpdate=!0,v=R,x=R.version,y=n.toneMapping),g.layers.enableAll(),L.unshift(g,g.geometry,g.material,0,0,null)):R&&R.isTexture&&(p===void 0&&(p=new ji(new _l(2,2),new bs({name:"BackgroundMaterial",uniforms:Qa(qi.background.uniforms),vertexShader:qi.background.vertexShader,fragmentShader:qi.background.fragmentShader,side:ur,depthTest:!1,depthWrite:!1,fog:!1})),p.geometry.deleteAttribute("normal"),Object.defineProperty(p.material,"map",{get:function(){return this.uniforms.t2D.value}}),a.update(p)),p.material.uniforms.t2D.value=R,p.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,p.material.toneMapped=Nt.getTransfer(R.colorSpace)!==Bt,R.matrixAutoUpdate===!0&&R.updateMatrix(),p.material.uniforms.uvTransform.value.copy(R.matrix),(v!==R||x!==R.version||y!==n.toneMapping)&&(p.material.needsUpdate=!0,v=R,x=R.version,y=n.toneMapping),p.layers.enableAll(),L.unshift(p,p.geometry,p.material,0,0,null))}function M(L,A){L.getRGB($c,vx(n)),s.buffers.color.setClear($c.r,$c.g,$c.b,A,u)}return{getClearColor:function(){return d},setClearColor:function(L,A=1){d.set(L),f=A,M(d,f)},getClearAlpha:function(){return f},setClearAlpha:function(L){f=L,M(d,f)},render:E,addToRenderList:_}}function aN(n,e){const t=n.getParameter(n.MAX_VERTEX_ATTRIBS),s={},a=x(null);let c=a,u=!1;function d(T,P,re,J,ae){let ve=!1;const V=v(J,re,P);c!==V&&(c=V,p(c.object)),ve=y(T,J,re,ae),ve&&w(T,J,re,ae),ae!==null&&e.update(ae,n.ELEMENT_ARRAY_BUFFER),(ve||u)&&(u=!1,R(T,P,re,J),ae!==null&&n.bindBuffer(n.ELEMENT_ARRAY_BUFFER,e.get(ae).buffer))}function f(){return n.createVertexArray()}function p(T){return n.bindVertexArray(T)}function g(T){return n.deleteVertexArray(T)}function v(T,P,re){const J=re.wireframe===!0;let ae=s[T.id];ae===void 0&&(ae={},s[T.id]=ae);let ve=ae[P.id];ve===void 0&&(ve={},ae[P.id]=ve);let V=ve[J];return V===void 0&&(V=x(f()),ve[J]=V),V}function x(T){const P=[],re=[],J=[];for(let ae=0;ae<t;ae++)P[ae]=0,re[ae]=0,J[ae]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:P,enabledAttributes:re,attributeDivisors:J,object:T,attributes:{},index:null}}function y(T,P,re,J){const ae=c.attributes,ve=P.attributes;let V=0;const de=re.getAttributes();for(const z in de)if(de[z].location>=0){const oe=ae[z];let O=ve[z];if(O===void 0&&(z==="instanceMatrix"&&T.instanceMatrix&&(O=T.instanceMatrix),z==="instanceColor"&&T.instanceColor&&(O=T.instanceColor)),oe===void 0||oe.attribute!==O||O&&oe.data!==O.data)return!0;V++}return c.attributesNum!==V||c.index!==J}function w(T,P,re,J){const ae={},ve=P.attributes;let V=0;const de=re.getAttributes();for(const z in de)if(de[z].location>=0){let oe=ve[z];oe===void 0&&(z==="instanceMatrix"&&T.instanceMatrix&&(oe=T.instanceMatrix),z==="instanceColor"&&T.instanceColor&&(oe=T.instanceColor));const O={};O.attribute=oe,oe&&oe.data&&(O.data=oe.data),ae[z]=O,V++}c.attributes=ae,c.attributesNum=V,c.index=J}function E(){const T=c.newAttributes;for(let P=0,re=T.length;P<re;P++)T[P]=0}function _(T){M(T,0)}function M(T,P){const re=c.newAttributes,J=c.enabledAttributes,ae=c.attributeDivisors;re[T]=1,J[T]===0&&(n.enableVertexAttribArray(T),J[T]=1),ae[T]!==P&&(n.vertexAttribDivisor(T,P),ae[T]=P)}function L(){const T=c.newAttributes,P=c.enabledAttributes;for(let re=0,J=P.length;re<J;re++)P[re]!==T[re]&&(n.disableVertexAttribArray(re),P[re]=0)}function A(T,P,re,J,ae,ve,V){V===!0?n.vertexAttribIPointer(T,P,re,ae,ve):n.vertexAttribPointer(T,P,re,J,ae,ve)}function R(T,P,re,J){E();const ae=J.attributes,ve=re.getAttributes(),V=P.defaultAttributeValues;for(const de in ve){const z=ve[de];if(z.location>=0){let ue=ae[de];if(ue===void 0&&(de==="instanceMatrix"&&T.instanceMatrix&&(ue=T.instanceMatrix),de==="instanceColor"&&T.instanceColor&&(ue=T.instanceColor)),ue!==void 0){const oe=ue.normalized,O=ue.itemSize,le=e.get(ue);if(le===void 0)continue;const we=le.buffer,K=le.type,fe=le.bytesPerElement,Te=K===n.INT||K===n.UNSIGNED_INT||ue.gpuType===Dp;if(ue.isInterleavedBufferAttribute){const Ae=ue.data,Ie=Ae.stride,Ue=ue.offset;if(Ae.isInstancedInterleavedBuffer){for(let rt=0;rt<z.locationSize;rt++)M(z.location+rt,Ae.meshPerAttribute);T.isInstancedMesh!==!0&&J._maxInstanceCount===void 0&&(J._maxInstanceCount=Ae.meshPerAttribute*Ae.count)}else for(let rt=0;rt<z.locationSize;rt++)_(z.location+rt);n.bindBuffer(n.ARRAY_BUFFER,we);for(let rt=0;rt<z.locationSize;rt++)A(z.location+rt,O/z.locationSize,K,oe,Ie*fe,(Ue+O/z.locationSize*rt)*fe,Te)}else{if(ue.isInstancedBufferAttribute){for(let Ae=0;Ae<z.locationSize;Ae++)M(z.location+Ae,ue.meshPerAttribute);T.isInstancedMesh!==!0&&J._maxInstanceCount===void 0&&(J._maxInstanceCount=ue.meshPerAttribute*ue.count)}else for(let Ae=0;Ae<z.locationSize;Ae++)_(z.location+Ae);n.bindBuffer(n.ARRAY_BUFFER,we);for(let Ae=0;Ae<z.locationSize;Ae++)A(z.location+Ae,O/z.locationSize,K,oe,O*fe,O/z.locationSize*Ae*fe,Te)}}else if(V!==void 0){const oe=V[de];if(oe!==void 0)switch(oe.length){case 2:n.vertexAttrib2fv(z.location,oe);break;case 3:n.vertexAttrib3fv(z.location,oe);break;case 4:n.vertexAttrib4fv(z.location,oe);break;default:n.vertexAttrib1fv(z.location,oe)}}}}L()}function k(){$();for(const T in s){const P=s[T];for(const re in P){const J=P[re];for(const ae in J)g(J[ae].object),delete J[ae];delete P[re]}delete s[T]}}function D(T){if(s[T.id]===void 0)return;const P=s[T.id];for(const re in P){const J=P[re];for(const ae in J)g(J[ae].object),delete J[ae];delete P[re]}delete s[T.id]}function U(T){for(const P in s){const re=s[P];if(re[T.id]===void 0)continue;const J=re[T.id];for(const ae in J)g(J[ae].object),delete J[ae];delete re[T.id]}}function $(){te(),u=!0,c!==a&&(c=a,p(c.object))}function te(){a.geometry=null,a.program=null,a.wireframe=!1}return{setup:d,reset:$,resetDefaultState:te,dispose:k,releaseStatesOfGeometry:D,releaseStatesOfProgram:U,initAttributes:E,enableAttribute:_,disableUnusedAttributes:L}}function oN(n,e,t){let s;function a(p){s=p}function c(p,g){n.drawArrays(s,p,g),t.update(g,s,1)}function u(p,g,v){v!==0&&(n.drawArraysInstanced(s,p,g,v),t.update(g,s,v))}function d(p,g,v){if(v===0)return;e.get("WEBGL_multi_draw").multiDrawArraysWEBGL(s,p,0,g,0,v);let y=0;for(let w=0;w<v;w++)y+=g[w];t.update(y,s,1)}function f(p,g,v,x){if(v===0)return;const y=e.get("WEBGL_multi_draw");if(y===null)for(let w=0;w<p.length;w++)u(p[w],g[w],x[w]);else{y.multiDrawArraysInstancedWEBGL(s,p,0,g,0,x,0,v);let w=0;for(let E=0;E<v;E++)w+=g[E];for(let E=0;E<x.length;E++)t.update(w,s,x[E])}}this.setMode=a,this.render=c,this.renderInstances=u,this.renderMultiDraw=d,this.renderMultiDrawInstances=f}function lN(n,e,t,s){let a;function c(){if(a!==void 0)return a;if(e.has("EXT_texture_filter_anisotropic")===!0){const U=e.get("EXT_texture_filter_anisotropic");a=n.getParameter(U.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else a=0;return a}function u(U){return!(U!==Oi&&s.convert(U)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_FORMAT))}function d(U){const $=U===hl&&(e.has("EXT_color_buffer_half_float")||e.has("EXT_color_buffer_float"));return!(U!==ws&&s.convert(U)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_TYPE)&&U!==xs&&!$)}function f(U){if(U==="highp"){if(n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.HIGH_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.HIGH_FLOAT).precision>0)return"highp";U="mediump"}return U==="mediump"&&n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.MEDIUM_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let p=t.precision!==void 0?t.precision:"highp";const g=f(p);g!==p&&(console.warn("THREE.WebGLRenderer:",p,"not supported, using",g,"instead."),p=g);const v=t.logarithmicDepthBuffer===!0,x=t.reverseDepthBuffer===!0&&e.has("EXT_clip_control");if(x===!0){const U=e.get("EXT_clip_control");U.clipControlEXT(U.LOWER_LEFT_EXT,U.ZERO_TO_ONE_EXT)}const y=n.getParameter(n.MAX_TEXTURE_IMAGE_UNITS),w=n.getParameter(n.MAX_VERTEX_TEXTURE_IMAGE_UNITS),E=n.getParameter(n.MAX_TEXTURE_SIZE),_=n.getParameter(n.MAX_CUBE_MAP_TEXTURE_SIZE),M=n.getParameter(n.MAX_VERTEX_ATTRIBS),L=n.getParameter(n.MAX_VERTEX_UNIFORM_VECTORS),A=n.getParameter(n.MAX_VARYING_VECTORS),R=n.getParameter(n.MAX_FRAGMENT_UNIFORM_VECTORS),k=w>0,D=n.getParameter(n.MAX_SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:c,getMaxPrecision:f,textureFormatReadable:u,textureTypeReadable:d,precision:p,logarithmicDepthBuffer:v,reverseDepthBuffer:x,maxTextures:y,maxVertexTextures:w,maxTextureSize:E,maxCubemapSize:_,maxAttributes:M,maxVertexUniforms:L,maxVaryings:A,maxFragmentUniforms:R,vertexTextures:k,maxSamples:D}}function cN(n){const e=this;let t=null,s=0,a=!1,c=!1;const u=new Lr,d=new dt,f={value:null,needsUpdate:!1};this.uniform=f,this.numPlanes=0,this.numIntersection=0,this.init=function(v,x){const y=v.length!==0||x||s!==0||a;return a=x,s=v.length,y},this.beginShadows=function(){c=!0,g(null)},this.endShadows=function(){c=!1},this.setGlobalState=function(v,x){t=g(v,x,0)},this.setState=function(v,x,y){const w=v.clippingPlanes,E=v.clipIntersection,_=v.clipShadows,M=n.get(v);if(!a||w===null||w.length===0||c&&!_)c?g(null):p();else{const L=c?0:s,A=L*4;let R=M.clippingState||null;f.value=R,R=g(w,x,A,y);for(let k=0;k!==A;++k)R[k]=t[k];M.clippingState=R,this.numIntersection=E?this.numPlanes:0,this.numPlanes+=L}};function p(){f.value!==t&&(f.value=t,f.needsUpdate=s>0),e.numPlanes=s,e.numIntersection=0}function g(v,x,y,w){const E=v!==null?v.length:0;let _=null;if(E!==0){if(_=f.value,w!==!0||_===null){const M=y+E*4,L=x.matrixWorldInverse;d.getNormalMatrix(L),(_===null||_.length<M)&&(_=new Float32Array(M));for(let A=0,R=y;A!==E;++A,R+=4)u.copy(v[A]).applyMatrix4(L,d),u.normal.toArray(_,R),_[R+3]=u.constant}f.value=_,f.needsUpdate=!0}return e.numPlanes=E,e.numIntersection=0,_}}function uN(n){let e=new WeakMap;function t(u,d){return d===Rf?u.mapping=qa:d===Pf&&(u.mapping=Ya),u}function s(u){if(u&&u.isTexture){const d=u.mapping;if(d===Rf||d===Pf)if(e.has(u)){const f=e.get(u).texture;return t(f,u.mapping)}else{const f=u.image;if(f&&f.height>0){const p=new Sb(f.height);return p.fromEquirectangularTexture(n,u),e.set(u,p),u.addEventListener("dispose",a),t(p.texture,u.mapping)}else return null}}return u}function a(u){const d=u.target;d.removeEventListener("dispose",a);const f=e.get(d);f!==void 0&&(e.delete(d),f.dispose())}function c(){e=new WeakMap}return{get:s,dispose:c}}class Ex extends xx{constructor(e=-1,t=1,s=1,a=-1,c=.1,u=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=e,this.right=t,this.top=s,this.bottom=a,this.near=c,this.far=u,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.left=e.left,this.right=e.right,this.top=e.top,this.bottom=e.bottom,this.near=e.near,this.far=e.far,this.zoom=e.zoom,this.view=e.view===null?null:Object.assign({},e.view),this}setViewOffset(e,t,s,a,c,u){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=s,this.view.offsetY=a,this.view.width=c,this.view.height=u,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=(this.right-this.left)/(2*this.zoom),t=(this.top-this.bottom)/(2*this.zoom),s=(this.right+this.left)/2,a=(this.top+this.bottom)/2;let c=s-e,u=s+e,d=a+t,f=a-t;if(this.view!==null&&this.view.enabled){const p=(this.right-this.left)/this.view.fullWidth/this.zoom,g=(this.top-this.bottom)/this.view.fullHeight/this.zoom;c+=p*this.view.offsetX,u=c+p*this.view.width,d-=g*this.view.offsetY,f=d-g*this.view.height}this.projectionMatrix.makeOrthographic(c,u,d,f,this.near,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.zoom=this.zoom,t.object.left=this.left,t.object.right=this.right,t.object.top=this.top,t.object.bottom=this.bottom,t.object.near=this.near,t.object.far=this.far,this.view!==null&&(t.object.view=Object.assign({},this.view)),t}}const ja=4,N_=[.125,.215,.35,.446,.526,.582],Ur=20,Jh=new Ex,R_=new Pt;let ef=null,tf=0,nf=0,sf=!1;const Dr=(1+Math.sqrt(5))/2,Fa=1/Dr,P_=[new se(-Dr,Fa,0),new se(Dr,Fa,0),new se(-Fa,0,Dr),new se(Fa,0,Dr),new se(0,Dr,-Fa),new se(0,Dr,Fa),new se(-1,1,-1),new se(1,1,-1),new se(-1,1,1),new se(1,1,1)];class k_{constructor(e){this._renderer=e,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._lodPlanes=[],this._sizeLods=[],this._sigmas=[],this._blurMaterial=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._compileMaterial(this._blurMaterial)}fromScene(e,t=0,s=.1,a=100){ef=this._renderer.getRenderTarget(),tf=this._renderer.getActiveCubeFace(),nf=this._renderer.getActiveMipmapLevel(),sf=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(256);const c=this._allocateTargets();return c.depthBuffer=!0,this._sceneToCubeUV(e,s,a,c),t>0&&this._blur(c,0,0,t),this._applyPMREM(c),this._cleanup(c),c}fromEquirectangular(e,t=null){return this._fromTexture(e,t)}fromCubemap(e,t=null){return this._fromTexture(e,t)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=I_(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=D_(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose()}_setSize(e){this._lodMax=Math.floor(Math.log2(e)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let e=0;e<this._lodPlanes.length;e++)this._lodPlanes[e].dispose()}_cleanup(e){this._renderer.setRenderTarget(ef,tf,nf),this._renderer.xr.enabled=sf,e.scissorTest=!1,Xc(e,0,0,e.width,e.height)}_fromTexture(e,t){e.mapping===qa||e.mapping===Ya?this._setSize(e.image.length===0?16:e.image[0].width||e.image[0].image.width):this._setSize(e.image.width/4),ef=this._renderer.getRenderTarget(),tf=this._renderer.getActiveCubeFace(),nf=this._renderer.getActiveMipmapLevel(),sf=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;const s=t||this._allocateTargets();return this._textureToCubeUV(e,s),this._applyPMREM(s),this._cleanup(s),s}_allocateTargets(){const e=3*Math.max(this._cubeSize,112),t=4*this._cubeSize,s={magFilter:Di,minFilter:Di,generateMipmaps:!1,type:hl,format:Oi,colorSpace:hr,depthBuffer:!1},a=L_(e,t,s);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==e||this._pingPongRenderTarget.height!==t){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=L_(e,t,s);const{_lodMax:c}=this;({sizeLods:this._sizeLods,lodPlanes:this._lodPlanes,sigmas:this._sigmas}=dN(c)),this._blurMaterial=hN(c,e,t)}return a}_compileMaterial(e){const t=new ji(this._lodPlanes[0],e);this._renderer.compile(t,Jh)}_sceneToCubeUV(e,t,s,a){const d=new xi(90,1,t,s),f=[1,-1,1,1,1,1],p=[1,1,1,-1,-1,-1],g=this._renderer,v=g.autoClear,x=g.toneMapping;g.getClearColor(R_),g.toneMapping=or,g.autoClear=!1;const y=new Hp({name:"PMREM.Background",side:qn,depthWrite:!1,depthTest:!1}),w=new ji(new gl,y);let E=!1;const _=e.background;_?_.isColor&&(y.color.copy(_),e.background=null,E=!0):(y.color.copy(R_),E=!0);for(let M=0;M<6;M++){const L=M%3;L===0?(d.up.set(0,f[M],0),d.lookAt(p[M],0,0)):L===1?(d.up.set(0,0,f[M]),d.lookAt(0,p[M],0)):(d.up.set(0,f[M],0),d.lookAt(0,0,p[M]));const A=this._cubeSize;Xc(a,L*A,M>2?A:0,A,A),g.setRenderTarget(a),E&&g.render(w,d),g.render(e,d)}w.geometry.dispose(),w.material.dispose(),g.toneMapping=x,g.autoClear=v,e.background=_}_textureToCubeUV(e,t){const s=this._renderer,a=e.mapping===qa||e.mapping===Ya;a?(this._cubemapMaterial===null&&(this._cubemapMaterial=I_()),this._cubemapMaterial.uniforms.flipEnvMap.value=e.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=D_());const c=a?this._cubemapMaterial:this._equirectMaterial,u=new ji(this._lodPlanes[0],c),d=c.uniforms;d.envMap.value=e;const f=this._cubeSize;Xc(t,0,0,3*f,2*f),s.setRenderTarget(t),s.render(u,Jh)}_applyPMREM(e){const t=this._renderer,s=t.autoClear;t.autoClear=!1;const a=this._lodPlanes.length;for(let c=1;c<a;c++){const u=Math.sqrt(this._sigmas[c]*this._sigmas[c]-this._sigmas[c-1]*this._sigmas[c-1]),d=P_[(a-c-1)%P_.length];this._blur(e,c-1,c,u,d)}t.autoClear=s}_blur(e,t,s,a,c){const u=this._pingPongRenderTarget;this._halfBlur(e,u,t,s,a,"latitudinal",c),this._halfBlur(u,e,s,s,a,"longitudinal",c)}_halfBlur(e,t,s,a,c,u,d){const f=this._renderer,p=this._blurMaterial;u!=="latitudinal"&&u!=="longitudinal"&&console.error("blur direction must be either latitudinal or longitudinal!");const g=3,v=new ji(this._lodPlanes[a],p),x=p.uniforms,y=this._sizeLods[s]-1,w=isFinite(c)?Math.PI/(2*y):2*Math.PI/(2*Ur-1),E=c/w,_=isFinite(c)?1+Math.floor(g*E):Ur;_>Ur&&console.warn(`sigmaRadians, ${c}, is too large and will clip, as it requested ${_} samples when the maximum is set to ${Ur}`);const M=[];let L=0;for(let U=0;U<Ur;++U){const $=U/E,te=Math.exp(-$*$/2);M.push(te),U===0?L+=te:U<_&&(L+=2*te)}for(let U=0;U<M.length;U++)M[U]=M[U]/L;x.envMap.value=e.texture,x.samples.value=_,x.weights.value=M,x.latitudinal.value=u==="latitudinal",d&&(x.poleAxis.value=d);const{_lodMax:A}=this;x.dTheta.value=w,x.mipInt.value=A-s;const R=this._sizeLods[a],k=3*R*(a>A-ja?a-A+ja:0),D=4*(this._cubeSize-R);Xc(t,k,D,3*R,2*R),f.setRenderTarget(t),f.render(v,Jh)}}function dN(n){const e=[],t=[],s=[];let a=n;const c=n-ja+1+N_.length;for(let u=0;u<c;u++){const d=Math.pow(2,a);t.push(d);let f=1/d;u>n-ja?f=N_[u-n+ja-1]:u===0&&(f=0),s.push(f);const p=1/(d-2),g=-p,v=1+p,x=[g,g,v,g,v,v,g,g,v,v,g,v],y=6,w=6,E=3,_=2,M=1,L=new Float32Array(E*w*y),A=new Float32Array(_*w*y),R=new Float32Array(M*w*y);for(let D=0;D<y;D++){const U=D%3*2/3-1,$=D>2?0:-1,te=[U,$,0,U+2/3,$,0,U+2/3,$+1,0,U,$,0,U+2/3,$+1,0,U,$+1,0];L.set(te,E*w*D),A.set(x,_*w*D);const T=[D,D,D,D,D,D];R.set(T,M*w*D)}const k=new As;k.setAttribute("position",new Ki(L,E)),k.setAttribute("uv",new Ki(A,_)),k.setAttribute("faceIndex",new Ki(R,M)),e.push(k),a>ja&&a--}return{lodPlanes:e,sizeLods:t,sigmas:s}}function L_(n,e,t){const s=new qr(n,e,t);return s.texture.mapping=Uu,s.texture.name="PMREM.cubeUv",s.scissorTest=!0,s}function Xc(n,e,t,s,a){n.viewport.set(e,t,s,a),n.scissor.set(e,t,s,a)}function hN(n,e,t){const s=new Float32Array(Ur),a=new se(0,1,0);return new bs({name:"SphericalGaussianBlur",defines:{n:Ur,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${n}.0`},uniforms:{envMap:{value:null},samples:{value:1},weights:{value:s},latitudinal:{value:!1},dTheta:{value:0},mipInt:{value:0},poleAxis:{value:a}},vertexShader:Vp(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform int samples;
			uniform float weights[ n ];
			uniform bool latitudinal;
			uniform float dTheta;
			uniform float mipInt;
			uniform vec3 poleAxis;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			vec3 getSample( float theta, vec3 axis ) {

				float cosTheta = cos( theta );
				// Rodrigues' axis-angle rotation
				vec3 sampleDirection = vOutputDirection * cosTheta
					+ cross( axis, vOutputDirection ) * sin( theta )
					+ axis * dot( axis, vOutputDirection ) * ( 1.0 - cosTheta );

				return bilinearCubeUV( envMap, sampleDirection, mipInt );

			}

			void main() {

				vec3 axis = latitudinal ? poleAxis : cross( poleAxis, vOutputDirection );

				if ( all( equal( axis, vec3( 0.0 ) ) ) ) {

					axis = vec3( vOutputDirection.z, 0.0, - vOutputDirection.x );

				}

				axis = normalize( axis );

				gl_FragColor = vec4( 0.0, 0.0, 0.0, 1.0 );
				gl_FragColor.rgb += weights[ 0 ] * getSample( 0.0, axis );

				for ( int i = 1; i < n; i++ ) {

					if ( i >= samples ) {

						break;

					}

					float theta = dTheta * float( i );
					gl_FragColor.rgb += weights[ i ] * getSample( -1.0 * theta, axis );
					gl_FragColor.rgb += weights[ i ] * getSample( theta, axis );

				}

			}
		`,blending:ar,depthTest:!1,depthWrite:!1})}function D_(){return new bs({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Vp(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;

			#include <common>

			void main() {

				vec3 outputDirection = normalize( vOutputDirection );
				vec2 uv = equirectUv( outputDirection );

				gl_FragColor = vec4( texture2D ( envMap, uv ).rgb, 1.0 );

			}
		`,blending:ar,depthTest:!1,depthWrite:!1})}function I_(){return new bs({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Vp(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:ar,depthTest:!1,depthWrite:!1})}function Vp(){return`

		precision mediump float;
		precision mediump int;

		attribute float faceIndex;

		varying vec3 vOutputDirection;

		// RH coordinate system; PMREM face-indexing convention
		vec3 getDirection( vec2 uv, float face ) {

			uv = 2.0 * uv - 1.0;

			vec3 direction = vec3( uv, 1.0 );

			if ( face == 0.0 ) {

				direction = direction.zyx; // ( 1, v, u ) pos x

			} else if ( face == 1.0 ) {

				direction = direction.xzy;
				direction.xz *= -1.0; // ( -u, 1, -v ) pos y

			} else if ( face == 2.0 ) {

				direction.x *= -1.0; // ( -u, v, 1 ) pos z

			} else if ( face == 3.0 ) {

				direction = direction.zyx;
				direction.xz *= -1.0; // ( -1, v, -u ) neg x

			} else if ( face == 4.0 ) {

				direction = direction.xzy;
				direction.xy *= -1.0; // ( -u, -1, v ) neg y

			} else if ( face == 5.0 ) {

				direction.z *= -1.0; // ( u, v, -1 ) neg z

			}

			return direction;

		}

		void main() {

			vOutputDirection = getDirection( uv, faceIndex );
			gl_Position = vec4( position, 1.0 );

		}
	`}function fN(n){let e=new WeakMap,t=null;function s(d){if(d&&d.isTexture){const f=d.mapping,p=f===Rf||f===Pf,g=f===qa||f===Ya;if(p||g){let v=e.get(d);const x=v!==void 0?v.texture.pmremVersion:0;if(d.isRenderTargetTexture&&d.pmremVersion!==x)return t===null&&(t=new k_(n)),v=p?t.fromEquirectangular(d,v):t.fromCubemap(d,v),v.texture.pmremVersion=d.pmremVersion,e.set(d,v),v.texture;if(v!==void 0)return v.texture;{const y=d.image;return p&&y&&y.height>0||g&&y&&a(y)?(t===null&&(t=new k_(n)),v=p?t.fromEquirectangular(d):t.fromCubemap(d),v.texture.pmremVersion=d.pmremVersion,e.set(d,v),d.addEventListener("dispose",c),v.texture):null}}}return d}function a(d){let f=0;const p=6;for(let g=0;g<p;g++)d[g]!==void 0&&f++;return f===p}function c(d){const f=d.target;f.removeEventListener("dispose",c);const p=e.get(f);p!==void 0&&(e.delete(f),p.dispose())}function u(){e=new WeakMap,t!==null&&(t.dispose(),t=null)}return{get:s,dispose:u}}function pN(n){const e={};function t(s){if(e[s]!==void 0)return e[s];let a;switch(s){case"WEBGL_depth_texture":a=n.getExtension("WEBGL_depth_texture")||n.getExtension("MOZ_WEBGL_depth_texture")||n.getExtension("WEBKIT_WEBGL_depth_texture");break;case"EXT_texture_filter_anisotropic":a=n.getExtension("EXT_texture_filter_anisotropic")||n.getExtension("MOZ_EXT_texture_filter_anisotropic")||n.getExtension("WEBKIT_EXT_texture_filter_anisotropic");break;case"WEBGL_compressed_texture_s3tc":a=n.getExtension("WEBGL_compressed_texture_s3tc")||n.getExtension("MOZ_WEBGL_compressed_texture_s3tc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_s3tc");break;case"WEBGL_compressed_texture_pvrtc":a=n.getExtension("WEBGL_compressed_texture_pvrtc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");break;default:a=n.getExtension(s)}return e[s]=a,a}return{has:function(s){return t(s)!==null},init:function(){t("EXT_color_buffer_float"),t("WEBGL_clip_cull_distance"),t("OES_texture_float_linear"),t("EXT_color_buffer_half_float"),t("WEBGL_multisampled_render_to_texture"),t("WEBGL_render_shared_exponent")},get:function(s){const a=t(s);return a===null&&au("THREE.WebGLRenderer: "+s+" extension not supported."),a}}}function mN(n,e,t,s){const a={},c=new WeakMap;function u(v){const x=v.target;x.index!==null&&e.remove(x.index);for(const w in x.attributes)e.remove(x.attributes[w]);for(const w in x.morphAttributes){const E=x.morphAttributes[w];for(let _=0,M=E.length;_<M;_++)e.remove(E[_])}x.removeEventListener("dispose",u),delete a[x.id];const y=c.get(x);y&&(e.remove(y),c.delete(x)),s.releaseStatesOfGeometry(x),x.isInstancedBufferGeometry===!0&&delete x._maxInstanceCount,t.memory.geometries--}function d(v,x){return a[x.id]===!0||(x.addEventListener("dispose",u),a[x.id]=!0,t.memory.geometries++),x}function f(v){const x=v.attributes;for(const w in x)e.update(x[w],n.ARRAY_BUFFER);const y=v.morphAttributes;for(const w in y){const E=y[w];for(let _=0,M=E.length;_<M;_++)e.update(E[_],n.ARRAY_BUFFER)}}function p(v){const x=[],y=v.index,w=v.attributes.position;let E=0;if(y!==null){const L=y.array;E=y.version;for(let A=0,R=L.length;A<R;A+=3){const k=L[A+0],D=L[A+1],U=L[A+2];x.push(k,D,D,U,U,k)}}else if(w!==void 0){const L=w.array;E=w.version;for(let A=0,R=L.length/3-1;A<R;A+=3){const k=A+0,D=A+1,U=A+2;x.push(k,D,D,U,U,k)}}else return;const _=new(dx(x)?_x:gx)(x,1);_.version=E;const M=c.get(v);M&&e.remove(M),c.set(v,_)}function g(v){const x=c.get(v);if(x){const y=v.index;y!==null&&x.version<y.version&&p(v)}else p(v);return c.get(v)}return{get:d,update:f,getWireframeAttribute:g}}function gN(n,e,t){let s;function a(x){s=x}let c,u;function d(x){c=x.type,u=x.bytesPerElement}function f(x,y){n.drawElements(s,y,c,x*u),t.update(y,s,1)}function p(x,y,w){w!==0&&(n.drawElementsInstanced(s,y,c,x*u,w),t.update(y,s,w))}function g(x,y,w){if(w===0)return;e.get("WEBGL_multi_draw").multiDrawElementsWEBGL(s,y,0,c,x,0,w);let _=0;for(let M=0;M<w;M++)_+=y[M];t.update(_,s,1)}function v(x,y,w,E){if(w===0)return;const _=e.get("WEBGL_multi_draw");if(_===null)for(let M=0;M<x.length;M++)p(x[M]/u,y[M],E[M]);else{_.multiDrawElementsInstancedWEBGL(s,y,0,c,x,0,E,0,w);let M=0;for(let L=0;L<w;L++)M+=y[L];for(let L=0;L<E.length;L++)t.update(M,s,E[L])}}this.setMode=a,this.setIndex=d,this.render=f,this.renderInstances=p,this.renderMultiDraw=g,this.renderMultiDrawInstances=v}function _N(n){const e={geometries:0,textures:0},t={frame:0,calls:0,triangles:0,points:0,lines:0};function s(c,u,d){switch(t.calls++,u){case n.TRIANGLES:t.triangles+=d*(c/3);break;case n.LINES:t.lines+=d*(c/2);break;case n.LINE_STRIP:t.lines+=d*(c-1);break;case n.LINE_LOOP:t.lines+=d*c;break;case n.POINTS:t.points+=d*c;break;default:console.error("THREE.WebGLInfo: Unknown draw mode:",u);break}}function a(){t.calls=0,t.triangles=0,t.points=0,t.lines=0}return{memory:e,render:t,programs:null,autoReset:!0,reset:a,update:s}}function vN(n,e,t){const s=new WeakMap,a=new Qt;function c(u,d,f){const p=u.morphTargetInfluences,g=d.morphAttributes.position||d.morphAttributes.normal||d.morphAttributes.color,v=g!==void 0?g.length:0;let x=s.get(d);if(x===void 0||x.count!==v){let te=function(){U.dispose(),s.delete(d),d.removeEventListener("dispose",te)};x!==void 0&&x.texture.dispose();const y=d.morphAttributes.position!==void 0,w=d.morphAttributes.normal!==void 0,E=d.morphAttributes.color!==void 0,_=d.morphAttributes.position||[],M=d.morphAttributes.normal||[],L=d.morphAttributes.color||[];let A=0;y===!0&&(A=1),w===!0&&(A=2),E===!0&&(A=3);let R=d.attributes.position.count*A,k=1;R>e.maxTextureSize&&(k=Math.ceil(R/e.maxTextureSize),R=e.maxTextureSize);const D=new Float32Array(R*k*4*v),U=new fx(D,R,k,v);U.type=xs,U.needsUpdate=!0;const $=A*4;for(let T=0;T<v;T++){const P=_[T],re=M[T],J=L[T],ae=R*k*4*T;for(let ve=0;ve<P.count;ve++){const V=ve*$;y===!0&&(a.fromBufferAttribute(P,ve),D[ae+V+0]=a.x,D[ae+V+1]=a.y,D[ae+V+2]=a.z,D[ae+V+3]=0),w===!0&&(a.fromBufferAttribute(re,ve),D[ae+V+4]=a.x,D[ae+V+5]=a.y,D[ae+V+6]=a.z,D[ae+V+7]=0),E===!0&&(a.fromBufferAttribute(J,ve),D[ae+V+8]=a.x,D[ae+V+9]=a.y,D[ae+V+10]=a.z,D[ae+V+11]=J.itemSize===4?a.w:1)}}x={count:v,texture:U,size:new At(R,k)},s.set(d,x),d.addEventListener("dispose",te)}if(u.isInstancedMesh===!0&&u.morphTexture!==null)f.getUniforms().setValue(n,"morphTexture",u.morphTexture,t);else{let y=0;for(let E=0;E<p.length;E++)y+=p[E];const w=d.morphTargetsRelative?1:1-y;f.getUniforms().setValue(n,"morphTargetBaseInfluence",w),f.getUniforms().setValue(n,"morphTargetInfluences",p)}f.getUniforms().setValue(n,"morphTargetsTexture",x.texture,t),f.getUniforms().setValue(n,"morphTargetsTextureSize",x.size)}return{update:c}}function xN(n,e,t,s){let a=new WeakMap;function c(f){const p=s.render.frame,g=f.geometry,v=e.get(f,g);if(a.get(v)!==p&&(e.update(v),a.set(v,p)),f.isInstancedMesh&&(f.hasEventListener("dispose",d)===!1&&f.addEventListener("dispose",d),a.get(f)!==p&&(t.update(f.instanceMatrix,n.ARRAY_BUFFER),f.instanceColor!==null&&t.update(f.instanceColor,n.ARRAY_BUFFER),a.set(f,p))),f.isSkinnedMesh){const x=f.skeleton;a.get(x)!==p&&(x.update(),a.set(x,p))}return v}function u(){a=new WeakMap}function d(f){const p=f.target;p.removeEventListener("dispose",d),t.remove(p.instanceMatrix),p.instanceColor!==null&&t.remove(p.instanceColor)}return{update:c,dispose:u}}class wx extends Yn{constructor(e,t,s,a,c,u,d,f,p,g=Va){if(g!==Va&&g!==Za)throw new Error("DepthTexture format must be either THREE.DepthFormat or THREE.DepthStencilFormat");s===void 0&&g===Va&&(s=Xr),s===void 0&&g===Za&&(s=Ka),super(null,a,c,u,d,f,g,s,p),this.isDepthTexture=!0,this.image={width:e,height:t},this.magFilter=d!==void 0?d:Si,this.minFilter=f!==void 0?f:Si,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(e){return super.copy(e),this.compareFunction=e.compareFunction,this}toJSON(e){const t=super.toJSON(e);return this.compareFunction!==null&&(t.compareFunction=this.compareFunction),t}}const Tx=new Yn,U_=new wx(1,1),bx=new fx,Ax=new sb,Cx=new yx,F_=[],O_=[],j_=new Float32Array(16),z_=new Float32Array(9),B_=new Float32Array(4);function ao(n,e,t){const s=n[0];if(s<=0||s>0)return n;const a=e*t;let c=F_[a];if(c===void 0&&(c=new Float32Array(a),F_[a]=c),e!==0){s.toArray(c,0);for(let u=1,d=0;u!==e;++u)d+=t,n[u].toArray(c,d)}return c}function cn(n,e){if(n.length!==e.length)return!1;for(let t=0,s=n.length;t<s;t++)if(n[t]!==e[t])return!1;return!0}function un(n,e){for(let t=0,s=e.length;t<s;t++)n[t]=e[t]}function ju(n,e){let t=O_[e];t===void 0&&(t=new Int32Array(e),O_[e]=t);for(let s=0;s!==e;++s)t[s]=n.allocateTextureUnit();return t}function yN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1f(this.addr,e),t[0]=e)}function SN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2f(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2fv(this.addr,e),un(t,e)}}function MN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3f(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else if(e.r!==void 0)(t[0]!==e.r||t[1]!==e.g||t[2]!==e.b)&&(n.uniform3f(this.addr,e.r,e.g,e.b),t[0]=e.r,t[1]=e.g,t[2]=e.b);else{if(cn(t,e))return;n.uniform3fv(this.addr,e),un(t,e)}}function EN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4f(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4fv(this.addr,e),un(t,e)}}function wN(n,e){const t=this.cache,s=e.elements;if(s===void 0){if(cn(t,e))return;n.uniformMatrix2fv(this.addr,!1,e),un(t,e)}else{if(cn(t,s))return;B_.set(s),n.uniformMatrix2fv(this.addr,!1,B_),un(t,s)}}function TN(n,e){const t=this.cache,s=e.elements;if(s===void 0){if(cn(t,e))return;n.uniformMatrix3fv(this.addr,!1,e),un(t,e)}else{if(cn(t,s))return;z_.set(s),n.uniformMatrix3fv(this.addr,!1,z_),un(t,s)}}function bN(n,e){const t=this.cache,s=e.elements;if(s===void 0){if(cn(t,e))return;n.uniformMatrix4fv(this.addr,!1,e),un(t,e)}else{if(cn(t,s))return;j_.set(s),n.uniformMatrix4fv(this.addr,!1,j_),un(t,s)}}function AN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1i(this.addr,e),t[0]=e)}function CN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2i(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2iv(this.addr,e),un(t,e)}}function NN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3i(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(cn(t,e))return;n.uniform3iv(this.addr,e),un(t,e)}}function RN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4i(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4iv(this.addr,e),un(t,e)}}function PN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1ui(this.addr,e),t[0]=e)}function kN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2ui(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2uiv(this.addr,e),un(t,e)}}function LN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3ui(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(cn(t,e))return;n.uniform3uiv(this.addr,e),un(t,e)}}function DN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4ui(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4uiv(this.addr,e),un(t,e)}}function IN(n,e,t){const s=this.cache,a=t.allocateTextureUnit();s[0]!==a&&(n.uniform1i(this.addr,a),s[0]=a);let c;this.type===n.SAMPLER_2D_SHADOW?(U_.compareFunction=ux,c=U_):c=Tx,t.setTexture2D(e||c,a)}function UN(n,e,t){const s=this.cache,a=t.allocateTextureUnit();s[0]!==a&&(n.uniform1i(this.addr,a),s[0]=a),t.setTexture3D(e||Ax,a)}function FN(n,e,t){const s=this.cache,a=t.allocateTextureUnit();s[0]!==a&&(n.uniform1i(this.addr,a),s[0]=a),t.setTextureCube(e||Cx,a)}function ON(n,e,t){const s=this.cache,a=t.allocateTextureUnit();s[0]!==a&&(n.uniform1i(this.addr,a),s[0]=a),t.setTexture2DArray(e||bx,a)}function jN(n){switch(n){case 5126:return yN;case 35664:return SN;case 35665:return MN;case 35666:return EN;case 35674:return wN;case 35675:return TN;case 35676:return bN;case 5124:case 35670:return AN;case 35667:case 35671:return CN;case 35668:case 35672:return NN;case 35669:case 35673:return RN;case 5125:return PN;case 36294:return kN;case 36295:return LN;case 36296:return DN;case 35678:case 36198:case 36298:case 36306:case 35682:return IN;case 35679:case 36299:case 36307:return UN;case 35680:case 36300:case 36308:case 36293:return FN;case 36289:case 36303:case 36311:case 36292:return ON}}function zN(n,e){n.uniform1fv(this.addr,e)}function BN(n,e){const t=ao(e,this.size,2);n.uniform2fv(this.addr,t)}function HN(n,e){const t=ao(e,this.size,3);n.uniform3fv(this.addr,t)}function VN(n,e){const t=ao(e,this.size,4);n.uniform4fv(this.addr,t)}function GN(n,e){const t=ao(e,this.size,4);n.uniformMatrix2fv(this.addr,!1,t)}function WN(n,e){const t=ao(e,this.size,9);n.uniformMatrix3fv(this.addr,!1,t)}function $N(n,e){const t=ao(e,this.size,16);n.uniformMatrix4fv(this.addr,!1,t)}function XN(n,e){n.uniform1iv(this.addr,e)}function qN(n,e){n.uniform2iv(this.addr,e)}function YN(n,e){n.uniform3iv(this.addr,e)}function KN(n,e){n.uniform4iv(this.addr,e)}function ZN(n,e){n.uniform1uiv(this.addr,e)}function QN(n,e){n.uniform2uiv(this.addr,e)}function JN(n,e){n.uniform3uiv(this.addr,e)}function eR(n,e){n.uniform4uiv(this.addr,e)}function tR(n,e,t){const s=this.cache,a=e.length,c=ju(t,a);cn(s,c)||(n.uniform1iv(this.addr,c),un(s,c));for(let u=0;u!==a;++u)t.setTexture2D(e[u]||Tx,c[u])}function nR(n,e,t){const s=this.cache,a=e.length,c=ju(t,a);cn(s,c)||(n.uniform1iv(this.addr,c),un(s,c));for(let u=0;u!==a;++u)t.setTexture3D(e[u]||Ax,c[u])}function iR(n,e,t){const s=this.cache,a=e.length,c=ju(t,a);cn(s,c)||(n.uniform1iv(this.addr,c),un(s,c));for(let u=0;u!==a;++u)t.setTextureCube(e[u]||Cx,c[u])}function sR(n,e,t){const s=this.cache,a=e.length,c=ju(t,a);cn(s,c)||(n.uniform1iv(this.addr,c),un(s,c));for(let u=0;u!==a;++u)t.setTexture2DArray(e[u]||bx,c[u])}function rR(n){switch(n){case 5126:return zN;case 35664:return BN;case 35665:return HN;case 35666:return VN;case 35674:return GN;case 35675:return WN;case 35676:return $N;case 5124:case 35670:return XN;case 35667:case 35671:return qN;case 35668:case 35672:return YN;case 35669:case 35673:return KN;case 5125:return ZN;case 36294:return QN;case 36295:return JN;case 36296:return eR;case 35678:case 36198:case 36298:case 36306:case 35682:return tR;case 35679:case 36299:case 36307:return nR;case 35680:case 36300:case 36308:case 36293:return iR;case 36289:case 36303:case 36311:case 36292:return sR}}class aR{constructor(e,t,s){this.id=e,this.addr=s,this.cache=[],this.type=t.type,this.setValue=jN(t.type)}}class oR{constructor(e,t,s){this.id=e,this.addr=s,this.cache=[],this.type=t.type,this.size=t.size,this.setValue=rR(t.type)}}class lR{constructor(e){this.id=e,this.seq=[],this.map={}}setValue(e,t,s){const a=this.seq;for(let c=0,u=a.length;c!==u;++c){const d=a[c];d.setValue(e,t[d.id],s)}}}const rf=/(\w+)(\])?(\[|\.)?/g;function H_(n,e){n.seq.push(e),n.map[e.id]=e}function cR(n,e,t){const s=n.name,a=s.length;for(rf.lastIndex=0;;){const c=rf.exec(s),u=rf.lastIndex;let d=c[1];const f=c[2]==="]",p=c[3];if(f&&(d=d|0),p===void 0||p==="["&&u+2===a){H_(t,p===void 0?new aR(d,n,e):new oR(d,n,e));break}else{let v=t.map[d];v===void 0&&(v=new lR(d),H_(t,v)),t=v}}}class ou{constructor(e,t){this.seq=[],this.map={};const s=e.getProgramParameter(t,e.ACTIVE_UNIFORMS);for(let a=0;a<s;++a){const c=e.getActiveUniform(t,a),u=e.getUniformLocation(t,c.name);cR(c,u,this)}}setValue(e,t,s,a){const c=this.map[t];c!==void 0&&c.setValue(e,s,a)}setOptional(e,t,s){const a=t[s];a!==void 0&&this.setValue(e,s,a)}static upload(e,t,s,a){for(let c=0,u=t.length;c!==u;++c){const d=t[c],f=s[d.id];f.needsUpdate!==!1&&d.setValue(e,f.value,a)}}static seqWithValue(e,t){const s=[];for(let a=0,c=e.length;a!==c;++a){const u=e[a];u.id in t&&s.push(u)}return s}}function V_(n,e,t){const s=n.createShader(e);return n.shaderSource(s,t),n.compileShader(s),s}const uR=37297;let dR=0;function hR(n,e){const t=n.split(`
`),s=[],a=Math.max(e-6,0),c=Math.min(e+6,t.length);for(let u=a;u<c;u++){const d=u+1;s.push(`${d===e?">":" "} ${d}: ${t[u]}`)}return s.join(`
`)}function fR(n){const e=Nt.getPrimaries(Nt.workingColorSpace),t=Nt.getPrimaries(n);let s;switch(e===t?s="":e===vu&&t===_u?s="LinearDisplayP3ToLinearSRGB":e===_u&&t===vu&&(s="LinearSRGBToLinearDisplayP3"),n){case hr:case Fu:return[s,"LinearTransferOETF"];case $i:case zp:return[s,"sRGBTransferOETF"];default:return console.warn("THREE.WebGLProgram: Unsupported color space:",n),[s,"LinearTransferOETF"]}}function G_(n,e,t){const s=n.getShaderParameter(e,n.COMPILE_STATUS),a=n.getShaderInfoLog(e).trim();if(s&&a==="")return"";const c=/ERROR: 0:(\d+)/.exec(a);if(c){const u=parseInt(c[1]);return t.toUpperCase()+`

`+a+`

`+hR(n.getShaderSource(e),u)}else return a}function pR(n,e){const t=fR(e);return`vec4 ${n}( vec4 value ) { return ${t[0]}( ${t[1]}( value ) ); }`}function mR(n,e){let t;switch(e){case NT:t="Linear";break;case RT:t="Reinhard";break;case PT:t="Cineon";break;case kT:t="ACESFilmic";break;case DT:t="AgX";break;case IT:t="Neutral";break;case LT:t="Custom";break;default:console.warn("THREE.WebGLProgram: Unsupported toneMapping:",e),t="Linear"}return"vec3 "+n+"( vec3 color ) { return "+t+"ToneMapping( color ); }"}const qc=new se;function gR(){Nt.getLuminanceCoefficients(qc);const n=qc.x.toFixed(4),e=qc.y.toFixed(4),t=qc.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${n}, ${e}, ${t} );`,"	return dot( weights, rgb );","}"].join(`
`)}function _R(n){return[n.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",n.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(Zo).join(`
`)}function vR(n){const e=[];for(const t in n){const s=n[t];s!==!1&&e.push("#define "+t+" "+s)}return e.join(`
`)}function xR(n,e){const t={},s=n.getProgramParameter(e,n.ACTIVE_ATTRIBUTES);for(let a=0;a<s;a++){const c=n.getActiveAttrib(e,a),u=c.name;let d=1;c.type===n.FLOAT_MAT2&&(d=2),c.type===n.FLOAT_MAT3&&(d=3),c.type===n.FLOAT_MAT4&&(d=4),t[u]={type:c.type,location:n.getAttribLocation(e,u),locationSize:d}}return t}function Zo(n){return n!==""}function W_(n,e){const t=e.numSpotLightShadows+e.numSpotLightMaps-e.numSpotLightShadowsWithMaps;return n.replace(/NUM_DIR_LIGHTS/g,e.numDirLights).replace(/NUM_SPOT_LIGHTS/g,e.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,e.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,t).replace(/NUM_RECT_AREA_LIGHTS/g,e.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,e.numPointLights).replace(/NUM_HEMI_LIGHTS/g,e.numHemiLights).replace(/NUM_DIR_LIGHT_SHADOWS/g,e.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,e.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,e.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,e.numPointLightShadows)}function $_(n,e){return n.replace(/NUM_CLIPPING_PLANES/g,e.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,e.numClippingPlanes-e.numClipIntersection)}const yR=/^[ \t]*#include +<([\w\d./]+)>/gm;function op(n){return n.replace(yR,MR)}const SR=new Map;function MR(n,e){let t=ut[e];if(t===void 0){const s=SR.get(e);if(s!==void 0)t=ut[s],console.warn('THREE.WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',e,s);else throw new Error("Can not resolve #include <"+e+">")}return op(t)}const ER=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function X_(n){return n.replace(ER,wR)}function wR(n,e,t,s){let a="";for(let c=parseInt(e);c<parseInt(t);c++)a+=s.replace(/\[\s*i\s*\]/g,"[ "+c+" ]").replace(/UNROLLED_LOOP_INDEX/g,c);return a}function q_(n){let e=`precision ${n.precision} float;
	precision ${n.precision} int;
	precision ${n.precision} sampler2D;
	precision ${n.precision} samplerCube;
	precision ${n.precision} sampler3D;
	precision ${n.precision} sampler2DArray;
	precision ${n.precision} sampler2DShadow;
	precision ${n.precision} samplerCubeShadow;
	precision ${n.precision} sampler2DArrayShadow;
	precision ${n.precision} isampler2D;
	precision ${n.precision} isampler3D;
	precision ${n.precision} isamplerCube;
	precision ${n.precision} isampler2DArray;
	precision ${n.precision} usampler2D;
	precision ${n.precision} usampler3D;
	precision ${n.precision} usamplerCube;
	precision ${n.precision} usampler2DArray;
	`;return n.precision==="highp"?e+=`
#define HIGH_PRECISION`:n.precision==="mediump"?e+=`
#define MEDIUM_PRECISION`:n.precision==="lowp"&&(e+=`
#define LOW_PRECISION`),e}function TR(n){let e="SHADOWMAP_TYPE_BASIC";return n.shadowMapType===Zv?e="SHADOWMAP_TYPE_PCF":n.shadowMapType===lT?e="SHADOWMAP_TYPE_PCF_SOFT":n.shadowMapType===gs&&(e="SHADOWMAP_TYPE_VSM"),e}function bR(n){let e="ENVMAP_TYPE_CUBE";if(n.envMap)switch(n.envMapMode){case qa:case Ya:e="ENVMAP_TYPE_CUBE";break;case Uu:e="ENVMAP_TYPE_CUBE_UV";break}return e}function AR(n){let e="ENVMAP_MODE_REFLECTION";if(n.envMap)switch(n.envMapMode){case Ya:e="ENVMAP_MODE_REFRACTION";break}return e}function CR(n){let e="ENVMAP_BLENDING_NONE";if(n.envMap)switch(n.combine){case Qv:e="ENVMAP_BLENDING_MULTIPLY";break;case AT:e="ENVMAP_BLENDING_MIX";break;case CT:e="ENVMAP_BLENDING_ADD";break}return e}function NR(n){const e=n.envMapCubeUVHeight;if(e===null)return null;const t=Math.log2(e)-2,s=1/e;return{texelWidth:1/(3*Math.max(Math.pow(2,t),112)),texelHeight:s,maxMip:t}}function RR(n,e,t,s){const a=n.getContext(),c=t.defines;let u=t.vertexShader,d=t.fragmentShader;const f=TR(t),p=bR(t),g=AR(t),v=CR(t),x=NR(t),y=_R(t),w=vR(c),E=a.createProgram();let _,M,L=t.glslVersion?"#version "+t.glslVersion+`
`:"";t.isRawShaderMaterial?(_=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w].filter(Zo).join(`
`),_.length>0&&(_+=`
`),M=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w].filter(Zo).join(`
`),M.length>0&&(M+=`
`)):(_=[q_(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w,t.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",t.batching?"#define USE_BATCHING":"",t.batchingColor?"#define USE_BATCHING_COLOR":"",t.instancing?"#define USE_INSTANCING":"",t.instancingColor?"#define USE_INSTANCING_COLOR":"",t.instancingMorph?"#define USE_INSTANCING_MORPH":"",t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.map?"#define USE_MAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+g:"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.displacementMap?"#define USE_DISPLACEMENTMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.mapUv?"#define MAP_UV "+t.mapUv:"",t.alphaMapUv?"#define ALPHAMAP_UV "+t.alphaMapUv:"",t.lightMapUv?"#define LIGHTMAP_UV "+t.lightMapUv:"",t.aoMapUv?"#define AOMAP_UV "+t.aoMapUv:"",t.emissiveMapUv?"#define EMISSIVEMAP_UV "+t.emissiveMapUv:"",t.bumpMapUv?"#define BUMPMAP_UV "+t.bumpMapUv:"",t.normalMapUv?"#define NORMALMAP_UV "+t.normalMapUv:"",t.displacementMapUv?"#define DISPLACEMENTMAP_UV "+t.displacementMapUv:"",t.metalnessMapUv?"#define METALNESSMAP_UV "+t.metalnessMapUv:"",t.roughnessMapUv?"#define ROUGHNESSMAP_UV "+t.roughnessMapUv:"",t.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+t.anisotropyMapUv:"",t.clearcoatMapUv?"#define CLEARCOATMAP_UV "+t.clearcoatMapUv:"",t.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+t.clearcoatNormalMapUv:"",t.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+t.clearcoatRoughnessMapUv:"",t.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+t.iridescenceMapUv:"",t.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+t.iridescenceThicknessMapUv:"",t.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+t.sheenColorMapUv:"",t.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+t.sheenRoughnessMapUv:"",t.specularMapUv?"#define SPECULARMAP_UV "+t.specularMapUv:"",t.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+t.specularColorMapUv:"",t.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+t.specularIntensityMapUv:"",t.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+t.transmissionMapUv:"",t.thicknessMapUv?"#define THICKNESSMAP_UV "+t.thicknessMapUv:"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.flatShading?"#define FLAT_SHADED":"",t.skinning?"#define USE_SKINNING":"",t.morphTargets?"#define USE_MORPHTARGETS":"",t.morphNormals&&t.flatShading===!1?"#define USE_MORPHNORMALS":"",t.morphColors?"#define USE_MORPHCOLORS":"",t.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+t.morphTextureStride:"",t.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+t.morphTargetsCount:"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+f:"",t.sizeAttenuation?"#define USE_SIZEATTENUATION":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(Zo).join(`
`),M=[q_(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w,t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",t.map?"#define USE_MAP":"",t.matcap?"#define USE_MATCAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+p:"",t.envMap?"#define "+g:"",t.envMap?"#define "+v:"",x?"#define CUBEUV_TEXEL_WIDTH "+x.texelWidth:"",x?"#define CUBEUV_TEXEL_HEIGHT "+x.texelHeight:"",x?"#define CUBEUV_MAX_MIP "+x.maxMip+".0":"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoat?"#define USE_CLEARCOAT":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.dispersion?"#define USE_DISPERSION":"",t.iridescence?"#define USE_IRIDESCENCE":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaTest?"#define USE_ALPHATEST":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.sheen?"#define USE_SHEEN":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors||t.instancingColor||t.batchingColor?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.gradientMap?"#define USE_GRADIENTMAP":"",t.flatShading?"#define FLAT_SHADED":"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+f:"",t.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",t.toneMapping!==or?"#define TONE_MAPPING":"",t.toneMapping!==or?ut.tonemapping_pars_fragment:"",t.toneMapping!==or?mR("toneMapping",t.toneMapping):"",t.dithering?"#define DITHERING":"",t.opaque?"#define OPAQUE":"",ut.colorspace_pars_fragment,pR("linearToOutputTexel",t.outputColorSpace),gR(),t.useDepthPacking?"#define DEPTH_PACKING "+t.depthPacking:"",`
`].filter(Zo).join(`
`)),u=op(u),u=W_(u,t),u=$_(u,t),d=op(d),d=W_(d,t),d=$_(d,t),u=X_(u),d=X_(d),t.isRawShaderMaterial!==!0&&(L=`#version 300 es
`,_=[y,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+_,M=["#define varying in",t.glslVersion===d_?"":"layout(location = 0) out highp vec4 pc_fragColor;",t.glslVersion===d_?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+M);const A=L+_+u,R=L+M+d,k=V_(a,a.VERTEX_SHADER,A),D=V_(a,a.FRAGMENT_SHADER,R);a.attachShader(E,k),a.attachShader(E,D),t.index0AttributeName!==void 0?a.bindAttribLocation(E,0,t.index0AttributeName):t.morphTargets===!0&&a.bindAttribLocation(E,0,"position"),a.linkProgram(E);function U(P){if(n.debug.checkShaderErrors){const re=a.getProgramInfoLog(E).trim(),J=a.getShaderInfoLog(k).trim(),ae=a.getShaderInfoLog(D).trim();let ve=!0,V=!0;if(a.getProgramParameter(E,a.LINK_STATUS)===!1)if(ve=!1,typeof n.debug.onShaderError=="function")n.debug.onShaderError(a,E,k,D);else{const de=G_(a,k,"vertex"),z=G_(a,D,"fragment");console.error("THREE.WebGLProgram: Shader Error "+a.getError()+" - VALIDATE_STATUS "+a.getProgramParameter(E,a.VALIDATE_STATUS)+`

Material Name: `+P.name+`
Material Type: `+P.type+`

Program Info Log: `+re+`
`+de+`
`+z)}else re!==""?console.warn("THREE.WebGLProgram: Program Info Log:",re):(J===""||ae==="")&&(V=!1);V&&(P.diagnostics={runnable:ve,programLog:re,vertexShader:{log:J,prefix:_},fragmentShader:{log:ae,prefix:M}})}a.deleteShader(k),a.deleteShader(D),$=new ou(a,E),te=xR(a,E)}let $;this.getUniforms=function(){return $===void 0&&U(this),$};let te;this.getAttributes=function(){return te===void 0&&U(this),te};let T=t.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return T===!1&&(T=a.getProgramParameter(E,uR)),T},this.destroy=function(){s.releaseStatesOfProgram(this),a.deleteProgram(E),this.program=void 0},this.type=t.shaderType,this.name=t.shaderName,this.id=dR++,this.cacheKey=e,this.usedTimes=1,this.program=E,this.vertexShader=k,this.fragmentShader=D,this}let PR=0;class kR{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(e){const t=e.vertexShader,s=e.fragmentShader,a=this._getShaderStage(t),c=this._getShaderStage(s),u=this._getShaderCacheForMaterial(e);return u.has(a)===!1&&(u.add(a),a.usedTimes++),u.has(c)===!1&&(u.add(c),c.usedTimes++),this}remove(e){const t=this.materialCache.get(e);for(const s of t)s.usedTimes--,s.usedTimes===0&&this.shaderCache.delete(s.code);return this.materialCache.delete(e),this}getVertexShaderID(e){return this._getShaderStage(e.vertexShader).id}getFragmentShaderID(e){return this._getShaderStage(e.fragmentShader).id}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(e){const t=this.materialCache;let s=t.get(e);return s===void 0&&(s=new Set,t.set(e,s)),s}_getShaderStage(e){const t=this.shaderCache;let s=t.get(e);return s===void 0&&(s=new LR(e),t.set(e,s)),s}}class LR{constructor(e){this.id=PR++,this.code=e,this.usedTimes=0}}function DR(n,e,t,s,a,c,u){const d=new px,f=new kR,p=new Set,g=[],v=a.logarithmicDepthBuffer,x=a.reverseDepthBuffer,y=a.vertexTextures;let w=a.precision;const E={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distanceRGBA",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function _(T){return p.add(T),T===0?"uv":`uv${T}`}function M(T,P,re,J,ae){const ve=J.fog,V=ae.geometry,de=T.isMeshStandardMaterial?J.environment:null,z=(T.isMeshStandardMaterial?t:e).get(T.envMap||de),ue=z&&z.mapping===Uu?z.image.height:null,oe=E[T.type];T.precision!==null&&(w=a.getMaxPrecision(T.precision),w!==T.precision&&console.warn("THREE.WebGLProgram.getParameters:",T.precision,"not supported, using",w,"instead."));const O=V.morphAttributes.position||V.morphAttributes.normal||V.morphAttributes.color,le=O!==void 0?O.length:0;let we=0;V.morphAttributes.position!==void 0&&(we=1),V.morphAttributes.normal!==void 0&&(we=2),V.morphAttributes.color!==void 0&&(we=3);let K,fe,Te,Ae;if(oe){const dn=qi[oe];K=dn.vertexShader,fe=dn.fragmentShader}else K=T.vertexShader,fe=T.fragmentShader,f.update(T),Te=f.getVertexShaderID(T),Ae=f.getFragmentShaderID(T);const Ie=n.getRenderTarget(),Ue=ae.isInstancedMesh===!0,rt=ae.isBatchedMesh===!0,yt=!!T.map,pt=!!T.matcap,B=!!z,_n=!!T.aoMap,ft=!!T.lightMap,_t=!!T.bumpMap,tt=!!T.normalMap,Lt=!!T.displacementMap,it=!!T.emissiveMap,I=!!T.metalnessMap,C=!!T.roughnessMap,Q=T.anisotropy>0,me=T.clearcoat>0,Se=T.dispersion>0,pe=T.iridescence>0,Ze=T.sheen>0,ke=T.transmission>0,Be=Q&&!!T.anisotropyMap,vt=me&&!!T.clearcoatMap,Ce=me&&!!T.clearcoatNormalMap,He=me&&!!T.clearcoatRoughnessMap,at=pe&&!!T.iridescenceMap,st=pe&&!!T.iridescenceThicknessMap,Ge=Ze&&!!T.sheenColorMap,mt=Ze&&!!T.sheenRoughnessMap,lt=!!T.specularMap,Ct=!!T.specularColorMap,G=!!T.specularIntensityMap,Fe=ke&&!!T.transmissionMap,ce=ke&&!!T.thicknessMap,_e=!!T.gradientMap,Le=!!T.alphaMap,je=T.alphaTest>0,gt=!!T.alphaHash,$t=!!T.extensions;let vn=or;T.toneMapped&&(Ie===null||Ie.isXRRenderTarget===!0)&&(vn=n.toneMapping);const xt={shaderID:oe,shaderType:T.type,shaderName:T.name,vertexShader:K,fragmentShader:fe,defines:T.defines,customVertexShaderID:Te,customFragmentShaderID:Ae,isRawShaderMaterial:T.isRawShaderMaterial===!0,glslVersion:T.glslVersion,precision:w,batching:rt,batchingColor:rt&&ae._colorsTexture!==null,instancing:Ue,instancingColor:Ue&&ae.instanceColor!==null,instancingMorph:Ue&&ae.morphTexture!==null,supportsVertexTextures:y,outputColorSpace:Ie===null?n.outputColorSpace:Ie.isXRRenderTarget===!0?Ie.texture.colorSpace:hr,alphaToCoverage:!!T.alphaToCoverage,map:yt,matcap:pt,envMap:B,envMapMode:B&&z.mapping,envMapCubeUVHeight:ue,aoMap:_n,lightMap:ft,bumpMap:_t,normalMap:tt,displacementMap:y&&Lt,emissiveMap:it,normalMapObjectSpace:tt&&T.normalMapType===zT,normalMapTangentSpace:tt&&T.normalMapType===jT,metalnessMap:I,roughnessMap:C,anisotropy:Q,anisotropyMap:Be,clearcoat:me,clearcoatMap:vt,clearcoatNormalMap:Ce,clearcoatRoughnessMap:He,dispersion:Se,iridescence:pe,iridescenceMap:at,iridescenceThicknessMap:st,sheen:Ze,sheenColorMap:Ge,sheenRoughnessMap:mt,specularMap:lt,specularColorMap:Ct,specularIntensityMap:G,transmission:ke,transmissionMap:Fe,thicknessMap:ce,gradientMap:_e,opaque:T.transparent===!1&&T.blending===Ha&&T.alphaToCoverage===!1,alphaMap:Le,alphaTest:je,alphaHash:gt,combine:T.combine,mapUv:yt&&_(T.map.channel),aoMapUv:_n&&_(T.aoMap.channel),lightMapUv:ft&&_(T.lightMap.channel),bumpMapUv:_t&&_(T.bumpMap.channel),normalMapUv:tt&&_(T.normalMap.channel),displacementMapUv:Lt&&_(T.displacementMap.channel),emissiveMapUv:it&&_(T.emissiveMap.channel),metalnessMapUv:I&&_(T.metalnessMap.channel),roughnessMapUv:C&&_(T.roughnessMap.channel),anisotropyMapUv:Be&&_(T.anisotropyMap.channel),clearcoatMapUv:vt&&_(T.clearcoatMap.channel),clearcoatNormalMapUv:Ce&&_(T.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:He&&_(T.clearcoatRoughnessMap.channel),iridescenceMapUv:at&&_(T.iridescenceMap.channel),iridescenceThicknessMapUv:st&&_(T.iridescenceThicknessMap.channel),sheenColorMapUv:Ge&&_(T.sheenColorMap.channel),sheenRoughnessMapUv:mt&&_(T.sheenRoughnessMap.channel),specularMapUv:lt&&_(T.specularMap.channel),specularColorMapUv:Ct&&_(T.specularColorMap.channel),specularIntensityMapUv:G&&_(T.specularIntensityMap.channel),transmissionMapUv:Fe&&_(T.transmissionMap.channel),thicknessMapUv:ce&&_(T.thicknessMap.channel),alphaMapUv:Le&&_(T.alphaMap.channel),vertexTangents:!!V.attributes.tangent&&(tt||Q),vertexColors:T.vertexColors,vertexAlphas:T.vertexColors===!0&&!!V.attributes.color&&V.attributes.color.itemSize===4,pointsUvs:ae.isPoints===!0&&!!V.attributes.uv&&(yt||Le),fog:!!ve,useFog:T.fog===!0,fogExp2:!!ve&&ve.isFogExp2,flatShading:T.flatShading===!0,sizeAttenuation:T.sizeAttenuation===!0,logarithmicDepthBuffer:v,reverseDepthBuffer:x,skinning:ae.isSkinnedMesh===!0,morphTargets:V.morphAttributes.position!==void 0,morphNormals:V.morphAttributes.normal!==void 0,morphColors:V.morphAttributes.color!==void 0,morphTargetsCount:le,morphTextureStride:we,numDirLights:P.directional.length,numPointLights:P.point.length,numSpotLights:P.spot.length,numSpotLightMaps:P.spotLightMap.length,numRectAreaLights:P.rectArea.length,numHemiLights:P.hemi.length,numDirLightShadows:P.directionalShadowMap.length,numPointLightShadows:P.pointShadowMap.length,numSpotLightShadows:P.spotShadowMap.length,numSpotLightShadowsWithMaps:P.numSpotLightShadowsWithMaps,numLightProbes:P.numLightProbes,numClippingPlanes:u.numPlanes,numClipIntersection:u.numIntersection,dithering:T.dithering,shadowMapEnabled:n.shadowMap.enabled&&re.length>0,shadowMapType:n.shadowMap.type,toneMapping:vn,decodeVideoTexture:yt&&T.map.isVideoTexture===!0&&Nt.getTransfer(T.map.colorSpace)===Bt,premultipliedAlpha:T.premultipliedAlpha,doubleSided:T.side===Yi,flipSided:T.side===qn,useDepthPacking:T.depthPacking>=0,depthPacking:T.depthPacking||0,index0AttributeName:T.index0AttributeName,extensionClipCullDistance:$t&&T.extensions.clipCullDistance===!0&&s.has("WEBGL_clip_cull_distance"),extensionMultiDraw:($t&&T.extensions.multiDraw===!0||rt)&&s.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:s.has("KHR_parallel_shader_compile"),customProgramCacheKey:T.customProgramCacheKey()};return xt.vertexUv1s=p.has(1),xt.vertexUv2s=p.has(2),xt.vertexUv3s=p.has(3),p.clear(),xt}function L(T){const P=[];if(T.shaderID?P.push(T.shaderID):(P.push(T.customVertexShaderID),P.push(T.customFragmentShaderID)),T.defines!==void 0)for(const re in T.defines)P.push(re),P.push(T.defines[re]);return T.isRawShaderMaterial===!1&&(A(P,T),R(P,T),P.push(n.outputColorSpace)),P.push(T.customProgramCacheKey),P.join()}function A(T,P){T.push(P.precision),T.push(P.outputColorSpace),T.push(P.envMapMode),T.push(P.envMapCubeUVHeight),T.push(P.mapUv),T.push(P.alphaMapUv),T.push(P.lightMapUv),T.push(P.aoMapUv),T.push(P.bumpMapUv),T.push(P.normalMapUv),T.push(P.displacementMapUv),T.push(P.emissiveMapUv),T.push(P.metalnessMapUv),T.push(P.roughnessMapUv),T.push(P.anisotropyMapUv),T.push(P.clearcoatMapUv),T.push(P.clearcoatNormalMapUv),T.push(P.clearcoatRoughnessMapUv),T.push(P.iridescenceMapUv),T.push(P.iridescenceThicknessMapUv),T.push(P.sheenColorMapUv),T.push(P.sheenRoughnessMapUv),T.push(P.specularMapUv),T.push(P.specularColorMapUv),T.push(P.specularIntensityMapUv),T.push(P.transmissionMapUv),T.push(P.thicknessMapUv),T.push(P.combine),T.push(P.fogExp2),T.push(P.sizeAttenuation),T.push(P.morphTargetsCount),T.push(P.morphAttributeCount),T.push(P.numDirLights),T.push(P.numPointLights),T.push(P.numSpotLights),T.push(P.numSpotLightMaps),T.push(P.numHemiLights),T.push(P.numRectAreaLights),T.push(P.numDirLightShadows),T.push(P.numPointLightShadows),T.push(P.numSpotLightShadows),T.push(P.numSpotLightShadowsWithMaps),T.push(P.numLightProbes),T.push(P.shadowMapType),T.push(P.toneMapping),T.push(P.numClippingPlanes),T.push(P.numClipIntersection),T.push(P.depthPacking)}function R(T,P){d.disableAll(),P.supportsVertexTextures&&d.enable(0),P.instancing&&d.enable(1),P.instancingColor&&d.enable(2),P.instancingMorph&&d.enable(3),P.matcap&&d.enable(4),P.envMap&&d.enable(5),P.normalMapObjectSpace&&d.enable(6),P.normalMapTangentSpace&&d.enable(7),P.clearcoat&&d.enable(8),P.iridescence&&d.enable(9),P.alphaTest&&d.enable(10),P.vertexColors&&d.enable(11),P.vertexAlphas&&d.enable(12),P.vertexUv1s&&d.enable(13),P.vertexUv2s&&d.enable(14),P.vertexUv3s&&d.enable(15),P.vertexTangents&&d.enable(16),P.anisotropy&&d.enable(17),P.alphaHash&&d.enable(18),P.batching&&d.enable(19),P.dispersion&&d.enable(20),P.batchingColor&&d.enable(21),T.push(d.mask),d.disableAll(),P.fog&&d.enable(0),P.useFog&&d.enable(1),P.flatShading&&d.enable(2),P.logarithmicDepthBuffer&&d.enable(3),P.reverseDepthBuffer&&d.enable(4),P.skinning&&d.enable(5),P.morphTargets&&d.enable(6),P.morphNormals&&d.enable(7),P.morphColors&&d.enable(8),P.premultipliedAlpha&&d.enable(9),P.shadowMapEnabled&&d.enable(10),P.doubleSided&&d.enable(11),P.flipSided&&d.enable(12),P.useDepthPacking&&d.enable(13),P.dithering&&d.enable(14),P.transmission&&d.enable(15),P.sheen&&d.enable(16),P.opaque&&d.enable(17),P.pointsUvs&&d.enable(18),P.decodeVideoTexture&&d.enable(19),P.alphaToCoverage&&d.enable(20),T.push(d.mask)}function k(T){const P=E[T.type];let re;if(P){const J=qi[P];re=_b.clone(J.uniforms)}else re=T.uniforms;return re}function D(T,P){let re;for(let J=0,ae=g.length;J<ae;J++){const ve=g[J];if(ve.cacheKey===P){re=ve,++re.usedTimes;break}}return re===void 0&&(re=new RR(n,P,T,c),g.push(re)),re}function U(T){if(--T.usedTimes===0){const P=g.indexOf(T);g[P]=g[g.length-1],g.pop(),T.destroy()}}function $(T){f.remove(T)}function te(){f.dispose()}return{getParameters:M,getProgramCacheKey:L,getUniforms:k,acquireProgram:D,releaseProgram:U,releaseShaderCache:$,programs:g,dispose:te}}function IR(){let n=new WeakMap;function e(u){return n.has(u)}function t(u){let d=n.get(u);return d===void 0&&(d={},n.set(u,d)),d}function s(u){n.delete(u)}function a(u,d,f){n.get(u)[d]=f}function c(){n=new WeakMap}return{has:e,get:t,remove:s,update:a,dispose:c}}function UR(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.material.id!==e.material.id?n.material.id-e.material.id:n.z!==e.z?n.z-e.z:n.id-e.id}function Y_(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.z!==e.z?e.z-n.z:n.id-e.id}function K_(){const n=[];let e=0;const t=[],s=[],a=[];function c(){e=0,t.length=0,s.length=0,a.length=0}function u(v,x,y,w,E,_){let M=n[e];return M===void 0?(M={id:v.id,object:v,geometry:x,material:y,groupOrder:w,renderOrder:v.renderOrder,z:E,group:_},n[e]=M):(M.id=v.id,M.object=v,M.geometry=x,M.material=y,M.groupOrder=w,M.renderOrder=v.renderOrder,M.z=E,M.group=_),e++,M}function d(v,x,y,w,E,_){const M=u(v,x,y,w,E,_);y.transmission>0?s.push(M):y.transparent===!0?a.push(M):t.push(M)}function f(v,x,y,w,E,_){const M=u(v,x,y,w,E,_);y.transmission>0?s.unshift(M):y.transparent===!0?a.unshift(M):t.unshift(M)}function p(v,x){t.length>1&&t.sort(v||UR),s.length>1&&s.sort(x||Y_),a.length>1&&a.sort(x||Y_)}function g(){for(let v=e,x=n.length;v<x;v++){const y=n[v];if(y.id===null)break;y.id=null,y.object=null,y.geometry=null,y.material=null,y.group=null}}return{opaque:t,transmissive:s,transparent:a,init:c,push:d,unshift:f,finish:g,sort:p}}function FR(){let n=new WeakMap;function e(s,a){const c=n.get(s);let u;return c===void 0?(u=new K_,n.set(s,[u])):a>=c.length?(u=new K_,c.push(u)):u=c[a],u}function t(){n=new WeakMap}return{get:e,dispose:t}}function OR(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={direction:new se,color:new Pt};break;case"SpotLight":t={position:new se,direction:new se,color:new Pt,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":t={position:new se,color:new Pt,distance:0,decay:0};break;case"HemisphereLight":t={direction:new se,skyColor:new Pt,groundColor:new Pt};break;case"RectAreaLight":t={color:new Pt,position:new se,halfWidth:new se,halfHeight:new se};break}return n[e.id]=t,t}}}function jR(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new At};break;case"SpotLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new At};break;case"PointLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new At,shadowCameraNear:1,shadowCameraFar:1e3};break}return n[e.id]=t,t}}}let zR=0;function BR(n,e){return(e.castShadow?2:0)-(n.castShadow?2:0)+(e.map?1:0)-(n.map?1:0)}function HR(n){const e=new OR,t=jR(),s={version:0,hash:{directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let p=0;p<9;p++)s.probe.push(new se);const a=new se,c=new nn,u=new nn;function d(p){let g=0,v=0,x=0;for(let te=0;te<9;te++)s.probe[te].set(0,0,0);let y=0,w=0,E=0,_=0,M=0,L=0,A=0,R=0,k=0,D=0,U=0;p.sort(BR);for(let te=0,T=p.length;te<T;te++){const P=p[te],re=P.color,J=P.intensity,ae=P.distance,ve=P.shadow&&P.shadow.map?P.shadow.map.texture:null;if(P.isAmbientLight)g+=re.r*J,v+=re.g*J,x+=re.b*J;else if(P.isLightProbe){for(let V=0;V<9;V++)s.probe[V].addScaledVector(P.sh.coefficients[V],J);U++}else if(P.isDirectionalLight){const V=e.get(P);if(V.color.copy(P.color).multiplyScalar(P.intensity),P.castShadow){const de=P.shadow,z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,s.directionalShadow[y]=z,s.directionalShadowMap[y]=ve,s.directionalShadowMatrix[y]=P.shadow.matrix,L++}s.directional[y]=V,y++}else if(P.isSpotLight){const V=e.get(P);V.position.setFromMatrixPosition(P.matrixWorld),V.color.copy(re).multiplyScalar(J),V.distance=ae,V.coneCos=Math.cos(P.angle),V.penumbraCos=Math.cos(P.angle*(1-P.penumbra)),V.decay=P.decay,s.spot[E]=V;const de=P.shadow;if(P.map&&(s.spotLightMap[k]=P.map,k++,de.updateMatrices(P),P.castShadow&&D++),s.spotLightMatrix[E]=de.matrix,P.castShadow){const z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,s.spotShadow[E]=z,s.spotShadowMap[E]=ve,R++}E++}else if(P.isRectAreaLight){const V=e.get(P);V.color.copy(re).multiplyScalar(J),V.halfWidth.set(P.width*.5,0,0),V.halfHeight.set(0,P.height*.5,0),s.rectArea[_]=V,_++}else if(P.isPointLight){const V=e.get(P);if(V.color.copy(P.color).multiplyScalar(P.intensity),V.distance=P.distance,V.decay=P.decay,P.castShadow){const de=P.shadow,z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,z.shadowCameraNear=de.camera.near,z.shadowCameraFar=de.camera.far,s.pointShadow[w]=z,s.pointShadowMap[w]=ve,s.pointShadowMatrix[w]=P.shadow.matrix,A++}s.point[w]=V,w++}else if(P.isHemisphereLight){const V=e.get(P);V.skyColor.copy(P.color).multiplyScalar(J),V.groundColor.copy(P.groundColor).multiplyScalar(J),s.hemi[M]=V,M++}}_>0&&(n.has("OES_texture_float_linear")===!0?(s.rectAreaLTC1=De.LTC_FLOAT_1,s.rectAreaLTC2=De.LTC_FLOAT_2):(s.rectAreaLTC1=De.LTC_HALF_1,s.rectAreaLTC2=De.LTC_HALF_2)),s.ambient[0]=g,s.ambient[1]=v,s.ambient[2]=x;const $=s.hash;($.directionalLength!==y||$.pointLength!==w||$.spotLength!==E||$.rectAreaLength!==_||$.hemiLength!==M||$.numDirectionalShadows!==L||$.numPointShadows!==A||$.numSpotShadows!==R||$.numSpotMaps!==k||$.numLightProbes!==U)&&(s.directional.length=y,s.spot.length=E,s.rectArea.length=_,s.point.length=w,s.hemi.length=M,s.directionalShadow.length=L,s.directionalShadowMap.length=L,s.pointShadow.length=A,s.pointShadowMap.length=A,s.spotShadow.length=R,s.spotShadowMap.length=R,s.directionalShadowMatrix.length=L,s.pointShadowMatrix.length=A,s.spotLightMatrix.length=R+k-D,s.spotLightMap.length=k,s.numSpotLightShadowsWithMaps=D,s.numLightProbes=U,$.directionalLength=y,$.pointLength=w,$.spotLength=E,$.rectAreaLength=_,$.hemiLength=M,$.numDirectionalShadows=L,$.numPointShadows=A,$.numSpotShadows=R,$.numSpotMaps=k,$.numLightProbes=U,s.version=zR++)}function f(p,g){let v=0,x=0,y=0,w=0,E=0;const _=g.matrixWorldInverse;for(let M=0,L=p.length;M<L;M++){const A=p[M];if(A.isDirectionalLight){const R=s.directional[v];R.direction.setFromMatrixPosition(A.matrixWorld),a.setFromMatrixPosition(A.target.matrixWorld),R.direction.sub(a),R.direction.transformDirection(_),v++}else if(A.isSpotLight){const R=s.spot[y];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),R.direction.setFromMatrixPosition(A.matrixWorld),a.setFromMatrixPosition(A.target.matrixWorld),R.direction.sub(a),R.direction.transformDirection(_),y++}else if(A.isRectAreaLight){const R=s.rectArea[w];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),u.identity(),c.copy(A.matrixWorld),c.premultiply(_),u.extractRotation(c),R.halfWidth.set(A.width*.5,0,0),R.halfHeight.set(0,A.height*.5,0),R.halfWidth.applyMatrix4(u),R.halfHeight.applyMatrix4(u),w++}else if(A.isPointLight){const R=s.point[x];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),x++}else if(A.isHemisphereLight){const R=s.hemi[E];R.direction.setFromMatrixPosition(A.matrixWorld),R.direction.transformDirection(_),E++}}}return{setup:d,setupView:f,state:s}}function Z_(n){const e=new HR(n),t=[],s=[];function a(g){p.camera=g,t.length=0,s.length=0}function c(g){t.push(g)}function u(g){s.push(g)}function d(){e.setup(t)}function f(g){e.setupView(t,g)}const p={lightsArray:t,shadowsArray:s,camera:null,lights:e,transmissionRenderTarget:{}};return{init:a,state:p,setupLights:d,setupLightsView:f,pushLight:c,pushShadow:u}}function VR(n){let e=new WeakMap;function t(a,c=0){const u=e.get(a);let d;return u===void 0?(d=new Z_(n),e.set(a,[d])):c>=u.length?(d=new Z_(n),u.push(d)):d=u[c],d}function s(){e=new WeakMap}return{get:t,dispose:s}}class GR extends Ou{constructor(e){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=FT,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(e)}copy(e){return super.copy(e),this.depthPacking=e.depthPacking,this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this}}class WR extends Ou{constructor(e){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(e)}copy(e){return super.copy(e),this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this}}const $R=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,XR=`uniform sampler2D shadow_pass;
uniform vec2 resolution;
uniform float radius;
#include <packing>
void main() {
	const float samples = float( VSM_SAMPLES );
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / ( samples - 1.0 );
	float uvStart = samples <= 1.0 ? 0.0 : - 1.0;
	for ( float i = 0.0; i < samples; i ++ ) {
		float uvOffset = uvStart + i * uvStride;
		#ifdef HORIZONTAL_PASS
			vec2 distribution = unpackRGBATo2Half( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( uvOffset, 0.0 ) * radius ) / resolution ) );
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		#else
			float depth = unpackRGBAToDepth( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( 0.0, uvOffset ) * radius ) / resolution ) );
			mean += depth;
			squared_mean += depth * depth;
		#endif
	}
	mean = mean / samples;
	squared_mean = squared_mean / samples;
	float std_dev = sqrt( squared_mean - mean * mean );
	gl_FragColor = pack2HalfToRGBA( vec2( mean, std_dev ) );
}`;function qR(n,e,t){let s=new Sx;const a=new At,c=new At,u=new Qt,d=new GR({depthPacking:OT}),f=new WR,p={},g=t.maxTextureSize,v={[ur]:qn,[qn]:ur,[Yi]:Yi},x=new bs({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new At},radius:{value:4}},vertexShader:$R,fragmentShader:XR}),y=x.clone();y.defines.HORIZONTAL_PASS=1;const w=new As;w.setAttribute("position",new Ki(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));const E=new ji(w,x),_=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Zv;let M=this.type;this.render=function(D,U,$){if(_.enabled===!1||_.autoUpdate===!1&&_.needsUpdate===!1||D.length===0)return;const te=n.getRenderTarget(),T=n.getActiveCubeFace(),P=n.getActiveMipmapLevel(),re=n.state;re.setBlending(ar),re.buffers.color.setClear(1,1,1,1),re.buffers.depth.setTest(!0),re.setScissorTest(!1);const J=M!==gs&&this.type===gs,ae=M===gs&&this.type!==gs;for(let ve=0,V=D.length;ve<V;ve++){const de=D[ve],z=de.shadow;if(z===void 0){console.warn("THREE.WebGLShadowMap:",de,"has no shadow.");continue}if(z.autoUpdate===!1&&z.needsUpdate===!1)continue;a.copy(z.mapSize);const ue=z.getFrameExtents();if(a.multiply(ue),c.copy(z.mapSize),(a.x>g||a.y>g)&&(a.x>g&&(c.x=Math.floor(g/ue.x),a.x=c.x*ue.x,z.mapSize.x=c.x),a.y>g&&(c.y=Math.floor(g/ue.y),a.y=c.y*ue.y,z.mapSize.y=c.y)),z.map===null||J===!0||ae===!0){const O=this.type!==gs?{minFilter:Si,magFilter:Si}:{};z.map!==null&&z.map.dispose(),z.map=new qr(a.x,a.y,O),z.map.texture.name=de.name+".shadowMap",z.camera.updateProjectionMatrix()}n.setRenderTarget(z.map),n.clear();const oe=z.getViewportCount();for(let O=0;O<oe;O++){const le=z.getViewport(O);u.set(c.x*le.x,c.y*le.y,c.x*le.z,c.y*le.w),re.viewport(u),z.updateMatrices(de,O),s=z.getFrustum(),R(U,$,z.camera,de,this.type)}z.isPointLightShadow!==!0&&this.type===gs&&L(z,$),z.needsUpdate=!1}M=this.type,_.needsUpdate=!1,n.setRenderTarget(te,T,P)};function L(D,U){const $=e.update(E);x.defines.VSM_SAMPLES!==D.blurSamples&&(x.defines.VSM_SAMPLES=D.blurSamples,y.defines.VSM_SAMPLES=D.blurSamples,x.needsUpdate=!0,y.needsUpdate=!0),D.mapPass===null&&(D.mapPass=new qr(a.x,a.y)),x.uniforms.shadow_pass.value=D.map.texture,x.uniforms.resolution.value=D.mapSize,x.uniforms.radius.value=D.radius,n.setRenderTarget(D.mapPass),n.clear(),n.renderBufferDirect(U,null,$,x,E,null),y.uniforms.shadow_pass.value=D.mapPass.texture,y.uniforms.resolution.value=D.mapSize,y.uniforms.radius.value=D.radius,n.setRenderTarget(D.map),n.clear(),n.renderBufferDirect(U,null,$,y,E,null)}function A(D,U,$,te){let T=null;const P=$.isPointLight===!0?D.customDistanceMaterial:D.customDepthMaterial;if(P!==void 0)T=P;else if(T=$.isPointLight===!0?f:d,n.localClippingEnabled&&U.clipShadows===!0&&Array.isArray(U.clippingPlanes)&&U.clippingPlanes.length!==0||U.displacementMap&&U.displacementScale!==0||U.alphaMap&&U.alphaTest>0||U.map&&U.alphaTest>0){const re=T.uuid,J=U.uuid;let ae=p[re];ae===void 0&&(ae={},p[re]=ae);let ve=ae[J];ve===void 0&&(ve=T.clone(),ae[J]=ve,U.addEventListener("dispose",k)),T=ve}if(T.visible=U.visible,T.wireframe=U.wireframe,te===gs?T.side=U.shadowSide!==null?U.shadowSide:U.side:T.side=U.shadowSide!==null?U.shadowSide:v[U.side],T.alphaMap=U.alphaMap,T.alphaTest=U.alphaTest,T.map=U.map,T.clipShadows=U.clipShadows,T.clippingPlanes=U.clippingPlanes,T.clipIntersection=U.clipIntersection,T.displacementMap=U.displacementMap,T.displacementScale=U.displacementScale,T.displacementBias=U.displacementBias,T.wireframeLinewidth=U.wireframeLinewidth,T.linewidth=U.linewidth,$.isPointLight===!0&&T.isMeshDistanceMaterial===!0){const re=n.properties.get(T);re.light=$}return T}function R(D,U,$,te,T){if(D.visible===!1)return;if(D.layers.test(U.layers)&&(D.isMesh||D.isLine||D.isPoints)&&(D.castShadow||D.receiveShadow&&T===gs)&&(!D.frustumCulled||s.intersectsObject(D))){D.modelViewMatrix.multiplyMatrices($.matrixWorldInverse,D.matrixWorld);const J=e.update(D),ae=D.material;if(Array.isArray(ae)){const ve=J.groups;for(let V=0,de=ve.length;V<de;V++){const z=ve[V],ue=ae[z.materialIndex];if(ue&&ue.visible){const oe=A(D,ue,te,T);D.onBeforeShadow(n,D,U,$,J,oe,z),n.renderBufferDirect($,null,J,oe,D,z),D.onAfterShadow(n,D,U,$,J,oe,z)}}}else if(ae.visible){const ve=A(D,ae,te,T);D.onBeforeShadow(n,D,U,$,J,ve,null),n.renderBufferDirect($,null,J,ve,D,null),D.onAfterShadow(n,D,U,$,J,ve,null)}}const re=D.children;for(let J=0,ae=re.length;J<ae;J++)R(re[J],U,$,te,T)}function k(D){D.target.removeEventListener("dispose",k);for(const $ in p){const te=p[$],T=D.target.uuid;T in te&&(te[T].dispose(),delete te[T])}}}const YR={[Ef]:wf,[Tf]:Cf,[bf]:Nf,[Xa]:Af,[wf]:Ef,[Cf]:Tf,[Nf]:bf,[Af]:Xa};function KR(n){function e(){let G=!1;const Fe=new Qt;let ce=null;const _e=new Qt(0,0,0,0);return{setMask:function(Le){ce!==Le&&!G&&(n.colorMask(Le,Le,Le,Le),ce=Le)},setLocked:function(Le){G=Le},setClear:function(Le,je,gt,$t,vn){vn===!0&&(Le*=$t,je*=$t,gt*=$t),Fe.set(Le,je,gt,$t),_e.equals(Fe)===!1&&(n.clearColor(Le,je,gt,$t),_e.copy(Fe))},reset:function(){G=!1,ce=null,_e.set(-1,0,0,0)}}}function t(){let G=!1,Fe=!1,ce=null,_e=null,Le=null;return{setReversed:function(je){Fe=je},setTest:function(je){je?Te(n.DEPTH_TEST):Ae(n.DEPTH_TEST)},setMask:function(je){ce!==je&&!G&&(n.depthMask(je),ce=je)},setFunc:function(je){if(Fe&&(je=YR[je]),_e!==je){switch(je){case Ef:n.depthFunc(n.NEVER);break;case wf:n.depthFunc(n.ALWAYS);break;case Tf:n.depthFunc(n.LESS);break;case Xa:n.depthFunc(n.LEQUAL);break;case bf:n.depthFunc(n.EQUAL);break;case Af:n.depthFunc(n.GEQUAL);break;case Cf:n.depthFunc(n.GREATER);break;case Nf:n.depthFunc(n.NOTEQUAL);break;default:n.depthFunc(n.LEQUAL)}_e=je}},setLocked:function(je){G=je},setClear:function(je){Le!==je&&(n.clearDepth(je),Le=je)},reset:function(){G=!1,ce=null,_e=null,Le=null}}}function s(){let G=!1,Fe=null,ce=null,_e=null,Le=null,je=null,gt=null,$t=null,vn=null;return{setTest:function(xt){G||(xt?Te(n.STENCIL_TEST):Ae(n.STENCIL_TEST))},setMask:function(xt){Fe!==xt&&!G&&(n.stencilMask(xt),Fe=xt)},setFunc:function(xt,dn,ci){(ce!==xt||_e!==dn||Le!==ci)&&(n.stencilFunc(xt,dn,ci),ce=xt,_e=dn,Le=ci)},setOp:function(xt,dn,ci){(je!==xt||gt!==dn||$t!==ci)&&(n.stencilOp(xt,dn,ci),je=xt,gt=dn,$t=ci)},setLocked:function(xt){G=xt},setClear:function(xt){vn!==xt&&(n.clearStencil(xt),vn=xt)},reset:function(){G=!1,Fe=null,ce=null,_e=null,Le=null,je=null,gt=null,$t=null,vn=null}}}const a=new e,c=new t,u=new s,d=new WeakMap,f=new WeakMap;let p={},g={},v=new WeakMap,x=[],y=null,w=!1,E=null,_=null,M=null,L=null,A=null,R=null,k=null,D=new Pt(0,0,0),U=0,$=!1,te=null,T=null,P=null,re=null,J=null;const ae=n.getParameter(n.MAX_COMBINED_TEXTURE_IMAGE_UNITS);let ve=!1,V=0;const de=n.getParameter(n.VERSION);de.indexOf("WebGL")!==-1?(V=parseFloat(/^WebGL (\d)/.exec(de)[1]),ve=V>=1):de.indexOf("OpenGL ES")!==-1&&(V=parseFloat(/^OpenGL ES (\d)/.exec(de)[1]),ve=V>=2);let z=null,ue={};const oe=n.getParameter(n.SCISSOR_BOX),O=n.getParameter(n.VIEWPORT),le=new Qt().fromArray(oe),we=new Qt().fromArray(O);function K(G,Fe,ce,_e){const Le=new Uint8Array(4),je=n.createTexture();n.bindTexture(G,je),n.texParameteri(G,n.TEXTURE_MIN_FILTER,n.NEAREST),n.texParameteri(G,n.TEXTURE_MAG_FILTER,n.NEAREST);for(let gt=0;gt<ce;gt++)G===n.TEXTURE_3D||G===n.TEXTURE_2D_ARRAY?n.texImage3D(Fe,0,n.RGBA,1,1,_e,0,n.RGBA,n.UNSIGNED_BYTE,Le):n.texImage2D(Fe+gt,0,n.RGBA,1,1,0,n.RGBA,n.UNSIGNED_BYTE,Le);return je}const fe={};fe[n.TEXTURE_2D]=K(n.TEXTURE_2D,n.TEXTURE_2D,1),fe[n.TEXTURE_CUBE_MAP]=K(n.TEXTURE_CUBE_MAP,n.TEXTURE_CUBE_MAP_POSITIVE_X,6),fe[n.TEXTURE_2D_ARRAY]=K(n.TEXTURE_2D_ARRAY,n.TEXTURE_2D_ARRAY,1,1),fe[n.TEXTURE_3D]=K(n.TEXTURE_3D,n.TEXTURE_3D,1,1),a.setClear(0,0,0,1),c.setClear(1),u.setClear(0),Te(n.DEPTH_TEST),c.setFunc(Xa),ft(!1),_t(a_),Te(n.CULL_FACE),B(ar);function Te(G){p[G]!==!0&&(n.enable(G),p[G]=!0)}function Ae(G){p[G]!==!1&&(n.disable(G),p[G]=!1)}function Ie(G,Fe){return g[G]!==Fe?(n.bindFramebuffer(G,Fe),g[G]=Fe,G===n.DRAW_FRAMEBUFFER&&(g[n.FRAMEBUFFER]=Fe),G===n.FRAMEBUFFER&&(g[n.DRAW_FRAMEBUFFER]=Fe),!0):!1}function Ue(G,Fe){let ce=x,_e=!1;if(G){ce=v.get(Fe),ce===void 0&&(ce=[],v.set(Fe,ce));const Le=G.textures;if(ce.length!==Le.length||ce[0]!==n.COLOR_ATTACHMENT0){for(let je=0,gt=Le.length;je<gt;je++)ce[je]=n.COLOR_ATTACHMENT0+je;ce.length=Le.length,_e=!0}}else ce[0]!==n.BACK&&(ce[0]=n.BACK,_e=!0);_e&&n.drawBuffers(ce)}function rt(G){return y!==G?(n.useProgram(G),y=G,!0):!1}const yt={[Ir]:n.FUNC_ADD,[uT]:n.FUNC_SUBTRACT,[dT]:n.FUNC_REVERSE_SUBTRACT};yt[hT]=n.MIN,yt[fT]=n.MAX;const pt={[pT]:n.ZERO,[mT]:n.ONE,[gT]:n.SRC_COLOR,[Sf]:n.SRC_ALPHA,[MT]:n.SRC_ALPHA_SATURATE,[yT]:n.DST_COLOR,[vT]:n.DST_ALPHA,[_T]:n.ONE_MINUS_SRC_COLOR,[Mf]:n.ONE_MINUS_SRC_ALPHA,[ST]:n.ONE_MINUS_DST_COLOR,[xT]:n.ONE_MINUS_DST_ALPHA,[ET]:n.CONSTANT_COLOR,[wT]:n.ONE_MINUS_CONSTANT_COLOR,[TT]:n.CONSTANT_ALPHA,[bT]:n.ONE_MINUS_CONSTANT_ALPHA};function B(G,Fe,ce,_e,Le,je,gt,$t,vn,xt){if(G===ar){w===!0&&(Ae(n.BLEND),w=!1);return}if(w===!1&&(Te(n.BLEND),w=!0),G!==cT){if(G!==E||xt!==$){if((_!==Ir||A!==Ir)&&(n.blendEquation(n.FUNC_ADD),_=Ir,A=Ir),xt)switch(G){case Ha:n.blendFuncSeparate(n.ONE,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case yf:n.blendFunc(n.ONE,n.ONE);break;case o_:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case l_:n.blendFuncSeparate(n.ZERO,n.SRC_COLOR,n.ZERO,n.SRC_ALPHA);break;default:console.error("THREE.WebGLState: Invalid blending: ",G);break}else switch(G){case Ha:n.blendFuncSeparate(n.SRC_ALPHA,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case yf:n.blendFunc(n.SRC_ALPHA,n.ONE);break;case o_:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case l_:n.blendFunc(n.ZERO,n.SRC_COLOR);break;default:console.error("THREE.WebGLState: Invalid blending: ",G);break}M=null,L=null,R=null,k=null,D.set(0,0,0),U=0,E=G,$=xt}return}Le=Le||Fe,je=je||ce,gt=gt||_e,(Fe!==_||Le!==A)&&(n.blendEquationSeparate(yt[Fe],yt[Le]),_=Fe,A=Le),(ce!==M||_e!==L||je!==R||gt!==k)&&(n.blendFuncSeparate(pt[ce],pt[_e],pt[je],pt[gt]),M=ce,L=_e,R=je,k=gt),($t.equals(D)===!1||vn!==U)&&(n.blendColor($t.r,$t.g,$t.b,vn),D.copy($t),U=vn),E=G,$=!1}function _n(G,Fe){G.side===Yi?Ae(n.CULL_FACE):Te(n.CULL_FACE);let ce=G.side===qn;Fe&&(ce=!ce),ft(ce),G.blending===Ha&&G.transparent===!1?B(ar):B(G.blending,G.blendEquation,G.blendSrc,G.blendDst,G.blendEquationAlpha,G.blendSrcAlpha,G.blendDstAlpha,G.blendColor,G.blendAlpha,G.premultipliedAlpha),c.setFunc(G.depthFunc),c.setTest(G.depthTest),c.setMask(G.depthWrite),a.setMask(G.colorWrite);const _e=G.stencilWrite;u.setTest(_e),_e&&(u.setMask(G.stencilWriteMask),u.setFunc(G.stencilFunc,G.stencilRef,G.stencilFuncMask),u.setOp(G.stencilFail,G.stencilZFail,G.stencilZPass)),Lt(G.polygonOffset,G.polygonOffsetFactor,G.polygonOffsetUnits),G.alphaToCoverage===!0?Te(n.SAMPLE_ALPHA_TO_COVERAGE):Ae(n.SAMPLE_ALPHA_TO_COVERAGE)}function ft(G){te!==G&&(G?n.frontFace(n.CW):n.frontFace(n.CCW),te=G)}function _t(G){G!==aT?(Te(n.CULL_FACE),G!==T&&(G===a_?n.cullFace(n.BACK):G===oT?n.cullFace(n.FRONT):n.cullFace(n.FRONT_AND_BACK))):Ae(n.CULL_FACE),T=G}function tt(G){G!==P&&(ve&&n.lineWidth(G),P=G)}function Lt(G,Fe,ce){G?(Te(n.POLYGON_OFFSET_FILL),(re!==Fe||J!==ce)&&(n.polygonOffset(Fe,ce),re=Fe,J=ce)):Ae(n.POLYGON_OFFSET_FILL)}function it(G){G?Te(n.SCISSOR_TEST):Ae(n.SCISSOR_TEST)}function I(G){G===void 0&&(G=n.TEXTURE0+ae-1),z!==G&&(n.activeTexture(G),z=G)}function C(G,Fe,ce){ce===void 0&&(z===null?ce=n.TEXTURE0+ae-1:ce=z);let _e=ue[ce];_e===void 0&&(_e={type:void 0,texture:void 0},ue[ce]=_e),(_e.type!==G||_e.texture!==Fe)&&(z!==ce&&(n.activeTexture(ce),z=ce),n.bindTexture(G,Fe||fe[G]),_e.type=G,_e.texture=Fe)}function Q(){const G=ue[z];G!==void 0&&G.type!==void 0&&(n.bindTexture(G.type,null),G.type=void 0,G.texture=void 0)}function me(){try{n.compressedTexImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Se(){try{n.compressedTexImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function pe(){try{n.texSubImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Ze(){try{n.texSubImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function ke(){try{n.compressedTexSubImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Be(){try{n.compressedTexSubImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function vt(){try{n.texStorage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Ce(){try{n.texStorage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function He(){try{n.texImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function at(){try{n.texImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function st(G){le.equals(G)===!1&&(n.scissor(G.x,G.y,G.z,G.w),le.copy(G))}function Ge(G){we.equals(G)===!1&&(n.viewport(G.x,G.y,G.z,G.w),we.copy(G))}function mt(G,Fe){let ce=f.get(Fe);ce===void 0&&(ce=new WeakMap,f.set(Fe,ce));let _e=ce.get(G);_e===void 0&&(_e=n.getUniformBlockIndex(Fe,G.name),ce.set(G,_e))}function lt(G,Fe){const _e=f.get(Fe).get(G);d.get(Fe)!==_e&&(n.uniformBlockBinding(Fe,_e,G.__bindingPointIndex),d.set(Fe,_e))}function Ct(){n.disable(n.BLEND),n.disable(n.CULL_FACE),n.disable(n.DEPTH_TEST),n.disable(n.POLYGON_OFFSET_FILL),n.disable(n.SCISSOR_TEST),n.disable(n.STENCIL_TEST),n.disable(n.SAMPLE_ALPHA_TO_COVERAGE),n.blendEquation(n.FUNC_ADD),n.blendFunc(n.ONE,n.ZERO),n.blendFuncSeparate(n.ONE,n.ZERO,n.ONE,n.ZERO),n.blendColor(0,0,0,0),n.colorMask(!0,!0,!0,!0),n.clearColor(0,0,0,0),n.depthMask(!0),n.depthFunc(n.LESS),n.clearDepth(1),n.stencilMask(4294967295),n.stencilFunc(n.ALWAYS,0,4294967295),n.stencilOp(n.KEEP,n.KEEP,n.KEEP),n.clearStencil(0),n.cullFace(n.BACK),n.frontFace(n.CCW),n.polygonOffset(0,0),n.activeTexture(n.TEXTURE0),n.bindFramebuffer(n.FRAMEBUFFER,null),n.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),n.bindFramebuffer(n.READ_FRAMEBUFFER,null),n.useProgram(null),n.lineWidth(1),n.scissor(0,0,n.canvas.width,n.canvas.height),n.viewport(0,0,n.canvas.width,n.canvas.height),p={},z=null,ue={},g={},v=new WeakMap,x=[],y=null,w=!1,E=null,_=null,M=null,L=null,A=null,R=null,k=null,D=new Pt(0,0,0),U=0,$=!1,te=null,T=null,P=null,re=null,J=null,le.set(0,0,n.canvas.width,n.canvas.height),we.set(0,0,n.canvas.width,n.canvas.height),a.reset(),c.reset(),u.reset()}return{buffers:{color:a,depth:c,stencil:u},enable:Te,disable:Ae,bindFramebuffer:Ie,drawBuffers:Ue,useProgram:rt,setBlending:B,setMaterial:_n,setFlipSided:ft,setCullFace:_t,setLineWidth:tt,setPolygonOffset:Lt,setScissorTest:it,activeTexture:I,bindTexture:C,unbindTexture:Q,compressedTexImage2D:me,compressedTexImage3D:Se,texImage2D:He,texImage3D:at,updateUBOMapping:mt,uniformBlockBinding:lt,texStorage2D:vt,texStorage3D:Ce,texSubImage2D:pe,texSubImage3D:Ze,compressedTexSubImage2D:ke,compressedTexSubImage3D:Be,scissor:st,viewport:Ge,reset:Ct}}function Q_(n,e,t,s){const a=ZR(s);switch(t){case ix:return n*e;case rx:return n*e;case ax:return n*e*2;case ox:return n*e/a.components*a.byteLength;case Fp:return n*e/a.components*a.byteLength;case lx:return n*e*2/a.components*a.byteLength;case Op:return n*e*2/a.components*a.byteLength;case sx:return n*e*3/a.components*a.byteLength;case Oi:return n*e*4/a.components*a.byteLength;case jp:return n*e*4/a.components*a.byteLength;case tu:case nu:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case iu:case su:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case If:case Ff:return Math.max(n,16)*Math.max(e,8)/4;case Df:case Uf:return Math.max(n,8)*Math.max(e,8)/2;case Of:case jf:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case zf:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Bf:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Hf:return Math.floor((n+4)/5)*Math.floor((e+3)/4)*16;case Vf:return Math.floor((n+4)/5)*Math.floor((e+4)/5)*16;case Gf:return Math.floor((n+5)/6)*Math.floor((e+4)/5)*16;case Wf:return Math.floor((n+5)/6)*Math.floor((e+5)/6)*16;case $f:return Math.floor((n+7)/8)*Math.floor((e+4)/5)*16;case Xf:return Math.floor((n+7)/8)*Math.floor((e+5)/6)*16;case qf:return Math.floor((n+7)/8)*Math.floor((e+7)/8)*16;case Yf:return Math.floor((n+9)/10)*Math.floor((e+4)/5)*16;case Kf:return Math.floor((n+9)/10)*Math.floor((e+5)/6)*16;case Zf:return Math.floor((n+9)/10)*Math.floor((e+7)/8)*16;case Qf:return Math.floor((n+9)/10)*Math.floor((e+9)/10)*16;case Jf:return Math.floor((n+11)/12)*Math.floor((e+9)/10)*16;case ep:return Math.floor((n+11)/12)*Math.floor((e+11)/12)*16;case ru:case tp:case np:return Math.ceil(n/4)*Math.ceil(e/4)*16;case cx:case ip:return Math.ceil(n/4)*Math.ceil(e/4)*8;case sp:case rp:return Math.ceil(n/4)*Math.ceil(e/4)*16}throw new Error(`Unable to determine texture byte length for ${t} format.`)}function ZR(n){switch(n){case ws:case ex:return{byteLength:1,components:1};case ol:case tx:case hl:return{byteLength:2,components:1};case Ip:case Up:return{byteLength:2,components:4};case Xr:case Dp:case xs:return{byteLength:4,components:1};case nx:return{byteLength:4,components:3}}throw new Error(`Unknown texture type ${n}.`)}function QR(n,e,t,s,a,c,u){const d=e.has("WEBGL_multisampled_render_to_texture")?e.get("WEBGL_multisampled_render_to_texture"):null,f=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),p=new At,g=new WeakMap;let v;const x=new WeakMap;let y=!1;try{y=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function w(I,C){return y?new OffscreenCanvas(I,C):yu("canvas")}function E(I,C,Q){let me=1;const Se=it(I);if((Se.width>Q||Se.height>Q)&&(me=Q/Math.max(Se.width,Se.height)),me<1)if(typeof HTMLImageElement<"u"&&I instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&I instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&I instanceof ImageBitmap||typeof VideoFrame<"u"&&I instanceof VideoFrame){const pe=Math.floor(me*Se.width),Ze=Math.floor(me*Se.height);v===void 0&&(v=w(pe,Ze));const ke=C?w(pe,Ze):v;return ke.width=pe,ke.height=Ze,ke.getContext("2d").drawImage(I,0,0,pe,Ze),console.warn("THREE.WebGLRenderer: Texture has been resized from ("+Se.width+"x"+Se.height+") to ("+pe+"x"+Ze+")."),ke}else return"data"in I&&console.warn("THREE.WebGLRenderer: Image in DataTexture is too big ("+Se.width+"x"+Se.height+")."),I;return I}function _(I){return I.generateMipmaps&&I.minFilter!==Si&&I.minFilter!==Di}function M(I){n.generateMipmap(I)}function L(I,C,Q,me,Se=!1){if(I!==null){if(n[I]!==void 0)return n[I];console.warn("THREE.WebGLRenderer: Attempt to use non-existing WebGL internal format '"+I+"'")}let pe=C;if(C===n.RED&&(Q===n.FLOAT&&(pe=n.R32F),Q===n.HALF_FLOAT&&(pe=n.R16F),Q===n.UNSIGNED_BYTE&&(pe=n.R8)),C===n.RED_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.R8UI),Q===n.UNSIGNED_SHORT&&(pe=n.R16UI),Q===n.UNSIGNED_INT&&(pe=n.R32UI),Q===n.BYTE&&(pe=n.R8I),Q===n.SHORT&&(pe=n.R16I),Q===n.INT&&(pe=n.R32I)),C===n.RG&&(Q===n.FLOAT&&(pe=n.RG32F),Q===n.HALF_FLOAT&&(pe=n.RG16F),Q===n.UNSIGNED_BYTE&&(pe=n.RG8)),C===n.RG_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RG8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RG16UI),Q===n.UNSIGNED_INT&&(pe=n.RG32UI),Q===n.BYTE&&(pe=n.RG8I),Q===n.SHORT&&(pe=n.RG16I),Q===n.INT&&(pe=n.RG32I)),C===n.RGB_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RGB8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RGB16UI),Q===n.UNSIGNED_INT&&(pe=n.RGB32UI),Q===n.BYTE&&(pe=n.RGB8I),Q===n.SHORT&&(pe=n.RGB16I),Q===n.INT&&(pe=n.RGB32I)),C===n.RGBA_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RGBA8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RGBA16UI),Q===n.UNSIGNED_INT&&(pe=n.RGBA32UI),Q===n.BYTE&&(pe=n.RGBA8I),Q===n.SHORT&&(pe=n.RGBA16I),Q===n.INT&&(pe=n.RGBA32I)),C===n.RGB&&Q===n.UNSIGNED_INT_5_9_9_9_REV&&(pe=n.RGB9_E5),C===n.RGBA){const Ze=Se?gu:Nt.getTransfer(me);Q===n.FLOAT&&(pe=n.RGBA32F),Q===n.HALF_FLOAT&&(pe=n.RGBA16F),Q===n.UNSIGNED_BYTE&&(pe=Ze===Bt?n.SRGB8_ALPHA8:n.RGBA8),Q===n.UNSIGNED_SHORT_4_4_4_4&&(pe=n.RGBA4),Q===n.UNSIGNED_SHORT_5_5_5_1&&(pe=n.RGB5_A1)}return(pe===n.R16F||pe===n.R32F||pe===n.RG16F||pe===n.RG32F||pe===n.RGBA16F||pe===n.RGBA32F)&&e.get("EXT_color_buffer_float"),pe}function A(I,C){let Q;return I?C===null||C===Xr||C===Ka?Q=n.DEPTH24_STENCIL8:C===xs?Q=n.DEPTH32F_STENCIL8:C===ol&&(Q=n.DEPTH24_STENCIL8,console.warn("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):C===null||C===Xr||C===Ka?Q=n.DEPTH_COMPONENT24:C===xs?Q=n.DEPTH_COMPONENT32F:C===ol&&(Q=n.DEPTH_COMPONENT16),Q}function R(I,C){return _(I)===!0||I.isFramebufferTexture&&I.minFilter!==Si&&I.minFilter!==Di?Math.log2(Math.max(C.width,C.height))+1:I.mipmaps!==void 0&&I.mipmaps.length>0?I.mipmaps.length:I.isCompressedTexture&&Array.isArray(I.image)?C.mipmaps.length:1}function k(I){const C=I.target;C.removeEventListener("dispose",k),U(C),C.isVideoTexture&&g.delete(C)}function D(I){const C=I.target;C.removeEventListener("dispose",D),te(C)}function U(I){const C=s.get(I);if(C.__webglInit===void 0)return;const Q=I.source,me=x.get(Q);if(me){const Se=me[C.__cacheKey];Se.usedTimes--,Se.usedTimes===0&&$(I),Object.keys(me).length===0&&x.delete(Q)}s.remove(I)}function $(I){const C=s.get(I);n.deleteTexture(C.__webglTexture);const Q=I.source,me=x.get(Q);delete me[C.__cacheKey],u.memory.textures--}function te(I){const C=s.get(I);if(I.depthTexture&&I.depthTexture.dispose(),I.isWebGLCubeRenderTarget)for(let me=0;me<6;me++){if(Array.isArray(C.__webglFramebuffer[me]))for(let Se=0;Se<C.__webglFramebuffer[me].length;Se++)n.deleteFramebuffer(C.__webglFramebuffer[me][Se]);else n.deleteFramebuffer(C.__webglFramebuffer[me]);C.__webglDepthbuffer&&n.deleteRenderbuffer(C.__webglDepthbuffer[me])}else{if(Array.isArray(C.__webglFramebuffer))for(let me=0;me<C.__webglFramebuffer.length;me++)n.deleteFramebuffer(C.__webglFramebuffer[me]);else n.deleteFramebuffer(C.__webglFramebuffer);if(C.__webglDepthbuffer&&n.deleteRenderbuffer(C.__webglDepthbuffer),C.__webglMultisampledFramebuffer&&n.deleteFramebuffer(C.__webglMultisampledFramebuffer),C.__webglColorRenderbuffer)for(let me=0;me<C.__webglColorRenderbuffer.length;me++)C.__webglColorRenderbuffer[me]&&n.deleteRenderbuffer(C.__webglColorRenderbuffer[me]);C.__webglDepthRenderbuffer&&n.deleteRenderbuffer(C.__webglDepthRenderbuffer)}const Q=I.textures;for(let me=0,Se=Q.length;me<Se;me++){const pe=s.get(Q[me]);pe.__webglTexture&&(n.deleteTexture(pe.__webglTexture),u.memory.textures--),s.remove(Q[me])}s.remove(I)}let T=0;function P(){T=0}function re(){const I=T;return I>=a.maxTextures&&console.warn("THREE.WebGLTextures: Trying to use "+I+" texture units while this GPU supports only "+a.maxTextures),T+=1,I}function J(I){const C=[];return C.push(I.wrapS),C.push(I.wrapT),C.push(I.wrapR||0),C.push(I.magFilter),C.push(I.minFilter),C.push(I.anisotropy),C.push(I.internalFormat),C.push(I.format),C.push(I.type),C.push(I.generateMipmaps),C.push(I.premultiplyAlpha),C.push(I.flipY),C.push(I.unpackAlignment),C.push(I.colorSpace),C.join()}function ae(I,C){const Q=s.get(I);if(I.isVideoTexture&&tt(I),I.isRenderTargetTexture===!1&&I.version>0&&Q.__version!==I.version){const me=I.image;if(me===null)console.warn("THREE.WebGLRenderer: Texture marked for update but no image data found.");else if(me.complete===!1)console.warn("THREE.WebGLRenderer: Texture marked for update but image is incomplete");else{we(Q,I,C);return}}t.bindTexture(n.TEXTURE_2D,Q.__webglTexture,n.TEXTURE0+C)}function ve(I,C){const Q=s.get(I);if(I.version>0&&Q.__version!==I.version){we(Q,I,C);return}t.bindTexture(n.TEXTURE_2D_ARRAY,Q.__webglTexture,n.TEXTURE0+C)}function V(I,C){const Q=s.get(I);if(I.version>0&&Q.__version!==I.version){we(Q,I,C);return}t.bindTexture(n.TEXTURE_3D,Q.__webglTexture,n.TEXTURE0+C)}function de(I,C){const Q=s.get(I);if(I.version>0&&Q.__version!==I.version){K(Q,I,C);return}t.bindTexture(n.TEXTURE_CUBE_MAP,Q.__webglTexture,n.TEXTURE0+C)}const z={[kf]:n.REPEAT,[jr]:n.CLAMP_TO_EDGE,[Lf]:n.MIRRORED_REPEAT},ue={[Si]:n.NEAREST,[UT]:n.NEAREST_MIPMAP_NEAREST,[Cc]:n.NEAREST_MIPMAP_LINEAR,[Di]:n.LINEAR,[Nh]:n.LINEAR_MIPMAP_NEAREST,[zr]:n.LINEAR_MIPMAP_LINEAR},oe={[BT]:n.NEVER,[XT]:n.ALWAYS,[HT]:n.LESS,[ux]:n.LEQUAL,[VT]:n.EQUAL,[$T]:n.GEQUAL,[GT]:n.GREATER,[WT]:n.NOTEQUAL};function O(I,C){if(C.type===xs&&e.has("OES_texture_float_linear")===!1&&(C.magFilter===Di||C.magFilter===Nh||C.magFilter===Cc||C.magFilter===zr||C.minFilter===Di||C.minFilter===Nh||C.minFilter===Cc||C.minFilter===zr)&&console.warn("THREE.WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),n.texParameteri(I,n.TEXTURE_WRAP_S,z[C.wrapS]),n.texParameteri(I,n.TEXTURE_WRAP_T,z[C.wrapT]),(I===n.TEXTURE_3D||I===n.TEXTURE_2D_ARRAY)&&n.texParameteri(I,n.TEXTURE_WRAP_R,z[C.wrapR]),n.texParameteri(I,n.TEXTURE_MAG_FILTER,ue[C.magFilter]),n.texParameteri(I,n.TEXTURE_MIN_FILTER,ue[C.minFilter]),C.compareFunction&&(n.texParameteri(I,n.TEXTURE_COMPARE_MODE,n.COMPARE_REF_TO_TEXTURE),n.texParameteri(I,n.TEXTURE_COMPARE_FUNC,oe[C.compareFunction])),e.has("EXT_texture_filter_anisotropic")===!0){if(C.magFilter===Si||C.minFilter!==Cc&&C.minFilter!==zr||C.type===xs&&e.has("OES_texture_float_linear")===!1)return;if(C.anisotropy>1||s.get(C).__currentAnisotropy){const Q=e.get("EXT_texture_filter_anisotropic");n.texParameterf(I,Q.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(C.anisotropy,a.getMaxAnisotropy())),s.get(C).__currentAnisotropy=C.anisotropy}}}function le(I,C){let Q=!1;I.__webglInit===void 0&&(I.__webglInit=!0,C.addEventListener("dispose",k));const me=C.source;let Se=x.get(me);Se===void 0&&(Se={},x.set(me,Se));const pe=J(C);if(pe!==I.__cacheKey){Se[pe]===void 0&&(Se[pe]={texture:n.createTexture(),usedTimes:0},u.memory.textures++,Q=!0),Se[pe].usedTimes++;const Ze=Se[I.__cacheKey];Ze!==void 0&&(Se[I.__cacheKey].usedTimes--,Ze.usedTimes===0&&$(C)),I.__cacheKey=pe,I.__webglTexture=Se[pe].texture}return Q}function we(I,C,Q){let me=n.TEXTURE_2D;(C.isDataArrayTexture||C.isCompressedArrayTexture)&&(me=n.TEXTURE_2D_ARRAY),C.isData3DTexture&&(me=n.TEXTURE_3D);const Se=le(I,C),pe=C.source;t.bindTexture(me,I.__webglTexture,n.TEXTURE0+Q);const Ze=s.get(pe);if(pe.version!==Ze.__version||Se===!0){t.activeTexture(n.TEXTURE0+Q);const ke=Nt.getPrimaries(Nt.workingColorSpace),Be=C.colorSpace===ir?null:Nt.getPrimaries(C.colorSpace),vt=C.colorSpace===ir||ke===Be?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,C.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,C.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,C.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,vt);let Ce=E(C.image,!1,a.maxTextureSize);Ce=Lt(C,Ce);const He=c.convert(C.format,C.colorSpace),at=c.convert(C.type);let st=L(C.internalFormat,He,at,C.colorSpace,C.isVideoTexture);O(me,C);let Ge;const mt=C.mipmaps,lt=C.isVideoTexture!==!0,Ct=Ze.__version===void 0||Se===!0,G=pe.dataReady,Fe=R(C,Ce);if(C.isDepthTexture)st=A(C.format===Za,C.type),Ct&&(lt?t.texStorage2D(n.TEXTURE_2D,1,st,Ce.width,Ce.height):t.texImage2D(n.TEXTURE_2D,0,st,Ce.width,Ce.height,0,He,at,null));else if(C.isDataTexture)if(mt.length>0){lt&&Ct&&t.texStorage2D(n.TEXTURE_2D,Fe,st,mt[0].width,mt[0].height);for(let ce=0,_e=mt.length;ce<_e;ce++)Ge=mt[ce],lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,at,Ge.data):t.texImage2D(n.TEXTURE_2D,ce,st,Ge.width,Ge.height,0,He,at,Ge.data);C.generateMipmaps=!1}else lt?(Ct&&t.texStorage2D(n.TEXTURE_2D,Fe,st,Ce.width,Ce.height),G&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,Ce.width,Ce.height,He,at,Ce.data)):t.texImage2D(n.TEXTURE_2D,0,st,Ce.width,Ce.height,0,He,at,Ce.data);else if(C.isCompressedTexture)if(C.isCompressedArrayTexture){lt&&Ct&&t.texStorage3D(n.TEXTURE_2D_ARRAY,Fe,st,mt[0].width,mt[0].height,Ce.depth);for(let ce=0,_e=mt.length;ce<_e;ce++)if(Ge=mt[ce],C.format!==Oi)if(He!==null)if(lt){if(G)if(C.layerUpdates.size>0){const Le=Q_(Ge.width,Ge.height,C.format,C.type);for(const je of C.layerUpdates){const gt=Ge.data.subarray(je*Le/Ge.data.BYTES_PER_ELEMENT,(je+1)*Le/Ge.data.BYTES_PER_ELEMENT);t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,je,Ge.width,Ge.height,1,He,gt,0,0)}C.clearLayerUpdates()}else t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,0,Ge.width,Ge.height,Ce.depth,He,Ge.data,0,0)}else t.compressedTexImage3D(n.TEXTURE_2D_ARRAY,ce,st,Ge.width,Ge.height,Ce.depth,0,Ge.data,0,0);else console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else lt?G&&t.texSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,0,Ge.width,Ge.height,Ce.depth,He,at,Ge.data):t.texImage3D(n.TEXTURE_2D_ARRAY,ce,st,Ge.width,Ge.height,Ce.depth,0,He,at,Ge.data)}else{lt&&Ct&&t.texStorage2D(n.TEXTURE_2D,Fe,st,mt[0].width,mt[0].height);for(let ce=0,_e=mt.length;ce<_e;ce++)Ge=mt[ce],C.format!==Oi?He!==null?lt?G&&t.compressedTexSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,Ge.data):t.compressedTexImage2D(n.TEXTURE_2D,ce,st,Ge.width,Ge.height,0,Ge.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,at,Ge.data):t.texImage2D(n.TEXTURE_2D,ce,st,Ge.width,Ge.height,0,He,at,Ge.data)}else if(C.isDataArrayTexture)if(lt){if(Ct&&t.texStorage3D(n.TEXTURE_2D_ARRAY,Fe,st,Ce.width,Ce.height,Ce.depth),G)if(C.layerUpdates.size>0){const ce=Q_(Ce.width,Ce.height,C.format,C.type);for(const _e of C.layerUpdates){const Le=Ce.data.subarray(_e*ce/Ce.data.BYTES_PER_ELEMENT,(_e+1)*ce/Ce.data.BYTES_PER_ELEMENT);t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,_e,Ce.width,Ce.height,1,He,at,Le)}C.clearLayerUpdates()}else t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,0,Ce.width,Ce.height,Ce.depth,He,at,Ce.data)}else t.texImage3D(n.TEXTURE_2D_ARRAY,0,st,Ce.width,Ce.height,Ce.depth,0,He,at,Ce.data);else if(C.isData3DTexture)lt?(Ct&&t.texStorage3D(n.TEXTURE_3D,Fe,st,Ce.width,Ce.height,Ce.depth),G&&t.texSubImage3D(n.TEXTURE_3D,0,0,0,0,Ce.width,Ce.height,Ce.depth,He,at,Ce.data)):t.texImage3D(n.TEXTURE_3D,0,st,Ce.width,Ce.height,Ce.depth,0,He,at,Ce.data);else if(C.isFramebufferTexture){if(Ct)if(lt)t.texStorage2D(n.TEXTURE_2D,Fe,st,Ce.width,Ce.height);else{let ce=Ce.width,_e=Ce.height;for(let Le=0;Le<Fe;Le++)t.texImage2D(n.TEXTURE_2D,Le,st,ce,_e,0,He,at,null),ce>>=1,_e>>=1}}else if(mt.length>0){if(lt&&Ct){const ce=it(mt[0]);t.texStorage2D(n.TEXTURE_2D,Fe,st,ce.width,ce.height)}for(let ce=0,_e=mt.length;ce<_e;ce++)Ge=mt[ce],lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,He,at,Ge):t.texImage2D(n.TEXTURE_2D,ce,st,He,at,Ge);C.generateMipmaps=!1}else if(lt){if(Ct){const ce=it(Ce);t.texStorage2D(n.TEXTURE_2D,Fe,st,ce.width,ce.height)}G&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,He,at,Ce)}else t.texImage2D(n.TEXTURE_2D,0,st,He,at,Ce);_(C)&&M(me),Ze.__version=pe.version,C.onUpdate&&C.onUpdate(C)}I.__version=C.version}function K(I,C,Q){if(C.image.length!==6)return;const me=le(I,C),Se=C.source;t.bindTexture(n.TEXTURE_CUBE_MAP,I.__webglTexture,n.TEXTURE0+Q);const pe=s.get(Se);if(Se.version!==pe.__version||me===!0){t.activeTexture(n.TEXTURE0+Q);const Ze=Nt.getPrimaries(Nt.workingColorSpace),ke=C.colorSpace===ir?null:Nt.getPrimaries(C.colorSpace),Be=C.colorSpace===ir||Ze===ke?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,C.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,C.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,C.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,Be);const vt=C.isCompressedTexture||C.image[0].isCompressedTexture,Ce=C.image[0]&&C.image[0].isDataTexture,He=[];for(let _e=0;_e<6;_e++)!vt&&!Ce?He[_e]=E(C.image[_e],!0,a.maxCubemapSize):He[_e]=Ce?C.image[_e].image:C.image[_e],He[_e]=Lt(C,He[_e]);const at=He[0],st=c.convert(C.format,C.colorSpace),Ge=c.convert(C.type),mt=L(C.internalFormat,st,Ge,C.colorSpace),lt=C.isVideoTexture!==!0,Ct=pe.__version===void 0||me===!0,G=Se.dataReady;let Fe=R(C,at);O(n.TEXTURE_CUBE_MAP,C);let ce;if(vt){lt&&Ct&&t.texStorage2D(n.TEXTURE_CUBE_MAP,Fe,mt,at.width,at.height);for(let _e=0;_e<6;_e++){ce=He[_e].mipmaps;for(let Le=0;Le<ce.length;Le++){const je=ce[Le];C.format!==Oi?st!==null?lt?G&&t.compressedTexSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le,0,0,je.width,je.height,st,je.data):t.compressedTexImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le,mt,je.width,je.height,0,je.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le,0,0,je.width,je.height,st,Ge,je.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le,mt,je.width,je.height,0,st,Ge,je.data)}}}else{if(ce=C.mipmaps,lt&&Ct){ce.length>0&&Fe++;const _e=it(He[0]);t.texStorage2D(n.TEXTURE_CUBE_MAP,Fe,mt,_e.width,_e.height)}for(let _e=0;_e<6;_e++)if(Ce){lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,0,0,He[_e].width,He[_e].height,st,Ge,He[_e].data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,mt,He[_e].width,He[_e].height,0,st,Ge,He[_e].data);for(let Le=0;Le<ce.length;Le++){const gt=ce[Le].image[_e].image;lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le+1,0,0,gt.width,gt.height,st,Ge,gt.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le+1,mt,gt.width,gt.height,0,st,Ge,gt.data)}}else{lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,0,0,st,Ge,He[_e]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,mt,st,Ge,He[_e]);for(let Le=0;Le<ce.length;Le++){const je=ce[Le];lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le+1,0,0,st,Ge,je.image[_e]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Le+1,mt,st,Ge,je.image[_e])}}}_(C)&&M(n.TEXTURE_CUBE_MAP),pe.__version=Se.version,C.onUpdate&&C.onUpdate(C)}I.__version=C.version}function fe(I,C,Q,me,Se,pe){const Ze=c.convert(Q.format,Q.colorSpace),ke=c.convert(Q.type),Be=L(Q.internalFormat,Ze,ke,Q.colorSpace);if(!s.get(C).__hasExternalTextures){const Ce=Math.max(1,C.width>>pe),He=Math.max(1,C.height>>pe);Se===n.TEXTURE_3D||Se===n.TEXTURE_2D_ARRAY?t.texImage3D(Se,pe,Be,Ce,He,C.depth,0,Ze,ke,null):t.texImage2D(Se,pe,Be,Ce,He,0,Ze,ke,null)}t.bindFramebuffer(n.FRAMEBUFFER,I),_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,me,Se,s.get(Q).__webglTexture,0,ft(C)):(Se===n.TEXTURE_2D||Se>=n.TEXTURE_CUBE_MAP_POSITIVE_X&&Se<=n.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&n.framebufferTexture2D(n.FRAMEBUFFER,me,Se,s.get(Q).__webglTexture,pe),t.bindFramebuffer(n.FRAMEBUFFER,null)}function Te(I,C,Q){if(n.bindRenderbuffer(n.RENDERBUFFER,I),C.depthBuffer){const me=C.depthTexture,Se=me&&me.isDepthTexture?me.type:null,pe=A(C.stencilBuffer,Se),Ze=C.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,ke=ft(C);_t(C)?d.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,ke,pe,C.width,C.height):Q?n.renderbufferStorageMultisample(n.RENDERBUFFER,ke,pe,C.width,C.height):n.renderbufferStorage(n.RENDERBUFFER,pe,C.width,C.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,Ze,n.RENDERBUFFER,I)}else{const me=C.textures;for(let Se=0;Se<me.length;Se++){const pe=me[Se],Ze=c.convert(pe.format,pe.colorSpace),ke=c.convert(pe.type),Be=L(pe.internalFormat,Ze,ke,pe.colorSpace),vt=ft(C);Q&&_t(C)===!1?n.renderbufferStorageMultisample(n.RENDERBUFFER,vt,Be,C.width,C.height):_t(C)?d.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,vt,Be,C.width,C.height):n.renderbufferStorage(n.RENDERBUFFER,Be,C.width,C.height)}}n.bindRenderbuffer(n.RENDERBUFFER,null)}function Ae(I,C){if(C&&C.isWebGLCubeRenderTarget)throw new Error("Depth Texture with cube render targets is not supported");if(t.bindFramebuffer(n.FRAMEBUFFER,I),!(C.depthTexture&&C.depthTexture.isDepthTexture))throw new Error("renderTarget.depthTexture must be an instance of THREE.DepthTexture");(!s.get(C.depthTexture).__webglTexture||C.depthTexture.image.width!==C.width||C.depthTexture.image.height!==C.height)&&(C.depthTexture.image.width=C.width,C.depthTexture.image.height=C.height,C.depthTexture.needsUpdate=!0),ae(C.depthTexture,0);const me=s.get(C.depthTexture).__webglTexture,Se=ft(C);if(C.depthTexture.format===Va)_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,me,0,Se):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,me,0);else if(C.depthTexture.format===Za)_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,me,0,Se):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,me,0);else throw new Error("Unknown depthTexture format")}function Ie(I){const C=s.get(I),Q=I.isWebGLCubeRenderTarget===!0;if(C.__boundDepthTexture!==I.depthTexture){const me=I.depthTexture;if(C.__depthDisposeCallback&&C.__depthDisposeCallback(),me){const Se=()=>{delete C.__boundDepthTexture,delete C.__depthDisposeCallback,me.removeEventListener("dispose",Se)};me.addEventListener("dispose",Se),C.__depthDisposeCallback=Se}C.__boundDepthTexture=me}if(I.depthTexture&&!C.__autoAllocateDepthBuffer){if(Q)throw new Error("target.depthTexture not supported in Cube render targets");Ae(C.__webglFramebuffer,I)}else if(Q){C.__webglDepthbuffer=[];for(let me=0;me<6;me++)if(t.bindFramebuffer(n.FRAMEBUFFER,C.__webglFramebuffer[me]),C.__webglDepthbuffer[me]===void 0)C.__webglDepthbuffer[me]=n.createRenderbuffer(),Te(C.__webglDepthbuffer[me],I,!1);else{const Se=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,pe=C.__webglDepthbuffer[me];n.bindRenderbuffer(n.RENDERBUFFER,pe),n.framebufferRenderbuffer(n.FRAMEBUFFER,Se,n.RENDERBUFFER,pe)}}else if(t.bindFramebuffer(n.FRAMEBUFFER,C.__webglFramebuffer),C.__webglDepthbuffer===void 0)C.__webglDepthbuffer=n.createRenderbuffer(),Te(C.__webglDepthbuffer,I,!1);else{const me=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Se=C.__webglDepthbuffer;n.bindRenderbuffer(n.RENDERBUFFER,Se),n.framebufferRenderbuffer(n.FRAMEBUFFER,me,n.RENDERBUFFER,Se)}t.bindFramebuffer(n.FRAMEBUFFER,null)}function Ue(I,C,Q){const me=s.get(I);C!==void 0&&fe(me.__webglFramebuffer,I,I.texture,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,0),Q!==void 0&&Ie(I)}function rt(I){const C=I.texture,Q=s.get(I),me=s.get(C);I.addEventListener("dispose",D);const Se=I.textures,pe=I.isWebGLCubeRenderTarget===!0,Ze=Se.length>1;if(Ze||(me.__webglTexture===void 0&&(me.__webglTexture=n.createTexture()),me.__version=C.version,u.memory.textures++),pe){Q.__webglFramebuffer=[];for(let ke=0;ke<6;ke++)if(C.mipmaps&&C.mipmaps.length>0){Q.__webglFramebuffer[ke]=[];for(let Be=0;Be<C.mipmaps.length;Be++)Q.__webglFramebuffer[ke][Be]=n.createFramebuffer()}else Q.__webglFramebuffer[ke]=n.createFramebuffer()}else{if(C.mipmaps&&C.mipmaps.length>0){Q.__webglFramebuffer=[];for(let ke=0;ke<C.mipmaps.length;ke++)Q.__webglFramebuffer[ke]=n.createFramebuffer()}else Q.__webglFramebuffer=n.createFramebuffer();if(Ze)for(let ke=0,Be=Se.length;ke<Be;ke++){const vt=s.get(Se[ke]);vt.__webglTexture===void 0&&(vt.__webglTexture=n.createTexture(),u.memory.textures++)}if(I.samples>0&&_t(I)===!1){Q.__webglMultisampledFramebuffer=n.createFramebuffer(),Q.__webglColorRenderbuffer=[],t.bindFramebuffer(n.FRAMEBUFFER,Q.__webglMultisampledFramebuffer);for(let ke=0;ke<Se.length;ke++){const Be=Se[ke];Q.__webglColorRenderbuffer[ke]=n.createRenderbuffer(),n.bindRenderbuffer(n.RENDERBUFFER,Q.__webglColorRenderbuffer[ke]);const vt=c.convert(Be.format,Be.colorSpace),Ce=c.convert(Be.type),He=L(Be.internalFormat,vt,Ce,Be.colorSpace,I.isXRRenderTarget===!0),at=ft(I);n.renderbufferStorageMultisample(n.RENDERBUFFER,at,He,I.width,I.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+ke,n.RENDERBUFFER,Q.__webglColorRenderbuffer[ke])}n.bindRenderbuffer(n.RENDERBUFFER,null),I.depthBuffer&&(Q.__webglDepthRenderbuffer=n.createRenderbuffer(),Te(Q.__webglDepthRenderbuffer,I,!0)),t.bindFramebuffer(n.FRAMEBUFFER,null)}}if(pe){t.bindTexture(n.TEXTURE_CUBE_MAP,me.__webglTexture),O(n.TEXTURE_CUBE_MAP,C);for(let ke=0;ke<6;ke++)if(C.mipmaps&&C.mipmaps.length>0)for(let Be=0;Be<C.mipmaps.length;Be++)fe(Q.__webglFramebuffer[ke][Be],I,C,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+ke,Be);else fe(Q.__webglFramebuffer[ke],I,C,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+ke,0);_(C)&&M(n.TEXTURE_CUBE_MAP),t.unbindTexture()}else if(Ze){for(let ke=0,Be=Se.length;ke<Be;ke++){const vt=Se[ke],Ce=s.get(vt);t.bindTexture(n.TEXTURE_2D,Ce.__webglTexture),O(n.TEXTURE_2D,vt),fe(Q.__webglFramebuffer,I,vt,n.COLOR_ATTACHMENT0+ke,n.TEXTURE_2D,0),_(vt)&&M(n.TEXTURE_2D)}t.unbindTexture()}else{let ke=n.TEXTURE_2D;if((I.isWebGL3DRenderTarget||I.isWebGLArrayRenderTarget)&&(ke=I.isWebGL3DRenderTarget?n.TEXTURE_3D:n.TEXTURE_2D_ARRAY),t.bindTexture(ke,me.__webglTexture),O(ke,C),C.mipmaps&&C.mipmaps.length>0)for(let Be=0;Be<C.mipmaps.length;Be++)fe(Q.__webglFramebuffer[Be],I,C,n.COLOR_ATTACHMENT0,ke,Be);else fe(Q.__webglFramebuffer,I,C,n.COLOR_ATTACHMENT0,ke,0);_(C)&&M(ke),t.unbindTexture()}I.depthBuffer&&Ie(I)}function yt(I){const C=I.textures;for(let Q=0,me=C.length;Q<me;Q++){const Se=C[Q];if(_(Se)){const pe=I.isWebGLCubeRenderTarget?n.TEXTURE_CUBE_MAP:n.TEXTURE_2D,Ze=s.get(Se).__webglTexture;t.bindTexture(pe,Ze),M(pe),t.unbindTexture()}}}const pt=[],B=[];function _n(I){if(I.samples>0){if(_t(I)===!1){const C=I.textures,Q=I.width,me=I.height;let Se=n.COLOR_BUFFER_BIT;const pe=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Ze=s.get(I),ke=C.length>1;if(ke)for(let Be=0;Be<C.length;Be++)t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.RENDERBUFFER,null),t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.TEXTURE_2D,null,0);t.bindFramebuffer(n.READ_FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ze.__webglFramebuffer);for(let Be=0;Be<C.length;Be++){if(I.resolveDepthBuffer&&(I.depthBuffer&&(Se|=n.DEPTH_BUFFER_BIT),I.stencilBuffer&&I.resolveStencilBuffer&&(Se|=n.STENCIL_BUFFER_BIT)),ke){n.framebufferRenderbuffer(n.READ_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.RENDERBUFFER,Ze.__webglColorRenderbuffer[Be]);const vt=s.get(C[Be]).__webglTexture;n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,vt,0)}n.blitFramebuffer(0,0,Q,me,0,0,Q,me,Se,n.NEAREST),f===!0&&(pt.length=0,B.length=0,pt.push(n.COLOR_ATTACHMENT0+Be),I.depthBuffer&&I.resolveDepthBuffer===!1&&(pt.push(pe),B.push(pe),n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,B)),n.invalidateFramebuffer(n.READ_FRAMEBUFFER,pt))}if(t.bindFramebuffer(n.READ_FRAMEBUFFER,null),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),ke)for(let Be=0;Be<C.length;Be++){t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.RENDERBUFFER,Ze.__webglColorRenderbuffer[Be]);const vt=s.get(C[Be]).__webglTexture;t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.TEXTURE_2D,vt,0)}t.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ze.__webglMultisampledFramebuffer)}else if(I.depthBuffer&&I.resolveDepthBuffer===!1&&f){const C=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT;n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,[C])}}}function ft(I){return Math.min(a.maxSamples,I.samples)}function _t(I){const C=s.get(I);return I.samples>0&&e.has("WEBGL_multisampled_render_to_texture")===!0&&C.__useRenderToTexture!==!1}function tt(I){const C=u.render.frame;g.get(I)!==C&&(g.set(I,C),I.update())}function Lt(I,C){const Q=I.colorSpace,me=I.format,Se=I.type;return I.isCompressedTexture===!0||I.isVideoTexture===!0||Q!==hr&&Q!==ir&&(Nt.getTransfer(Q)===Bt?(me!==Oi||Se!==ws)&&console.warn("THREE.WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):console.error("THREE.WebGLTextures: Unsupported texture color space:",Q)),C}function it(I){return typeof HTMLImageElement<"u"&&I instanceof HTMLImageElement?(p.width=I.naturalWidth||I.width,p.height=I.naturalHeight||I.height):typeof VideoFrame<"u"&&I instanceof VideoFrame?(p.width=I.displayWidth,p.height=I.displayHeight):(p.width=I.width,p.height=I.height),p}this.allocateTextureUnit=re,this.resetTextureUnits=P,this.setTexture2D=ae,this.setTexture2DArray=ve,this.setTexture3D=V,this.setTextureCube=de,this.rebindTextures=Ue,this.setupRenderTarget=rt,this.updateRenderTargetMipmap=yt,this.updateMultisampleRenderTarget=_n,this.setupDepthRenderbuffer=Ie,this.setupFrameBufferTexture=fe,this.useMultisampledRTT=_t}function JR(n,e){function t(s,a=ir){let c;const u=Nt.getTransfer(a);if(s===ws)return n.UNSIGNED_BYTE;if(s===Ip)return n.UNSIGNED_SHORT_4_4_4_4;if(s===Up)return n.UNSIGNED_SHORT_5_5_5_1;if(s===nx)return n.UNSIGNED_INT_5_9_9_9_REV;if(s===ex)return n.BYTE;if(s===tx)return n.SHORT;if(s===ol)return n.UNSIGNED_SHORT;if(s===Dp)return n.INT;if(s===Xr)return n.UNSIGNED_INT;if(s===xs)return n.FLOAT;if(s===hl)return n.HALF_FLOAT;if(s===ix)return n.ALPHA;if(s===sx)return n.RGB;if(s===Oi)return n.RGBA;if(s===rx)return n.LUMINANCE;if(s===ax)return n.LUMINANCE_ALPHA;if(s===Va)return n.DEPTH_COMPONENT;if(s===Za)return n.DEPTH_STENCIL;if(s===ox)return n.RED;if(s===Fp)return n.RED_INTEGER;if(s===lx)return n.RG;if(s===Op)return n.RG_INTEGER;if(s===jp)return n.RGBA_INTEGER;if(s===tu||s===nu||s===iu||s===su)if(u===Bt)if(c=e.get("WEBGL_compressed_texture_s3tc_srgb"),c!==null){if(s===tu)return c.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(s===nu)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(s===iu)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(s===su)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(c=e.get("WEBGL_compressed_texture_s3tc"),c!==null){if(s===tu)return c.COMPRESSED_RGB_S3TC_DXT1_EXT;if(s===nu)return c.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(s===iu)return c.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(s===su)return c.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(s===Df||s===If||s===Uf||s===Ff)if(c=e.get("WEBGL_compressed_texture_pvrtc"),c!==null){if(s===Df)return c.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(s===If)return c.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(s===Uf)return c.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(s===Ff)return c.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(s===Of||s===jf||s===zf)if(c=e.get("WEBGL_compressed_texture_etc"),c!==null){if(s===Of||s===jf)return u===Bt?c.COMPRESSED_SRGB8_ETC2:c.COMPRESSED_RGB8_ETC2;if(s===zf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:c.COMPRESSED_RGBA8_ETC2_EAC}else return null;if(s===Bf||s===Hf||s===Vf||s===Gf||s===Wf||s===$f||s===Xf||s===qf||s===Yf||s===Kf||s===Zf||s===Qf||s===Jf||s===ep)if(c=e.get("WEBGL_compressed_texture_astc"),c!==null){if(s===Bf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:c.COMPRESSED_RGBA_ASTC_4x4_KHR;if(s===Hf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:c.COMPRESSED_RGBA_ASTC_5x4_KHR;if(s===Vf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:c.COMPRESSED_RGBA_ASTC_5x5_KHR;if(s===Gf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:c.COMPRESSED_RGBA_ASTC_6x5_KHR;if(s===Wf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:c.COMPRESSED_RGBA_ASTC_6x6_KHR;if(s===$f)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:c.COMPRESSED_RGBA_ASTC_8x5_KHR;if(s===Xf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:c.COMPRESSED_RGBA_ASTC_8x6_KHR;if(s===qf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:c.COMPRESSED_RGBA_ASTC_8x8_KHR;if(s===Yf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:c.COMPRESSED_RGBA_ASTC_10x5_KHR;if(s===Kf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:c.COMPRESSED_RGBA_ASTC_10x6_KHR;if(s===Zf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:c.COMPRESSED_RGBA_ASTC_10x8_KHR;if(s===Qf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:c.COMPRESSED_RGBA_ASTC_10x10_KHR;if(s===Jf)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:c.COMPRESSED_RGBA_ASTC_12x10_KHR;if(s===ep)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:c.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(s===ru||s===tp||s===np)if(c=e.get("EXT_texture_compression_bptc"),c!==null){if(s===ru)return u===Bt?c.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:c.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(s===tp)return c.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(s===np)return c.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(s===cx||s===ip||s===sp||s===rp)if(c=e.get("EXT_texture_compression_rgtc"),c!==null){if(s===ru)return c.COMPRESSED_RED_RGTC1_EXT;if(s===ip)return c.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(s===sp)return c.COMPRESSED_RED_GREEN_RGTC2_EXT;if(s===rp)return c.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return s===Ka?n.UNSIGNED_INT_24_8:n[s]!==void 0?n[s]:null}return{convert:t}}class e3 extends xi{constructor(e=[]){super(),this.isArrayCamera=!0,this.cameras=e}}class Br extends oi{constructor(){super(),this.isGroup=!0,this.type="Group"}}const t3={type:"move"};class af{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new Br,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new Br,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new se,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new se),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new Br,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new se,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new se),this._grip}dispatchEvent(e){return this._targetRay!==null&&this._targetRay.dispatchEvent(e),this._grip!==null&&this._grip.dispatchEvent(e),this._hand!==null&&this._hand.dispatchEvent(e),this}connect(e){if(e&&e.hand){const t=this._hand;if(t)for(const s of e.hand.values())this._getHandJoint(t,s)}return this.dispatchEvent({type:"connected",data:e}),this}disconnect(e){return this.dispatchEvent({type:"disconnected",data:e}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(e,t,s){let a=null,c=null,u=null;const d=this._targetRay,f=this._grip,p=this._hand;if(e&&t.session.visibilityState!=="visible-blurred"){if(p&&e.hand){u=!0;for(const E of e.hand.values()){const _=t.getJointPose(E,s),M=this._getHandJoint(p,E);_!==null&&(M.matrix.fromArray(_.transform.matrix),M.matrix.decompose(M.position,M.rotation,M.scale),M.matrixWorldNeedsUpdate=!0,M.jointRadius=_.radius),M.visible=_!==null}const g=p.joints["index-finger-tip"],v=p.joints["thumb-tip"],x=g.position.distanceTo(v.position),y=.02,w=.005;p.inputState.pinching&&x>y+w?(p.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:e.handedness,target:this})):!p.inputState.pinching&&x<=y-w&&(p.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:e.handedness,target:this}))}else f!==null&&e.gripSpace&&(c=t.getPose(e.gripSpace,s),c!==null&&(f.matrix.fromArray(c.transform.matrix),f.matrix.decompose(f.position,f.rotation,f.scale),f.matrixWorldNeedsUpdate=!0,c.linearVelocity?(f.hasLinearVelocity=!0,f.linearVelocity.copy(c.linearVelocity)):f.hasLinearVelocity=!1,c.angularVelocity?(f.hasAngularVelocity=!0,f.angularVelocity.copy(c.angularVelocity)):f.hasAngularVelocity=!1));d!==null&&(a=t.getPose(e.targetRaySpace,s),a===null&&c!==null&&(a=c),a!==null&&(d.matrix.fromArray(a.transform.matrix),d.matrix.decompose(d.position,d.rotation,d.scale),d.matrixWorldNeedsUpdate=!0,a.linearVelocity?(d.hasLinearVelocity=!0,d.linearVelocity.copy(a.linearVelocity)):d.hasLinearVelocity=!1,a.angularVelocity?(d.hasAngularVelocity=!0,d.angularVelocity.copy(a.angularVelocity)):d.hasAngularVelocity=!1,this.dispatchEvent(t3)))}return d!==null&&(d.visible=a!==null),f!==null&&(f.visible=c!==null),p!==null&&(p.visible=u!==null),this}_getHandJoint(e,t){if(e.joints[t.jointName]===void 0){const s=new Br;s.matrixAutoUpdate=!1,s.visible=!1,e.joints[t.jointName]=s,e.add(s)}return e.joints[t.jointName]}}const n3=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,i3=`
uniform sampler2DArray depthColor;
uniform float depthWidth;
uniform float depthHeight;

void main() {

	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );

	if ( coord.x >= 1.0 ) {

		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;

	} else {

		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;

	}

}`;class s3{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(e,t,s){if(this.texture===null){const a=new Yn,c=e.properties.get(a);c.__webglTexture=t.texture,(t.depthNear!=s.depthNear||t.depthFar!=s.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=a}}getMesh(e){if(this.texture!==null&&this.mesh===null){const t=e.cameras[0].viewport,s=new bs({vertexShader:n3,fragmentShader:i3,uniforms:{depthColor:{value:this.texture},depthWidth:{value:t.z},depthHeight:{value:t.w}}});this.mesh=new ji(new _l(20,20),s)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}}class r3 extends ro{constructor(e,t){super();const s=this;let a=null,c=1,u=null,d="local-floor",f=1,p=null,g=null,v=null,x=null,y=null,w=null;const E=new s3,_=t.getContextAttributes();let M=null,L=null;const A=[],R=[],k=new At;let D=null;const U=new xi;U.layers.enable(1),U.viewport=new Qt;const $=new xi;$.layers.enable(2),$.viewport=new Qt;const te=[U,$],T=new e3;T.layers.enable(1),T.layers.enable(2);let P=null,re=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(K){let fe=A[K];return fe===void 0&&(fe=new af,A[K]=fe),fe.getTargetRaySpace()},this.getControllerGrip=function(K){let fe=A[K];return fe===void 0&&(fe=new af,A[K]=fe),fe.getGripSpace()},this.getHand=function(K){let fe=A[K];return fe===void 0&&(fe=new af,A[K]=fe),fe.getHandSpace()};function J(K){const fe=R.indexOf(K.inputSource);if(fe===-1)return;const Te=A[fe];Te!==void 0&&(Te.update(K.inputSource,K.frame,p||u),Te.dispatchEvent({type:K.type,data:K.inputSource}))}function ae(){a.removeEventListener("select",J),a.removeEventListener("selectstart",J),a.removeEventListener("selectend",J),a.removeEventListener("squeeze",J),a.removeEventListener("squeezestart",J),a.removeEventListener("squeezeend",J),a.removeEventListener("end",ae),a.removeEventListener("inputsourceschange",ve);for(let K=0;K<A.length;K++){const fe=R[K];fe!==null&&(R[K]=null,A[K].disconnect(fe))}P=null,re=null,E.reset(),e.setRenderTarget(M),y=null,x=null,v=null,a=null,L=null,we.stop(),s.isPresenting=!1,e.setPixelRatio(D),e.setSize(k.width,k.height,!1),s.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(K){c=K,s.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(K){d=K,s.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return p||u},this.setReferenceSpace=function(K){p=K},this.getBaseLayer=function(){return x!==null?x:y},this.getBinding=function(){return v},this.getFrame=function(){return w},this.getSession=function(){return a},this.setSession=async function(K){if(a=K,a!==null){if(M=e.getRenderTarget(),a.addEventListener("select",J),a.addEventListener("selectstart",J),a.addEventListener("selectend",J),a.addEventListener("squeeze",J),a.addEventListener("squeezestart",J),a.addEventListener("squeezeend",J),a.addEventListener("end",ae),a.addEventListener("inputsourceschange",ve),_.xrCompatible!==!0&&await t.makeXRCompatible(),D=e.getPixelRatio(),e.getSize(k),a.renderState.layers===void 0){const fe={antialias:_.antialias,alpha:!0,depth:_.depth,stencil:_.stencil,framebufferScaleFactor:c};y=new XRWebGLLayer(a,t,fe),a.updateRenderState({baseLayer:y}),e.setPixelRatio(1),e.setSize(y.framebufferWidth,y.framebufferHeight,!1),L=new qr(y.framebufferWidth,y.framebufferHeight,{format:Oi,type:ws,colorSpace:e.outputColorSpace,stencilBuffer:_.stencil})}else{let fe=null,Te=null,Ae=null;_.depth&&(Ae=_.stencil?t.DEPTH24_STENCIL8:t.DEPTH_COMPONENT24,fe=_.stencil?Za:Va,Te=_.stencil?Ka:Xr);const Ie={colorFormat:t.RGBA8,depthFormat:Ae,scaleFactor:c};v=new XRWebGLBinding(a,t),x=v.createProjectionLayer(Ie),a.updateRenderState({layers:[x]}),e.setPixelRatio(1),e.setSize(x.textureWidth,x.textureHeight,!1),L=new qr(x.textureWidth,x.textureHeight,{format:Oi,type:ws,depthTexture:new wx(x.textureWidth,x.textureHeight,Te,void 0,void 0,void 0,void 0,void 0,void 0,fe),stencilBuffer:_.stencil,colorSpace:e.outputColorSpace,samples:_.antialias?4:0,resolveDepthBuffer:x.ignoreDepthValues===!1})}L.isXRRenderTarget=!0,this.setFoveation(f),p=null,u=await a.requestReferenceSpace(d),we.setContext(a),we.start(),s.isPresenting=!0,s.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(a!==null)return a.environmentBlendMode},this.getDepthTexture=function(){return E.getDepthTexture()};function ve(K){for(let fe=0;fe<K.removed.length;fe++){const Te=K.removed[fe],Ae=R.indexOf(Te);Ae>=0&&(R[Ae]=null,A[Ae].disconnect(Te))}for(let fe=0;fe<K.added.length;fe++){const Te=K.added[fe];let Ae=R.indexOf(Te);if(Ae===-1){for(let Ue=0;Ue<A.length;Ue++)if(Ue>=R.length){R.push(Te),Ae=Ue;break}else if(R[Ue]===null){R[Ue]=Te,Ae=Ue;break}if(Ae===-1)break}const Ie=A[Ae];Ie&&Ie.connect(Te)}}const V=new se,de=new se;function z(K,fe,Te){V.setFromMatrixPosition(fe.matrixWorld),de.setFromMatrixPosition(Te.matrixWorld);const Ae=V.distanceTo(de),Ie=fe.projectionMatrix.elements,Ue=Te.projectionMatrix.elements,rt=Ie[14]/(Ie[10]-1),yt=Ie[14]/(Ie[10]+1),pt=(Ie[9]+1)/Ie[5],B=(Ie[9]-1)/Ie[5],_n=(Ie[8]-1)/Ie[0],ft=(Ue[8]+1)/Ue[0],_t=rt*_n,tt=rt*ft,Lt=Ae/(-_n+ft),it=Lt*-_n;if(fe.matrixWorld.decompose(K.position,K.quaternion,K.scale),K.translateX(it),K.translateZ(Lt),K.matrixWorld.compose(K.position,K.quaternion,K.scale),K.matrixWorldInverse.copy(K.matrixWorld).invert(),Ie[10]===-1)K.projectionMatrix.copy(fe.projectionMatrix),K.projectionMatrixInverse.copy(fe.projectionMatrixInverse);else{const I=rt+Lt,C=yt+Lt,Q=_t-it,me=tt+(Ae-it),Se=pt*yt/C*I,pe=B*yt/C*I;K.projectionMatrix.makePerspective(Q,me,Se,pe,I,C),K.projectionMatrixInverse.copy(K.projectionMatrix).invert()}}function ue(K,fe){fe===null?K.matrixWorld.copy(K.matrix):K.matrixWorld.multiplyMatrices(fe.matrixWorld,K.matrix),K.matrixWorldInverse.copy(K.matrixWorld).invert()}this.updateCamera=function(K){if(a===null)return;let fe=K.near,Te=K.far;E.texture!==null&&(E.depthNear>0&&(fe=E.depthNear),E.depthFar>0&&(Te=E.depthFar)),T.near=$.near=U.near=fe,T.far=$.far=U.far=Te,(P!==T.near||re!==T.far)&&(a.updateRenderState({depthNear:T.near,depthFar:T.far}),P=T.near,re=T.far);const Ae=K.parent,Ie=T.cameras;ue(T,Ae);for(let Ue=0;Ue<Ie.length;Ue++)ue(Ie[Ue],Ae);Ie.length===2?z(T,U,$):T.projectionMatrix.copy(U.projectionMatrix),oe(K,T,Ae)};function oe(K,fe,Te){Te===null?K.matrix.copy(fe.matrixWorld):(K.matrix.copy(Te.matrixWorld),K.matrix.invert(),K.matrix.multiply(fe.matrixWorld)),K.matrix.decompose(K.position,K.quaternion,K.scale),K.updateMatrixWorld(!0),K.projectionMatrix.copy(fe.projectionMatrix),K.projectionMatrixInverse.copy(fe.projectionMatrixInverse),K.isPerspectiveCamera&&(K.fov=ap*2*Math.atan(1/K.projectionMatrix.elements[5]),K.zoom=1)}this.getCamera=function(){return T},this.getFoveation=function(){if(!(x===null&&y===null))return f},this.setFoveation=function(K){f=K,x!==null&&(x.fixedFoveation=K),y!==null&&y.fixedFoveation!==void 0&&(y.fixedFoveation=K)},this.hasDepthSensing=function(){return E.texture!==null},this.getDepthSensingMesh=function(){return E.getMesh(T)};let O=null;function le(K,fe){if(g=fe.getViewerPose(p||u),w=fe,g!==null){const Te=g.views;y!==null&&(e.setRenderTargetFramebuffer(L,y.framebuffer),e.setRenderTarget(L));let Ae=!1;Te.length!==T.cameras.length&&(T.cameras.length=0,Ae=!0);for(let Ue=0;Ue<Te.length;Ue++){const rt=Te[Ue];let yt=null;if(y!==null)yt=y.getViewport(rt);else{const B=v.getViewSubImage(x,rt);yt=B.viewport,Ue===0&&(e.setRenderTargetTextures(L,B.colorTexture,x.ignoreDepthValues?void 0:B.depthStencilTexture),e.setRenderTarget(L))}let pt=te[Ue];pt===void 0&&(pt=new xi,pt.layers.enable(Ue),pt.viewport=new Qt,te[Ue]=pt),pt.matrix.fromArray(rt.transform.matrix),pt.matrix.decompose(pt.position,pt.quaternion,pt.scale),pt.projectionMatrix.fromArray(rt.projectionMatrix),pt.projectionMatrixInverse.copy(pt.projectionMatrix).invert(),pt.viewport.set(yt.x,yt.y,yt.width,yt.height),Ue===0&&(T.matrix.copy(pt.matrix),T.matrix.decompose(T.position,T.quaternion,T.scale)),Ae===!0&&T.cameras.push(pt)}const Ie=a.enabledFeatures;if(Ie&&Ie.includes("depth-sensing")){const Ue=v.getDepthInformation(Te[0]);Ue&&Ue.isValid&&Ue.texture&&E.init(e,Ue,a.renderState)}}for(let Te=0;Te<A.length;Te++){const Ae=R[Te],Ie=A[Te];Ae!==null&&Ie!==void 0&&Ie.update(Ae,fe,p||u)}O&&O(K,fe),fe.detectedPlanes&&s.dispatchEvent({type:"planesdetected",data:fe}),w=null}const we=new Mx;we.setAnimationLoop(le),this.setAnimationLoop=function(K){O=K},this.dispose=function(){}}}const kr=new Ts,a3=new nn;function o3(n,e){function t(_,M){_.matrixAutoUpdate===!0&&_.updateMatrix(),M.value.copy(_.matrix)}function s(_,M){M.color.getRGB(_.fogColor.value,vx(n)),M.isFog?(_.fogNear.value=M.near,_.fogFar.value=M.far):M.isFogExp2&&(_.fogDensity.value=M.density)}function a(_,M,L,A,R){M.isMeshBasicMaterial||M.isMeshLambertMaterial?c(_,M):M.isMeshToonMaterial?(c(_,M),v(_,M)):M.isMeshPhongMaterial?(c(_,M),g(_,M)):M.isMeshStandardMaterial?(c(_,M),x(_,M),M.isMeshPhysicalMaterial&&y(_,M,R)):M.isMeshMatcapMaterial?(c(_,M),w(_,M)):M.isMeshDepthMaterial?c(_,M):M.isMeshDistanceMaterial?(c(_,M),E(_,M)):M.isMeshNormalMaterial?c(_,M):M.isLineBasicMaterial?(u(_,M),M.isLineDashedMaterial&&d(_,M)):M.isPointsMaterial?f(_,M,L,A):M.isSpriteMaterial?p(_,M):M.isShadowMaterial?(_.color.value.copy(M.color),_.opacity.value=M.opacity):M.isShaderMaterial&&(M.uniformsNeedUpdate=!1)}function c(_,M){_.opacity.value=M.opacity,M.color&&_.diffuse.value.copy(M.color),M.emissive&&_.emissive.value.copy(M.emissive).multiplyScalar(M.emissiveIntensity),M.map&&(_.map.value=M.map,t(M.map,_.mapTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.bumpMap&&(_.bumpMap.value=M.bumpMap,t(M.bumpMap,_.bumpMapTransform),_.bumpScale.value=M.bumpScale,M.side===qn&&(_.bumpScale.value*=-1)),M.normalMap&&(_.normalMap.value=M.normalMap,t(M.normalMap,_.normalMapTransform),_.normalScale.value.copy(M.normalScale),M.side===qn&&_.normalScale.value.negate()),M.displacementMap&&(_.displacementMap.value=M.displacementMap,t(M.displacementMap,_.displacementMapTransform),_.displacementScale.value=M.displacementScale,_.displacementBias.value=M.displacementBias),M.emissiveMap&&(_.emissiveMap.value=M.emissiveMap,t(M.emissiveMap,_.emissiveMapTransform)),M.specularMap&&(_.specularMap.value=M.specularMap,t(M.specularMap,_.specularMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest);const L=e.get(M),A=L.envMap,R=L.envMapRotation;A&&(_.envMap.value=A,kr.copy(R),kr.x*=-1,kr.y*=-1,kr.z*=-1,A.isCubeTexture&&A.isRenderTargetTexture===!1&&(kr.y*=-1,kr.z*=-1),_.envMapRotation.value.setFromMatrix4(a3.makeRotationFromEuler(kr)),_.flipEnvMap.value=A.isCubeTexture&&A.isRenderTargetTexture===!1?-1:1,_.reflectivity.value=M.reflectivity,_.ior.value=M.ior,_.refractionRatio.value=M.refractionRatio),M.lightMap&&(_.lightMap.value=M.lightMap,_.lightMapIntensity.value=M.lightMapIntensity,t(M.lightMap,_.lightMapTransform)),M.aoMap&&(_.aoMap.value=M.aoMap,_.aoMapIntensity.value=M.aoMapIntensity,t(M.aoMap,_.aoMapTransform))}function u(_,M){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,M.map&&(_.map.value=M.map,t(M.map,_.mapTransform))}function d(_,M){_.dashSize.value=M.dashSize,_.totalSize.value=M.dashSize+M.gapSize,_.scale.value=M.scale}function f(_,M,L,A){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,_.size.value=M.size*L,_.scale.value=A*.5,M.map&&(_.map.value=M.map,t(M.map,_.uvTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest)}function p(_,M){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,_.rotation.value=M.rotation,M.map&&(_.map.value=M.map,t(M.map,_.mapTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest)}function g(_,M){_.specular.value.copy(M.specular),_.shininess.value=Math.max(M.shininess,1e-4)}function v(_,M){M.gradientMap&&(_.gradientMap.value=M.gradientMap)}function x(_,M){_.metalness.value=M.metalness,M.metalnessMap&&(_.metalnessMap.value=M.metalnessMap,t(M.metalnessMap,_.metalnessMapTransform)),_.roughness.value=M.roughness,M.roughnessMap&&(_.roughnessMap.value=M.roughnessMap,t(M.roughnessMap,_.roughnessMapTransform)),M.envMap&&(_.envMapIntensity.value=M.envMapIntensity)}function y(_,M,L){_.ior.value=M.ior,M.sheen>0&&(_.sheenColor.value.copy(M.sheenColor).multiplyScalar(M.sheen),_.sheenRoughness.value=M.sheenRoughness,M.sheenColorMap&&(_.sheenColorMap.value=M.sheenColorMap,t(M.sheenColorMap,_.sheenColorMapTransform)),M.sheenRoughnessMap&&(_.sheenRoughnessMap.value=M.sheenRoughnessMap,t(M.sheenRoughnessMap,_.sheenRoughnessMapTransform))),M.clearcoat>0&&(_.clearcoat.value=M.clearcoat,_.clearcoatRoughness.value=M.clearcoatRoughness,M.clearcoatMap&&(_.clearcoatMap.value=M.clearcoatMap,t(M.clearcoatMap,_.clearcoatMapTransform)),M.clearcoatRoughnessMap&&(_.clearcoatRoughnessMap.value=M.clearcoatRoughnessMap,t(M.clearcoatRoughnessMap,_.clearcoatRoughnessMapTransform)),M.clearcoatNormalMap&&(_.clearcoatNormalMap.value=M.clearcoatNormalMap,t(M.clearcoatNormalMap,_.clearcoatNormalMapTransform),_.clearcoatNormalScale.value.copy(M.clearcoatNormalScale),M.side===qn&&_.clearcoatNormalScale.value.negate())),M.dispersion>0&&(_.dispersion.value=M.dispersion),M.iridescence>0&&(_.iridescence.value=M.iridescence,_.iridescenceIOR.value=M.iridescenceIOR,_.iridescenceThicknessMinimum.value=M.iridescenceThicknessRange[0],_.iridescenceThicknessMaximum.value=M.iridescenceThicknessRange[1],M.iridescenceMap&&(_.iridescenceMap.value=M.iridescenceMap,t(M.iridescenceMap,_.iridescenceMapTransform)),M.iridescenceThicknessMap&&(_.iridescenceThicknessMap.value=M.iridescenceThicknessMap,t(M.iridescenceThicknessMap,_.iridescenceThicknessMapTransform))),M.transmission>0&&(_.transmission.value=M.transmission,_.transmissionSamplerMap.value=L.texture,_.transmissionSamplerSize.value.set(L.width,L.height),M.transmissionMap&&(_.transmissionMap.value=M.transmissionMap,t(M.transmissionMap,_.transmissionMapTransform)),_.thickness.value=M.thickness,M.thicknessMap&&(_.thicknessMap.value=M.thicknessMap,t(M.thicknessMap,_.thicknessMapTransform)),_.attenuationDistance.value=M.attenuationDistance,_.attenuationColor.value.copy(M.attenuationColor)),M.anisotropy>0&&(_.anisotropyVector.value.set(M.anisotropy*Math.cos(M.anisotropyRotation),M.anisotropy*Math.sin(M.anisotropyRotation)),M.anisotropyMap&&(_.anisotropyMap.value=M.anisotropyMap,t(M.anisotropyMap,_.anisotropyMapTransform))),_.specularIntensity.value=M.specularIntensity,_.specularColor.value.copy(M.specularColor),M.specularColorMap&&(_.specularColorMap.value=M.specularColorMap,t(M.specularColorMap,_.specularColorMapTransform)),M.specularIntensityMap&&(_.specularIntensityMap.value=M.specularIntensityMap,t(M.specularIntensityMap,_.specularIntensityMapTransform))}function w(_,M){M.matcap&&(_.matcap.value=M.matcap)}function E(_,M){const L=e.get(M).light;_.referencePosition.value.setFromMatrixPosition(L.matrixWorld),_.nearDistance.value=L.shadow.camera.near,_.farDistance.value=L.shadow.camera.far}return{refreshFogUniforms:s,refreshMaterialUniforms:a}}function l3(n,e,t,s){let a={},c={},u=[];const d=n.getParameter(n.MAX_UNIFORM_BUFFER_BINDINGS);function f(L,A){const R=A.program;s.uniformBlockBinding(L,R)}function p(L,A){let R=a[L.id];R===void 0&&(w(L),R=g(L),a[L.id]=R,L.addEventListener("dispose",_));const k=A.program;s.updateUBOMapping(L,k);const D=e.render.frame;c[L.id]!==D&&(x(L),c[L.id]=D)}function g(L){const A=v();L.__bindingPointIndex=A;const R=n.createBuffer(),k=L.__size,D=L.usage;return n.bindBuffer(n.UNIFORM_BUFFER,R),n.bufferData(n.UNIFORM_BUFFER,k,D),n.bindBuffer(n.UNIFORM_BUFFER,null),n.bindBufferBase(n.UNIFORM_BUFFER,A,R),R}function v(){for(let L=0;L<d;L++)if(u.indexOf(L)===-1)return u.push(L),L;return console.error("THREE.WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function x(L){const A=a[L.id],R=L.uniforms,k=L.__cache;n.bindBuffer(n.UNIFORM_BUFFER,A);for(let D=0,U=R.length;D<U;D++){const $=Array.isArray(R[D])?R[D]:[R[D]];for(let te=0,T=$.length;te<T;te++){const P=$[te];if(y(P,D,te,k)===!0){const re=P.__offset,J=Array.isArray(P.value)?P.value:[P.value];let ae=0;for(let ve=0;ve<J.length;ve++){const V=J[ve],de=E(V);typeof V=="number"||typeof V=="boolean"?(P.__data[0]=V,n.bufferSubData(n.UNIFORM_BUFFER,re+ae,P.__data)):V.isMatrix3?(P.__data[0]=V.elements[0],P.__data[1]=V.elements[1],P.__data[2]=V.elements[2],P.__data[3]=0,P.__data[4]=V.elements[3],P.__data[5]=V.elements[4],P.__data[6]=V.elements[5],P.__data[7]=0,P.__data[8]=V.elements[6],P.__data[9]=V.elements[7],P.__data[10]=V.elements[8],P.__data[11]=0):(V.toArray(P.__data,ae),ae+=de.storage/Float32Array.BYTES_PER_ELEMENT)}n.bufferSubData(n.UNIFORM_BUFFER,re,P.__data)}}}n.bindBuffer(n.UNIFORM_BUFFER,null)}function y(L,A,R,k){const D=L.value,U=A+"_"+R;if(k[U]===void 0)return typeof D=="number"||typeof D=="boolean"?k[U]=D:k[U]=D.clone(),!0;{const $=k[U];if(typeof D=="number"||typeof D=="boolean"){if($!==D)return k[U]=D,!0}else if($.equals(D)===!1)return $.copy(D),!0}return!1}function w(L){const A=L.uniforms;let R=0;const k=16;for(let U=0,$=A.length;U<$;U++){const te=Array.isArray(A[U])?A[U]:[A[U]];for(let T=0,P=te.length;T<P;T++){const re=te[T],J=Array.isArray(re.value)?re.value:[re.value];for(let ae=0,ve=J.length;ae<ve;ae++){const V=J[ae],de=E(V),z=R%k,ue=z%de.boundary,oe=z+ue;R+=ue,oe!==0&&k-oe<de.storage&&(R+=k-oe),re.__data=new Float32Array(de.storage/Float32Array.BYTES_PER_ELEMENT),re.__offset=R,R+=de.storage}}}const D=R%k;return D>0&&(R+=k-D),L.__size=R,L.__cache={},this}function E(L){const A={boundary:0,storage:0};return typeof L=="number"||typeof L=="boolean"?(A.boundary=4,A.storage=4):L.isVector2?(A.boundary=8,A.storage=8):L.isVector3||L.isColor?(A.boundary=16,A.storage=12):L.isVector4?(A.boundary=16,A.storage=16):L.isMatrix3?(A.boundary=48,A.storage=48):L.isMatrix4?(A.boundary=64,A.storage=64):L.isTexture?console.warn("THREE.WebGLRenderer: Texture samplers can not be part of an uniforms group."):console.warn("THREE.WebGLRenderer: Unsupported uniform value type.",L),A}function _(L){const A=L.target;A.removeEventListener("dispose",_);const R=u.indexOf(A.__bindingPointIndex);u.splice(R,1),n.deleteBuffer(a[A.id]),delete a[A.id],delete c[A.id]}function M(){for(const L in a)n.deleteBuffer(a[L]);u=[],a={},c={}}return{bind:f,update:p,dispose:M}}class c3{constructor(e={}){const{canvas:t=YT(),context:s=null,depth:a=!0,stencil:c=!1,alpha:u=!1,antialias:d=!1,premultipliedAlpha:f=!0,preserveDrawingBuffer:p=!1,powerPreference:g="default",failIfMajorPerformanceCaveat:v=!1}=e;this.isWebGLRenderer=!0;let x;if(s!==null){if(typeof WebGLRenderingContext<"u"&&s instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");x=s.getContextAttributes().alpha}else x=u;const y=new Uint32Array(4),w=new Int32Array(4);let E=null,_=null;const M=[],L=[];this.domElement=t,this.debug={checkShaderErrors:!0,onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this._outputColorSpace=$i,this.toneMapping=or,this.toneMappingExposure=1;const A=this;let R=!1,k=0,D=0,U=null,$=-1,te=null;const T=new Qt,P=new Qt;let re=null;const J=new Pt(0);let ae=0,ve=t.width,V=t.height,de=1,z=null,ue=null;const oe=new Qt(0,0,ve,V),O=new Qt(0,0,ve,V);let le=!1;const we=new Sx;let K=!1,fe=!1;const Te=new nn,Ae=new nn,Ie=new se,Ue=new Qt,rt={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0};let yt=!1;function pt(){return U===null?de:1}let B=s;function _n(N,W){return t.getContext(N,W)}try{const N={alpha:!0,depth:a,stencil:c,antialias:d,premultipliedAlpha:f,preserveDrawingBuffer:p,powerPreference:g,failIfMajorPerformanceCaveat:v};if("setAttribute"in t&&t.setAttribute("data-engine",`three.js r${Lp}`),t.addEventListener("webglcontextlost",_e,!1),t.addEventListener("webglcontextrestored",Le,!1),t.addEventListener("webglcontextcreationerror",je,!1),B===null){const W="webgl2";if(B=_n(W,N),B===null)throw _n(W)?new Error("Error creating WebGL context with your selected attributes."):new Error("Error creating WebGL context.")}}catch(N){throw console.error("THREE.WebGLRenderer: "+N.message),N}let ft,_t,tt,Lt,it,I,C,Q,me,Se,pe,Ze,ke,Be,vt,Ce,He,at,st,Ge,mt,lt,Ct,G;function Fe(){ft=new pN(B),ft.init(),lt=new JR(B,ft),_t=new lN(B,ft,e,lt),tt=new KR(B),_t.reverseDepthBuffer&&tt.buffers.depth.setReversed(!0),Lt=new _N(B),it=new IR,I=new QR(B,ft,tt,it,_t,lt,Lt),C=new uN(A),Q=new fN(A),me=new wb(B),Ct=new aN(B,me),Se=new mN(B,me,Lt,Ct),pe=new xN(B,Se,me,Lt),st=new vN(B,_t,I),Ce=new cN(it),Ze=new DR(A,C,Q,ft,_t,Ct,Ce),ke=new o3(A,it),Be=new FR,vt=new VR(ft),at=new rN(A,C,Q,tt,pe,x,f),He=new qR(A,pe,_t),G=new l3(B,Lt,_t,tt),Ge=new oN(B,ft,Lt),mt=new gN(B,ft,Lt),Lt.programs=Ze.programs,A.capabilities=_t,A.extensions=ft,A.properties=it,A.renderLists=Be,A.shadowMap=He,A.state=tt,A.info=Lt}Fe();const ce=new r3(A,B);this.xr=ce,this.getContext=function(){return B},this.getContextAttributes=function(){return B.getContextAttributes()},this.forceContextLoss=function(){const N=ft.get("WEBGL_lose_context");N&&N.loseContext()},this.forceContextRestore=function(){const N=ft.get("WEBGL_lose_context");N&&N.restoreContext()},this.getPixelRatio=function(){return de},this.setPixelRatio=function(N){N!==void 0&&(de=N,this.setSize(ve,V,!1))},this.getSize=function(N){return N.set(ve,V)},this.setSize=function(N,W,ee=!0){if(ce.isPresenting){console.warn("THREE.WebGLRenderer: Can't change size while VR device is presenting.");return}ve=N,V=W,t.width=Math.floor(N*de),t.height=Math.floor(W*de),ee===!0&&(t.style.width=N+"px",t.style.height=W+"px"),this.setViewport(0,0,N,W)},this.getDrawingBufferSize=function(N){return N.set(ve*de,V*de).floor()},this.setDrawingBufferSize=function(N,W,ee){ve=N,V=W,de=ee,t.width=Math.floor(N*ee),t.height=Math.floor(W*ee),this.setViewport(0,0,N,W)},this.getCurrentViewport=function(N){return N.copy(T)},this.getViewport=function(N){return N.copy(oe)},this.setViewport=function(N,W,ee,ne){N.isVector4?oe.set(N.x,N.y,N.z,N.w):oe.set(N,W,ee,ne),tt.viewport(T.copy(oe).multiplyScalar(de).round())},this.getScissor=function(N){return N.copy(O)},this.setScissor=function(N,W,ee,ne){N.isVector4?O.set(N.x,N.y,N.z,N.w):O.set(N,W,ee,ne),tt.scissor(P.copy(O).multiplyScalar(de).round())},this.getScissorTest=function(){return le},this.setScissorTest=function(N){tt.setScissorTest(le=N)},this.setOpaqueSort=function(N){z=N},this.setTransparentSort=function(N){ue=N},this.getClearColor=function(N){return N.copy(at.getClearColor())},this.setClearColor=function(){at.setClearColor.apply(at,arguments)},this.getClearAlpha=function(){return at.getClearAlpha()},this.setClearAlpha=function(){at.setClearAlpha.apply(at,arguments)},this.clear=function(N=!0,W=!0,ee=!0){let ne=0;if(N){let X=!1;if(U!==null){const Re=U.texture.format;X=Re===jp||Re===Op||Re===Fp}if(X){const Re=U.texture.type,Oe=Re===ws||Re===Xr||Re===ol||Re===Ka||Re===Ip||Re===Up,Pe=at.getClearColor(),qe=at.getClearAlpha(),et=Pe.r,nt=Pe.g,Ye=Pe.b;Oe?(y[0]=et,y[1]=nt,y[2]=Ye,y[3]=qe,B.clearBufferuiv(B.COLOR,0,y)):(w[0]=et,w[1]=nt,w[2]=Ye,w[3]=qe,B.clearBufferiv(B.COLOR,0,w))}else ne|=B.COLOR_BUFFER_BIT}W&&(ne|=B.DEPTH_BUFFER_BIT,B.clearDepth(this.capabilities.reverseDepthBuffer?0:1)),ee&&(ne|=B.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),B.clear(ne)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.dispose=function(){t.removeEventListener("webglcontextlost",_e,!1),t.removeEventListener("webglcontextrestored",Le,!1),t.removeEventListener("webglcontextcreationerror",je,!1),Be.dispose(),vt.dispose(),it.dispose(),C.dispose(),Q.dispose(),pe.dispose(),Ct.dispose(),G.dispose(),Ze.dispose(),ce.dispose(),ce.removeEventListener("sessionstart",Cs),ce.removeEventListener("sessionend",Zr),Zn.stop()};function _e(N){N.preventDefault(),console.log("THREE.WebGLRenderer: Context Lost."),R=!0}function Le(){console.log("THREE.WebGLRenderer: Context Restored."),R=!1;const N=Lt.autoReset,W=He.enabled,ee=He.autoUpdate,ne=He.needsUpdate,X=He.type;Fe(),Lt.autoReset=N,He.enabled=W,He.autoUpdate=ee,He.needsUpdate=ne,He.type=X}function je(N){console.error("THREE.WebGLRenderer: A WebGL context could not be created. Reason: ",N.statusMessage)}function gt(N){const W=N.target;W.removeEventListener("dispose",gt),$t(W)}function $t(N){vn(N),it.remove(N)}function vn(N){const W=it.get(N).programs;W!==void 0&&(W.forEach(function(ee){Ze.releaseProgram(ee)}),N.isShaderMaterial&&Ze.releaseShaderCache(N))}this.renderBufferDirect=function(N,W,ee,ne,X,Re){W===null&&(W=rt);const Oe=X.isMesh&&X.matrixWorld.determinant()<0,Pe=ts(N,W,ee,ne,X);tt.setMaterial(ne,Oe);let qe=ee.index,et=1;if(ne.wireframe===!0){if(qe=Se.getWireframeAttribute(ee),qe===void 0)return;et=2}const nt=ee.drawRange,Ye=ee.attributes.position;let bt=nt.start*et,Dt=(nt.start+nt.count)*et;Re!==null&&(bt=Math.max(bt,Re.start*et),Dt=Math.min(Dt,(Re.start+Re.count)*et)),qe!==null?(bt=Math.max(bt,0),Dt=Math.min(Dt,qe.count)):Ye!=null&&(bt=Math.max(bt,0),Dt=Math.min(Dt,Ye.count));const It=Dt-bt;if(It<0||It===1/0)return;Ct.setup(X,ne,Pe,ee,qe);let Vt,Mt=Ge;if(qe!==null&&(Vt=me.get(qe),Mt=mt,Mt.setIndex(Vt)),X.isMesh)ne.wireframe===!0?(tt.setLineWidth(ne.wireframeLinewidth*pt()),Mt.setMode(B.LINES)):Mt.setMode(B.TRIANGLES);else if(X.isLine){let Ve=ne.linewidth;Ve===void 0&&(Ve=1),tt.setLineWidth(Ve*pt()),X.isLineSegments?Mt.setMode(B.LINES):X.isLineLoop?Mt.setMode(B.LINE_LOOP):Mt.setMode(B.LINE_STRIP)}else X.isPoints?Mt.setMode(B.POINTS):X.isSprite&&Mt.setMode(B.TRIANGLES);if(X.isBatchedMesh)if(X._multiDrawInstances!==null)Mt.renderMultiDrawInstances(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount,X._multiDrawInstances);else if(ft.get("WEBGL_multi_draw"))Mt.renderMultiDraw(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount);else{const Ve=X._multiDrawStarts,sn=X._multiDrawCounts,Et=X._multiDrawCount,Qn=qe?me.get(qe).bytesPerElement:1,wi=it.get(ne).currentProgram.getUniforms();for(let hn=0;hn<Et;hn++)wi.setValue(B,"_gl_DrawID",hn),Mt.render(Ve[hn]/Qn,sn[hn])}else if(X.isInstancedMesh)Mt.renderInstances(bt,It,X.count);else if(ee.isInstancedBufferGeometry){const Ve=ee._maxInstanceCount!==void 0?ee._maxInstanceCount:1/0,sn=Math.min(ee.instanceCount,Ve);Mt.renderInstances(bt,It,sn)}else Mt.render(bt,It)};function xt(N,W,ee){N.transparent===!0&&N.side===Yi&&N.forceSinglePass===!1?(N.side=qn,N.needsUpdate=!0,Jr(N,W,ee),N.side=ur,N.needsUpdate=!0,Jr(N,W,ee),N.side=Yi):Jr(N,W,ee)}this.compile=function(N,W,ee=null){ee===null&&(ee=N),_=vt.get(ee),_.init(W),L.push(_),ee.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(_.pushLight(X),X.castShadow&&_.pushShadow(X))}),N!==ee&&N.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(_.pushLight(X),X.castShadow&&_.pushShadow(X))}),_.setupLights();const ne=new Set;return N.traverse(function(X){if(!(X.isMesh||X.isPoints||X.isLine||X.isSprite))return;const Re=X.material;if(Re)if(Array.isArray(Re))for(let Oe=0;Oe<Re.length;Oe++){const Pe=Re[Oe];xt(Pe,ee,X),ne.add(Pe)}else xt(Re,ee,X),ne.add(Re)}),L.pop(),_=null,ne},this.compileAsync=function(N,W,ee=null){const ne=this.compile(N,W,ee);return new Promise(X=>{function Re(){if(ne.forEach(function(Oe){it.get(Oe).currentProgram.isReady()&&ne.delete(Oe)}),ne.size===0){X(N);return}setTimeout(Re,10)}ft.get("KHR_parallel_shader_compile")!==null?Re():setTimeout(Re,10)})};let dn=null;function ci(N){dn&&dn(N)}function Cs(){Zn.stop()}function Zr(){Zn.start()}const Zn=new Mx;Zn.setAnimationLoop(ci),typeof self<"u"&&Zn.setContext(self),this.setAnimationLoop=function(N){dn=N,ce.setAnimationLoop(N),N===null?Zn.stop():Zn.start()},ce.addEventListener("sessionstart",Cs),ce.addEventListener("sessionend",Zr),this.render=function(N,W){if(W!==void 0&&W.isCamera!==!0){console.error("THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(R===!0)return;if(N.matrixWorldAutoUpdate===!0&&N.updateMatrixWorld(),W.parent===null&&W.matrixWorldAutoUpdate===!0&&W.updateMatrixWorld(),ce.enabled===!0&&ce.isPresenting===!0&&(ce.cameraAutoUpdate===!0&&ce.updateCamera(W),W=ce.getCamera()),N.isScene===!0&&N.onBeforeRender(A,N,W,U),_=vt.get(N,L.length),_.init(W),L.push(_),Ae.multiplyMatrices(W.projectionMatrix,W.matrixWorldInverse),we.setFromProjectionMatrix(Ae),fe=this.localClippingEnabled,K=Ce.init(this.clippingPlanes,fe),E=Be.get(N,M.length),E.init(),M.push(E),ce.enabled===!0&&ce.isPresenting===!0){const Re=A.xr.getDepthSensingMesh();Re!==null&&oo(Re,W,-1/0,A.sortObjects)}oo(N,W,0,A.sortObjects),E.finish(),A.sortObjects===!0&&E.sort(z,ue),yt=ce.enabled===!1||ce.isPresenting===!1||ce.hasDepthSensing()===!1,yt&&at.addToRenderList(E,N),this.info.render.frame++,K===!0&&Ce.beginShadows();const ee=_.state.shadowsArray;He.render(ee,N,W),K===!0&&Ce.endShadows(),this.info.autoReset===!0&&this.info.reset();const ne=E.opaque,X=E.transmissive;if(_.setupLights(),W.isArrayCamera){const Re=W.cameras;if(X.length>0)for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++){const qe=Re[Oe];fr(ne,X,N,qe)}yt&&at.render(N);for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++){const qe=Re[Oe];Ns(E,N,qe,qe.viewport)}}else X.length>0&&fr(ne,X,N,W),yt&&at.render(N),Ns(E,N,W);U!==null&&(I.updateMultisampleRenderTarget(U),I.updateRenderTargetMipmap(U)),N.isScene===!0&&N.onAfterRender(A,N,W),Ct.resetDefaultState(),$=-1,te=null,L.pop(),L.length>0?(_=L[L.length-1],K===!0&&Ce.setGlobalState(A.clippingPlanes,_.state.camera)):_=null,M.pop(),M.length>0?E=M[M.length-1]:E=null};function oo(N,W,ee,ne){if(N.visible===!1)return;if(N.layers.test(W.layers)){if(N.isGroup)ee=N.renderOrder;else if(N.isLOD)N.autoUpdate===!0&&N.update(W);else if(N.isLight)_.pushLight(N),N.castShadow&&_.pushShadow(N);else if(N.isSprite){if(!N.frustumCulled||we.intersectsSprite(N)){ne&&Ue.setFromMatrixPosition(N.matrixWorld).applyMatrix4(Ae);const Oe=pe.update(N),Pe=N.material;Pe.visible&&E.push(N,Oe,Pe,ee,Ue.z,null)}}else if((N.isMesh||N.isLine||N.isPoints)&&(!N.frustumCulled||we.intersectsObject(N))){const Oe=pe.update(N),Pe=N.material;if(ne&&(N.boundingSphere!==void 0?(N.boundingSphere===null&&N.computeBoundingSphere(),Ue.copy(N.boundingSphere.center)):(Oe.boundingSphere===null&&Oe.computeBoundingSphere(),Ue.copy(Oe.boundingSphere.center)),Ue.applyMatrix4(N.matrixWorld).applyMatrix4(Ae)),Array.isArray(Pe)){const qe=Oe.groups;for(let et=0,nt=qe.length;et<nt;et++){const Ye=qe[et],bt=Pe[Ye.materialIndex];bt&&bt.visible&&E.push(N,Oe,bt,ee,Ue.z,Ye)}}else Pe.visible&&E.push(N,Oe,Pe,ee,Ue.z,null)}}const Re=N.children;for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++)oo(Re[Oe],W,ee,ne)}function Ns(N,W,ee,ne){const X=N.opaque,Re=N.transmissive,Oe=N.transparent;_.setupLightsView(ee),K===!0&&Ce.setGlobalState(A.clippingPlanes,ee),ne&&tt.viewport(T.copy(ne)),X.length>0&&es(X,W,ee),Re.length>0&&es(Re,W,ee),Oe.length>0&&es(Oe,W,ee),tt.buffers.depth.setTest(!0),tt.buffers.depth.setMask(!0),tt.buffers.color.setMask(!0),tt.setPolygonOffset(!1)}function fr(N,W,ee,ne){if((ee.isScene===!0?ee.overrideMaterial:null)!==null)return;_.state.transmissionRenderTarget[ne.id]===void 0&&(_.state.transmissionRenderTarget[ne.id]=new qr(1,1,{generateMipmaps:!0,type:ft.has("EXT_color_buffer_half_float")||ft.has("EXT_color_buffer_float")?hl:ws,minFilter:zr,samples:4,stencilBuffer:c,resolveDepthBuffer:!1,resolveStencilBuffer:!1,colorSpace:Nt.workingColorSpace}));const Re=_.state.transmissionRenderTarget[ne.id],Oe=ne.viewport||T;Re.setSize(Oe.z,Oe.w);const Pe=A.getRenderTarget();A.setRenderTarget(Re),A.getClearColor(J),ae=A.getClearAlpha(),ae<1&&A.setClearColor(16777215,.5),A.clear(),yt&&at.render(ee);const qe=A.toneMapping;A.toneMapping=or;const et=ne.viewport;if(ne.viewport!==void 0&&(ne.viewport=void 0),_.setupLightsView(ne),K===!0&&Ce.setGlobalState(A.clippingPlanes,ne),es(N,ee,ne),I.updateMultisampleRenderTarget(Re),I.updateRenderTargetMipmap(Re),ft.has("WEBGL_multisampled_render_to_texture")===!1){let nt=!1;for(let Ye=0,bt=W.length;Ye<bt;Ye++){const Dt=W[Ye],It=Dt.object,Vt=Dt.geometry,Mt=Dt.material,Ve=Dt.group;if(Mt.side===Yi&&It.layers.test(ne.layers)){const sn=Mt.side;Mt.side=qn,Mt.needsUpdate=!0,Qr(It,ee,ne,Vt,Mt,Ve),Mt.side=sn,Mt.needsUpdate=!0,nt=!0}}nt===!0&&(I.updateMultisampleRenderTarget(Re),I.updateRenderTargetMipmap(Re))}A.setRenderTarget(Pe),A.setClearColor(J,ae),et!==void 0&&(ne.viewport=et),A.toneMapping=qe}function es(N,W,ee){const ne=W.isScene===!0?W.overrideMaterial:null;for(let X=0,Re=N.length;X<Re;X++){const Oe=N[X],Pe=Oe.object,qe=Oe.geometry,et=ne===null?Oe.material:ne,nt=Oe.group;Pe.layers.test(ee.layers)&&Qr(Pe,W,ee,qe,et,nt)}}function Qr(N,W,ee,ne,X,Re){N.onBeforeRender(A,W,ee,ne,X,Re),N.modelViewMatrix.multiplyMatrices(ee.matrixWorldInverse,N.matrixWorld),N.normalMatrix.getNormalMatrix(N.modelViewMatrix),X.onBeforeRender(A,W,ee,ne,N,Re),X.transparent===!0&&X.side===Yi&&X.forceSinglePass===!1?(X.side=qn,X.needsUpdate=!0,A.renderBufferDirect(ee,W,ne,X,N,Re),X.side=ur,X.needsUpdate=!0,A.renderBufferDirect(ee,W,ne,X,N,Re),X.side=Yi):A.renderBufferDirect(ee,W,ne,X,N,Re),N.onAfterRender(A,W,ee,ne,X,Re)}function Jr(N,W,ee){W.isScene!==!0&&(W=rt);const ne=it.get(N),X=_.state.lights,Re=_.state.shadowsArray,Oe=X.state.version,Pe=Ze.getParameters(N,X.state,Re,W,ee),qe=Ze.getProgramCacheKey(Pe);let et=ne.programs;ne.environment=N.isMeshStandardMaterial?W.environment:null,ne.fog=W.fog,ne.envMap=(N.isMeshStandardMaterial?Q:C).get(N.envMap||ne.environment),ne.envMapRotation=ne.environment!==null&&N.envMap===null?W.environmentRotation:N.envMapRotation,et===void 0&&(N.addEventListener("dispose",gt),et=new Map,ne.programs=et);let nt=et.get(qe);if(nt!==void 0){if(ne.currentProgram===nt&&ne.lightsStateVersion===Oe)return yl(N,Pe),nt}else Pe.uniforms=Ze.getUniforms(N),N.onBeforeCompile(Pe,A),nt=Ze.acquireProgram(Pe,qe),et.set(qe,nt),ne.uniforms=Pe.uniforms;const Ye=ne.uniforms;return(!N.isShaderMaterial&&!N.isRawShaderMaterial||N.clipping===!0)&&(Ye.clippingPlanes=Ce.uniform),yl(N,Pe),ne.needsLights=Ml(N),ne.lightsStateVersion=Oe,ne.needsLights&&(Ye.ambientLightColor.value=X.state.ambient,Ye.lightProbe.value=X.state.probe,Ye.directionalLights.value=X.state.directional,Ye.directionalLightShadows.value=X.state.directionalShadow,Ye.spotLights.value=X.state.spot,Ye.spotLightShadows.value=X.state.spotShadow,Ye.rectAreaLights.value=X.state.rectArea,Ye.ltc_1.value=X.state.rectAreaLTC1,Ye.ltc_2.value=X.state.rectAreaLTC2,Ye.pointLights.value=X.state.point,Ye.pointLightShadows.value=X.state.pointShadow,Ye.hemisphereLights.value=X.state.hemi,Ye.directionalShadowMap.value=X.state.directionalShadowMap,Ye.directionalShadowMatrix.value=X.state.directionalShadowMatrix,Ye.spotShadowMap.value=X.state.spotShadowMap,Ye.spotLightMatrix.value=X.state.spotLightMatrix,Ye.spotLightMap.value=X.state.spotLightMap,Ye.pointShadowMap.value=X.state.pointShadowMap,Ye.pointShadowMatrix.value=X.state.pointShadowMatrix),ne.currentProgram=nt,ne.uniformsList=null,nt}function xl(N){if(N.uniformsList===null){const W=N.currentProgram.getUniforms();N.uniformsList=ou.seqWithValue(W.seq,N.uniforms)}return N.uniformsList}function yl(N,W){const ee=it.get(N);ee.outputColorSpace=W.outputColorSpace,ee.batching=W.batching,ee.batchingColor=W.batchingColor,ee.instancing=W.instancing,ee.instancingColor=W.instancingColor,ee.instancingMorph=W.instancingMorph,ee.skinning=W.skinning,ee.morphTargets=W.morphTargets,ee.morphNormals=W.morphNormals,ee.morphColors=W.morphColors,ee.morphTargetsCount=W.morphTargetsCount,ee.numClippingPlanes=W.numClippingPlanes,ee.numIntersection=W.numClipIntersection,ee.vertexAlphas=W.vertexAlphas,ee.vertexTangents=W.vertexTangents,ee.toneMapping=W.toneMapping}function ts(N,W,ee,ne,X){W.isScene!==!0&&(W=rt),I.resetTextureUnits();const Re=W.fog,Oe=ne.isMeshStandardMaterial?W.environment:null,Pe=U===null?A.outputColorSpace:U.isXRRenderTarget===!0?U.texture.colorSpace:hr,qe=(ne.isMeshStandardMaterial?Q:C).get(ne.envMap||Oe),et=ne.vertexColors===!0&&!!ee.attributes.color&&ee.attributes.color.itemSize===4,nt=!!ee.attributes.tangent&&(!!ne.normalMap||ne.anisotropy>0),Ye=!!ee.morphAttributes.position,bt=!!ee.morphAttributes.normal,Dt=!!ee.morphAttributes.color;let It=or;ne.toneMapped&&(U===null||U.isXRRenderTarget===!0)&&(It=A.toneMapping);const Vt=ee.morphAttributes.position||ee.morphAttributes.normal||ee.morphAttributes.color,Mt=Vt!==void 0?Vt.length:0,Ve=it.get(ne),sn=_.state.lights;if(K===!0&&(fe===!0||N!==te)){const wn=N===te&&ne.id===$;Ce.setState(ne,N,wn)}let Et=!1;ne.version===Ve.__version?(Ve.needsLights&&Ve.lightsStateVersion!==sn.state.version||Ve.outputColorSpace!==Pe||X.isBatchedMesh&&Ve.batching===!1||!X.isBatchedMesh&&Ve.batching===!0||X.isBatchedMesh&&Ve.batchingColor===!0&&X.colorTexture===null||X.isBatchedMesh&&Ve.batchingColor===!1&&X.colorTexture!==null||X.isInstancedMesh&&Ve.instancing===!1||!X.isInstancedMesh&&Ve.instancing===!0||X.isSkinnedMesh&&Ve.skinning===!1||!X.isSkinnedMesh&&Ve.skinning===!0||X.isInstancedMesh&&Ve.instancingColor===!0&&X.instanceColor===null||X.isInstancedMesh&&Ve.instancingColor===!1&&X.instanceColor!==null||X.isInstancedMesh&&Ve.instancingMorph===!0&&X.morphTexture===null||X.isInstancedMesh&&Ve.instancingMorph===!1&&X.morphTexture!==null||Ve.envMap!==qe||ne.fog===!0&&Ve.fog!==Re||Ve.numClippingPlanes!==void 0&&(Ve.numClippingPlanes!==Ce.numPlanes||Ve.numIntersection!==Ce.numIntersection)||Ve.vertexAlphas!==et||Ve.vertexTangents!==nt||Ve.morphTargets!==Ye||Ve.morphNormals!==bt||Ve.morphColors!==Dt||Ve.toneMapping!==It||Ve.morphTargetsCount!==Mt)&&(Et=!0):(Et=!0,Ve.__version=ne.version);let Qn=Ve.currentProgram;Et===!0&&(Qn=Jr(ne,W,X));let wi=!1,hn=!1,ns=!1;const Ut=Qn.getUniforms(),Bi=Ve.uniforms;if(tt.useProgram(Qn.program)&&(wi=!0,hn=!0,ns=!0),ne.id!==$&&($=ne.id,hn=!0),wi||te!==N){_t.reverseDepthBuffer?(Te.copy(N.projectionMatrix),ZT(Te),QT(Te),Ut.setValue(B,"projectionMatrix",Te)):Ut.setValue(B,"projectionMatrix",N.projectionMatrix),Ut.setValue(B,"viewMatrix",N.matrixWorldInverse);const wn=Ut.map.cameraPosition;wn!==void 0&&wn.setValue(B,Ie.setFromMatrixPosition(N.matrixWorld)),_t.logarithmicDepthBuffer&&Ut.setValue(B,"logDepthBufFC",2/(Math.log(N.far+1)/Math.LN2)),(ne.isMeshPhongMaterial||ne.isMeshToonMaterial||ne.isMeshLambertMaterial||ne.isMeshBasicMaterial||ne.isMeshStandardMaterial||ne.isShaderMaterial)&&Ut.setValue(B,"isOrthographic",N.isOrthographicCamera===!0),te!==N&&(te=N,hn=!0,ns=!0)}if(X.isSkinnedMesh){Ut.setOptional(B,X,"bindMatrix"),Ut.setOptional(B,X,"bindMatrixInverse");const wn=X.skeleton;wn&&(wn.boneTexture===null&&wn.computeBoneTexture(),Ut.setValue(B,"boneTexture",wn.boneTexture,I))}X.isBatchedMesh&&(Ut.setOptional(B,X,"batchingTexture"),Ut.setValue(B,"batchingTexture",X._matricesTexture,I),Ut.setOptional(B,X,"batchingIdTexture"),Ut.setValue(B,"batchingIdTexture",X._indirectTexture,I),Ut.setOptional(B,X,"batchingColorTexture"),X._colorsTexture!==null&&Ut.setValue(B,"batchingColorTexture",X._colorsTexture,I));const lo=ee.morphAttributes;if((lo.position!==void 0||lo.normal!==void 0||lo.color!==void 0)&&st.update(X,ee,Qn),(hn||Ve.receiveShadow!==X.receiveShadow)&&(Ve.receiveShadow=X.receiveShadow,Ut.setValue(B,"receiveShadow",X.receiveShadow)),ne.isMeshGouraudMaterial&&ne.envMap!==null&&(Bi.envMap.value=qe,Bi.flipEnvMap.value=qe.isCubeTexture&&qe.isRenderTargetTexture===!1?-1:1),ne.isMeshStandardMaterial&&ne.envMap===null&&W.environment!==null&&(Bi.envMapIntensity.value=W.environmentIntensity),hn&&(Ut.setValue(B,"toneMappingExposure",A.toneMappingExposure),Ve.needsLights&&Sl(Bi,ns),Re&&ne.fog===!0&&ke.refreshFogUniforms(Bi,Re),ke.refreshMaterialUniforms(Bi,ne,de,V,_.state.transmissionRenderTarget[N.id]),ou.upload(B,xl(Ve),Bi,I)),ne.isShaderMaterial&&ne.uniformsNeedUpdate===!0&&(ou.upload(B,xl(Ve),Bi,I),ne.uniformsNeedUpdate=!1),ne.isSpriteMaterial&&Ut.setValue(B,"center",X.center),Ut.setValue(B,"modelViewMatrix",X.modelViewMatrix),Ut.setValue(B,"normalMatrix",X.normalMatrix),Ut.setValue(B,"modelMatrix",X.matrixWorld),ne.isShaderMaterial||ne.isRawShaderMaterial){const wn=ne.uniformsGroups;for(let ea=0,co=wn.length;ea<co;ea++){const Rs=wn[ea];G.update(Rs,Qn),G.bind(Rs,Qn)}}return Qn}function Sl(N,W){N.ambientLightColor.needsUpdate=W,N.lightProbe.needsUpdate=W,N.directionalLights.needsUpdate=W,N.directionalLightShadows.needsUpdate=W,N.pointLights.needsUpdate=W,N.pointLightShadows.needsUpdate=W,N.spotLights.needsUpdate=W,N.spotLightShadows.needsUpdate=W,N.rectAreaLights.needsUpdate=W,N.hemisphereLights.needsUpdate=W}function Ml(N){return N.isMeshLambertMaterial||N.isMeshToonMaterial||N.isMeshPhongMaterial||N.isMeshStandardMaterial||N.isShadowMaterial||N.isShaderMaterial&&N.lights===!0}this.getActiveCubeFace=function(){return k},this.getActiveMipmapLevel=function(){return D},this.getRenderTarget=function(){return U},this.setRenderTargetTextures=function(N,W,ee){it.get(N.texture).__webglTexture=W,it.get(N.depthTexture).__webglTexture=ee;const ne=it.get(N);ne.__hasExternalTextures=!0,ne.__autoAllocateDepthBuffer=ee===void 0,ne.__autoAllocateDepthBuffer||ft.has("WEBGL_multisampled_render_to_texture")===!0&&(console.warn("THREE.WebGLRenderer: Render-to-texture extension was disabled because an external texture was provided"),ne.__useRenderToTexture=!1)},this.setRenderTargetFramebuffer=function(N,W){const ee=it.get(N);ee.__webglFramebuffer=W,ee.__useDefaultFramebuffer=W===void 0},this.setRenderTarget=function(N,W=0,ee=0){U=N,k=W,D=ee;let ne=!0,X=null,Re=!1,Oe=!1;if(N){const qe=it.get(N);if(qe.__useDefaultFramebuffer!==void 0)tt.bindFramebuffer(B.FRAMEBUFFER,null),ne=!1;else if(qe.__webglFramebuffer===void 0)I.setupRenderTarget(N);else if(qe.__hasExternalTextures)I.rebindTextures(N,it.get(N.texture).__webglTexture,it.get(N.depthTexture).__webglTexture);else if(N.depthBuffer){const Ye=N.depthTexture;if(qe.__boundDepthTexture!==Ye){if(Ye!==null&&it.has(Ye)&&(N.width!==Ye.image.width||N.height!==Ye.image.height))throw new Error("WebGLRenderTarget: Attached DepthTexture is initialized to the incorrect size.");I.setupDepthRenderbuffer(N)}}const et=N.texture;(et.isData3DTexture||et.isDataArrayTexture||et.isCompressedArrayTexture)&&(Oe=!0);const nt=it.get(N).__webglFramebuffer;N.isWebGLCubeRenderTarget?(Array.isArray(nt[W])?X=nt[W][ee]:X=nt[W],Re=!0):N.samples>0&&I.useMultisampledRTT(N)===!1?X=it.get(N).__webglMultisampledFramebuffer:Array.isArray(nt)?X=nt[ee]:X=nt,T.copy(N.viewport),P.copy(N.scissor),re=N.scissorTest}else T.copy(oe).multiplyScalar(de).floor(),P.copy(O).multiplyScalar(de).floor(),re=le;if(tt.bindFramebuffer(B.FRAMEBUFFER,X)&&ne&&tt.drawBuffers(N,X),tt.viewport(T),tt.scissor(P),tt.setScissorTest(re),Re){const qe=it.get(N.texture);B.framebufferTexture2D(B.FRAMEBUFFER,B.COLOR_ATTACHMENT0,B.TEXTURE_CUBE_MAP_POSITIVE_X+W,qe.__webglTexture,ee)}else if(Oe){const qe=it.get(N.texture),et=W||0;B.framebufferTextureLayer(B.FRAMEBUFFER,B.COLOR_ATTACHMENT0,qe.__webglTexture,ee||0,et)}$=-1},this.readRenderTargetPixels=function(N,W,ee,ne,X,Re,Oe){if(!(N&&N.isWebGLRenderTarget)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let Pe=it.get(N).__webglFramebuffer;if(N.isWebGLCubeRenderTarget&&Oe!==void 0&&(Pe=Pe[Oe]),Pe){tt.bindFramebuffer(B.FRAMEBUFFER,Pe);try{const qe=N.texture,et=qe.format,nt=qe.type;if(!_t.textureFormatReadable(et)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(!_t.textureTypeReadable(nt)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}W>=0&&W<=N.width-ne&&ee>=0&&ee<=N.height-X&&B.readPixels(W,ee,ne,X,lt.convert(et),lt.convert(nt),Re)}finally{const qe=U!==null?it.get(U).__webglFramebuffer:null;tt.bindFramebuffer(B.FRAMEBUFFER,qe)}}},this.readRenderTargetPixelsAsync=async function(N,W,ee,ne,X,Re,Oe){if(!(N&&N.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let Pe=it.get(N).__webglFramebuffer;if(N.isWebGLCubeRenderTarget&&Oe!==void 0&&(Pe=Pe[Oe]),Pe){const qe=N.texture,et=qe.format,nt=qe.type;if(!_t.textureFormatReadable(et))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(!_t.textureTypeReadable(nt))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");if(W>=0&&W<=N.width-ne&&ee>=0&&ee<=N.height-X){tt.bindFramebuffer(B.FRAMEBUFFER,Pe);const Ye=B.createBuffer();B.bindBuffer(B.PIXEL_PACK_BUFFER,Ye),B.bufferData(B.PIXEL_PACK_BUFFER,Re.byteLength,B.STREAM_READ),B.readPixels(W,ee,ne,X,lt.convert(et),lt.convert(nt),0);const bt=U!==null?it.get(U).__webglFramebuffer:null;tt.bindFramebuffer(B.FRAMEBUFFER,bt);const Dt=B.fenceSync(B.SYNC_GPU_COMMANDS_COMPLETE,0);return B.flush(),await KT(B,Dt,4),B.bindBuffer(B.PIXEL_PACK_BUFFER,Ye),B.getBufferSubData(B.PIXEL_PACK_BUFFER,0,Re),B.deleteBuffer(Ye),B.deleteSync(Dt),Re}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")}},this.copyFramebufferToTexture=function(N,W=null,ee=0){N.isTexture!==!0&&(au("WebGLRenderer: copyFramebufferToTexture function signature has changed."),W=arguments[0]||null,N=arguments[1]);const ne=Math.pow(2,-ee),X=Math.floor(N.image.width*ne),Re=Math.floor(N.image.height*ne),Oe=W!==null?W.x:0,Pe=W!==null?W.y:0;I.setTexture2D(N,0),B.copyTexSubImage2D(B.TEXTURE_2D,ee,0,0,Oe,Pe,X,Re),tt.unbindTexture()},this.copyTextureToTexture=function(N,W,ee=null,ne=null,X=0){N.isTexture!==!0&&(au("WebGLRenderer: copyTextureToTexture function signature has changed."),ne=arguments[0]||null,N=arguments[1],W=arguments[2],X=arguments[3]||0,ee=null);let Re,Oe,Pe,qe,et,nt;ee!==null?(Re=ee.max.x-ee.min.x,Oe=ee.max.y-ee.min.y,Pe=ee.min.x,qe=ee.min.y):(Re=N.image.width,Oe=N.image.height,Pe=0,qe=0),ne!==null?(et=ne.x,nt=ne.y):(et=0,nt=0);const Ye=lt.convert(W.format),bt=lt.convert(W.type);I.setTexture2D(W,0),B.pixelStorei(B.UNPACK_FLIP_Y_WEBGL,W.flipY),B.pixelStorei(B.UNPACK_PREMULTIPLY_ALPHA_WEBGL,W.premultiplyAlpha),B.pixelStorei(B.UNPACK_ALIGNMENT,W.unpackAlignment);const Dt=B.getParameter(B.UNPACK_ROW_LENGTH),It=B.getParameter(B.UNPACK_IMAGE_HEIGHT),Vt=B.getParameter(B.UNPACK_SKIP_PIXELS),Mt=B.getParameter(B.UNPACK_SKIP_ROWS),Ve=B.getParameter(B.UNPACK_SKIP_IMAGES),sn=N.isCompressedTexture?N.mipmaps[X]:N.image;B.pixelStorei(B.UNPACK_ROW_LENGTH,sn.width),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,sn.height),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Pe),B.pixelStorei(B.UNPACK_SKIP_ROWS,qe),N.isDataTexture?B.texSubImage2D(B.TEXTURE_2D,X,et,nt,Re,Oe,Ye,bt,sn.data):N.isCompressedTexture?B.compressedTexSubImage2D(B.TEXTURE_2D,X,et,nt,sn.width,sn.height,Ye,sn.data):B.texSubImage2D(B.TEXTURE_2D,X,et,nt,Re,Oe,Ye,bt,sn),B.pixelStorei(B.UNPACK_ROW_LENGTH,Dt),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,It),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Vt),B.pixelStorei(B.UNPACK_SKIP_ROWS,Mt),B.pixelStorei(B.UNPACK_SKIP_IMAGES,Ve),X===0&&W.generateMipmaps&&B.generateMipmap(B.TEXTURE_2D),tt.unbindTexture()},this.copyTextureToTexture3D=function(N,W,ee=null,ne=null,X=0){N.isTexture!==!0&&(au("WebGLRenderer: copyTextureToTexture3D function signature has changed."),ee=arguments[0]||null,ne=arguments[1]||null,N=arguments[2],W=arguments[3],X=arguments[4]||0);let Re,Oe,Pe,qe,et,nt,Ye,bt,Dt;const It=N.isCompressedTexture?N.mipmaps[X]:N.image;ee!==null?(Re=ee.max.x-ee.min.x,Oe=ee.max.y-ee.min.y,Pe=ee.max.z-ee.min.z,qe=ee.min.x,et=ee.min.y,nt=ee.min.z):(Re=It.width,Oe=It.height,Pe=It.depth,qe=0,et=0,nt=0),ne!==null?(Ye=ne.x,bt=ne.y,Dt=ne.z):(Ye=0,bt=0,Dt=0);const Vt=lt.convert(W.format),Mt=lt.convert(W.type);let Ve;if(W.isData3DTexture)I.setTexture3D(W,0),Ve=B.TEXTURE_3D;else if(W.isDataArrayTexture||W.isCompressedArrayTexture)I.setTexture2DArray(W,0),Ve=B.TEXTURE_2D_ARRAY;else{console.warn("THREE.WebGLRenderer.copyTextureToTexture3D: only supports THREE.DataTexture3D and THREE.DataTexture2DArray.");return}B.pixelStorei(B.UNPACK_FLIP_Y_WEBGL,W.flipY),B.pixelStorei(B.UNPACK_PREMULTIPLY_ALPHA_WEBGL,W.premultiplyAlpha),B.pixelStorei(B.UNPACK_ALIGNMENT,W.unpackAlignment);const sn=B.getParameter(B.UNPACK_ROW_LENGTH),Et=B.getParameter(B.UNPACK_IMAGE_HEIGHT),Qn=B.getParameter(B.UNPACK_SKIP_PIXELS),wi=B.getParameter(B.UNPACK_SKIP_ROWS),hn=B.getParameter(B.UNPACK_SKIP_IMAGES);B.pixelStorei(B.UNPACK_ROW_LENGTH,It.width),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,It.height),B.pixelStorei(B.UNPACK_SKIP_PIXELS,qe),B.pixelStorei(B.UNPACK_SKIP_ROWS,et),B.pixelStorei(B.UNPACK_SKIP_IMAGES,nt),N.isDataTexture||N.isData3DTexture?B.texSubImage3D(Ve,X,Ye,bt,Dt,Re,Oe,Pe,Vt,Mt,It.data):W.isCompressedArrayTexture?B.compressedTexSubImage3D(Ve,X,Ye,bt,Dt,Re,Oe,Pe,Vt,It.data):B.texSubImage3D(Ve,X,Ye,bt,Dt,Re,Oe,Pe,Vt,Mt,It),B.pixelStorei(B.UNPACK_ROW_LENGTH,sn),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,Et),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Qn),B.pixelStorei(B.UNPACK_SKIP_ROWS,wi),B.pixelStorei(B.UNPACK_SKIP_IMAGES,hn),X===0&&W.generateMipmaps&&B.generateMipmap(Ve),tt.unbindTexture()},this.initRenderTarget=function(N){it.get(N).__webglFramebuffer===void 0&&I.setupRenderTarget(N)},this.initTexture=function(N){N.isCubeTexture?I.setTextureCube(N,0):N.isData3DTexture?I.setTexture3D(N,0):N.isDataArrayTexture||N.isCompressedArrayTexture?I.setTexture2DArray(N,0):I.setTexture2D(N,0),tt.unbindTexture()},this.resetState=function(){k=0,D=0,U=null,tt.reset(),Ct.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return ys}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(e){this._outputColorSpace=e;const t=this.getContext();t.drawingBufferColorSpace=e===zp?"display-p3":"srgb",t.unpackColorSpace=Nt.workingColorSpace===Fu?"display-p3":"srgb"}}class J_ extends oi{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Ts,this.environmentIntensity=1,this.environmentRotation=new Ts,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(e,t){return super.copy(e,t),e.background!==null&&(this.background=e.background.clone()),e.environment!==null&&(this.environment=e.environment.clone()),e.fog!==null&&(this.fog=e.fog.clone()),this.backgroundBlurriness=e.backgroundBlurriness,this.backgroundIntensity=e.backgroundIntensity,this.backgroundRotation.copy(e.backgroundRotation),this.environmentIntensity=e.environmentIntensity,this.environmentRotation.copy(e.environmentRotation),e.overrideMaterial!==null&&(this.overrideMaterial=e.overrideMaterial.clone()),this.matrixAutoUpdate=e.matrixAutoUpdate,this}toJSON(e){const t=super.toJSON(e);return this.fog!==null&&(t.object.fog=this.fog.toJSON()),this.backgroundBlurriness>0&&(t.object.backgroundBlurriness=this.backgroundBlurriness),this.backgroundIntensity!==1&&(t.object.backgroundIntensity=this.backgroundIntensity),t.object.backgroundRotation=this.backgroundRotation.toArray(),this.environmentIntensity!==1&&(t.object.environmentIntensity=this.environmentIntensity),t.object.environmentRotation=this.environmentRotation.toArray(),t}}class Su extends As{constructor(e=1,t=32,s=0,a=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:e,segments:t,thetaStart:s,thetaLength:a},t=Math.max(3,t);const c=[],u=[],d=[],f=[],p=new se,g=new At;u.push(0,0,0),d.push(0,0,1),f.push(.5,.5);for(let v=0,x=3;v<=t;v++,x+=3){const y=s+v/t*a;p.x=e*Math.cos(y),p.y=e*Math.sin(y),u.push(p.x,p.y,p.z),d.push(0,0,1),g.x=(u[x]/e+1)/2,g.y=(u[x+1]/e+1)/2,f.push(g.x,g.y)}for(let v=1;v<=t;v++)c.push(v,v+1,0);this.setIndex(c),this.setAttribute("position",new li(u,3)),this.setAttribute("normal",new li(d,3)),this.setAttribute("uv",new li(f,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new Su(e.radius,e.segments,e.thetaStart,e.thetaLength)}}class Mu extends As{constructor(e=.5,t=1,s=32,a=1,c=0,u=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:e,outerRadius:t,thetaSegments:s,phiSegments:a,thetaStart:c,thetaLength:u},s=Math.max(3,s),a=Math.max(1,a);const d=[],f=[],p=[],g=[];let v=e;const x=(t-e)/a,y=new se,w=new At;for(let E=0;E<=a;E++){for(let _=0;_<=s;_++){const M=c+_/s*u;y.x=v*Math.cos(M),y.y=v*Math.sin(M),f.push(y.x,y.y,y.z),p.push(0,0,1),w.x=(y.x/t+1)/2,w.y=(y.y/t+1)/2,g.push(w.x,w.y)}v+=x}for(let E=0;E<a;E++){const _=E*(s+1);for(let M=0;M<s;M++){const L=M+_,A=L,R=L+s+1,k=L+s+2,D=L+1;d.push(A,R,D),d.push(R,k,D)}}this.setIndex(d),this.setAttribute("position",new li(f,3)),this.setAttribute("normal",new li(p,3)),this.setAttribute("uv",new li(g,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new Mu(e.innerRadius,e.outerRadius,e.thetaSegments,e.phiSegments,e.thetaStart,e.thetaLength)}}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:Lp}}));typeof window<"u"&&(window.__THREE__?console.warn("WARNING: Multiple instances of Three.js being imported."):window.__THREE__=Lp);const lr={linear:n=>n,easeInOutCubic:n=>n<.5?4*n*n*n:(n-1)*(2*n-2)*(2*n-2)+1,easeOutExpo:n=>n===1?1:1-Math.pow(2,-10*n),easeOutBack:n=>1+2.70158*Math.pow(n-1,3)+1.70158*Math.pow(n-1,2)},vl=(n,e,t)=>Math.max(e,Math.min(t,n)),nl=(n,e,t)=>n+(e-n)*t,il=(n,e,t)=>vl((n-e)/Math.max(t-e,1e-6),0,1),Rt={enter:(n,e,t)=>lr.easeOutExpo(il(n,e,t)),draw:(n,e,t)=>lr.easeInOutCubic(il(n,e,t)),pop:(n,e,t)=>lr.easeOutBack(il(n,e,t))};function u3(n,e,t=lr.linear){return s=>{if(s<=n[0])return e[0];if(s>=n[n.length-1])return e[e.length-1];for(let a=0;a<n.length-1;a++){const c=n[a],u=n[a+1];if(s>=c&&s<=u){const d=u===c?0:(s-c)/(u-c),f=Array.isArray(t)?t[a]??lr.linear:t;return e[a]+(e[a+1]-e[a])*f(d)}}return e[e.length-1]}}const Ui=n=>{const e=Math.sin(n*127.1+311.7)*43758.5453;return e-Math.floor(e)},$n=(n,e,t)=>n>=e&&n<e+t?1-(n-e)/t:0,zu=(n,e,t,s=40)=>n.slice(0,Math.max(0,Math.floor((e-t)*s)));function lp(n){let e=String(n||"#ff3340").replace("#","");e.length===3&&(e=e.split("").map(s=>s+s).join(""));const t=parseInt(e,16);return[t>>16&255,t>>8&255,t&255]}const Yr=(n,e)=>{const[t,s,a]=lp(n);return`rgba(${t},${s},${a},${e})`},Fr=1920,_s=1080,lu=Math.PI*2,Yc=(n,e,t)=>Array.from({length:n},(s,a)=>[t+a*lu/n-e/2,e]),cp=[{r:1,w:.03,arcs:[[0,lu]],c:0,spin:.12},{r:.86,w:.08,arcs:Yc(4,.95,Math.PI/4),c:1,spin:-.22},{r:.7,w:.028,arcs:Yc(3,1.75,0),c:0,spin:.36},{r:.55,w:.09,arcs:Yc(2,1.25,Math.PI/2),c:1,spin:-.3},{r:.4,w:.026,arcs:[[0,lu]],c:0,spin:.55},{r:.26,w:.105,arcs:Yc(2,2.1,0),c:1,spin:-.48},{r:0,w:.075,arcs:[[0,lu]],c:0,spin:0}],d3="varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }",h3=`
varying vec2 vUv;
uniform float uTime, uStatic, uGlitch, uGlowR, uGlowI;
uniform vec2 uRes, uGlow; uniform vec3 uColA, uColB;
float h21(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p, p+45.32); return fract(p.x*p.y); }
void main(){
  vec2 uv = vUv; float asp = uRes.x/uRes.y;
  vec2 c = uv - 0.5; c.x *= asp; float r2 = dot(c,c);
  float band = floor(uv.y*30.0) + floor(uTime*17.0)*7.0;
  float gb = step(1.0 - uGlitch*0.35, h21(vec2(band, 7.1)));
  uv.x += gb*(h21(vec2(band, 3.3))-0.5)*0.12*uGlitch;
  vec3 col = vec3(0.016,0.019,0.03);
  vec2 g = fract(uv*vec2(48.0, 27.0)) - 0.5;
  float dots = smoothstep(0.08, 0.0, length(g));
  col += vec3(0.05,0.07,0.09)*dots*0.5;
  vec2 d = uv - uGlow; d.x *= asp; float gr = dot(d,d);
  col += uColA*uGlowI*exp(-gr/(uGlowR*uGlowR))*0.35;
  col += uColB*uGlowI*exp(-gr/(uGlowR*uGlowR*0.22))*0.22;
  float roll = smoothstep(0.0, 0.1, abs(fract(uv.y + uTime*0.06) - 0.5));
  col *= 0.9 + 0.1*roll;
  float n = h21(floor(vUv*uRes*0.5) + fract(uTime*13.7)*100.0);
  col = mix(col, vec3(n)*0.45, uStatic*uStatic);
  col *= 1.0 - 0.75*r2;
  col += (h21(vUv*uRes + fract(uTime)*37.0)-0.5)*0.03;
  gl_FragColor = vec4(col, 1.0);
}`;class f3{renderer;colA=new Pt("#2ee6e0");colB=new Pt("#ff3fb8");vA=new se;vB=new se;palKey="";bgScene=new J_;bgCam=new Ex(-1,1,1,-1,0,1);bgU;scene=new J_;cam=new xi(30,Fr/_s,1,2e4);matA;matB;glowA;glowB;emblem=new Br;rings;disposables=[];constructor(e){const t=this.renderer=new c3({canvas:e,antialias:!0,alpha:!1,powerPreference:"high-performance"});t.setPixelRatio(1),t.setSize(Fr,_s,!1),t.autoClear=!1,this.bgU={uTime:{value:0},uStatic:{value:1},uGlitch:{value:0},uGlowR:{value:.3},uGlowI:{value:0},uRes:{value:new At(Fr,_s)},uGlow:{value:new At(.5,.5)},uColA:{value:this.vA},uColB:{value:this.vB}};const s=new _l(2,2),a=new bs({uniforms:this.bgU,vertexShader:d3,fragmentShader:h3,depthTest:!1,depthWrite:!1});this.bgScene.add(new ji(s,a)),this.disposables.push(s,a),this.cam.position.z=_s/2/Math.tan(Math.PI/12),this.cam.lookAt(0,0,0);const c=u=>{const d=new Hp({color:u.clone(),transparent:!0,opacity:0,blending:yf,depthWrite:!1,side:Yi});return this.disposables.push(d),d};this.matA=c(this.colA),this.matB=c(this.colB),this.glowA=c(this.colA),this.glowB=c(this.colB),this.scene.add(this.emblem),this.rings=cp.map((u,d)=>{const f=new Br;this.emblem.add(f);const p=u.c?this.matB:this.matA,g=u.c?this.glowB:this.glowA,v=u.arcs.map(([x,y],w)=>{const E=new Br,_=(L,A)=>{this.disposables.push(L),E.add(new ji(L,A))};u.r===0?(_(new Su(u.w,48),p),_(new Su(u.w*2.2,48),g)):(_(new Mu(u.r-u.w/2,u.r+u.w/2,96,1,x,y),p),_(new Mu(u.r-u.w*1.9,u.r+u.w*1.9,96,1,x-.03,y+.06),g));const M=x+y/2;return E.userData={dx:u.r===0?0:Math.cos(M),dy:u.r===0?0:Math.sin(M),h:Ui(d*7+w*3+1)},f.add(E),E});return{rg:f,arcs:v}})}setPalette(e,t){const s=e+"|"+t;if(s===this.palKey)return;this.palKey=s;const a=lp(e),c=lp(t);this.vA.set(a[0]/255,a[1]/255,a[2]/255),this.vB.set(c[0]/255,c[1]/255,c[2]/255),this.colA.set(e),this.colB.set(t)}draw(e,t){this.setPalette(t[0],t[1]);const s=e.emb,a=this.bgU;a.uTime.value=e.W,a.uStatic.value=e.stat,a.uGlitch.value=e.glitch,a.uGlow.value.set(s.pos[0]/Fr,1-s.pos[1]/_s),a.uGlowR.value=s.pos[2]/_s*1.7,a.uGlowI.value=s.alpha*(.6+.8*s.pulse);const c=this.emblem;c.position.set(s.pos[0]-Fr/2,_s/2-s.pos[1],0),c.scale.setScalar(Math.max(.001,s.pos[2]*(1+.16*s.pulse)));const u=s.assemble.reduce((p,g)=>p+g,0)/s.assemble.length;c.rotation.x=s.tilt*.28*Math.sin(e.W*.37)+(1-u)*1.1,c.rotation.y=s.tilt*.42*Math.sin(e.W*.29),this.rings.forEach((p,g)=>{p.rg.rotation.z=cp[g].spin*s.spinT;const v=s.assemble[g]??1,x=Math.max(1-v,s.explode);for(const y of p.arcs){const w=y.userData;y.position.set(w.dx*x*1.3,w.dy*x*1.3,x*2.2*(w.h-.5)),y.rotation.x=(1-v)*2.2*(w.h>.5?1:-1)}});const d=1+1.3*s.pulse;this.matA.opacity=s.alpha,this.matB.opacity=s.alpha,this.glowA.opacity=s.alpha*.2*d,this.glowB.opacity=s.alpha*.18*d,this.matA.color.copy(this.colA).multiplyScalar(d),this.matB.color.copy(this.colB).multiplyScalar(d),this.glowA.color.copy(this.colA),this.glowB.color.copy(this.colB);const f=this.renderer;f.clear(),f.render(this.bgScene,this.bgCam),f.clearDepth(),f.render(this.scene,this.cam)}dispose(){for(const e of this.disposables)try{e.dispose()}catch{}try{this.renderer.dispose(),this.renderer.forceContextLoss()}catch{}}}const Kc=[{at:0,sound:"install_crton"},{at:.35,sound:"install_emblem"},{at:.45,sound:"install_assemble"},{at:.5,sound:"install_bios"},{at:1,sound:"install_type_a"},{at:1.5,sound:"install_wordmark"},{at:2.2,sound:"install_select"},{at:3,sound:"install_glitch"},{at:3.05,sound:"install_zoom"},{at:3.05,sound:"install_type_c"},{at:3.55,sound:"install_panel"},{at:3.6,sound:"install_dmesg"},{at:4.3,sound:"install_nomodule"},{at:4.9,sound:"install_banner"},{at:5.5,sound:"install_type_b"},{at:6.3,sound:"install_ask"},{at:6.65,sound:"install_press"},{at:7,sound:"install_bed"},{at:7.1,sound:"install_type_c"},{at:8,sound:"install_carrier1"},{at:8.2,sound:"install_carrier2"},{at:8.4,sound:"install_carrier3"},{at:8.65,sound:"install_joined"},{at:8.9,sound:"install_type_a"},{at:9.4,sound:"install_download"},{at:10.35,sound:"install_dldone"},{at:10.47,sound:"install_ok"},{at:11.1,sound:"install_type_b"},{at:11.65,sound:"install_probe"},{at:11.9,sound:"install_grid"},{at:13.6,sound:"install_mapped"},{at:13.8,sound:"install_type_c"},{at:14.3,sound:"install_ok"},{at:14.5,sound:"install_stable"},{at:15.1,sound:"install_type_a"},{at:15.65,sound:"install_trace"},{at:15.75,sound:"install_wave"},{at:16.75,sound:"install_bound"},{at:16.9,sound:"install_bound2"},{at:17.05,sound:"install_chiasm"},{at:17.9,sound:"install_relay"},{at:18.1,sound:"install_reflex"},{at:19.1,sound:"install_type_b"},{at:19.7,sound:"install_erase"},{at:20.05,sound:"install_hex"},{at:21.25,sound:"install_firmware"},{at:22.2,sound:"install_written"},{at:22.32,sound:"install_emitter"},{at:22.52,sound:"install_ok"},{at:23.1,sound:"install_type_c"},{at:23.3,sound:"install_zoom"},{at:23.85,sound:"install_explode"},{at:23.9,sound:"install_hologram"},{at:25.3,sound:"install_implode"},{at:25.3,sound:"install_pass"},{at:26,sound:"install_glitch"},{at:26.5,sound:"install_online"},{at:27.1,sound:"install_tick"},{at:28.1,sound:"install_tick"},{at:28.3,sound:"install_crtoff"}],ct={Post:0,Kernel:3,Network:7,Cortex:11,Nerve:15,Flash:19,Verify:23,Done:26},Nx=ct.Kernel+3.3,ev=ct.Kernel+3.6,Gp=ct.Kernel+3.65,of=ct.Flash,tv=ct.Done-.001,p3=ct.Done+3,ai='"IBM Plex Mono", "Share Tech Mono", ui-monospace, monospace',m3='"Chakra Petch", "IBM Plex Mono", sans-serif',g3='"Noto Sans JP", "Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", sans-serif',yi="#dfe9ee",on="rgba(223,233,238,0.5)",Ja="rgba(223,233,238,0.22)",Eu="#05060a",Wt="#2ee6e0",Pn="#ff3fb8",_3=[Wt,Pn],lf={enter:lr.easeOutExpo,draw:lr.easeInOutCubic,pop:lr.easeOutBack},Rx=n=>String(n).padStart(2,"0"),v3=22e3,x3=[960,440,230],y3=[1808,64,30],S3=[698,556,270],M3=[960,400,190];function E3(n){const{T:e,W:t}=n,{Post:s,Kernel:a,Network:c,Cortex:u,Nerve:d,Flash:f,Verify:p,Done:g}=ct;let v=.8*$n(e,a,.35)+.3*($n(e,c,.2)+$n(e,u,.2)+$n(e,d,.2)+$n(e,f,.2))+$n(e,p+.85,.4)+.7*$n(e,p+2.3,.3)+$n(e,g,.4);v=vl(v+n.idle+(n.fault?$n(t,n.fault.at,.5):0),0,1.5);const x=Rt.draw(e,a-.1,a+.7),y=Rt.draw(e,p+.3,p+.9),w=Rt.draw(e,g,g+.6);let E=x3.map((U,$)=>nl(U,y3[$],x));E=E.map((U,$)=>nl(U,S3[$],y)),E=E.map((U,$)=>nl(U,M3[$],w));const _=cp.map((U,$)=>Rt.draw(e,s+.35+$*.1,s+1.3+$*.1)),M=Math.max(0,u3([p+.9,p+1.25,p+1.9,p+2.3],[0,.5,.5,0],[lf.enter,lf.draw,lf.pop])(e));let L=0,A=0;for(const U of[a,c,u,d,f,p,g])L+=$n(e,U,.5),A+=Rt.draw(e,U,U+.9);L+=.8*$n(e,p+2.3,.5)+(n.fault?$n(t,n.fault.at,.6):0);const R=t+1.4*A+7*Rt.draw(e,p+.85,p+2.4),k=(1-.65*x)*(1-y)+y*.9*(1-.5*w),D=Rt.enter(e,s+.2,s+.6);return{T:e,W:t,glitch:v,stat:1-Rt.draw(e,s+.1,s+1.1),emb:{pos:E,assemble:_,explode:M,pulse:L,spinT:R,tilt:k,alpha:D}}}function w3({params:n}){const e=q.useRef(null),t=q.useRef(null);return q.useEffect(()=>{const s=document.createElement("canvas");s.width=Fr,s.height=_s,s.style.cssText=`position:absolute;left:0;top:0;width:${Fr}px;height:${_s}px`;try{t.current=new f3(s),e.current?.appendChild(s)}catch(a){console.warn("[neuralink] installation: WebGL unavailable, terminal only",a)}return()=>{t.current?.dispose(),t.current=null,s.remove()}},[]),q.useEffect(()=>{t.current?.draw(n,_3)}),l.jsx("div",{ref:e,style:{position:"absolute",inset:0,background:Eu,pointerEvents:"none"}})}const T3=[" _  _  ___  _    ___     ___  ___ ","| || |/ _ \\| |  / _ \\   / _ \\/ __|","| __ | (_) | |_| (_) | | (_) \\__ \\","|_||_|\\___/|___|\\___/   \\___/|___/"];function b3(n){const{Kernel:e,Network:t,Cortex:s,Nerve:a,Flash:c,Verify:u,Done:d}=ct,f=[];let p=0;const g=(_,M)=>{f.push({t:p,kind:"cmd",text:_,dur:M}),p+=M+.05},v=(_,M,L)=>{f.push({t:p,kind:"out",text:_,...L}),p+=M??.1},x=(_,M,L)=>v(_,M??.14,{tag:L||"OK"}),y=(_,M,L)=>{f.push({t:p,kind:"bar",to:M,label:_,right:L}),p=M+.12},w=()=>v("",.02),E=n.model;return p=e+.05,g("boot holo-os-4.3.0.img --target=/dev/ocular0",.5),[["0.000000","HOLO-OS 4.3.0 (build nc-09) #1 SMP PREEMPT"],["0.000412","npu: Kiroshi NPU-7 @ 2.4 THz, 4096 phase cells"],["0.001207","mem: 2048 PB neural lattice, ECC enabled"],["0.004881",`ocular0: ${E} at cortical port C7`],["0.004902",`ocular1: ${E} at cortical port C8`],["0.009340","bus: optic nerve bridge online (2.4 TB/s)"],["0.012003","crypto: QEC-4096 engine ready"],["0.018754","holo: no Neural-Link module on ocular0 -- installer required","b"],["0.020110","init: switching to installer shell"]].forEach(([_,M,L])=>v(`[    ${_}] ${M}`,.1,{color:L,stamp:!0})),p=e+1.9,w(),T3.forEach(_=>v(_,.05,{color:"a"})),v("HOLO-OS INSTALLER 4.3.0  ·  8 stages  ·  target /dev/ocular0",.1,{color:"dim"}),w(),p=e+2.5,g("holo-install neuralink.core --target=/dev/ocular0",.6),v("module  neuralink.core 2.0  ·  38.2 MB  ·  signed kiroshi",.1,{color:"dim"}),p=Nx,n.selfInstall?(f.push({t:p,kind:"ask",text:"install the Neural-Link on /dev/ocular0? [Y/n] "}),p=Gp+.08,x("installation confirmed  ·  do not move your eyes",.1)):(v("holo-install: self-install locked on this model",.12,{color:"b",tag:"LOCK"}),v("visit a ripperdoc to have the Neural-Link installed",.1,{color:"a"})),p=t+.1,g("netlink up --carrier=kiroshi-net",.5),v("scanning carriers",.35,{color:"dim"}),v("  nc-09.watson.grid       -41 dBm    QEC-4096",.2,{color:"a"}),v("  nc-12.westbrook.grid    -67 dBm    QEC-4096",.2),v("  nc-03.corpo.net         -83 dBm    open",.25,{color:"dim"}),x("joined nc-09.watson.grid    lease 7F:3A:91:C4",.25),g("fetch pkg://kiroshi/neuralink.core-2.0.pak",.45),y("neuralink.core-2.0.pak",t+3.35,"38.2 MB    2.4 TB/s"),x("sha3-512  9f3a:b2c1:77e0 ... verified",.15),x("package staged in /var/holo/stage"),p=s+.1,g("cortex map --region=V1 --cells=4096",.5),x("probing occipital bus",.25),f.push({t:p,kind:"grid",to:s+2.5}),p=s+2.6,x("4096/4096 phase cells mapped    delta 0.003",.2),g("cortex link --bus=occipital",.45),x("synaptic interface calibrated",.2),x("cortical link stable    2.4 TB/s"),p=a+.1,g("nerve bind --optic L,R --relay T1",.5),v("tracing optic nerve L -> chiasm -> V1 (right)",.1,{color:"dim"}),f.push({t:p,kind:"wave",to:a+1.7}),p=a+1.75,x("optic nerve L bound",.15),x("optic nerve R bound",.15),x("chiasm crossover",.25),v("syncing spinal relay T1",.6,{color:"dim"}),x("spinal relay T1    12 ms",.2),v("reflex gate armed:  blink x2 = accept    look away = decline",.1,{color:"a"}),p=c+.1,g("flash --module neuralink.core-2.0.pak --port C7",.55),v("erasing sectors 0x3F2A-0x4B6A",.35,{color:"b"}),f.push({t:p,kind:"hex",to:c+2.2,rate:9,max:10}),p=c+2.25,y("firmware 4.2.1 -> 4.3.0",c+3.2,"sector 0x4B6A"),x("emitter warm-up 31°C -> 44°C",.2),x("holocall.service enabled"),p=u+.1,g("selftest --all",.45),v("projecting emitter test pattern ...",.1,{color:"dim"}),p=u+2.3,x("emitter test pattern",.12,"PASS"),x("link latency 12 ms",.12,"PASS"),x("encryption QEC-4096",.12,"PASS"),v("7/7 checks passed",.1,{color:"a"}),p=d+.02,g("clear",.25),f.push({t:p,kind:"clear"}),f}const A3=n=>n.kind==="cmd"?n.t+n.dur:"to"in n?n.to:n.t;function up(){return l.jsxs("span",{children:[l.jsx("span",{style:{color:Pn},children:"root@kiroshi"}),l.jsx("span",{style:{color:on},children:":~"}),l.jsx("span",{style:{color:Wt},children:"# "})]})}function cu({W:n}){return l.jsx("span",{style:{display:"inline-block",width:11,height:20,background:Wt,verticalAlign:-3,opacity:Math.floor(n*2.5)%2===0?1:.15,boxShadow:`0 0 10px ${Yr(Wt,.7)}`}})}const _i=27,nv=31;function cf({text:n,color:e,stamp:t,tag:s}){const a=e==="a"?Wt:e==="b"?Pn:e==="dim"?on:yi,c=s==="OK"||s==="PASS"?Wt:Pn;return l.jsxs("div",{style:{height:_i,whiteSpace:"pre",display:"flex",color:a},children:[l.jsx("span",{style:{color:t?on:"inherit"},children:t?n.slice(0,15):""}),l.jsxs("span",{style:{width:s?700:"auto"},children:[s?"  ":"",t?n.slice(15):n]}),s?l.jsxs("span",{style:{color:on},children:["[ ",l.jsx("span",{style:{color:c,textShadow:`0 0 10px ${Yr(c,.6)}`},children:s.padStart(4," ")})," ]"]}):null]})}function C3({v:n,log:e,ctx:t,choices:s}){const{T:a,W:c}=n,u=[];let d=-1;for(const g of e){if(g.t>a)break;d=Math.max(d,A3(g));const v=g.kind+g.t;if(g.kind==="clear"){u.length=0;continue}if(g.kind==="cmd"){const x=a<g.t+g.dur;u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre"},children:[l.jsx(up,{}),zu(g.text,a,g.t,g.text.length/g.dur),x?l.jsx(cu,{W:c}):null]},v)})}else if(g.kind==="out")u.push({u:1,el:l.jsx(cf,{...g},v)});else if(g.kind==="ask"){const x=n.confirmed&&a>=Gp;u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:yi},children:[l.jsx("span",{style:{color:Wt},children:"? "}),g.text,x?l.jsx("span",{style:{color:Wt},children:"y"}):l.jsx(cu,{W:c})]},v)})}else if(g.kind==="bar"){const x=Rt.draw(a,g.t,g.to),y=Math.round(x*40),w=x>=1;u.push({u:1,el:l.jsxs("div",{style:{height:_i,display:"flex",alignItems:"center",gap:14,whiteSpace:"pre"},children:[l.jsxs("span",{style:{color:on},children:["  ",g.label.padEnd(26," ")]}),l.jsx("span",{style:{color:on},children:"["}),l.jsx("span",{style:{display:"flex",gap:2},children:Array.from({length:40},(E,_)=>l.jsx("span",{style:{width:9,height:14,background:_<y?w?yi:Wt:Ja,boxShadow:_<y&&!w?`0 0 6px ${Yr(Wt,.5)}`:"none"}},_))}),l.jsx("span",{style:{color:on},children:"]"}),l.jsxs("span",{style:{color:yi,width:54,textAlign:"right"},children:[Math.round(x*100),"%"]}),l.jsx("span",{style:{color:on},children:g.right})]},v)})}else if(g.kind==="grid"){const x=Math.floor(Rt.draw(a,g.t,g.to)*384);u.push({u:4,el:l.jsx("div",{style:{height:_i*4,display:"grid",gridTemplateColumns:"repeat(64, 14px)",gridAutoRows:"14px",gap:3,alignContent:"center",paddingLeft:26},children:Array.from({length:384},(y,w)=>l.jsx("div",{style:{background:w<x?Ui(w)>.9?Pn:Wt:"rgba(223,233,238,0.07)",opacity:w<x?.55+.45*Ui(w+5):1}},w))},v)})}else if(g.kind==="wave"){const x=a<g.to?1:.2,y=a<g.to?a:c;u.push({u:2,el:l.jsx("div",{style:{height:_i*2,display:"flex",alignItems:"center",gap:4,paddingLeft:26},children:Array.from({length:110},(w,E)=>{const _=3+40*x*Math.abs(Math.sin(E*.33-y*9))*(.4+.6*Ui(E));return l.jsx("div",{style:{width:6,height:_,background:E%7===0?Pn:Wt,opacity:.5+.5*Ui(E+9)}},E)})},v)})}else if(g.kind==="hex"){const x=Math.min(g.max,Math.floor((a-g.t)*g.rate)+1);for(let y=0;y<x;y++){const w=Array.from({length:12},(M,L)=>Math.floor(Ui(y*31+L*7+2)*256)),E=w.map(M=>M.toString(16).padStart(2,"0")).join(" "),_=w.map(M=>M>32&&M<127?String.fromCharCode(M):".").join("");u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:on},children:["  ",l.jsxs("span",{style:{color:Pn},children:["0x",(16170+y*16).toString(16).toUpperCase()]}),"   ",E,"   ",l.jsxs("span",{style:{color:Ja},children:["|",_,"|"]})]},v+y)})}}}if(n.holding){const g="|/-\\"[Math.floor(c*10)%4];u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:on},children:["  registering line ",l.jsx("span",{style:{color:yi},children:t.number})," on nc-09.watson.grid  ",l.jsx("span",{style:{color:Wt},children:g})]},"hold")})}n.fault&&(u.push({u:1,el:l.jsx(cf,{text:`flash: ${On(n.fault.slug).toLowerCase()}`,color:"b",tag:"FAIL"},"fault")}),u.push({u:1,el:l.jsx(cf,{text:"module rolled back  ·  nothing was written to ocular0",color:"dim"},"fault2")})),s?u.push({u:2,el:l.jsx("div",{className:"holo-choice",style:{height:_i*2},children:s.map(g=>l.jsxs("button",{type:"button",className:`holo-key${g.primary?" holo-key--primary":""}`,onClick:g.act,children:[l.jsx("span",{className:"holo-key__cap",children:g.key}),l.jsx("span",{children:g.label})]},g.key))},"choice")}):a>d+.08&&!n.holding&&!n.fault&&u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre"},children:[l.jsx(up,{}),l.jsx(cu,{W:c})]},"prompt")});let f=0,p=u.length;for(;p>0&&f+u[p-1].u<=nv;)f+=u[p-1].u,p--;return l.jsx("div",{style:{position:"absolute",left:64,top:128,width:1268,height:nv*_i,overflow:"hidden",fontFamily:ai,fontSize:19,lineHeight:_i+"px",color:yi,display:"flex",flexDirection:"column",justifyContent:"flex-end"},children:u.slice(p).map(g=>g.el)})}const Px=["POST","KERNEL","NETWORK","CORTEX","NERVE","FLASH","SELFTEST","DONE"],wu=[ct.Post,ct.Kernel,ct.Network,ct.Cortex,ct.Nerve,ct.Flash,ct.Verify,ct.Done],kx=n=>{let e=0;for(let t=0;t<wu.length;t++)n>=wu[t]&&(e=t);return e};function uf({title:n,top:e,height:t,children:s}){return l.jsxs("div",{style:{position:"absolute",left:1372,top:e,width:484,height:t,boxSizing:"border-box",border:`1px solid ${Ja}`,padding:"22px 22px 16px"},children:[l.jsx("div",{style:{position:"absolute",left:14,top:-10,padding:"0 8px",background:Eu,fontFamily:ai,fontSize:14,letterSpacing:"0.24em",color:Wt},children:n}),s]})}function Zc({label:n,u:e,value:t,warn:s}){const a=Math.round(vl(e,0,1)*24);return l.jsxs("div",{style:{display:"flex",alignItems:"center",height:30,fontFamily:ai,fontSize:15,whiteSpace:"pre"},children:[l.jsx("span",{style:{color:on,width:120},children:n}),l.jsx("span",{style:{display:"flex",gap:2,width:190},children:Array.from({length:24},(c,u)=>l.jsx("span",{style:{width:6,height:12,background:u<a?s?Pn:Wt:Ja}},u))}),l.jsx("span",{style:{color:yi,flex:1,textAlign:"right"},children:t})]})}function N3({v:n,ctx:e}){const{T:t,W:s}=n,a=kx(t),c=Rt.enter(t,ct.Kernel+.5,ct.Kernel+1)*(1-Rt.draw(t,ct.Done+.3,ct.Done+.7)),u=t>ct.Kernel+1.2?.7+.25*Ui(Math.floor(s*5)):0,d=t>ct.Network+.4?.82*Rt.draw(t,ct.Network+.4,ct.Network+1.2):0,f=nl(31,44,il(t,ct.Flash+2.3,ct.Flash+3.4)),p=Math.round(4096*Rt.draw(t,ct.Cortex+.9,ct.Cortex+2.5)),g=Math.floor(s*3)%2===0,v=t>=ct.Flash+3.2;return l.jsxs("div",{style:{position:"absolute",inset:0,opacity:c,transform:`translateX(${(1-c)*30}px)`,pointerEvents:"none"},children:[l.jsx(uf,{title:"STAGES",top:128,height:356,children:Px.map((x,y)=>{const w=y<a,E=y===a,_=E&&!!n.fault;return l.jsxs("div",{style:{display:"flex",alignItems:"center",height:38,fontFamily:ai,fontSize:17,whiteSpace:"pre",color:w?yi:_?Pn:E?Wt:on},children:[l.jsx("span",{style:{color:on,width:44},children:Rx(y+1)}),l.jsx("span",{style:{width:150,textShadow:E?`0 0 12px ${Yr(_?Pn:Wt,.6)}`:"none"},children:x}),l.jsx("span",{style:{flex:1,textAlign:"right",color:w||E?_?Pn:Wt:Ja,opacity:E&&!g?.4:1},children:w?"[ OK ]":_?"[FAIL]":E?"[ >> ]":"[ -- ]"})]},x)})}),l.jsxs(uf,{title:"SYSTEM",top:516,height:204,children:[l.jsx(Zc,{label:"NEURAL BUS",u,value:u?"2.4 TB/s":"idle"}),l.jsx(Zc,{label:"UPLINK",u:d,value:d?"-41 dBm":"no carrier"}),l.jsx(Zc,{label:"EMITTER",u:(f-20)/30,value:`${Math.round(f)}°C`,warn:f<40&&t>ct.Flash+2.3}),l.jsx(Zc,{label:"V1 CELLS",u:p/4096,value:`${p} / 4096`})]}),l.jsx(uf,{title:"TARGET",top:752,height:226,children:[["DEVICE","/dev/ocular0"],["PORT","cortical C7"],["MODEL",e.model],["FIRMWARE",v?"4.3.0":"4.2.1"],["LINE",e.number]].map(([x,y])=>l.jsxs("div",{style:{display:"flex",height:32,alignItems:"center",fontFamily:ai,fontSize:15,whiteSpace:"pre"},children:[l.jsx("span",{style:{color:on,width:120},children:x}),l.jsx("span",{style:{color:x==="FIRMWARE"&&v?Wt:yi,overflow:"hidden",textOverflow:"ellipsis"},children:y})]},x))})]})}function R3({T:n}){const e=Rt.enter(n,ct.Kernel+.3,ct.Kernel+.8)*(1-Rt.draw(n,ct.Done+.3,ct.Done+.7)),t=n>=ct.Kernel?`UP 00:${Rx(Math.floor(n-ct.Kernel))}`:"UP --:--";return l.jsxs("div",{style:{position:"absolute",left:64,right:64,top:48,height:36,display:"flex",alignItems:"center",justifyContent:"space-between",fontFamily:ai,fontSize:15,letterSpacing:"0.16em",color:on,opacity:e,borderBottom:`1px solid ${Ja}`,whiteSpace:"pre"},children:[l.jsxs("span",{children:[l.jsx("span",{style:{color:yi},children:"KIROSHI OPTICS"}),"  //  HOLO-OS INSTALLER 4.3.0"]}),l.jsxs("span",{children:["tty1  ·  /dev/ocular0  ·  ",t]}),l.jsx("span",{style:{width:160}})]})}function P3({v:n}){const{T:e}=n,t=kx(e),s=Rt.enter(e,ct.Kernel+.6,ct.Kernel+1)*(1-Rt.draw(e,ct.Done+.3,ct.Done+.7)),a=t<7?wu[t+1]:ct.Done+2,c=(t+il(e,wu[t],a))/8,u=Math.round(c*30),d=n.fault?Pn:Wt;return l.jsxs("div",{style:{position:"absolute",left:64,right:64,top:1004,height:34,background:Yr(d,.88),color:Eu,display:"flex",alignItems:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.1em",fontWeight:500,opacity:s,whiteSpace:"pre"},children:[l.jsx("span",{style:{padding:"0 18px",background:n.fault?Wt:Pn,color:"#1a0410",height:"100%",display:"flex",alignItems:"center"},children:"HOLO-OS"}),l.jsxs("span",{style:{padding:"0 18px"},children:["STAGE ",t+1,"/8  ",Px[t],n.fault?"  ·  FAILED":n.waiting?"  ·  AWAITING INPUT":n.holding?"  ·  REGISTERING":""]}),l.jsx("span",{style:{display:"flex",gap:2,padding:"0 10px"},children:Array.from({length:30},(f,p)=>l.jsx("span",{style:{width:8,height:12,background:p<u?Eu:"rgba(5,6,10,0.25)"}},p))}),l.jsxs("span",{style:{padding:"0 14px"},children:[Math.round(c*100),"%"]}),l.jsx("span",{style:{flex:1}}),l.jsx("span",{style:{padding:"0 18px"},children:e>ct.Network+1.6?"nc-09.watson.grid":"no carrier"}),l.jsx("span",{style:{padding:"0 18px"},children:"QEC-4096"})]})}function Lx({T:n,at:e,size:t,top:s}){const a=Rt.enter(n,e,e+.5);return l.jsxs("div",{style:{position:"absolute",left:0,right:0,top:s,textAlign:"center",opacity:a,transform:`translateY(${(1-a)*14}px)`},children:[l.jsx("div",{style:{fontFamily:m3,fontWeight:700,fontSize:t,letterSpacing:"0.34em",textIndent:"0.34em",lineHeight:1,color:Pn,textShadow:`0 0 24px ${Yr(Pn,.55)}, 0 0 2px ${Pn}`,minHeight:t},children:zu("KIROSHI",n,e,18)}),l.jsx("div",{style:{fontFamily:g3,fontWeight:500,fontSize:t*.42,letterSpacing:"0.2em",textIndent:"0.2em",color:Wt,marginTop:t*.22,textShadow:`0 0 16px ${Yr(Wt,.5)}`,opacity:Rt.enter(n,e+.5,e+.9)},children:"キロシ・オプティクス"})]})}function k3({T:n,W:e}){const t=ct.Post,s=ct.Kernel,a=1-Rt.draw(n,s-.05,s+.35),c=[["KIROSHI OPTICS BIOS 4.2.1",t+.5],["POST ................ OK",t+1],["MEM 2048 PB .......... OK",t+1.4],["OCULAR0 MK.IV ........ OK",t+1.75],["BOOT holo-os-4.3.0.img",t+2.2]];return l.jsxs("div",{style:{position:"absolute",inset:0,opacity:a,pointerEvents:"none"},children:[l.jsx(Lx,{T:n,at:t+1.5,size:76,top:740}),l.jsx("div",{style:{position:"absolute",left:64,top:880,fontFamily:ai,fontSize:16,lineHeight:"26px",color:on,whiteSpace:"pre"},children:c.map(([u,d])=>l.jsx("div",{style:{color:u.endsWith("OK")&&n>d+u.length/50?yi:on},children:zu(u,n,d,50)},u))}),l.jsx("div",{style:{position:"absolute",right:64,top:1e3,fontFamily:ai,fontSize:14,letterSpacing:"0.2em",color:on,opacity:n>t+1.2&&Math.floor(e*1.5)%2===0?1:.3},children:"BLINK x2 TO ENTER SETUP"})]})}function L3({T:n,W:e,ctx:t}){const s=ct.Done,a=Rt.enter(n,s+.5,s+1),c=vl(3-Math.floor(n-(s+1.1)),1,3);return l.jsxs("div",{style:{position:"absolute",inset:0,pointerEvents:"none"},children:[l.jsx(Lx,{T:n,at:s+.5,size:64,top:650}),l.jsx("div",{style:{position:"absolute",left:0,right:0,top:800,textAlign:"center",fontFamily:ai,fontSize:18,letterSpacing:"0.3em",textIndent:"0.3em",color:yi,opacity:a,whiteSpace:"pre"},children:zu("HOLO-OS 4.3.0  ·  NEURAL-LINK INSTALLED",n,s+.9,60)}),l.jsx("div",{style:{position:"absolute",left:0,right:0,top:838,textAlign:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.2em",color:Wt,opacity:Rt.enter(n,s+1.3,s+1.6),whiteSpace:"pre"},children:`${t.name.toUpperCase()}  ·  LINE ${t.number}`}),l.jsxs("div",{style:{position:"absolute",left:0,right:0,top:874,textAlign:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.2em",color:on,opacity:Rt.enter(n,s+1.5,s+1.8)},children:["rebooting ocular suite in ",c]}),l.jsxs("div",{style:{position:"absolute",left:64,top:1e3,fontFamily:ai,fontSize:19,whiteSpace:"pre",opacity:a},children:[l.jsx(up,{}),l.jsx(cu,{W:e})]})]})}function D3({W:n,g:e,children:t}){const s=Math.floor(n*30),a=e<.03?[]:[0,1,2].map(c=>({y:Ui(s+c*7)*92,h:3+Ui(s+c*13)*9,dx:(Ui(s+c*3)-.5)*70*e}));return l.jsxs("div",{style:{position:"absolute",inset:0},children:[l.jsx("div",{style:{position:"absolute",inset:0,transform:e<.03?void 0:`translateX(${(Ui(s)-.5)*10*e}px)`},children:t}),a.map((c,u)=>l.jsx("div",{"aria-hidden":!0,inert:"",style:{position:"absolute",inset:0,pointerEvents:"none",clipPath:`inset(${c.y}% 0 ${Math.max(0,100-c.y-c.h)}% 0)`,transform:`translateX(${c.dx}px)`,filter:u===1?"hue-rotate(120deg) saturate(2)":"none"},children:t},u))]})}function I3({selfInstall:n,autoStart:e}){const t=he(V=>V.state?.implant),s=he(V=>V.state?.line),a={selfInstall:n,model:t?.model||"Kiroshi NL-77 Synapse",name:s?.name||"Unknown citizen",number:s?.number??"---"},c=q.useMemo(()=>b3(a),[a.selfInstall,a.model]),[,u]=q.useReducer(V=>V+1,0),d=q.useRef({T:0,W:0,holding:!1,idle:0,fault:null,waiting:!1,confirmed:!1}),f=q.useRef({asked:!1,reply:null,cue:0,idleAt:-10,nextIdle:9,lastIdleSound:-99,done:!1,alive:!0}),p=q.useRef(e&&n),g=()=>{const V=d.current;V.confirmed||!n||V.T<Nx||(V.confirmed=!0,be().setImplantFlow(!0),V.T=Math.max(V.T,Gp),V.waiting=!1)},v=()=>{const V=f.current,de=d.current;de.fault&&(de.fault=null,de.holding=!1,de.T=of,V.asked=!1,V.reply=null,V.cue=Kc.findIndex(z=>z.at>=of))},x=()=>{const V=f.current;V.asked=!0;let de=0;const z=new Promise((ue,oe)=>{de=window.setTimeout(()=>oe(new Sn("timeout")),v3)});Promise.race([to("implant.install",{}),z]).then(ue=>{V.alive&&(V.reply={implant:ue?.implant&&typeof ue.implant=="object"?ue.implant:null})},ue=>{V.alive&&(d.current.fault={slug:ue instanceof Sn?ue.slug:"unknown",at:d.current.W},Me("install_fault"))}).finally(()=>window.clearTimeout(de))};q.useEffect(()=>{const V=f.current;V.alive=!0;const de=sr()?1.6:1;let z=performance.now(),ue=0;const oe=O=>{if(!V.alive)return;const le=vl((O-z)/1e3,0,.1);z=O;const we=d.current;if(we.W+=le,!we.fault&&!V.done){let K=we.T+le*de;for(we.confirmed?(!V.asked&&K>=of&&x(),we.holding=K>=tv&&!V.reply&&!we.fault,we.holding&&(K=tv)):K>=ev&&(K=ev,we.waiting=!0,p.current&&(p.current=!1,we.T=K,g(),K=we.T)),we.T=K;V.cue<Kc.length&&Kc[V.cue].at<=we.T;)Me(Kc[V.cue].sound),V.cue++;if(we.T>=p3){V.done=!0,he.getState().implantOnline(V.reply?.implant??null);return}}we.waiting&&!we.fault&&we.W>=V.nextIdle&&(V.idleAt=we.W,V.nextIdle=we.W+2.6+Math.random()*4.2,we.W-V.lastIdleSound>9&&Math.random()<.45&&(V.lastIdleSound=we.W,Me("install_idle"))),we.idle=we.waiting?.9*$n(we.W,V.idleAt,.28):0,u(),ue=requestAnimationFrame(oe)};return ue=requestAnimationFrame(oe),()=>{V.alive=!1,cancelAnimationFrame(ue)}},[]);const y=d.current,w=y.fault?[{key:"R",label:"Retry the installation",primary:!0,act:v},{key:"Q",label:"Close",act:Vr}]:y.waiting?n?[{key:"Y",label:"Install the Neural-Link",primary:!0,act:g},{key:"N",label:"Cancel",act:Vr}]:[{key:"Q",label:"Close",act:Vr}]:null,E=q.useRef(w);E.current=w,q.useEffect(()=>{const V=de=>{const z=E.current;if(!z||de.repeat)return;const ue=de.key.length===1?de.key.toUpperCase():de.key,oe=ue==="Enter"?z[0]:z.find(O=>O.key===ue);oe&&(de.preventDefault(),oe.act())};return window.addEventListener("keydown",V),()=>window.removeEventListener("keydown",V)},[]);const{T:_,W:M}=y,{Post:L,Kernel:A,Verify:R,Done:k}=ct,D=E3(y),U=Rt.enter(_,L,L+.4),$=Rt.draw(_,k+2.35,k+2.7),te=Rt.draw(_,k+2.7,k+2.95),T=nl(.004,1,U)*(1-$*.996),P=1-te,re=1+.9*$n(_,L,.45)+1.6*$*(1-te),J=1-.7*Rt.draw(_,R+.3,R+.9)*(1-Rt.draw(_,R+2.2,R+2.5)),ae=1-Rt.draw(_,k+.3,k+.7),ve=(V,de)=>_>=V&&_<de;return l.jsx("div",{className:"holo-os",role:"dialog","aria-modal":"true","aria-label":"Kiroshi Neural-Link installation",children:l.jsxs("div",{className:"holo-os__screen",style:{transform:`scale(${P}, ${T})`,filter:re!==1?`brightness(${re.toFixed(2)})`:void 0},children:[l.jsx(w3,{params:D}),l.jsxs(D3,{W:M,g:D.glitch,children:[ve(L,A+.5)&&l.jsx(k3,{T:_,W:M}),ve(A-.2,k+.8)&&l.jsxs(l.Fragment,{children:[l.jsx(R3,{T:_}),l.jsx("div",{style:{position:"absolute",inset:0,opacity:J*ae},children:l.jsx(C3,{v:y,log:c,ctx:a,choices:w})}),l.jsx(N3,{v:y,ctx:a}),l.jsx(P3,{v:y})]}),_>=k+.4&&l.jsx(L3,{T:_,W:M,ctx:a})]}),l.jsx("div",{className:"holo-os__scan","aria-hidden":!0}),l.jsx("div",{className:"holo-os__vignette","aria-hidden":!0})]})})}function U3(){const n=he(t=>t.state?.implant?.selfInstall!==!1),[e]=q.useState(()=>be().implantAutoStart);return q.useEffect(()=>{be().implantAutoStart&&he.setState({implantAutoStart:!1})},[]),l.jsx("div",{className:"implant",children:l.jsx(I3,{selfInstall:n,autoStart:e})})}const F3=1500,O3=330;let iv=-1;function j3(){const n=he(d=>d.phase),e=he(d=>d.openSeq),t=he(d=>!!d.state?.ready),s=he(mf),a=eo().style!=="sao",c=q.useRef(null),u=n==="open"||n==="opening";return q.useEffect(()=>{if(n==="opening"){iv!==e&&(iv=e,mf(be())||Me("open"));const d=window.setTimeout(()=>he.getState().setPhase("open"),sr()?50:F3);return()=>window.clearTimeout(d)}if(n==="closing"){const d=window.setTimeout(()=>he.getState().setPhase("closed"),sr()?30:O3);return()=>window.clearTimeout(d)}},[n,e]),q.useEffect(()=>{const d=x=>{document.documentElement.dataset.input="mouse",Zy(x.clientX/window.innerWidth*2-1,x.clientY/window.innerHeight*2-1)},f=x=>{(x.key.startsWith("Arrow")||x.key==="Enter")&&(document.documentElement.dataset.input="kbd")};window.addEventListener("pointermove",d,{passive:!0}),window.addEventListener("keydown",f);let p=0,g=performance.now();const v=x=>{p=requestAnimationFrame(v);const y=c.current;!y||sr()||(Qy(Math.min(.1,Math.max(0,(x-g)/1e3))),g=x,y.style.setProperty("--mx",ri.x.toFixed(4)),y.style.setProperty("--my",ri.y.toFixed(4)))};return u&&(p=requestAnimationFrame(v)),()=>{window.removeEventListener("pointermove",d),window.removeEventListener("keydown",f),cancelAnimationFrame(p)}},[u]),q.useEffect(()=>{if(!u||!a||sr())return;let d=0,f=0;const p=()=>{const g=Array.from(document.querySelectorAll(".plane .nl3d")),v=g[Math.floor(Math.random()*g.length)];v&&(v.classList.add("is-glitch"),f=window.setTimeout(()=>v.classList.remove("is-glitch"),180+Math.random()*160)),d=window.setTimeout(p,4200+Math.random()*5200)};return d=window.setTimeout(p,3600),()=>{window.clearTimeout(d),window.clearTimeout(f)}},[u,a]),l.jsxs("div",{className:`shell is-${n}`,children:[n==="opening"&&!s&&l.jsx(qy,{}),!s&&!a&&l.jsx(Ky,{running:u}),!s&&a&&l.jsx(tS,{running:u}),l.jsx("div",{className:"plane",ref:c,children:t?s?l.jsx(U3,{}):l.jsx(z3,{}):l.jsx(rT,{})}),!s&&a&&t&&l.jsx(sS,{})]},e)}function z3(){const n=he(g=>g.state),e=he(g=>g.recentsSeenAt),t=he(g=>g.menu),s=he(g=>g.callView),a=he(g=>!!g.state?.call),c=Du(n,e),u=Pv(n,c,a),d=XE(u.length),f=u.findIndex(g=>g.id==="call"?s:g.id===t),p=f>=0?d.centers[f]:540;return l.jsxs(l.Fragment,{children:[l.jsx(NE,{}),l.jsx(qE,{items:u,layout:d}),t&&!s&&!t.startsWith("app:")&&l.jsx(ZE,{anchorY:p,missed:c},t),l.jsx(iT,{})]})}function df(){const n=be();if(n.phase==="closed"||n.phase==="closing"||n.callView)return null;const e=_p(n);return e&&e.app==="messages"&&e.screen==="thread"?e.threadId:null}function B3(){const n=be();if(n.phase==="closed"||n.phase==="closing"||n.callView)return null;const e=_p(n);return e&&e.app==="social"?e:null}function H3(n){const e=be(),t=B3();switch(n.kind){case"post":n.post&&!n.post.mine&&e.pushFresh(n.post);break;case"ping":e.setSocialUnread(n.unread),t?.app==="social"&&t.screen==="pings"&&xf();break;case"stats":{const s=e.postLive[n.postId]?.replies??e.screamThreads[n.postId]?.post?.replies??0;e.setPostLive(n.postId,{cred:n.cred,echoes:n.echoes,replies:n.replies}),t?.app==="social"&&t.screen==="thread"&&t.postId===n.postId&&n.replies>s&&zv(n.postId);break}case"deleted":e.removePost(n.postId);break}}function hf(n,e){if(!e)return;const t=n?n.participants.filter(a=>!a.isMe&&a.state==="connected").length:0,s=e.participants.filter(a=>!a.isMe&&a.state==="connected").length;e.phase==="active"&&(!n||n.phase!=="active"||n.id!==e.id)?Me("connect"):e.phase==="active"&&n?.phase==="active"&&s>t&&Me("receive")}function V3(){q.useEffect(()=>{const n=[Un("nl:state",e=>{if(!e)return;const t=be(),s=t.state?.call;t.applyState(e),be().setCall(e.call??null),hf(s,e.call??null);const a=df();a!=null&&mu(a)}),Un("nl:patch",e=>{if(!e)return;const t=be().state?.call;be().applyPatch(e),"call"in e&&(be().setCall(e.call??null),hf(t,e.call??null))}),Un("nl:open",e=>{be().openUi(e??{}),e?.app==="messages"&&typeof e.threadId=="number"&&!gf(be())&&mu(e.threadId)}),Un("nl:close",()=>{const e=be();e.phase==="closed"||e.phase==="closing"||(Zg(),Me("close"),e.closeUi())}),Un("nl:thread",e=>{e&&typeof e.threadId=="number"&&be().threadLoaded(e)}),Un("nl:message",e=>{e?.message&&(be().messageArrived(e),!(e.message.mine||e.message.kind==="system")&&df()===e.message.threadId&&(be().setUnread(e.message.threadId,0),Tt("threads.read",{threadId:e.message.threadId},{quiet:!0}),Me("receive")))}),Un("nl:messageUpdate",e=>{e?.message&&typeof e.message.id=="number"&&be().messageUpdated(e.message)}),Un("nl:call",e=>{const t=be().state?.call;be().setCall(e??null),hf(t,e??null)}),Un("nl:callEnded",e=>{e&&(be().setEnded(e),Me("disconnect"))}),Un("nl:talkers",e=>be().setTalkers(e??{})),Un("nl:toast",e=>{if(!e)return;const t=be();gf(t)||e.kind==="message"&&e.threadId!=null&&df()===e.threadId||(t.pushToast({...e,at:e.at??Date.now()}),gp(t).dnd)||(e.kind==="message"?Me("chime"):e.kind==="error"?Me("error"):Me("toast"))}),Un("nl:clock",e=>{e&&be().setClock(e)}),Un("nl:social",e=>{e&&typeof e.kind=="string"&&H3(e)}),Un("nl:keys",e=>{e&&typeof e.toggle=="string"&&e.toggle&&be().setToggleKey(e.toggle)}),Un("nl:focus",e=>{const t=!!e?.keyboard;be().setKeyboard(t),t||Zg()})];return Xy(),()=>n.forEach(e=>e())},[])}function G3(){const n=he(g=>g.state?.call??null),e=he(g=>g.state?.contacts??kn),t=he(g=>g.talkers),s=he(g=>g.phase!=="closed"&&g.phase!=="closing"&&g.state!==null),a=he(g=>g.callView),c=Kv(n?.startedAt??null);if(!n||n.phase==="incoming"||s&&a)return null;const u=n.participants.find(g=>g.isMe),d=!!u&&!n.muted&&(t[u.lineId]??0)>.05,f=n.participants.some(g=>!g.isMe&&(t[g.lineId]??0)>.05),p=Math.max(0,...Object.values(t));return l.jsxs("button",{type:"button",className:`callhud ${s?"nl-hit":""} ${f||d?"is-talking":""} ${n.muted?"is-muted":""}`,style:{"--level":p.toFixed(2)},onClick:()=>{s&&(Me("select"),he.getState().setCallView(!0))},tabIndex:s?0:-1,children:[l.jsx("span",{className:"callhud__glow","aria-hidden":!0}),l.jsx("span",{className:"callhud__icon",children:n.group?l.jsx(Ln,{size:16}):l.jsx(Ji,{size:16})}),l.jsx("span",{className:"callhud__name",children:Yv(n,e)}),l.jsx("span",{className:"callhud__time mono",children:n.phase==="outgoing"||!c?"linking…":c}),l.jsx("span",{className:`callhud__mic ${d?"is-live":""}`,children:n.muted?l.jsx(vf,{size:15}):l.jsx(wv,{size:15})})]})}function W3(){const n=he(a=>a.ended),e=he(a=>a.state?.contacts??kn);if(q.useEffect(()=>{if(!n)return;const a=window.setTimeout(()=>he.getState().setEnded(null),2500);return()=>window.clearTimeout(a)},[n]),!n)return null;const t=n.number?Fi(e,n.number,n.name):n.name,s=n.reason!=="hangup";return l.jsxs("div",{className:`endcard ${s?"is-bad":""}`,role:"status",children:[l.jsx("span",{className:"endcard__icon",children:l.jsx(Pu,{size:20})}),l.jsxs("span",{className:"endcard__text",children:[l.jsx("span",{className:"endcard__reason label",children:PE(n.reason)}),l.jsxs("span",{className:"endcard__who",children:[t??"Neural call",n.duration?l.jsxs("span",{className:"mono",children:[" · ",pp(n.duration)]}):null]})]}),l.jsx("span",{className:"endcard__bar","aria-hidden":!0})]},n.key)}const sv=5e3,rv={message:l.jsx(Zi,{size:20}),call:l.jsx(cl,{size:20}),missed:l.jsx(Ru,{size:20}),info:l.jsx(Sp,{size:20}),error:l.jsx(Tp,{size:20}),social:l.jsx($r,{size:20})};function $3(){const n=he(t=>t.toasts),e=he(t=>t.phase==="open"||t.phase==="opening");return l.jsx("div",{className:`toasts ${e?"is-open":""}`,"aria-live":"polite",children:n.map((t,s)=>l.jsx(X3,{t,depth:n.length-1-s,clickable:e},t.key))})}function X3({t:n,depth:e,clickable:t}){const[s,a]=q.useState(!1);q.useEffect(()=>{const d=Math.max(400,sv-(Date.now()-n.born)),f=window.setTimeout(()=>a(!0),d),p=window.setTimeout(()=>he.getState().dismissToast(n.key),d+320);return()=>{window.clearTimeout(f),window.clearTimeout(p)}},[n.key,n.born]);const c=t&&(n.kind==="message"&&n.threadId!=null||(n.kind==="missed"||n.kind==="call")&&!!n.number||n.kind==="social"&&(n.postId!=null||!!n.handle)),u=()=>{t&&(n.kind==="message"&&n.threadId!=null?$a(n.threadId,"reset"):(n.kind==="missed"||n.kind==="call")&&n.number?Es(n.number):n.kind==="social"&&n.postId!=null?ul(n.postId,"reset"):n.kind==="social"&&n.handle?rr(n.handle,"reset"):Me("back"),he.getState().dismissToast(n.key))};return l.jsxs("div",{className:`toast toast--${n.kind} ${s?"is-leaving":""} ${t?"nl-hit":""} ${c?"is-actionable":""}`,style:{"--depth":e},onClick:u,role:"status",children:[l.jsx("span",{className:"toast__icon",children:rv[n.kind]??rv.info}),l.jsxs("span",{className:"toast__text",children:[l.jsxs("span",{className:"toast__top",children:[l.jsx("span",{className:"toast__title",children:n.title}),l.jsx("span",{className:"toast__time mono",children:Wa(n.at||Date.now())})]}),l.jsx("span",{className:"toast__body",children:n.body})]}),l.jsx("span",{className:"toast__life",style:{animationDuration:`${sv}ms`},"aria-hidden":!0}),l.jsx("span",{className:"toast__scan","aria-hidden":!0})]})}const q3=q.lazy(()=>dp(()=>import("./chunk-MockPanel.js"),__vite__mapDeps([0,1]),import.meta.url));function Y3(){V3(),$E(),Hy();const n=he(s=>s.phase!=="closed"&&s.state!==null),e=he(gf),t=mv()&&new URLSearchParams(location.search).get("dev")!=="0";return l.jsxs(l.Fragment,{children:[l.jsxs(By,{children:[n&&l.jsx(j3,{}),!e&&l.jsxs(l.Fragment,{children:[l.jsx(eT,{}),l.jsx(G3,{}),l.jsx(W3,{}),l.jsx($3,{})]})]}),t&&l.jsx(q.Suspense,{fallback:null,children:l.jsx(q3,{})})]})}class K3 extends q.Component{state={failed:!1};static getDerivedStateFromError(){return{failed:!0}}componentDidCatch(e,t){console.error("[neuralink] render failed",e,t.componentStack),window.setTimeout(()=>this.setState({failed:!1}),1500)}render(){return this.state.failed?null:this.props.children}}async function Z3(){if(!window.Open77){const{installMockBridge:n}=await dp(async()=>{const{installMockBridge:e}=await import("./chunk-mock.js");return{installMockBridge:e}},[],import.meta.url);n()}wy.createRoot(document.getElementById("root")).render(l.jsx(q.StrictMode,{children:l.jsx(K3,{children:l.jsx(Y3,{})})}))}Z3();export{R2 as $,uu as A,Vo as B,kS as C,ff as D,XS as E,YS as F,ZS as G,av as H,JS as I,i2 as J,Mv as K,xp as L,o2 as M,fp as N,c2 as O,d2 as P,f2 as Q,m2 as R,Ag as S,_2 as T,x2 as U,Cu as V,M2 as W,w2 as X,b2 as Y,Ev as Z,rl as _,Or as a,vE as a$,yp as a0,L2 as a1,Sp as a2,U2 as a3,zg as a4,z2 as a5,ll as a6,$r as a7,Nu as a8,Zi as a9,cr as aA,NM as aB,wp as aC,kM as aD,UM as aE,DM as aF,OM as aG,zM as aH,HM as aI,GM as aJ,$M as aK,Ms as aL,YM as aM,ZM as aN,hu as aO,Tp as aP,tE as aQ,iE as aR,rE as aS,oE as aT,bp as aU,Qi as aV,no as aW,hE as aX,Ln as aY,mE as aZ,Nv as a_,du as aa,wv as ab,vf as ac,q2 as ad,K2 as ae,Q2 as af,eM as ag,Tv as ah,al as ai,bv as aj,Ji as ak,cl as al,aM as am,Ru as an,Pu as ao,uM as ap,fM as aq,mM as ar,_M as as,xM as at,Mp as au,ku as av,Av as aw,Ep as ax,TM as ay,Cv as az,yv as b,yE as b0,ME as b1,io as b2,Ap as b3,ge as c,dS as d,fS as e,Sv as f,gS as g,_f as h,vS as i,l as j,SS as k,sl as l,wS as m,bS as n,CS as o,RS as p,DS as q,q as r,zS as s,US as t,he as u,OS as v,vp as w,VS as x,WS as y,t2 as z};
