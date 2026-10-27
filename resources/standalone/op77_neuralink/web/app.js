const __vite__mapDeps=(i,m=__vite__mapDeps,d=(m.f||(m.f=["./chunk-MockPanel.js","./chunk-mock.js"])))=>i.map(i=>d[i]);
(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const a of document.querySelectorAll('link[rel="modulepreload"]'))r(a);new MutationObserver(a=>{for(const c of a)if(c.type==="childList")for(const u of c.addedNodes)u.tagName==="LINK"&&u.rel==="modulepreload"&&r(u)}).observe(document,{childList:!0,subtree:!0});function t(a){const c={};return a.integrity&&(c.integrity=a.integrity),a.referrerPolicy&&(c.referrerPolicy=a.referrerPolicy),a.crossOrigin==="use-credentials"?c.credentials="include":a.crossOrigin==="anonymous"?c.credentials="omit":c.credentials="same-origin",c}function r(a){if(a.ep)return;a.ep=!0;const c=t(a);fetch(a.href,c)}})();const dy="modulepreload",fy=function(n,e){return new URL(n,e).href},fg={},dp=function(e,t,r){let a=Promise.resolve();if(t&&t.length>0){let u=function(g){return Promise.all(g.map(y=>Promise.resolve(y).then(v=>({status:"fulfilled",value:v}),v=>({status:"rejected",reason:v}))))};const d=document.getElementsByTagName("link"),h=document.querySelector("meta[property=csp-nonce]"),p=h?.nonce||h?.getAttribute("nonce");a=u(t.map(g=>{if(g=fy(g,r),g in fg)return;fg[g]=!0;const y=g.endsWith(".css"),v=y?'[rel="stylesheet"]':"";if(!!r)for(let E=d.length-1;E>=0;E--){const _=d[E];if(_.href===g&&(!y||_.rel==="stylesheet"))return}else if(document.querySelector(`link[href="${g}"]${v}`))return;const w=document.createElement("link");if(w.rel=y?"stylesheet":dy,y||(w.as="script"),w.crossOrigin="",w.href=g,p&&w.setAttribute("nonce",p),document.head.appendChild(w),y)return new Promise((E,_)=>{w.addEventListener("load",E),w.addEventListener("error",()=>_(new Error(`Unable to preload CSS for ${g}`)))})}))}function c(u){const d=new Event("vite:preloadError",{cancelable:!0});if(d.payload=u,window.dispatchEvent(d),!d.defaultPrevented)throw u}return a.then(u=>{for(const d of u||[])d.status==="rejected"&&c(d.reason);return e().catch(c)})};function hy(n){return n&&n.__esModule&&Object.prototype.hasOwnProperty.call(n,"default")?n.default:n}var xf={exports:{}},Bo={},yf={exports:{}},ft={};/**
 * @license React
 * react.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var hg;function py(){if(hg)return ft;hg=1;var n=Symbol.for("react.element"),e=Symbol.for("react.portal"),t=Symbol.for("react.fragment"),r=Symbol.for("react.strict_mode"),a=Symbol.for("react.profiler"),c=Symbol.for("react.provider"),u=Symbol.for("react.context"),d=Symbol.for("react.forward_ref"),h=Symbol.for("react.suspense"),p=Symbol.for("react.memo"),g=Symbol.for("react.lazy"),y=Symbol.iterator;function v(O){return O===null||typeof O!="object"?null:(O=y&&O[y]||O["@@iterator"],typeof O=="function"?O:null)}var x={isMounted:function(){return!1},enqueueForceUpdate:function(){},enqueueReplaceState:function(){},enqueueSetState:function(){}},w=Object.assign,E={};function _(O,le,we){this.props=O,this.context=le,this.refs=E,this.updater=we||x}_.prototype.isReactComponent={},_.prototype.setState=function(O,le){if(typeof O!="object"&&typeof O!="function"&&O!=null)throw Error("setState(...): takes an object of state variables to update or a function which returns an object of state variables.");this.updater.enqueueSetState(this,O,le,"setState")},_.prototype.forceUpdate=function(O){this.updater.enqueueForceUpdate(this,O,"forceUpdate")};function M(){}M.prototype=_.prototype;function k(O,le,we){this.props=O,this.context=le,this.refs=E,this.updater=we||x}var A=k.prototype=new M;A.constructor=k,w(A,_.prototype),A.isPureReactComponent=!0;var R=Array.isArray,L=Object.prototype.hasOwnProperty,D={current:null},U={key:!0,ref:!0,__self:!0,__source:!0};function $(O,le,we){var K,he={},Te=null,Ae=null;if(le!=null)for(K in le.ref!==void 0&&(Ae=le.ref),le.key!==void 0&&(Te=""+le.key),le)L.call(le,K)&&!U.hasOwnProperty(K)&&(he[K]=le[K]);var Ie=arguments.length-2;if(Ie===1)he.children=we;else if(1<Ie){for(var Ue=Array(Ie),st=0;st<Ie;st++)Ue[st]=arguments[st+2];he.children=Ue}if(O&&O.defaultProps)for(K in Ie=O.defaultProps,Ie)he[K]===void 0&&(he[K]=Ie[K]);return{$$typeof:n,type:O,key:Te,ref:Ae,props:he,_owner:D.current}}function te(O,le){return{$$typeof:n,type:O.type,key:le,ref:O.ref,props:O.props,_owner:O._owner}}function T(O){return typeof O=="object"&&O!==null&&O.$$typeof===n}function P(O){var le={"=":"=0",":":"=2"};return"$"+O.replace(/[=:]/g,function(we){return le[we]})}var se=/\/+/g;function J(O,le){return typeof O=="object"&&O!==null&&O.key!=null?P(""+O.key):le.toString(36)}function ae(O,le,we,K,he){var Te=typeof O;(Te==="undefined"||Te==="boolean")&&(O=null);var Ae=!1;if(O===null)Ae=!0;else switch(Te){case"string":case"number":Ae=!0;break;case"object":switch(O.$$typeof){case n:case e:Ae=!0}}if(Ae)return Ae=O,he=he(Ae),O=K===""?"."+J(Ae,0):K,R(he)?(we="",O!=null&&(we=O.replace(se,"$&/")+"/"),ae(he,le,we,"",function(st){return st})):he!=null&&(T(he)&&(he=te(he,we+(!he.key||Ae&&Ae.key===he.key?"":(""+he.key).replace(se,"$&/")+"/")+O)),le.push(he)),1;if(Ae=0,K=K===""?".":K+":",R(O))for(var Ie=0;Ie<O.length;Ie++){Te=O[Ie];var Ue=K+J(Te,Ie);Ae+=ae(Te,le,we,Ue,he)}else if(Ue=v(O),typeof Ue=="function")for(O=Ue.call(O),Ie=0;!(Te=O.next()).done;)Te=Te.value,Ue=K+J(Te,Ie++),Ae+=ae(Te,le,we,Ue,he);else if(Te==="object")throw le=String(O),Error("Objects are not valid as a React child (found: "+(le==="[object Object]"?"object with keys {"+Object.keys(O).join(", ")+"}":le)+"). If you meant to render a collection of children, use an array instead.");return Ae}function ve(O,le,we){if(O==null)return O;var K=[],he=0;return ae(O,K,"","",function(Te){return le.call(we,Te,he++)}),K}function V(O){if(O._status===-1){var le=O._result;le=le(),le.then(function(we){(O._status===0||O._status===-1)&&(O._status=1,O._result=we)},function(we){(O._status===0||O._status===-1)&&(O._status=2,O._result=we)}),O._status===-1&&(O._status=0,O._result=le)}if(O._status===1)return O._result.default;throw O._result}var de={current:null},z={transition:null},ue={ReactCurrentDispatcher:de,ReactCurrentBatchConfig:z,ReactCurrentOwner:D};function oe(){throw Error("act(...) is not supported in production builds of React.")}return ft.Children={map:ve,forEach:function(O,le,we){ve(O,function(){le.apply(this,arguments)},we)},count:function(O){var le=0;return ve(O,function(){le++}),le},toArray:function(O){return ve(O,function(le){return le})||[]},only:function(O){if(!T(O))throw Error("React.Children.only expected to receive a single React element child.");return O}},ft.Component=_,ft.Fragment=t,ft.Profiler=a,ft.PureComponent=k,ft.StrictMode=r,ft.Suspense=h,ft.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED=ue,ft.act=oe,ft.cloneElement=function(O,le,we){if(O==null)throw Error("React.cloneElement(...): The argument must be a React element, but you passed "+O+".");var K=w({},O.props),he=O.key,Te=O.ref,Ae=O._owner;if(le!=null){if(le.ref!==void 0&&(Te=le.ref,Ae=D.current),le.key!==void 0&&(he=""+le.key),O.type&&O.type.defaultProps)var Ie=O.type.defaultProps;for(Ue in le)L.call(le,Ue)&&!U.hasOwnProperty(Ue)&&(K[Ue]=le[Ue]===void 0&&Ie!==void 0?Ie[Ue]:le[Ue])}var Ue=arguments.length-2;if(Ue===1)K.children=we;else if(1<Ue){Ie=Array(Ue);for(var st=0;st<Ue;st++)Ie[st]=arguments[st+2];K.children=Ie}return{$$typeof:n,type:O.type,key:he,ref:Te,props:K,_owner:Ae}},ft.createContext=function(O){return O={$$typeof:u,_currentValue:O,_currentValue2:O,_threadCount:0,Provider:null,Consumer:null,_defaultValue:null,_globalName:null},O.Provider={$$typeof:c,_context:O},O.Consumer=O},ft.createElement=$,ft.createFactory=function(O){var le=$.bind(null,O);return le.type=O,le},ft.createRef=function(){return{current:null}},ft.forwardRef=function(O){return{$$typeof:d,render:O}},ft.isValidElement=T,ft.lazy=function(O){return{$$typeof:g,_payload:{_status:-1,_result:O},_init:V}},ft.memo=function(O,le){return{$$typeof:p,type:O,compare:le===void 0?null:le}},ft.startTransition=function(O){var le=z.transition;z.transition={};try{O()}finally{z.transition=le}},ft.unstable_act=oe,ft.useCallback=function(O,le){return de.current.useCallback(O,le)},ft.useContext=function(O){return de.current.useContext(O)},ft.useDebugValue=function(){},ft.useDeferredValue=function(O){return de.current.useDeferredValue(O)},ft.useEffect=function(O,le){return de.current.useEffect(O,le)},ft.useId=function(){return de.current.useId()},ft.useImperativeHandle=function(O,le,we){return de.current.useImperativeHandle(O,le,we)},ft.useInsertionEffect=function(O,le){return de.current.useInsertionEffect(O,le)},ft.useLayoutEffect=function(O,le){return de.current.useLayoutEffect(O,le)},ft.useMemo=function(O,le){return de.current.useMemo(O,le)},ft.useReducer=function(O,le,we){return de.current.useReducer(O,le,we)},ft.useRef=function(O){return de.current.useRef(O)},ft.useState=function(O){return de.current.useState(O)},ft.useSyncExternalStore=function(O,le,we){return de.current.useSyncExternalStore(O,le,we)},ft.useTransition=function(){return de.current.useTransition()},ft.version="18.3.1",ft}var pg;function fp(){return pg||(pg=1,yf.exports=py()),yf.exports}/**
 * @license React
 * react-jsx-runtime.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var mg;function my(){if(mg)return Bo;mg=1;var n=fp(),e=Symbol.for("react.element"),t=Symbol.for("react.fragment"),r=Object.prototype.hasOwnProperty,a=n.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED.ReactCurrentOwner,c={key:!0,ref:!0,__self:!0,__source:!0};function u(d,h,p){var g,y={},v=null,x=null;p!==void 0&&(v=""+p),h.key!==void 0&&(v=""+h.key),h.ref!==void 0&&(x=h.ref);for(g in h)r.call(h,g)&&!c.hasOwnProperty(g)&&(y[g]=h[g]);if(d&&d.defaultProps)for(g in h=d.defaultProps,h)y[g]===void 0&&(y[g]=h[g]);return{$$typeof:e,type:d,key:v,ref:x,props:y,_owner:a.current}}return Bo.Fragment=t,Bo.jsx=u,Bo.jsxs=u,Bo}var gg;function gy(){return gg||(gg=1,xf.exports=my()),xf.exports}var l=gy(),q=fp();const Kc=hy(q);var Sc={},Sf={exports:{}},Vn={},Mf={exports:{}},Ef={};/**
 * @license React
 * scheduler.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var _g;function _y(){return _g||(_g=1,(function(n){function e(z,ue){var oe=z.length;z.push(ue);e:for(;0<oe;){var O=oe-1>>>1,le=z[O];if(0<a(le,ue))z[O]=ue,z[oe]=le,oe=O;else break e}}function t(z){return z.length===0?null:z[0]}function r(z){if(z.length===0)return null;var ue=z[0],oe=z.pop();if(oe!==ue){z[0]=oe;e:for(var O=0,le=z.length,we=le>>>1;O<we;){var K=2*(O+1)-1,he=z[K],Te=K+1,Ae=z[Te];if(0>a(he,oe))Te<le&&0>a(Ae,he)?(z[O]=Ae,z[Te]=oe,O=Te):(z[O]=he,z[K]=oe,O=K);else if(Te<le&&0>a(Ae,oe))z[O]=Ae,z[Te]=oe,O=Te;else break e}}return ue}function a(z,ue){var oe=z.sortIndex-ue.sortIndex;return oe!==0?oe:z.id-ue.id}if(typeof performance=="object"&&typeof performance.now=="function"){var c=performance;n.unstable_now=function(){return c.now()}}else{var u=Date,d=u.now();n.unstable_now=function(){return u.now()-d}}var h=[],p=[],g=1,y=null,v=3,x=!1,w=!1,E=!1,_=typeof setTimeout=="function"?setTimeout:null,M=typeof clearTimeout=="function"?clearTimeout:null,k=typeof setImmediate<"u"?setImmediate:null;typeof navigator<"u"&&navigator.scheduling!==void 0&&navigator.scheduling.isInputPending!==void 0&&navigator.scheduling.isInputPending.bind(navigator.scheduling);function A(z){for(var ue=t(p);ue!==null;){if(ue.callback===null)r(p);else if(ue.startTime<=z)r(p),ue.sortIndex=ue.expirationTime,e(h,ue);else break;ue=t(p)}}function R(z){if(E=!1,A(z),!w)if(t(h)!==null)w=!0,V(L);else{var ue=t(p);ue!==null&&de(R,ue.startTime-z)}}function L(z,ue){w=!1,E&&(E=!1,M($),$=-1),x=!0;var oe=v;try{for(A(ue),y=t(h);y!==null&&(!(y.expirationTime>ue)||z&&!P());){var O=y.callback;if(typeof O=="function"){y.callback=null,v=y.priorityLevel;var le=O(y.expirationTime<=ue);ue=n.unstable_now(),typeof le=="function"?y.callback=le:y===t(h)&&r(h),A(ue)}else r(h);y=t(h)}if(y!==null)var we=!0;else{var K=t(p);K!==null&&de(R,K.startTime-ue),we=!1}return we}finally{y=null,v=oe,x=!1}}var D=!1,U=null,$=-1,te=5,T=-1;function P(){return!(n.unstable_now()-T<te)}function se(){if(U!==null){var z=n.unstable_now();T=z;var ue=!0;try{ue=U(!0,z)}finally{ue?J():(D=!1,U=null)}}else D=!1}var J;if(typeof k=="function")J=function(){k(se)};else if(typeof MessageChannel<"u"){var ae=new MessageChannel,ve=ae.port2;ae.port1.onmessage=se,J=function(){ve.postMessage(null)}}else J=function(){_(se,0)};function V(z){U=z,D||(D=!0,J())}function de(z,ue){$=_(function(){z(n.unstable_now())},ue)}n.unstable_IdlePriority=5,n.unstable_ImmediatePriority=1,n.unstable_LowPriority=4,n.unstable_NormalPriority=3,n.unstable_Profiling=null,n.unstable_UserBlockingPriority=2,n.unstable_cancelCallback=function(z){z.callback=null},n.unstable_continueExecution=function(){w||x||(w=!0,V(L))},n.unstable_forceFrameRate=function(z){0>z||125<z?console.error("forceFrameRate takes a positive int between 0 and 125, forcing frame rates higher than 125 fps is not supported"):te=0<z?Math.floor(1e3/z):5},n.unstable_getCurrentPriorityLevel=function(){return v},n.unstable_getFirstCallbackNode=function(){return t(h)},n.unstable_next=function(z){switch(v){case 1:case 2:case 3:var ue=3;break;default:ue=v}var oe=v;v=ue;try{return z()}finally{v=oe}},n.unstable_pauseExecution=function(){},n.unstable_requestPaint=function(){},n.unstable_runWithPriority=function(z,ue){switch(z){case 1:case 2:case 3:case 4:case 5:break;default:z=3}var oe=v;v=z;try{return ue()}finally{v=oe}},n.unstable_scheduleCallback=function(z,ue,oe){var O=n.unstable_now();switch(typeof oe=="object"&&oe!==null?(oe=oe.delay,oe=typeof oe=="number"&&0<oe?O+oe:O):oe=O,z){case 1:var le=-1;break;case 2:le=250;break;case 5:le=1073741823;break;case 4:le=1e4;break;default:le=5e3}return le=oe+le,z={id:g++,callback:ue,priorityLevel:z,startTime:oe,expirationTime:le,sortIndex:-1},oe>O?(z.sortIndex=oe,e(p,z),t(h)===null&&z===t(p)&&(E?(M($),$=-1):E=!0,de(R,oe-O))):(z.sortIndex=le,e(h,z),w||x||(w=!0,V(L))),z},n.unstable_shouldYield=P,n.unstable_wrapCallback=function(z){var ue=v;return function(){var oe=v;v=ue;try{return z.apply(this,arguments)}finally{v=oe}}}})(Ef)),Ef}var vg;function vy(){return vg||(vg=1,Mf.exports=_y()),Mf.exports}/**
 * @license React
 * react-dom.production.min.js
 *
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */var xg;function xy(){if(xg)return Vn;xg=1;var n=fp(),e=vy();function t(i){for(var s="https://reactjs.org/docs/error-decoder.html?invariant="+i,o=1;o<arguments.length;o++)s+="&args[]="+encodeURIComponent(arguments[o]);return"Minified React error #"+i+"; visit "+s+" for the full message or use the non-minified dev environment for full errors and additional helpful warnings."}var r=new Set,a={};function c(i,s){u(i,s),u(i+"Capture",s)}function u(i,s){for(a[i]=s,i=0;i<s.length;i++)r.add(s[i])}var d=!(typeof window>"u"||typeof window.document>"u"||typeof window.document.createElement>"u"),h=Object.prototype.hasOwnProperty,p=/^[:A-Z_a-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD][:A-Z_a-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD\-.0-9\u00B7\u0300-\u036F\u203F-\u2040]*$/,g={},y={};function v(i){return h.call(y,i)?!0:h.call(g,i)?!1:p.test(i)?y[i]=!0:(g[i]=!0,!1)}function x(i,s,o,f){if(o!==null&&o.type===0)return!1;switch(typeof s){case"function":case"symbol":return!0;case"boolean":return f?!1:o!==null?!o.acceptsBooleans:(i=i.toLowerCase().slice(0,5),i!=="data-"&&i!=="aria-");default:return!1}}function w(i,s,o,f){if(s===null||typeof s>"u"||x(i,s,o,f))return!0;if(f)return!1;if(o!==null)switch(o.type){case 3:return!s;case 4:return s===!1;case 5:return isNaN(s);case 6:return isNaN(s)||1>s}return!1}function E(i,s,o,f,m,S,b){this.acceptsBooleans=s===2||s===3||s===4,this.attributeName=f,this.attributeNamespace=m,this.mustUseProperty=o,this.propertyName=i,this.type=s,this.sanitizeURL=S,this.removeEmptyString=b}var _={};"children dangerouslySetInnerHTML defaultValue defaultChecked innerHTML suppressContentEditableWarning suppressHydrationWarning style".split(" ").forEach(function(i){_[i]=new E(i,0,!1,i,null,!1,!1)}),[["acceptCharset","accept-charset"],["className","class"],["htmlFor","for"],["httpEquiv","http-equiv"]].forEach(function(i){var s=i[0];_[s]=new E(s,1,!1,i[1],null,!1,!1)}),["contentEditable","draggable","spellCheck","value"].forEach(function(i){_[i]=new E(i,2,!1,i.toLowerCase(),null,!1,!1)}),["autoReverse","externalResourcesRequired","focusable","preserveAlpha"].forEach(function(i){_[i]=new E(i,2,!1,i,null,!1,!1)}),"allowFullScreen async autoFocus autoPlay controls default defer disabled disablePictureInPicture disableRemotePlayback formNoValidate hidden loop noModule noValidate open playsInline readOnly required reversed scoped seamless itemScope".split(" ").forEach(function(i){_[i]=new E(i,3,!1,i.toLowerCase(),null,!1,!1)}),["checked","multiple","muted","selected"].forEach(function(i){_[i]=new E(i,3,!0,i,null,!1,!1)}),["capture","download"].forEach(function(i){_[i]=new E(i,4,!1,i,null,!1,!1)}),["cols","rows","size","span"].forEach(function(i){_[i]=new E(i,6,!1,i,null,!1,!1)}),["rowSpan","start"].forEach(function(i){_[i]=new E(i,5,!1,i.toLowerCase(),null,!1,!1)});var M=/[\-:]([a-z])/g;function k(i){return i[1].toUpperCase()}"accent-height alignment-baseline arabic-form baseline-shift cap-height clip-path clip-rule color-interpolation color-interpolation-filters color-profile color-rendering dominant-baseline enable-background fill-opacity fill-rule flood-color flood-opacity font-family font-size font-size-adjust font-stretch font-style font-variant font-weight glyph-name glyph-orientation-horizontal glyph-orientation-vertical horiz-adv-x horiz-origin-x image-rendering letter-spacing lighting-color marker-end marker-mid marker-start overline-position overline-thickness paint-order panose-1 pointer-events rendering-intent shape-rendering stop-color stop-opacity strikethrough-position strikethrough-thickness stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin stroke-miterlimit stroke-opacity stroke-width text-anchor text-decoration text-rendering underline-position underline-thickness unicode-bidi unicode-range units-per-em v-alphabetic v-hanging v-ideographic v-mathematical vector-effect vert-adv-y vert-origin-x vert-origin-y word-spacing writing-mode xmlns:xlink x-height".split(" ").forEach(function(i){var s=i.replace(M,k);_[s]=new E(s,1,!1,i,null,!1,!1)}),"xlink:actuate xlink:arcrole xlink:role xlink:show xlink:title xlink:type".split(" ").forEach(function(i){var s=i.replace(M,k);_[s]=new E(s,1,!1,i,"http://www.w3.org/1999/xlink",!1,!1)}),["xml:base","xml:lang","xml:space"].forEach(function(i){var s=i.replace(M,k);_[s]=new E(s,1,!1,i,"http://www.w3.org/XML/1998/namespace",!1,!1)}),["tabIndex","crossOrigin"].forEach(function(i){_[i]=new E(i,1,!1,i.toLowerCase(),null,!1,!1)}),_.xlinkHref=new E("xlinkHref",1,!1,"xlink:href","http://www.w3.org/1999/xlink",!0,!1),["src","href","action","formAction"].forEach(function(i){_[i]=new E(i,1,!1,i.toLowerCase(),null,!0,!0)});function A(i,s,o,f){var m=_.hasOwnProperty(s)?_[s]:null;(m!==null?m.type!==0:f||!(2<s.length)||s[0]!=="o"&&s[0]!=="O"||s[1]!=="n"&&s[1]!=="N")&&(w(s,o,m,f)&&(o=null),f||m===null?v(s)&&(o===null?i.removeAttribute(s):i.setAttribute(s,""+o)):m.mustUseProperty?i[m.propertyName]=o===null?m.type===3?!1:"":o:(s=m.attributeName,f=m.attributeNamespace,o===null?i.removeAttribute(s):(m=m.type,o=m===3||m===4&&o===!0?"":""+o,f?i.setAttributeNS(f,s,o):i.setAttribute(s,o))))}var R=n.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED,L=Symbol.for("react.element"),D=Symbol.for("react.portal"),U=Symbol.for("react.fragment"),$=Symbol.for("react.strict_mode"),te=Symbol.for("react.profiler"),T=Symbol.for("react.provider"),P=Symbol.for("react.context"),se=Symbol.for("react.forward_ref"),J=Symbol.for("react.suspense"),ae=Symbol.for("react.suspense_list"),ve=Symbol.for("react.memo"),V=Symbol.for("react.lazy"),de=Symbol.for("react.offscreen"),z=Symbol.iterator;function ue(i){return i===null||typeof i!="object"?null:(i=z&&i[z]||i["@@iterator"],typeof i=="function"?i:null)}var oe=Object.assign,O;function le(i){if(O===void 0)try{throw Error()}catch(o){var s=o.stack.trim().match(/\n( *(at )?)/);O=s&&s[1]||""}return`
`+O+i}var we=!1;function K(i,s){if(!i||we)return"";we=!0;var o=Error.prepareStackTrace;Error.prepareStackTrace=void 0;try{if(s)if(s=function(){throw Error()},Object.defineProperty(s.prototype,"props",{set:function(){throw Error()}}),typeof Reflect=="object"&&Reflect.construct){try{Reflect.construct(s,[])}catch(ie){var f=ie}Reflect.construct(i,[],s)}else{try{s.call()}catch(ie){f=ie}i.call(s.prototype)}else{try{throw Error()}catch(ie){f=ie}i()}}catch(ie){if(ie&&f&&typeof ie.stack=="string"){for(var m=ie.stack.split(`
`),S=f.stack.split(`
`),b=m.length-1,F=S.length-1;1<=b&&0<=F&&m[b]!==S[F];)F--;for(;1<=b&&0<=F;b--,F--)if(m[b]!==S[F]){if(b!==1||F!==1)do if(b--,F--,0>F||m[b]!==S[F]){var j=`
`+m[b].replace(" at new "," at ");return i.displayName&&j.includes("<anonymous>")&&(j=j.replace("<anonymous>",i.displayName)),j}while(1<=b&&0<=F);break}}}finally{we=!1,Error.prepareStackTrace=o}return(i=i?i.displayName||i.name:"")?le(i):""}function he(i){switch(i.tag){case 5:return le(i.type);case 16:return le("Lazy");case 13:return le("Suspense");case 19:return le("SuspenseList");case 0:case 2:case 15:return i=K(i.type,!1),i;case 11:return i=K(i.type.render,!1),i;case 1:return i=K(i.type,!0),i;default:return""}}function Te(i){if(i==null)return null;if(typeof i=="function")return i.displayName||i.name||null;if(typeof i=="string")return i;switch(i){case U:return"Fragment";case D:return"Portal";case te:return"Profiler";case $:return"StrictMode";case J:return"Suspense";case ae:return"SuspenseList"}if(typeof i=="object")switch(i.$$typeof){case P:return(i.displayName||"Context")+".Consumer";case T:return(i._context.displayName||"Context")+".Provider";case se:var s=i.render;return i=i.displayName,i||(i=s.displayName||s.name||"",i=i!==""?"ForwardRef("+i+")":"ForwardRef"),i;case ve:return s=i.displayName||null,s!==null?s:Te(i.type)||"Memo";case V:s=i._payload,i=i._init;try{return Te(i(s))}catch{}}return null}function Ae(i){var s=i.type;switch(i.tag){case 24:return"Cache";case 9:return(s.displayName||"Context")+".Consumer";case 10:return(s._context.displayName||"Context")+".Provider";case 18:return"DehydratedFragment";case 11:return i=s.render,i=i.displayName||i.name||"",s.displayName||(i!==""?"ForwardRef("+i+")":"ForwardRef");case 7:return"Fragment";case 5:return s;case 4:return"Portal";case 3:return"Root";case 6:return"Text";case 16:return Te(s);case 8:return s===$?"StrictMode":"Mode";case 22:return"Offscreen";case 12:return"Profiler";case 21:return"Scope";case 13:return"Suspense";case 19:return"SuspenseList";case 25:return"TracingMarker";case 1:case 0:case 17:case 2:case 14:case 15:if(typeof s=="function")return s.displayName||s.name||null;if(typeof s=="string")return s}return null}function Ie(i){switch(typeof i){case"boolean":case"number":case"string":case"undefined":return i;case"object":return i;default:return""}}function Ue(i){var s=i.type;return(i=i.nodeName)&&i.toLowerCase()==="input"&&(s==="checkbox"||s==="radio")}function st(i){var s=Ue(i)?"checked":"value",o=Object.getOwnPropertyDescriptor(i.constructor.prototype,s),f=""+i[s];if(!i.hasOwnProperty(s)&&typeof o<"u"&&typeof o.get=="function"&&typeof o.set=="function"){var m=o.get,S=o.set;return Object.defineProperty(i,s,{configurable:!0,get:function(){return m.call(this)},set:function(b){f=""+b,S.call(this,b)}}),Object.defineProperty(i,s,{enumerable:o.enumerable}),{getValue:function(){return f},setValue:function(b){f=""+b},stopTracking:function(){i._valueTracker=null,delete i[s]}}}}function yt(i){i._valueTracker||(i._valueTracker=st(i))}function pt(i){if(!i)return!1;var s=i._valueTracker;if(!s)return!0;var o=s.getValue(),f="";return i&&(f=Ue(i)?i.checked?"true":"false":i.value),i=f,i!==o?(s.setValue(i),!0):!1}function B(i){if(i=i||(typeof document<"u"?document:void 0),typeof i>"u")return null;try{return i.activeElement||i.body}catch{return i.body}}function _n(i,s){var o=s.checked;return oe({},s,{defaultChecked:void 0,defaultValue:void 0,value:void 0,checked:o??i._wrapperState.initialChecked})}function ht(i,s){var o=s.defaultValue==null?"":s.defaultValue,f=s.checked!=null?s.checked:s.defaultChecked;o=Ie(s.value!=null?s.value:o),i._wrapperState={initialChecked:f,initialValue:o,controlled:s.type==="checkbox"||s.type==="radio"?s.checked!=null:s.value!=null}}function _t(i,s){s=s.checked,s!=null&&A(i,"checked",s,!1)}function tt(i,s){_t(i,s);var o=Ie(s.value),f=s.type;if(o!=null)f==="number"?(o===0&&i.value===""||i.value!=o)&&(i.value=""+o):i.value!==""+o&&(i.value=""+o);else if(f==="submit"||f==="reset"){i.removeAttribute("value");return}s.hasOwnProperty("value")?it(i,s.type,o):s.hasOwnProperty("defaultValue")&&it(i,s.type,Ie(s.defaultValue)),s.checked==null&&s.defaultChecked!=null&&(i.defaultChecked=!!s.defaultChecked)}function kt(i,s,o){if(s.hasOwnProperty("value")||s.hasOwnProperty("defaultValue")){var f=s.type;if(!(f!=="submit"&&f!=="reset"||s.value!==void 0&&s.value!==null))return;s=""+i._wrapperState.initialValue,o||s===i.value||(i.value=s),i.defaultValue=s}o=i.name,o!==""&&(i.name=""),i.defaultChecked=!!i._wrapperState.initialChecked,o!==""&&(i.name=o)}function it(i,s,o){(s!=="number"||B(i.ownerDocument)!==i)&&(o==null?i.defaultValue=""+i._wrapperState.initialValue:i.defaultValue!==""+o&&(i.defaultValue=""+o))}var I=Array.isArray;function C(i,s,o,f){if(i=i.options,s){s={};for(var m=0;m<o.length;m++)s["$"+o[m]]=!0;for(o=0;o<i.length;o++)m=s.hasOwnProperty("$"+i[o].value),i[o].selected!==m&&(i[o].selected=m),m&&f&&(i[o].defaultSelected=!0)}else{for(o=""+Ie(o),s=null,m=0;m<i.length;m++){if(i[m].value===o){i[m].selected=!0,f&&(i[m].defaultSelected=!0);return}s!==null||i[m].disabled||(s=i[m])}s!==null&&(s.selected=!0)}}function Q(i,s){if(s.dangerouslySetInnerHTML!=null)throw Error(t(91));return oe({},s,{value:void 0,defaultValue:void 0,children:""+i._wrapperState.initialValue})}function me(i,s){var o=s.value;if(o==null){if(o=s.children,s=s.defaultValue,o!=null){if(s!=null)throw Error(t(92));if(I(o)){if(1<o.length)throw Error(t(93));o=o[0]}s=o}s==null&&(s=""),o=s}i._wrapperState={initialValue:Ie(o)}}function Se(i,s){var o=Ie(s.value),f=Ie(s.defaultValue);o!=null&&(o=""+o,o!==i.value&&(i.value=o),s.defaultValue==null&&i.defaultValue!==o&&(i.defaultValue=o)),f!=null&&(i.defaultValue=""+f)}function pe(i){var s=i.textContent;s===i._wrapperState.initialValue&&s!==""&&s!==null&&(i.value=s)}function Ze(i){switch(i){case"svg":return"http://www.w3.org/2000/svg";case"math":return"http://www.w3.org/1998/Math/MathML";default:return"http://www.w3.org/1999/xhtml"}}function Le(i,s){return i==null||i==="http://www.w3.org/1999/xhtml"?Ze(s):i==="http://www.w3.org/2000/svg"&&s==="foreignObject"?"http://www.w3.org/1999/xhtml":i}var Be,vt=(function(i){return typeof MSApp<"u"&&MSApp.execUnsafeLocalFunction?function(s,o,f,m){MSApp.execUnsafeLocalFunction(function(){return i(s,o,f,m)})}:i})(function(i,s){if(i.namespaceURI!=="http://www.w3.org/2000/svg"||"innerHTML"in i)i.innerHTML=s;else{for(Be=Be||document.createElement("div"),Be.innerHTML="<svg>"+s.valueOf().toString()+"</svg>",s=Be.firstChild;i.firstChild;)i.removeChild(i.firstChild);for(;s.firstChild;)i.appendChild(s.firstChild)}});function Ce(i,s){if(s){var o=i.firstChild;if(o&&o===i.lastChild&&o.nodeType===3){o.nodeValue=s;return}}i.textContent=s}var He={animationIterationCount:!0,aspectRatio:!0,borderImageOutset:!0,borderImageSlice:!0,borderImageWidth:!0,boxFlex:!0,boxFlexGroup:!0,boxOrdinalGroup:!0,columnCount:!0,columns:!0,flex:!0,flexGrow:!0,flexPositive:!0,flexShrink:!0,flexNegative:!0,flexOrder:!0,gridArea:!0,gridRow:!0,gridRowEnd:!0,gridRowSpan:!0,gridRowStart:!0,gridColumn:!0,gridColumnEnd:!0,gridColumnSpan:!0,gridColumnStart:!0,fontWeight:!0,lineClamp:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,tabSize:!0,widows:!0,zIndex:!0,zoom:!0,fillOpacity:!0,floodOpacity:!0,stopOpacity:!0,strokeDasharray:!0,strokeDashoffset:!0,strokeMiterlimit:!0,strokeOpacity:!0,strokeWidth:!0},at=["Webkit","ms","Moz","O"];Object.keys(He).forEach(function(i){at.forEach(function(s){s=s+i.charAt(0).toUpperCase()+i.substring(1),He[s]=He[i]})});function rt(i,s,o){return s==null||typeof s=="boolean"||s===""?"":o||typeof s!="number"||s===0||He.hasOwnProperty(i)&&He[i]?(""+s).trim():s+"px"}function Ge(i,s){i=i.style;for(var o in s)if(s.hasOwnProperty(o)){var f=o.indexOf("--")===0,m=rt(o,s[o],f);o==="float"&&(o="cssFloat"),f?i.setProperty(o,m):i[o]=m}}var mt=oe({menuitem:!0},{area:!0,base:!0,br:!0,col:!0,embed:!0,hr:!0,img:!0,input:!0,keygen:!0,link:!0,meta:!0,param:!0,source:!0,track:!0,wbr:!0});function lt(i,s){if(s){if(mt[i]&&(s.children!=null||s.dangerouslySetInnerHTML!=null))throw Error(t(137,i));if(s.dangerouslySetInnerHTML!=null){if(s.children!=null)throw Error(t(60));if(typeof s.dangerouslySetInnerHTML!="object"||!("__html"in s.dangerouslySetInnerHTML))throw Error(t(61))}if(s.style!=null&&typeof s.style!="object")throw Error(t(62))}}function At(i,s){if(i.indexOf("-")===-1)return typeof s.is=="string";switch(i){case"annotation-xml":case"color-profile":case"font-face":case"font-face-src":case"font-face-uri":case"font-face-format":case"font-face-name":case"missing-glyph":return!1;default:return!0}}var G=null;function Fe(i){return i=i.target||i.srcElement||window,i.correspondingUseElement&&(i=i.correspondingUseElement),i.nodeType===3?i.parentNode:i}var ce=null,ge=null,ke=null;function je(i){if(i=bo(i)){if(typeof ce!="function")throw Error(t(280));var s=i.stateNode;s&&(s=Ul(s),ce(i.stateNode,i.type,s))}}function gt(i){ge?ke?ke.push(i):ke=[i]:ge=i}function $t(){if(ge){var i=ge,s=ke;if(ke=ge=null,je(i),s)for(i=0;i<s.length;i++)je(s[i])}}function vn(i,s){return i(s)}function xt(){}var dn=!1;function ci(i,s,o){if(dn)return i(s,o);dn=!0;try{return vn(i,s,o)}finally{dn=!1,(ge!==null||ke!==null)&&(xt(),$t())}}function Cr(i,s){var o=i.stateNode;if(o===null)return null;var f=Ul(o);if(f===null)return null;o=f[s];e:switch(s){case"onClick":case"onClickCapture":case"onDoubleClick":case"onDoubleClickCapture":case"onMouseDown":case"onMouseDownCapture":case"onMouseMove":case"onMouseMoveCapture":case"onMouseUp":case"onMouseUpCapture":case"onMouseEnter":(f=!f.disabled)||(i=i.type,f=!(i==="button"||i==="input"||i==="select"||i==="textarea")),i=!f;break e;default:i=!1}if(i)return null;if(o&&typeof o!="function")throw Error(t(231,s,typeof o));return o}var Zs=!1;if(d)try{var Zn={};Object.defineProperty(Zn,"passive",{get:function(){Zs=!0}}),window.addEventListener("test",Zn,Zn),window.removeEventListener("test",Zn,Zn)}catch{Zs=!1}function ao(i,s,o,f,m,S,b,F,j){var ie=Array.prototype.slice.call(arguments,3);try{s.apply(o,ie)}catch(ye){this.onError(ye)}}var Nr=!1,hs=null,er=!1,Qs=null,Js={onError:function(i){Nr=!0,hs=i}};function _l(i,s,o,f,m,S,b,F,j){Nr=!1,hs=null,ao.apply(Js,arguments)}function vl(i,s,o,f,m,S,b,F,j){if(_l.apply(this,arguments),Nr){if(Nr){var ie=hs;Nr=!1,hs=null}else throw Error(t(198));er||(er=!0,Qs=ie)}}function tr(i){var s=i,o=i;if(i.alternate)for(;s.return;)s=s.return;else{i=s;do s=i,(s.flags&4098)!==0&&(o=s.return),i=s.return;while(i)}return s.tag===3?o:null}function xl(i){if(i.tag===13){var s=i.memoizedState;if(s===null&&(i=i.alternate,i!==null&&(s=i.memoizedState)),s!==null)return s.dehydrated}return null}function yl(i){if(tr(i)!==i)throw Error(t(188))}function N(i){var s=i.alternate;if(!s){if(s=tr(i),s===null)throw Error(t(188));return s!==i?null:i}for(var o=i,f=s;;){var m=o.return;if(m===null)break;var S=m.alternate;if(S===null){if(f=m.return,f!==null){o=f;continue}break}if(m.child===S.child){for(S=m.child;S;){if(S===o)return yl(m),i;if(S===f)return yl(m),s;S=S.sibling}throw Error(t(188))}if(o.return!==f.return)o=m,f=S;else{for(var b=!1,F=m.child;F;){if(F===o){b=!0,o=m,f=S;break}if(F===f){b=!0,f=m,o=S;break}F=F.sibling}if(!b){for(F=S.child;F;){if(F===o){b=!0,o=S,f=m;break}if(F===f){b=!0,f=S,o=m;break}F=F.sibling}if(!b)throw Error(t(189))}}if(o.alternate!==f)throw Error(t(190))}if(o.tag!==3)throw Error(t(188));return o.stateNode.current===o?i:s}function W(i){return i=N(i),i!==null?ee(i):null}function ee(i){if(i.tag===5||i.tag===6)return i;for(i=i.child;i!==null;){var s=ee(i);if(s!==null)return s;i=i.sibling}return null}var ne=e.unstable_scheduleCallback,X=e.unstable_cancelCallback,Re=e.unstable_shouldYield,Oe=e.unstable_requestPaint,Pe=e.unstable_now,qe=e.unstable_getCurrentPriorityLevel,et=e.unstable_ImmediatePriority,nt=e.unstable_UserBlockingPriority,Ye=e.unstable_NormalPriority,Tt=e.unstable_LowPriority,Dt=e.unstable_IdlePriority,It=null,Vt=null;function Mt(i){if(Vt&&typeof Vt.onCommitFiberRoot=="function")try{Vt.onCommitFiberRoot(It,i,void 0,(i.current.flags&128)===128)}catch{}}var Ve=Math.clz32?Math.clz32:Qn,rn=Math.log,Et=Math.LN2;function Qn(i){return i>>>=0,i===0?32:31-(rn(i)/Et|0)|0}var wi=64,fn=4194304;function nr(i){switch(i&-i){case 1:return 1;case 2:return 2;case 4:return 4;case 8:return 8;case 16:return 16;case 32:return 32;case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:return i&4194240;case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:return i&130023424;case 134217728:return 134217728;case 268435456:return 268435456;case 536870912:return 536870912;case 1073741824:return 1073741824;default:return i}}function Ut(i,s){var o=i.pendingLanes;if(o===0)return 0;var f=0,m=i.suspendedLanes,S=i.pingedLanes,b=o&268435455;if(b!==0){var F=b&~m;F!==0?f=nr(F):(S&=b,S!==0&&(f=nr(S)))}else b=o&~m,b!==0?f=nr(b):S!==0&&(f=nr(S));if(f===0)return 0;if(s!==0&&s!==f&&(s&m)===0&&(m=f&-f,S=s&-s,m>=S||m===16&&(S&4194240)!==0))return s;if((f&4)!==0&&(f|=o&16),s=i.entangledLanes,s!==0)for(i=i.entanglements,s&=f;0<s;)o=31-Ve(s),m=1<<o,f|=i[o],s&=~m;return f}function Bi(i,s){switch(i){case 1:case 2:case 4:return s+250;case 8:case 16:case 32:case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:return s+5e3;case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:return-1;case 134217728:case 268435456:case 536870912:case 1073741824:return-1;default:return-1}}function oo(i,s){for(var o=i.suspendedLanes,f=i.pingedLanes,m=i.expirationTimes,S=i.pendingLanes;0<S;){var b=31-Ve(S),F=1<<b,j=m[b];j===-1?((F&o)===0||(F&f)!==0)&&(m[b]=Bi(F,s)):j<=s&&(i.expiredLanes|=F),S&=~F}}function wn(i){return i=i.pendingLanes&-1073741825,i!==0?i:i&1073741824?1073741824:0}function ea(){var i=wi;return wi<<=1,(wi&4194240)===0&&(wi=64),i}function lo(i){for(var s=[],o=0;31>o;o++)s.push(i);return s}function Rr(i,s,o){i.pendingLanes|=s,s!==536870912&&(i.suspendedLanes=0,i.pingedLanes=0),i=i.eventTimes,s=31-Ve(s),i[s]=o}function Lx(i,s){var o=i.pendingLanes&~s;i.pendingLanes=s,i.suspendedLanes=0,i.pingedLanes=0,i.expiredLanes&=s,i.mutableReadLanes&=s,i.entangledLanes&=s,s=i.entanglements;var f=i.eventTimes;for(i=i.expirationTimes;0<o;){var m=31-Ve(o),S=1<<m;s[m]=0,f[m]=-1,i[m]=-1,o&=~S}}function Bu(i,s){var o=i.entangledLanes|=s;for(i=i.entanglements;o;){var f=31-Ve(o),m=1<<f;m&s|i[f]&s&&(i[f]|=s),o&=~m}}var Lt=0;function Gp(i){return i&=-i,1<i?4<i?(i&268435455)!==0?16:536870912:4:1}var Wp,Hu,$p,Xp,qp,Vu=!1,Sl=[],Pr=null,Lr=null,kr=null,co=new Map,uo=new Map,Dr=[],kx="mousedown mouseup touchcancel touchend touchstart auxclick dblclick pointercancel pointerdown pointerup dragend dragstart drop compositionend compositionstart keydown keypress keyup input textInput copy cut paste click change contextmenu reset submit".split(" ");function Yp(i,s){switch(i){case"focusin":case"focusout":Pr=null;break;case"dragenter":case"dragleave":Lr=null;break;case"mouseover":case"mouseout":kr=null;break;case"pointerover":case"pointerout":co.delete(s.pointerId);break;case"gotpointercapture":case"lostpointercapture":uo.delete(s.pointerId)}}function fo(i,s,o,f,m,S){return i===null||i.nativeEvent!==S?(i={blockedOn:s,domEventName:o,eventSystemFlags:f,nativeEvent:S,targetContainers:[m]},s!==null&&(s=bo(s),s!==null&&Hu(s)),i):(i.eventSystemFlags|=f,s=i.targetContainers,m!==null&&s.indexOf(m)===-1&&s.push(m),i)}function Dx(i,s,o,f,m){switch(s){case"focusin":return Pr=fo(Pr,i,s,o,f,m),!0;case"dragenter":return Lr=fo(Lr,i,s,o,f,m),!0;case"mouseover":return kr=fo(kr,i,s,o,f,m),!0;case"pointerover":var S=m.pointerId;return co.set(S,fo(co.get(S)||null,i,s,o,f,m)),!0;case"gotpointercapture":return S=m.pointerId,uo.set(S,fo(uo.get(S)||null,i,s,o,f,m)),!0}return!1}function Kp(i){var s=ps(i.target);if(s!==null){var o=tr(s);if(o!==null){if(s=o.tag,s===13){if(s=xl(o),s!==null){i.blockedOn=s,qp(i.priority,function(){$p(o)});return}}else if(s===3&&o.stateNode.current.memoizedState.isDehydrated){i.blockedOn=o.tag===3?o.stateNode.containerInfo:null;return}}}i.blockedOn=null}function Ml(i){if(i.blockedOn!==null)return!1;for(var s=i.targetContainers;0<s.length;){var o=Wu(i.domEventName,i.eventSystemFlags,s[0],i.nativeEvent);if(o===null){o=i.nativeEvent;var f=new o.constructor(o.type,o);G=f,o.target.dispatchEvent(f),G=null}else return s=bo(o),s!==null&&Hu(s),i.blockedOn=o,!1;s.shift()}return!0}function Zp(i,s,o){Ml(i)&&o.delete(s)}function Ix(){Vu=!1,Pr!==null&&Ml(Pr)&&(Pr=null),Lr!==null&&Ml(Lr)&&(Lr=null),kr!==null&&Ml(kr)&&(kr=null),co.forEach(Zp),uo.forEach(Zp)}function ho(i,s){i.blockedOn===s&&(i.blockedOn=null,Vu||(Vu=!0,e.unstable_scheduleCallback(e.unstable_NormalPriority,Ix)))}function po(i){function s(m){return ho(m,i)}if(0<Sl.length){ho(Sl[0],i);for(var o=1;o<Sl.length;o++){var f=Sl[o];f.blockedOn===i&&(f.blockedOn=null)}}for(Pr!==null&&ho(Pr,i),Lr!==null&&ho(Lr,i),kr!==null&&ho(kr,i),co.forEach(s),uo.forEach(s),o=0;o<Dr.length;o++)f=Dr[o],f.blockedOn===i&&(f.blockedOn=null);for(;0<Dr.length&&(o=Dr[0],o.blockedOn===null);)Kp(o),o.blockedOn===null&&Dr.shift()}var ta=R.ReactCurrentBatchConfig,El=!0;function Ux(i,s,o,f){var m=Lt,S=ta.transition;ta.transition=null;try{Lt=1,Gu(i,s,o,f)}finally{Lt=m,ta.transition=S}}function Fx(i,s,o,f){var m=Lt,S=ta.transition;ta.transition=null;try{Lt=4,Gu(i,s,o,f)}finally{Lt=m,ta.transition=S}}function Gu(i,s,o,f){if(El){var m=Wu(i,s,o,f);if(m===null)ld(i,s,f,wl,o),Yp(i,f);else if(Dx(m,i,s,o,f))f.stopPropagation();else if(Yp(i,f),s&4&&-1<kx.indexOf(i)){for(;m!==null;){var S=bo(m);if(S!==null&&Wp(S),S=Wu(i,s,o,f),S===null&&ld(i,s,f,wl,o),S===m)break;m=S}m!==null&&f.stopPropagation()}else ld(i,s,f,null,o)}}var wl=null;function Wu(i,s,o,f){if(wl=null,i=Fe(f),i=ps(i),i!==null)if(s=tr(i),s===null)i=null;else if(o=s.tag,o===13){if(i=xl(s),i!==null)return i;i=null}else if(o===3){if(s.stateNode.current.memoizedState.isDehydrated)return s.tag===3?s.stateNode.containerInfo:null;i=null}else s!==i&&(i=null);return wl=i,null}function Qp(i){switch(i){case"cancel":case"click":case"close":case"contextmenu":case"copy":case"cut":case"auxclick":case"dblclick":case"dragend":case"dragstart":case"drop":case"focusin":case"focusout":case"input":case"invalid":case"keydown":case"keypress":case"keyup":case"mousedown":case"mouseup":case"paste":case"pause":case"play":case"pointercancel":case"pointerdown":case"pointerup":case"ratechange":case"reset":case"resize":case"seeked":case"submit":case"touchcancel":case"touchend":case"touchstart":case"volumechange":case"change":case"selectionchange":case"textInput":case"compositionstart":case"compositionend":case"compositionupdate":case"beforeblur":case"afterblur":case"beforeinput":case"blur":case"fullscreenchange":case"focus":case"hashchange":case"popstate":case"select":case"selectstart":return 1;case"drag":case"dragenter":case"dragexit":case"dragleave":case"dragover":case"mousemove":case"mouseout":case"mouseover":case"pointermove":case"pointerout":case"pointerover":case"scroll":case"toggle":case"touchmove":case"wheel":case"mouseenter":case"mouseleave":case"pointerenter":case"pointerleave":return 4;case"message":switch(qe()){case et:return 1;case nt:return 4;case Ye:case Tt:return 16;case Dt:return 536870912;default:return 16}default:return 16}}var Ir=null,$u=null,Tl=null;function Jp(){if(Tl)return Tl;var i,s=$u,o=s.length,f,m="value"in Ir?Ir.value:Ir.textContent,S=m.length;for(i=0;i<o&&s[i]===m[i];i++);var b=o-i;for(f=1;f<=b&&s[o-f]===m[S-f];f++);return Tl=m.slice(i,1<f?1-f:void 0)}function bl(i){var s=i.keyCode;return"charCode"in i?(i=i.charCode,i===0&&s===13&&(i=13)):i=s,i===10&&(i=13),32<=i||i===13?i:0}function Al(){return!0}function em(){return!1}function Jn(i){function s(o,f,m,S,b){this._reactName=o,this._targetInst=m,this.type=f,this.nativeEvent=S,this.target=b,this.currentTarget=null;for(var F in i)i.hasOwnProperty(F)&&(o=i[F],this[F]=o?o(S):S[F]);return this.isDefaultPrevented=(S.defaultPrevented!=null?S.defaultPrevented:S.returnValue===!1)?Al:em,this.isPropagationStopped=em,this}return oe(s.prototype,{preventDefault:function(){this.defaultPrevented=!0;var o=this.nativeEvent;o&&(o.preventDefault?o.preventDefault():typeof o.returnValue!="unknown"&&(o.returnValue=!1),this.isDefaultPrevented=Al)},stopPropagation:function(){var o=this.nativeEvent;o&&(o.stopPropagation?o.stopPropagation():typeof o.cancelBubble!="unknown"&&(o.cancelBubble=!0),this.isPropagationStopped=Al)},persist:function(){},isPersistent:Al}),s}var na={eventPhase:0,bubbles:0,cancelable:0,timeStamp:function(i){return i.timeStamp||Date.now()},defaultPrevented:0,isTrusted:0},Xu=Jn(na),mo=oe({},na,{view:0,detail:0}),Ox=Jn(mo),qu,Yu,go,Cl=oe({},mo,{screenX:0,screenY:0,clientX:0,clientY:0,pageX:0,pageY:0,ctrlKey:0,shiftKey:0,altKey:0,metaKey:0,getModifierState:Zu,button:0,buttons:0,relatedTarget:function(i){return i.relatedTarget===void 0?i.fromElement===i.srcElement?i.toElement:i.fromElement:i.relatedTarget},movementX:function(i){return"movementX"in i?i.movementX:(i!==go&&(go&&i.type==="mousemove"?(qu=i.screenX-go.screenX,Yu=i.screenY-go.screenY):Yu=qu=0,go=i),qu)},movementY:function(i){return"movementY"in i?i.movementY:Yu}}),tm=Jn(Cl),jx=oe({},Cl,{dataTransfer:0}),zx=Jn(jx),Bx=oe({},mo,{relatedTarget:0}),Ku=Jn(Bx),Hx=oe({},na,{animationName:0,elapsedTime:0,pseudoElement:0}),Vx=Jn(Hx),Gx=oe({},na,{clipboardData:function(i){return"clipboardData"in i?i.clipboardData:window.clipboardData}}),Wx=Jn(Gx),$x=oe({},na,{data:0}),nm=Jn($x),Xx={Esc:"Escape",Spacebar:" ",Left:"ArrowLeft",Up:"ArrowUp",Right:"ArrowRight",Down:"ArrowDown",Del:"Delete",Win:"OS",Menu:"ContextMenu",Apps:"ContextMenu",Scroll:"ScrollLock",MozPrintableKey:"Unidentified"},qx={8:"Backspace",9:"Tab",12:"Clear",13:"Enter",16:"Shift",17:"Control",18:"Alt",19:"Pause",20:"CapsLock",27:"Escape",32:" ",33:"PageUp",34:"PageDown",35:"End",36:"Home",37:"ArrowLeft",38:"ArrowUp",39:"ArrowRight",40:"ArrowDown",45:"Insert",46:"Delete",112:"F1",113:"F2",114:"F3",115:"F4",116:"F5",117:"F6",118:"F7",119:"F8",120:"F9",121:"F10",122:"F11",123:"F12",144:"NumLock",145:"ScrollLock",224:"Meta"},Yx={Alt:"altKey",Control:"ctrlKey",Meta:"metaKey",Shift:"shiftKey"};function Kx(i){var s=this.nativeEvent;return s.getModifierState?s.getModifierState(i):(i=Yx[i])?!!s[i]:!1}function Zu(){return Kx}var Zx=oe({},mo,{key:function(i){if(i.key){var s=Xx[i.key]||i.key;if(s!=="Unidentified")return s}return i.type==="keypress"?(i=bl(i),i===13?"Enter":String.fromCharCode(i)):i.type==="keydown"||i.type==="keyup"?qx[i.keyCode]||"Unidentified":""},code:0,location:0,ctrlKey:0,shiftKey:0,altKey:0,metaKey:0,repeat:0,locale:0,getModifierState:Zu,charCode:function(i){return i.type==="keypress"?bl(i):0},keyCode:function(i){return i.type==="keydown"||i.type==="keyup"?i.keyCode:0},which:function(i){return i.type==="keypress"?bl(i):i.type==="keydown"||i.type==="keyup"?i.keyCode:0}}),Qx=Jn(Zx),Jx=oe({},Cl,{pointerId:0,width:0,height:0,pressure:0,tangentialPressure:0,tiltX:0,tiltY:0,twist:0,pointerType:0,isPrimary:0}),im=Jn(Jx),e1=oe({},mo,{touches:0,targetTouches:0,changedTouches:0,altKey:0,metaKey:0,ctrlKey:0,shiftKey:0,getModifierState:Zu}),t1=Jn(e1),n1=oe({},na,{propertyName:0,elapsedTime:0,pseudoElement:0}),i1=Jn(n1),r1=oe({},Cl,{deltaX:function(i){return"deltaX"in i?i.deltaX:"wheelDeltaX"in i?-i.wheelDeltaX:0},deltaY:function(i){return"deltaY"in i?i.deltaY:"wheelDeltaY"in i?-i.wheelDeltaY:"wheelDelta"in i?-i.wheelDelta:0},deltaZ:0,deltaMode:0}),s1=Jn(r1),a1=[9,13,27,32],Qu=d&&"CompositionEvent"in window,_o=null;d&&"documentMode"in document&&(_o=document.documentMode);var o1=d&&"TextEvent"in window&&!_o,rm=d&&(!Qu||_o&&8<_o&&11>=_o),sm=" ",am=!1;function om(i,s){switch(i){case"keyup":return a1.indexOf(s.keyCode)!==-1;case"keydown":return s.keyCode!==229;case"keypress":case"mousedown":case"focusout":return!0;default:return!1}}function lm(i){return i=i.detail,typeof i=="object"&&"data"in i?i.data:null}var ia=!1;function l1(i,s){switch(i){case"compositionend":return lm(s);case"keypress":return s.which!==32?null:(am=!0,sm);case"textInput":return i=s.data,i===sm&&am?null:i;default:return null}}function c1(i,s){if(ia)return i==="compositionend"||!Qu&&om(i,s)?(i=Jp(),Tl=$u=Ir=null,ia=!1,i):null;switch(i){case"paste":return null;case"keypress":if(!(s.ctrlKey||s.altKey||s.metaKey)||s.ctrlKey&&s.altKey){if(s.char&&1<s.char.length)return s.char;if(s.which)return String.fromCharCode(s.which)}return null;case"compositionend":return rm&&s.locale!=="ko"?null:s.data;default:return null}}var u1={color:!0,date:!0,datetime:!0,"datetime-local":!0,email:!0,month:!0,number:!0,password:!0,range:!0,search:!0,tel:!0,text:!0,time:!0,url:!0,week:!0};function cm(i){var s=i&&i.nodeName&&i.nodeName.toLowerCase();return s==="input"?!!u1[i.type]:s==="textarea"}function um(i,s,o,f){gt(f),s=kl(s,"onChange"),0<s.length&&(o=new Xu("onChange","change",null,o,f),i.push({event:o,listeners:s}))}var vo=null,xo=null;function d1(i){Cm(i,0)}function Nl(i){var s=la(i);if(pt(s))return i}function f1(i,s){if(i==="change")return s}var dm=!1;if(d){var Ju;if(d){var ed="oninput"in document;if(!ed){var fm=document.createElement("div");fm.setAttribute("oninput","return;"),ed=typeof fm.oninput=="function"}Ju=ed}else Ju=!1;dm=Ju&&(!document.documentMode||9<document.documentMode)}function hm(){vo&&(vo.detachEvent("onpropertychange",pm),xo=vo=null)}function pm(i){if(i.propertyName==="value"&&Nl(xo)){var s=[];um(s,xo,i,Fe(i)),ci(d1,s)}}function h1(i,s,o){i==="focusin"?(hm(),vo=s,xo=o,vo.attachEvent("onpropertychange",pm)):i==="focusout"&&hm()}function p1(i){if(i==="selectionchange"||i==="keyup"||i==="keydown")return Nl(xo)}function m1(i,s){if(i==="click")return Nl(s)}function g1(i,s){if(i==="input"||i==="change")return Nl(s)}function _1(i,s){return i===s&&(i!==0||1/i===1/s)||i!==i&&s!==s}var Ti=typeof Object.is=="function"?Object.is:_1;function yo(i,s){if(Ti(i,s))return!0;if(typeof i!="object"||i===null||typeof s!="object"||s===null)return!1;var o=Object.keys(i),f=Object.keys(s);if(o.length!==f.length)return!1;for(f=0;f<o.length;f++){var m=o[f];if(!h.call(s,m)||!Ti(i[m],s[m]))return!1}return!0}function mm(i){for(;i&&i.firstChild;)i=i.firstChild;return i}function gm(i,s){var o=mm(i);i=0;for(var f;o;){if(o.nodeType===3){if(f=i+o.textContent.length,i<=s&&f>=s)return{node:o,offset:s-i};i=f}e:{for(;o;){if(o.nextSibling){o=o.nextSibling;break e}o=o.parentNode}o=void 0}o=mm(o)}}function _m(i,s){return i&&s?i===s?!0:i&&i.nodeType===3?!1:s&&s.nodeType===3?_m(i,s.parentNode):"contains"in i?i.contains(s):i.compareDocumentPosition?!!(i.compareDocumentPosition(s)&16):!1:!1}function vm(){for(var i=window,s=B();s instanceof i.HTMLIFrameElement;){try{var o=typeof s.contentWindow.location.href=="string"}catch{o=!1}if(o)i=s.contentWindow;else break;s=B(i.document)}return s}function td(i){var s=i&&i.nodeName&&i.nodeName.toLowerCase();return s&&(s==="input"&&(i.type==="text"||i.type==="search"||i.type==="tel"||i.type==="url"||i.type==="password")||s==="textarea"||i.contentEditable==="true")}function v1(i){var s=vm(),o=i.focusedElem,f=i.selectionRange;if(s!==o&&o&&o.ownerDocument&&_m(o.ownerDocument.documentElement,o)){if(f!==null&&td(o)){if(s=f.start,i=f.end,i===void 0&&(i=s),"selectionStart"in o)o.selectionStart=s,o.selectionEnd=Math.min(i,o.value.length);else if(i=(s=o.ownerDocument||document)&&s.defaultView||window,i.getSelection){i=i.getSelection();var m=o.textContent.length,S=Math.min(f.start,m);f=f.end===void 0?S:Math.min(f.end,m),!i.extend&&S>f&&(m=f,f=S,S=m),m=gm(o,S);var b=gm(o,f);m&&b&&(i.rangeCount!==1||i.anchorNode!==m.node||i.anchorOffset!==m.offset||i.focusNode!==b.node||i.focusOffset!==b.offset)&&(s=s.createRange(),s.setStart(m.node,m.offset),i.removeAllRanges(),S>f?(i.addRange(s),i.extend(b.node,b.offset)):(s.setEnd(b.node,b.offset),i.addRange(s)))}}for(s=[],i=o;i=i.parentNode;)i.nodeType===1&&s.push({element:i,left:i.scrollLeft,top:i.scrollTop});for(typeof o.focus=="function"&&o.focus(),o=0;o<s.length;o++)i=s[o],i.element.scrollLeft=i.left,i.element.scrollTop=i.top}}var x1=d&&"documentMode"in document&&11>=document.documentMode,ra=null,nd=null,So=null,id=!1;function xm(i,s,o){var f=o.window===o?o.document:o.nodeType===9?o:o.ownerDocument;id||ra==null||ra!==B(f)||(f=ra,"selectionStart"in f&&td(f)?f={start:f.selectionStart,end:f.selectionEnd}:(f=(f.ownerDocument&&f.ownerDocument.defaultView||window).getSelection(),f={anchorNode:f.anchorNode,anchorOffset:f.anchorOffset,focusNode:f.focusNode,focusOffset:f.focusOffset}),So&&yo(So,f)||(So=f,f=kl(nd,"onSelect"),0<f.length&&(s=new Xu("onSelect","select",null,s,o),i.push({event:s,listeners:f}),s.target=ra)))}function Rl(i,s){var o={};return o[i.toLowerCase()]=s.toLowerCase(),o["Webkit"+i]="webkit"+s,o["Moz"+i]="moz"+s,o}var sa={animationend:Rl("Animation","AnimationEnd"),animationiteration:Rl("Animation","AnimationIteration"),animationstart:Rl("Animation","AnimationStart"),transitionend:Rl("Transition","TransitionEnd")},rd={},ym={};d&&(ym=document.createElement("div").style,"AnimationEvent"in window||(delete sa.animationend.animation,delete sa.animationiteration.animation,delete sa.animationstart.animation),"TransitionEvent"in window||delete sa.transitionend.transition);function Pl(i){if(rd[i])return rd[i];if(!sa[i])return i;var s=sa[i],o;for(o in s)if(s.hasOwnProperty(o)&&o in ym)return rd[i]=s[o];return i}var Sm=Pl("animationend"),Mm=Pl("animationiteration"),Em=Pl("animationstart"),wm=Pl("transitionend"),Tm=new Map,bm="abort auxClick cancel canPlay canPlayThrough click close contextMenu copy cut drag dragEnd dragEnter dragExit dragLeave dragOver dragStart drop durationChange emptied encrypted ended error gotPointerCapture input invalid keyDown keyPress keyUp load loadedData loadedMetadata loadStart lostPointerCapture mouseDown mouseMove mouseOut mouseOver mouseUp paste pause play playing pointerCancel pointerDown pointerMove pointerOut pointerOver pointerUp progress rateChange reset resize seeked seeking stalled submit suspend timeUpdate touchCancel touchEnd touchStart volumeChange scroll toggle touchMove waiting wheel".split(" ");function Ur(i,s){Tm.set(i,s),c(s,[i])}for(var sd=0;sd<bm.length;sd++){var ad=bm[sd],y1=ad.toLowerCase(),S1=ad[0].toUpperCase()+ad.slice(1);Ur(y1,"on"+S1)}Ur(Sm,"onAnimationEnd"),Ur(Mm,"onAnimationIteration"),Ur(Em,"onAnimationStart"),Ur("dblclick","onDoubleClick"),Ur("focusin","onFocus"),Ur("focusout","onBlur"),Ur(wm,"onTransitionEnd"),u("onMouseEnter",["mouseout","mouseover"]),u("onMouseLeave",["mouseout","mouseover"]),u("onPointerEnter",["pointerout","pointerover"]),u("onPointerLeave",["pointerout","pointerover"]),c("onChange","change click focusin focusout input keydown keyup selectionchange".split(" ")),c("onSelect","focusout contextmenu dragend focusin keydown keyup mousedown mouseup selectionchange".split(" ")),c("onBeforeInput",["compositionend","keypress","textInput","paste"]),c("onCompositionEnd","compositionend focusout keydown keypress keyup mousedown".split(" ")),c("onCompositionStart","compositionstart focusout keydown keypress keyup mousedown".split(" ")),c("onCompositionUpdate","compositionupdate focusout keydown keypress keyup mousedown".split(" "));var Mo="abort canplay canplaythrough durationchange emptied encrypted ended error loadeddata loadedmetadata loadstart pause play playing progress ratechange resize seeked seeking stalled suspend timeupdate volumechange waiting".split(" "),M1=new Set("cancel close invalid load scroll toggle".split(" ").concat(Mo));function Am(i,s,o){var f=i.type||"unknown-event";i.currentTarget=o,vl(f,s,void 0,i),i.currentTarget=null}function Cm(i,s){s=(s&4)!==0;for(var o=0;o<i.length;o++){var f=i[o],m=f.event;f=f.listeners;e:{var S=void 0;if(s)for(var b=f.length-1;0<=b;b--){var F=f[b],j=F.instance,ie=F.currentTarget;if(F=F.listener,j!==S&&m.isPropagationStopped())break e;Am(m,F,ie),S=j}else for(b=0;b<f.length;b++){if(F=f[b],j=F.instance,ie=F.currentTarget,F=F.listener,j!==S&&m.isPropagationStopped())break e;Am(m,F,ie),S=j}}}if(er)throw i=Qs,er=!1,Qs=null,i}function jt(i,s){var o=s[pd];o===void 0&&(o=s[pd]=new Set);var f=i+"__bubble";o.has(f)||(Nm(s,i,2,!1),o.add(f))}function od(i,s,o){var f=0;s&&(f|=4),Nm(o,i,f,s)}var Ll="_reactListening"+Math.random().toString(36).slice(2);function Eo(i){if(!i[Ll]){i[Ll]=!0,r.forEach(function(o){o!=="selectionchange"&&(M1.has(o)||od(o,!1,i),od(o,!0,i))});var s=i.nodeType===9?i:i.ownerDocument;s===null||s[Ll]||(s[Ll]=!0,od("selectionchange",!1,s))}}function Nm(i,s,o,f){switch(Qp(s)){case 1:var m=Ux;break;case 4:m=Fx;break;default:m=Gu}o=m.bind(null,s,o,i),m=void 0,!Zs||s!=="touchstart"&&s!=="touchmove"&&s!=="wheel"||(m=!0),f?m!==void 0?i.addEventListener(s,o,{capture:!0,passive:m}):i.addEventListener(s,o,!0):m!==void 0?i.addEventListener(s,o,{passive:m}):i.addEventListener(s,o,!1)}function ld(i,s,o,f,m){var S=f;if((s&1)===0&&(s&2)===0&&f!==null)e:for(;;){if(f===null)return;var b=f.tag;if(b===3||b===4){var F=f.stateNode.containerInfo;if(F===m||F.nodeType===8&&F.parentNode===m)break;if(b===4)for(b=f.return;b!==null;){var j=b.tag;if((j===3||j===4)&&(j=b.stateNode.containerInfo,j===m||j.nodeType===8&&j.parentNode===m))return;b=b.return}for(;F!==null;){if(b=ps(F),b===null)return;if(j=b.tag,j===5||j===6){f=S=b;continue e}F=F.parentNode}}f=f.return}ci(function(){var ie=S,ye=Fe(o),Me=[];e:{var xe=Tm.get(i);if(xe!==void 0){var ze=Xu,$e=i;switch(i){case"keypress":if(bl(o)===0)break e;case"keydown":case"keyup":ze=Qx;break;case"focusin":$e="focus",ze=Ku;break;case"focusout":$e="blur",ze=Ku;break;case"beforeblur":case"afterblur":ze=Ku;break;case"click":if(o.button===2)break e;case"auxclick":case"dblclick":case"mousedown":case"mousemove":case"mouseup":case"mouseout":case"mouseover":case"contextmenu":ze=tm;break;case"drag":case"dragend":case"dragenter":case"dragexit":case"dragleave":case"dragover":case"dragstart":case"drop":ze=zx;break;case"touchcancel":case"touchend":case"touchmove":case"touchstart":ze=t1;break;case Sm:case Mm:case Em:ze=Vx;break;case wm:ze=i1;break;case"scroll":ze=Ox;break;case"wheel":ze=s1;break;case"copy":case"cut":case"paste":ze=Wx;break;case"gotpointercapture":case"lostpointercapture":case"pointercancel":case"pointerdown":case"pointermove":case"pointerout":case"pointerover":case"pointerup":ze=im}var Xe=(s&4)!==0,Kt=!Xe&&i==="scroll",Y=Xe?xe!==null?xe+"Capture":null:xe;Xe=[];for(var H=ie,Z;H!==null;){Z=H;var Ne=Z.stateNode;if(Z.tag===5&&Ne!==null&&(Z=Ne,Y!==null&&(Ne=Cr(H,Y),Ne!=null&&Xe.push(wo(H,Ne,Z)))),Kt)break;H=H.return}0<Xe.length&&(xe=new ze(xe,$e,null,o,ye),Me.push({event:xe,listeners:Xe}))}}if((s&7)===0){e:{if(xe=i==="mouseover"||i==="pointerover",ze=i==="mouseout"||i==="pointerout",xe&&o!==G&&($e=o.relatedTarget||o.fromElement)&&(ps($e)||$e[ir]))break e;if((ze||xe)&&(xe=ye.window===ye?ye:(xe=ye.ownerDocument)?xe.defaultView||xe.parentWindow:window,ze?($e=o.relatedTarget||o.toElement,ze=ie,$e=$e?ps($e):null,$e!==null&&(Kt=tr($e),$e!==Kt||$e.tag!==5&&$e.tag!==6)&&($e=null)):(ze=null,$e=ie),ze!==$e)){if(Xe=tm,Ne="onMouseLeave",Y="onMouseEnter",H="mouse",(i==="pointerout"||i==="pointerover")&&(Xe=im,Ne="onPointerLeave",Y="onPointerEnter",H="pointer"),Kt=ze==null?xe:la(ze),Z=$e==null?xe:la($e),xe=new Xe(Ne,H+"leave",ze,o,ye),xe.target=Kt,xe.relatedTarget=Z,Ne=null,ps(ye)===ie&&(Xe=new Xe(Y,H+"enter",$e,o,ye),Xe.target=Z,Xe.relatedTarget=Kt,Ne=Xe),Kt=Ne,ze&&$e)t:{for(Xe=ze,Y=$e,H=0,Z=Xe;Z;Z=aa(Z))H++;for(Z=0,Ne=Y;Ne;Ne=aa(Ne))Z++;for(;0<H-Z;)Xe=aa(Xe),H--;for(;0<Z-H;)Y=aa(Y),Z--;for(;H--;){if(Xe===Y||Y!==null&&Xe===Y.alternate)break t;Xe=aa(Xe),Y=aa(Y)}Xe=null}else Xe=null;ze!==null&&Rm(Me,xe,ze,Xe,!1),$e!==null&&Kt!==null&&Rm(Me,Kt,$e,Xe,!0)}}e:{if(xe=ie?la(ie):window,ze=xe.nodeName&&xe.nodeName.toLowerCase(),ze==="select"||ze==="input"&&xe.type==="file")var Ke=f1;else if(cm(xe))if(dm)Ke=g1;else{Ke=p1;var Qe=h1}else(ze=xe.nodeName)&&ze.toLowerCase()==="input"&&(xe.type==="checkbox"||xe.type==="radio")&&(Ke=m1);if(Ke&&(Ke=Ke(i,ie))){um(Me,Ke,o,ye);break e}Qe&&Qe(i,xe,ie),i==="focusout"&&(Qe=xe._wrapperState)&&Qe.controlled&&xe.type==="number"&&it(xe,"number",xe.value)}switch(Qe=ie?la(ie):window,i){case"focusin":(cm(Qe)||Qe.contentEditable==="true")&&(ra=Qe,nd=ie,So=null);break;case"focusout":So=nd=ra=null;break;case"mousedown":id=!0;break;case"contextmenu":case"mouseup":case"dragend":id=!1,xm(Me,o,ye);break;case"selectionchange":if(x1)break;case"keydown":case"keyup":xm(Me,o,ye)}var Je;if(Qu)e:{switch(i){case"compositionstart":var ot="onCompositionStart";break e;case"compositionend":ot="onCompositionEnd";break e;case"compositionupdate":ot="onCompositionUpdate";break e}ot=void 0}else ia?om(i,o)&&(ot="onCompositionEnd"):i==="keydown"&&o.keyCode===229&&(ot="onCompositionStart");ot&&(rm&&o.locale!=="ko"&&(ia||ot!=="onCompositionStart"?ot==="onCompositionEnd"&&ia&&(Je=Jp()):(Ir=ye,$u="value"in Ir?Ir.value:Ir.textContent,ia=!0)),Qe=kl(ie,ot),0<Qe.length&&(ot=new nm(ot,i,null,o,ye),Me.push({event:ot,listeners:Qe}),Je?ot.data=Je:(Je=lm(o),Je!==null&&(ot.data=Je)))),(Je=o1?l1(i,o):c1(i,o))&&(ie=kl(ie,"onBeforeInput"),0<ie.length&&(ye=new nm("onBeforeInput","beforeinput",null,o,ye),Me.push({event:ye,listeners:ie}),ye.data=Je))}Cm(Me,s)})}function wo(i,s,o){return{instance:i,listener:s,currentTarget:o}}function kl(i,s){for(var o=s+"Capture",f=[];i!==null;){var m=i,S=m.stateNode;m.tag===5&&S!==null&&(m=S,S=Cr(i,o),S!=null&&f.unshift(wo(i,S,m)),S=Cr(i,s),S!=null&&f.push(wo(i,S,m))),i=i.return}return f}function aa(i){if(i===null)return null;do i=i.return;while(i&&i.tag!==5);return i||null}function Rm(i,s,o,f,m){for(var S=s._reactName,b=[];o!==null&&o!==f;){var F=o,j=F.alternate,ie=F.stateNode;if(j!==null&&j===f)break;F.tag===5&&ie!==null&&(F=ie,m?(j=Cr(o,S),j!=null&&b.unshift(wo(o,j,F))):m||(j=Cr(o,S),j!=null&&b.push(wo(o,j,F)))),o=o.return}b.length!==0&&i.push({event:s,listeners:b})}var E1=/\r\n?/g,w1=/\u0000|\uFFFD/g;function Pm(i){return(typeof i=="string"?i:""+i).replace(E1,`
`).replace(w1,"")}function Dl(i,s,o){if(s=Pm(s),Pm(i)!==s&&o)throw Error(t(425))}function Il(){}var cd=null,ud=null;function dd(i,s){return i==="textarea"||i==="noscript"||typeof s.children=="string"||typeof s.children=="number"||typeof s.dangerouslySetInnerHTML=="object"&&s.dangerouslySetInnerHTML!==null&&s.dangerouslySetInnerHTML.__html!=null}var fd=typeof setTimeout=="function"?setTimeout:void 0,T1=typeof clearTimeout=="function"?clearTimeout:void 0,Lm=typeof Promise=="function"?Promise:void 0,b1=typeof queueMicrotask=="function"?queueMicrotask:typeof Lm<"u"?function(i){return Lm.resolve(null).then(i).catch(A1)}:fd;function A1(i){setTimeout(function(){throw i})}function hd(i,s){var o=s,f=0;do{var m=o.nextSibling;if(i.removeChild(o),m&&m.nodeType===8)if(o=m.data,o==="/$"){if(f===0){i.removeChild(m),po(s);return}f--}else o!=="$"&&o!=="$?"&&o!=="$!"||f++;o=m}while(o);po(s)}function Fr(i){for(;i!=null;i=i.nextSibling){var s=i.nodeType;if(s===1||s===3)break;if(s===8){if(s=i.data,s==="$"||s==="$!"||s==="$?")break;if(s==="/$")return null}}return i}function km(i){i=i.previousSibling;for(var s=0;i;){if(i.nodeType===8){var o=i.data;if(o==="$"||o==="$!"||o==="$?"){if(s===0)return i;s--}else o==="/$"&&s++}i=i.previousSibling}return null}var oa=Math.random().toString(36).slice(2),Hi="__reactFiber$"+oa,To="__reactProps$"+oa,ir="__reactContainer$"+oa,pd="__reactEvents$"+oa,C1="__reactListeners$"+oa,N1="__reactHandles$"+oa;function ps(i){var s=i[Hi];if(s)return s;for(var o=i.parentNode;o;){if(s=o[ir]||o[Hi]){if(o=s.alternate,s.child!==null||o!==null&&o.child!==null)for(i=km(i);i!==null;){if(o=i[Hi])return o;i=km(i)}return s}i=o,o=i.parentNode}return null}function bo(i){return i=i[Hi]||i[ir],!i||i.tag!==5&&i.tag!==6&&i.tag!==13&&i.tag!==3?null:i}function la(i){if(i.tag===5||i.tag===6)return i.stateNode;throw Error(t(33))}function Ul(i){return i[To]||null}var md=[],ca=-1;function Or(i){return{current:i}}function zt(i){0>ca||(i.current=md[ca],md[ca]=null,ca--)}function Ft(i,s){ca++,md[ca]=i.current,i.current=s}var jr={},Tn=Or(jr),On=Or(!1),ms=jr;function ua(i,s){var o=i.type.contextTypes;if(!o)return jr;var f=i.stateNode;if(f&&f.__reactInternalMemoizedUnmaskedChildContext===s)return f.__reactInternalMemoizedMaskedChildContext;var m={},S;for(S in o)m[S]=s[S];return f&&(i=i.stateNode,i.__reactInternalMemoizedUnmaskedChildContext=s,i.__reactInternalMemoizedMaskedChildContext=m),m}function jn(i){return i=i.childContextTypes,i!=null}function Fl(){zt(On),zt(Tn)}function Dm(i,s,o){if(Tn.current!==jr)throw Error(t(168));Ft(Tn,s),Ft(On,o)}function Im(i,s,o){var f=i.stateNode;if(s=s.childContextTypes,typeof f.getChildContext!="function")return o;f=f.getChildContext();for(var m in f)if(!(m in s))throw Error(t(108,Ae(i)||"Unknown",m));return oe({},o,f)}function Ol(i){return i=(i=i.stateNode)&&i.__reactInternalMemoizedMergedChildContext||jr,ms=Tn.current,Ft(Tn,i),Ft(On,On.current),!0}function Um(i,s,o){var f=i.stateNode;if(!f)throw Error(t(169));o?(i=Im(i,s,ms),f.__reactInternalMemoizedMergedChildContext=i,zt(On),zt(Tn),Ft(Tn,i)):zt(On),Ft(On,o)}var rr=null,jl=!1,gd=!1;function Fm(i){rr===null?rr=[i]:rr.push(i)}function R1(i){jl=!0,Fm(i)}function zr(){if(!gd&&rr!==null){gd=!0;var i=0,s=Lt;try{var o=rr;for(Lt=1;i<o.length;i++){var f=o[i];do f=f(!0);while(f!==null)}rr=null,jl=!1}catch(m){throw rr!==null&&(rr=rr.slice(i+1)),ne(et,zr),m}finally{Lt=s,gd=!1}}return null}var da=[],fa=0,zl=null,Bl=0,ui=[],di=0,gs=null,sr=1,ar="";function _s(i,s){da[fa++]=Bl,da[fa++]=zl,zl=i,Bl=s}function Om(i,s,o){ui[di++]=sr,ui[di++]=ar,ui[di++]=gs,gs=i;var f=sr;i=ar;var m=32-Ve(f)-1;f&=~(1<<m),o+=1;var S=32-Ve(s)+m;if(30<S){var b=m-m%5;S=(f&(1<<b)-1).toString(32),f>>=b,m-=b,sr=1<<32-Ve(s)+m|o<<m|f,ar=S+i}else sr=1<<S|o<<m|f,ar=i}function _d(i){i.return!==null&&(_s(i,1),Om(i,1,0))}function vd(i){for(;i===zl;)zl=da[--fa],da[fa]=null,Bl=da[--fa],da[fa]=null;for(;i===gs;)gs=ui[--di],ui[di]=null,ar=ui[--di],ui[di]=null,sr=ui[--di],ui[di]=null}var ei=null,ti=null,Gt=!1,bi=null;function jm(i,s){var o=mi(5,null,null,0);o.elementType="DELETED",o.stateNode=s,o.return=i,s=i.deletions,s===null?(i.deletions=[o],i.flags|=16):s.push(o)}function zm(i,s){switch(i.tag){case 5:var o=i.type;return s=s.nodeType!==1||o.toLowerCase()!==s.nodeName.toLowerCase()?null:s,s!==null?(i.stateNode=s,ei=i,ti=Fr(s.firstChild),!0):!1;case 6:return s=i.pendingProps===""||s.nodeType!==3?null:s,s!==null?(i.stateNode=s,ei=i,ti=null,!0):!1;case 13:return s=s.nodeType!==8?null:s,s!==null?(o=gs!==null?{id:sr,overflow:ar}:null,i.memoizedState={dehydrated:s,treeContext:o,retryLane:1073741824},o=mi(18,null,null,0),o.stateNode=s,o.return=i,i.child=o,ei=i,ti=null,!0):!1;default:return!1}}function xd(i){return(i.mode&1)!==0&&(i.flags&128)===0}function yd(i){if(Gt){var s=ti;if(s){var o=s;if(!zm(i,s)){if(xd(i))throw Error(t(418));s=Fr(o.nextSibling);var f=ei;s&&zm(i,s)?jm(f,o):(i.flags=i.flags&-4097|2,Gt=!1,ei=i)}}else{if(xd(i))throw Error(t(418));i.flags=i.flags&-4097|2,Gt=!1,ei=i}}}function Bm(i){for(i=i.return;i!==null&&i.tag!==5&&i.tag!==3&&i.tag!==13;)i=i.return;ei=i}function Hl(i){if(i!==ei)return!1;if(!Gt)return Bm(i),Gt=!0,!1;var s;if((s=i.tag!==3)&&!(s=i.tag!==5)&&(s=i.type,s=s!=="head"&&s!=="body"&&!dd(i.type,i.memoizedProps)),s&&(s=ti)){if(xd(i))throw Hm(),Error(t(418));for(;s;)jm(i,s),s=Fr(s.nextSibling)}if(Bm(i),i.tag===13){if(i=i.memoizedState,i=i!==null?i.dehydrated:null,!i)throw Error(t(317));e:{for(i=i.nextSibling,s=0;i;){if(i.nodeType===8){var o=i.data;if(o==="/$"){if(s===0){ti=Fr(i.nextSibling);break e}s--}else o!=="$"&&o!=="$!"&&o!=="$?"||s++}i=i.nextSibling}ti=null}}else ti=ei?Fr(i.stateNode.nextSibling):null;return!0}function Hm(){for(var i=ti;i;)i=Fr(i.nextSibling)}function ha(){ti=ei=null,Gt=!1}function Sd(i){bi===null?bi=[i]:bi.push(i)}var P1=R.ReactCurrentBatchConfig;function Ao(i,s,o){if(i=o.ref,i!==null&&typeof i!="function"&&typeof i!="object"){if(o._owner){if(o=o._owner,o){if(o.tag!==1)throw Error(t(309));var f=o.stateNode}if(!f)throw Error(t(147,i));var m=f,S=""+i;return s!==null&&s.ref!==null&&typeof s.ref=="function"&&s.ref._stringRef===S?s.ref:(s=function(b){var F=m.refs;b===null?delete F[S]:F[S]=b},s._stringRef=S,s)}if(typeof i!="string")throw Error(t(284));if(!o._owner)throw Error(t(290,i))}return i}function Vl(i,s){throw i=Object.prototype.toString.call(s),Error(t(31,i==="[object Object]"?"object with keys {"+Object.keys(s).join(", ")+"}":i))}function Vm(i){var s=i._init;return s(i._payload)}function Gm(i){function s(Y,H){if(i){var Z=Y.deletions;Z===null?(Y.deletions=[H],Y.flags|=16):Z.push(H)}}function o(Y,H){if(!i)return null;for(;H!==null;)s(Y,H),H=H.sibling;return null}function f(Y,H){for(Y=new Map;H!==null;)H.key!==null?Y.set(H.key,H):Y.set(H.index,H),H=H.sibling;return Y}function m(Y,H){return Y=qr(Y,H),Y.index=0,Y.sibling=null,Y}function S(Y,H,Z){return Y.index=Z,i?(Z=Y.alternate,Z!==null?(Z=Z.index,Z<H?(Y.flags|=2,H):Z):(Y.flags|=2,H)):(Y.flags|=1048576,H)}function b(Y){return i&&Y.alternate===null&&(Y.flags|=2),Y}function F(Y,H,Z,Ne){return H===null||H.tag!==6?(H=hf(Z,Y.mode,Ne),H.return=Y,H):(H=m(H,Z),H.return=Y,H)}function j(Y,H,Z,Ne){var Ke=Z.type;return Ke===U?ye(Y,H,Z.props.children,Ne,Z.key):H!==null&&(H.elementType===Ke||typeof Ke=="object"&&Ke!==null&&Ke.$$typeof===V&&Vm(Ke)===H.type)?(Ne=m(H,Z.props),Ne.ref=Ao(Y,H,Z),Ne.return=Y,Ne):(Ne=hc(Z.type,Z.key,Z.props,null,Y.mode,Ne),Ne.ref=Ao(Y,H,Z),Ne.return=Y,Ne)}function ie(Y,H,Z,Ne){return H===null||H.tag!==4||H.stateNode.containerInfo!==Z.containerInfo||H.stateNode.implementation!==Z.implementation?(H=pf(Z,Y.mode,Ne),H.return=Y,H):(H=m(H,Z.children||[]),H.return=Y,H)}function ye(Y,H,Z,Ne,Ke){return H===null||H.tag!==7?(H=Ts(Z,Y.mode,Ne,Ke),H.return=Y,H):(H=m(H,Z),H.return=Y,H)}function Me(Y,H,Z){if(typeof H=="string"&&H!==""||typeof H=="number")return H=hf(""+H,Y.mode,Z),H.return=Y,H;if(typeof H=="object"&&H!==null){switch(H.$$typeof){case L:return Z=hc(H.type,H.key,H.props,null,Y.mode,Z),Z.ref=Ao(Y,null,H),Z.return=Y,Z;case D:return H=pf(H,Y.mode,Z),H.return=Y,H;case V:var Ne=H._init;return Me(Y,Ne(H._payload),Z)}if(I(H)||ue(H))return H=Ts(H,Y.mode,Z,null),H.return=Y,H;Vl(Y,H)}return null}function xe(Y,H,Z,Ne){var Ke=H!==null?H.key:null;if(typeof Z=="string"&&Z!==""||typeof Z=="number")return Ke!==null?null:F(Y,H,""+Z,Ne);if(typeof Z=="object"&&Z!==null){switch(Z.$$typeof){case L:return Z.key===Ke?j(Y,H,Z,Ne):null;case D:return Z.key===Ke?ie(Y,H,Z,Ne):null;case V:return Ke=Z._init,xe(Y,H,Ke(Z._payload),Ne)}if(I(Z)||ue(Z))return Ke!==null?null:ye(Y,H,Z,Ne,null);Vl(Y,Z)}return null}function ze(Y,H,Z,Ne,Ke){if(typeof Ne=="string"&&Ne!==""||typeof Ne=="number")return Y=Y.get(Z)||null,F(H,Y,""+Ne,Ke);if(typeof Ne=="object"&&Ne!==null){switch(Ne.$$typeof){case L:return Y=Y.get(Ne.key===null?Z:Ne.key)||null,j(H,Y,Ne,Ke);case D:return Y=Y.get(Ne.key===null?Z:Ne.key)||null,ie(H,Y,Ne,Ke);case V:var Qe=Ne._init;return ze(Y,H,Z,Qe(Ne._payload),Ke)}if(I(Ne)||ue(Ne))return Y=Y.get(Z)||null,ye(H,Y,Ne,Ke,null);Vl(H,Ne)}return null}function $e(Y,H,Z,Ne){for(var Ke=null,Qe=null,Je=H,ot=H=0,mn=null;Je!==null&&ot<Z.length;ot++){Je.index>ot?(mn=Je,Je=null):mn=Je.sibling;var wt=xe(Y,Je,Z[ot],Ne);if(wt===null){Je===null&&(Je=mn);break}i&&Je&&wt.alternate===null&&s(Y,Je),H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt,Je=mn}if(ot===Z.length)return o(Y,Je),Gt&&_s(Y,ot),Ke;if(Je===null){for(;ot<Z.length;ot++)Je=Me(Y,Z[ot],Ne),Je!==null&&(H=S(Je,H,ot),Qe===null?Ke=Je:Qe.sibling=Je,Qe=Je);return Gt&&_s(Y,ot),Ke}for(Je=f(Y,Je);ot<Z.length;ot++)mn=ze(Je,Y,ot,Z[ot],Ne),mn!==null&&(i&&mn.alternate!==null&&Je.delete(mn.key===null?ot:mn.key),H=S(mn,H,ot),Qe===null?Ke=mn:Qe.sibling=mn,Qe=mn);return i&&Je.forEach(function(Yr){return s(Y,Yr)}),Gt&&_s(Y,ot),Ke}function Xe(Y,H,Z,Ne){var Ke=ue(Z);if(typeof Ke!="function")throw Error(t(150));if(Z=Ke.call(Z),Z==null)throw Error(t(151));for(var Qe=Ke=null,Je=H,ot=H=0,mn=null,wt=Z.next();Je!==null&&!wt.done;ot++,wt=Z.next()){Je.index>ot?(mn=Je,Je=null):mn=Je.sibling;var Yr=xe(Y,Je,wt.value,Ne);if(Yr===null){Je===null&&(Je=mn);break}i&&Je&&Yr.alternate===null&&s(Y,Je),H=S(Yr,H,ot),Qe===null?Ke=Yr:Qe.sibling=Yr,Qe=Yr,Je=mn}if(wt.done)return o(Y,Je),Gt&&_s(Y,ot),Ke;if(Je===null){for(;!wt.done;ot++,wt=Z.next())wt=Me(Y,wt.value,Ne),wt!==null&&(H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt);return Gt&&_s(Y,ot),Ke}for(Je=f(Y,Je);!wt.done;ot++,wt=Z.next())wt=ze(Je,Y,ot,wt.value,Ne),wt!==null&&(i&&wt.alternate!==null&&Je.delete(wt.key===null?ot:wt.key),H=S(wt,H,ot),Qe===null?Ke=wt:Qe.sibling=wt,Qe=wt);return i&&Je.forEach(function(uy){return s(Y,uy)}),Gt&&_s(Y,ot),Ke}function Kt(Y,H,Z,Ne){if(typeof Z=="object"&&Z!==null&&Z.type===U&&Z.key===null&&(Z=Z.props.children),typeof Z=="object"&&Z!==null){switch(Z.$$typeof){case L:e:{for(var Ke=Z.key,Qe=H;Qe!==null;){if(Qe.key===Ke){if(Ke=Z.type,Ke===U){if(Qe.tag===7){o(Y,Qe.sibling),H=m(Qe,Z.props.children),H.return=Y,Y=H;break e}}else if(Qe.elementType===Ke||typeof Ke=="object"&&Ke!==null&&Ke.$$typeof===V&&Vm(Ke)===Qe.type){o(Y,Qe.sibling),H=m(Qe,Z.props),H.ref=Ao(Y,Qe,Z),H.return=Y,Y=H;break e}o(Y,Qe);break}else s(Y,Qe);Qe=Qe.sibling}Z.type===U?(H=Ts(Z.props.children,Y.mode,Ne,Z.key),H.return=Y,Y=H):(Ne=hc(Z.type,Z.key,Z.props,null,Y.mode,Ne),Ne.ref=Ao(Y,H,Z),Ne.return=Y,Y=Ne)}return b(Y);case D:e:{for(Qe=Z.key;H!==null;){if(H.key===Qe)if(H.tag===4&&H.stateNode.containerInfo===Z.containerInfo&&H.stateNode.implementation===Z.implementation){o(Y,H.sibling),H=m(H,Z.children||[]),H.return=Y,Y=H;break e}else{o(Y,H);break}else s(Y,H);H=H.sibling}H=pf(Z,Y.mode,Ne),H.return=Y,Y=H}return b(Y);case V:return Qe=Z._init,Kt(Y,H,Qe(Z._payload),Ne)}if(I(Z))return $e(Y,H,Z,Ne);if(ue(Z))return Xe(Y,H,Z,Ne);Vl(Y,Z)}return typeof Z=="string"&&Z!==""||typeof Z=="number"?(Z=""+Z,H!==null&&H.tag===6?(o(Y,H.sibling),H=m(H,Z),H.return=Y,Y=H):(o(Y,H),H=hf(Z,Y.mode,Ne),H.return=Y,Y=H),b(Y)):o(Y,H)}return Kt}var pa=Gm(!0),Wm=Gm(!1),Gl=Or(null),Wl=null,ma=null,Md=null;function Ed(){Md=ma=Wl=null}function wd(i){var s=Gl.current;zt(Gl),i._currentValue=s}function Td(i,s,o){for(;i!==null;){var f=i.alternate;if((i.childLanes&s)!==s?(i.childLanes|=s,f!==null&&(f.childLanes|=s)):f!==null&&(f.childLanes&s)!==s&&(f.childLanes|=s),i===o)break;i=i.return}}function ga(i,s){Wl=i,Md=ma=null,i=i.dependencies,i!==null&&i.firstContext!==null&&((i.lanes&s)!==0&&(zn=!0),i.firstContext=null)}function fi(i){var s=i._currentValue;if(Md!==i)if(i={context:i,memoizedValue:s,next:null},ma===null){if(Wl===null)throw Error(t(308));ma=i,Wl.dependencies={lanes:0,firstContext:i}}else ma=ma.next=i;return s}var vs=null;function bd(i){vs===null?vs=[i]:vs.push(i)}function $m(i,s,o,f){var m=s.interleaved;return m===null?(o.next=o,bd(s)):(o.next=m.next,m.next=o),s.interleaved=o,or(i,f)}function or(i,s){i.lanes|=s;var o=i.alternate;for(o!==null&&(o.lanes|=s),o=i,i=i.return;i!==null;)i.childLanes|=s,o=i.alternate,o!==null&&(o.childLanes|=s),o=i,i=i.return;return o.tag===3?o.stateNode:null}var Br=!1;function Ad(i){i.updateQueue={baseState:i.memoizedState,firstBaseUpdate:null,lastBaseUpdate:null,shared:{pending:null,interleaved:null,lanes:0},effects:null}}function Xm(i,s){i=i.updateQueue,s.updateQueue===i&&(s.updateQueue={baseState:i.baseState,firstBaseUpdate:i.firstBaseUpdate,lastBaseUpdate:i.lastBaseUpdate,shared:i.shared,effects:i.effects})}function lr(i,s){return{eventTime:i,lane:s,tag:0,payload:null,callback:null,next:null}}function Hr(i,s,o){var f=i.updateQueue;if(f===null)return null;if(f=f.shared,(St&2)!==0){var m=f.pending;return m===null?s.next=s:(s.next=m.next,m.next=s),f.pending=s,or(i,o)}return m=f.interleaved,m===null?(s.next=s,bd(f)):(s.next=m.next,m.next=s),f.interleaved=s,or(i,o)}function $l(i,s,o){if(s=s.updateQueue,s!==null&&(s=s.shared,(o&4194240)!==0)){var f=s.lanes;f&=i.pendingLanes,o|=f,s.lanes=o,Bu(i,o)}}function qm(i,s){var o=i.updateQueue,f=i.alternate;if(f!==null&&(f=f.updateQueue,o===f)){var m=null,S=null;if(o=o.firstBaseUpdate,o!==null){do{var b={eventTime:o.eventTime,lane:o.lane,tag:o.tag,payload:o.payload,callback:o.callback,next:null};S===null?m=S=b:S=S.next=b,o=o.next}while(o!==null);S===null?m=S=s:S=S.next=s}else m=S=s;o={baseState:f.baseState,firstBaseUpdate:m,lastBaseUpdate:S,shared:f.shared,effects:f.effects},i.updateQueue=o;return}i=o.lastBaseUpdate,i===null?o.firstBaseUpdate=s:i.next=s,o.lastBaseUpdate=s}function Xl(i,s,o,f){var m=i.updateQueue;Br=!1;var S=m.firstBaseUpdate,b=m.lastBaseUpdate,F=m.shared.pending;if(F!==null){m.shared.pending=null;var j=F,ie=j.next;j.next=null,b===null?S=ie:b.next=ie,b=j;var ye=i.alternate;ye!==null&&(ye=ye.updateQueue,F=ye.lastBaseUpdate,F!==b&&(F===null?ye.firstBaseUpdate=ie:F.next=ie,ye.lastBaseUpdate=j))}if(S!==null){var Me=m.baseState;b=0,ye=ie=j=null,F=S;do{var xe=F.lane,ze=F.eventTime;if((f&xe)===xe){ye!==null&&(ye=ye.next={eventTime:ze,lane:0,tag:F.tag,payload:F.payload,callback:F.callback,next:null});e:{var $e=i,Xe=F;switch(xe=s,ze=o,Xe.tag){case 1:if($e=Xe.payload,typeof $e=="function"){Me=$e.call(ze,Me,xe);break e}Me=$e;break e;case 3:$e.flags=$e.flags&-65537|128;case 0:if($e=Xe.payload,xe=typeof $e=="function"?$e.call(ze,Me,xe):$e,xe==null)break e;Me=oe({},Me,xe);break e;case 2:Br=!0}}F.callback!==null&&F.lane!==0&&(i.flags|=64,xe=m.effects,xe===null?m.effects=[F]:xe.push(F))}else ze={eventTime:ze,lane:xe,tag:F.tag,payload:F.payload,callback:F.callback,next:null},ye===null?(ie=ye=ze,j=Me):ye=ye.next=ze,b|=xe;if(F=F.next,F===null){if(F=m.shared.pending,F===null)break;xe=F,F=xe.next,xe.next=null,m.lastBaseUpdate=xe,m.shared.pending=null}}while(!0);if(ye===null&&(j=Me),m.baseState=j,m.firstBaseUpdate=ie,m.lastBaseUpdate=ye,s=m.shared.interleaved,s!==null){m=s;do b|=m.lane,m=m.next;while(m!==s)}else S===null&&(m.shared.lanes=0);Ss|=b,i.lanes=b,i.memoizedState=Me}}function Ym(i,s,o){if(i=s.effects,s.effects=null,i!==null)for(s=0;s<i.length;s++){var f=i[s],m=f.callback;if(m!==null){if(f.callback=null,f=o,typeof m!="function")throw Error(t(191,m));m.call(f)}}}var Co={},Vi=Or(Co),No=Or(Co),Ro=Or(Co);function xs(i){if(i===Co)throw Error(t(174));return i}function Cd(i,s){switch(Ft(Ro,s),Ft(No,i),Ft(Vi,Co),i=s.nodeType,i){case 9:case 11:s=(s=s.documentElement)?s.namespaceURI:Le(null,"");break;default:i=i===8?s.parentNode:s,s=i.namespaceURI||null,i=i.tagName,s=Le(s,i)}zt(Vi),Ft(Vi,s)}function _a(){zt(Vi),zt(No),zt(Ro)}function Km(i){xs(Ro.current);var s=xs(Vi.current),o=Le(s,i.type);s!==o&&(Ft(No,i),Ft(Vi,o))}function Nd(i){No.current===i&&(zt(Vi),zt(No))}var Xt=Or(0);function ql(i){for(var s=i;s!==null;){if(s.tag===13){var o=s.memoizedState;if(o!==null&&(o=o.dehydrated,o===null||o.data==="$?"||o.data==="$!"))return s}else if(s.tag===19&&s.memoizedProps.revealOrder!==void 0){if((s.flags&128)!==0)return s}else if(s.child!==null){s.child.return=s,s=s.child;continue}if(s===i)break;for(;s.sibling===null;){if(s.return===null||s.return===i)return null;s=s.return}s.sibling.return=s.return,s=s.sibling}return null}var Rd=[];function Pd(){for(var i=0;i<Rd.length;i++)Rd[i]._workInProgressVersionPrimary=null;Rd.length=0}var Yl=R.ReactCurrentDispatcher,Ld=R.ReactCurrentBatchConfig,ys=0,qt=null,sn=null,hn=null,Kl=!1,Po=!1,Lo=0,L1=0;function bn(){throw Error(t(321))}function kd(i,s){if(s===null)return!1;for(var o=0;o<s.length&&o<i.length;o++)if(!Ti(i[o],s[o]))return!1;return!0}function Dd(i,s,o,f,m,S){if(ys=S,qt=s,s.memoizedState=null,s.updateQueue=null,s.lanes=0,Yl.current=i===null||i.memoizedState===null?U1:F1,i=o(f,m),Po){S=0;do{if(Po=!1,Lo=0,25<=S)throw Error(t(301));S+=1,hn=sn=null,s.updateQueue=null,Yl.current=O1,i=o(f,m)}while(Po)}if(Yl.current=Jl,s=sn!==null&&sn.next!==null,ys=0,hn=sn=qt=null,Kl=!1,s)throw Error(t(300));return i}function Id(){var i=Lo!==0;return Lo=0,i}function Gi(){var i={memoizedState:null,baseState:null,baseQueue:null,queue:null,next:null};return hn===null?qt.memoizedState=hn=i:hn=hn.next=i,hn}function hi(){if(sn===null){var i=qt.alternate;i=i!==null?i.memoizedState:null}else i=sn.next;var s=hn===null?qt.memoizedState:hn.next;if(s!==null)hn=s,sn=i;else{if(i===null)throw Error(t(310));sn=i,i={memoizedState:sn.memoizedState,baseState:sn.baseState,baseQueue:sn.baseQueue,queue:sn.queue,next:null},hn===null?qt.memoizedState=hn=i:hn=hn.next=i}return hn}function ko(i,s){return typeof s=="function"?s(i):s}function Ud(i){var s=hi(),o=s.queue;if(o===null)throw Error(t(311));o.lastRenderedReducer=i;var f=sn,m=f.baseQueue,S=o.pending;if(S!==null){if(m!==null){var b=m.next;m.next=S.next,S.next=b}f.baseQueue=m=S,o.pending=null}if(m!==null){S=m.next,f=f.baseState;var F=b=null,j=null,ie=S;do{var ye=ie.lane;if((ys&ye)===ye)j!==null&&(j=j.next={lane:0,action:ie.action,hasEagerState:ie.hasEagerState,eagerState:ie.eagerState,next:null}),f=ie.hasEagerState?ie.eagerState:i(f,ie.action);else{var Me={lane:ye,action:ie.action,hasEagerState:ie.hasEagerState,eagerState:ie.eagerState,next:null};j===null?(F=j=Me,b=f):j=j.next=Me,qt.lanes|=ye,Ss|=ye}ie=ie.next}while(ie!==null&&ie!==S);j===null?b=f:j.next=F,Ti(f,s.memoizedState)||(zn=!0),s.memoizedState=f,s.baseState=b,s.baseQueue=j,o.lastRenderedState=f}if(i=o.interleaved,i!==null){m=i;do S=m.lane,qt.lanes|=S,Ss|=S,m=m.next;while(m!==i)}else m===null&&(o.lanes=0);return[s.memoizedState,o.dispatch]}function Fd(i){var s=hi(),o=s.queue;if(o===null)throw Error(t(311));o.lastRenderedReducer=i;var f=o.dispatch,m=o.pending,S=s.memoizedState;if(m!==null){o.pending=null;var b=m=m.next;do S=i(S,b.action),b=b.next;while(b!==m);Ti(S,s.memoizedState)||(zn=!0),s.memoizedState=S,s.baseQueue===null&&(s.baseState=S),o.lastRenderedState=S}return[S,f]}function Zm(){}function Qm(i,s){var o=qt,f=hi(),m=s(),S=!Ti(f.memoizedState,m);if(S&&(f.memoizedState=m,zn=!0),f=f.queue,Od(t0.bind(null,o,f,i),[i]),f.getSnapshot!==s||S||hn!==null&&hn.memoizedState.tag&1){if(o.flags|=2048,Do(9,e0.bind(null,o,f,m,s),void 0,null),pn===null)throw Error(t(349));(ys&30)!==0||Jm(o,s,m)}return m}function Jm(i,s,o){i.flags|=16384,i={getSnapshot:s,value:o},s=qt.updateQueue,s===null?(s={lastEffect:null,stores:null},qt.updateQueue=s,s.stores=[i]):(o=s.stores,o===null?s.stores=[i]:o.push(i))}function e0(i,s,o,f){s.value=o,s.getSnapshot=f,n0(s)&&i0(i)}function t0(i,s,o){return o(function(){n0(s)&&i0(i)})}function n0(i){var s=i.getSnapshot;i=i.value;try{var o=s();return!Ti(i,o)}catch{return!0}}function i0(i){var s=or(i,1);s!==null&&Ri(s,i,1,-1)}function r0(i){var s=Gi();return typeof i=="function"&&(i=i()),s.memoizedState=s.baseState=i,i={pending:null,interleaved:null,lanes:0,dispatch:null,lastRenderedReducer:ko,lastRenderedState:i},s.queue=i,i=i.dispatch=I1.bind(null,qt,i),[s.memoizedState,i]}function Do(i,s,o,f){return i={tag:i,create:s,destroy:o,deps:f,next:null},s=qt.updateQueue,s===null?(s={lastEffect:null,stores:null},qt.updateQueue=s,s.lastEffect=i.next=i):(o=s.lastEffect,o===null?s.lastEffect=i.next=i:(f=o.next,o.next=i,i.next=f,s.lastEffect=i)),i}function s0(){return hi().memoizedState}function Zl(i,s,o,f){var m=Gi();qt.flags|=i,m.memoizedState=Do(1|s,o,void 0,f===void 0?null:f)}function Ql(i,s,o,f){var m=hi();f=f===void 0?null:f;var S=void 0;if(sn!==null){var b=sn.memoizedState;if(S=b.destroy,f!==null&&kd(f,b.deps)){m.memoizedState=Do(s,o,S,f);return}}qt.flags|=i,m.memoizedState=Do(1|s,o,S,f)}function a0(i,s){return Zl(8390656,8,i,s)}function Od(i,s){return Ql(2048,8,i,s)}function o0(i,s){return Ql(4,2,i,s)}function l0(i,s){return Ql(4,4,i,s)}function c0(i,s){if(typeof s=="function")return i=i(),s(i),function(){s(null)};if(s!=null)return i=i(),s.current=i,function(){s.current=null}}function u0(i,s,o){return o=o!=null?o.concat([i]):null,Ql(4,4,c0.bind(null,s,i),o)}function jd(){}function d0(i,s){var o=hi();s=s===void 0?null:s;var f=o.memoizedState;return f!==null&&s!==null&&kd(s,f[1])?f[0]:(o.memoizedState=[i,s],i)}function f0(i,s){var o=hi();s=s===void 0?null:s;var f=o.memoizedState;return f!==null&&s!==null&&kd(s,f[1])?f[0]:(i=i(),o.memoizedState=[i,s],i)}function h0(i,s,o){return(ys&21)===0?(i.baseState&&(i.baseState=!1,zn=!0),i.memoizedState=o):(Ti(o,s)||(o=ea(),qt.lanes|=o,Ss|=o,i.baseState=!0),s)}function k1(i,s){var o=Lt;Lt=o!==0&&4>o?o:4,i(!0);var f=Ld.transition;Ld.transition={};try{i(!1),s()}finally{Lt=o,Ld.transition=f}}function p0(){return hi().memoizedState}function D1(i,s,o){var f=$r(i);if(o={lane:f,action:o,hasEagerState:!1,eagerState:null,next:null},m0(i))g0(s,o);else if(o=$m(i,s,o,f),o!==null){var m=In();Ri(o,i,f,m),_0(o,s,f)}}function I1(i,s,o){var f=$r(i),m={lane:f,action:o,hasEagerState:!1,eagerState:null,next:null};if(m0(i))g0(s,m);else{var S=i.alternate;if(i.lanes===0&&(S===null||S.lanes===0)&&(S=s.lastRenderedReducer,S!==null))try{var b=s.lastRenderedState,F=S(b,o);if(m.hasEagerState=!0,m.eagerState=F,Ti(F,b)){var j=s.interleaved;j===null?(m.next=m,bd(s)):(m.next=j.next,j.next=m),s.interleaved=m;return}}catch{}finally{}o=$m(i,s,m,f),o!==null&&(m=In(),Ri(o,i,f,m),_0(o,s,f))}}function m0(i){var s=i.alternate;return i===qt||s!==null&&s===qt}function g0(i,s){Po=Kl=!0;var o=i.pending;o===null?s.next=s:(s.next=o.next,o.next=s),i.pending=s}function _0(i,s,o){if((o&4194240)!==0){var f=s.lanes;f&=i.pendingLanes,o|=f,s.lanes=o,Bu(i,o)}}var Jl={readContext:fi,useCallback:bn,useContext:bn,useEffect:bn,useImperativeHandle:bn,useInsertionEffect:bn,useLayoutEffect:bn,useMemo:bn,useReducer:bn,useRef:bn,useState:bn,useDebugValue:bn,useDeferredValue:bn,useTransition:bn,useMutableSource:bn,useSyncExternalStore:bn,useId:bn,unstable_isNewReconciler:!1},U1={readContext:fi,useCallback:function(i,s){return Gi().memoizedState=[i,s===void 0?null:s],i},useContext:fi,useEffect:a0,useImperativeHandle:function(i,s,o){return o=o!=null?o.concat([i]):null,Zl(4194308,4,c0.bind(null,s,i),o)},useLayoutEffect:function(i,s){return Zl(4194308,4,i,s)},useInsertionEffect:function(i,s){return Zl(4,2,i,s)},useMemo:function(i,s){var o=Gi();return s=s===void 0?null:s,i=i(),o.memoizedState=[i,s],i},useReducer:function(i,s,o){var f=Gi();return s=o!==void 0?o(s):s,f.memoizedState=f.baseState=s,i={pending:null,interleaved:null,lanes:0,dispatch:null,lastRenderedReducer:i,lastRenderedState:s},f.queue=i,i=i.dispatch=D1.bind(null,qt,i),[f.memoizedState,i]},useRef:function(i){var s=Gi();return i={current:i},s.memoizedState=i},useState:r0,useDebugValue:jd,useDeferredValue:function(i){return Gi().memoizedState=i},useTransition:function(){var i=r0(!1),s=i[0];return i=k1.bind(null,i[1]),Gi().memoizedState=i,[s,i]},useMutableSource:function(){},useSyncExternalStore:function(i,s,o){var f=qt,m=Gi();if(Gt){if(o===void 0)throw Error(t(407));o=o()}else{if(o=s(),pn===null)throw Error(t(349));(ys&30)!==0||Jm(f,s,o)}m.memoizedState=o;var S={value:o,getSnapshot:s};return m.queue=S,a0(t0.bind(null,f,S,i),[i]),f.flags|=2048,Do(9,e0.bind(null,f,S,o,s),void 0,null),o},useId:function(){var i=Gi(),s=pn.identifierPrefix;if(Gt){var o=ar,f=sr;o=(f&~(1<<32-Ve(f)-1)).toString(32)+o,s=":"+s+"R"+o,o=Lo++,0<o&&(s+="H"+o.toString(32)),s+=":"}else o=L1++,s=":"+s+"r"+o.toString(32)+":";return i.memoizedState=s},unstable_isNewReconciler:!1},F1={readContext:fi,useCallback:d0,useContext:fi,useEffect:Od,useImperativeHandle:u0,useInsertionEffect:o0,useLayoutEffect:l0,useMemo:f0,useReducer:Ud,useRef:s0,useState:function(){return Ud(ko)},useDebugValue:jd,useDeferredValue:function(i){var s=hi();return h0(s,sn.memoizedState,i)},useTransition:function(){var i=Ud(ko)[0],s=hi().memoizedState;return[i,s]},useMutableSource:Zm,useSyncExternalStore:Qm,useId:p0,unstable_isNewReconciler:!1},O1={readContext:fi,useCallback:d0,useContext:fi,useEffect:Od,useImperativeHandle:u0,useInsertionEffect:o0,useLayoutEffect:l0,useMemo:f0,useReducer:Fd,useRef:s0,useState:function(){return Fd(ko)},useDebugValue:jd,useDeferredValue:function(i){var s=hi();return sn===null?s.memoizedState=i:h0(s,sn.memoizedState,i)},useTransition:function(){var i=Fd(ko)[0],s=hi().memoizedState;return[i,s]},useMutableSource:Zm,useSyncExternalStore:Qm,useId:p0,unstable_isNewReconciler:!1};function Ai(i,s){if(i&&i.defaultProps){s=oe({},s),i=i.defaultProps;for(var o in i)s[o]===void 0&&(s[o]=i[o]);return s}return s}function zd(i,s,o,f){s=i.memoizedState,o=o(f,s),o=o==null?s:oe({},s,o),i.memoizedState=o,i.lanes===0&&(i.updateQueue.baseState=o)}var ec={isMounted:function(i){return(i=i._reactInternals)?tr(i)===i:!1},enqueueSetState:function(i,s,o){i=i._reactInternals;var f=In(),m=$r(i),S=lr(f,m);S.payload=s,o!=null&&(S.callback=o),s=Hr(i,S,m),s!==null&&(Ri(s,i,m,f),$l(s,i,m))},enqueueReplaceState:function(i,s,o){i=i._reactInternals;var f=In(),m=$r(i),S=lr(f,m);S.tag=1,S.payload=s,o!=null&&(S.callback=o),s=Hr(i,S,m),s!==null&&(Ri(s,i,m,f),$l(s,i,m))},enqueueForceUpdate:function(i,s){i=i._reactInternals;var o=In(),f=$r(i),m=lr(o,f);m.tag=2,s!=null&&(m.callback=s),s=Hr(i,m,f),s!==null&&(Ri(s,i,f,o),$l(s,i,f))}};function v0(i,s,o,f,m,S,b){return i=i.stateNode,typeof i.shouldComponentUpdate=="function"?i.shouldComponentUpdate(f,S,b):s.prototype&&s.prototype.isPureReactComponent?!yo(o,f)||!yo(m,S):!0}function x0(i,s,o){var f=!1,m=jr,S=s.contextType;return typeof S=="object"&&S!==null?S=fi(S):(m=jn(s)?ms:Tn.current,f=s.contextTypes,S=(f=f!=null)?ua(i,m):jr),s=new s(o,S),i.memoizedState=s.state!==null&&s.state!==void 0?s.state:null,s.updater=ec,i.stateNode=s,s._reactInternals=i,f&&(i=i.stateNode,i.__reactInternalMemoizedUnmaskedChildContext=m,i.__reactInternalMemoizedMaskedChildContext=S),s}function y0(i,s,o,f){i=s.state,typeof s.componentWillReceiveProps=="function"&&s.componentWillReceiveProps(o,f),typeof s.UNSAFE_componentWillReceiveProps=="function"&&s.UNSAFE_componentWillReceiveProps(o,f),s.state!==i&&ec.enqueueReplaceState(s,s.state,null)}function Bd(i,s,o,f){var m=i.stateNode;m.props=o,m.state=i.memoizedState,m.refs={},Ad(i);var S=s.contextType;typeof S=="object"&&S!==null?m.context=fi(S):(S=jn(s)?ms:Tn.current,m.context=ua(i,S)),m.state=i.memoizedState,S=s.getDerivedStateFromProps,typeof S=="function"&&(zd(i,s,S,o),m.state=i.memoizedState),typeof s.getDerivedStateFromProps=="function"||typeof m.getSnapshotBeforeUpdate=="function"||typeof m.UNSAFE_componentWillMount!="function"&&typeof m.componentWillMount!="function"||(s=m.state,typeof m.componentWillMount=="function"&&m.componentWillMount(),typeof m.UNSAFE_componentWillMount=="function"&&m.UNSAFE_componentWillMount(),s!==m.state&&ec.enqueueReplaceState(m,m.state,null),Xl(i,o,m,f),m.state=i.memoizedState),typeof m.componentDidMount=="function"&&(i.flags|=4194308)}function va(i,s){try{var o="",f=s;do o+=he(f),f=f.return;while(f);var m=o}catch(S){m=`
Error generating stack: `+S.message+`
`+S.stack}return{value:i,source:s,stack:m,digest:null}}function Hd(i,s,o){return{value:i,source:null,stack:o??null,digest:s??null}}function Vd(i,s){try{console.error(s.value)}catch(o){setTimeout(function(){throw o})}}var j1=typeof WeakMap=="function"?WeakMap:Map;function S0(i,s,o){o=lr(-1,o),o.tag=3,o.payload={element:null};var f=s.value;return o.callback=function(){oc||(oc=!0,sf=f),Vd(i,s)},o}function M0(i,s,o){o=lr(-1,o),o.tag=3;var f=i.type.getDerivedStateFromError;if(typeof f=="function"){var m=s.value;o.payload=function(){return f(m)},o.callback=function(){Vd(i,s)}}var S=i.stateNode;return S!==null&&typeof S.componentDidCatch=="function"&&(o.callback=function(){Vd(i,s),typeof f!="function"&&(Gr===null?Gr=new Set([this]):Gr.add(this));var b=s.stack;this.componentDidCatch(s.value,{componentStack:b!==null?b:""})}),o}function E0(i,s,o){var f=i.pingCache;if(f===null){f=i.pingCache=new j1;var m=new Set;f.set(s,m)}else m=f.get(s),m===void 0&&(m=new Set,f.set(s,m));m.has(o)||(m.add(o),i=J1.bind(null,i,s,o),s.then(i,i))}function w0(i){do{var s;if((s=i.tag===13)&&(s=i.memoizedState,s=s!==null?s.dehydrated!==null:!0),s)return i;i=i.return}while(i!==null);return null}function T0(i,s,o,f,m){return(i.mode&1)===0?(i===s?i.flags|=65536:(i.flags|=128,o.flags|=131072,o.flags&=-52805,o.tag===1&&(o.alternate===null?o.tag=17:(s=lr(-1,1),s.tag=2,Hr(o,s,1))),o.lanes|=1),i):(i.flags|=65536,i.lanes=m,i)}var z1=R.ReactCurrentOwner,zn=!1;function Dn(i,s,o,f){s.child=i===null?Wm(s,null,o,f):pa(s,i.child,o,f)}function b0(i,s,o,f,m){o=o.render;var S=s.ref;return ga(s,m),f=Dd(i,s,o,f,S,m),o=Id(),i!==null&&!zn?(s.updateQueue=i.updateQueue,s.flags&=-2053,i.lanes&=~m,cr(i,s,m)):(Gt&&o&&_d(s),s.flags|=1,Dn(i,s,f,m),s.child)}function A0(i,s,o,f,m){if(i===null){var S=o.type;return typeof S=="function"&&!ff(S)&&S.defaultProps===void 0&&o.compare===null&&o.defaultProps===void 0?(s.tag=15,s.type=S,C0(i,s,S,f,m)):(i=hc(o.type,null,f,s,s.mode,m),i.ref=s.ref,i.return=s,s.child=i)}if(S=i.child,(i.lanes&m)===0){var b=S.memoizedProps;if(o=o.compare,o=o!==null?o:yo,o(b,f)&&i.ref===s.ref)return cr(i,s,m)}return s.flags|=1,i=qr(S,f),i.ref=s.ref,i.return=s,s.child=i}function C0(i,s,o,f,m){if(i!==null){var S=i.memoizedProps;if(yo(S,f)&&i.ref===s.ref)if(zn=!1,s.pendingProps=f=S,(i.lanes&m)!==0)(i.flags&131072)!==0&&(zn=!0);else return s.lanes=i.lanes,cr(i,s,m)}return Gd(i,s,o,f,m)}function N0(i,s,o){var f=s.pendingProps,m=f.children,S=i!==null?i.memoizedState:null;if(f.mode==="hidden")if((s.mode&1)===0)s.memoizedState={baseLanes:0,cachePool:null,transitions:null},Ft(ya,ni),ni|=o;else{if((o&1073741824)===0)return i=S!==null?S.baseLanes|o:o,s.lanes=s.childLanes=1073741824,s.memoizedState={baseLanes:i,cachePool:null,transitions:null},s.updateQueue=null,Ft(ya,ni),ni|=i,null;s.memoizedState={baseLanes:0,cachePool:null,transitions:null},f=S!==null?S.baseLanes:o,Ft(ya,ni),ni|=f}else S!==null?(f=S.baseLanes|o,s.memoizedState=null):f=o,Ft(ya,ni),ni|=f;return Dn(i,s,m,o),s.child}function R0(i,s){var o=s.ref;(i===null&&o!==null||i!==null&&i.ref!==o)&&(s.flags|=512,s.flags|=2097152)}function Gd(i,s,o,f,m){var S=jn(o)?ms:Tn.current;return S=ua(s,S),ga(s,m),o=Dd(i,s,o,f,S,m),f=Id(),i!==null&&!zn?(s.updateQueue=i.updateQueue,s.flags&=-2053,i.lanes&=~m,cr(i,s,m)):(Gt&&f&&_d(s),s.flags|=1,Dn(i,s,o,m),s.child)}function P0(i,s,o,f,m){if(jn(o)){var S=!0;Ol(s)}else S=!1;if(ga(s,m),s.stateNode===null)nc(i,s),x0(s,o,f),Bd(s,o,f,m),f=!0;else if(i===null){var b=s.stateNode,F=s.memoizedProps;b.props=F;var j=b.context,ie=o.contextType;typeof ie=="object"&&ie!==null?ie=fi(ie):(ie=jn(o)?ms:Tn.current,ie=ua(s,ie));var ye=o.getDerivedStateFromProps,Me=typeof ye=="function"||typeof b.getSnapshotBeforeUpdate=="function";Me||typeof b.UNSAFE_componentWillReceiveProps!="function"&&typeof b.componentWillReceiveProps!="function"||(F!==f||j!==ie)&&y0(s,b,f,ie),Br=!1;var xe=s.memoizedState;b.state=xe,Xl(s,f,b,m),j=s.memoizedState,F!==f||xe!==j||On.current||Br?(typeof ye=="function"&&(zd(s,o,ye,f),j=s.memoizedState),(F=Br||v0(s,o,F,f,xe,j,ie))?(Me||typeof b.UNSAFE_componentWillMount!="function"&&typeof b.componentWillMount!="function"||(typeof b.componentWillMount=="function"&&b.componentWillMount(),typeof b.UNSAFE_componentWillMount=="function"&&b.UNSAFE_componentWillMount()),typeof b.componentDidMount=="function"&&(s.flags|=4194308)):(typeof b.componentDidMount=="function"&&(s.flags|=4194308),s.memoizedProps=f,s.memoizedState=j),b.props=f,b.state=j,b.context=ie,f=F):(typeof b.componentDidMount=="function"&&(s.flags|=4194308),f=!1)}else{b=s.stateNode,Xm(i,s),F=s.memoizedProps,ie=s.type===s.elementType?F:Ai(s.type,F),b.props=ie,Me=s.pendingProps,xe=b.context,j=o.contextType,typeof j=="object"&&j!==null?j=fi(j):(j=jn(o)?ms:Tn.current,j=ua(s,j));var ze=o.getDerivedStateFromProps;(ye=typeof ze=="function"||typeof b.getSnapshotBeforeUpdate=="function")||typeof b.UNSAFE_componentWillReceiveProps!="function"&&typeof b.componentWillReceiveProps!="function"||(F!==Me||xe!==j)&&y0(s,b,f,j),Br=!1,xe=s.memoizedState,b.state=xe,Xl(s,f,b,m);var $e=s.memoizedState;F!==Me||xe!==$e||On.current||Br?(typeof ze=="function"&&(zd(s,o,ze,f),$e=s.memoizedState),(ie=Br||v0(s,o,ie,f,xe,$e,j)||!1)?(ye||typeof b.UNSAFE_componentWillUpdate!="function"&&typeof b.componentWillUpdate!="function"||(typeof b.componentWillUpdate=="function"&&b.componentWillUpdate(f,$e,j),typeof b.UNSAFE_componentWillUpdate=="function"&&b.UNSAFE_componentWillUpdate(f,$e,j)),typeof b.componentDidUpdate=="function"&&(s.flags|=4),typeof b.getSnapshotBeforeUpdate=="function"&&(s.flags|=1024)):(typeof b.componentDidUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(s.flags|=4),typeof b.getSnapshotBeforeUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(s.flags|=1024),s.memoizedProps=f,s.memoizedState=$e),b.props=f,b.state=$e,b.context=j,f=ie):(typeof b.componentDidUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(s.flags|=4),typeof b.getSnapshotBeforeUpdate!="function"||F===i.memoizedProps&&xe===i.memoizedState||(s.flags|=1024),f=!1)}return Wd(i,s,o,f,S,m)}function Wd(i,s,o,f,m,S){R0(i,s);var b=(s.flags&128)!==0;if(!f&&!b)return m&&Um(s,o,!1),cr(i,s,S);f=s.stateNode,z1.current=s;var F=b&&typeof o.getDerivedStateFromError!="function"?null:f.render();return s.flags|=1,i!==null&&b?(s.child=pa(s,i.child,null,S),s.child=pa(s,null,F,S)):Dn(i,s,F,S),s.memoizedState=f.state,m&&Um(s,o,!0),s.child}function L0(i){var s=i.stateNode;s.pendingContext?Dm(i,s.pendingContext,s.pendingContext!==s.context):s.context&&Dm(i,s.context,!1),Cd(i,s.containerInfo)}function k0(i,s,o,f,m){return ha(),Sd(m),s.flags|=256,Dn(i,s,o,f),s.child}var $d={dehydrated:null,treeContext:null,retryLane:0};function Xd(i){return{baseLanes:i,cachePool:null,transitions:null}}function D0(i,s,o){var f=s.pendingProps,m=Xt.current,S=!1,b=(s.flags&128)!==0,F;if((F=b)||(F=i!==null&&i.memoizedState===null?!1:(m&2)!==0),F?(S=!0,s.flags&=-129):(i===null||i.memoizedState!==null)&&(m|=1),Ft(Xt,m&1),i===null)return yd(s),i=s.memoizedState,i!==null&&(i=i.dehydrated,i!==null)?((s.mode&1)===0?s.lanes=1:i.data==="$!"?s.lanes=8:s.lanes=1073741824,null):(b=f.children,i=f.fallback,S?(f=s.mode,S=s.child,b={mode:"hidden",children:b},(f&1)===0&&S!==null?(S.childLanes=0,S.pendingProps=b):S=pc(b,f,0,null),i=Ts(i,f,o,null),S.return=s,i.return=s,S.sibling=i,s.child=S,s.child.memoizedState=Xd(o),s.memoizedState=$d,i):qd(s,b));if(m=i.memoizedState,m!==null&&(F=m.dehydrated,F!==null))return B1(i,s,b,f,F,m,o);if(S){S=f.fallback,b=s.mode,m=i.child,F=m.sibling;var j={mode:"hidden",children:f.children};return(b&1)===0&&s.child!==m?(f=s.child,f.childLanes=0,f.pendingProps=j,s.deletions=null):(f=qr(m,j),f.subtreeFlags=m.subtreeFlags&14680064),F!==null?S=qr(F,S):(S=Ts(S,b,o,null),S.flags|=2),S.return=s,f.return=s,f.sibling=S,s.child=f,f=S,S=s.child,b=i.child.memoizedState,b=b===null?Xd(o):{baseLanes:b.baseLanes|o,cachePool:null,transitions:b.transitions},S.memoizedState=b,S.childLanes=i.childLanes&~o,s.memoizedState=$d,f}return S=i.child,i=S.sibling,f=qr(S,{mode:"visible",children:f.children}),(s.mode&1)===0&&(f.lanes=o),f.return=s,f.sibling=null,i!==null&&(o=s.deletions,o===null?(s.deletions=[i],s.flags|=16):o.push(i)),s.child=f,s.memoizedState=null,f}function qd(i,s){return s=pc({mode:"visible",children:s},i.mode,0,null),s.return=i,i.child=s}function tc(i,s,o,f){return f!==null&&Sd(f),pa(s,i.child,null,o),i=qd(s,s.pendingProps.children),i.flags|=2,s.memoizedState=null,i}function B1(i,s,o,f,m,S,b){if(o)return s.flags&256?(s.flags&=-257,f=Hd(Error(t(422))),tc(i,s,b,f)):s.memoizedState!==null?(s.child=i.child,s.flags|=128,null):(S=f.fallback,m=s.mode,f=pc({mode:"visible",children:f.children},m,0,null),S=Ts(S,m,b,null),S.flags|=2,f.return=s,S.return=s,f.sibling=S,s.child=f,(s.mode&1)!==0&&pa(s,i.child,null,b),s.child.memoizedState=Xd(b),s.memoizedState=$d,S);if((s.mode&1)===0)return tc(i,s,b,null);if(m.data==="$!"){if(f=m.nextSibling&&m.nextSibling.dataset,f)var F=f.dgst;return f=F,S=Error(t(419)),f=Hd(S,f,void 0),tc(i,s,b,f)}if(F=(b&i.childLanes)!==0,zn||F){if(f=pn,f!==null){switch(b&-b){case 4:m=2;break;case 16:m=8;break;case 64:case 128:case 256:case 512:case 1024:case 2048:case 4096:case 8192:case 16384:case 32768:case 65536:case 131072:case 262144:case 524288:case 1048576:case 2097152:case 4194304:case 8388608:case 16777216:case 33554432:case 67108864:m=32;break;case 536870912:m=268435456;break;default:m=0}m=(m&(f.suspendedLanes|b))!==0?0:m,m!==0&&m!==S.retryLane&&(S.retryLane=m,or(i,m),Ri(f,i,m,-1))}return df(),f=Hd(Error(t(421))),tc(i,s,b,f)}return m.data==="$?"?(s.flags|=128,s.child=i.child,s=ey.bind(null,i),m._reactRetry=s,null):(i=S.treeContext,ti=Fr(m.nextSibling),ei=s,Gt=!0,bi=null,i!==null&&(ui[di++]=sr,ui[di++]=ar,ui[di++]=gs,sr=i.id,ar=i.overflow,gs=s),s=qd(s,f.children),s.flags|=4096,s)}function I0(i,s,o){i.lanes|=s;var f=i.alternate;f!==null&&(f.lanes|=s),Td(i.return,s,o)}function Yd(i,s,o,f,m){var S=i.memoizedState;S===null?i.memoizedState={isBackwards:s,rendering:null,renderingStartTime:0,last:f,tail:o,tailMode:m}:(S.isBackwards=s,S.rendering=null,S.renderingStartTime=0,S.last=f,S.tail=o,S.tailMode=m)}function U0(i,s,o){var f=s.pendingProps,m=f.revealOrder,S=f.tail;if(Dn(i,s,f.children,o),f=Xt.current,(f&2)!==0)f=f&1|2,s.flags|=128;else{if(i!==null&&(i.flags&128)!==0)e:for(i=s.child;i!==null;){if(i.tag===13)i.memoizedState!==null&&I0(i,o,s);else if(i.tag===19)I0(i,o,s);else if(i.child!==null){i.child.return=i,i=i.child;continue}if(i===s)break e;for(;i.sibling===null;){if(i.return===null||i.return===s)break e;i=i.return}i.sibling.return=i.return,i=i.sibling}f&=1}if(Ft(Xt,f),(s.mode&1)===0)s.memoizedState=null;else switch(m){case"forwards":for(o=s.child,m=null;o!==null;)i=o.alternate,i!==null&&ql(i)===null&&(m=o),o=o.sibling;o=m,o===null?(m=s.child,s.child=null):(m=o.sibling,o.sibling=null),Yd(s,!1,m,o,S);break;case"backwards":for(o=null,m=s.child,s.child=null;m!==null;){if(i=m.alternate,i!==null&&ql(i)===null){s.child=m;break}i=m.sibling,m.sibling=o,o=m,m=i}Yd(s,!0,o,null,S);break;case"together":Yd(s,!1,null,null,void 0);break;default:s.memoizedState=null}return s.child}function nc(i,s){(s.mode&1)===0&&i!==null&&(i.alternate=null,s.alternate=null,s.flags|=2)}function cr(i,s,o){if(i!==null&&(s.dependencies=i.dependencies),Ss|=s.lanes,(o&s.childLanes)===0)return null;if(i!==null&&s.child!==i.child)throw Error(t(153));if(s.child!==null){for(i=s.child,o=qr(i,i.pendingProps),s.child=o,o.return=s;i.sibling!==null;)i=i.sibling,o=o.sibling=qr(i,i.pendingProps),o.return=s;o.sibling=null}return s.child}function H1(i,s,o){switch(s.tag){case 3:L0(s),ha();break;case 5:Km(s);break;case 1:jn(s.type)&&Ol(s);break;case 4:Cd(s,s.stateNode.containerInfo);break;case 10:var f=s.type._context,m=s.memoizedProps.value;Ft(Gl,f._currentValue),f._currentValue=m;break;case 13:if(f=s.memoizedState,f!==null)return f.dehydrated!==null?(Ft(Xt,Xt.current&1),s.flags|=128,null):(o&s.child.childLanes)!==0?D0(i,s,o):(Ft(Xt,Xt.current&1),i=cr(i,s,o),i!==null?i.sibling:null);Ft(Xt,Xt.current&1);break;case 19:if(f=(o&s.childLanes)!==0,(i.flags&128)!==0){if(f)return U0(i,s,o);s.flags|=128}if(m=s.memoizedState,m!==null&&(m.rendering=null,m.tail=null,m.lastEffect=null),Ft(Xt,Xt.current),f)break;return null;case 22:case 23:return s.lanes=0,N0(i,s,o)}return cr(i,s,o)}var F0,Kd,O0,j0;F0=function(i,s){for(var o=s.child;o!==null;){if(o.tag===5||o.tag===6)i.appendChild(o.stateNode);else if(o.tag!==4&&o.child!==null){o.child.return=o,o=o.child;continue}if(o===s)break;for(;o.sibling===null;){if(o.return===null||o.return===s)return;o=o.return}o.sibling.return=o.return,o=o.sibling}},Kd=function(){},O0=function(i,s,o,f){var m=i.memoizedProps;if(m!==f){i=s.stateNode,xs(Vi.current);var S=null;switch(o){case"input":m=_n(i,m),f=_n(i,f),S=[];break;case"select":m=oe({},m,{value:void 0}),f=oe({},f,{value:void 0}),S=[];break;case"textarea":m=Q(i,m),f=Q(i,f),S=[];break;default:typeof m.onClick!="function"&&typeof f.onClick=="function"&&(i.onclick=Il)}lt(o,f);var b;o=null;for(ie in m)if(!f.hasOwnProperty(ie)&&m.hasOwnProperty(ie)&&m[ie]!=null)if(ie==="style"){var F=m[ie];for(b in F)F.hasOwnProperty(b)&&(o||(o={}),o[b]="")}else ie!=="dangerouslySetInnerHTML"&&ie!=="children"&&ie!=="suppressContentEditableWarning"&&ie!=="suppressHydrationWarning"&&ie!=="autoFocus"&&(a.hasOwnProperty(ie)?S||(S=[]):(S=S||[]).push(ie,null));for(ie in f){var j=f[ie];if(F=m?.[ie],f.hasOwnProperty(ie)&&j!==F&&(j!=null||F!=null))if(ie==="style")if(F){for(b in F)!F.hasOwnProperty(b)||j&&j.hasOwnProperty(b)||(o||(o={}),o[b]="");for(b in j)j.hasOwnProperty(b)&&F[b]!==j[b]&&(o||(o={}),o[b]=j[b])}else o||(S||(S=[]),S.push(ie,o)),o=j;else ie==="dangerouslySetInnerHTML"?(j=j?j.__html:void 0,F=F?F.__html:void 0,j!=null&&F!==j&&(S=S||[]).push(ie,j)):ie==="children"?typeof j!="string"&&typeof j!="number"||(S=S||[]).push(ie,""+j):ie!=="suppressContentEditableWarning"&&ie!=="suppressHydrationWarning"&&(a.hasOwnProperty(ie)?(j!=null&&ie==="onScroll"&&jt("scroll",i),S||F===j||(S=[])):(S=S||[]).push(ie,j))}o&&(S=S||[]).push("style",o);var ie=S;(s.updateQueue=ie)&&(s.flags|=4)}},j0=function(i,s,o,f){o!==f&&(s.flags|=4)};function Io(i,s){if(!Gt)switch(i.tailMode){case"hidden":s=i.tail;for(var o=null;s!==null;)s.alternate!==null&&(o=s),s=s.sibling;o===null?i.tail=null:o.sibling=null;break;case"collapsed":o=i.tail;for(var f=null;o!==null;)o.alternate!==null&&(f=o),o=o.sibling;f===null?s||i.tail===null?i.tail=null:i.tail.sibling=null:f.sibling=null}}function An(i){var s=i.alternate!==null&&i.alternate.child===i.child,o=0,f=0;if(s)for(var m=i.child;m!==null;)o|=m.lanes|m.childLanes,f|=m.subtreeFlags&14680064,f|=m.flags&14680064,m.return=i,m=m.sibling;else for(m=i.child;m!==null;)o|=m.lanes|m.childLanes,f|=m.subtreeFlags,f|=m.flags,m.return=i,m=m.sibling;return i.subtreeFlags|=f,i.childLanes=o,s}function V1(i,s,o){var f=s.pendingProps;switch(vd(s),s.tag){case 2:case 16:case 15:case 0:case 11:case 7:case 8:case 12:case 9:case 14:return An(s),null;case 1:return jn(s.type)&&Fl(),An(s),null;case 3:return f=s.stateNode,_a(),zt(On),zt(Tn),Pd(),f.pendingContext&&(f.context=f.pendingContext,f.pendingContext=null),(i===null||i.child===null)&&(Hl(s)?s.flags|=4:i===null||i.memoizedState.isDehydrated&&(s.flags&256)===0||(s.flags|=1024,bi!==null&&(lf(bi),bi=null))),Kd(i,s),An(s),null;case 5:Nd(s);var m=xs(Ro.current);if(o=s.type,i!==null&&s.stateNode!=null)O0(i,s,o,f,m),i.ref!==s.ref&&(s.flags|=512,s.flags|=2097152);else{if(!f){if(s.stateNode===null)throw Error(t(166));return An(s),null}if(i=xs(Vi.current),Hl(s)){f=s.stateNode,o=s.type;var S=s.memoizedProps;switch(f[Hi]=s,f[To]=S,i=(s.mode&1)!==0,o){case"dialog":jt("cancel",f),jt("close",f);break;case"iframe":case"object":case"embed":jt("load",f);break;case"video":case"audio":for(m=0;m<Mo.length;m++)jt(Mo[m],f);break;case"source":jt("error",f);break;case"img":case"image":case"link":jt("error",f),jt("load",f);break;case"details":jt("toggle",f);break;case"input":ht(f,S),jt("invalid",f);break;case"select":f._wrapperState={wasMultiple:!!S.multiple},jt("invalid",f);break;case"textarea":me(f,S),jt("invalid",f)}lt(o,S),m=null;for(var b in S)if(S.hasOwnProperty(b)){var F=S[b];b==="children"?typeof F=="string"?f.textContent!==F&&(S.suppressHydrationWarning!==!0&&Dl(f.textContent,F,i),m=["children",F]):typeof F=="number"&&f.textContent!==""+F&&(S.suppressHydrationWarning!==!0&&Dl(f.textContent,F,i),m=["children",""+F]):a.hasOwnProperty(b)&&F!=null&&b==="onScroll"&&jt("scroll",f)}switch(o){case"input":yt(f),kt(f,S,!0);break;case"textarea":yt(f),pe(f);break;case"select":case"option":break;default:typeof S.onClick=="function"&&(f.onclick=Il)}f=m,s.updateQueue=f,f!==null&&(s.flags|=4)}else{b=m.nodeType===9?m:m.ownerDocument,i==="http://www.w3.org/1999/xhtml"&&(i=Ze(o)),i==="http://www.w3.org/1999/xhtml"?o==="script"?(i=b.createElement("div"),i.innerHTML="<script><\/script>",i=i.removeChild(i.firstChild)):typeof f.is=="string"?i=b.createElement(o,{is:f.is}):(i=b.createElement(o),o==="select"&&(b=i,f.multiple?b.multiple=!0:f.size&&(b.size=f.size))):i=b.createElementNS(i,o),i[Hi]=s,i[To]=f,F0(i,s,!1,!1),s.stateNode=i;e:{switch(b=At(o,f),o){case"dialog":jt("cancel",i),jt("close",i),m=f;break;case"iframe":case"object":case"embed":jt("load",i),m=f;break;case"video":case"audio":for(m=0;m<Mo.length;m++)jt(Mo[m],i);m=f;break;case"source":jt("error",i),m=f;break;case"img":case"image":case"link":jt("error",i),jt("load",i),m=f;break;case"details":jt("toggle",i),m=f;break;case"input":ht(i,f),m=_n(i,f),jt("invalid",i);break;case"option":m=f;break;case"select":i._wrapperState={wasMultiple:!!f.multiple},m=oe({},f,{value:void 0}),jt("invalid",i);break;case"textarea":me(i,f),m=Q(i,f),jt("invalid",i);break;default:m=f}lt(o,m),F=m;for(S in F)if(F.hasOwnProperty(S)){var j=F[S];S==="style"?Ge(i,j):S==="dangerouslySetInnerHTML"?(j=j?j.__html:void 0,j!=null&&vt(i,j)):S==="children"?typeof j=="string"?(o!=="textarea"||j!=="")&&Ce(i,j):typeof j=="number"&&Ce(i,""+j):S!=="suppressContentEditableWarning"&&S!=="suppressHydrationWarning"&&S!=="autoFocus"&&(a.hasOwnProperty(S)?j!=null&&S==="onScroll"&&jt("scroll",i):j!=null&&A(i,S,j,b))}switch(o){case"input":yt(i),kt(i,f,!1);break;case"textarea":yt(i),pe(i);break;case"option":f.value!=null&&i.setAttribute("value",""+Ie(f.value));break;case"select":i.multiple=!!f.multiple,S=f.value,S!=null?C(i,!!f.multiple,S,!1):f.defaultValue!=null&&C(i,!!f.multiple,f.defaultValue,!0);break;default:typeof m.onClick=="function"&&(i.onclick=Il)}switch(o){case"button":case"input":case"select":case"textarea":f=!!f.autoFocus;break e;case"img":f=!0;break e;default:f=!1}}f&&(s.flags|=4)}s.ref!==null&&(s.flags|=512,s.flags|=2097152)}return An(s),null;case 6:if(i&&s.stateNode!=null)j0(i,s,i.memoizedProps,f);else{if(typeof f!="string"&&s.stateNode===null)throw Error(t(166));if(o=xs(Ro.current),xs(Vi.current),Hl(s)){if(f=s.stateNode,o=s.memoizedProps,f[Hi]=s,(S=f.nodeValue!==o)&&(i=ei,i!==null))switch(i.tag){case 3:Dl(f.nodeValue,o,(i.mode&1)!==0);break;case 5:i.memoizedProps.suppressHydrationWarning!==!0&&Dl(f.nodeValue,o,(i.mode&1)!==0)}S&&(s.flags|=4)}else f=(o.nodeType===9?o:o.ownerDocument).createTextNode(f),f[Hi]=s,s.stateNode=f}return An(s),null;case 13:if(zt(Xt),f=s.memoizedState,i===null||i.memoizedState!==null&&i.memoizedState.dehydrated!==null){if(Gt&&ti!==null&&(s.mode&1)!==0&&(s.flags&128)===0)Hm(),ha(),s.flags|=98560,S=!1;else if(S=Hl(s),f!==null&&f.dehydrated!==null){if(i===null){if(!S)throw Error(t(318));if(S=s.memoizedState,S=S!==null?S.dehydrated:null,!S)throw Error(t(317));S[Hi]=s}else ha(),(s.flags&128)===0&&(s.memoizedState=null),s.flags|=4;An(s),S=!1}else bi!==null&&(lf(bi),bi=null),S=!0;if(!S)return s.flags&65536?s:null}return(s.flags&128)!==0?(s.lanes=o,s):(f=f!==null,f!==(i!==null&&i.memoizedState!==null)&&f&&(s.child.flags|=8192,(s.mode&1)!==0&&(i===null||(Xt.current&1)!==0?an===0&&(an=3):df())),s.updateQueue!==null&&(s.flags|=4),An(s),null);case 4:return _a(),Kd(i,s),i===null&&Eo(s.stateNode.containerInfo),An(s),null;case 10:return wd(s.type._context),An(s),null;case 17:return jn(s.type)&&Fl(),An(s),null;case 19:if(zt(Xt),S=s.memoizedState,S===null)return An(s),null;if(f=(s.flags&128)!==0,b=S.rendering,b===null)if(f)Io(S,!1);else{if(an!==0||i!==null&&(i.flags&128)!==0)for(i=s.child;i!==null;){if(b=ql(i),b!==null){for(s.flags|=128,Io(S,!1),f=b.updateQueue,f!==null&&(s.updateQueue=f,s.flags|=4),s.subtreeFlags=0,f=o,o=s.child;o!==null;)S=o,i=f,S.flags&=14680066,b=S.alternate,b===null?(S.childLanes=0,S.lanes=i,S.child=null,S.subtreeFlags=0,S.memoizedProps=null,S.memoizedState=null,S.updateQueue=null,S.dependencies=null,S.stateNode=null):(S.childLanes=b.childLanes,S.lanes=b.lanes,S.child=b.child,S.subtreeFlags=0,S.deletions=null,S.memoizedProps=b.memoizedProps,S.memoizedState=b.memoizedState,S.updateQueue=b.updateQueue,S.type=b.type,i=b.dependencies,S.dependencies=i===null?null:{lanes:i.lanes,firstContext:i.firstContext}),o=o.sibling;return Ft(Xt,Xt.current&1|2),s.child}i=i.sibling}S.tail!==null&&Pe()>Sa&&(s.flags|=128,f=!0,Io(S,!1),s.lanes=4194304)}else{if(!f)if(i=ql(b),i!==null){if(s.flags|=128,f=!0,o=i.updateQueue,o!==null&&(s.updateQueue=o,s.flags|=4),Io(S,!0),S.tail===null&&S.tailMode==="hidden"&&!b.alternate&&!Gt)return An(s),null}else 2*Pe()-S.renderingStartTime>Sa&&o!==1073741824&&(s.flags|=128,f=!0,Io(S,!1),s.lanes=4194304);S.isBackwards?(b.sibling=s.child,s.child=b):(o=S.last,o!==null?o.sibling=b:s.child=b,S.last=b)}return S.tail!==null?(s=S.tail,S.rendering=s,S.tail=s.sibling,S.renderingStartTime=Pe(),s.sibling=null,o=Xt.current,Ft(Xt,f?o&1|2:o&1),s):(An(s),null);case 22:case 23:return uf(),f=s.memoizedState!==null,i!==null&&i.memoizedState!==null!==f&&(s.flags|=8192),f&&(s.mode&1)!==0?(ni&1073741824)!==0&&(An(s),s.subtreeFlags&6&&(s.flags|=8192)):An(s),null;case 24:return null;case 25:return null}throw Error(t(156,s.tag))}function G1(i,s){switch(vd(s),s.tag){case 1:return jn(s.type)&&Fl(),i=s.flags,i&65536?(s.flags=i&-65537|128,s):null;case 3:return _a(),zt(On),zt(Tn),Pd(),i=s.flags,(i&65536)!==0&&(i&128)===0?(s.flags=i&-65537|128,s):null;case 5:return Nd(s),null;case 13:if(zt(Xt),i=s.memoizedState,i!==null&&i.dehydrated!==null){if(s.alternate===null)throw Error(t(340));ha()}return i=s.flags,i&65536?(s.flags=i&-65537|128,s):null;case 19:return zt(Xt),null;case 4:return _a(),null;case 10:return wd(s.type._context),null;case 22:case 23:return uf(),null;case 24:return null;default:return null}}var ic=!1,Cn=!1,W1=typeof WeakSet=="function"?WeakSet:Set,We=null;function xa(i,s){var o=i.ref;if(o!==null)if(typeof o=="function")try{o(null)}catch(f){Yt(i,s,f)}else o.current=null}function Zd(i,s,o){try{o()}catch(f){Yt(i,s,f)}}var z0=!1;function $1(i,s){if(cd=El,i=vm(),td(i)){if("selectionStart"in i)var o={start:i.selectionStart,end:i.selectionEnd};else e:{o=(o=i.ownerDocument)&&o.defaultView||window;var f=o.getSelection&&o.getSelection();if(f&&f.rangeCount!==0){o=f.anchorNode;var m=f.anchorOffset,S=f.focusNode;f=f.focusOffset;try{o.nodeType,S.nodeType}catch{o=null;break e}var b=0,F=-1,j=-1,ie=0,ye=0,Me=i,xe=null;t:for(;;){for(var ze;Me!==o||m!==0&&Me.nodeType!==3||(F=b+m),Me!==S||f!==0&&Me.nodeType!==3||(j=b+f),Me.nodeType===3&&(b+=Me.nodeValue.length),(ze=Me.firstChild)!==null;)xe=Me,Me=ze;for(;;){if(Me===i)break t;if(xe===o&&++ie===m&&(F=b),xe===S&&++ye===f&&(j=b),(ze=Me.nextSibling)!==null)break;Me=xe,xe=Me.parentNode}Me=ze}o=F===-1||j===-1?null:{start:F,end:j}}else o=null}o=o||{start:0,end:0}}else o=null;for(ud={focusedElem:i,selectionRange:o},El=!1,We=s;We!==null;)if(s=We,i=s.child,(s.subtreeFlags&1028)!==0&&i!==null)i.return=s,We=i;else for(;We!==null;){s=We;try{var $e=s.alternate;if((s.flags&1024)!==0)switch(s.tag){case 0:case 11:case 15:break;case 1:if($e!==null){var Xe=$e.memoizedProps,Kt=$e.memoizedState,Y=s.stateNode,H=Y.getSnapshotBeforeUpdate(s.elementType===s.type?Xe:Ai(s.type,Xe),Kt);Y.__reactInternalSnapshotBeforeUpdate=H}break;case 3:var Z=s.stateNode.containerInfo;Z.nodeType===1?Z.textContent="":Z.nodeType===9&&Z.documentElement&&Z.removeChild(Z.documentElement);break;case 5:case 6:case 4:case 17:break;default:throw Error(t(163))}}catch(Ne){Yt(s,s.return,Ne)}if(i=s.sibling,i!==null){i.return=s.return,We=i;break}We=s.return}return $e=z0,z0=!1,$e}function Uo(i,s,o){var f=s.updateQueue;if(f=f!==null?f.lastEffect:null,f!==null){var m=f=f.next;do{if((m.tag&i)===i){var S=m.destroy;m.destroy=void 0,S!==void 0&&Zd(s,o,S)}m=m.next}while(m!==f)}}function rc(i,s){if(s=s.updateQueue,s=s!==null?s.lastEffect:null,s!==null){var o=s=s.next;do{if((o.tag&i)===i){var f=o.create;o.destroy=f()}o=o.next}while(o!==s)}}function Qd(i){var s=i.ref;if(s!==null){var o=i.stateNode;switch(i.tag){case 5:i=o;break;default:i=o}typeof s=="function"?s(i):s.current=i}}function B0(i){var s=i.alternate;s!==null&&(i.alternate=null,B0(s)),i.child=null,i.deletions=null,i.sibling=null,i.tag===5&&(s=i.stateNode,s!==null&&(delete s[Hi],delete s[To],delete s[pd],delete s[C1],delete s[N1])),i.stateNode=null,i.return=null,i.dependencies=null,i.memoizedProps=null,i.memoizedState=null,i.pendingProps=null,i.stateNode=null,i.updateQueue=null}function H0(i){return i.tag===5||i.tag===3||i.tag===4}function V0(i){e:for(;;){for(;i.sibling===null;){if(i.return===null||H0(i.return))return null;i=i.return}for(i.sibling.return=i.return,i=i.sibling;i.tag!==5&&i.tag!==6&&i.tag!==18;){if(i.flags&2||i.child===null||i.tag===4)continue e;i.child.return=i,i=i.child}if(!(i.flags&2))return i.stateNode}}function Jd(i,s,o){var f=i.tag;if(f===5||f===6)i=i.stateNode,s?o.nodeType===8?o.parentNode.insertBefore(i,s):o.insertBefore(i,s):(o.nodeType===8?(s=o.parentNode,s.insertBefore(i,o)):(s=o,s.appendChild(i)),o=o._reactRootContainer,o!=null||s.onclick!==null||(s.onclick=Il));else if(f!==4&&(i=i.child,i!==null))for(Jd(i,s,o),i=i.sibling;i!==null;)Jd(i,s,o),i=i.sibling}function ef(i,s,o){var f=i.tag;if(f===5||f===6)i=i.stateNode,s?o.insertBefore(i,s):o.appendChild(i);else if(f!==4&&(i=i.child,i!==null))for(ef(i,s,o),i=i.sibling;i!==null;)ef(i,s,o),i=i.sibling}var xn=null,Ci=!1;function Vr(i,s,o){for(o=o.child;o!==null;)G0(i,s,o),o=o.sibling}function G0(i,s,o){if(Vt&&typeof Vt.onCommitFiberUnmount=="function")try{Vt.onCommitFiberUnmount(It,o)}catch{}switch(o.tag){case 5:Cn||xa(o,s);case 6:var f=xn,m=Ci;xn=null,Vr(i,s,o),xn=f,Ci=m,xn!==null&&(Ci?(i=xn,o=o.stateNode,i.nodeType===8?i.parentNode.removeChild(o):i.removeChild(o)):xn.removeChild(o.stateNode));break;case 18:xn!==null&&(Ci?(i=xn,o=o.stateNode,i.nodeType===8?hd(i.parentNode,o):i.nodeType===1&&hd(i,o),po(i)):hd(xn,o.stateNode));break;case 4:f=xn,m=Ci,xn=o.stateNode.containerInfo,Ci=!0,Vr(i,s,o),xn=f,Ci=m;break;case 0:case 11:case 14:case 15:if(!Cn&&(f=o.updateQueue,f!==null&&(f=f.lastEffect,f!==null))){m=f=f.next;do{var S=m,b=S.destroy;S=S.tag,b!==void 0&&((S&2)!==0||(S&4)!==0)&&Zd(o,s,b),m=m.next}while(m!==f)}Vr(i,s,o);break;case 1:if(!Cn&&(xa(o,s),f=o.stateNode,typeof f.componentWillUnmount=="function"))try{f.props=o.memoizedProps,f.state=o.memoizedState,f.componentWillUnmount()}catch(F){Yt(o,s,F)}Vr(i,s,o);break;case 21:Vr(i,s,o);break;case 22:o.mode&1?(Cn=(f=Cn)||o.memoizedState!==null,Vr(i,s,o),Cn=f):Vr(i,s,o);break;default:Vr(i,s,o)}}function W0(i){var s=i.updateQueue;if(s!==null){i.updateQueue=null;var o=i.stateNode;o===null&&(o=i.stateNode=new W1),s.forEach(function(f){var m=ty.bind(null,i,f);o.has(f)||(o.add(f),f.then(m,m))})}}function Ni(i,s){var o=s.deletions;if(o!==null)for(var f=0;f<o.length;f++){var m=o[f];try{var S=i,b=s,F=b;e:for(;F!==null;){switch(F.tag){case 5:xn=F.stateNode,Ci=!1;break e;case 3:xn=F.stateNode.containerInfo,Ci=!0;break e;case 4:xn=F.stateNode.containerInfo,Ci=!0;break e}F=F.return}if(xn===null)throw Error(t(160));G0(S,b,m),xn=null,Ci=!1;var j=m.alternate;j!==null&&(j.return=null),m.return=null}catch(ie){Yt(m,s,ie)}}if(s.subtreeFlags&12854)for(s=s.child;s!==null;)$0(s,i),s=s.sibling}function $0(i,s){var o=i.alternate,f=i.flags;switch(i.tag){case 0:case 11:case 14:case 15:if(Ni(s,i),Wi(i),f&4){try{Uo(3,i,i.return),rc(3,i)}catch(Xe){Yt(i,i.return,Xe)}try{Uo(5,i,i.return)}catch(Xe){Yt(i,i.return,Xe)}}break;case 1:Ni(s,i),Wi(i),f&512&&o!==null&&xa(o,o.return);break;case 5:if(Ni(s,i),Wi(i),f&512&&o!==null&&xa(o,o.return),i.flags&32){var m=i.stateNode;try{Ce(m,"")}catch(Xe){Yt(i,i.return,Xe)}}if(f&4&&(m=i.stateNode,m!=null)){var S=i.memoizedProps,b=o!==null?o.memoizedProps:S,F=i.type,j=i.updateQueue;if(i.updateQueue=null,j!==null)try{F==="input"&&S.type==="radio"&&S.name!=null&&_t(m,S),At(F,b);var ie=At(F,S);for(b=0;b<j.length;b+=2){var ye=j[b],Me=j[b+1];ye==="style"?Ge(m,Me):ye==="dangerouslySetInnerHTML"?vt(m,Me):ye==="children"?Ce(m,Me):A(m,ye,Me,ie)}switch(F){case"input":tt(m,S);break;case"textarea":Se(m,S);break;case"select":var xe=m._wrapperState.wasMultiple;m._wrapperState.wasMultiple=!!S.multiple;var ze=S.value;ze!=null?C(m,!!S.multiple,ze,!1):xe!==!!S.multiple&&(S.defaultValue!=null?C(m,!!S.multiple,S.defaultValue,!0):C(m,!!S.multiple,S.multiple?[]:"",!1))}m[To]=S}catch(Xe){Yt(i,i.return,Xe)}}break;case 6:if(Ni(s,i),Wi(i),f&4){if(i.stateNode===null)throw Error(t(162));m=i.stateNode,S=i.memoizedProps;try{m.nodeValue=S}catch(Xe){Yt(i,i.return,Xe)}}break;case 3:if(Ni(s,i),Wi(i),f&4&&o!==null&&o.memoizedState.isDehydrated)try{po(s.containerInfo)}catch(Xe){Yt(i,i.return,Xe)}break;case 4:Ni(s,i),Wi(i);break;case 13:Ni(s,i),Wi(i),m=i.child,m.flags&8192&&(S=m.memoizedState!==null,m.stateNode.isHidden=S,!S||m.alternate!==null&&m.alternate.memoizedState!==null||(rf=Pe())),f&4&&W0(i);break;case 22:if(ye=o!==null&&o.memoizedState!==null,i.mode&1?(Cn=(ie=Cn)||ye,Ni(s,i),Cn=ie):Ni(s,i),Wi(i),f&8192){if(ie=i.memoizedState!==null,(i.stateNode.isHidden=ie)&&!ye&&(i.mode&1)!==0)for(We=i,ye=i.child;ye!==null;){for(Me=We=ye;We!==null;){switch(xe=We,ze=xe.child,xe.tag){case 0:case 11:case 14:case 15:Uo(4,xe,xe.return);break;case 1:xa(xe,xe.return);var $e=xe.stateNode;if(typeof $e.componentWillUnmount=="function"){f=xe,o=xe.return;try{s=f,$e.props=s.memoizedProps,$e.state=s.memoizedState,$e.componentWillUnmount()}catch(Xe){Yt(f,o,Xe)}}break;case 5:xa(xe,xe.return);break;case 22:if(xe.memoizedState!==null){Y0(Me);continue}}ze!==null?(ze.return=xe,We=ze):Y0(Me)}ye=ye.sibling}e:for(ye=null,Me=i;;){if(Me.tag===5){if(ye===null){ye=Me;try{m=Me.stateNode,ie?(S=m.style,typeof S.setProperty=="function"?S.setProperty("display","none","important"):S.display="none"):(F=Me.stateNode,j=Me.memoizedProps.style,b=j!=null&&j.hasOwnProperty("display")?j.display:null,F.style.display=rt("display",b))}catch(Xe){Yt(i,i.return,Xe)}}}else if(Me.tag===6){if(ye===null)try{Me.stateNode.nodeValue=ie?"":Me.memoizedProps}catch(Xe){Yt(i,i.return,Xe)}}else if((Me.tag!==22&&Me.tag!==23||Me.memoizedState===null||Me===i)&&Me.child!==null){Me.child.return=Me,Me=Me.child;continue}if(Me===i)break e;for(;Me.sibling===null;){if(Me.return===null||Me.return===i)break e;ye===Me&&(ye=null),Me=Me.return}ye===Me&&(ye=null),Me.sibling.return=Me.return,Me=Me.sibling}}break;case 19:Ni(s,i),Wi(i),f&4&&W0(i);break;case 21:break;default:Ni(s,i),Wi(i)}}function Wi(i){var s=i.flags;if(s&2){try{e:{for(var o=i.return;o!==null;){if(H0(o)){var f=o;break e}o=o.return}throw Error(t(160))}switch(f.tag){case 5:var m=f.stateNode;f.flags&32&&(Ce(m,""),f.flags&=-33);var S=V0(i);ef(i,S,m);break;case 3:case 4:var b=f.stateNode.containerInfo,F=V0(i);Jd(i,F,b);break;default:throw Error(t(161))}}catch(j){Yt(i,i.return,j)}i.flags&=-3}s&4096&&(i.flags&=-4097)}function X1(i,s,o){We=i,X0(i)}function X0(i,s,o){for(var f=(i.mode&1)!==0;We!==null;){var m=We,S=m.child;if(m.tag===22&&f){var b=m.memoizedState!==null||ic;if(!b){var F=m.alternate,j=F!==null&&F.memoizedState!==null||Cn;F=ic;var ie=Cn;if(ic=b,(Cn=j)&&!ie)for(We=m;We!==null;)b=We,j=b.child,b.tag===22&&b.memoizedState!==null?K0(m):j!==null?(j.return=b,We=j):K0(m);for(;S!==null;)We=S,X0(S),S=S.sibling;We=m,ic=F,Cn=ie}q0(i)}else(m.subtreeFlags&8772)!==0&&S!==null?(S.return=m,We=S):q0(i)}}function q0(i){for(;We!==null;){var s=We;if((s.flags&8772)!==0){var o=s.alternate;try{if((s.flags&8772)!==0)switch(s.tag){case 0:case 11:case 15:Cn||rc(5,s);break;case 1:var f=s.stateNode;if(s.flags&4&&!Cn)if(o===null)f.componentDidMount();else{var m=s.elementType===s.type?o.memoizedProps:Ai(s.type,o.memoizedProps);f.componentDidUpdate(m,o.memoizedState,f.__reactInternalSnapshotBeforeUpdate)}var S=s.updateQueue;S!==null&&Ym(s,S,f);break;case 3:var b=s.updateQueue;if(b!==null){if(o=null,s.child!==null)switch(s.child.tag){case 5:o=s.child.stateNode;break;case 1:o=s.child.stateNode}Ym(s,b,o)}break;case 5:var F=s.stateNode;if(o===null&&s.flags&4){o=F;var j=s.memoizedProps;switch(s.type){case"button":case"input":case"select":case"textarea":j.autoFocus&&o.focus();break;case"img":j.src&&(o.src=j.src)}}break;case 6:break;case 4:break;case 12:break;case 13:if(s.memoizedState===null){var ie=s.alternate;if(ie!==null){var ye=ie.memoizedState;if(ye!==null){var Me=ye.dehydrated;Me!==null&&po(Me)}}}break;case 19:case 17:case 21:case 22:case 23:case 25:break;default:throw Error(t(163))}Cn||s.flags&512&&Qd(s)}catch(xe){Yt(s,s.return,xe)}}if(s===i){We=null;break}if(o=s.sibling,o!==null){o.return=s.return,We=o;break}We=s.return}}function Y0(i){for(;We!==null;){var s=We;if(s===i){We=null;break}var o=s.sibling;if(o!==null){o.return=s.return,We=o;break}We=s.return}}function K0(i){for(;We!==null;){var s=We;try{switch(s.tag){case 0:case 11:case 15:var o=s.return;try{rc(4,s)}catch(j){Yt(s,o,j)}break;case 1:var f=s.stateNode;if(typeof f.componentDidMount=="function"){var m=s.return;try{f.componentDidMount()}catch(j){Yt(s,m,j)}}var S=s.return;try{Qd(s)}catch(j){Yt(s,S,j)}break;case 5:var b=s.return;try{Qd(s)}catch(j){Yt(s,b,j)}}}catch(j){Yt(s,s.return,j)}if(s===i){We=null;break}var F=s.sibling;if(F!==null){F.return=s.return,We=F;break}We=s.return}}var q1=Math.ceil,sc=R.ReactCurrentDispatcher,tf=R.ReactCurrentOwner,pi=R.ReactCurrentBatchConfig,St=0,pn=null,Jt=null,yn=0,ni=0,ya=Or(0),an=0,Fo=null,Ss=0,ac=0,nf=0,Oo=null,Bn=null,rf=0,Sa=1/0,ur=null,oc=!1,sf=null,Gr=null,lc=!1,Wr=null,cc=0,jo=0,af=null,uc=-1,dc=0;function In(){return(St&6)!==0?Pe():uc!==-1?uc:uc=Pe()}function $r(i){return(i.mode&1)===0?1:(St&2)!==0&&yn!==0?yn&-yn:P1.transition!==null?(dc===0&&(dc=ea()),dc):(i=Lt,i!==0||(i=window.event,i=i===void 0?16:Qp(i.type)),i)}function Ri(i,s,o,f){if(50<jo)throw jo=0,af=null,Error(t(185));Rr(i,o,f),((St&2)===0||i!==pn)&&(i===pn&&((St&2)===0&&(ac|=o),an===4&&Xr(i,yn)),Hn(i,f),o===1&&St===0&&(s.mode&1)===0&&(Sa=Pe()+500,jl&&zr()))}function Hn(i,s){var o=i.callbackNode;oo(i,s);var f=Ut(i,i===pn?yn:0);if(f===0)o!==null&&X(o),i.callbackNode=null,i.callbackPriority=0;else if(s=f&-f,i.callbackPriority!==s){if(o!=null&&X(o),s===1)i.tag===0?R1(Q0.bind(null,i)):Fm(Q0.bind(null,i)),b1(function(){(St&6)===0&&zr()}),o=null;else{switch(Gp(f)){case 1:o=et;break;case 4:o=nt;break;case 16:o=Ye;break;case 536870912:o=Dt;break;default:o=Ye}o=ag(o,Z0.bind(null,i))}i.callbackPriority=s,i.callbackNode=o}}function Z0(i,s){if(uc=-1,dc=0,(St&6)!==0)throw Error(t(327));var o=i.callbackNode;if(Ma()&&i.callbackNode!==o)return null;var f=Ut(i,i===pn?yn:0);if(f===0)return null;if((f&30)!==0||(f&i.expiredLanes)!==0||s)s=fc(i,f);else{s=f;var m=St;St|=2;var S=eg();(pn!==i||yn!==s)&&(ur=null,Sa=Pe()+500,Es(i,s));do try{Z1();break}catch(F){J0(i,F)}while(!0);Ed(),sc.current=S,St=m,Jt!==null?s=0:(pn=null,yn=0,s=an)}if(s!==0){if(s===2&&(m=wn(i),m!==0&&(f=m,s=of(i,m))),s===1)throw o=Fo,Es(i,0),Xr(i,f),Hn(i,Pe()),o;if(s===6)Xr(i,f);else{if(m=i.current.alternate,(f&30)===0&&!Y1(m)&&(s=fc(i,f),s===2&&(S=wn(i),S!==0&&(f=S,s=of(i,S))),s===1))throw o=Fo,Es(i,0),Xr(i,f),Hn(i,Pe()),o;switch(i.finishedWork=m,i.finishedLanes=f,s){case 0:case 1:throw Error(t(345));case 2:ws(i,Bn,ur);break;case 3:if(Xr(i,f),(f&130023424)===f&&(s=rf+500-Pe(),10<s)){if(Ut(i,0)!==0)break;if(m=i.suspendedLanes,(m&f)!==f){In(),i.pingedLanes|=i.suspendedLanes&m;break}i.timeoutHandle=fd(ws.bind(null,i,Bn,ur),s);break}ws(i,Bn,ur);break;case 4:if(Xr(i,f),(f&4194240)===f)break;for(s=i.eventTimes,m=-1;0<f;){var b=31-Ve(f);S=1<<b,b=s[b],b>m&&(m=b),f&=~S}if(f=m,f=Pe()-f,f=(120>f?120:480>f?480:1080>f?1080:1920>f?1920:3e3>f?3e3:4320>f?4320:1960*q1(f/1960))-f,10<f){i.timeoutHandle=fd(ws.bind(null,i,Bn,ur),f);break}ws(i,Bn,ur);break;case 5:ws(i,Bn,ur);break;default:throw Error(t(329))}}}return Hn(i,Pe()),i.callbackNode===o?Z0.bind(null,i):null}function of(i,s){var o=Oo;return i.current.memoizedState.isDehydrated&&(Es(i,s).flags|=256),i=fc(i,s),i!==2&&(s=Bn,Bn=o,s!==null&&lf(s)),i}function lf(i){Bn===null?Bn=i:Bn.push.apply(Bn,i)}function Y1(i){for(var s=i;;){if(s.flags&16384){var o=s.updateQueue;if(o!==null&&(o=o.stores,o!==null))for(var f=0;f<o.length;f++){var m=o[f],S=m.getSnapshot;m=m.value;try{if(!Ti(S(),m))return!1}catch{return!1}}}if(o=s.child,s.subtreeFlags&16384&&o!==null)o.return=s,s=o;else{if(s===i)break;for(;s.sibling===null;){if(s.return===null||s.return===i)return!0;s=s.return}s.sibling.return=s.return,s=s.sibling}}return!0}function Xr(i,s){for(s&=~nf,s&=~ac,i.suspendedLanes|=s,i.pingedLanes&=~s,i=i.expirationTimes;0<s;){var o=31-Ve(s),f=1<<o;i[o]=-1,s&=~f}}function Q0(i){if((St&6)!==0)throw Error(t(327));Ma();var s=Ut(i,0);if((s&1)===0)return Hn(i,Pe()),null;var o=fc(i,s);if(i.tag!==0&&o===2){var f=wn(i);f!==0&&(s=f,o=of(i,f))}if(o===1)throw o=Fo,Es(i,0),Xr(i,s),Hn(i,Pe()),o;if(o===6)throw Error(t(345));return i.finishedWork=i.current.alternate,i.finishedLanes=s,ws(i,Bn,ur),Hn(i,Pe()),null}function cf(i,s){var o=St;St|=1;try{return i(s)}finally{St=o,St===0&&(Sa=Pe()+500,jl&&zr())}}function Ms(i){Wr!==null&&Wr.tag===0&&(St&6)===0&&Ma();var s=St;St|=1;var o=pi.transition,f=Lt;try{if(pi.transition=null,Lt=1,i)return i()}finally{Lt=f,pi.transition=o,St=s,(St&6)===0&&zr()}}function uf(){ni=ya.current,zt(ya)}function Es(i,s){i.finishedWork=null,i.finishedLanes=0;var o=i.timeoutHandle;if(o!==-1&&(i.timeoutHandle=-1,T1(o)),Jt!==null)for(o=Jt.return;o!==null;){var f=o;switch(vd(f),f.tag){case 1:f=f.type.childContextTypes,f!=null&&Fl();break;case 3:_a(),zt(On),zt(Tn),Pd();break;case 5:Nd(f);break;case 4:_a();break;case 13:zt(Xt);break;case 19:zt(Xt);break;case 10:wd(f.type._context);break;case 22:case 23:uf()}o=o.return}if(pn=i,Jt=i=qr(i.current,null),yn=ni=s,an=0,Fo=null,nf=ac=Ss=0,Bn=Oo=null,vs!==null){for(s=0;s<vs.length;s++)if(o=vs[s],f=o.interleaved,f!==null){o.interleaved=null;var m=f.next,S=o.pending;if(S!==null){var b=S.next;S.next=m,f.next=b}o.pending=f}vs=null}return i}function J0(i,s){do{var o=Jt;try{if(Ed(),Yl.current=Jl,Kl){for(var f=qt.memoizedState;f!==null;){var m=f.queue;m!==null&&(m.pending=null),f=f.next}Kl=!1}if(ys=0,hn=sn=qt=null,Po=!1,Lo=0,tf.current=null,o===null||o.return===null){an=1,Fo=s,Jt=null;break}e:{var S=i,b=o.return,F=o,j=s;if(s=yn,F.flags|=32768,j!==null&&typeof j=="object"&&typeof j.then=="function"){var ie=j,ye=F,Me=ye.tag;if((ye.mode&1)===0&&(Me===0||Me===11||Me===15)){var xe=ye.alternate;xe?(ye.updateQueue=xe.updateQueue,ye.memoizedState=xe.memoizedState,ye.lanes=xe.lanes):(ye.updateQueue=null,ye.memoizedState=null)}var ze=w0(b);if(ze!==null){ze.flags&=-257,T0(ze,b,F,S,s),ze.mode&1&&E0(S,ie,s),s=ze,j=ie;var $e=s.updateQueue;if($e===null){var Xe=new Set;Xe.add(j),s.updateQueue=Xe}else $e.add(j);break e}else{if((s&1)===0){E0(S,ie,s),df();break e}j=Error(t(426))}}else if(Gt&&F.mode&1){var Kt=w0(b);if(Kt!==null){(Kt.flags&65536)===0&&(Kt.flags|=256),T0(Kt,b,F,S,s),Sd(va(j,F));break e}}S=j=va(j,F),an!==4&&(an=2),Oo===null?Oo=[S]:Oo.push(S),S=b;do{switch(S.tag){case 3:S.flags|=65536,s&=-s,S.lanes|=s;var Y=S0(S,j,s);qm(S,Y);break e;case 1:F=j;var H=S.type,Z=S.stateNode;if((S.flags&128)===0&&(typeof H.getDerivedStateFromError=="function"||Z!==null&&typeof Z.componentDidCatch=="function"&&(Gr===null||!Gr.has(Z)))){S.flags|=65536,s&=-s,S.lanes|=s;var Ne=M0(S,F,s);qm(S,Ne);break e}}S=S.return}while(S!==null)}ng(o)}catch(Ke){s=Ke,Jt===o&&o!==null&&(Jt=o=o.return);continue}break}while(!0)}function eg(){var i=sc.current;return sc.current=Jl,i===null?Jl:i}function df(){(an===0||an===3||an===2)&&(an=4),pn===null||(Ss&268435455)===0&&(ac&268435455)===0||Xr(pn,yn)}function fc(i,s){var o=St;St|=2;var f=eg();(pn!==i||yn!==s)&&(ur=null,Es(i,s));do try{K1();break}catch(m){J0(i,m)}while(!0);if(Ed(),St=o,sc.current=f,Jt!==null)throw Error(t(261));return pn=null,yn=0,an}function K1(){for(;Jt!==null;)tg(Jt)}function Z1(){for(;Jt!==null&&!Re();)tg(Jt)}function tg(i){var s=sg(i.alternate,i,ni);i.memoizedProps=i.pendingProps,s===null?ng(i):Jt=s,tf.current=null}function ng(i){var s=i;do{var o=s.alternate;if(i=s.return,(s.flags&32768)===0){if(o=V1(o,s,ni),o!==null){Jt=o;return}}else{if(o=G1(o,s),o!==null){o.flags&=32767,Jt=o;return}if(i!==null)i.flags|=32768,i.subtreeFlags=0,i.deletions=null;else{an=6,Jt=null;return}}if(s=s.sibling,s!==null){Jt=s;return}Jt=s=i}while(s!==null);an===0&&(an=5)}function ws(i,s,o){var f=Lt,m=pi.transition;try{pi.transition=null,Lt=1,Q1(i,s,o,f)}finally{pi.transition=m,Lt=f}return null}function Q1(i,s,o,f){do Ma();while(Wr!==null);if((St&6)!==0)throw Error(t(327));o=i.finishedWork;var m=i.finishedLanes;if(o===null)return null;if(i.finishedWork=null,i.finishedLanes=0,o===i.current)throw Error(t(177));i.callbackNode=null,i.callbackPriority=0;var S=o.lanes|o.childLanes;if(Lx(i,S),i===pn&&(Jt=pn=null,yn=0),(o.subtreeFlags&2064)===0&&(o.flags&2064)===0||lc||(lc=!0,ag(Ye,function(){return Ma(),null})),S=(o.flags&15990)!==0,(o.subtreeFlags&15990)!==0||S){S=pi.transition,pi.transition=null;var b=Lt;Lt=1;var F=St;St|=4,tf.current=null,$1(i,o),$0(o,i),v1(ud),El=!!cd,ud=cd=null,i.current=o,X1(o),Oe(),St=F,Lt=b,pi.transition=S}else i.current=o;if(lc&&(lc=!1,Wr=i,cc=m),S=i.pendingLanes,S===0&&(Gr=null),Mt(o.stateNode),Hn(i,Pe()),s!==null)for(f=i.onRecoverableError,o=0;o<s.length;o++)m=s[o],f(m.value,{componentStack:m.stack,digest:m.digest});if(oc)throw oc=!1,i=sf,sf=null,i;return(cc&1)!==0&&i.tag!==0&&Ma(),S=i.pendingLanes,(S&1)!==0?i===af?jo++:(jo=0,af=i):jo=0,zr(),null}function Ma(){if(Wr!==null){var i=Gp(cc),s=pi.transition,o=Lt;try{if(pi.transition=null,Lt=16>i?16:i,Wr===null)var f=!1;else{if(i=Wr,Wr=null,cc=0,(St&6)!==0)throw Error(t(331));var m=St;for(St|=4,We=i.current;We!==null;){var S=We,b=S.child;if((We.flags&16)!==0){var F=S.deletions;if(F!==null){for(var j=0;j<F.length;j++){var ie=F[j];for(We=ie;We!==null;){var ye=We;switch(ye.tag){case 0:case 11:case 15:Uo(8,ye,S)}var Me=ye.child;if(Me!==null)Me.return=ye,We=Me;else for(;We!==null;){ye=We;var xe=ye.sibling,ze=ye.return;if(B0(ye),ye===ie){We=null;break}if(xe!==null){xe.return=ze,We=xe;break}We=ze}}}var $e=S.alternate;if($e!==null){var Xe=$e.child;if(Xe!==null){$e.child=null;do{var Kt=Xe.sibling;Xe.sibling=null,Xe=Kt}while(Xe!==null)}}We=S}}if((S.subtreeFlags&2064)!==0&&b!==null)b.return=S,We=b;else e:for(;We!==null;){if(S=We,(S.flags&2048)!==0)switch(S.tag){case 0:case 11:case 15:Uo(9,S,S.return)}var Y=S.sibling;if(Y!==null){Y.return=S.return,We=Y;break e}We=S.return}}var H=i.current;for(We=H;We!==null;){b=We;var Z=b.child;if((b.subtreeFlags&2064)!==0&&Z!==null)Z.return=b,We=Z;else e:for(b=H;We!==null;){if(F=We,(F.flags&2048)!==0)try{switch(F.tag){case 0:case 11:case 15:rc(9,F)}}catch(Ke){Yt(F,F.return,Ke)}if(F===b){We=null;break e}var Ne=F.sibling;if(Ne!==null){Ne.return=F.return,We=Ne;break e}We=F.return}}if(St=m,zr(),Vt&&typeof Vt.onPostCommitFiberRoot=="function")try{Vt.onPostCommitFiberRoot(It,i)}catch{}f=!0}return f}finally{Lt=o,pi.transition=s}}return!1}function ig(i,s,o){s=va(o,s),s=S0(i,s,1),i=Hr(i,s,1),s=In(),i!==null&&(Rr(i,1,s),Hn(i,s))}function Yt(i,s,o){if(i.tag===3)ig(i,i,o);else for(;s!==null;){if(s.tag===3){ig(s,i,o);break}else if(s.tag===1){var f=s.stateNode;if(typeof s.type.getDerivedStateFromError=="function"||typeof f.componentDidCatch=="function"&&(Gr===null||!Gr.has(f))){i=va(o,i),i=M0(s,i,1),s=Hr(s,i,1),i=In(),s!==null&&(Rr(s,1,i),Hn(s,i));break}}s=s.return}}function J1(i,s,o){var f=i.pingCache;f!==null&&f.delete(s),s=In(),i.pingedLanes|=i.suspendedLanes&o,pn===i&&(yn&o)===o&&(an===4||an===3&&(yn&130023424)===yn&&500>Pe()-rf?Es(i,0):nf|=o),Hn(i,s)}function rg(i,s){s===0&&((i.mode&1)===0?s=1:(s=fn,fn<<=1,(fn&130023424)===0&&(fn=4194304)));var o=In();i=or(i,s),i!==null&&(Rr(i,s,o),Hn(i,o))}function ey(i){var s=i.memoizedState,o=0;s!==null&&(o=s.retryLane),rg(i,o)}function ty(i,s){var o=0;switch(i.tag){case 13:var f=i.stateNode,m=i.memoizedState;m!==null&&(o=m.retryLane);break;case 19:f=i.stateNode;break;default:throw Error(t(314))}f!==null&&f.delete(s),rg(i,o)}var sg;sg=function(i,s,o){if(i!==null)if(i.memoizedProps!==s.pendingProps||On.current)zn=!0;else{if((i.lanes&o)===0&&(s.flags&128)===0)return zn=!1,H1(i,s,o);zn=(i.flags&131072)!==0}else zn=!1,Gt&&(s.flags&1048576)!==0&&Om(s,Bl,s.index);switch(s.lanes=0,s.tag){case 2:var f=s.type;nc(i,s),i=s.pendingProps;var m=ua(s,Tn.current);ga(s,o),m=Dd(null,s,f,i,m,o);var S=Id();return s.flags|=1,typeof m=="object"&&m!==null&&typeof m.render=="function"&&m.$$typeof===void 0?(s.tag=1,s.memoizedState=null,s.updateQueue=null,jn(f)?(S=!0,Ol(s)):S=!1,s.memoizedState=m.state!==null&&m.state!==void 0?m.state:null,Ad(s),m.updater=ec,s.stateNode=m,m._reactInternals=s,Bd(s,f,i,o),s=Wd(null,s,f,!0,S,o)):(s.tag=0,Gt&&S&&_d(s),Dn(null,s,m,o),s=s.child),s;case 16:f=s.elementType;e:{switch(nc(i,s),i=s.pendingProps,m=f._init,f=m(f._payload),s.type=f,m=s.tag=iy(f),i=Ai(f,i),m){case 0:s=Gd(null,s,f,i,o);break e;case 1:s=P0(null,s,f,i,o);break e;case 11:s=b0(null,s,f,i,o);break e;case 14:s=A0(null,s,f,Ai(f.type,i),o);break e}throw Error(t(306,f,""))}return s;case 0:return f=s.type,m=s.pendingProps,m=s.elementType===f?m:Ai(f,m),Gd(i,s,f,m,o);case 1:return f=s.type,m=s.pendingProps,m=s.elementType===f?m:Ai(f,m),P0(i,s,f,m,o);case 3:e:{if(L0(s),i===null)throw Error(t(387));f=s.pendingProps,S=s.memoizedState,m=S.element,Xm(i,s),Xl(s,f,null,o);var b=s.memoizedState;if(f=b.element,S.isDehydrated)if(S={element:f,isDehydrated:!1,cache:b.cache,pendingSuspenseBoundaries:b.pendingSuspenseBoundaries,transitions:b.transitions},s.updateQueue.baseState=S,s.memoizedState=S,s.flags&256){m=va(Error(t(423)),s),s=k0(i,s,f,o,m);break e}else if(f!==m){m=va(Error(t(424)),s),s=k0(i,s,f,o,m);break e}else for(ti=Fr(s.stateNode.containerInfo.firstChild),ei=s,Gt=!0,bi=null,o=Wm(s,null,f,o),s.child=o;o;)o.flags=o.flags&-3|4096,o=o.sibling;else{if(ha(),f===m){s=cr(i,s,o);break e}Dn(i,s,f,o)}s=s.child}return s;case 5:return Km(s),i===null&&yd(s),f=s.type,m=s.pendingProps,S=i!==null?i.memoizedProps:null,b=m.children,dd(f,m)?b=null:S!==null&&dd(f,S)&&(s.flags|=32),R0(i,s),Dn(i,s,b,o),s.child;case 6:return i===null&&yd(s),null;case 13:return D0(i,s,o);case 4:return Cd(s,s.stateNode.containerInfo),f=s.pendingProps,i===null?s.child=pa(s,null,f,o):Dn(i,s,f,o),s.child;case 11:return f=s.type,m=s.pendingProps,m=s.elementType===f?m:Ai(f,m),b0(i,s,f,m,o);case 7:return Dn(i,s,s.pendingProps,o),s.child;case 8:return Dn(i,s,s.pendingProps.children,o),s.child;case 12:return Dn(i,s,s.pendingProps.children,o),s.child;case 10:e:{if(f=s.type._context,m=s.pendingProps,S=s.memoizedProps,b=m.value,Ft(Gl,f._currentValue),f._currentValue=b,S!==null)if(Ti(S.value,b)){if(S.children===m.children&&!On.current){s=cr(i,s,o);break e}}else for(S=s.child,S!==null&&(S.return=s);S!==null;){var F=S.dependencies;if(F!==null){b=S.child;for(var j=F.firstContext;j!==null;){if(j.context===f){if(S.tag===1){j=lr(-1,o&-o),j.tag=2;var ie=S.updateQueue;if(ie!==null){ie=ie.shared;var ye=ie.pending;ye===null?j.next=j:(j.next=ye.next,ye.next=j),ie.pending=j}}S.lanes|=o,j=S.alternate,j!==null&&(j.lanes|=o),Td(S.return,o,s),F.lanes|=o;break}j=j.next}}else if(S.tag===10)b=S.type===s.type?null:S.child;else if(S.tag===18){if(b=S.return,b===null)throw Error(t(341));b.lanes|=o,F=b.alternate,F!==null&&(F.lanes|=o),Td(b,o,s),b=S.sibling}else b=S.child;if(b!==null)b.return=S;else for(b=S;b!==null;){if(b===s){b=null;break}if(S=b.sibling,S!==null){S.return=b.return,b=S;break}b=b.return}S=b}Dn(i,s,m.children,o),s=s.child}return s;case 9:return m=s.type,f=s.pendingProps.children,ga(s,o),m=fi(m),f=f(m),s.flags|=1,Dn(i,s,f,o),s.child;case 14:return f=s.type,m=Ai(f,s.pendingProps),m=Ai(f.type,m),A0(i,s,f,m,o);case 15:return C0(i,s,s.type,s.pendingProps,o);case 17:return f=s.type,m=s.pendingProps,m=s.elementType===f?m:Ai(f,m),nc(i,s),s.tag=1,jn(f)?(i=!0,Ol(s)):i=!1,ga(s,o),x0(s,f,m),Bd(s,f,m,o),Wd(null,s,f,!0,i,o);case 19:return U0(i,s,o);case 22:return N0(i,s,o)}throw Error(t(156,s.tag))};function ag(i,s){return ne(i,s)}function ny(i,s,o,f){this.tag=i,this.key=o,this.sibling=this.child=this.return=this.stateNode=this.type=this.elementType=null,this.index=0,this.ref=null,this.pendingProps=s,this.dependencies=this.memoizedState=this.updateQueue=this.memoizedProps=null,this.mode=f,this.subtreeFlags=this.flags=0,this.deletions=null,this.childLanes=this.lanes=0,this.alternate=null}function mi(i,s,o,f){return new ny(i,s,o,f)}function ff(i){return i=i.prototype,!(!i||!i.isReactComponent)}function iy(i){if(typeof i=="function")return ff(i)?1:0;if(i!=null){if(i=i.$$typeof,i===se)return 11;if(i===ve)return 14}return 2}function qr(i,s){var o=i.alternate;return o===null?(o=mi(i.tag,s,i.key,i.mode),o.elementType=i.elementType,o.type=i.type,o.stateNode=i.stateNode,o.alternate=i,i.alternate=o):(o.pendingProps=s,o.type=i.type,o.flags=0,o.subtreeFlags=0,o.deletions=null),o.flags=i.flags&14680064,o.childLanes=i.childLanes,o.lanes=i.lanes,o.child=i.child,o.memoizedProps=i.memoizedProps,o.memoizedState=i.memoizedState,o.updateQueue=i.updateQueue,s=i.dependencies,o.dependencies=s===null?null:{lanes:s.lanes,firstContext:s.firstContext},o.sibling=i.sibling,o.index=i.index,o.ref=i.ref,o}function hc(i,s,o,f,m,S){var b=2;if(f=i,typeof i=="function")ff(i)&&(b=1);else if(typeof i=="string")b=5;else e:switch(i){case U:return Ts(o.children,m,S,s);case $:b=8,m|=8;break;case te:return i=mi(12,o,s,m|2),i.elementType=te,i.lanes=S,i;case J:return i=mi(13,o,s,m),i.elementType=J,i.lanes=S,i;case ae:return i=mi(19,o,s,m),i.elementType=ae,i.lanes=S,i;case de:return pc(o,m,S,s);default:if(typeof i=="object"&&i!==null)switch(i.$$typeof){case T:b=10;break e;case P:b=9;break e;case se:b=11;break e;case ve:b=14;break e;case V:b=16,f=null;break e}throw Error(t(130,i==null?i:typeof i,""))}return s=mi(b,o,s,m),s.elementType=i,s.type=f,s.lanes=S,s}function Ts(i,s,o,f){return i=mi(7,i,f,s),i.lanes=o,i}function pc(i,s,o,f){return i=mi(22,i,f,s),i.elementType=de,i.lanes=o,i.stateNode={isHidden:!1},i}function hf(i,s,o){return i=mi(6,i,null,s),i.lanes=o,i}function pf(i,s,o){return s=mi(4,i.children!==null?i.children:[],i.key,s),s.lanes=o,s.stateNode={containerInfo:i.containerInfo,pendingChildren:null,implementation:i.implementation},s}function ry(i,s,o,f,m){this.tag=s,this.containerInfo=i,this.finishedWork=this.pingCache=this.current=this.pendingChildren=null,this.timeoutHandle=-1,this.callbackNode=this.pendingContext=this.context=null,this.callbackPriority=0,this.eventTimes=lo(0),this.expirationTimes=lo(-1),this.entangledLanes=this.finishedLanes=this.mutableReadLanes=this.expiredLanes=this.pingedLanes=this.suspendedLanes=this.pendingLanes=0,this.entanglements=lo(0),this.identifierPrefix=f,this.onRecoverableError=m,this.mutableSourceEagerHydrationData=null}function mf(i,s,o,f,m,S,b,F,j){return i=new ry(i,s,o,F,j),s===1?(s=1,S===!0&&(s|=8)):s=0,S=mi(3,null,null,s),i.current=S,S.stateNode=i,S.memoizedState={element:f,isDehydrated:o,cache:null,transitions:null,pendingSuspenseBoundaries:null},Ad(S),i}function sy(i,s,o){var f=3<arguments.length&&arguments[3]!==void 0?arguments[3]:null;return{$$typeof:D,key:f==null?null:""+f,children:i,containerInfo:s,implementation:o}}function og(i){if(!i)return jr;i=i._reactInternals;e:{if(tr(i)!==i||i.tag!==1)throw Error(t(170));var s=i;do{switch(s.tag){case 3:s=s.stateNode.context;break e;case 1:if(jn(s.type)){s=s.stateNode.__reactInternalMemoizedMergedChildContext;break e}}s=s.return}while(s!==null);throw Error(t(171))}if(i.tag===1){var o=i.type;if(jn(o))return Im(i,o,s)}return s}function lg(i,s,o,f,m,S,b,F,j){return i=mf(o,f,!0,i,m,S,b,F,j),i.context=og(null),o=i.current,f=In(),m=$r(o),S=lr(f,m),S.callback=s??null,Hr(o,S,m),i.current.lanes=m,Rr(i,m,f),Hn(i,f),i}function mc(i,s,o,f){var m=s.current,S=In(),b=$r(m);return o=og(o),s.context===null?s.context=o:s.pendingContext=o,s=lr(S,b),s.payload={element:i},f=f===void 0?null:f,f!==null&&(s.callback=f),i=Hr(m,s,b),i!==null&&(Ri(i,m,b,S),$l(i,m,b)),b}function gc(i){if(i=i.current,!i.child)return null;switch(i.child.tag){case 5:return i.child.stateNode;default:return i.child.stateNode}}function cg(i,s){if(i=i.memoizedState,i!==null&&i.dehydrated!==null){var o=i.retryLane;i.retryLane=o!==0&&o<s?o:s}}function gf(i,s){cg(i,s),(i=i.alternate)&&cg(i,s)}function ay(){return null}var ug=typeof reportError=="function"?reportError:function(i){console.error(i)};function _f(i){this._internalRoot=i}_c.prototype.render=_f.prototype.render=function(i){var s=this._internalRoot;if(s===null)throw Error(t(409));mc(i,s,null,null)},_c.prototype.unmount=_f.prototype.unmount=function(){var i=this._internalRoot;if(i!==null){this._internalRoot=null;var s=i.containerInfo;Ms(function(){mc(null,i,null,null)}),s[ir]=null}};function _c(i){this._internalRoot=i}_c.prototype.unstable_scheduleHydration=function(i){if(i){var s=Xp();i={blockedOn:null,target:i,priority:s};for(var o=0;o<Dr.length&&s!==0&&s<Dr[o].priority;o++);Dr.splice(o,0,i),o===0&&Kp(i)}};function vf(i){return!(!i||i.nodeType!==1&&i.nodeType!==9&&i.nodeType!==11)}function vc(i){return!(!i||i.nodeType!==1&&i.nodeType!==9&&i.nodeType!==11&&(i.nodeType!==8||i.nodeValue!==" react-mount-point-unstable "))}function dg(){}function oy(i,s,o,f,m){if(m){if(typeof f=="function"){var S=f;f=function(){var ie=gc(b);S.call(ie)}}var b=lg(s,f,i,0,null,!1,!1,"",dg);return i._reactRootContainer=b,i[ir]=b.current,Eo(i.nodeType===8?i.parentNode:i),Ms(),b}for(;m=i.lastChild;)i.removeChild(m);if(typeof f=="function"){var F=f;f=function(){var ie=gc(j);F.call(ie)}}var j=mf(i,0,!1,null,null,!1,!1,"",dg);return i._reactRootContainer=j,i[ir]=j.current,Eo(i.nodeType===8?i.parentNode:i),Ms(function(){mc(s,j,o,f)}),j}function xc(i,s,o,f,m){var S=o._reactRootContainer;if(S){var b=S;if(typeof m=="function"){var F=m;m=function(){var j=gc(b);F.call(j)}}mc(s,b,i,m)}else b=oy(o,s,i,m,f);return gc(b)}Wp=function(i){switch(i.tag){case 3:var s=i.stateNode;if(s.current.memoizedState.isDehydrated){var o=nr(s.pendingLanes);o!==0&&(Bu(s,o|1),Hn(s,Pe()),(St&6)===0&&(Sa=Pe()+500,zr()))}break;case 13:Ms(function(){var f=or(i,1);if(f!==null){var m=In();Ri(f,i,1,m)}}),gf(i,1)}},Hu=function(i){if(i.tag===13){var s=or(i,134217728);if(s!==null){var o=In();Ri(s,i,134217728,o)}gf(i,134217728)}},$p=function(i){if(i.tag===13){var s=$r(i),o=or(i,s);if(o!==null){var f=In();Ri(o,i,s,f)}gf(i,s)}},Xp=function(){return Lt},qp=function(i,s){var o=Lt;try{return Lt=i,s()}finally{Lt=o}},ce=function(i,s,o){switch(s){case"input":if(tt(i,o),s=o.name,o.type==="radio"&&s!=null){for(o=i;o.parentNode;)o=o.parentNode;for(o=o.querySelectorAll("input[name="+JSON.stringify(""+s)+'][type="radio"]'),s=0;s<o.length;s++){var f=o[s];if(f!==i&&f.form===i.form){var m=Ul(f);if(!m)throw Error(t(90));pt(f),tt(f,m)}}}break;case"textarea":Se(i,o);break;case"select":s=o.value,s!=null&&C(i,!!o.multiple,s,!1)}},vn=cf,xt=Ms;var ly={usingClientEntryPoint:!1,Events:[bo,la,Ul,gt,$t,cf]},zo={findFiberByHostInstance:ps,bundleType:0,version:"18.3.1",rendererPackageName:"react-dom"},cy={bundleType:zo.bundleType,version:zo.version,rendererPackageName:zo.rendererPackageName,rendererConfig:zo.rendererConfig,overrideHookState:null,overrideHookStateDeletePath:null,overrideHookStateRenamePath:null,overrideProps:null,overridePropsDeletePath:null,overridePropsRenamePath:null,setErrorHandler:null,setSuspenseHandler:null,scheduleUpdate:null,currentDispatcherRef:R.ReactCurrentDispatcher,findHostInstanceByFiber:function(i){return i=W(i),i===null?null:i.stateNode},findFiberByHostInstance:zo.findFiberByHostInstance||ay,findHostInstancesForRefresh:null,scheduleRefresh:null,scheduleRoot:null,setRefreshHandler:null,getCurrentFiber:null,reconcilerVersion:"18.3.1-next-f1338f8080-20240426"};if(typeof __REACT_DEVTOOLS_GLOBAL_HOOK__<"u"){var yc=__REACT_DEVTOOLS_GLOBAL_HOOK__;if(!yc.isDisabled&&yc.supportsFiber)try{It=yc.inject(cy),Vt=yc}catch{}}return Vn.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED=ly,Vn.createPortal=function(i,s){var o=2<arguments.length&&arguments[2]!==void 0?arguments[2]:null;if(!vf(s))throw Error(t(200));return sy(i,s,null,o)},Vn.createRoot=function(i,s){if(!vf(i))throw Error(t(299));var o=!1,f="",m=ug;return s!=null&&(s.unstable_strictMode===!0&&(o=!0),s.identifierPrefix!==void 0&&(f=s.identifierPrefix),s.onRecoverableError!==void 0&&(m=s.onRecoverableError)),s=mf(i,1,!1,null,null,o,!1,f,m),i[ir]=s.current,Eo(i.nodeType===8?i.parentNode:i),new _f(s)},Vn.findDOMNode=function(i){if(i==null)return null;if(i.nodeType===1)return i;var s=i._reactInternals;if(s===void 0)throw typeof i.render=="function"?Error(t(188)):(i=Object.keys(i).join(","),Error(t(268,i)));return i=W(s),i=i===null?null:i.stateNode,i},Vn.flushSync=function(i){return Ms(i)},Vn.hydrate=function(i,s,o){if(!vc(s))throw Error(t(200));return xc(null,i,s,!0,o)},Vn.hydrateRoot=function(i,s,o){if(!vf(i))throw Error(t(405));var f=o!=null&&o.hydratedSources||null,m=!1,S="",b=ug;if(o!=null&&(o.unstable_strictMode===!0&&(m=!0),o.identifierPrefix!==void 0&&(S=o.identifierPrefix),o.onRecoverableError!==void 0&&(b=o.onRecoverableError)),s=lg(s,null,i,1,o??null,m,!1,S,b),i[ir]=s.current,Eo(i),f)for(i=0;i<f.length;i++)o=f[i],m=o._getVersion,m=m(o._source),s.mutableSourceEagerHydrationData==null?s.mutableSourceEagerHydrationData=[o,m]:s.mutableSourceEagerHydrationData.push(o,m);return new _c(s)},Vn.render=function(i,s,o){if(!vc(s))throw Error(t(200));return xc(null,i,s,!1,o)},Vn.unmountComponentAtNode=function(i){if(!vc(i))throw Error(t(40));return i._reactRootContainer?(Ms(function(){xc(null,null,i,!1,function(){i._reactRootContainer=null,i[ir]=null})}),!0):!1},Vn.unstable_batchedUpdates=cf,Vn.unstable_renderSubtreeIntoContainer=function(i,s,o,f){if(!vc(o))throw Error(t(200));if(i==null||i._reactInternals===void 0)throw Error(t(38));return xc(i,s,o,!1,f)},Vn.version="18.3.1-next-f1338f8080-20240426",Vn}var yg;function yy(){if(yg)return Sf.exports;yg=1;function n(){if(!(typeof __REACT_DEVTOOLS_GLOBAL_HOOK__>"u"||typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE!="function"))try{__REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE(n)}catch(e){console.error(e)}}return n(),Sf.exports=xy(),Sf.exports}var Sg;function Sy(){if(Sg)return Sc;Sg=1;var n=yy();return Sc.createRoot=n.createRoot,Sc.hydrateRoot=n.hydrateRoot,Sc}var My=Sy();const Mg=n=>{let e;const t=new Set,r=(p,g)=>{const y=typeof p=="function"?p(e):p;if(!Object.is(y,e)){const v=e;e=g??(typeof y!="object"||y===null)?y:Object.assign({},e,y),t.forEach(x=>x(e,v))}},a=()=>e,d={setState:r,getState:a,getInitialState:()=>h,subscribe:p=>(t.add(p),()=>t.delete(p))},h=e=n(r,a,d);return d},Ey=(n=>n?Mg(n):Mg),wy=n=>n;function Ty(n,e=wy){const t=Kc.useSyncExternalStore(n.subscribe,Kc.useCallback(()=>e(n.getState()),[n,e]),()=>e(n.getInitialState()));return Kc.useDebugValue(t),t}const by=n=>{const e=Ey(n),t=r=>Ty(e,r);return Object.assign(t,e),t},Ay=(n=>by),Eg=n=>Symbol.iterator in n,wg=n=>"entries"in n,Tg=(n,e)=>{const t=n instanceof Map?n:new Map(n.entries()),r=e instanceof Map?e:new Map(e.entries());if(t.size!==r.size)return!1;for(const[a,c]of t)if(!r.has(a)||!Object.is(c,r.get(a)))return!1;return!0},Cy=(n,e)=>{const t=n[Symbol.iterator](),r=e[Symbol.iterator]();let a=t.next(),c=r.next();for(;!a.done&&!c.done;){if(!Object.is(a.value,c.value))return!1;a=t.next(),c=r.next()}return!!a.done&&!!c.done};function Ny(n,e){return Object.is(n,e)?!0:typeof n!="object"||n===null||typeof e!="object"||e===null||Object.getPrototypeOf(n)!==Object.getPrototypeOf(e)?!1:Eg(n)&&Eg(e)?wg(n)&&wg(e)?Tg(n,e):Cy(n,e):Tg({entries:()=>Object.entries(n)},{entries:()=>Object.entries(e)})}function Ry(n){const e=Kc.useRef(void 0);return t=>{const r=n(t);return Ny(e.current,r)?e.current:e.current=r}}const Os=280,rv=/^[a-z0-9_]{3,16}$/,Ho=160,bg=32,hh={ringtone:"aurora",volume:.7,dnd:!1,accent:"sao",intensity:.8,theme:"light",style:"cyberpunk"},hp=/^\d{3}-\d{4}$/,Ea=500,wf=2,Zc=15,Py=6,Sr=n=>String(Math.max(0,Math.floor(n))).padStart(2,"0");function Wa(n){const e=new Date(n);return`${Sr(e.getHours())}:${Sr(e.getMinutes())}`}const sv=864e5;function vi(n){const e=new Date(n);return e.setHours(0,0,0,0),e.getTime()}const av=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],ov=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function ph(n,e=Date.now()){const t=Math.round((vi(e)-vi(n))/sv);if(t<=0)return"Today";if(t===1)return"Yesterday";const r=new Date(n);return`${av[r.getDay()]} ${r.getDate()} ${ov[r.getMonth()]}`}function lv(n,e=Date.now()){const t=Math.round((vi(e)-vi(n))/sv);if(t<=0)return Wa(n);if(t===1)return"Yesterday";const r=new Date(n);return t<7?av[r.getDay()]:`${r.getDate()} ${ov[r.getMonth()]}`}function Eu(n,e=Date.now()){const t=Math.max(0,(e-n)/1e3);return t<50?"now":t<3600?`${Math.round(t/60)} min ago`:t<6*3600?`${Math.round(t/3600)} h ago`:lv(n,e)}function pp(n){const e=Math.max(0,Math.floor(n)),t=Math.floor(e/3600),r=Math.floor(e%3600/60),a=e%60;return t>0?`${t}:${Sr(r)}:${Sr(a)}`:`${r}:${Sr(a)}`}function mp(n){const e=n.replace(/\D/g,"").slice(0,7);return e.length>3?`${e.slice(0,3)}-${e.slice(3)}`:e}function Ly(n){const e=n.replace(/[^\p{L}\p{N} ]/gu," ").trim().split(/\s+/).filter(Boolean);return e.length===0?"#":e.length===1?e[0].slice(0,2).toUpperCase():(e[0][0]+e[e.length-1][0]).toUpperCase()}function Qc(n){let e=0;for(let t=0;t<n.length;t++)e=e*31+n.charCodeAt(t)>>>0;return e%360}function ky(n,e){return n.find(t=>t.number===e)}function Fi(n,e,t){return ky(n,e)?.name??(t&&t!==e?t:e)}function Ag(n,e,t){return Math.min(t,Math.max(e,n))}async function cv(n){try{if(navigator.clipboard?.writeText)return await navigator.clipboard.writeText(n),!0}catch{}try{const e=document.createElement("textarea");e.value=n,e.setAttribute("readonly",""),e.style.position="fixed",e.style.opacity="0",document.body.appendChild(e),e.select();const t=document.execCommand("copy");return e.remove(),t}catch{return!1}}let Cg=1;const uv="nl.recentsSeenAt";function Dy(){try{const n=Number(localStorage.getItem(uv));if(Number.isFinite(n)&&n>0)return n}catch{}return Date.now()-864e5}let Iy=1;const Ng=n=>n.app;function Uy(n,e){const t=n.filter(r=>r.id!==e.id);return[e,...t].sort((r,a)=>a.updatedAt-r.updatedAt)}const Fy={posts:[],hasMore:!1,loading:!1,loadingMore:!1,rev:0};function Rg(n,e){let t=null;const r=a=>{a&&(n[a.id]&&(t??={...n},t[a.id]={cred:a.cred,echoes:a.echoes,replies:a.replies,credded:a.credded,echoed:a.echoed}),r(a.echoOf))};return e.forEach(r),t??n}function Mc(n,e){return n.some(t=>t.id===e||t.echoOf?.id===e)?n.filter(t=>t.id!==e&&!(t.echoOf?.id===e&&!t.body)).map(t=>t.echoOf?.id===e?{...t,echoOf:null,echoGone:!0}:t):n}function Pg(n,e,t){let r=null;for(const a of e)a.kind!=="text"||a.at<t||n[a.id]||(r??={...n},r[a.id]=1);return r??n}const fe=Ay()((n,e)=>({state:null,phase:"closed",openSeq:0,implantFlow:!1,implantAutoStart:!1,menu:null,cursor:0,row:0,stack:[],callView:!1,navDir:"fwd",dial:"",threadCache:{},pending:[],talkers:{},toasts:[],clock:null,toggleKey:"F2",ended:null,keyboard:!1,settingsDraft:{},seenToday:{},dayStart:vi(Date.now()),recentsSeenAt:Dy(),feeds:{},screamThreads:{},profiles:{},pings:null,postLive:{},postGone:{},freshPosts:[],composeCtx:{},applyState(t){const r=e().state,a=r?.line?.number!==t.line?.number,c=e().phase,u=r?.implant?.installed===!1&&t.implant?.installed!==!1&&!e().implantFlow&&(c==="open"||c==="opening"),d=new Set((t.threads??[]).map(h=>h.id));n(h=>({state:{...t,settings:{...hh,...t.settings??{}},contacts:t.contacts??[],threads:t.threads??[],recents:t.recents??[],apps:t.apps??[],social:t.social??null},threadCache:{},...a?{feeds:{},screamThreads:{},profiles:{},pings:null,postLive:{},postGone:{},freshPosts:[],composeCtx:{}}:{},pending:[],settingsDraft:{},seenToday:a?{}:h.seenToday,stack:a?[]:h.stack.filter(p=>!("threadId"in p)||d.has(p.threadId)),menu:a?null:h.menu,callView:!!t.call&&(t.call.phase==="incoming"||h.callView),...u?{phase:"opening",openSeq:h.openSeq+1}:{}}))},applyPatch(t){const r=e().state;if(!r)return;const a={...r};Object.keys(t).forEach(u=>{t[u]!==void 0&&(a[u]=t[u])}),t.settings&&(a.settings={...hh,...t.settings});const c=new Set(a.threads.map(u=>u.id));n(u=>({state:a,settingsDraft:t.settings?{}:u.settingsDraft,stack:t.threads?u.stack.filter(d=>!("threadId"in d)||c.has(d.threadId)):u.stack}))},openUi(t){const r=e(),a=r.phase==="closed"||r.phase==="closing",c={};a&&(c.phase="opening",c.openSeq=r.openSeq+1,c.implantFlow=!1),c.implantAutoStart=t?.install===!0;const u=t?.app;if(u&&u!=="home"){let d=[],h=null;u==="messages"?(h="messages",d=[{app:"messages",screen:"list"}],typeof t.threadId=="number"&&d.push({app:"messages",screen:"thread",threadId:t.threadId})):u==="phone"?(h="phone",d=[{app:"phone",tab:t.number?"dial":"recents"}],t.number&&(c.dial=t.number)):u==="contacts"?(h="contacts",d=[{app:"contacts",screen:"list",filter:"all"}],t.number&&d.push({app:"contacts",screen:"edit",number:t.number})):u==="social"?(h="social",d=[{app:"social",screen:"feed",mode:"pulse"}],t.screen==="thread"&&typeof t.postId=="number"?d.push({app:"social",screen:"thread",postId:t.postId}):t.screen==="profile"&&t.handle?d.push({app:"social",screen:"profile",handle:t.handle}):t.screen==="tag"&&t.tag?d.push({app:"social",screen:"tag",tag:t.tag}):t.screen==="compose"?d.push({app:"social",screen:"compose"}):t.screen==="pings"?d.push({app:"social",screen:"pings"}):t.screen==="heat"?d.push({app:"social",screen:"heat"}):t.screen==="edit"&&d.push({app:"social",screen:"edit"})):u==="settings"?(h="settings",d=[{app:"settings",section:"sound"}]):u==="status"?(h="status",d=[{app:"status"}]):h=`app:${u}`,Object.assign(c,{menu:h,stack:d,callView:!1,row:0})}else if(u==="home")Object.assign(c,{menu:null,stack:[],callView:!1});else if(a){const d=r.state?.call;c.callView=!!d}n(c)},setPhase(t){n(t==="closed"?{phase:t,implantFlow:!1}:{phase:t})},closeUi(){const t=e().phase;t==="closed"||t==="closing"||n({phase:"closing"})},setImplantFlow(t){n({implantFlow:t})},implantOnline(t){const r=e();if(r.phase==="closed"||r.phase==="closing")return;const a=r.state?{...r.state,implant:t??{...r.state.implant,installed:!0,installedAt:Date.now()}}:r.state;n({state:a,implantFlow:!1,phase:"opening",openSeq:r.openSeq+1,menu:null,stack:[],callView:!1})},setMenu(t){n({menu:t,row:0,stack:[],callView:!1})},setCursor(t){n({cursor:t})},setRow(t){n({row:t})},resetView(t){n(t?{stack:[t],menu:Ng(t),callView:!1,navDir:"fwd"}:{stack:[],navDir:"back"})},pushView(t){n(r=>({stack:[...r.stack,t],menu:Ng(t),callView:!1,navDir:"fwd"}))},replaceTop(t){n(r=>({stack:[...r.stack.slice(0,-1),t]}))},back(){const t=e(),r=t.state?.call;return t.callView&&r&&r.phase!=="incoming"?(n({callView:!1}),!0):t.stack.length>1?(n({stack:t.stack.slice(0,-1),navDir:"back"}),!0):t.stack.length===1?(n({stack:[]}),!0):t.menu?(n({menu:null}),!0):!1},setCallView(t){n({callView:t})},setDial(t){n({dial:t})},threadLoading(t,r){n(a=>{const c=a.threadCache[t],u=c??{messages:[],members:[],hasMore:!1,loading:!1,loadingMore:!1,rev:0,lastOp:"load"};return{threadCache:{...a.threadCache,[t]:{...u,loading:r?u.loading:!c,loadingMore:r}}}})},threadLoaded(t){n(r=>{const a=r.threadCache[t.threadId],c=t.messages??[];let u;if(t.prepend&&a){const h=new Set(a.messages.map(p=>p.id));u=[...c.filter(p=>!h.has(p.id)),...a.messages]}else u=c;const d=new Set(u.map(h=>h.id));return{threadCache:{...r.threadCache,[t.threadId]:{messages:u,members:t.members??a?.members??[],hasMore:!!t.hasMore,loading:!1,loadingMore:!1,rev:(a?.rev??0)+1,lastOp:t.prepend?"prepend":"load"}},pending:r.pending.filter(h=>h.serverId==null||!d.has(h.serverId)),seenToday:Pg(r.seenToday,c,r.dayStart)}})},messageArrived({message:t,summary:r}){n(a=>{const c=a.state?{...a.state,threads:r?Uy(a.state.threads,r):a.state.threads}:a.state,u=a.threadCache[t.threadId];let d=a.threadCache;return u&&!u.messages.some(h=>h.id===t.id)&&(d={...a.threadCache,[t.threadId]:{...u,messages:[...u.messages,t],members:r?.members??u.members,rev:u.rev+1,lastOp:"append"}}),{state:c,threadCache:d,pending:a.pending.filter(h=>h.serverId!==t.id),seenToday:Pg(a.seenToday,[t],a.dayStart)}})},setUnread(t,r){n(a=>a.state?{state:{...a.state,threads:a.state.threads.map(c=>c.id===t?{...c,unread:r}:c)}}:{})},addPending(t){n(r=>({pending:[...r.pending,t]}))},pendingSent(t,r){n(a=>({pending:Object.values(a.threadCache).some(u=>u.messages.some(d=>d.id===r))?a.pending.filter(u=>u.tempId!==t):a.pending.map(u=>u.tempId===t?{...u,serverId:r}:u)}))},pendingFailed(t){n(r=>({pending:r.pending.map(a=>a.tempId===t?{...a,failed:!0}:a)}))},dropPending(t){n(r=>({pending:r.pending.filter(a=>a.tempId!==t)}))},setCall(t){n(r=>{const a=r.state?.call??null,c=r.state?{...r.state,call:t}:r.state;let u=r.callView;return t?(t.phase==="incoming"||!a||a.id!==t.id||a.phase==="incoming")&&(u=!0):u=!1,{state:c,callView:u,talkers:t?r.talkers:{}}})},setTalkers(t){n({talkers:t??{}})},pushToast(t){n(r=>{const a={...t,id:t.id??`t${Cg}`,at:t.at??Date.now(),key:Cg++,born:Date.now()};return{toasts:[...r.toasts.filter(u=>u.id!==a.id),a].slice(-3)}})},dismissToast(t){n(r=>({toasts:r.toasts.filter(a=>a.key!==t)}))},setClock(t){n({clock:t})},setToggleKey(t){n({toggleKey:t})},setEnded(t){n({ended:t?{...t,key:Iy++}:null})},setKeyboard(t){n({keyboard:t})},setSettingsDraft(t){n(r=>({settingsDraft:{...r.settingsDraft,...t}}))},replaceSettingsDraft(t){n({settingsDraft:t})},markRecentsSeen(){const t=Date.now();try{localStorage.setItem(uv,String(t))}catch{}n({recentsSeenAt:t})},setSocialUnread(t){n(r=>r.state?.social?{state:{...r.state,social:{...r.state.social,unread:Math.max(0,t)}}}:{})},setSocialHandle(t){n(r=>{const a=r.state?.social?.handle;if(!r.state?.social||!a||a===t)return{};const{[a]:c,...u}=r.profiles;return{state:{...r.state,social:{...r.state.social,handle:t}},profiles:u,stack:r.stack.map(d=>d.app==="social"&&d.screen==="profile"&&d.handle===a?{...d,handle:t}:d)}})},feedLoading(t,r){n(a=>{const c=a.feeds[t];return{feeds:{...a.feeds,[t]:{...c??Fy,loading:r?!!c?.loading:!c,loadingMore:r}}}})},feedLoaded(t,r,a,c){n(u=>{const d=u.feeds[t];let h=r;if(c&&d){const y=new Set(d.posts.map(v=>v.id));h=[...d.posts,...r.filter(v=>!y.has(v.id))]}const p=r[0]?.id??0,g=t==="pulse"&&!c?u.freshPosts.filter(y=>y.id>p):u.freshPosts;return{feeds:{...u.feeds,[t]:{posts:h,hasMore:a,loading:!1,loadingMore:!1,rev:(d?.rev??0)+1}},postLive:Rg(u.postLive,r),freshPosts:g}})},feedFailed(t){n(r=>{const a=r.feeds[t];return a?{feeds:{...r.feeds,[t]:{...a,loading:!1,loadingMore:!1}}}:{}})},prependPosts(t,r){n(a=>{const c=a.feeds[t];if(!c)return{};const u=r.filter(d=>!c.posts.some(h=>h.id===d.id));return u.length?{feeds:{...a.feeds,[t]:{...c,posts:[...u,...c.posts],rev:c.rev+1}}}:{}})},screamThreadLoading(t){n(r=>{const a=r.screamThreads[t];return{screamThreads:{...r.screamThreads,[t]:a?{...a,loading:!a.post}:{post:null,parents:[],replies:[],loading:!0,missing:!1}}}})},screamThreadLoaded(t,r){n(a=>{const c=a.screamThreads[t];return r?{screamThreads:{...a.screamThreads,[t]:{...r,loading:!1,missing:!1}},postLive:Rg(a.postLive,[...r.post?[r.post]:[],...r.parents,...r.replies])}:{screamThreads:{...a.screamThreads,[t]:{post:c?.post??null,parents:c?.parents??[],replies:c?.replies??[],loading:!1,missing:!c?.post}}}})},addReply(t,r){n(a=>{const c=a.screamThreads[t],u=a.postLive[t],d=c?.post??Object.values(a.feeds).flatMap(h=>h.posts).find(h=>h.id===t);return{screamThreads:c&&!c.replies.some(h=>h.id===r.id)?{...a.screamThreads,[t]:{...c,replies:[...c.replies,r]}}:a.screamThreads,postLive:{...a.postLive,[t]:{...u,replies:(u?.replies??d?.replies??0)+1}}}})},setProfile(t){n(r=>({profiles:{...r.profiles,[t.handle]:t}}))},pingsLoading(t){n(r=>({pings:{pings:r.pings?.pings??[],hasMore:r.pings?.hasMore??!1,loading:t?!!r.pings?.loading:!r.pings,loadingMore:t}}))},pingsLoaded(t,r,a){n(c=>{const u=c.pings?.pings??[],d=new Set(u.filter(g=>!g.read).map(g=>g.id)),h=t.map(g=>d.has(g.id)?{...g,read:!1}:g);return{pings:{pings:a?[...u,...h.filter(g=>!u.some(y=>y.id===g.id))]:h,hasMore:r,loading:!1,loadingMore:!1}}})},pingsSeen(){n(t=>t.pings?{pings:{...t.pings,pings:t.pings.pings.map(r=>r.read?r:{...r,read:!0})}}:{})},setPostLive(t,r){n(a=>({postLive:{...a.postLive,[t]:{...a.postLive[t],...r}}}))},removePost(t){n(r=>{const a={};for(const[u,d]of Object.entries(r.feeds)){const h=Mc(d.posts,t);a[u]=h===d.posts?d:{...d,posts:h,rev:d.rev+1}}const c={};for(const[u,d]of Object.entries(r.screamThreads)){if(Number(u)===t)continue;const h=d.post?.echoOf?.id===t?{...d.post,echoOf:null,echoGone:!0}:d.post;c[Number(u)]={...d,post:h,parents:Mc(d.parents,t),replies:Mc(d.replies,t)}}return{feeds:a,screamThreads:c,postGone:{...r.postGone,[t]:1},freshPosts:Mc(r.freshPosts,t)}})},pushFresh(t){n(r=>r.freshPosts.some(a=>a.id===t.id)||r.feeds.pulse?.posts.some(a=>a.id===t.id)?{}:{freshPosts:[t,...r.freshPosts].slice(0,50)})},takeFresh(){const t=e().freshPosts;return n({freshPosts:[]}),t},rememberPost(t){n(r=>({composeCtx:{...r.composeCtx,[t.id]:t}}))}})),gp=n=>({...hh,...n.state?.settings??{},...n.settingsDraft}),_p=n=>n.stack[n.stack.length-1]??null,be=()=>fe.getState(),dv=n=>n.state?.implant?.installed===!1,mh=n=>!!n.state?.ready&&(dv(n)||n.implantFlow),gh=n=>dv(n)||n.implantFlow,eo=()=>fe(Ry(gp));function Oy(n){const e=fe(t=>t.postLive[n.id]);return e?{...n,...e}:n}const Ln=[];function jy({children:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=()=>{const r=e.current;if(!r)return;const a=window.innerWidth,c=window.innerHeight,u=Math.min(a/1920,c/1080),d=(a-1920*u)/2,h=(c-1080*u)/2;r.style.transform=`translate(${d}px, ${h}px) scale(${u})`,document.documentElement.style.setProperty("--stage-scale",String(u))};return t(),window.addEventListener("resize",t),()=>window.removeEventListener("resize",t)},[]),l.jsx("div",{ref:e,className:"nl-stage",children:n})}function zy(){const n=eo();q.useEffect(()=>{const e=document.documentElement;e.dataset.accent=n.accent,e.dataset.theme=n.theme==="dark"?"dark":"light",e.dataset.style=n.style==="sao"?"sao":"cyberpunk";const t=Math.min(1,Math.max(.3,Number.isFinite(n.intensity)?n.intensity:.8));e.style.setProperty("--intensity",t.toFixed(2))},[n.accent,n.intensity,n.theme,n.style]),q.useEffect(()=>{const e=window.matchMedia?.("(prefers-reduced-motion: reduce)"),t=()=>{document.documentElement.dataset.motion=e?.matches?"reduced":"full"};return t(),e?.addEventListener?.("change",t),()=>e?.removeEventListener?.("change",t)},[])}function rs(){return document.documentElement.dataset.motion==="reduced"}const By=new Set(["contacts","threads","recents","apps","members","participants","messages","numbers","posts","parents","replies","profiles","pings","tags","districts","hot"]);function Hy(n){if(Array.isArray(n))return n;if(n&&typeof n=="object"){const e=Object.entries(n);if(e.length===0)return[];if(e.every(([t])=>/^\d+$/.test(t)))return e.sort((t,r)=>Number(t[0])-Number(r[0])).map(([,t])=>t)}return[]}function Zo(n,e){if(e>8||n===null||typeof n!="object")return n;if(Array.isArray(n))return n.map(r=>Zo(r,e+1));const t={};for(const[r,a]of Object.entries(n))t[r]=By.has(r)&&a!==null&&typeof a=="object"?Hy(a).map(c=>Zo(c,e+1)):Zo(a,e+1);return t}function Lg(n){return!!n&&typeof n=="object"&&typeof n.id=="number"}function kg(n){return Zo(n,0)}function Vy(n,e){if(n==="nl:talkers")return e;if(n==="nl:call"&&!Lg(e))return null;const t=Zo(e,0);return n==="nl:state"&&t&&typeof t=="object"&&"call"in t&&!Lg(t.call)&&(t.call=null),t}const Dg=new Map,wu=()=>window.Open77;function Gn(n,e){let t=Dg.get(n);if(!t){const r=new Set;Dg.set(n,r),t=r,wu()?.on(n,a=>{const c=Vy(n,a);for(const u of r)try{u(c)}catch(d){console.error(`[neuralink] handler ${n} failed`,d)}})}return t.add(e),()=>{t?.delete(e)}}function Tu(n,e){try{wu()?.emit(n,e)}catch(t){console.error(`[neuralink] emit ${n} failed`,t)}}function Gy(n){Tu("nl:sound",{name:n})}let Ig=!1;function Wy(){Ig||(Ig=!0,wu()?.ready())}class Sn extends Error{constructor(e){super(e),this.slug=e,this.name="RequestError"}}function Ug(n){const e=n.trim();if(e.startsWith('"')||e.startsWith("{"))try{const t=JSON.parse(e);if(typeof t=="string")return t;if(t&&typeof t=="object")return fv(t)}catch{}return e}function fv(n){if(n instanceof Sn)return n.slug;if(n instanceof Error)return n.message?Ug(n.message):"unknown";if(typeof n=="string")return Ug(n);if(n&&typeof n=="object"){const e=n;for(const t of[e.reason,e.error,e.message])if(typeof t=="string"&&t)return t}return"unknown"}async function to(n,e){const t=wu();if(!t?.invoke)throw new Sn("unavailable");let r;try{r=await t.invoke("nl:request",{op:n,args:e})}catch(c){throw new Sn(fv(c))}const a=r;if(a&&typeof a=="object"&&"ok"in a){if(a.ok)return kg(a.data??{});throw new Sn(a.reason??a.error??"unknown")}return kg(r??{})}function hv(){return!!window.__neuralinkMock}let Fg=0;function Ee(n){const e=gp(be());if(n==="chime"&&e.dnd)return;const t=Math.max(0,Math.min(1,e.volume));if(!(t<=.001)){if(n==="tick"){const r=performance.now();if(r-Fg<60)return;Fg=r}hv()&&console.debug(`[neuralink] sound ${n}`),Tu("nl:sound",{name:`ui:${n}`,volume:t})}}function $y(){const n=eo().style!=="sao";return q.useEffect(()=>{if(!n)return;const e=window.setTimeout(()=>Ee("glitch"),90);return()=>window.clearTimeout(e)},[n]),l.jsxs("div",{className:"linkstart","aria-hidden":!0,children:[l.jsx("span",{className:"linkstart__flash"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--a"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--b"}),l.jsx("span",{className:"linkstart__ring linkstart__ring--c"}),l.jsx("span",{className:"linkstart__cross"}),l.jsx("div",{className:"linkstart__band",children:l.jsxs("svg",{width:"100%",height:"100%",children:[l.jsx("defs",{children:l.jsx("pattern",{id:"nl-hex",width:"28",height:"48.5",patternUnits:"userSpaceOnUse",patternTransform:"scale(1.1)",children:l.jsx("path",{d:"M14 0 L28 8.08 L28 24.25 L14 32.33 L0 24.25 L0 8.08 Z M14 32.33 L14 48.5",fill:"none",stroke:"currentColor",strokeWidth:"1.1"})})}),l.jsx("rect",{width:"100%",height:"100%",fill:"url(#nl-hex)"})]})}),l.jsxs("div",{className:"linkstart__text",children:[l.jsx("span",{className:"linkstart__word label",children:n?"Neural-Link":"Link start"}),l.jsx("span",{className:"linkstart__sub mono",children:n?"kiroshi nl-77 · synapse handshake ok":"neural handshake · ok"})]})]})}const Xy=90,Tf=960,Vo=540;function qy({running:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=e.current;if(!t||!n||rs())return;const r=t.getContext("2d",{alpha:!0});if(!r)return;const a=()=>Number(getComputedStyle(document.documentElement).getPropertyValue("--intensity"))||.8,c=()=>getComputedStyle(document.documentElement).getPropertyValue("--holo-rgb").trim()||"0, 229, 255";let u=a(),d=c();const h=w=>({x:40+Math.random()*880,y:w?Math.random()*Vo:Vo+10,vx:(Math.random()-.5)*.12,vy:-(.08+Math.random()*.28),r:.5+Math.random()*1.5,a:.15+Math.random()*.5,tw:Math.random()*Math.PI*2,hue:Math.random()<.72?0:1}),p=Array.from({length:Xy},()=>h(!0));let g=0,y=performance.now(),v=0;const x=w=>{g=requestAnimationFrame(x);const E=Math.min(50,w-y)/16.67;y=w,++v%120===0&&(u=a(),d=c()),r.clearRect(0,0,Tf,Vo);for(const _ of p){_.x+=_.vx*E,_.y+=_.vy*E,_.tw+=.03*E,_.y<-10&&Object.assign(_,h(!1));const M=_.a*(.55+.45*Math.sin(_.tw))*u;r.fillStyle=_.hue===0?`rgba(${d}, ${M.toFixed(3)})`:`rgba(255, 255, 255, ${(M*.9).toFixed(3)})`,r.beginPath(),r.arc(_.x,_.y,_.r,0,Math.PI*2),r.fill()}};return g=requestAnimationFrame(x),()=>{cancelAnimationFrame(g),r.clearRect(0,0,Tf,Vo)}},[n]),l.jsx("canvas",{ref:e,className:"particles",width:Tf,height:Vo,"aria-hidden":!0})}const si={x:0,y:0,t:0};let pv=0,mv=0,gv=0;function Yy(n,e){pv=n,mv=e,gv=performance.now()}function Ky(n,e){si.t+=n;const t=Math.min(1,Math.max(0,(performance.now()-gv-2500)/2500)),r=Math.sin(si.t*.31)*.16+Math.sin(si.t*.73)*.04,a=Math.sin(si.t*.23+1.3)*.1,c=pv*(1-t*.6)+r*t,u=mv*(1-t*.6)+a*t,d=1-Math.exp(-n*4.2);si.x+=(c-si.x)*d,si.y+=(u-si.y)*d}const Ec=960,bf=540,Zy=86,Qy=3;function Og(n,e){const t=document.createElement("canvas");t.width=t.height=e;const r=t.getContext("2d"),a=r.createRadialGradient(e/2,e/2,0,e/2,e/2,e/2);return a.addColorStop(0,"rgba(255,255,255,1)"),a.addColorStop(.18,`rgba(${n},0.95)`),a.addColorStop(.45,`rgba(${n},0.28)`),a.addColorStop(1,`rgba(${n},0)`),r.fillStyle=a,r.fillRect(0,0,e,e),t}function Jy({running:n}){const e=q.useRef(null);return q.useEffect(()=>{const t=e.current;if(!t||!n||rs())return;const r=t.getContext("2d",{alpha:!0});if(!r)return;const a=Og("46,230,245",32),c=Og("255,59,72",32),u=Math.random,d=Array.from({length:Zy},()=>{let E=u()*2-1;E=Math.sign(E)*Math.pow(Math.abs(E),.6);const _=u()*2-1,M=.25+Math.hypot(E+.4,_*.6)*.75;return{x:E,y:_,z:.25+u()*.75,vx:(u()-.5)*.012,vy:(u()-.5)*.01,ph:u()*6.28,fire:0,sx:0,sy:0,a:0,wake:M}}),h=[];d.forEach((E,_)=>{const M=d.map((k,A)=>({j:A,d:(k.x-E.x)**2+((k.y-E.y)*.6)**2+(k.z-E.z)**2})).filter(k=>k.j!==_).sort((k,A)=>k.d-A.d).slice(0,Qy);for(const k of M)h.some(([A,R])=>A===k.j&&R===_||A===_&&R===k.j)||h.push([_,k.j])});const p=[];let g=0,y=performance.now(),v=0,x=0;const w=E=>{const _=Math.min(.05,Math.max(0,(E-y)/1e3));y=E,x+=_,r.clearRect(0,0,Ec,bf);const M=si.x,k=si.y;for(const A of d){A.x+=A.vx*_,A.y+=A.vy*_,(A.x<-1.15||A.x>1.15)&&(A.vx*=-1),(A.y<-1.15||A.y>1.15)&&(A.vy*=-1),A.fire=Math.max(0,A.fire-_*1.8),A.wake>0&&x>=A.wake&&(A.wake=0,A.fire=1);const R=A.z;A.sx=(.5+A.x*.5)*Ec-M*22*R,A.sy=(.5+A.y*.5)*bf-k*13*R;const L=Math.abs(A.sx/Ec-.5)*2;A.a=(.25+.75*Math.min(1,Math.max(0,(L-.12)/.5)))*(.35+.65*R)}r.lineWidth=.6;for(const[A,R]of h){const L=d[A],D=d[R],U=Math.min(L.a,D.a)*.28+Math.max(L.fire,D.fire)*.35;U<.02||(r.strokeStyle=`rgba(46,230,245,${U.toFixed(3)})`,r.beginPath(),r.moveTo(L.sx,L.sy),r.lineTo(D.sx,D.sy),r.stroke())}for(const A of d){const R=(3+A.z*5)*(1+A.fire*1.6)*(.85+.15*Math.sin(si.t*2+A.ph));r.globalAlpha=Math.min(1,A.a*(.55+A.fire)),r.drawImage(A.fire>.5?c:a,A.sx-R,A.sy-R,R*2,R*2)}if(v-=_,v<=0&&p.length<26){v=.05+u()*.12;const[A,R]=h[Math.floor(u()*h.length)],L=u()<.5;p.push({from:L?A:R,to:L?R:A,t:0,speed:.6+u()*.9,red:u()<.16})}for(let A=p.length-1;A>=0;A--){const R=p[A];R.t+=_*R.speed;const L=d[R.from],D=d[R.to];if(R.t>=1){if(D.fire=Math.max(D.fire,R.red?1:.7),p.splice(A,1),u()<.35&&p.length<26){const J=h.filter(([ve,V])=>ve===R.to||V===R.to),ae=J[Math.floor(u()*J.length)];ae&&p.push({from:R.to,to:ae[0]===R.to?ae[1]:ae[0],t:0,speed:R.speed,red:R.red})}continue}const U=L.sx+(D.sx-L.sx)*R.t,$=L.sy+(D.sy-L.sy)*R.t,te=Math.min(L.a,D.a)+.25,T=R.red?7:5.5;r.globalAlpha=Math.min(1,te),r.drawImage(R.red?c:a,U-T,$-T,T*2,T*2),r.globalAlpha=Math.min(1,te*.4);const P=L.sx+(D.sx-L.sx)*Math.max(0,R.t-.06),se=L.sy+(D.sy-L.sy)*Math.max(0,R.t-.06);r.drawImage(R.red?c:a,P-T*.7,se-T*.7,T*1.4,T*1.4)}r.globalAlpha=1,g=requestAnimationFrame(w)};return g=requestAnimationFrame(w),()=>cancelAnimationFrame(g)},[n]),l.jsx("canvas",{ref:e,className:"neural-field",width:Ec,height:bf,"aria-hidden":!0})}const eS=2;function tS(n,e){const t=Math.max(30,(e.x-n.x)*.5);return`M${n.x.toFixed(1)},${n.y.toFixed(1)} C${(n.x+t).toFixed(1)},${n.y.toFixed(1)} ${(e.x-t).toFixed(1)},${e.y.toFixed(1)} ${e.x.toFixed(1)},${e.y.toFixed(1)}`}function nS(){const n=q.useRef(null);return q.useEffect(()=>{const e=n.current;if(!e)return;const t=Array.from(e.querySelectorAll(".syn"));let r=0;const a=performance.now(),c=u=>{r=requestAnimationFrame(c);const d=document.querySelector(".nl-stage");if(!d)return;const h=d.getBoundingClientRect(),p=h.width/1920||1,g=(A,R)=>({x:(A-h.left)/p,y:(R-h.top)/p}),y=A=>{const R=document.querySelector(A);return R?R.getBoundingClientRect():null},v=y(".column .rb.is-selected .rb__disc"),x=y(".subpanel__head"),w=y(".subpanel .slab.is-active"),E=y(".tilt--window .nl3d__face")??y(".tilt--call .nl3d__face"),_=[null,null];v&&x&&(_[0]=[g(v.right+2,v.top+v.height/2),g(x.left-2,x.top+x.height/2)]);const M=w??(x?null:v);if(M&&E){const A=Math.min(E.bottom-90*p,Math.max(E.top+90*p,M.top+M.height/2));_[1]=[g(M.right+2,M.top+M.height/2),g(E.left+4,A)]}const k=(u-a)/1e3;_.forEach((A,R)=>{const L=t[R];if(!L)return;if(!A){L.style.opacity="0";return}L.style.opacity="1";const D=tS(A[0],A[1]),U=L.querySelectorAll("path");U.forEach(se=>se.setAttribute("d",D));const $=U[1],te=$.getTotalLength();L.querySelectorAll("circle.syn__dot").forEach((se,J)=>{const ae=(k*(.55+J*.17)+J*.5)%1,ve=$.getPointAtLength(ae*te);se.setAttribute("cx",ve.x.toFixed(1)),se.setAttribute("cy",ve.y.toFixed(1)),se.setAttribute("opacity",Math.sin(ae*Math.PI).toFixed(2))});const[T,P]=L.querySelectorAll("circle.syn__end");T?.setAttribute("cx",A[0].x.toFixed(1)),T?.setAttribute("cy",A[0].y.toFixed(1)),P?.setAttribute("cx",A[1].x.toFixed(1)),P?.setAttribute("cy",A[1].y.toFixed(1))})};return rs()?c(performance.now()):r=requestAnimationFrame(c),()=>cancelAnimationFrame(r)},[]),l.jsxs("svg",{ref:n,className:"synapse",width:1920,height:1080,viewBox:"0 0 1920 1080","aria-hidden":!0,children:[l.jsx("defs",{children:l.jsx("filter",{id:"syn-bloom",x:"-20%",y:"-50%",width:"140%",height:"200%",children:l.jsx("feGaussianBlur",{stdDeviation:"4"})})}),Array.from({length:eS},(e,t)=>l.jsxs("g",{className:`syn syn--${t}`,style:{opacity:0},children:[l.jsx("path",{className:"syn__bloom",filter:"url(#syn-bloom)"}),l.jsx("path",{className:"syn__core"}),l.jsx("path",{className:"syn__flow"}),l.jsx("circle",{className:"syn__end",r:3.2}),l.jsx("circle",{className:"syn__end",r:3.2}),l.jsx("circle",{className:"syn__dot",r:4}),l.jsx("circle",{className:"syn__dot",r:3})]},t))]})}/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const iS=n=>n.replace(/([a-z0-9])([A-Z])/g,"$1-$2").toLowerCase(),_v=(...n)=>n.filter((e,t,r)=>!!e&&e.trim()!==""&&r.indexOf(e)===t).join(" ").trim();/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */var rS={xmlns:"http://www.w3.org/2000/svg",width:24,height:24,viewBox:"0 0 24 24",fill:"none",stroke:"currentColor",strokeWidth:2,strokeLinecap:"round",strokeLinejoin:"round"};/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const sS=q.forwardRef(({color:n="currentColor",size:e=24,strokeWidth:t=2,absoluteStrokeWidth:r,className:a="",children:c,iconNode:u,...d},h)=>q.createElement("svg",{ref:h,...rS,width:e,height:e,stroke:n,strokeWidth:r?Number(t)*24/Number(e):t,className:_v("lucide",a),...d},[...u.map(([p,g])=>q.createElement(p,g)),...Array.isArray(c)?c:[c]]));/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const _e=(n,e)=>{const t=q.forwardRef(({className:r,...a},c)=>q.createElement(sS,{ref:c,iconNode:e,className:_v(`lucide-${iS(n)}`,r),...a}));return t.displayName=`${n}`,t};/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const aS=[["path",{d:"M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2",key:"169zse"}]],lu=_e("Activity",aS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const oS=[["rect",{x:"2",y:"4",width:"20",height:"16",rx:"2",key:"izxlao"}],["path",{d:"M10 4v4",key:"pp8u80"}],["path",{d:"M2 8h20",key:"d11cs7"}],["path",{d:"M6 4v4",key:"1svtjw"}]],vv=_e("AppWindow",oS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const lS=[["path",{d:"m12 19-7-7 7-7",key:"1l729n"}],["path",{d:"M19 12H5",key:"x3x0zl"}]],cS=_e("ArrowLeft",lS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const uS=[["path",{d:"m5 12 7-7 7 7",key:"hav0vg"}],["path",{d:"M12 19V5",key:"x0mq9r"}]],dS=_e("ArrowUp",uS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const fS=[["circle",{cx:"12",cy:"12",r:"4",key:"4exip2"}],["path",{d:"M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8",key:"7n84p3"}]],xv=_e("AtSign",fS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const hS=[["rect",{width:"20",height:"12",x:"2",y:"6",rx:"2",key:"9lu3g6"}],["circle",{cx:"12",cy:"12",r:"2",key:"1c9p78"}],["path",{d:"M6 12h.01M18 12h.01",key:"113zkx"}]],pS=_e("Banknote",hS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const mS=[["path",{d:"M10.268 21a2 2 0 0 0 3.464 0",key:"vwvbt9"}],["path",{d:"M17 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 .258-1.742",key:"178tsu"}],["path",{d:"m2 2 20 20",key:"1ooewy"}],["path",{d:"M8.668 3.01A6 6 0 0 1 18 8c0 2.687.77 4.653 1.707 6.05",key:"1hqiys"}]],gS=_e("BellOff",mS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const _S=[["path",{d:"M10.268 21a2 2 0 0 0 3.464 0",key:"vwvbt9"}],["path",{d:"M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326",key:"11g9vi"}]],_h=_e("Bell",_S);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const vS=[["circle",{cx:"18.5",cy:"17.5",r:"3.5",key:"15x4ox"}],["circle",{cx:"5.5",cy:"17.5",r:"3.5",key:"1noe27"}],["circle",{cx:"15",cy:"5",r:"1",key:"19l28e"}],["path",{d:"M12 17.5V14l-3-3 4-3 2 3h2",key:"1npguv"}]],xS=_e("Bike",vS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const yS=[["path",{d:"M15 13a3 3 0 1 0-6 0",key:"10j68g"}],["path",{d:"M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20",key:"k3hazp"}],["circle",{cx:"12",cy:"8",r:"2",key:"1822b1"}]],il=_e("BookUser",yS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const SS=[["path",{d:"M12 8V4H8",key:"hb8ula"}],["rect",{width:"16",height:"12",x:"4",y:"8",rx:"2",key:"enze0r"}],["path",{d:"M2 14h2",key:"vft8re"}],["path",{d:"M20 14h2",key:"4cs60a"}],["path",{d:"M15 13v2",key:"1xurst"}],["path",{d:"M9 13v2",key:"rq6x2g"}]],MS=_e("Bot",SS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const ES=[["path",{d:"M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16",key:"jecpp"}],["rect",{width:"20",height:"14",x:"2",y:"6",rx:"2",key:"i6l2r4"}]],wS=_e("Briefcase",ES);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const TS=[["path",{d:"M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z",key:"1b4qmf"}],["path",{d:"M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2",key:"i71pzd"}],["path",{d:"M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2",key:"10jefs"}],["path",{d:"M10 6h4",key:"1itunk"}],["path",{d:"M10 10h4",key:"tcdvrf"}],["path",{d:"M10 14h4",key:"kelpxr"}],["path",{d:"M10 18h4",key:"1ulq68"}]],bS=_e("Building2",TS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const AS=[["path",{d:"M8 2v4",key:"1cmpym"}],["path",{d:"M16 2v4",key:"4m81vk"}],["rect",{width:"18",height:"18",x:"3",y:"4",rx:"2",key:"1hopcy"}],["path",{d:"M3 10h18",key:"8toen8"}],["path",{d:"M8 14h.01",key:"6423bh"}],["path",{d:"M12 14h.01",key:"1etili"}],["path",{d:"M16 14h.01",key:"1gbofw"}],["path",{d:"M8 18h.01",key:"lrp35t"}],["path",{d:"M12 18h.01",key:"mhygvu"}],["path",{d:"M16 18h.01",key:"kzsmim"}]],CS=_e("CalendarDays",AS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const NS=[["path",{d:"M8 2v4",key:"1cmpym"}],["path",{d:"M16 2v4",key:"4m81vk"}],["rect",{width:"18",height:"18",x:"3",y:"4",rx:"2",key:"1hopcy"}],["path",{d:"M3 10h18",key:"8toen8"}]],RS=_e("Calendar",NS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const PS=[["path",{d:"M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z",key:"1tc9qg"}],["circle",{cx:"12",cy:"13",r:"3",key:"1vg3eu"}]],LS=_e("Camera",PS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const kS=[["path",{d:"m21 8-2 2-1.5-3.7A2 2 0 0 0 15.646 5H8.4a2 2 0 0 0-1.903 1.257L5 10 3 8",key:"1imjwt"}],["path",{d:"M7 14h.01",key:"1qa3f1"}],["path",{d:"M17 14h.01",key:"7oqj8z"}],["rect",{width:"18",height:"8",x:"3",y:"10",rx:"2",key:"a7itu8"}],["path",{d:"M5 18v2",key:"ppbyun"}],["path",{d:"M19 18v2",key:"gy7782"}]],DS=_e("CarFront",kS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const IS=[["path",{d:"M10 2h4",key:"n1abiw"}],["path",{d:"m21 8-2 2-1.5-3.7A2 2 0 0 0 15.646 5H8.4a2 2 0 0 0-1.903 1.257L5 10 3 8",key:"1imjwt"}],["path",{d:"M7 14h.01",key:"1qa3f1"}],["path",{d:"M17 14h.01",key:"7oqj8z"}],["rect",{width:"18",height:"8",x:"3",y:"10",rx:"2",key:"a7itu8"}],["path",{d:"M5 18v2",key:"ppbyun"}],["path",{d:"M19 18v2",key:"gy7782"}]],US=_e("CarTaxiFront",IS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const FS=[["path",{d:"M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2",key:"5owen"}],["circle",{cx:"7",cy:"17",r:"2",key:"u2ysq9"}],["path",{d:"M9 17h6",key:"r8uit2"}],["circle",{cx:"17",cy:"17",r:"2",key:"axvx0g"}]],OS=_e("Car",FS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const jS=[["path",{d:"M20 6 9 17l-5-5",key:"1gmf2c"}]],yv=_e("Check",jS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const zS=[["path",{d:"m9 18 6-6-6-6",key:"mthhwq"}]],BS=_e("ChevronRight",zS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const HS=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["circle",{cx:"12",cy:"10",r:"3",key:"ilqhr7"}],["path",{d:"M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662",key:"154egf"}]],VS=_e("CircleUser",HS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const GS=[["path",{d:"M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242",key:"1pljnt"}],["path",{d:"M16 17H7",key:"pygtm1"}],["path",{d:"M17 21H9",key:"1u2q02"}]],WS=_e("CloudFog",GS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const $S=[["path",{d:"M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 .5 8.973",key:"1cez44"}],["path",{d:"m13 12-3 5h4l-3 5",key:"1t22er"}]],XS=_e("CloudLightning",$S);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const qS=[["path",{d:"M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242",key:"1pljnt"}],["path",{d:"M16 14v6",key:"1j4efv"}],["path",{d:"M8 14v6",key:"17c4r9"}],["path",{d:"M12 16v6",key:"c8a4gj"}]],YS=_e("CloudRain",qS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const KS=[["path",{d:"M12 2v2",key:"tus03m"}],["path",{d:"m4.93 4.93 1.41 1.41",key:"149t6j"}],["path",{d:"M20 12h2",key:"1q8mjw"}],["path",{d:"m19.07 4.93-1.41 1.41",key:"1shlcs"}],["path",{d:"M15.947 12.65a4 4 0 0 0-5.925-4.128",key:"dpwdj0"}],["path",{d:"M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z",key:"s09mg5"}]],ZS=_e("CloudSun",KS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const QS=[["path",{d:"M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z",key:"p7xjir"}]],JS=_e("Cloud",QS);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const eM=[["path",{d:"M16 2v2",key:"scm5qe"}],["path",{d:"M7 22v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2",key:"1waht3"}],["path",{d:"M8 2v2",key:"pbkmx"}],["circle",{cx:"12",cy:"11",r:"3",key:"itu57m"}],["rect",{x:"3",y:"4",width:"18",height:"18",rx:"2",key:"12vinp"}]],tM=_e("Contact",eM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const nM=[["rect",{width:"14",height:"14",x:"8",y:"8",rx:"2",ry:"2",key:"17jyea"}],["path",{d:"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2",key:"zix9uf"}]],Sv=_e("Copy",nM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const iM=[["rect",{width:"16",height:"16",x:"4",y:"4",rx:"2",key:"14l7u7"}],["rect",{width:"6",height:"6",x:"9",y:"9",rx:"1",key:"5aljv4"}],["path",{d:"M15 2v2",key:"13l42r"}],["path",{d:"M15 20v2",key:"15mkzm"}],["path",{d:"M2 15h2",key:"1gxd5l"}],["path",{d:"M2 9h2",key:"1bbxkp"}],["path",{d:"M20 15h2",key:"19e6y8"}],["path",{d:"M20 9h2",key:"19tzq7"}],["path",{d:"M9 2v2",key:"165o2o"}],["path",{d:"M9 20v2",key:"i2bqo8"}]],vp=_e("Cpu",iM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const rM=[["rect",{width:"20",height:"14",x:"2",y:"5",rx:"2",key:"ynyp8z"}],["line",{x1:"2",x2:"22",y1:"10",y2:"10",key:"1b3vmo"}]],sM=_e("CreditCard",rM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const aM=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["line",{x1:"22",x2:"18",y1:"12",y2:"12",key:"l9bcsi"}],["line",{x1:"6",x2:"2",y1:"12",y2:"12",key:"13hhkx"}],["line",{x1:"12",x2:"12",y1:"6",y2:"2",key:"10w3f3"}],["line",{x1:"12",x2:"12",y1:"22",y2:"18",key:"15g9kq"}]],oM=_e("Crosshair",aM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const lM=[["path",{d:"M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z",key:"1vdc57"}],["path",{d:"M5 21h14",key:"11awu3"}]],cM=_e("Crown",lM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const uM=[["path",{d:"M10 5a2 2 0 0 0-1.344.519l-6.328 5.74a1 1 0 0 0 0 1.481l6.328 5.741A2 2 0 0 0 10 19h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z",key:"1yo7s0"}],["path",{d:"m12 9 6 6",key:"anjzzh"}],["path",{d:"m18 9-6 6",key:"1fp51s"}]],dM=_e("Delete",uM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const fM=[["circle",{cx:"12",cy:"12",r:"1",key:"41hilf"}],["circle",{cx:"19",cy:"12",r:"1",key:"1wjl8i"}],["circle",{cx:"5",cy:"12",r:"1",key:"1pcz8c"}]],hM=_e("Ellipsis",fM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const pM=[["path",{d:"M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4",key:"1nerag"}],["path",{d:"M14 13.12c0 2.38 0 6.38-1 8.88",key:"o46ks0"}],["path",{d:"M17.29 21.02c.12-.6.43-2.3.5-3.02",key:"ptglia"}],["path",{d:"M2 12a10 10 0 0 1 18-6",key:"ydlgp0"}],["path",{d:"M2 16h.01",key:"1gqxmh"}],["path",{d:"M21.8 16c.2-2 .131-5.354 0-6",key:"drycrb"}],["path",{d:"M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2",key:"1tidbn"}],["path",{d:"M8.65 22c.21-.66.45-1.32.57-2",key:"13wd9y"}],["path",{d:"M9 6.8a6 6 0 0 1 9 5.2v2",key:"1fr1j5"}]],mM=_e("Fingerprint",pM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const gM=[["path",{d:"M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z",key:"i9b6wo"}],["line",{x1:"4",x2:"4",y1:"22",y2:"15",key:"1cm3nv"}]],_M=_e("Flag",gM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const vM=[["path",{d:"M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z",key:"96xj49"}]],bu=_e("Flame",vM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const xM=[["line",{x1:"6",x2:"10",y1:"11",y2:"11",key:"1gktln"}],["line",{x1:"8",x2:"8",y1:"9",y2:"13",key:"qnk9ow"}],["line",{x1:"15",x2:"15.01",y1:"12",y2:"12",key:"krot7o"}],["line",{x1:"18",x2:"18.01",y1:"10",y2:"10",key:"1lcuu1"}],["path",{d:"M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z",key:"mfqc10"}]],yM=_e("Gamepad2",xM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const SM=[["path",{d:"m14.5 12.5-8 8a2.119 2.119 0 1 1-3-3l8-8",key:"15492f"}],["path",{d:"m16 16 6-6",key:"vzrcl6"}],["path",{d:"m8 8 6-6",key:"18bi4p"}],["path",{d:"m9 7 8 8",key:"5jnvq1"}],["path",{d:"m21 11-8-8",key:"z4y7zo"}]],MM=_e("Gavel",SM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const EM=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["path",{d:"M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20",key:"13o1zl"}],["path",{d:"M2 12h20",key:"9i4pu4"}]],wM=_e("Globe",EM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const TM=[["rect",{width:"18",height:"18",x:"3",y:"3",rx:"2",key:"afitv7"}],["path",{d:"M3 9h18",key:"1pudct"}],["path",{d:"M3 15h18",key:"5xshup"}],["path",{d:"M9 3v18",key:"fh3hqa"}],["path",{d:"M15 3v18",key:"14nvp0"}]],Mv=_e("Grid3x3",TM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const bM=[["line",{x1:"4",x2:"20",y1:"9",y2:"9",key:"4lhtct"}],["line",{x1:"4",x2:"20",y1:"15",y2:"15",key:"vyu0kd"}],["line",{x1:"10",x2:"8",y1:"3",y2:"21",key:"1ggp8o"}],["line",{x1:"16",x2:"14",y1:"3",y2:"21",key:"weycgp"}]],rl=_e("Hash",bM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const AM=[["path",{d:"M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",key:"c3ymky"}],["path",{d:"M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27",key:"1uw2ng"}]],CM=_e("HeartPulse",AM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const NM=[["path",{d:"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8",key:"1357e3"}],["path",{d:"M3 3v5h5",key:"1xhq8a"}],["path",{d:"M12 7v5l4 2",key:"1fdv2h"}]],xp=_e("History",NM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const RM=[["path",{d:"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",key:"5wwlr5"}],["path",{d:"M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",key:"1d0kgt"}]],PM=_e("House",RM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const LM=[["circle",{cx:"12",cy:"12",r:"10",key:"1mglay"}],["path",{d:"M12 16v-4",key:"1dtifu"}],["path",{d:"M12 8h.01",key:"e9boi3"}]],yp=_e("Info",LM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const kM=[["line",{x1:"3",x2:"21",y1:"22",y2:"22",key:"j8o0r"}],["line",{x1:"6",x2:"6",y1:"18",y2:"11",key:"10tf0k"}],["line",{x1:"10",x2:"10",y1:"18",y2:"11",key:"54lgf6"}],["line",{x1:"14",x2:"14",y1:"18",y2:"11",key:"380y"}],["line",{x1:"18",x2:"18",y1:"18",y2:"11",key:"1kevvc"}],["polygon",{points:"12 2 20 7 4 7",key:"jkujk7"}]],DM=_e("Landmark",kM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const IM=[["path",{d:"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4",key:"1uf3rs"}],["polyline",{points:"16 17 21 12 16 7",key:"1gabdz"}],["line",{x1:"21",x2:"9",y1:"12",y2:"12",key:"1uyos4"}]],jg=_e("LogOut",IM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const UM=[["path",{d:"M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0",key:"1r0f0z"}],["circle",{cx:"12",cy:"10",r:"3",key:"ilqhr7"}]],Au=_e("MapPin",UM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const FM=[["path",{d:"M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z",key:"169xi5"}],["path",{d:"M15 5.764v15",key:"1pn4in"}],["path",{d:"M9 3.236v15",key:"1uimfh"}]],OM=_e("Map",FM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const jM=[["path",{d:"m3 11 18-5v12L3 14v-3z",key:"n962bs"}],["path",{d:"M11.6 16.8a3 3 0 1 1-5.8-1.6",key:"1yl0tm"}]],$s=_e("Megaphone",jM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const zM=[["path",{d:"M7.9 20A9 9 0 1 0 4 16.1L2 22Z",key:"vv11sd"}]],Cu=_e("MessageCircle",zM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const BM=[["path",{d:"M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",key:"1lielz"}],["path",{d:"M12 7v6",key:"lw1j43"}],["path",{d:"M9 10h6",key:"9gxzsh"}]],cu=_e("MessageSquarePlus",BM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const HM=[["path",{d:"M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",key:"1lielz"}]],Zi=_e("MessageSquare",HM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const VM=[["line",{x1:"2",x2:"22",y1:"2",y2:"22",key:"a6p6uj"}],["path",{d:"M18.89 13.23A7.12 7.12 0 0 0 19 12v-2",key:"80xlxr"}],["path",{d:"M5 10v2a7 7 0 0 0 12 5",key:"p2k8kg"}],["path",{d:"M15 9.34V5a3 3 0 0 0-5.68-1.33",key:"1gzdoj"}],["path",{d:"M9 9v3a3 3 0 0 0 5.12 2.12",key:"r2i35w"}],["line",{x1:"12",x2:"12",y1:"19",y2:"22",key:"x3vr5v"}]],vh=_e("MicOff",VM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const GM=[["path",{d:"M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z",key:"131961"}],["path",{d:"M19 10v2a7 7 0 0 1-14 0v-2",key:"1vc78b"}],["line",{x1:"12",x2:"12",y1:"19",y2:"22",key:"x3vr5v"}]],Ev=_e("Mic",GM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const WM=[["path",{d:"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z",key:"a7tn18"}]],$M=_e("Moon",WM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const XM=[["path",{d:"M9 18V5l12-2v13",key:"1jmyc2"}],["circle",{cx:"6",cy:"18",r:"3",key:"fqmcym"}],["circle",{cx:"18",cy:"16",r:"3",key:"1hluhg"}]],qM=_e("Music",XM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const YM=[["path",{d:"M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2",key:"7pis2x"}],["path",{d:"M18 14h-8",key:"sponae"}],["path",{d:"M15 18h-5",key:"95g1m2"}],["path",{d:"M10 6h8v4h-8V6Z",key:"smlsk5"}]],KM=_e("Newspaper",YM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const ZM=[["path",{d:"M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z",key:"1a0edw"}],["path",{d:"M12 22V12",key:"d0xqtd"}],["polyline",{points:"3.29 7 12 12 20.71 7",key:"ousv84"}],["path",{d:"m7.5 4.27 9 5.15",key:"1c824w"}]],QM=_e("Package",ZM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const JM=[["circle",{cx:"13.5",cy:"6.5",r:".5",fill:"currentColor",key:"1okk4w"}],["circle",{cx:"17.5",cy:"10.5",r:".5",fill:"currentColor",key:"f64h9f"}],["circle",{cx:"8.5",cy:"7.5",r:".5",fill:"currentColor",key:"fotxhn"}],["circle",{cx:"6.5",cy:"12.5",r:".5",fill:"currentColor",key:"qy21gx"}],["path",{d:"M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z",key:"12rzf8"}]],wv=_e("Palette",JM);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const e2=[["path",{d:"M12 20h9",key:"t2du7b"}],["path",{d:"M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z",key:"1ykcvy"}]],sl=_e("PenLine",e2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const t2=[["path",{d:"M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",key:"1a8usu"}],["path",{d:"m15 5 4 4",key:"1mk7zo"}]],Tv=_e("Pencil",t2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const n2=[["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}],["path",{d:"M14.05 2a9 9 0 0 1 8 7.94",key:"vmijpz"}],["path",{d:"M14.05 6A5 5 0 0 1 18 10",key:"13nbpp"}]],ol=_e("PhoneCall",n2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const i2=[["polyline",{points:"16 2 16 8 22 8",key:"1ygljm"}],["line",{x1:"22",x2:"16",y1:"2",y2:"8",key:"1xzwqn"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],r2=_e("PhoneIncoming",i2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const s2=[["line",{x1:"22",x2:"16",y1:"2",y2:"8",key:"1xzwqn"}],["line",{x1:"16",x2:"22",y1:"2",y2:"8",key:"13zxdn"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],Nu=_e("PhoneMissed",s2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const a2=[["path",{d:"M10.68 13.31a16 16 0 0 0 3.41 2.6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7 2 2 0 0 1 1.72 2v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.42 19.42 0 0 1-3.33-2.67m-2.67-3.34a19.79 19.79 0 0 1-3.07-8.63A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91",key:"z86iuo"}],["line",{x1:"22",x2:"2",y1:"2",y2:"22",key:"11kh81"}]],Ru=_e("PhoneOff",a2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const o2=[["polyline",{points:"22 8 22 2 16 2",key:"1g204g"}],["line",{x1:"16",x2:"22",y1:"8",y2:"2",key:"1ggias"}],["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],l2=_e("PhoneOutgoing",o2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const c2=[["path",{d:"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z",key:"foiqr5"}]],Ji=_e("Phone",c2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const u2=[["path",{d:"m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z",key:"wa1lgi"}],["path",{d:"m8.5 8.5 7 7",key:"rvfmvr"}]],d2=_e("Pill",u2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const f2=[["polygon",{points:"6 3 20 12 6 21 6 3",key:"1oa8hb"}]],h2=_e("Play",f2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const p2=[["path",{d:"M5 12h14",key:"1ays0h"}],["path",{d:"M12 5v14",key:"s699le"}]],m2=_e("Plus",p2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const g2=[["path",{d:"M12 2v10",key:"mnfbl"}],["path",{d:"M18.4 6.6a9 9 0 1 1-12.77.04",key:"obofu9"}]],_2=_e("Power",g2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const v2=[["path",{d:"M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z",key:"rib7q0"}],["path",{d:"M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z",key:"1ymkrd"}]],Sp=_e("Quote",v2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const x2=[["path",{d:"M4.9 19.1C1 15.2 1 8.8 4.9 4.9",key:"1vaf9d"}],["path",{d:"M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5",key:"u1ii0m"}],["circle",{cx:"12",cy:"12",r:"2",key:"1c9p78"}],["path",{d:"M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5",key:"1j5fej"}],["path",{d:"M19.1 4.9C23 8.8 23 15.1 19.1 19",key:"10b0cb"}]],Pu=_e("Radio",x2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const y2=[["path",{d:"M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8",key:"v9h5vc"}],["path",{d:"M21 3v5h-5",key:"1q7to0"}],["path",{d:"M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16",key:"3uifl3"}],["path",{d:"M8 16H3v5",key:"1cv678"}]],bv=_e("RefreshCw",y2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const S2=[["path",{d:"m2 9 3-3 3 3",key:"1ltn5i"}],["path",{d:"M13 18H7a2 2 0 0 1-2-2V6",key:"1r6tfw"}],["path",{d:"m22 15-3 3-3-3",key:"4rnwn2"}],["path",{d:"M11 6h6a2 2 0 0 1 2 2v10",key:"2f72bc"}]],Mp=_e("Repeat2",S2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const M2=[["path",{d:"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8",key:"1p45f6"}],["path",{d:"M21 3v5h-5",key:"1q7to0"}]],E2=_e("RotateCw",M2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const w2=[["path",{d:"M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z",key:"1c8476"}],["path",{d:"M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7",key:"1ydtos"}],["path",{d:"M7 3v4a1 1 0 0 0 1 1h7",key:"t51u73"}]],Av=_e("Save",w2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const T2=[["circle",{cx:"11",cy:"11",r:"8",key:"4ej97u"}],["path",{d:"m21 21-4.3-4.3",key:"1qie3q"}]],cs=_e("Search",T2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const b2=[["path",{d:"M3.714 3.048a.498.498 0 0 0-.683.627l2.843 7.627a2 2 0 0 1 0 1.396l-2.842 7.627a.498.498 0 0 0 .682.627l18-8.5a.5.5 0 0 0 0-.904z",key:"117uat"}],["path",{d:"M6 12h16",key:"s4cdu5"}]],A2=_e("SendHorizontal",b2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const C2=[["path",{d:"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z",key:"1qme2f"}],["circle",{cx:"12",cy:"12",r:"3",key:"1v7zrd"}]],Ep=_e("Settings",C2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const N2=[["path",{d:"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",key:"oel41y"}],["path",{d:"M12 8v4",key:"1got3b"}],["path",{d:"M12 16h.01",key:"1drbdi"}]],R2=_e("ShieldAlert",N2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const P2=[["path",{d:"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",key:"oel41y"}]],L2=_e("Shield",P2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const k2=[["path",{d:"M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z",key:"hou9p0"}],["path",{d:"M3 6h18",key:"d0wm0j"}],["path",{d:"M16 10a4 4 0 0 1-8 0",key:"1ltviw"}]],D2=_e("ShoppingBag",k2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const I2=[["circle",{cx:"8",cy:"21",r:"1",key:"jimo8o"}],["circle",{cx:"19",cy:"21",r:"1",key:"13723u"}],["path",{d:"M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12",key:"9zh506"}]],U2=_e("ShoppingCart",I2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const F2=[["path",{d:"M2 20h.01",key:"4haj6o"}],["path",{d:"M7 20v-4",key:"j294jx"}],["path",{d:"M12 20v-8",key:"i3yub9"}],["path",{d:"M17 20V8",key:"1tkaf5"}],["path",{d:"M22 4v16",key:"sih9yq"}]],O2=_e("Signal",F2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const j2=[["path",{d:"M7 18v-6a5 5 0 1 1 10 0v6",key:"pcx96s"}],["path",{d:"M5 21a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-1a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2z",key:"1b4s83"}],["path",{d:"M21 12h1",key:"jtio3y"}],["path",{d:"M18.5 4.5 18 5",key:"g5sp9y"}],["path",{d:"M2 12h1",key:"1uaihz"}],["path",{d:"M12 2v1",key:"11qlp1"}],["path",{d:"m4.929 4.929.707.707",key:"1i51kw"}],["path",{d:"M12 12v6",key:"3ahymv"}]],z2=_e("Siren",j2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const B2=[["path",{d:"m12.5 17-.5-1-.5 1h1z",key:"3me087"}],["path",{d:"M15 22a1 1 0 0 0 1-1v-1a2 2 0 0 0 1.56-3.25 8 8 0 1 0-11.12 0A2 2 0 0 0 8 20v1a1 1 0 0 0 1 1z",key:"1o5pge"}],["circle",{cx:"15",cy:"12",r:"1",key:"1tmaij"}],["circle",{cx:"9",cy:"12",r:"1",key:"1vctgf"}]],H2=_e("Skull",B2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const V2=[["path",{d:"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",key:"r04s7s"}]],Mr=_e("Star",V2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const G2=[["path",{d:"M11 2v2",key:"1539x4"}],["path",{d:"M5 2v2",key:"1yf1q8"}],["path",{d:"M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1",key:"rb5t3r"}],["path",{d:"M8 15a6 6 0 0 0 12 0v-3",key:"x18d4x"}],["circle",{cx:"20",cy:"10",r:"2",key:"ts1r5v"}]],W2=_e("Stethoscope",G2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const $2=[["circle",{cx:"12",cy:"12",r:"4",key:"4exip2"}],["path",{d:"M12 2v2",key:"tus03m"}],["path",{d:"M12 20v2",key:"1lh1kg"}],["path",{d:"m4.93 4.93 1.41 1.41",key:"149t6j"}],["path",{d:"m17.66 17.66 1.41 1.41",key:"ptbguv"}],["path",{d:"M2 12h2",key:"1t8f8n"}],["path",{d:"M20 12h2",key:"1q8mjw"}],["path",{d:"m6.34 17.66-1.41 1.41",key:"1m8zz5"}],["path",{d:"m19.07 4.93-1.41 1.41",key:"1shlcs"}]],X2=_e("Sun",$2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const q2=[["path",{d:"M3 6h18",key:"d0wm0j"}],["path",{d:"M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6",key:"4alrt4"}],["path",{d:"M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",key:"v07s0e"}],["line",{x1:"10",x2:"10",y1:"11",y2:"17",key:"1uufr5"}],["line",{x1:"14",x2:"14",y1:"11",y2:"17",key:"xtxkd"}]],uu=_e("Trash2",q2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const Y2=[["path",{d:"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3",key:"wmoenq"}],["path",{d:"M12 9v4",key:"juzpu7"}],["path",{d:"M12 17h.01",key:"p32p05"}]],wp=_e("TriangleAlert",Y2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const K2=[["path",{d:"M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2",key:"wrbu53"}],["path",{d:"M15 18H9",key:"1lyqi6"}],["path",{d:"M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14",key:"lysw3i"}],["circle",{cx:"17",cy:"18",r:"2",key:"332jqn"}],["circle",{cx:"7",cy:"18",r:"2",key:"19iecd"}]],Z2=_e("Truck",K2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const Q2=[["polyline",{points:"4 7 4 4 20 4 20 7",key:"1nosan"}],["line",{x1:"9",x2:"15",y1:"20",y2:"20",key:"swin9y"}],["line",{x1:"12",x2:"12",y1:"4",y2:"20",key:"1tx1rr"}]],J2=_e("Type",Q2);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const eE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["polyline",{points:"16 11 18 13 22 9",key:"1pwet4"}]],tE=_e("UserCheck",eE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const nE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"22",x2:"16",y1:"11",y2:"11",key:"1shjgl"}]],iE=_e("UserMinus",nE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const rE=[["path",{d:"M11.5 15H7a4 4 0 0 0-4 4v2",key:"15lzij"}],["path",{d:"M21.378 16.626a1 1 0 0 0-3.004-3.004l-4.01 4.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z",key:"1817ys"}],["circle",{cx:"10",cy:"7",r:"4",key:"e45bow"}]],Tp=_e("UserPen",rE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const sE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"19",x2:"19",y1:"8",y2:"14",key:"1bvyxn"}],["line",{x1:"22",x2:"16",y1:"11",y2:"11",key:"1shjgl"}]],Qi=_e("UserPlus",sE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const aE=[["circle",{cx:"12",cy:"8",r:"5",key:"1hypcn"}],["path",{d:"M20 21a8 8 0 0 0-16 0",key:"rfgkzh"}]],no=_e("UserRound",aE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const oE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["line",{x1:"17",x2:"22",y1:"8",y2:"13",key:"3nzzx3"}],["line",{x1:"22",x2:"17",y1:"8",y2:"13",key:"1swrse"}]],lE=_e("UserX",oE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const cE=[["path",{d:"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",key:"1yyitq"}],["circle",{cx:"9",cy:"7",r:"4",key:"nufk8"}],["path",{d:"M22 21v-2a4 4 0 0 0-3-3.87",key:"kshegd"}],["path",{d:"M16 3.13a4 4 0 0 1 0 7.75",key:"1da9ce"}]],kn=_e("Users",cE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const uE=[["path",{d:"M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2",key:"cjf0a3"}],["path",{d:"M7 2v20",key:"1473qp"}],["path",{d:"M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7",key:"j28e5"}]],dE=_e("Utensils",uE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const fE=[["path",{d:"M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z",key:"uqj9uw"}],["path",{d:"M16 9a5 5 0 0 1 0 6",key:"1q6k2b"}],["path",{d:"M19.364 18.364a9 9 0 0 0 0-12.728",key:"ijwkga"}]],Cv=_e("Volume2",fE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const hE=[["path",{d:"M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1",key:"18etb6"}],["path",{d:"M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4",key:"xoc0q4"}]],pE=_e("Wallet",hE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const mE=[["path",{d:"M12.8 19.6A2 2 0 1 0 14 16H2",key:"148xed"}],["path",{d:"M17.5 8a2.5 2.5 0 1 1 2 4H2",key:"1u4tom"}],["path",{d:"M9.8 4.4A2 2 0 1 1 11 8H2",key:"75valh"}]],gE=_e("Wind",mE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const _E=[["path",{d:"M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z",key:"cbrjhi"}]],vE=_e("Wrench",_E);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const xE=[["path",{d:"M18 6 6 18",key:"1bl5f8"}],["path",{d:"m6 6 12 12",key:"d8bk6v"}]],ll=_e("X",xE);/**
 * @license lucide-react v0.475.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const yE=[["path",{d:"M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z",key:"1xq2db"}]],bp=_e("Zap",yE);function Nv({weather:n,size:e=22}){const t=(n??"").toLowerCase(),r={size:e,strokeWidth:1.9};return/storm|thunder|lightning/.test(t)?l.jsx(XS,{...r}):/rain|drizzle|shower/.test(t)?l.jsx(YS,{...r}):/fog|mist|haze|smog|pollution/.test(t)?l.jsx(WS,{...r}):/sand|dust|wind/.test(t)?l.jsx(gE,{...r}):/overcast|cloud/.test(t)?/partly|few/.test(t)?l.jsx(ZS,{...r}):l.jsx(JS,{...r}):/night|moon/.test(t)?l.jsx($M,{...r}):l.jsx(X2,{...r})}function du({children:n,cut:e=16,depth:t=5,tone:r="holo",className:a,faceClassName:c,style:u}){const d=q.useRef(null),h=q.useRef(0),p=y=>{const v=d.current;if(!v)return;const{clientX:x,clientY:w}=y;h.current||(h.current=requestAnimationFrame(()=>{h.current=0;const E=v.getBoundingClientRect(),_=Math.max(-1,Math.min(1,(x-E.left)/E.width*2-1)),M=Math.max(-1,Math.min(1,(w-E.top)/E.height*2-1));v.style.setProperty("--lx",_.toFixed(3)),v.style.setProperty("--ly",M.toFixed(3)),v.style.setProperty("--gx",`${((_+1)*50).toFixed(1)}%`),v.style.setProperty("--gy",`${((M+1)*50).toFixed(1)}%`)}))},g=()=>{const y=d.current;y&&(y.style.setProperty("--lx","0"),y.style.setProperty("--ly","0"),y.classList.remove("is-hover"))};return l.jsxs("div",{ref:d,className:["nl3d",`nl3d--${r}`,a].filter(Boolean).join(" "),style:{...u,"--nl-c":`${e}px`},onPointerMove:p,onPointerEnter:()=>d.current?.classList.add("is-hover"),onPointerLeave:g,children:[l.jsx("div",{className:"nl3d__bloom","aria-hidden":!0}),l.jsx("div",{className:"nl3d__depth","aria-hidden":!0,children:Array.from({length:t},(y,v)=>l.jsx("i",{style:{"--k":v+1,"--n":t}},v))}),l.jsx("div",{className:["nl3d__face",c].filter(Boolean).join(" "),children:n}),l.jsx("div",{className:"nl3d__glint","aria-hidden":!0}),l.jsx("div",{className:"nl3d__halo","aria-hidden":!0}),l.jsxs("div",{className:"nl3d__corners","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})]})}const zg={AppWindow:vv,Banknote:pS,Bike:xS,Bot:MS,Briefcase:wS,Building2:bS,Calendar:RS,Camera:LS,Car:OS,CarFront:DS,CarTaxiFront:US,Cpu:vp,CreditCard:sM,Crosshair:oM,Gamepad2:yM,Gavel:MM,Globe:wM,HeartPulse:CM,Home:PM,Landmark:DM,Map:OM,MapPin:Au,Music:qM,Newspaper:KM,Package:QM,Pill:d2,Radio:Pu,Shield:L2,ShieldAlert:R2,ShoppingBag:D2,ShoppingCart:U2,Siren:z2,Skull:H2,Star:Mr,Stethoscope:W2,Truck:Z2,Utensils:dE,Wallet:pE,Wrench:vE,Zap:bp};function SE(n){return n.trim().split(/[-_\s]+/).filter(Boolean).map(e=>e[0].toUpperCase()+e.slice(1)).join("")}let fu=null,Bg=null;function ME(){return Bg??=dp(()=>import("./chunk-lucideAll.js"),[],import.meta.url).then(n=>fu=n.icons).catch(()=>fu={}),Bg}function EE({name:n,size:e=30,strokeWidth:t=1.9}){const r=SE(n||"app-window"),[,a]=q.useState(0),c=zg[r]??fu?.[r];q.useEffect(()=>{!zg[r]&&!fu&&ME().then(()=>a(d=>d+1))},[r]);const u=c??vv;return l.jsx(u,{size:e,strokeWidth:t})}const Kr=30,en=18;function Lu(n){return(n?.threads??[]).reduce((e,t)=>e+(t.unread>0?t.unread:0),0)}function ku(n,e){return(n?.recents??[]).filter(t=>t.direction==="in"&&t.status==="missed"&&t.at>e).length}function Rv(n,e,t){const r=[];t&&r.push({id:"call",label:"Call",icon:l.jsx(ol,{size:Kr,strokeWidth:1.9})}),r.push({id:"status",label:"Status",icon:l.jsx(no,{size:Kr,strokeWidth:1.9})},{id:"phone",label:"Phone",icon:l.jsx(Ji,{size:Kr,strokeWidth:1.9}),badge:e},{id:"messages",label:"Messages",icon:l.jsx(Zi,{size:Kr,strokeWidth:1.9}),badge:Lu(n)},{id:"contacts",label:"Contacts",icon:l.jsx(il,{size:Kr,strokeWidth:1.9})},{id:"social",label:"Screamsheet",icon:l.jsx($s,{size:Kr,strokeWidth:1.9}),badge:n?.social?.unread??0},{id:"settings",label:"Settings",icon:l.jsx(Ep,{size:Kr,strokeWidth:1.9})});for(const a of n?.apps??[])r.push({id:`app:${a.id}`,label:a.label,icon:l.jsx(EE,{name:a.icon,size:Kr}),color:a.color,appId:a.id});return r}function Pv(n,e,t){switch(n){case"status":return[{id:"identity",label:"Identity",hint:e?.line?.number??"No line",icon:l.jsx(tM,{size:en}),view:{app:"status"}}];case"phone":return[{id:"dial",label:"Keypad",hint:"Dial a number",icon:l.jsx(Mv,{size:en}),view:{app:"phone",tab:"dial"}},{id:"recents",label:"Recents",hint:`${e?.recents.length??0} calls`,icon:l.jsx(xp,{size:en}),badge:t,view:{app:"phone",tab:"recents"}},{id:"favorites",label:"Favorites",hint:`${e?.contacts.filter(r=>r.favorite).length??0} linked`,icon:l.jsx(Mr,{size:en}),view:{app:"phone",tab:"favorites"}}];case"messages":return[{id:"inbox",label:"Inbox",hint:`${e?.threads.length??0} threads`,icon:l.jsx(Zi,{size:en}),badge:Lu(e),view:{app:"messages",screen:"list"}},{id:"new",label:"New message",hint:"Number or contact",icon:l.jsx(cu,{size:en}),view:{app:"messages",screen:"new"}},{id:"group",label:"New group",hint:"2 to 15 members",icon:l.jsx(kn,{size:en}),view:{app:"messages",screen:"group-new"}}];case"contacts":return[{id:"all",label:"All contacts",hint:`${e?.contacts.length??0} saved`,icon:l.jsx(il,{size:en}),view:{app:"contacts",screen:"list",filter:"all"}},{id:"fav",label:"Favorites",hint:`${e?.contacts.filter(r=>r.favorite).length??0} starred`,icon:l.jsx(Mr,{size:en}),view:{app:"contacts",screen:"list",filter:"favorites"}},{id:"add",label:"Add contact",hint:"Name and number",icon:l.jsx(Qi,{size:en}),view:{app:"contacts",screen:"edit"}}];case"social":{const r=e?.social?.unread??0,a=e?.social?.handle??"";return[{id:"pulse",label:"Pulse",hint:"Everyone, live",icon:l.jsx(Pu,{size:en}),view:{app:"social",screen:"feed",mode:"pulse"}},{id:"crew",label:"Crew",hint:"People you follow",icon:l.jsx(kn,{size:en}),view:{app:"social",screen:"feed",mode:"crew"}},{id:"hot",label:"Hot",hint:"Best of the last 24 h",icon:l.jsx(bu,{size:en}),view:{app:"social",screen:"feed",mode:"hot"}},{id:"compose",label:"Compose",hint:"Scream to the city",icon:l.jsx(sl,{size:en}),view:{app:"social",screen:"compose"}},{id:"pings",label:"Pings",hint:r?`${r} new`:"Cred, echoes, replies",icon:l.jsx(_h,{size:en}),badge:r,view:{app:"social",screen:"pings"}},{id:"heat",label:"Net Heat",hint:"Trending tags and districts",icon:l.jsx(lu,{size:en}),view:{app:"social",screen:"heat"}},{id:"me",label:"My profile",hint:a?`@${a}`:"Your screams",icon:l.jsx(VS,{size:en}),view:{app:"social",screen:"profile",handle:a}}]}case"settings":return[{id:"sound",label:"Sound",hint:"Ringtone, volume, DND",icon:l.jsx(Cv,{size:en}),view:{app:"settings",section:"sound"}},{id:"display",label:"Hologram",hint:"Accent, intensity",icon:l.jsx(wv,{size:en}),view:{app:"settings",section:"display"}},{id:"about",label:"System",hint:"Neural-Link OS",icon:l.jsx(vp,{size:en}),view:{app:"settings",section:"about"}}];default:return[]}}const wE={status:{title:"Status",icon:l.jsx(no,{size:22})},phone:{title:"Phone",icon:l.jsx(Ji,{size:22})},messages:{title:"Messages",icon:l.jsx(Zi,{size:22})},contacts:{title:"Contacts",icon:l.jsx(il,{size:22})},social:{title:"Screamsheet",icon:l.jsx($s,{size:22})},settings:{title:"Settings",icon:l.jsx(Ep,{size:22})},about:{title:"About",icon:l.jsx(yp,{size:22})}};function Hg(n,e){return!e||e.app!==n.view.app?!1:e.app==="phone"&&n.view.app==="phone"?e.tab===n.view.tab:e.app==="settings"&&n.view.app==="settings"?e.section===n.view.section:e.app==="contacts"&&n.view.app==="contacts"?n.view.screen==="edit"?e.screen==="edit"&&e.id==null:e.screen==="list"&&e.filter===n.view.filter:e.app==="messages"&&n.view.app==="messages"?e.screen===n.view.screen:e.app==="social"&&n.view.app==="social"?e.screen==="feed"&&n.view.screen==="feed"?e.mode===n.view.mode:e.screen==="profile"&&n.view.screen==="profile"?e.handle===n.view.handle:e.screen==="compose"?n.view.screen==="compose"&&e.replyTo==null&&e.quoteOf==null:e.screen===n.view.screen:e.app===n.view.app}function Lv(){const[n,e]=q.useState(97.4);return q.useEffect(()=>{const t=window.setInterval(()=>e(r=>Math.max(94,Math.min(99.9,r+(Math.random()-.5)*1.2))),2400);return()=>window.clearInterval(t)},[]),n}function TE(){const n=fe(g=>g.state?.line??null),e=fe(g=>g.clock),t=fe(g=>g.state),r=fe(g=>g.recentsSeenAt),a=Lv(),[c,u]=q.useState(!1),d=Lu(t),h=ku(t,r),p=async()=>{if(!n)return;const g=await cv(n.number);Ee(g?"select":"error"),u(g),window.setTimeout(()=>u(!1),1400)};return l.jsx("div",{className:"tilt tilt--card",children:l.jsx(du,{cut:16,depth:6,children:l.jsxs("aside",{className:"card nl-hit",children:[l.jsxs("div",{className:"card__top",children:[l.jsx("span",{className:"card__brand mono",children:"NEURAL-LINK"}),l.jsx("span",{className:"card__fw mono",children:"OS 2.7.7"})]}),l.jsx("div",{className:"card__name",children:n?.name??"Unlinked"}),l.jsxs("button",{type:"button",className:"card__num",onClick:p,disabled:!n,title:"Copy number",children:[l.jsx("span",{className:"mono",children:n?.number??"---- ----"}),l.jsx(Sv,{size:14,strokeWidth:2.4}),l.jsx("span",{className:`card__copied ${c?"is-on":""}`,children:"Copied"})]}),l.jsxs("div",{className:"card__bar",children:[l.jsx("span",{className:"card__bar-label label",children:"Sync"}),l.jsxs("span",{className:"card__bar-track",children:[l.jsx("span",{className:"card__bar-fill",style:{transform:`scaleX(${n?a/100:.08})`}}),l.jsx("span",{className:"card__bar-seg","aria-hidden":!0})]}),l.jsx("span",{className:"card__bar-val mono",children:n?`${a.toFixed(1)}%`:"0%"})]}),l.jsxs("div",{className:"card__row",children:[l.jsxs("div",{className:"card__time",children:[l.jsx("span",{className:"mono card__clock",children:e?`${Sr(e.hours)}:${Sr(e.minutes)}`:"--:--"}),l.jsx("span",{className:"card__city label",children:"Night City"})]}),l.jsxs("div",{className:"card__weather",children:[l.jsx(Nv,{weather:e?.weather,size:26}),l.jsx("span",{children:e?.weather??"No data"})]})]}),l.jsxs("div",{className:"card__foot",children:[l.jsx("span",{className:`card__signal ${n?"":"is-off"}`,"aria-label":"link quality",children:[0,1,2,3,4].map(g=>l.jsx("i",{style:{"--i":g}},g))}),l.jsxs("span",{className:"card__stat",title:"Unread messages",children:[l.jsx(Zi,{size:15})," ",l.jsx("b",{className:"mono",children:d})]}),l.jsxs("span",{className:`card__stat ${h?"is-alert":""}`,title:"Missed calls",children:[l.jsx(Nu,{size:15})," ",l.jsx("b",{className:"mono",children:h})]})]})]})})})}function Vg({icon:n,label:e,selected:t,cursor:r,badge:a,tone:c="glass",size:u,pulse:d,disabled:h,labelSide:p="left",className:g,style:y,color:v,onClick:x,dataCol:w}){const E={...y};return u&&(E["--size"]=`${u}px`),v&&(E["--app-color"]=v),l.jsxs("button",{type:"button",className:["rb",`rb--${c}`,t&&"is-selected",r&&"is-cursor",d&&"is-pulse",v&&"has-color",g].filter(Boolean).join(" "),style:E,disabled:h,"aria-label":e,"aria-pressed":t,"data-col":w,onClick:x,children:[l.jsx("span",{className:"rb__ring","aria-hidden":!0,children:l.jsx("svg",{viewBox:"0 0 100 100",children:l.jsx("circle",{cx:"50",cy:"50",r:"47"})})}),l.jsxs("span",{className:"rb__rim","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"rb__disc",children:l.jsx("span",{className:"rb__icon",children:n})}),a!=null&&a!==0&&a!==""&&l.jsx("span",{className:"rb__badge mono",children:typeof a=="number"&&a>99?"99+":a}),e&&p!=="none"&&l.jsx("span",{className:`rb__label rb__label--${p} label`,children:e})]})}const Af={unknown_number:"No neural line answers to that number.",unavailable:"Line unreachable. They are offline.",busy:"Line busy. Try again later.",in_call:"You are already in a call.",not_member:"You are not a member of this group.",not_owner:"Only the group owner can do that.",group_full:"This group is full.",invalid_body:"Messages must be 1 to 500 characters.",invalid_name:"That name is not valid.",invalid_number:"Numbers look like 555-0123.",rate_limited:"Too fast. Wait a moment.",no_line:"No neural line assigned yet.",database_unavailable:"Neural network storage is offline. Try again soon.",self:"You cannot do that with your own number.",handle_taken:"That handle is already taken.",invalid_handle:"Handles are 3 to 16 lowercase letters, digits or underscores.",unknown_handle:"No citizen answers to that handle.",unknown_post:"That scream is gone.",not_author:"Only the author can do that.",not_installed:"No Neural-Link implant detected.",ripperdoc_required:"Visit a ripperdoc to have a Neural-Link installed.",timeout:"The link timed out. Try again.",unknown:"Something went wrong on the link."};function Fn(n){return n?Af[n]??Af.unknown:Af.unknown}const bE={hangup:"Call ended",declined:"Call declined",busy:"Line busy",unavailable:"Unreachable",missed:"Missed call",no_answer:"No answer",dropped:"Link dropped"};function AE(n){return bE[n]??"Call ended"}let kv=1;function io(n){Ee("error"),be().pushToast({id:`local-err-${kv++}`,kind:"error",title:"Neural-Link",body:Fn(n),at:Date.now()})}function CE(n,e){be().pushToast({id:`local-info-${kv++}`,kind:"info",title:n,body:e,at:Date.now()})}async function Pt(n,e,t={}){try{return await to(n,e)}catch(r){const a=r instanceof Sn?r.slug:"unknown";t.quiet||io(a);return}}async function Hs(n,e){try{return await to(n,e)}catch(t){throw t instanceof Sn?t:new Sn("unknown")}}function Vs(){const n=be();n.phase==="closed"||n.phase==="closing"||(document.activeElement?.blur?.(),Ee("close"),n.closeUi(),Tu("nl:close",{}))}function Oa(){be().back()?Ee("back"):Vs()}function Mn(n,e="push"){const t=be();e==="reset"?t.resetView(n):t.pushView(n),Ee("select")}function $a(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"messages",screen:"list"}),be().pushView({app:"messages",screen:"thread",threadId:n}),Ee("select"),hu(n)}function hu(n){const e=be();e.threadLoading(n,!1),e.setUnread(n,0),Pt("threads.open",{threadId:n}).then(t=>{if(t===void 0){const r=be().threadCache[n];r?.loading&&be().threadLoaded({threadId:n,messages:r.messages,members:r.members,hasMore:!1})}})}function NE(n){const e=be(),t=e.threadCache[n];if(!t||!t.hasMore||t.loadingMore||t.loading)return;const r=t.messages[0];r&&(e.threadLoading(n,!0),Pt("threads.more",{threadId:n,beforeId:r.id},{quiet:!0}).then(a=>{if(a===void 0){const c=be().threadCache[n];c&&be().threadLoaded({threadId:n,messages:[],members:c.members,hasMore:c.hasMore,prepend:!0})}}))}async function RE(n){const e=await Pt("threads.direct",{number:n});e&&$a(e.threadId,"reset")}let PE=-1;async function Dv(n,e){const t=be(),r=PE--;t.addPending({tempId:r,threadId:n,body:e,at:Date.now(),failed:!1}),Ee("send");try{const a=await to("messages.send",{threadId:n,body:e});return be().pendingSent(r,a.id),!0}catch(a){return be().pendingFailed(r),io(a instanceof Sn?a.slug:"unknown"),!1}}function LE(n){const e=be().pending.find(t=>t.tempId===n);e&&(be().dropPending(n),Dv(e.threadId,e.body))}async function Er(n){return be().state?.call?(io("in_call"),!1):(Ee("select"),await Pt("call.dial",{number:n})!==void 0)}async function Iv(n){return be().state?.call?(io("in_call"),!1):(Ee("select"),await Pt("call.group",{threadId:n})!==void 0)}let Gg,Qo={};function Gs(n,e=450){be().setSettingsDraft(n),Qo={...Qo,...n},window.clearTimeout(Gg),Gg=window.setTimeout(kE,e)}async function kE(){const n=Qo;if(Qo={},Object.keys(n).length===0)return;const e=await Pt("settings.save",n),t=be(),r={...t.settingsDraft};for(const a of Object.keys(n))a in Qo||delete r[a];e&&t.state&&t.applyPatch({settings:e}),be().replaceSettingsDraft(r)}const DE=n=>`#${n}`,Ap=n=>`@${n}`;function cl(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"social",screen:"feed",mode:"pulse"}),be().pushView({app:"social",screen:"thread",postId:n}),Ee("select")}function ss(n,e="push"){const t=be();e==="reset"&&t.resetView({app:"social",screen:"feed",mode:"pulse"}),be().pushView({app:"social",screen:"profile",handle:n}),Ee("select")}function Uv(n){Mn({app:"social",screen:"tag",tag:n.replace(/^#/,"").toLowerCase()})}function Fv(n,e){be().rememberPost(n),Mn(e==="reply"?{app:"social",screen:"compose",replyTo:n.id}:{app:"social",screen:"compose",quoteOf:n.id})}async function Jo(n,e=!1){const t=be(),r=t.feeds[n];if(e&&(!r||!r.hasMore||r.loading||r.loadingMore))return;const a=e?r?.posts[r.posts.length-1]?.id:void 0;t.feedLoading(n,e);let c;if(n.startsWith("#"))c=await Pt("social.tag",{tag:n.slice(1),beforeId:a},{quiet:e});else if(n.startsWith("@")){const u=await Pt("social.profile",{handle:n.slice(1),beforeId:a},{quiet:!0});u&&be().setProfile(u.profile),c=u}else c=await Pt("social.feed",{mode:n,beforeId:a},{quiet:e});c?be().feedLoaded(n,c.posts??[],!!c.hasMore,e):be().feedFailed(n)}function Wg(n,e=!1){return Jo(Ap(n),e)}async function Ov(n){be().screamThreadLoading(n);const e=await Pt("social.thread",{postId:n},{quiet:!0});be().screamThreadLoaded(n,e?{post:e.post,parents:e.parents??[],replies:e.replies??[]}:null)}let Cf=null;function xh(n=!1){return n?$g(!0):(Cf??=$g(!1).finally(()=>{Cf=null}),Cf)}async function $g(n){const e=be(),t=e.pings;if(n&&(!t||!t.hasMore||t.loading||t.loadingMore))return;const r=n?t?.pings[t.pings.length-1]?.id:void 0;e.pingsLoading(n);const a=await Pt("social.pings",{beforeId:r},{quiet:n});a&&!n&&be().setSocialUnread(0),be().pingsLoaded(a?.pings??t?.pings??[],a?!!a.hasMore:!1,n&&!!a)}const za=new Set;async function IE(n){const e=`cred:${n.id}`;if(za.has(e))return;za.add(e);const t={credded:n.credded,cred:n.cred},r=!n.credded;be().setPostLive(n.id,{credded:r,cred:Math.max(0,n.cred+(r?1:-1))}),Ee(r?"select":"back");try{const a=await to("social.cred",{postId:n.id});be().setPostLive(n.id,{credded:a.credded,cred:a.cred})}catch(a){be().setPostLive(n.id,t),io(a instanceof Sn?a.slug:"unknown")}finally{za.delete(e)}}async function UE(n){const e=`echo:${n.id}`;if(za.has(e))return;za.add(e);const t={echoed:n.echoed,echoes:n.echoes},r=!n.echoed;be().setPostLive(n.id,{echoed:r,echoes:Math.max(0,n.echoes+(r?1:-1))}),Ee(r?"select":"back");try{const a=await to("social.echo",{postId:n.id,district:be().clock?.district});be().setPostLive(n.id,{echoed:a.echoed,echoes:a.echoes})}catch(a){be().setPostLive(n.id,t),io(a instanceof Sn?a.slug:"unknown")}finally{za.delete(e)}}async function FE(n,e={}){const t=await Pt("social.post",{body:n,replyTo:e.replyTo,quoteOf:e.quoteOf,district:be().clock?.district});if(!t?.post)return null;Ee("send");const r=be();if(e.replyTo!=null)r.addReply(e.replyTo,t.post);else{r.prependPosts("pulse",[t.post]),r.prependPosts("crew",[t.post]);const a=r.state?.social?.handle;a&&r.prependPosts(Ap(a),[t.post])}return t.post}async function OE(n){if(await Pt("social.delete",{postId:n})===void 0)return;Ee("back");const e=be();e.removePost(n);const t=e.stack[e.stack.length-1];t?.app==="social"&&t.screen==="thread"&&t.postId===n&&e.back()}async function jE(n,e){await Pt("social.report",{postId:n,reason:e})!==void 0&&(Ee("select"),CE("Screamsheet","Report filed. The sysops will take a look."))}async function Xg(n,e){const t=await Pt("social.follow",{handle:n,follow:e});if(!t)return;Ee(t.followed?"select":"back");const r=be(),a=r.profiles[n];a&&r.setProfile({...a,followed:t.followed,followers:t.followers}),r.feeds.crew&&Jo("crew")}function Cp(n){return!n||n.dataset?.nlIgnore?!1:n instanceof HTMLTextAreaElement?!n.readOnly:n instanceof HTMLInputElement?["text","search","tel","number","email","url","password",""].includes(n.type)&&!n.readOnly:n.isContentEditable===!0}let qg=!1,Yg;function zE(){window.clearTimeout(Yg),Yg=window.setTimeout(()=>{const n=Cp(document.activeElement);n!==qg&&(qg=n,Tu("nl:typing",{active:n}))},0)}function Kg(){const n=document.activeElement;Cp(n)&&n.blur()}const el=[];function ds(n,e=!0){q.useEffect(()=>{if(e)return el.push(n),()=>{const t=el.lastIndexOf(n);t>=0&&el.splice(t,1)}},[n,e])}function BE(n){be().resetView(n),Ee("select")}function HE(n){const e=be();if(n==="call"){e.setMenu(null),e.setCallView(!0),Ee("select");return}n.startsWith("app:")||(e.setMenu(e.menu===n?null:n),Ee(e.menu===n?"back":"select"))}function Zg(n){const e=be(),t=n.target;if(Cp(t)){n.key==="Escape"&&(n.preventDefault(),t.blur());return}if(e.phase==="closed"||e.phase==="closing"||!e.state)return;if(mh(e)){n.key==="Escape"&&(n.preventDefault(),Vs());return}if(n.key==="Escape"){n.preventDefault(),Oa();return}if(e.stack.length>0||e.callView){for(let u=el.length-1;u>=0;u--)if(el[u](n)){n.preventDefault();return}(n.key==="ArrowLeft"||n.key==="Backspace")&&(n.preventDefault(),Oa());return}if(n.key==="Backspace"){n.preventDefault(),Oa();return}const a=ku(e.state,e.recentsSeenAt);if(e.menu){const u=Pv(e.menu,e.state,a);if(u.length===0)return;if(n.key==="ArrowDown"||n.key==="ArrowUp"){n.preventDefault();const d=n.key==="ArrowDown"?1:-1;e.setRow((e.row+d+u.length)%u.length),Ee("tick")}else if(n.key==="Enter"||n.key==="ArrowRight"){n.preventDefault();const d=u[Math.min(e.row,u.length-1)];d&&BE(d.view)}else n.key==="ArrowLeft"&&(n.preventDefault(),Oa());return}const c=Rv(e.state,a,!!e.state.call);if(n.key==="ArrowDown"||n.key==="ArrowUp"){n.preventDefault();const u=n.key==="ArrowDown"?1:-1;e.setCursor((e.cursor+u+c.length)%c.length),Ee("tick")}else if(n.key==="Enter"||n.key==="ArrowRight"){n.preventDefault();const u=c[Math.min(e.cursor,c.length-1)];u&&document.querySelector(`[data-col="${CSS.escape(u.id)}"]`)?.click()}}function VE(){q.useEffect(()=>{const n=()=>zE();return document.addEventListener("focusin",n),document.addEventListener("focusout",n),window.addEventListener("keydown",Zg),()=>{document.removeEventListener("focusin",n),document.removeEventListener("focusout",n),window.removeEventListener("keydown",Zg)}},[])}function Ks(n,e,t,r){return a=>{if(n===0)return!1;if(a.key==="ArrowDown"||a.key==="ArrowUp"){const c=a.key==="ArrowDown"?1:-1,u=e<0?c>0?0:n-1:(e+c+n)%n;return t(u),Ee("tick"),requestAnimationFrame(()=>document.querySelector(".is-kbd")?.scrollIntoView({block:"nearest"})),!0}return a.key==="Enter"&&e>=0&&e<n?(r(e),!0):!1}}const Xi={x:560,btn:80,gap:16,closeBtn:54,closeGap:34};function GE(n){const e=Xi.btn+Xi.gap,t=n*e-Xi.gap+Xi.closeGap+Xi.closeBtn,r=Math.round(540-t/2);return{top:r,height:t,centers:Array.from({length:n},(a,c)=>r+c*e+Xi.btn/2)}}function WE({items:n,layout:e}){const t=fe(d=>d.menu),r=fe(d=>d.callView),a=fe(d=>d.cursor),c=fe(d=>d.state?.call??null),u=async d=>{Ee("select"),fe.getState().setMenu(null),await Pt("apps.launch",{id:d})};return l.jsxs("nav",{className:"column nl-hit",style:{top:e.top,left:Xi.x},"aria-label":"Neural-Link menu",children:[l.jsx("span",{className:"column__spine","aria-hidden":!0,style:{height:e.height}}),n.map((d,h)=>{const p=d.id==="call"?r:d.id===t,g=d.id==="call";return l.jsx("div",{className:"column__slot",style:{"--i":h},children:l.jsx(Vg,{icon:d.icon,label:g?c?.phase==="incoming"?"Incoming":"In call":d.label,selected:p,cursor:a===h,badge:d.badge,tone:g?"ok":"glass",pulse:g,color:d.color,className:g?"rb--call":void 0,onClick:()=>{fe.getState().setCursor(h),d.appId?u(d.appId):HE(d.id)},dataCol:d.id})},d.id)}),l.jsx("div",{className:"column__slot column__slot--close",style:{"--i":n.length,marginTop:Xi.closeGap-Xi.gap},children:l.jsx(Vg,{icon:l.jsx(_2,{size:22,strokeWidth:2.2}),label:"Disconnect",size:Xi.closeBtn,tone:"danger",onClick:Vs})})]})}function $E({icon:n,label:e,hint:t,badge:r,active:a,cursor:c,danger:u,chevron:d=!0,index:h=0,style:p,onClick:g}){return l.jsxs("button",{type:"button",className:["slab",a&&"is-active",c&&"is-cursor",u&&"is-danger"].filter(Boolean).join(" "),style:{...p,"--i":h},onClick:g,children:[n&&l.jsx("span",{className:"slab__icon",children:n}),l.jsxs("span",{className:"slab__text",children:[l.jsx("span",{className:"slab__label label",children:e}),t&&l.jsx("span",{className:"slab__hint",children:t})]}),r?l.jsx("span",{className:"slab__badge mono",children:r>99?"99+":r}):null,d&&l.jsx(BS,{className:"slab__chev",size:18,strokeWidth:2.4})]})}function Np({children:n,className:e,style:t,corners:r=!0,sheen:a=!0,tag:c,flicker:u=!0}){return l.jsxs("div",{className:["holo",u&&"holo--flicker",e].filter(Boolean).join(" "),style:t,children:[l.jsxs("div",{className:"holo__fx","aria-hidden":!0,children:[l.jsx("span",{className:"holo__scan"}),a&&l.jsx("span",{className:"holo__sheen"})]}),r&&l.jsxs("div",{className:"holo__corners","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),c&&l.jsx("span",{className:"holo__tag mono","aria-hidden":!0,children:c}),n]})}function XE({y:n,side:e="left"}){return l.jsx("span",{className:`pointer pointer--${e}`,style:{transform:`translateY(${n}px)`},"aria-hidden":!0})}const bs={x:690,w:340,head:64,row:62,foot:34};function qE({anchorY:n,missed:e}){const t=fe(x=>x.menu),r=fe(x=>x.state),a=fe(x=>x.row),c=fe(x=>x.stack[0]??null),u=fe(_p),d=Pv(t,r,e);if(!t||d.length===0)return null;const h=wE[t]??{title:t,icon:null},p=bs.head+d.length*bs.row+bs.foot,g=Ag(Math.round(n-bs.head-bs.row/2+6),70,1010-p),y=Ag(n-g-11,18,p-30),v=String(["status","phone","messages","contacts","settings","social"].indexOf(t)+1).padStart(2,"0");return l.jsx("div",{className:"tilt tilt--panel",style:{left:bs.x,top:g,width:bs.w},children:l.jsx(du,{cut:12,depth:3,className:"nl3d--board",children:l.jsxs("section",{className:"subpanel nl-hit","aria-label":h.title,children:[l.jsx(XE,{y}),l.jsxs("header",{className:"subpanel__head",children:[l.jsx("span",{className:"subpanel__icon",children:h.icon}),l.jsx("span",{className:"subpanel__title label",children:h.title}),l.jsxs("span",{className:"subpanel__tag mono",children:["NL//",v]})]}),l.jsx("div",{className:"subpanel__rows",children:d.map((x,w)=>l.jsx($E,{index:w,icon:x.icon,label:x.label,hint:x.hint,badge:x.badge,active:Hg(x,c)&&!!u,cursor:a===w,onClick:()=>{const E=fe.getState();if(E.setRow(w),Hg(x,c)&&E.stack.length===1){E.resetView(null),Ee("back");return}E.resetView(x.view),Ee("select")}},x.id))}),l.jsxs("footer",{className:"subpanel__foot mono","aria-hidden":!0,children:[l.jsx("span",{children:"↑↓ select"}),l.jsx("span",{children:"⏎ open"}),l.jsx("span",{children:"esc back"})]})]})})})}function ln({icon:n,title:e,subtitle:t,tag:r,actions:a,children:c,footer:u,canBack:d,className:h,bodyClass:p}){return l.jsxs(Np,{className:["win",h].filter(Boolean).join(" "),tag:r,children:[l.jsxs("header",{className:"win__head",children:[d?l.jsx("button",{type:"button",className:"win__back","aria-label":"Back",onClick:Oa,children:l.jsx(cS,{size:20,strokeWidth:2.4})}):null,l.jsx("span",{className:"win__icon",children:n}),l.jsxs("div",{className:"win__titles",children:[l.jsx("div",{className:"win__title label",children:e}),t&&l.jsx("div",{className:"win__sub",children:t})]}),l.jsxs("div",{className:"win__actions",children:[a,!d&&l.jsx("button",{type:"button",className:"icon-btn win__close","aria-label":"Close window",onClick:Oa,children:l.jsx(ll,{size:18,strokeWidth:2.4})})]})]}),l.jsx("div",{className:"win__rule","aria-hidden":!0}),l.jsx("div",{className:["win__body",p].filter(Boolean).join(" "),children:c}),u&&l.jsx("footer",{className:"win__foot",children:u})]})}function Ht({name:n,seed:e,size:t=44,online:r,group:a,owner:c,level:u,ring:d="none",className:h}){const p=Qc(e??n),g={"--size":`${t}px`,"--hue":p,"--level":u??0};return l.jsxs("span",{className:["avatar",`avatar--${d}`,u?"is-talking":"",h].filter(Boolean).join(" "),style:g,children:[l.jsx("span",{className:"avatar__voice","aria-hidden":!0}),l.jsx("span",{className:"avatar__disc",children:a?l.jsx(kn,{size:Math.round(t*.46),strokeWidth:2.1}):l.jsx("span",{className:"avatar__ini",children:Ly(n)})}),r!=null&&l.jsx("span",{className:`avatar__dot ${r?"is-on":""}`,"aria-label":r?"online":"offline"}),c&&l.jsx("span",{className:"avatar__crown","aria-label":"owner",children:l.jsx(cM,{size:12,strokeWidth:2.6})})]})}function Ot({tone:n="plain",icon:e,small:t,block:r,className:a,children:c,onPointerEnter:u,...d}){return l.jsxs("button",{type:"button",className:["btn",`btn--${n}`,t&&"btn--sm",r&&"btn--block",a].filter(Boolean).join(" "),onPointerEnter:u,...d,children:[e,c!=null&&l.jsx("span",{children:c})]})}function Zt({label:n,tone:e,className:t,children:r,...a}){return l.jsx("button",{type:"button","aria-label":n,title:n,className:["icon-btn",e&&`icon-btn--${e}`,t].filter(Boolean).join(" "),...a,children:r})}const zi=q.forwardRef(function({label:e,icon:t,error:r,counter:a,className:c,...u},d){const h=q.useId(),p=typeof u.value=="string"?u.value.length:0;return l.jsxs("label",{className:["field",r&&"has-error",c].filter(Boolean).join(" "),htmlFor:h,children:[e&&l.jsx("span",{className:"field__label label",children:e}),l.jsxs("span",{className:"field__box",children:[t&&l.jsx("span",{className:"field__icon",children:t}),l.jsx("input",{id:h,ref:d,autoComplete:"off",spellCheck:!1,...u}),a&&u.maxLength?l.jsxs("span",{className:"field__count mono",children:[p,"/",u.maxLength]}):null]}),r&&l.jsx("span",{className:"field__error",children:r})]})}),YE=q.forwardRef(function({className:e,...t},r){return l.jsx("textarea",{ref:r,className:["area",e].filter(Boolean).join(" "),spellCheck:!1,...t})});function Rp({checked:n,onChange:e,label:t,hint:r}){return l.jsxs("button",{type:"button",role:"switch","aria-checked":n,className:`toggle ${n?"is-on":""}`,onClick:()=>{Ee("select"),e(!n)},children:[l.jsxs("span",{className:"toggle__text",children:[l.jsx("span",{className:"label",children:t}),r&&l.jsx("span",{className:"toggle__hint",children:r})]}),l.jsx("span",{className:"toggle__track",children:l.jsx("span",{className:"toggle__knob"})})]})}function jv({value:n,min:e=0,max:t=1,step:r=.01,onInput:a,onCommit:c,label:u,display:d}){const h=(n-e)/(t-e)*100;return l.jsxs("label",{className:"slider",children:[l.jsxs("span",{className:"slider__head",children:[l.jsx("span",{className:"label",children:u}),l.jsx("span",{className:"slider__val mono",children:d??`${Math.round(h)}%`})]}),l.jsxs("span",{className:"slider__wrap",style:{"--pct":`${h}%`},children:[l.jsx("span",{className:"slider__track",children:l.jsx("span",{className:"slider__fill"})}),l.jsx("span",{className:"slider__ticks","aria-hidden":!0,children:Array.from({length:11},(p,g)=>l.jsx("i",{},g))}),l.jsx("input",{type:"range",min:e,max:t,step:r,value:n,onChange:p=>a(Number(p.target.value)),onPointerUp:p=>c?.(Number(p.target.value)),onKeyUp:p=>c?.(Number(p.target.value))})]})]})}function Du({value:n,options:e,onChange:t}){const r=Math.max(0,e.findIndex(a=>a.id===n));return l.jsxs("div",{className:"seg",style:{"--n":e.length,"--idx":r},children:[l.jsx("span",{className:"seg__thumb","aria-hidden":!0}),e.map(a=>l.jsxs("button",{type:"button",className:`seg__opt ${a.id===n?"is-on":""}`,onClick:()=>{a.id!==n&&(Ee("select"),t(a.id))},children:[a.icon,l.jsx("span",{className:"label",children:a.label}),a.badge?l.jsx("span",{className:"seg__badge mono",children:a.badge}):null]},a.id))]})}function Kn({icon:n,title:e,body:t,action:r}){return l.jsxs("div",{className:"empty",children:[l.jsxs("span",{className:"empty__icon",children:[n,l.jsx("span",{className:"empty__orbit","aria-hidden":!0})]}),l.jsx("div",{className:"empty__title label",children:e}),t&&l.jsx("div",{className:"empty__body",children:t}),r]})}function Ei({text:n="Syncing"}){return l.jsxs("div",{className:"loader",children:[l.jsxs("span",{className:"loader__hex","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:n})]})}function En({children:n,aside:e}){return l.jsxs("div",{className:"sect",children:[l.jsx("span",{className:"sect__mark","aria-hidden":!0}),l.jsx("span",{className:"sect__text label",children:n}),l.jsx("span",{className:"sect__line","aria-hidden":!0}),e]})}function KE({canBack:n}){const e=fe(x=>x.state),t=fe(x=>x.clock),r=fe(x=>x.seenToday),a=fe(x=>x.state?.recents??Ln),c=fe(x=>x.state?.threads??Ln),[u,d]=q.useState(!1),h=e?.line??null,p=q.useMemo(()=>{const x=vi(Date.now()),w=a.filter(E=>E.at>=x);return{calls:w.filter(E=>E.status==="answered").length,missed:w.filter(E=>E.direction==="in"&&E.status==="missed").length,talk:w.reduce((E,_)=>E+(_.duration||0),0),messages:Math.max(Object.keys(r).length,c.filter(E=>E.last&&E.last.kind==="text"&&E.last.at>=x).length)}},[a,r,c]),g=e?.contacts??[],y=g.filter(x=>x.online).length,v=async()=>{if(!h)return;const x=await cv(h.number);Ee(x?"select":"error"),d(x),window.setTimeout(()=>d(!1),1500)};return l.jsx(ln,{icon:l.jsx(mM,{size:22}),title:"Status",subtitle:"Neural identity",tag:"NL//01-ID",canBack:n,children:l.jsxs("div",{className:"status nl-scroll",children:[l.jsxs("div",{className:"status__id",children:[l.jsxs("div",{className:"status__avatar",children:[l.jsx(Ht,{name:h?.name??"?",seed:h?.number??"x",size:112,ring:"sel"}),l.jsx("svg",{className:"status__orbit",viewBox:"0 0 140 140","aria-hidden":!0,children:l.jsx("circle",{cx:"70",cy:"70",r:"66"})})]}),l.jsxs("div",{className:"status__who",children:[l.jsx("div",{className:"status__name",children:h?.name??"No line assigned"}),l.jsxs("div",{className:"status__numrow",children:[l.jsx("span",{className:"status__num mono",children:h?.number??"--- ----"}),l.jsx(Ot,{small:!0,tone:"ghost",icon:l.jsx(Sv,{size:15}),onClick:v,disabled:!h,children:u?"Copied":"Copy"})]}),l.jsxs("div",{className:"status__chips",children:[l.jsxs("span",{className:`pill ${h?"pill--ok":"pill--danger"}`,children:[l.jsx(O2,{size:13})," ",h?"Linked":"Offline"]}),l.jsxs("span",{className:"pill",children:[l.jsx(kn,{size:13})," ",y,"/",g.length," contacts online"]})]})]}),l.jsxs("div",{className:"status__clock",children:[l.jsx("div",{className:"status__time mono",children:t?`${Sr(t.hours)}:${Sr(t.minutes)}`:"--:--"}),l.jsxs("div",{className:"status__weather",children:[l.jsx(Nv,{weather:t?.weather,size:22})," ",t?.weather??"Weather unavailable"]}),l.jsx("div",{className:"status__city label",children:"Night City · NCT"})]})]}),l.jsx(En,{children:"Neural sync"}),l.jsx(ZE,{linked:!!h,online:y,total:g.length}),l.jsx(En,{children:"Today"}),l.jsxs("div",{className:"stats",children:[l.jsx(wc,{icon:l.jsx(Zi,{size:20}),value:p.messages,label:"Messages"}),l.jsx(wc,{icon:l.jsx(Ji,{size:20}),value:p.calls,label:"Calls"}),l.jsx(wc,{icon:l.jsx(Nu,{size:20}),value:p.missed,label:"Missed",alert:p.missed>0}),l.jsx(wc,{icon:l.jsx(lu,{size:20}),value:Lu(e),label:"Unread"})]}),l.jsx(En,{aside:l.jsxs("span",{className:"mono status__sync",children:[y," online"]}),children:"Neural network"}),l.jsxs("div",{className:"netlist",children:[g.length===0&&l.jsx("span",{className:"netlist__none",children:"No contacts linked yet."}),[...g].sort((x,w)=>Number(w.online)-Number(x.online)||x.name.localeCompare(w.name)).map((x,w)=>l.jsxs("span",{className:`netlist__c ${x.online?"is-on":""}`,style:{"--i":w},title:`${x.name} · ${x.number}`,children:[l.jsx(Ht,{name:x.name,seed:x.number,size:46,online:x.online}),l.jsx("span",{children:x.name.split(" ")[0]})]},x.id))]})]})})}function wc({icon:n,value:e,label:t,alert:r}){return l.jsxs("div",{className:`stat ${r?"is-alert":""}`,children:[l.jsx("span",{className:"stat__icon",children:n}),l.jsx("span",{className:"stat__val mono",children:e}),l.jsx("span",{className:"stat__label label",children:t})]})}function ZE({linked:n,online:e,total:t}){const r=Lv(),[a,c]=q.useState([0,0,0]);q.useEffect(()=>{const h=window.setInterval(()=>c(p=>p.map(g=>Math.max(-6,Math.min(6,g+(Math.random()-.5)*3)))),1600);return()=>window.clearInterval(h)},[]);const u=n?1:.12,d=[["Cortex link",r],["Bandwidth",64+(t?e/t*26:8)+a[0]],["Synaptic latency",88+a[1]*.8],["Firewall (ICE)",74+a[2]]];return l.jsx("div",{className:"nsync",children:d.map(([h,p],g)=>{const y=Math.max(0,Math.min(99,Math.round(p*u)));return l.jsxs("div",{className:"nsync__row",style:{"--i":g},children:[l.jsx("span",{className:"nsync__label label",children:h}),l.jsxs("span",{className:"nsync__track",children:[l.jsx("span",{className:"nsync__fill",style:{transform:`scaleX(${y/100})`}}),l.jsx("span",{className:"nsync__ticks","aria-hidden":!0})]}),l.jsxs("span",{className:"nsync__val mono",children:[l.jsx("i",{"aria-hidden":!0}),y]})]},h)})})}function QE({tab:n,canBack:e}){const t=fe(u=>u.state),r=fe(u=>u.recentsSeenAt),a=ku(t,r),c=u=>fe.getState().replaceTop({app:"phone",tab:u});return q.useEffect(()=>{n==="recents"&&fe.getState().markRecentsSeen()},[n,t?.recents]),l.jsxs(ln,{icon:l.jsx(Ji,{size:22}),title:"Phone",subtitle:t?.line?`Your line ${t.line.number}`:"No line",tag:"NL//02-TEL",canBack:e,bodyClass:"phone",children:[l.jsx(Du,{value:n,onChange:c,options:[{id:"dial",label:"Keypad",icon:l.jsx(Mv,{size:16})},{id:"recents",label:"Recents",icon:l.jsx(xp,{size:16}),badge:a},{id:"favorites",label:"Favorites",icon:l.jsx(Mr,{size:16})}]}),l.jsxs("div",{className:"phone__pane",children:[n==="dial"&&l.jsx(ew,{}),n==="recents"&&l.jsx(nw,{}),n==="favorites"&&l.jsx(iw,{})]},n)]})}const JE=[["1",""],["2","ABC"],["3","DEF"],["4","GHI"],["5","JKL"],["6","MNO"],["7","PQRS"],["8","TUV"],["9","WXYZ"],["*",""],["0","+"],["#",""]];function ew(){const n=fe(x=>x.dial),e=fe(x=>x.state?.contacts??Ln),t=fe(x=>!!x.state?.call),[r,a]=q.useState(null),c=x=>fe.getState().setDial(mp(x)),u=hp.test(n),d=u?e.find(x=>x.number===n):void 0,h=q.useMemo(()=>{const x=n.replace(/\D/g,"");return!x||u?[]:e.filter(w=>w.number.replace(/\D/g,"").startsWith(x)).slice(0,3)},[n,e,u]),p=x=>{if(!/\d/.test(x)){Ee("tick");return}Ee("tick"),a(x),window.setTimeout(()=>a(w=>w===x?null:w),140),c(fe.getState().dial+x)},g=()=>{Ee("back"),c(fe.getState().dial.replace(/\D/g,"").slice(0,-1))},y=async()=>{u&&await Er(n)&&c("")},v=q.useCallback(x=>/^\d$/.test(x.key)?(p(x.key),!0):x.key==="Backspace"?(g(),!0):x.key==="Enter"?(y(),!0):!1,[n]);return ds(v),l.jsxs("div",{className:"dial",children:[l.jsxs("div",{className:"dial__display",children:[l.jsx("input",{className:"dial__input mono",value:n,placeholder:"555-0000",inputMode:"numeric",onChange:x=>c(x.target.value),onKeyDown:x=>{x.key==="Enter"&&(x.preventDefault(),y())},"aria-label":"Number"}),l.jsxs("div",{className:"dial__who",children:[d?l.jsxs(l.Fragment,{children:[l.jsx(Ht,{name:d.name,seed:d.number,size:22,online:d.online})," ",d.name]}):u?"Unknown number":h.length?"":"Enter a 7-digit number",h.map(x=>l.jsxs("button",{type:"button",className:"dial__sugg",onClick:()=>{Ee("select"),c(x.number)},children:[x.name," ",l.jsx("span",{className:"mono",children:x.number})]},x.id))]}),l.jsx(Zt,{label:"Delete digit",onClick:g,disabled:!n,className:"dial__bs",children:l.jsx(dM,{size:22})})]}),l.jsx("div",{className:"dial__grid",children:JE.map(([x,w],E)=>l.jsxs("button",{type:"button",className:`dial__key ${r===x?"is-pressed":""}`,style:{"--i":E},onClick:()=>p(x),children:[l.jsx("span",{className:"dial__digit",children:x}),l.jsx("span",{className:"dial__letters mono",children:w})]},x))}),l.jsxs("div",{className:"dial__actions",children:[u&&!d&&l.jsx(Ot,{tone:"ghost",small:!0,icon:l.jsx(Qi,{size:16}),onClick:()=>Mn({app:"contacts",screen:"edit",number:n},"reset"),children:"Save"}),l.jsxs("button",{type:"button",className:`callbtn ${u&&!t?"":"is-off"}`,disabled:!u||t,onClick:y,"aria-label":"Call",children:[l.jsx("span",{className:"callbtn__glow","aria-hidden":!0}),l.jsx(ol,{size:30,strokeWidth:2.2})]})]})]})}function tw({r:n}){return n.direction==="in"&&n.status==="missed"?l.jsx(Nu,{size:18}):n.status==="declined"||n.status==="busy"||n.status==="unavailable"?l.jsx(Ru,{size:18}):n.direction==="in"?l.jsx(r2,{size:18}):l.jsx(l2,{size:18})}const Qg={answered:"",missed:"Missed",declined:"Declined",busy:"Busy",unavailable:"Unreachable"};function nw(){const n=fe(u=>u.state?.recents??Ln),e=fe(u=>u.state?.contacts??Ln),[t,r]=q.useState(!1),[a,c]=q.useState(-1);return ds(q.useMemo(()=>Ks(n.length,a,c,u=>{const d=n[u];d&&Er(d.number)}),[n,a])),n.length===0?l.jsx(Kn,{icon:l.jsx(xp,{size:30}),title:"No recent calls",body:"Calls you make and receive appear here."}):l.jsxs("div",{className:"recents",children:[l.jsxs("div",{className:"recents__bar",children:[l.jsxs("span",{className:"label recents__count",children:[n.length," calls"]}),t?l.jsxs("span",{className:"recents__confirm",children:[l.jsx("span",{children:"Clear all recents?"}),l.jsx(Ot,{small:!0,tone:"danger",onClick:async()=>{r(!1),await Pt("recents.clear",{})&&Ee("back")},children:"Clear"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>r(!1),children:"Cancel"})]}):l.jsx(Ot,{small:!0,tone:"ghost",icon:l.jsx(uu,{size:15}),onClick:()=>r(!0),children:"Clear all"})]}),l.jsx("div",{className:"list nl-scroll",children:n.map((u,d)=>{const h=u.direction==="in"&&u.status==="missed",p=Fi(e,u.number,u.name),g=e.find(y=>y.number===u.number);return l.jsxs("button",{type:"button",className:`lrow ${h?"is-missed":""} ${a===d?"is-kbd":""}`,style:{"--i":Math.min(d,14)},onClick:()=>void Er(u.number),title:`Call ${p}`,children:[l.jsx("span",{className:`lrow__kind ${h?"is-missed":u.status!=="answered"?"is-dim":""}`,children:l.jsx(tw,{r:u})}),l.jsxs("span",{className:"lrow__main",children:[l.jsx("span",{className:"lrow__title",children:p}),l.jsxs("span",{className:"lrow__sub",children:[p!==u.number&&l.jsx("span",{className:"mono",children:u.number}),l.jsxs("span",{children:[u.direction==="in"?"Incoming":"Outgoing",Qg[u.status]?` · ${Qg[u.status]}`:"",u.status==="answered"&&u.duration>0?` · ${pp(u.duration)}`:""]})]})]}),l.jsxs("span",{className:"lrow__side",children:[l.jsx("span",{className:"lrow__time",children:Eu(u.at)}),!g&&l.jsx("span",{className:"lrow__tag label",children:"Unknown"})]}),l.jsx("span",{className:"lrow__call",children:l.jsx(ol,{size:18})})]},u.id)})})]})}function iw(){const n=fe(a=>a.state?.contacts??Ln),e=q.useMemo(()=>n.filter(a=>a.favorite).sort((a,c)=>a.name.localeCompare(c.name)),[n]),[t,r]=q.useState(-1);return ds(q.useMemo(()=>Ks(e.length,t,r,a=>{const c=e[a];c&&Er(c.number)}),[e,t])),e.length===0?l.jsx(Kn,{icon:l.jsx(Mr,{size:30}),title:"No favorites",body:"Star a contact to pin it here.",action:l.jsx(Ot,{tone:"ghost",small:!0,onClick:()=>Mn({app:"contacts",screen:"list",filter:"all"},"reset"),children:"Open contacts"})}):l.jsx("div",{className:"favs nl-scroll",children:e.map((a,c)=>l.jsxs("button",{type:"button",className:`fav ${t===c?"is-kbd":""}`,style:{"--i":c},onClick:()=>void Er(a.number),children:[l.jsx(Ht,{name:a.name,seed:a.number,size:78,online:a.online}),l.jsx("span",{className:"fav__name",children:a.name}),l.jsx("span",{className:"fav__num mono",children:a.number}),l.jsxs("span",{className:"fav__call",children:[l.jsx(ol,{size:15})," Call"]})]},a.id))})}function zv(n){return n.kind==="direct"?n.members.find(e=>!e.isMe)??null:null}function rw(n){return n.last?n.last.kind==="system"?n.last.body:n.last.mine?`You: ${n.last.body}`:n.kind==="group"?`${n.last.sender.split(" ")[0]}: ${n.last.body}`:n.last.body:"No messages yet"}function sw({canBack:n}){const e=fe(h=>h.state?.threads??Ln),[t,r]=q.useState(""),[a,c]=q.useState(-1),u=q.useMemo(()=>{const h=t.trim().toLowerCase();return h?e.filter(p=>p.title.toLowerCase().includes(h)||(p.last?.body.toLowerCase().includes(h)??!1)||p.members.some(g=>g.name.toLowerCase().includes(h)||g.number.includes(h))):e},[e,t]);ds(q.useMemo(()=>Ks(u.length,a,c,h=>{const p=u[h];p&&$a(p.id)}),[u,a]));const d=e.reduce((h,p)=>h+p.unread,0);return l.jsx(ln,{icon:l.jsx(Zi,{size:22}),title:"Messages",subtitle:d?`${d} unread`:`${e.length} threads`,tag:"NL//03-MSG",canBack:n,actions:l.jsxs(l.Fragment,{children:[l.jsx(Zt,{label:"New group",onClick:()=>Mn({app:"messages",screen:"group-new"}),children:l.jsx(kn,{size:18})}),l.jsx(Zt,{label:"New message",tone:"sel",onClick:()=>Mn({app:"messages",screen:"new"}),children:l.jsx(cu,{size:18})})]}),children:l.jsxs("div",{className:"msgs",children:[l.jsx(zi,{icon:l.jsx(cs,{size:16}),placeholder:"Search messages and people",value:t,onChange:h=>{r(h.target.value),c(-1)},className:"msgs__search"}),e.length===0?l.jsx(Kn,{icon:l.jsx(Zi,{size:30}),title:"No conversations",body:"Start a thread with a number or a contact.",action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(cu,{size:16}),onClick:()=>Mn({app:"messages",screen:"new"}),children:"New message"})}):u.length===0?l.jsx(Kn,{icon:l.jsx(cs,{size:30}),title:"No match",body:`Nothing for "${t}".`}):l.jsx("div",{className:"list nl-scroll",children:u.map((h,p)=>{const g=zv(h);return l.jsxs("button",{type:"button",className:`trow ${h.unread?"is-unread":""} ${a===p?"is-kbd":""}`,style:{"--i":Math.min(p,14)},onClick:()=>$a(h.id),children:[l.jsx(Ht,{name:h.title,seed:g?.number??`g${h.id}`,size:48,group:h.kind==="group",online:g?g.online:null}),l.jsxs("span",{className:"trow__main",children:[l.jsxs("span",{className:"trow__top",children:[l.jsx("span",{className:"trow__title",children:h.title}),h.kind==="group"&&l.jsxs("span",{className:"trow__count mono",children:[l.jsx(kn,{size:12})," ",h.members.length]})]}),l.jsx("span",{className:`trow__prev ${h.last?.kind==="system"?"is-system":""}`,children:rw(h)})]}),l.jsxs("span",{className:"trow__side",children:[l.jsx("span",{className:"trow__time",children:h.last?lv(h.last.at):""}),h.unread>0&&l.jsx("span",{className:"badge mono",children:h.unread>99?"99+":h.unread})]})]},h.id)})})]})})}const Nf=10*6e4;function aw(n,e,t){const r=[];let a=null;n.forEach((c,u)=>{const d=n[u+1];if(!a||vi(a.at)!==vi(c.at)?r.push({kind:"day",key:`d${c.id}`,label:ph(c.at)}):c.at-a.at>Nf&&r.push({kind:"time",key:`t${c.id}`,label:Wa(c.at)}),c.kind==="system")r.push({kind:"system",key:`s${c.id}`,m:c});else{const h=!!a&&a.kind==="text"&&a.sender.number===c.sender.number&&c.at-a.at<=Nf&&vi(a.at)===vi(c.at),p=!!d&&d.kind==="text"&&d.sender.number===c.sender.number&&d.at-c.at<=Nf&&vi(d.at)===vi(c.at);r.push({kind:"msg",key:`m${c.id}`,m:c,first:!h,last:!p,showName:t&&!c.mine&&!h})}a=c});for(const c of e)r.push({kind:"pending",key:`p${c.tempId}`,p:c});return r}function ow({threadId:n,canBack:e}){const t=fe(L=>L.state?.threads.find(D=>D.id===n)??null),r=fe(L=>L.threadCache[n]),a=fe(L=>L.pending),c=fe(L=>L.state?.contacts??Ln),u=fe(L=>!!L.state?.call),d=q.useMemo(()=>a.filter(L=>L.threadId===n&&!(r?.messages.some(D=>D.id===L.serverId)??!1)),[a,n,r]),h=q.useRef(null),p=q.useRef(null),g=q.useRef(null),[y,v]=q.useState(!0);q.useEffect(()=>{fe.getState().threadCache[n]||hu(n)},[n]);const x=t?.kind==="group",w=q.useMemo(()=>aw(r?.messages??[],d,x),[r?.messages,d,x]);q.useLayoutEffect(()=>{const L=h.current;!L||!r||(r.lastOp==="prepend"&&p.current?(L.scrollTop=L.scrollHeight-p.current.h+p.current.t,p.current=null):r.lastOp==="load"&&(L.scrollTop=L.scrollHeight))},[r?.rev]),q.useEffect(()=>{const L=h.current;if(!L||!r||r.lastOp!=="append")return;const D=r.messages[r.messages.length-1];(y||D?.mine)&&L.scrollTo({top:L.scrollHeight,behavior:"smooth"})},[r?.rev]),q.useEffect(()=>{const L=h.current;L&&d.length&&L.scrollTo({top:L.scrollHeight,behavior:"smooth"})},[d.length]);const E=L=>g.current!=null&&!g.current.has(L)&&r?.lastOp==="append";q.useEffect(()=>{if(!(!r||r.loading)){g.current??=new Set;for(const L of r.messages)g.current.add(L.id)}});const _=()=>{const L=h.current;if(!L)return;const D=L.scrollHeight-L.scrollTop-L.clientHeight<140;D!==y&&v(D),L.scrollTop<60&&r?.hasMore&&!r.loadingMore&&!r.loading&&(p.current={h:L.scrollHeight,t:L.scrollTop},NE(n))};if(!t)return l.jsx(ln,{icon:l.jsx(Zi,{size:22}),title:"Thread",tag:"NL//03-MSG",canBack:e,children:l.jsx(Kn,{icon:l.jsx(wp,{size:30}),title:"Thread unavailable",body:"You are no longer part of this conversation."})});const M=zv(t),k=M?c.find(L=>L.number===M.number):void 0,A=t.members.filter(L=>!L.isMe&&L.online).length,R=x?`${t.members.length} members · ${A} online`:M?`${M.number}${M.online?" · online":" · offline"}`:"";return l.jsxs(ln,{className:"win--thread",icon:l.jsx(Ht,{name:t.title,seed:M?.number??`g${t.id}`,size:40,group:x,online:M?M.online:null}),title:t.title,subtitle:R,tag:`THR-${String(t.id).padStart(4,"0")}`,canBack:e,actions:l.jsxs(l.Fragment,{children:[M&&!k&&l.jsx(Zt,{label:"Save contact",onClick:()=>Mn({app:"contacts",screen:"edit",number:M.number}),children:l.jsx(Qi,{size:18})}),l.jsx(Zt,{label:x?"Group call":"Call",tone:"ok",disabled:u,onClick:()=>{x?Iv(t.id):M&&Er(M.number)},children:x?l.jsx(kn,{size:18}):l.jsx(Ji,{size:18})}),x&&l.jsx(Zt,{label:"Group info",onClick:()=>Mn({app:"messages",screen:"group-info",threadId:t.id}),children:l.jsx(yp,{size:18})})]}),bodyClass:"thread",footer:l.jsx(cw,{threadId:n}),children:[l.jsx("div",{className:"thread__scroll nl-scroll",ref:h,onScroll:_,children:!r||r.loading?l.jsx(Ei,{text:"Decrypting thread"}):l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"thread__head",children:r.loadingMore?l.jsx(Ei,{text:"Loading older"}):r.hasMore?l.jsx("span",{className:"thread__more mono",children:"scroll up for older"}):l.jsxs("span",{className:"thread__start",children:[l.jsx(Ht,{name:t.title,seed:M?.number??`g${t.id}`,size:58,group:x}),l.jsx("span",{className:"label",children:x?"Group created":"Start of the conversation"}),l.jsx("span",{className:"mono",children:"end-to-end neural encryption"})]})}),w.length===0&&l.jsx("div",{className:"thread__empty",children:"Say hello."}),w.map(L=>{switch(L.kind){case"day":return l.jsx("div",{className:"tdiv",children:l.jsx("span",{className:"label",children:L.label})},L.key);case"time":return l.jsx("div",{className:"tdiv tdiv--time",children:l.jsx("span",{className:"mono",children:L.label})},L.key);case"system":return l.jsx("div",{className:`sysmsg ${E(L.m.id)?"is-new":""}`,children:l.jsx("span",{children:L.m.body})},L.key);case"msg":return l.jsxs(q.Fragment,{children:[L.showName&&l.jsx("div",{className:"bname",style:{"--hue":lw(L.m.sender.number)},children:L.m.sender.name}),l.jsxs("div",{className:`bubble-row ${L.m.mine?"is-mine":""} ${L.first?"is-first":""} ${L.last?"is-last":""} ${E(L.m.id)?"is-new":""}`,children:[x&&!L.m.mine&&l.jsx("span",{className:"bubble-row__av",children:L.last&&l.jsx(Ht,{name:L.m.sender.name,seed:L.m.sender.number,size:30})}),l.jsxs("div",{className:"bubble",children:[l.jsx("span",{className:"bubble__text",children:L.m.body}),l.jsx("span",{className:"bubble__time mono",children:Wa(L.m.at)})]})]})]},L.key);case"pending":return l.jsx("div",{className:`bubble-row is-mine is-first is-last is-pending ${L.p.failed?"is-failed":""}`,children:l.jsxs("div",{className:"bubble",children:[l.jsx("span",{className:"bubble__text",children:L.p.body}),l.jsx("span",{className:"bubble__time mono",children:L.p.failed?l.jsxs("button",{type:"button",className:"bubble__retry",onClick:()=>LE(L.p.tempId),children:[l.jsx(E2,{size:12})," Retry"]}):l.jsxs("span",{className:"bubble__dots",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})})]})},L.key)}return null})]})}),!y&&l.jsx("button",{type:"button",className:"thread__jump",onClick:()=>h.current?.scrollTo({top:h.current.scrollHeight,behavior:"smooth"}),children:"Latest"})]})}function lw(n){let e=0;for(let t=0;t<n.length;t++)e=e*31+n.charCodeAt(t)>>>0;return e%360}function cw({threadId:n}){const[e,t]=q.useState(""),r=q.useRef(null),a=e.length,c=e.trim().length>0&&a<=Ea,u=q.useCallback(()=>{const h=r.current;h&&(h.style.height="auto",h.style.height=`${Math.min(124,h.scrollHeight)}px`)},[]);q.useLayoutEffect(u,[e,u]);const d=()=>{if(!c)return;const h=e.replace(/\s+$/,"");t(""),Dv(n,h)};return l.jsxs("div",{className:"composer",children:[l.jsxs("div",{className:"composer__box",children:[l.jsx("textarea",{ref:r,className:"composer__input",rows:1,value:e,maxLength:Ea,placeholder:"Neural message…",spellCheck:!1,onChange:h=>t(h.target.value.slice(0,Ea)),onKeyDown:h=>{h.key==="Enter"&&!h.shiftKey&&!h.nativeEvent.isComposing&&(h.preventDefault(),d())}}),l.jsxs("span",{className:`composer__count mono ${a>Ea-50?"is-warn":""} ${a>=Ea?"is-max":""}`,children:[a,"/",Ea]})]}),l.jsx("button",{type:"button",className:`composer__send ${c?"is-ready":""}`,disabled:!c,onClick:d,"aria-label":"Send",children:l.jsx(A2,{size:22,strokeWidth:2.2})})]})}function Iu({mode:n,exclude:e=[],selected:t=[],max:r=15,onPick:a,onChange:c,pickLabel:u="Select"}){const d=fe(L=>L.state?.contacts??Ln),h=fe(L=>L.state?.line?.number),[p,g]=q.useState(""),[y,v]=q.useState(""),[x,w]=q.useState(null),E=q.useMemo(()=>{const L=p.trim().toLowerCase();return[...d].filter(D=>!e.includes(D.number)&&D.number!==h).filter(D=>!L||D.name.toLowerCase().includes(L)||D.number.includes(L)).sort((D,U)=>Number(U.online)-Number(D.online)||D.name.localeCompare(U.name))},[d,p,e,h]),_=n==="multi"&&t.length>=r,[M,k]=q.useState(-1),A=L=>{if(n==="single"){Ee("select"),a?.(L);return}if(t.includes(L)){Ee("back"),c?.(t.filter(D=>D!==L));return}if(_){Ee("error");return}Ee("select"),c?.([...t,L])};ds(q.useMemo(()=>Ks(E.length,M,k,L=>{const D=E[L];D&&A(D.number)}),[E,M,t]));const R=()=>{if(!hp.test(y)){w("Numbers look like 555-0123."),Ee("error");return}if(y===h){w("That is your own number."),Ee("error");return}if(e.includes(y)){w("Already included."),Ee("error");return}w(null),A(y),v("")};return l.jsxs("div",{className:"picker",children:[n==="multi"&&t.length>0&&l.jsxs("div",{className:"chips",children:[t.map(L=>l.jsxs("span",{className:"chip",children:[l.jsx("span",{children:Fi(d,L)}),l.jsx("button",{type:"button","aria-label":"Remove",onClick:()=>A(L),children:l.jsx(ll,{size:13,strokeWidth:2.6})})]},L)),l.jsxs("span",{className:"chips__count mono",children:[t.length,"/",r]})]}),l.jsxs("div",{className:"picker__row",children:[l.jsx(zi,{icon:l.jsx(cs,{size:16}),placeholder:"Search contacts",value:p,onChange:L=>g(L.target.value)}),l.jsx(zi,{icon:l.jsx(rl,{size:16}),placeholder:"555-0000",inputMode:"numeric",value:y,error:x,className:"picker__raw",onChange:L=>{v(mp(L.target.value)),w(null)},onKeyDown:L=>{L.key==="Enter"&&(L.preventDefault(),R())}}),l.jsx(Zt,{label:n==="multi"?"Add number":u,tone:"sel",onClick:R,disabled:y.length===0,children:l.jsx(m2,{size:18,strokeWidth:2.6})})]}),l.jsxs("div",{className:"picker__list nl-scroll",children:[E.length===0&&l.jsx("div",{className:"picker__none",children:d.length===0?"No contacts yet. Type a number above.":"No match."}),E.map((L,D)=>{const U=t.includes(L.number);return l.jsxs("button",{type:"button",className:`prow ${U?"is-on":""} ${M===D?"is-kbd":""}`,style:{"--i":Math.min(D,12)},disabled:n==="multi"&&_&&!U,onClick:()=>A(L.number),children:[l.jsx(Ht,{name:L.name,seed:L.number,size:36,online:L.online}),l.jsxs("span",{className:"prow__text",children:[l.jsx("span",{className:"prow__name",children:L.name}),l.jsx("span",{className:"prow__num mono",children:L.number})]}),n==="multi"?l.jsx("span",{className:`check ${U?"is-on":""}`,children:U&&l.jsx(yv,{size:14,strokeWidth:3})}):l.jsx("span",{className:"prow__pick label",children:u})]},L.id)})]})]})}function uw({canBack:n}){const[e,t]=q.useState(!1),[r,a]=q.useState(null),c=async u=>{if(!e){t(!0),a(null);try{const d=await Hs("threads.direct",{number:u});$a(d.threadId,"reset")}catch(d){Ee("error"),a(Fn(d instanceof Sn?d.slug:"unknown")),t(!1)}}};return l.jsx(ln,{icon:l.jsx(cu,{size:22}),title:"New message",subtitle:"Choose who to reach",tag:"NL//03-NEW",canBack:n,children:l.jsxs("div",{className:"form",children:[r&&l.jsx("div",{className:"form__error",children:r}),l.jsx(Iu,{mode:"single",onPick:c,pickLabel:"Message"})]})})}function dw({canBack:n}){const[e,t]=q.useState(""),[r,a]=q.useState([]),[c,u]=q.useState(!1),[d,h]=q.useState(null),p=e.trim().length>=1&&e.trim().length<=32,g=r.length>=wf&&r.length<=Zc,y=async()=>{if(!p||!g||c){Ee("error");return}u(!0),h(null);try{const x=await Hs("groups.create",{title:e.trim(),numbers:r});$a(x.threadId,"reset")}catch(x){Ee("error"),h(Fn(x instanceof Sn?x.slug:"unknown")),u(!1)}},v=wf-r.length;return l.jsx(ln,{icon:l.jsx(kn,{size:22}),title:"New group",subtitle:`${r.length} selected · ${wf} to ${Zc} members`,tag:"NL//03-GRP",canBack:n,footer:l.jsxs("div",{className:"form__bar",children:[l.jsx("span",{className:"form__hint",children:p?v>0?`Add ${v} more member${v>1?"s":""}.`:"Ready to link.":"Give the group a name."}),l.jsx(Ot,{tone:"sel",icon:l.jsx(kn,{size:17}),onClick:y,disabled:!p||!g||c,children:c?"Creating…":"Create group"})]}),children:l.jsxs("div",{className:"form",children:[l.jsx(zi,{label:"Group name",icon:l.jsx(J2,{size:16}),placeholder:"Afterlife Crew",value:e,maxLength:32,counter:!0,onChange:x=>t(x.target.value)}),d&&l.jsx("div",{className:"form__error",children:d}),l.jsx(Iu,{mode:"multi",selected:r,onChange:a,max:Zc})]})})}function fw({threadId:n,canBack:e}){const t=fe(te=>te.state?.threads.find(T=>T.id===n)??null),r=fe(te=>te.threadCache[n]?.members),a=fe(te=>!!te.state?.call),[c,u]=q.useState(!1),[d,h]=q.useState(t?.title??""),[p,g]=q.useState(!1),[y,v]=q.useState(!1),[x,w]=q.useState(null),[E,_]=q.useState(null);if(q.useEffect(()=>{c||h(t?.title??"")},[t?.title,c]),!t)return l.jsx(ln,{icon:l.jsx(kn,{size:22}),title:"Group",canBack:e,children:l.jsx("div",{className:"form",children:l.jsx("div",{className:"form__error",children:"This group is no longer available."})})});const M=[...t.members.length?t.members:r??[]].sort((te,T)=>Number(T.owner)-Number(te.owner)||Number(T.isMe)-Number(te.isMe)||Number(T.online)-Number(te.online)||te.name.localeCompare(T.name)),k=t.isOwner,A=M.length-1>=Zc,R=te=>{Ee("error"),_(Fn(te instanceof Sn?te.slug:"unknown"))},L=async()=>{const te=d.trim();if(!te||te===t.title){u(!1);return}try{await Hs("groups.rename",{threadId:n,title:te}),Ee("select"),u(!1),_(null)}catch(T){R(T)}},D=async te=>{try{await Hs("groups.add",{threadId:n,number:te}),Ee("select"),g(!1),_(null)}catch(T){R(T)}},U=async te=>{w(null);try{await Hs("groups.remove",{threadId:n,number:te}),Ee("back"),_(null)}catch(T){R(T)}},$=async()=>{await Pt("groups.leave",{threadId:n})&&(Ee("back"),fe.getState().resetView({app:"messages",screen:"list"}))};return l.jsx(ln,{icon:l.jsx(kn,{size:22}),title:"Group info",subtitle:`${M.length} members${k?" · you own this group":""}`,tag:`GRP-${String(n).padStart(4,"0")}`,canBack:e,children:l.jsxs("div",{className:"ginfo nl-scroll",children:[l.jsxs("div",{className:"ginfo__hero",children:[l.jsx(Ht,{name:t.title,seed:`g${t.id}`,size:84,group:!0,ring:"sel"}),c?l.jsxs("div",{className:"ginfo__rename",children:[l.jsx(zi,{value:d,maxLength:32,counter:!0,onChange:te=>h(te.target.value),onKeyDown:te=>{te.key==="Enter"&&(te.preventDefault(),L())}}),l.jsx(Zt,{label:"Save name",tone:"sel",onClick:L,children:l.jsx(yv,{size:18})}),l.jsx(Zt,{label:"Cancel",onClick:()=>u(!1),children:l.jsx(ll,{size:18})})]}):l.jsxs("div",{className:"ginfo__title",children:[l.jsx("span",{children:t.title}),l.jsx(Zt,{label:"Rename group",onClick:()=>u(!0),children:l.jsx(Tv,{size:16})})]}),l.jsxs("div",{className:"ginfo__actions",children:[l.jsx(Ot,{tone:"ok",icon:l.jsx(Ji,{size:17}),disabled:a,onClick:()=>void Iv(n),children:"Group call"}),l.jsx(Ot,{tone:"ghost",icon:l.jsx(Qi,{size:17}),disabled:A,onClick:()=>g(te=>!te),children:p?"Close":"Add member"})]})]}),E&&l.jsx("div",{className:"form__error",children:E}),p&&l.jsxs("div",{className:"ginfo__add",children:[l.jsx(En,{children:"Add a member"}),l.jsx(Iu,{mode:"single",exclude:M.map(te=>te.number),onPick:D,pickLabel:"Add"})]}),l.jsx(En,{aside:l.jsxs("span",{className:"mono ginfo__online",children:[M.filter(te=>te.online).length," online"]}),children:"Members"}),l.jsx("div",{className:"ginfo__members",children:M.map((te,T)=>l.jsxs("div",{className:"mrow",style:{"--i":Math.min(T,14)},children:[l.jsx(Ht,{name:te.name,seed:te.number,size:40,online:te.online,owner:te.owner}),l.jsxs("span",{className:"mrow__main",children:[l.jsxs("span",{className:"mrow__name",children:[te.name,te.isMe&&l.jsx("span",{className:"mrow__me label",children:"You"})]}),l.jsxs("span",{className:"mrow__num mono",children:[te.number,te.owner?" · owner":""]})]}),k&&!te.isMe&&(x===te.number?l.jsxs("span",{className:"mrow__confirm",children:[l.jsx(Ot,{small:!0,tone:"danger",onClick:()=>U(te.number),children:"Remove"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>w(null),children:"Keep"})]}):l.jsx(Zt,{label:`Remove ${te.name}`,tone:"danger",onClick:()=>w(te.number),children:l.jsx(iE,{size:17})}))]},te.number))}),l.jsx("div",{className:"ginfo__leave",children:y?l.jsxs(l.Fragment,{children:[l.jsxs("span",{children:["Leave “",t.title,"”? You will stop receiving its messages."]}),l.jsx(Ot,{tone:"danger",icon:l.jsx(jg,{size:16}),onClick:$,children:"Leave group"}),l.jsx(Ot,{tone:"ghost",onClick:()=>v(!1),children:"Cancel"})]}):l.jsx(Ot,{tone:"danger",icon:l.jsx(jg,{size:16}),onClick:()=>v(!0),children:"Leave group"})})]})})}const hw=n=>{const e=n.trim()[0]?.toUpperCase()??"#";return/[A-Z]/.test(e)?e:"#"};function pw({filter:n,canBack:e}){const t=fe(E=>E.state?.contacts??Ln),r=fe(E=>!!E.state?.call),[a,c]=q.useState(""),[u,d]=q.useState(-1),h=q.useRef(null),p=q.useMemo(()=>{const E=a.trim().toLowerCase();return t.filter(_=>n==="all"||_.favorite).filter(_=>!E||_.name.toLowerCase().includes(E)||_.number.includes(E)).sort((_,M)=>_.name.localeCompare(M.name,void 0,{sensitivity:"base"}))},[t,a,n]),g=q.useMemo(()=>{const E=[];return p.forEach((_,M)=>{const k=hw(_.name),A=E[E.length-1];A&&A.letter===k?A.items.push({c:_,idx:M}):E.push({letter:k,items:[{c:_,idx:M}]})}),E},[p]),y=g.map(E=>E.letter);ds(q.useMemo(()=>Ks(p.length,u,d,E=>{const _=p[E];_&&Er(_.number)}),[p,u]));const v=E=>fe.getState().replaceTop({app:"contacts",screen:"list",filter:E}),x=async E=>{Ee("select"),await Pt("contacts.save",{id:E.id,name:E.name,number:E.number,favorite:!E.favorite})},w=E=>{Ee("tick"),h.current?.querySelector(`[data-letter="${E}"]`)?.scrollIntoView({block:"start",behavior:"smooth"})};return l.jsx(ln,{icon:l.jsx(il,{size:22}),title:"Contacts",subtitle:`${t.length} saved · ${t.filter(E=>E.online).length} online`,tag:"NL//04-DIR",canBack:e,actions:l.jsx(Zt,{label:"Add contact",tone:"sel",onClick:()=>Mn({app:"contacts",screen:"edit"}),children:l.jsx(Qi,{size:18})}),children:l.jsxs("div",{className:"contacts",children:[l.jsxs("div",{className:"contacts__bar",children:[l.jsx(Du,{value:n,onChange:v,options:[{id:"all",label:"All"},{id:"favorites",label:"Favorites",icon:l.jsx(Mr,{size:14})}]}),l.jsx(zi,{icon:l.jsx(cs,{size:16}),placeholder:"Search",value:a,onChange:E=>{c(E.target.value),d(-1)}})]}),p.length===0?t.length===0?l.jsx(Kn,{icon:l.jsx(il,{size:30}),title:"No contacts",body:"Save the numbers you meet in Night City.",action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(Qi,{size:16}),onClick:()=>Mn({app:"contacts",screen:"edit"}),children:"Add contact"})}):l.jsx(Kn,{icon:n==="favorites"?l.jsx(Mr,{size:30}):l.jsx(cs,{size:30}),title:n==="favorites"&&!a?"No favorites":"No match",body:n==="favorites"&&!a?"Tap the star on a contact to pin it.":void 0}):l.jsxs("div",{className:"contacts__body",children:[l.jsx("div",{className:"list nl-scroll",ref:h,children:g.map(E=>l.jsxs("div",{className:"csec",children:[l.jsx("div",{className:"csec__letter label","data-letter":E.letter,children:E.letter}),E.items.map(({c:_,idx:M})=>l.jsxs("div",{className:`crow ${u===M?"is-kbd":""}`,style:{"--i":Math.min(M,14)},children:[l.jsx(Ht,{name:_.name,seed:_.number,size:44,online:_.online}),l.jsxs("span",{className:"crow__main",children:[l.jsx("span",{className:"crow__name",children:_.name}),l.jsxs("span",{className:"crow__num mono",children:[_.number,l.jsx("span",{className:`crow__state ${_.online?"is-on":""}`,children:_.online?"online":"offline"})]})]}),l.jsxs("span",{className:"crow__acts",children:[l.jsx(Zt,{label:_.favorite?"Unstar":"Star",className:`star ${_.favorite?"is-on":""}`,onClick:()=>x(_),children:l.jsx(Mr,{size:17})}),l.jsx(Zt,{label:"Message",onClick:()=>void RE(_.number),children:l.jsx(Zi,{size:17})}),l.jsx(Zt,{label:"Call",tone:"ok",disabled:r,onClick:()=>void Er(_.number),children:l.jsx(Ji,{size:17})}),l.jsx(Zt,{label:"Edit",onClick:()=>Mn({app:"contacts",screen:"edit",id:_.id}),children:l.jsx(Tv,{size:16})})]})]},_.id))]},E.letter))}),y.length>1&&l.jsx("div",{className:"alpha","aria-label":"Index",children:y.map(E=>l.jsx("button",{type:"button",className:"alpha__l mono",onClick:()=>w(E),children:E},E))})]})]})})}function mw({id:n,number:e,canBack:t}){const r=fe(D=>n!=null?D.state?.contacts.find(U=>U.id===n):void 0),a=fe(D=>D.state?.line?.number),[c,u]=q.useState(r?.name??""),[d,h]=q.useState(r?.number??e??""),[p,g]=q.useState(r?.favorite??!1),[y,v]=q.useState(null),[x,w]=q.useState(!1),[E,_]=q.useState(!1),M=c.trim().length>=1&&c.trim().length<=32,k=hp.test(d),A=()=>{fe.getState().back()||fe.getState().resetView(null)},R=async()=>{if(!M){v(Fn("invalid_name")),Ee("error");return}if(!k){v(Fn("invalid_number")),Ee("error");return}if(d===a){v(Fn("self")),Ee("error");return}w(!0),v(null);try{await Hs("contacts.save",{id:r?.id,name:c.trim(),number:d,favorite:p}),Ee("select"),A()}catch(D){Ee("error"),v(Fn(D instanceof Sn?D.slug:"unknown")),w(!1)}},L=async()=>{r&&await Pt("contacts.delete",{id:r.id})&&(Ee("back"),A())};return l.jsx(ln,{icon:r?l.jsx(Tp,{size:22}):l.jsx(Qi,{size:22}),title:r?"Edit contact":"New contact",subtitle:r?r.number:"Save a neural line",tag:"NL//04-EDT",canBack:t,footer:l.jsxs("div",{className:"form__bar",children:[r?E?l.jsxs("span",{className:"form__confirm",children:[l.jsxs("span",{children:["Delete ",r.name,"?"]}),l.jsx(Ot,{small:!0,tone:"danger",onClick:L,children:"Delete"}),l.jsx(Ot,{small:!0,tone:"ghost",onClick:()=>_(!1),children:"Keep"})]}):l.jsx(Ot,{tone:"danger",icon:l.jsx(uu,{size:16}),onClick:()=>_(!0),children:"Delete"}):l.jsx("span",{}),l.jsx(Ot,{tone:"sel",icon:l.jsx(Av,{size:17}),onClick:R,disabled:x,children:x?"Saving…":"Save"})]}),children:l.jsxs("div",{className:"form form--contact",children:[l.jsx("div",{className:"form__hero",children:l.jsx(Ht,{name:c||"?",seed:d||"new",size:96,ring:"sel"})}),l.jsx(zi,{label:"Name",icon:l.jsx(no,{size:16}),placeholder:"Jackie Welles",value:c,maxLength:32,counter:!0,onChange:D=>{u(D.target.value),v(null)},onKeyDown:D=>{D.key==="Enter"&&(D.preventDefault(),R())}}),l.jsx(zi,{label:"Number",icon:l.jsx(rl,{size:16}),placeholder:"555-0000",inputMode:"numeric",value:d,error:d.length>0&&d.length===8&&!k?Fn("invalid_number"):null,onChange:D=>{h(mp(D.target.value)),v(null)},onKeyDown:D=>{D.key==="Enter"&&(D.preventDefault(),R())}}),l.jsx(Rp,{checked:p,onChange:g,label:"Favorite",hint:"Pin to the phone's favorites"}),y&&l.jsx("div",{className:"form__error",children:y}),l.jsxs("div",{className:"form__note",children:[l.jsx(Mr,{size:14})," Contacts are stored on your neural line and follow you across sessions."]})]})})}const gw=[{id:"aurora",label:"Holocall",hint:"The implant's own ring"},{id:"link",label:"Rockerboy",hint:"Kerry's private line"},{id:"pulse",label:"Landline",hint:"An old corded phone"},{id:"silent",label:"Silent",hint:"Vibration only"}],_w=[{id:"cyberpunk",label:"Night City",hint:"Navy glass, cut corners, red selection"},{id:"sao",label:"Aincrad",hint:"The original holographic glass"}],vw=[{id:"sao",label:"Aincrad",hint:"White glass, gold selection"},{id:"cyan",label:"Netrunner",hint:"Ice cyan, magenta edges"},{id:"magenta",label:"Kabuki",hint:"Neon magenta, cyan edges"}];function xw({section:n,canBack:e}){const t=r=>fe.getState().replaceTop({app:"settings",section:r});return l.jsxs(ln,{icon:l.jsx(Ep,{size:22}),title:"Settings",subtitle:"Neural-Link preferences",tag:"NL//05-CFG",canBack:e,bodyClass:"settings",children:[l.jsx(Du,{value:n,onChange:t,options:[{id:"sound",label:"Sound",icon:l.jsx(Cv,{size:15})},{id:"display",label:"Hologram",icon:l.jsx(wv,{size:15})},{id:"about",label:"System",icon:l.jsx(vp,{size:15})}]}),l.jsxs("div",{className:"settings__pane nl-scroll",children:[n==="sound"&&l.jsx(yw,{}),n==="display"&&l.jsx(Sw,{}),n==="about"&&l.jsx(Ew,{})]},n)]})}function yw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Ringtone"}),l.jsx("div",{className:"rings",children:gw.map((e,t)=>l.jsxs("div",{className:`ring-opt ${n.ringtone===e.id?"is-on":""}`,style:{"--i":t},children:[l.jsxs("button",{type:"button",className:"ring-opt__main",onClick:()=>{Ee("select"),Gs({ringtone:e.id},0)},children:[l.jsx("span",{className:"ring-opt__radio"}),l.jsxs("span",{className:"ring-opt__text",children:[l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{children:e.hint})]})]}),e.id!=="silent"&&l.jsx("button",{type:"button",className:"ring-opt__play","aria-label":`Preview ${e.label}`,onClick:()=>Gy(`preview:${e.id}`),children:l.jsx(h2,{size:16})})]},e.id))}),l.jsx(En,{children:"Levels"}),l.jsx(jv,{label:"Volume",value:n.volume,onInput:e=>Gs({volume:e}),onCommit:()=>Ee("select")}),l.jsx(Rp,{checked:n.dnd,onChange:e=>Gs({dnd:e},0),label:"Do not disturb",hint:"No ringtone, silent notifications"}),n.dnd&&l.jsxs("div",{className:"form__note",children:[l.jsx(gS,{size:14})," Calls still reach you; the ringtone and notification sounds are muted."]})]})}function Sw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Interface"}),l.jsx("div",{className:"accents",children:_w.map(e=>l.jsxs("button",{type:"button",className:`accent accent--style-${e.id} ${n.style===e.id?"is-on":""}`,onClick:()=>{Ee("select"),Gs({style:e.id},0)},children:[l.jsxs("span",{className:"accent__swatch",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{className:"accent__hint",children:e.hint})]},e.id))}),n.style==="sao"&&l.jsx(Mw,{}),l.jsx(En,{children:"Hologram"}),l.jsx(jv,{label:"Intensity",min:.3,max:1,value:n.intensity,onInput:e=>Gs({intensity:e}),display:`${Math.round(n.intensity*100)}%`}),l.jsx("div",{className:"form__note",children:"Glow, scanlines and ambient particles follow this level."})]})}function Mw(){const n=eo();return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"Theme"}),l.jsx(Rp,{checked:n.theme==="dark",onChange:e=>Gs({theme:e?"dark":"light"},0),label:"Dark mode",hint:"Smoked black glass, light text"}),l.jsx(En,{children:"Accent"}),l.jsx("div",{className:"accents",children:vw.map(e=>l.jsxs("button",{type:"button",className:`accent accent--${e.id} ${n.accent===e.id?"is-on":""}`,onClick:()=>{Ee("select"),Gs({accent:e.id},0)},children:[l.jsxs("span",{className:"accent__swatch",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsx("span",{className:"label",children:e.label}),l.jsx("span",{className:"accent__hint",children:e.hint})]},e.id))})]})}function Ew(){const n=fe(r=>r.state?.line??null),e=fe(r=>r.state?.apps.length??0),t=[["System","Neural-Link OS 2.7.7"],["Firmware","Kiroshi Optics / NL-77 bridge"],["Line",n?`${n.number} · ${n.name}`:"Not assigned"],["Third-party apps",String(e)],["Encryption","Quantum-sealed, end-to-end"],["Manufacturer","Zetatech for Open//77"]];return l.jsxs(l.Fragment,{children:[l.jsx(En,{children:"System"}),l.jsx("dl",{className:"about",children:t.map(([r,a])=>l.jsxs("div",{children:[l.jsx("dt",{className:"label",children:r}),l.jsx("dd",{className:"mono",children:a})]},r))}),l.jsx("div",{className:"form__note",children:"Press Esc to go back a level. Close the link from the bottom of the column."})]})}const ww=/([#@][A-Za-z0-9_]+)/g,Tw=["Spam","Harassment","Doxxing","Impersonation"];function Mi(n){return n<1e3?String(Math.max(0,n)):n<1e4?`${(n/1e3).toFixed(1).replace(/\.0$/,"")}k`:`${Math.round(n/1e3)}k`}const Ws=n=>e=>{e.stopPropagation(),n()};function Pp({text:n,className:e}){const t=n.split(ww);return l.jsx("span",{className:e,children:t.map((r,a)=>{if(a%2===0)return r;const c=r.slice(1).toLowerCase();return r[0]==="#"?l.jsx("button",{type:"button",className:"stoken stoken--tag",onClick:Ws(()=>Uv(c)),children:r},a):rv.test(c)?l.jsx("button",{type:"button",className:"stoken stoken--handle",onClick:Ws(()=>ss(c)),children:r},a):r})})}function Bv({district:n}){return n?l.jsxs("span",{className:"sdistrict mono",children:[l.jsx(Au,{size:11,strokeWidth:2.4}),n]}):null}function bw({a:n,big:e}){return l.jsxs(l.Fragment,{children:[l.jsx("button",{type:"button",className:"scream__name",onClick:Ws(()=>ss(n.handle)),children:n.name}),l.jsxs("span",{className:`scream__handle mono ${e?"is-big":""}`,children:["@",n.handle]})]})}function Ba({post:n,index:e=0,variant:t="feed",kbd:r,rail:a}){const c=fe(h=>!!h.postGone[n.id]),u=fe(h=>n.echoOf?!!h.postGone[n.echoOf.id]:!1),d=!n.body&&(!!n.echoOf||!!n.echoGone);return c?null:d?!n.echoOf||u?null:l.jsx(Jg,{post:n.echoOf,echoedBy:n.author,index:e,variant:t,kbd:r,rail:a}):l.jsx(Jg,{post:n,index:e,variant:t,kbd:r,rail:a})}function Jg({post:n,echoedBy:e,index:t,variant:r,kbd:a,rail:c}){const u=Oy(n),d=fe(g=>g.state?.social?.handle),h=fe(g=>n.echoOf?!!g.postGone[n.echoOf.id]:!1),p=r==="focus";return l.jsxs("article",{className:`scream scream--${r} ${a?"is-kbd":""} ${c?"has-rail":""}`,style:{"--i":Math.min(t,14)},onClick:p?void 0:()=>cl(u.id),children:[e&&l.jsxs("div",{className:"scream__echoed label",children:[l.jsx(Mp,{size:14,strokeWidth:2.4}),e.handle===d?"You echoed":l.jsxs(l.Fragment,{children:[l.jsxs("button",{type:"button",onClick:Ws(()=>ss(e.handle)),children:["@",e.handle]})," echoed"]})]}),l.jsxs("div",{className:"scream__grid",children:[l.jsxs("div",{className:"scream__side",children:[l.jsx("button",{type:"button",className:"scream__av",onClick:Ws(()=>ss(u.author.handle)),"aria-label":`@${u.author.handle}`,children:l.jsx(Ht,{name:u.author.name,seed:u.author.seed,size:p?56:46,online:u.author.online})}),c&&l.jsx("span",{className:"scream__rail","aria-hidden":!0})]}),l.jsxs("div",{className:"scream__main",children:[l.jsxs("div",{className:"scream__top",children:[l.jsx("span",{className:"scream__who",children:l.jsx(bw,{a:u.author,big:p})}),!p&&l.jsx("span",{className:"scream__time",title:`${ph(u.at)} ${Wa(u.at)}`,children:Eu(u.at)}),l.jsx(Bv,{district:u.district})]}),u.replyTo&&l.jsxs("div",{className:"scream__replying",children:["Replying to ",l.jsxs("button",{type:"button",className:"stoken stoken--handle",onClick:Ws(()=>ss(u.replyTo.handle)),children:["@",u.replyTo.handle]})]}),u.body&&l.jsx(Pp,{text:u.body,className:"scream__body"}),u.echoOf&&!h?l.jsx(Hv,{post:u.echoOf}):(u.echoGone||h)&&l.jsx("div",{className:"sembed sembed--gone",children:"This scream was deleted."}),p&&l.jsxs("div",{className:"scream__meta",children:[l.jsxs("span",{className:"mono",children:[Wa(u.at)," · ",ph(u.at)]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.cred)})," Street Cred"]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.echoes)})," ",u.echoes===1?"Echo":"Echoes"]}),l.jsxs("span",{children:[l.jsx("b",{className:"mono",children:Mi(u.replies)})," ",u.replies===1?"Reply":"Replies"]})]}),l.jsx(Aw,{post:u})]})]})]})}function Aw({post:n}){const[e,t]=q.useState(0),[r,a]=q.useState(""),c=q.useRef(null),u=()=>{n.credded||t(h=>h+1),IE(n)},d=()=>{if(r){a("");return}const h=c.current,p=h?.closest(".nl-scroll")?.getBoundingClientRect(),g=h?.getBoundingClientRect(),y=Number(getComputedStyle(document.documentElement).getPropertyValue("--stage-scale"))||1;a(p&&g&&p.bottom-g.bottom<190*y?"up":"down"),Ee("select")};return l.jsxs("div",{className:"sacts",onClick:h=>h.stopPropagation(),children:[l.jsxs("button",{type:"button",className:"sact sact--reply",onClick:()=>Fv(n,"reply"),"aria-label":"Reply",children:[l.jsx("span",{className:"sact__icon",children:l.jsx(Cu,{size:17,strokeWidth:2.2})}),l.jsx("span",{className:"sact__count mono",children:n.replies?Mi(n.replies):""})]}),l.jsxs("button",{type:"button",className:`sact sact--echo ${n.echoed?"is-on":""}`,onClick:()=>void UE(n),"aria-pressed":n.echoed,"aria-label":"Echo",children:[l.jsx("span",{className:"sact__icon",children:l.jsx(Mp,{size:18,strokeWidth:2.2})}),l.jsx("span",{className:"sact__count mono",children:n.echoes?Mi(n.echoes):""})]}),l.jsxs("button",{type:"button",className:`sact sact--cred ${n.credded?"is-on":""}`,onClick:u,"aria-pressed":n.credded,"aria-label":"Street Cred",children:[l.jsxs("span",{className:"sact__icon",children:[l.jsx(bp,{size:17,strokeWidth:2.2}),e>0&&l.jsx(Cw,{},e)]}),l.jsx("span",{className:"sact__label label",children:"Cred"}),l.jsx("span",{className:"sact__count mono",children:Mi(n.cred)})]}),l.jsxs("div",{className:"sact-more",ref:c,children:[l.jsx("button",{type:"button",className:`sact sact--more ${r?"is-on":""}`,onClick:d,"aria-label":"More",children:l.jsx("span",{className:"sact__icon",children:l.jsx(hM,{size:18,strokeWidth:2.4})})}),r&&l.jsx(Nw,{post:n,up:r==="up",onClose:()=>a(""),anchor:c})]})]})}function Cw(){return l.jsxs("span",{className:"credburst","aria-hidden":!0,children:[l.jsx("span",{className:"credburst__flash"}),l.jsx("span",{className:"credburst__ring"}),l.jsx("span",{className:"credburst__ring credburst__ring--2"}),Array.from({length:10},(n,e)=>l.jsx("i",{style:{"--a":`${e*36+e%2*14}deg`,"--d":`${24+e%3*7}px`}},e)),l.jsx("span",{className:"credburst__text",children:"+CRED"})]})}function Nw({post:n,up:e,onClose:t,anchor:r}){const[a,c]=q.useState("");return q.useEffect(()=>{const u=d=>{r.current?.contains(d.target)||t()};return document.addEventListener("pointerdown",u),()=>document.removeEventListener("pointerdown",u)},[r,t]),l.jsxs("div",{className:`smenu ${e?"is-up":""}`,role:"menu",children:[a===""&&l.jsxs(l.Fragment,{children:[l.jsxs("button",{type:"button",className:"smenu__item",onClick:()=>{t(),Fv(n,"quote")},children:[l.jsx(Sp,{size:16})," Quote"]}),n.mine&&l.jsxs("button",{type:"button",className:"smenu__item is-danger",onClick:()=>{Ee("select"),c("delete")},children:[l.jsx(uu,{size:16})," Delete"]}),!n.mine&&l.jsxs("button",{type:"button",className:"smenu__item",onClick:()=>{Ee("select"),c("report")},children:[l.jsx(_M,{size:16})," Report"]})]}),a==="delete"&&l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"smenu__head label",children:"Delete this scream?"}),l.jsxs("button",{type:"button",className:"smenu__item is-danger",onClick:()=>{t(),OE(n.id)},children:[l.jsx(uu,{size:16})," Delete for good"]}),l.jsx("button",{type:"button",className:"smenu__item",onClick:()=>{Ee("back"),c("")},children:"Keep it"})]}),a==="report"&&l.jsxs(l.Fragment,{children:[l.jsx("div",{className:"smenu__head label",children:"Report for"}),Tw.map(u=>l.jsx("button",{type:"button",className:"smenu__item",onClick:()=>{t(),jE(n.id,u.toLowerCase())},children:u},u))]})]})}function Hv({post:n,static:e}){return l.jsxs("div",{className:`sembed ${e?"is-static":""}`,onClick:e?void 0:Ws(()=>cl(n.id)),children:[l.jsxs("div",{className:"sembed__top",children:[l.jsx(Ht,{name:n.author.name,seed:n.author.seed,size:24}),l.jsx("span",{className:"sembed__name",children:n.author.name}),l.jsxs("span",{className:"sembed__handle mono",children:["@",n.author.handle]}),l.jsx("span",{className:"sembed__time",children:Eu(n.at)}),l.jsx(Bv,{district:n.district})]}),n.body?l.jsx(Pp,{text:n.body,className:"sembed__body"}):l.jsxs("span",{className:"sembed__body is-echo",children:["Echo of @",n.echoOf?.author.handle??"deleted"]})]})}const Rw=n=>!n.body&&n.echoOf?n.echoOf.id:n.id,Vv=q.forwardRef(function({posts:e,hasMore:t,loadingMore:r,onMore:a,head:c,empty:u,className:d},h){const[p,g]=q.useState(-1);ds(q.useMemo(()=>Ks(e.length,p,g,v=>{const x=e[v];x&&cl(Rw(x))}),[e,p]));const y=v=>{const x=v.currentTarget;t&&!r&&x.scrollHeight-x.scrollTop-x.clientHeight<260&&a()};return l.jsxs("div",{className:["screams nl-scroll",d].filter(Boolean).join(" "),ref:h,onScroll:y,children:[c,e.length===0&&!t?u:e.map((v,x)=>l.jsx(Ba,{post:v,index:x,kbd:p===x},v.id)),r?l.jsx(Ei,{text:"Pulling older screams"}):t?l.jsx("button",{type:"button",className:"screams__more label",onClick:a,children:"Load more"}):e.length>0?l.jsx("div",{className:"screams__end mono",children:"// end of the sheet"}):null]})}),Pw={pulse:{sub:"Pulse · every citizen, live",empty:["The sheet is blank","Nobody has screamed yet. Be the first."]},crew:{sub:"Crew · people you follow",empty:["Your crew is quiet","Follow citizens from their profile to fill this feed."]},hot:{sub:"Hot · best of the last 24 h",empty:["Nothing is burning","Give Street Cred to the screams that matter."]}};function e_({mode:n,tag:e,canBack:t}){const r=e!=null?DE(e):n??"pulse",a=fe(w=>w.feeds[r]),c=fe(w=>r==="pulse"?w.freshPosts:Ln),u=q.useRef(null),[d,h]=q.useState(!1);q.useEffect(()=>{be().feeds[r]||Jo(r)},[r]);const p=async()=>{Ee("select"),h(!0),r==="pulse"&&be().takeFresh(),await Jo(r),h(!1),u.current?.scrollTo({top:0,behavior:"smooth"})},g=()=>{const w=be();w.prependPosts("pulse",w.takeFresh()),Ee("select"),u.current?.scrollTo({top:0,behavior:"smooth"})},y=w=>be().replaceTop({app:"social",screen:"feed",mode:w}),v=e==null?Pw[n??"pulse"]:null,x=a?.posts.length??0;return l.jsxs(ln,{icon:e!=null?l.jsx(rl,{size:22}):l.jsx($s,{size:22}),title:e!=null?`#${e}`:"Screamsheet",subtitle:v?v.sub:`${x}${a?.hasMore?"+":""} screams on this tag`,tag:e!=null?"NL//06-TAG":"NL//06-SCR",canBack:t,bodyClass:"sfeed",actions:l.jsxs(l.Fragment,{children:[l.jsx(Zt,{label:"Search",onClick:()=>Mn({app:"social",screen:"heat",search:!0}),children:l.jsx(cs,{size:18})}),l.jsx(Zt,{label:"Refresh",className:d?"is-spinning":"",onClick:()=>void p(),children:l.jsx(bv,{size:18})}),l.jsx(Zt,{label:"Compose",tone:"sel",onClick:()=>Mn({app:"social",screen:"compose"}),children:l.jsx(sl,{size:18})})]}),children:[e==null&&l.jsx(Du,{value:n??"pulse",onChange:y,options:[{id:"pulse",label:"Pulse",icon:l.jsx(Pu,{size:16}),badge:c.length||void 0},{id:"crew",label:"Crew",icon:l.jsx(kn,{size:16})},{id:"hot",label:"Hot",icon:l.jsx(bu,{size:16})}]}),l.jsxs("div",{className:"sfeed__pane",children:[c.length>0&&l.jsxs("button",{type:"button",className:"sfresh",onClick:g,children:[l.jsx(dS,{size:16,strokeWidth:2.6}),l.jsx("span",{className:"sfresh__avs",children:c.slice(0,3).map(w=>l.jsx(Ht,{name:w.author.name,seed:w.author.seed,size:24},w.id))}),l.jsxs("span",{className:"label",children:[c.length," new scream",c.length>1?"s":""]})]}),!a||a.loading?l.jsx(Ei,{text:"Tuning in"}):l.jsx(Vv,{ref:u,posts:a.posts,hasMore:a.hasMore,loadingMore:a.loadingMore,onMore:()=>void Jo(r,!0),empty:v?l.jsx(Kn,{icon:l.jsx($s,{size:30}),title:v.empty[0],body:v.empty[1],action:l.jsx(Ot,{tone:"sel",small:!0,icon:l.jsx(sl,{size:16}),onClick:()=>Mn({app:"social",screen:"compose"}),children:"Scream"})}):l.jsx(Kn,{icon:l.jsx(rl,{size:30}),title:"No screams",body:`Nothing tagged #${e} yet.`})})]},r)]})}const t_=260;function Lw({len:n}){const t=2*Math.PI*13,r=Math.min(1,n/Os),a=n>Os?"is-over":n>=t_?"is-warn":"";return l.jsxs("span",{className:`cring ${a}`,title:`${n}/${Os}`,children:[l.jsxs("svg",{viewBox:"0 0 34 34","aria-hidden":!0,children:[l.jsx("circle",{className:"cring__track",cx:"17",cy:"17",r:13}),l.jsx("circle",{className:"cring__fill",cx:"17",cy:"17",r:13,style:{strokeDasharray:t,strokeDashoffset:t*(1-r)}})]}),n>=t_&&l.jsx("span",{className:"cring__left mono",children:Os-n})]})}function Gv({replyTo:n,quoteOf:e,autoFocus:t,compact:r,onSent:a}){const c=fe(M=>M.clock?.district),u=fe(M=>M.state?.line?.name??"Me"),d=fe(M=>{const k=M.state?.social?.handle;return k&&M.profiles[k]?.seed||M.state?.line?.number||k||"me"}),[h,p]=q.useState(""),[g,y]=q.useState(!1),v=q.useRef(null),x=h.length,w=h.trim().length>0&&x<=Os&&!g,E=q.useCallback(()=>{const M=v.current;M&&(M.style.height="auto",M.style.height=`${Math.min(r?120:220,Math.max(r?44:120,M.scrollHeight))}px`)},[r]);q.useLayoutEffect(E,[h,E]),q.useEffect(()=>{t&&v.current?.focus()},[t]);const _=async()=>{if(!w)return;y(!0);const M=await FE(h.trim(),{replyTo:n,quoteOf:e});y(!1),M&&(p(""),a?.(M))};return l.jsxs("div",{className:`scomp ${r?"scomp--compact":""}`,children:[l.jsxs("div",{className:"scomp__row",children:[l.jsx(Ht,{name:u,seed:d,size:r?38:46}),l.jsx("div",{className:"scomp__box",children:l.jsx("textarea",{ref:v,className:"scomp__input",rows:r?1:4,value:h,placeholder:n!=null?"Scream your reply…":e!=null?"Add your take…":"What's happening in Night City?",spellCheck:!1,onChange:M=>p(M.target.value.slice(0,Os+120)),onKeyDown:M=>{M.key==="Enter"&&(M.ctrlKey||M.metaKey)&&!M.nativeEvent.isComposing&&(M.preventDefault(),_())}})})]}),l.jsxs("div",{className:"scomp__bar",children:[l.jsxs("span",{className:`scomp__from ${c?"":"is-unknown"}`,children:[l.jsx(Au,{size:14,strokeWidth:2.4}),c?l.jsxs(l.Fragment,{children:["Screaming from ",l.jsx("b",{children:c})]}):"Location unknown"]}),l.jsx("span",{className:"scomp__hint mono",children:"ctrl+enter"}),l.jsx(Lw,{len:x}),l.jsx(Ot,{tone:"sel",small:r,icon:l.jsx($s,{size:16}),disabled:!w,onClick:()=>void _(),children:g?"Sending…":n!=null?"Reply":"Scream"})]})]})}function kw(n){const e=fe(a=>n!=null?a.composeCtx[n]??a.screamThreads[n]?.post??null:null),[t,r]=q.useState(!1);if(q.useEffect(()=>{n==null||be().composeCtx[n]||be().screamThreads[n]?.post||Pt("social.thread",{postId:n},{quiet:!0}).then(a=>{a?.post?be().rememberPost(a.post):r(!0)})},[n]),n!=null)return e??(t?null:void 0)}function Dw({replyTo:n,quoteOf:e,canBack:t}){const r=n??e,a=kw(r),c=n!=null?"reply":e!=null?"quote":"new",u=()=>{const d=be();d.stack.length>1?d.back():d.resetView({app:"social",screen:"feed",mode:"pulse"})};return l.jsxs(ln,{icon:c==="reply"?l.jsx(Cu,{size:22}):c==="quote"?l.jsx(Sp,{size:22}):l.jsx(sl,{size:22}),title:c==="reply"?"Reply":c==="quote"?"Quote":"Compose",subtitle:a?`${c==="reply"?"Replying to":"Quoting"} @${a.author.handle}`:`Up to ${Os} characters, #tags and @handles`,tag:"NL//06-NEW",canBack:t,bodyClass:"scompose",children:[r!=null&&l.jsxs("div",{className:"scompose__ctx",children:[l.jsx("span",{className:"scompose__ctxlabel label",children:c==="reply"?"Replying to":"Quoting"}),a?l.jsx(Hv,{post:a,static:!0}):a===null?l.jsx("div",{className:"sembed sembed--gone",children:"This scream was deleted."}):l.jsx(Ei,{text:"Fetching scream"})]}),l.jsx(Gv,{replyTo:n,quoteOf:e,autoFocus:!0,onSent:u})]})}function Iw({postId:n,canBack:e}){const t=fe(g=>g.screamThreads[n]),r=fe(g=>!!g.postGone[n]),a=fe(g=>g.postLive[n]?.replies??g.screamThreads[n]?.post?.replies??0),c=q.useRef(null),u=q.useRef(null),d=q.useRef(!1);q.useEffect(()=>{Ov(n)},[n]),q.useLayoutEffect(()=>{d.current||!t?.post||!c.current||!u.current||(d.current=!0,t.parents.length&&(c.current.scrollTop=Math.max(0,u.current.offsetTop-70)))},[t?.post,t?.parents.length]);const h=t?.post,p=()=>requestAnimationFrame(()=>c.current?.scrollTo({top:c.current.scrollHeight,behavior:"smooth"}));return l.jsx(ln,{icon:l.jsx(Pu,{size:22}),title:"Scream",subtitle:h?`@${h.author.handle} · ${Mi(a)} ${a===1?"reply":"replies"}`:"Screamsheet",tag:`SCR-${String(n).padStart(5,"0")}`,canBack:e,bodyClass:"sthread",children:r||t?.missing?l.jsx(Kn,{icon:l.jsx(wp,{size:30}),title:"Scream gone",body:"It was deleted, or it never hit the sheet."}):h?l.jsxs("div",{className:"sthread__scroll nl-scroll",ref:c,children:[t.parents.length>0&&l.jsx("div",{className:"sthread__parents",children:t.parents.map((g,y)=>l.jsx(Ba,{post:g,index:y,variant:"parent",rail:!0},g.id))}),l.jsx("div",{ref:u,className:"sthread__focus",children:l.jsx(Ba,{post:h,variant:"focus"})}),l.jsx("div",{className:"sthread__reply",children:l.jsx(Gv,{replyTo:h.id,compact:!0,onSent:p})}),l.jsxs(En,{children:["Replies · ",t.replies.length]}),t.replies.length===0?l.jsxs("div",{className:"sthread__none",children:[l.jsx(Cu,{size:18})," No replies yet. Start the noise."]}):t.replies.map((g,y)=>l.jsx(Ba,{post:g,index:y,variant:"reply"},g.id))]}):l.jsx(Ei,{text:"Tracing the thread"})})}const Uw=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Fw(n){const e=Qc(n),t=Qc(`${n}:cover`),r=Array.from({length:26},(a,c)=>1+((t>>c%12)+c*7)%4);return{style:{"--h1":e,"--h2":(e+55+t%50)%360,"--h3":(e+180+t%70)%360,"--ang":`${t%140+20}deg`,"--gx":`${15+t%70}%`},bars:r,id:`NC-${(Qc(`${n}:id`)*7919).toString(16).toUpperCase().padStart(6,"0").slice(-6)}`}}function Wv({seed:n,handle:e}){const t=q.useMemo(()=>Fw(n),[n]);return l.jsxs("div",{className:"pcover",style:t.style,"aria-hidden":!0,children:[l.jsx("span",{className:"pcover__grid"}),l.jsx("span",{className:"pcover__scan"}),l.jsx("span",{className:"pcover__sweep"}),l.jsxs("span",{className:"pcover__id mono",children:[t.id," // @",e]}),l.jsx("span",{className:"pcover__bars",children:t.bars.map((r,a)=>l.jsx("i",{style:{width:r*2}},a))})]})}function Ow({p:n}){const e=new Date(n.joinedAt);return l.jsxs("div",{className:"phead",children:[l.jsx(Wv,{seed:n.seed,handle:n.handle}),l.jsxs("div",{className:"phead__bar",children:[l.jsx("span",{className:"phead__av",children:l.jsx(Ht,{name:n.name,seed:n.seed,size:104,ring:"sel",online:n.online})}),l.jsx("span",{className:"phead__acts",children:n.isMe?l.jsx(Ot,{tone:"ghost",icon:l.jsx(Tp,{size:16}),onClick:()=>Mn({app:"social",screen:"edit"}),children:"Edit profile"}):n.followed?l.jsxs(Ot,{className:"phead__unfollow",icon:l.jsx(tE,{size:16}),onClick:()=>void Xg(n.handle,!1),children:[l.jsx("span",{className:"is-idle",children:"Following"}),l.jsx("span",{className:"is-hover",children:"Unfollow"})]}):l.jsx(Ot,{tone:"sel",icon:l.jsx(Qi,{size:16}),onClick:()=>void Xg(n.handle,!0),children:"Follow"})})]}),l.jsxs("div",{className:"phead__id",children:[l.jsx("div",{className:"phead__name",children:n.name}),l.jsxs("div",{className:"phead__handle",children:[l.jsxs("span",{className:"mono",children:["@",n.handle]}),n.followsMe&&!n.isMe&&l.jsx("span",{className:"phead__chip label",children:"Follows you"}),n.isMe&&l.jsx("span",{className:"phead__chip is-me label",children:"You"})]}),n.bio?l.jsx(Pp,{text:n.bio,className:"phead__bio"}):l.jsx("div",{className:"phead__bio is-empty",children:n.isMe?"No bio yet. Tell the city who you are.":"No bio."}),l.jsxs("div",{className:"phead__joined",children:[l.jsx(CS,{size:14})," Joined ",Uw[e.getMonth()]," ",e.getFullYear()]})]}),l.jsxs("div",{className:"pstats",children:[l.jsx(Tc,{value:n.posts,label:"Screams"}),l.jsx(Tc,{value:n.followers,label:"Followers"}),l.jsx(Tc,{value:n.following,label:"Following"}),l.jsx(Tc,{value:n.cred,label:"Street Cred",hot:!0})]})]})}function Tc({value:n,label:e,hot:t}){return l.jsxs("div",{className:`pstat ${t?"is-hot":""}`,children:[l.jsx("span",{className:"pstat__val mono",children:Mi(n)}),l.jsx("span",{className:"pstat__label label",children:e})]})}function jw({handle:n,canBack:e}){const t=fe(d=>d.state?.social?.handle??""),r=n||t,a=fe(d=>r?d.profiles[r]:void 0),c=fe(d=>r?d.feeds[Ap(r)]:void 0);q.useEffect(()=>{r&&Wg(r)},[r]);const u=!a&&c&&!c.loading;return l.jsx(ln,{icon:l.jsx(no,{size:22}),title:a?.name??"Profile",subtitle:r?`@${r}`:"Screamsheet",tag:"NL//06-CIT",canBack:e,bodyClass:"sprofile",actions:a?.isMe?l.jsx(Zt,{label:"Compose",tone:"sel",onClick:()=>Mn({app:"social",screen:"compose"}),children:l.jsx(sl,{size:18})}):null,children:!r||u?l.jsx(Kn,{icon:l.jsx(lE,{size:30}),title:"No such citizen",body:r?`Nobody answers to @${r}.`:"Your neural profile is not ready yet."}):!a||!c||c.loading?l.jsx(Ei,{text:"Pulling the file"}):l.jsx(Vv,{posts:c.posts,hasMore:c.hasMore,loadingMore:c.loadingMore,onMore:()=>void Wg(r,!0),head:l.jsx(Ow,{p:a}),empty:l.jsxs("div",{className:"sprofile__none",children:[l.jsx($s,{size:18})," ",a.isMe?"You have not screamed yet.":"Silent so far."]})})})}function zw({canBack:n}){const e=fe(D=>D.state?.social?.handle??""),t=fe(D=>e?D.profiles[e]:void 0),[r,a]=q.useState(t?.handle??e),[c,u]=q.useState(t?.name??""),[d,h]=q.useState(t?.bio??""),[p,g]=q.useState(!!t),[y,v]=q.useState(null),[x,w]=q.useState(null),[E,_]=q.useState(!1);q.useEffect(()=>{p||Pt("social.me",{}).then(D=>{D&&(be().setProfile(D.profile),be().setSocialUnread(D.unread),a(D.profile.handle),u(D.profile.name),h(D.profile.bio),g(!0))})},[p]);const M=rv.test(r),k=c.trim().length>=1&&c.trim().length<=bg,A=d.length<=Ho,R=async()=>{if(!t)return;if(!M){v(Fn("invalid_handle")),Ee("error");return}if(!k){w(Fn("invalid_name")),Ee("error");return}if(!A)return;const D={};if(r!==t.handle&&(D.handle=r),c.trim()!==t.name&&(D.name=c.trim()),d.trim()!==t.bio&&(D.bio=d.trim()),Object.keys(D).length===0){Ee("back"),be().back();return}_(!0),w(null),v(null);try{const U=await Hs("social.update",D),$=be();$.setSocialHandle(U.profile.handle),$.setProfile(U.profile),Ee("select"),be().back()||be().resetView(null)}catch(U){Ee("error");const $=U instanceof Sn?U.slug:"unknown";$==="handle_taken"||$==="invalid_handle"?v(Fn($)):w(Fn($)),_(!1)}},L=D=>{D.key==="Enter"&&(D.preventDefault(),R())};return l.jsx(ln,{icon:l.jsx(Tp,{size:22}),title:"Edit profile",subtitle:`@${r||e}`,tag:"NL//06-EDT",canBack:n,bodyClass:"sedit",footer:l.jsxs("div",{className:"form__bar",children:[l.jsx("span",{className:"form__hint",children:"Your handle is how the city tags you."}),l.jsx(Ot,{tone:"sel",icon:l.jsx(Av,{size:17}),onClick:()=>void R(),disabled:E||!p,children:E?"Saving…":"Save"})]}),children:!p||!t?l.jsx(Ei,{text:"Pulling your file"}):l.jsxs("div",{className:"form sedit__form nl-scroll",children:[l.jsxs("div",{className:"sedit__preview",children:[l.jsx(Wv,{seed:t.seed,handle:r||t.handle}),l.jsx("span",{className:"sedit__av",children:l.jsx(Ht,{name:c||"?",seed:t.seed,size:76,ring:"sel"})})]}),l.jsx(zi,{label:"Handle",icon:l.jsx(xv,{size:16}),placeholder:"judy_a",value:r,maxLength:16,counter:!0,error:y??(r.length>0&&!M?Fn("invalid_handle"):null),onChange:D=>{a(D.target.value.toLowerCase().replace(/[^a-z0-9_]/g,"")),v(null)},onKeyDown:L}),l.jsx(zi,{label:"Display name",icon:l.jsx(no,{size:16}),placeholder:"Judy Alvarez",value:c,maxLength:bg,counter:!0,onChange:D=>{u(D.target.value),w(null)},onKeyDown:L}),l.jsxs("label",{className:"field sedit__bio",children:[l.jsx("span",{className:"field__label label",children:"Bio"}),l.jsx(YE,{value:d,maxLength:Ho,rows:3,placeholder:"Braindance editor. Lizzie's regular. Don't ask about the Mox.",onChange:D=>h(D.target.value)}),l.jsxs("span",{className:`sedit__count mono ${d.length>=Ho?"is-max":d.length>Ho-20?"is-warn":""}`,children:[d.length,"/",Ho]})]}),x&&l.jsx("div",{className:"form__error",children:x})]})})}const n_={cred:{icon:l.jsx(bp,{size:15,strokeWidth:2.4}),text:"gave you Street Cred"},echo:{icon:l.jsx(Mp,{size:16,strokeWidth:2.4}),text:"echoed your scream"},quote:{icon:l.jsx(Sp,{size:14,strokeWidth:2.4}),text:"quoted your scream"},reply:{icon:l.jsx(Cu,{size:15,strokeWidth:2.4}),text:"replied to you"},mention:{icon:l.jsx(xv,{size:15,strokeWidth:2.4}),text:"mentioned you"},follow:{icon:l.jsx(Qi,{size:15,strokeWidth:2.4}),text:"started following you"}},i_=n=>n.kind==="follow"||!n.post?ss(n.actor.handle):cl(n.post.id);function Bw({canBack:n}){const e=fe(d=>d.pings),[t,r]=q.useState(-1),a=e?.pings??[];q.useEffect(()=>(xh(),()=>fe.getState().pingsSeen()),[]),ds(q.useMemo(()=>Ks(a.length,t,r,d=>{const h=a[d];h&&i_(h)}),[a,t]));const c=d=>{const h=d.currentTarget;h.scrollHeight-h.scrollTop-h.clientHeight<200&&xh(!0)},u=a.filter(d=>!d.read).length;return l.jsx(ln,{icon:l.jsx(_h,{size:22}),title:"Pings",subtitle:u?`${u} new since last time`:"All caught up",tag:"NL//06-PNG",canBack:n,children:!e||e.loading?l.jsx(Ei,{text:"Listening for pings"}):a.length===0?l.jsx(Kn,{icon:l.jsx(_h,{size:30}),title:"No pings",body:"Scream something. The city will answer."}):l.jsxs("div",{className:"list nl-scroll",onScroll:c,children:[a.map((d,h)=>{const p=n_[d.kind]??n_.mention;return l.jsxs("button",{type:"button",className:`pingrow pingrow--${d.kind} ${d.read?"":"is-new"} ${t===h?"is-kbd":""}`,style:{"--i":Math.min(h,14)},onClick:()=>i_(d),children:[l.jsx("span",{className:"pingrow__kind",children:p.icon}),l.jsx(Ht,{name:d.actor.name,seed:d.actor.seed,size:42,online:d.actor.online}),l.jsxs("span",{className:"pingrow__main",children:[l.jsxs("span",{className:"pingrow__line",children:[l.jsx("b",{children:d.actor.name})," ",l.jsxs("span",{className:"mono",children:["@",d.actor.handle]})," ",p.text]}),d.post&&l.jsx("span",{className:"pingrow__post",children:d.post.body||"Echo"})]}),l.jsx("span",{className:"pingrow__time",children:Eu(d.at)})]},d.id)}),e.loadingMore&&l.jsx(Ei,{text:"Older pings"})]})})}function Hw({search:n,canBack:e}){const[t,r]=q.useState(null),[a,c]=q.useState(!1),[u,d]=q.useState(""),[h,p]=q.useState(null),[g,y]=q.useState(!1),v=q.useRef(0),x=async()=>{const E=await Pt("social.heat",{},{quiet:!0});E?r(E):c(!0)};q.useEffect(()=>{x()},[]),q.useEffect(()=>{const E=u.trim(),_=++v.current;if(E.length<2){p(null),y(!1);return}y(!0);const M=window.setTimeout(async()=>{const k=await Pt("social.search",{q:E},{quiet:!0});_===v.current&&(y(!1),p({q:E,profiles:k?.profiles??[],posts:k?.posts??[]}))},320);return()=>window.clearTimeout(M)},[u]);const w=t?.districts.reduce((E,_)=>E+_.count,0)??0;return l.jsxs(ln,{icon:l.jsx(lu,{size:22}),title:"Net Heat",subtitle:t?`${Mi(w)} screams across the city · last 24 h`:"Night City · last 24 h",tag:"NL//06-HEAT",canBack:e,bodyClass:"sheat",actions:l.jsx(Zt,{label:"Refresh",onClick:()=>{Ee("select"),x()},children:l.jsx(bv,{size:18})}),children:[l.jsx(zi,{icon:l.jsx(cs,{size:16}),placeholder:"Search citizens, screams, #tags",value:u,autoFocus:n,onChange:E=>d(E.target.value),className:"sheat__search"}),l.jsx("div",{className:"sheat__scroll nl-scroll",children:u.trim().length>=2?g&&!h?l.jsx(Ei,{text:"Scanning the sheet"}):h&&l.jsx(Ww,{res:h}):t?l.jsxs(l.Fragment,{children:[l.jsx(Vw,{list:t.districts}),l.jsx(En,{aside:l.jsxs("span",{className:"mono sheat__aside",children:[t.tags.length," tags"]}),children:"Trending"}),l.jsx(Gw,{list:t.tags}),l.jsx(En,{aside:l.jsx(bu,{size:16,className:"sheat__flame"}),children:"Hot screams"}),t.hot.length===0?l.jsx("div",{className:"sheat__none",children:"Nothing is burning yet."}):t.hot.map((E,_)=>l.jsx(Ba,{post:E,index:_},E.id))]}):a?l.jsx(Kn,{icon:l.jsx(lu,{size:30}),title:"No signal",body:"The Net Heat feed is offline."}):l.jsx(Ei,{text:"Reading the grid"})})]})}function Vw({list:n}){const e=Math.max(1,...n.map(t=>t.count));return l.jsxs("section",{className:"hmap",children:[l.jsxs("header",{className:"hmap__head",children:[l.jsxs("span",{className:"hmap__title label",children:[l.jsx(Au,{size:15,strokeWidth:2.4})," District heat"]}),l.jsxs("span",{className:"hmap__legend mono",children:[l.jsx("i",{className:"is-cold"}),"cold",l.jsx("i",{className:"is-hot"}),"burning"]})]}),n.length===0?l.jsx("div",{className:"sheat__none",children:"The grid is silent."}):l.jsx("div",{className:"hmap__rows",children:n.slice(0,12).map((t,r)=>{const a=t.count/e;return l.jsxs("div",{className:`hbar ${a>.75?"is-burning":a>.4?"is-warm":""}`,style:{"--t":a.toFixed(3),"--i":r},children:[l.jsx("span",{className:"hbar__rank mono",children:String(r+1).padStart(2,"0")}),l.jsx("span",{className:"hbar__name label",children:t.district}),l.jsx("span",{className:"hbar__track",children:l.jsx("span",{className:"hbar__fill",children:l.jsx("span",{className:"hbar__ember"})})}),l.jsx("span",{className:"hbar__count mono",children:Mi(t.count)}),a>.75&&l.jsx(bu,{className:"hbar__flame",size:15,strokeWidth:2.4})]},t.district)})})]})}function Gw({list:n}){if(n.length===0)return l.jsx("div",{className:"sheat__none",children:"No tag is trending."});const e=Math.max(1,...n.map(t=>t.count));return l.jsx("div",{className:"tcloud",children:n.slice(0,18).map((t,r)=>{const a=t.count/e,c=t.tag.replace(/^#/,"");return l.jsxs("button",{type:"button",className:`tcloud__tag ${a>.66?"is-hot":a>.33?"is-warm":""}`,style:{"--k":a.toFixed(3),"--i":r},onClick:()=>Uv(c),children:[l.jsx(rl,{size:14,strokeWidth:2.6}),l.jsx("span",{children:c}),l.jsx("span",{className:"tcloud__n mono",children:Mi(t.count)})]},c)})})}function Ww({res:n}){return n.profiles.length===0&&n.posts.length===0?l.jsx(Kn,{icon:l.jsx(cs,{size:30}),title:"No match",body:`Nothing for "${n.q}".`}):l.jsxs(l.Fragment,{children:[n.profiles.length>0&&l.jsxs(l.Fragment,{children:[l.jsx(En,{aside:l.jsx("span",{className:"mono sheat__aside",children:n.profiles.length}),children:"Citizens"}),l.jsx("div",{className:"sres__people",children:n.profiles.map((e,t)=>l.jsxs("button",{type:"button",className:"prow sres__person",style:{"--i":t},onClick:()=>ss(e.handle),children:[l.jsx(Ht,{name:e.name,seed:e.seed,size:40,online:e.online}),l.jsxs("span",{className:"prow__text",children:[l.jsx("span",{className:"prow__name",children:e.name}),l.jsxs("span",{className:"prow__num mono",children:["@",e.handle," · ",Mi(e.followers)," followers"]})]}),e.followsMe&&l.jsx("span",{className:"phead__chip label",children:"Follows you"}),l.jsx(no,{size:16,className:"sres__go"})]},e.handle))})]}),n.posts.length>0&&l.jsxs(l.Fragment,{children:[l.jsx(En,{aside:l.jsx("span",{className:"mono sheat__aside",children:n.posts.length}),children:"Screams"}),n.posts.map((e,t)=>l.jsx(Ba,{post:e,index:t},e.id))]})]})}function vr(n){return n.participants.filter(e=>!e.isMe)}function $v(n){const e=vr(n);return e.find(t=>t.state==="connected")??e[0]}function Xv(n,e){if(n.group)return n.group.title;const t=vr(n).filter(a=>a.state!=="left"),r=t.length?t:vr(n);return r.length===0?"Call":r.length===1?Fi(e,r[0].number,r[0].name):`${Fi(e,r[0].number,r[0].name)} +${r.length-1}`}function qv(n){const[e,t]=q.useState(Date.now());return q.useEffect(()=>{if(n==null)return;t(Date.now());const r=window.setInterval(()=>t(Date.now()),1e3);return()=>window.clearInterval(r)},[n]),n==null?null:pp((e-n)/1e3)}const $w={ringing:"Ringing…",connected:"Linked",left:"Left"};function Xw({call:n}){const e=fe(_=>_.state?.contacts??Ln),t=fe(_=>_.talkers),r=qv(n.startedAt),[a,c]=q.useState(!1),u=Xv(n,e),d=n.phase==="outgoing",h=n.participants.filter(_=>_.state!=="left"||!_.isMe),p=n.participants.find(_=>_.isMe),g=p?t[p.lineId]??0:0,y=n.participants.filter(_=>_.state!=="left").length,v=d?0:Math.max(0,...Object.values(t)),x=()=>{Ee("back"),Pt("call.hangup",{})},w=()=>{Ee("select"),Pt("call.mute",{muted:!n.muted})},E=async _=>{await Pt("call.add",{number:_})&&(Ee("select"),c(!1))};return l.jsxs(Np,{className:`callscreen ${d?"is-outgoing":"is-active"}`,tag:`NL//CALL-${String(n.id).padStart(4,"0")}`,children:[l.jsxs("div",{className:"callscreen__bg","aria-hidden":!0,children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]}),l.jsxs("header",{className:"callscreen__head",children:[l.jsx("span",{className:"callscreen__kind label",children:n.group?l.jsxs(l.Fragment,{children:[l.jsx(kn,{size:15})," Group call"]}):d?"Outgoing call":"Neural call"}),l.jsx("div",{className:"callscreen__title",children:u}),l.jsx("div",{className:"callscreen__status",children:d||n.startedAt==null?l.jsxs("span",{className:"linking",children:[l.jsx("span",{className:"label",children:"Linking"}),l.jsxs("span",{className:"linking__dots",children:[l.jsx("i",{}),l.jsx("i",{}),l.jsx("i",{})]})]}):l.jsxs("span",{className:"callscreen__timer mono",children:[l.jsx("span",{className:"rec-dot"}),r]})})]}),d&&vr(n).length===1?l.jsxs("div",{className:"orbit",children:[l.jsx("span",{className:"orbit__path"}),l.jsx("span",{className:"orbit__sat",style:{"--d":"0s"}}),l.jsx("span",{className:"orbit__sat",style:{"--d":"-0.8s"}}),l.jsx("span",{className:"orbit__sat",style:{"--d":"-1.6s"}}),l.jsx(Ht,{name:u,seed:vr(n)[0].number,size:128,ring:"ringing"})]}):l.jsx("div",{className:`parts parts--n${Math.min(6,h.length)}`,children:h.map((_,M)=>{const k=_.state==="connected"&&!(_.isMe&&n.muted)?t[_.lineId]??0:0,A=_.isMe?"You":Fi(e,_.number,_.name);return l.jsxs("div",{className:`part is-${_.state} ${k>.05?"is-talking":""}`,style:{"--i":M},children:[l.jsx(Ht,{name:_.isMe?p?.name??"You":A,seed:_.number,size:92,level:k,ring:_.state==="ringing"?"ringing":"none"}),l.jsx("span",{className:"part__name",children:A}),l.jsx("span",{className:"part__state mono",children:(_.isMe?n.muted:_.muted)&&_.state==="connected"?l.jsxs(l.Fragment,{children:[l.jsx(vh,{size:12})," muted"]}):$w[_.state]})]},_.lineId)})}),a&&l.jsxs("div",{className:"callscreen__add",children:[l.jsxs("div",{className:"callscreen__addhead",children:[l.jsxs("span",{className:"label",children:["Add to call · ",y,"/",Py]}),l.jsx("button",{type:"button",className:"icon-btn","aria-label":"Close",onClick:()=>c(!1),children:l.jsx(ll,{size:18})})]}),l.jsx(Iu,{mode:"single",exclude:n.participants.filter(_=>_.state!=="left").map(_=>_.number),onPick:E,pickLabel:"Invite"})]}),l.jsx("div",{className:`wave ${v>.05?"is-live":""}`,style:{"--level":v.toFixed(2)},"aria-hidden":!0,children:Array.from({length:32},(_,M)=>l.jsx("i",{style:{"--i":M}},M))}),l.jsxs("footer",{className:"callscreen__controls",children:[l.jsxs("button",{type:"button",className:`cbtn ${n.muted?"cbtn--on":""} ${g>.05?"is-talking":""}`,onClick:w,disabled:d,children:[l.jsx("span",{className:"cbtn__disc",children:n.muted?l.jsx(vh,{size:26}):l.jsx(Ev,{size:26})}),l.jsx("span",{className:"label",children:n.muted?"Unmute":"Mute"})]}),l.jsxs("button",{type:"button",className:"cbtn cbtn--danger cbtn--big",onClick:x,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Ru,{size:32})}),l.jsx("span",{className:"label",children:d?"Cancel":"Hang up"})]}),l.jsxs("button",{type:"button",className:`cbtn ${a?"cbtn--on":""}`,onClick:()=>{Ee("select"),c(_=>!_)},disabled:!n.canAdd,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Qi,{size:26})}),l.jsx("span",{className:"label",children:"Add"})]})]})]})}function qw({call:n}){const e=fe(d=>d.state?.contacts??Ln),t=$v(n),r=n.group?n.group.title:t?Fi(e,t.number,t.name):"Unknown",a=n.group?`${t?Fi(e,t.number,t.name):"Someone"} is calling the group · ${vr(n).length} members`:t&&Fi(e,t.number,t.name)!==t.number?t.number:"Unknown number",c=()=>{Ee("select"),Pt("call.accept",{})},u=()=>{Ee("back"),Pt("call.decline",{})};return l.jsxs(Np,{className:"incoming incoming--docked",tag:"NL//CALL-IN",children:[l.jsx("div",{className:"incoming__label label",children:n.group?"Incoming group call":"Incoming neural call"}),l.jsxs("div",{className:"incoming__orb",children:[l.jsx("span",{className:"incoming__wave",style:{"--d":"0s"}}),l.jsx("span",{className:"incoming__wave",style:{"--d":"0.6s"}}),l.jsx("span",{className:"incoming__wave",style:{"--d":"1.2s"}}),l.jsx("span",{className:"incoming__dotring","aria-hidden":!0,children:l.jsx("svg",{viewBox:"0 0 100 100",children:l.jsx("circle",{cx:"50",cy:"50",r:"48"})})}),l.jsx(Ht,{name:r,seed:n.group?`g${n.group.threadId}`:t?.number??"?",size:132,group:!!n.group})]}),l.jsx("div",{className:"incoming__name",children:r}),l.jsx("div",{className:"incoming__sub mono",children:a}),n.group&&l.jsxs("div",{className:"incoming__members",children:[vr(n).slice(0,6).map(d=>l.jsx("span",{className:`incoming__m ${d.state==="connected"?"is-on":""}`,title:d.name,children:l.jsx(Ht,{name:Fi(e,d.number,d.name),seed:d.number,size:30})},d.lineId)),vr(n).length>6&&l.jsxs("span",{className:"incoming__more mono",children:["+",vr(n).length-6]}),l.jsx(kn,{size:14})]}),l.jsxs("div",{className:"incoming__actions",children:[l.jsxs("button",{type:"button",className:"cbtn cbtn--danger",onClick:u,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Ru,{size:30})}),l.jsx("span",{className:"label",children:"Decline"})]}),l.jsxs("button",{type:"button",className:"cbtn cbtn--ok cbtn--throb",onClick:c,children:[l.jsx("span",{className:"cbtn__disc",children:l.jsx(Ji,{size:30})}),l.jsx("span",{className:"label",children:"Accept"})]})]})]})}function Yw(){const n=fe(d=>d.state?.call??null),e=fe(d=>d.state?.contacts??Ln),t=fe(d=>d.toggleKey),r=fe(d=>d.phase!=="closed"&&d.state!==null);if(!n||n.phase!=="incoming"||r)return null;const a=$v(n),c=n.group?n.group.title:a?Fi(e,a.number,a.name):"Unknown",u=!n.group&&!!a&&c!==a.number;return l.jsxs("div",{className:"inpill",children:[l.jsxs("span",{className:"inpill__icon",children:[l.jsx("span",{className:"inpill__wave",style:{"--d":"0s"}}),l.jsx("span",{className:"inpill__wave",style:{"--d":"0.6s"}}),n.group?l.jsx(kn,{size:17}):l.jsx(Ji,{size:17})]}),l.jsxs("span",{className:"inpill__text",children:[l.jsx("span",{className:"inpill__label label",children:n.group?"Incoming group call":"Incoming call"}),l.jsxs("span",{className:"inpill__name",children:[c,u&&l.jsx("span",{className:"inpill__num mono",children:a.number})]})]}),l.jsxs("span",{className:"inpill__key",children:[l.jsx("kbd",{className:"mono",children:t}),l.jsx("span",{className:"label",children:"answer"})]})]},n.id)}function Kw(n){switch(n.app){case"phone":return"phone";case"settings":return"settings";case"messages":return`messages:${n.screen}:${"threadId"in n?n.threadId:""}`;case"contacts":return n.screen==="edit"?`contacts:edit:${n.id??"new"}`:"contacts:list";case"social":switch(n.screen){case"feed":return"social:feed";case"tag":return`social:tag:${n.tag}`;case"thread":return`social:thread:${n.postId}`;case"compose":return`social:compose:${n.replyTo??""}:${n.quoteOf??""}`;case"profile":return`social:profile:${n.handle}`;default:return`social:${n.screen}`}default:return n.app}}function Zw(n,e){switch(n.app){case"status":return l.jsx(KE,{canBack:e});case"phone":return l.jsx(QE,{tab:n.tab,canBack:e});case"messages":switch(n.screen){case"list":return l.jsx(sw,{canBack:e});case"thread":return l.jsx(ow,{threadId:n.threadId,canBack:e});case"new":return l.jsx(uw,{canBack:e});case"group-new":return l.jsx(dw,{canBack:e});case"group-info":return l.jsx(fw,{threadId:n.threadId,canBack:e})}return null;case"contacts":return n.screen==="edit"?l.jsx(mw,{id:n.id,number:n.number,canBack:e}):l.jsx(pw,{filter:n.filter,canBack:e});case"settings":return l.jsx(xw,{section:n.section,canBack:e});case"social":switch(n.screen){case"feed":return l.jsx(e_,{mode:n.mode,canBack:e});case"tag":return l.jsx(e_,{tag:n.tag,canBack:e});case"thread":return l.jsx(Iw,{postId:n.postId,canBack:e});case"compose":return l.jsx(Dw,{replyTo:n.replyTo,quoteOf:n.quoteOf,canBack:e});case"profile":return l.jsx(jw,{handle:n.handle,canBack:e});case"edit":return l.jsx(zw,{canBack:e});case"pings":return l.jsx(Bw,{canBack:e});case"heat":return l.jsx(Hw,{search:!!n.search,canBack:e})}return null}}function Qw(){const n=fe(c=>c.stack),e=fe(c=>c.callView),t=fe(c=>c.state?.call??null),r=fe(c=>c.navDir);if(t&&e)return l.jsx("div",{className:"tilt tilt--call",children:l.jsx(du,{cut:22,depth:7,tone:"ok",className:"nl3d--fill",children:l.jsx("div",{className:"win-enter nl-hit",children:t.phase==="incoming"?l.jsx(qw,{call:t}):l.jsx(Xw,{call:t})})})},`call-${t.id}-${t.phase==="incoming"?"in":"on"}`);const a=n[n.length-1];return a?l.jsx("div",{className:"tilt tilt--window",children:l.jsx(du,{cut:22,depth:8,className:"nl3d--fill",children:l.jsx("div",{className:`win-enter win-enter--${r} nl-hit`,children:Zw(a,n.length>1)},Kw(a))})}):null}const Jw=["Cortex handshake","Bio-signature","Line allocation","Network registry"];function eT(){return l.jsxs("div",{className:"sync nl-hit",role:"status","aria-live":"polite",children:[l.jsxs("div",{className:"sync__orb","aria-hidden":!0,children:[l.jsx("span",{className:"sync__ring sync__ring--a"}),l.jsx("span",{className:"sync__ring sync__ring--b"}),l.jsx("span",{className:"sync__ring sync__ring--c"}),l.jsx("span",{className:"sync__core"})]}),l.jsx("div",{className:"sync__title label",children:"Synchronising neural link…"}),l.jsx("div",{className:"sync__bar","aria-hidden":!0,children:l.jsx("span",{})}),l.jsx("ul",{className:"sync__steps mono",children:Jw.map((n,e)=>l.jsxs("li",{style:{"--i":e},children:[l.jsx("span",{className:"sync__dot"}),n]},n))}),l.jsxs("button",{type:"button",className:"btn btn--ghost btn--sm sync__close",onClick:Vs,children:[l.jsx(ll,{size:16})," ",l.jsx("span",{children:"Close"})]})]})}/**
 * @license
 * Copyright 2010-2024 Three.js Authors
 * SPDX-License-Identifier: MIT
 */const Lp="169",tT=0,r_=1,nT=2,Yv=1,iT=2,gr=3,us=0,qn=1,Yi=2,as=0,Ha=1,yh=2,s_=3,a_=4,rT=5,Is=100,sT=101,aT=102,oT=103,lT=104,cT=200,uT=201,dT=202,fT=203,Sh=204,Mh=205,hT=206,pT=207,mT=208,gT=209,_T=210,vT=211,xT=212,yT=213,ST=214,Eh=0,wh=1,Th=2,Xa=3,bh=4,Ah=5,Ch=6,Nh=7,Kv=0,MT=1,ET=2,os=0,wT=1,TT=2,bT=3,AT=4,CT=5,NT=6,RT=7,Zv=300,qa=301,Ya=302,Rh=303,Ph=304,Uu=306,Lh=1e3,js=1001,kh=1002,Si=1003,PT=1004,bc=1005,Di=1006,Rf=1007,zs=1008,wr=1009,Qv=1010,Jv=1011,al=1012,kp=1013,Xs=1014,xr=1015,ul=1016,Dp=1017,Ip=1018,Ka=1020,ex=35902,tx=1021,nx=1022,Oi=1023,ix=1024,rx=1025,Va=1026,Za=1027,sx=1028,Up=1029,ax=1030,Fp=1031,Op=1033,Jc=33776,eu=33777,tu=33778,nu=33779,Dh=35840,Ih=35841,Uh=35842,Fh=35843,Oh=36196,jh=37492,zh=37496,Bh=37808,Hh=37809,Vh=37810,Gh=37811,Wh=37812,$h=37813,Xh=37814,qh=37815,Yh=37816,Kh=37817,Zh=37818,Qh=37819,Jh=37820,ep=37821,iu=36492,tp=36494,np=36495,ox=36283,ip=36284,rp=36285,sp=36286,LT=3200,kT=3201,DT=0,IT=1,is="",$i="srgb",fs="srgb-linear",jp="display-p3",Fu="display-p3-linear",pu="linear",Bt="srgb",mu="rec709",gu="p3",wa=7680,o_=519,UT=512,FT=513,OT=514,lx=515,jT=516,zT=517,BT=518,HT=519,l_=35044,c_="300 es",yr=2e3,_u=2001;class ro{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});const r=this._listeners;r[e]===void 0&&(r[e]=[]),r[e].indexOf(t)===-1&&r[e].push(t)}hasEventListener(e,t){if(this._listeners===void 0)return!1;const r=this._listeners;return r[e]!==void 0&&r[e].indexOf(t)!==-1}removeEventListener(e,t){if(this._listeners===void 0)return;const a=this._listeners[e];if(a!==void 0){const c=a.indexOf(t);c!==-1&&a.splice(c,1)}}dispatchEvent(e){if(this._listeners===void 0)return;const r=this._listeners[e.type];if(r!==void 0){e.target=this;const a=r.slice(0);for(let c=0,u=a.length;c<u;c++)a[c].call(this,e);e.target=null}}}const Nn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"],Pf=Math.PI/180,ap=180/Math.PI;function dl(){const n=Math.random()*4294967295|0,e=Math.random()*4294967295|0,t=Math.random()*4294967295|0,r=Math.random()*4294967295|0;return(Nn[n&255]+Nn[n>>8&255]+Nn[n>>16&255]+Nn[n>>24&255]+"-"+Nn[e&255]+Nn[e>>8&255]+"-"+Nn[e>>16&15|64]+Nn[e>>24&255]+"-"+Nn[t&63|128]+Nn[t>>8&255]+"-"+Nn[t>>16&255]+Nn[t>>24&255]+Nn[r&255]+Nn[r>>8&255]+Nn[r>>16&255]+Nn[r>>24&255]).toLowerCase()}function Xn(n,e,t){return Math.max(e,Math.min(t,n))}function VT(n,e){return(n%e+e)%e}function Lf(n,e,t){return(1-t)*n+t*e}function Go(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return n/4294967295;case Uint16Array:return n/65535;case Uint8Array:return n/255;case Int32Array:return Math.max(n/2147483647,-1);case Int16Array:return Math.max(n/32767,-1);case Int8Array:return Math.max(n/127,-1);default:throw new Error("Invalid component type.")}}function Wn(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return Math.round(n*4294967295);case Uint16Array:return Math.round(n*65535);case Uint8Array:return Math.round(n*255);case Int32Array:return Math.round(n*2147483647);case Int16Array:return Math.round(n*32767);case Int8Array:return Math.round(n*127);default:throw new Error("Invalid component type.")}}class bt{constructor(e=0,t=0){bt.prototype.isVector2=!0,this.x=e,this.y=t}get width(){return this.x}set width(e){this.x=e}get height(){return this.y}set height(e){this.y=e}set(e,t){return this.x=e,this.y=t,this}setScalar(e){return this.x=e,this.y=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y)}copy(e){return this.x=e.x,this.y=e.y,this}add(e){return this.x+=e.x,this.y+=e.y,this}addScalar(e){return this.x+=e,this.y+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this}subScalar(e){return this.x-=e,this.y-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this}multiply(e){return this.x*=e.x,this.y*=e.y,this}multiplyScalar(e){return this.x*=e,this.y*=e,this}divide(e){return this.x/=e.x,this.y/=e.y,this}divideScalar(e){return this.multiplyScalar(1/e)}applyMatrix3(e){const t=this.x,r=this.y,a=e.elements;return this.x=a[0]*t+a[3]*r+a[6],this.y=a[1]*t+a[4]*r+a[7],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this}clampLength(e,t){const r=this.length();return this.divideScalar(r||1).multiplyScalar(Math.max(e,Math.min(t,r)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(e){return this.x*e.x+this.y*e.y}cross(e){return this.x*e.y-this.y*e.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const r=this.dot(e)/t;return Math.acos(Xn(r,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,r=this.y-e.y;return t*t+r*r}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this}lerpVectors(e,t,r){return this.x=e.x+(t.x-e.x)*r,this.y=e.y+(t.y-e.y)*r,this}equals(e){return e.x===this.x&&e.y===this.y}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this}rotateAround(e,t){const r=Math.cos(t),a=Math.sin(t),c=this.x-e.x,u=this.y-e.y;return this.x=c*r-u*a+e.x,this.y=c*a+u*r+e.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}}class dt{constructor(e,t,r,a,c,u,d,h,p){dt.prototype.isMatrix3=!0,this.elements=[1,0,0,0,1,0,0,0,1],e!==void 0&&this.set(e,t,r,a,c,u,d,h,p)}set(e,t,r,a,c,u,d,h,p){const g=this.elements;return g[0]=e,g[1]=a,g[2]=d,g[3]=t,g[4]=c,g[5]=h,g[6]=r,g[7]=u,g[8]=p,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(e){const t=this.elements,r=e.elements;return t[0]=r[0],t[1]=r[1],t[2]=r[2],t[3]=r[3],t[4]=r[4],t[5]=r[5],t[6]=r[6],t[7]=r[7],t[8]=r[8],this}extractBasis(e,t,r){return e.setFromMatrix3Column(this,0),t.setFromMatrix3Column(this,1),r.setFromMatrix3Column(this,2),this}setFromMatrix4(e){const t=e.elements;return this.set(t[0],t[4],t[8],t[1],t[5],t[9],t[2],t[6],t[10]),this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const r=e.elements,a=t.elements,c=this.elements,u=r[0],d=r[3],h=r[6],p=r[1],g=r[4],y=r[7],v=r[2],x=r[5],w=r[8],E=a[0],_=a[3],M=a[6],k=a[1],A=a[4],R=a[7],L=a[2],D=a[5],U=a[8];return c[0]=u*E+d*k+h*L,c[3]=u*_+d*A+h*D,c[6]=u*M+d*R+h*U,c[1]=p*E+g*k+y*L,c[4]=p*_+g*A+y*D,c[7]=p*M+g*R+y*U,c[2]=v*E+x*k+w*L,c[5]=v*_+x*A+w*D,c[8]=v*M+x*R+w*U,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[3]*=e,t[6]*=e,t[1]*=e,t[4]*=e,t[7]*=e,t[2]*=e,t[5]*=e,t[8]*=e,this}determinant(){const e=this.elements,t=e[0],r=e[1],a=e[2],c=e[3],u=e[4],d=e[5],h=e[6],p=e[7],g=e[8];return t*u*g-t*d*p-r*c*g+r*d*h+a*c*p-a*u*h}invert(){const e=this.elements,t=e[0],r=e[1],a=e[2],c=e[3],u=e[4],d=e[5],h=e[6],p=e[7],g=e[8],y=g*u-d*p,v=d*h-g*c,x=p*c-u*h,w=t*y+r*v+a*x;if(w===0)return this.set(0,0,0,0,0,0,0,0,0);const E=1/w;return e[0]=y*E,e[1]=(a*p-g*r)*E,e[2]=(d*r-a*u)*E,e[3]=v*E,e[4]=(g*t-a*h)*E,e[5]=(a*c-d*t)*E,e[6]=x*E,e[7]=(r*h-p*t)*E,e[8]=(u*t-r*c)*E,this}transpose(){let e;const t=this.elements;return e=t[1],t[1]=t[3],t[3]=e,e=t[2],t[2]=t[6],t[6]=e,e=t[5],t[5]=t[7],t[7]=e,this}getNormalMatrix(e){return this.setFromMatrix4(e).invert().transpose()}transposeIntoArray(e){const t=this.elements;return e[0]=t[0],e[1]=t[3],e[2]=t[6],e[3]=t[1],e[4]=t[4],e[5]=t[7],e[6]=t[2],e[7]=t[5],e[8]=t[8],this}setUvTransform(e,t,r,a,c,u,d){const h=Math.cos(c),p=Math.sin(c);return this.set(r*h,r*p,-r*(h*u+p*d)+u+e,-a*p,a*h,-a*(-p*u+h*d)+d+t,0,0,1),this}scale(e,t){return this.premultiply(kf.makeScale(e,t)),this}rotate(e){return this.premultiply(kf.makeRotation(-e)),this}translate(e,t){return this.premultiply(kf.makeTranslation(e,t)),this}makeTranslation(e,t){return e.isVector2?this.set(1,0,e.x,0,1,e.y,0,0,1):this.set(1,0,e,0,1,t,0,0,1),this}makeRotation(e){const t=Math.cos(e),r=Math.sin(e);return this.set(t,-r,0,r,t,0,0,0,1),this}makeScale(e,t){return this.set(e,0,0,0,t,0,0,0,1),this}equals(e){const t=this.elements,r=e.elements;for(let a=0;a<9;a++)if(t[a]!==r[a])return!1;return!0}fromArray(e,t=0){for(let r=0;r<9;r++)this.elements[r]=e[r+t];return this}toArray(e=[],t=0){const r=this.elements;return e[t]=r[0],e[t+1]=r[1],e[t+2]=r[2],e[t+3]=r[3],e[t+4]=r[4],e[t+5]=r[5],e[t+6]=r[6],e[t+7]=r[7],e[t+8]=r[8],e}clone(){return new this.constructor().fromArray(this.elements)}}const kf=new dt;function cx(n){for(let e=n.length-1;e>=0;--e)if(n[e]>=65535)return!0;return!1}function vu(n){return document.createElementNS("http://www.w3.org/1999/xhtml",n)}function GT(){const n=vu("canvas");return n.style.display="block",n}const u_={};function ru(n){n in u_||(u_[n]=!0,console.warn(n))}function WT(n,e,t){return new Promise(function(r,a){function c(){switch(n.clientWaitSync(e,n.SYNC_FLUSH_COMMANDS_BIT,0)){case n.WAIT_FAILED:a();break;case n.TIMEOUT_EXPIRED:setTimeout(c,t);break;default:r()}}setTimeout(c,t)})}function $T(n){const e=n.elements;e[2]=.5*e[2]+.5*e[3],e[6]=.5*e[6]+.5*e[7],e[10]=.5*e[10]+.5*e[11],e[14]=.5*e[14]+.5*e[15]}function XT(n){const e=n.elements;e[11]===-1?(e[10]=-e[10]-1,e[14]=-e[14]):(e[10]=-e[10],e[14]=-e[14]+1)}const d_=new dt().set(.8224621,.177538,0,.0331941,.9668058,0,.0170827,.0723974,.9105199),f_=new dt().set(1.2249401,-.2249404,0,-.0420569,1.0420571,0,-.0196376,-.0786361,1.0982735),Wo={[fs]:{transfer:pu,primaries:mu,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n,fromReference:n=>n},[$i]:{transfer:Bt,primaries:mu,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n.convertSRGBToLinear(),fromReference:n=>n.convertLinearToSRGB()},[Fu]:{transfer:pu,primaries:gu,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.applyMatrix3(f_),fromReference:n=>n.applyMatrix3(d_)},[jp]:{transfer:Bt,primaries:gu,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.convertSRGBToLinear().applyMatrix3(f_),fromReference:n=>n.applyMatrix3(d_).convertLinearToSRGB()}},qT=new Set([fs,Fu]),Ct={enabled:!0,_workingColorSpace:fs,get workingColorSpace(){return this._workingColorSpace},set workingColorSpace(n){if(!qT.has(n))throw new Error(`Unsupported working color space, "${n}".`);this._workingColorSpace=n},convert:function(n,e,t){if(this.enabled===!1||e===t||!e||!t)return n;const r=Wo[e].toReference,a=Wo[t].fromReference;return a(r(n))},fromWorkingColorSpace:function(n,e){return this.convert(n,this._workingColorSpace,e)},toWorkingColorSpace:function(n,e){return this.convert(n,e,this._workingColorSpace)},getPrimaries:function(n){return Wo[n].primaries},getTransfer:function(n){return n===is?pu:Wo[n].transfer},getLuminanceCoefficients:function(n,e=this._workingColorSpace){return n.fromArray(Wo[e].luminanceCoefficients)}};function Ga(n){return n<.04045?n*.0773993808:Math.pow(n*.9478672986+.0521327014,2.4)}function Df(n){return n<.0031308?n*12.92:1.055*Math.pow(n,.41666)-.055}let Ta;class YT{static getDataURL(e){if(/^data:/i.test(e.src)||typeof HTMLCanvasElement>"u")return e.src;let t;if(e instanceof HTMLCanvasElement)t=e;else{Ta===void 0&&(Ta=vu("canvas")),Ta.width=e.width,Ta.height=e.height;const r=Ta.getContext("2d");e instanceof ImageData?r.putImageData(e,0,0):r.drawImage(e,0,0,e.width,e.height),t=Ta}return t.width>2048||t.height>2048?(console.warn("THREE.ImageUtils.getDataURL: Image converted to jpg for performance reasons",e),t.toDataURL("image/jpeg",.6)):t.toDataURL("image/png")}static sRGBToLinear(e){if(typeof HTMLImageElement<"u"&&e instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&e instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&e instanceof ImageBitmap){const t=vu("canvas");t.width=e.width,t.height=e.height;const r=t.getContext("2d");r.drawImage(e,0,0,e.width,e.height);const a=r.getImageData(0,0,e.width,e.height),c=a.data;for(let u=0;u<c.length;u++)c[u]=Ga(c[u]/255)*255;return r.putImageData(a,0,0),t}else if(e.data){const t=e.data.slice(0);for(let r=0;r<t.length;r++)t instanceof Uint8Array||t instanceof Uint8ClampedArray?t[r]=Math.floor(Ga(t[r]/255)*255):t[r]=Ga(t[r]);return{data:t,width:e.width,height:e.height}}else return console.warn("THREE.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),e}}let KT=0;class ux{constructor(e=null){this.isSource=!0,Object.defineProperty(this,"id",{value:KT++}),this.uuid=dl(),this.data=e,this.dataReady=!0,this.version=0}set needsUpdate(e){e===!0&&this.version++}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.images[this.uuid]!==void 0)return e.images[this.uuid];const r={uuid:this.uuid,url:""},a=this.data;if(a!==null){let c;if(Array.isArray(a)){c=[];for(let u=0,d=a.length;u<d;u++)a[u].isDataTexture?c.push(If(a[u].image)):c.push(If(a[u]))}else c=If(a);r.url=c}return t||(e.images[this.uuid]=r),r}}function If(n){return typeof HTMLImageElement<"u"&&n instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&n instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&n instanceof ImageBitmap?YT.getDataURL(n):n.data?{data:Array.from(n.data),width:n.width,height:n.height,type:n.data.constructor.name}:(console.warn("THREE.Texture: Unable to serialize Texture."),{})}let ZT=0;class Yn extends ro{constructor(e=Yn.DEFAULT_IMAGE,t=Yn.DEFAULT_MAPPING,r=js,a=js,c=Di,u=zs,d=Oi,h=wr,p=Yn.DEFAULT_ANISOTROPY,g=is){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:ZT++}),this.uuid=dl(),this.name="",this.source=new ux(e),this.mipmaps=[],this.mapping=t,this.channel=0,this.wrapS=r,this.wrapT=a,this.magFilter=c,this.minFilter=u,this.anisotropy=p,this.format=d,this.internalFormat=null,this.type=h,this.offset=new bt(0,0),this.repeat=new bt(1,1),this.center=new bt(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new dt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=g,this.userData={},this.version=0,this.onUpdate=null,this.isRenderTargetTexture=!1,this.pmremVersion=0}get image(){return this.source.data}set image(e=null){this.source.data=e}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}clone(){return new this.constructor().copy(this)}copy(e){return this.name=e.name,this.source=e.source,this.mipmaps=e.mipmaps.slice(0),this.mapping=e.mapping,this.channel=e.channel,this.wrapS=e.wrapS,this.wrapT=e.wrapT,this.magFilter=e.magFilter,this.minFilter=e.minFilter,this.anisotropy=e.anisotropy,this.format=e.format,this.internalFormat=e.internalFormat,this.type=e.type,this.offset.copy(e.offset),this.repeat.copy(e.repeat),this.center.copy(e.center),this.rotation=e.rotation,this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrix.copy(e.matrix),this.generateMipmaps=e.generateMipmaps,this.premultiplyAlpha=e.premultiplyAlpha,this.flipY=e.flipY,this.unpackAlignment=e.unpackAlignment,this.colorSpace=e.colorSpace,this.userData=JSON.parse(JSON.stringify(e.userData)),this.needsUpdate=!0,this}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.textures[this.uuid]!==void 0)return e.textures[this.uuid];const r={metadata:{version:4.6,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(e).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(r.userData=this.userData),t||(e.textures[this.uuid]=r),r}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(e){if(this.mapping!==Zv)return e;if(e.applyMatrix3(this.matrix),e.x<0||e.x>1)switch(this.wrapS){case Lh:e.x=e.x-Math.floor(e.x);break;case js:e.x=e.x<0?0:1;break;case kh:Math.abs(Math.floor(e.x)%2)===1?e.x=Math.ceil(e.x)-e.x:e.x=e.x-Math.floor(e.x);break}if(e.y<0||e.y>1)switch(this.wrapT){case Lh:e.y=e.y-Math.floor(e.y);break;case js:e.y=e.y<0?0:1;break;case kh:Math.abs(Math.floor(e.y)%2)===1?e.y=Math.ceil(e.y)-e.y:e.y=e.y-Math.floor(e.y);break}return this.flipY&&(e.y=1-e.y),e}set needsUpdate(e){e===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(e){e===!0&&this.pmremVersion++}}Yn.DEFAULT_IMAGE=null;Yn.DEFAULT_MAPPING=Zv;Yn.DEFAULT_ANISOTROPY=1;class Qt{constructor(e=0,t=0,r=0,a=1){Qt.prototype.isVector4=!0,this.x=e,this.y=t,this.z=r,this.w=a}get width(){return this.z}set width(e){this.z=e}get height(){return this.w}set height(e){this.w=e}set(e,t,r,a){return this.x=e,this.y=t,this.z=r,this.w=a,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this.w=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setW(e){return this.w=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;case 3:this.w=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w!==void 0?e.w:1,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this.w+=e.w,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this.w+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this.w=e.w+t.w,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this.w+=e.w*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this.w-=e.w,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this.w-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this.w=e.w-t.w,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this.w*=e.w,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this.w*=e,this}applyMatrix4(e){const t=this.x,r=this.y,a=this.z,c=this.w,u=e.elements;return this.x=u[0]*t+u[4]*r+u[8]*a+u[12]*c,this.y=u[1]*t+u[5]*r+u[9]*a+u[13]*c,this.z=u[2]*t+u[6]*r+u[10]*a+u[14]*c,this.w=u[3]*t+u[7]*r+u[11]*a+u[15]*c,this}divideScalar(e){return this.multiplyScalar(1/e)}setAxisAngleFromQuaternion(e){this.w=2*Math.acos(e.w);const t=Math.sqrt(1-e.w*e.w);return t<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=e.x/t,this.y=e.y/t,this.z=e.z/t),this}setAxisAngleFromRotationMatrix(e){let t,r,a,c;const h=e.elements,p=h[0],g=h[4],y=h[8],v=h[1],x=h[5],w=h[9],E=h[2],_=h[6],M=h[10];if(Math.abs(g-v)<.01&&Math.abs(y-E)<.01&&Math.abs(w-_)<.01){if(Math.abs(g+v)<.1&&Math.abs(y+E)<.1&&Math.abs(w+_)<.1&&Math.abs(p+x+M-3)<.1)return this.set(1,0,0,0),this;t=Math.PI;const A=(p+1)/2,R=(x+1)/2,L=(M+1)/2,D=(g+v)/4,U=(y+E)/4,$=(w+_)/4;return A>R&&A>L?A<.01?(r=0,a=.707106781,c=.707106781):(r=Math.sqrt(A),a=D/r,c=U/r):R>L?R<.01?(r=.707106781,a=0,c=.707106781):(a=Math.sqrt(R),r=D/a,c=$/a):L<.01?(r=.707106781,a=.707106781,c=0):(c=Math.sqrt(L),r=U/c,a=$/c),this.set(r,a,c,t),this}let k=Math.sqrt((_-w)*(_-w)+(y-E)*(y-E)+(v-g)*(v-g));return Math.abs(k)<.001&&(k=1),this.x=(_-w)/k,this.y=(y-E)/k,this.z=(v-g)/k,this.w=Math.acos((p+x+M-1)/2),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this.w=t[15],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this.w=Math.min(this.w,e.w),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this.w=Math.max(this.w,e.w),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this.w=Math.max(e.w,Math.min(t.w,this.w)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this.w=Math.max(e,Math.min(t,this.w)),this}clampLength(e,t){const r=this.length();return this.divideScalar(r||1).multiplyScalar(Math.max(e,Math.min(t,r)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z+this.w*e.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this.w+=(e.w-this.w)*t,this}lerpVectors(e,t,r){return this.x=e.x+(t.x-e.x)*r,this.y=e.y+(t.y-e.y)*r,this.z=e.z+(t.z-e.z)*r,this.w=e.w+(t.w-e.w)*r,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z&&e.w===this.w}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this.w=e[t+3],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e[t+3]=this.w,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this.w=e.getW(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}}class QT extends ro{constructor(e=1,t=1,r={}){super(),this.isRenderTarget=!0,this.width=e,this.height=t,this.depth=1,this.scissor=new Qt(0,0,e,t),this.scissorTest=!1,this.viewport=new Qt(0,0,e,t);const a={width:e,height:t,depth:1};r=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Di,depthBuffer:!0,stencilBuffer:!1,resolveDepthBuffer:!0,resolveStencilBuffer:!0,depthTexture:null,samples:0,count:1},r);const c=new Yn(a,r.mapping,r.wrapS,r.wrapT,r.magFilter,r.minFilter,r.format,r.type,r.anisotropy,r.colorSpace);c.flipY=!1,c.generateMipmaps=r.generateMipmaps,c.internalFormat=r.internalFormat,this.textures=[];const u=r.count;for(let d=0;d<u;d++)this.textures[d]=c.clone(),this.textures[d].isRenderTargetTexture=!0;this.depthBuffer=r.depthBuffer,this.stencilBuffer=r.stencilBuffer,this.resolveDepthBuffer=r.resolveDepthBuffer,this.resolveStencilBuffer=r.resolveStencilBuffer,this.depthTexture=r.depthTexture,this.samples=r.samples}get texture(){return this.textures[0]}set texture(e){this.textures[0]=e}setSize(e,t,r=1){if(this.width!==e||this.height!==t||this.depth!==r){this.width=e,this.height=t,this.depth=r;for(let a=0,c=this.textures.length;a<c;a++)this.textures[a].image.width=e,this.textures[a].image.height=t,this.textures[a].image.depth=r;this.dispose()}this.viewport.set(0,0,e,t),this.scissor.set(0,0,e,t)}clone(){return new this.constructor().copy(this)}copy(e){this.width=e.width,this.height=e.height,this.depth=e.depth,this.scissor.copy(e.scissor),this.scissorTest=e.scissorTest,this.viewport.copy(e.viewport),this.textures.length=0;for(let r=0,a=e.textures.length;r<a;r++)this.textures[r]=e.textures[r].clone(),this.textures[r].isRenderTargetTexture=!0;const t=Object.assign({},e.texture.image);return this.texture.source=new ux(t),this.depthBuffer=e.depthBuffer,this.stencilBuffer=e.stencilBuffer,this.resolveDepthBuffer=e.resolveDepthBuffer,this.resolveStencilBuffer=e.resolveStencilBuffer,e.depthTexture!==null&&(this.depthTexture=e.depthTexture.clone()),this.samples=e.samples,this}dispose(){this.dispatchEvent({type:"dispose"})}}class qs extends QT{constructor(e=1,t=1,r={}){super(e,t,r),this.isWebGLRenderTarget=!0}}class dx extends Yn{constructor(e=null,t=1,r=1,a=1){super(null),this.isDataArrayTexture=!0,this.image={data:e,width:t,height:r,depth:a},this.magFilter=Si,this.minFilter=Si,this.wrapR=js,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}addLayerUpdate(e){this.layerUpdates.add(e)}clearLayerUpdates(){this.layerUpdates.clear()}}class JT extends Yn{constructor(e=null,t=1,r=1,a=1){super(null),this.isData3DTexture=!0,this.image={data:e,width:t,height:r,depth:a},this.magFilter=Si,this.minFilter=Si,this.wrapR=js,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}}class fl{constructor(e=0,t=0,r=0,a=1){this.isQuaternion=!0,this._x=e,this._y=t,this._z=r,this._w=a}static slerpFlat(e,t,r,a,c,u,d){let h=r[a+0],p=r[a+1],g=r[a+2],y=r[a+3];const v=c[u+0],x=c[u+1],w=c[u+2],E=c[u+3];if(d===0){e[t+0]=h,e[t+1]=p,e[t+2]=g,e[t+3]=y;return}if(d===1){e[t+0]=v,e[t+1]=x,e[t+2]=w,e[t+3]=E;return}if(y!==E||h!==v||p!==x||g!==w){let _=1-d;const M=h*v+p*x+g*w+y*E,k=M>=0?1:-1,A=1-M*M;if(A>Number.EPSILON){const L=Math.sqrt(A),D=Math.atan2(L,M*k);_=Math.sin(_*D)/L,d=Math.sin(d*D)/L}const R=d*k;if(h=h*_+v*R,p=p*_+x*R,g=g*_+w*R,y=y*_+E*R,_===1-d){const L=1/Math.sqrt(h*h+p*p+g*g+y*y);h*=L,p*=L,g*=L,y*=L}}e[t]=h,e[t+1]=p,e[t+2]=g,e[t+3]=y}static multiplyQuaternionsFlat(e,t,r,a,c,u){const d=r[a],h=r[a+1],p=r[a+2],g=r[a+3],y=c[u],v=c[u+1],x=c[u+2],w=c[u+3];return e[t]=d*w+g*y+h*x-p*v,e[t+1]=h*w+g*v+p*y-d*x,e[t+2]=p*w+g*x+d*v-h*y,e[t+3]=g*w-d*y-h*v-p*x,e}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get w(){return this._w}set w(e){this._w=e,this._onChangeCallback()}set(e,t,r,a){return this._x=e,this._y=t,this._z=r,this._w=a,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(e){return this._x=e.x,this._y=e.y,this._z=e.z,this._w=e.w,this._onChangeCallback(),this}setFromEuler(e,t=!0){const r=e._x,a=e._y,c=e._z,u=e._order,d=Math.cos,h=Math.sin,p=d(r/2),g=d(a/2),y=d(c/2),v=h(r/2),x=h(a/2),w=h(c/2);switch(u){case"XYZ":this._x=v*g*y+p*x*w,this._y=p*x*y-v*g*w,this._z=p*g*w+v*x*y,this._w=p*g*y-v*x*w;break;case"YXZ":this._x=v*g*y+p*x*w,this._y=p*x*y-v*g*w,this._z=p*g*w-v*x*y,this._w=p*g*y+v*x*w;break;case"ZXY":this._x=v*g*y-p*x*w,this._y=p*x*y+v*g*w,this._z=p*g*w+v*x*y,this._w=p*g*y-v*x*w;break;case"ZYX":this._x=v*g*y-p*x*w,this._y=p*x*y+v*g*w,this._z=p*g*w-v*x*y,this._w=p*g*y+v*x*w;break;case"YZX":this._x=v*g*y+p*x*w,this._y=p*x*y+v*g*w,this._z=p*g*w-v*x*y,this._w=p*g*y-v*x*w;break;case"XZY":this._x=v*g*y-p*x*w,this._y=p*x*y-v*g*w,this._z=p*g*w+v*x*y,this._w=p*g*y+v*x*w;break;default:console.warn("THREE.Quaternion: .setFromEuler() encountered an unknown order: "+u)}return t===!0&&this._onChangeCallback(),this}setFromAxisAngle(e,t){const r=t/2,a=Math.sin(r);return this._x=e.x*a,this._y=e.y*a,this._z=e.z*a,this._w=Math.cos(r),this._onChangeCallback(),this}setFromRotationMatrix(e){const t=e.elements,r=t[0],a=t[4],c=t[8],u=t[1],d=t[5],h=t[9],p=t[2],g=t[6],y=t[10],v=r+d+y;if(v>0){const x=.5/Math.sqrt(v+1);this._w=.25/x,this._x=(g-h)*x,this._y=(c-p)*x,this._z=(u-a)*x}else if(r>d&&r>y){const x=2*Math.sqrt(1+r-d-y);this._w=(g-h)/x,this._x=.25*x,this._y=(a+u)/x,this._z=(c+p)/x}else if(d>y){const x=2*Math.sqrt(1+d-r-y);this._w=(c-p)/x,this._x=(a+u)/x,this._y=.25*x,this._z=(h+g)/x}else{const x=2*Math.sqrt(1+y-r-d);this._w=(u-a)/x,this._x=(c+p)/x,this._y=(h+g)/x,this._z=.25*x}return this._onChangeCallback(),this}setFromUnitVectors(e,t){let r=e.dot(t)+1;return r<Number.EPSILON?(r=0,Math.abs(e.x)>Math.abs(e.z)?(this._x=-e.y,this._y=e.x,this._z=0,this._w=r):(this._x=0,this._y=-e.z,this._z=e.y,this._w=r)):(this._x=e.y*t.z-e.z*t.y,this._y=e.z*t.x-e.x*t.z,this._z=e.x*t.y-e.y*t.x,this._w=r),this.normalize()}angleTo(e){return 2*Math.acos(Math.abs(Xn(this.dot(e),-1,1)))}rotateTowards(e,t){const r=this.angleTo(e);if(r===0)return this;const a=Math.min(1,t/r);return this.slerp(e,a),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(e){return this._x*e._x+this._y*e._y+this._z*e._z+this._w*e._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let e=this.length();return e===0?(this._x=0,this._y=0,this._z=0,this._w=1):(e=1/e,this._x=this._x*e,this._y=this._y*e,this._z=this._z*e,this._w=this._w*e),this._onChangeCallback(),this}multiply(e){return this.multiplyQuaternions(this,e)}premultiply(e){return this.multiplyQuaternions(e,this)}multiplyQuaternions(e,t){const r=e._x,a=e._y,c=e._z,u=e._w,d=t._x,h=t._y,p=t._z,g=t._w;return this._x=r*g+u*d+a*p-c*h,this._y=a*g+u*h+c*d-r*p,this._z=c*g+u*p+r*h-a*d,this._w=u*g-r*d-a*h-c*p,this._onChangeCallback(),this}slerp(e,t){if(t===0)return this;if(t===1)return this.copy(e);const r=this._x,a=this._y,c=this._z,u=this._w;let d=u*e._w+r*e._x+a*e._y+c*e._z;if(d<0?(this._w=-e._w,this._x=-e._x,this._y=-e._y,this._z=-e._z,d=-d):this.copy(e),d>=1)return this._w=u,this._x=r,this._y=a,this._z=c,this;const h=1-d*d;if(h<=Number.EPSILON){const x=1-t;return this._w=x*u+t*this._w,this._x=x*r+t*this._x,this._y=x*a+t*this._y,this._z=x*c+t*this._z,this.normalize(),this}const p=Math.sqrt(h),g=Math.atan2(p,d),y=Math.sin((1-t)*g)/p,v=Math.sin(t*g)/p;return this._w=u*y+this._w*v,this._x=r*y+this._x*v,this._y=a*y+this._y*v,this._z=c*y+this._z*v,this._onChangeCallback(),this}slerpQuaternions(e,t,r){return this.copy(e).slerp(t,r)}random(){const e=2*Math.PI*Math.random(),t=2*Math.PI*Math.random(),r=Math.random(),a=Math.sqrt(1-r),c=Math.sqrt(r);return this.set(a*Math.sin(e),a*Math.cos(e),c*Math.sin(t),c*Math.cos(t))}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._w===this._w}fromArray(e,t=0){return this._x=e[t],this._y=e[t+1],this._z=e[t+2],this._w=e[t+3],this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._w,e}fromBufferAttribute(e,t){return this._x=e.getX(t),this._y=e.getY(t),this._z=e.getZ(t),this._w=e.getW(t),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}}class re{constructor(e=0,t=0,r=0){re.prototype.isVector3=!0,this.x=e,this.y=t,this.z=r}set(e,t,r){return r===void 0&&(r=this.z),this.x=e,this.y=t,this.z=r,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this}multiplyVectors(e,t){return this.x=e.x*t.x,this.y=e.y*t.y,this.z=e.z*t.z,this}applyEuler(e){return this.applyQuaternion(h_.setFromEuler(e))}applyAxisAngle(e,t){return this.applyQuaternion(h_.setFromAxisAngle(e,t))}applyMatrix3(e){const t=this.x,r=this.y,a=this.z,c=e.elements;return this.x=c[0]*t+c[3]*r+c[6]*a,this.y=c[1]*t+c[4]*r+c[7]*a,this.z=c[2]*t+c[5]*r+c[8]*a,this}applyNormalMatrix(e){return this.applyMatrix3(e).normalize()}applyMatrix4(e){const t=this.x,r=this.y,a=this.z,c=e.elements,u=1/(c[3]*t+c[7]*r+c[11]*a+c[15]);return this.x=(c[0]*t+c[4]*r+c[8]*a+c[12])*u,this.y=(c[1]*t+c[5]*r+c[9]*a+c[13])*u,this.z=(c[2]*t+c[6]*r+c[10]*a+c[14])*u,this}applyQuaternion(e){const t=this.x,r=this.y,a=this.z,c=e.x,u=e.y,d=e.z,h=e.w,p=2*(u*a-d*r),g=2*(d*t-c*a),y=2*(c*r-u*t);return this.x=t+h*p+u*y-d*g,this.y=r+h*g+d*p-c*y,this.z=a+h*y+c*g-u*p,this}project(e){return this.applyMatrix4(e.matrixWorldInverse).applyMatrix4(e.projectionMatrix)}unproject(e){return this.applyMatrix4(e.projectionMatrixInverse).applyMatrix4(e.matrixWorld)}transformDirection(e){const t=this.x,r=this.y,a=this.z,c=e.elements;return this.x=c[0]*t+c[4]*r+c[8]*a,this.y=c[1]*t+c[5]*r+c[9]*a,this.z=c[2]*t+c[6]*r+c[10]*a,this.normalize()}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this}divideScalar(e){return this.multiplyScalar(1/e)}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this}clampLength(e,t){const r=this.length();return this.divideScalar(r||1).multiplyScalar(Math.max(e,Math.min(t,r)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this}lerpVectors(e,t,r){return this.x=e.x+(t.x-e.x)*r,this.y=e.y+(t.y-e.y)*r,this.z=e.z+(t.z-e.z)*r,this}cross(e){return this.crossVectors(this,e)}crossVectors(e,t){const r=e.x,a=e.y,c=e.z,u=t.x,d=t.y,h=t.z;return this.x=a*h-c*d,this.y=c*u-r*h,this.z=r*d-a*u,this}projectOnVector(e){const t=e.lengthSq();if(t===0)return this.set(0,0,0);const r=e.dot(this)/t;return this.copy(e).multiplyScalar(r)}projectOnPlane(e){return Uf.copy(this).projectOnVector(e),this.sub(Uf)}reflect(e){return this.sub(Uf.copy(e).multiplyScalar(2*this.dot(e)))}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const r=this.dot(e)/t;return Math.acos(Xn(r,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,r=this.y-e.y,a=this.z-e.z;return t*t+r*r+a*a}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)+Math.abs(this.z-e.z)}setFromSpherical(e){return this.setFromSphericalCoords(e.radius,e.phi,e.theta)}setFromSphericalCoords(e,t,r){const a=Math.sin(t)*e;return this.x=a*Math.sin(r),this.y=Math.cos(t)*e,this.z=a*Math.cos(r),this}setFromCylindrical(e){return this.setFromCylindricalCoords(e.radius,e.theta,e.y)}setFromCylindricalCoords(e,t,r){return this.x=e*Math.sin(t),this.y=r,this.z=e*Math.cos(t),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this}setFromMatrixScale(e){const t=this.setFromMatrixColumn(e,0).length(),r=this.setFromMatrixColumn(e,1).length(),a=this.setFromMatrixColumn(e,2).length();return this.x=t,this.y=r,this.z=a,this}setFromMatrixColumn(e,t){return this.fromArray(e.elements,t*4)}setFromMatrix3Column(e,t){return this.fromArray(e.elements,t*3)}setFromEuler(e){return this.x=e._x,this.y=e._y,this.z=e._z,this}setFromColor(e){return this.x=e.r,this.y=e.g,this.z=e.b,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){const e=Math.random()*Math.PI*2,t=Math.random()*2-1,r=Math.sqrt(1-t*t);return this.x=r*Math.cos(e),this.y=t,this.z=r*Math.sin(e),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}}const Uf=new re,h_=new fl;class hl{constructor(e=new re(1/0,1/0,1/0),t=new re(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=e,this.max=t}set(e,t){return this.min.copy(e),this.max.copy(t),this}setFromArray(e){this.makeEmpty();for(let t=0,r=e.length;t<r;t+=3)this.expandByPoint(Pi.fromArray(e,t));return this}setFromBufferAttribute(e){this.makeEmpty();for(let t=0,r=e.count;t<r;t++)this.expandByPoint(Pi.fromBufferAttribute(e,t));return this}setFromPoints(e){this.makeEmpty();for(let t=0,r=e.length;t<r;t++)this.expandByPoint(e[t]);return this}setFromCenterAndSize(e,t){const r=Pi.copy(t).multiplyScalar(.5);return this.min.copy(e).sub(r),this.max.copy(e).add(r),this}setFromObject(e,t=!1){return this.makeEmpty(),this.expandByObject(e,t)}clone(){return new this.constructor().copy(this)}copy(e){return this.min.copy(e.min),this.max.copy(e.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(e){return this.isEmpty()?e.set(0,0,0):e.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(e){return this.isEmpty()?e.set(0,0,0):e.subVectors(this.max,this.min)}expandByPoint(e){return this.min.min(e),this.max.max(e),this}expandByVector(e){return this.min.sub(e),this.max.add(e),this}expandByScalar(e){return this.min.addScalar(-e),this.max.addScalar(e),this}expandByObject(e,t=!1){e.updateWorldMatrix(!1,!1);const r=e.geometry;if(r!==void 0){const c=r.getAttribute("position");if(t===!0&&c!==void 0&&e.isInstancedMesh!==!0)for(let u=0,d=c.count;u<d;u++)e.isMesh===!0?e.getVertexPosition(u,Pi):Pi.fromBufferAttribute(c,u),Pi.applyMatrix4(e.matrixWorld),this.expandByPoint(Pi);else e.boundingBox!==void 0?(e.boundingBox===null&&e.computeBoundingBox(),Ac.copy(e.boundingBox)):(r.boundingBox===null&&r.computeBoundingBox(),Ac.copy(r.boundingBox)),Ac.applyMatrix4(e.matrixWorld),this.union(Ac)}const a=e.children;for(let c=0,u=a.length;c<u;c++)this.expandByObject(a[c],t);return this}containsPoint(e){return e.x>=this.min.x&&e.x<=this.max.x&&e.y>=this.min.y&&e.y<=this.max.y&&e.z>=this.min.z&&e.z<=this.max.z}containsBox(e){return this.min.x<=e.min.x&&e.max.x<=this.max.x&&this.min.y<=e.min.y&&e.max.y<=this.max.y&&this.min.z<=e.min.z&&e.max.z<=this.max.z}getParameter(e,t){return t.set((e.x-this.min.x)/(this.max.x-this.min.x),(e.y-this.min.y)/(this.max.y-this.min.y),(e.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(e){return e.max.x>=this.min.x&&e.min.x<=this.max.x&&e.max.y>=this.min.y&&e.min.y<=this.max.y&&e.max.z>=this.min.z&&e.min.z<=this.max.z}intersectsSphere(e){return this.clampPoint(e.center,Pi),Pi.distanceToSquared(e.center)<=e.radius*e.radius}intersectsPlane(e){let t,r;return e.normal.x>0?(t=e.normal.x*this.min.x,r=e.normal.x*this.max.x):(t=e.normal.x*this.max.x,r=e.normal.x*this.min.x),e.normal.y>0?(t+=e.normal.y*this.min.y,r+=e.normal.y*this.max.y):(t+=e.normal.y*this.max.y,r+=e.normal.y*this.min.y),e.normal.z>0?(t+=e.normal.z*this.min.z,r+=e.normal.z*this.max.z):(t+=e.normal.z*this.max.z,r+=e.normal.z*this.min.z),t<=-e.constant&&r>=-e.constant}intersectsTriangle(e){if(this.isEmpty())return!1;this.getCenter($o),Cc.subVectors(this.max,$o),ba.subVectors(e.a,$o),Aa.subVectors(e.b,$o),Ca.subVectors(e.c,$o),Zr.subVectors(Aa,ba),Qr.subVectors(Ca,Aa),As.subVectors(ba,Ca);let t=[0,-Zr.z,Zr.y,0,-Qr.z,Qr.y,0,-As.z,As.y,Zr.z,0,-Zr.x,Qr.z,0,-Qr.x,As.z,0,-As.x,-Zr.y,Zr.x,0,-Qr.y,Qr.x,0,-As.y,As.x,0];return!Ff(t,ba,Aa,Ca,Cc)||(t=[1,0,0,0,1,0,0,0,1],!Ff(t,ba,Aa,Ca,Cc))?!1:(Nc.crossVectors(Zr,Qr),t=[Nc.x,Nc.y,Nc.z],Ff(t,ba,Aa,Ca,Cc))}clampPoint(e,t){return t.copy(e).clamp(this.min,this.max)}distanceToPoint(e){return this.clampPoint(e,Pi).distanceTo(e)}getBoundingSphere(e){return this.isEmpty()?e.makeEmpty():(this.getCenter(e.center),e.radius=this.getSize(Pi).length()*.5),e}intersect(e){return this.min.max(e.min),this.max.min(e.max),this.isEmpty()&&this.makeEmpty(),this}union(e){return this.min.min(e.min),this.max.max(e.max),this}applyMatrix4(e){return this.isEmpty()?this:(dr[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(e),dr[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(e),dr[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(e),dr[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(e),dr[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(e),dr[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(e),dr[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(e),dr[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(e),this.setFromPoints(dr),this)}translate(e){return this.min.add(e),this.max.add(e),this}equals(e){return e.min.equals(this.min)&&e.max.equals(this.max)}}const dr=[new re,new re,new re,new re,new re,new re,new re,new re],Pi=new re,Ac=new hl,ba=new re,Aa=new re,Ca=new re,Zr=new re,Qr=new re,As=new re,$o=new re,Cc=new re,Nc=new re,Cs=new re;function Ff(n,e,t,r,a){for(let c=0,u=n.length-3;c<=u;c+=3){Cs.fromArray(n,c);const d=a.x*Math.abs(Cs.x)+a.y*Math.abs(Cs.y)+a.z*Math.abs(Cs.z),h=e.dot(Cs),p=t.dot(Cs),g=r.dot(Cs);if(Math.max(-Math.max(h,p,g),Math.min(h,p,g))>d)return!1}return!0}const eb=new hl,Xo=new re,Of=new re;class zp{constructor(e=new re,t=-1){this.isSphere=!0,this.center=e,this.radius=t}set(e,t){return this.center.copy(e),this.radius=t,this}setFromPoints(e,t){const r=this.center;t!==void 0?r.copy(t):eb.setFromPoints(e).getCenter(r);let a=0;for(let c=0,u=e.length;c<u;c++)a=Math.max(a,r.distanceToSquared(e[c]));return this.radius=Math.sqrt(a),this}copy(e){return this.center.copy(e.center),this.radius=e.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(e){return e.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(e){return e.distanceTo(this.center)-this.radius}intersectsSphere(e){const t=this.radius+e.radius;return e.center.distanceToSquared(this.center)<=t*t}intersectsBox(e){return e.intersectsSphere(this)}intersectsPlane(e){return Math.abs(e.distanceToPoint(this.center))<=this.radius}clampPoint(e,t){const r=this.center.distanceToSquared(e);return t.copy(e),r>this.radius*this.radius&&(t.sub(this.center).normalize(),t.multiplyScalar(this.radius).add(this.center)),t}getBoundingBox(e){return this.isEmpty()?(e.makeEmpty(),e):(e.set(this.center,this.center),e.expandByScalar(this.radius),e)}applyMatrix4(e){return this.center.applyMatrix4(e),this.radius=this.radius*e.getMaxScaleOnAxis(),this}translate(e){return this.center.add(e),this}expandByPoint(e){if(this.isEmpty())return this.center.copy(e),this.radius=0,this;Xo.subVectors(e,this.center);const t=Xo.lengthSq();if(t>this.radius*this.radius){const r=Math.sqrt(t),a=(r-this.radius)*.5;this.center.addScaledVector(Xo,a/r),this.radius+=a}return this}union(e){return e.isEmpty()?this:this.isEmpty()?(this.copy(e),this):(this.center.equals(e.center)===!0?this.radius=Math.max(this.radius,e.radius):(Of.subVectors(e.center,this.center).setLength(e.radius),this.expandByPoint(Xo.copy(e.center).add(Of)),this.expandByPoint(Xo.copy(e.center).sub(Of))),this)}equals(e){return e.center.equals(this.center)&&e.radius===this.radius}clone(){return new this.constructor().copy(this)}}const fr=new re,jf=new re,Rc=new re,Jr=new re,zf=new re,Pc=new re,Bf=new re;class tb{constructor(e=new re,t=new re(0,0,-1)){this.origin=e,this.direction=t}set(e,t){return this.origin.copy(e),this.direction.copy(t),this}copy(e){return this.origin.copy(e.origin),this.direction.copy(e.direction),this}at(e,t){return t.copy(this.origin).addScaledVector(this.direction,e)}lookAt(e){return this.direction.copy(e).sub(this.origin).normalize(),this}recast(e){return this.origin.copy(this.at(e,fr)),this}closestPointToPoint(e,t){t.subVectors(e,this.origin);const r=t.dot(this.direction);return r<0?t.copy(this.origin):t.copy(this.origin).addScaledVector(this.direction,r)}distanceToPoint(e){return Math.sqrt(this.distanceSqToPoint(e))}distanceSqToPoint(e){const t=fr.subVectors(e,this.origin).dot(this.direction);return t<0?this.origin.distanceToSquared(e):(fr.copy(this.origin).addScaledVector(this.direction,t),fr.distanceToSquared(e))}distanceSqToSegment(e,t,r,a){jf.copy(e).add(t).multiplyScalar(.5),Rc.copy(t).sub(e).normalize(),Jr.copy(this.origin).sub(jf);const c=e.distanceTo(t)*.5,u=-this.direction.dot(Rc),d=Jr.dot(this.direction),h=-Jr.dot(Rc),p=Jr.lengthSq(),g=Math.abs(1-u*u);let y,v,x,w;if(g>0)if(y=u*h-d,v=u*d-h,w=c*g,y>=0)if(v>=-w)if(v<=w){const E=1/g;y*=E,v*=E,x=y*(y+u*v+2*d)+v*(u*y+v+2*h)+p}else v=c,y=Math.max(0,-(u*v+d)),x=-y*y+v*(v+2*h)+p;else v=-c,y=Math.max(0,-(u*v+d)),x=-y*y+v*(v+2*h)+p;else v<=-w?(y=Math.max(0,-(-u*c+d)),v=y>0?-c:Math.min(Math.max(-c,-h),c),x=-y*y+v*(v+2*h)+p):v<=w?(y=0,v=Math.min(Math.max(-c,-h),c),x=v*(v+2*h)+p):(y=Math.max(0,-(u*c+d)),v=y>0?c:Math.min(Math.max(-c,-h),c),x=-y*y+v*(v+2*h)+p);else v=u>0?-c:c,y=Math.max(0,-(u*v+d)),x=-y*y+v*(v+2*h)+p;return r&&r.copy(this.origin).addScaledVector(this.direction,y),a&&a.copy(jf).addScaledVector(Rc,v),x}intersectSphere(e,t){fr.subVectors(e.center,this.origin);const r=fr.dot(this.direction),a=fr.dot(fr)-r*r,c=e.radius*e.radius;if(a>c)return null;const u=Math.sqrt(c-a),d=r-u,h=r+u;return h<0?null:d<0?this.at(h,t):this.at(d,t)}intersectsSphere(e){return this.distanceSqToPoint(e.center)<=e.radius*e.radius}distanceToPlane(e){const t=e.normal.dot(this.direction);if(t===0)return e.distanceToPoint(this.origin)===0?0:null;const r=-(this.origin.dot(e.normal)+e.constant)/t;return r>=0?r:null}intersectPlane(e,t){const r=this.distanceToPlane(e);return r===null?null:this.at(r,t)}intersectsPlane(e){const t=e.distanceToPoint(this.origin);return t===0||e.normal.dot(this.direction)*t<0}intersectBox(e,t){let r,a,c,u,d,h;const p=1/this.direction.x,g=1/this.direction.y,y=1/this.direction.z,v=this.origin;return p>=0?(r=(e.min.x-v.x)*p,a=(e.max.x-v.x)*p):(r=(e.max.x-v.x)*p,a=(e.min.x-v.x)*p),g>=0?(c=(e.min.y-v.y)*g,u=(e.max.y-v.y)*g):(c=(e.max.y-v.y)*g,u=(e.min.y-v.y)*g),r>u||c>a||((c>r||isNaN(r))&&(r=c),(u<a||isNaN(a))&&(a=u),y>=0?(d=(e.min.z-v.z)*y,h=(e.max.z-v.z)*y):(d=(e.max.z-v.z)*y,h=(e.min.z-v.z)*y),r>h||d>a)||((d>r||r!==r)&&(r=d),(h<a||a!==a)&&(a=h),a<0)?null:this.at(r>=0?r:a,t)}intersectsBox(e){return this.intersectBox(e,fr)!==null}intersectTriangle(e,t,r,a,c){zf.subVectors(t,e),Pc.subVectors(r,e),Bf.crossVectors(zf,Pc);let u=this.direction.dot(Bf),d;if(u>0){if(a)return null;d=1}else if(u<0)d=-1,u=-u;else return null;Jr.subVectors(this.origin,e);const h=d*this.direction.dot(Pc.crossVectors(Jr,Pc));if(h<0)return null;const p=d*this.direction.dot(zf.cross(Jr));if(p<0||h+p>u)return null;const g=-d*Jr.dot(Bf);return g<0?null:this.at(g/u,c)}applyMatrix4(e){return this.origin.applyMatrix4(e),this.direction.transformDirection(e),this}equals(e){return e.origin.equals(this.origin)&&e.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}}class nn{constructor(e,t,r,a,c,u,d,h,p,g,y,v,x,w,E,_){nn.prototype.isMatrix4=!0,this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],e!==void 0&&this.set(e,t,r,a,c,u,d,h,p,g,y,v,x,w,E,_)}set(e,t,r,a,c,u,d,h,p,g,y,v,x,w,E,_){const M=this.elements;return M[0]=e,M[4]=t,M[8]=r,M[12]=a,M[1]=c,M[5]=u,M[9]=d,M[13]=h,M[2]=p,M[6]=g,M[10]=y,M[14]=v,M[3]=x,M[7]=w,M[11]=E,M[15]=_,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new nn().fromArray(this.elements)}copy(e){const t=this.elements,r=e.elements;return t[0]=r[0],t[1]=r[1],t[2]=r[2],t[3]=r[3],t[4]=r[4],t[5]=r[5],t[6]=r[6],t[7]=r[7],t[8]=r[8],t[9]=r[9],t[10]=r[10],t[11]=r[11],t[12]=r[12],t[13]=r[13],t[14]=r[14],t[15]=r[15],this}copyPosition(e){const t=this.elements,r=e.elements;return t[12]=r[12],t[13]=r[13],t[14]=r[14],this}setFromMatrix3(e){const t=e.elements;return this.set(t[0],t[3],t[6],0,t[1],t[4],t[7],0,t[2],t[5],t[8],0,0,0,0,1),this}extractBasis(e,t,r){return e.setFromMatrixColumn(this,0),t.setFromMatrixColumn(this,1),r.setFromMatrixColumn(this,2),this}makeBasis(e,t,r){return this.set(e.x,t.x,r.x,0,e.y,t.y,r.y,0,e.z,t.z,r.z,0,0,0,0,1),this}extractRotation(e){const t=this.elements,r=e.elements,a=1/Na.setFromMatrixColumn(e,0).length(),c=1/Na.setFromMatrixColumn(e,1).length(),u=1/Na.setFromMatrixColumn(e,2).length();return t[0]=r[0]*a,t[1]=r[1]*a,t[2]=r[2]*a,t[3]=0,t[4]=r[4]*c,t[5]=r[5]*c,t[6]=r[6]*c,t[7]=0,t[8]=r[8]*u,t[9]=r[9]*u,t[10]=r[10]*u,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromEuler(e){const t=this.elements,r=e.x,a=e.y,c=e.z,u=Math.cos(r),d=Math.sin(r),h=Math.cos(a),p=Math.sin(a),g=Math.cos(c),y=Math.sin(c);if(e.order==="XYZ"){const v=u*g,x=u*y,w=d*g,E=d*y;t[0]=h*g,t[4]=-h*y,t[8]=p,t[1]=x+w*p,t[5]=v-E*p,t[9]=-d*h,t[2]=E-v*p,t[6]=w+x*p,t[10]=u*h}else if(e.order==="YXZ"){const v=h*g,x=h*y,w=p*g,E=p*y;t[0]=v+E*d,t[4]=w*d-x,t[8]=u*p,t[1]=u*y,t[5]=u*g,t[9]=-d,t[2]=x*d-w,t[6]=E+v*d,t[10]=u*h}else if(e.order==="ZXY"){const v=h*g,x=h*y,w=p*g,E=p*y;t[0]=v-E*d,t[4]=-u*y,t[8]=w+x*d,t[1]=x+w*d,t[5]=u*g,t[9]=E-v*d,t[2]=-u*p,t[6]=d,t[10]=u*h}else if(e.order==="ZYX"){const v=u*g,x=u*y,w=d*g,E=d*y;t[0]=h*g,t[4]=w*p-x,t[8]=v*p+E,t[1]=h*y,t[5]=E*p+v,t[9]=x*p-w,t[2]=-p,t[6]=d*h,t[10]=u*h}else if(e.order==="YZX"){const v=u*h,x=u*p,w=d*h,E=d*p;t[0]=h*g,t[4]=E-v*y,t[8]=w*y+x,t[1]=y,t[5]=u*g,t[9]=-d*g,t[2]=-p*g,t[6]=x*y+w,t[10]=v-E*y}else if(e.order==="XZY"){const v=u*h,x=u*p,w=d*h,E=d*p;t[0]=h*g,t[4]=-y,t[8]=p*g,t[1]=v*y+E,t[5]=u*g,t[9]=x*y-w,t[2]=w*y-x,t[6]=d*g,t[10]=E*y+v}return t[3]=0,t[7]=0,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromQuaternion(e){return this.compose(nb,e,ib)}lookAt(e,t,r){const a=this.elements;return ii.subVectors(e,t),ii.lengthSq()===0&&(ii.z=1),ii.normalize(),es.crossVectors(r,ii),es.lengthSq()===0&&(Math.abs(r.z)===1?ii.x+=1e-4:ii.z+=1e-4,ii.normalize(),es.crossVectors(r,ii)),es.normalize(),Lc.crossVectors(ii,es),a[0]=es.x,a[4]=Lc.x,a[8]=ii.x,a[1]=es.y,a[5]=Lc.y,a[9]=ii.y,a[2]=es.z,a[6]=Lc.z,a[10]=ii.z,this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const r=e.elements,a=t.elements,c=this.elements,u=r[0],d=r[4],h=r[8],p=r[12],g=r[1],y=r[5],v=r[9],x=r[13],w=r[2],E=r[6],_=r[10],M=r[14],k=r[3],A=r[7],R=r[11],L=r[15],D=a[0],U=a[4],$=a[8],te=a[12],T=a[1],P=a[5],se=a[9],J=a[13],ae=a[2],ve=a[6],V=a[10],de=a[14],z=a[3],ue=a[7],oe=a[11],O=a[15];return c[0]=u*D+d*T+h*ae+p*z,c[4]=u*U+d*P+h*ve+p*ue,c[8]=u*$+d*se+h*V+p*oe,c[12]=u*te+d*J+h*de+p*O,c[1]=g*D+y*T+v*ae+x*z,c[5]=g*U+y*P+v*ve+x*ue,c[9]=g*$+y*se+v*V+x*oe,c[13]=g*te+y*J+v*de+x*O,c[2]=w*D+E*T+_*ae+M*z,c[6]=w*U+E*P+_*ve+M*ue,c[10]=w*$+E*se+_*V+M*oe,c[14]=w*te+E*J+_*de+M*O,c[3]=k*D+A*T+R*ae+L*z,c[7]=k*U+A*P+R*ve+L*ue,c[11]=k*$+A*se+R*V+L*oe,c[15]=k*te+A*J+R*de+L*O,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[4]*=e,t[8]*=e,t[12]*=e,t[1]*=e,t[5]*=e,t[9]*=e,t[13]*=e,t[2]*=e,t[6]*=e,t[10]*=e,t[14]*=e,t[3]*=e,t[7]*=e,t[11]*=e,t[15]*=e,this}determinant(){const e=this.elements,t=e[0],r=e[4],a=e[8],c=e[12],u=e[1],d=e[5],h=e[9],p=e[13],g=e[2],y=e[6],v=e[10],x=e[14],w=e[3],E=e[7],_=e[11],M=e[15];return w*(+c*h*y-a*p*y-c*d*v+r*p*v+a*d*x-r*h*x)+E*(+t*h*x-t*p*v+c*u*v-a*u*x+a*p*g-c*h*g)+_*(+t*p*y-t*d*x-c*u*y+r*u*x+c*d*g-r*p*g)+M*(-a*d*g-t*h*y+t*d*v+a*u*y-r*u*v+r*h*g)}transpose(){const e=this.elements;let t;return t=e[1],e[1]=e[4],e[4]=t,t=e[2],e[2]=e[8],e[8]=t,t=e[6],e[6]=e[9],e[9]=t,t=e[3],e[3]=e[12],e[12]=t,t=e[7],e[7]=e[13],e[13]=t,t=e[11],e[11]=e[14],e[14]=t,this}setPosition(e,t,r){const a=this.elements;return e.isVector3?(a[12]=e.x,a[13]=e.y,a[14]=e.z):(a[12]=e,a[13]=t,a[14]=r),this}invert(){const e=this.elements,t=e[0],r=e[1],a=e[2],c=e[3],u=e[4],d=e[5],h=e[6],p=e[7],g=e[8],y=e[9],v=e[10],x=e[11],w=e[12],E=e[13],_=e[14],M=e[15],k=y*_*p-E*v*p+E*h*x-d*_*x-y*h*M+d*v*M,A=w*v*p-g*_*p-w*h*x+u*_*x+g*h*M-u*v*M,R=g*E*p-w*y*p+w*d*x-u*E*x-g*d*M+u*y*M,L=w*y*h-g*E*h-w*d*v+u*E*v+g*d*_-u*y*_,D=t*k+r*A+a*R+c*L;if(D===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);const U=1/D;return e[0]=k*U,e[1]=(E*v*c-y*_*c-E*a*x+r*_*x+y*a*M-r*v*M)*U,e[2]=(d*_*c-E*h*c+E*a*p-r*_*p-d*a*M+r*h*M)*U,e[3]=(y*h*c-d*v*c-y*a*p+r*v*p+d*a*x-r*h*x)*U,e[4]=A*U,e[5]=(g*_*c-w*v*c+w*a*x-t*_*x-g*a*M+t*v*M)*U,e[6]=(w*h*c-u*_*c-w*a*p+t*_*p+u*a*M-t*h*M)*U,e[7]=(u*v*c-g*h*c+g*a*p-t*v*p-u*a*x+t*h*x)*U,e[8]=R*U,e[9]=(w*y*c-g*E*c-w*r*x+t*E*x+g*r*M-t*y*M)*U,e[10]=(u*E*c-w*d*c+w*r*p-t*E*p-u*r*M+t*d*M)*U,e[11]=(g*d*c-u*y*c-g*r*p+t*y*p+u*r*x-t*d*x)*U,e[12]=L*U,e[13]=(g*E*a-w*y*a+w*r*v-t*E*v-g*r*_+t*y*_)*U,e[14]=(w*d*a-u*E*a-w*r*h+t*E*h+u*r*_-t*d*_)*U,e[15]=(u*y*a-g*d*a+g*r*h-t*y*h-u*r*v+t*d*v)*U,this}scale(e){const t=this.elements,r=e.x,a=e.y,c=e.z;return t[0]*=r,t[4]*=a,t[8]*=c,t[1]*=r,t[5]*=a,t[9]*=c,t[2]*=r,t[6]*=a,t[10]*=c,t[3]*=r,t[7]*=a,t[11]*=c,this}getMaxScaleOnAxis(){const e=this.elements,t=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],r=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],a=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];return Math.sqrt(Math.max(t,r,a))}makeTranslation(e,t,r){return e.isVector3?this.set(1,0,0,e.x,0,1,0,e.y,0,0,1,e.z,0,0,0,1):this.set(1,0,0,e,0,1,0,t,0,0,1,r,0,0,0,1),this}makeRotationX(e){const t=Math.cos(e),r=Math.sin(e);return this.set(1,0,0,0,0,t,-r,0,0,r,t,0,0,0,0,1),this}makeRotationY(e){const t=Math.cos(e),r=Math.sin(e);return this.set(t,0,r,0,0,1,0,0,-r,0,t,0,0,0,0,1),this}makeRotationZ(e){const t=Math.cos(e),r=Math.sin(e);return this.set(t,-r,0,0,r,t,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(e,t){const r=Math.cos(t),a=Math.sin(t),c=1-r,u=e.x,d=e.y,h=e.z,p=c*u,g=c*d;return this.set(p*u+r,p*d-a*h,p*h+a*d,0,p*d+a*h,g*d+r,g*h-a*u,0,p*h-a*d,g*h+a*u,c*h*h+r,0,0,0,0,1),this}makeScale(e,t,r){return this.set(e,0,0,0,0,t,0,0,0,0,r,0,0,0,0,1),this}makeShear(e,t,r,a,c,u){return this.set(1,r,c,0,e,1,u,0,t,a,1,0,0,0,0,1),this}compose(e,t,r){const a=this.elements,c=t._x,u=t._y,d=t._z,h=t._w,p=c+c,g=u+u,y=d+d,v=c*p,x=c*g,w=c*y,E=u*g,_=u*y,M=d*y,k=h*p,A=h*g,R=h*y,L=r.x,D=r.y,U=r.z;return a[0]=(1-(E+M))*L,a[1]=(x+R)*L,a[2]=(w-A)*L,a[3]=0,a[4]=(x-R)*D,a[5]=(1-(v+M))*D,a[6]=(_+k)*D,a[7]=0,a[8]=(w+A)*U,a[9]=(_-k)*U,a[10]=(1-(v+E))*U,a[11]=0,a[12]=e.x,a[13]=e.y,a[14]=e.z,a[15]=1,this}decompose(e,t,r){const a=this.elements;let c=Na.set(a[0],a[1],a[2]).length();const u=Na.set(a[4],a[5],a[6]).length(),d=Na.set(a[8],a[9],a[10]).length();this.determinant()<0&&(c=-c),e.x=a[12],e.y=a[13],e.z=a[14],Li.copy(this);const p=1/c,g=1/u,y=1/d;return Li.elements[0]*=p,Li.elements[1]*=p,Li.elements[2]*=p,Li.elements[4]*=g,Li.elements[5]*=g,Li.elements[6]*=g,Li.elements[8]*=y,Li.elements[9]*=y,Li.elements[10]*=y,t.setFromRotationMatrix(Li),r.x=c,r.y=u,r.z=d,this}makePerspective(e,t,r,a,c,u,d=yr){const h=this.elements,p=2*c/(t-e),g=2*c/(r-a),y=(t+e)/(t-e),v=(r+a)/(r-a);let x,w;if(d===yr)x=-(u+c)/(u-c),w=-2*u*c/(u-c);else if(d===_u)x=-u/(u-c),w=-u*c/(u-c);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+d);return h[0]=p,h[4]=0,h[8]=y,h[12]=0,h[1]=0,h[5]=g,h[9]=v,h[13]=0,h[2]=0,h[6]=0,h[10]=x,h[14]=w,h[3]=0,h[7]=0,h[11]=-1,h[15]=0,this}makeOrthographic(e,t,r,a,c,u,d=yr){const h=this.elements,p=1/(t-e),g=1/(r-a),y=1/(u-c),v=(t+e)*p,x=(r+a)*g;let w,E;if(d===yr)w=(u+c)*y,E=-2*y;else if(d===_u)w=c*y,E=-1*y;else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+d);return h[0]=2*p,h[4]=0,h[8]=0,h[12]=-v,h[1]=0,h[5]=2*g,h[9]=0,h[13]=-x,h[2]=0,h[6]=0,h[10]=E,h[14]=-w,h[3]=0,h[7]=0,h[11]=0,h[15]=1,this}equals(e){const t=this.elements,r=e.elements;for(let a=0;a<16;a++)if(t[a]!==r[a])return!1;return!0}fromArray(e,t=0){for(let r=0;r<16;r++)this.elements[r]=e[r+t];return this}toArray(e=[],t=0){const r=this.elements;return e[t]=r[0],e[t+1]=r[1],e[t+2]=r[2],e[t+3]=r[3],e[t+4]=r[4],e[t+5]=r[5],e[t+6]=r[6],e[t+7]=r[7],e[t+8]=r[8],e[t+9]=r[9],e[t+10]=r[10],e[t+11]=r[11],e[t+12]=r[12],e[t+13]=r[13],e[t+14]=r[14],e[t+15]=r[15],e}}const Na=new re,Li=new nn,nb=new re(0,0,0),ib=new re(1,1,1),es=new re,Lc=new re,ii=new re,p_=new nn,m_=new fl;class Tr{constructor(e=0,t=0,r=0,a=Tr.DEFAULT_ORDER){this.isEuler=!0,this._x=e,this._y=t,this._z=r,this._order=a}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get order(){return this._order}set order(e){this._order=e,this._onChangeCallback()}set(e,t,r,a=this._order){return this._x=e,this._y=t,this._z=r,this._order=a,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(e){return this._x=e._x,this._y=e._y,this._z=e._z,this._order=e._order,this._onChangeCallback(),this}setFromRotationMatrix(e,t=this._order,r=!0){const a=e.elements,c=a[0],u=a[4],d=a[8],h=a[1],p=a[5],g=a[9],y=a[2],v=a[6],x=a[10];switch(t){case"XYZ":this._y=Math.asin(Xn(d,-1,1)),Math.abs(d)<.9999999?(this._x=Math.atan2(-g,x),this._z=Math.atan2(-u,c)):(this._x=Math.atan2(v,p),this._z=0);break;case"YXZ":this._x=Math.asin(-Xn(g,-1,1)),Math.abs(g)<.9999999?(this._y=Math.atan2(d,x),this._z=Math.atan2(h,p)):(this._y=Math.atan2(-y,c),this._z=0);break;case"ZXY":this._x=Math.asin(Xn(v,-1,1)),Math.abs(v)<.9999999?(this._y=Math.atan2(-y,x),this._z=Math.atan2(-u,p)):(this._y=0,this._z=Math.atan2(h,c));break;case"ZYX":this._y=Math.asin(-Xn(y,-1,1)),Math.abs(y)<.9999999?(this._x=Math.atan2(v,x),this._z=Math.atan2(h,c)):(this._x=0,this._z=Math.atan2(-u,p));break;case"YZX":this._z=Math.asin(Xn(h,-1,1)),Math.abs(h)<.9999999?(this._x=Math.atan2(-g,p),this._y=Math.atan2(-y,c)):(this._x=0,this._y=Math.atan2(d,x));break;case"XZY":this._z=Math.asin(-Xn(u,-1,1)),Math.abs(u)<.9999999?(this._x=Math.atan2(v,p),this._y=Math.atan2(d,c)):(this._x=Math.atan2(-g,x),this._y=0);break;default:console.warn("THREE.Euler: .setFromRotationMatrix() encountered an unknown order: "+t)}return this._order=t,r===!0&&this._onChangeCallback(),this}setFromQuaternion(e,t,r){return p_.makeRotationFromQuaternion(e),this.setFromRotationMatrix(p_,t,r)}setFromVector3(e,t=this._order){return this.set(e.x,e.y,e.z,t)}reorder(e){return m_.setFromEuler(this),this.setFromQuaternion(m_,e)}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._order===this._order}fromArray(e){return this._x=e[0],this._y=e[1],this._z=e[2],e[3]!==void 0&&(this._order=e[3]),this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._order,e}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}}Tr.DEFAULT_ORDER="XYZ";class fx{constructor(){this.mask=1}set(e){this.mask=(1<<e|0)>>>0}enable(e){this.mask|=1<<e|0}enableAll(){this.mask=-1}toggle(e){this.mask^=1<<e|0}disable(e){this.mask&=~(1<<e|0)}disableAll(){this.mask=0}test(e){return(this.mask&e.mask)!==0}isEnabled(e){return(this.mask&(1<<e|0))!==0}}let rb=0;const g_=new re,Ra=new fl,hr=new nn,kc=new re,qo=new re,sb=new re,ab=new fl,__=new re(1,0,0),v_=new re(0,1,0),x_=new re(0,0,1),y_={type:"added"},ob={type:"removed"},Pa={type:"childadded",child:null},Hf={type:"childremoved",child:null};class oi extends ro{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:rb++}),this.uuid=dl(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=oi.DEFAULT_UP.clone();const e=new re,t=new Tr,r=new fl,a=new re(1,1,1);function c(){r.setFromEuler(t,!1)}function u(){t.setFromQuaternion(r,void 0,!1)}t._onChange(c),r._onChange(u),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:e},rotation:{configurable:!0,enumerable:!0,value:t},quaternion:{configurable:!0,enumerable:!0,value:r},scale:{configurable:!0,enumerable:!0,value:a},modelViewMatrix:{value:new nn},normalMatrix:{value:new dt}}),this.matrix=new nn,this.matrixWorld=new nn,this.matrixAutoUpdate=oi.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=oi.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new fx,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.userData={}}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(e){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(e),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(e){return this.quaternion.premultiply(e),this}setRotationFromAxisAngle(e,t){this.quaternion.setFromAxisAngle(e,t)}setRotationFromEuler(e){this.quaternion.setFromEuler(e,!0)}setRotationFromMatrix(e){this.quaternion.setFromRotationMatrix(e)}setRotationFromQuaternion(e){this.quaternion.copy(e)}rotateOnAxis(e,t){return Ra.setFromAxisAngle(e,t),this.quaternion.multiply(Ra),this}rotateOnWorldAxis(e,t){return Ra.setFromAxisAngle(e,t),this.quaternion.premultiply(Ra),this}rotateX(e){return this.rotateOnAxis(__,e)}rotateY(e){return this.rotateOnAxis(v_,e)}rotateZ(e){return this.rotateOnAxis(x_,e)}translateOnAxis(e,t){return g_.copy(e).applyQuaternion(this.quaternion),this.position.add(g_.multiplyScalar(t)),this}translateX(e){return this.translateOnAxis(__,e)}translateY(e){return this.translateOnAxis(v_,e)}translateZ(e){return this.translateOnAxis(x_,e)}localToWorld(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(this.matrixWorld)}worldToLocal(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(hr.copy(this.matrixWorld).invert())}lookAt(e,t,r){e.isVector3?kc.copy(e):kc.set(e,t,r);const a=this.parent;this.updateWorldMatrix(!0,!1),qo.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?hr.lookAt(qo,kc,this.up):hr.lookAt(kc,qo,this.up),this.quaternion.setFromRotationMatrix(hr),a&&(hr.extractRotation(a.matrixWorld),Ra.setFromRotationMatrix(hr),this.quaternion.premultiply(Ra.invert()))}add(e){if(arguments.length>1){for(let t=0;t<arguments.length;t++)this.add(arguments[t]);return this}return e===this?(console.error("THREE.Object3D.add: object can't be added as a child of itself.",e),this):(e&&e.isObject3D?(e.removeFromParent(),e.parent=this,this.children.push(e),e.dispatchEvent(y_),Pa.child=e,this.dispatchEvent(Pa),Pa.child=null):console.error("THREE.Object3D.add: object not an instance of THREE.Object3D.",e),this)}remove(e){if(arguments.length>1){for(let r=0;r<arguments.length;r++)this.remove(arguments[r]);return this}const t=this.children.indexOf(e);return t!==-1&&(e.parent=null,this.children.splice(t,1),e.dispatchEvent(ob),Hf.child=e,this.dispatchEvent(Hf),Hf.child=null),this}removeFromParent(){const e=this.parent;return e!==null&&e.remove(this),this}clear(){return this.remove(...this.children)}attach(e){return this.updateWorldMatrix(!0,!1),hr.copy(this.matrixWorld).invert(),e.parent!==null&&(e.parent.updateWorldMatrix(!0,!1),hr.multiply(e.parent.matrixWorld)),e.applyMatrix4(hr),e.removeFromParent(),e.parent=this,this.children.push(e),e.updateWorldMatrix(!1,!0),e.dispatchEvent(y_),Pa.child=e,this.dispatchEvent(Pa),Pa.child=null,this}getObjectById(e){return this.getObjectByProperty("id",e)}getObjectByName(e){return this.getObjectByProperty("name",e)}getObjectByProperty(e,t){if(this[e]===t)return this;for(let r=0,a=this.children.length;r<a;r++){const u=this.children[r].getObjectByProperty(e,t);if(u!==void 0)return u}}getObjectsByProperty(e,t,r=[]){this[e]===t&&r.push(this);const a=this.children;for(let c=0,u=a.length;c<u;c++)a[c].getObjectsByProperty(e,t,r);return r}getWorldPosition(e){return this.updateWorldMatrix(!0,!1),e.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(qo,e,sb),e}getWorldScale(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(qo,ab,e),e}getWorldDirection(e){this.updateWorldMatrix(!0,!1);const t=this.matrixWorld.elements;return e.set(t[8],t[9],t[10]).normalize()}raycast(){}traverse(e){e(this);const t=this.children;for(let r=0,a=t.length;r<a;r++)t[r].traverse(e)}traverseVisible(e){if(this.visible===!1)return;e(this);const t=this.children;for(let r=0,a=t.length;r<a;r++)t[r].traverseVisible(e)}traverseAncestors(e){const t=this.parent;t!==null&&(e(t),t.traverseAncestors(e))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale),this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(e){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||e)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,e=!0);const t=this.children;for(let r=0,a=t.length;r<a;r++)t[r].updateMatrixWorld(e)}updateWorldMatrix(e,t){const r=this.parent;if(e===!0&&r!==null&&r.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),t===!0){const a=this.children;for(let c=0,u=a.length;c<u;c++)a[c].updateWorldMatrix(!1,!0)}}toJSON(e){const t=e===void 0||typeof e=="string",r={};t&&(e={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},r.metadata={version:4.6,type:"Object",generator:"Object3D.toJSON"});const a={};a.uuid=this.uuid,a.type=this.type,this.name!==""&&(a.name=this.name),this.castShadow===!0&&(a.castShadow=!0),this.receiveShadow===!0&&(a.receiveShadow=!0),this.visible===!1&&(a.visible=!1),this.frustumCulled===!1&&(a.frustumCulled=!1),this.renderOrder!==0&&(a.renderOrder=this.renderOrder),Object.keys(this.userData).length>0&&(a.userData=this.userData),a.layers=this.layers.mask,a.matrix=this.matrix.toArray(),a.up=this.up.toArray(),this.matrixAutoUpdate===!1&&(a.matrixAutoUpdate=!1),this.isInstancedMesh&&(a.type="InstancedMesh",a.count=this.count,a.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(a.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(a.type="BatchedMesh",a.perObjectFrustumCulled=this.perObjectFrustumCulled,a.sortObjects=this.sortObjects,a.drawRanges=this._drawRanges,a.reservedRanges=this._reservedRanges,a.visibility=this._visibility,a.active=this._active,a.bounds=this._bounds.map(d=>({boxInitialized:d.boxInitialized,boxMin:d.box.min.toArray(),boxMax:d.box.max.toArray(),sphereInitialized:d.sphereInitialized,sphereRadius:d.sphere.radius,sphereCenter:d.sphere.center.toArray()})),a.maxInstanceCount=this._maxInstanceCount,a.maxVertexCount=this._maxVertexCount,a.maxIndexCount=this._maxIndexCount,a.geometryInitialized=this._geometryInitialized,a.geometryCount=this._geometryCount,a.matricesTexture=this._matricesTexture.toJSON(e),this._colorsTexture!==null&&(a.colorsTexture=this._colorsTexture.toJSON(e)),this.boundingSphere!==null&&(a.boundingSphere={center:a.boundingSphere.center.toArray(),radius:a.boundingSphere.radius}),this.boundingBox!==null&&(a.boundingBox={min:a.boundingBox.min.toArray(),max:a.boundingBox.max.toArray()}));function c(d,h){return d[h.uuid]===void 0&&(d[h.uuid]=h.toJSON(e)),h.uuid}if(this.isScene)this.background&&(this.background.isColor?a.background=this.background.toJSON():this.background.isTexture&&(a.background=this.background.toJSON(e).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(a.environment=this.environment.toJSON(e).uuid);else if(this.isMesh||this.isLine||this.isPoints){a.geometry=c(e.geometries,this.geometry);const d=this.geometry.parameters;if(d!==void 0&&d.shapes!==void 0){const h=d.shapes;if(Array.isArray(h))for(let p=0,g=h.length;p<g;p++){const y=h[p];c(e.shapes,y)}else c(e.shapes,h)}}if(this.isSkinnedMesh&&(a.bindMode=this.bindMode,a.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(c(e.skeletons,this.skeleton),a.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){const d=[];for(let h=0,p=this.material.length;h<p;h++)d.push(c(e.materials,this.material[h]));a.material=d}else a.material=c(e.materials,this.material);if(this.children.length>0){a.children=[];for(let d=0;d<this.children.length;d++)a.children.push(this.children[d].toJSON(e).object)}if(this.animations.length>0){a.animations=[];for(let d=0;d<this.animations.length;d++){const h=this.animations[d];a.animations.push(c(e.animations,h))}}if(t){const d=u(e.geometries),h=u(e.materials),p=u(e.textures),g=u(e.images),y=u(e.shapes),v=u(e.skeletons),x=u(e.animations),w=u(e.nodes);d.length>0&&(r.geometries=d),h.length>0&&(r.materials=h),p.length>0&&(r.textures=p),g.length>0&&(r.images=g),y.length>0&&(r.shapes=y),v.length>0&&(r.skeletons=v),x.length>0&&(r.animations=x),w.length>0&&(r.nodes=w)}return r.object=a,r;function u(d){const h=[];for(const p in d){const g=d[p];delete g.metadata,h.push(g)}return h}}clone(e){return new this.constructor().copy(this,e)}copy(e,t=!0){if(this.name=e.name,this.up.copy(e.up),this.position.copy(e.position),this.rotation.order=e.rotation.order,this.quaternion.copy(e.quaternion),this.scale.copy(e.scale),this.matrix.copy(e.matrix),this.matrixWorld.copy(e.matrixWorld),this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrixWorldAutoUpdate=e.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=e.matrixWorldNeedsUpdate,this.layers.mask=e.layers.mask,this.visible=e.visible,this.castShadow=e.castShadow,this.receiveShadow=e.receiveShadow,this.frustumCulled=e.frustumCulled,this.renderOrder=e.renderOrder,this.animations=e.animations.slice(),this.userData=JSON.parse(JSON.stringify(e.userData)),t===!0)for(let r=0;r<e.children.length;r++){const a=e.children[r];this.add(a.clone())}return this}}oi.DEFAULT_UP=new re(0,1,0);oi.DEFAULT_MATRIX_AUTO_UPDATE=!0;oi.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;const ki=new re,pr=new re,Vf=new re,mr=new re,La=new re,ka=new re,S_=new re,Gf=new re,Wf=new re,$f=new re,Xf=new Qt,qf=new Qt,Yf=new Qt;class Ii{constructor(e=new re,t=new re,r=new re){this.a=e,this.b=t,this.c=r}static getNormal(e,t,r,a){a.subVectors(r,t),ki.subVectors(e,t),a.cross(ki);const c=a.lengthSq();return c>0?a.multiplyScalar(1/Math.sqrt(c)):a.set(0,0,0)}static getBarycoord(e,t,r,a,c){ki.subVectors(a,t),pr.subVectors(r,t),Vf.subVectors(e,t);const u=ki.dot(ki),d=ki.dot(pr),h=ki.dot(Vf),p=pr.dot(pr),g=pr.dot(Vf),y=u*p-d*d;if(y===0)return c.set(0,0,0),null;const v=1/y,x=(p*h-d*g)*v,w=(u*g-d*h)*v;return c.set(1-x-w,w,x)}static containsPoint(e,t,r,a){return this.getBarycoord(e,t,r,a,mr)===null?!1:mr.x>=0&&mr.y>=0&&mr.x+mr.y<=1}static getInterpolation(e,t,r,a,c,u,d,h){return this.getBarycoord(e,t,r,a,mr)===null?(h.x=0,h.y=0,"z"in h&&(h.z=0),"w"in h&&(h.w=0),null):(h.setScalar(0),h.addScaledVector(c,mr.x),h.addScaledVector(u,mr.y),h.addScaledVector(d,mr.z),h)}static getInterpolatedAttribute(e,t,r,a,c,u){return Xf.setScalar(0),qf.setScalar(0),Yf.setScalar(0),Xf.fromBufferAttribute(e,t),qf.fromBufferAttribute(e,r),Yf.fromBufferAttribute(e,a),u.setScalar(0),u.addScaledVector(Xf,c.x),u.addScaledVector(qf,c.y),u.addScaledVector(Yf,c.z),u}static isFrontFacing(e,t,r,a){return ki.subVectors(r,t),pr.subVectors(e,t),ki.cross(pr).dot(a)<0}set(e,t,r){return this.a.copy(e),this.b.copy(t),this.c.copy(r),this}setFromPointsAndIndices(e,t,r,a){return this.a.copy(e[t]),this.b.copy(e[r]),this.c.copy(e[a]),this}setFromAttributeAndIndices(e,t,r,a){return this.a.fromBufferAttribute(e,t),this.b.fromBufferAttribute(e,r),this.c.fromBufferAttribute(e,a),this}clone(){return new this.constructor().copy(this)}copy(e){return this.a.copy(e.a),this.b.copy(e.b),this.c.copy(e.c),this}getArea(){return ki.subVectors(this.c,this.b),pr.subVectors(this.a,this.b),ki.cross(pr).length()*.5}getMidpoint(e){return e.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(e){return Ii.getNormal(this.a,this.b,this.c,e)}getPlane(e){return e.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(e,t){return Ii.getBarycoord(e,this.a,this.b,this.c,t)}getInterpolation(e,t,r,a,c){return Ii.getInterpolation(e,this.a,this.b,this.c,t,r,a,c)}containsPoint(e){return Ii.containsPoint(e,this.a,this.b,this.c)}isFrontFacing(e){return Ii.isFrontFacing(this.a,this.b,this.c,e)}intersectsBox(e){return e.intersectsTriangle(this)}closestPointToPoint(e,t){const r=this.a,a=this.b,c=this.c;let u,d;La.subVectors(a,r),ka.subVectors(c,r),Gf.subVectors(e,r);const h=La.dot(Gf),p=ka.dot(Gf);if(h<=0&&p<=0)return t.copy(r);Wf.subVectors(e,a);const g=La.dot(Wf),y=ka.dot(Wf);if(g>=0&&y<=g)return t.copy(a);const v=h*y-g*p;if(v<=0&&h>=0&&g<=0)return u=h/(h-g),t.copy(r).addScaledVector(La,u);$f.subVectors(e,c);const x=La.dot($f),w=ka.dot($f);if(w>=0&&x<=w)return t.copy(c);const E=x*p-h*w;if(E<=0&&p>=0&&w<=0)return d=p/(p-w),t.copy(r).addScaledVector(ka,d);const _=g*w-x*y;if(_<=0&&y-g>=0&&x-w>=0)return S_.subVectors(c,a),d=(y-g)/(y-g+(x-w)),t.copy(a).addScaledVector(S_,d);const M=1/(_+E+v);return u=E*M,d=v*M,t.copy(r).addScaledVector(La,u).addScaledVector(ka,d)}equals(e){return e.a.equals(this.a)&&e.b.equals(this.b)&&e.c.equals(this.c)}}const hx={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},ts={h:0,s:0,l:0},Dc={h:0,s:0,l:0};function Kf(n,e,t){return t<0&&(t+=1),t>1&&(t-=1),t<1/6?n+(e-n)*6*t:t<1/2?e:t<2/3?n+(e-n)*6*(2/3-t):n}class Rt{constructor(e,t,r){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(e,t,r)}set(e,t,r){if(t===void 0&&r===void 0){const a=e;a&&a.isColor?this.copy(a):typeof a=="number"?this.setHex(a):typeof a=="string"&&this.setStyle(a)}else this.setRGB(e,t,r);return this}setScalar(e){return this.r=e,this.g=e,this.b=e,this}setHex(e,t=$i){return e=Math.floor(e),this.r=(e>>16&255)/255,this.g=(e>>8&255)/255,this.b=(e&255)/255,Ct.toWorkingColorSpace(this,t),this}setRGB(e,t,r,a=Ct.workingColorSpace){return this.r=e,this.g=t,this.b=r,Ct.toWorkingColorSpace(this,a),this}setHSL(e,t,r,a=Ct.workingColorSpace){if(e=VT(e,1),t=Xn(t,0,1),r=Xn(r,0,1),t===0)this.r=this.g=this.b=r;else{const c=r<=.5?r*(1+t):r+t-r*t,u=2*r-c;this.r=Kf(u,c,e+1/3),this.g=Kf(u,c,e),this.b=Kf(u,c,e-1/3)}return Ct.toWorkingColorSpace(this,a),this}setStyle(e,t=$i){function r(c){c!==void 0&&parseFloat(c)<1&&console.warn("THREE.Color: Alpha component of "+e+" will be ignored.")}let a;if(a=/^(\w+)\(([^\)]*)\)/.exec(e)){let c;const u=a[1],d=a[2];switch(u){case"rgb":case"rgba":if(c=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return r(c[4]),this.setRGB(Math.min(255,parseInt(c[1],10))/255,Math.min(255,parseInt(c[2],10))/255,Math.min(255,parseInt(c[3],10))/255,t);if(c=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return r(c[4]),this.setRGB(Math.min(100,parseInt(c[1],10))/100,Math.min(100,parseInt(c[2],10))/100,Math.min(100,parseInt(c[3],10))/100,t);break;case"hsl":case"hsla":if(c=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(d))return r(c[4]),this.setHSL(parseFloat(c[1])/360,parseFloat(c[2])/100,parseFloat(c[3])/100,t);break;default:console.warn("THREE.Color: Unknown color model "+e)}}else if(a=/^\#([A-Fa-f\d]+)$/.exec(e)){const c=a[1],u=c.length;if(u===3)return this.setRGB(parseInt(c.charAt(0),16)/15,parseInt(c.charAt(1),16)/15,parseInt(c.charAt(2),16)/15,t);if(u===6)return this.setHex(parseInt(c,16),t);console.warn("THREE.Color: Invalid hex color "+e)}else if(e&&e.length>0)return this.setColorName(e,t);return this}setColorName(e,t=$i){const r=hx[e.toLowerCase()];return r!==void 0?this.setHex(r,t):console.warn("THREE.Color: Unknown color "+e),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(e){return this.r=e.r,this.g=e.g,this.b=e.b,this}copySRGBToLinear(e){return this.r=Ga(e.r),this.g=Ga(e.g),this.b=Ga(e.b),this}copyLinearToSRGB(e){return this.r=Df(e.r),this.g=Df(e.g),this.b=Df(e.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(e=$i){return Ct.fromWorkingColorSpace(Rn.copy(this),e),Math.round(Xn(Rn.r*255,0,255))*65536+Math.round(Xn(Rn.g*255,0,255))*256+Math.round(Xn(Rn.b*255,0,255))}getHexString(e=$i){return("000000"+this.getHex(e).toString(16)).slice(-6)}getHSL(e,t=Ct.workingColorSpace){Ct.fromWorkingColorSpace(Rn.copy(this),t);const r=Rn.r,a=Rn.g,c=Rn.b,u=Math.max(r,a,c),d=Math.min(r,a,c);let h,p;const g=(d+u)/2;if(d===u)h=0,p=0;else{const y=u-d;switch(p=g<=.5?y/(u+d):y/(2-u-d),u){case r:h=(a-c)/y+(a<c?6:0);break;case a:h=(c-r)/y+2;break;case c:h=(r-a)/y+4;break}h/=6}return e.h=h,e.s=p,e.l=g,e}getRGB(e,t=Ct.workingColorSpace){return Ct.fromWorkingColorSpace(Rn.copy(this),t),e.r=Rn.r,e.g=Rn.g,e.b=Rn.b,e}getStyle(e=$i){Ct.fromWorkingColorSpace(Rn.copy(this),e);const t=Rn.r,r=Rn.g,a=Rn.b;return e!==$i?`color(${e} ${t.toFixed(3)} ${r.toFixed(3)} ${a.toFixed(3)})`:`rgb(${Math.round(t*255)},${Math.round(r*255)},${Math.round(a*255)})`}offsetHSL(e,t,r){return this.getHSL(ts),this.setHSL(ts.h+e,ts.s+t,ts.l+r)}add(e){return this.r+=e.r,this.g+=e.g,this.b+=e.b,this}addColors(e,t){return this.r=e.r+t.r,this.g=e.g+t.g,this.b=e.b+t.b,this}addScalar(e){return this.r+=e,this.g+=e,this.b+=e,this}sub(e){return this.r=Math.max(0,this.r-e.r),this.g=Math.max(0,this.g-e.g),this.b=Math.max(0,this.b-e.b),this}multiply(e){return this.r*=e.r,this.g*=e.g,this.b*=e.b,this}multiplyScalar(e){return this.r*=e,this.g*=e,this.b*=e,this}lerp(e,t){return this.r+=(e.r-this.r)*t,this.g+=(e.g-this.g)*t,this.b+=(e.b-this.b)*t,this}lerpColors(e,t,r){return this.r=e.r+(t.r-e.r)*r,this.g=e.g+(t.g-e.g)*r,this.b=e.b+(t.b-e.b)*r,this}lerpHSL(e,t){this.getHSL(ts),e.getHSL(Dc);const r=Lf(ts.h,Dc.h,t),a=Lf(ts.s,Dc.s,t),c=Lf(ts.l,Dc.l,t);return this.setHSL(r,a,c),this}setFromVector3(e){return this.r=e.x,this.g=e.y,this.b=e.z,this}applyMatrix3(e){const t=this.r,r=this.g,a=this.b,c=e.elements;return this.r=c[0]*t+c[3]*r+c[6]*a,this.g=c[1]*t+c[4]*r+c[7]*a,this.b=c[2]*t+c[5]*r+c[8]*a,this}equals(e){return e.r===this.r&&e.g===this.g&&e.b===this.b}fromArray(e,t=0){return this.r=e[t],this.g=e[t+1],this.b=e[t+2],this}toArray(e=[],t=0){return e[t]=this.r,e[t+1]=this.g,e[t+2]=this.b,e}fromBufferAttribute(e,t){return this.r=e.getX(t),this.g=e.getY(t),this.b=e.getZ(t),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}}const Rn=new Rt;Rt.NAMES=hx;let lb=0;class Ou extends ro{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:lb++}),this.uuid=dl(),this.name="",this.type="Material",this.blending=Ha,this.side=us,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=Sh,this.blendDst=Mh,this.blendEquation=Is,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new Rt(0,0,0),this.blendAlpha=0,this.depthFunc=Xa,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=o_,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=wa,this.stencilZFail=wa,this.stencilZPass=wa,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(e){this._alphaTest>0!=e>0&&this.version++,this._alphaTest=e}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(e){if(e!==void 0)for(const t in e){const r=e[t];if(r===void 0){console.warn(`THREE.Material: parameter '${t}' has value of undefined.`);continue}const a=this[t];if(a===void 0){console.warn(`THREE.Material: '${t}' is not a property of THREE.${this.type}.`);continue}a&&a.isColor?a.set(r):a&&a.isVector3&&r&&r.isVector3?a.copy(r):this[t]=r}}toJSON(e){const t=e===void 0||typeof e=="string";t&&(e={textures:{},images:{}});const r={metadata:{version:4.6,type:"Material",generator:"Material.toJSON"}};r.uuid=this.uuid,r.type=this.type,this.name!==""&&(r.name=this.name),this.color&&this.color.isColor&&(r.color=this.color.getHex()),this.roughness!==void 0&&(r.roughness=this.roughness),this.metalness!==void 0&&(r.metalness=this.metalness),this.sheen!==void 0&&(r.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(r.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(r.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(r.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&this.emissiveIntensity!==1&&(r.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(r.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(r.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(r.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(r.shininess=this.shininess),this.clearcoat!==void 0&&(r.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(r.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(r.clearcoatMap=this.clearcoatMap.toJSON(e).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(r.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(e).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(r.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(e).uuid,r.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.dispersion!==void 0&&(r.dispersion=this.dispersion),this.iridescence!==void 0&&(r.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(r.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(r.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(r.iridescenceMap=this.iridescenceMap.toJSON(e).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(r.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(e).uuid),this.anisotropy!==void 0&&(r.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(r.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(r.anisotropyMap=this.anisotropyMap.toJSON(e).uuid),this.map&&this.map.isTexture&&(r.map=this.map.toJSON(e).uuid),this.matcap&&this.matcap.isTexture&&(r.matcap=this.matcap.toJSON(e).uuid),this.alphaMap&&this.alphaMap.isTexture&&(r.alphaMap=this.alphaMap.toJSON(e).uuid),this.lightMap&&this.lightMap.isTexture&&(r.lightMap=this.lightMap.toJSON(e).uuid,r.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(r.aoMap=this.aoMap.toJSON(e).uuid,r.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(r.bumpMap=this.bumpMap.toJSON(e).uuid,r.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(r.normalMap=this.normalMap.toJSON(e).uuid,r.normalMapType=this.normalMapType,r.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(r.displacementMap=this.displacementMap.toJSON(e).uuid,r.displacementScale=this.displacementScale,r.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(r.roughnessMap=this.roughnessMap.toJSON(e).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(r.metalnessMap=this.metalnessMap.toJSON(e).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(r.emissiveMap=this.emissiveMap.toJSON(e).uuid),this.specularMap&&this.specularMap.isTexture&&(r.specularMap=this.specularMap.toJSON(e).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(r.specularIntensityMap=this.specularIntensityMap.toJSON(e).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(r.specularColorMap=this.specularColorMap.toJSON(e).uuid),this.envMap&&this.envMap.isTexture&&(r.envMap=this.envMap.toJSON(e).uuid,this.combine!==void 0&&(r.combine=this.combine)),this.envMapRotation!==void 0&&(r.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(r.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(r.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(r.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(r.gradientMap=this.gradientMap.toJSON(e).uuid),this.transmission!==void 0&&(r.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(r.transmissionMap=this.transmissionMap.toJSON(e).uuid),this.thickness!==void 0&&(r.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(r.thicknessMap=this.thicknessMap.toJSON(e).uuid),this.attenuationDistance!==void 0&&this.attenuationDistance!==1/0&&(r.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(r.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(r.size=this.size),this.shadowSide!==null&&(r.shadowSide=this.shadowSide),this.sizeAttenuation!==void 0&&(r.sizeAttenuation=this.sizeAttenuation),this.blending!==Ha&&(r.blending=this.blending),this.side!==us&&(r.side=this.side),this.vertexColors===!0&&(r.vertexColors=!0),this.opacity<1&&(r.opacity=this.opacity),this.transparent===!0&&(r.transparent=!0),this.blendSrc!==Sh&&(r.blendSrc=this.blendSrc),this.blendDst!==Mh&&(r.blendDst=this.blendDst),this.blendEquation!==Is&&(r.blendEquation=this.blendEquation),this.blendSrcAlpha!==null&&(r.blendSrcAlpha=this.blendSrcAlpha),this.blendDstAlpha!==null&&(r.blendDstAlpha=this.blendDstAlpha),this.blendEquationAlpha!==null&&(r.blendEquationAlpha=this.blendEquationAlpha),this.blendColor&&this.blendColor.isColor&&(r.blendColor=this.blendColor.getHex()),this.blendAlpha!==0&&(r.blendAlpha=this.blendAlpha),this.depthFunc!==Xa&&(r.depthFunc=this.depthFunc),this.depthTest===!1&&(r.depthTest=this.depthTest),this.depthWrite===!1&&(r.depthWrite=this.depthWrite),this.colorWrite===!1&&(r.colorWrite=this.colorWrite),this.stencilWriteMask!==255&&(r.stencilWriteMask=this.stencilWriteMask),this.stencilFunc!==o_&&(r.stencilFunc=this.stencilFunc),this.stencilRef!==0&&(r.stencilRef=this.stencilRef),this.stencilFuncMask!==255&&(r.stencilFuncMask=this.stencilFuncMask),this.stencilFail!==wa&&(r.stencilFail=this.stencilFail),this.stencilZFail!==wa&&(r.stencilZFail=this.stencilZFail),this.stencilZPass!==wa&&(r.stencilZPass=this.stencilZPass),this.stencilWrite===!0&&(r.stencilWrite=this.stencilWrite),this.rotation!==void 0&&this.rotation!==0&&(r.rotation=this.rotation),this.polygonOffset===!0&&(r.polygonOffset=!0),this.polygonOffsetFactor!==0&&(r.polygonOffsetFactor=this.polygonOffsetFactor),this.polygonOffsetUnits!==0&&(r.polygonOffsetUnits=this.polygonOffsetUnits),this.linewidth!==void 0&&this.linewidth!==1&&(r.linewidth=this.linewidth),this.dashSize!==void 0&&(r.dashSize=this.dashSize),this.gapSize!==void 0&&(r.gapSize=this.gapSize),this.scale!==void 0&&(r.scale=this.scale),this.dithering===!0&&(r.dithering=!0),this.alphaTest>0&&(r.alphaTest=this.alphaTest),this.alphaHash===!0&&(r.alphaHash=!0),this.alphaToCoverage===!0&&(r.alphaToCoverage=!0),this.premultipliedAlpha===!0&&(r.premultipliedAlpha=!0),this.forceSinglePass===!0&&(r.forceSinglePass=!0),this.wireframe===!0&&(r.wireframe=!0),this.wireframeLinewidth>1&&(r.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!=="round"&&(r.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!=="round"&&(r.wireframeLinejoin=this.wireframeLinejoin),this.flatShading===!0&&(r.flatShading=!0),this.visible===!1&&(r.visible=!1),this.toneMapped===!1&&(r.toneMapped=!1),this.fog===!1&&(r.fog=!1),Object.keys(this.userData).length>0&&(r.userData=this.userData);function a(c){const u=[];for(const d in c){const h=c[d];delete h.metadata,u.push(h)}return u}if(t){const c=a(e.textures),u=a(e.images);c.length>0&&(r.textures=c),u.length>0&&(r.images=u)}return r}clone(){return new this.constructor().copy(this)}copy(e){this.name=e.name,this.blending=e.blending,this.side=e.side,this.vertexColors=e.vertexColors,this.opacity=e.opacity,this.transparent=e.transparent,this.blendSrc=e.blendSrc,this.blendDst=e.blendDst,this.blendEquation=e.blendEquation,this.blendSrcAlpha=e.blendSrcAlpha,this.blendDstAlpha=e.blendDstAlpha,this.blendEquationAlpha=e.blendEquationAlpha,this.blendColor.copy(e.blendColor),this.blendAlpha=e.blendAlpha,this.depthFunc=e.depthFunc,this.depthTest=e.depthTest,this.depthWrite=e.depthWrite,this.stencilWriteMask=e.stencilWriteMask,this.stencilFunc=e.stencilFunc,this.stencilRef=e.stencilRef,this.stencilFuncMask=e.stencilFuncMask,this.stencilFail=e.stencilFail,this.stencilZFail=e.stencilZFail,this.stencilZPass=e.stencilZPass,this.stencilWrite=e.stencilWrite;const t=e.clippingPlanes;let r=null;if(t!==null){const a=t.length;r=new Array(a);for(let c=0;c!==a;++c)r[c]=t[c].clone()}return this.clippingPlanes=r,this.clipIntersection=e.clipIntersection,this.clipShadows=e.clipShadows,this.shadowSide=e.shadowSide,this.colorWrite=e.colorWrite,this.precision=e.precision,this.polygonOffset=e.polygonOffset,this.polygonOffsetFactor=e.polygonOffsetFactor,this.polygonOffsetUnits=e.polygonOffsetUnits,this.dithering=e.dithering,this.alphaTest=e.alphaTest,this.alphaHash=e.alphaHash,this.alphaToCoverage=e.alphaToCoverage,this.premultipliedAlpha=e.premultipliedAlpha,this.forceSinglePass=e.forceSinglePass,this.visible=e.visible,this.toneMapped=e.toneMapped,this.userData=JSON.parse(JSON.stringify(e.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(e){e===!0&&this.version++}onBuild(){console.warn("Material: onBuild() has been removed.")}}class Bp extends Ou{constructor(e){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new Rt(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Tr,this.combine=Kv,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.specularMap=e.specularMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.combine=e.combine,this.reflectivity=e.reflectivity,this.refractionRatio=e.refractionRatio,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.fog=e.fog,this}}const tn=new re,Ic=new bt;class Ki{constructor(e,t,r=!1){if(Array.isArray(e))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,this.name="",this.array=e,this.itemSize=t,this.count=e!==void 0?e.length/t:0,this.normalized=r,this.usage=l_,this.updateRanges=[],this.gpuType=xr,this.version=0}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.name=e.name,this.array=new e.array.constructor(e.array),this.itemSize=e.itemSize,this.count=e.count,this.normalized=e.normalized,this.usage=e.usage,this.gpuType=e.gpuType,this}copyAt(e,t,r){e*=this.itemSize,r*=t.itemSize;for(let a=0,c=this.itemSize;a<c;a++)this.array[e+a]=t.array[r+a];return this}copyArray(e){return this.array.set(e),this}applyMatrix3(e){if(this.itemSize===2)for(let t=0,r=this.count;t<r;t++)Ic.fromBufferAttribute(this,t),Ic.applyMatrix3(e),this.setXY(t,Ic.x,Ic.y);else if(this.itemSize===3)for(let t=0,r=this.count;t<r;t++)tn.fromBufferAttribute(this,t),tn.applyMatrix3(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}applyMatrix4(e){for(let t=0,r=this.count;t<r;t++)tn.fromBufferAttribute(this,t),tn.applyMatrix4(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}applyNormalMatrix(e){for(let t=0,r=this.count;t<r;t++)tn.fromBufferAttribute(this,t),tn.applyNormalMatrix(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}transformDirection(e){for(let t=0,r=this.count;t<r;t++)tn.fromBufferAttribute(this,t),tn.transformDirection(e),this.setXYZ(t,tn.x,tn.y,tn.z);return this}set(e,t=0){return this.array.set(e,t),this}getComponent(e,t){let r=this.array[e*this.itemSize+t];return this.normalized&&(r=Go(r,this.array)),r}setComponent(e,t,r){return this.normalized&&(r=Wn(r,this.array)),this.array[e*this.itemSize+t]=r,this}getX(e){let t=this.array[e*this.itemSize];return this.normalized&&(t=Go(t,this.array)),t}setX(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize]=t,this}getY(e){let t=this.array[e*this.itemSize+1];return this.normalized&&(t=Go(t,this.array)),t}setY(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+1]=t,this}getZ(e){let t=this.array[e*this.itemSize+2];return this.normalized&&(t=Go(t,this.array)),t}setZ(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+2]=t,this}getW(e){let t=this.array[e*this.itemSize+3];return this.normalized&&(t=Go(t,this.array)),t}setW(e,t){return this.normalized&&(t=Wn(t,this.array)),this.array[e*this.itemSize+3]=t,this}setXY(e,t,r){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),r=Wn(r,this.array)),this.array[e+0]=t,this.array[e+1]=r,this}setXYZ(e,t,r,a){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),r=Wn(r,this.array),a=Wn(a,this.array)),this.array[e+0]=t,this.array[e+1]=r,this.array[e+2]=a,this}setXYZW(e,t,r,a,c){return e*=this.itemSize,this.normalized&&(t=Wn(t,this.array),r=Wn(r,this.array),a=Wn(a,this.array),c=Wn(c,this.array)),this.array[e+0]=t,this.array[e+1]=r,this.array[e+2]=a,this.array[e+3]=c,this}onUpload(e){return this.onUploadCallback=e,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){const e={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return this.name!==""&&(e.name=this.name),this.usage!==l_&&(e.usage=this.usage),e}}class px extends Ki{constructor(e,t,r){super(new Uint16Array(e),t,r)}}class mx extends Ki{constructor(e,t,r){super(new Uint32Array(e),t,r)}}class li extends Ki{constructor(e,t,r){super(new Float32Array(e),t,r)}}let cb=0;const gi=new nn,Zf=new oi,Da=new re,ri=new hl,Yo=new hl,gn=new re;class Ar extends ro{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:cb++}),this.uuid=dl(),this.name="",this.type="BufferGeometry",this.index=null,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={}}getIndex(){return this.index}setIndex(e){return Array.isArray(e)?this.index=new(cx(e)?mx:px)(e,1):this.index=e,this}getAttribute(e){return this.attributes[e]}setAttribute(e,t){return this.attributes[e]=t,this}deleteAttribute(e){return delete this.attributes[e],this}hasAttribute(e){return this.attributes[e]!==void 0}addGroup(e,t,r=0){this.groups.push({start:e,count:t,materialIndex:r})}clearGroups(){this.groups=[]}setDrawRange(e,t){this.drawRange.start=e,this.drawRange.count=t}applyMatrix4(e){const t=this.attributes.position;t!==void 0&&(t.applyMatrix4(e),t.needsUpdate=!0);const r=this.attributes.normal;if(r!==void 0){const c=new dt().getNormalMatrix(e);r.applyNormalMatrix(c),r.needsUpdate=!0}const a=this.attributes.tangent;return a!==void 0&&(a.transformDirection(e),a.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this}applyQuaternion(e){return gi.makeRotationFromQuaternion(e),this.applyMatrix4(gi),this}rotateX(e){return gi.makeRotationX(e),this.applyMatrix4(gi),this}rotateY(e){return gi.makeRotationY(e),this.applyMatrix4(gi),this}rotateZ(e){return gi.makeRotationZ(e),this.applyMatrix4(gi),this}translate(e,t,r){return gi.makeTranslation(e,t,r),this.applyMatrix4(gi),this}scale(e,t,r){return gi.makeScale(e,t,r),this.applyMatrix4(gi),this}lookAt(e){return Zf.lookAt(e),Zf.updateMatrix(),this.applyMatrix4(Zf.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Da).negate(),this.translate(Da.x,Da.y,Da.z),this}setFromPoints(e){const t=[];for(let r=0,a=e.length;r<a;r++){const c=e[r];t.push(c.x,c.y,c.z||0)}return this.setAttribute("position",new li(t,3)),this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new hl);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new re(-1/0,-1/0,-1/0),new re(1/0,1/0,1/0));return}if(e!==void 0){if(this.boundingBox.setFromBufferAttribute(e),t)for(let r=0,a=t.length;r<a;r++){const c=t[r];ri.setFromBufferAttribute(c),this.morphTargetsRelative?(gn.addVectors(this.boundingBox.min,ri.min),this.boundingBox.expandByPoint(gn),gn.addVectors(this.boundingBox.max,ri.max),this.boundingBox.expandByPoint(gn)):(this.boundingBox.expandByPoint(ri.min),this.boundingBox.expandByPoint(ri.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&console.error('THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new zp);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new re,1/0);return}if(e){const r=this.boundingSphere.center;if(ri.setFromBufferAttribute(e),t)for(let c=0,u=t.length;c<u;c++){const d=t[c];Yo.setFromBufferAttribute(d),this.morphTargetsRelative?(gn.addVectors(ri.min,Yo.min),ri.expandByPoint(gn),gn.addVectors(ri.max,Yo.max),ri.expandByPoint(gn)):(ri.expandByPoint(Yo.min),ri.expandByPoint(Yo.max))}ri.getCenter(r);let a=0;for(let c=0,u=e.count;c<u;c++)gn.fromBufferAttribute(e,c),a=Math.max(a,r.distanceToSquared(gn));if(t)for(let c=0,u=t.length;c<u;c++){const d=t[c],h=this.morphTargetsRelative;for(let p=0,g=d.count;p<g;p++)gn.fromBufferAttribute(d,p),h&&(Da.fromBufferAttribute(e,p),gn.add(Da)),a=Math.max(a,r.distanceToSquared(gn))}this.boundingSphere.radius=Math.sqrt(a),isNaN(this.boundingSphere.radius)&&console.error('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){const e=this.index,t=this.attributes;if(e===null||t.position===void 0||t.normal===void 0||t.uv===void 0){console.error("THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}const r=t.position,a=t.normal,c=t.uv;this.hasAttribute("tangent")===!1&&this.setAttribute("tangent",new Ki(new Float32Array(4*r.count),4));const u=this.getAttribute("tangent"),d=[],h=[];for(let $=0;$<r.count;$++)d[$]=new re,h[$]=new re;const p=new re,g=new re,y=new re,v=new bt,x=new bt,w=new bt,E=new re,_=new re;function M($,te,T){p.fromBufferAttribute(r,$),g.fromBufferAttribute(r,te),y.fromBufferAttribute(r,T),v.fromBufferAttribute(c,$),x.fromBufferAttribute(c,te),w.fromBufferAttribute(c,T),g.sub(p),y.sub(p),x.sub(v),w.sub(v);const P=1/(x.x*w.y-w.x*x.y);isFinite(P)&&(E.copy(g).multiplyScalar(w.y).addScaledVector(y,-x.y).multiplyScalar(P),_.copy(y).multiplyScalar(x.x).addScaledVector(g,-w.x).multiplyScalar(P),d[$].add(E),d[te].add(E),d[T].add(E),h[$].add(_),h[te].add(_),h[T].add(_))}let k=this.groups;k.length===0&&(k=[{start:0,count:e.count}]);for(let $=0,te=k.length;$<te;++$){const T=k[$],P=T.start,se=T.count;for(let J=P,ae=P+se;J<ae;J+=3)M(e.getX(J+0),e.getX(J+1),e.getX(J+2))}const A=new re,R=new re,L=new re,D=new re;function U($){L.fromBufferAttribute(a,$),D.copy(L);const te=d[$];A.copy(te),A.sub(L.multiplyScalar(L.dot(te))).normalize(),R.crossVectors(D,te);const P=R.dot(h[$])<0?-1:1;u.setXYZW($,A.x,A.y,A.z,P)}for(let $=0,te=k.length;$<te;++$){const T=k[$],P=T.start,se=T.count;for(let J=P,ae=P+se;J<ae;J+=3)U(e.getX(J+0)),U(e.getX(J+1)),U(e.getX(J+2))}}computeVertexNormals(){const e=this.index,t=this.getAttribute("position");if(t!==void 0){let r=this.getAttribute("normal");if(r===void 0)r=new Ki(new Float32Array(t.count*3),3),this.setAttribute("normal",r);else for(let v=0,x=r.count;v<x;v++)r.setXYZ(v,0,0,0);const a=new re,c=new re,u=new re,d=new re,h=new re,p=new re,g=new re,y=new re;if(e)for(let v=0,x=e.count;v<x;v+=3){const w=e.getX(v+0),E=e.getX(v+1),_=e.getX(v+2);a.fromBufferAttribute(t,w),c.fromBufferAttribute(t,E),u.fromBufferAttribute(t,_),g.subVectors(u,c),y.subVectors(a,c),g.cross(y),d.fromBufferAttribute(r,w),h.fromBufferAttribute(r,E),p.fromBufferAttribute(r,_),d.add(g),h.add(g),p.add(g),r.setXYZ(w,d.x,d.y,d.z),r.setXYZ(E,h.x,h.y,h.z),r.setXYZ(_,p.x,p.y,p.z)}else for(let v=0,x=t.count;v<x;v+=3)a.fromBufferAttribute(t,v+0),c.fromBufferAttribute(t,v+1),u.fromBufferAttribute(t,v+2),g.subVectors(u,c),y.subVectors(a,c),g.cross(y),r.setXYZ(v+0,g.x,g.y,g.z),r.setXYZ(v+1,g.x,g.y,g.z),r.setXYZ(v+2,g.x,g.y,g.z);this.normalizeNormals(),r.needsUpdate=!0}}normalizeNormals(){const e=this.attributes.normal;for(let t=0,r=e.count;t<r;t++)gn.fromBufferAttribute(e,t),gn.normalize(),e.setXYZ(t,gn.x,gn.y,gn.z)}toNonIndexed(){function e(d,h){const p=d.array,g=d.itemSize,y=d.normalized,v=new p.constructor(h.length*g);let x=0,w=0;for(let E=0,_=h.length;E<_;E++){d.isInterleavedBufferAttribute?x=h[E]*d.data.stride+d.offset:x=h[E]*g;for(let M=0;M<g;M++)v[w++]=p[x++]}return new Ki(v,g,y)}if(this.index===null)return console.warn("THREE.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;const t=new Ar,r=this.index.array,a=this.attributes;for(const d in a){const h=a[d],p=e(h,r);t.setAttribute(d,p)}const c=this.morphAttributes;for(const d in c){const h=[],p=c[d];for(let g=0,y=p.length;g<y;g++){const v=p[g],x=e(v,r);h.push(x)}t.morphAttributes[d]=h}t.morphTargetsRelative=this.morphTargetsRelative;const u=this.groups;for(let d=0,h=u.length;d<h;d++){const p=u[d];t.addGroup(p.start,p.count,p.materialIndex)}return t}toJSON(){const e={metadata:{version:4.6,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(e.uuid=this.uuid,e.type=this.type,this.name!==""&&(e.name=this.name),Object.keys(this.userData).length>0&&(e.userData=this.userData),this.parameters!==void 0){const h=this.parameters;for(const p in h)h[p]!==void 0&&(e[p]=h[p]);return e}e.data={attributes:{}};const t=this.index;t!==null&&(e.data.index={type:t.array.constructor.name,array:Array.prototype.slice.call(t.array)});const r=this.attributes;for(const h in r){const p=r[h];e.data.attributes[h]=p.toJSON(e.data)}const a={};let c=!1;for(const h in this.morphAttributes){const p=this.morphAttributes[h],g=[];for(let y=0,v=p.length;y<v;y++){const x=p[y];g.push(x.toJSON(e.data))}g.length>0&&(a[h]=g,c=!0)}c&&(e.data.morphAttributes=a,e.data.morphTargetsRelative=this.morphTargetsRelative);const u=this.groups;u.length>0&&(e.data.groups=JSON.parse(JSON.stringify(u)));const d=this.boundingSphere;return d!==null&&(e.data.boundingSphere={center:d.center.toArray(),radius:d.radius}),e}clone(){return new this.constructor().copy(this)}copy(e){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;const t={};this.name=e.name;const r=e.index;r!==null&&this.setIndex(r.clone(t));const a=e.attributes;for(const p in a){const g=a[p];this.setAttribute(p,g.clone(t))}const c=e.morphAttributes;for(const p in c){const g=[],y=c[p];for(let v=0,x=y.length;v<x;v++)g.push(y[v].clone(t));this.morphAttributes[p]=g}this.morphTargetsRelative=e.morphTargetsRelative;const u=e.groups;for(let p=0,g=u.length;p<g;p++){const y=u[p];this.addGroup(y.start,y.count,y.materialIndex)}const d=e.boundingBox;d!==null&&(this.boundingBox=d.clone());const h=e.boundingSphere;return h!==null&&(this.boundingSphere=h.clone()),this.drawRange.start=e.drawRange.start,this.drawRange.count=e.drawRange.count,this.userData=e.userData,this}dispose(){this.dispatchEvent({type:"dispose"})}}const M_=new nn,Ns=new tb,Uc=new zp,E_=new re,Fc=new re,Oc=new re,jc=new re,Qf=new re,zc=new re,w_=new re,Bc=new re;class ji extends oi{constructor(e=new Ar,t=new Bp){super(),this.isMesh=!0,this.type="Mesh",this.geometry=e,this.material=t,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),e.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=e.morphTargetInfluences.slice()),e.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},e.morphTargetDictionary)),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}updateMorphTargets(){const t=this.geometry.morphAttributes,r=Object.keys(t);if(r.length>0){const a=t[r[0]];if(a!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let c=0,u=a.length;c<u;c++){const d=a[c].name||String(c);this.morphTargetInfluences.push(0),this.morphTargetDictionary[d]=c}}}}getVertexPosition(e,t){const r=this.geometry,a=r.attributes.position,c=r.morphAttributes.position,u=r.morphTargetsRelative;t.fromBufferAttribute(a,e);const d=this.morphTargetInfluences;if(c&&d){zc.set(0,0,0);for(let h=0,p=c.length;h<p;h++){const g=d[h],y=c[h];g!==0&&(Qf.fromBufferAttribute(y,e),u?zc.addScaledVector(Qf,g):zc.addScaledVector(Qf.sub(t),g))}t.add(zc)}return t}raycast(e,t){const r=this.geometry,a=this.material,c=this.matrixWorld;a!==void 0&&(r.boundingSphere===null&&r.computeBoundingSphere(),Uc.copy(r.boundingSphere),Uc.applyMatrix4(c),Ns.copy(e.ray).recast(e.near),!(Uc.containsPoint(Ns.origin)===!1&&(Ns.intersectSphere(Uc,E_)===null||Ns.origin.distanceToSquared(E_)>(e.far-e.near)**2))&&(M_.copy(c).invert(),Ns.copy(e.ray).applyMatrix4(M_),!(r.boundingBox!==null&&Ns.intersectsBox(r.boundingBox)===!1)&&this._computeIntersections(e,t,Ns)))}_computeIntersections(e,t,r){let a;const c=this.geometry,u=this.material,d=c.index,h=c.attributes.position,p=c.attributes.uv,g=c.attributes.uv1,y=c.attributes.normal,v=c.groups,x=c.drawRange;if(d!==null)if(Array.isArray(u))for(let w=0,E=v.length;w<E;w++){const _=v[w],M=u[_.materialIndex],k=Math.max(_.start,x.start),A=Math.min(d.count,Math.min(_.start+_.count,x.start+x.count));for(let R=k,L=A;R<L;R+=3){const D=d.getX(R),U=d.getX(R+1),$=d.getX(R+2);a=Hc(this,M,e,r,p,g,y,D,U,$),a&&(a.faceIndex=Math.floor(R/3),a.face.materialIndex=_.materialIndex,t.push(a))}}else{const w=Math.max(0,x.start),E=Math.min(d.count,x.start+x.count);for(let _=w,M=E;_<M;_+=3){const k=d.getX(_),A=d.getX(_+1),R=d.getX(_+2);a=Hc(this,u,e,r,p,g,y,k,A,R),a&&(a.faceIndex=Math.floor(_/3),t.push(a))}}else if(h!==void 0)if(Array.isArray(u))for(let w=0,E=v.length;w<E;w++){const _=v[w],M=u[_.materialIndex],k=Math.max(_.start,x.start),A=Math.min(h.count,Math.min(_.start+_.count,x.start+x.count));for(let R=k,L=A;R<L;R+=3){const D=R,U=R+1,$=R+2;a=Hc(this,M,e,r,p,g,y,D,U,$),a&&(a.faceIndex=Math.floor(R/3),a.face.materialIndex=_.materialIndex,t.push(a))}}else{const w=Math.max(0,x.start),E=Math.min(h.count,x.start+x.count);for(let _=w,M=E;_<M;_+=3){const k=_,A=_+1,R=_+2;a=Hc(this,u,e,r,p,g,y,k,A,R),a&&(a.faceIndex=Math.floor(_/3),t.push(a))}}}}function ub(n,e,t,r,a,c,u,d){let h;if(e.side===qn?h=r.intersectTriangle(u,c,a,!0,d):h=r.intersectTriangle(a,c,u,e.side===us,d),h===null)return null;Bc.copy(d),Bc.applyMatrix4(n.matrixWorld);const p=t.ray.origin.distanceTo(Bc);return p<t.near||p>t.far?null:{distance:p,point:Bc.clone(),object:n}}function Hc(n,e,t,r,a,c,u,d,h,p){n.getVertexPosition(d,Fc),n.getVertexPosition(h,Oc),n.getVertexPosition(p,jc);const g=ub(n,e,t,r,Fc,Oc,jc,w_);if(g){const y=new re;Ii.getBarycoord(w_,Fc,Oc,jc,y),a&&(g.uv=Ii.getInterpolatedAttribute(a,d,h,p,y,new bt)),c&&(g.uv1=Ii.getInterpolatedAttribute(c,d,h,p,y,new bt)),u&&(g.normal=Ii.getInterpolatedAttribute(u,d,h,p,y,new re),g.normal.dot(r.direction)>0&&g.normal.multiplyScalar(-1));const v={a:d,b:h,c:p,normal:new re,materialIndex:0};Ii.getNormal(Fc,Oc,jc,v.normal),g.face=v,g.barycoord=y}return g}class pl extends Ar{constructor(e=1,t=1,r=1,a=1,c=1,u=1){super(),this.type="BoxGeometry",this.parameters={width:e,height:t,depth:r,widthSegments:a,heightSegments:c,depthSegments:u};const d=this;a=Math.floor(a),c=Math.floor(c),u=Math.floor(u);const h=[],p=[],g=[],y=[];let v=0,x=0;w("z","y","x",-1,-1,r,t,e,u,c,0),w("z","y","x",1,-1,r,t,-e,u,c,1),w("x","z","y",1,1,e,r,t,a,u,2),w("x","z","y",1,-1,e,r,-t,a,u,3),w("x","y","z",1,-1,e,t,r,a,c,4),w("x","y","z",-1,-1,e,t,-r,a,c,5),this.setIndex(h),this.setAttribute("position",new li(p,3)),this.setAttribute("normal",new li(g,3)),this.setAttribute("uv",new li(y,2));function w(E,_,M,k,A,R,L,D,U,$,te){const T=R/U,P=L/$,se=R/2,J=L/2,ae=D/2,ve=U+1,V=$+1;let de=0,z=0;const ue=new re;for(let oe=0;oe<V;oe++){const O=oe*P-J;for(let le=0;le<ve;le++){const we=le*T-se;ue[E]=we*k,ue[_]=O*A,ue[M]=ae,p.push(ue.x,ue.y,ue.z),ue[E]=0,ue[_]=0,ue[M]=D>0?1:-1,g.push(ue.x,ue.y,ue.z),y.push(le/U),y.push(1-oe/$),de+=1}}for(let oe=0;oe<$;oe++)for(let O=0;O<U;O++){const le=v+O+ve*oe,we=v+O+ve*(oe+1),K=v+(O+1)+ve*(oe+1),he=v+(O+1)+ve*oe;h.push(le,we,he),h.push(we,K,he),z+=6}d.addGroup(x,z,te),x+=z,v+=de}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new pl(e.width,e.height,e.depth,e.widthSegments,e.heightSegments,e.depthSegments)}}function Qa(n){const e={};for(const t in n){e[t]={};for(const r in n[t]){const a=n[t][r];a&&(a.isColor||a.isMatrix3||a.isMatrix4||a.isVector2||a.isVector3||a.isVector4||a.isTexture||a.isQuaternion)?a.isRenderTargetTexture?(console.warn("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),e[t][r]=null):e[t][r]=a.clone():Array.isArray(a)?e[t][r]=a.slice():e[t][r]=a}}return e}function Un(n){const e={};for(let t=0;t<n.length;t++){const r=Qa(n[t]);for(const a in r)e[a]=r[a]}return e}function db(n){const e=[];for(let t=0;t<n.length;t++)e.push(n[t].clone());return e}function gx(n){const e=n.getRenderTarget();return e===null?n.outputColorSpace:e.isXRRenderTarget===!0?e.texture.colorSpace:Ct.workingColorSpace}const fb={clone:Qa,merge:Un};var hb=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,pb=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`;class br extends Ou{constructor(e){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=hb,this.fragmentShader=pb,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,e!==void 0&&this.setValues(e)}copy(e){return super.copy(e),this.fragmentShader=e.fragmentShader,this.vertexShader=e.vertexShader,this.uniforms=Qa(e.uniforms),this.uniformsGroups=db(e.uniformsGroups),this.defines=Object.assign({},e.defines),this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.fog=e.fog,this.lights=e.lights,this.clipping=e.clipping,this.extensions=Object.assign({},e.extensions),this.glslVersion=e.glslVersion,this}toJSON(e){const t=super.toJSON(e);t.glslVersion=this.glslVersion,t.uniforms={};for(const a in this.uniforms){const u=this.uniforms[a].value;u&&u.isTexture?t.uniforms[a]={type:"t",value:u.toJSON(e).uuid}:u&&u.isColor?t.uniforms[a]={type:"c",value:u.getHex()}:u&&u.isVector2?t.uniforms[a]={type:"v2",value:u.toArray()}:u&&u.isVector3?t.uniforms[a]={type:"v3",value:u.toArray()}:u&&u.isVector4?t.uniforms[a]={type:"v4",value:u.toArray()}:u&&u.isMatrix3?t.uniforms[a]={type:"m3",value:u.toArray()}:u&&u.isMatrix4?t.uniforms[a]={type:"m4",value:u.toArray()}:t.uniforms[a]={value:u}}Object.keys(this.defines).length>0&&(t.defines=this.defines),t.vertexShader=this.vertexShader,t.fragmentShader=this.fragmentShader,t.lights=this.lights,t.clipping=this.clipping;const r={};for(const a in this.extensions)this.extensions[a]===!0&&(r[a]=!0);return Object.keys(r).length>0&&(t.extensions=r),t}}class _x extends oi{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new nn,this.projectionMatrix=new nn,this.projectionMatrixInverse=new nn,this.coordinateSystem=yr}copy(e,t){return super.copy(e,t),this.matrixWorldInverse.copy(e.matrixWorldInverse),this.projectionMatrix.copy(e.projectionMatrix),this.projectionMatrixInverse.copy(e.projectionMatrixInverse),this.coordinateSystem=e.coordinateSystem,this}getWorldDirection(e){return super.getWorldDirection(e).negate()}updateMatrixWorld(e){super.updateMatrixWorld(e),this.matrixWorldInverse.copy(this.matrixWorld).invert()}updateWorldMatrix(e,t){super.updateWorldMatrix(e,t),this.matrixWorldInverse.copy(this.matrixWorld).invert()}clone(){return new this.constructor().copy(this)}}const ns=new re,T_=new bt,b_=new bt;class xi extends _x{constructor(e=50,t=1,r=.1,a=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=e,this.zoom=1,this.near=r,this.far=a,this.focus=10,this.aspect=t,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.fov=e.fov,this.zoom=e.zoom,this.near=e.near,this.far=e.far,this.focus=e.focus,this.aspect=e.aspect,this.view=e.view===null?null:Object.assign({},e.view),this.filmGauge=e.filmGauge,this.filmOffset=e.filmOffset,this}setFocalLength(e){const t=.5*this.getFilmHeight()/e;this.fov=ap*2*Math.atan(t),this.updateProjectionMatrix()}getFocalLength(){const e=Math.tan(Pf*.5*this.fov);return .5*this.getFilmHeight()/e}getEffectiveFOV(){return ap*2*Math.atan(Math.tan(Pf*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(e,t,r){ns.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),t.set(ns.x,ns.y).multiplyScalar(-e/ns.z),ns.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),r.set(ns.x,ns.y).multiplyScalar(-e/ns.z)}getViewSize(e,t){return this.getViewBounds(e,T_,b_),t.subVectors(b_,T_)}setViewOffset(e,t,r,a,c,u){this.aspect=e/t,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=r,this.view.offsetY=a,this.view.width=c,this.view.height=u,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=this.near;let t=e*Math.tan(Pf*.5*this.fov)/this.zoom,r=2*t,a=this.aspect*r,c=-.5*a;const u=this.view;if(this.view!==null&&this.view.enabled){const h=u.fullWidth,p=u.fullHeight;c+=u.offsetX*a/h,t-=u.offsetY*r/p,a*=u.width/h,r*=u.height/p}const d=this.filmOffset;d!==0&&(c+=e*d/this.getFilmWidth()),this.projectionMatrix.makePerspective(c,c+a,t,t-r,e,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.fov=this.fov,t.object.zoom=this.zoom,t.object.near=this.near,t.object.far=this.far,t.object.focus=this.focus,t.object.aspect=this.aspect,this.view!==null&&(t.object.view=Object.assign({},this.view)),t.object.filmGauge=this.filmGauge,t.object.filmOffset=this.filmOffset,t}}const Ia=-90,Ua=1;class mb extends oi{constructor(e,t,r){super(),this.type="CubeCamera",this.renderTarget=r,this.coordinateSystem=null,this.activeMipmapLevel=0;const a=new xi(Ia,Ua,e,t);a.layers=this.layers,this.add(a);const c=new xi(Ia,Ua,e,t);c.layers=this.layers,this.add(c);const u=new xi(Ia,Ua,e,t);u.layers=this.layers,this.add(u);const d=new xi(Ia,Ua,e,t);d.layers=this.layers,this.add(d);const h=new xi(Ia,Ua,e,t);h.layers=this.layers,this.add(h);const p=new xi(Ia,Ua,e,t);p.layers=this.layers,this.add(p)}updateCoordinateSystem(){const e=this.coordinateSystem,t=this.children.concat(),[r,a,c,u,d,h]=t;for(const p of t)this.remove(p);if(e===yr)r.up.set(0,1,0),r.lookAt(1,0,0),a.up.set(0,1,0),a.lookAt(-1,0,0),c.up.set(0,0,-1),c.lookAt(0,1,0),u.up.set(0,0,1),u.lookAt(0,-1,0),d.up.set(0,1,0),d.lookAt(0,0,1),h.up.set(0,1,0),h.lookAt(0,0,-1);else if(e===_u)r.up.set(0,-1,0),r.lookAt(-1,0,0),a.up.set(0,-1,0),a.lookAt(1,0,0),c.up.set(0,0,1),c.lookAt(0,1,0),u.up.set(0,0,-1),u.lookAt(0,-1,0),d.up.set(0,-1,0),d.lookAt(0,0,1),h.up.set(0,-1,0),h.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+e);for(const p of t)this.add(p),p.updateMatrixWorld()}update(e,t){this.parent===null&&this.updateMatrixWorld();const{renderTarget:r,activeMipmapLevel:a}=this;this.coordinateSystem!==e.coordinateSystem&&(this.coordinateSystem=e.coordinateSystem,this.updateCoordinateSystem());const[c,u,d,h,p,g]=this.children,y=e.getRenderTarget(),v=e.getActiveCubeFace(),x=e.getActiveMipmapLevel(),w=e.xr.enabled;e.xr.enabled=!1;const E=r.texture.generateMipmaps;r.texture.generateMipmaps=!1,e.setRenderTarget(r,0,a),e.render(t,c),e.setRenderTarget(r,1,a),e.render(t,u),e.setRenderTarget(r,2,a),e.render(t,d),e.setRenderTarget(r,3,a),e.render(t,h),e.setRenderTarget(r,4,a),e.render(t,p),r.texture.generateMipmaps=E,e.setRenderTarget(r,5,a),e.render(t,g),e.setRenderTarget(y,v,x),e.xr.enabled=w,r.texture.needsPMREMUpdate=!0}}class vx extends Yn{constructor(e,t,r,a,c,u,d,h,p,g){e=e!==void 0?e:[],t=t!==void 0?t:qa,super(e,t,r,a,c,u,d,h,p,g),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(e){this.image=e}}class gb extends qs{constructor(e=1,t={}){super(e,e,t),this.isWebGLCubeRenderTarget=!0;const r={width:e,height:e,depth:1},a=[r,r,r,r,r,r];this.texture=new vx(a,t.mapping,t.wrapS,t.wrapT,t.magFilter,t.minFilter,t.format,t.type,t.anisotropy,t.colorSpace),this.texture.isRenderTargetTexture=!0,this.texture.generateMipmaps=t.generateMipmaps!==void 0?t.generateMipmaps:!1,this.texture.minFilter=t.minFilter!==void 0?t.minFilter:Di}fromEquirectangularTexture(e,t){this.texture.type=t.type,this.texture.colorSpace=t.colorSpace,this.texture.generateMipmaps=t.generateMipmaps,this.texture.minFilter=t.minFilter,this.texture.magFilter=t.magFilter;const r={uniforms:{tEquirect:{value:null}},vertexShader:`

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
			`},a=new pl(5,5,5),c=new br({name:"CubemapFromEquirect",uniforms:Qa(r.uniforms),vertexShader:r.vertexShader,fragmentShader:r.fragmentShader,side:qn,blending:as});c.uniforms.tEquirect.value=t;const u=new ji(a,c),d=t.minFilter;return t.minFilter===zs&&(t.minFilter=Di),new mb(1,10,this).update(e,u),t.minFilter=d,u.geometry.dispose(),u.material.dispose(),this}clear(e,t,r,a){const c=e.getRenderTarget();for(let u=0;u<6;u++)e.setRenderTarget(this,u),e.clear(t,r,a);e.setRenderTarget(c)}}const Jf=new re,_b=new re,vb=new dt;class ks{constructor(e=new re(1,0,0),t=0){this.isPlane=!0,this.normal=e,this.constant=t}set(e,t){return this.normal.copy(e),this.constant=t,this}setComponents(e,t,r,a){return this.normal.set(e,t,r),this.constant=a,this}setFromNormalAndCoplanarPoint(e,t){return this.normal.copy(e),this.constant=-t.dot(this.normal),this}setFromCoplanarPoints(e,t,r){const a=Jf.subVectors(r,t).cross(_b.subVectors(e,t)).normalize();return this.setFromNormalAndCoplanarPoint(a,e),this}copy(e){return this.normal.copy(e.normal),this.constant=e.constant,this}normalize(){const e=1/this.normal.length();return this.normal.multiplyScalar(e),this.constant*=e,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(e){return this.normal.dot(e)+this.constant}distanceToSphere(e){return this.distanceToPoint(e.center)-e.radius}projectPoint(e,t){return t.copy(e).addScaledVector(this.normal,-this.distanceToPoint(e))}intersectLine(e,t){const r=e.delta(Jf),a=this.normal.dot(r);if(a===0)return this.distanceToPoint(e.start)===0?t.copy(e.start):null;const c=-(e.start.dot(this.normal)+this.constant)/a;return c<0||c>1?null:t.copy(e.start).addScaledVector(r,c)}intersectsLine(e){const t=this.distanceToPoint(e.start),r=this.distanceToPoint(e.end);return t<0&&r>0||r<0&&t>0}intersectsBox(e){return e.intersectsPlane(this)}intersectsSphere(e){return e.intersectsPlane(this)}coplanarPoint(e){return e.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(e,t){const r=t||vb.getNormalMatrix(e),a=this.coplanarPoint(Jf).applyMatrix4(e),c=this.normal.applyMatrix3(r).normalize();return this.constant=-a.dot(c),this}translate(e){return this.constant-=e.dot(this.normal),this}equals(e){return e.normal.equals(this.normal)&&e.constant===this.constant}clone(){return new this.constructor().copy(this)}}const Rs=new zp,Vc=new re;class xx{constructor(e=new ks,t=new ks,r=new ks,a=new ks,c=new ks,u=new ks){this.planes=[e,t,r,a,c,u]}set(e,t,r,a,c,u){const d=this.planes;return d[0].copy(e),d[1].copy(t),d[2].copy(r),d[3].copy(a),d[4].copy(c),d[5].copy(u),this}copy(e){const t=this.planes;for(let r=0;r<6;r++)t[r].copy(e.planes[r]);return this}setFromProjectionMatrix(e,t=yr){const r=this.planes,a=e.elements,c=a[0],u=a[1],d=a[2],h=a[3],p=a[4],g=a[5],y=a[6],v=a[7],x=a[8],w=a[9],E=a[10],_=a[11],M=a[12],k=a[13],A=a[14],R=a[15];if(r[0].setComponents(h-c,v-p,_-x,R-M).normalize(),r[1].setComponents(h+c,v+p,_+x,R+M).normalize(),r[2].setComponents(h+u,v+g,_+w,R+k).normalize(),r[3].setComponents(h-u,v-g,_-w,R-k).normalize(),r[4].setComponents(h-d,v-y,_-E,R-A).normalize(),t===yr)r[5].setComponents(h+d,v+y,_+E,R+A).normalize();else if(t===_u)r[5].setComponents(d,y,E,A).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+t);return this}intersectsObject(e){if(e.boundingSphere!==void 0)e.boundingSphere===null&&e.computeBoundingSphere(),Rs.copy(e.boundingSphere).applyMatrix4(e.matrixWorld);else{const t=e.geometry;t.boundingSphere===null&&t.computeBoundingSphere(),Rs.copy(t.boundingSphere).applyMatrix4(e.matrixWorld)}return this.intersectsSphere(Rs)}intersectsSprite(e){return Rs.center.set(0,0,0),Rs.radius=.7071067811865476,Rs.applyMatrix4(e.matrixWorld),this.intersectsSphere(Rs)}intersectsSphere(e){const t=this.planes,r=e.center,a=-e.radius;for(let c=0;c<6;c++)if(t[c].distanceToPoint(r)<a)return!1;return!0}intersectsBox(e){const t=this.planes;for(let r=0;r<6;r++){const a=t[r];if(Vc.x=a.normal.x>0?e.max.x:e.min.x,Vc.y=a.normal.y>0?e.max.y:e.min.y,Vc.z=a.normal.z>0?e.max.z:e.min.z,a.distanceToPoint(Vc)<0)return!1}return!0}containsPoint(e){const t=this.planes;for(let r=0;r<6;r++)if(t[r].distanceToPoint(e)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}}function yx(){let n=null,e=!1,t=null,r=null;function a(c,u){t(c,u),r=n.requestAnimationFrame(a)}return{start:function(){e!==!0&&t!==null&&(r=n.requestAnimationFrame(a),e=!0)},stop:function(){n.cancelAnimationFrame(r),e=!1},setAnimationLoop:function(c){t=c},setContext:function(c){n=c}}}function xb(n){const e=new WeakMap;function t(d,h){const p=d.array,g=d.usage,y=p.byteLength,v=n.createBuffer();n.bindBuffer(h,v),n.bufferData(h,p,g),d.onUploadCallback();let x;if(p instanceof Float32Array)x=n.FLOAT;else if(p instanceof Uint16Array)d.isFloat16BufferAttribute?x=n.HALF_FLOAT:x=n.UNSIGNED_SHORT;else if(p instanceof Int16Array)x=n.SHORT;else if(p instanceof Uint32Array)x=n.UNSIGNED_INT;else if(p instanceof Int32Array)x=n.INT;else if(p instanceof Int8Array)x=n.BYTE;else if(p instanceof Uint8Array)x=n.UNSIGNED_BYTE;else if(p instanceof Uint8ClampedArray)x=n.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+p);return{buffer:v,type:x,bytesPerElement:p.BYTES_PER_ELEMENT,version:d.version,size:y}}function r(d,h,p){const g=h.array,y=h.updateRanges;if(n.bindBuffer(p,d),y.length===0)n.bufferSubData(p,0,g);else{y.sort((x,w)=>x.start-w.start);let v=0;for(let x=1;x<y.length;x++){const w=y[v],E=y[x];E.start<=w.start+w.count+1?w.count=Math.max(w.count,E.start+E.count-w.start):(++v,y[v]=E)}y.length=v+1;for(let x=0,w=y.length;x<w;x++){const E=y[x];n.bufferSubData(p,E.start*g.BYTES_PER_ELEMENT,g,E.start,E.count)}h.clearUpdateRanges()}h.onUploadCallback()}function a(d){return d.isInterleavedBufferAttribute&&(d=d.data),e.get(d)}function c(d){d.isInterleavedBufferAttribute&&(d=d.data);const h=e.get(d);h&&(n.deleteBuffer(h.buffer),e.delete(d))}function u(d,h){if(d.isInterleavedBufferAttribute&&(d=d.data),d.isGLBufferAttribute){const g=e.get(d);(!g||g.version<d.version)&&e.set(d,{buffer:d.buffer,type:d.type,bytesPerElement:d.elementSize,version:d.version});return}const p=e.get(d);if(p===void 0)e.set(d,t(d,h));else if(p.version<d.version){if(p.size!==d.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");r(p.buffer,d,h),p.version=d.version}}return{get:a,remove:c,update:u}}class ml extends Ar{constructor(e=1,t=1,r=1,a=1){super(),this.type="PlaneGeometry",this.parameters={width:e,height:t,widthSegments:r,heightSegments:a};const c=e/2,u=t/2,d=Math.floor(r),h=Math.floor(a),p=d+1,g=h+1,y=e/d,v=t/h,x=[],w=[],E=[],_=[];for(let M=0;M<g;M++){const k=M*v-u;for(let A=0;A<p;A++){const R=A*y-c;w.push(R,-k,0),E.push(0,0,1),_.push(A/d),_.push(1-M/h)}}for(let M=0;M<h;M++)for(let k=0;k<d;k++){const A=k+p*M,R=k+p*(M+1),L=k+1+p*(M+1),D=k+1+p*M;x.push(A,R,D),x.push(R,L,D)}this.setIndex(x),this.setAttribute("position",new li(w,3)),this.setAttribute("normal",new li(E,3)),this.setAttribute("uv",new li(_,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new ml(e.width,e.height,e.widthSegments,e.heightSegments)}}var yb=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,Sb=`#ifdef USE_ALPHAHASH
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
#endif`,Mb=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,Eb=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,wb=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,Tb=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,bb=`#ifdef USE_AOMAP
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
#endif`,Ab=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,Cb=`#ifdef USE_BATCHING
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
#endif`,Nb=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,Rb=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Pb=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,Lb=`float G_BlinnPhong_Implicit( ) {
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
} // validated`,kb=`#ifdef USE_IRIDESCENCE
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
#endif`,Db=`#ifdef USE_BUMPMAP
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
#endif`,Ib=`#if NUM_CLIPPING_PLANES > 0
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
#endif`,Ub=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,Fb=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,Ob=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,jb=`#if defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#elif defined( USE_COLOR )
	diffuseColor.rgb *= vColor;
#endif`,zb=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR )
	varying vec3 vColor;
#endif`,Bb=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec3 vColor;
#endif`,Hb=`#if defined( USE_COLOR_ALPHA )
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
#endif`,Vb=`#define PI 3.141592653589793
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
} // validated`,Gb=`#ifdef ENVMAP_TYPE_CUBE_UV
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
#endif`,Wb=`vec3 transformedNormal = objectNormal;
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
#endif`,$b=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,Xb=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,qb=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,Yb=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,Kb="gl_FragColor = linearToOutputTexel( gl_FragColor );",Zb=`
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
}`,Qb=`#ifdef USE_ENVMAP
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
#endif`,Jb=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform float flipEnvMap;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
	
#endif`,eA=`#ifdef USE_ENVMAP
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
#endif`,tA=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,nA=`#ifdef USE_ENVMAP
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
#endif`,iA=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,rA=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,sA=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,aA=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,oA=`#ifdef USE_GRADIENTMAP
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
}`,lA=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,cA=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,uA=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,dA=`uniform bool receiveShadow;
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
#endif`,fA=`#ifdef USE_ENVMAP
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
#endif`,hA=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,pA=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,mA=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,gA=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,_A=`PhysicalMaterial material;
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
#endif`,vA=`struct PhysicalMaterial {
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
}`,xA=`
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
#endif`,yA=`#if defined( RE_IndirectDiffuse )
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
#endif`,SA=`#if defined( RE_IndirectDiffuse )
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,MA=`#if defined( USE_LOGDEPTHBUF )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,EA=`#if defined( USE_LOGDEPTHBUF )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,wA=`#ifdef USE_LOGDEPTHBUF
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,TA=`#ifdef USE_LOGDEPTHBUF
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,bA=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = vec4( mix( pow( sampledDiffuseColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), sampledDiffuseColor.rgb * 0.0773993808, vec3( lessThanEqual( sampledDiffuseColor.rgb, vec3( 0.04045 ) ) ) ), sampledDiffuseColor.w );
	
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,AA=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,CA=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
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
#endif`,NA=`#if defined( USE_POINTS_UV )
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
#endif`,RA=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,PA=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,LA=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,kA=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,DA=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,IA=`#ifdef USE_MORPHTARGETS
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
#endif`,UA=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,FA=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
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
vec3 nonPerturbedNormal = normal;`,OA=`#ifdef USE_NORMALMAP_OBJECTSPACE
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
#endif`,jA=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,zA=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,BA=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif
#endif`,HA=`#ifdef USE_NORMALMAP
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
#endif`,VA=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,GA=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,WA=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,$A=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,XA=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,qA=`vec3 packNormalToRGB( const in vec3 normal ) {
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
}`,YA=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,KA=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,ZA=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,QA=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,JA=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,eC=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,tC=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,nC=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,iC=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
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
#endif`,rC=`float getShadowMask() {
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
}`,sC=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,aC=`#ifdef USE_SKINNING
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
#endif`,oC=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,lC=`#ifdef USE_SKINNING
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
#endif`,cC=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,uC=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,dC=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,fC=`#ifndef saturate
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
vec3 CustomToneMapping( vec3 color ) { return color; }`,hC=`#ifdef USE_TRANSMISSION
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
#endif`,pC=`#ifdef USE_TRANSMISSION
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
#endif`,mC=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,gC=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,_C=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,vC=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`;const xC=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,yC=`uniform sampler2D t2D;
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
}`,SC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,MC=`#ifdef ENVMAP_TYPE_CUBE
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
}`,EC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,wC=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,TC=`#include <common>
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
}`,bC=`#if DEPTH_PACKING == 3200
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
}`,AC=`#define DISTANCE
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
}`,CC=`#define DISTANCE
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
}`,NC=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,RC=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,PC=`uniform float scale;
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
}`,LC=`uniform vec3 diffuse;
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
}`,kC=`#include <common>
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
}`,DC=`uniform vec3 diffuse;
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
}`,IC=`#define LAMBERT
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
}`,UC=`#define LAMBERT
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
}`,FC=`#define MATCAP
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
}`,OC=`#define MATCAP
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
}`,jC=`#define NORMAL
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
}`,zC=`#define NORMAL
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
}`,BC=`#define PHONG
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
}`,HC=`#define PHONG
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
}`,VC=`#define STANDARD
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
}`,GC=`#define STANDARD
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
}`,WC=`#define TOON
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
}`,$C=`#define TOON
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
}`,XC=`uniform float size;
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
}`,qC=`uniform vec3 diffuse;
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
}`,YC=`#include <common>
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
}`,KC=`uniform vec3 color;
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
}`,ZC=`uniform float rotation;
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
}`,QC=`uniform vec3 diffuse;
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
}`,ut={alphahash_fragment:yb,alphahash_pars_fragment:Sb,alphamap_fragment:Mb,alphamap_pars_fragment:Eb,alphatest_fragment:wb,alphatest_pars_fragment:Tb,aomap_fragment:bb,aomap_pars_fragment:Ab,batching_pars_vertex:Cb,batching_vertex:Nb,begin_vertex:Rb,beginnormal_vertex:Pb,bsdfs:Lb,iridescence_fragment:kb,bumpmap_pars_fragment:Db,clipping_planes_fragment:Ib,clipping_planes_pars_fragment:Ub,clipping_planes_pars_vertex:Fb,clipping_planes_vertex:Ob,color_fragment:jb,color_pars_fragment:zb,color_pars_vertex:Bb,color_vertex:Hb,common:Vb,cube_uv_reflection_fragment:Gb,defaultnormal_vertex:Wb,displacementmap_pars_vertex:$b,displacementmap_vertex:Xb,emissivemap_fragment:qb,emissivemap_pars_fragment:Yb,colorspace_fragment:Kb,colorspace_pars_fragment:Zb,envmap_fragment:Qb,envmap_common_pars_fragment:Jb,envmap_pars_fragment:eA,envmap_pars_vertex:tA,envmap_physical_pars_fragment:fA,envmap_vertex:nA,fog_vertex:iA,fog_pars_vertex:rA,fog_fragment:sA,fog_pars_fragment:aA,gradientmap_pars_fragment:oA,lightmap_pars_fragment:lA,lights_lambert_fragment:cA,lights_lambert_pars_fragment:uA,lights_pars_begin:dA,lights_toon_fragment:hA,lights_toon_pars_fragment:pA,lights_phong_fragment:mA,lights_phong_pars_fragment:gA,lights_physical_fragment:_A,lights_physical_pars_fragment:vA,lights_fragment_begin:xA,lights_fragment_maps:yA,lights_fragment_end:SA,logdepthbuf_fragment:MA,logdepthbuf_pars_fragment:EA,logdepthbuf_pars_vertex:wA,logdepthbuf_vertex:TA,map_fragment:bA,map_pars_fragment:AA,map_particle_fragment:CA,map_particle_pars_fragment:NA,metalnessmap_fragment:RA,metalnessmap_pars_fragment:PA,morphinstance_vertex:LA,morphcolor_vertex:kA,morphnormal_vertex:DA,morphtarget_pars_vertex:IA,morphtarget_vertex:UA,normal_fragment_begin:FA,normal_fragment_maps:OA,normal_pars_fragment:jA,normal_pars_vertex:zA,normal_vertex:BA,normalmap_pars_fragment:HA,clearcoat_normal_fragment_begin:VA,clearcoat_normal_fragment_maps:GA,clearcoat_pars_fragment:WA,iridescence_pars_fragment:$A,opaque_fragment:XA,packing:qA,premultiplied_alpha_fragment:YA,project_vertex:KA,dithering_fragment:ZA,dithering_pars_fragment:QA,roughnessmap_fragment:JA,roughnessmap_pars_fragment:eC,shadowmap_pars_fragment:tC,shadowmap_pars_vertex:nC,shadowmap_vertex:iC,shadowmask_pars_fragment:rC,skinbase_vertex:sC,skinning_pars_vertex:aC,skinning_vertex:oC,skinnormal_vertex:lC,specularmap_fragment:cC,specularmap_pars_fragment:uC,tonemapping_fragment:dC,tonemapping_pars_fragment:fC,transmission_fragment:hC,transmission_pars_fragment:pC,uv_pars_fragment:mC,uv_pars_vertex:gC,uv_vertex:_C,worldpos_vertex:vC,background_vert:xC,background_frag:yC,backgroundCube_vert:SC,backgroundCube_frag:MC,cube_vert:EC,cube_frag:wC,depth_vert:TC,depth_frag:bC,distanceRGBA_vert:AC,distanceRGBA_frag:CC,equirect_vert:NC,equirect_frag:RC,linedashed_vert:PC,linedashed_frag:LC,meshbasic_vert:kC,meshbasic_frag:DC,meshlambert_vert:IC,meshlambert_frag:UC,meshmatcap_vert:FC,meshmatcap_frag:OC,meshnormal_vert:jC,meshnormal_frag:zC,meshphong_vert:BC,meshphong_frag:HC,meshphysical_vert:VC,meshphysical_frag:GC,meshtoon_vert:WC,meshtoon_frag:$C,points_vert:XC,points_frag:qC,shadow_vert:YC,shadow_frag:KC,sprite_vert:ZC,sprite_frag:QC},De={common:{diffuse:{value:new Rt(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new dt}},envmap:{envMap:{value:null},envMapRotation:{value:new dt},flipEnvMap:{value:-1},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new dt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new dt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new dt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new dt},normalScale:{value:new bt(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new dt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new dt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new dt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new dt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new Rt(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMap:{value:[]},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotShadowMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMap:{value:[]},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null}},points:{diffuse:{value:new Rt(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0},uvTransform:{value:new dt}},sprite:{diffuse:{value:new Rt(16777215)},opacity:{value:1},center:{value:new bt(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}}},qi={basic:{uniforms:Un([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.fog]),vertexShader:ut.meshbasic_vert,fragmentShader:ut.meshbasic_frag},lambert:{uniforms:Un([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.fog,De.lights,{emissive:{value:new Rt(0)}}]),vertexShader:ut.meshlambert_vert,fragmentShader:ut.meshlambert_frag},phong:{uniforms:Un([De.common,De.specularmap,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.fog,De.lights,{emissive:{value:new Rt(0)},specular:{value:new Rt(1118481)},shininess:{value:30}}]),vertexShader:ut.meshphong_vert,fragmentShader:ut.meshphong_frag},standard:{uniforms:Un([De.common,De.envmap,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.roughnessmap,De.metalnessmap,De.fog,De.lights,{emissive:{value:new Rt(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:ut.meshphysical_vert,fragmentShader:ut.meshphysical_frag},toon:{uniforms:Un([De.common,De.aomap,De.lightmap,De.emissivemap,De.bumpmap,De.normalmap,De.displacementmap,De.gradientmap,De.fog,De.lights,{emissive:{value:new Rt(0)}}]),vertexShader:ut.meshtoon_vert,fragmentShader:ut.meshtoon_frag},matcap:{uniforms:Un([De.common,De.bumpmap,De.normalmap,De.displacementmap,De.fog,{matcap:{value:null}}]),vertexShader:ut.meshmatcap_vert,fragmentShader:ut.meshmatcap_frag},points:{uniforms:Un([De.points,De.fog]),vertexShader:ut.points_vert,fragmentShader:ut.points_frag},dashed:{uniforms:Un([De.common,De.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:ut.linedashed_vert,fragmentShader:ut.linedashed_frag},depth:{uniforms:Un([De.common,De.displacementmap]),vertexShader:ut.depth_vert,fragmentShader:ut.depth_frag},normal:{uniforms:Un([De.common,De.bumpmap,De.normalmap,De.displacementmap,{opacity:{value:1}}]),vertexShader:ut.meshnormal_vert,fragmentShader:ut.meshnormal_frag},sprite:{uniforms:Un([De.sprite,De.fog]),vertexShader:ut.sprite_vert,fragmentShader:ut.sprite_frag},background:{uniforms:{uvTransform:{value:new dt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:ut.background_vert,fragmentShader:ut.background_frag},backgroundCube:{uniforms:{envMap:{value:null},flipEnvMap:{value:-1},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new dt}},vertexShader:ut.backgroundCube_vert,fragmentShader:ut.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:ut.cube_vert,fragmentShader:ut.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:ut.equirect_vert,fragmentShader:ut.equirect_frag},distanceRGBA:{uniforms:Un([De.common,De.displacementmap,{referencePosition:{value:new re},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:ut.distanceRGBA_vert,fragmentShader:ut.distanceRGBA_frag},shadow:{uniforms:Un([De.lights,De.fog,{color:{value:new Rt(0)},opacity:{value:1}}]),vertexShader:ut.shadow_vert,fragmentShader:ut.shadow_frag}};qi.physical={uniforms:Un([qi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new dt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new dt},clearcoatNormalScale:{value:new bt(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new dt},dispersion:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new dt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new dt},sheen:{value:0},sheenColor:{value:new Rt(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new dt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new dt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new dt},transmissionSamplerSize:{value:new bt},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new dt},attenuationDistance:{value:0},attenuationColor:{value:new Rt(0)},specularColor:{value:new Rt(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new dt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new dt},anisotropyVector:{value:new bt},anisotropyMap:{value:null},anisotropyMapTransform:{value:new dt}}]),vertexShader:ut.meshphysical_vert,fragmentShader:ut.meshphysical_frag};const Gc={r:0,b:0,g:0},Ps=new Tr,JC=new nn;function eN(n,e,t,r,a,c,u){const d=new Rt(0);let h=c===!0?0:1,p,g,y=null,v=0,x=null;function w(k){let A=k.isScene===!0?k.background:null;return A&&A.isTexture&&(A=(k.backgroundBlurriness>0?t:e).get(A)),A}function E(k){let A=!1;const R=w(k);R===null?M(d,h):R&&R.isColor&&(M(R,1),A=!0);const L=n.xr.getEnvironmentBlendMode();L==="additive"?r.buffers.color.setClear(0,0,0,1,u):L==="alpha-blend"&&r.buffers.color.setClear(0,0,0,0,u),(n.autoClear||A)&&(r.buffers.depth.setTest(!0),r.buffers.depth.setMask(!0),r.buffers.color.setMask(!0),n.clear(n.autoClearColor,n.autoClearDepth,n.autoClearStencil))}function _(k,A){const R=w(A);R&&(R.isCubeTexture||R.mapping===Uu)?(g===void 0&&(g=new ji(new pl(1,1,1),new br({name:"BackgroundCubeMaterial",uniforms:Qa(qi.backgroundCube.uniforms),vertexShader:qi.backgroundCube.vertexShader,fragmentShader:qi.backgroundCube.fragmentShader,side:qn,depthTest:!1,depthWrite:!1,fog:!1})),g.geometry.deleteAttribute("normal"),g.geometry.deleteAttribute("uv"),g.onBeforeRender=function(L,D,U){this.matrixWorld.copyPosition(U.matrixWorld)},Object.defineProperty(g.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),a.update(g)),Ps.copy(A.backgroundRotation),Ps.x*=-1,Ps.y*=-1,Ps.z*=-1,R.isCubeTexture&&R.isRenderTargetTexture===!1&&(Ps.y*=-1,Ps.z*=-1),g.material.uniforms.envMap.value=R,g.material.uniforms.flipEnvMap.value=R.isCubeTexture&&R.isRenderTargetTexture===!1?-1:1,g.material.uniforms.backgroundBlurriness.value=A.backgroundBlurriness,g.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,g.material.uniforms.backgroundRotation.value.setFromMatrix4(JC.makeRotationFromEuler(Ps)),g.material.toneMapped=Ct.getTransfer(R.colorSpace)!==Bt,(y!==R||v!==R.version||x!==n.toneMapping)&&(g.material.needsUpdate=!0,y=R,v=R.version,x=n.toneMapping),g.layers.enableAll(),k.unshift(g,g.geometry,g.material,0,0,null)):R&&R.isTexture&&(p===void 0&&(p=new ji(new ml(2,2),new br({name:"BackgroundMaterial",uniforms:Qa(qi.background.uniforms),vertexShader:qi.background.vertexShader,fragmentShader:qi.background.fragmentShader,side:us,depthTest:!1,depthWrite:!1,fog:!1})),p.geometry.deleteAttribute("normal"),Object.defineProperty(p.material,"map",{get:function(){return this.uniforms.t2D.value}}),a.update(p)),p.material.uniforms.t2D.value=R,p.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,p.material.toneMapped=Ct.getTransfer(R.colorSpace)!==Bt,R.matrixAutoUpdate===!0&&R.updateMatrix(),p.material.uniforms.uvTransform.value.copy(R.matrix),(y!==R||v!==R.version||x!==n.toneMapping)&&(p.material.needsUpdate=!0,y=R,v=R.version,x=n.toneMapping),p.layers.enableAll(),k.unshift(p,p.geometry,p.material,0,0,null))}function M(k,A){k.getRGB(Gc,gx(n)),r.buffers.color.setClear(Gc.r,Gc.g,Gc.b,A,u)}return{getClearColor:function(){return d},setClearColor:function(k,A=1){d.set(k),h=A,M(d,h)},getClearAlpha:function(){return h},setClearAlpha:function(k){h=k,M(d,h)},render:E,addToRenderList:_}}function tN(n,e){const t=n.getParameter(n.MAX_VERTEX_ATTRIBS),r={},a=v(null);let c=a,u=!1;function d(T,P,se,J,ae){let ve=!1;const V=y(J,se,P);c!==V&&(c=V,p(c.object)),ve=x(T,J,se,ae),ve&&w(T,J,se,ae),ae!==null&&e.update(ae,n.ELEMENT_ARRAY_BUFFER),(ve||u)&&(u=!1,R(T,P,se,J),ae!==null&&n.bindBuffer(n.ELEMENT_ARRAY_BUFFER,e.get(ae).buffer))}function h(){return n.createVertexArray()}function p(T){return n.bindVertexArray(T)}function g(T){return n.deleteVertexArray(T)}function y(T,P,se){const J=se.wireframe===!0;let ae=r[T.id];ae===void 0&&(ae={},r[T.id]=ae);let ve=ae[P.id];ve===void 0&&(ve={},ae[P.id]=ve);let V=ve[J];return V===void 0&&(V=v(h()),ve[J]=V),V}function v(T){const P=[],se=[],J=[];for(let ae=0;ae<t;ae++)P[ae]=0,se[ae]=0,J[ae]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:P,enabledAttributes:se,attributeDivisors:J,object:T,attributes:{},index:null}}function x(T,P,se,J){const ae=c.attributes,ve=P.attributes;let V=0;const de=se.getAttributes();for(const z in de)if(de[z].location>=0){const oe=ae[z];let O=ve[z];if(O===void 0&&(z==="instanceMatrix"&&T.instanceMatrix&&(O=T.instanceMatrix),z==="instanceColor"&&T.instanceColor&&(O=T.instanceColor)),oe===void 0||oe.attribute!==O||O&&oe.data!==O.data)return!0;V++}return c.attributesNum!==V||c.index!==J}function w(T,P,se,J){const ae={},ve=P.attributes;let V=0;const de=se.getAttributes();for(const z in de)if(de[z].location>=0){let oe=ve[z];oe===void 0&&(z==="instanceMatrix"&&T.instanceMatrix&&(oe=T.instanceMatrix),z==="instanceColor"&&T.instanceColor&&(oe=T.instanceColor));const O={};O.attribute=oe,oe&&oe.data&&(O.data=oe.data),ae[z]=O,V++}c.attributes=ae,c.attributesNum=V,c.index=J}function E(){const T=c.newAttributes;for(let P=0,se=T.length;P<se;P++)T[P]=0}function _(T){M(T,0)}function M(T,P){const se=c.newAttributes,J=c.enabledAttributes,ae=c.attributeDivisors;se[T]=1,J[T]===0&&(n.enableVertexAttribArray(T),J[T]=1),ae[T]!==P&&(n.vertexAttribDivisor(T,P),ae[T]=P)}function k(){const T=c.newAttributes,P=c.enabledAttributes;for(let se=0,J=P.length;se<J;se++)P[se]!==T[se]&&(n.disableVertexAttribArray(se),P[se]=0)}function A(T,P,se,J,ae,ve,V){V===!0?n.vertexAttribIPointer(T,P,se,ae,ve):n.vertexAttribPointer(T,P,se,J,ae,ve)}function R(T,P,se,J){E();const ae=J.attributes,ve=se.getAttributes(),V=P.defaultAttributeValues;for(const de in ve){const z=ve[de];if(z.location>=0){let ue=ae[de];if(ue===void 0&&(de==="instanceMatrix"&&T.instanceMatrix&&(ue=T.instanceMatrix),de==="instanceColor"&&T.instanceColor&&(ue=T.instanceColor)),ue!==void 0){const oe=ue.normalized,O=ue.itemSize,le=e.get(ue);if(le===void 0)continue;const we=le.buffer,K=le.type,he=le.bytesPerElement,Te=K===n.INT||K===n.UNSIGNED_INT||ue.gpuType===kp;if(ue.isInterleavedBufferAttribute){const Ae=ue.data,Ie=Ae.stride,Ue=ue.offset;if(Ae.isInstancedInterleavedBuffer){for(let st=0;st<z.locationSize;st++)M(z.location+st,Ae.meshPerAttribute);T.isInstancedMesh!==!0&&J._maxInstanceCount===void 0&&(J._maxInstanceCount=Ae.meshPerAttribute*Ae.count)}else for(let st=0;st<z.locationSize;st++)_(z.location+st);n.bindBuffer(n.ARRAY_BUFFER,we);for(let st=0;st<z.locationSize;st++)A(z.location+st,O/z.locationSize,K,oe,Ie*he,(Ue+O/z.locationSize*st)*he,Te)}else{if(ue.isInstancedBufferAttribute){for(let Ae=0;Ae<z.locationSize;Ae++)M(z.location+Ae,ue.meshPerAttribute);T.isInstancedMesh!==!0&&J._maxInstanceCount===void 0&&(J._maxInstanceCount=ue.meshPerAttribute*ue.count)}else for(let Ae=0;Ae<z.locationSize;Ae++)_(z.location+Ae);n.bindBuffer(n.ARRAY_BUFFER,we);for(let Ae=0;Ae<z.locationSize;Ae++)A(z.location+Ae,O/z.locationSize,K,oe,O*he,O/z.locationSize*Ae*he,Te)}}else if(V!==void 0){const oe=V[de];if(oe!==void 0)switch(oe.length){case 2:n.vertexAttrib2fv(z.location,oe);break;case 3:n.vertexAttrib3fv(z.location,oe);break;case 4:n.vertexAttrib4fv(z.location,oe);break;default:n.vertexAttrib1fv(z.location,oe)}}}}k()}function L(){$();for(const T in r){const P=r[T];for(const se in P){const J=P[se];for(const ae in J)g(J[ae].object),delete J[ae];delete P[se]}delete r[T]}}function D(T){if(r[T.id]===void 0)return;const P=r[T.id];for(const se in P){const J=P[se];for(const ae in J)g(J[ae].object),delete J[ae];delete P[se]}delete r[T.id]}function U(T){for(const P in r){const se=r[P];if(se[T.id]===void 0)continue;const J=se[T.id];for(const ae in J)g(J[ae].object),delete J[ae];delete se[T.id]}}function $(){te(),u=!0,c!==a&&(c=a,p(c.object))}function te(){a.geometry=null,a.program=null,a.wireframe=!1}return{setup:d,reset:$,resetDefaultState:te,dispose:L,releaseStatesOfGeometry:D,releaseStatesOfProgram:U,initAttributes:E,enableAttribute:_,disableUnusedAttributes:k}}function nN(n,e,t){let r;function a(p){r=p}function c(p,g){n.drawArrays(r,p,g),t.update(g,r,1)}function u(p,g,y){y!==0&&(n.drawArraysInstanced(r,p,g,y),t.update(g,r,y))}function d(p,g,y){if(y===0)return;e.get("WEBGL_multi_draw").multiDrawArraysWEBGL(r,p,0,g,0,y);let x=0;for(let w=0;w<y;w++)x+=g[w];t.update(x,r,1)}function h(p,g,y,v){if(y===0)return;const x=e.get("WEBGL_multi_draw");if(x===null)for(let w=0;w<p.length;w++)u(p[w],g[w],v[w]);else{x.multiDrawArraysInstancedWEBGL(r,p,0,g,0,v,0,y);let w=0;for(let E=0;E<y;E++)w+=g[E];for(let E=0;E<v.length;E++)t.update(w,r,v[E])}}this.setMode=a,this.render=c,this.renderInstances=u,this.renderMultiDraw=d,this.renderMultiDrawInstances=h}function iN(n,e,t,r){let a;function c(){if(a!==void 0)return a;if(e.has("EXT_texture_filter_anisotropic")===!0){const U=e.get("EXT_texture_filter_anisotropic");a=n.getParameter(U.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else a=0;return a}function u(U){return!(U!==Oi&&r.convert(U)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_FORMAT))}function d(U){const $=U===ul&&(e.has("EXT_color_buffer_half_float")||e.has("EXT_color_buffer_float"));return!(U!==wr&&r.convert(U)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_TYPE)&&U!==xr&&!$)}function h(U){if(U==="highp"){if(n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.HIGH_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.HIGH_FLOAT).precision>0)return"highp";U="mediump"}return U==="mediump"&&n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.MEDIUM_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let p=t.precision!==void 0?t.precision:"highp";const g=h(p);g!==p&&(console.warn("THREE.WebGLRenderer:",p,"not supported, using",g,"instead."),p=g);const y=t.logarithmicDepthBuffer===!0,v=t.reverseDepthBuffer===!0&&e.has("EXT_clip_control");if(v===!0){const U=e.get("EXT_clip_control");U.clipControlEXT(U.LOWER_LEFT_EXT,U.ZERO_TO_ONE_EXT)}const x=n.getParameter(n.MAX_TEXTURE_IMAGE_UNITS),w=n.getParameter(n.MAX_VERTEX_TEXTURE_IMAGE_UNITS),E=n.getParameter(n.MAX_TEXTURE_SIZE),_=n.getParameter(n.MAX_CUBE_MAP_TEXTURE_SIZE),M=n.getParameter(n.MAX_VERTEX_ATTRIBS),k=n.getParameter(n.MAX_VERTEX_UNIFORM_VECTORS),A=n.getParameter(n.MAX_VARYING_VECTORS),R=n.getParameter(n.MAX_FRAGMENT_UNIFORM_VECTORS),L=w>0,D=n.getParameter(n.MAX_SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:c,getMaxPrecision:h,textureFormatReadable:u,textureTypeReadable:d,precision:p,logarithmicDepthBuffer:y,reverseDepthBuffer:v,maxTextures:x,maxVertexTextures:w,maxTextureSize:E,maxCubemapSize:_,maxAttributes:M,maxVertexUniforms:k,maxVaryings:A,maxFragmentUniforms:R,vertexTextures:L,maxSamples:D}}function rN(n){const e=this;let t=null,r=0,a=!1,c=!1;const u=new ks,d=new dt,h={value:null,needsUpdate:!1};this.uniform=h,this.numPlanes=0,this.numIntersection=0,this.init=function(y,v){const x=y.length!==0||v||r!==0||a;return a=v,r=y.length,x},this.beginShadows=function(){c=!0,g(null)},this.endShadows=function(){c=!1},this.setGlobalState=function(y,v){t=g(y,v,0)},this.setState=function(y,v,x){const w=y.clippingPlanes,E=y.clipIntersection,_=y.clipShadows,M=n.get(y);if(!a||w===null||w.length===0||c&&!_)c?g(null):p();else{const k=c?0:r,A=k*4;let R=M.clippingState||null;h.value=R,R=g(w,v,A,x);for(let L=0;L!==A;++L)R[L]=t[L];M.clippingState=R,this.numIntersection=E?this.numPlanes:0,this.numPlanes+=k}};function p(){h.value!==t&&(h.value=t,h.needsUpdate=r>0),e.numPlanes=r,e.numIntersection=0}function g(y,v,x,w){const E=y!==null?y.length:0;let _=null;if(E!==0){if(_=h.value,w!==!0||_===null){const M=x+E*4,k=v.matrixWorldInverse;d.getNormalMatrix(k),(_===null||_.length<M)&&(_=new Float32Array(M));for(let A=0,R=x;A!==E;++A,R+=4)u.copy(y[A]).applyMatrix4(k,d),u.normal.toArray(_,R),_[R+3]=u.constant}h.value=_,h.needsUpdate=!0}return e.numPlanes=E,e.numIntersection=0,_}}function sN(n){let e=new WeakMap;function t(u,d){return d===Rh?u.mapping=qa:d===Ph&&(u.mapping=Ya),u}function r(u){if(u&&u.isTexture){const d=u.mapping;if(d===Rh||d===Ph)if(e.has(u)){const h=e.get(u).texture;return t(h,u.mapping)}else{const h=u.image;if(h&&h.height>0){const p=new gb(h.height);return p.fromEquirectangularTexture(n,u),e.set(u,p),u.addEventListener("dispose",a),t(p.texture,u.mapping)}else return null}}return u}function a(u){const d=u.target;d.removeEventListener("dispose",a);const h=e.get(d);h!==void 0&&(e.delete(d),h.dispose())}function c(){e=new WeakMap}return{get:r,dispose:c}}class Sx extends _x{constructor(e=-1,t=1,r=1,a=-1,c=.1,u=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=e,this.right=t,this.top=r,this.bottom=a,this.near=c,this.far=u,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.left=e.left,this.right=e.right,this.top=e.top,this.bottom=e.bottom,this.near=e.near,this.far=e.far,this.zoom=e.zoom,this.view=e.view===null?null:Object.assign({},e.view),this}setViewOffset(e,t,r,a,c,u){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=r,this.view.offsetY=a,this.view.width=c,this.view.height=u,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=(this.right-this.left)/(2*this.zoom),t=(this.top-this.bottom)/(2*this.zoom),r=(this.right+this.left)/2,a=(this.top+this.bottom)/2;let c=r-e,u=r+e,d=a+t,h=a-t;if(this.view!==null&&this.view.enabled){const p=(this.right-this.left)/this.view.fullWidth/this.zoom,g=(this.top-this.bottom)/this.view.fullHeight/this.zoom;c+=p*this.view.offsetX,u=c+p*this.view.width,d-=g*this.view.offsetY,h=d-g*this.view.height}this.projectionMatrix.makeOrthographic(c,u,d,h,this.near,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.zoom=this.zoom,t.object.left=this.left,t.object.right=this.right,t.object.top=this.top,t.object.bottom=this.bottom,t.object.near=this.near,t.object.far=this.far,this.view!==null&&(t.object.view=Object.assign({},this.view)),t}}const ja=4,A_=[.125,.215,.35,.446,.526,.582],Us=20,eh=new Sx,C_=new Rt;let th=null,nh=0,ih=0,rh=!1;const Ds=(1+Math.sqrt(5))/2,Fa=1/Ds,N_=[new re(-Ds,Fa,0),new re(Ds,Fa,0),new re(-Fa,0,Ds),new re(Fa,0,Ds),new re(0,Ds,-Fa),new re(0,Ds,Fa),new re(-1,1,-1),new re(1,1,-1),new re(-1,1,1),new re(1,1,1)];class R_{constructor(e){this._renderer=e,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._lodPlanes=[],this._sizeLods=[],this._sigmas=[],this._blurMaterial=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._compileMaterial(this._blurMaterial)}fromScene(e,t=0,r=.1,a=100){th=this._renderer.getRenderTarget(),nh=this._renderer.getActiveCubeFace(),ih=this._renderer.getActiveMipmapLevel(),rh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(256);const c=this._allocateTargets();return c.depthBuffer=!0,this._sceneToCubeUV(e,r,a,c),t>0&&this._blur(c,0,0,t),this._applyPMREM(c),this._cleanup(c),c}fromEquirectangular(e,t=null){return this._fromTexture(e,t)}fromCubemap(e,t=null){return this._fromTexture(e,t)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=k_(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=L_(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose()}_setSize(e){this._lodMax=Math.floor(Math.log2(e)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let e=0;e<this._lodPlanes.length;e++)this._lodPlanes[e].dispose()}_cleanup(e){this._renderer.setRenderTarget(th,nh,ih),this._renderer.xr.enabled=rh,e.scissorTest=!1,Wc(e,0,0,e.width,e.height)}_fromTexture(e,t){e.mapping===qa||e.mapping===Ya?this._setSize(e.image.length===0?16:e.image[0].width||e.image[0].image.width):this._setSize(e.image.width/4),th=this._renderer.getRenderTarget(),nh=this._renderer.getActiveCubeFace(),ih=this._renderer.getActiveMipmapLevel(),rh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;const r=t||this._allocateTargets();return this._textureToCubeUV(e,r),this._applyPMREM(r),this._cleanup(r),r}_allocateTargets(){const e=3*Math.max(this._cubeSize,112),t=4*this._cubeSize,r={magFilter:Di,minFilter:Di,generateMipmaps:!1,type:ul,format:Oi,colorSpace:fs,depthBuffer:!1},a=P_(e,t,r);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==e||this._pingPongRenderTarget.height!==t){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=P_(e,t,r);const{_lodMax:c}=this;({sizeLods:this._sizeLods,lodPlanes:this._lodPlanes,sigmas:this._sigmas}=aN(c)),this._blurMaterial=oN(c,e,t)}return a}_compileMaterial(e){const t=new ji(this._lodPlanes[0],e);this._renderer.compile(t,eh)}_sceneToCubeUV(e,t,r,a){const d=new xi(90,1,t,r),h=[1,-1,1,1,1,1],p=[1,1,1,-1,-1,-1],g=this._renderer,y=g.autoClear,v=g.toneMapping;g.getClearColor(C_),g.toneMapping=os,g.autoClear=!1;const x=new Bp({name:"PMREM.Background",side:qn,depthWrite:!1,depthTest:!1}),w=new ji(new pl,x);let E=!1;const _=e.background;_?_.isColor&&(x.color.copy(_),e.background=null,E=!0):(x.color.copy(C_),E=!0);for(let M=0;M<6;M++){const k=M%3;k===0?(d.up.set(0,h[M],0),d.lookAt(p[M],0,0)):k===1?(d.up.set(0,0,h[M]),d.lookAt(0,p[M],0)):(d.up.set(0,h[M],0),d.lookAt(0,0,p[M]));const A=this._cubeSize;Wc(a,k*A,M>2?A:0,A,A),g.setRenderTarget(a),E&&g.render(w,d),g.render(e,d)}w.geometry.dispose(),w.material.dispose(),g.toneMapping=v,g.autoClear=y,e.background=_}_textureToCubeUV(e,t){const r=this._renderer,a=e.mapping===qa||e.mapping===Ya;a?(this._cubemapMaterial===null&&(this._cubemapMaterial=k_()),this._cubemapMaterial.uniforms.flipEnvMap.value=e.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=L_());const c=a?this._cubemapMaterial:this._equirectMaterial,u=new ji(this._lodPlanes[0],c),d=c.uniforms;d.envMap.value=e;const h=this._cubeSize;Wc(t,0,0,3*h,2*h),r.setRenderTarget(t),r.render(u,eh)}_applyPMREM(e){const t=this._renderer,r=t.autoClear;t.autoClear=!1;const a=this._lodPlanes.length;for(let c=1;c<a;c++){const u=Math.sqrt(this._sigmas[c]*this._sigmas[c]-this._sigmas[c-1]*this._sigmas[c-1]),d=N_[(a-c-1)%N_.length];this._blur(e,c-1,c,u,d)}t.autoClear=r}_blur(e,t,r,a,c){const u=this._pingPongRenderTarget;this._halfBlur(e,u,t,r,a,"latitudinal",c),this._halfBlur(u,e,r,r,a,"longitudinal",c)}_halfBlur(e,t,r,a,c,u,d){const h=this._renderer,p=this._blurMaterial;u!=="latitudinal"&&u!=="longitudinal"&&console.error("blur direction must be either latitudinal or longitudinal!");const g=3,y=new ji(this._lodPlanes[a],p),v=p.uniforms,x=this._sizeLods[r]-1,w=isFinite(c)?Math.PI/(2*x):2*Math.PI/(2*Us-1),E=c/w,_=isFinite(c)?1+Math.floor(g*E):Us;_>Us&&console.warn(`sigmaRadians, ${c}, is too large and will clip, as it requested ${_} samples when the maximum is set to ${Us}`);const M=[];let k=0;for(let U=0;U<Us;++U){const $=U/E,te=Math.exp(-$*$/2);M.push(te),U===0?k+=te:U<_&&(k+=2*te)}for(let U=0;U<M.length;U++)M[U]=M[U]/k;v.envMap.value=e.texture,v.samples.value=_,v.weights.value=M,v.latitudinal.value=u==="latitudinal",d&&(v.poleAxis.value=d);const{_lodMax:A}=this;v.dTheta.value=w,v.mipInt.value=A-r;const R=this._sizeLods[a],L=3*R*(a>A-ja?a-A+ja:0),D=4*(this._cubeSize-R);Wc(t,L,D,3*R,2*R),h.setRenderTarget(t),h.render(y,eh)}}function aN(n){const e=[],t=[],r=[];let a=n;const c=n-ja+1+A_.length;for(let u=0;u<c;u++){const d=Math.pow(2,a);t.push(d);let h=1/d;u>n-ja?h=A_[u-n+ja-1]:u===0&&(h=0),r.push(h);const p=1/(d-2),g=-p,y=1+p,v=[g,g,y,g,y,y,g,g,y,y,g,y],x=6,w=6,E=3,_=2,M=1,k=new Float32Array(E*w*x),A=new Float32Array(_*w*x),R=new Float32Array(M*w*x);for(let D=0;D<x;D++){const U=D%3*2/3-1,$=D>2?0:-1,te=[U,$,0,U+2/3,$,0,U+2/3,$+1,0,U,$,0,U+2/3,$+1,0,U,$+1,0];k.set(te,E*w*D),A.set(v,_*w*D);const T=[D,D,D,D,D,D];R.set(T,M*w*D)}const L=new Ar;L.setAttribute("position",new Ki(k,E)),L.setAttribute("uv",new Ki(A,_)),L.setAttribute("faceIndex",new Ki(R,M)),e.push(L),a>ja&&a--}return{lodPlanes:e,sizeLods:t,sigmas:r}}function P_(n,e,t){const r=new qs(n,e,t);return r.texture.mapping=Uu,r.texture.name="PMREM.cubeUv",r.scissorTest=!0,r}function Wc(n,e,t,r,a){n.viewport.set(e,t,r,a),n.scissor.set(e,t,r,a)}function oN(n,e,t){const r=new Float32Array(Us),a=new re(0,1,0);return new br({name:"SphericalGaussianBlur",defines:{n:Us,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${n}.0`},uniforms:{envMap:{value:null},samples:{value:1},weights:{value:r},latitudinal:{value:!1},dTheta:{value:0},mipInt:{value:0},poleAxis:{value:a}},vertexShader:Hp(),fragmentShader:`

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
		`,blending:as,depthTest:!1,depthWrite:!1})}function L_(){return new br({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Hp(),fragmentShader:`

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
		`,blending:as,depthTest:!1,depthWrite:!1})}function k_(){return new br({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Hp(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:as,depthTest:!1,depthWrite:!1})}function Hp(){return`

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
	`}function lN(n){let e=new WeakMap,t=null;function r(d){if(d&&d.isTexture){const h=d.mapping,p=h===Rh||h===Ph,g=h===qa||h===Ya;if(p||g){let y=e.get(d);const v=y!==void 0?y.texture.pmremVersion:0;if(d.isRenderTargetTexture&&d.pmremVersion!==v)return t===null&&(t=new R_(n)),y=p?t.fromEquirectangular(d,y):t.fromCubemap(d,y),y.texture.pmremVersion=d.pmremVersion,e.set(d,y),y.texture;if(y!==void 0)return y.texture;{const x=d.image;return p&&x&&x.height>0||g&&x&&a(x)?(t===null&&(t=new R_(n)),y=p?t.fromEquirectangular(d):t.fromCubemap(d),y.texture.pmremVersion=d.pmremVersion,e.set(d,y),d.addEventListener("dispose",c),y.texture):null}}}return d}function a(d){let h=0;const p=6;for(let g=0;g<p;g++)d[g]!==void 0&&h++;return h===p}function c(d){const h=d.target;h.removeEventListener("dispose",c);const p=e.get(h);p!==void 0&&(e.delete(h),p.dispose())}function u(){e=new WeakMap,t!==null&&(t.dispose(),t=null)}return{get:r,dispose:u}}function cN(n){const e={};function t(r){if(e[r]!==void 0)return e[r];let a;switch(r){case"WEBGL_depth_texture":a=n.getExtension("WEBGL_depth_texture")||n.getExtension("MOZ_WEBGL_depth_texture")||n.getExtension("WEBKIT_WEBGL_depth_texture");break;case"EXT_texture_filter_anisotropic":a=n.getExtension("EXT_texture_filter_anisotropic")||n.getExtension("MOZ_EXT_texture_filter_anisotropic")||n.getExtension("WEBKIT_EXT_texture_filter_anisotropic");break;case"WEBGL_compressed_texture_s3tc":a=n.getExtension("WEBGL_compressed_texture_s3tc")||n.getExtension("MOZ_WEBGL_compressed_texture_s3tc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_s3tc");break;case"WEBGL_compressed_texture_pvrtc":a=n.getExtension("WEBGL_compressed_texture_pvrtc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");break;default:a=n.getExtension(r)}return e[r]=a,a}return{has:function(r){return t(r)!==null},init:function(){t("EXT_color_buffer_float"),t("WEBGL_clip_cull_distance"),t("OES_texture_float_linear"),t("EXT_color_buffer_half_float"),t("WEBGL_multisampled_render_to_texture"),t("WEBGL_render_shared_exponent")},get:function(r){const a=t(r);return a===null&&ru("THREE.WebGLRenderer: "+r+" extension not supported."),a}}}function uN(n,e,t,r){const a={},c=new WeakMap;function u(y){const v=y.target;v.index!==null&&e.remove(v.index);for(const w in v.attributes)e.remove(v.attributes[w]);for(const w in v.morphAttributes){const E=v.morphAttributes[w];for(let _=0,M=E.length;_<M;_++)e.remove(E[_])}v.removeEventListener("dispose",u),delete a[v.id];const x=c.get(v);x&&(e.remove(x),c.delete(v)),r.releaseStatesOfGeometry(v),v.isInstancedBufferGeometry===!0&&delete v._maxInstanceCount,t.memory.geometries--}function d(y,v){return a[v.id]===!0||(v.addEventListener("dispose",u),a[v.id]=!0,t.memory.geometries++),v}function h(y){const v=y.attributes;for(const w in v)e.update(v[w],n.ARRAY_BUFFER);const x=y.morphAttributes;for(const w in x){const E=x[w];for(let _=0,M=E.length;_<M;_++)e.update(E[_],n.ARRAY_BUFFER)}}function p(y){const v=[],x=y.index,w=y.attributes.position;let E=0;if(x!==null){const k=x.array;E=x.version;for(let A=0,R=k.length;A<R;A+=3){const L=k[A+0],D=k[A+1],U=k[A+2];v.push(L,D,D,U,U,L)}}else if(w!==void 0){const k=w.array;E=w.version;for(let A=0,R=k.length/3-1;A<R;A+=3){const L=A+0,D=A+1,U=A+2;v.push(L,D,D,U,U,L)}}else return;const _=new(cx(v)?mx:px)(v,1);_.version=E;const M=c.get(y);M&&e.remove(M),c.set(y,_)}function g(y){const v=c.get(y);if(v){const x=y.index;x!==null&&v.version<x.version&&p(y)}else p(y);return c.get(y)}return{get:d,update:h,getWireframeAttribute:g}}function dN(n,e,t){let r;function a(v){r=v}let c,u;function d(v){c=v.type,u=v.bytesPerElement}function h(v,x){n.drawElements(r,x,c,v*u),t.update(x,r,1)}function p(v,x,w){w!==0&&(n.drawElementsInstanced(r,x,c,v*u,w),t.update(x,r,w))}function g(v,x,w){if(w===0)return;e.get("WEBGL_multi_draw").multiDrawElementsWEBGL(r,x,0,c,v,0,w);let _=0;for(let M=0;M<w;M++)_+=x[M];t.update(_,r,1)}function y(v,x,w,E){if(w===0)return;const _=e.get("WEBGL_multi_draw");if(_===null)for(let M=0;M<v.length;M++)p(v[M]/u,x[M],E[M]);else{_.multiDrawElementsInstancedWEBGL(r,x,0,c,v,0,E,0,w);let M=0;for(let k=0;k<w;k++)M+=x[k];for(let k=0;k<E.length;k++)t.update(M,r,E[k])}}this.setMode=a,this.setIndex=d,this.render=h,this.renderInstances=p,this.renderMultiDraw=g,this.renderMultiDrawInstances=y}function fN(n){const e={geometries:0,textures:0},t={frame:0,calls:0,triangles:0,points:0,lines:0};function r(c,u,d){switch(t.calls++,u){case n.TRIANGLES:t.triangles+=d*(c/3);break;case n.LINES:t.lines+=d*(c/2);break;case n.LINE_STRIP:t.lines+=d*(c-1);break;case n.LINE_LOOP:t.lines+=d*c;break;case n.POINTS:t.points+=d*c;break;default:console.error("THREE.WebGLInfo: Unknown draw mode:",u);break}}function a(){t.calls=0,t.triangles=0,t.points=0,t.lines=0}return{memory:e,render:t,programs:null,autoReset:!0,reset:a,update:r}}function hN(n,e,t){const r=new WeakMap,a=new Qt;function c(u,d,h){const p=u.morphTargetInfluences,g=d.morphAttributes.position||d.morphAttributes.normal||d.morphAttributes.color,y=g!==void 0?g.length:0;let v=r.get(d);if(v===void 0||v.count!==y){let te=function(){U.dispose(),r.delete(d),d.removeEventListener("dispose",te)};v!==void 0&&v.texture.dispose();const x=d.morphAttributes.position!==void 0,w=d.morphAttributes.normal!==void 0,E=d.morphAttributes.color!==void 0,_=d.morphAttributes.position||[],M=d.morphAttributes.normal||[],k=d.morphAttributes.color||[];let A=0;x===!0&&(A=1),w===!0&&(A=2),E===!0&&(A=3);let R=d.attributes.position.count*A,L=1;R>e.maxTextureSize&&(L=Math.ceil(R/e.maxTextureSize),R=e.maxTextureSize);const D=new Float32Array(R*L*4*y),U=new dx(D,R,L,y);U.type=xr,U.needsUpdate=!0;const $=A*4;for(let T=0;T<y;T++){const P=_[T],se=M[T],J=k[T],ae=R*L*4*T;for(let ve=0;ve<P.count;ve++){const V=ve*$;x===!0&&(a.fromBufferAttribute(P,ve),D[ae+V+0]=a.x,D[ae+V+1]=a.y,D[ae+V+2]=a.z,D[ae+V+3]=0),w===!0&&(a.fromBufferAttribute(se,ve),D[ae+V+4]=a.x,D[ae+V+5]=a.y,D[ae+V+6]=a.z,D[ae+V+7]=0),E===!0&&(a.fromBufferAttribute(J,ve),D[ae+V+8]=a.x,D[ae+V+9]=a.y,D[ae+V+10]=a.z,D[ae+V+11]=J.itemSize===4?a.w:1)}}v={count:y,texture:U,size:new bt(R,L)},r.set(d,v),d.addEventListener("dispose",te)}if(u.isInstancedMesh===!0&&u.morphTexture!==null)h.getUniforms().setValue(n,"morphTexture",u.morphTexture,t);else{let x=0;for(let E=0;E<p.length;E++)x+=p[E];const w=d.morphTargetsRelative?1:1-x;h.getUniforms().setValue(n,"morphTargetBaseInfluence",w),h.getUniforms().setValue(n,"morphTargetInfluences",p)}h.getUniforms().setValue(n,"morphTargetsTexture",v.texture,t),h.getUniforms().setValue(n,"morphTargetsTextureSize",v.size)}return{update:c}}function pN(n,e,t,r){let a=new WeakMap;function c(h){const p=r.render.frame,g=h.geometry,y=e.get(h,g);if(a.get(y)!==p&&(e.update(y),a.set(y,p)),h.isInstancedMesh&&(h.hasEventListener("dispose",d)===!1&&h.addEventListener("dispose",d),a.get(h)!==p&&(t.update(h.instanceMatrix,n.ARRAY_BUFFER),h.instanceColor!==null&&t.update(h.instanceColor,n.ARRAY_BUFFER),a.set(h,p))),h.isSkinnedMesh){const v=h.skeleton;a.get(v)!==p&&(v.update(),a.set(v,p))}return y}function u(){a=new WeakMap}function d(h){const p=h.target;p.removeEventListener("dispose",d),t.remove(p.instanceMatrix),p.instanceColor!==null&&t.remove(p.instanceColor)}return{update:c,dispose:u}}class Mx extends Yn{constructor(e,t,r,a,c,u,d,h,p,g=Va){if(g!==Va&&g!==Za)throw new Error("DepthTexture format must be either THREE.DepthFormat or THREE.DepthStencilFormat");r===void 0&&g===Va&&(r=Xs),r===void 0&&g===Za&&(r=Ka),super(null,a,c,u,d,h,g,r,p),this.isDepthTexture=!0,this.image={width:e,height:t},this.magFilter=d!==void 0?d:Si,this.minFilter=h!==void 0?h:Si,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(e){return super.copy(e),this.compareFunction=e.compareFunction,this}toJSON(e){const t=super.toJSON(e);return this.compareFunction!==null&&(t.compareFunction=this.compareFunction),t}}const Ex=new Yn,D_=new Mx(1,1),wx=new dx,Tx=new JT,bx=new vx,I_=[],U_=[],F_=new Float32Array(16),O_=new Float32Array(9),j_=new Float32Array(4);function so(n,e,t){const r=n[0];if(r<=0||r>0)return n;const a=e*t;let c=I_[a];if(c===void 0&&(c=new Float32Array(a),I_[a]=c),e!==0){r.toArray(c,0);for(let u=1,d=0;u!==e;++u)d+=t,n[u].toArray(c,d)}return c}function cn(n,e){if(n.length!==e.length)return!1;for(let t=0,r=n.length;t<r;t++)if(n[t]!==e[t])return!1;return!0}function un(n,e){for(let t=0,r=e.length;t<r;t++)n[t]=e[t]}function ju(n,e){let t=U_[e];t===void 0&&(t=new Int32Array(e),U_[e]=t);for(let r=0;r!==e;++r)t[r]=n.allocateTextureUnit();return t}function mN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1f(this.addr,e),t[0]=e)}function gN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2f(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2fv(this.addr,e),un(t,e)}}function _N(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3f(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else if(e.r!==void 0)(t[0]!==e.r||t[1]!==e.g||t[2]!==e.b)&&(n.uniform3f(this.addr,e.r,e.g,e.b),t[0]=e.r,t[1]=e.g,t[2]=e.b);else{if(cn(t,e))return;n.uniform3fv(this.addr,e),un(t,e)}}function vN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4f(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4fv(this.addr,e),un(t,e)}}function xN(n,e){const t=this.cache,r=e.elements;if(r===void 0){if(cn(t,e))return;n.uniformMatrix2fv(this.addr,!1,e),un(t,e)}else{if(cn(t,r))return;j_.set(r),n.uniformMatrix2fv(this.addr,!1,j_),un(t,r)}}function yN(n,e){const t=this.cache,r=e.elements;if(r===void 0){if(cn(t,e))return;n.uniformMatrix3fv(this.addr,!1,e),un(t,e)}else{if(cn(t,r))return;O_.set(r),n.uniformMatrix3fv(this.addr,!1,O_),un(t,r)}}function SN(n,e){const t=this.cache,r=e.elements;if(r===void 0){if(cn(t,e))return;n.uniformMatrix4fv(this.addr,!1,e),un(t,e)}else{if(cn(t,r))return;F_.set(r),n.uniformMatrix4fv(this.addr,!1,F_),un(t,r)}}function MN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1i(this.addr,e),t[0]=e)}function EN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2i(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2iv(this.addr,e),un(t,e)}}function wN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3i(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(cn(t,e))return;n.uniform3iv(this.addr,e),un(t,e)}}function TN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4i(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4iv(this.addr,e),un(t,e)}}function bN(n,e){const t=this.cache;t[0]!==e&&(n.uniform1ui(this.addr,e),t[0]=e)}function AN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2ui(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(cn(t,e))return;n.uniform2uiv(this.addr,e),un(t,e)}}function CN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3ui(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(cn(t,e))return;n.uniform3uiv(this.addr,e),un(t,e)}}function NN(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4ui(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(cn(t,e))return;n.uniform4uiv(this.addr,e),un(t,e)}}function RN(n,e,t){const r=this.cache,a=t.allocateTextureUnit();r[0]!==a&&(n.uniform1i(this.addr,a),r[0]=a);let c;this.type===n.SAMPLER_2D_SHADOW?(D_.compareFunction=lx,c=D_):c=Ex,t.setTexture2D(e||c,a)}function PN(n,e,t){const r=this.cache,a=t.allocateTextureUnit();r[0]!==a&&(n.uniform1i(this.addr,a),r[0]=a),t.setTexture3D(e||Tx,a)}function LN(n,e,t){const r=this.cache,a=t.allocateTextureUnit();r[0]!==a&&(n.uniform1i(this.addr,a),r[0]=a),t.setTextureCube(e||bx,a)}function kN(n,e,t){const r=this.cache,a=t.allocateTextureUnit();r[0]!==a&&(n.uniform1i(this.addr,a),r[0]=a),t.setTexture2DArray(e||wx,a)}function DN(n){switch(n){case 5126:return mN;case 35664:return gN;case 35665:return _N;case 35666:return vN;case 35674:return xN;case 35675:return yN;case 35676:return SN;case 5124:case 35670:return MN;case 35667:case 35671:return EN;case 35668:case 35672:return wN;case 35669:case 35673:return TN;case 5125:return bN;case 36294:return AN;case 36295:return CN;case 36296:return NN;case 35678:case 36198:case 36298:case 36306:case 35682:return RN;case 35679:case 36299:case 36307:return PN;case 35680:case 36300:case 36308:case 36293:return LN;case 36289:case 36303:case 36311:case 36292:return kN}}function IN(n,e){n.uniform1fv(this.addr,e)}function UN(n,e){const t=so(e,this.size,2);n.uniform2fv(this.addr,t)}function FN(n,e){const t=so(e,this.size,3);n.uniform3fv(this.addr,t)}function ON(n,e){const t=so(e,this.size,4);n.uniform4fv(this.addr,t)}function jN(n,e){const t=so(e,this.size,4);n.uniformMatrix2fv(this.addr,!1,t)}function zN(n,e){const t=so(e,this.size,9);n.uniformMatrix3fv(this.addr,!1,t)}function BN(n,e){const t=so(e,this.size,16);n.uniformMatrix4fv(this.addr,!1,t)}function HN(n,e){n.uniform1iv(this.addr,e)}function VN(n,e){n.uniform2iv(this.addr,e)}function GN(n,e){n.uniform3iv(this.addr,e)}function WN(n,e){n.uniform4iv(this.addr,e)}function $N(n,e){n.uniform1uiv(this.addr,e)}function XN(n,e){n.uniform2uiv(this.addr,e)}function qN(n,e){n.uniform3uiv(this.addr,e)}function YN(n,e){n.uniform4uiv(this.addr,e)}function KN(n,e,t){const r=this.cache,a=e.length,c=ju(t,a);cn(r,c)||(n.uniform1iv(this.addr,c),un(r,c));for(let u=0;u!==a;++u)t.setTexture2D(e[u]||Ex,c[u])}function ZN(n,e,t){const r=this.cache,a=e.length,c=ju(t,a);cn(r,c)||(n.uniform1iv(this.addr,c),un(r,c));for(let u=0;u!==a;++u)t.setTexture3D(e[u]||Tx,c[u])}function QN(n,e,t){const r=this.cache,a=e.length,c=ju(t,a);cn(r,c)||(n.uniform1iv(this.addr,c),un(r,c));for(let u=0;u!==a;++u)t.setTextureCube(e[u]||bx,c[u])}function JN(n,e,t){const r=this.cache,a=e.length,c=ju(t,a);cn(r,c)||(n.uniform1iv(this.addr,c),un(r,c));for(let u=0;u!==a;++u)t.setTexture2DArray(e[u]||wx,c[u])}function eR(n){switch(n){case 5126:return IN;case 35664:return UN;case 35665:return FN;case 35666:return ON;case 35674:return jN;case 35675:return zN;case 35676:return BN;case 5124:case 35670:return HN;case 35667:case 35671:return VN;case 35668:case 35672:return GN;case 35669:case 35673:return WN;case 5125:return $N;case 36294:return XN;case 36295:return qN;case 36296:return YN;case 35678:case 36198:case 36298:case 36306:case 35682:return KN;case 35679:case 36299:case 36307:return ZN;case 35680:case 36300:case 36308:case 36293:return QN;case 36289:case 36303:case 36311:case 36292:return JN}}class tR{constructor(e,t,r){this.id=e,this.addr=r,this.cache=[],this.type=t.type,this.setValue=DN(t.type)}}class nR{constructor(e,t,r){this.id=e,this.addr=r,this.cache=[],this.type=t.type,this.size=t.size,this.setValue=eR(t.type)}}class iR{constructor(e){this.id=e,this.seq=[],this.map={}}setValue(e,t,r){const a=this.seq;for(let c=0,u=a.length;c!==u;++c){const d=a[c];d.setValue(e,t[d.id],r)}}}const sh=/(\w+)(\])?(\[|\.)?/g;function z_(n,e){n.seq.push(e),n.map[e.id]=e}function rR(n,e,t){const r=n.name,a=r.length;for(sh.lastIndex=0;;){const c=sh.exec(r),u=sh.lastIndex;let d=c[1];const h=c[2]==="]",p=c[3];if(h&&(d=d|0),p===void 0||p==="["&&u+2===a){z_(t,p===void 0?new tR(d,n,e):new nR(d,n,e));break}else{let y=t.map[d];y===void 0&&(y=new iR(d),z_(t,y)),t=y}}}class su{constructor(e,t){this.seq=[],this.map={};const r=e.getProgramParameter(t,e.ACTIVE_UNIFORMS);for(let a=0;a<r;++a){const c=e.getActiveUniform(t,a),u=e.getUniformLocation(t,c.name);rR(c,u,this)}}setValue(e,t,r,a){const c=this.map[t];c!==void 0&&c.setValue(e,r,a)}setOptional(e,t,r){const a=t[r];a!==void 0&&this.setValue(e,r,a)}static upload(e,t,r,a){for(let c=0,u=t.length;c!==u;++c){const d=t[c],h=r[d.id];h.needsUpdate!==!1&&d.setValue(e,h.value,a)}}static seqWithValue(e,t){const r=[];for(let a=0,c=e.length;a!==c;++a){const u=e[a];u.id in t&&r.push(u)}return r}}function B_(n,e,t){const r=n.createShader(e);return n.shaderSource(r,t),n.compileShader(r),r}const sR=37297;let aR=0;function oR(n,e){const t=n.split(`
`),r=[],a=Math.max(e-6,0),c=Math.min(e+6,t.length);for(let u=a;u<c;u++){const d=u+1;r.push(`${d===e?">":" "} ${d}: ${t[u]}`)}return r.join(`
`)}function lR(n){const e=Ct.getPrimaries(Ct.workingColorSpace),t=Ct.getPrimaries(n);let r;switch(e===t?r="":e===gu&&t===mu?r="LinearDisplayP3ToLinearSRGB":e===mu&&t===gu&&(r="LinearSRGBToLinearDisplayP3"),n){case fs:case Fu:return[r,"LinearTransferOETF"];case $i:case jp:return[r,"sRGBTransferOETF"];default:return console.warn("THREE.WebGLProgram: Unsupported color space:",n),[r,"LinearTransferOETF"]}}function H_(n,e,t){const r=n.getShaderParameter(e,n.COMPILE_STATUS),a=n.getShaderInfoLog(e).trim();if(r&&a==="")return"";const c=/ERROR: 0:(\d+)/.exec(a);if(c){const u=parseInt(c[1]);return t.toUpperCase()+`

`+a+`

`+oR(n.getShaderSource(e),u)}else return a}function cR(n,e){const t=lR(e);return`vec4 ${n}( vec4 value ) { return ${t[0]}( ${t[1]}( value ) ); }`}function uR(n,e){let t;switch(e){case wT:t="Linear";break;case TT:t="Reinhard";break;case bT:t="Cineon";break;case AT:t="ACESFilmic";break;case NT:t="AgX";break;case RT:t="Neutral";break;case CT:t="Custom";break;default:console.warn("THREE.WebGLProgram: Unsupported toneMapping:",e),t="Linear"}return"vec3 "+n+"( vec3 color ) { return "+t+"ToneMapping( color ); }"}const $c=new re;function dR(){Ct.getLuminanceCoefficients($c);const n=$c.x.toFixed(4),e=$c.y.toFixed(4),t=$c.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${n}, ${e}, ${t} );`,"	return dot( weights, rgb );","}"].join(`
`)}function fR(n){return[n.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",n.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(Ko).join(`
`)}function hR(n){const e=[];for(const t in n){const r=n[t];r!==!1&&e.push("#define "+t+" "+r)}return e.join(`
`)}function pR(n,e){const t={},r=n.getProgramParameter(e,n.ACTIVE_ATTRIBUTES);for(let a=0;a<r;a++){const c=n.getActiveAttrib(e,a),u=c.name;let d=1;c.type===n.FLOAT_MAT2&&(d=2),c.type===n.FLOAT_MAT3&&(d=3),c.type===n.FLOAT_MAT4&&(d=4),t[u]={type:c.type,location:n.getAttribLocation(e,u),locationSize:d}}return t}function Ko(n){return n!==""}function V_(n,e){const t=e.numSpotLightShadows+e.numSpotLightMaps-e.numSpotLightShadowsWithMaps;return n.replace(/NUM_DIR_LIGHTS/g,e.numDirLights).replace(/NUM_SPOT_LIGHTS/g,e.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,e.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,t).replace(/NUM_RECT_AREA_LIGHTS/g,e.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,e.numPointLights).replace(/NUM_HEMI_LIGHTS/g,e.numHemiLights).replace(/NUM_DIR_LIGHT_SHADOWS/g,e.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,e.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,e.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,e.numPointLightShadows)}function G_(n,e){return n.replace(/NUM_CLIPPING_PLANES/g,e.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,e.numClippingPlanes-e.numClipIntersection)}const mR=/^[ \t]*#include +<([\w\d./]+)>/gm;function op(n){return n.replace(mR,_R)}const gR=new Map;function _R(n,e){let t=ut[e];if(t===void 0){const r=gR.get(e);if(r!==void 0)t=ut[r],console.warn('THREE.WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',e,r);else throw new Error("Can not resolve #include <"+e+">")}return op(t)}const vR=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function W_(n){return n.replace(vR,xR)}function xR(n,e,t,r){let a="";for(let c=parseInt(e);c<parseInt(t);c++)a+=r.replace(/\[\s*i\s*\]/g,"[ "+c+" ]").replace(/UNROLLED_LOOP_INDEX/g,c);return a}function $_(n){let e=`precision ${n.precision} float;
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
#define LOW_PRECISION`),e}function yR(n){let e="SHADOWMAP_TYPE_BASIC";return n.shadowMapType===Yv?e="SHADOWMAP_TYPE_PCF":n.shadowMapType===iT?e="SHADOWMAP_TYPE_PCF_SOFT":n.shadowMapType===gr&&(e="SHADOWMAP_TYPE_VSM"),e}function SR(n){let e="ENVMAP_TYPE_CUBE";if(n.envMap)switch(n.envMapMode){case qa:case Ya:e="ENVMAP_TYPE_CUBE";break;case Uu:e="ENVMAP_TYPE_CUBE_UV";break}return e}function MR(n){let e="ENVMAP_MODE_REFLECTION";if(n.envMap)switch(n.envMapMode){case Ya:e="ENVMAP_MODE_REFRACTION";break}return e}function ER(n){let e="ENVMAP_BLENDING_NONE";if(n.envMap)switch(n.combine){case Kv:e="ENVMAP_BLENDING_MULTIPLY";break;case MT:e="ENVMAP_BLENDING_MIX";break;case ET:e="ENVMAP_BLENDING_ADD";break}return e}function wR(n){const e=n.envMapCubeUVHeight;if(e===null)return null;const t=Math.log2(e)-2,r=1/e;return{texelWidth:1/(3*Math.max(Math.pow(2,t),112)),texelHeight:r,maxMip:t}}function TR(n,e,t,r){const a=n.getContext(),c=t.defines;let u=t.vertexShader,d=t.fragmentShader;const h=yR(t),p=SR(t),g=MR(t),y=ER(t),v=wR(t),x=fR(t),w=hR(c),E=a.createProgram();let _,M,k=t.glslVersion?"#version "+t.glslVersion+`
`:"";t.isRawShaderMaterial?(_=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w].filter(Ko).join(`
`),_.length>0&&(_+=`
`),M=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w].filter(Ko).join(`
`),M.length>0&&(M+=`
`)):(_=[$_(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w,t.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",t.batching?"#define USE_BATCHING":"",t.batchingColor?"#define USE_BATCHING_COLOR":"",t.instancing?"#define USE_INSTANCING":"",t.instancingColor?"#define USE_INSTANCING_COLOR":"",t.instancingMorph?"#define USE_INSTANCING_MORPH":"",t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.map?"#define USE_MAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+g:"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.displacementMap?"#define USE_DISPLACEMENTMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.mapUv?"#define MAP_UV "+t.mapUv:"",t.alphaMapUv?"#define ALPHAMAP_UV "+t.alphaMapUv:"",t.lightMapUv?"#define LIGHTMAP_UV "+t.lightMapUv:"",t.aoMapUv?"#define AOMAP_UV "+t.aoMapUv:"",t.emissiveMapUv?"#define EMISSIVEMAP_UV "+t.emissiveMapUv:"",t.bumpMapUv?"#define BUMPMAP_UV "+t.bumpMapUv:"",t.normalMapUv?"#define NORMALMAP_UV "+t.normalMapUv:"",t.displacementMapUv?"#define DISPLACEMENTMAP_UV "+t.displacementMapUv:"",t.metalnessMapUv?"#define METALNESSMAP_UV "+t.metalnessMapUv:"",t.roughnessMapUv?"#define ROUGHNESSMAP_UV "+t.roughnessMapUv:"",t.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+t.anisotropyMapUv:"",t.clearcoatMapUv?"#define CLEARCOATMAP_UV "+t.clearcoatMapUv:"",t.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+t.clearcoatNormalMapUv:"",t.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+t.clearcoatRoughnessMapUv:"",t.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+t.iridescenceMapUv:"",t.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+t.iridescenceThicknessMapUv:"",t.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+t.sheenColorMapUv:"",t.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+t.sheenRoughnessMapUv:"",t.specularMapUv?"#define SPECULARMAP_UV "+t.specularMapUv:"",t.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+t.specularColorMapUv:"",t.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+t.specularIntensityMapUv:"",t.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+t.transmissionMapUv:"",t.thicknessMapUv?"#define THICKNESSMAP_UV "+t.thicknessMapUv:"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.flatShading?"#define FLAT_SHADED":"",t.skinning?"#define USE_SKINNING":"",t.morphTargets?"#define USE_MORPHTARGETS":"",t.morphNormals&&t.flatShading===!1?"#define USE_MORPHNORMALS":"",t.morphColors?"#define USE_MORPHCOLORS":"",t.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+t.morphTextureStride:"",t.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+t.morphTargetsCount:"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+h:"",t.sizeAttenuation?"#define USE_SIZEATTENUATION":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(Ko).join(`
`),M=[$_(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,w,t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",t.map?"#define USE_MAP":"",t.matcap?"#define USE_MATCAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+p:"",t.envMap?"#define "+g:"",t.envMap?"#define "+y:"",v?"#define CUBEUV_TEXEL_WIDTH "+v.texelWidth:"",v?"#define CUBEUV_TEXEL_HEIGHT "+v.texelHeight:"",v?"#define CUBEUV_MAX_MIP "+v.maxMip+".0":"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoat?"#define USE_CLEARCOAT":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.dispersion?"#define USE_DISPERSION":"",t.iridescence?"#define USE_IRIDESCENCE":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaTest?"#define USE_ALPHATEST":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.sheen?"#define USE_SHEEN":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors||t.instancingColor||t.batchingColor?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.gradientMap?"#define USE_GRADIENTMAP":"",t.flatShading?"#define FLAT_SHADED":"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+h:"",t.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",t.toneMapping!==os?"#define TONE_MAPPING":"",t.toneMapping!==os?ut.tonemapping_pars_fragment:"",t.toneMapping!==os?uR("toneMapping",t.toneMapping):"",t.dithering?"#define DITHERING":"",t.opaque?"#define OPAQUE":"",ut.colorspace_pars_fragment,cR("linearToOutputTexel",t.outputColorSpace),dR(),t.useDepthPacking?"#define DEPTH_PACKING "+t.depthPacking:"",`
`].filter(Ko).join(`
`)),u=op(u),u=V_(u,t),u=G_(u,t),d=op(d),d=V_(d,t),d=G_(d,t),u=W_(u),d=W_(d),t.isRawShaderMaterial!==!0&&(k=`#version 300 es
`,_=[x,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+_,M=["#define varying in",t.glslVersion===c_?"":"layout(location = 0) out highp vec4 pc_fragColor;",t.glslVersion===c_?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+M);const A=k+_+u,R=k+M+d,L=B_(a,a.VERTEX_SHADER,A),D=B_(a,a.FRAGMENT_SHADER,R);a.attachShader(E,L),a.attachShader(E,D),t.index0AttributeName!==void 0?a.bindAttribLocation(E,0,t.index0AttributeName):t.morphTargets===!0&&a.bindAttribLocation(E,0,"position"),a.linkProgram(E);function U(P){if(n.debug.checkShaderErrors){const se=a.getProgramInfoLog(E).trim(),J=a.getShaderInfoLog(L).trim(),ae=a.getShaderInfoLog(D).trim();let ve=!0,V=!0;if(a.getProgramParameter(E,a.LINK_STATUS)===!1)if(ve=!1,typeof n.debug.onShaderError=="function")n.debug.onShaderError(a,E,L,D);else{const de=H_(a,L,"vertex"),z=H_(a,D,"fragment");console.error("THREE.WebGLProgram: Shader Error "+a.getError()+" - VALIDATE_STATUS "+a.getProgramParameter(E,a.VALIDATE_STATUS)+`

Material Name: `+P.name+`
Material Type: `+P.type+`

Program Info Log: `+se+`
`+de+`
`+z)}else se!==""?console.warn("THREE.WebGLProgram: Program Info Log:",se):(J===""||ae==="")&&(V=!1);V&&(P.diagnostics={runnable:ve,programLog:se,vertexShader:{log:J,prefix:_},fragmentShader:{log:ae,prefix:M}})}a.deleteShader(L),a.deleteShader(D),$=new su(a,E),te=pR(a,E)}let $;this.getUniforms=function(){return $===void 0&&U(this),$};let te;this.getAttributes=function(){return te===void 0&&U(this),te};let T=t.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return T===!1&&(T=a.getProgramParameter(E,sR)),T},this.destroy=function(){r.releaseStatesOfProgram(this),a.deleteProgram(E),this.program=void 0},this.type=t.shaderType,this.name=t.shaderName,this.id=aR++,this.cacheKey=e,this.usedTimes=1,this.program=E,this.vertexShader=L,this.fragmentShader=D,this}let bR=0;class AR{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(e){const t=e.vertexShader,r=e.fragmentShader,a=this._getShaderStage(t),c=this._getShaderStage(r),u=this._getShaderCacheForMaterial(e);return u.has(a)===!1&&(u.add(a),a.usedTimes++),u.has(c)===!1&&(u.add(c),c.usedTimes++),this}remove(e){const t=this.materialCache.get(e);for(const r of t)r.usedTimes--,r.usedTimes===0&&this.shaderCache.delete(r.code);return this.materialCache.delete(e),this}getVertexShaderID(e){return this._getShaderStage(e.vertexShader).id}getFragmentShaderID(e){return this._getShaderStage(e.fragmentShader).id}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(e){const t=this.materialCache;let r=t.get(e);return r===void 0&&(r=new Set,t.set(e,r)),r}_getShaderStage(e){const t=this.shaderCache;let r=t.get(e);return r===void 0&&(r=new CR(e),t.set(e,r)),r}}class CR{constructor(e){this.id=bR++,this.code=e,this.usedTimes=0}}function NR(n,e,t,r,a,c,u){const d=new fx,h=new AR,p=new Set,g=[],y=a.logarithmicDepthBuffer,v=a.reverseDepthBuffer,x=a.vertexTextures;let w=a.precision;const E={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distanceRGBA",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function _(T){return p.add(T),T===0?"uv":`uv${T}`}function M(T,P,se,J,ae){const ve=J.fog,V=ae.geometry,de=T.isMeshStandardMaterial?J.environment:null,z=(T.isMeshStandardMaterial?t:e).get(T.envMap||de),ue=z&&z.mapping===Uu?z.image.height:null,oe=E[T.type];T.precision!==null&&(w=a.getMaxPrecision(T.precision),w!==T.precision&&console.warn("THREE.WebGLProgram.getParameters:",T.precision,"not supported, using",w,"instead."));const O=V.morphAttributes.position||V.morphAttributes.normal||V.morphAttributes.color,le=O!==void 0?O.length:0;let we=0;V.morphAttributes.position!==void 0&&(we=1),V.morphAttributes.normal!==void 0&&(we=2),V.morphAttributes.color!==void 0&&(we=3);let K,he,Te,Ae;if(oe){const dn=qi[oe];K=dn.vertexShader,he=dn.fragmentShader}else K=T.vertexShader,he=T.fragmentShader,h.update(T),Te=h.getVertexShaderID(T),Ae=h.getFragmentShaderID(T);const Ie=n.getRenderTarget(),Ue=ae.isInstancedMesh===!0,st=ae.isBatchedMesh===!0,yt=!!T.map,pt=!!T.matcap,B=!!z,_n=!!T.aoMap,ht=!!T.lightMap,_t=!!T.bumpMap,tt=!!T.normalMap,kt=!!T.displacementMap,it=!!T.emissiveMap,I=!!T.metalnessMap,C=!!T.roughnessMap,Q=T.anisotropy>0,me=T.clearcoat>0,Se=T.dispersion>0,pe=T.iridescence>0,Ze=T.sheen>0,Le=T.transmission>0,Be=Q&&!!T.anisotropyMap,vt=me&&!!T.clearcoatMap,Ce=me&&!!T.clearcoatNormalMap,He=me&&!!T.clearcoatRoughnessMap,at=pe&&!!T.iridescenceMap,rt=pe&&!!T.iridescenceThicknessMap,Ge=Ze&&!!T.sheenColorMap,mt=Ze&&!!T.sheenRoughnessMap,lt=!!T.specularMap,At=!!T.specularColorMap,G=!!T.specularIntensityMap,Fe=Le&&!!T.transmissionMap,ce=Le&&!!T.thicknessMap,ge=!!T.gradientMap,ke=!!T.alphaMap,je=T.alphaTest>0,gt=!!T.alphaHash,$t=!!T.extensions;let vn=os;T.toneMapped&&(Ie===null||Ie.isXRRenderTarget===!0)&&(vn=n.toneMapping);const xt={shaderID:oe,shaderType:T.type,shaderName:T.name,vertexShader:K,fragmentShader:he,defines:T.defines,customVertexShaderID:Te,customFragmentShaderID:Ae,isRawShaderMaterial:T.isRawShaderMaterial===!0,glslVersion:T.glslVersion,precision:w,batching:st,batchingColor:st&&ae._colorsTexture!==null,instancing:Ue,instancingColor:Ue&&ae.instanceColor!==null,instancingMorph:Ue&&ae.morphTexture!==null,supportsVertexTextures:x,outputColorSpace:Ie===null?n.outputColorSpace:Ie.isXRRenderTarget===!0?Ie.texture.colorSpace:fs,alphaToCoverage:!!T.alphaToCoverage,map:yt,matcap:pt,envMap:B,envMapMode:B&&z.mapping,envMapCubeUVHeight:ue,aoMap:_n,lightMap:ht,bumpMap:_t,normalMap:tt,displacementMap:x&&kt,emissiveMap:it,normalMapObjectSpace:tt&&T.normalMapType===IT,normalMapTangentSpace:tt&&T.normalMapType===DT,metalnessMap:I,roughnessMap:C,anisotropy:Q,anisotropyMap:Be,clearcoat:me,clearcoatMap:vt,clearcoatNormalMap:Ce,clearcoatRoughnessMap:He,dispersion:Se,iridescence:pe,iridescenceMap:at,iridescenceThicknessMap:rt,sheen:Ze,sheenColorMap:Ge,sheenRoughnessMap:mt,specularMap:lt,specularColorMap:At,specularIntensityMap:G,transmission:Le,transmissionMap:Fe,thicknessMap:ce,gradientMap:ge,opaque:T.transparent===!1&&T.blending===Ha&&T.alphaToCoverage===!1,alphaMap:ke,alphaTest:je,alphaHash:gt,combine:T.combine,mapUv:yt&&_(T.map.channel),aoMapUv:_n&&_(T.aoMap.channel),lightMapUv:ht&&_(T.lightMap.channel),bumpMapUv:_t&&_(T.bumpMap.channel),normalMapUv:tt&&_(T.normalMap.channel),displacementMapUv:kt&&_(T.displacementMap.channel),emissiveMapUv:it&&_(T.emissiveMap.channel),metalnessMapUv:I&&_(T.metalnessMap.channel),roughnessMapUv:C&&_(T.roughnessMap.channel),anisotropyMapUv:Be&&_(T.anisotropyMap.channel),clearcoatMapUv:vt&&_(T.clearcoatMap.channel),clearcoatNormalMapUv:Ce&&_(T.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:He&&_(T.clearcoatRoughnessMap.channel),iridescenceMapUv:at&&_(T.iridescenceMap.channel),iridescenceThicknessMapUv:rt&&_(T.iridescenceThicknessMap.channel),sheenColorMapUv:Ge&&_(T.sheenColorMap.channel),sheenRoughnessMapUv:mt&&_(T.sheenRoughnessMap.channel),specularMapUv:lt&&_(T.specularMap.channel),specularColorMapUv:At&&_(T.specularColorMap.channel),specularIntensityMapUv:G&&_(T.specularIntensityMap.channel),transmissionMapUv:Fe&&_(T.transmissionMap.channel),thicknessMapUv:ce&&_(T.thicknessMap.channel),alphaMapUv:ke&&_(T.alphaMap.channel),vertexTangents:!!V.attributes.tangent&&(tt||Q),vertexColors:T.vertexColors,vertexAlphas:T.vertexColors===!0&&!!V.attributes.color&&V.attributes.color.itemSize===4,pointsUvs:ae.isPoints===!0&&!!V.attributes.uv&&(yt||ke),fog:!!ve,useFog:T.fog===!0,fogExp2:!!ve&&ve.isFogExp2,flatShading:T.flatShading===!0,sizeAttenuation:T.sizeAttenuation===!0,logarithmicDepthBuffer:y,reverseDepthBuffer:v,skinning:ae.isSkinnedMesh===!0,morphTargets:V.morphAttributes.position!==void 0,morphNormals:V.morphAttributes.normal!==void 0,morphColors:V.morphAttributes.color!==void 0,morphTargetsCount:le,morphTextureStride:we,numDirLights:P.directional.length,numPointLights:P.point.length,numSpotLights:P.spot.length,numSpotLightMaps:P.spotLightMap.length,numRectAreaLights:P.rectArea.length,numHemiLights:P.hemi.length,numDirLightShadows:P.directionalShadowMap.length,numPointLightShadows:P.pointShadowMap.length,numSpotLightShadows:P.spotShadowMap.length,numSpotLightShadowsWithMaps:P.numSpotLightShadowsWithMaps,numLightProbes:P.numLightProbes,numClippingPlanes:u.numPlanes,numClipIntersection:u.numIntersection,dithering:T.dithering,shadowMapEnabled:n.shadowMap.enabled&&se.length>0,shadowMapType:n.shadowMap.type,toneMapping:vn,decodeVideoTexture:yt&&T.map.isVideoTexture===!0&&Ct.getTransfer(T.map.colorSpace)===Bt,premultipliedAlpha:T.premultipliedAlpha,doubleSided:T.side===Yi,flipSided:T.side===qn,useDepthPacking:T.depthPacking>=0,depthPacking:T.depthPacking||0,index0AttributeName:T.index0AttributeName,extensionClipCullDistance:$t&&T.extensions.clipCullDistance===!0&&r.has("WEBGL_clip_cull_distance"),extensionMultiDraw:($t&&T.extensions.multiDraw===!0||st)&&r.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:r.has("KHR_parallel_shader_compile"),customProgramCacheKey:T.customProgramCacheKey()};return xt.vertexUv1s=p.has(1),xt.vertexUv2s=p.has(2),xt.vertexUv3s=p.has(3),p.clear(),xt}function k(T){const P=[];if(T.shaderID?P.push(T.shaderID):(P.push(T.customVertexShaderID),P.push(T.customFragmentShaderID)),T.defines!==void 0)for(const se in T.defines)P.push(se),P.push(T.defines[se]);return T.isRawShaderMaterial===!1&&(A(P,T),R(P,T),P.push(n.outputColorSpace)),P.push(T.customProgramCacheKey),P.join()}function A(T,P){T.push(P.precision),T.push(P.outputColorSpace),T.push(P.envMapMode),T.push(P.envMapCubeUVHeight),T.push(P.mapUv),T.push(P.alphaMapUv),T.push(P.lightMapUv),T.push(P.aoMapUv),T.push(P.bumpMapUv),T.push(P.normalMapUv),T.push(P.displacementMapUv),T.push(P.emissiveMapUv),T.push(P.metalnessMapUv),T.push(P.roughnessMapUv),T.push(P.anisotropyMapUv),T.push(P.clearcoatMapUv),T.push(P.clearcoatNormalMapUv),T.push(P.clearcoatRoughnessMapUv),T.push(P.iridescenceMapUv),T.push(P.iridescenceThicknessMapUv),T.push(P.sheenColorMapUv),T.push(P.sheenRoughnessMapUv),T.push(P.specularMapUv),T.push(P.specularColorMapUv),T.push(P.specularIntensityMapUv),T.push(P.transmissionMapUv),T.push(P.thicknessMapUv),T.push(P.combine),T.push(P.fogExp2),T.push(P.sizeAttenuation),T.push(P.morphTargetsCount),T.push(P.morphAttributeCount),T.push(P.numDirLights),T.push(P.numPointLights),T.push(P.numSpotLights),T.push(P.numSpotLightMaps),T.push(P.numHemiLights),T.push(P.numRectAreaLights),T.push(P.numDirLightShadows),T.push(P.numPointLightShadows),T.push(P.numSpotLightShadows),T.push(P.numSpotLightShadowsWithMaps),T.push(P.numLightProbes),T.push(P.shadowMapType),T.push(P.toneMapping),T.push(P.numClippingPlanes),T.push(P.numClipIntersection),T.push(P.depthPacking)}function R(T,P){d.disableAll(),P.supportsVertexTextures&&d.enable(0),P.instancing&&d.enable(1),P.instancingColor&&d.enable(2),P.instancingMorph&&d.enable(3),P.matcap&&d.enable(4),P.envMap&&d.enable(5),P.normalMapObjectSpace&&d.enable(6),P.normalMapTangentSpace&&d.enable(7),P.clearcoat&&d.enable(8),P.iridescence&&d.enable(9),P.alphaTest&&d.enable(10),P.vertexColors&&d.enable(11),P.vertexAlphas&&d.enable(12),P.vertexUv1s&&d.enable(13),P.vertexUv2s&&d.enable(14),P.vertexUv3s&&d.enable(15),P.vertexTangents&&d.enable(16),P.anisotropy&&d.enable(17),P.alphaHash&&d.enable(18),P.batching&&d.enable(19),P.dispersion&&d.enable(20),P.batchingColor&&d.enable(21),T.push(d.mask),d.disableAll(),P.fog&&d.enable(0),P.useFog&&d.enable(1),P.flatShading&&d.enable(2),P.logarithmicDepthBuffer&&d.enable(3),P.reverseDepthBuffer&&d.enable(4),P.skinning&&d.enable(5),P.morphTargets&&d.enable(6),P.morphNormals&&d.enable(7),P.morphColors&&d.enable(8),P.premultipliedAlpha&&d.enable(9),P.shadowMapEnabled&&d.enable(10),P.doubleSided&&d.enable(11),P.flipSided&&d.enable(12),P.useDepthPacking&&d.enable(13),P.dithering&&d.enable(14),P.transmission&&d.enable(15),P.sheen&&d.enable(16),P.opaque&&d.enable(17),P.pointsUvs&&d.enable(18),P.decodeVideoTexture&&d.enable(19),P.alphaToCoverage&&d.enable(20),T.push(d.mask)}function L(T){const P=E[T.type];let se;if(P){const J=qi[P];se=fb.clone(J.uniforms)}else se=T.uniforms;return se}function D(T,P){let se;for(let J=0,ae=g.length;J<ae;J++){const ve=g[J];if(ve.cacheKey===P){se=ve,++se.usedTimes;break}}return se===void 0&&(se=new TR(n,P,T,c),g.push(se)),se}function U(T){if(--T.usedTimes===0){const P=g.indexOf(T);g[P]=g[g.length-1],g.pop(),T.destroy()}}function $(T){h.remove(T)}function te(){h.dispose()}return{getParameters:M,getProgramCacheKey:k,getUniforms:L,acquireProgram:D,releaseProgram:U,releaseShaderCache:$,programs:g,dispose:te}}function RR(){let n=new WeakMap;function e(u){return n.has(u)}function t(u){let d=n.get(u);return d===void 0&&(d={},n.set(u,d)),d}function r(u){n.delete(u)}function a(u,d,h){n.get(u)[d]=h}function c(){n=new WeakMap}return{has:e,get:t,remove:r,update:a,dispose:c}}function PR(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.material.id!==e.material.id?n.material.id-e.material.id:n.z!==e.z?n.z-e.z:n.id-e.id}function X_(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.z!==e.z?e.z-n.z:n.id-e.id}function q_(){const n=[];let e=0;const t=[],r=[],a=[];function c(){e=0,t.length=0,r.length=0,a.length=0}function u(y,v,x,w,E,_){let M=n[e];return M===void 0?(M={id:y.id,object:y,geometry:v,material:x,groupOrder:w,renderOrder:y.renderOrder,z:E,group:_},n[e]=M):(M.id=y.id,M.object=y,M.geometry=v,M.material=x,M.groupOrder=w,M.renderOrder=y.renderOrder,M.z=E,M.group=_),e++,M}function d(y,v,x,w,E,_){const M=u(y,v,x,w,E,_);x.transmission>0?r.push(M):x.transparent===!0?a.push(M):t.push(M)}function h(y,v,x,w,E,_){const M=u(y,v,x,w,E,_);x.transmission>0?r.unshift(M):x.transparent===!0?a.unshift(M):t.unshift(M)}function p(y,v){t.length>1&&t.sort(y||PR),r.length>1&&r.sort(v||X_),a.length>1&&a.sort(v||X_)}function g(){for(let y=e,v=n.length;y<v;y++){const x=n[y];if(x.id===null)break;x.id=null,x.object=null,x.geometry=null,x.material=null,x.group=null}}return{opaque:t,transmissive:r,transparent:a,init:c,push:d,unshift:h,finish:g,sort:p}}function LR(){let n=new WeakMap;function e(r,a){const c=n.get(r);let u;return c===void 0?(u=new q_,n.set(r,[u])):a>=c.length?(u=new q_,c.push(u)):u=c[a],u}function t(){n=new WeakMap}return{get:e,dispose:t}}function kR(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={direction:new re,color:new Rt};break;case"SpotLight":t={position:new re,direction:new re,color:new Rt,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":t={position:new re,color:new Rt,distance:0,decay:0};break;case"HemisphereLight":t={direction:new re,skyColor:new Rt,groundColor:new Rt};break;case"RectAreaLight":t={color:new Rt,position:new re,halfWidth:new re,halfHeight:new re};break}return n[e.id]=t,t}}}function DR(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new bt};break;case"SpotLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new bt};break;case"PointLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new bt,shadowCameraNear:1,shadowCameraFar:1e3};break}return n[e.id]=t,t}}}let IR=0;function UR(n,e){return(e.castShadow?2:0)-(n.castShadow?2:0)+(e.map?1:0)-(n.map?1:0)}function FR(n){const e=new kR,t=DR(),r={version:0,hash:{directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let p=0;p<9;p++)r.probe.push(new re);const a=new re,c=new nn,u=new nn;function d(p){let g=0,y=0,v=0;for(let te=0;te<9;te++)r.probe[te].set(0,0,0);let x=0,w=0,E=0,_=0,M=0,k=0,A=0,R=0,L=0,D=0,U=0;p.sort(UR);for(let te=0,T=p.length;te<T;te++){const P=p[te],se=P.color,J=P.intensity,ae=P.distance,ve=P.shadow&&P.shadow.map?P.shadow.map.texture:null;if(P.isAmbientLight)g+=se.r*J,y+=se.g*J,v+=se.b*J;else if(P.isLightProbe){for(let V=0;V<9;V++)r.probe[V].addScaledVector(P.sh.coefficients[V],J);U++}else if(P.isDirectionalLight){const V=e.get(P);if(V.color.copy(P.color).multiplyScalar(P.intensity),P.castShadow){const de=P.shadow,z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,r.directionalShadow[x]=z,r.directionalShadowMap[x]=ve,r.directionalShadowMatrix[x]=P.shadow.matrix,k++}r.directional[x]=V,x++}else if(P.isSpotLight){const V=e.get(P);V.position.setFromMatrixPosition(P.matrixWorld),V.color.copy(se).multiplyScalar(J),V.distance=ae,V.coneCos=Math.cos(P.angle),V.penumbraCos=Math.cos(P.angle*(1-P.penumbra)),V.decay=P.decay,r.spot[E]=V;const de=P.shadow;if(P.map&&(r.spotLightMap[L]=P.map,L++,de.updateMatrices(P),P.castShadow&&D++),r.spotLightMatrix[E]=de.matrix,P.castShadow){const z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,r.spotShadow[E]=z,r.spotShadowMap[E]=ve,R++}E++}else if(P.isRectAreaLight){const V=e.get(P);V.color.copy(se).multiplyScalar(J),V.halfWidth.set(P.width*.5,0,0),V.halfHeight.set(0,P.height*.5,0),r.rectArea[_]=V,_++}else if(P.isPointLight){const V=e.get(P);if(V.color.copy(P.color).multiplyScalar(P.intensity),V.distance=P.distance,V.decay=P.decay,P.castShadow){const de=P.shadow,z=t.get(P);z.shadowIntensity=de.intensity,z.shadowBias=de.bias,z.shadowNormalBias=de.normalBias,z.shadowRadius=de.radius,z.shadowMapSize=de.mapSize,z.shadowCameraNear=de.camera.near,z.shadowCameraFar=de.camera.far,r.pointShadow[w]=z,r.pointShadowMap[w]=ve,r.pointShadowMatrix[w]=P.shadow.matrix,A++}r.point[w]=V,w++}else if(P.isHemisphereLight){const V=e.get(P);V.skyColor.copy(P.color).multiplyScalar(J),V.groundColor.copy(P.groundColor).multiplyScalar(J),r.hemi[M]=V,M++}}_>0&&(n.has("OES_texture_float_linear")===!0?(r.rectAreaLTC1=De.LTC_FLOAT_1,r.rectAreaLTC2=De.LTC_FLOAT_2):(r.rectAreaLTC1=De.LTC_HALF_1,r.rectAreaLTC2=De.LTC_HALF_2)),r.ambient[0]=g,r.ambient[1]=y,r.ambient[2]=v;const $=r.hash;($.directionalLength!==x||$.pointLength!==w||$.spotLength!==E||$.rectAreaLength!==_||$.hemiLength!==M||$.numDirectionalShadows!==k||$.numPointShadows!==A||$.numSpotShadows!==R||$.numSpotMaps!==L||$.numLightProbes!==U)&&(r.directional.length=x,r.spot.length=E,r.rectArea.length=_,r.point.length=w,r.hemi.length=M,r.directionalShadow.length=k,r.directionalShadowMap.length=k,r.pointShadow.length=A,r.pointShadowMap.length=A,r.spotShadow.length=R,r.spotShadowMap.length=R,r.directionalShadowMatrix.length=k,r.pointShadowMatrix.length=A,r.spotLightMatrix.length=R+L-D,r.spotLightMap.length=L,r.numSpotLightShadowsWithMaps=D,r.numLightProbes=U,$.directionalLength=x,$.pointLength=w,$.spotLength=E,$.rectAreaLength=_,$.hemiLength=M,$.numDirectionalShadows=k,$.numPointShadows=A,$.numSpotShadows=R,$.numSpotMaps=L,$.numLightProbes=U,r.version=IR++)}function h(p,g){let y=0,v=0,x=0,w=0,E=0;const _=g.matrixWorldInverse;for(let M=0,k=p.length;M<k;M++){const A=p[M];if(A.isDirectionalLight){const R=r.directional[y];R.direction.setFromMatrixPosition(A.matrixWorld),a.setFromMatrixPosition(A.target.matrixWorld),R.direction.sub(a),R.direction.transformDirection(_),y++}else if(A.isSpotLight){const R=r.spot[x];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),R.direction.setFromMatrixPosition(A.matrixWorld),a.setFromMatrixPosition(A.target.matrixWorld),R.direction.sub(a),R.direction.transformDirection(_),x++}else if(A.isRectAreaLight){const R=r.rectArea[w];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),u.identity(),c.copy(A.matrixWorld),c.premultiply(_),u.extractRotation(c),R.halfWidth.set(A.width*.5,0,0),R.halfHeight.set(0,A.height*.5,0),R.halfWidth.applyMatrix4(u),R.halfHeight.applyMatrix4(u),w++}else if(A.isPointLight){const R=r.point[v];R.position.setFromMatrixPosition(A.matrixWorld),R.position.applyMatrix4(_),v++}else if(A.isHemisphereLight){const R=r.hemi[E];R.direction.setFromMatrixPosition(A.matrixWorld),R.direction.transformDirection(_),E++}}}return{setup:d,setupView:h,state:r}}function Y_(n){const e=new FR(n),t=[],r=[];function a(g){p.camera=g,t.length=0,r.length=0}function c(g){t.push(g)}function u(g){r.push(g)}function d(){e.setup(t)}function h(g){e.setupView(t,g)}const p={lightsArray:t,shadowsArray:r,camera:null,lights:e,transmissionRenderTarget:{}};return{init:a,state:p,setupLights:d,setupLightsView:h,pushLight:c,pushShadow:u}}function OR(n){let e=new WeakMap;function t(a,c=0){const u=e.get(a);let d;return u===void 0?(d=new Y_(n),e.set(a,[d])):c>=u.length?(d=new Y_(n),u.push(d)):d=u[c],d}function r(){e=new WeakMap}return{get:t,dispose:r}}class jR extends Ou{constructor(e){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=LT,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(e)}copy(e){return super.copy(e),this.depthPacking=e.depthPacking,this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this}}class zR extends Ou{constructor(e){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(e)}copy(e){return super.copy(e),this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this}}const BR=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,HR=`uniform sampler2D shadow_pass;
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
}`;function VR(n,e,t){let r=new xx;const a=new bt,c=new bt,u=new Qt,d=new jR({depthPacking:kT}),h=new zR,p={},g=t.maxTextureSize,y={[us]:qn,[qn]:us,[Yi]:Yi},v=new br({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new bt},radius:{value:4}},vertexShader:BR,fragmentShader:HR}),x=v.clone();x.defines.HORIZONTAL_PASS=1;const w=new Ar;w.setAttribute("position",new Ki(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));const E=new ji(w,v),_=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Yv;let M=this.type;this.render=function(D,U,$){if(_.enabled===!1||_.autoUpdate===!1&&_.needsUpdate===!1||D.length===0)return;const te=n.getRenderTarget(),T=n.getActiveCubeFace(),P=n.getActiveMipmapLevel(),se=n.state;se.setBlending(as),se.buffers.color.setClear(1,1,1,1),se.buffers.depth.setTest(!0),se.setScissorTest(!1);const J=M!==gr&&this.type===gr,ae=M===gr&&this.type!==gr;for(let ve=0,V=D.length;ve<V;ve++){const de=D[ve],z=de.shadow;if(z===void 0){console.warn("THREE.WebGLShadowMap:",de,"has no shadow.");continue}if(z.autoUpdate===!1&&z.needsUpdate===!1)continue;a.copy(z.mapSize);const ue=z.getFrameExtents();if(a.multiply(ue),c.copy(z.mapSize),(a.x>g||a.y>g)&&(a.x>g&&(c.x=Math.floor(g/ue.x),a.x=c.x*ue.x,z.mapSize.x=c.x),a.y>g&&(c.y=Math.floor(g/ue.y),a.y=c.y*ue.y,z.mapSize.y=c.y)),z.map===null||J===!0||ae===!0){const O=this.type!==gr?{minFilter:Si,magFilter:Si}:{};z.map!==null&&z.map.dispose(),z.map=new qs(a.x,a.y,O),z.map.texture.name=de.name+".shadowMap",z.camera.updateProjectionMatrix()}n.setRenderTarget(z.map),n.clear();const oe=z.getViewportCount();for(let O=0;O<oe;O++){const le=z.getViewport(O);u.set(c.x*le.x,c.y*le.y,c.x*le.z,c.y*le.w),se.viewport(u),z.updateMatrices(de,O),r=z.getFrustum(),R(U,$,z.camera,de,this.type)}z.isPointLightShadow!==!0&&this.type===gr&&k(z,$),z.needsUpdate=!1}M=this.type,_.needsUpdate=!1,n.setRenderTarget(te,T,P)};function k(D,U){const $=e.update(E);v.defines.VSM_SAMPLES!==D.blurSamples&&(v.defines.VSM_SAMPLES=D.blurSamples,x.defines.VSM_SAMPLES=D.blurSamples,v.needsUpdate=!0,x.needsUpdate=!0),D.mapPass===null&&(D.mapPass=new qs(a.x,a.y)),v.uniforms.shadow_pass.value=D.map.texture,v.uniforms.resolution.value=D.mapSize,v.uniforms.radius.value=D.radius,n.setRenderTarget(D.mapPass),n.clear(),n.renderBufferDirect(U,null,$,v,E,null),x.uniforms.shadow_pass.value=D.mapPass.texture,x.uniforms.resolution.value=D.mapSize,x.uniforms.radius.value=D.radius,n.setRenderTarget(D.map),n.clear(),n.renderBufferDirect(U,null,$,x,E,null)}function A(D,U,$,te){let T=null;const P=$.isPointLight===!0?D.customDistanceMaterial:D.customDepthMaterial;if(P!==void 0)T=P;else if(T=$.isPointLight===!0?h:d,n.localClippingEnabled&&U.clipShadows===!0&&Array.isArray(U.clippingPlanes)&&U.clippingPlanes.length!==0||U.displacementMap&&U.displacementScale!==0||U.alphaMap&&U.alphaTest>0||U.map&&U.alphaTest>0){const se=T.uuid,J=U.uuid;let ae=p[se];ae===void 0&&(ae={},p[se]=ae);let ve=ae[J];ve===void 0&&(ve=T.clone(),ae[J]=ve,U.addEventListener("dispose",L)),T=ve}if(T.visible=U.visible,T.wireframe=U.wireframe,te===gr?T.side=U.shadowSide!==null?U.shadowSide:U.side:T.side=U.shadowSide!==null?U.shadowSide:y[U.side],T.alphaMap=U.alphaMap,T.alphaTest=U.alphaTest,T.map=U.map,T.clipShadows=U.clipShadows,T.clippingPlanes=U.clippingPlanes,T.clipIntersection=U.clipIntersection,T.displacementMap=U.displacementMap,T.displacementScale=U.displacementScale,T.displacementBias=U.displacementBias,T.wireframeLinewidth=U.wireframeLinewidth,T.linewidth=U.linewidth,$.isPointLight===!0&&T.isMeshDistanceMaterial===!0){const se=n.properties.get(T);se.light=$}return T}function R(D,U,$,te,T){if(D.visible===!1)return;if(D.layers.test(U.layers)&&(D.isMesh||D.isLine||D.isPoints)&&(D.castShadow||D.receiveShadow&&T===gr)&&(!D.frustumCulled||r.intersectsObject(D))){D.modelViewMatrix.multiplyMatrices($.matrixWorldInverse,D.matrixWorld);const J=e.update(D),ae=D.material;if(Array.isArray(ae)){const ve=J.groups;for(let V=0,de=ve.length;V<de;V++){const z=ve[V],ue=ae[z.materialIndex];if(ue&&ue.visible){const oe=A(D,ue,te,T);D.onBeforeShadow(n,D,U,$,J,oe,z),n.renderBufferDirect($,null,J,oe,D,z),D.onAfterShadow(n,D,U,$,J,oe,z)}}}else if(ae.visible){const ve=A(D,ae,te,T);D.onBeforeShadow(n,D,U,$,J,ve,null),n.renderBufferDirect($,null,J,ve,D,null),D.onAfterShadow(n,D,U,$,J,ve,null)}}const se=D.children;for(let J=0,ae=se.length;J<ae;J++)R(se[J],U,$,te,T)}function L(D){D.target.removeEventListener("dispose",L);for(const $ in p){const te=p[$],T=D.target.uuid;T in te&&(te[T].dispose(),delete te[T])}}}const GR={[Eh]:wh,[Th]:Ch,[bh]:Nh,[Xa]:Ah,[wh]:Eh,[Ch]:Th,[Nh]:bh,[Ah]:Xa};function WR(n){function e(){let G=!1;const Fe=new Qt;let ce=null;const ge=new Qt(0,0,0,0);return{setMask:function(ke){ce!==ke&&!G&&(n.colorMask(ke,ke,ke,ke),ce=ke)},setLocked:function(ke){G=ke},setClear:function(ke,je,gt,$t,vn){vn===!0&&(ke*=$t,je*=$t,gt*=$t),Fe.set(ke,je,gt,$t),ge.equals(Fe)===!1&&(n.clearColor(ke,je,gt,$t),ge.copy(Fe))},reset:function(){G=!1,ce=null,ge.set(-1,0,0,0)}}}function t(){let G=!1,Fe=!1,ce=null,ge=null,ke=null;return{setReversed:function(je){Fe=je},setTest:function(je){je?Te(n.DEPTH_TEST):Ae(n.DEPTH_TEST)},setMask:function(je){ce!==je&&!G&&(n.depthMask(je),ce=je)},setFunc:function(je){if(Fe&&(je=GR[je]),ge!==je){switch(je){case Eh:n.depthFunc(n.NEVER);break;case wh:n.depthFunc(n.ALWAYS);break;case Th:n.depthFunc(n.LESS);break;case Xa:n.depthFunc(n.LEQUAL);break;case bh:n.depthFunc(n.EQUAL);break;case Ah:n.depthFunc(n.GEQUAL);break;case Ch:n.depthFunc(n.GREATER);break;case Nh:n.depthFunc(n.NOTEQUAL);break;default:n.depthFunc(n.LEQUAL)}ge=je}},setLocked:function(je){G=je},setClear:function(je){ke!==je&&(n.clearDepth(je),ke=je)},reset:function(){G=!1,ce=null,ge=null,ke=null}}}function r(){let G=!1,Fe=null,ce=null,ge=null,ke=null,je=null,gt=null,$t=null,vn=null;return{setTest:function(xt){G||(xt?Te(n.STENCIL_TEST):Ae(n.STENCIL_TEST))},setMask:function(xt){Fe!==xt&&!G&&(n.stencilMask(xt),Fe=xt)},setFunc:function(xt,dn,ci){(ce!==xt||ge!==dn||ke!==ci)&&(n.stencilFunc(xt,dn,ci),ce=xt,ge=dn,ke=ci)},setOp:function(xt,dn,ci){(je!==xt||gt!==dn||$t!==ci)&&(n.stencilOp(xt,dn,ci),je=xt,gt=dn,$t=ci)},setLocked:function(xt){G=xt},setClear:function(xt){vn!==xt&&(n.clearStencil(xt),vn=xt)},reset:function(){G=!1,Fe=null,ce=null,ge=null,ke=null,je=null,gt=null,$t=null,vn=null}}}const a=new e,c=new t,u=new r,d=new WeakMap,h=new WeakMap;let p={},g={},y=new WeakMap,v=[],x=null,w=!1,E=null,_=null,M=null,k=null,A=null,R=null,L=null,D=new Rt(0,0,0),U=0,$=!1,te=null,T=null,P=null,se=null,J=null;const ae=n.getParameter(n.MAX_COMBINED_TEXTURE_IMAGE_UNITS);let ve=!1,V=0;const de=n.getParameter(n.VERSION);de.indexOf("WebGL")!==-1?(V=parseFloat(/^WebGL (\d)/.exec(de)[1]),ve=V>=1):de.indexOf("OpenGL ES")!==-1&&(V=parseFloat(/^OpenGL ES (\d)/.exec(de)[1]),ve=V>=2);let z=null,ue={};const oe=n.getParameter(n.SCISSOR_BOX),O=n.getParameter(n.VIEWPORT),le=new Qt().fromArray(oe),we=new Qt().fromArray(O);function K(G,Fe,ce,ge){const ke=new Uint8Array(4),je=n.createTexture();n.bindTexture(G,je),n.texParameteri(G,n.TEXTURE_MIN_FILTER,n.NEAREST),n.texParameteri(G,n.TEXTURE_MAG_FILTER,n.NEAREST);for(let gt=0;gt<ce;gt++)G===n.TEXTURE_3D||G===n.TEXTURE_2D_ARRAY?n.texImage3D(Fe,0,n.RGBA,1,1,ge,0,n.RGBA,n.UNSIGNED_BYTE,ke):n.texImage2D(Fe+gt,0,n.RGBA,1,1,0,n.RGBA,n.UNSIGNED_BYTE,ke);return je}const he={};he[n.TEXTURE_2D]=K(n.TEXTURE_2D,n.TEXTURE_2D,1),he[n.TEXTURE_CUBE_MAP]=K(n.TEXTURE_CUBE_MAP,n.TEXTURE_CUBE_MAP_POSITIVE_X,6),he[n.TEXTURE_2D_ARRAY]=K(n.TEXTURE_2D_ARRAY,n.TEXTURE_2D_ARRAY,1,1),he[n.TEXTURE_3D]=K(n.TEXTURE_3D,n.TEXTURE_3D,1,1),a.setClear(0,0,0,1),c.setClear(1),u.setClear(0),Te(n.DEPTH_TEST),c.setFunc(Xa),ht(!1),_t(r_),Te(n.CULL_FACE),B(as);function Te(G){p[G]!==!0&&(n.enable(G),p[G]=!0)}function Ae(G){p[G]!==!1&&(n.disable(G),p[G]=!1)}function Ie(G,Fe){return g[G]!==Fe?(n.bindFramebuffer(G,Fe),g[G]=Fe,G===n.DRAW_FRAMEBUFFER&&(g[n.FRAMEBUFFER]=Fe),G===n.FRAMEBUFFER&&(g[n.DRAW_FRAMEBUFFER]=Fe),!0):!1}function Ue(G,Fe){let ce=v,ge=!1;if(G){ce=y.get(Fe),ce===void 0&&(ce=[],y.set(Fe,ce));const ke=G.textures;if(ce.length!==ke.length||ce[0]!==n.COLOR_ATTACHMENT0){for(let je=0,gt=ke.length;je<gt;je++)ce[je]=n.COLOR_ATTACHMENT0+je;ce.length=ke.length,ge=!0}}else ce[0]!==n.BACK&&(ce[0]=n.BACK,ge=!0);ge&&n.drawBuffers(ce)}function st(G){return x!==G?(n.useProgram(G),x=G,!0):!1}const yt={[Is]:n.FUNC_ADD,[sT]:n.FUNC_SUBTRACT,[aT]:n.FUNC_REVERSE_SUBTRACT};yt[oT]=n.MIN,yt[lT]=n.MAX;const pt={[cT]:n.ZERO,[uT]:n.ONE,[dT]:n.SRC_COLOR,[Sh]:n.SRC_ALPHA,[_T]:n.SRC_ALPHA_SATURATE,[mT]:n.DST_COLOR,[hT]:n.DST_ALPHA,[fT]:n.ONE_MINUS_SRC_COLOR,[Mh]:n.ONE_MINUS_SRC_ALPHA,[gT]:n.ONE_MINUS_DST_COLOR,[pT]:n.ONE_MINUS_DST_ALPHA,[vT]:n.CONSTANT_COLOR,[xT]:n.ONE_MINUS_CONSTANT_COLOR,[yT]:n.CONSTANT_ALPHA,[ST]:n.ONE_MINUS_CONSTANT_ALPHA};function B(G,Fe,ce,ge,ke,je,gt,$t,vn,xt){if(G===as){w===!0&&(Ae(n.BLEND),w=!1);return}if(w===!1&&(Te(n.BLEND),w=!0),G!==rT){if(G!==E||xt!==$){if((_!==Is||A!==Is)&&(n.blendEquation(n.FUNC_ADD),_=Is,A=Is),xt)switch(G){case Ha:n.blendFuncSeparate(n.ONE,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case yh:n.blendFunc(n.ONE,n.ONE);break;case s_:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case a_:n.blendFuncSeparate(n.ZERO,n.SRC_COLOR,n.ZERO,n.SRC_ALPHA);break;default:console.error("THREE.WebGLState: Invalid blending: ",G);break}else switch(G){case Ha:n.blendFuncSeparate(n.SRC_ALPHA,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case yh:n.blendFunc(n.SRC_ALPHA,n.ONE);break;case s_:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case a_:n.blendFunc(n.ZERO,n.SRC_COLOR);break;default:console.error("THREE.WebGLState: Invalid blending: ",G);break}M=null,k=null,R=null,L=null,D.set(0,0,0),U=0,E=G,$=xt}return}ke=ke||Fe,je=je||ce,gt=gt||ge,(Fe!==_||ke!==A)&&(n.blendEquationSeparate(yt[Fe],yt[ke]),_=Fe,A=ke),(ce!==M||ge!==k||je!==R||gt!==L)&&(n.blendFuncSeparate(pt[ce],pt[ge],pt[je],pt[gt]),M=ce,k=ge,R=je,L=gt),($t.equals(D)===!1||vn!==U)&&(n.blendColor($t.r,$t.g,$t.b,vn),D.copy($t),U=vn),E=G,$=!1}function _n(G,Fe){G.side===Yi?Ae(n.CULL_FACE):Te(n.CULL_FACE);let ce=G.side===qn;Fe&&(ce=!ce),ht(ce),G.blending===Ha&&G.transparent===!1?B(as):B(G.blending,G.blendEquation,G.blendSrc,G.blendDst,G.blendEquationAlpha,G.blendSrcAlpha,G.blendDstAlpha,G.blendColor,G.blendAlpha,G.premultipliedAlpha),c.setFunc(G.depthFunc),c.setTest(G.depthTest),c.setMask(G.depthWrite),a.setMask(G.colorWrite);const ge=G.stencilWrite;u.setTest(ge),ge&&(u.setMask(G.stencilWriteMask),u.setFunc(G.stencilFunc,G.stencilRef,G.stencilFuncMask),u.setOp(G.stencilFail,G.stencilZFail,G.stencilZPass)),kt(G.polygonOffset,G.polygonOffsetFactor,G.polygonOffsetUnits),G.alphaToCoverage===!0?Te(n.SAMPLE_ALPHA_TO_COVERAGE):Ae(n.SAMPLE_ALPHA_TO_COVERAGE)}function ht(G){te!==G&&(G?n.frontFace(n.CW):n.frontFace(n.CCW),te=G)}function _t(G){G!==tT?(Te(n.CULL_FACE),G!==T&&(G===r_?n.cullFace(n.BACK):G===nT?n.cullFace(n.FRONT):n.cullFace(n.FRONT_AND_BACK))):Ae(n.CULL_FACE),T=G}function tt(G){G!==P&&(ve&&n.lineWidth(G),P=G)}function kt(G,Fe,ce){G?(Te(n.POLYGON_OFFSET_FILL),(se!==Fe||J!==ce)&&(n.polygonOffset(Fe,ce),se=Fe,J=ce)):Ae(n.POLYGON_OFFSET_FILL)}function it(G){G?Te(n.SCISSOR_TEST):Ae(n.SCISSOR_TEST)}function I(G){G===void 0&&(G=n.TEXTURE0+ae-1),z!==G&&(n.activeTexture(G),z=G)}function C(G,Fe,ce){ce===void 0&&(z===null?ce=n.TEXTURE0+ae-1:ce=z);let ge=ue[ce];ge===void 0&&(ge={type:void 0,texture:void 0},ue[ce]=ge),(ge.type!==G||ge.texture!==Fe)&&(z!==ce&&(n.activeTexture(ce),z=ce),n.bindTexture(G,Fe||he[G]),ge.type=G,ge.texture=Fe)}function Q(){const G=ue[z];G!==void 0&&G.type!==void 0&&(n.bindTexture(G.type,null),G.type=void 0,G.texture=void 0)}function me(){try{n.compressedTexImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Se(){try{n.compressedTexImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function pe(){try{n.texSubImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Ze(){try{n.texSubImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Le(){try{n.compressedTexSubImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Be(){try{n.compressedTexSubImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function vt(){try{n.texStorage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function Ce(){try{n.texStorage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function He(){try{n.texImage2D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function at(){try{n.texImage3D.apply(n,arguments)}catch(G){console.error("THREE.WebGLState:",G)}}function rt(G){le.equals(G)===!1&&(n.scissor(G.x,G.y,G.z,G.w),le.copy(G))}function Ge(G){we.equals(G)===!1&&(n.viewport(G.x,G.y,G.z,G.w),we.copy(G))}function mt(G,Fe){let ce=h.get(Fe);ce===void 0&&(ce=new WeakMap,h.set(Fe,ce));let ge=ce.get(G);ge===void 0&&(ge=n.getUniformBlockIndex(Fe,G.name),ce.set(G,ge))}function lt(G,Fe){const ge=h.get(Fe).get(G);d.get(Fe)!==ge&&(n.uniformBlockBinding(Fe,ge,G.__bindingPointIndex),d.set(Fe,ge))}function At(){n.disable(n.BLEND),n.disable(n.CULL_FACE),n.disable(n.DEPTH_TEST),n.disable(n.POLYGON_OFFSET_FILL),n.disable(n.SCISSOR_TEST),n.disable(n.STENCIL_TEST),n.disable(n.SAMPLE_ALPHA_TO_COVERAGE),n.blendEquation(n.FUNC_ADD),n.blendFunc(n.ONE,n.ZERO),n.blendFuncSeparate(n.ONE,n.ZERO,n.ONE,n.ZERO),n.blendColor(0,0,0,0),n.colorMask(!0,!0,!0,!0),n.clearColor(0,0,0,0),n.depthMask(!0),n.depthFunc(n.LESS),n.clearDepth(1),n.stencilMask(4294967295),n.stencilFunc(n.ALWAYS,0,4294967295),n.stencilOp(n.KEEP,n.KEEP,n.KEEP),n.clearStencil(0),n.cullFace(n.BACK),n.frontFace(n.CCW),n.polygonOffset(0,0),n.activeTexture(n.TEXTURE0),n.bindFramebuffer(n.FRAMEBUFFER,null),n.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),n.bindFramebuffer(n.READ_FRAMEBUFFER,null),n.useProgram(null),n.lineWidth(1),n.scissor(0,0,n.canvas.width,n.canvas.height),n.viewport(0,0,n.canvas.width,n.canvas.height),p={},z=null,ue={},g={},y=new WeakMap,v=[],x=null,w=!1,E=null,_=null,M=null,k=null,A=null,R=null,L=null,D=new Rt(0,0,0),U=0,$=!1,te=null,T=null,P=null,se=null,J=null,le.set(0,0,n.canvas.width,n.canvas.height),we.set(0,0,n.canvas.width,n.canvas.height),a.reset(),c.reset(),u.reset()}return{buffers:{color:a,depth:c,stencil:u},enable:Te,disable:Ae,bindFramebuffer:Ie,drawBuffers:Ue,useProgram:st,setBlending:B,setMaterial:_n,setFlipSided:ht,setCullFace:_t,setLineWidth:tt,setPolygonOffset:kt,setScissorTest:it,activeTexture:I,bindTexture:C,unbindTexture:Q,compressedTexImage2D:me,compressedTexImage3D:Se,texImage2D:He,texImage3D:at,updateUBOMapping:mt,uniformBlockBinding:lt,texStorage2D:vt,texStorage3D:Ce,texSubImage2D:pe,texSubImage3D:Ze,compressedTexSubImage2D:Le,compressedTexSubImage3D:Be,scissor:rt,viewport:Ge,reset:At}}function K_(n,e,t,r){const a=$R(r);switch(t){case tx:return n*e;case ix:return n*e;case rx:return n*e*2;case sx:return n*e/a.components*a.byteLength;case Up:return n*e/a.components*a.byteLength;case ax:return n*e*2/a.components*a.byteLength;case Fp:return n*e*2/a.components*a.byteLength;case nx:return n*e*3/a.components*a.byteLength;case Oi:return n*e*4/a.components*a.byteLength;case Op:return n*e*4/a.components*a.byteLength;case Jc:case eu:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case tu:case nu:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Ih:case Fh:return Math.max(n,16)*Math.max(e,8)/4;case Dh:case Uh:return Math.max(n,8)*Math.max(e,8)/2;case Oh:case jh:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case zh:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Bh:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Hh:return Math.floor((n+4)/5)*Math.floor((e+3)/4)*16;case Vh:return Math.floor((n+4)/5)*Math.floor((e+4)/5)*16;case Gh:return Math.floor((n+5)/6)*Math.floor((e+4)/5)*16;case Wh:return Math.floor((n+5)/6)*Math.floor((e+5)/6)*16;case $h:return Math.floor((n+7)/8)*Math.floor((e+4)/5)*16;case Xh:return Math.floor((n+7)/8)*Math.floor((e+5)/6)*16;case qh:return Math.floor((n+7)/8)*Math.floor((e+7)/8)*16;case Yh:return Math.floor((n+9)/10)*Math.floor((e+4)/5)*16;case Kh:return Math.floor((n+9)/10)*Math.floor((e+5)/6)*16;case Zh:return Math.floor((n+9)/10)*Math.floor((e+7)/8)*16;case Qh:return Math.floor((n+9)/10)*Math.floor((e+9)/10)*16;case Jh:return Math.floor((n+11)/12)*Math.floor((e+9)/10)*16;case ep:return Math.floor((n+11)/12)*Math.floor((e+11)/12)*16;case iu:case tp:case np:return Math.ceil(n/4)*Math.ceil(e/4)*16;case ox:case ip:return Math.ceil(n/4)*Math.ceil(e/4)*8;case rp:case sp:return Math.ceil(n/4)*Math.ceil(e/4)*16}throw new Error(`Unable to determine texture byte length for ${t} format.`)}function $R(n){switch(n){case wr:case Qv:return{byteLength:1,components:1};case al:case Jv:case ul:return{byteLength:2,components:1};case Dp:case Ip:return{byteLength:2,components:4};case Xs:case kp:case xr:return{byteLength:4,components:1};case ex:return{byteLength:4,components:3}}throw new Error(`Unknown texture type ${n}.`)}function XR(n,e,t,r,a,c,u){const d=e.has("WEBGL_multisampled_render_to_texture")?e.get("WEBGL_multisampled_render_to_texture"):null,h=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),p=new bt,g=new WeakMap;let y;const v=new WeakMap;let x=!1;try{x=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function w(I,C){return x?new OffscreenCanvas(I,C):vu("canvas")}function E(I,C,Q){let me=1;const Se=it(I);if((Se.width>Q||Se.height>Q)&&(me=Q/Math.max(Se.width,Se.height)),me<1)if(typeof HTMLImageElement<"u"&&I instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&I instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&I instanceof ImageBitmap||typeof VideoFrame<"u"&&I instanceof VideoFrame){const pe=Math.floor(me*Se.width),Ze=Math.floor(me*Se.height);y===void 0&&(y=w(pe,Ze));const Le=C?w(pe,Ze):y;return Le.width=pe,Le.height=Ze,Le.getContext("2d").drawImage(I,0,0,pe,Ze),console.warn("THREE.WebGLRenderer: Texture has been resized from ("+Se.width+"x"+Se.height+") to ("+pe+"x"+Ze+")."),Le}else return"data"in I&&console.warn("THREE.WebGLRenderer: Image in DataTexture is too big ("+Se.width+"x"+Se.height+")."),I;return I}function _(I){return I.generateMipmaps&&I.minFilter!==Si&&I.minFilter!==Di}function M(I){n.generateMipmap(I)}function k(I,C,Q,me,Se=!1){if(I!==null){if(n[I]!==void 0)return n[I];console.warn("THREE.WebGLRenderer: Attempt to use non-existing WebGL internal format '"+I+"'")}let pe=C;if(C===n.RED&&(Q===n.FLOAT&&(pe=n.R32F),Q===n.HALF_FLOAT&&(pe=n.R16F),Q===n.UNSIGNED_BYTE&&(pe=n.R8)),C===n.RED_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.R8UI),Q===n.UNSIGNED_SHORT&&(pe=n.R16UI),Q===n.UNSIGNED_INT&&(pe=n.R32UI),Q===n.BYTE&&(pe=n.R8I),Q===n.SHORT&&(pe=n.R16I),Q===n.INT&&(pe=n.R32I)),C===n.RG&&(Q===n.FLOAT&&(pe=n.RG32F),Q===n.HALF_FLOAT&&(pe=n.RG16F),Q===n.UNSIGNED_BYTE&&(pe=n.RG8)),C===n.RG_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RG8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RG16UI),Q===n.UNSIGNED_INT&&(pe=n.RG32UI),Q===n.BYTE&&(pe=n.RG8I),Q===n.SHORT&&(pe=n.RG16I),Q===n.INT&&(pe=n.RG32I)),C===n.RGB_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RGB8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RGB16UI),Q===n.UNSIGNED_INT&&(pe=n.RGB32UI),Q===n.BYTE&&(pe=n.RGB8I),Q===n.SHORT&&(pe=n.RGB16I),Q===n.INT&&(pe=n.RGB32I)),C===n.RGBA_INTEGER&&(Q===n.UNSIGNED_BYTE&&(pe=n.RGBA8UI),Q===n.UNSIGNED_SHORT&&(pe=n.RGBA16UI),Q===n.UNSIGNED_INT&&(pe=n.RGBA32UI),Q===n.BYTE&&(pe=n.RGBA8I),Q===n.SHORT&&(pe=n.RGBA16I),Q===n.INT&&(pe=n.RGBA32I)),C===n.RGB&&Q===n.UNSIGNED_INT_5_9_9_9_REV&&(pe=n.RGB9_E5),C===n.RGBA){const Ze=Se?pu:Ct.getTransfer(me);Q===n.FLOAT&&(pe=n.RGBA32F),Q===n.HALF_FLOAT&&(pe=n.RGBA16F),Q===n.UNSIGNED_BYTE&&(pe=Ze===Bt?n.SRGB8_ALPHA8:n.RGBA8),Q===n.UNSIGNED_SHORT_4_4_4_4&&(pe=n.RGBA4),Q===n.UNSIGNED_SHORT_5_5_5_1&&(pe=n.RGB5_A1)}return(pe===n.R16F||pe===n.R32F||pe===n.RG16F||pe===n.RG32F||pe===n.RGBA16F||pe===n.RGBA32F)&&e.get("EXT_color_buffer_float"),pe}function A(I,C){let Q;return I?C===null||C===Xs||C===Ka?Q=n.DEPTH24_STENCIL8:C===xr?Q=n.DEPTH32F_STENCIL8:C===al&&(Q=n.DEPTH24_STENCIL8,console.warn("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):C===null||C===Xs||C===Ka?Q=n.DEPTH_COMPONENT24:C===xr?Q=n.DEPTH_COMPONENT32F:C===al&&(Q=n.DEPTH_COMPONENT16),Q}function R(I,C){return _(I)===!0||I.isFramebufferTexture&&I.minFilter!==Si&&I.minFilter!==Di?Math.log2(Math.max(C.width,C.height))+1:I.mipmaps!==void 0&&I.mipmaps.length>0?I.mipmaps.length:I.isCompressedTexture&&Array.isArray(I.image)?C.mipmaps.length:1}function L(I){const C=I.target;C.removeEventListener("dispose",L),U(C),C.isVideoTexture&&g.delete(C)}function D(I){const C=I.target;C.removeEventListener("dispose",D),te(C)}function U(I){const C=r.get(I);if(C.__webglInit===void 0)return;const Q=I.source,me=v.get(Q);if(me){const Se=me[C.__cacheKey];Se.usedTimes--,Se.usedTimes===0&&$(I),Object.keys(me).length===0&&v.delete(Q)}r.remove(I)}function $(I){const C=r.get(I);n.deleteTexture(C.__webglTexture);const Q=I.source,me=v.get(Q);delete me[C.__cacheKey],u.memory.textures--}function te(I){const C=r.get(I);if(I.depthTexture&&I.depthTexture.dispose(),I.isWebGLCubeRenderTarget)for(let me=0;me<6;me++){if(Array.isArray(C.__webglFramebuffer[me]))for(let Se=0;Se<C.__webglFramebuffer[me].length;Se++)n.deleteFramebuffer(C.__webglFramebuffer[me][Se]);else n.deleteFramebuffer(C.__webglFramebuffer[me]);C.__webglDepthbuffer&&n.deleteRenderbuffer(C.__webglDepthbuffer[me])}else{if(Array.isArray(C.__webglFramebuffer))for(let me=0;me<C.__webglFramebuffer.length;me++)n.deleteFramebuffer(C.__webglFramebuffer[me]);else n.deleteFramebuffer(C.__webglFramebuffer);if(C.__webglDepthbuffer&&n.deleteRenderbuffer(C.__webglDepthbuffer),C.__webglMultisampledFramebuffer&&n.deleteFramebuffer(C.__webglMultisampledFramebuffer),C.__webglColorRenderbuffer)for(let me=0;me<C.__webglColorRenderbuffer.length;me++)C.__webglColorRenderbuffer[me]&&n.deleteRenderbuffer(C.__webglColorRenderbuffer[me]);C.__webglDepthRenderbuffer&&n.deleteRenderbuffer(C.__webglDepthRenderbuffer)}const Q=I.textures;for(let me=0,Se=Q.length;me<Se;me++){const pe=r.get(Q[me]);pe.__webglTexture&&(n.deleteTexture(pe.__webglTexture),u.memory.textures--),r.remove(Q[me])}r.remove(I)}let T=0;function P(){T=0}function se(){const I=T;return I>=a.maxTextures&&console.warn("THREE.WebGLTextures: Trying to use "+I+" texture units while this GPU supports only "+a.maxTextures),T+=1,I}function J(I){const C=[];return C.push(I.wrapS),C.push(I.wrapT),C.push(I.wrapR||0),C.push(I.magFilter),C.push(I.minFilter),C.push(I.anisotropy),C.push(I.internalFormat),C.push(I.format),C.push(I.type),C.push(I.generateMipmaps),C.push(I.premultiplyAlpha),C.push(I.flipY),C.push(I.unpackAlignment),C.push(I.colorSpace),C.join()}function ae(I,C){const Q=r.get(I);if(I.isVideoTexture&&tt(I),I.isRenderTargetTexture===!1&&I.version>0&&Q.__version!==I.version){const me=I.image;if(me===null)console.warn("THREE.WebGLRenderer: Texture marked for update but no image data found.");else if(me.complete===!1)console.warn("THREE.WebGLRenderer: Texture marked for update but image is incomplete");else{we(Q,I,C);return}}t.bindTexture(n.TEXTURE_2D,Q.__webglTexture,n.TEXTURE0+C)}function ve(I,C){const Q=r.get(I);if(I.version>0&&Q.__version!==I.version){we(Q,I,C);return}t.bindTexture(n.TEXTURE_2D_ARRAY,Q.__webglTexture,n.TEXTURE0+C)}function V(I,C){const Q=r.get(I);if(I.version>0&&Q.__version!==I.version){we(Q,I,C);return}t.bindTexture(n.TEXTURE_3D,Q.__webglTexture,n.TEXTURE0+C)}function de(I,C){const Q=r.get(I);if(I.version>0&&Q.__version!==I.version){K(Q,I,C);return}t.bindTexture(n.TEXTURE_CUBE_MAP,Q.__webglTexture,n.TEXTURE0+C)}const z={[Lh]:n.REPEAT,[js]:n.CLAMP_TO_EDGE,[kh]:n.MIRRORED_REPEAT},ue={[Si]:n.NEAREST,[PT]:n.NEAREST_MIPMAP_NEAREST,[bc]:n.NEAREST_MIPMAP_LINEAR,[Di]:n.LINEAR,[Rf]:n.LINEAR_MIPMAP_NEAREST,[zs]:n.LINEAR_MIPMAP_LINEAR},oe={[UT]:n.NEVER,[HT]:n.ALWAYS,[FT]:n.LESS,[lx]:n.LEQUAL,[OT]:n.EQUAL,[BT]:n.GEQUAL,[jT]:n.GREATER,[zT]:n.NOTEQUAL};function O(I,C){if(C.type===xr&&e.has("OES_texture_float_linear")===!1&&(C.magFilter===Di||C.magFilter===Rf||C.magFilter===bc||C.magFilter===zs||C.minFilter===Di||C.minFilter===Rf||C.minFilter===bc||C.minFilter===zs)&&console.warn("THREE.WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),n.texParameteri(I,n.TEXTURE_WRAP_S,z[C.wrapS]),n.texParameteri(I,n.TEXTURE_WRAP_T,z[C.wrapT]),(I===n.TEXTURE_3D||I===n.TEXTURE_2D_ARRAY)&&n.texParameteri(I,n.TEXTURE_WRAP_R,z[C.wrapR]),n.texParameteri(I,n.TEXTURE_MAG_FILTER,ue[C.magFilter]),n.texParameteri(I,n.TEXTURE_MIN_FILTER,ue[C.minFilter]),C.compareFunction&&(n.texParameteri(I,n.TEXTURE_COMPARE_MODE,n.COMPARE_REF_TO_TEXTURE),n.texParameteri(I,n.TEXTURE_COMPARE_FUNC,oe[C.compareFunction])),e.has("EXT_texture_filter_anisotropic")===!0){if(C.magFilter===Si||C.minFilter!==bc&&C.minFilter!==zs||C.type===xr&&e.has("OES_texture_float_linear")===!1)return;if(C.anisotropy>1||r.get(C).__currentAnisotropy){const Q=e.get("EXT_texture_filter_anisotropic");n.texParameterf(I,Q.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(C.anisotropy,a.getMaxAnisotropy())),r.get(C).__currentAnisotropy=C.anisotropy}}}function le(I,C){let Q=!1;I.__webglInit===void 0&&(I.__webglInit=!0,C.addEventListener("dispose",L));const me=C.source;let Se=v.get(me);Se===void 0&&(Se={},v.set(me,Se));const pe=J(C);if(pe!==I.__cacheKey){Se[pe]===void 0&&(Se[pe]={texture:n.createTexture(),usedTimes:0},u.memory.textures++,Q=!0),Se[pe].usedTimes++;const Ze=Se[I.__cacheKey];Ze!==void 0&&(Se[I.__cacheKey].usedTimes--,Ze.usedTimes===0&&$(C)),I.__cacheKey=pe,I.__webglTexture=Se[pe].texture}return Q}function we(I,C,Q){let me=n.TEXTURE_2D;(C.isDataArrayTexture||C.isCompressedArrayTexture)&&(me=n.TEXTURE_2D_ARRAY),C.isData3DTexture&&(me=n.TEXTURE_3D);const Se=le(I,C),pe=C.source;t.bindTexture(me,I.__webglTexture,n.TEXTURE0+Q);const Ze=r.get(pe);if(pe.version!==Ze.__version||Se===!0){t.activeTexture(n.TEXTURE0+Q);const Le=Ct.getPrimaries(Ct.workingColorSpace),Be=C.colorSpace===is?null:Ct.getPrimaries(C.colorSpace),vt=C.colorSpace===is||Le===Be?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,C.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,C.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,C.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,vt);let Ce=E(C.image,!1,a.maxTextureSize);Ce=kt(C,Ce);const He=c.convert(C.format,C.colorSpace),at=c.convert(C.type);let rt=k(C.internalFormat,He,at,C.colorSpace,C.isVideoTexture);O(me,C);let Ge;const mt=C.mipmaps,lt=C.isVideoTexture!==!0,At=Ze.__version===void 0||Se===!0,G=pe.dataReady,Fe=R(C,Ce);if(C.isDepthTexture)rt=A(C.format===Za,C.type),At&&(lt?t.texStorage2D(n.TEXTURE_2D,1,rt,Ce.width,Ce.height):t.texImage2D(n.TEXTURE_2D,0,rt,Ce.width,Ce.height,0,He,at,null));else if(C.isDataTexture)if(mt.length>0){lt&&At&&t.texStorage2D(n.TEXTURE_2D,Fe,rt,mt[0].width,mt[0].height);for(let ce=0,ge=mt.length;ce<ge;ce++)Ge=mt[ce],lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,at,Ge.data):t.texImage2D(n.TEXTURE_2D,ce,rt,Ge.width,Ge.height,0,He,at,Ge.data);C.generateMipmaps=!1}else lt?(At&&t.texStorage2D(n.TEXTURE_2D,Fe,rt,Ce.width,Ce.height),G&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,Ce.width,Ce.height,He,at,Ce.data)):t.texImage2D(n.TEXTURE_2D,0,rt,Ce.width,Ce.height,0,He,at,Ce.data);else if(C.isCompressedTexture)if(C.isCompressedArrayTexture){lt&&At&&t.texStorage3D(n.TEXTURE_2D_ARRAY,Fe,rt,mt[0].width,mt[0].height,Ce.depth);for(let ce=0,ge=mt.length;ce<ge;ce++)if(Ge=mt[ce],C.format!==Oi)if(He!==null)if(lt){if(G)if(C.layerUpdates.size>0){const ke=K_(Ge.width,Ge.height,C.format,C.type);for(const je of C.layerUpdates){const gt=Ge.data.subarray(je*ke/Ge.data.BYTES_PER_ELEMENT,(je+1)*ke/Ge.data.BYTES_PER_ELEMENT);t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,je,Ge.width,Ge.height,1,He,gt,0,0)}C.clearLayerUpdates()}else t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,0,Ge.width,Ge.height,Ce.depth,He,Ge.data,0,0)}else t.compressedTexImage3D(n.TEXTURE_2D_ARRAY,ce,rt,Ge.width,Ge.height,Ce.depth,0,Ge.data,0,0);else console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else lt?G&&t.texSubImage3D(n.TEXTURE_2D_ARRAY,ce,0,0,0,Ge.width,Ge.height,Ce.depth,He,at,Ge.data):t.texImage3D(n.TEXTURE_2D_ARRAY,ce,rt,Ge.width,Ge.height,Ce.depth,0,He,at,Ge.data)}else{lt&&At&&t.texStorage2D(n.TEXTURE_2D,Fe,rt,mt[0].width,mt[0].height);for(let ce=0,ge=mt.length;ce<ge;ce++)Ge=mt[ce],C.format!==Oi?He!==null?lt?G&&t.compressedTexSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,Ge.data):t.compressedTexImage2D(n.TEXTURE_2D,ce,rt,Ge.width,Ge.height,0,Ge.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,Ge.width,Ge.height,He,at,Ge.data):t.texImage2D(n.TEXTURE_2D,ce,rt,Ge.width,Ge.height,0,He,at,Ge.data)}else if(C.isDataArrayTexture)if(lt){if(At&&t.texStorage3D(n.TEXTURE_2D_ARRAY,Fe,rt,Ce.width,Ce.height,Ce.depth),G)if(C.layerUpdates.size>0){const ce=K_(Ce.width,Ce.height,C.format,C.type);for(const ge of C.layerUpdates){const ke=Ce.data.subarray(ge*ce/Ce.data.BYTES_PER_ELEMENT,(ge+1)*ce/Ce.data.BYTES_PER_ELEMENT);t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,ge,Ce.width,Ce.height,1,He,at,ke)}C.clearLayerUpdates()}else t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,0,Ce.width,Ce.height,Ce.depth,He,at,Ce.data)}else t.texImage3D(n.TEXTURE_2D_ARRAY,0,rt,Ce.width,Ce.height,Ce.depth,0,He,at,Ce.data);else if(C.isData3DTexture)lt?(At&&t.texStorage3D(n.TEXTURE_3D,Fe,rt,Ce.width,Ce.height,Ce.depth),G&&t.texSubImage3D(n.TEXTURE_3D,0,0,0,0,Ce.width,Ce.height,Ce.depth,He,at,Ce.data)):t.texImage3D(n.TEXTURE_3D,0,rt,Ce.width,Ce.height,Ce.depth,0,He,at,Ce.data);else if(C.isFramebufferTexture){if(At)if(lt)t.texStorage2D(n.TEXTURE_2D,Fe,rt,Ce.width,Ce.height);else{let ce=Ce.width,ge=Ce.height;for(let ke=0;ke<Fe;ke++)t.texImage2D(n.TEXTURE_2D,ke,rt,ce,ge,0,He,at,null),ce>>=1,ge>>=1}}else if(mt.length>0){if(lt&&At){const ce=it(mt[0]);t.texStorage2D(n.TEXTURE_2D,Fe,rt,ce.width,ce.height)}for(let ce=0,ge=mt.length;ce<ge;ce++)Ge=mt[ce],lt?G&&t.texSubImage2D(n.TEXTURE_2D,ce,0,0,He,at,Ge):t.texImage2D(n.TEXTURE_2D,ce,rt,He,at,Ge);C.generateMipmaps=!1}else if(lt){if(At){const ce=it(Ce);t.texStorage2D(n.TEXTURE_2D,Fe,rt,ce.width,ce.height)}G&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,He,at,Ce)}else t.texImage2D(n.TEXTURE_2D,0,rt,He,at,Ce);_(C)&&M(me),Ze.__version=pe.version,C.onUpdate&&C.onUpdate(C)}I.__version=C.version}function K(I,C,Q){if(C.image.length!==6)return;const me=le(I,C),Se=C.source;t.bindTexture(n.TEXTURE_CUBE_MAP,I.__webglTexture,n.TEXTURE0+Q);const pe=r.get(Se);if(Se.version!==pe.__version||me===!0){t.activeTexture(n.TEXTURE0+Q);const Ze=Ct.getPrimaries(Ct.workingColorSpace),Le=C.colorSpace===is?null:Ct.getPrimaries(C.colorSpace),Be=C.colorSpace===is||Ze===Le?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,C.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,C.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,C.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,Be);const vt=C.isCompressedTexture||C.image[0].isCompressedTexture,Ce=C.image[0]&&C.image[0].isDataTexture,He=[];for(let ge=0;ge<6;ge++)!vt&&!Ce?He[ge]=E(C.image[ge],!0,a.maxCubemapSize):He[ge]=Ce?C.image[ge].image:C.image[ge],He[ge]=kt(C,He[ge]);const at=He[0],rt=c.convert(C.format,C.colorSpace),Ge=c.convert(C.type),mt=k(C.internalFormat,rt,Ge,C.colorSpace),lt=C.isVideoTexture!==!0,At=pe.__version===void 0||me===!0,G=Se.dataReady;let Fe=R(C,at);O(n.TEXTURE_CUBE_MAP,C);let ce;if(vt){lt&&At&&t.texStorage2D(n.TEXTURE_CUBE_MAP,Fe,mt,at.width,at.height);for(let ge=0;ge<6;ge++){ce=He[ge].mipmaps;for(let ke=0;ke<ce.length;ke++){const je=ce[ke];C.format!==Oi?rt!==null?lt?G&&t.compressedTexSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke,0,0,je.width,je.height,rt,je.data):t.compressedTexImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke,mt,je.width,je.height,0,je.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke,0,0,je.width,je.height,rt,Ge,je.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke,mt,je.width,je.height,0,rt,Ge,je.data)}}}else{if(ce=C.mipmaps,lt&&At){ce.length>0&&Fe++;const ge=it(He[0]);t.texStorage2D(n.TEXTURE_CUBE_MAP,Fe,mt,ge.width,ge.height)}for(let ge=0;ge<6;ge++)if(Ce){lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,0,0,0,He[ge].width,He[ge].height,rt,Ge,He[ge].data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,0,mt,He[ge].width,He[ge].height,0,rt,Ge,He[ge].data);for(let ke=0;ke<ce.length;ke++){const gt=ce[ke].image[ge].image;lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke+1,0,0,gt.width,gt.height,rt,Ge,gt.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke+1,mt,gt.width,gt.height,0,rt,Ge,gt.data)}}else{lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,0,0,0,rt,Ge,He[ge]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,0,mt,rt,Ge,He[ge]);for(let ke=0;ke<ce.length;ke++){const je=ce[ke];lt?G&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke+1,0,0,rt,Ge,je.image[ge]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ge,ke+1,mt,rt,Ge,je.image[ge])}}}_(C)&&M(n.TEXTURE_CUBE_MAP),pe.__version=Se.version,C.onUpdate&&C.onUpdate(C)}I.__version=C.version}function he(I,C,Q,me,Se,pe){const Ze=c.convert(Q.format,Q.colorSpace),Le=c.convert(Q.type),Be=k(Q.internalFormat,Ze,Le,Q.colorSpace);if(!r.get(C).__hasExternalTextures){const Ce=Math.max(1,C.width>>pe),He=Math.max(1,C.height>>pe);Se===n.TEXTURE_3D||Se===n.TEXTURE_2D_ARRAY?t.texImage3D(Se,pe,Be,Ce,He,C.depth,0,Ze,Le,null):t.texImage2D(Se,pe,Be,Ce,He,0,Ze,Le,null)}t.bindFramebuffer(n.FRAMEBUFFER,I),_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,me,Se,r.get(Q).__webglTexture,0,ht(C)):(Se===n.TEXTURE_2D||Se>=n.TEXTURE_CUBE_MAP_POSITIVE_X&&Se<=n.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&n.framebufferTexture2D(n.FRAMEBUFFER,me,Se,r.get(Q).__webglTexture,pe),t.bindFramebuffer(n.FRAMEBUFFER,null)}function Te(I,C,Q){if(n.bindRenderbuffer(n.RENDERBUFFER,I),C.depthBuffer){const me=C.depthTexture,Se=me&&me.isDepthTexture?me.type:null,pe=A(C.stencilBuffer,Se),Ze=C.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Le=ht(C);_t(C)?d.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,Le,pe,C.width,C.height):Q?n.renderbufferStorageMultisample(n.RENDERBUFFER,Le,pe,C.width,C.height):n.renderbufferStorage(n.RENDERBUFFER,pe,C.width,C.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,Ze,n.RENDERBUFFER,I)}else{const me=C.textures;for(let Se=0;Se<me.length;Se++){const pe=me[Se],Ze=c.convert(pe.format,pe.colorSpace),Le=c.convert(pe.type),Be=k(pe.internalFormat,Ze,Le,pe.colorSpace),vt=ht(C);Q&&_t(C)===!1?n.renderbufferStorageMultisample(n.RENDERBUFFER,vt,Be,C.width,C.height):_t(C)?d.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,vt,Be,C.width,C.height):n.renderbufferStorage(n.RENDERBUFFER,Be,C.width,C.height)}}n.bindRenderbuffer(n.RENDERBUFFER,null)}function Ae(I,C){if(C&&C.isWebGLCubeRenderTarget)throw new Error("Depth Texture with cube render targets is not supported");if(t.bindFramebuffer(n.FRAMEBUFFER,I),!(C.depthTexture&&C.depthTexture.isDepthTexture))throw new Error("renderTarget.depthTexture must be an instance of THREE.DepthTexture");(!r.get(C.depthTexture).__webglTexture||C.depthTexture.image.width!==C.width||C.depthTexture.image.height!==C.height)&&(C.depthTexture.image.width=C.width,C.depthTexture.image.height=C.height,C.depthTexture.needsUpdate=!0),ae(C.depthTexture,0);const me=r.get(C.depthTexture).__webglTexture,Se=ht(C);if(C.depthTexture.format===Va)_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,me,0,Se):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,me,0);else if(C.depthTexture.format===Za)_t(C)?d.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,me,0,Se):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,me,0);else throw new Error("Unknown depthTexture format")}function Ie(I){const C=r.get(I),Q=I.isWebGLCubeRenderTarget===!0;if(C.__boundDepthTexture!==I.depthTexture){const me=I.depthTexture;if(C.__depthDisposeCallback&&C.__depthDisposeCallback(),me){const Se=()=>{delete C.__boundDepthTexture,delete C.__depthDisposeCallback,me.removeEventListener("dispose",Se)};me.addEventListener("dispose",Se),C.__depthDisposeCallback=Se}C.__boundDepthTexture=me}if(I.depthTexture&&!C.__autoAllocateDepthBuffer){if(Q)throw new Error("target.depthTexture not supported in Cube render targets");Ae(C.__webglFramebuffer,I)}else if(Q){C.__webglDepthbuffer=[];for(let me=0;me<6;me++)if(t.bindFramebuffer(n.FRAMEBUFFER,C.__webglFramebuffer[me]),C.__webglDepthbuffer[me]===void 0)C.__webglDepthbuffer[me]=n.createRenderbuffer(),Te(C.__webglDepthbuffer[me],I,!1);else{const Se=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,pe=C.__webglDepthbuffer[me];n.bindRenderbuffer(n.RENDERBUFFER,pe),n.framebufferRenderbuffer(n.FRAMEBUFFER,Se,n.RENDERBUFFER,pe)}}else if(t.bindFramebuffer(n.FRAMEBUFFER,C.__webglFramebuffer),C.__webglDepthbuffer===void 0)C.__webglDepthbuffer=n.createRenderbuffer(),Te(C.__webglDepthbuffer,I,!1);else{const me=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Se=C.__webglDepthbuffer;n.bindRenderbuffer(n.RENDERBUFFER,Se),n.framebufferRenderbuffer(n.FRAMEBUFFER,me,n.RENDERBUFFER,Se)}t.bindFramebuffer(n.FRAMEBUFFER,null)}function Ue(I,C,Q){const me=r.get(I);C!==void 0&&he(me.__webglFramebuffer,I,I.texture,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,0),Q!==void 0&&Ie(I)}function st(I){const C=I.texture,Q=r.get(I),me=r.get(C);I.addEventListener("dispose",D);const Se=I.textures,pe=I.isWebGLCubeRenderTarget===!0,Ze=Se.length>1;if(Ze||(me.__webglTexture===void 0&&(me.__webglTexture=n.createTexture()),me.__version=C.version,u.memory.textures++),pe){Q.__webglFramebuffer=[];for(let Le=0;Le<6;Le++)if(C.mipmaps&&C.mipmaps.length>0){Q.__webglFramebuffer[Le]=[];for(let Be=0;Be<C.mipmaps.length;Be++)Q.__webglFramebuffer[Le][Be]=n.createFramebuffer()}else Q.__webglFramebuffer[Le]=n.createFramebuffer()}else{if(C.mipmaps&&C.mipmaps.length>0){Q.__webglFramebuffer=[];for(let Le=0;Le<C.mipmaps.length;Le++)Q.__webglFramebuffer[Le]=n.createFramebuffer()}else Q.__webglFramebuffer=n.createFramebuffer();if(Ze)for(let Le=0,Be=Se.length;Le<Be;Le++){const vt=r.get(Se[Le]);vt.__webglTexture===void 0&&(vt.__webglTexture=n.createTexture(),u.memory.textures++)}if(I.samples>0&&_t(I)===!1){Q.__webglMultisampledFramebuffer=n.createFramebuffer(),Q.__webglColorRenderbuffer=[],t.bindFramebuffer(n.FRAMEBUFFER,Q.__webglMultisampledFramebuffer);for(let Le=0;Le<Se.length;Le++){const Be=Se[Le];Q.__webglColorRenderbuffer[Le]=n.createRenderbuffer(),n.bindRenderbuffer(n.RENDERBUFFER,Q.__webglColorRenderbuffer[Le]);const vt=c.convert(Be.format,Be.colorSpace),Ce=c.convert(Be.type),He=k(Be.internalFormat,vt,Ce,Be.colorSpace,I.isXRRenderTarget===!0),at=ht(I);n.renderbufferStorageMultisample(n.RENDERBUFFER,at,He,I.width,I.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Le,n.RENDERBUFFER,Q.__webglColorRenderbuffer[Le])}n.bindRenderbuffer(n.RENDERBUFFER,null),I.depthBuffer&&(Q.__webglDepthRenderbuffer=n.createRenderbuffer(),Te(Q.__webglDepthRenderbuffer,I,!0)),t.bindFramebuffer(n.FRAMEBUFFER,null)}}if(pe){t.bindTexture(n.TEXTURE_CUBE_MAP,me.__webglTexture),O(n.TEXTURE_CUBE_MAP,C);for(let Le=0;Le<6;Le++)if(C.mipmaps&&C.mipmaps.length>0)for(let Be=0;Be<C.mipmaps.length;Be++)he(Q.__webglFramebuffer[Le][Be],I,C,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+Le,Be);else he(Q.__webglFramebuffer[Le],I,C,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+Le,0);_(C)&&M(n.TEXTURE_CUBE_MAP),t.unbindTexture()}else if(Ze){for(let Le=0,Be=Se.length;Le<Be;Le++){const vt=Se[Le],Ce=r.get(vt);t.bindTexture(n.TEXTURE_2D,Ce.__webglTexture),O(n.TEXTURE_2D,vt),he(Q.__webglFramebuffer,I,vt,n.COLOR_ATTACHMENT0+Le,n.TEXTURE_2D,0),_(vt)&&M(n.TEXTURE_2D)}t.unbindTexture()}else{let Le=n.TEXTURE_2D;if((I.isWebGL3DRenderTarget||I.isWebGLArrayRenderTarget)&&(Le=I.isWebGL3DRenderTarget?n.TEXTURE_3D:n.TEXTURE_2D_ARRAY),t.bindTexture(Le,me.__webglTexture),O(Le,C),C.mipmaps&&C.mipmaps.length>0)for(let Be=0;Be<C.mipmaps.length;Be++)he(Q.__webglFramebuffer[Be],I,C,n.COLOR_ATTACHMENT0,Le,Be);else he(Q.__webglFramebuffer,I,C,n.COLOR_ATTACHMENT0,Le,0);_(C)&&M(Le),t.unbindTexture()}I.depthBuffer&&Ie(I)}function yt(I){const C=I.textures;for(let Q=0,me=C.length;Q<me;Q++){const Se=C[Q];if(_(Se)){const pe=I.isWebGLCubeRenderTarget?n.TEXTURE_CUBE_MAP:n.TEXTURE_2D,Ze=r.get(Se).__webglTexture;t.bindTexture(pe,Ze),M(pe),t.unbindTexture()}}}const pt=[],B=[];function _n(I){if(I.samples>0){if(_t(I)===!1){const C=I.textures,Q=I.width,me=I.height;let Se=n.COLOR_BUFFER_BIT;const pe=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Ze=r.get(I),Le=C.length>1;if(Le)for(let Be=0;Be<C.length;Be++)t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.RENDERBUFFER,null),t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.TEXTURE_2D,null,0);t.bindFramebuffer(n.READ_FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ze.__webglFramebuffer);for(let Be=0;Be<C.length;Be++){if(I.resolveDepthBuffer&&(I.depthBuffer&&(Se|=n.DEPTH_BUFFER_BIT),I.stencilBuffer&&I.resolveStencilBuffer&&(Se|=n.STENCIL_BUFFER_BIT)),Le){n.framebufferRenderbuffer(n.READ_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.RENDERBUFFER,Ze.__webglColorRenderbuffer[Be]);const vt=r.get(C[Be]).__webglTexture;n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,vt,0)}n.blitFramebuffer(0,0,Q,me,0,0,Q,me,Se,n.NEAREST),h===!0&&(pt.length=0,B.length=0,pt.push(n.COLOR_ATTACHMENT0+Be),I.depthBuffer&&I.resolveDepthBuffer===!1&&(pt.push(pe),B.push(pe),n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,B)),n.invalidateFramebuffer(n.READ_FRAMEBUFFER,pt))}if(t.bindFramebuffer(n.READ_FRAMEBUFFER,null),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),Le)for(let Be=0;Be<C.length;Be++){t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.RENDERBUFFER,Ze.__webglColorRenderbuffer[Be]);const vt=r.get(C[Be]).__webglTexture;t.bindFramebuffer(n.FRAMEBUFFER,Ze.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Be,n.TEXTURE_2D,vt,0)}t.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ze.__webglMultisampledFramebuffer)}else if(I.depthBuffer&&I.resolveDepthBuffer===!1&&h){const C=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT;n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,[C])}}}function ht(I){return Math.min(a.maxSamples,I.samples)}function _t(I){const C=r.get(I);return I.samples>0&&e.has("WEBGL_multisampled_render_to_texture")===!0&&C.__useRenderToTexture!==!1}function tt(I){const C=u.render.frame;g.get(I)!==C&&(g.set(I,C),I.update())}function kt(I,C){const Q=I.colorSpace,me=I.format,Se=I.type;return I.isCompressedTexture===!0||I.isVideoTexture===!0||Q!==fs&&Q!==is&&(Ct.getTransfer(Q)===Bt?(me!==Oi||Se!==wr)&&console.warn("THREE.WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):console.error("THREE.WebGLTextures: Unsupported texture color space:",Q)),C}function it(I){return typeof HTMLImageElement<"u"&&I instanceof HTMLImageElement?(p.width=I.naturalWidth||I.width,p.height=I.naturalHeight||I.height):typeof VideoFrame<"u"&&I instanceof VideoFrame?(p.width=I.displayWidth,p.height=I.displayHeight):(p.width=I.width,p.height=I.height),p}this.allocateTextureUnit=se,this.resetTextureUnits=P,this.setTexture2D=ae,this.setTexture2DArray=ve,this.setTexture3D=V,this.setTextureCube=de,this.rebindTextures=Ue,this.setupRenderTarget=st,this.updateRenderTargetMipmap=yt,this.updateMultisampleRenderTarget=_n,this.setupDepthRenderbuffer=Ie,this.setupFrameBufferTexture=he,this.useMultisampledRTT=_t}function qR(n,e){function t(r,a=is){let c;const u=Ct.getTransfer(a);if(r===wr)return n.UNSIGNED_BYTE;if(r===Dp)return n.UNSIGNED_SHORT_4_4_4_4;if(r===Ip)return n.UNSIGNED_SHORT_5_5_5_1;if(r===ex)return n.UNSIGNED_INT_5_9_9_9_REV;if(r===Qv)return n.BYTE;if(r===Jv)return n.SHORT;if(r===al)return n.UNSIGNED_SHORT;if(r===kp)return n.INT;if(r===Xs)return n.UNSIGNED_INT;if(r===xr)return n.FLOAT;if(r===ul)return n.HALF_FLOAT;if(r===tx)return n.ALPHA;if(r===nx)return n.RGB;if(r===Oi)return n.RGBA;if(r===ix)return n.LUMINANCE;if(r===rx)return n.LUMINANCE_ALPHA;if(r===Va)return n.DEPTH_COMPONENT;if(r===Za)return n.DEPTH_STENCIL;if(r===sx)return n.RED;if(r===Up)return n.RED_INTEGER;if(r===ax)return n.RG;if(r===Fp)return n.RG_INTEGER;if(r===Op)return n.RGBA_INTEGER;if(r===Jc||r===eu||r===tu||r===nu)if(u===Bt)if(c=e.get("WEBGL_compressed_texture_s3tc_srgb"),c!==null){if(r===Jc)return c.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(r===eu)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(r===tu)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(r===nu)return c.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(c=e.get("WEBGL_compressed_texture_s3tc"),c!==null){if(r===Jc)return c.COMPRESSED_RGB_S3TC_DXT1_EXT;if(r===eu)return c.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(r===tu)return c.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(r===nu)return c.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(r===Dh||r===Ih||r===Uh||r===Fh)if(c=e.get("WEBGL_compressed_texture_pvrtc"),c!==null){if(r===Dh)return c.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(r===Ih)return c.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(r===Uh)return c.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(r===Fh)return c.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(r===Oh||r===jh||r===zh)if(c=e.get("WEBGL_compressed_texture_etc"),c!==null){if(r===Oh||r===jh)return u===Bt?c.COMPRESSED_SRGB8_ETC2:c.COMPRESSED_RGB8_ETC2;if(r===zh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:c.COMPRESSED_RGBA8_ETC2_EAC}else return null;if(r===Bh||r===Hh||r===Vh||r===Gh||r===Wh||r===$h||r===Xh||r===qh||r===Yh||r===Kh||r===Zh||r===Qh||r===Jh||r===ep)if(c=e.get("WEBGL_compressed_texture_astc"),c!==null){if(r===Bh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:c.COMPRESSED_RGBA_ASTC_4x4_KHR;if(r===Hh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:c.COMPRESSED_RGBA_ASTC_5x4_KHR;if(r===Vh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:c.COMPRESSED_RGBA_ASTC_5x5_KHR;if(r===Gh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:c.COMPRESSED_RGBA_ASTC_6x5_KHR;if(r===Wh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:c.COMPRESSED_RGBA_ASTC_6x6_KHR;if(r===$h)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:c.COMPRESSED_RGBA_ASTC_8x5_KHR;if(r===Xh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:c.COMPRESSED_RGBA_ASTC_8x6_KHR;if(r===qh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:c.COMPRESSED_RGBA_ASTC_8x8_KHR;if(r===Yh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:c.COMPRESSED_RGBA_ASTC_10x5_KHR;if(r===Kh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:c.COMPRESSED_RGBA_ASTC_10x6_KHR;if(r===Zh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:c.COMPRESSED_RGBA_ASTC_10x8_KHR;if(r===Qh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:c.COMPRESSED_RGBA_ASTC_10x10_KHR;if(r===Jh)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:c.COMPRESSED_RGBA_ASTC_12x10_KHR;if(r===ep)return u===Bt?c.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:c.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(r===iu||r===tp||r===np)if(c=e.get("EXT_texture_compression_bptc"),c!==null){if(r===iu)return u===Bt?c.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:c.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(r===tp)return c.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(r===np)return c.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(r===ox||r===ip||r===rp||r===sp)if(c=e.get("EXT_texture_compression_rgtc"),c!==null){if(r===iu)return c.COMPRESSED_RED_RGTC1_EXT;if(r===ip)return c.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(r===rp)return c.COMPRESSED_RED_GREEN_RGTC2_EXT;if(r===sp)return c.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return r===Ka?n.UNSIGNED_INT_24_8:n[r]!==void 0?n[r]:null}return{convert:t}}class YR extends xi{constructor(e=[]){super(),this.isArrayCamera=!0,this.cameras=e}}class Bs extends oi{constructor(){super(),this.isGroup=!0,this.type="Group"}}const KR={type:"move"};class ah{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new Bs,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new Bs,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new re,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new re),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new Bs,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new re,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new re),this._grip}dispatchEvent(e){return this._targetRay!==null&&this._targetRay.dispatchEvent(e),this._grip!==null&&this._grip.dispatchEvent(e),this._hand!==null&&this._hand.dispatchEvent(e),this}connect(e){if(e&&e.hand){const t=this._hand;if(t)for(const r of e.hand.values())this._getHandJoint(t,r)}return this.dispatchEvent({type:"connected",data:e}),this}disconnect(e){return this.dispatchEvent({type:"disconnected",data:e}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(e,t,r){let a=null,c=null,u=null;const d=this._targetRay,h=this._grip,p=this._hand;if(e&&t.session.visibilityState!=="visible-blurred"){if(p&&e.hand){u=!0;for(const E of e.hand.values()){const _=t.getJointPose(E,r),M=this._getHandJoint(p,E);_!==null&&(M.matrix.fromArray(_.transform.matrix),M.matrix.decompose(M.position,M.rotation,M.scale),M.matrixWorldNeedsUpdate=!0,M.jointRadius=_.radius),M.visible=_!==null}const g=p.joints["index-finger-tip"],y=p.joints["thumb-tip"],v=g.position.distanceTo(y.position),x=.02,w=.005;p.inputState.pinching&&v>x+w?(p.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:e.handedness,target:this})):!p.inputState.pinching&&v<=x-w&&(p.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:e.handedness,target:this}))}else h!==null&&e.gripSpace&&(c=t.getPose(e.gripSpace,r),c!==null&&(h.matrix.fromArray(c.transform.matrix),h.matrix.decompose(h.position,h.rotation,h.scale),h.matrixWorldNeedsUpdate=!0,c.linearVelocity?(h.hasLinearVelocity=!0,h.linearVelocity.copy(c.linearVelocity)):h.hasLinearVelocity=!1,c.angularVelocity?(h.hasAngularVelocity=!0,h.angularVelocity.copy(c.angularVelocity)):h.hasAngularVelocity=!1));d!==null&&(a=t.getPose(e.targetRaySpace,r),a===null&&c!==null&&(a=c),a!==null&&(d.matrix.fromArray(a.transform.matrix),d.matrix.decompose(d.position,d.rotation,d.scale),d.matrixWorldNeedsUpdate=!0,a.linearVelocity?(d.hasLinearVelocity=!0,d.linearVelocity.copy(a.linearVelocity)):d.hasLinearVelocity=!1,a.angularVelocity?(d.hasAngularVelocity=!0,d.angularVelocity.copy(a.angularVelocity)):d.hasAngularVelocity=!1,this.dispatchEvent(KR)))}return d!==null&&(d.visible=a!==null),h!==null&&(h.visible=c!==null),p!==null&&(p.visible=u!==null),this}_getHandJoint(e,t){if(e.joints[t.jointName]===void 0){const r=new Bs;r.matrixAutoUpdate=!1,r.visible=!1,e.joints[t.jointName]=r,e.add(r)}return e.joints[t.jointName]}}const ZR=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,QR=`
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

}`;class JR{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(e,t,r){if(this.texture===null){const a=new Yn,c=e.properties.get(a);c.__webglTexture=t.texture,(t.depthNear!=r.depthNear||t.depthFar!=r.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=a}}getMesh(e){if(this.texture!==null&&this.mesh===null){const t=e.cameras[0].viewport,r=new br({vertexShader:ZR,fragmentShader:QR,uniforms:{depthColor:{value:this.texture},depthWidth:{value:t.z},depthHeight:{value:t.w}}});this.mesh=new ji(new ml(20,20),r)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}}class e3 extends ro{constructor(e,t){super();const r=this;let a=null,c=1,u=null,d="local-floor",h=1,p=null,g=null,y=null,v=null,x=null,w=null;const E=new JR,_=t.getContextAttributes();let M=null,k=null;const A=[],R=[],L=new bt;let D=null;const U=new xi;U.layers.enable(1),U.viewport=new Qt;const $=new xi;$.layers.enable(2),$.viewport=new Qt;const te=[U,$],T=new YR;T.layers.enable(1),T.layers.enable(2);let P=null,se=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(K){let he=A[K];return he===void 0&&(he=new ah,A[K]=he),he.getTargetRaySpace()},this.getControllerGrip=function(K){let he=A[K];return he===void 0&&(he=new ah,A[K]=he),he.getGripSpace()},this.getHand=function(K){let he=A[K];return he===void 0&&(he=new ah,A[K]=he),he.getHandSpace()};function J(K){const he=R.indexOf(K.inputSource);if(he===-1)return;const Te=A[he];Te!==void 0&&(Te.update(K.inputSource,K.frame,p||u),Te.dispatchEvent({type:K.type,data:K.inputSource}))}function ae(){a.removeEventListener("select",J),a.removeEventListener("selectstart",J),a.removeEventListener("selectend",J),a.removeEventListener("squeeze",J),a.removeEventListener("squeezestart",J),a.removeEventListener("squeezeend",J),a.removeEventListener("end",ae),a.removeEventListener("inputsourceschange",ve);for(let K=0;K<A.length;K++){const he=R[K];he!==null&&(R[K]=null,A[K].disconnect(he))}P=null,se=null,E.reset(),e.setRenderTarget(M),x=null,v=null,y=null,a=null,k=null,we.stop(),r.isPresenting=!1,e.setPixelRatio(D),e.setSize(L.width,L.height,!1),r.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(K){c=K,r.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(K){d=K,r.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return p||u},this.setReferenceSpace=function(K){p=K},this.getBaseLayer=function(){return v!==null?v:x},this.getBinding=function(){return y},this.getFrame=function(){return w},this.getSession=function(){return a},this.setSession=async function(K){if(a=K,a!==null){if(M=e.getRenderTarget(),a.addEventListener("select",J),a.addEventListener("selectstart",J),a.addEventListener("selectend",J),a.addEventListener("squeeze",J),a.addEventListener("squeezestart",J),a.addEventListener("squeezeend",J),a.addEventListener("end",ae),a.addEventListener("inputsourceschange",ve),_.xrCompatible!==!0&&await t.makeXRCompatible(),D=e.getPixelRatio(),e.getSize(L),a.renderState.layers===void 0){const he={antialias:_.antialias,alpha:!0,depth:_.depth,stencil:_.stencil,framebufferScaleFactor:c};x=new XRWebGLLayer(a,t,he),a.updateRenderState({baseLayer:x}),e.setPixelRatio(1),e.setSize(x.framebufferWidth,x.framebufferHeight,!1),k=new qs(x.framebufferWidth,x.framebufferHeight,{format:Oi,type:wr,colorSpace:e.outputColorSpace,stencilBuffer:_.stencil})}else{let he=null,Te=null,Ae=null;_.depth&&(Ae=_.stencil?t.DEPTH24_STENCIL8:t.DEPTH_COMPONENT24,he=_.stencil?Za:Va,Te=_.stencil?Ka:Xs);const Ie={colorFormat:t.RGBA8,depthFormat:Ae,scaleFactor:c};y=new XRWebGLBinding(a,t),v=y.createProjectionLayer(Ie),a.updateRenderState({layers:[v]}),e.setPixelRatio(1),e.setSize(v.textureWidth,v.textureHeight,!1),k=new qs(v.textureWidth,v.textureHeight,{format:Oi,type:wr,depthTexture:new Mx(v.textureWidth,v.textureHeight,Te,void 0,void 0,void 0,void 0,void 0,void 0,he),stencilBuffer:_.stencil,colorSpace:e.outputColorSpace,samples:_.antialias?4:0,resolveDepthBuffer:v.ignoreDepthValues===!1})}k.isXRRenderTarget=!0,this.setFoveation(h),p=null,u=await a.requestReferenceSpace(d),we.setContext(a),we.start(),r.isPresenting=!0,r.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(a!==null)return a.environmentBlendMode},this.getDepthTexture=function(){return E.getDepthTexture()};function ve(K){for(let he=0;he<K.removed.length;he++){const Te=K.removed[he],Ae=R.indexOf(Te);Ae>=0&&(R[Ae]=null,A[Ae].disconnect(Te))}for(let he=0;he<K.added.length;he++){const Te=K.added[he];let Ae=R.indexOf(Te);if(Ae===-1){for(let Ue=0;Ue<A.length;Ue++)if(Ue>=R.length){R.push(Te),Ae=Ue;break}else if(R[Ue]===null){R[Ue]=Te,Ae=Ue;break}if(Ae===-1)break}const Ie=A[Ae];Ie&&Ie.connect(Te)}}const V=new re,de=new re;function z(K,he,Te){V.setFromMatrixPosition(he.matrixWorld),de.setFromMatrixPosition(Te.matrixWorld);const Ae=V.distanceTo(de),Ie=he.projectionMatrix.elements,Ue=Te.projectionMatrix.elements,st=Ie[14]/(Ie[10]-1),yt=Ie[14]/(Ie[10]+1),pt=(Ie[9]+1)/Ie[5],B=(Ie[9]-1)/Ie[5],_n=(Ie[8]-1)/Ie[0],ht=(Ue[8]+1)/Ue[0],_t=st*_n,tt=st*ht,kt=Ae/(-_n+ht),it=kt*-_n;if(he.matrixWorld.decompose(K.position,K.quaternion,K.scale),K.translateX(it),K.translateZ(kt),K.matrixWorld.compose(K.position,K.quaternion,K.scale),K.matrixWorldInverse.copy(K.matrixWorld).invert(),Ie[10]===-1)K.projectionMatrix.copy(he.projectionMatrix),K.projectionMatrixInverse.copy(he.projectionMatrixInverse);else{const I=st+kt,C=yt+kt,Q=_t-it,me=tt+(Ae-it),Se=pt*yt/C*I,pe=B*yt/C*I;K.projectionMatrix.makePerspective(Q,me,Se,pe,I,C),K.projectionMatrixInverse.copy(K.projectionMatrix).invert()}}function ue(K,he){he===null?K.matrixWorld.copy(K.matrix):K.matrixWorld.multiplyMatrices(he.matrixWorld,K.matrix),K.matrixWorldInverse.copy(K.matrixWorld).invert()}this.updateCamera=function(K){if(a===null)return;let he=K.near,Te=K.far;E.texture!==null&&(E.depthNear>0&&(he=E.depthNear),E.depthFar>0&&(Te=E.depthFar)),T.near=$.near=U.near=he,T.far=$.far=U.far=Te,(P!==T.near||se!==T.far)&&(a.updateRenderState({depthNear:T.near,depthFar:T.far}),P=T.near,se=T.far);const Ae=K.parent,Ie=T.cameras;ue(T,Ae);for(let Ue=0;Ue<Ie.length;Ue++)ue(Ie[Ue],Ae);Ie.length===2?z(T,U,$):T.projectionMatrix.copy(U.projectionMatrix),oe(K,T,Ae)};function oe(K,he,Te){Te===null?K.matrix.copy(he.matrixWorld):(K.matrix.copy(Te.matrixWorld),K.matrix.invert(),K.matrix.multiply(he.matrixWorld)),K.matrix.decompose(K.position,K.quaternion,K.scale),K.updateMatrixWorld(!0),K.projectionMatrix.copy(he.projectionMatrix),K.projectionMatrixInverse.copy(he.projectionMatrixInverse),K.isPerspectiveCamera&&(K.fov=ap*2*Math.atan(1/K.projectionMatrix.elements[5]),K.zoom=1)}this.getCamera=function(){return T},this.getFoveation=function(){if(!(v===null&&x===null))return h},this.setFoveation=function(K){h=K,v!==null&&(v.fixedFoveation=K),x!==null&&x.fixedFoveation!==void 0&&(x.fixedFoveation=K)},this.hasDepthSensing=function(){return E.texture!==null},this.getDepthSensingMesh=function(){return E.getMesh(T)};let O=null;function le(K,he){if(g=he.getViewerPose(p||u),w=he,g!==null){const Te=g.views;x!==null&&(e.setRenderTargetFramebuffer(k,x.framebuffer),e.setRenderTarget(k));let Ae=!1;Te.length!==T.cameras.length&&(T.cameras.length=0,Ae=!0);for(let Ue=0;Ue<Te.length;Ue++){const st=Te[Ue];let yt=null;if(x!==null)yt=x.getViewport(st);else{const B=y.getViewSubImage(v,st);yt=B.viewport,Ue===0&&(e.setRenderTargetTextures(k,B.colorTexture,v.ignoreDepthValues?void 0:B.depthStencilTexture),e.setRenderTarget(k))}let pt=te[Ue];pt===void 0&&(pt=new xi,pt.layers.enable(Ue),pt.viewport=new Qt,te[Ue]=pt),pt.matrix.fromArray(st.transform.matrix),pt.matrix.decompose(pt.position,pt.quaternion,pt.scale),pt.projectionMatrix.fromArray(st.projectionMatrix),pt.projectionMatrixInverse.copy(pt.projectionMatrix).invert(),pt.viewport.set(yt.x,yt.y,yt.width,yt.height),Ue===0&&(T.matrix.copy(pt.matrix),T.matrix.decompose(T.position,T.quaternion,T.scale)),Ae===!0&&T.cameras.push(pt)}const Ie=a.enabledFeatures;if(Ie&&Ie.includes("depth-sensing")){const Ue=y.getDepthInformation(Te[0]);Ue&&Ue.isValid&&Ue.texture&&E.init(e,Ue,a.renderState)}}for(let Te=0;Te<A.length;Te++){const Ae=R[Te],Ie=A[Te];Ae!==null&&Ie!==void 0&&Ie.update(Ae,he,p||u)}O&&O(K,he),he.detectedPlanes&&r.dispatchEvent({type:"planesdetected",data:he}),w=null}const we=new yx;we.setAnimationLoop(le),this.setAnimationLoop=function(K){O=K},this.dispose=function(){}}}const Ls=new Tr,t3=new nn;function n3(n,e){function t(_,M){_.matrixAutoUpdate===!0&&_.updateMatrix(),M.value.copy(_.matrix)}function r(_,M){M.color.getRGB(_.fogColor.value,gx(n)),M.isFog?(_.fogNear.value=M.near,_.fogFar.value=M.far):M.isFogExp2&&(_.fogDensity.value=M.density)}function a(_,M,k,A,R){M.isMeshBasicMaterial||M.isMeshLambertMaterial?c(_,M):M.isMeshToonMaterial?(c(_,M),y(_,M)):M.isMeshPhongMaterial?(c(_,M),g(_,M)):M.isMeshStandardMaterial?(c(_,M),v(_,M),M.isMeshPhysicalMaterial&&x(_,M,R)):M.isMeshMatcapMaterial?(c(_,M),w(_,M)):M.isMeshDepthMaterial?c(_,M):M.isMeshDistanceMaterial?(c(_,M),E(_,M)):M.isMeshNormalMaterial?c(_,M):M.isLineBasicMaterial?(u(_,M),M.isLineDashedMaterial&&d(_,M)):M.isPointsMaterial?h(_,M,k,A):M.isSpriteMaterial?p(_,M):M.isShadowMaterial?(_.color.value.copy(M.color),_.opacity.value=M.opacity):M.isShaderMaterial&&(M.uniformsNeedUpdate=!1)}function c(_,M){_.opacity.value=M.opacity,M.color&&_.diffuse.value.copy(M.color),M.emissive&&_.emissive.value.copy(M.emissive).multiplyScalar(M.emissiveIntensity),M.map&&(_.map.value=M.map,t(M.map,_.mapTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.bumpMap&&(_.bumpMap.value=M.bumpMap,t(M.bumpMap,_.bumpMapTransform),_.bumpScale.value=M.bumpScale,M.side===qn&&(_.bumpScale.value*=-1)),M.normalMap&&(_.normalMap.value=M.normalMap,t(M.normalMap,_.normalMapTransform),_.normalScale.value.copy(M.normalScale),M.side===qn&&_.normalScale.value.negate()),M.displacementMap&&(_.displacementMap.value=M.displacementMap,t(M.displacementMap,_.displacementMapTransform),_.displacementScale.value=M.displacementScale,_.displacementBias.value=M.displacementBias),M.emissiveMap&&(_.emissiveMap.value=M.emissiveMap,t(M.emissiveMap,_.emissiveMapTransform)),M.specularMap&&(_.specularMap.value=M.specularMap,t(M.specularMap,_.specularMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest);const k=e.get(M),A=k.envMap,R=k.envMapRotation;A&&(_.envMap.value=A,Ls.copy(R),Ls.x*=-1,Ls.y*=-1,Ls.z*=-1,A.isCubeTexture&&A.isRenderTargetTexture===!1&&(Ls.y*=-1,Ls.z*=-1),_.envMapRotation.value.setFromMatrix4(t3.makeRotationFromEuler(Ls)),_.flipEnvMap.value=A.isCubeTexture&&A.isRenderTargetTexture===!1?-1:1,_.reflectivity.value=M.reflectivity,_.ior.value=M.ior,_.refractionRatio.value=M.refractionRatio),M.lightMap&&(_.lightMap.value=M.lightMap,_.lightMapIntensity.value=M.lightMapIntensity,t(M.lightMap,_.lightMapTransform)),M.aoMap&&(_.aoMap.value=M.aoMap,_.aoMapIntensity.value=M.aoMapIntensity,t(M.aoMap,_.aoMapTransform))}function u(_,M){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,M.map&&(_.map.value=M.map,t(M.map,_.mapTransform))}function d(_,M){_.dashSize.value=M.dashSize,_.totalSize.value=M.dashSize+M.gapSize,_.scale.value=M.scale}function h(_,M,k,A){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,_.size.value=M.size*k,_.scale.value=A*.5,M.map&&(_.map.value=M.map,t(M.map,_.uvTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest)}function p(_,M){_.diffuse.value.copy(M.color),_.opacity.value=M.opacity,_.rotation.value=M.rotation,M.map&&(_.map.value=M.map,t(M.map,_.mapTransform)),M.alphaMap&&(_.alphaMap.value=M.alphaMap,t(M.alphaMap,_.alphaMapTransform)),M.alphaTest>0&&(_.alphaTest.value=M.alphaTest)}function g(_,M){_.specular.value.copy(M.specular),_.shininess.value=Math.max(M.shininess,1e-4)}function y(_,M){M.gradientMap&&(_.gradientMap.value=M.gradientMap)}function v(_,M){_.metalness.value=M.metalness,M.metalnessMap&&(_.metalnessMap.value=M.metalnessMap,t(M.metalnessMap,_.metalnessMapTransform)),_.roughness.value=M.roughness,M.roughnessMap&&(_.roughnessMap.value=M.roughnessMap,t(M.roughnessMap,_.roughnessMapTransform)),M.envMap&&(_.envMapIntensity.value=M.envMapIntensity)}function x(_,M,k){_.ior.value=M.ior,M.sheen>0&&(_.sheenColor.value.copy(M.sheenColor).multiplyScalar(M.sheen),_.sheenRoughness.value=M.sheenRoughness,M.sheenColorMap&&(_.sheenColorMap.value=M.sheenColorMap,t(M.sheenColorMap,_.sheenColorMapTransform)),M.sheenRoughnessMap&&(_.sheenRoughnessMap.value=M.sheenRoughnessMap,t(M.sheenRoughnessMap,_.sheenRoughnessMapTransform))),M.clearcoat>0&&(_.clearcoat.value=M.clearcoat,_.clearcoatRoughness.value=M.clearcoatRoughness,M.clearcoatMap&&(_.clearcoatMap.value=M.clearcoatMap,t(M.clearcoatMap,_.clearcoatMapTransform)),M.clearcoatRoughnessMap&&(_.clearcoatRoughnessMap.value=M.clearcoatRoughnessMap,t(M.clearcoatRoughnessMap,_.clearcoatRoughnessMapTransform)),M.clearcoatNormalMap&&(_.clearcoatNormalMap.value=M.clearcoatNormalMap,t(M.clearcoatNormalMap,_.clearcoatNormalMapTransform),_.clearcoatNormalScale.value.copy(M.clearcoatNormalScale),M.side===qn&&_.clearcoatNormalScale.value.negate())),M.dispersion>0&&(_.dispersion.value=M.dispersion),M.iridescence>0&&(_.iridescence.value=M.iridescence,_.iridescenceIOR.value=M.iridescenceIOR,_.iridescenceThicknessMinimum.value=M.iridescenceThicknessRange[0],_.iridescenceThicknessMaximum.value=M.iridescenceThicknessRange[1],M.iridescenceMap&&(_.iridescenceMap.value=M.iridescenceMap,t(M.iridescenceMap,_.iridescenceMapTransform)),M.iridescenceThicknessMap&&(_.iridescenceThicknessMap.value=M.iridescenceThicknessMap,t(M.iridescenceThicknessMap,_.iridescenceThicknessMapTransform))),M.transmission>0&&(_.transmission.value=M.transmission,_.transmissionSamplerMap.value=k.texture,_.transmissionSamplerSize.value.set(k.width,k.height),M.transmissionMap&&(_.transmissionMap.value=M.transmissionMap,t(M.transmissionMap,_.transmissionMapTransform)),_.thickness.value=M.thickness,M.thicknessMap&&(_.thicknessMap.value=M.thicknessMap,t(M.thicknessMap,_.thicknessMapTransform)),_.attenuationDistance.value=M.attenuationDistance,_.attenuationColor.value.copy(M.attenuationColor)),M.anisotropy>0&&(_.anisotropyVector.value.set(M.anisotropy*Math.cos(M.anisotropyRotation),M.anisotropy*Math.sin(M.anisotropyRotation)),M.anisotropyMap&&(_.anisotropyMap.value=M.anisotropyMap,t(M.anisotropyMap,_.anisotropyMapTransform))),_.specularIntensity.value=M.specularIntensity,_.specularColor.value.copy(M.specularColor),M.specularColorMap&&(_.specularColorMap.value=M.specularColorMap,t(M.specularColorMap,_.specularColorMapTransform)),M.specularIntensityMap&&(_.specularIntensityMap.value=M.specularIntensityMap,t(M.specularIntensityMap,_.specularIntensityMapTransform))}function w(_,M){M.matcap&&(_.matcap.value=M.matcap)}function E(_,M){const k=e.get(M).light;_.referencePosition.value.setFromMatrixPosition(k.matrixWorld),_.nearDistance.value=k.shadow.camera.near,_.farDistance.value=k.shadow.camera.far}return{refreshFogUniforms:r,refreshMaterialUniforms:a}}function i3(n,e,t,r){let a={},c={},u=[];const d=n.getParameter(n.MAX_UNIFORM_BUFFER_BINDINGS);function h(k,A){const R=A.program;r.uniformBlockBinding(k,R)}function p(k,A){let R=a[k.id];R===void 0&&(w(k),R=g(k),a[k.id]=R,k.addEventListener("dispose",_));const L=A.program;r.updateUBOMapping(k,L);const D=e.render.frame;c[k.id]!==D&&(v(k),c[k.id]=D)}function g(k){const A=y();k.__bindingPointIndex=A;const R=n.createBuffer(),L=k.__size,D=k.usage;return n.bindBuffer(n.UNIFORM_BUFFER,R),n.bufferData(n.UNIFORM_BUFFER,L,D),n.bindBuffer(n.UNIFORM_BUFFER,null),n.bindBufferBase(n.UNIFORM_BUFFER,A,R),R}function y(){for(let k=0;k<d;k++)if(u.indexOf(k)===-1)return u.push(k),k;return console.error("THREE.WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function v(k){const A=a[k.id],R=k.uniforms,L=k.__cache;n.bindBuffer(n.UNIFORM_BUFFER,A);for(let D=0,U=R.length;D<U;D++){const $=Array.isArray(R[D])?R[D]:[R[D]];for(let te=0,T=$.length;te<T;te++){const P=$[te];if(x(P,D,te,L)===!0){const se=P.__offset,J=Array.isArray(P.value)?P.value:[P.value];let ae=0;for(let ve=0;ve<J.length;ve++){const V=J[ve],de=E(V);typeof V=="number"||typeof V=="boolean"?(P.__data[0]=V,n.bufferSubData(n.UNIFORM_BUFFER,se+ae,P.__data)):V.isMatrix3?(P.__data[0]=V.elements[0],P.__data[1]=V.elements[1],P.__data[2]=V.elements[2],P.__data[3]=0,P.__data[4]=V.elements[3],P.__data[5]=V.elements[4],P.__data[6]=V.elements[5],P.__data[7]=0,P.__data[8]=V.elements[6],P.__data[9]=V.elements[7],P.__data[10]=V.elements[8],P.__data[11]=0):(V.toArray(P.__data,ae),ae+=de.storage/Float32Array.BYTES_PER_ELEMENT)}n.bufferSubData(n.UNIFORM_BUFFER,se,P.__data)}}}n.bindBuffer(n.UNIFORM_BUFFER,null)}function x(k,A,R,L){const D=k.value,U=A+"_"+R;if(L[U]===void 0)return typeof D=="number"||typeof D=="boolean"?L[U]=D:L[U]=D.clone(),!0;{const $=L[U];if(typeof D=="number"||typeof D=="boolean"){if($!==D)return L[U]=D,!0}else if($.equals(D)===!1)return $.copy(D),!0}return!1}function w(k){const A=k.uniforms;let R=0;const L=16;for(let U=0,$=A.length;U<$;U++){const te=Array.isArray(A[U])?A[U]:[A[U]];for(let T=0,P=te.length;T<P;T++){const se=te[T],J=Array.isArray(se.value)?se.value:[se.value];for(let ae=0,ve=J.length;ae<ve;ae++){const V=J[ae],de=E(V),z=R%L,ue=z%de.boundary,oe=z+ue;R+=ue,oe!==0&&L-oe<de.storage&&(R+=L-oe),se.__data=new Float32Array(de.storage/Float32Array.BYTES_PER_ELEMENT),se.__offset=R,R+=de.storage}}}const D=R%L;return D>0&&(R+=L-D),k.__size=R,k.__cache={},this}function E(k){const A={boundary:0,storage:0};return typeof k=="number"||typeof k=="boolean"?(A.boundary=4,A.storage=4):k.isVector2?(A.boundary=8,A.storage=8):k.isVector3||k.isColor?(A.boundary=16,A.storage=12):k.isVector4?(A.boundary=16,A.storage=16):k.isMatrix3?(A.boundary=48,A.storage=48):k.isMatrix4?(A.boundary=64,A.storage=64):k.isTexture?console.warn("THREE.WebGLRenderer: Texture samplers can not be part of an uniforms group."):console.warn("THREE.WebGLRenderer: Unsupported uniform value type.",k),A}function _(k){const A=k.target;A.removeEventListener("dispose",_);const R=u.indexOf(A.__bindingPointIndex);u.splice(R,1),n.deleteBuffer(a[A.id]),delete a[A.id],delete c[A.id]}function M(){for(const k in a)n.deleteBuffer(a[k]);u=[],a={},c={}}return{bind:h,update:p,dispose:M}}class r3{constructor(e={}){const{canvas:t=GT(),context:r=null,depth:a=!0,stencil:c=!1,alpha:u=!1,antialias:d=!1,premultipliedAlpha:h=!0,preserveDrawingBuffer:p=!1,powerPreference:g="default",failIfMajorPerformanceCaveat:y=!1}=e;this.isWebGLRenderer=!0;let v;if(r!==null){if(typeof WebGLRenderingContext<"u"&&r instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");v=r.getContextAttributes().alpha}else v=u;const x=new Uint32Array(4),w=new Int32Array(4);let E=null,_=null;const M=[],k=[];this.domElement=t,this.debug={checkShaderErrors:!0,onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this._outputColorSpace=$i,this.toneMapping=os,this.toneMappingExposure=1;const A=this;let R=!1,L=0,D=0,U=null,$=-1,te=null;const T=new Qt,P=new Qt;let se=null;const J=new Rt(0);let ae=0,ve=t.width,V=t.height,de=1,z=null,ue=null;const oe=new Qt(0,0,ve,V),O=new Qt(0,0,ve,V);let le=!1;const we=new xx;let K=!1,he=!1;const Te=new nn,Ae=new nn,Ie=new re,Ue=new Qt,st={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0};let yt=!1;function pt(){return U===null?de:1}let B=r;function _n(N,W){return t.getContext(N,W)}try{const N={alpha:!0,depth:a,stencil:c,antialias:d,premultipliedAlpha:h,preserveDrawingBuffer:p,powerPreference:g,failIfMajorPerformanceCaveat:y};if("setAttribute"in t&&t.setAttribute("data-engine",`three.js r${Lp}`),t.addEventListener("webglcontextlost",ge,!1),t.addEventListener("webglcontextrestored",ke,!1),t.addEventListener("webglcontextcreationerror",je,!1),B===null){const W="webgl2";if(B=_n(W,N),B===null)throw _n(W)?new Error("Error creating WebGL context with your selected attributes."):new Error("Error creating WebGL context.")}}catch(N){throw console.error("THREE.WebGLRenderer: "+N.message),N}let ht,_t,tt,kt,it,I,C,Q,me,Se,pe,Ze,Le,Be,vt,Ce,He,at,rt,Ge,mt,lt,At,G;function Fe(){ht=new cN(B),ht.init(),lt=new qR(B,ht),_t=new iN(B,ht,e,lt),tt=new WR(B),_t.reverseDepthBuffer&&tt.buffers.depth.setReversed(!0),kt=new fN(B),it=new RR,I=new XR(B,ht,tt,it,_t,lt,kt),C=new sN(A),Q=new lN(A),me=new xb(B),At=new tN(B,me),Se=new uN(B,me,kt,At),pe=new pN(B,Se,me,kt),rt=new hN(B,_t,I),Ce=new rN(it),Ze=new NR(A,C,Q,ht,_t,At,Ce),Le=new n3(A,it),Be=new LR,vt=new OR(ht),at=new eN(A,C,Q,tt,pe,v,h),He=new VR(A,pe,_t),G=new i3(B,kt,_t,tt),Ge=new nN(B,ht,kt),mt=new dN(B,ht,kt),kt.programs=Ze.programs,A.capabilities=_t,A.extensions=ht,A.properties=it,A.renderLists=Be,A.shadowMap=He,A.state=tt,A.info=kt}Fe();const ce=new e3(A,B);this.xr=ce,this.getContext=function(){return B},this.getContextAttributes=function(){return B.getContextAttributes()},this.forceContextLoss=function(){const N=ht.get("WEBGL_lose_context");N&&N.loseContext()},this.forceContextRestore=function(){const N=ht.get("WEBGL_lose_context");N&&N.restoreContext()},this.getPixelRatio=function(){return de},this.setPixelRatio=function(N){N!==void 0&&(de=N,this.setSize(ve,V,!1))},this.getSize=function(N){return N.set(ve,V)},this.setSize=function(N,W,ee=!0){if(ce.isPresenting){console.warn("THREE.WebGLRenderer: Can't change size while VR device is presenting.");return}ve=N,V=W,t.width=Math.floor(N*de),t.height=Math.floor(W*de),ee===!0&&(t.style.width=N+"px",t.style.height=W+"px"),this.setViewport(0,0,N,W)},this.getDrawingBufferSize=function(N){return N.set(ve*de,V*de).floor()},this.setDrawingBufferSize=function(N,W,ee){ve=N,V=W,de=ee,t.width=Math.floor(N*ee),t.height=Math.floor(W*ee),this.setViewport(0,0,N,W)},this.getCurrentViewport=function(N){return N.copy(T)},this.getViewport=function(N){return N.copy(oe)},this.setViewport=function(N,W,ee,ne){N.isVector4?oe.set(N.x,N.y,N.z,N.w):oe.set(N,W,ee,ne),tt.viewport(T.copy(oe).multiplyScalar(de).round())},this.getScissor=function(N){return N.copy(O)},this.setScissor=function(N,W,ee,ne){N.isVector4?O.set(N.x,N.y,N.z,N.w):O.set(N,W,ee,ne),tt.scissor(P.copy(O).multiplyScalar(de).round())},this.getScissorTest=function(){return le},this.setScissorTest=function(N){tt.setScissorTest(le=N)},this.setOpaqueSort=function(N){z=N},this.setTransparentSort=function(N){ue=N},this.getClearColor=function(N){return N.copy(at.getClearColor())},this.setClearColor=function(){at.setClearColor.apply(at,arguments)},this.getClearAlpha=function(){return at.getClearAlpha()},this.setClearAlpha=function(){at.setClearAlpha.apply(at,arguments)},this.clear=function(N=!0,W=!0,ee=!0){let ne=0;if(N){let X=!1;if(U!==null){const Re=U.texture.format;X=Re===Op||Re===Fp||Re===Up}if(X){const Re=U.texture.type,Oe=Re===wr||Re===Xs||Re===al||Re===Ka||Re===Dp||Re===Ip,Pe=at.getClearColor(),qe=at.getClearAlpha(),et=Pe.r,nt=Pe.g,Ye=Pe.b;Oe?(x[0]=et,x[1]=nt,x[2]=Ye,x[3]=qe,B.clearBufferuiv(B.COLOR,0,x)):(w[0]=et,w[1]=nt,w[2]=Ye,w[3]=qe,B.clearBufferiv(B.COLOR,0,w))}else ne|=B.COLOR_BUFFER_BIT}W&&(ne|=B.DEPTH_BUFFER_BIT,B.clearDepth(this.capabilities.reverseDepthBuffer?0:1)),ee&&(ne|=B.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),B.clear(ne)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.dispose=function(){t.removeEventListener("webglcontextlost",ge,!1),t.removeEventListener("webglcontextrestored",ke,!1),t.removeEventListener("webglcontextcreationerror",je,!1),Be.dispose(),vt.dispose(),it.dispose(),C.dispose(),Q.dispose(),pe.dispose(),At.dispose(),G.dispose(),Ze.dispose(),ce.dispose(),ce.removeEventListener("sessionstart",Cr),ce.removeEventListener("sessionend",Zs),Zn.stop()};function ge(N){N.preventDefault(),console.log("THREE.WebGLRenderer: Context Lost."),R=!0}function ke(){console.log("THREE.WebGLRenderer: Context Restored."),R=!1;const N=kt.autoReset,W=He.enabled,ee=He.autoUpdate,ne=He.needsUpdate,X=He.type;Fe(),kt.autoReset=N,He.enabled=W,He.autoUpdate=ee,He.needsUpdate=ne,He.type=X}function je(N){console.error("THREE.WebGLRenderer: A WebGL context could not be created. Reason: ",N.statusMessage)}function gt(N){const W=N.target;W.removeEventListener("dispose",gt),$t(W)}function $t(N){vn(N),it.remove(N)}function vn(N){const W=it.get(N).programs;W!==void 0&&(W.forEach(function(ee){Ze.releaseProgram(ee)}),N.isShaderMaterial&&Ze.releaseShaderCache(N))}this.renderBufferDirect=function(N,W,ee,ne,X,Re){W===null&&(W=st);const Oe=X.isMesh&&X.matrixWorld.determinant()<0,Pe=tr(N,W,ee,ne,X);tt.setMaterial(ne,Oe);let qe=ee.index,et=1;if(ne.wireframe===!0){if(qe=Se.getWireframeAttribute(ee),qe===void 0)return;et=2}const nt=ee.drawRange,Ye=ee.attributes.position;let Tt=nt.start*et,Dt=(nt.start+nt.count)*et;Re!==null&&(Tt=Math.max(Tt,Re.start*et),Dt=Math.min(Dt,(Re.start+Re.count)*et)),qe!==null?(Tt=Math.max(Tt,0),Dt=Math.min(Dt,qe.count)):Ye!=null&&(Tt=Math.max(Tt,0),Dt=Math.min(Dt,Ye.count));const It=Dt-Tt;if(It<0||It===1/0)return;At.setup(X,ne,Pe,ee,qe);let Vt,Mt=Ge;if(qe!==null&&(Vt=me.get(qe),Mt=mt,Mt.setIndex(Vt)),X.isMesh)ne.wireframe===!0?(tt.setLineWidth(ne.wireframeLinewidth*pt()),Mt.setMode(B.LINES)):Mt.setMode(B.TRIANGLES);else if(X.isLine){let Ve=ne.linewidth;Ve===void 0&&(Ve=1),tt.setLineWidth(Ve*pt()),X.isLineSegments?Mt.setMode(B.LINES):X.isLineLoop?Mt.setMode(B.LINE_LOOP):Mt.setMode(B.LINE_STRIP)}else X.isPoints?Mt.setMode(B.POINTS):X.isSprite&&Mt.setMode(B.TRIANGLES);if(X.isBatchedMesh)if(X._multiDrawInstances!==null)Mt.renderMultiDrawInstances(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount,X._multiDrawInstances);else if(ht.get("WEBGL_multi_draw"))Mt.renderMultiDraw(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount);else{const Ve=X._multiDrawStarts,rn=X._multiDrawCounts,Et=X._multiDrawCount,Qn=qe?me.get(qe).bytesPerElement:1,wi=it.get(ne).currentProgram.getUniforms();for(let fn=0;fn<Et;fn++)wi.setValue(B,"_gl_DrawID",fn),Mt.render(Ve[fn]/Qn,rn[fn])}else if(X.isInstancedMesh)Mt.renderInstances(Tt,It,X.count);else if(ee.isInstancedBufferGeometry){const Ve=ee._maxInstanceCount!==void 0?ee._maxInstanceCount:1/0,rn=Math.min(ee.instanceCount,Ve);Mt.renderInstances(Tt,It,rn)}else Mt.render(Tt,It)};function xt(N,W,ee){N.transparent===!0&&N.side===Yi&&N.forceSinglePass===!1?(N.side=qn,N.needsUpdate=!0,Js(N,W,ee),N.side=us,N.needsUpdate=!0,Js(N,W,ee),N.side=Yi):Js(N,W,ee)}this.compile=function(N,W,ee=null){ee===null&&(ee=N),_=vt.get(ee),_.init(W),k.push(_),ee.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(_.pushLight(X),X.castShadow&&_.pushShadow(X))}),N!==ee&&N.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(_.pushLight(X),X.castShadow&&_.pushShadow(X))}),_.setupLights();const ne=new Set;return N.traverse(function(X){if(!(X.isMesh||X.isPoints||X.isLine||X.isSprite))return;const Re=X.material;if(Re)if(Array.isArray(Re))for(let Oe=0;Oe<Re.length;Oe++){const Pe=Re[Oe];xt(Pe,ee,X),ne.add(Pe)}else xt(Re,ee,X),ne.add(Re)}),k.pop(),_=null,ne},this.compileAsync=function(N,W,ee=null){const ne=this.compile(N,W,ee);return new Promise(X=>{function Re(){if(ne.forEach(function(Oe){it.get(Oe).currentProgram.isReady()&&ne.delete(Oe)}),ne.size===0){X(N);return}setTimeout(Re,10)}ht.get("KHR_parallel_shader_compile")!==null?Re():setTimeout(Re,10)})};let dn=null;function ci(N){dn&&dn(N)}function Cr(){Zn.stop()}function Zs(){Zn.start()}const Zn=new yx;Zn.setAnimationLoop(ci),typeof self<"u"&&Zn.setContext(self),this.setAnimationLoop=function(N){dn=N,ce.setAnimationLoop(N),N===null?Zn.stop():Zn.start()},ce.addEventListener("sessionstart",Cr),ce.addEventListener("sessionend",Zs),this.render=function(N,W){if(W!==void 0&&W.isCamera!==!0){console.error("THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(R===!0)return;if(N.matrixWorldAutoUpdate===!0&&N.updateMatrixWorld(),W.parent===null&&W.matrixWorldAutoUpdate===!0&&W.updateMatrixWorld(),ce.enabled===!0&&ce.isPresenting===!0&&(ce.cameraAutoUpdate===!0&&ce.updateCamera(W),W=ce.getCamera()),N.isScene===!0&&N.onBeforeRender(A,N,W,U),_=vt.get(N,k.length),_.init(W),k.push(_),Ae.multiplyMatrices(W.projectionMatrix,W.matrixWorldInverse),we.setFromProjectionMatrix(Ae),he=this.localClippingEnabled,K=Ce.init(this.clippingPlanes,he),E=Be.get(N,M.length),E.init(),M.push(E),ce.enabled===!0&&ce.isPresenting===!0){const Re=A.xr.getDepthSensingMesh();Re!==null&&ao(Re,W,-1/0,A.sortObjects)}ao(N,W,0,A.sortObjects),E.finish(),A.sortObjects===!0&&E.sort(z,ue),yt=ce.enabled===!1||ce.isPresenting===!1||ce.hasDepthSensing()===!1,yt&&at.addToRenderList(E,N),this.info.render.frame++,K===!0&&Ce.beginShadows();const ee=_.state.shadowsArray;He.render(ee,N,W),K===!0&&Ce.endShadows(),this.info.autoReset===!0&&this.info.reset();const ne=E.opaque,X=E.transmissive;if(_.setupLights(),W.isArrayCamera){const Re=W.cameras;if(X.length>0)for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++){const qe=Re[Oe];hs(ne,X,N,qe)}yt&&at.render(N);for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++){const qe=Re[Oe];Nr(E,N,qe,qe.viewport)}}else X.length>0&&hs(ne,X,N,W),yt&&at.render(N),Nr(E,N,W);U!==null&&(I.updateMultisampleRenderTarget(U),I.updateRenderTargetMipmap(U)),N.isScene===!0&&N.onAfterRender(A,N,W),At.resetDefaultState(),$=-1,te=null,k.pop(),k.length>0?(_=k[k.length-1],K===!0&&Ce.setGlobalState(A.clippingPlanes,_.state.camera)):_=null,M.pop(),M.length>0?E=M[M.length-1]:E=null};function ao(N,W,ee,ne){if(N.visible===!1)return;if(N.layers.test(W.layers)){if(N.isGroup)ee=N.renderOrder;else if(N.isLOD)N.autoUpdate===!0&&N.update(W);else if(N.isLight)_.pushLight(N),N.castShadow&&_.pushShadow(N);else if(N.isSprite){if(!N.frustumCulled||we.intersectsSprite(N)){ne&&Ue.setFromMatrixPosition(N.matrixWorld).applyMatrix4(Ae);const Oe=pe.update(N),Pe=N.material;Pe.visible&&E.push(N,Oe,Pe,ee,Ue.z,null)}}else if((N.isMesh||N.isLine||N.isPoints)&&(!N.frustumCulled||we.intersectsObject(N))){const Oe=pe.update(N),Pe=N.material;if(ne&&(N.boundingSphere!==void 0?(N.boundingSphere===null&&N.computeBoundingSphere(),Ue.copy(N.boundingSphere.center)):(Oe.boundingSphere===null&&Oe.computeBoundingSphere(),Ue.copy(Oe.boundingSphere.center)),Ue.applyMatrix4(N.matrixWorld).applyMatrix4(Ae)),Array.isArray(Pe)){const qe=Oe.groups;for(let et=0,nt=qe.length;et<nt;et++){const Ye=qe[et],Tt=Pe[Ye.materialIndex];Tt&&Tt.visible&&E.push(N,Oe,Tt,ee,Ue.z,Ye)}}else Pe.visible&&E.push(N,Oe,Pe,ee,Ue.z,null)}}const Re=N.children;for(let Oe=0,Pe=Re.length;Oe<Pe;Oe++)ao(Re[Oe],W,ee,ne)}function Nr(N,W,ee,ne){const X=N.opaque,Re=N.transmissive,Oe=N.transparent;_.setupLightsView(ee),K===!0&&Ce.setGlobalState(A.clippingPlanes,ee),ne&&tt.viewport(T.copy(ne)),X.length>0&&er(X,W,ee),Re.length>0&&er(Re,W,ee),Oe.length>0&&er(Oe,W,ee),tt.buffers.depth.setTest(!0),tt.buffers.depth.setMask(!0),tt.buffers.color.setMask(!0),tt.setPolygonOffset(!1)}function hs(N,W,ee,ne){if((ee.isScene===!0?ee.overrideMaterial:null)!==null)return;_.state.transmissionRenderTarget[ne.id]===void 0&&(_.state.transmissionRenderTarget[ne.id]=new qs(1,1,{generateMipmaps:!0,type:ht.has("EXT_color_buffer_half_float")||ht.has("EXT_color_buffer_float")?ul:wr,minFilter:zs,samples:4,stencilBuffer:c,resolveDepthBuffer:!1,resolveStencilBuffer:!1,colorSpace:Ct.workingColorSpace}));const Re=_.state.transmissionRenderTarget[ne.id],Oe=ne.viewport||T;Re.setSize(Oe.z,Oe.w);const Pe=A.getRenderTarget();A.setRenderTarget(Re),A.getClearColor(J),ae=A.getClearAlpha(),ae<1&&A.setClearColor(16777215,.5),A.clear(),yt&&at.render(ee);const qe=A.toneMapping;A.toneMapping=os;const et=ne.viewport;if(ne.viewport!==void 0&&(ne.viewport=void 0),_.setupLightsView(ne),K===!0&&Ce.setGlobalState(A.clippingPlanes,ne),er(N,ee,ne),I.updateMultisampleRenderTarget(Re),I.updateRenderTargetMipmap(Re),ht.has("WEBGL_multisampled_render_to_texture")===!1){let nt=!1;for(let Ye=0,Tt=W.length;Ye<Tt;Ye++){const Dt=W[Ye],It=Dt.object,Vt=Dt.geometry,Mt=Dt.material,Ve=Dt.group;if(Mt.side===Yi&&It.layers.test(ne.layers)){const rn=Mt.side;Mt.side=qn,Mt.needsUpdate=!0,Qs(It,ee,ne,Vt,Mt,Ve),Mt.side=rn,Mt.needsUpdate=!0,nt=!0}}nt===!0&&(I.updateMultisampleRenderTarget(Re),I.updateRenderTargetMipmap(Re))}A.setRenderTarget(Pe),A.setClearColor(J,ae),et!==void 0&&(ne.viewport=et),A.toneMapping=qe}function er(N,W,ee){const ne=W.isScene===!0?W.overrideMaterial:null;for(let X=0,Re=N.length;X<Re;X++){const Oe=N[X],Pe=Oe.object,qe=Oe.geometry,et=ne===null?Oe.material:ne,nt=Oe.group;Pe.layers.test(ee.layers)&&Qs(Pe,W,ee,qe,et,nt)}}function Qs(N,W,ee,ne,X,Re){N.onBeforeRender(A,W,ee,ne,X,Re),N.modelViewMatrix.multiplyMatrices(ee.matrixWorldInverse,N.matrixWorld),N.normalMatrix.getNormalMatrix(N.modelViewMatrix),X.onBeforeRender(A,W,ee,ne,N,Re),X.transparent===!0&&X.side===Yi&&X.forceSinglePass===!1?(X.side=qn,X.needsUpdate=!0,A.renderBufferDirect(ee,W,ne,X,N,Re),X.side=us,X.needsUpdate=!0,A.renderBufferDirect(ee,W,ne,X,N,Re),X.side=Yi):A.renderBufferDirect(ee,W,ne,X,N,Re),N.onAfterRender(A,W,ee,ne,X,Re)}function Js(N,W,ee){W.isScene!==!0&&(W=st);const ne=it.get(N),X=_.state.lights,Re=_.state.shadowsArray,Oe=X.state.version,Pe=Ze.getParameters(N,X.state,Re,W,ee),qe=Ze.getProgramCacheKey(Pe);let et=ne.programs;ne.environment=N.isMeshStandardMaterial?W.environment:null,ne.fog=W.fog,ne.envMap=(N.isMeshStandardMaterial?Q:C).get(N.envMap||ne.environment),ne.envMapRotation=ne.environment!==null&&N.envMap===null?W.environmentRotation:N.envMapRotation,et===void 0&&(N.addEventListener("dispose",gt),et=new Map,ne.programs=et);let nt=et.get(qe);if(nt!==void 0){if(ne.currentProgram===nt&&ne.lightsStateVersion===Oe)return vl(N,Pe),nt}else Pe.uniforms=Ze.getUniforms(N),N.onBeforeCompile(Pe,A),nt=Ze.acquireProgram(Pe,qe),et.set(qe,nt),ne.uniforms=Pe.uniforms;const Ye=ne.uniforms;return(!N.isShaderMaterial&&!N.isRawShaderMaterial||N.clipping===!0)&&(Ye.clippingPlanes=Ce.uniform),vl(N,Pe),ne.needsLights=yl(N),ne.lightsStateVersion=Oe,ne.needsLights&&(Ye.ambientLightColor.value=X.state.ambient,Ye.lightProbe.value=X.state.probe,Ye.directionalLights.value=X.state.directional,Ye.directionalLightShadows.value=X.state.directionalShadow,Ye.spotLights.value=X.state.spot,Ye.spotLightShadows.value=X.state.spotShadow,Ye.rectAreaLights.value=X.state.rectArea,Ye.ltc_1.value=X.state.rectAreaLTC1,Ye.ltc_2.value=X.state.rectAreaLTC2,Ye.pointLights.value=X.state.point,Ye.pointLightShadows.value=X.state.pointShadow,Ye.hemisphereLights.value=X.state.hemi,Ye.directionalShadowMap.value=X.state.directionalShadowMap,Ye.directionalShadowMatrix.value=X.state.directionalShadowMatrix,Ye.spotShadowMap.value=X.state.spotShadowMap,Ye.spotLightMatrix.value=X.state.spotLightMatrix,Ye.spotLightMap.value=X.state.spotLightMap,Ye.pointShadowMap.value=X.state.pointShadowMap,Ye.pointShadowMatrix.value=X.state.pointShadowMatrix),ne.currentProgram=nt,ne.uniformsList=null,nt}function _l(N){if(N.uniformsList===null){const W=N.currentProgram.getUniforms();N.uniformsList=su.seqWithValue(W.seq,N.uniforms)}return N.uniformsList}function vl(N,W){const ee=it.get(N);ee.outputColorSpace=W.outputColorSpace,ee.batching=W.batching,ee.batchingColor=W.batchingColor,ee.instancing=W.instancing,ee.instancingColor=W.instancingColor,ee.instancingMorph=W.instancingMorph,ee.skinning=W.skinning,ee.morphTargets=W.morphTargets,ee.morphNormals=W.morphNormals,ee.morphColors=W.morphColors,ee.morphTargetsCount=W.morphTargetsCount,ee.numClippingPlanes=W.numClippingPlanes,ee.numIntersection=W.numClipIntersection,ee.vertexAlphas=W.vertexAlphas,ee.vertexTangents=W.vertexTangents,ee.toneMapping=W.toneMapping}function tr(N,W,ee,ne,X){W.isScene!==!0&&(W=st),I.resetTextureUnits();const Re=W.fog,Oe=ne.isMeshStandardMaterial?W.environment:null,Pe=U===null?A.outputColorSpace:U.isXRRenderTarget===!0?U.texture.colorSpace:fs,qe=(ne.isMeshStandardMaterial?Q:C).get(ne.envMap||Oe),et=ne.vertexColors===!0&&!!ee.attributes.color&&ee.attributes.color.itemSize===4,nt=!!ee.attributes.tangent&&(!!ne.normalMap||ne.anisotropy>0),Ye=!!ee.morphAttributes.position,Tt=!!ee.morphAttributes.normal,Dt=!!ee.morphAttributes.color;let It=os;ne.toneMapped&&(U===null||U.isXRRenderTarget===!0)&&(It=A.toneMapping);const Vt=ee.morphAttributes.position||ee.morphAttributes.normal||ee.morphAttributes.color,Mt=Vt!==void 0?Vt.length:0,Ve=it.get(ne),rn=_.state.lights;if(K===!0&&(he===!0||N!==te)){const wn=N===te&&ne.id===$;Ce.setState(ne,N,wn)}let Et=!1;ne.version===Ve.__version?(Ve.needsLights&&Ve.lightsStateVersion!==rn.state.version||Ve.outputColorSpace!==Pe||X.isBatchedMesh&&Ve.batching===!1||!X.isBatchedMesh&&Ve.batching===!0||X.isBatchedMesh&&Ve.batchingColor===!0&&X.colorTexture===null||X.isBatchedMesh&&Ve.batchingColor===!1&&X.colorTexture!==null||X.isInstancedMesh&&Ve.instancing===!1||!X.isInstancedMesh&&Ve.instancing===!0||X.isSkinnedMesh&&Ve.skinning===!1||!X.isSkinnedMesh&&Ve.skinning===!0||X.isInstancedMesh&&Ve.instancingColor===!0&&X.instanceColor===null||X.isInstancedMesh&&Ve.instancingColor===!1&&X.instanceColor!==null||X.isInstancedMesh&&Ve.instancingMorph===!0&&X.morphTexture===null||X.isInstancedMesh&&Ve.instancingMorph===!1&&X.morphTexture!==null||Ve.envMap!==qe||ne.fog===!0&&Ve.fog!==Re||Ve.numClippingPlanes!==void 0&&(Ve.numClippingPlanes!==Ce.numPlanes||Ve.numIntersection!==Ce.numIntersection)||Ve.vertexAlphas!==et||Ve.vertexTangents!==nt||Ve.morphTargets!==Ye||Ve.morphNormals!==Tt||Ve.morphColors!==Dt||Ve.toneMapping!==It||Ve.morphTargetsCount!==Mt)&&(Et=!0):(Et=!0,Ve.__version=ne.version);let Qn=Ve.currentProgram;Et===!0&&(Qn=Js(ne,W,X));let wi=!1,fn=!1,nr=!1;const Ut=Qn.getUniforms(),Bi=Ve.uniforms;if(tt.useProgram(Qn.program)&&(wi=!0,fn=!0,nr=!0),ne.id!==$&&($=ne.id,fn=!0),wi||te!==N){_t.reverseDepthBuffer?(Te.copy(N.projectionMatrix),$T(Te),XT(Te),Ut.setValue(B,"projectionMatrix",Te)):Ut.setValue(B,"projectionMatrix",N.projectionMatrix),Ut.setValue(B,"viewMatrix",N.matrixWorldInverse);const wn=Ut.map.cameraPosition;wn!==void 0&&wn.setValue(B,Ie.setFromMatrixPosition(N.matrixWorld)),_t.logarithmicDepthBuffer&&Ut.setValue(B,"logDepthBufFC",2/(Math.log(N.far+1)/Math.LN2)),(ne.isMeshPhongMaterial||ne.isMeshToonMaterial||ne.isMeshLambertMaterial||ne.isMeshBasicMaterial||ne.isMeshStandardMaterial||ne.isShaderMaterial)&&Ut.setValue(B,"isOrthographic",N.isOrthographicCamera===!0),te!==N&&(te=N,fn=!0,nr=!0)}if(X.isSkinnedMesh){Ut.setOptional(B,X,"bindMatrix"),Ut.setOptional(B,X,"bindMatrixInverse");const wn=X.skeleton;wn&&(wn.boneTexture===null&&wn.computeBoneTexture(),Ut.setValue(B,"boneTexture",wn.boneTexture,I))}X.isBatchedMesh&&(Ut.setOptional(B,X,"batchingTexture"),Ut.setValue(B,"batchingTexture",X._matricesTexture,I),Ut.setOptional(B,X,"batchingIdTexture"),Ut.setValue(B,"batchingIdTexture",X._indirectTexture,I),Ut.setOptional(B,X,"batchingColorTexture"),X._colorsTexture!==null&&Ut.setValue(B,"batchingColorTexture",X._colorsTexture,I));const oo=ee.morphAttributes;if((oo.position!==void 0||oo.normal!==void 0||oo.color!==void 0)&&rt.update(X,ee,Qn),(fn||Ve.receiveShadow!==X.receiveShadow)&&(Ve.receiveShadow=X.receiveShadow,Ut.setValue(B,"receiveShadow",X.receiveShadow)),ne.isMeshGouraudMaterial&&ne.envMap!==null&&(Bi.envMap.value=qe,Bi.flipEnvMap.value=qe.isCubeTexture&&qe.isRenderTargetTexture===!1?-1:1),ne.isMeshStandardMaterial&&ne.envMap===null&&W.environment!==null&&(Bi.envMapIntensity.value=W.environmentIntensity),fn&&(Ut.setValue(B,"toneMappingExposure",A.toneMappingExposure),Ve.needsLights&&xl(Bi,nr),Re&&ne.fog===!0&&Le.refreshFogUniforms(Bi,Re),Le.refreshMaterialUniforms(Bi,ne,de,V,_.state.transmissionRenderTarget[N.id]),su.upload(B,_l(Ve),Bi,I)),ne.isShaderMaterial&&ne.uniformsNeedUpdate===!0&&(su.upload(B,_l(Ve),Bi,I),ne.uniformsNeedUpdate=!1),ne.isSpriteMaterial&&Ut.setValue(B,"center",X.center),Ut.setValue(B,"modelViewMatrix",X.modelViewMatrix),Ut.setValue(B,"normalMatrix",X.normalMatrix),Ut.setValue(B,"modelMatrix",X.matrixWorld),ne.isShaderMaterial||ne.isRawShaderMaterial){const wn=ne.uniformsGroups;for(let ea=0,lo=wn.length;ea<lo;ea++){const Rr=wn[ea];G.update(Rr,Qn),G.bind(Rr,Qn)}}return Qn}function xl(N,W){N.ambientLightColor.needsUpdate=W,N.lightProbe.needsUpdate=W,N.directionalLights.needsUpdate=W,N.directionalLightShadows.needsUpdate=W,N.pointLights.needsUpdate=W,N.pointLightShadows.needsUpdate=W,N.spotLights.needsUpdate=W,N.spotLightShadows.needsUpdate=W,N.rectAreaLights.needsUpdate=W,N.hemisphereLights.needsUpdate=W}function yl(N){return N.isMeshLambertMaterial||N.isMeshToonMaterial||N.isMeshPhongMaterial||N.isMeshStandardMaterial||N.isShadowMaterial||N.isShaderMaterial&&N.lights===!0}this.getActiveCubeFace=function(){return L},this.getActiveMipmapLevel=function(){return D},this.getRenderTarget=function(){return U},this.setRenderTargetTextures=function(N,W,ee){it.get(N.texture).__webglTexture=W,it.get(N.depthTexture).__webglTexture=ee;const ne=it.get(N);ne.__hasExternalTextures=!0,ne.__autoAllocateDepthBuffer=ee===void 0,ne.__autoAllocateDepthBuffer||ht.has("WEBGL_multisampled_render_to_texture")===!0&&(console.warn("THREE.WebGLRenderer: Render-to-texture extension was disabled because an external texture was provided"),ne.__useRenderToTexture=!1)},this.setRenderTargetFramebuffer=function(N,W){const ee=it.get(N);ee.__webglFramebuffer=W,ee.__useDefaultFramebuffer=W===void 0},this.setRenderTarget=function(N,W=0,ee=0){U=N,L=W,D=ee;let ne=!0,X=null,Re=!1,Oe=!1;if(N){const qe=it.get(N);if(qe.__useDefaultFramebuffer!==void 0)tt.bindFramebuffer(B.FRAMEBUFFER,null),ne=!1;else if(qe.__webglFramebuffer===void 0)I.setupRenderTarget(N);else if(qe.__hasExternalTextures)I.rebindTextures(N,it.get(N.texture).__webglTexture,it.get(N.depthTexture).__webglTexture);else if(N.depthBuffer){const Ye=N.depthTexture;if(qe.__boundDepthTexture!==Ye){if(Ye!==null&&it.has(Ye)&&(N.width!==Ye.image.width||N.height!==Ye.image.height))throw new Error("WebGLRenderTarget: Attached DepthTexture is initialized to the incorrect size.");I.setupDepthRenderbuffer(N)}}const et=N.texture;(et.isData3DTexture||et.isDataArrayTexture||et.isCompressedArrayTexture)&&(Oe=!0);const nt=it.get(N).__webglFramebuffer;N.isWebGLCubeRenderTarget?(Array.isArray(nt[W])?X=nt[W][ee]:X=nt[W],Re=!0):N.samples>0&&I.useMultisampledRTT(N)===!1?X=it.get(N).__webglMultisampledFramebuffer:Array.isArray(nt)?X=nt[ee]:X=nt,T.copy(N.viewport),P.copy(N.scissor),se=N.scissorTest}else T.copy(oe).multiplyScalar(de).floor(),P.copy(O).multiplyScalar(de).floor(),se=le;if(tt.bindFramebuffer(B.FRAMEBUFFER,X)&&ne&&tt.drawBuffers(N,X),tt.viewport(T),tt.scissor(P),tt.setScissorTest(se),Re){const qe=it.get(N.texture);B.framebufferTexture2D(B.FRAMEBUFFER,B.COLOR_ATTACHMENT0,B.TEXTURE_CUBE_MAP_POSITIVE_X+W,qe.__webglTexture,ee)}else if(Oe){const qe=it.get(N.texture),et=W||0;B.framebufferTextureLayer(B.FRAMEBUFFER,B.COLOR_ATTACHMENT0,qe.__webglTexture,ee||0,et)}$=-1},this.readRenderTargetPixels=function(N,W,ee,ne,X,Re,Oe){if(!(N&&N.isWebGLRenderTarget)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let Pe=it.get(N).__webglFramebuffer;if(N.isWebGLCubeRenderTarget&&Oe!==void 0&&(Pe=Pe[Oe]),Pe){tt.bindFramebuffer(B.FRAMEBUFFER,Pe);try{const qe=N.texture,et=qe.format,nt=qe.type;if(!_t.textureFormatReadable(et)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(!_t.textureTypeReadable(nt)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}W>=0&&W<=N.width-ne&&ee>=0&&ee<=N.height-X&&B.readPixels(W,ee,ne,X,lt.convert(et),lt.convert(nt),Re)}finally{const qe=U!==null?it.get(U).__webglFramebuffer:null;tt.bindFramebuffer(B.FRAMEBUFFER,qe)}}},this.readRenderTargetPixelsAsync=async function(N,W,ee,ne,X,Re,Oe){if(!(N&&N.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let Pe=it.get(N).__webglFramebuffer;if(N.isWebGLCubeRenderTarget&&Oe!==void 0&&(Pe=Pe[Oe]),Pe){const qe=N.texture,et=qe.format,nt=qe.type;if(!_t.textureFormatReadable(et))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(!_t.textureTypeReadable(nt))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");if(W>=0&&W<=N.width-ne&&ee>=0&&ee<=N.height-X){tt.bindFramebuffer(B.FRAMEBUFFER,Pe);const Ye=B.createBuffer();B.bindBuffer(B.PIXEL_PACK_BUFFER,Ye),B.bufferData(B.PIXEL_PACK_BUFFER,Re.byteLength,B.STREAM_READ),B.readPixels(W,ee,ne,X,lt.convert(et),lt.convert(nt),0);const Tt=U!==null?it.get(U).__webglFramebuffer:null;tt.bindFramebuffer(B.FRAMEBUFFER,Tt);const Dt=B.fenceSync(B.SYNC_GPU_COMMANDS_COMPLETE,0);return B.flush(),await WT(B,Dt,4),B.bindBuffer(B.PIXEL_PACK_BUFFER,Ye),B.getBufferSubData(B.PIXEL_PACK_BUFFER,0,Re),B.deleteBuffer(Ye),B.deleteSync(Dt),Re}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")}},this.copyFramebufferToTexture=function(N,W=null,ee=0){N.isTexture!==!0&&(ru("WebGLRenderer: copyFramebufferToTexture function signature has changed."),W=arguments[0]||null,N=arguments[1]);const ne=Math.pow(2,-ee),X=Math.floor(N.image.width*ne),Re=Math.floor(N.image.height*ne),Oe=W!==null?W.x:0,Pe=W!==null?W.y:0;I.setTexture2D(N,0),B.copyTexSubImage2D(B.TEXTURE_2D,ee,0,0,Oe,Pe,X,Re),tt.unbindTexture()},this.copyTextureToTexture=function(N,W,ee=null,ne=null,X=0){N.isTexture!==!0&&(ru("WebGLRenderer: copyTextureToTexture function signature has changed."),ne=arguments[0]||null,N=arguments[1],W=arguments[2],X=arguments[3]||0,ee=null);let Re,Oe,Pe,qe,et,nt;ee!==null?(Re=ee.max.x-ee.min.x,Oe=ee.max.y-ee.min.y,Pe=ee.min.x,qe=ee.min.y):(Re=N.image.width,Oe=N.image.height,Pe=0,qe=0),ne!==null?(et=ne.x,nt=ne.y):(et=0,nt=0);const Ye=lt.convert(W.format),Tt=lt.convert(W.type);I.setTexture2D(W,0),B.pixelStorei(B.UNPACK_FLIP_Y_WEBGL,W.flipY),B.pixelStorei(B.UNPACK_PREMULTIPLY_ALPHA_WEBGL,W.premultiplyAlpha),B.pixelStorei(B.UNPACK_ALIGNMENT,W.unpackAlignment);const Dt=B.getParameter(B.UNPACK_ROW_LENGTH),It=B.getParameter(B.UNPACK_IMAGE_HEIGHT),Vt=B.getParameter(B.UNPACK_SKIP_PIXELS),Mt=B.getParameter(B.UNPACK_SKIP_ROWS),Ve=B.getParameter(B.UNPACK_SKIP_IMAGES),rn=N.isCompressedTexture?N.mipmaps[X]:N.image;B.pixelStorei(B.UNPACK_ROW_LENGTH,rn.width),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,rn.height),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Pe),B.pixelStorei(B.UNPACK_SKIP_ROWS,qe),N.isDataTexture?B.texSubImage2D(B.TEXTURE_2D,X,et,nt,Re,Oe,Ye,Tt,rn.data):N.isCompressedTexture?B.compressedTexSubImage2D(B.TEXTURE_2D,X,et,nt,rn.width,rn.height,Ye,rn.data):B.texSubImage2D(B.TEXTURE_2D,X,et,nt,Re,Oe,Ye,Tt,rn),B.pixelStorei(B.UNPACK_ROW_LENGTH,Dt),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,It),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Vt),B.pixelStorei(B.UNPACK_SKIP_ROWS,Mt),B.pixelStorei(B.UNPACK_SKIP_IMAGES,Ve),X===0&&W.generateMipmaps&&B.generateMipmap(B.TEXTURE_2D),tt.unbindTexture()},this.copyTextureToTexture3D=function(N,W,ee=null,ne=null,X=0){N.isTexture!==!0&&(ru("WebGLRenderer: copyTextureToTexture3D function signature has changed."),ee=arguments[0]||null,ne=arguments[1]||null,N=arguments[2],W=arguments[3],X=arguments[4]||0);let Re,Oe,Pe,qe,et,nt,Ye,Tt,Dt;const It=N.isCompressedTexture?N.mipmaps[X]:N.image;ee!==null?(Re=ee.max.x-ee.min.x,Oe=ee.max.y-ee.min.y,Pe=ee.max.z-ee.min.z,qe=ee.min.x,et=ee.min.y,nt=ee.min.z):(Re=It.width,Oe=It.height,Pe=It.depth,qe=0,et=0,nt=0),ne!==null?(Ye=ne.x,Tt=ne.y,Dt=ne.z):(Ye=0,Tt=0,Dt=0);const Vt=lt.convert(W.format),Mt=lt.convert(W.type);let Ve;if(W.isData3DTexture)I.setTexture3D(W,0),Ve=B.TEXTURE_3D;else if(W.isDataArrayTexture||W.isCompressedArrayTexture)I.setTexture2DArray(W,0),Ve=B.TEXTURE_2D_ARRAY;else{console.warn("THREE.WebGLRenderer.copyTextureToTexture3D: only supports THREE.DataTexture3D and THREE.DataTexture2DArray.");return}B.pixelStorei(B.UNPACK_FLIP_Y_WEBGL,W.flipY),B.pixelStorei(B.UNPACK_PREMULTIPLY_ALPHA_WEBGL,W.premultiplyAlpha),B.pixelStorei(B.UNPACK_ALIGNMENT,W.unpackAlignment);const rn=B.getParameter(B.UNPACK_ROW_LENGTH),Et=B.getParameter(B.UNPACK_IMAGE_HEIGHT),Qn=B.getParameter(B.UNPACK_SKIP_PIXELS),wi=B.getParameter(B.UNPACK_SKIP_ROWS),fn=B.getParameter(B.UNPACK_SKIP_IMAGES);B.pixelStorei(B.UNPACK_ROW_LENGTH,It.width),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,It.height),B.pixelStorei(B.UNPACK_SKIP_PIXELS,qe),B.pixelStorei(B.UNPACK_SKIP_ROWS,et),B.pixelStorei(B.UNPACK_SKIP_IMAGES,nt),N.isDataTexture||N.isData3DTexture?B.texSubImage3D(Ve,X,Ye,Tt,Dt,Re,Oe,Pe,Vt,Mt,It.data):W.isCompressedArrayTexture?B.compressedTexSubImage3D(Ve,X,Ye,Tt,Dt,Re,Oe,Pe,Vt,It.data):B.texSubImage3D(Ve,X,Ye,Tt,Dt,Re,Oe,Pe,Vt,Mt,It),B.pixelStorei(B.UNPACK_ROW_LENGTH,rn),B.pixelStorei(B.UNPACK_IMAGE_HEIGHT,Et),B.pixelStorei(B.UNPACK_SKIP_PIXELS,Qn),B.pixelStorei(B.UNPACK_SKIP_ROWS,wi),B.pixelStorei(B.UNPACK_SKIP_IMAGES,fn),X===0&&W.generateMipmaps&&B.generateMipmap(Ve),tt.unbindTexture()},this.initRenderTarget=function(N){it.get(N).__webglFramebuffer===void 0&&I.setupRenderTarget(N)},this.initTexture=function(N){N.isCubeTexture?I.setTextureCube(N,0):N.isData3DTexture?I.setTexture3D(N,0):N.isDataArrayTexture||N.isCompressedArrayTexture?I.setTexture2DArray(N,0):I.setTexture2D(N,0),tt.unbindTexture()},this.resetState=function(){L=0,D=0,U=null,tt.reset(),At.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return yr}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(e){this._outputColorSpace=e;const t=this.getContext();t.drawingBufferColorSpace=e===jp?"display-p3":"srgb",t.unpackColorSpace=Ct.workingColorSpace===Fu?"display-p3":"srgb"}}class Z_ extends oi{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Tr,this.environmentIntensity=1,this.environmentRotation=new Tr,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(e,t){return super.copy(e,t),e.background!==null&&(this.background=e.background.clone()),e.environment!==null&&(this.environment=e.environment.clone()),e.fog!==null&&(this.fog=e.fog.clone()),this.backgroundBlurriness=e.backgroundBlurriness,this.backgroundIntensity=e.backgroundIntensity,this.backgroundRotation.copy(e.backgroundRotation),this.environmentIntensity=e.environmentIntensity,this.environmentRotation.copy(e.environmentRotation),e.overrideMaterial!==null&&(this.overrideMaterial=e.overrideMaterial.clone()),this.matrixAutoUpdate=e.matrixAutoUpdate,this}toJSON(e){const t=super.toJSON(e);return this.fog!==null&&(t.object.fog=this.fog.toJSON()),this.backgroundBlurriness>0&&(t.object.backgroundBlurriness=this.backgroundBlurriness),this.backgroundIntensity!==1&&(t.object.backgroundIntensity=this.backgroundIntensity),t.object.backgroundRotation=this.backgroundRotation.toArray(),this.environmentIntensity!==1&&(t.object.environmentIntensity=this.environmentIntensity),t.object.environmentRotation=this.environmentRotation.toArray(),t}}class xu extends Ar{constructor(e=1,t=32,r=0,a=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:e,segments:t,thetaStart:r,thetaLength:a},t=Math.max(3,t);const c=[],u=[],d=[],h=[],p=new re,g=new bt;u.push(0,0,0),d.push(0,0,1),h.push(.5,.5);for(let y=0,v=3;y<=t;y++,v+=3){const x=r+y/t*a;p.x=e*Math.cos(x),p.y=e*Math.sin(x),u.push(p.x,p.y,p.z),d.push(0,0,1),g.x=(u[v]/e+1)/2,g.y=(u[v+1]/e+1)/2,h.push(g.x,g.y)}for(let y=1;y<=t;y++)c.push(y,y+1,0);this.setIndex(c),this.setAttribute("position",new li(u,3)),this.setAttribute("normal",new li(d,3)),this.setAttribute("uv",new li(h,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new xu(e.radius,e.segments,e.thetaStart,e.thetaLength)}}class yu extends Ar{constructor(e=.5,t=1,r=32,a=1,c=0,u=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:e,outerRadius:t,thetaSegments:r,phiSegments:a,thetaStart:c,thetaLength:u},r=Math.max(3,r),a=Math.max(1,a);const d=[],h=[],p=[],g=[];let y=e;const v=(t-e)/a,x=new re,w=new bt;for(let E=0;E<=a;E++){for(let _=0;_<=r;_++){const M=c+_/r*u;x.x=y*Math.cos(M),x.y=y*Math.sin(M),h.push(x.x,x.y,x.z),p.push(0,0,1),w.x=(x.x/t+1)/2,w.y=(x.y/t+1)/2,g.push(w.x,w.y)}y+=v}for(let E=0;E<a;E++){const _=E*(r+1);for(let M=0;M<r;M++){const k=M+_,A=k,R=k+r+1,L=k+r+2,D=k+1;d.push(A,R,D),d.push(R,L,D)}}this.setIndex(d),this.setAttribute("position",new li(h,3)),this.setAttribute("normal",new li(p,3)),this.setAttribute("uv",new li(g,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new yu(e.innerRadius,e.outerRadius,e.thetaSegments,e.phiSegments,e.thetaStart,e.thetaLength)}}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:Lp}}));typeof window<"u"&&(window.__THREE__?console.warn("WARNING: Multiple instances of Three.js being imported."):window.__THREE__=Lp);const ls={linear:n=>n,easeInOutCubic:n=>n<.5?4*n*n*n:(n-1)*(2*n-2)*(2*n-2)+1,easeOutExpo:n=>n===1?1:1-Math.pow(2,-10*n),easeOutBack:n=>1+2.70158*Math.pow(n-1,3)+1.70158*Math.pow(n-1,2)},gl=(n,e,t)=>Math.max(e,Math.min(t,n)),tl=(n,e,t)=>n+(e-n)*t,nl=(n,e,t)=>gl((n-e)/Math.max(t-e,1e-6),0,1),Nt={enter:(n,e,t)=>ls.easeOutExpo(nl(n,e,t)),draw:(n,e,t)=>ls.easeInOutCubic(nl(n,e,t)),pop:(n,e,t)=>ls.easeOutBack(nl(n,e,t))};function s3(n,e,t=ls.linear){return r=>{if(r<=n[0])return e[0];if(r>=n[n.length-1])return e[e.length-1];for(let a=0;a<n.length-1;a++){const c=n[a],u=n[a+1];if(r>=c&&r<=u){const d=u===c?0:(r-c)/(u-c),h=Array.isArray(t)?t[a]??ls.linear:t;return e[a]+(e[a+1]-e[a])*h(d)}}return e[e.length-1]}}const Ui=n=>{const e=Math.sin(n*127.1+311.7)*43758.5453;return e-Math.floor(e)},$n=(n,e,t)=>n>=e&&n<e+t?1-(n-e)/t:0,zu=(n,e,t,r=40)=>n.slice(0,Math.max(0,Math.floor((e-t)*r)));function lp(n){let e=String(n||"#ff3340").replace("#","");e.length===3&&(e=e.split("").map(r=>r+r).join(""));const t=parseInt(e,16);return[t>>16&255,t>>8&255,t&255]}const Ys=(n,e)=>{const[t,r,a]=lp(n);return`rgba(${t},${r},${a},${e})`},Fs=1920,_r=1080,au=Math.PI*2,Xc=(n,e,t)=>Array.from({length:n},(r,a)=>[t+a*au/n-e/2,e]),cp=[{r:1,w:.03,arcs:[[0,au]],c:0,spin:.12},{r:.86,w:.08,arcs:Xc(4,.95,Math.PI/4),c:1,spin:-.22},{r:.7,w:.028,arcs:Xc(3,1.75,0),c:0,spin:.36},{r:.55,w:.09,arcs:Xc(2,1.25,Math.PI/2),c:1,spin:-.3},{r:.4,w:.026,arcs:[[0,au]],c:0,spin:.55},{r:.26,w:.105,arcs:Xc(2,2.1,0),c:1,spin:-.48},{r:0,w:.075,arcs:[[0,au]],c:0,spin:0}],a3="varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }",o3=`
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
}`;class l3{renderer;colA=new Rt("#2ee6e0");colB=new Rt("#ff3fb8");vA=new re;vB=new re;palKey="";bgScene=new Z_;bgCam=new Sx(-1,1,1,-1,0,1);bgU;scene=new Z_;cam=new xi(30,Fs/_r,1,2e4);matA;matB;glowA;glowB;emblem=new Bs;rings;disposables=[];constructor(e){const t=this.renderer=new r3({canvas:e,antialias:!0,alpha:!1,powerPreference:"high-performance"});t.setPixelRatio(1),t.setSize(Fs,_r,!1),t.autoClear=!1,this.bgU={uTime:{value:0},uStatic:{value:1},uGlitch:{value:0},uGlowR:{value:.3},uGlowI:{value:0},uRes:{value:new bt(Fs,_r)},uGlow:{value:new bt(.5,.5)},uColA:{value:this.vA},uColB:{value:this.vB}};const r=new ml(2,2),a=new br({uniforms:this.bgU,vertexShader:a3,fragmentShader:o3,depthTest:!1,depthWrite:!1});this.bgScene.add(new ji(r,a)),this.disposables.push(r,a),this.cam.position.z=_r/2/Math.tan(Math.PI/12),this.cam.lookAt(0,0,0);const c=u=>{const d=new Bp({color:u.clone(),transparent:!0,opacity:0,blending:yh,depthWrite:!1,side:Yi});return this.disposables.push(d),d};this.matA=c(this.colA),this.matB=c(this.colB),this.glowA=c(this.colA),this.glowB=c(this.colB),this.scene.add(this.emblem),this.rings=cp.map((u,d)=>{const h=new Bs;this.emblem.add(h);const p=u.c?this.matB:this.matA,g=u.c?this.glowB:this.glowA,y=u.arcs.map(([v,x],w)=>{const E=new Bs,_=(k,A)=>{this.disposables.push(k),E.add(new ji(k,A))};u.r===0?(_(new xu(u.w,48),p),_(new xu(u.w*2.2,48),g)):(_(new yu(u.r-u.w/2,u.r+u.w/2,96,1,v,x),p),_(new yu(u.r-u.w*1.9,u.r+u.w*1.9,96,1,v-.03,x+.06),g));const M=v+x/2;return E.userData={dx:u.r===0?0:Math.cos(M),dy:u.r===0?0:Math.sin(M),h:Ui(d*7+w*3+1)},h.add(E),E});return{rg:h,arcs:y}})}setPalette(e,t){const r=e+"|"+t;if(r===this.palKey)return;this.palKey=r;const a=lp(e),c=lp(t);this.vA.set(a[0]/255,a[1]/255,a[2]/255),this.vB.set(c[0]/255,c[1]/255,c[2]/255),this.colA.set(e),this.colB.set(t)}draw(e,t){this.setPalette(t[0],t[1]);const r=e.emb,a=this.bgU;a.uTime.value=e.W,a.uStatic.value=e.stat,a.uGlitch.value=e.glitch,a.uGlow.value.set(r.pos[0]/Fs,1-r.pos[1]/_r),a.uGlowR.value=r.pos[2]/_r*1.7,a.uGlowI.value=r.alpha*(.6+.8*r.pulse);const c=this.emblem;c.position.set(r.pos[0]-Fs/2,_r/2-r.pos[1],0),c.scale.setScalar(Math.max(.001,r.pos[2]*(1+.16*r.pulse)));const u=r.assemble.reduce((p,g)=>p+g,0)/r.assemble.length;c.rotation.x=r.tilt*.28*Math.sin(e.W*.37)+(1-u)*1.1,c.rotation.y=r.tilt*.42*Math.sin(e.W*.29),this.rings.forEach((p,g)=>{p.rg.rotation.z=cp[g].spin*r.spinT;const y=r.assemble[g]??1,v=Math.max(1-y,r.explode);for(const x of p.arcs){const w=x.userData;x.position.set(w.dx*v*1.3,w.dy*v*1.3,v*2.2*(w.h-.5)),x.rotation.x=(1-y)*2.2*(w.h>.5?1:-1)}});const d=1+1.3*r.pulse;this.matA.opacity=r.alpha,this.matB.opacity=r.alpha,this.glowA.opacity=r.alpha*.2*d,this.glowB.opacity=r.alpha*.18*d,this.matA.color.copy(this.colA).multiplyScalar(d),this.matB.color.copy(this.colB).multiplyScalar(d),this.glowA.color.copy(this.colA),this.glowB.color.copy(this.colB);const h=this.renderer;h.clear(),h.render(this.bgScene,this.bgCam),h.clearDepth(),h.render(this.scene,this.cam)}dispose(){for(const e of this.disposables)try{e.dispose()}catch{}try{this.renderer.dispose(),this.renderer.forceContextLoss()}catch{}}}const qc=[{at:0,sound:"install_crton"},{at:.35,sound:"install_emblem"},{at:.45,sound:"install_assemble"},{at:.5,sound:"install_bios"},{at:1,sound:"install_type_a"},{at:1.5,sound:"install_wordmark"},{at:2.2,sound:"install_select"},{at:3,sound:"install_glitch"},{at:3.05,sound:"install_zoom"},{at:3.05,sound:"install_type_c"},{at:3.55,sound:"install_panel"},{at:3.6,sound:"install_dmesg"},{at:4.3,sound:"install_nomodule"},{at:4.9,sound:"install_banner"},{at:5.5,sound:"install_type_b"},{at:6.3,sound:"install_ask"},{at:6.65,sound:"install_press"},{at:7,sound:"install_bed"},{at:7.1,sound:"install_type_c"},{at:8,sound:"install_carrier1"},{at:8.2,sound:"install_carrier2"},{at:8.4,sound:"install_carrier3"},{at:8.65,sound:"install_joined"},{at:8.9,sound:"install_type_a"},{at:9.4,sound:"install_download"},{at:10.35,sound:"install_dldone"},{at:10.47,sound:"install_ok"},{at:11.1,sound:"install_type_b"},{at:11.65,sound:"install_probe"},{at:11.9,sound:"install_grid"},{at:13.6,sound:"install_mapped"},{at:13.8,sound:"install_type_c"},{at:14.3,sound:"install_ok"},{at:14.5,sound:"install_stable"},{at:15.1,sound:"install_type_a"},{at:15.65,sound:"install_trace"},{at:15.75,sound:"install_wave"},{at:16.75,sound:"install_bound"},{at:16.9,sound:"install_bound2"},{at:17.05,sound:"install_chiasm"},{at:17.9,sound:"install_relay"},{at:18.1,sound:"install_reflex"},{at:19.1,sound:"install_type_b"},{at:19.7,sound:"install_erase"},{at:20.05,sound:"install_hex"},{at:21.25,sound:"install_firmware"},{at:22.2,sound:"install_written"},{at:22.32,sound:"install_emitter"},{at:22.52,sound:"install_ok"},{at:23.1,sound:"install_type_c"},{at:23.3,sound:"install_zoom"},{at:23.85,sound:"install_explode"},{at:23.9,sound:"install_hologram"},{at:25.3,sound:"install_implode"},{at:25.3,sound:"install_pass"},{at:26,sound:"install_glitch"},{at:26.5,sound:"install_online"},{at:27.1,sound:"install_tick"},{at:28.1,sound:"install_tick"},{at:28.3,sound:"install_crtoff"}],ct={Post:0,Kernel:3,Network:7,Cortex:11,Nerve:15,Flash:19,Verify:23,Done:26},Ax=ct.Kernel+3.3,Q_=ct.Kernel+3.6,Vp=ct.Kernel+3.65,oh=ct.Flash,J_=ct.Done-.001,c3=ct.Done+3,ai='"IBM Plex Mono", "Share Tech Mono", ui-monospace, monospace',u3='"Chakra Petch", "IBM Plex Mono", sans-serif',d3='"Noto Sans JP", "Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", sans-serif',yi="#dfe9ee",on="rgba(223,233,238,0.5)",Ja="rgba(223,233,238,0.22)",Su="#05060a",Wt="#2ee6e0",Pn="#ff3fb8",f3=[Wt,Pn],lh={enter:ls.easeOutExpo,draw:ls.easeInOutCubic,pop:ls.easeOutBack},Cx=n=>String(n).padStart(2,"0"),h3=22e3,p3=[960,440,230],m3=[1808,64,30],g3=[698,556,270],_3=[960,400,190];function v3(n){const{T:e,W:t}=n,{Post:r,Kernel:a,Network:c,Cortex:u,Nerve:d,Flash:h,Verify:p,Done:g}=ct;let y=.8*$n(e,a,.35)+.3*($n(e,c,.2)+$n(e,u,.2)+$n(e,d,.2)+$n(e,h,.2))+$n(e,p+.85,.4)+.7*$n(e,p+2.3,.3)+$n(e,g,.4);y=gl(y+n.idle+(n.fault?$n(t,n.fault.at,.5):0),0,1.5);const v=Nt.draw(e,a-.1,a+.7),x=Nt.draw(e,p+.3,p+.9),w=Nt.draw(e,g,g+.6);let E=p3.map((U,$)=>tl(U,m3[$],v));E=E.map((U,$)=>tl(U,g3[$],x)),E=E.map((U,$)=>tl(U,_3[$],w));const _=cp.map((U,$)=>Nt.draw(e,r+.35+$*.1,r+1.3+$*.1)),M=Math.max(0,s3([p+.9,p+1.25,p+1.9,p+2.3],[0,.5,.5,0],[lh.enter,lh.draw,lh.pop])(e));let k=0,A=0;for(const U of[a,c,u,d,h,p,g])k+=$n(e,U,.5),A+=Nt.draw(e,U,U+.9);k+=.8*$n(e,p+2.3,.5)+(n.fault?$n(t,n.fault.at,.6):0);const R=t+1.4*A+7*Nt.draw(e,p+.85,p+2.4),L=(1-.65*v)*(1-x)+x*.9*(1-.5*w),D=Nt.enter(e,r+.2,r+.6);return{T:e,W:t,glitch:y,stat:1-Nt.draw(e,r+.1,r+1.1),emb:{pos:E,assemble:_,explode:M,pulse:k,spinT:R,tilt:L,alpha:D}}}function x3({params:n}){const e=q.useRef(null),t=q.useRef(null);return q.useEffect(()=>{const r=document.createElement("canvas");r.width=Fs,r.height=_r,r.style.cssText=`position:absolute;left:0;top:0;width:${Fs}px;height:${_r}px`;try{t.current=new l3(r),e.current?.appendChild(r)}catch(a){console.warn("[neuralink] installation: WebGL unavailable, terminal only",a)}return()=>{t.current?.dispose(),t.current=null,r.remove()}},[]),q.useEffect(()=>{t.current?.draw(n,f3)}),l.jsx("div",{ref:e,style:{position:"absolute",inset:0,background:Su,pointerEvents:"none"}})}const y3=[" _  _  ___  _    ___     ___  ___ ","| || |/ _ \\| |  / _ \\   / _ \\/ __|","| __ | (_) | |_| (_) | | (_) \\__ \\","|_||_|\\___/|___|\\___/   \\___/|___/"];function S3(n){const{Kernel:e,Network:t,Cortex:r,Nerve:a,Flash:c,Verify:u,Done:d}=ct,h=[];let p=0;const g=(_,M)=>{h.push({t:p,kind:"cmd",text:_,dur:M}),p+=M+.05},y=(_,M,k)=>{h.push({t:p,kind:"out",text:_,...k}),p+=M??.1},v=(_,M,k)=>y(_,M??.14,{tag:k||"OK"}),x=(_,M,k)=>{h.push({t:p,kind:"bar",to:M,label:_,right:k}),p=M+.12},w=()=>y("",.02),E=n.model;return p=e+.05,g("boot holo-os-4.3.0.img --target=/dev/ocular0",.5),[["0.000000","HOLO-OS 4.3.0 (build nc-09) #1 SMP PREEMPT"],["0.000412","npu: Kiroshi NPU-7 @ 2.4 THz, 4096 phase cells"],["0.001207","mem: 2048 PB neural lattice, ECC enabled"],["0.004881",`ocular0: ${E} at cortical port C7`],["0.004902",`ocular1: ${E} at cortical port C8`],["0.009340","bus: optic nerve bridge online (2.4 TB/s)"],["0.012003","crypto: QEC-4096 engine ready"],["0.018754","holo: no Neural-Link module on ocular0 -- installer required","b"],["0.020110","init: switching to installer shell"]].forEach(([_,M,k])=>y(`[    ${_}] ${M}`,.1,{color:k,stamp:!0})),p=e+1.9,w(),y3.forEach(_=>y(_,.05,{color:"a"})),y("HOLO-OS INSTALLER 4.3.0  ·  8 stages  ·  target /dev/ocular0",.1,{color:"dim"}),w(),p=e+2.5,g("holo-install neuralink.core --target=/dev/ocular0",.6),y("module  neuralink.core 2.0  ·  38.2 MB  ·  signed kiroshi",.1,{color:"dim"}),p=Ax,n.selfInstall?(h.push({t:p,kind:"ask",text:"install the Neural-Link on /dev/ocular0? [Y/n] "}),p=Vp+.08,v("installation confirmed  ·  do not move your eyes",.1)):(y("holo-install: self-install locked on this model",.12,{color:"b",tag:"LOCK"}),y("visit a ripperdoc to have the Neural-Link installed",.1,{color:"a"})),p=t+.1,g("netlink up --carrier=kiroshi-net",.5),y("scanning carriers",.35,{color:"dim"}),y("  nc-09.watson.grid       -41 dBm    QEC-4096",.2,{color:"a"}),y("  nc-12.westbrook.grid    -67 dBm    QEC-4096",.2),y("  nc-03.corpo.net         -83 dBm    open",.25,{color:"dim"}),v("joined nc-09.watson.grid    lease 7F:3A:91:C4",.25),g("fetch pkg://kiroshi/neuralink.core-2.0.pak",.45),x("neuralink.core-2.0.pak",t+3.35,"38.2 MB    2.4 TB/s"),v("sha3-512  9f3a:b2c1:77e0 ... verified",.15),v("package staged in /var/holo/stage"),p=r+.1,g("cortex map --region=V1 --cells=4096",.5),v("probing occipital bus",.25),h.push({t:p,kind:"grid",to:r+2.5}),p=r+2.6,v("4096/4096 phase cells mapped    delta 0.003",.2),g("cortex link --bus=occipital",.45),v("synaptic interface calibrated",.2),v("cortical link stable    2.4 TB/s"),p=a+.1,g("nerve bind --optic L,R --relay T1",.5),y("tracing optic nerve L -> chiasm -> V1 (right)",.1,{color:"dim"}),h.push({t:p,kind:"wave",to:a+1.7}),p=a+1.75,v("optic nerve L bound",.15),v("optic nerve R bound",.15),v("chiasm crossover",.25),y("syncing spinal relay T1",.6,{color:"dim"}),v("spinal relay T1    12 ms",.2),y("reflex gate armed:  blink x2 = accept    look away = decline",.1,{color:"a"}),p=c+.1,g("flash --module neuralink.core-2.0.pak --port C7",.55),y("erasing sectors 0x3F2A-0x4B6A",.35,{color:"b"}),h.push({t:p,kind:"hex",to:c+2.2,rate:9,max:10}),p=c+2.25,x("firmware 4.2.1 -> 4.3.0",c+3.2,"sector 0x4B6A"),v("emitter warm-up 31°C -> 44°C",.2),v("holocall.service enabled"),p=u+.1,g("selftest --all",.45),y("projecting emitter test pattern ...",.1,{color:"dim"}),p=u+2.3,v("emitter test pattern",.12,"PASS"),v("link latency 12 ms",.12,"PASS"),v("encryption QEC-4096",.12,"PASS"),y("7/7 checks passed",.1,{color:"a"}),p=d+.02,g("clear",.25),h.push({t:p,kind:"clear"}),h}const M3=n=>n.kind==="cmd"?n.t+n.dur:"to"in n?n.to:n.t;function up(){return l.jsxs("span",{children:[l.jsx("span",{style:{color:Pn},children:"root@kiroshi"}),l.jsx("span",{style:{color:on},children:":~"}),l.jsx("span",{style:{color:Wt},children:"# "})]})}function ou({W:n}){return l.jsx("span",{style:{display:"inline-block",width:11,height:20,background:Wt,verticalAlign:-3,opacity:Math.floor(n*2.5)%2===0?1:.15,boxShadow:`0 0 10px ${Ys(Wt,.7)}`}})}const _i=27,ev=31;function ch({text:n,color:e,stamp:t,tag:r}){const a=e==="a"?Wt:e==="b"?Pn:e==="dim"?on:yi,c=r==="OK"||r==="PASS"?Wt:Pn;return l.jsxs("div",{style:{height:_i,whiteSpace:"pre",display:"flex",color:a},children:[l.jsx("span",{style:{color:t?on:"inherit"},children:t?n.slice(0,15):""}),l.jsxs("span",{style:{width:r?700:"auto"},children:[r?"  ":"",t?n.slice(15):n]}),r?l.jsxs("span",{style:{color:on},children:["[ ",l.jsx("span",{style:{color:c,textShadow:`0 0 10px ${Ys(c,.6)}`},children:r.padStart(4," ")})," ]"]}):null]})}function E3({v:n,log:e,ctx:t,choices:r}){const{T:a,W:c}=n,u=[];let d=-1;for(const g of e){if(g.t>a)break;d=Math.max(d,M3(g));const y=g.kind+g.t;if(g.kind==="clear"){u.length=0;continue}if(g.kind==="cmd"){const v=a<g.t+g.dur;u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre"},children:[l.jsx(up,{}),zu(g.text,a,g.t,g.text.length/g.dur),v?l.jsx(ou,{W:c}):null]},y)})}else if(g.kind==="out")u.push({u:1,el:l.jsx(ch,{...g},y)});else if(g.kind==="ask"){const v=n.confirmed&&a>=Vp;u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:yi},children:[l.jsx("span",{style:{color:Wt},children:"? "}),g.text,v?l.jsx("span",{style:{color:Wt},children:"y"}):l.jsx(ou,{W:c})]},y)})}else if(g.kind==="bar"){const v=Nt.draw(a,g.t,g.to),x=Math.round(v*40),w=v>=1;u.push({u:1,el:l.jsxs("div",{style:{height:_i,display:"flex",alignItems:"center",gap:14,whiteSpace:"pre"},children:[l.jsxs("span",{style:{color:on},children:["  ",g.label.padEnd(26," ")]}),l.jsx("span",{style:{color:on},children:"["}),l.jsx("span",{style:{display:"flex",gap:2},children:Array.from({length:40},(E,_)=>l.jsx("span",{style:{width:9,height:14,background:_<x?w?yi:Wt:Ja,boxShadow:_<x&&!w?`0 0 6px ${Ys(Wt,.5)}`:"none"}},_))}),l.jsx("span",{style:{color:on},children:"]"}),l.jsxs("span",{style:{color:yi,width:54,textAlign:"right"},children:[Math.round(v*100),"%"]}),l.jsx("span",{style:{color:on},children:g.right})]},y)})}else if(g.kind==="grid"){const v=Math.floor(Nt.draw(a,g.t,g.to)*384);u.push({u:4,el:l.jsx("div",{style:{height:_i*4,display:"grid",gridTemplateColumns:"repeat(64, 14px)",gridAutoRows:"14px",gap:3,alignContent:"center",paddingLeft:26},children:Array.from({length:384},(x,w)=>l.jsx("div",{style:{background:w<v?Ui(w)>.9?Pn:Wt:"rgba(223,233,238,0.07)",opacity:w<v?.55+.45*Ui(w+5):1}},w))},y)})}else if(g.kind==="wave"){const v=a<g.to?1:.2,x=a<g.to?a:c;u.push({u:2,el:l.jsx("div",{style:{height:_i*2,display:"flex",alignItems:"center",gap:4,paddingLeft:26},children:Array.from({length:110},(w,E)=>{const _=3+40*v*Math.abs(Math.sin(E*.33-x*9))*(.4+.6*Ui(E));return l.jsx("div",{style:{width:6,height:_,background:E%7===0?Pn:Wt,opacity:.5+.5*Ui(E+9)}},E)})},y)})}else if(g.kind==="hex"){const v=Math.min(g.max,Math.floor((a-g.t)*g.rate)+1);for(let x=0;x<v;x++){const w=Array.from({length:12},(M,k)=>Math.floor(Ui(x*31+k*7+2)*256)),E=w.map(M=>M.toString(16).padStart(2,"0")).join(" "),_=w.map(M=>M>32&&M<127?String.fromCharCode(M):".").join("");u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:on},children:["  ",l.jsxs("span",{style:{color:Pn},children:["0x",(16170+x*16).toString(16).toUpperCase()]}),"   ",E,"   ",l.jsxs("span",{style:{color:Ja},children:["|",_,"|"]})]},y+x)})}}}if(n.holding){const g="|/-\\"[Math.floor(c*10)%4];u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre",color:on},children:["  registering line ",l.jsx("span",{style:{color:yi},children:t.number})," on nc-09.watson.grid  ",l.jsx("span",{style:{color:Wt},children:g})]},"hold")})}n.fault&&(u.push({u:1,el:l.jsx(ch,{text:`flash: ${Fn(n.fault.slug).toLowerCase()}`,color:"b",tag:"FAIL"},"fault")}),u.push({u:1,el:l.jsx(ch,{text:"module rolled back  ·  nothing was written to ocular0",color:"dim"},"fault2")})),r?u.push({u:2,el:l.jsx("div",{className:"holo-choice",style:{height:_i*2},children:r.map(g=>l.jsxs("button",{type:"button",className:`holo-key${g.primary?" holo-key--primary":""}`,onClick:g.act,children:[l.jsx("span",{className:"holo-key__cap",children:g.key}),l.jsx("span",{children:g.label})]},g.key))},"choice")}):a>d+.08&&!n.holding&&!n.fault&&u.push({u:1,el:l.jsxs("div",{style:{height:_i,whiteSpace:"pre"},children:[l.jsx(up,{}),l.jsx(ou,{W:c})]},"prompt")});let h=0,p=u.length;for(;p>0&&h+u[p-1].u<=ev;)h+=u[p-1].u,p--;return l.jsx("div",{style:{position:"absolute",left:64,top:128,width:1268,height:ev*_i,overflow:"hidden",fontFamily:ai,fontSize:19,lineHeight:_i+"px",color:yi,display:"flex",flexDirection:"column",justifyContent:"flex-end"},children:u.slice(p).map(g=>g.el)})}const Nx=["POST","KERNEL","NETWORK","CORTEX","NERVE","FLASH","SELFTEST","DONE"],Mu=[ct.Post,ct.Kernel,ct.Network,ct.Cortex,ct.Nerve,ct.Flash,ct.Verify,ct.Done],Rx=n=>{let e=0;for(let t=0;t<Mu.length;t++)n>=Mu[t]&&(e=t);return e};function uh({title:n,top:e,height:t,children:r}){return l.jsxs("div",{style:{position:"absolute",left:1372,top:e,width:484,height:t,boxSizing:"border-box",border:`1px solid ${Ja}`,padding:"22px 22px 16px"},children:[l.jsx("div",{style:{position:"absolute",left:14,top:-10,padding:"0 8px",background:Su,fontFamily:ai,fontSize:14,letterSpacing:"0.24em",color:Wt},children:n}),r]})}function Yc({label:n,u:e,value:t,warn:r}){const a=Math.round(gl(e,0,1)*24);return l.jsxs("div",{style:{display:"flex",alignItems:"center",height:30,fontFamily:ai,fontSize:15,whiteSpace:"pre"},children:[l.jsx("span",{style:{color:on,width:120},children:n}),l.jsx("span",{style:{display:"flex",gap:2,width:190},children:Array.from({length:24},(c,u)=>l.jsx("span",{style:{width:6,height:12,background:u<a?r?Pn:Wt:Ja}},u))}),l.jsx("span",{style:{color:yi,flex:1,textAlign:"right"},children:t})]})}function w3({v:n,ctx:e}){const{T:t,W:r}=n,a=Rx(t),c=Nt.enter(t,ct.Kernel+.5,ct.Kernel+1)*(1-Nt.draw(t,ct.Done+.3,ct.Done+.7)),u=t>ct.Kernel+1.2?.7+.25*Ui(Math.floor(r*5)):0,d=t>ct.Network+.4?.82*Nt.draw(t,ct.Network+.4,ct.Network+1.2):0,h=tl(31,44,nl(t,ct.Flash+2.3,ct.Flash+3.4)),p=Math.round(4096*Nt.draw(t,ct.Cortex+.9,ct.Cortex+2.5)),g=Math.floor(r*3)%2===0,y=t>=ct.Flash+3.2;return l.jsxs("div",{style:{position:"absolute",inset:0,opacity:c,transform:`translateX(${(1-c)*30}px)`,pointerEvents:"none"},children:[l.jsx(uh,{title:"STAGES",top:128,height:356,children:Nx.map((v,x)=>{const w=x<a,E=x===a,_=E&&!!n.fault;return l.jsxs("div",{style:{display:"flex",alignItems:"center",height:38,fontFamily:ai,fontSize:17,whiteSpace:"pre",color:w?yi:_?Pn:E?Wt:on},children:[l.jsx("span",{style:{color:on,width:44},children:Cx(x+1)}),l.jsx("span",{style:{width:150,textShadow:E?`0 0 12px ${Ys(_?Pn:Wt,.6)}`:"none"},children:v}),l.jsx("span",{style:{flex:1,textAlign:"right",color:w||E?_?Pn:Wt:Ja,opacity:E&&!g?.4:1},children:w?"[ OK ]":_?"[FAIL]":E?"[ >> ]":"[ -- ]"})]},v)})}),l.jsxs(uh,{title:"SYSTEM",top:516,height:204,children:[l.jsx(Yc,{label:"NEURAL BUS",u,value:u?"2.4 TB/s":"idle"}),l.jsx(Yc,{label:"UPLINK",u:d,value:d?"-41 dBm":"no carrier"}),l.jsx(Yc,{label:"EMITTER",u:(h-20)/30,value:`${Math.round(h)}°C`,warn:h<40&&t>ct.Flash+2.3}),l.jsx(Yc,{label:"V1 CELLS",u:p/4096,value:`${p} / 4096`})]}),l.jsx(uh,{title:"TARGET",top:752,height:226,children:[["DEVICE","/dev/ocular0"],["PORT","cortical C7"],["MODEL",e.model],["FIRMWARE",y?"4.3.0":"4.2.1"],["LINE",e.number]].map(([v,x])=>l.jsxs("div",{style:{display:"flex",height:32,alignItems:"center",fontFamily:ai,fontSize:15,whiteSpace:"pre"},children:[l.jsx("span",{style:{color:on,width:120},children:v}),l.jsx("span",{style:{color:v==="FIRMWARE"&&y?Wt:yi,overflow:"hidden",textOverflow:"ellipsis"},children:x})]},v))})]})}function T3({T:n}){const e=Nt.enter(n,ct.Kernel+.3,ct.Kernel+.8)*(1-Nt.draw(n,ct.Done+.3,ct.Done+.7)),t=n>=ct.Kernel?`UP 00:${Cx(Math.floor(n-ct.Kernel))}`:"UP --:--";return l.jsxs("div",{style:{position:"absolute",left:64,right:64,top:48,height:36,display:"flex",alignItems:"center",justifyContent:"space-between",fontFamily:ai,fontSize:15,letterSpacing:"0.16em",color:on,opacity:e,borderBottom:`1px solid ${Ja}`,whiteSpace:"pre"},children:[l.jsxs("span",{children:[l.jsx("span",{style:{color:yi},children:"KIROSHI OPTICS"}),"  //  HOLO-OS INSTALLER 4.3.0"]}),l.jsxs("span",{children:["tty1  ·  /dev/ocular0  ·  ",t]}),l.jsx("span",{style:{width:160}})]})}function b3({v:n}){const{T:e}=n,t=Rx(e),r=Nt.enter(e,ct.Kernel+.6,ct.Kernel+1)*(1-Nt.draw(e,ct.Done+.3,ct.Done+.7)),a=t<7?Mu[t+1]:ct.Done+2,c=(t+nl(e,Mu[t],a))/8,u=Math.round(c*30),d=n.fault?Pn:Wt;return l.jsxs("div",{style:{position:"absolute",left:64,right:64,top:1004,height:34,background:Ys(d,.88),color:Su,display:"flex",alignItems:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.1em",fontWeight:500,opacity:r,whiteSpace:"pre"},children:[l.jsx("span",{style:{padding:"0 18px",background:n.fault?Wt:Pn,color:"#1a0410",height:"100%",display:"flex",alignItems:"center"},children:"HOLO-OS"}),l.jsxs("span",{style:{padding:"0 18px"},children:["STAGE ",t+1,"/8  ",Nx[t],n.fault?"  ·  FAILED":n.waiting?"  ·  AWAITING INPUT":n.holding?"  ·  REGISTERING":""]}),l.jsx("span",{style:{display:"flex",gap:2,padding:"0 10px"},children:Array.from({length:30},(h,p)=>l.jsx("span",{style:{width:8,height:12,background:p<u?Su:"rgba(5,6,10,0.25)"}},p))}),l.jsxs("span",{style:{padding:"0 14px"},children:[Math.round(c*100),"%"]}),l.jsx("span",{style:{flex:1}}),l.jsx("span",{style:{padding:"0 18px"},children:e>ct.Network+1.6?"nc-09.watson.grid":"no carrier"}),l.jsx("span",{style:{padding:"0 18px"},children:"QEC-4096"})]})}function Px({T:n,at:e,size:t,top:r}){const a=Nt.enter(n,e,e+.5);return l.jsxs("div",{style:{position:"absolute",left:0,right:0,top:r,textAlign:"center",opacity:a,transform:`translateY(${(1-a)*14}px)`},children:[l.jsx("div",{style:{fontFamily:u3,fontWeight:700,fontSize:t,letterSpacing:"0.34em",textIndent:"0.34em",lineHeight:1,color:Pn,textShadow:`0 0 24px ${Ys(Pn,.55)}, 0 0 2px ${Pn}`,minHeight:t},children:zu("KIROSHI",n,e,18)}),l.jsx("div",{style:{fontFamily:d3,fontWeight:500,fontSize:t*.42,letterSpacing:"0.2em",textIndent:"0.2em",color:Wt,marginTop:t*.22,textShadow:`0 0 16px ${Ys(Wt,.5)}`,opacity:Nt.enter(n,e+.5,e+.9)},children:"キロシ・オプティクス"})]})}function A3({T:n,W:e}){const t=ct.Post,r=ct.Kernel,a=1-Nt.draw(n,r-.05,r+.35),c=[["KIROSHI OPTICS BIOS 4.2.1",t+.5],["POST ................ OK",t+1],["MEM 2048 PB .......... OK",t+1.4],["OCULAR0 MK.IV ........ OK",t+1.75],["BOOT holo-os-4.3.0.img",t+2.2]];return l.jsxs("div",{style:{position:"absolute",inset:0,opacity:a,pointerEvents:"none"},children:[l.jsx(Px,{T:n,at:t+1.5,size:76,top:740}),l.jsx("div",{style:{position:"absolute",left:64,top:880,fontFamily:ai,fontSize:16,lineHeight:"26px",color:on,whiteSpace:"pre"},children:c.map(([u,d])=>l.jsx("div",{style:{color:u.endsWith("OK")&&n>d+u.length/50?yi:on},children:zu(u,n,d,50)},u))}),l.jsx("div",{style:{position:"absolute",right:64,top:1e3,fontFamily:ai,fontSize:14,letterSpacing:"0.2em",color:on,opacity:n>t+1.2&&Math.floor(e*1.5)%2===0?1:.3},children:"BLINK x2 TO ENTER SETUP"})]})}function C3({T:n,W:e,ctx:t}){const r=ct.Done,a=Nt.enter(n,r+.5,r+1),c=gl(3-Math.floor(n-(r+1.1)),1,3);return l.jsxs("div",{style:{position:"absolute",inset:0,pointerEvents:"none"},children:[l.jsx(Px,{T:n,at:r+.5,size:64,top:650}),l.jsx("div",{style:{position:"absolute",left:0,right:0,top:800,textAlign:"center",fontFamily:ai,fontSize:18,letterSpacing:"0.3em",textIndent:"0.3em",color:yi,opacity:a,whiteSpace:"pre"},children:zu("HOLO-OS 4.3.0  ·  NEURAL-LINK INSTALLED",n,r+.9,60)}),l.jsx("div",{style:{position:"absolute",left:0,right:0,top:838,textAlign:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.2em",color:Wt,opacity:Nt.enter(n,r+1.3,r+1.6),whiteSpace:"pre"},children:`${t.name.toUpperCase()}  ·  LINE ${t.number}`}),l.jsxs("div",{style:{position:"absolute",left:0,right:0,top:874,textAlign:"center",fontFamily:ai,fontSize:15,letterSpacing:"0.2em",color:on,opacity:Nt.enter(n,r+1.5,r+1.8)},children:["rebooting ocular suite in ",c]}),l.jsxs("div",{style:{position:"absolute",left:64,top:1e3,fontFamily:ai,fontSize:19,whiteSpace:"pre",opacity:a},children:[l.jsx(up,{}),l.jsx(ou,{W:e})]})]})}function N3({W:n,g:e,children:t}){const r=Math.floor(n*30),a=e<.03?[]:[0,1,2].map(c=>({y:Ui(r+c*7)*92,h:3+Ui(r+c*13)*9,dx:(Ui(r+c*3)-.5)*70*e}));return l.jsxs("div",{style:{position:"absolute",inset:0},children:[l.jsx("div",{style:{position:"absolute",inset:0,transform:e<.03?void 0:`translateX(${(Ui(r)-.5)*10*e}px)`},children:t}),a.map((c,u)=>l.jsx("div",{"aria-hidden":!0,inert:"",style:{position:"absolute",inset:0,pointerEvents:"none",clipPath:`inset(${c.y}% 0 ${Math.max(0,100-c.y-c.h)}% 0)`,transform:`translateX(${c.dx}px)`,filter:u===1?"hue-rotate(120deg) saturate(2)":"none"},children:t},u))]})}function R3({selfInstall:n,autoStart:e}){const t=fe(V=>V.state?.implant),r=fe(V=>V.state?.line),a={selfInstall:n,model:t?.model||"Kiroshi NL-77 Synapse",name:r?.name||"Unknown citizen",number:r?.number??"---"},c=q.useMemo(()=>S3(a),[a.selfInstall,a.model]),[,u]=q.useReducer(V=>V+1,0),d=q.useRef({T:0,W:0,holding:!1,idle:0,fault:null,waiting:!1,confirmed:!1}),h=q.useRef({asked:!1,reply:null,cue:0,idleAt:-10,nextIdle:9,lastIdleSound:-99,done:!1,alive:!0}),p=q.useRef(e&&n),g=()=>{const V=d.current;V.confirmed||!n||V.T<Ax||(V.confirmed=!0,be().setImplantFlow(!0),V.T=Math.max(V.T,Vp),V.waiting=!1)},y=()=>{const V=h.current,de=d.current;de.fault&&(de.fault=null,de.holding=!1,de.T=oh,V.asked=!1,V.reply=null,V.cue=qc.findIndex(z=>z.at>=oh))},v=()=>{const V=h.current;V.asked=!0;let de=0;const z=new Promise((ue,oe)=>{de=window.setTimeout(()=>oe(new Sn("timeout")),h3)});Promise.race([to("implant.install",{}),z]).then(ue=>{V.alive&&(V.reply={implant:ue?.implant&&typeof ue.implant=="object"?ue.implant:null})},ue=>{V.alive&&(d.current.fault={slug:ue instanceof Sn?ue.slug:"unknown",at:d.current.W},Ee("install_fault"))}).finally(()=>window.clearTimeout(de))};q.useEffect(()=>{const V=h.current;V.alive=!0;const de=rs()?1.6:1;let z=performance.now(),ue=0;const oe=O=>{if(!V.alive)return;const le=gl((O-z)/1e3,0,.1);z=O;const we=d.current;if(we.W+=le,!we.fault&&!V.done){let K=we.T+le*de;for(we.confirmed?(!V.asked&&K>=oh&&v(),we.holding=K>=J_&&!V.reply&&!we.fault,we.holding&&(K=J_)):K>=Q_&&(K=Q_,we.waiting=!0,p.current&&(p.current=!1,we.T=K,g(),K=we.T)),we.T=K;V.cue<qc.length&&qc[V.cue].at<=we.T;)Ee(qc[V.cue].sound),V.cue++;if(we.T>=c3){V.done=!0,fe.getState().implantOnline(V.reply?.implant??null);return}}we.waiting&&!we.fault&&we.W>=V.nextIdle&&(V.idleAt=we.W,V.nextIdle=we.W+2.6+Math.random()*4.2,we.W-V.lastIdleSound>9&&Math.random()<.45&&(V.lastIdleSound=we.W,Ee("install_idle"))),we.idle=we.waiting?.9*$n(we.W,V.idleAt,.28):0,u(),ue=requestAnimationFrame(oe)};return ue=requestAnimationFrame(oe),()=>{V.alive=!1,cancelAnimationFrame(ue)}},[]);const x=d.current,w=x.fault?[{key:"R",label:"Retry the installation",primary:!0,act:y},{key:"Q",label:"Close",act:Vs}]:x.waiting?n?[{key:"Y",label:"Install the Neural-Link",primary:!0,act:g},{key:"N",label:"Cancel",act:Vs}]:[{key:"Q",label:"Close",act:Vs}]:null,E=q.useRef(w);E.current=w,q.useEffect(()=>{const V=de=>{const z=E.current;if(!z||de.repeat)return;const ue=de.key.length===1?de.key.toUpperCase():de.key,oe=ue==="Enter"?z[0]:z.find(O=>O.key===ue);oe&&(de.preventDefault(),oe.act())};return window.addEventListener("keydown",V),()=>window.removeEventListener("keydown",V)},[]);const{T:_,W:M}=x,{Post:k,Kernel:A,Verify:R,Done:L}=ct,D=v3(x),U=Nt.enter(_,k,k+.4),$=Nt.draw(_,L+2.35,L+2.7),te=Nt.draw(_,L+2.7,L+2.95),T=tl(.004,1,U)*(1-$*.996),P=1-te,se=1+.9*$n(_,k,.45)+1.6*$*(1-te),J=1-.7*Nt.draw(_,R+.3,R+.9)*(1-Nt.draw(_,R+2.2,R+2.5)),ae=1-Nt.draw(_,L+.3,L+.7),ve=(V,de)=>_>=V&&_<de;return l.jsx("div",{className:"holo-os",role:"dialog","aria-modal":"true","aria-label":"Kiroshi Neural-Link installation",children:l.jsxs("div",{className:"holo-os__screen",style:{transform:`scale(${P}, ${T})`,filter:se!==1?`brightness(${se.toFixed(2)})`:void 0},children:[l.jsx(x3,{params:D}),l.jsxs(N3,{W:M,g:D.glitch,children:[ve(k,A+.5)&&l.jsx(A3,{T:_,W:M}),ve(A-.2,L+.8)&&l.jsxs(l.Fragment,{children:[l.jsx(T3,{T:_}),l.jsx("div",{style:{position:"absolute",inset:0,opacity:J*ae},children:l.jsx(E3,{v:x,log:c,ctx:a,choices:w})}),l.jsx(w3,{v:x,ctx:a}),l.jsx(b3,{v:x})]}),_>=L+.4&&l.jsx(C3,{T:_,W:M,ctx:a})]}),l.jsx("div",{className:"holo-os__scan","aria-hidden":!0}),l.jsx("div",{className:"holo-os__vignette","aria-hidden":!0})]})})}function P3(){const n=fe(t=>t.state?.implant?.selfInstall!==!1),[e]=q.useState(()=>be().implantAutoStart);return q.useEffect(()=>{be().implantAutoStart&&fe.setState({implantAutoStart:!1})},[]),l.jsx("div",{className:"implant",children:l.jsx(R3,{selfInstall:n,autoStart:e})})}const L3=1500,k3=330;let tv=-1;function D3(){const n=fe(d=>d.phase),e=fe(d=>d.openSeq),t=fe(d=>!!d.state?.ready),r=fe(mh),a=eo().style!=="sao",c=q.useRef(null),u=n==="open"||n==="opening";return q.useEffect(()=>{if(n==="opening"){tv!==e&&(tv=e,mh(be())||Ee("open"));const d=window.setTimeout(()=>fe.getState().setPhase("open"),rs()?50:L3);return()=>window.clearTimeout(d)}if(n==="closing"){const d=window.setTimeout(()=>fe.getState().setPhase("closed"),rs()?30:k3);return()=>window.clearTimeout(d)}},[n,e]),q.useEffect(()=>{const d=v=>{document.documentElement.dataset.input="mouse",Yy(v.clientX/window.innerWidth*2-1,v.clientY/window.innerHeight*2-1)},h=v=>{(v.key.startsWith("Arrow")||v.key==="Enter")&&(document.documentElement.dataset.input="kbd")};window.addEventListener("pointermove",d,{passive:!0}),window.addEventListener("keydown",h);let p=0,g=performance.now();const y=v=>{p=requestAnimationFrame(y);const x=c.current;!x||rs()||(Ky(Math.min(.1,Math.max(0,(v-g)/1e3))),g=v,x.style.setProperty("--mx",si.x.toFixed(4)),x.style.setProperty("--my",si.y.toFixed(4)))};return u&&(p=requestAnimationFrame(y)),()=>{window.removeEventListener("pointermove",d),window.removeEventListener("keydown",h),cancelAnimationFrame(p)}},[u]),q.useEffect(()=>{if(!u||!a||rs())return;let d=0,h=0;const p=()=>{const g=Array.from(document.querySelectorAll(".plane .nl3d")),y=g[Math.floor(Math.random()*g.length)];y&&(y.classList.add("is-glitch"),h=window.setTimeout(()=>y.classList.remove("is-glitch"),180+Math.random()*160)),d=window.setTimeout(p,4200+Math.random()*5200)};return d=window.setTimeout(p,3600),()=>{window.clearTimeout(d),window.clearTimeout(h)}},[u,a]),l.jsxs("div",{className:`shell is-${n}`,children:[n==="opening"&&!r&&l.jsx($y,{}),!r&&!a&&l.jsx(qy,{running:u}),!r&&a&&l.jsx(Jy,{running:u}),l.jsx("div",{className:"plane",ref:c,children:t?r?l.jsx(P3,{}):l.jsx(I3,{}):l.jsx(eT,{})}),!r&&a&&t&&l.jsx(nS,{})]},e)}function I3(){const n=fe(g=>g.state),e=fe(g=>g.recentsSeenAt),t=fe(g=>g.menu),r=fe(g=>g.callView),a=fe(g=>!!g.state?.call),c=ku(n,e),u=Rv(n,c,a),d=GE(u.length),h=u.findIndex(g=>g.id==="call"?r:g.id===t),p=h>=0?d.centers[h]:540;return l.jsxs(l.Fragment,{children:[l.jsx(TE,{}),l.jsx(WE,{items:u,layout:d}),t&&!r&&!t.startsWith("app:")&&l.jsx(qE,{anchorY:p,missed:c},t),l.jsx(Qw,{})]})}function dh(){const n=be();if(n.phase==="closed"||n.phase==="closing"||n.callView)return null;const e=_p(n);return e&&e.app==="messages"&&e.screen==="thread"?e.threadId:null}function U3(){const n=be();if(n.phase==="closed"||n.phase==="closing"||n.callView)return null;const e=_p(n);return e&&e.app==="social"?e:null}function F3(n){const e=be(),t=U3();switch(n.kind){case"post":n.post&&!n.post.mine&&e.pushFresh(n.post);break;case"ping":e.setSocialUnread(n.unread),t?.app==="social"&&t.screen==="pings"&&xh();break;case"stats":{const r=e.postLive[n.postId]?.replies??e.screamThreads[n.postId]?.post?.replies??0;e.setPostLive(n.postId,{cred:n.cred,echoes:n.echoes,replies:n.replies}),t?.app==="social"&&t.screen==="thread"&&t.postId===n.postId&&n.replies>r&&Ov(n.postId);break}case"deleted":e.removePost(n.postId);break}}function fh(n,e){if(!e)return;const t=n?n.participants.filter(a=>!a.isMe&&a.state==="connected").length:0,r=e.participants.filter(a=>!a.isMe&&a.state==="connected").length;e.phase==="active"&&(!n||n.phase!=="active"||n.id!==e.id)?Ee("connect"):e.phase==="active"&&n?.phase==="active"&&r>t&&Ee("receive")}function O3(){q.useEffect(()=>{const n=[Gn("nl:state",e=>{if(!e)return;const t=be(),r=t.state?.call;t.applyState(e),be().setCall(e.call??null),fh(r,e.call??null);const a=dh();a!=null&&hu(a)}),Gn("nl:patch",e=>{if(!e)return;const t=be().state?.call;be().applyPatch(e),"call"in e&&(be().setCall(e.call??null),fh(t,e.call??null))}),Gn("nl:open",e=>{be().openUi(e??{}),e?.app==="messages"&&typeof e.threadId=="number"&&!gh(be())&&hu(e.threadId)}),Gn("nl:close",()=>{const e=be();e.phase==="closed"||e.phase==="closing"||(Kg(),Ee("close"),e.closeUi())}),Gn("nl:thread",e=>{e&&typeof e.threadId=="number"&&be().threadLoaded(e)}),Gn("nl:message",e=>{e?.message&&(be().messageArrived(e),!(e.message.mine||e.message.kind==="system")&&dh()===e.message.threadId&&(be().setUnread(e.message.threadId,0),Pt("threads.read",{threadId:e.message.threadId},{quiet:!0}),Ee("receive")))}),Gn("nl:call",e=>{const t=be().state?.call;be().setCall(e??null),fh(t,e??null)}),Gn("nl:callEnded",e=>{e&&(be().setEnded(e),Ee("disconnect"))}),Gn("nl:talkers",e=>be().setTalkers(e??{})),Gn("nl:toast",e=>{if(!e)return;const t=be();gh(t)||e.kind==="message"&&e.threadId!=null&&dh()===e.threadId||(t.pushToast({...e,at:e.at??Date.now()}),gp(t).dnd)||(e.kind==="message"?Ee("chime"):e.kind==="error"?Ee("error"):Ee("toast"))}),Gn("nl:clock",e=>{e&&be().setClock(e)}),Gn("nl:social",e=>{e&&typeof e.kind=="string"&&F3(e)}),Gn("nl:keys",e=>{e&&typeof e.toggle=="string"&&e.toggle&&be().setToggleKey(e.toggle)}),Gn("nl:focus",e=>{const t=!!e?.keyboard;be().setKeyboard(t),t||Kg()})];return Wy(),()=>n.forEach(e=>e())},[])}function j3(){const n=fe(g=>g.state?.call??null),e=fe(g=>g.state?.contacts??Ln),t=fe(g=>g.talkers),r=fe(g=>g.phase!=="closed"&&g.phase!=="closing"&&g.state!==null),a=fe(g=>g.callView),c=qv(n?.startedAt??null);if(!n||n.phase==="incoming"||r&&a)return null;const u=n.participants.find(g=>g.isMe),d=!!u&&!n.muted&&(t[u.lineId]??0)>.05,h=n.participants.some(g=>!g.isMe&&(t[g.lineId]??0)>.05),p=Math.max(0,...Object.values(t));return l.jsxs("button",{type:"button",className:`callhud ${r?"nl-hit":""} ${h||d?"is-talking":""} ${n.muted?"is-muted":""}`,style:{"--level":p.toFixed(2)},onClick:()=>{r&&(Ee("select"),fe.getState().setCallView(!0))},tabIndex:r?0:-1,children:[l.jsx("span",{className:"callhud__glow","aria-hidden":!0}),l.jsx("span",{className:"callhud__icon",children:n.group?l.jsx(kn,{size:16}):l.jsx(Ji,{size:16})}),l.jsx("span",{className:"callhud__name",children:Xv(n,e)}),l.jsx("span",{className:"callhud__time mono",children:n.phase==="outgoing"||!c?"linking…":c}),l.jsx("span",{className:`callhud__mic ${d?"is-live":""}`,children:n.muted?l.jsx(vh,{size:15}):l.jsx(Ev,{size:15})})]})}function z3(){const n=fe(a=>a.ended),e=fe(a=>a.state?.contacts??Ln);if(q.useEffect(()=>{if(!n)return;const a=window.setTimeout(()=>fe.getState().setEnded(null),2500);return()=>window.clearTimeout(a)},[n]),!n)return null;const t=n.number?Fi(e,n.number,n.name):n.name,r=n.reason!=="hangup";return l.jsxs("div",{className:`endcard ${r?"is-bad":""}`,role:"status",children:[l.jsx("span",{className:"endcard__icon",children:l.jsx(Ru,{size:20})}),l.jsxs("span",{className:"endcard__text",children:[l.jsx("span",{className:"endcard__reason label",children:AE(n.reason)}),l.jsxs("span",{className:"endcard__who",children:[t??"Neural call",n.duration?l.jsxs("span",{className:"mono",children:[" · ",pp(n.duration)]}):null]})]}),l.jsx("span",{className:"endcard__bar","aria-hidden":!0})]},n.key)}const nv=5e3,iv={message:l.jsx(Zi,{size:20}),call:l.jsx(ol,{size:20}),missed:l.jsx(Nu,{size:20}),info:l.jsx(yp,{size:20}),error:l.jsx(wp,{size:20}),social:l.jsx($s,{size:20})};function B3(){const n=fe(t=>t.toasts),e=fe(t=>t.phase==="open"||t.phase==="opening");return l.jsx("div",{className:`toasts ${e?"is-open":""}`,"aria-live":"polite",children:n.map((t,r)=>l.jsx(H3,{t,depth:n.length-1-r,clickable:e},t.key))})}function H3({t:n,depth:e,clickable:t}){const[r,a]=q.useState(!1);q.useEffect(()=>{const d=Math.max(400,nv-(Date.now()-n.born)),h=window.setTimeout(()=>a(!0),d),p=window.setTimeout(()=>fe.getState().dismissToast(n.key),d+320);return()=>{window.clearTimeout(h),window.clearTimeout(p)}},[n.key,n.born]);const c=t&&(n.kind==="message"&&n.threadId!=null||(n.kind==="missed"||n.kind==="call")&&!!n.number||n.kind==="social"&&(n.postId!=null||!!n.handle)),u=()=>{t&&(n.kind==="message"&&n.threadId!=null?$a(n.threadId,"reset"):(n.kind==="missed"||n.kind==="call")&&n.number?Er(n.number):n.kind==="social"&&n.postId!=null?cl(n.postId,"reset"):n.kind==="social"&&n.handle?ss(n.handle,"reset"):Ee("back"),fe.getState().dismissToast(n.key))};return l.jsxs("div",{className:`toast toast--${n.kind} ${r?"is-leaving":""} ${t?"nl-hit":""} ${c?"is-actionable":""}`,style:{"--depth":e},onClick:u,role:"status",children:[l.jsx("span",{className:"toast__icon",children:iv[n.kind]??iv.info}),l.jsxs("span",{className:"toast__text",children:[l.jsxs("span",{className:"toast__top",children:[l.jsx("span",{className:"toast__title",children:n.title}),l.jsx("span",{className:"toast__time mono",children:Wa(n.at||Date.now())})]}),l.jsx("span",{className:"toast__body",children:n.body})]}),l.jsx("span",{className:"toast__life",style:{animationDuration:`${nv}ms`},"aria-hidden":!0}),l.jsx("span",{className:"toast__scan","aria-hidden":!0})]})}const V3=q.lazy(()=>dp(()=>import("./chunk-MockPanel.js"),__vite__mapDeps([0,1]),import.meta.url));function G3(){O3(),VE(),zy();const n=fe(r=>r.phase!=="closed"&&r.state!==null),e=fe(gh),t=hv()&&new URLSearchParams(location.search).get("dev")!=="0";return l.jsxs(l.Fragment,{children:[l.jsxs(jy,{children:[n&&l.jsx(D3,{}),!e&&l.jsxs(l.Fragment,{children:[l.jsx(Yw,{}),l.jsx(j3,{}),l.jsx(z3,{}),l.jsx(B3,{})]})]}),t&&l.jsx(q.Suspense,{fallback:null,children:l.jsx(V3,{})})]})}class W3 extends q.Component{state={failed:!1};static getDerivedStateFromError(){return{failed:!0}}componentDidCatch(e,t){console.error("[neuralink] render failed",e,t.componentStack),window.setTimeout(()=>this.setState({failed:!1}),1500)}render(){return this.state.failed?null:this.props.children}}async function $3(){if(!window.Open77){const{installMockBridge:n}=await dp(async()=>{const{installMockBridge:e}=await import("./chunk-mock.js");return{installMockBridge:e}},[],import.meta.url);n()}My.createRoot(document.getElementById("root")).render(l.jsx(q.StrictMode,{children:l.jsx(W3,{children:l.jsx(G3,{})})}))}$3();export{CM as $,lu as A,Ho as B,RS as C,hh as D,WS as E,XS as F,YS as G,rv as H,ZS as I,tM as J,Sv as K,vp as L,sM as M,hp as N,oM as O,cM as P,dM as Q,hM as R,bg as S,mM as T,_M as U,bu as V,yM as W,MM as X,wM as Y,Mv as Z,rl as _,Os as a,gE as a$,xp as a0,PM as a1,yp as a2,DM as a3,jg as a4,OM as a5,Au as a6,$s as a7,Cu as a8,Zi as a9,cs as aA,A2 as aB,Ep as aC,L2 as aD,R2 as aE,D2 as aF,U2 as aG,O2 as aH,z2 as aI,H2 as aJ,Mr as aK,W2 as aL,X2 as aM,uu as aN,wp as aO,Z2 as aP,J2 as aQ,tE as aR,iE as aS,Tp as aT,Qi as aU,no as aV,lE as aW,kn as aX,dE as aY,Cv as aZ,pE as a_,cu as aa,Ev as ab,vh as ac,$M as ad,qM as ae,KM as af,QM as ag,wv as ah,sl as ai,Tv as aj,Ji as ak,ol as al,r2 as am,Nu as an,Ru as ao,l2 as ap,d2 as aq,h2 as ar,m2 as as,_2 as at,Sp as au,Pu as av,bv as aw,Mp as ax,E2 as ay,Av as az,vv as b,vE as b0,ll as b1,bp as b2,_e as c,cS as d,dS as e,xv as f,pS as g,_h as h,gS as i,l as j,xS as k,il as l,MS as m,wS as n,bS as o,CS as p,LS as q,q as r,OS as s,DS as t,fe as u,US as v,yv as w,BS as x,VS as y,JS as z};
