(()=>{var Js=Object.create;var qr=Object.defineProperty;var el=Object.getOwnPropertyDescriptor;var tl=Object.getOwnPropertyNames;var nl=Object.getPrototypeOf,al=Object.prototype.hasOwnProperty;var ht=(a,n)=>()=>(n||a((n={exports:{}}).exports,n),n.exports);var rl=(a,n,e,t)=>{if(n&&typeof n=="object"||typeof n=="function")for(let r of tl(n))!al.call(a,r)&&r!==e&&qr(a,r,{get:()=>n[r],enumerable:!(t=el(n,r))||t.enumerable});return a};var Ve=(a,n,e)=>(e=a!=null?Js(nl(a)):{},rl(n||!a||!a.__esModule?qr(e,"default",{value:a,enumerable:!0}):e,a));var Dt=ht((wf,Ma)=>{"use strict";var At=typeof Reflect=="object"?Reflect:null,Xr=At&&typeof At.apply=="function"?At.apply:function(n,e,t){return Function.prototype.apply.call(n,e,t)},Bn;At&&typeof At.ownKeys=="function"?Bn=At.ownKeys:Object.getOwnPropertySymbols?Bn=function(n){return Object.getOwnPropertyNames(n).concat(Object.getOwnPropertySymbols(n))}:Bn=function(n){return Object.getOwnPropertyNames(n)};function il(a){console&&console.warn&&console.warn(a)}var Yr=Number.isNaN||function(n){return n!==n};function ie(){ie.init.call(this)}Ma.exports=ie;Ma.exports.once=ul;ie.EventEmitter=ie;ie.prototype._events=void 0;ie.prototype._eventsCount=0;ie.prototype._maxListeners=void 0;var jr=10;function Un(a){if(typeof a!="function")throw new TypeError('The "listener" argument must be of type Function. Received type '+typeof a)}Object.defineProperty(ie,"defaultMaxListeners",{enumerable:!0,get:function(){return jr},set:function(a){if(typeof a!="number"||a<0||Yr(a))throw new RangeError('The value of "defaultMaxListeners" is out of range. It must be a non-negative number. Received '+a+".");jr=a}});ie.init=function(){(this._events===void 0||this._events===Object.getPrototypeOf(this)._events)&&(this._events=Object.create(null),this._eventsCount=0),this._maxListeners=this._maxListeners||void 0};ie.prototype.setMaxListeners=function(n){if(typeof n!="number"||n<0||Yr(n))throw new RangeError('The value of "n" is out of range. It must be a non-negative number. Received '+n+".");return this._maxListeners=n,this};function Kr(a){return a._maxListeners===void 0?ie.defaultMaxListeners:a._maxListeners}ie.prototype.getMaxListeners=function(){return Kr(this)};ie.prototype.emit=function(n){for(var e=[],t=1;t<arguments.length;t++)e.push(arguments[t]);var r=n==="error",i=this._events;if(i!==void 0)r=r&&i.error===void 0;else if(!r)return!1;if(r){var o;if(e.length>0&&(o=e[0]),o instanceof Error)throw o;var s=new Error("Unhandled error."+(o?" ("+o.message+")":""));throw s.context=o,s}var l=i[n];if(l===void 0)return!1;if(typeof l=="function")Xr(l,this,e);else for(var u=l.length,d=ti(l,u),t=0;t<u;++t)Xr(d[t],this,e);return!0};function Zr(a,n,e,t){var r,i,o;if(Un(e),i=a._events,i===void 0?(i=a._events=Object.create(null),a._eventsCount=0):(i.newListener!==void 0&&(a.emit("newListener",n,e.listener?e.listener:e),i=a._events),o=i[n]),o===void 0)o=i[n]=e,++a._eventsCount;else if(typeof o=="function"?o=i[n]=t?[e,o]:[o,e]:t?o.unshift(e):o.push(e),r=Kr(a),r>0&&o.length>r&&!o.warned){o.warned=!0;var s=new Error("Possible EventEmitter memory leak detected. "+o.length+" "+String(n)+" listeners added. Use emitter.setMaxListeners() to increase limit");s.name="MaxListenersExceededWarning",s.emitter=a,s.type=n,s.count=o.length,il(s)}return a}ie.prototype.addListener=function(n,e){return Zr(this,n,e,!1)};ie.prototype.on=ie.prototype.addListener;ie.prototype.prependListener=function(n,e){return Zr(this,n,e,!0)};function ol(){if(!this.fired)return this.target.removeListener(this.type,this.wrapFn),this.fired=!0,arguments.length===0?this.listener.call(this.target):this.listener.apply(this.target,arguments)}function Qr(a,n,e){var t={fired:!1,wrapFn:void 0,target:a,type:n,listener:e},r=ol.bind(t);return r.listener=e,t.wrapFn=r,r}ie.prototype.once=function(n,e){return Un(e),this.on(n,Qr(this,n,e)),this};ie.prototype.prependOnceListener=function(n,e){return Un(e),this.prependListener(n,Qr(this,n,e)),this};ie.prototype.removeListener=function(n,e){var t,r,i,o,s;if(Un(e),r=this._events,r===void 0)return this;if(t=r[n],t===void 0)return this;if(t===e||t.listener===e)--this._eventsCount===0?this._events=Object.create(null):(delete r[n],r.removeListener&&this.emit("removeListener",n,t.listener||e));else if(typeof t!="function"){for(i=-1,o=t.length-1;o>=0;o--)if(t[o]===e||t[o].listener===e){s=t[o].listener,i=o;break}if(i<0)return this;i===0?t.shift():sl(t,i),t.length===1&&(r[n]=t[0]),r.removeListener!==void 0&&this.emit("removeListener",n,s||e)}return this};ie.prototype.off=ie.prototype.removeListener;ie.prototype.removeAllListeners=function(n){var e,t,r;if(t=this._events,t===void 0)return this;if(t.removeListener===void 0)return arguments.length===0?(this._events=Object.create(null),this._eventsCount=0):t[n]!==void 0&&(--this._eventsCount===0?this._events=Object.create(null):delete t[n]),this;if(arguments.length===0){var i=Object.keys(t),o;for(r=0;r<i.length;++r)o=i[r],o!=="removeListener"&&this.removeAllListeners(o);return this.removeAllListeners("removeListener"),this._events=Object.create(null),this._eventsCount=0,this}if(e=t[n],typeof e=="function")this.removeListener(n,e);else if(e!==void 0)for(r=e.length-1;r>=0;r--)this.removeListener(n,e[r]);return this};function Jr(a,n,e){var t=a._events;if(t===void 0)return[];var r=t[n];return r===void 0?[]:typeof r=="function"?e?[r.listener||r]:[r]:e?ll(r):ti(r,r.length)}ie.prototype.listeners=function(n){return Jr(this,n,!0)};ie.prototype.rawListeners=function(n){return Jr(this,n,!1)};ie.listenerCount=function(a,n){return typeof a.listenerCount=="function"?a.listenerCount(n):ei.call(a,n)};ie.prototype.listenerCount=ei;function ei(a){var n=this._events;if(n!==void 0){var e=n[a];if(typeof e=="function")return 1;if(e!==void 0)return e.length}return 0}ie.prototype.eventNames=function(){return this._eventsCount>0?Bn(this._events):[]};function ti(a,n){for(var e=new Array(n),t=0;t<n;++t)e[t]=a[t];return e}function sl(a,n){for(;n+1<a.length;n++)a[n]=a[n+1];a.pop()}function ll(a){for(var n=new Array(a.length),e=0;e<n.length;++e)n[e]=a[e].listener||a[e];return n}function ul(a,n){return new Promise(function(e,t){function r(o){a.removeListener(n,i),t(o)}function i(){typeof a.removeListener=="function"&&a.removeListener("error",r),e([].slice.call(arguments))}ni(a,n,i,{once:!0}),n!=="error"&&dl(a,r,{once:!0})})}function dl(a,n,e){typeof a.on=="function"&&ni(a,"error",n,e)}function ni(a,n,e,t){if(typeof a.on=="function")t.once?a.once(n,e):a.on(n,e);else if(typeof a.addEventListener=="function")a.addEventListener(n,function r(i){t.once&&a.removeEventListener(n,r),e(i)});else throw new TypeError('The "emitter" argument must be of type EventEmitter. Received type '+typeof a)}});var sn=ht((Cf,pi)=>{pi.exports=function(n){return n!==null&&typeof n=="object"&&typeof n.addUndirectedEdgeWithKey=="function"&&typeof n.dropNode=="function"&&typeof n.multi=="boolean"}});var bi=ht(Kn=>{function pu(a){return typeof a!="number"||isNaN(a)?1:a}function mu(a,n){var e={},t=function(o){return typeof o>"u"?n:o};typeof n=="function"&&(t=n);var r=function(o){return t(o[a])},i=function(){return t(void 0)};return typeof a=="string"?(e.fromAttributes=r,e.fromGraph=function(o,s){return r(o.getNodeAttributes(s))},e.fromEntry=function(o,s){return r(s)}):typeof a=="function"?(e.fromAttributes=function(){throw new Error("graphology-utils/getters/createNodeValueGetter: irrelevant usage.")},e.fromGraph=function(o,s){return t(a(s,o.getNodeAttributes(s)))},e.fromEntry=function(o,s){return t(a(o,s))}):(e.fromAttributes=i,e.fromGraph=i,e.fromEntry=i),e}function mi(a,n){var e={},t=function(o){return typeof o>"u"?n:o};typeof n=="function"&&(t=n);var r=function(o){return t(o[a])},i=function(){return t(void 0)};return typeof a=="string"?(e.fromAttributes=r,e.fromGraph=function(o,s){return r(o.getEdgeAttributes(s))},e.fromEntry=function(o,s){return r(s)},e.fromPartialEntry=e.fromEntry,e.fromMinimalEntry=e.fromEntry):typeof a=="function"?(e.fromAttributes=function(){throw new Error("graphology-utils/getters/createEdgeValueGetter: irrelevant usage.")},e.fromGraph=function(o,s){var l=o.extremities(s);return t(a(s,o.getEdgeAttributes(s),l[0],l[1],o.getNodeAttributes(l[0]),o.getNodeAttributes(l[1]),o.isUndirected(s)))},e.fromEntry=function(o,s,l,u,d,c,h){return t(a(o,s,l,u,d,c,h))},e.fromPartialEntry=function(o,s,l,u){return t(a(o,s,l,u))},e.fromMinimalEntry=function(o,s){return t(a(o,s))}):(e.fromAttributes=i,e.fromGraph=i,e.fromEntry=i,e.fromMinimalEntry=i),e}Kn.createNodeValueGetter=mu;Kn.createEdgeValueGetter=mi;Kn.createEdgeWeightGetter=function(a){return mi(a,pu)}});var Si=ht((kf,Ti)=>{var fe=0,se=1,ne=2,ae=3,je=4,Ye=5,re=6,yi=7,Zn=8,xi=9,bu=0,yu=1,xu=2,me=0,Le=1,_e=2,ft=3,et=4,ce=5,Se=6,Oe=7,We=8,_i=3,ze=10,_u=3,ye=9,$a=10;Ti.exports=function(n,e,t){var r,i,o,s,l,u,d,c,h,f,g=e.length,m=t.length,p=n.adjustSizes,v=n.barnesHutTheta*n.barnesHutTheta,b,y,_,x,T,R,E,S=[];for(o=0;o<g;o+=ze)e[o+je]=e[o+ne],e[o+Ye]=e[o+ae],e[o+ne]=0,e[o+ae]=0;if(n.outboundAttractionDistribution){for(b=0,o=0;o<g;o+=ze)b+=e[o+re];b/=g/ze}if(n.barnesHutOptimize){var w=1/0,F=-1/0,D=1/0,P=-1/0,L,I,z;for(o=0;o<g;o+=ze)w=Math.min(w,e[o+fe]),F=Math.max(F,e[o+fe]),D=Math.min(D,e[o+se]),P=Math.max(P,e[o+se]);var G=F-w,k=P-D;for(G>k?(D-=(G-k)/2,P=D+G):(w-=(k-G)/2,F=w+k),S[0+me]=-1,S[0+Le]=(w+F)/2,S[0+_e]=(D+P)/2,S[0+ft]=Math.max(F-w,P-D),S[0+et]=-1,S[0+ce]=-1,S[0+Se]=0,S[0+Oe]=0,S[0+We]=0,r=1,o=0;o<g;o+=ze)for(i=0,z=_i;;)if(S[i+ce]>=0){e[o+fe]<S[i+Le]?e[o+se]<S[i+_e]?L=S[i+ce]:L=S[i+ce]+ye:e[o+se]<S[i+_e]?L=S[i+ce]+ye*2:L=S[i+ce]+ye*3,S[i+Oe]=(S[i+Oe]*S[i+Se]+e[o+fe]*e[o+re])/(S[i+Se]+e[o+re]),S[i+We]=(S[i+We]*S[i+Se]+e[o+se]*e[o+re])/(S[i+Se]+e[o+re]),S[i+Se]+=e[o+re],i=L;continue}else if(S[i+me]<0){S[i+me]=o;break}else{if(S[i+ce]=r*ye,c=S[i+ft]/2,h=S[i+ce],S[h+me]=-1,S[h+Le]=S[i+Le]-c,S[h+_e]=S[i+_e]-c,S[h+ft]=c,S[h+et]=h+ye,S[h+ce]=-1,S[h+Se]=0,S[h+Oe]=0,S[h+We]=0,h+=ye,S[h+me]=-1,S[h+Le]=S[i+Le]-c,S[h+_e]=S[i+_e]+c,S[h+ft]=c,S[h+et]=h+ye,S[h+ce]=-1,S[h+Se]=0,S[h+Oe]=0,S[h+We]=0,h+=ye,S[h+me]=-1,S[h+Le]=S[i+Le]+c,S[h+_e]=S[i+_e]-c,S[h+ft]=c,S[h+et]=h+ye,S[h+ce]=-1,S[h+Se]=0,S[h+Oe]=0,S[h+We]=0,h+=ye,S[h+me]=-1,S[h+Le]=S[i+Le]+c,S[h+_e]=S[i+_e]+c,S[h+ft]=c,S[h+et]=S[i+et],S[h+ce]=-1,S[h+Se]=0,S[h+Oe]=0,S[h+We]=0,r+=4,e[S[i+me]+fe]<S[i+Le]?e[S[i+me]+se]<S[i+_e]?L=S[i+ce]:L=S[i+ce]+ye:e[S[i+me]+se]<S[i+_e]?L=S[i+ce]+ye*2:L=S[i+ce]+ye*3,S[i+Se]=e[S[i+me]+re],S[i+Oe]=e[S[i+me]+fe],S[i+We]=e[S[i+me]+se],S[L+me]=S[i+me],S[i+me]=-1,e[o+fe]<S[i+Le]?e[o+se]<S[i+_e]?I=S[i+ce]:I=S[i+ce]+ye:e[o+se]<S[i+_e]?I=S[i+ce]+ye*2:I=S[i+ce]+ye*3,L===I)if(z--){i=L;continue}else{z=_i;break}S[I+me]=o;break}}if(n.barnesHutOptimize)for(y=n.scalingRatio,o=0;o<g;o+=ze)for(i=0;;)if(S[i+ce]>=0)if(R=Math.pow(e[o+fe]-S[i+Oe],2)+Math.pow(e[o+se]-S[i+We],2),f=S[i+ft],4*f*f/R<v){if(_=e[o+fe]-S[i+Oe],x=e[o+se]-S[i+We],p===!0?R>0?(E=y*e[o+re]*S[i+Se]/R,e[o+ne]+=_*E,e[o+ae]+=x*E):R<0&&(E=-y*e[o+re]*S[i+Se]/Math.sqrt(R),e[o+ne]+=_*E,e[o+ae]+=x*E):R>0&&(E=y*e[o+re]*S[i+Se]/R,e[o+ne]+=_*E,e[o+ae]+=x*E),i=S[i+et],i<0)break;continue}else{i=S[i+ce];continue}else{if(u=S[i+me],u>=0&&u!==o&&(_=e[o+fe]-e[u+fe],x=e[o+se]-e[u+se],R=_*_+x*x,p===!0?R>0?(E=y*e[o+re]*e[u+re]/R,e[o+ne]+=_*E,e[o+ae]+=x*E):R<0&&(E=-y*e[o+re]*e[u+re]/Math.sqrt(R),e[o+ne]+=_*E,e[o+ae]+=x*E):R>0&&(E=y*e[o+re]*e[u+re]/R,e[o+ne]+=_*E,e[o+ae]+=x*E)),i=S[i+et],i<0)break;continue}else for(y=n.scalingRatio,s=0;s<g;s+=ze)for(l=0;l<s;l+=ze)_=e[s+fe]-e[l+fe],x=e[s+se]-e[l+se],p===!0?(R=Math.sqrt(_*_+x*x)-e[s+Zn]-e[l+Zn],R>0?(E=y*e[s+re]*e[l+re]/R/R,e[s+ne]+=_*E,e[s+ae]+=x*E,e[l+ne]-=_*E,e[l+ae]-=x*E):R<0&&(E=100*y*e[s+re]*e[l+re],e[s+ne]+=_*E,e[s+ae]+=x*E,e[l+ne]-=_*E,e[l+ae]-=x*E)):(R=Math.sqrt(_*_+x*x),R>0&&(E=y*e[s+re]*e[l+re]/R/R,e[s+ne]+=_*E,e[s+ae]+=x*E,e[l+ne]-=_*E,e[l+ae]-=x*E));for(h=n.gravity/n.scalingRatio,y=n.scalingRatio,o=0;o<g;o+=ze)E=0,_=e[o+fe],x=e[o+se],R=Math.sqrt(Math.pow(_,2)+Math.pow(x,2)),n.strongGravityMode?R>0&&(E=y*e[o+re]*h):R>0&&(E=y*e[o+re]*h/R),e[o+ne]-=_*E,e[o+ae]-=x*E;for(y=1*(n.outboundAttractionDistribution?b:1),d=0;d<m;d+=_u)s=t[d+bu],l=t[d+yu],c=t[d+xu],T=Math.pow(c,n.edgeWeightInfluence),_=e[s+fe]-e[l+fe],x=e[s+se]-e[l+se],p===!0?(R=Math.sqrt(_*_+x*x)-e[s+Zn]-e[l+Zn],n.linLogMode?n.outboundAttractionDistribution?R>0&&(E=-y*T*Math.log(1+R)/R/e[s+re]):R>0&&(E=-y*T*Math.log(1+R)/R):n.outboundAttractionDistribution?R>0&&(E=-y*T/e[s+re]):R>0&&(E=-y*T)):(R=Math.sqrt(Math.pow(_,2)+Math.pow(x,2)),n.linLogMode?n.outboundAttractionDistribution?R>0&&(E=-y*T*Math.log(1+R)/R/e[s+re]):R>0&&(E=-y*T*Math.log(1+R)/R):n.outboundAttractionDistribution?(R=1,E=-y*T/e[s+re]):(R=1,E=-y*T)),R>0&&(e[s+ne]+=_*E,e[s+ae]+=x*E,e[l+ne]-=_*E,e[l+ae]-=x*E);var C,N,$,H,Z,X;if(p===!0)for(o=0;o<g;o+=ze)e[o+xi]!==1&&(C=Math.sqrt(Math.pow(e[o+ne],2)+Math.pow(e[o+ae],2)),C>$a&&(e[o+ne]=e[o+ne]*$a/C,e[o+ae]=e[o+ae]*$a/C),N=e[o+re]*Math.sqrt((e[o+je]-e[o+ne])*(e[o+je]-e[o+ne])+(e[o+Ye]-e[o+ae])*(e[o+Ye]-e[o+ae])),$=Math.sqrt((e[o+je]+e[o+ne])*(e[o+je]+e[o+ne])+(e[o+Ye]+e[o+ae])*(e[o+Ye]+e[o+ae]))/2,H=.1*Math.log(1+$)/(1+Math.sqrt(N)),Z=e[o+fe]+e[o+ne]*(H/n.slowDown),e[o+fe]=Z,X=e[o+se]+e[o+ae]*(H/n.slowDown),e[o+se]=X);else for(o=0;o<g;o+=ze)e[o+xi]!==1&&(N=e[o+re]*Math.sqrt((e[o+je]-e[o+ne])*(e[o+je]-e[o+ne])+(e[o+Ye]-e[o+ae])*(e[o+Ye]-e[o+ae])),$=Math.sqrt((e[o+je]+e[o+ne])*(e[o+je]+e[o+ne])+(e[o+Ye]+e[o+ae])*(e[o+Ye]+e[o+ae]))/2,H=e[o+yi]*Math.log(1+$)/(1+Math.sqrt(N)),e[o+yi]=Math.min(1,Math.sqrt(H*(Math.pow(e[o+ne],2)+Math.pow(e[o+ae],2))/(1+Math.sqrt(N)))),Z=e[o+fe]+e[o+ne]*(H/n.slowDown),e[o+fe]=Z,X=e[o+se]+e[o+ae]*(H/n.slowDown),e[o+se]=X);return{}}});var Ri=ht(tt=>{var ln=10,Ei=3;tt.assign=function(a){a=a||{};var n=Array.prototype.slice.call(arguments).slice(1),e,t,r;for(e=0,r=n.length;e<r;e++)if(n[e])for(t in n[e])a[t]=n[e][t];return a};tt.validateSettings=function(a){return"linLogMode"in a&&typeof a.linLogMode!="boolean"?{message:"the `linLogMode` setting should be a boolean."}:"outboundAttractionDistribution"in a&&typeof a.outboundAttractionDistribution!="boolean"?{message:"the `outboundAttractionDistribution` setting should be a boolean."}:"adjustSizes"in a&&typeof a.adjustSizes!="boolean"?{message:"the `adjustSizes` setting should be a boolean."}:"edgeWeightInfluence"in a&&typeof a.edgeWeightInfluence!="number"?{message:"the `edgeWeightInfluence` setting should be a number."}:"scalingRatio"in a&&!(typeof a.scalingRatio=="number"&&a.scalingRatio>=0)?{message:"the `scalingRatio` setting should be a number >= 0."}:"strongGravityMode"in a&&typeof a.strongGravityMode!="boolean"?{message:"the `strongGravityMode` setting should be a boolean."}:"gravity"in a&&!(typeof a.gravity=="number"&&a.gravity>=0)?{message:"the `gravity` setting should be a number >= 0."}:"slowDown"in a&&!(typeof a.slowDown=="number"||a.slowDown>=0)?{message:"the `slowDown` setting should be a number >= 0."}:"barnesHutOptimize"in a&&typeof a.barnesHutOptimize!="boolean"?{message:"the `barnesHutOptimize` setting should be a boolean."}:"barnesHutTheta"in a&&!(typeof a.barnesHutTheta=="number"&&a.barnesHutTheta>=0)?{message:"the `barnesHutTheta` setting should be a number >= 0."}:null};tt.graphToByteArrays=function(a,n){var e=a.order,t=a.size,r={},i,o=new Float32Array(e*ln),s=new Float32Array(t*Ei);return i=0,a.forEachNode(function(l,u){r[l]=i,o[i]=u.x,o[i+1]=u.y,o[i+2]=0,o[i+3]=0,o[i+4]=0,o[i+5]=0,o[i+6]=1,o[i+7]=1,o[i+8]=u.size||1,o[i+9]=u.fixed?1:0,i+=ln}),i=0,a.forEachEdge(function(l,u,d,c,h,f,g){var m=r[d],p=r[c],v=n(l,u,d,c,h,f,g);o[m+6]+=v,o[p+6]+=v,s[i]=m,s[i+1]=p,s[i+2]=v,i+=Ei}),{nodes:o,edges:s}};tt.assignLayoutChanges=function(a,n,e){var t=0;a.updateEachNodeAttributes(function(r,i){return i.x=n[t],i.y=n[t+1],t+=ln,e?e(r,i):i})};tt.readGraphPositions=function(a,n){var e=0;a.forEachNode(function(t,r){n[e]=r.x,n[e+1]=r.y,e+=ln})};tt.collectLayoutChanges=function(a,n,e){for(var t=a.nodes(),r={},i=0,o=0,s=n.length;i<s;i+=ln){if(e){var l=Object.assign({},a.getNodeAttributes(t[o]));l.x=n[i],l.y=n[i+1],l=e(t[o],l),r[t[o]]={x:l.x,y:l.y}}else r[t[o]]={x:n[i],y:n[i+1]};o++}return r};tt.createWorker=function(n){var e=window.URL||window.webkitURL,t=n.toString(),r=e.createObjectURL(new Blob(["("+t+").call(this);"],{type:"text/javascript"})),i=new Worker(r);return e.revokeObjectURL(r),i}});var Di=ht((If,Ai)=>{Ai.exports={linLogMode:!1,outboundAttractionDistribution:!1,adjustSizes:!1,edgeWeightInfluence:1,scalingRatio:1,strongGravityMode:!1,gravity:1,slowDown:1,barnesHutOptimize:!1,barnesHutTheta:.5}});var Ci=ht((Gf,Li)=>{var Tu=sn(),Su=bi().createEdgeWeightGetter,Eu=Si(),un=Ri(),Ru=Di();function wi(a,n,e){if(!Tu(n))throw new Error("graphology-layout-forceatlas2: the given graph is not a valid graphology instance.");typeof e=="number"&&(e={iterations:e});var t=e.iterations;if(typeof t!="number")throw new Error("graphology-layout-forceatlas2: invalid number of iterations.");if(t<=0)throw new Error("graphology-layout-forceatlas2: you should provide a positive number of iterations.");var r=Su("getEdgeWeight"in e?e.getEdgeWeight:"weight").fromEntry,i=typeof e.outputReducer=="function"?e.outputReducer:null,o=un.assign({},Ru,e.settings),s=un.validateSettings(o);if(s)throw new Error("graphology-layout-forceatlas2: "+s.message);var l=un.graphToByteArrays(n,r),u;for(u=0;u<t;u++)Eu(o,l.nodes,l.edges);if(a){un.assignLayoutChanges(n,l.nodes,i);return}return un.collectLayoutChanges(n,l.nodes)}function Au(a){var n=typeof a=="number"?a:a.order;return{barnesHutOptimize:n>2e3,strongGravityMode:!0,gravity:.05,scalingRatio:10,slowDown:1+Math.log(n)}}var Va=wi.bind(null,!1);Va.assign=wi.bind(null,!0);Va.inferSettings=Au;Li.exports=Va});var oi=Ve(Dt(),1);function cl(){let a=arguments[0];for(let n=1,e=arguments.length;n<e;n++)if(arguments[n])for(let t in arguments[n])a[t]=arguments[n][t];return a}var ge=cl;typeof Object.assign=="function"&&(ge=Object.assign);function we(a,n,e,t){let r=a._nodes.get(n),i=null;return r&&(t==="mixed"?i=r.out&&r.out[e]||r.undirected&&r.undirected[e]:t==="directed"?i=r.out&&r.out[e]:i=r.undirected&&r.undirected[e]),i}function be(a){return typeof a=="object"&&a!==null}function si(a){let n;for(n in a)return!1;return!0}function De(a,n,e){Object.defineProperty(a,n,{enumerable:!1,configurable:!1,writable:!0,value:e})}function Ge(a,n,e){let t={enumerable:!0,configurable:!0};typeof e=="function"?t.get=e:(t.value=e,t.writable=!1),Object.defineProperty(a,n,t)}function ai(a){return!(!be(a)||a.attributes&&!Array.isArray(a.attributes))}function hl(){let a=Math.floor(Math.random()*256)&255;return()=>a++}function qe(){let a=arguments,n=null,e=-1;return{[Symbol.iterator](){return this},next(){let t=null;do{if(n===null){if(e++,e>=a.length)return{done:!0};n=a[e][Symbol.iterator]()}if(t=n.next(),t.done){n=null;continue}break}while(!0);return t}}}function Lt(){return{[Symbol.iterator](){return this},next(){return{done:!0}}}}var on=class extends Error{constructor(n){super(),this.name="GraphError",this.message=n}},U=class a extends on{constructor(n){super(n),this.name="InvalidArgumentsGraphError",typeof Error.captureStackTrace=="function"&&Error.captureStackTrace(this,a.prototype.constructor)}},W=class a extends on{constructor(n){super(n),this.name="NotFoundGraphError",typeof Error.captureStackTrace=="function"&&Error.captureStackTrace(this,a.prototype.constructor)}},Y=class a extends on{constructor(n){super(n),this.name="UsageGraphError",typeof Error.captureStackTrace=="function"&&Error.captureStackTrace(this,a.prototype.constructor)}};function li(a,n){this.key=a,this.attributes=n,this.clear()}li.prototype.clear=function(){this.inDegree=0,this.outDegree=0,this.undirectedDegree=0,this.undirectedLoops=0,this.directedLoops=0,this.in={},this.out={},this.undirected={}};function ui(a,n){this.key=a,this.attributes=n,this.clear()}ui.prototype.clear=function(){this.inDegree=0,this.outDegree=0,this.directedLoops=0,this.in={},this.out={}};function di(a,n){this.key=a,this.attributes=n,this.clear()}di.prototype.clear=function(){this.undirectedDegree=0,this.undirectedLoops=0,this.undirected={}};function Ct(a,n,e,t,r){this.key=n,this.attributes=r,this.undirected=a,this.source=e,this.target=t}Ct.prototype.attach=function(){let a="out",n="in";this.undirected&&(a=n="undirected");let e=this.source.key,t=this.target.key;this.source[a][t]=this,!(this.undirected&&e===t)&&(this.target[n][e]=this)};Ct.prototype.attachMulti=function(){let a="out",n="in",e=this.source.key,t=this.target.key;this.undirected&&(a=n="undirected");let r=this.source[a],i=r[t];if(typeof i>"u"){r[t]=this,this.undirected&&e===t||(this.target[n][e]=this);return}i.previous=this,this.next=i,r[t]=this,this.target[n][e]=this};Ct.prototype.detach=function(){let a=this.source.key,n=this.target.key,e="out",t="in";this.undirected&&(e=t="undirected"),delete this.source[e][n],delete this.target[t][a]};Ct.prototype.detachMulti=function(){let a=this.source.key,n=this.target.key,e="out",t="in";this.undirected&&(e=t="undirected"),this.previous===void 0?this.next===void 0?(delete this.source[e][n],delete this.target[t][a]):(this.next.previous=void 0,this.source[e][n]=this.next,this.target[t][a]=this.next):(this.previous.next=this.next,this.next!==void 0&&(this.next.previous=this.previous))};var ci=0,hi=1,fl=2,fi=3;function Xe(a,n,e,t,r,i,o){let s,l,u,d;if(t=""+t,e===ci){if(s=a._nodes.get(t),!s)throw new W(`Graph.${n}: could not find the "${t}" node in the graph.`);u=r,d=i}else if(e===fi){if(r=""+r,l=a._edges.get(r),!l)throw new W(`Graph.${n}: could not find the "${r}" edge in the graph.`);let c=l.source.key,h=l.target.key;if(t===c)s=l.target;else if(t===h)s=l.source;else throw new W(`Graph.${n}: the "${t}" node is not attached to the "${r}" edge (${c}, ${h}).`);u=i,d=o}else{if(l=a._edges.get(t),!l)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`);e===hi?s=l.source:s=l.target,u=r,d=i}return[s,u,d]}function gl(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);return o.attributes[s]}}function vl(a,n,e){a.prototype[n]=function(t,r){let[i]=Xe(this,n,e,t,r);return i.attributes}}function pl(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);return o.attributes.hasOwnProperty(s)}}function ml(a,n,e){a.prototype[n]=function(t,r,i,o){let[s,l,u]=Xe(this,n,e,t,r,i,o);return s.attributes[l]=u,this.emit("nodeAttributesUpdated",{key:s.key,type:"set",attributes:s.attributes,name:l}),this}}function bl(a,n,e){a.prototype[n]=function(t,r,i,o){let[s,l,u]=Xe(this,n,e,t,r,i,o);if(typeof u!="function")throw new U(`Graph.${n}: updater should be a function.`);let d=s.attributes,c=u(d[l]);return d[l]=c,this.emit("nodeAttributesUpdated",{key:s.key,type:"set",attributes:s.attributes,name:l}),this}}function yl(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);return delete o.attributes[s],this.emit("nodeAttributesUpdated",{key:o.key,type:"remove",attributes:o.attributes,name:s}),this}}function xl(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);if(!be(s))throw new U(`Graph.${n}: provided attributes are not a plain object.`);return o.attributes=s,this.emit("nodeAttributesUpdated",{key:o.key,type:"replace",attributes:o.attributes}),this}}function _l(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);if(!be(s))throw new U(`Graph.${n}: provided attributes are not a plain object.`);return ge(o.attributes,s),this.emit("nodeAttributesUpdated",{key:o.key,type:"merge",attributes:o.attributes,data:s}),this}}function Tl(a,n,e){a.prototype[n]=function(t,r,i){let[o,s]=Xe(this,n,e,t,r,i);if(typeof s!="function")throw new U(`Graph.${n}: provided updater is not a function.`);return o.attributes=s(o.attributes),this.emit("nodeAttributesUpdated",{key:o.key,type:"update",attributes:o.attributes}),this}}var Sl=[{name:a=>`get${a}Attribute`,attacher:gl},{name:a=>`get${a}Attributes`,attacher:vl},{name:a=>`has${a}Attribute`,attacher:pl},{name:a=>`set${a}Attribute`,attacher:ml},{name:a=>`update${a}Attribute`,attacher:bl},{name:a=>`remove${a}Attribute`,attacher:yl},{name:a=>`replace${a}Attributes`,attacher:xl},{name:a=>`merge${a}Attributes`,attacher:_l},{name:a=>`update${a}Attributes`,attacher:Tl}];function El(a){Sl.forEach(function({name:n,attacher:e}){e(a,n("Node"),ci),e(a,n("Source"),hi),e(a,n("Target"),fl),e(a,n("Opposite"),fi)})}function Rl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}return i.attributes[r]}}function Al(a,n,e){a.prototype[n]=function(t){let r;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>1){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let i=""+t,o=""+arguments[1];if(r=we(this,i,o,e),!r)throw new W(`Graph.${n}: could not find an edge for the given path ("${i}" - "${o}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,r=this._edges.get(t),!r)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}return r.attributes}}function Dl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}return i.attributes.hasOwnProperty(r)}}function wl(a,n,e){a.prototype[n]=function(t,r,i){let o;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>3){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let s=""+t,l=""+r;if(r=arguments[2],i=arguments[3],o=we(this,s,l,e),!o)throw new W(`Graph.${n}: could not find an edge for the given path ("${s}" - "${l}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,o=this._edges.get(t),!o)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}return o.attributes[r]=i,this.emit("edgeAttributesUpdated",{key:o.key,type:"set",attributes:o.attributes,name:r}),this}}function Ll(a,n,e){a.prototype[n]=function(t,r,i){let o;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>3){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let s=""+t,l=""+r;if(r=arguments[2],i=arguments[3],o=we(this,s,l,e),!o)throw new W(`Graph.${n}: could not find an edge for the given path ("${s}" - "${l}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,o=this._edges.get(t),!o)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}if(typeof i!="function")throw new U(`Graph.${n}: updater should be a function.`);return o.attributes[r]=i(o.attributes[r]),this.emit("edgeAttributesUpdated",{key:o.key,type:"set",attributes:o.attributes,name:r}),this}}function Cl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}return delete i.attributes[r],this.emit("edgeAttributesUpdated",{key:i.key,type:"remove",attributes:i.attributes,name:r}),this}}function Pl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}if(!be(r))throw new U(`Graph.${n}: provided attributes are not a plain object.`);return i.attributes=r,this.emit("edgeAttributesUpdated",{key:i.key,type:"replace",attributes:i.attributes}),this}}function kl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}if(!be(r))throw new U(`Graph.${n}: provided attributes are not a plain object.`);return ge(i.attributes,r),this.emit("edgeAttributesUpdated",{key:i.key,type:"merge",attributes:i.attributes,data:r}),this}}function Fl(a,n,e){a.prototype[n]=function(t,r){let i;if(this.type!=="mixed"&&e!=="mixed"&&e!==this.type)throw new Y(`Graph.${n}: cannot find this type of edges in your ${this.type} graph.`);if(arguments.length>2){if(this.multi)throw new Y(`Graph.${n}: cannot use a {source,target} combo when asking about an edge's attributes in a MultiGraph since we cannot infer the one you want information about.`);let o=""+t,s=""+r;if(r=arguments[2],i=we(this,o,s,e),!i)throw new W(`Graph.${n}: could not find an edge for the given path ("${o}" - "${s}").`)}else{if(e!=="mixed")throw new Y(`Graph.${n}: calling this method with only a key (vs. a source and target) does not make sense since an edge with this key could have the other type.`);if(t=""+t,i=this._edges.get(t),!i)throw new W(`Graph.${n}: could not find the "${t}" edge in the graph.`)}if(typeof r!="function")throw new U(`Graph.${n}: provided updater is not a function.`);return i.attributes=r(i.attributes),this.emit("edgeAttributesUpdated",{key:i.key,type:"update",attributes:i.attributes}),this}}var Il=[{name:a=>`get${a}Attribute`,attacher:Rl},{name:a=>`get${a}Attributes`,attacher:Al},{name:a=>`has${a}Attribute`,attacher:Dl},{name:a=>`set${a}Attribute`,attacher:wl},{name:a=>`update${a}Attribute`,attacher:Ll},{name:a=>`remove${a}Attribute`,attacher:Cl},{name:a=>`replace${a}Attributes`,attacher:Pl},{name:a=>`merge${a}Attributes`,attacher:kl},{name:a=>`update${a}Attributes`,attacher:Fl}];function Gl(a){Il.forEach(function({name:n,attacher:e}){e(a,n("Edge"),"mixed"),e(a,n("DirectedEdge"),"directed"),e(a,n("UndirectedEdge"),"undirected")})}var zl=[{name:"edges",type:"mixed"},{name:"inEdges",type:"directed",direction:"in"},{name:"outEdges",type:"directed",direction:"out"},{name:"inboundEdges",type:"mixed",direction:"in"},{name:"outboundEdges",type:"mixed",direction:"out"},{name:"directedEdges",type:"directed"},{name:"undirectedEdges",type:"undirected"}];function Nl(a,n,e,t){let r=!1;for(let i in n){if(i===t)continue;let o=n[i];if(r=e(o.key,o.attributes,o.source.key,o.target.key,o.source.attributes,o.target.attributes,o.undirected),a&&r)return o.key}}function Ml(a,n,e,t){let r,i,o,s=!1;for(let l in n)if(l!==t){r=n[l];do{if(i=r.source,o=r.target,s=e(r.key,r.attributes,i.key,o.key,i.attributes,o.attributes,r.undirected),a&&s)return r.key;r=r.next}while(r!==void 0)}}function Oa(a,n){let e=Object.keys(a),t=e.length,r,i=0;return{[Symbol.iterator](){return this},next(){do if(r)r=r.next;else{if(i>=t)return{done:!0};let o=e[i++];if(o===n){r=void 0;continue}r=a[o]}while(!r);return{done:!1,value:{edge:r.key,attributes:r.attributes,source:r.source.key,target:r.target.key,sourceAttributes:r.source.attributes,targetAttributes:r.target.attributes,undirected:r.undirected}}}}}function Ol(a,n,e,t){let r=n[e];if(!r)return;let i=r.source,o=r.target;if(t(r.key,r.attributes,i.key,o.key,i.attributes,o.attributes,r.undirected)&&a)return r.key}function Wl(a,n,e,t){let r=n[e];if(!r)return;let i=!1;do{if(i=t(r.key,r.attributes,r.source.key,r.target.key,r.source.attributes,r.target.attributes,r.undirected),a&&i)return r.key;r=r.next}while(r!==void 0)}function Wa(a,n){let e=a[n];if(e.next!==void 0)return{[Symbol.iterator](){return this},next(){if(!e)return{done:!0};let r={edge:e.key,attributes:e.attributes,source:e.source.key,target:e.target.key,sourceAttributes:e.source.attributes,targetAttributes:e.target.attributes,undirected:e.undirected};return e=e.next,{done:!1,value:r}}};let t=!1;return{[Symbol.iterator](){return this},next(){return t===!0?{done:!0}:(t=!0,{done:!1,value:{edge:e.key,attributes:e.attributes,source:e.source.key,target:e.target.key,sourceAttributes:e.source.attributes,targetAttributes:e.target.attributes,undirected:e.undirected}})}}}function Bl(a,n){if(a.size===0)return[];if(n==="mixed"||n===a.type)return Array.from(a._edges.keys());let e=n==="undirected"?a.undirectedSize:a.directedSize,t=new Array(e),r=n==="undirected",i=a._edges.values(),o=0,s,l;for(;s=i.next(),s.done!==!0;)l=s.value,l.undirected===r&&(t[o++]=l.key);return t}function gi(a,n,e,t){if(n.size===0)return;let r=e!=="mixed"&&e!==n.type,i=e==="undirected",o,s,l=!1,u=n._edges.values();for(;o=u.next(),o.done!==!0;){if(s=o.value,r&&s.undirected!==i)continue;let{key:d,attributes:c,source:h,target:f}=s;if(l=t(d,c,h.key,f.key,h.attributes,f.attributes,s.undirected),a&&l)return d}}function Ul(a,n){if(a.size===0)return Lt();let e=n!=="mixed"&&n!==a.type,t=n==="undirected",r=a._edges.values();return{[Symbol.iterator](){return this},next(){let i,o;for(;;){if(i=r.next(),i.done)return i;if(o=i.value,!(e&&o.undirected!==t))break}return{value:{edge:o.key,attributes:o.attributes,source:o.source.key,target:o.target.key,sourceAttributes:o.source.attributes,targetAttributes:o.target.attributes,undirected:o.undirected},done:!1}}}}function Ba(a,n,e,t,r,i){let o=n?Ml:Nl,s;if(e!=="undirected"&&(t!=="out"&&(s=o(a,r.in,i),a&&s)||t!=="in"&&(s=o(a,r.out,i,t?void 0:r.key),a&&s))||e!=="directed"&&(s=o(a,r.undirected,i),a&&s))return s}function Hl(a,n,e,t){let r=[];return Ba(!1,a,n,e,t,function(i){r.push(i)}),r}function $l(a,n,e){let t=Lt();return a!=="undirected"&&(n!=="out"&&typeof e.in<"u"&&(t=qe(t,Oa(e.in))),n!=="in"&&typeof e.out<"u"&&(t=qe(t,Oa(e.out,n?void 0:e.key)))),a!=="directed"&&typeof e.undirected<"u"&&(t=qe(t,Oa(e.undirected))),t}function Ua(a,n,e,t,r,i,o){let s=e?Wl:Ol,l;if(n!=="undirected"&&(typeof r.in<"u"&&t!=="out"&&(l=s(a,r.in,i,o),a&&l)||typeof r.out<"u"&&t!=="in"&&(t||r.key!==i)&&(l=s(a,r.out,i,o),a&&l))||n!=="directed"&&typeof r.undirected<"u"&&(l=s(a,r.undirected,i,o),a&&l))return l}function Vl(a,n,e,t,r){let i=[];return Ua(!1,a,n,e,t,r,function(o){i.push(o)}),i}function ql(a,n,e,t){let r=Lt();return a!=="undirected"&&(typeof e.in<"u"&&n!=="out"&&t in e.in&&(r=qe(r,Wa(e.in,t))),typeof e.out<"u"&&n!=="in"&&t in e.out&&(n||e.key!==t)&&(r=qe(r,Wa(e.out,t)))),a!=="directed"&&typeof e.undirected<"u"&&t in e.undirected&&(r=qe(r,Wa(e.undirected,t))),r}function Xl(a,n){let{name:e,type:t,direction:r}=n;a.prototype[e]=function(i,o){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return[];if(!arguments.length)return Bl(this,t);if(arguments.length===1){i=""+i;let s=this._nodes.get(i);if(typeof s>"u")throw new W(`Graph.${e}: could not find the "${i}" node in the graph.`);return Hl(this.multi,t==="mixed"?this.type:t,r,s)}if(arguments.length===2){i=""+i,o=""+o;let s=this._nodes.get(i);if(!s)throw new W(`Graph.${e}:  could not find the "${i}" source node in the graph.`);if(!this._nodes.has(o))throw new W(`Graph.${e}:  could not find the "${o}" target node in the graph.`);return Vl(t,this.multi,r,s,o)}throw new U(`Graph.${e}: too many arguments (expecting 0, 1 or 2 and got ${arguments.length}).`)}}function jl(a,n){let{name:e,type:t,direction:r}=n,i="forEach"+e[0].toUpperCase()+e.slice(1,-1);a.prototype[i]=function(u,d,c){if(!(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)){if(arguments.length===1)return c=u,gi(!1,this,t,c);if(arguments.length===2){u=""+u,c=d;let h=this._nodes.get(u);if(typeof h>"u")throw new W(`Graph.${i}: could not find the "${u}" node in the graph.`);return Ba(!1,this.multi,t==="mixed"?this.type:t,r,h,c)}if(arguments.length===3){u=""+u,d=""+d;let h=this._nodes.get(u);if(!h)throw new W(`Graph.${i}:  could not find the "${u}" source node in the graph.`);if(!this._nodes.has(d))throw new W(`Graph.${i}:  could not find the "${d}" target node in the graph.`);return Ua(!1,t,this.multi,r,h,d,c)}throw new U(`Graph.${i}: too many arguments (expecting 1, 2 or 3 and got ${arguments.length}).`)}};let o="map"+e[0].toUpperCase()+e.slice(1);a.prototype[o]=function(){let u=Array.prototype.slice.call(arguments),d=u.pop(),c;if(u.length===0){let h=0;t!=="directed"&&(h+=this.undirectedSize),t!=="undirected"&&(h+=this.directedSize),c=new Array(h);let f=0;u.push((g,m,p,v,b,y,_)=>{c[f++]=d(g,m,p,v,b,y,_)})}else c=[],u.push((h,f,g,m,p,v,b)=>{c.push(d(h,f,g,m,p,v,b))});return this[i].apply(this,u),c};let s="filter"+e[0].toUpperCase()+e.slice(1);a.prototype[s]=function(){let u=Array.prototype.slice.call(arguments),d=u.pop(),c=[];return u.push((h,f,g,m,p,v,b)=>{d(h,f,g,m,p,v,b)&&c.push(h)}),this[i].apply(this,u),c};let l="reduce"+e[0].toUpperCase()+e.slice(1);a.prototype[l]=function(){let u=Array.prototype.slice.call(arguments);if(u.length<2||u.length>4)throw new U(`Graph.${l}: invalid number of arguments (expecting 2, 3 or 4 and got ${u.length}).`);if(typeof u[u.length-1]=="function"&&typeof u[u.length-2]!="function")throw new U(`Graph.${l}: missing initial value. You must provide it because the callback takes more than one argument and we cannot infer the initial value from the first iteration, as you could with a simple array.`);let d,c;u.length===2?(d=u[0],c=u[1],u=[]):u.length===3?(d=u[1],c=u[2],u=[u[0]]):u.length===4&&(d=u[2],c=u[3],u=[u[0],u[1]]);let h=c;return u.push((f,g,m,p,v,b,y)=>{h=d(h,f,g,m,p,v,b,y)}),this[i].apply(this,u),h}}function Yl(a,n){let{name:e,type:t,direction:r}=n,i="find"+e[0].toUpperCase()+e.slice(1,-1);a.prototype[i]=function(l,u,d){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return!1;if(arguments.length===1)return d=l,gi(!0,this,t,d);if(arguments.length===2){l=""+l,d=u;let c=this._nodes.get(l);if(typeof c>"u")throw new W(`Graph.${i}: could not find the "${l}" node in the graph.`);return Ba(!0,this.multi,t==="mixed"?this.type:t,r,c,d)}if(arguments.length===3){l=""+l,u=""+u;let c=this._nodes.get(l);if(!c)throw new W(`Graph.${i}:  could not find the "${l}" source node in the graph.`);if(!this._nodes.has(u))throw new W(`Graph.${i}:  could not find the "${u}" target node in the graph.`);return Ua(!0,t,this.multi,r,c,u,d)}throw new U(`Graph.${i}: too many arguments (expecting 1, 2 or 3 and got ${arguments.length}).`)};let o="some"+e[0].toUpperCase()+e.slice(1,-1);a.prototype[o]=function(){let l=Array.prototype.slice.call(arguments),u=l.pop();return l.push((c,h,f,g,m,p,v)=>u(c,h,f,g,m,p,v)),!!this[i].apply(this,l)};let s="every"+e[0].toUpperCase()+e.slice(1,-1);a.prototype[s]=function(){let l=Array.prototype.slice.call(arguments),u=l.pop();return l.push((c,h,f,g,m,p,v)=>!u(c,h,f,g,m,p,v)),!this[i].apply(this,l)}}function Kl(a,n){let{name:e,type:t,direction:r}=n,i=e.slice(0,-1)+"Entries";a.prototype[i]=function(o,s){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return Lt();if(!arguments.length)return Ul(this,t);if(arguments.length===1){o=""+o;let l=this._nodes.get(o);if(!l)throw new W(`Graph.${i}: could not find the "${o}" node in the graph.`);return $l(t,r,l)}if(arguments.length===2){o=""+o,s=""+s;let l=this._nodes.get(o);if(!l)throw new W(`Graph.${i}:  could not find the "${o}" source node in the graph.`);if(!this._nodes.has(s))throw new W(`Graph.${i}:  could not find the "${s}" target node in the graph.`);return ql(t,r,l,s)}throw new U(`Graph.${i}: too many arguments (expecting 0, 1 or 2 and got ${arguments.length}).`)}}function Zl(a){zl.forEach(n=>{Xl(a,n),jl(a,n),Yl(a,n),Kl(a,n)})}var Ql=[{name:"neighbors",type:"mixed"},{name:"inNeighbors",type:"directed",direction:"in"},{name:"outNeighbors",type:"directed",direction:"out"},{name:"inboundNeighbors",type:"mixed",direction:"in"},{name:"outboundNeighbors",type:"mixed",direction:"out"},{name:"directedNeighbors",type:"directed"},{name:"undirectedNeighbors",type:"undirected"}];function Yn(){this.A=null,this.B=null}Yn.prototype.wrap=function(a){this.A===null?this.A=a:this.B===null&&(this.B=a)};Yn.prototype.has=function(a){return this.A!==null&&a in this.A||this.B!==null&&a in this.B};function an(a,n,e,t,r){for(let i in t){let o=t[i],s=o.source,l=o.target,u=s===e?l:s;if(n&&n.has(u.key))continue;let d=r(u.key,u.attributes);if(a&&d)return u.key}}function Ha(a,n,e,t,r){if(n!=="mixed"){if(n==="undirected")return an(a,null,t,t.undirected,r);if(typeof e=="string")return an(a,null,t,t[e],r)}let i=new Yn,o;if(n!=="undirected"){if(e!=="out"){if(o=an(a,null,t,t.in,r),a&&o)return o;i.wrap(t.in)}if(e!=="in"){if(o=an(a,i,t,t.out,r),a&&o)return o;i.wrap(t.out)}}if(n!=="directed"&&(o=an(a,i,t,t.undirected,r),a&&o))return o}function Jl(a,n,e){if(a!=="mixed"){if(a==="undirected")return Object.keys(e.undirected);if(typeof n=="string")return Object.keys(e[n])}let t=[];return Ha(!1,a,n,e,function(r){t.push(r)}),t}function rn(a,n,e){let t=Object.keys(e),r=t.length,i=0;return{[Symbol.iterator](){return this},next(){let o=null;do{if(i>=r)return a&&a.wrap(e),{done:!0};let s=e[t[i++]],l=s.source,u=s.target;if(o=l===n?u:l,a&&a.has(o.key)){o=null;continue}}while(o===null);return{done:!1,value:{neighbor:o.key,attributes:o.attributes}}}}}function eu(a,n,e){if(a!=="mixed"){if(a==="undirected")return rn(null,e,e.undirected);if(typeof n=="string")return rn(null,e,e[n])}let t=Lt(),r=new Yn;return a!=="undirected"&&(n!=="out"&&(t=qe(t,rn(r,e,e.in))),n!=="in"&&(t=qe(t,rn(r,e,e.out)))),a!=="directed"&&(t=qe(t,rn(r,e,e.undirected))),t}function tu(a,n){let{name:e,type:t,direction:r}=n;a.prototype[e]=function(i){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return[];i=""+i;let o=this._nodes.get(i);if(typeof o>"u")throw new W(`Graph.${e}: could not find the "${i}" node in the graph.`);return Jl(t==="mixed"?this.type:t,r,o)}}function nu(a,n){let{name:e,type:t,direction:r}=n,i="forEach"+e[0].toUpperCase()+e.slice(1,-1);a.prototype[i]=function(u,d){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return;u=""+u;let c=this._nodes.get(u);if(typeof c>"u")throw new W(`Graph.${i}: could not find the "${u}" node in the graph.`);Ha(!1,t==="mixed"?this.type:t,r,c,d)};let o="map"+e[0].toUpperCase()+e.slice(1);a.prototype[o]=function(u,d){let c=[];return this[i](u,(h,f)=>{c.push(d(h,f))}),c};let s="filter"+e[0].toUpperCase()+e.slice(1);a.prototype[s]=function(u,d){let c=[];return this[i](u,(h,f)=>{d(h,f)&&c.push(h)}),c};let l="reduce"+e[0].toUpperCase()+e.slice(1);a.prototype[l]=function(u,d,c){if(arguments.length<3)throw new U(`Graph.${l}: missing initial value. You must provide it because the callback takes more than one argument and we cannot infer the initial value from the first iteration, as you could with a simple array.`);let h=c;return this[i](u,(f,g)=>{h=d(h,f,g)}),h}}function au(a,n){let{name:e,type:t,direction:r}=n,i=e[0].toUpperCase()+e.slice(1,-1),o="find"+i;a.prototype[o]=function(u,d){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return;u=""+u;let c=this._nodes.get(u);if(typeof c>"u")throw new W(`Graph.${o}: could not find the "${u}" node in the graph.`);return Ha(!0,t==="mixed"?this.type:t,r,c,d)};let s="some"+i;a.prototype[s]=function(u,d){return!!this[o](u,d)};let l="every"+i;a.prototype[l]=function(u,d){return!this[o](u,(h,f)=>!d(h,f))}}function ru(a,n){let{name:e,type:t,direction:r}=n,i=e.slice(0,-1)+"Entries";a.prototype[i]=function(o){if(t!=="mixed"&&this.type!=="mixed"&&t!==this.type)return Lt();o=""+o;let s=this._nodes.get(o);if(typeof s>"u")throw new W(`Graph.${i}: could not find the "${o}" node in the graph.`);return eu(t==="mixed"?this.type:t,r,s)}}function iu(a){Ql.forEach(n=>{tu(a,n),nu(a,n),au(a,n),ru(a,n)})}function Hn(a,n,e,t,r){let i=t._nodes.values(),o=t.type,s,l,u,d,c,h,f;for(;s=i.next(),s.done!==!0;){let g=!1;if(l=s.value,o!=="undirected"){d=l.out;for(u in d){c=d[u];do{if(h=c.target,g=!0,f=r(l.key,h.key,l.attributes,h.attributes,c.key,c.attributes,c.undirected),a&&f)return c;c=c.next}while(c)}}if(o!=="directed"){d=l.undirected;for(u in d)if(!(n&&l.key>u)){c=d[u];do{if(h=c.target,h.key!==u&&(h=c.source),g=!0,f=r(l.key,h.key,l.attributes,h.attributes,c.key,c.attributes,c.undirected),a&&f)return c;c=c.next}while(c)}}if(e&&!g&&(f=r(l.key,null,l.attributes,null,null,null,null),a&&f))return null}}function ou(a,n){let e={key:a};return si(n.attributes)||(e.attributes=ge({},n.attributes)),e}function su(a,n,e){let t={key:n,source:e.source.key,target:e.target.key};return si(e.attributes)||(t.attributes=ge({},e.attributes)),a==="mixed"&&e.undirected&&(t.undirected=!0),t}function lu(a){if(!be(a))throw new U('Graph.import: invalid serialized node. A serialized node should be a plain object with at least a "key" property.');if(!("key"in a))throw new U("Graph.import: serialized node is missing its key.");if("attributes"in a&&(!be(a.attributes)||a.attributes===null))throw new U("Graph.import: invalid attributes. Attributes should be a plain object, null or omitted.")}function uu(a){if(!be(a))throw new U('Graph.import: invalid serialized edge. A serialized edge should be a plain object with at least a "source" & "target" property.');if(!("source"in a))throw new U("Graph.import: serialized edge is missing its source.");if(!("target"in a))throw new U("Graph.import: serialized edge is missing its target.");if("attributes"in a&&(!be(a.attributes)||a.attributes===null))throw new U("Graph.import: invalid attributes. Attributes should be a plain object, null or omitted.");if("undirected"in a&&typeof a.undirected!="boolean")throw new U("Graph.import: invalid undirectedness information. Undirected should be boolean or omitted.")}var du=hl(),cu=new Set(["directed","undirected","mixed"]),ri=new Set(["domain","_events","_eventsCount","_maxListeners"]),hu=[{name:a=>`${a}Edge`,generateKey:!0},{name:a=>`${a}DirectedEdge`,generateKey:!0,type:"directed"},{name:a=>`${a}UndirectedEdge`,generateKey:!0,type:"undirected"},{name:a=>`${a}EdgeWithKey`},{name:a=>`${a}DirectedEdgeWithKey`,type:"directed"},{name:a=>`${a}UndirectedEdgeWithKey`,type:"undirected"}],fu={allowSelfLoops:!0,multi:!1,type:"mixed"};function gu(a,n,e){if(e&&!be(e))throw new U(`Graph.addNode: invalid attributes. Expecting an object but got "${e}"`);if(n=""+n,e=e||{},a._nodes.has(n))throw new Y(`Graph.addNode: the "${n}" node already exist in the graph.`);let t=new a.NodeDataClass(n,e);return a._nodes.set(n,t),a.emit("nodeAdded",{key:n,attributes:e}),t}function ii(a,n,e){let t=new a.NodeDataClass(n,e);return a._nodes.set(n,t),a.emit("nodeAdded",{key:n,attributes:e}),t}function vi(a,n,e,t,r,i,o,s){if(!t&&a.type==="undirected")throw new Y(`Graph.${n}: you cannot add a directed edge to an undirected graph. Use the #.addEdge or #.addUndirectedEdge instead.`);if(t&&a.type==="directed")throw new Y(`Graph.${n}: you cannot add an undirected edge to a directed graph. Use the #.addEdge or #.addDirectedEdge instead.`);if(s&&!be(s))throw new U(`Graph.${n}: invalid attributes. Expecting an object but got "${s}"`);if(i=""+i,o=""+o,s=s||{},!a.allowSelfLoops&&i===o)throw new Y(`Graph.${n}: source & target are the same ("${i}"), thus creating a loop explicitly forbidden by this graph 'allowSelfLoops' option set to false.`);let l=a._nodes.get(i),u=a._nodes.get(o);if(!l)throw new W(`Graph.${n}: source node "${i}" not found.`);if(!u)throw new W(`Graph.${n}: target node "${o}" not found.`);let d={key:null,undirected:t,source:i,target:o,attributes:s};if(e)r=a._edgeKeyGenerator();else if(r=""+r,a._edges.has(r))throw new Y(`Graph.${n}: the "${r}" edge already exists in the graph.`);if(!a.multi&&(t?typeof l.undirected[o]<"u":typeof l.out[o]<"u"))throw new Y(`Graph.${n}: an edge linking "${i}" to "${o}" already exists. If you really want to add multiple edges linking those nodes, you should create a multi graph by using the 'multi' option.`);let c=new Ct(t,r,l,u,s);a._edges.set(r,c);let h=i===o;return t?(l.undirectedDegree++,u.undirectedDegree++,h&&(l.undirectedLoops++,a._undirectedSelfLoopCount++)):(l.outDegree++,u.inDegree++,h&&(l.directedLoops++,a._directedSelfLoopCount++)),a.multi?c.attachMulti():c.attach(),t?a._undirectedSize++:a._directedSize++,d.key=r,a.emit("edgeAdded",d),r}function vu(a,n,e,t,r,i,o,s,l){if(!t&&a.type==="undirected")throw new Y(`Graph.${n}: you cannot merge/update a directed edge to an undirected graph. Use the #.mergeEdge/#.updateEdge or #.addUndirectedEdge instead.`);if(t&&a.type==="directed")throw new Y(`Graph.${n}: you cannot merge/update an undirected edge to a directed graph. Use the #.mergeEdge/#.updateEdge or #.addDirectedEdge instead.`);if(s){if(l){if(typeof s!="function")throw new U(`Graph.${n}: invalid updater function. Expecting a function but got "${s}"`)}else if(!be(s))throw new U(`Graph.${n}: invalid attributes. Expecting an object but got "${s}"`)}i=""+i,o=""+o;let u;if(l&&(u=s,s=void 0),!a.allowSelfLoops&&i===o)throw new Y(`Graph.${n}: source & target are the same ("${i}"), thus creating a loop explicitly forbidden by this graph 'allowSelfLoops' option set to false.`);let d=a._nodes.get(i),c=a._nodes.get(o),h,f;if(!e&&(h=a._edges.get(r),h)){if((h.source.key!==i||h.target.key!==o)&&(!t||h.source.key!==o||h.target.key!==i))throw new Y(`Graph.${n}: inconsistency detected when attempting to merge the "${r}" edge with "${i}" source & "${o}" target vs. ("${h.source.key}", "${h.target.key}").`);f=h}if(!f&&!a.multi&&d&&(f=t?d.undirected[o]:d.out[o]),f){let b=[f.key,!1,!1,!1];if(l?!u:!s)return b;if(l){let y=f.attributes;f.attributes=u(y),a.emit("edgeAttributesUpdated",{type:"replace",key:f.key,attributes:f.attributes})}else ge(f.attributes,s),a.emit("edgeAttributesUpdated",{type:"merge",key:f.key,attributes:f.attributes,data:s});return b}s=s||{},l&&u&&(s=u(s));let g={key:null,undirected:t,source:i,target:o,attributes:s};if(e)r=a._edgeKeyGenerator();else if(r=""+r,a._edges.has(r))throw new Y(`Graph.${n}: the "${r}" edge already exists in the graph.`);let m=!1,p=!1;d||(d=ii(a,i,{}),m=!0,i===o&&(c=d,p=!0)),c||(c=ii(a,o,{}),p=!0),h=new Ct(t,r,d,c,s),a._edges.set(r,h);let v=i===o;return t?(d.undirectedDegree++,c.undirectedDegree++,v&&(d.undirectedLoops++,a._undirectedSelfLoopCount++)):(d.outDegree++,c.inDegree++,v&&(d.directedLoops++,a._directedSelfLoopCount++)),a.multi?h.attachMulti():h.attach(),t?a._undirectedSize++:a._directedSize++,g.key=r,a.emit("edgeAdded",g),[r,!0,m,p]}function wt(a,n){a._edges.delete(n.key);let{source:e,target:t,attributes:r}=n,i=n.undirected,o=e===t;i?(e.undirectedDegree--,t.undirectedDegree--,o&&(e.undirectedLoops--,a._undirectedSelfLoopCount--)):(e.outDegree--,t.inDegree--,o&&(e.directedLoops--,a._directedSelfLoopCount--)),a.multi?n.detachMulti():n.detach(),i?a._undirectedSize--:a._directedSize--,a.emit("edgeDropped",{key:n.key,attributes:r,source:e.key,target:t.key,undirected:i})}var oe=class a extends oi.EventEmitter{constructor(n){if(super(),n=ge({},fu,n),typeof n.multi!="boolean")throw new U(`Graph.constructor: invalid 'multi' option. Expecting a boolean but got "${n.multi}".`);if(!cu.has(n.type))throw new U(`Graph.constructor: invalid 'type' option. Should be one of "mixed", "directed" or "undirected" but got "${n.type}".`);if(typeof n.allowSelfLoops!="boolean")throw new U(`Graph.constructor: invalid 'allowSelfLoops' option. Expecting a boolean but got "${n.allowSelfLoops}".`);let e=n.type==="mixed"?li:n.type==="directed"?ui:di;De(this,"NodeDataClass",e);let t="geid_"+du()+"_",r=0,i=()=>{let o;do o=t+r++;while(this._edges.has(o));return o};De(this,"_attributes",{}),De(this,"_nodes",new Map),De(this,"_edges",new Map),De(this,"_directedSize",0),De(this,"_undirectedSize",0),De(this,"_directedSelfLoopCount",0),De(this,"_undirectedSelfLoopCount",0),De(this,"_edgeKeyGenerator",i),De(this,"_options",n),ri.forEach(o=>De(this,o,this[o])),Ge(this,"order",()=>this._nodes.size),Ge(this,"size",()=>this._edges.size),Ge(this,"directedSize",()=>this._directedSize),Ge(this,"undirectedSize",()=>this._undirectedSize),Ge(this,"selfLoopCount",()=>this._directedSelfLoopCount+this._undirectedSelfLoopCount),Ge(this,"directedSelfLoopCount",()=>this._directedSelfLoopCount),Ge(this,"undirectedSelfLoopCount",()=>this._undirectedSelfLoopCount),Ge(this,"multi",this._options.multi),Ge(this,"type",this._options.type),Ge(this,"allowSelfLoops",this._options.allowSelfLoops),Ge(this,"implementation",()=>"graphology")}_resetInstanceCounters(){this._directedSize=0,this._undirectedSize=0,this._directedSelfLoopCount=0,this._undirectedSelfLoopCount=0}hasNode(n){return this._nodes.has(""+n)}hasDirectedEdge(n,e){if(this.type==="undirected")return!1;if(arguments.length===1){let t=""+n,r=this._edges.get(t);return!!r&&!r.undirected}else if(arguments.length===2){n=""+n,e=""+e;let t=this._nodes.get(n);return t?t.out.hasOwnProperty(e):!1}throw new U(`Graph.hasDirectedEdge: invalid arity (${arguments.length}, instead of 1 or 2). You can either ask for an edge id or for the existence of an edge between a source & a target.`)}hasUndirectedEdge(n,e){if(this.type==="directed")return!1;if(arguments.length===1){let t=""+n,r=this._edges.get(t);return!!r&&r.undirected}else if(arguments.length===2){n=""+n,e=""+e;let t=this._nodes.get(n);return t?t.undirected.hasOwnProperty(e):!1}throw new U(`Graph.hasDirectedEdge: invalid arity (${arguments.length}, instead of 1 or 2). You can either ask for an edge id or for the existence of an edge between a source & a target.`)}hasEdge(n,e){if(arguments.length===1){let t=""+n;return this._edges.has(t)}else if(arguments.length===2){n=""+n,e=""+e;let t=this._nodes.get(n);return t?typeof t.out<"u"&&t.out.hasOwnProperty(e)||typeof t.undirected<"u"&&t.undirected.hasOwnProperty(e):!1}throw new U(`Graph.hasEdge: invalid arity (${arguments.length}, instead of 1 or 2). You can either ask for an edge id or for the existence of an edge between a source & a target.`)}directedEdge(n,e){if(this.type==="undirected")return;if(n=""+n,e=""+e,this.multi)throw new Y("Graph.directedEdge: this method is irrelevant with multigraphs since there might be multiple edges between source & target. See #.directedEdges instead.");let t=this._nodes.get(n);if(!t)throw new W(`Graph.directedEdge: could not find the "${n}" source node in the graph.`);if(!this._nodes.has(e))throw new W(`Graph.directedEdge: could not find the "${e}" target node in the graph.`);let r=t.out&&t.out[e]||void 0;if(r)return r.key}undirectedEdge(n,e){if(this.type==="directed")return;if(n=""+n,e=""+e,this.multi)throw new Y("Graph.undirectedEdge: this method is irrelevant with multigraphs since there might be multiple edges between source & target. See #.undirectedEdges instead.");let t=this._nodes.get(n);if(!t)throw new W(`Graph.undirectedEdge: could not find the "${n}" source node in the graph.`);if(!this._nodes.has(e))throw new W(`Graph.undirectedEdge: could not find the "${e}" target node in the graph.`);let r=t.undirected&&t.undirected[e]||void 0;if(r)return r.key}edge(n,e){if(this.multi)throw new Y("Graph.edge: this method is irrelevant with multigraphs since there might be multiple edges between source & target. See #.edges instead.");n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.edge: could not find the "${n}" source node in the graph.`);if(!this._nodes.has(e))throw new W(`Graph.edge: could not find the "${e}" target node in the graph.`);let r=t.out&&t.out[e]||t.undirected&&t.undirected[e]||void 0;if(r)return r.key}areDirectedNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areDirectedNeighbors: could not find the "${n}" node in the graph.`);return this.type==="undirected"?!1:e in t.in||e in t.out}areOutNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areOutNeighbors: could not find the "${n}" node in the graph.`);return this.type==="undirected"?!1:e in t.out}areInNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areInNeighbors: could not find the "${n}" node in the graph.`);return this.type==="undirected"?!1:e in t.in}areUndirectedNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areUndirectedNeighbors: could not find the "${n}" node in the graph.`);return this.type==="directed"?!1:e in t.undirected}areNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areNeighbors: could not find the "${n}" node in the graph.`);return this.type!=="undirected"&&(e in t.in||e in t.out)||this.type!=="directed"&&e in t.undirected}areInboundNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areInboundNeighbors: could not find the "${n}" node in the graph.`);return this.type!=="undirected"&&e in t.in||this.type!=="directed"&&e in t.undirected}areOutboundNeighbors(n,e){n=""+n,e=""+e;let t=this._nodes.get(n);if(!t)throw new W(`Graph.areOutboundNeighbors: could not find the "${n}" node in the graph.`);return this.type!=="undirected"&&e in t.out||this.type!=="directed"&&e in t.undirected}inDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.inDegree: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.inDegree}outDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.outDegree: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.outDegree}directedDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.directedDegree: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.inDegree+e.outDegree}undirectedDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.undirectedDegree: could not find the "${n}" node in the graph.`);return this.type==="directed"?0:e.undirectedDegree}inboundDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.inboundDegree: could not find the "${n}" node in the graph.`);let t=0;return this.type!=="directed"&&(t+=e.undirectedDegree),this.type!=="undirected"&&(t+=e.inDegree),t}outboundDegree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.outboundDegree: could not find the "${n}" node in the graph.`);let t=0;return this.type!=="directed"&&(t+=e.undirectedDegree),this.type!=="undirected"&&(t+=e.outDegree),t}degree(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.degree: could not find the "${n}" node in the graph.`);let t=0;return this.type!=="directed"&&(t+=e.undirectedDegree),this.type!=="undirected"&&(t+=e.inDegree+e.outDegree),t}inDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.inDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.inDegree-e.directedLoops}outDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.outDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.outDegree-e.directedLoops}directedDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.directedDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);return this.type==="undirected"?0:e.inDegree+e.outDegree-e.directedLoops*2}undirectedDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.undirectedDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);return this.type==="directed"?0:e.undirectedDegree-e.undirectedLoops*2}inboundDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.inboundDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);let t=0,r=0;return this.type!=="directed"&&(t+=e.undirectedDegree,r+=e.undirectedLoops*2),this.type!=="undirected"&&(t+=e.inDegree,r+=e.directedLoops),t-r}outboundDegreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.outboundDegreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);let t=0,r=0;return this.type!=="directed"&&(t+=e.undirectedDegree,r+=e.undirectedLoops*2),this.type!=="undirected"&&(t+=e.outDegree,r+=e.directedLoops),t-r}degreeWithoutSelfLoops(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.degreeWithoutSelfLoops: could not find the "${n}" node in the graph.`);let t=0,r=0;return this.type!=="directed"&&(t+=e.undirectedDegree,r+=e.undirectedLoops*2),this.type!=="undirected"&&(t+=e.inDegree+e.outDegree,r+=e.directedLoops*2),t-r}source(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.source: could not find the "${n}" edge in the graph.`);return e.source.key}target(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.target: could not find the "${n}" edge in the graph.`);return e.target.key}extremities(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.extremities: could not find the "${n}" edge in the graph.`);return[e.source.key,e.target.key]}opposite(n,e){n=""+n,e=""+e;let t=this._edges.get(e);if(!t)throw new W(`Graph.opposite: could not find the "${e}" edge in the graph.`);let r=t.source.key,i=t.target.key;if(n===r)return i;if(n===i)return r;throw new W(`Graph.opposite: the "${n}" node is not attached to the "${e}" edge (${r}, ${i}).`)}hasExtremity(n,e){n=""+n,e=""+e;let t=this._edges.get(n);if(!t)throw new W(`Graph.hasExtremity: could not find the "${n}" edge in the graph.`);return t.source.key===e||t.target.key===e}isUndirected(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.isUndirected: could not find the "${n}" edge in the graph.`);return e.undirected}isDirected(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.isDirected: could not find the "${n}" edge in the graph.`);return!e.undirected}isSelfLoop(n){n=""+n;let e=this._edges.get(n);if(!e)throw new W(`Graph.isSelfLoop: could not find the "${n}" edge in the graph.`);return e.source===e.target}addNode(n,e){return gu(this,n,e).key}mergeNode(n,e){if(e&&!be(e))throw new U(`Graph.mergeNode: invalid attributes. Expecting an object but got "${e}"`);n=""+n,e=e||{};let t=this._nodes.get(n);return t?(e&&(ge(t.attributes,e),this.emit("nodeAttributesUpdated",{type:"merge",key:n,attributes:t.attributes,data:e})),[n,!1]):(t=new this.NodeDataClass(n,e),this._nodes.set(n,t),this.emit("nodeAdded",{key:n,attributes:e}),[n,!0])}updateNode(n,e){if(e&&typeof e!="function")throw new U(`Graph.updateNode: invalid updater function. Expecting a function but got "${e}"`);n=""+n;let t=this._nodes.get(n);if(t){if(e){let i=t.attributes;t.attributes=e(i),this.emit("nodeAttributesUpdated",{type:"replace",key:n,attributes:t.attributes})}return[n,!1]}let r=e?e({}):{};return t=new this.NodeDataClass(n,r),this._nodes.set(n,t),this.emit("nodeAdded",{key:n,attributes:r}),[n,!0]}dropNode(n){n=""+n;let e=this._nodes.get(n);if(!e)throw new W(`Graph.dropNode: could not find the "${n}" node in the graph.`);let t;if(this.type!=="undirected"){for(let r in e.out){t=e.out[r];do wt(this,t),t=t.next;while(t)}for(let r in e.in){t=e.in[r];do wt(this,t),t=t.next;while(t)}}if(this.type!=="directed")for(let r in e.undirected){t=e.undirected[r];do wt(this,t),t=t.next;while(t)}this._nodes.delete(n),this.emit("nodeDropped",{key:n,attributes:e.attributes})}dropEdge(n){let e;if(arguments.length>1){let t=""+arguments[0],r=""+arguments[1];if(e=we(this,t,r,this.type),!e)throw new W(`Graph.dropEdge: could not find the "${t}" -> "${r}" edge in the graph.`)}else if(n=""+n,e=this._edges.get(n),!e)throw new W(`Graph.dropEdge: could not find the "${n}" edge in the graph.`);return wt(this,e),this}dropDirectedEdge(n,e){if(arguments.length<2)throw new Y("Graph.dropDirectedEdge: it does not make sense to try and drop a directed edge by key. What if the edge with this key is undirected? Use #.dropEdge for this purpose instead.");if(this.multi)throw new Y("Graph.dropDirectedEdge: cannot use a {source,target} combo when dropping an edge in a MultiGraph since we cannot infer the one you want to delete as there could be multiple ones.");n=""+n,e=""+e;let t=we(this,n,e,"directed");if(!t)throw new W(`Graph.dropDirectedEdge: could not find a "${n}" -> "${e}" edge in the graph.`);return wt(this,t),this}dropUndirectedEdge(n,e){if(arguments.length<2)throw new Y("Graph.dropUndirectedEdge: it does not make sense to drop a directed edge by key. What if the edge with this key is undirected? Use #.dropEdge for this purpose instead.");if(this.multi)throw new Y("Graph.dropUndirectedEdge: cannot use a {source,target} combo when dropping an edge in a MultiGraph since we cannot infer the one you want to delete as there could be multiple ones.");let t=we(this,n,e,"undirected");if(!t)throw new W(`Graph.dropUndirectedEdge: could not find a "${n}" -> "${e}" edge in the graph.`);return wt(this,t),this}clear(){this._edges.clear(),this._nodes.clear(),this._resetInstanceCounters(),this.emit("cleared")}clearEdges(){let n=this._nodes.values(),e;for(;e=n.next(),e.done!==!0;)e.value.clear();this._edges.clear(),this._resetInstanceCounters(),this.emit("edgesCleared")}getAttribute(n){return this._attributes[n]}getAttributes(){return this._attributes}hasAttribute(n){return this._attributes.hasOwnProperty(n)}setAttribute(n,e){return this._attributes[n]=e,this.emit("attributesUpdated",{type:"set",attributes:this._attributes,name:n}),this}updateAttribute(n,e){if(typeof e!="function")throw new U("Graph.updateAttribute: updater should be a function.");let t=this._attributes[n];return this._attributes[n]=e(t),this.emit("attributesUpdated",{type:"set",attributes:this._attributes,name:n}),this}removeAttribute(n){return delete this._attributes[n],this.emit("attributesUpdated",{type:"remove",attributes:this._attributes,name:n}),this}replaceAttributes(n){if(!be(n))throw new U("Graph.replaceAttributes: provided attributes are not a plain object.");return this._attributes=n,this.emit("attributesUpdated",{type:"replace",attributes:this._attributes}),this}mergeAttributes(n){if(!be(n))throw new U("Graph.mergeAttributes: provided attributes are not a plain object.");return ge(this._attributes,n),this.emit("attributesUpdated",{type:"merge",attributes:this._attributes,data:n}),this}updateAttributes(n){if(typeof n!="function")throw new U("Graph.updateAttributes: provided updater is not a function.");return this._attributes=n(this._attributes),this.emit("attributesUpdated",{type:"update",attributes:this._attributes}),this}updateEachNodeAttributes(n,e){if(typeof n!="function")throw new U("Graph.updateEachNodeAttributes: expecting an updater function.");if(e&&!ai(e))throw new U("Graph.updateEachNodeAttributes: invalid hints. Expecting an object having the following shape: {attributes?: [string]}");let t=this._nodes.values(),r,i;for(;r=t.next(),r.done!==!0;)i=r.value,i.attributes=n(i.key,i.attributes);this.emit("eachNodeAttributesUpdated",{hints:e||null})}updateEachEdgeAttributes(n,e){if(typeof n!="function")throw new U("Graph.updateEachEdgeAttributes: expecting an updater function.");if(e&&!ai(e))throw new U("Graph.updateEachEdgeAttributes: invalid hints. Expecting an object having the following shape: {attributes?: [string]}");let t=this._edges.values(),r,i,o,s;for(;r=t.next(),r.done!==!0;)i=r.value,o=i.source,s=i.target,i.attributes=n(i.key,i.attributes,o.key,s.key,o.attributes,s.attributes,i.undirected);this.emit("eachEdgeAttributesUpdated",{hints:e||null})}forEachAdjacencyEntry(n){if(typeof n!="function")throw new U("Graph.forEachAdjacencyEntry: expecting a callback.");Hn(!1,!1,!1,this,n)}forEachAdjacencyEntryWithOrphans(n){if(typeof n!="function")throw new U("Graph.forEachAdjacencyEntryWithOrphans: expecting a callback.");Hn(!1,!1,!0,this,n)}forEachAssymetricAdjacencyEntry(n){if(typeof n!="function")throw new U("Graph.forEachAssymetricAdjacencyEntry: expecting a callback.");Hn(!1,!0,!1,this,n)}forEachAssymetricAdjacencyEntryWithOrphans(n){if(typeof n!="function")throw new U("Graph.forEachAssymetricAdjacencyEntryWithOrphans: expecting a callback.");Hn(!1,!0,!0,this,n)}nodes(){return Array.from(this._nodes.keys())}forEachNode(n){if(typeof n!="function")throw new U("Graph.forEachNode: expecting a callback.");let e=this._nodes.values(),t,r;for(;t=e.next(),t.done!==!0;)r=t.value,n(r.key,r.attributes)}findNode(n){if(typeof n!="function")throw new U("Graph.findNode: expecting a callback.");let e=this._nodes.values(),t,r;for(;t=e.next(),t.done!==!0;)if(r=t.value,n(r.key,r.attributes))return r.key}mapNodes(n){if(typeof n!="function")throw new U("Graph.mapNode: expecting a callback.");let e=this._nodes.values(),t,r,i=new Array(this.order),o=0;for(;t=e.next(),t.done!==!0;)r=t.value,i[o++]=n(r.key,r.attributes);return i}someNode(n){if(typeof n!="function")throw new U("Graph.someNode: expecting a callback.");let e=this._nodes.values(),t,r;for(;t=e.next(),t.done!==!0;)if(r=t.value,n(r.key,r.attributes))return!0;return!1}everyNode(n){if(typeof n!="function")throw new U("Graph.everyNode: expecting a callback.");let e=this._nodes.values(),t,r;for(;t=e.next(),t.done!==!0;)if(r=t.value,!n(r.key,r.attributes))return!1;return!0}filterNodes(n){if(typeof n!="function")throw new U("Graph.filterNodes: expecting a callback.");let e=this._nodes.values(),t,r,i=[];for(;t=e.next(),t.done!==!0;)r=t.value,n(r.key,r.attributes)&&i.push(r.key);return i}reduceNodes(n,e){if(typeof n!="function")throw new U("Graph.reduceNodes: expecting a callback.");if(arguments.length<2)throw new U("Graph.reduceNodes: missing initial value. You must provide it because the callback takes more than one argument and we cannot infer the initial value from the first iteration, as you could with a simple array.");let t=e,r=this._nodes.values(),i,o;for(;i=r.next(),i.done!==!0;)o=i.value,t=n(t,o.key,o.attributes);return t}nodeEntries(){let n=this._nodes.values();return{[Symbol.iterator](){return this},next(){let e=n.next();if(e.done)return e;let t=e.value;return{value:{node:t.key,attributes:t.attributes},done:!1}}}}export(){let n=new Array(this._nodes.size),e=0;this._nodes.forEach((r,i)=>{n[e++]=ou(i,r)});let t=new Array(this._edges.size);return e=0,this._edges.forEach((r,i)=>{t[e++]=su(this.type,i,r)}),{options:{type:this.type,multi:this.multi,allowSelfLoops:this.allowSelfLoops},attributes:this.getAttributes(),nodes:n,edges:t}}import(n,e=!1){if(n instanceof a)return n.forEachNode((l,u)=>{e?this.mergeNode(l,u):this.addNode(l,u)}),n.forEachEdge((l,u,d,c,h,f,g)=>{e?g?this.mergeUndirectedEdgeWithKey(l,d,c,u):this.mergeDirectedEdgeWithKey(l,d,c,u):g?this.addUndirectedEdgeWithKey(l,d,c,u):this.addDirectedEdgeWithKey(l,d,c,u)}),this;if(!be(n))throw new U("Graph.import: invalid argument. Expecting a serialized graph or, alternatively, a Graph instance.");if(n.attributes){if(!be(n.attributes))throw new U("Graph.import: invalid attributes. Expecting a plain object.");e?this.mergeAttributes(n.attributes):this.replaceAttributes(n.attributes)}let t,r,i,o,s;if(n.nodes){if(i=n.nodes,!Array.isArray(i))throw new U("Graph.import: invalid nodes. Expecting an array.");for(t=0,r=i.length;t<r;t++){o=i[t],lu(o);let{key:l,attributes:u}=o;e?this.mergeNode(l,u):this.addNode(l,u)}}if(n.edges){let l=!1;if(this.type==="undirected"&&(l=!0),i=n.edges,!Array.isArray(i))throw new U("Graph.import: invalid edges. Expecting an array.");for(t=0,r=i.length;t<r;t++){s=i[t],uu(s);let{source:u,target:d,attributes:c,undirected:h=l}=s,f;"key"in s?(f=e?h?this.mergeUndirectedEdgeWithKey:this.mergeDirectedEdgeWithKey:h?this.addUndirectedEdgeWithKey:this.addDirectedEdgeWithKey,f.call(this,s.key,u,d,c)):(f=e?h?this.mergeUndirectedEdge:this.mergeDirectedEdge:h?this.addUndirectedEdge:this.addDirectedEdge,f.call(this,u,d,c))}}return this}nullCopy(n){let e=new a(ge({},this._options,n));return e.replaceAttributes(ge({},this.getAttributes())),e}emptyCopy(n){let e=this.nullCopy(n);return this._nodes.forEach((t,r)=>{let i=ge({},t.attributes);t=new e.NodeDataClass(r,i),e._nodes.set(r,t)}),e}copy(n){if(n=n||{},typeof n.type=="string"&&n.type!==this.type&&n.type!=="mixed")throw new Y(`Graph.copy: cannot create an incompatible copy from "${this.type}" type to "${n.type}" because this would mean losing information about the current graph.`);if(typeof n.multi=="boolean"&&n.multi!==this.multi&&n.multi!==!0)throw new Y("Graph.copy: cannot create an incompatible copy by downgrading a multi graph to a simple one because this would mean losing information about the current graph.");if(typeof n.allowSelfLoops=="boolean"&&n.allowSelfLoops!==this.allowSelfLoops&&n.allowSelfLoops!==!0)throw new Y("Graph.copy: cannot create an incompatible copy from a graph allowing self loops to one that does not because this would mean losing information about the current graph.");let e=this.emptyCopy(n),t=this._edges.values(),r,i;for(;r=t.next(),r.done!==!0;)i=r.value,vi(e,"copy",!1,i.undirected,i.key,i.source.key,i.target.key,ge({},i.attributes));return e}toJSON(){return this.export()}toString(){return"[object Graph]"}inspect(){let n={};this._nodes.forEach((i,o)=>{n[o]=i.attributes});let e={},t={};this._edges.forEach((i,o)=>{let s=i.undirected?"--":"->",l="",u=i.source.key,d=i.target.key,c;i.undirected&&u>d&&(c=u,u=d,d=c);let h=`(${u})${s}(${d})`;o.startsWith("geid_")?this.multi&&(typeof t[h]>"u"?t[h]=0:t[h]++,l+=`${t[h]}. `):l+=`[${o}]: `,l+=h,e[l]=i.attributes});let r={};for(let i in this)this.hasOwnProperty(i)&&!ri.has(i)&&typeof this[i]!="function"&&typeof i!="symbol"&&(r[i]=this[i]);return r.attributes=this._attributes,r.nodes=n,r.edges=e,De(r,"constructor",this.constructor),r}};typeof Symbol<"u"&&(oe.prototype[Symbol.for("nodejs.util.inspect.custom")]=oe.prototype.inspect);hu.forEach(a=>{["add","merge","update"].forEach(n=>{let e=a.name(n),t=n==="add"?vi:vu;a.generateKey?oe.prototype[e]=function(r,i,o){return t(this,e,!0,(a.type||this.type)==="undirected",null,r,i,o,n==="update")}:oe.prototype[e]=function(r,i,o,s){return t(this,e,!1,(a.type||this.type)==="undirected",r,i,o,s,n==="update")}})});El(oe);Gl(oe);Zl(oe);iu(oe);var $n=class extends oe{constructor(n){let e=ge({type:"directed"},n);if("multi"in e&&e.multi!==!1)throw new U("DirectedGraph.from: inconsistent indication that the graph should be multi in given options!");if(e.type!=="directed")throw new U('DirectedGraph.from: inconsistent "'+e.type+'" type in given options!');super(e)}},Vn=class extends oe{constructor(n){let e=ge({type:"undirected"},n);if("multi"in e&&e.multi!==!1)throw new U("UndirectedGraph.from: inconsistent indication that the graph should be multi in given options!");if(e.type!=="undirected")throw new U('UndirectedGraph.from: inconsistent "'+e.type+'" type in given options!');super(e)}},qn=class extends oe{constructor(n){let e=ge({multi:!0},n);if("multi"in e&&e.multi!==!0)throw new U("MultiGraph.from: inconsistent indication that the graph should be simple in given options!");super(e)}},Xn=class extends oe{constructor(n){let e=ge({type:"directed",multi:!0},n);if("multi"in e&&e.multi!==!0)throw new U("MultiDirectedGraph.from: inconsistent indication that the graph should be simple in given options!");if(e.type!=="directed")throw new U('MultiDirectedGraph.from: inconsistent "'+e.type+'" type in given options!');super(e)}},jn=class extends oe{constructor(n){let e=ge({type:"undirected",multi:!0},n);if("multi"in e&&e.multi!==!0)throw new U("MultiUndirectedGraph.from: inconsistent indication that the graph should be simple in given options!");if(e.type!=="undirected")throw new U('MultiUndirectedGraph.from: inconsistent "'+e.type+'" type in given options!');super(e)}};function Pt(a){a.from=function(n,e){let t=ge({},n.options,e),r=new a(t);return r.import(n),r}}Pt(oe);Pt($n);Pt(Vn);Pt(qn);Pt(Xn);Pt(jn);oe.Graph=oe;oe.DirectedGraph=$n;oe.UndirectedGraph=Vn;oe.MultiGraph=qn;oe.MultiDirectedGraph=Xn;oe.MultiUndirectedGraph=jn;oe.InvalidArgumentsGraphError=U;oe.NotFoundGraphError=W;oe.UsageGraphError=Y;var Ir=Ve(Ci());function ea(a,n){(n==null||n>a.length)&&(n=a.length);for(var e=0,t=Array(n);e<n;e++)t[e]=a[e];return t}function ta(a,n){if(a){if(typeof a=="string")return ea(a,n);var e={}.toString.call(a).slice(8,-1);return e==="Object"&&a.constructor&&(e=a.constructor.name),e==="Map"||e==="Set"?Array.from(a):e==="Arguments"||/^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(e)?ea(a,n):void 0}}function Du(a){if(Array.isArray(a))return a}function wu(a,n){var e=a==null?null:typeof Symbol<"u"&&a[Symbol.iterator]||a["@@iterator"];if(e!=null){var t,r,i,o,s=[],l=!0,u=!1;try{if(i=(e=e.call(a)).next,n===0){if(Object(e)!==e)return;l=!1}else for(;!(l=(t=i.call(e)).done)&&(s.push(t.value),s.length!==n);l=!0);}catch(d){u=!0,r=d}finally{try{if(!l&&e.return!=null&&(o=e.return(),Object(o)!==o))return}finally{if(u)throw r}}return s}}function Lu(){throw new TypeError(`Invalid attempt to destructure non-iterable instance.
In order to be iterable, non-array objects must have a [Symbol.iterator]() method.`)}function te(a,n){return Du(a)||wu(a,n)||ta(a,n)||Lu()}function M(a,n){var e=typeof Symbol<"u"&&a[Symbol.iterator]||a["@@iterator"];if(!e){if(Array.isArray(a)||(e=ta(a))||n&&a&&typeof a.length=="number"){e&&(a=e);var t=0,r=function(){};return{s:r,n:function(){return t>=a.length?{done:!0}:{done:!1,value:a[t++]}},e:function(l){throw l},f:r}}throw new TypeError(`Invalid attempt to iterate non-iterable instance.
In order to be iterable, non-array objects must have a [Symbol.iterator]() method.`)}var i,o=!0,s=!1;return{s:function(){e=e.call(a)},n:function(){var l=e.next();return o=l.done,l},e:function(l){s=!0,i=l},f:function(){try{o||e.return==null||e.return()}finally{if(s)throw i}}}}function Ce(){return Float32Array.of(1,0,0,0,1,0,0,0,1)}function Qn(a,n,e){return a[0]=n,a[4]=typeof e=="number"?e:n,a}function Pi(a,n){var e=Math.sin(n),t=Math.cos(n);return a[0]=t,a[1]=e,a[3]=-e,a[4]=t,a}function ki(a,n,e){return a[6]=n,a[7]=e,a}function nt(a,n){var e=a[0],t=a[1],r=a[2],i=a[3],o=a[4],s=a[5],l=a[6],u=a[7],d=a[8],c=n[0],h=n[1],f=n[2],g=n[3],m=n[4],p=n[5],v=n[6],b=n[7],y=n[8];return a[0]=c*e+h*i+f*l,a[1]=c*t+h*o+f*u,a[2]=c*r+h*s+f*d,a[3]=g*e+m*i+p*l,a[4]=g*t+m*o+p*u,a[5]=g*r+m*s+p*d,a[6]=v*e+b*i+y*l,a[7]=v*t+b*o+y*u,a[8]=v*r+b*s+y*d,a}function qa(a,n){var e=Math.cos(n),t=Math.sin(n);return{x:e*a.x+t*a.y,y:-t*a.x+e*a.y}}function Ft(a,n){var e=arguments.length>2&&arguments[2]!==void 0?arguments[2]:1,t=a[0],r=a[1],i=a[3],o=a[4],s=a[6],l=a[7],u=n.x,d=n.y;return{x:u*t+d*i+s*e,y:u*r+d*o+l*e}}function Cu(a,n){var e=a.height/a.width,t=n.height/n.width;return e<1&&t>1||e>1&&t<1?1:Math.min(Math.max(t,1/t),Math.max(1/e,e))}function at(a,n,e,t,r){var i=a.angle,o=a.ratio,s=a.x,l=a.y,u=n.width,d=n.height,c=Ce(),h=Math.min(u,d)-2*t,f=Cu(n,e);return r?(nt(c,ki(Ce(),s,l)),nt(c,Qn(Ce(),o)),nt(c,Pi(Ce(),i)),nt(c,Qn(Ce(),u/h/2/f,d/h/2/f))):(nt(c,Qn(Ce(),2*(h/u)*f,2*(h/d)*f)),nt(c,Pi(Ce(),-i)),nt(c,Qn(Ce(),1/o)),nt(c,ki(Ce(),-s,-l))),c}function Fi(a,n,e){var t=Ft(a,{x:Math.cos(n.angle),y:Math.sin(n.angle)},0),r=t.x,i=t.y;return 1/Math.sqrt(Math.pow(r,2)+Math.pow(i,2))/e.width}function Xa(a,n,e,t,r){var i=Math.floor(n/r*t),o=Math.floor(a.drawingBufferHeight/r-e/r*t);return[i,o]}var cn={black:"#000000",silver:"#C0C0C0",gray:"#808080",grey:"#808080",white:"#FFFFFF",maroon:"#800000",red:"#FF0000",purple:"#800080",fuchsia:"#FF00FF",green:"#008000",lime:"#00FF00",olive:"#808000",yellow:"#FFFF00",navy:"#000080",blue:"#0000FF",teal:"#008080",aqua:"#00FFFF",darkblue:"#00008B",mediumblue:"#0000CD",darkgreen:"#006400",darkcyan:"#008B8B",deepskyblue:"#00BFFF",darkturquoise:"#00CED1",mediumspringgreen:"#00FA9A",springgreen:"#00FF7F",cyan:"#00FFFF",midnightblue:"#191970",dodgerblue:"#1E90FF",lightseagreen:"#20B2AA",forestgreen:"#228B22",seagreen:"#2E8B57",darkslategray:"#2F4F4F",darkslategrey:"#2F4F4F",limegreen:"#32CD32",mediumseagreen:"#3CB371",turquoise:"#40E0D0",royalblue:"#4169E1",steelblue:"#4682B4",darkslateblue:"#483D8B",mediumturquoise:"#48D1CC",indigo:"#4B0082",darkolivegreen:"#556B2F",cadetblue:"#5F9EA0",cornflowerblue:"#6495ED",rebeccapurple:"#663399",mediumaquamarine:"#66CDAA",dimgray:"#696969",dimgrey:"#696969",slateblue:"#6A5ACD",olivedrab:"#6B8E23",slategray:"#708090",slategrey:"#708090",lightslategray:"#778899",lightslategrey:"#778899",mediumslateblue:"#7B68EE",lawngreen:"#7CFC00",chartreuse:"#7FFF00",aquamarine:"#7FFFD4",skyblue:"#87CEEB",lightskyblue:"#87CEFA",blueviolet:"#8A2BE2",darkred:"#8B0000",darkmagenta:"#8B008B",saddlebrown:"#8B4513",darkseagreen:"#8FBC8F",lightgreen:"#90EE90",mediumpurple:"#9370DB",darkviolet:"#9400D3",palegreen:"#98FB98",darkorchid:"#9932CC",yellowgreen:"#9ACD32",sienna:"#A0522D",brown:"#A52A2A",darkgray:"#A9A9A9",darkgrey:"#A9A9A9",lightblue:"#ADD8E6",greenyellow:"#ADFF2F",paleturquoise:"#AFEEEE",lightsteelblue:"#B0C4DE",powderblue:"#B0E0E6",firebrick:"#B22222",darkgoldenrod:"#B8860B",mediumorchid:"#BA55D3",rosybrown:"#BC8F8F",darkkhaki:"#BDB76B",mediumvioletred:"#C71585",indianred:"#CD5C5C",peru:"#CD853F",chocolate:"#D2691E",tan:"#D2B48C",lightgray:"#D3D3D3",lightgrey:"#D3D3D3",thistle:"#D8BFD8",orchid:"#DA70D6",goldenrod:"#DAA520",palevioletred:"#DB7093",crimson:"#DC143C",gainsboro:"#DCDCDC",plum:"#DDA0DD",burlywood:"#DEB887",lightcyan:"#E0FFFF",lavender:"#E6E6FA",darksalmon:"#E9967A",violet:"#EE82EE",palegoldenrod:"#EEE8AA",lightcoral:"#F08080",khaki:"#F0E68C",aliceblue:"#F0F8FF",honeydew:"#F0FFF0",azure:"#F0FFFF",sandybrown:"#F4A460",wheat:"#F5DEB3",beige:"#F5F5DC",whitesmoke:"#F5F5F5",mintcream:"#F5FFFA",ghostwhite:"#F8F8FF",salmon:"#FA8072",antiquewhite:"#FAEBD7",linen:"#FAF0E6",lightgoldenrodyellow:"#FAFAD2",oldlace:"#FDF5E6",magenta:"#FF00FF",deeppink:"#FF1493",orangered:"#FF4500",tomato:"#FF6347",hotpink:"#FF69B4",coral:"#FF7F50",darkorange:"#FF8C00",lightsalmon:"#FFA07A",orange:"#FFA500",lightpink:"#FFB6C1",pink:"#FFC0CB",gold:"#FFD700",peachpuff:"#FFDAB9",navajowhite:"#FFDEAD",moccasin:"#FFE4B5",bisque:"#FFE4C4",mistyrose:"#FFE4E1",blanchedalmond:"#FFEBCD",papayawhip:"#FFEFD5",lavenderblush:"#FFF0F5",seashell:"#FFF5EE",cornsilk:"#FFF8DC",lemonchiffon:"#FFFACD",floralwhite:"#FFFAF0",snow:"#FFFAFA",lightyellow:"#FFFFE0",ivory:"#FFFFF0"},Ii=new Int8Array(4),Jn=new Int32Array(Ii.buffer,0,1),Gi=new Float32Array(Ii.buffer,0,1),Pu=/^\s*rgba?\s*\(/,ku=/^\s*rgba?\s*\(\s*([0-9]*)\s*,\s*([0-9]*)\s*,\s*([0-9]*)(?:\s*,\s*(.*)?)?\)\s*$/;function na(a){var n=0,e=0,t=0,r=1,i=a.toLowerCase();if(i==="transparent")return{r:0,g:0,b:0,a:0};if(i in cn)return na(cn[i]);if(a[0]==="#")a.length===4?(n=parseInt(a.charAt(1)+a.charAt(1),16),e=parseInt(a.charAt(2)+a.charAt(2),16),t=parseInt(a.charAt(3)+a.charAt(3),16)):(n=parseInt(a.charAt(1)+a.charAt(2),16),e=parseInt(a.charAt(3)+a.charAt(4),16),t=parseInt(a.charAt(5)+a.charAt(6),16)),a.length===9&&(r=parseInt(a.charAt(7)+a.charAt(8),16)/255);else if(Pu.test(a)){var o=a.match(ku);o&&(n=+o[1],e=+o[2],t=+o[3],o[4]&&(r=+o[4]))}return{r:n,g:e,b:t,a:r}}function zi(a){var n=arguments.length>1&&arguments[1]!==void 0?arguments[1]:!1,e=na(a),t=e.r,r=e.g,i=e.b,o=e.a;return n?[t/255*o,r/255*o,i/255*o,o]:[t/255,r/255,i/255,o]}var kt={};for(dn in cn)kt[dn]=Pe(cn[dn]),kt[cn[dn]]=kt[dn];var dn;function Fu(a,n,e,t,r){return Jn[0]=t<<24|e<<16|n<<8|a,r&&(Jn[0]=Jn[0]&4278190079),Gi[0]}function Pe(a){if(a=a.toLowerCase(),typeof kt[a]<"u")return kt[a];var n=na(a),e=n.r,t=n.g,r=n.b,i=n.a;i=i*255|0;var o=Fu(e,t,r,i,!0);return kt[a]=o,o}function rt(a,n){Gi[0]=Pe(a);var e=Jn[0];n&&(e=e|16777216);var t=e&255,r=e>>8&255,i=e>>16&255,o=e>>24&255;return[t,r,i,o]}function It(a){var n=a>>>8&255,e=a>>>16&255,t=a>>>24&255,r=a&255;return(r<<24|t<<16|e<<8|n)>>>0}function ja(a,n,e,t){return(e<<24|n<<16|a<<8|t)>>>0}function Ni(a,n,e,t,r,i){var o=Xa(a,e,t,r,i),s=te(o,2),l=s[0],u=s[1],d=new Uint8Array(4);a.bindFramebuffer(a.FRAMEBUFFER,n),a.readPixels(l,u,1,1,a.RGBA,a.UNSIGNED_BYTE,d);var c=te(d,4),h=c[0],f=c[1],g=c[2],m=c[3];return[h,f,g,m]}function Mi(a){var n=na(a),e=n.r,t=n.g,r=n.b,i=n.a,o=(e/255).toFixed(6),s=(t/255).toFixed(6),l=(r/255).toFixed(6),u=i.toFixed(6);return"vec4(".concat(o,", ").concat(s,", ").concat(l,", ").concat(u,")")}function Iu(a,n){if(typeof a!="object"||!a)return a;var e;if(typeof Symbol<"u"&&(e=a[Symbol.toPrimitive])!==void 0){var t=e.call(a,n||"default");if(typeof t!="object")return t;throw new TypeError("@@toPrimitive must return a primitive value.")}return(n==="string"?String:Number)(a)}function Bi(a){var n=Iu(a,"string");return typeof n=="symbol"?n:n+""}function A(a,n,e){return(n=Bi(n))in a?Object.defineProperty(a,n,{value:e,enumerable:!0,configurable:!0,writable:!0}):a[n]=e,a}function Oi(a,n){var e=Object.keys(a);if(Object.getOwnPropertySymbols){var t=Object.getOwnPropertySymbols(a);n&&(t=t.filter(function(r){return Object.getOwnPropertyDescriptor(a,r).enumerable})),e.push.apply(e,t)}return e}function O(a){for(var n=1;n<arguments.length;n++){var e=arguments[n]!=null?arguments[n]:{};n%2?Oi(Object(e),!0).forEach(function(t){A(a,t,e[t])}):Object.getOwnPropertyDescriptors?Object.defineProperties(a,Object.getOwnPropertyDescriptors(e)):Oi(Object(e)).forEach(function(t){Object.defineProperty(a,t,Object.getOwnPropertyDescriptor(e,t))})}return a}function Q(a,n){if(!(a instanceof n))throw new TypeError("Cannot call a class as a function")}function Wi(a,n){for(var e=0;e<n.length;e++){var t=n[e];t.enumerable=t.enumerable||!1,t.configurable=!0,"value"in t&&(t.writable=!0),Object.defineProperty(a,Bi(t.key),t)}}function J(a,n,e){return n&&Wi(a.prototype,n),e&&Wi(a,e),Object.defineProperty(a,"prototype",{writable:!1}),a}function gt(a){return gt=Object.setPrototypeOf?Object.getPrototypeOf.bind():function(n){return n.__proto__||Object.getPrototypeOf(n)},gt(a)}function Ui(){try{var a=!Boolean.prototype.valueOf.call(Reflect.construct(Boolean,[],function(){}))}catch{}return(Ui=function(){return!!a})()}function Gu(a){if(a===void 0)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return a}function zu(a,n){if(n&&(typeof n=="object"||typeof n=="function"))return n;if(n!==void 0)throw new TypeError("Derived constructors may only return object or undefined");return Gu(a)}function le(a,n,e){return n=gt(n),zu(a,Ui()?Reflect.construct(n,e||[],gt(a).constructor):n.apply(a,e))}function Ya(a,n){return Ya=Object.setPrototypeOf?Object.setPrototypeOf.bind():function(e,t){return e.__proto__=t,e},Ya(a,n)}function ue(a,n){if(typeof n!="function"&&n!==null)throw new TypeError("Super expression must either be null or a function");a.prototype=Object.create(n&&n.prototype,{constructor:{value:a,writable:!0,configurable:!0}}),Object.defineProperty(a,"prototype",{writable:!1}),n&&Ya(a,n)}function Nu(a){if(Array.isArray(a))return ea(a)}function Mu(a){if(typeof Symbol<"u"&&a[Symbol.iterator]!=null||a["@@iterator"]!=null)return Array.from(a)}function Ou(){throw new TypeError(`Invalid attempt to spread non-iterable instance.
In order to be iterable, non-array objects must have a [Symbol.iterator]() method.`)}function V(a){return Nu(a)||Mu(a)||ta(a)||Ou()}function ee(a){"@babel/helpers - typeof";return ee=typeof Symbol=="function"&&typeof Symbol.iterator=="symbol"?function(n){return typeof n}:function(n){return n&&typeof Symbol=="function"&&n.constructor===Symbol&&n!==Symbol.prototype?"symbol":typeof n},ee(a)}function Ne(a){return ee(a)==="object"&&a!==null&&"attribute"in a}function hn(){var a=`
float sdf_circle(vec2 uv, float size) {
  return length(uv) - size;
}
`;return{name:"circle",glsl:a,uniforms:[]}}function Ka(a){var n,e=WebGL2RenderingContext,t=e.UNSIGNED_BYTE,r=(n=a?.color)!==null&&n!==void 0?n:{attribute:"color"};if(!Ne(r)){var i=r,o=`
vec4 layer_fill() {
  return `.concat(Mi(i),`;
}
`);return{name:"fill",uniforms:[],attributes:[],glsl:o}}var s=r.attribute,l=`
vec4 layer_fill(vec4 v_fillColor) {
  return v_fillColor;
}
`;return{name:"fill",uniforms:[],attributes:[{name:"fillColor",size:4,type:t,normalized:!0,source:s}],glsl:l}}function fn(a,n){if(typeof a=="string"){var e=zi(a).map(function(u){return u.toFixed(6)}),t=te(e,4),r=t[0],i=t[1],o=t[2],s=t[3];return{glsl:"vec4(".concat(r,", ").concat(i,", ").concat(o,", ").concat(s,")"),attributes:[],needsNodeColors:!1}}if("node"in a&&a.node)return{glsl:a.node==="source"?"v_sourceColor":"v_targetColor",attributes:[],needsNodeColors:!0};var l=a;return{glsl:"v_".concat(n),attributes:[{name:"a_".concat(n),size:4,type:WebGL2RenderingContext.UNSIGNED_BYTE,normalized:!0,source:l.attribute,defaultValue:l.default}],needsNodeColors:!1}}function Be(a){var n=a?.color;if(n===void 0){var e=`
// Plain solid color layer
vec4 layer_plain(EdgeContext ctx) {
  return v_color;
}
`;return{name:"plain",glsl:e,uniforms:[],attributes:[]}}var t=fn(n,"plainColor"),r=`
// Plain solid color layer
vec4 layer_plain(EdgeContext ctx) {
  return `.concat(t.glsl,`;
}
`);return{name:"plain",glsl:r,uniforms:[],attributes:t.attributes,needsNodeColors:t.needsNodeColors}}function gn(){var a=`
// Position at parameter t \u2208 [0, 1]
vec2 path_straight_position(float t, vec2 source, vec2 target) {
  return mix(source, target, t);
}

// Total length of the path (analytical - more efficient than sampling)
float path_straight_length(vec2 source, vec2 target) {
  return length(target - source);
}
`;return{name:"straight",segments:1,minBodyLengthRatio:0,linearParameterization:!0,glsl:a,uniforms:[],attributes:[]}}function Za(a){var n=a??{},e=n.segments,t=e===void 0?32:e,r=`
const float LOOP_PI = 3.141592653589793;

float loopWorldRadius() {
  float nodeWorldRadius = v_sourceNodeSize * u_correctionRatio / u_sizeRatio;
  return max(v_loopRadius * nodeWorldRadius, 0.001);
}

// Cubic B\xE9zier with P0 = P3 = source.
// Control points extend outward orthogonal to the node surface at exit/entry angles.
vec2 path_loop_position(float t, vec2 source, vec2 target) {
  float R = loopWorldRadius();
  float angle = v_loopAngle + (v_loopFixedOrientation > 0.5 ? u_cameraAngle : 0.0);
  float halfSpread = v_loopSpread * 0.5;

  float exitAngle = angle - halfSpread;
  float entryAngle = angle + halfSpread;

  // Control point distance: at t=0.5 the B\xE9zier reaches 0.75 * cpDist * cos(halfSpread)
  // from source. Solve for cpDist so the loop tip reaches exactly R.
  float cpDist = R / (0.75 * cos(halfSpread));

  vec2 cp1 = source + cpDist * vec2(cos(exitAngle), sin(exitAngle));
  vec2 cp2 = source + cpDist * vec2(cos(entryAngle), sin(entryAngle));

  float u = 1.0 - t;
  vec2 d1 = cp1 - source;
  vec2 d2 = cp2 - source;
  return source + 3.0 * t * u * (u * d1 + t * d2);
}

// Approximate arc length via chord sampling
float path_loop_length(vec2 source, vec2 target) {
  float len = 0.0;
  vec2 prev = path_loop_position(0.0, source, target);
  const int STEPS = 16;
  for (int i = 1; i <= STEPS; i++) {
    float t = float(i) / float(STEPS);
    vec2 cur = path_loop_position(t, source, target);
    len += length(cur - prev);
    prev = cur;
  }
  return len;
}
`;return{name:"loop",segments:t,glsl:r,needsNodeSize:!0,uniforms:[],attributes:[{name:"loopRadius",size:1,type:WebGL2RenderingContext.FLOAT},{name:"loopAngle",size:1,type:WebGL2RenderingContext.FLOAT},{name:"loopSpread",size:1,type:WebGL2RenderingContext.FLOAT},{name:"loopFixedOrientation",size:1,type:WebGL2RenderingContext.FLOAT}],variables:{loopRadius:{type:"number",default:4},loopAngle:{type:"number",default:Math.PI/4},loopSpread:{type:"number",default:80*Math.PI/180},loopFixedOrientation:{type:"number",default:0}},spread:{variable:"loopRadius",compute:function(o){return o+4}}}}var ji=Ve(Dt());function Hi(a){return ee(a)==="object"&&"glsl"in a&&!("attributes"in a)}function $i(a){return ee(a)==="object"&&"glsl"in a&&!("attributes"in a)}var vn={shapes:[hn()],variables:{},layers:[Ka()],label:{},backdrop:{},labelAttachments:{}},Gt={paths:[gn(),Za()],extremities:[],variables:{},layers:[Be()],defaultHead:"none",defaultTail:"none",label:{}},aa=["nodes","topNodes"],ra=["edges","topEdges"],ia=[].concat(ra,aa),Vi={nodes:vn,edges:Gt,depthLayers:V(ia)};var Wu=function(n){return n},Bu=function(n){return n*n},Uu=function(n){return n*(2-n)},Hu=function(n){return(n*=2)<1?.5*n*n:-.5*(--n*(n-2)-1)},$u=function(n){return n*n*n},Vu=function(n){return--n*n*n+1},qu=function(n){return(n*=2)<1?.5*n*n*n:.5*((n-=2)*n*n+2)},Xu=function(n){return n===0?0:Math.pow(2,10*(n-1))},ju=function(n){return n===1?1:1-Math.pow(2,-10*n)},Yu=function(n){return n===0?0:n===1?1:n<.5?Math.pow(2,10*(2*n-1))/2:(2-Math.pow(2,-10*(2*n-1)))/2},Qa={linear:Wu,quadraticIn:Bu,quadraticOut:Uu,quadraticInOut:Hu,cubicIn:$u,cubicOut:Vu,cubicInOut:qu,exponentialIn:Xu,exponentialOut:ju,exponentialInOut:Yu};function zt(a){return a?typeof a=="function"?a:Qa[a]:Qa.linear}function er(a){return ee(a)==="object"&&a!==null&&"attribute"in a}function Yi(a){return typeof a=="function"}function Ki(a){return ee(a)==="object"&&a!==null&&"when"in a&&typeof a.when=="function"&&"then"in a}function Zi(a){return ee(a)==="object"&&a!==null&&"whenState"in a&&"then"in a}function Qi(a){return ee(a)==="object"&&a!==null&&"whenData"in a&&"then"in a}var Ku={isHovered:!1,isLabelHovered:!1,isHidden:!1,isHighlighted:!1,isDragged:!1},Zu={isHovered:!1,isLabelHovered:!1,isHidden:!1,isHighlighted:!1,parallelIndex:0,parallelCount:1},Qu={isIdle:!0,isPanning:!1,isZooming:!1,isDragging:!1,hasHovered:!1,hasHighlighted:!1};function Ji(a){return O(O({},Ku),a)}function eo(a){return O(O({},Zu),a)}function tr(a){return O(O({},Qu),a)}var Ju={x:{attribute:"x"},y:{attribute:"y"},size:{whenState:"isHovered",then:{attribute:"size",defaultValue:12},else:{attribute:"size",defaultValue:10}},color:{attribute:"color",defaultValue:"#666"},label:{attribute:"label"},visibility:{whenState:"isHidden",then:"hidden",else:"visible"},labelVisibility:{whenState:"isHovered",then:"visible",else:"auto"},backdropVisibility:{whenState:"isHovered",then:"visible",else:"hidden"},backdropColor:"#ffffff",backdropShadowColor:"rgba(0, 0, 0, 0.5)",backdropShadowBlur:12,backdropPadding:6},ed={size:{attribute:"size",defaultValue:1},color:{attribute:"color",defaultValue:"#ccc"},label:{attribute:"label"},visibility:{whenState:"isHidden",then:"hidden",else:"visible"}};var sa={nodes:O(O({},Ju),{},{depth:{whenState:"isHovered",then:"topNodes",else:"nodes"}}),edges:O(O({},ed),{},{depth:{whenState:["isHighlighted","isHovered"],then:"topEdges",else:"edges"}})};function td(a){return"min"in a||"max"in a||"minValue"in a||"maxValue"in a||"easing"in a}function nd(a){return"dict"in a}function la(a,n){return typeof a=="string"?n[a]===!0:Array.isArray(a)?a.every(function(e){return n[e]===!0}):ee(a)==="object"&&a!==null?Object.entries(a).every(function(e){var t=te(e,2),r=t[0],i=t[1];return n[r]===i}):!1}function ad(a,n){var e=n[a.attribute];return e===void 0?a.defaultValue:e}function rd(a,n,e){var t,r,i,o,s=n[a.attribute];if(s===void 0)return a.defaultValue;var l=Number(s);if(isNaN(l))return a.defaultValue;if(a.min===void 0&&a.max===void 0)return l;var u=(t=a.minValue)!==null&&t!==void 0?t:l,d=(r=a.maxValue)!==null&&r!==void 0?r:l;if(d===u){var c;return(c=a.min)!==null&&c!==void 0?c:l}var h=(l-u)/(d-u);h=Math.max(0,Math.min(1,h));var f=zt(a.easing);h=f(h);var g=(i=a.min)!==null&&i!==void 0?i:0,m=(o=a.max)!==null&&o!==void 0?o:1;return g+h*(m-g)}function id(a,n){var e=n[a.attribute];if(e===void 0)return a.defaultValue;var t=String(e);return t in a.dict?a.dict[t]:a.defaultValue}function od(a,n,e){return nd(a)?id(a,n):td(a)?rd(a,n):ad(a,n)}function to(a,n){return typeof a=="string"?!!n[a]:Array.isArray(a)?a.every(function(e){return!!n[e]}):ee(a)==="object"&&a!==null?Object.entries(a).every(function(e){var t=te(e,2),r=t[0],i=t[1];return n[r]===i}):!1}function oa(a,n,e,t,r,i){if(a==null)return i;if(ee(a)!=="object"&&typeof a!="function")return a;if(Ki(a)){var o=a.when(n,e,t,r)?a.then:a.else;return o===void 0?i:oa(o,n,e,t,r,i)}if(Zi(a)){var s=la(a.whenState,e)?a.then:a.else;return s===void 0?i:oa(s,n,e,t,r,i)}if(Qi(a)){var l=to(a.whenData,n)?a.then:a.else;return l===void 0?i:oa(l,n,e,t,r,i)}if(Yi(a)){var u=a(n,e,t,r);return u??i}if(er(a)){var d=od(a,n);return d??i}return a}function Me(a){if(a==null)return"static";if(Ki(a))return"graph-state";if(Zi(a)){var n=Me(a.then),e=a.else!==void 0?Me(a.else):"static";return ke("item-state",ke(n,e))}if(Qi(a)){var t=Me(a.then),r=a.else!==void 0?Me(a.else):"static";return ke(t,r)}return Yi(a)?"graph-state":(er(a),"static")}function ke(a,n){return a==="graph-state"||n==="graph-state"?"graph-state":a==="item-state"||n==="item-state"?"item-state":"static"}function nr(a){if(!a)return{dependency:"static",xAttribute:null,yAttribute:null};var n=Array.isArray(a)?a:[a],e="static",t=null,r=null,i=M(n),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;if("matchData"in s&&"cases"in s)for(var l=s.cases,u=0,d=Object.values(l);u<d.length;u++)for(var c=d[u],h=0,f=Object.values(c);h<f.length;h++){var g=f[h];e=ke(e,Me(g))}else if("matchState"in s&&"cases"in s){e=ke(e,"item-state");for(var m=s.cases,p=0,v=Object.values(m);p<v.length;p++)for(var b=v[p],y=0,_=Object.values(b);y<_.length;y++){var x=_[y];e=ke(e,Me(x))}}else if("when"in s&&"then"in s)e="graph-state";else if("whenState"in s){e=ke(e,"item-state");var T=s.then;if(T&&ee(T)==="object")for(var R=0,E=Object.values(T);R<E.length;R++){var S=E[R];e=ke(e,Me(S))}var w=s.else;if(w&&ee(w)==="object")for(var F=0,D=Object.values(w);F<D.length;F++){var P=D[F];e=ke(e,Me(P))}}else if("whenData"in s){var L=s.then;if(L&&ee(L)==="object")for(var I=0,z=Object.values(L);I<z.length;I++){var G=z[I];e=ke(e,Me(G))}var k=s.else;if(k&&ee(k)==="object")for(var C=0,N=Object.values(k);C<N.length;C++){var $=N[C];e=ke(e,Me($))}}else for(var H=0,Z=Object.entries(s);H<Z.length;H++){var X=te(Z[H],2),K=X[0],Ie=X[1];if(!rr.has(K)&&(e=ke(e,Me(Ie)),(K==="x"||K==="y")&&er(Ie))){var Te=Ie.attribute;K==="x"&&!t&&(t=Te),K==="y"&&!r&&(r=Te)}}}}catch($e){i.e($e)}finally{i.f()}return{dependency:e,xAttribute:t,yAttribute:r}}var Ke={size:10,color:"#666",opacity:1,shape:"circle",rotationAlignment:"viewport",labelRotationAlignment:"viewport",visibility:"visible",depth:"nodes",zIndex:0,label:"",labelColor:"#000",labelSize:12,labelFont:"sans-serif",labelVisibility:"auto",labelPosition:"right",labelAngle:0,labelDepth:"nodes",backdropVisibility:"hidden",backdropColor:"transparent",backdropShadowColor:"transparent",backdropShadowBlur:0,backdropPadding:0,backdropBorderColor:"transparent",backdropBorderWidth:0,backdropCornerRadius:0,backdropLabelPadding:-1,backdropArea:"both",labelAttachment:null,labelAttachmentPlacement:"below"},ar={size:1,color:"#ccc",opacity:1,path:"straight",selfLoopPath:"loop",parallelSpread:.25,tail:"none",head:"none",visibility:"visible",depth:"edges",zIndex:0,label:"",labelColor:"#666",labelVisibility:"auto",labelDepth:"edges"},rr=new Set(["when","whenState","whenData","then","else"]),qi=Object.keys(Ke),sd=Object.values(Ke),Xi=Object.keys(ar),ld=Object.values(ar);function Nt(a,n,e,t,r,i,o){for(var s in n){var l;if(!rr.has(s)){var u=(l=a[s])!==null&&l!==void 0?l:o[s];a[s]=oa(n[s],e,t,r,i,u)}}"depth"in n&&!("labelDepth"in n)&&(a.labelDepth=a.depth)}function no(a,n,e,t,r,i,o){var s=M(n),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;if("matchData"in u&&"cases"in u){var d,c=String((d=e[u.matchData])!==null&&d!==void 0?d:""),h=u.cases;c in h&&Nt(a,h[c],e,t,r,i,o)}else if("matchState"in u&&"cases"in u){var f,g=String((f=t[u.matchState])!==null&&f!==void 0?f:""),m=u.cases;g in m&&Nt(a,m[g],e,t,r,i,o)}else if("when"in u&&"then"in u){var p=u.when;if(!p(e,t,r,i))continue;Nt(a,u.then,e,t,r,i,o)}else if("whenState"in u&&"then"in u){if(!la(u.whenState,t))continue;Nt(a,u.then,e,t,r,i,o)}else if("whenData"in u&&"then"in u){if(!to(u.whenData,e))continue;Nt(a,u.then,e,t,r,i,o)}else Nt(a,u,e,t,r,i,o)}}catch(v){s.e(v)}finally{s.f()}}function ir(a,n,e,t,r,i){for(var o=i||{},s=o,l=0,u=qi.length;l<u;l++)s[qi[l]]=sd[l];if(s.x=void 0,s.y=void 0,s.labelBackgroundColor=void 0,s.labelBackgroundPadding=void 0,s.labelCursor=void 0,!a){var d,c,h,f,g;return s.x=(d=n.x)!==null&&d!==void 0?d:0,s.y=(c=n.y)!==null&&c!==void 0?c:0,o.size=(h=n.size)!==null&&h!==void 0?h:10,o.color=(f=n.color)!==null&&f!==void 0?f:"#666",o.label=(g=n.label)!==null&&g!==void 0?g:"",o}var m=Array.isArray(a)?a:[a];return no(s,m,n,e,t,r,Ke),o}function or(a,n,e,t,r,i){for(var o=i||{},s=o,l=0,u=Xi.length;l<u;l++)s[Xi[l]]=ld[l];if(!a){var d,c,h;return o.size=(d=n.size)!==null&&d!==void 0?d:1,o.color=(c=n.color)!==null&&c!==void 0?c:"#ccc",o.label=(h=n.label)!==null&&h!==void 0?h:"",o}var f=Array.isArray(a)?a:[a];return no(s,f,n,e,t,r,ar),typeof s.labelPosition=="number"&&(s.labelPosition=void 0),o}function ud(a,n,e){var t,r;if(a==null)return e;if(typeof a=="function")return(t=a(n))!==null&&t!==void 0?t:e;if(ee(a)==="object"&&"when"in a){var i,o=a,s=o.when(n),l=s?o.then:o.else;return l===void 0?e:typeof l=="function"?(i=l(n))!==null&&i!==void 0?i:e:l??e}if(ee(a)==="object"&&"whenState"in a){var u,d=a,c=la(d.whenState,n),h=c?d.then:d.else;return h===void 0?e:typeof h=="function"?(u=h(n))!==null&&u!==void 0?u:e:h??e}return(r=a)!==null&&r!==void 0?r:e}function sr(a,n){var e={};if(!a)return e;var t=Array.isArray(a)?a:[a],r=M(t),i;try{for(r.s();!(i=r.n()).done;){var o=i.value;if("when"in o&&"then"in o){var s=o.when(n),l=s?o.then:o.else;l&&ee(l)==="object"&&Ja(e,l,n)}else if("whenState"in o&&"then"in o){var u=la(o.whenState,n),d=u?o.then:o.else;d&&ee(d)==="object"&&Ja(e,d,n)}else Ja(e,o,n)}}catch(c){r.e(c)}finally{r.f()}return e}function Ja(a,n,e){for(var t=0,r=Object.entries(n);t<r.length;t++){var i=te(r[t],2),o=i[0],s=i[1];rr.has(o)||(a[o]=ud(s,e))}}var ua=function(a){function n(){var e;return Q(this,n),e=le(this,n),e.rawEmitter=e,e}return ue(n,a),J(n)}(ji.EventEmitter);var ao=Vi;function lr(a,n){var e=n.size;if(e!==0){var t=a.length;a.length+=e;var r=0;n.forEach(function(i){a[t+r]=i,r++})}}function ro(a){a=a||{};for(var n=0,e=arguments.length<=1?0:arguments.length-1;n<e;n++){var t=n+1<1||arguments.length<=n+1?void 0:arguments[n+1];t&&Object.assign(a,t)}return a}function Mt(a,n){for(var e in n)if(Object.prototype.hasOwnProperty.call(n,e)&&n[e]!==a[e])return!0;return!1}function io(a,n){var e=a,t=n;for(var r in e)if(Object.prototype.hasOwnProperty.call(e,r)&&e[r]!==t[r])return!1;for(var i in t)if(Object.prototype.hasOwnProperty.call(t,i)&&t[i]!==e[i])return!1;return!0}function vt(a,n,e){e?a.add(n):a.delete(n)}var oo=Ve(sn());var da={easing:"quadraticInOut",duration:150};function ur(a,n,e,t){var r=Object.assign({},da,e),i=zt(r.easing),o=Date.now(),s={};for(var l in n){var u=n[l];s[l]={};for(var d in u)s[l][d]=a.getNodeAttribute(l,d)}var c=null,h=function(){c=null;var g=(Date.now()-o)/r.duration;if(g>=1){for(var m in n){var p=n[m];for(var v in p)a.setNodeAttribute(m,v,p[v])}typeof t=="function"&&t();return}g=i(g);for(var b in n){var y=n[b],_=s[b];for(var x in y)a.setNodeAttribute(b,x,y[x]*g+_[x]*(1-g))}c=requestAnimationFrame(h)};return h(),function(){c&&cancelAnimationFrame(c)}}function Ze(a){return a.labelVisibility==="visible"&&a.visibility!=="hidden"}function ca(a){return a.backdropVisibility==="visible"&&a.visibility!=="hidden"}function pn(a){return[a.rotationAlignment==="graph"?1:0,a.labelRotationAlignment==="graph"?1:0]}function ha(a,n,e){var t=a[n];if(t)for(var r=0;r<t.length;r++){var i=t[r];if(!(e<i.offset||e>=i.offset+i.count)){if(i.count===1)t.splice(r,1);else if(e===i.offset)i.offset++,i.count--;else if(e===i.offset+i.count-1)i.count--;else{var o=e+1,s=i.offset+i.count-o;i.count=e-i.offset,t.splice(r+1,0,{offset:o,count:s})}return}}}function fa(a,n,e){if(!a[n]){a[n]=[{offset:e,count:1}];return}for(var t=a[n],r=t.length,i=0;i<t.length;i++)if(e<t[i].offset){r=i;break}var o=r>0?t[r-1]:null,s=r<t.length?t[r]:null,l=o&&o.offset+o.count===e,u=s&&e+1===s.offset;l&&u?(o.count+=1+s.count,t.splice(r,1)):l?o.count++:u?(s.offset--,s.count++):t.splice(r,0,{offset:e,count:1})}function dr(a){if(!(0,oo.default)(a))throw new Error("Sigma: invalid graph instance.")}function mn(a){var n=te(a.x,2),e=n[0],t=n[1],r=te(a.y,2),i=r[0],o=r[1],s=Math.max(t-e,o-i),l=(t+e)/2,u=(o+i)/2;(s===0||Math.abs(s)===1/0||isNaN(s))&&(s=1),isNaN(l)&&(l=0),isNaN(u)&&(u=0);var d=function(h){return{x:.5+(h.x-l)/s,y:.5+(h.y-u)/s}};return d.applyTo=function(c){c.x=.5+(c.x-l)/s,c.y=.5+(c.y-u)/s},d.inverse=function(c){return{x:l+s*(c.x-.5),y:u+s*(c.y-.5)}},d.ratio=s,d}var ga={hideEdgesOnMove:!1,hideLabelsOnMove:!1,renderLabels:!0,renderEdgeLabels:!1,edgeLabelAnchors:"nodeLabels",enableEdgeEvents:!1,nodeLabelEvents:!1,edgeLabelEvents:!1,pickingDownSizingRatio:2,nodePickingPadding:0,edgePickingPadding:4,labelPickingPadding:10,stagePadding:30,minEdgeThickness:1.7,antiAliasingFeather:1,antialiasEdges:!0,antialiasNodes:!0,dragTimeout:100,draggedEventsTolerance:3,inertiaDuration:200,inertiaRatio:3,zoomDuration:250,zoomingRatio:1.7,doubleClickTimeout:300,doubleClickZoomingRatio:2.2,doubleClickZoomingDuration:200,tapMoveTolerance:10,zoomToSizeRatioFunction:Math.sqrt,itemSizesReference:"positions",autoRescale:!0,autoRescaleContent:"positions",enableNodeDrag:!1,getDraggedNodes:function(n){return[n]},dragPositionToAttributes:null,labelDensity:1,labelGridCellSize:100,labelRenderedSizeThreshold:6,labelPixelSnapping:!0,minCameraRatio:null,maxCameraRatio:null,enableCameraZooming:!0,enableCameraPanning:!0,enableCameraRotation:!0,enableCameraMouseRotation:!0,cameraPanBoundaries:null,gestureTarget:"graph",sharedGestureWheelMessage:"Use Ctrl + scroll to zoom the graph",sharedGestureAppleWheelMessage:"Use \u2318 + scroll to zoom the graph",sharedGestureTouchMessage:"Use two fingers to move the graph",allowInvalidContainer:!1,DEBUG_displayPickingLayer:!1,DEBUG_logShaders:!1,DEBUG_logRenderStats:!1,DEBUG_gpuTimerQueries:!1};function va(a){if(typeof a.labelDensity!="number"||a.labelDensity<0)throw new Error("Settings: invalid `labelDensity`. Expecting a positive number.");var n=a.minCameraRatio,e=a.maxCameraRatio;if(typeof n=="number"&&typeof e=="number"&&e<n)throw new Error("Settings: invalid camera ratio boundaries. Expecting `maxCameraRatio` to be greater than `minCameraRatio`.")}function so(a){return ro({},ga,a)}var dd=new Set(["italic","oblique"]),cd=new Set(["bold","bolder","lighter"]);function pa(a){for(var n="normal",e="normal",t=a.trim(),r=t.split(/\s+/),i=0,o=0;o<r.length;o++){var s=r[o].toLowerCase();if(dd.has(s))e=s,i=o+1;else if(cd.has(s)||/^\d{3}$/.test(s))n=s,i=o+1;else if(s==="normal")i=o+1;else break}var l=r.slice(i).join(" ");return{family:l||t,weight:n,style:e}}function Ot(a,n,e){var t=document.createElement(a);if(n)for(var r in n)t.style[r]=n[r];if(e)for(var i in e)t.setAttribute(i,e[i]);return t}function bn(){return typeof window.devicePixelRatio<"u"?window.devicePixelRatio:1}var bo=Ve(Dt());function hd(a){var n=a.type===WebGL2RenderingContext.FLOAT&&!a.normalized,e=a.type===WebGL2RenderingContext.UNSIGNED_BYTE&&a.size===4&&a.normalized;if(!n&&!e)throw new Error('Attribute "'.concat(a.name,'" is invalid: only non-normalized FLOAT and normalized UNSIGNED_BYTE with size 4 are supported.'));return a.normalized?1:a.size}function cr(a){var n=0;return a.forEach(function(e){return n+=hd(e)}),n}function yo(a,n,e){var t=a==="VERTEX"?n.VERTEX_SHADER:n.FRAGMENT_SHADER,r=n.createShader(t);if(r===null)throw new Error("loadShader: error while creating the shader");n.shaderSource(r,e),n.compileShader(r);var i=n.getShaderParameter(r,n.COMPILE_STATUS);if(!i){var o=n.getShaderInfoLog(r);throw n.deleteShader(r),new Error(`loadShader: error while compiling the shader:
`.concat(o,`
`).concat(e))}return r}function fr(a,n){return yo("VERTEX",a,n)}function gr(a,n){return yo("FRAGMENT",a,n)}function vr(a,n){var e=a.createProgram();if(e===null)throw new Error("loadProgram: error while creating the program.");var t,r;for(t=0,r=n.length;t<r;t++)a.attachShader(e,n[t]);a.linkProgram(e);var i=a.getProgramParameter(e,a.LINK_STATUS);if(!i){var o=a.getProgramInfoLog(e);throw a.deleteProgram(e),new Error("loadProgram: error while linking the program: ".concat(o))}return e}function lo(a){var n=a.gl,e=a.buffer,t=a.program,r=a.vertexShader,i=a.fragmentShader;n.deleteShader(r),n.deleteShader(i),n.deleteProgram(t),n.deleteBuffer(e)}function he(a){return a%1===0?a.toFixed(1):a.toString()}var Ta=new Map,xo=new Map,fd=0;function _o(a,n){var e,t=(e=a.variables)===null||e===void 0||(e=e[n.source||n.name.replace(/^a_/,"")])===null||e===void 0?void 0:e.default,r=typeof t=="number"?t:typeof n.defaultValue=="number"?n.defaultValue:0;return he(r)}function Sa(a,n,e){var t,r=arguments.length>3&&arguments[3]!==void 0?arguments[3]:function(o){return"v_".concat(o.name.replace(/^a_/,""))},i=[n,e].concat(V(a.uniforms.filter(function(o){return o.type==="float"}).map(function(o){var s;return he((s=o.value)!==null&&s!==void 0?s:0)})),V(((t=a.attributes)!==null&&t!==void 0?t:[]).map(r)));return"sdf_".concat(a.name,"(").concat(i.join(", "),")")}function gd(a){var n,e=a.name,t=a.uniforms.filter(function(o){return o.type==="float"&&o.value!==void 0&&o.value!==0}).map(function(o){return"".concat(o.name.replace("u_",""),"=").concat(o.value)}).sort(),r=((n=a.attributes)!==null&&n!==void 0?n:[]).map(function(o){var s;return"".concat(o.name,"@").concat((s=o.source)!==null&&s!==void 0?s:"","=").concat(_o(a,o))}),i=[].concat(V(t),V(r));return i.length>0&&(e+="#"+i.join("#")),e}function vd(a){var n=gd(a);if(!Ta.has(n)){var e={},t=M(a.uniforms),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;i.type==="float"&&i.value!==void 0&&(e[i.name]=i.value)}}catch(o){t.e(o)}finally{t.f()}Ta.set(n,{shape:a,uniformValues:e,slug:n}),xo.set(n,fd++)}return n}function Sn(a){var n;return(n=xo.get(a))!==null&&n!==void 0?n:-1}function To(a){var n=[],e=new Set,t=new Set,r=/mat2 rotate2D\(float angle\)\s*\{[^}]+\}/,i=M(a),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;if(!t.has(s.name)){t.add(s.name);var l=s.glsl;r.test(l)&&(e.has("rotate2D")?l=l.replace(r,""):e.add("rotate2D")),n.push(l)}}}catch(u){i.e(u)}finally{i.f()}return n.join(`
`)}function pd(){return To(Array.from(Ta.values()).map(function(a){return a.shape}))}function md(a){var n=Array.from(Ta.entries());if(n.length===0)return`
float querySDF(int shapeId, vec2 uv, float size) {
  return length(uv) - size;
}
`;var e=n.map(function(t,r){var i=te(t,2),o=i[0],s=i[1].shape,l=Sa(s,"uv","size",function(u){var d=u.name.replace(/^a_/,"");return a!=null&&a.has(d)?"g_".concat(d):_o(s,u)});return"    case ".concat(r,": return ").concat(l,"; // ").concat(o)}).join(`
`);return`
float querySDF(int shapeId, vec2 uv, float size) {
  switch (shapeId) {
`.concat(e,`
    default: return length(uv) - size;
  }
}
`)}function pr(a){return To(a)}function En(a){return V(new Map(a.flatMap(function(n){return n.uniforms}).map(function(n){return[n.name,n]})).values())}function bd(a,n){if(a.length===0)return`
void queryNodeSDF(int shapeId, vec2 uv, float size) {
  context.sdf = length(uv) - size;
  context.inradiusFactor = 1.0;
}
`;var e=function(c){return Sa(c,"uv","size")},t=function(c){var h,f;return(h=c.inradiusFactorGLSL)!==null&&h!==void 0?h:he((f=c.inradiusFactor)!==null&&f!==void 0?f:1)};if(a.length===1){var r=a[0];return`
void queryNodeSDF(int shapeId, vec2 uv, float size) {
  context.sdf = `.concat(e(r),`;
  context.inradiusFactor = `).concat(t(r),`;
}
`)}var i=a.map(function(d,c){return"    case ".concat(c,": // ").concat(d.name,`
      context.sdf = `).concat(e(d),`;
      context.inradiusFactor = `).concat(t(d),`;
      break;`)}).join(`
`),o=a[0],s="",l="shapeId";if(n&&n.length>1){var u=n.map(function(d,c){return"    case ".concat(d,": return ").concat(c,"; // ").concat(a[c].name)}).join(`
`);s=`
int globalToLocalShapeId(int globalId) {
  switch (globalId) {
`.concat(u,`
    default: return 0;
  }
}
`),l="globalToLocalShapeId(shapeId)"}return"".concat(s,`
void queryNodeSDF(int shapeId, vec2 uv, float size) {
  switch (`).concat(l,`) {
`).concat(i,`
    default:
      context.sdf = `).concat(e(o),`;
      context.inradiusFactor = `).concat(t(o),`;
  }
}
`)}var Bt={right:0,left:1,above:2,below:3,over:4},Ut=5,mr=3,So=`
float matrixScaleX = length(vec2(u_matrix[0][0], u_matrix[1][0]));
float nodeRadiusGraphSpace = nodeSize * u_correctionRatio / u_sizeRatio * 2.0;
float nodeRadiusNDC = nodeRadiusGraphSpace * matrixScaleX;
float nodeRadiusPixels = nodeRadiusNDC * u_resolution.x / 2.0;
`,Eo=`
mat2 rotate2D(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return mat2(c, -s, s, c);
}
`,Ro=`
vec2 getLabelDirection(float positionMode) {
  if (positionMode < 0.5) return vec2(1.0, 0.0);   // Right
  if (positionMode < 1.5) return vec2(-1.0, 0.0);  // Left
  if (positionMode < 2.5) return vec2(0.0, -1.0);  // Above
  if (positionMode < 3.5) return vec2(0.0, 1.0);   // Below
  return vec2(0.0);                                 // Over (centered)
}
`,yd=`
float sdfBox(vec2 p, vec2 halfSize) {
  vec2 d = abs(p) - halfSize;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
`,xd=`
float sdfRotatedBox(vec2 p, vec2 halfSize, float angle) {
  float c = cos(-angle);
  float s = sin(-angle);
  vec2 rotatedP = mat2(c, -s, s, c) * p;
  return sdfBox(rotatedP, halfSize);
}
`,_d=`
float sdfRoundedBox(vec2 p, vec2 halfSize, float radius) {
  vec2 d = abs(p) - halfSize + radius;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}
`,Td=`
float sdfRoundedRotatedBox(vec2 p, vec2 halfSize, float angle, float radius) {
  float c = cos(-angle);
  float s = sin(-angle);
  vec2 rotatedP = mat2(c, -s, s, c) * p;
  return sdfRoundedBox(rotatedP, halfSize, radius);
}
`,Ao=`
vec2 labelBoxCenter(float positionMode, float labelStart, vec2 halfSize, float textHalfY) {
  if (positionMode < 0.5) return vec2(labelStart + halfSize.x, 0.0);    // right
  if (positionMode < 1.5) return vec2(-(labelStart + halfSize.x), 0.0); // left
  if (positionMode < 2.5) return vec2(0.0, -(labelStart + textHalfY));  // above
  if (positionMode < 3.5) return vec2(0.0, labelStart + textHalfY);     // below
  return vec2(0.0);                                                     // over
}
`,br=2,Qe=`
vec4 readNodeData(sampler2D nodeDataTexture, int nodeDataTextureWidth, int nodeIndex) {
  int t = nodeIndex * `.concat(br,`;
  ivec2 coord = ivec2(t % nodeDataTextureWidth, t / nodeDataTextureWidth);
  return texelFetch(nodeDataTexture, coord, 0);
}
`),mt=`
vec4 readNodeFlags(sampler2D nodeDataTexture, int nodeDataTextureWidth, int nodeIndex) {
  int t = nodeIndex * `.concat(br,` + 1;
  ivec2 coord = ivec2(t % nodeDataTextureWidth, t / nodeDataTextureWidth);
  return texelFetch(nodeDataTexture, coord, 0);
}
`),Sd=`
vec4 readNodeColor(sampler2D nodeDataTexture, int nodeDataTextureWidth, int nodeIndex) {
  int t = nodeIndex * `.concat(br,` + 1;
  ivec2 coord = ivec2(t % nodeDataTextureWidth, t / nodeDataTextureWidth);
  vec4 texel = texelFetch(nodeDataTexture, coord, 0);
  float r = floor(texel.b / 65536.0);
  float g = floor(mod(texel.b, 65536.0) / 256.0);
  float b = mod(texel.b, 256.0);
  return vec4(r / 255.0, g / 255.0, b / 255.0, texel.a);
}
`),Ht=`
vec4 readFrameTexel(sampler2D frameTexture, int frameTextureWidth, int index) {
  ivec2 coord = ivec2(index % frameTextureWidth, index / frameTextureWidth);
  return texelFetch(frameTexture, coord, 0);
}
`;function Ed(a,n){var e=function(o){return Sa(o,"uv","size")};if(a.length===1)return{code:uo(e(a[0])),multiShape:!1};var t=a.map(function(i,o){return"    case ".concat(n?n[o]:o,": return ").concat(e(i),";")}).join(`
`),r=`
float queryShapeSDF(int shapeId, vec2 uv, float size) {
  switch (shapeId) {
`.concat(t,`
    default: return `).concat(e(a[0]),`;
  }
}
int g_shapeId;
`).concat(uo("queryShapeSDF(g_shapeId, uv, size)"),`
`);return{code:r,multiShape:!0}}function uo(a){return`
float findEdgeDistance(vec2 direction, float size) {
  float lo = 0.0, hi = 2.0;
  for (int i = 0; i < 8; i++) {
    float mid = (lo + hi) * 0.5;
    vec2 uv = direction * mid;
    if (`.concat(a,` < 0.0) lo = mid; else hi = mid;
  }
  return (lo + hi) * 0.5;
}
`)}function Rd(a,n){for(;!{}.hasOwnProperty.call(a,n)&&(a=gt(a))!==null;);return a}function hr(){return hr=typeof Reflect<"u"&&Reflect.get?Reflect.get.bind():function(a,n,e){var t=Rd(a,n);if(t){var r=Object.getOwnPropertyDescriptor(t,n);return r.get?r.get.call(arguments.length<3?a:e):r.value}},hr.apply(null,arguments)}function ve(a,n,e,t){var r=hr(gt(1&t?a.prototype:a),n,e);return 2&t&&typeof r=="function"?function(i){return r.apply(e,i)}:r}var Ad=1024,Dd=1.5,Do=-1,Ea=function(){function a(n,e){var t=arguments.length>2&&arguments[2]!==void 0?arguments[2]:Ad;Q(this,a),A(this,"texture",null),A(this,"dirty",!1),A(this,"dirtyRangeStart",1/0),A(this,"dirtyRangeEnd",-1),A(this,"indexMap",new Map),A(this,"freeIndices",[]),A(this,"nextIndex",0),this.gl=n,this.maxTextureSize=n.getParameter(n.MAX_TEXTURE_SIZE),this.TEXELS_PER_ITEM=e,this.capacity=this.roundUpToPowerOfTwo(t);var r=this.computeTextureDimensions(this.capacity);this.textureWidth=r.width,this.textureHeight=r.height,this.data=new Float32Array(this.textureWidth*this.textureHeight*4),this.createTexture()}return J(a,[{key:"computeTextureDimensions",value:function(e){var t=e*this.TEXELS_PER_ITEM,r=Math.min(t,this.maxTextureSize),i=Math.ceil(t/r);return{width:r,height:i}}},{key:"roundUpToPowerOfTwo",value:function(e){return Math.pow(2,Math.ceil(Math.log2(Math.max(1,e))))}},{key:"createTexture",value:function(){var e=this.gl;this.texture=e.createTexture(),e.activeTexture(e.TEXTURE0),e.bindTexture(e.TEXTURE_2D,this.texture),e.texImage2D(e.TEXTURE_2D,0,e.RGBA32F,this.textureWidth,this.textureHeight,0,e.RGBA,e.FLOAT,this.data),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MIN_FILTER,e.NEAREST),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MAG_FILTER,e.NEAREST),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_WRAP_S,e.CLAMP_TO_EDGE),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_WRAP_T,e.CLAMP_TO_EDGE),e.bindTexture(e.TEXTURE_2D,null)}},{key:"resize",value:function(e){if(!(e<=this.capacity)){var t=this.roundUpToPowerOfTwo(Math.ceil(e*Dd)),r=this.gl,i=this.computeTextureDimensions(t),o=new Float32Array(i.width*i.height*4);o.set(this.data),this.texture&&r.deleteTexture(this.texture),this.data=o,this.capacity=t,this.textureWidth=i.width,this.textureHeight=i.height,this.createTexture(),this.dirty=!0,this.dirtyRangeStart=0,this.dirtyRangeEnd=this.nextIndex}}},{key:"allocate",value:function(e){var t=this.indexMap.get(e);if(t!==void 0)return t;var r;return this.freeIndices.length>0?r=this.freeIndices.pop():(r=this.nextIndex++,r>=this.capacity&&this.resize(r+1)),this.indexMap.set(e,r),r}},{key:"free",value:function(e){var t=this.indexMap.get(e);if(t!==void 0){this.indexMap.delete(e),this.freeIndices.push(t);for(var r=t*this.TEXELS_PER_ITEM*4,i=0;i<this.TEXELS_PER_ITEM*4;i++)this.data[r+i]=0;this.markDirty(t)}}},{key:"getIndex",value:function(e){var t;return(t=this.indexMap.get(e))!==null&&t!==void 0?t:-1}},{key:"has",value:function(e){return this.indexMap.has(e)}},{key:"markDirty",value:function(e){this.dirty=!0,this.dirtyRangeStart=Math.min(this.dirtyRangeStart,e),this.dirtyRangeEnd=Math.max(this.dirtyRangeEnd,e+1)}},{key:"upload",value:function(){if(!(!this.dirty||!this.texture)){var e=this.gl,t=this.textureWidth;e.activeTexture(e.TEXTURE0),e.bindTexture(e.TEXTURE_2D,this.texture);var r=this.dirtyRangeStart*this.TEXELS_PER_ITEM,i=Math.min(this.dirtyRangeEnd*this.TEXELS_PER_ITEM,this.capacity*this.TEXELS_PER_ITEM);if(r<i)for(var o=Math.floor(r/t),s=Math.floor((i-1)/t),l=o;l<=s;l++){var u=l*t,d=Math.min(u+t,this.capacity*this.TEXELS_PER_ITEM),c=Math.max(r,u),h=Math.min(i,d);if(c<h){var f=c-u,g=h-c,m=this.data.subarray(c*4,h*4);e.texSubImage2D(e.TEXTURE_2D,0,f,l,g,1,e.RGBA,e.FLOAT,m)}}e.bindTexture(e.TEXTURE_2D,null),this.dirty=!1,this.dirtyRangeStart=1/0,this.dirtyRangeEnd=-1}}},{key:"bind",value:function(e){var t=this.gl;t.activeTexture(t.TEXTURE0+e),t.bindTexture(t.TEXTURE_2D,this.texture)}},{key:"getTexture",value:function(){return this.texture}},{key:"getCapacity",value:function(){return this.capacity}},{key:"getTextureWidth",value:function(){return this.textureWidth}},{key:"getTextureHeight",value:function(){return this.textureHeight}},{key:"getTexelsPerItem",value:function(){return this.TEXELS_PER_ITEM}},{key:"getCount",value:function(){return this.indexMap.size}},{key:"getHighWaterMark",value:function(){return this.nextIndex}},{key:"isDirty",value:function(){return this.dirty}},{key:"clear",value:function(){this.indexMap.clear(),this.freeIndices=[],this.nextIndex=0,this.data.fill(0),this.dirty=!0,this.dirtyRangeStart=0,this.dirtyRangeEnd=this.capacity}},{key:"restore",value:function(){this.createTexture(),this.dirty=!1,this.dirtyRangeStart=1/0,this.dirtyRangeEnd=-1}},{key:"kill",value:function(){this.texture&&(this.gl.deleteTexture(this.texture),this.texture=null),this.indexMap.clear(),this.freeIndices=[]}}])}();function Fe(a){var n={},e={},t=0,r=M(a),i;try{for(r.s();!(i=r.n()).done;){var o=i.value,s=M(o.attributes),l;try{for(s.s();!(l=s.n()).done;){var u=l.value,d=u.name.replace(/^a_/,"");d in n||(n[d]=t,e[d]=u,t+=u.size)}}catch(c){s.e(c)}finally{s.f()}}}catch(c){r.e(c)}finally{r.f()}return{floatsPerItem:t,texelsPerItem:Math.max(1,Math.ceil(t/4)),offsets:n,specs:e}}var Ra=function(a){function n(e,t,r){var i;return Q(this,n),i=le(this,n,[e,t.texelsPerItem,r]),i.floatsPerItem=t.floatsPerItem,i}return ue(n,a),J(n,[{key:"updateAllAttributes",value:function(t,r){var i=this.indexMap.get(t);i===void 0&&(i=this.allocate(t));for(var o=i*this.TEXELS_PER_ITEM*4,s=Math.min(r.length,this.floatsPerItem),l=0;l<s;l++)this.data[o+l]=r[l];this.markDirty(i)}},{key:"updateAllAttributesAtRow",value:function(t,r){t>=this.capacity&&this.resize(t+1);for(var i=t*this.TEXELS_PER_ITEM*4,o=Math.min(r.length,this.floatsPerItem),s=0;s<o;s++)this.data[i+s]=r[s];this.markDirty(t)}}])}(Ea);function Aa(a,n,e){for(var t=[],r=new Set,i=0;i<a.length;i++){var o=a[i],s=M(o.attributes),l;try{for(s.s();!(l=s.n()).done;){var u=l.value,d=u.name.replace(/^a_/,"");if(!r.has(d)){r.add(d);var c=n.offsets[d];if(c!==void 0){var h=e?.get(i);t.push({sourceKey:u.source||d,packedOffset:c,size:u.size,isColor:u.size===4&&!!u.normalized,defaultNum:typeof u.defaultValue=="number"?u.defaultValue:u.defaultValue===!0?1:0,defaultColor:typeof u.defaultValue=="string"?u.defaultValue:"",sourceIndex:i,hasLifecycleHook:!!(h!=null&&h.getAttributeData)})}}}}catch(f){s.e(f)}finally{s.f()}}return t}function Da(a,n,e,t,r,i){e.fill(0);for(var o=0,s=a.length;o<s;o++){var l=a[o],u=l.packedOffset,d=void 0;if(l.hasLifecycleHook){var c=r.get(l.sourceIndex-i);d=c.getAttributeData(n,l.sourceKey),d===null&&(d=n[l.sourceKey])}else d=n[l.sourceKey];if(l.isColor){var h=typeof d=="string"?d:l.defaultColor||t,f=rt(h),g=te(f,4),m=g[0],p=g[1],v=g[2],b=g[3];e[u]=m/255,e[u+1]=p/255,e[u+2]=v/255,e[u+3]=b/255}else if(l.size===1)e[u]=typeof d=="number"?d:typeof d=="boolean"?d?1:0:l.defaultNum;else{var y=Array.isArray(d)?d:null;if(y)for(var _=0;_<l.size;_++){var x;e[u+_]=(x=y[_])!==null&&x!==void 0?x:0}}}}var ma=["r","g","b","a"];function Wt(a,n){var e=a.offsets,t=a.specs,r=a.texelsPerItem,i=a.floatsPerItem,o=Object.keys(e);if(o.length===0||i===0)return{fetchCode:"",varyingAssignments:""};var s=n.varPrefix,l=n.baseTexelExpr,u=n.textureWidthUniform,d=n.textureSamplerUniform,c=n.outputPrefix,h=c===void 0?"v_":c,f=[];f.push("  int ".concat(s,"BaseTexel = ").concat(l,";")),f.push("");for(var g=0;g<r;g++)f.push("  ivec2 ".concat(s,"Coord").concat(g," = ivec2((").concat(s,"BaseTexel + ").concat(g,") % ").concat(u,", (").concat(s,"BaseTexel + ").concat(g,") / ").concat(u,");")),f.push("  vec4 ".concat(s,"Texel").concat(g," = texelFetch(").concat(d,", ").concat(s,"Coord").concat(g,", 0);"));f.push("");for(var m=[],p=function(){var _=b[v],x=t[_],T=e[_],R=Math.floor(T/4),E=T%4,S="".concat(s,"Texel").concat(R),w="".concat(s,"Texel").concat(R+1),F="".concat(s,"Fetched_").concat(_);if(x.size===1)f.push("  float ".concat(F," = ").concat(S,".").concat(ma[E],";"));else if(x.size===4&&E===0)f.push("  vec4 ".concat(F," = ").concat(S,";"));else{var D=E+x.size;if(D<=4){var P="vec".concat(x.size),L=ma.slice(E,D).join("");f.push("  ".concat(P," ").concat(F," = ").concat(S,".").concat(L,";"))}else{var I=x.size===4?"vec4":"vec".concat(x.size),z=ma.slice(E).map(function(C){return"".concat(S,".").concat(C)}),G=ma.slice(0,D-4).map(function(C){return"".concat(w,".").concat(C)}),k=[].concat(V(z),V(G)).join(", ");f.push("  ".concat(I," ").concat(F," = ").concat(I,"(").concat(k,");"))}}m.push("  ".concat(h).concat(_," = ").concat(F,";"))},v=0,b=o;v<b.length;v++)p();return{fetchCode:f.join(`
`),varyingAssignments:m.join(`
`)}}function yr(a,n,e){if(!(!n||e.type==="sampler2D"))switch(e.type){case"float":a.uniform1f(n,e.value);break;case"int":case"bool":a.uniform1i(n,e.value);break;case"vec2":a.uniform2fv(n,e.value);break;case"vec3":a.uniform3fv(n,e.value);break;case"vec4":a.uniform4fv(n,e.value);break;case"mat3":a.uniformMatrix3fv(n,!1,e.value);break;case"mat4":a.uniformMatrix4fv(n,!1,e.value);break}}var wd=A(A(A(A(A(A(A(A({},WebGL2RenderingContext.BOOL,1),WebGL2RenderingContext.BYTE,1),WebGL2RenderingContext.UNSIGNED_BYTE,1),WebGL2RenderingContext.SHORT,2),WebGL2RenderingContext.UNSIGNED_SHORT,2),WebGL2RenderingContext.INT,4),WebGL2RenderingContext.UNSIGNED_INT,4),WebGL2RenderingContext.FLOAT,4);function ba(a){var n=a.match(/^(#version[^\n]*\n)/);return n?n[1]+`#define PICKING_MODE
`+a.slice(n[1].length):`#define PICKING_MODE
`+a}var bt=function(){function a(n,e,t){Q(this,a),A(this,"floats",new Float32Array),A(this,"ints",new Uint32Array),A(this,"constantArray",new Float32Array),A(this,"capacity",0),A(this,"verticesCount",0),A(this,"bufferGeneration",0),A(this,"uploadedGeneration",new Map),A(this,"constantBufferGeneration",0),A(this,"uploadedConstantGeneration",new Map),A(this,"renderOffset",0),A(this,"renderCount",-1),A(this,"debugStats",{drawCalls:0,verticesDrawn:0,bufferUploadBytes:0}),A(this,"shadersLogged",!1),A(this,"pickProgram",null);var r=this.getDefinition();if(this.VERTICES=r.VERTICES,this.VERTEX_SHADER_SOURCE=r.VERTEX_SHADER_SOURCE,this.FRAGMENT_SHADER_SOURCE=r.FRAGMENT_SHADER_SOURCE,this.UNIFORMS=r.UNIFORMS,this.ATTRIBUTES=r.ATTRIBUTES,this.METHOD=r.METHOD,this.CONSTANT_ATTRIBUTES="CONSTANT_ATTRIBUTES"in r?r.CONSTANT_ATTRIBUTES:[],this.CONSTANT_DATA="CONSTANT_DATA"in r?r.CONSTANT_DATA:[],this.isInstanced="CONSTANT_ATTRIBUTES"in r,this.ATTRIBUTES_ITEMS_COUNT=cr(this.ATTRIBUTES),this.STRIDE=this.VERTICES*this.ATTRIBUTES_ITEMS_COUNT,this.renderer=t,this.normalProgram=this.getProgramInfo("normal",n,r.VERTEX_SHADER_SOURCE,r.FRAGMENT_SHADER_SOURCE,null),this.pickProgram=this.getProgramInfo("pick",n,ba(r.VERTEX_SHADER_SOURCE),ba(r.FRAGMENT_SHADER_SOURCE),null),this.isInstanced){var i=cr(this.CONSTANT_ATTRIBUTES);if(this.CONSTANT_DATA.length!==this.VERTICES)throw new Error("Program: error while getting constant data (expected ".concat(this.VERTICES," items, received ").concat(this.CONSTANT_DATA.length," instead)"));this.constantArray=new Float32Array(this.CONSTANT_DATA.length*i);for(var o=0;o<this.CONSTANT_DATA.length;o++){var s=this.CONSTANT_DATA[o];if(s.length!==i)throw new Error("Program: error while getting constant data (one vector has ".concat(s.length," items instead of ").concat(i,")"));for(var l=0;l<s.length;l++)this.constantArray[o*i+l]=s[l]}this.STRIDE=this.ATTRIBUTES_ITEMS_COUNT}}return J(a,[{key:"kill",value:function(){lo(this.normalProgram),this.pickProgram&&lo(this.pickProgram)}},{key:"resetDebugStats",value:function(){this.debugStats.drawCalls=0,this.debugStats.verticesDrawn=0,this.debugStats.bufferUploadBytes=0}},{key:"getProgramInfo",value:function(e,t,r,i,o){var s=t.createBuffer();if(s===null)throw new Error("Program: error while creating the WebGL buffer.");var l=fr(t,r),u=gr(t,i),d=vr(t,[l,u]),c={};this.UNIFORMS.forEach(function(g){var m=t.getUniformLocation(d,g);m&&(c[g]=m)});var h={};this.ATTRIBUTES.forEach(function(g){h[g.name]=t.getAttribLocation(d,g.name)});var f;if(this.isInstanced&&(this.CONSTANT_ATTRIBUTES.forEach(function(g){h[g.name]=t.getAttribLocation(d,g.name)}),f=t.createBuffer(),f===null))throw new Error("Program: error while creating the WebGL constant buffer.");return{name:e,program:d,gl:t,frameBuffer:o,buffer:s,constantBuffer:f||{},uniformLocations:c,attributeLocations:h,isPicking:e==="pick",vertexShader:l,fragmentShader:u}}},{key:"bindProgram",value:function(e){var t=this,r=0,i=e.gl,o=e.buffer;if(this.isInstanced){if(i.bindBuffer(i.ARRAY_BUFFER,e.constantBuffer),r=0,this.CONSTANT_ATTRIBUTES.forEach(function(d){return r+=t.bindAttribute(d,e,r,!1)}),this.uploadedConstantGeneration.get(e.constantBuffer)!==this.constantBufferGeneration){var l;i.bufferData(i.ARRAY_BUFFER,this.constantArray,i.STATIC_DRAW),this.uploadedConstantGeneration.set(e.constantBuffer,this.constantBufferGeneration),(l=this.renderer)!==null&&l!==void 0&&l.getSetting("DEBUG_logRenderStats")&&(this.debugStats.bufferUploadBytes+=this.constantArray.byteLength)}if(i.bindBuffer(i.ARRAY_BUFFER,e.buffer),r=this.renderOffset*this.ATTRIBUTES_ITEMS_COUNT*Float32Array.BYTES_PER_ELEMENT,this.ATTRIBUTES.forEach(function(d){return r+=t.bindAttribute(d,e,r,!0)}),this.uploadedGeneration.get(o)!==this.bufferGeneration){var u;i.bufferData(i.ARRAY_BUFFER,this.floats,i.DYNAMIC_DRAW),this.uploadedGeneration.set(o,this.bufferGeneration),(u=this.renderer)!==null&&u!==void 0&&u.getSetting("DEBUG_logRenderStats")&&(this.debugStats.bufferUploadBytes+=this.floats.byteLength)}}else if(i.bindBuffer(i.ARRAY_BUFFER,o),r=0,this.ATTRIBUTES.forEach(function(d){return r+=t.bindAttribute(d,e,r)}),this.uploadedGeneration.get(o)!==this.bufferGeneration){var s;i.bufferData(i.ARRAY_BUFFER,this.floats,i.DYNAMIC_DRAW),this.uploadedGeneration.set(o,this.bufferGeneration),(s=this.renderer)!==null&&s!==void 0&&s.getSetting("DEBUG_logRenderStats")&&(this.debugStats.bufferUploadBytes+=this.floats.byteLength)}i.bindBuffer(i.ARRAY_BUFFER,null)}},{key:"unbindProgram",value:function(e){var t=this;this.isInstanced?(this.CONSTANT_ATTRIBUTES.forEach(function(r){return t.unbindAttribute(r,e,!1)}),this.ATTRIBUTES.forEach(function(r){return t.unbindAttribute(r,e,!0)})):this.ATTRIBUTES.forEach(function(r){return t.unbindAttribute(r,e)})}},{key:"bindAttribute",value:function(e,t,r,i){var o=wd[e.type];if(typeof o!="number")throw new Error('Program.bind: yet unsupported attribute type "'.concat(e.type,'"'));var s=t.attributeLocations[e.name],l=t.gl;if(s!==-1){l.enableVertexAttribArray(s);var u=this.isInstanced?(i?this.ATTRIBUTES_ITEMS_COUNT:cr(this.CONSTANT_ATTRIBUTES))*Float32Array.BYTES_PER_ELEMENT:this.ATTRIBUTES_ITEMS_COUNT*Float32Array.BYTES_PER_ELEMENT;l.vertexAttribPointer(s,e.size,e.type,e.normalized||!1,u,r),this.isInstanced&&i&&l.vertexAttribDivisor(s,1)}return e.size*o}},{key:"unbindAttribute",value:function(e,t,r){var i=t.attributeLocations[e.name],o=t.gl;i!==-1&&(o.disableVertexAttribArray(i),this.isInstanced&&r&&o.vertexAttribDivisor(i,0))}},{key:"reallocate",value:function(e){e!==this.capacity&&(this.capacity=e,this.verticesCount=this.VERTICES*e,this.floats=new Float32Array(this.isInstanced?this.capacity*this.ATTRIBUTES_ITEMS_COUNT:this.verticesCount*this.ATTRIBUTES_ITEMS_COUNT),this.ints=new Uint32Array(this.floats.buffer),this.invalidateBuffers())}},{key:"invalidateBuffers",value:function(){this.bufferGeneration++,this.constantBufferGeneration++}},{key:"hasNothingToRender",value:function(){return this.verticesCount===0}},{key:"setTypedUniform",value:function(e,t){var r;yr(t.gl,(r=t.uniformLocations[e.name])!==null&&r!==void 0?r:null,e)}},{key:"renderProgram",value:function(e,t){var r=t.gl,i=t.program,o=t.isPicking;o?r.disable(r.BLEND):r.enable(r.BLEND),r.useProgram(i),this.setUniforms(e,t),this.drawWebGL(this.METHOD,t)}},{key:"render",value:function(e,t,r){var i;if(!this.shadersLogged&&(i=this.renderer)!==null&&i!==void 0&&i.getSetting("DEBUG_logShaders")&&(this.shadersLogged=!0,console.log("[sigma] DEBUG_logShaders: ".concat(this.constructor.name),{normal:{vertexShaderSource:this.VERTEX_SHADER_SOURCE,fragmentShaderSource:this.FRAGMENT_SHADER_SOURCE},pick:{vertexShaderSource:ba(this.VERTEX_SHADER_SOURCE),fragmentShaderSource:ba(this.FRAGMENT_SHADER_SOURCE)}})),!this.hasNothingToRender()){this.renderOffset=t??0,this.renderCount=r??-1;var o=this.normalProgram.gl;if(o.bindFramebuffer(o.FRAMEBUFFER,null),o.viewport(0,0,e.width*e.pixelRatio,e.height*e.pixelRatio),this.bindProgram(this.normalProgram),this.renderProgram(e,this.normalProgram),this.unbindProgram(this.normalProgram),this.pickProgram&&e.pickingFrameBuffer){var s=Math.ceil(e.width*e.pixelRatio/e.downSizingRatio),l=Math.ceil(e.height*e.pixelRatio/e.downSizingRatio);o.bindFramebuffer(o.FRAMEBUFFER,e.pickingFrameBuffer),o.viewport(0,0,s,l),this.bindProgram(this.pickProgram),this.renderProgram(e,this.pickProgram),this.unbindProgram(this.pickProgram),o.bindFramebuffer(o.FRAMEBUFFER,null),o.viewport(0,0,e.width*e.pixelRatio,e.height*e.pixelRatio)}}}},{key:"drawWebGL",value:function(e,t){var r,i=t.gl,o=this.renderCount>=0?this.renderCount:this.capacity;(r=this.renderer)!==null&&r!==void 0&&r.getSetting("DEBUG_logRenderStats")&&(this.debugStats.drawCalls++,this.debugStats.verticesDrawn+=o*this.VERTICES),this.isInstanced?i.drawArraysInstanced(e,0,this.VERTICES,o):i.drawArrays(e,this.renderOffset*this.VERTICES,o*this.VERTICES)}}])}(),st=2,Rn=7,wo={below:0,above:1,left:2,right:3};function Ld(){var a=`#version 300 es
precision highp float;

uniform mat3 u_matrix;
uniform vec2 u_resolution;
uniform float u_labelPixelSnapping;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
uniform float u_pixelRatio;
uniform float u_labelMargin;
uniform float u_zoomLabelSizeRatio;

uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_nodeFrameTexture;
uniform int u_nodeFrameTextureWidth;

// Atlas size is fixed at 2048\xD72048 \u2014 matches AttachmentManager.ATLAS_SIZE.
uniform sampler2D u_atlasTexture;
const vec2 u_atlasSize = vec2(2048.0);

// Per-instance
in float a_nodeIndex;           // node-data texture index
in vec4 a_atlasRect;            // x, y, width, height in atlas pixels
in vec2 a_attachmentSize;       // attachment dimensions (CSS px)
in float a_positionMode;        // label position: 0=right 1=left 2=above 3=below 4=over
in float a_attachmentPlacement; // 0=below 1=above 2=left 3=right (relative to label)
in float a_labelWidth;          // label width (CSS px)
in float a_labelHeight;         // label height: font line box (CSS px)
in float a_textHeight;          // actual glyph height (CSS px)
in float a_labelAngle;          // label rotation angle (radians)

// Per-vertex (constant)
in vec2 a_quadCorner;           // [-1,-1], [1,-1], [-1,1], [1,1]

out vec2 v_texCoord;

`.concat(Qe,`
`).concat(mt,`
`).concat(Ht,`
`).concat(Ao,`
`).concat(Eo,`

void main() {
  int nodeIdx = int(a_nodeIndex);

  // Node data: (x, y, size, shapeId).
  vec4 nodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  vec2 nodePos = nodeData.xy;
  float nodeSize = nodeData.z;

  // Normalized edge distance from the shared frame texture (the frame-pass ran
  // the SDF search once; we just read the result).
  float edgeDist = readFrameTexel(u_nodeFrameTexture, u_nodeFrameTextureWidth, nodeIdx).r;

  // Per-node label rotation alignment: 0 = viewport, 1 = label turns with camera.
  float labelRotation = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx).g;

  vec3 nodeClip = u_matrix * vec3(nodePos, 1.0);

  // Node radius in physical pixels (matches label/background).
  float matrixScaleX = length(vec2(u_matrix[0][0], u_matrix[1][0]));
  float nodeRadiusGraphSpace = nodeSize * u_correctionRatio / u_sizeRatio * 2.0;
  float nodeRadiusPixels = nodeRadiusGraphSpace * matrixScaleX * u_resolution.x / 2.0;

  // CSS-px inputs -> physical px, scaled by the zoom-dependent label ratio, so
  // the attachment stays glued to the label box exactly as the label scales.
  float zoomScale = u_zoomLabelSizeRatio;
  vec2 labelHalf = vec2(a_labelWidth, a_labelHeight) * 0.5 * zoomScale * u_pixelRatio;
  vec2 attachHalf = a_attachmentSize * 0.5 * zoomScale * u_pixelRatio;
  float gap = `).concat(st.toFixed(1),` * zoomScale * u_pixelRatio;
  float labelMargin = u_labelMargin * zoomScale * u_pixelRatio;

  // Graph-aligned labels add the camera angle so the attachment orbits with the box.
  mat2 labelRotMat = rotate2D(a_labelAngle - labelRotation * u_cameraAngle);

  // Label box center relative to the node center (pre-rotation). The shape-aware
  // edge distance comes from the frame texture, so placement matches the label.
  vec2 boxCenter = vec2(0.0);
  if (a_positionMode < 4.0) {
    float labelStart = nodeRadiusPixels * edgeDist + labelMargin;
    float textHalf = a_textHeight * 0.5 * zoomScale * u_pixelRatio;
    boxCenter = labelBoxCenter(a_positionMode, labelStart, labelHalf, textHalf);
  }

  // Horizontal anchor of below/above attachments tracks the label position, so
  // the attachment hangs from the label edge nearest the node (or is centered
  // when the label itself is node-centered): right->left, left->right, else center.
  float anchorX = 0.0;
  if (a_positionMode < 0.5) anchorX = -labelHalf.x + attachHalf.x;       // right label
  else if (a_positionMode < 1.5) anchorX = labelHalf.x - attachHalf.x;   // left label

  // Attachment center relative to the box (pre-rotation, Y-down). This offset
  // depends only on the box, the gap and the attachment size \u2014 never the shape.
  vec2 attachCenter;
  if (a_attachmentPlacement < 0.5) {
    // below
    attachCenter = boxCenter + vec2(anchorX, labelHalf.y + gap + attachHalf.y);
  } else if (a_attachmentPlacement < 1.5) {
    // above
    attachCenter = boxCenter + vec2(anchorX, -(labelHalf.y + gap + attachHalf.y));
  } else if (a_attachmentPlacement < 2.5) {
    // left, top-aligned
    attachCenter = boxCenter + vec2(-(labelHalf.x + gap + attachHalf.x), -labelHalf.y + attachHalf.y);
  } else {
    // right, top-aligned
    attachCenter = boxCenter + vec2(labelHalf.x + gap + attachHalf.x, -labelHalf.y + attachHalf.y);
  }

  // Rotate the whole assembly by the label angle, around the node center.
  vec2 rotatedCenter = labelRotMat * attachCenter;
  vec2 cornerOffset = labelRotMat * (a_quadCorner * attachHalf);

  // Node center in screen px (Y-down).
  vec2 nodeScreen = vec2(
    (nodeClip.x + 1.0) * u_resolution.x,
    (1.0 - nodeClip.y) * u_resolution.y
  ) * 0.5;

  // Snap node center to the pixel grid so label/backdrop/attachment move as one.
  vec2 snapDelta = (round(nodeScreen) - nodeScreen) * u_labelPixelSnapping;

  // Snap the quad's top-left to integer pixels so atlas texels map 1:1.
  vec2 centerScreen = nodeScreen + rotatedCenter + snapDelta;
  vec2 topLeft = centerScreen - attachHalf;
  topLeft = mix(topLeft, round(topLeft), u_labelPixelSnapping);
  centerScreen = topLeft + attachHalf;

  vec2 vertexScreen = centerScreen + cornerOffset;
  gl_Position = vec4(
    vertexScreen.x * 2.0 / u_resolution.x - 1.0,
    1.0 - vertexScreen.y * 2.0 / u_resolution.y,
    0.0, 1.0
  );

  vec2 texOrigin = a_atlasRect.xy / u_atlasSize;
  vec2 texSize = a_atlasRect.zw / u_atlasSize;
  vec2 uv = (a_quadCorner + 1.0) / 2.0;
  v_texCoord = texOrigin + uv * texSize;
}
`);return a}var Cd=`#version 300 es
precision highp float;

uniform sampler2D u_atlasTexture;

in vec2 v_texCoord;

layout(location = 0) out vec4 fragColor;
#ifdef PICKING_MODE
layout(location = 1) out vec4 pickColor;
#endif

void main() {
  // Canvas textures are premultiplied; output directly for (ONE, 1-SRC_ALPHA) blending
  vec4 color = texture(u_atlasTexture, v_texCoord);
  if (color.a < 0.01) discard;
  fragColor = color;
#ifdef PICKING_MODE
  pickColor = vec4(0.0); // Attachments are not pickable
#endif
}
`;function Pd(a,n,e,t){var r,i,o=t.label,s=o===void 0?{}:o,l=(r=s.margin)!==null&&r!==void 0?r:Ut,u=(i=s.zoomToLabelSizeRatioFunction)!==null&&i!==void 0?i:function(){return 1},d=Ld(),c=Cd,h=function(f){function g(){var m;Q(this,g);for(var p=arguments.length,v=new Array(p),b=0;b<p;b++)v[b]=arguments[b];return m=le(this,g,[].concat(v)),A(m,"totalCount",0),A(m,"bufferCapacity",0),m}return ue(g,f),J(g,[{key:"getDefinition",value:function(){var p=WebGL2RenderingContext,v=p.FLOAT,b=p.TRIANGLE_STRIP;return{VERTICES:4,VERTEX_SHADER_SOURCE:d,FRAGMENT_SHADER_SOURCE:c,METHOD:b,UNIFORMS:["u_matrix","u_resolution","u_labelPixelSnapping","u_sizeRatio","u_correctionRatio","u_cameraAngle","u_pixelRatio","u_labelMargin","u_zoomLabelSizeRatio","u_nodeDataTexture","u_nodeDataTextureWidth","u_nodeFrameTexture","u_nodeFrameTextureWidth","u_atlasTexture"],ATTRIBUTES:[{name:"a_nodeIndex",size:1,type:v},{name:"a_atlasRect",size:4,type:v},{name:"a_attachmentSize",size:2,type:v},{name:"a_positionMode",size:1,type:v},{name:"a_attachmentPlacement",size:1,type:v},{name:"a_labelWidth",size:1,type:v},{name:"a_labelHeight",size:1,type:v},{name:"a_textHeight",size:1,type:v},{name:"a_labelAngle",size:1,type:v}],CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:v}],CONSTANT_DATA:[[-1,-1],[1,-1],[-1,1],[1,1]]}}},{key:"processAttachment",value:function(p,v){var b=this.floats,y=p*this.STRIDE;b[y++]=v.nodeIndex,b[y++]=v.atlasX,b[y++]=v.atlasY,b[y++]=v.atlasW,b[y++]=v.atlasH,b[y++]=v.attachWidth,b[y++]=v.attachHeight,b[y++]=v.positionMode,b[y++]=v.attachmentPlacement,b[y++]=v.labelWidth,b[y++]=v.labelHeight,b[y++]=v.textHeight,b[y++]=v.labelAngle}},{key:"setUniforms",value:function(p,v){var b=v.gl,y=v.uniformLocations;b.uniformMatrix3fv(y.u_matrix,!1,p.matrix),b.uniform2f(y.u_resolution,p.width*p.pixelRatio,p.height*p.pixelRatio),b.uniform1f(y.u_labelPixelSnapping,p.labelPixelSnapping),b.uniform1f(y.u_sizeRatio,p.sizeRatio),b.uniform1f(y.u_correctionRatio,p.correctionRatio),b.uniform1f(y.u_cameraAngle,p.cameraAngle),b.uniform1f(y.u_pixelRatio,p.pixelRatio),b.uniform1f(y.u_labelMargin,g.labelMargin),b.uniform1f(y.u_zoomLabelSizeRatio,1/u(p.zoomRatio)),b.uniform1i(y.u_nodeDataTexture,p.nodeDataTextureUnit),b.uniform1i(y.u_nodeDataTextureWidth,p.nodeDataTextureWidth),b.uniform1i(y.u_nodeFrameTexture,p.nodeFrameTextureUnit),b.uniform1i(y.u_nodeFrameTextureWidth,p.nodeFrameTextureWidth),b.uniform1i(y.u_atlasTexture,Rn)}},{key:"reallocateAttachments",value:function(p){this.totalCount=p,p>this.bufferCapacity&&(this.bufferCapacity=Math.max(p,Math.ceil(this.bufferCapacity*1.5)||10),ve(g,"reallocate",this,3)([this.bufferCapacity]))}},{key:"hasNothingToRender",value:function(){return this.totalCount===0}},{key:"drawWebGL",value:function(p,v){var b=v.gl;this.totalCount!==0&&b.drawArraysInstanced(p,0,this.VERTICES,this.totalCount)}}])}(bt);return A(h,"labelMargin",l),new h(a,n,e)}var it=5;function wa(a,n){return[].concat(V(n),V(a.map(function(e){var t;return{attributes:(t=e.attributes)!==null&&t!==void 0?t:[]}})))}function $t(a,n){var e=Fe(wa(a,n)),t=new Set(a.flatMap(function(u){var d;return(d=u.attributes)!==null&&d!==void 0?d:[]}).map(function(u){return u.name.replace(/^a_/,"")})),r={},i={},o=M(t),s;try{for(o.s();!(s=o.n()).done;){var l=s.value;r[l]=e.offsets[l],i[l]=e.specs[l]}}catch(u){o.e(u)}finally{o.f()}return O(O({},e),{},{offsets:r,specs:i})}function kd(a,n){var e=new Set(["u_matrix","u_sizeRatio","u_correctionRatio","u_cameraAngle","u_pickingPadding","u_nodeDataTexture","u_layerAttributeTexture"]),t=new Set,r=a.flatMap(function(f){return f.uniforms}).filter(function(f){return e.has(f.name)||t.has(f.name)?!1:(t.add(f.name),!0)}).map(function(f){return"uniform ".concat(f.type," ").concat(f.name,";")}).join(`
`),i=n.flatMap(function(f){return f.uniforms}).filter(function(f){return e.has(f.name)||t.has(f.name)?!1:(t.add(f.name),!0)}).map(function(f){return"uniform ".concat(f.type," ").concat(f.name,";")}).join(`
`),o=wa(a,n),s=new Set,l=o.flatMap(function(f){return f.attributes}).filter(function(f){var g=f.name.replace(/^a_/,"");return s.has(g)?!1:(s.add(g),!0)}).map(function(f){var g=f.name.replace(/^a_/,""),m=f.size===1?"float":"vec".concat(f.size);return"out ".concat(m," v_").concat(g,";")}).join(`
`),u=Wt(Fe(o),{varPrefix:"layer",baseTexelExpr:"nodeIdx * u_layerAttributeTexelsPerNode",textureWidthUniform:"u_layerAttributeTextureWidth",textureSamplerUniform:"u_layerAttributeTexture"}),d=u.fetchCode,c=u.varyingAssignments,h=`#version 300 es

// Standard node attributes (per instance) - minimal buffer usage
in float a_nodeIndex;  // Index into node data texture AND layer attribute texture
in vec4 a_id;          // Node ID for picking
in float a_opacity;    // Node opacity, applied once to the final fragment

// Constant attributes (per vertex, same for all instances)
in vec2 a_quadCorner;  // (-1,-1), (1,-1), (1,1), (-1,1) for quad corners

// Standard uniforms
uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
#ifdef PICKING_MODE
uniform float u_pickingPadding;
#endif
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;

// Layer attribute texture uniforms
uniform sampler2D u_layerAttributeTexture;
uniform int u_layerAttributeTextureWidth;
uniform int u_layerAttributeTexelsPerNode;

`.concat(r,`
`).concat(i,`

// Standard varyings
out vec2 v_uv;                    // Normalized coordinates [-1, 1]
out vec4 v_id;
out float v_opacity;
out float v_antialiasingWidth;    // Width for antialiasing in UV space
out float v_pixelSize;            // Node size in pixels (for pixel-mode borders)
out float v_pixelToUV;            // Conversion factor: multiply by this to convert screen pixels to UV units
out float v_shapeId;              // Shape ID for multi-shape programs

// Layer varyings
`).concat(l,`

// Node-data fetch helpers (geometry texel + rotation-flags texel)
`).concat(Qe,`
`).concat(mt,`

void main() {
  // Fetch node geometry: vec4(x, y, size, shapeId).
  int nodeIdx = int(a_nodeIndex);

  // Hidden nodes are flagged with a negative row by NodeProgram.process(). Push
  // the whole quad outside the clip volume: every vertex lands at the same
  // out-of-range position, so the primitive is fully clipped and rasterizes
  // nothing \u2014 neither to the frame buffer nor to the picking buffer.
  if (nodeIdx < 0) {
    gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
    v_id = vec4(0.0);
    return;
  }

  vec4 nodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  vec2 a_position = nodeData.xy;
  float a_size = nodeData.z;
  v_shapeId = nodeData.w;  // Pass shape ID to fragment shader

  // Per-node rotation alignment: 0 = viewport (screen-upright), 1 = graph.
  float nodeRotation = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx).r;

`).concat(d,`

  // Calculate the actual size in pixels
  float size = a_size * u_correctionRatio / u_sizeRatio * 2.0;

  // In PICKING_MODE, inflate the quad by nodePickingPadding pixels on each side
  #ifdef PICKING_MODE
    float paddedSize = size + u_pickingPadding * u_correctionRatio;
    vec2 offset = a_quadCorner * paddedSize;
  #else
    vec2 offset = a_quadCorner * size;
  #endif
  // Counter-rotate the quad offset so viewport-aligned nodes stay upright as the
  // camera turns. Graph-aligned nodes (nodeRotation=1) skip it and turn with the
  // camera. The angle scales by (1 - nodeRotation) so both fall out of one path.
  {
    float ca = u_cameraAngle * (1.0 - nodeRotation);
    float c = cos(ca);
    float s = sin(ca);
    offset = mat2(c, s, -s, c) * offset;
  }
  vec2 position = a_position + offset;

  gl_Position = vec4(
    (u_matrix * vec3(position, 1)).xy,
    0,
    1
  );

  // In PICKING_MODE, UV is scaled beyond [-1, 1] to match the inflated quad
  #ifdef PICKING_MODE
    v_uv = a_quadCorner * (paddedSize / size);
  #else
    v_uv = a_quadCorner;
  #endif

  // Pass ID to fragment shader
  v_id = a_id;
  v_opacity = a_opacity;

  // Pass pixel size for layers that need pixel-mode calculations
  // Multiply by 2 because 'size' is half-width (offset from center), not full diameter
  v_pixelSize = size * 2.0;

  // Conversion factor from screen pixels to UV units
  // Same derivation as v_antialiasingWidth which represents ~1 pixel in UV space
  // P pixels in UV space = P * u_correctionRatio / size
  v_pixelToUV = u_correctionRatio / size;

  // We use an antialiasing width of 1px (so v_pixelToUV)
  v_antialiasingWidth = v_pixelToUV;

  // Pass layer attributes to fragment shader (fetched from texture)
`).concat(c,`
}
`);return h}function Fd(a,n,e){var t=arguments.length>3&&arguments[3]!==void 0?arguments[3]:!0,r=n.map(function(g,m){var p="layer_".concat(g.name),v=[].concat(V(g.attributes.map(function(b){return"v_".concat(b.name.replace(/^a_/,""))})),V(g.uniforms.map(function(b){return b.name}))).join(", ");return"  // Layer ".concat(m+1,": ").concat(g.name,`
  color = blendOver(color, `).concat(p,"(").concat(v,"));")}).join(`

`),i=new Set(["u_correctionRatio"]),o=new Set,s=a.flatMap(function(g){return g.uniforms}).filter(function(g){return i.has(g.name)||o.has(g.name)?!1:(o.add(g.name),!0)}).map(function(g){return"uniform ".concat(g.type," ").concat(g.name,";")}).join(`
`),l=n.flatMap(function(g){return g.uniforms}).filter(function(g){return i.has(g.name)||o.has(g.name)?!1:(o.add(g.name),!0)}).map(function(g){return"uniform ".concat(g.type," ").concat(g.name,";")}).join(`
`),u=new Set,d=wa(a,n).flatMap(function(g){return g.attributes}).filter(function(g){var m=g.name.replace(/^a_/,"");return u.has(m)?!1:(u.add(m),!0)}).map(function(g){var m=g.name.replace(/^a_/,""),p=g.size===1?"float":"vec".concat(g.size);return"in ".concat(p," v_").concat(m,";")}).join(`
`),c=pr(a),h=bd(a,e),f=`#version 300 es
precision highp float;

// Standard varyings
in vec2 v_uv;
in vec4 v_id;
in float v_opacity;
in float v_antialiasingWidth;
in float v_pixelSize;
in float v_pixelToUV;
in float v_shapeId;  // Shape ID for multi-shape programs

// Standard uniforms (needed for some layer calculations like pixel-mode borders)
uniform float u_correctionRatio;
#ifdef PICKING_MODE
uniform float u_pickingPadding;
#endif

// Shape uniforms
`.concat(s,`

// Layer uniforms
`).concat(l,`

// Layer varyings
`).concat(d,`

// Fragment output (single target - picking handled via separate pass)
out vec4 fragColor;

// LayerContext struct - provides rendering context to all layers
struct LayerContext {
  float sdf;             // Signed distance from shape boundary (negative inside)
  vec2 uv;               // UV coordinates [-1, 1], center at (0,0)
  float shapeSize;       // Effective shape size (~diameter) in UV space (1.0 - aaWidth)
  float shapeHalfSize;   // Effective shape half size (~radius) in UV space
  float pixelSize;       // Node full size (~diameter) in screen pixels
  float aaWidth;         // Anti-aliasing width for smooth transitions
  float correctionRatio; // Scaling factor for consistent rendering across zoom levels
  float pixelToUV;       // Conversion factor: multiply screen pixels by this to get UV units
  float inradiusFactor;  // Ratio of inradius to circumradius (shape depth factor)
};

LayerContext context;  // Global instance, populated before layer calls

// Alpha "over" compositing for layer blending
vec4 blendOver(vec4 bg, vec4 fg) {
  float a = fg.a;
  return vec4(mix(bg.rgb, fg.rgb, a), bg.a + a * (1.0 - bg.a));
}

// SDF shape functions
`).concat(c,`

// Shape selector function (sets context.sdf and context.inradiusFactor)
`).concat(h,`

// Layer functions
`).concat(n.map(function(g){return g.glsl}).join(`

`),`

void main() {
  // 1. Setup LayerContext (available to all layer functions)
  context.shapeSize = 1.0 - v_antialiasingWidth;
  context.shapeHalfSize = context.shapeSize * 0.5;
  context.pixelSize = v_pixelSize;
  context.uv = v_uv;
  context.aaWidth = v_antialiasingWidth;
  context.correctionRatio = u_correctionRatio;
  context.pixelToUV = v_pixelToUV;

  // Query shape SDF based on shapeId (sets context.sdf and context.inradiusFactor)
  queryNodeSDF(int(v_shapeId), v_uv, context.shapeSize);

  // 2. Early discard for pixels fully outside the shape (with AA margin)
  // In PICKING_MODE, allow extra fragments up to the picking padding distance
  #ifdef PICKING_MODE
    if (context.sdf > u_pickingPadding * v_pixelToUV + context.aaWidth) discard;
  #else
    if (context.sdf > context.aaWidth) discard;
  #endif

  // 3. Apply layers sequentially with "over" compositing
  vec4 color = vec4(0.0);

`).concat(r,`

  #ifdef PICKING_MODE
    // Picking pass: output node ID for pixels within the picking area.
    if (context.sdf > u_pickingPadding * v_pixelToUV) discard;
    fragColor = v_id;
  #else
`).concat(t?`    // Visual pass: apply antialiasing at shape boundary, node opacity once
    // smoothstep provides smooth transition from opaque to transparent
    float alpha = smoothstep(context.aaWidth, -context.aaWidth, context.sdf) * v_opacity;`:`    // Visual pass: hard-edged (no anti-aliasing gradient) shape boundary, node opacity applied once
    float alpha = (context.sdf < 0.0 ? 1.0 : 0.0) * v_opacity;`,`
    // Mix with transparent to fade both color AND alpha together (avoids bright halo)
    fragColor = mix(vec4(0.0), color, alpha);
  #endif
}
`);return f}function Id(a,n){var e=new Set;return e.add("u_matrix"),e.add("u_sizeRatio"),e.add("u_correctionRatio"),e.add("u_cameraAngle"),e.add("u_pickingPadding"),e.add("u_nodeDataTexture"),e.add("u_nodeDataTextureWidth"),e.add("u_layerAttributeTexture"),e.add("u_layerAttributeTextureWidth"),e.add("u_layerAttributeTexelsPerNode"),a.forEach(function(t){t.uniforms.forEach(function(r){return e.add(r.name)})}),n.forEach(function(t){t.uniforms.forEach(function(r){return e.add(r.name)})}),Array.from(e)}function Gd(a){var n=WebGL2RenderingContext,e=n.UNSIGNED_BYTE,t=n.FLOAT;return[{name:"a_nodeIndex",size:1,type:t},{name:"a_id",size:4,type:e,normalized:!0},{name:"a_opacity",size:1,type:t}]}function co(a){var n=a.shapes,e=a.layers,t=a.shapeGlobalIds,r=a.antialias,i=r===void 0?!0:r;return{vertexShader:kd(n,e),fragmentShader:Fd(n,e,t,i),uniforms:Id(n,e),attributes:Gd()}}function Lo(a,n,e){var t=$t(a,n),r=t.specs;return Object.keys(r).map(function(i){return"flat ".concat(e," ").concat(r[i].size===1?"float":"vec".concat(r[i].size)," v_").concat(i,";")}).join(`
`)}function zd(a){var n,e,t=a.shapes,r=a.layers,i=a.shapeGlobalIds,o=Wt($t(t,r),{varPrefix:"nodeAttr",baseTexelExpr:"nodeIdx * u_layerAttributeTexelsPerNode",textureWidthUniform:"u_layerAttributeTextureWidth",textureSamplerUniform:"u_layerAttributeTexture"}),s=t.length===1?"float inradiusFactor = ".concat(he((n=t[0].inradiusFactor)!==null&&n!==void 0?n:1),";"):"float inradiusFactor = ".concat(he((e=t[0].inradiusFactor)!==null&&e!==void 0?e:1),`;
  switch (int(shapeId)) {
`).concat(t.map(function(u,d){var c,h=i?i[d]:d;return"    case ".concat(h,": inradiusFactor = ").concat(he((c=u.inradiusFactor)!==null&&c!==void 0?c:1),"; break;")}).join(`
`),`
    default: break;
  }`),l=`#version 300 es

in float a_nodeIndex;
in float a_labelWidth;
in float a_labelHeight;
in float a_textHeight;
in float a_positionMode;
in float a_labelAngle;
in vec4 a_backdropColor;
in vec4 a_backdropShadowColor;
in float a_backdropShadowBlur;
in float a_backdropPadding;
in vec4 a_backdropBorderColor;
in vec4 a_backdropExtra; // [borderWidth, cornerRadius, labelPadding, area]
in vec2 a_labelBoxOffset;
in vec2 a_quadCorner;

uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
uniform vec2 u_resolution;
uniform float u_pixelRatio;
uniform float u_labelMargin;
uniform float u_zoomLabelSizeRatio;
uniform float u_labelPixelSnapping;
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_nodeFrameTexture;
uniform int u_nodeFrameTextureWidth;
uniform sampler2D u_layerAttributeTexture;
uniform int u_layerAttributeTextureWidth;
uniform int u_layerAttributeTexelsPerNode;

out vec2 v_uv;
out vec2 v_nodeCenter;
out float v_nodeRadius;
out vec2 v_labelCenter;
out vec2 v_labelHalfSize;
out float v_aaWidth;
out float v_shapeId;
out float v_nodeRotation;
out float v_labelAngle;
out vec4 v_backdropColor;
out vec4 v_backdropShadowColor;
out float v_backdropShadowBlur;
out float v_backdropPadding;
out vec4 v_backdropBorderColor;
out float v_backdropBorderWidth;
out float v_backdropCornerRadius;
out float v_backdropArea;
`.concat(Lo(t,r,"out"),`

`).concat(Qe,`
`).concat(mt,`
`).concat(Ht,`

void main() {
  int nodeIdx = int(a_nodeIndex);
`).concat(o.fetchCode,`
`).concat(o.varyingAssignments,`

  // Node data: (x, y, size, shapeId). shapeId (global) is forwarded to the
  // fragment shader, which keeps the shape SDF for the outline.
  vec4 nodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  vec2 nodePosition = nodeData.xy;
  float nodeSize = nodeData.z;
  float shapeId = nodeData.w;

  // Per-node rotation alignment (0 = viewport, 1 = graph). nodeRotation drives
  // the fragment's shape outline; labelRotation turns the label box with camera.
  vec4 nodeFlags = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  float nodeRotation = nodeFlags.r;
  float labelRotation = nodeFlags.g;
  v_nodeRotation = nodeRotation;

  `).concat(So,`
  // CSS pixel attributes are multiplied by u_pixelRatio to match nodeRadiusPixels,
  // which is already in physical pixels (nodeRadiusNDC * u_resolution.x / 2.0).
  float padding = a_backdropPadding * u_pixelRatio;
  float shadowBlur = a_backdropShadowBlur * u_pixelRatio;
  // Unpack a_backdropExtra: [borderWidth, cornerRadius, labelPadding, area]
  float borderWidth = a_backdropExtra.x * u_pixelRatio;
  float cornerRadius = a_backdropExtra.y * u_pixelRatio;
  float labelPad = a_backdropExtra.z * u_pixelRatio;
  float backdropArea = a_backdropExtra.w;
  // Use 2x shadowBlur so the Gaussian fully decays before the quad edge
  float totalExpansion = shadowBlur * 2.0 + borderWidth;
  float enlargedRadius = nodeRadiusPixels + padding;

  // Circumscribed radius for the quad bounds. Non-circular shapes reach past
  // their inradius out to their circumradius (= enlargedRadius / inradiusFactor),
  // in any direction once rotated. The axis-aligned quad must contain that, or
  // the fill/shadow gets clipped (square corners, triangle tip, etc.).
  `).concat(s,`
  float boundRadius = enlargedRadius / inradiusFactor;

  // Apply zoom-dependent label size scaling
  float zoomScale = u_zoomLabelSizeRatio;
  float labelW = a_labelWidth * zoomScale * u_pixelRatio;
  float labelH = a_labelHeight * zoomScale * u_pixelRatio;
  float labelMargin = u_labelMargin * zoomScale * u_pixelRatio;

  // Only apply labelPad when a label is actually present
  float effectiveLabelPad = labelW > 0.0 ? labelPad : 0.0;
  vec2 labelHalfSize = vec2(labelW * 0.5 + effectiveLabelPad, labelH * 0.5 + effectiveLabelPad);
  vec2 labelOffset = vec2(0.0);

  // Effective label angle: intrinsic angle plus the camera angle when the label
  // is graph-aligned, so the box orbits the node in lockstep with the frame-pass.
  float labelAngle = a_labelAngle - labelRotation * u_cameraAngle;
  float la_c = cos(labelAngle);
  float la_s = sin(labelAngle);
  mat2 labelRotMat = mat2(la_c, -la_s, la_s, la_c);

  vec3 nodeClip = u_matrix * vec3(nodePosition, 1.0);
  vec2 snapDelta = vec2(0.0);

  if (labelW > 0.0) {
    // labelW > 0.0 means this node's label is displayed, so the frame-pass wrote
    // its edge distance this frame.
    float edgeDistPixels = nodeRadiusPixels * readFrameTexel(u_nodeFrameTexture, u_nodeFrameTextureWidth, nodeIdx).r;
    // labelMargin matches the label shader's margin (gap from node edge to text)
    float labelStart = edgeDistPixels + labelMargin;
    // Above/below center on the actual glyph height, not the font line box, so
    // the box stays aligned with the rendered text (matches labelBoxCenter()).
    float textHalf = a_textHeight * zoomScale * u_pixelRatio * 0.5;

    // Snap node center to pixel grid so label/backdrop/attachment move as a unit
    vec2 nodeScreen = vec2(
      (nodeClip.x + 1.0) * u_resolution.x,
      (1.0 - nodeClip.y) * u_resolution.y
    ) * 0.5;
    snapDelta = (round(nodeScreen) - nodeScreen) * u_labelPixelSnapping;

    if (a_positionMode < 0.5) {
      // Right: box spans from node center to text end + padding
      float boxRightEdge = labelStart + labelW + labelPad;
      labelOffset = vec2(boxRightEdge * 0.5, 0.0);
      labelHalfSize.x = boxRightEdge * 0.5;
    } else if (a_positionMode < 1.5) {
      // Left: mirror of right
      float boxLeftEdge = labelStart + labelW + labelPad;
      labelOffset = vec2(-boxLeftEdge * 0.5, 0.0);
      labelHalfSize.x = boxLeftEdge * 0.5;
    } else if (a_positionMode < 2.5) {
      // Above: text bottom at labelStart, centered horizontally
      labelOffset = vec2(0.0, -(labelStart + textHalf));
    } else if (a_positionMode < 3.5) {
      // Below: text top at labelStart, centered horizontally
      labelOffset = vec2(0.0, labelStart + textHalf);
    }
    // over (>=4): labelOffset stays (0,0) \u2014 text centered on the node.

    // The attachment-cover shift is in label space (like the attachment itself),
    // so rotate it together with the position offset \u2014 otherwise the box drifts
    // off the attachment as the label angle grows.
    labelOffset = labelRotMat * (labelOffset + a_labelBoxOffset * zoomScale * u_pixelRatio);
  }

  // For node-only mode, zero out label dimensions
  if (backdropArea > 0.5 && backdropArea < 1.5) {
    labelHalfSize = vec2(0.0);
    labelOffset = vec2(0.0);
  }

  vec2 minBound, maxBound;

  bool hasLabelBounds = labelW > 0.0 && (backdropArea > 1.5 || backdropArea < 0.5);

  if (hasLabelBounds) {
    // Union with label bounds (area=both) or label-only bounds (area=label)
    vec2 labelMin, labelMax;

    if (a_labelAngle != 0.0) {
      vec2 corner1 = labelOffset + labelRotMat * vec2(-labelHalfSize.x, -labelHalfSize.y);
      vec2 corner2 = labelOffset + labelRotMat * vec2(labelHalfSize.x, -labelHalfSize.y);
      vec2 corner3 = labelOffset + labelRotMat * vec2(labelHalfSize.x, labelHalfSize.y);
      vec2 corner4 = labelOffset + labelRotMat * vec2(-labelHalfSize.x, labelHalfSize.y);
      labelMin = min(min(corner1, corner2), min(corner3, corner4));
      labelMax = max(max(corner1, corner2), max(corner3, corner4));
    } else {
      labelMin = labelOffset - labelHalfSize;
      labelMax = labelOffset + labelHalfSize;
    }

    if (backdropArea > 1.5) {
      // Label-only: bounds from label rect only
      minBound = labelMin - totalExpansion;
      maxBound = labelMax + totalExpansion;
    } else {
      // Both: union of node + label
      minBound = min(-vec2(boundRadius), labelMin) - totalExpansion;
      maxBound = max(vec2(boundRadius), labelMax) + totalExpansion;
    }
  } else {
    // Node-only or no visible label
    float totalRadius = boundRadius + totalExpansion;
    minBound = -vec2(totalRadius);
    maxBound = vec2(totalRadius);
  }

  vec2 quadSize = maxBound - minBound;
  vec2 quadCenter = (minBound + maxBound) * 0.5;

  vec2 localPos = quadCenter + a_quadCorner * quadSize * 0.5 + snapDelta;
  vec2 ndcOffset = localPos * 2.0 / u_resolution;
  ndcOffset.y = -ndcOffset.y;

  gl_Position = vec4(nodeClip.xy + ndcOffset, 0.0, 1.0);

  v_uv = localPos;
  v_nodeCenter = vec2(0.0);
  v_nodeRadius = nodeRadiusPixels;
  v_labelCenter = labelOffset;
  v_labelHalfSize = labelHalfSize;
  v_aaWidth = 1.0;
  v_shapeId = shapeId;
  v_labelAngle = labelAngle;
  v_backdropColor = a_backdropColor;
  v_backdropShadowColor = a_backdropShadowColor;
  v_backdropShadowBlur = a_backdropShadowBlur;
  v_backdropPadding = a_backdropPadding;
  v_backdropBorderColor = a_backdropBorderColor;
  v_backdropBorderWidth = borderWidth;
  v_backdropCornerRadius = cornerRadius;
  v_backdropArea = backdropArea;
}
`);return l}function Nd(a){var n=a.shapes,e=a.layers,t=a.shapeGlobalIds,r=pr(n),i=En(n).map(function(h){return"uniform ".concat(h.type," ").concat(h.name,";")}).join(`
`),o=function(f){return Sa(f,"nodeUV","1.0")},s;if(n.length===1)s="float nodeSdfNormalized = ".concat(o(n[0]),";");else{var l=n.map(function(h,f){var g=t?t[f]:f;return"    case ".concat(g,": nodeSdfNormalized = ").concat(o(h),"; break;")}).join(`
`),u=o(n[0]);s=`float nodeSdfNormalized;
  int shapeId = int(v_shapeId);
  switch (shapeId) {
`.concat(l,`
    default: nodeSdfNormalized = `).concat(u,`;
  }`)}var d=`float effectiveRadius = max(enlargedRadius - cornerRadius, 0.01);
  float ca = u_cameraAngle * v_nodeRotation;
  float ca_c = cos(ca);
  float ca_s = sin(ca);
  vec2 rotatedScreenUV = mat2(ca_c, -ca_s, ca_s, ca_c) * screenUV;
  vec2 nodeUV = vec2(rotatedScreenUV.x, -rotatedScreenUV.y) / effectiveRadius;`,c=`#version 300 es
precision highp float;

in vec2 v_uv;
in vec2 v_nodeCenter;
in float v_nodeRadius;
in vec2 v_labelCenter;
in vec2 v_labelHalfSize;
in float v_aaWidth;
in float v_shapeId;
in float v_nodeRotation;
in float v_labelAngle;
in vec4 v_backdropColor;
in vec4 v_backdropShadowColor;
in float v_backdropShadowBlur;
in float v_backdropPadding;
in vec4 v_backdropBorderColor;
in float v_backdropBorderWidth;
in float v_backdropCornerRadius;
in float v_backdropArea;
`.concat(Lo(n,e,"in"),`

uniform float u_cameraAngle;
`).concat(i,`

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 fragPicking;

`).concat(r,`
`).concat(yd,`
`).concat(xd,`
`).concat(_d,`
`).concat(Td,`

void main() {
  vec4 backdropColor = v_backdropColor;
  vec4 shadowColor = v_backdropShadowColor;
  float shadowBlur = v_backdropShadowBlur;
  float padding = v_backdropPadding;
  vec4 borderColor = v_backdropBorderColor;
  float borderWidth = v_backdropBorderWidth;
  float cornerRadius = v_backdropCornerRadius;

  float enlargedRadius = v_nodeRadius + padding;
  vec2 screenUV = v_uv - v_nodeCenter;
  `).concat(d,`

  // Query the correct shape SDF based on shapeId
  `).concat(s,`
  float nodeSdfPixels = nodeSdfNormalized * effectiveRadius - cornerRadius;

  // Label SDF with optional corner radius and rotation
  float labelSdfPixels;
  if (v_labelHalfSize.x > 0.0) {
    vec2 labelP = v_uv - v_labelCenter;
    labelSdfPixels = sdfRoundedRotatedBox(labelP, v_labelHalfSize, v_labelAngle, cornerRadius);
  } else {
    labelSdfPixels = 10000.0;
  }

  // Select area: 0=both, 1=node, 2=label
  float combinedSdf;
  if (v_backdropArea > 1.5) {
    combinedSdf = labelSdfPixels;
  } else if (v_backdropArea > 0.5) {
    combinedSdf = nodeSdfPixels;
  } else {
    combinedSdf = min(nodeSdfPixels, labelSdfPixels);
  }

  // Fill + border composite
  float outerEdge = smoothstep(v_aaWidth, -v_aaWidth, combinedSdf);
  vec4 background;
  if (borderWidth > 0.5) {
    float innerEdge = smoothstep(v_aaWidth, -v_aaWidth, combinedSdf + borderWidth);
    float fillAlpha = innerEdge * backdropColor.a;
    vec4 fill = vec4(backdropColor.rgb * fillAlpha, fillAlpha);
    float borderAlpha = (outerEdge - innerEdge) * borderColor.a;
    vec4 border = vec4(borderColor.rgb * borderAlpha, borderAlpha);
    background = fill + border * (1.0 - fill.a);
  } else {
    float fillAlpha = outerEdge * backdropColor.a;
    background = vec4(backdropColor.rgb * fillAlpha, fillAlpha);
  }

  // Gaussian-like shadow falloff (mimics canvas shadowBlur)
  vec4 shadow = vec4(0.0);
  float sigma = shadowBlur / 2.5;
  if (sigma > 0.001) {
    float shadowDist = max(0.0, combinedSdf);
    float shadowAlpha = exp(-(shadowDist * shadowDist) / (2.0 * sigma * sigma)) * shadowColor.a;
    shadow = vec4(shadowColor.rgb * shadowAlpha, shadowAlpha);
  }

  fragColor = background + shadow * (1.0 - background.a);
  fragPicking = vec4(0.0);
}
`);return c}function Md(a){var n=["u_matrix","u_sizeRatio","u_correctionRatio","u_cameraAngle","u_resolution","u_pixelRatio","u_labelMargin","u_zoomLabelSizeRatio","u_labelPixelSnapping","u_nodeDataTexture","u_nodeDataTextureWidth","u_nodeFrameTexture","u_nodeFrameTextureWidth","u_layerAttributeTexture","u_layerAttributeTextureWidth","u_layerAttributeTexelsPerNode"],e=M(En(a)),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;n.includes(r.name)||n.push(r.name)}}catch(i){e.e(i)}finally{e.f()}return n}function Od(a){return{vertexShader:zd(a),fragmentShader:Nd(a),uniforms:Md(a.shapes)}}function Wd(a,n,e,t){var r,i,o=t.label,s=o===void 0?{}:o,l=t.shapes,u=t.layers,d=t.getAttributeTexture,c=t.shapeGlobalIds;if(l.length===0)throw new Error("createBackdropProgram: at least one shape must be provided in 'shapes'");var h=(r=s.margin)!==null&&r!==void 0?r:5,f=(i=s.zoomToLabelSizeRatioFunction)!==null&&i!==void 0?i:function(){return 1},g={shapes:l,layers:u,shapeGlobalIds:c},m=Od(g),p=function(v){function b(){var y;Q(this,b);for(var _=arguments.length,x=new Array(_),T=0;T<_;T++)x[T]=arguments[T];return y=le(this,b,[].concat(x)),A(y,"totalBackdropCount",0),A(y,"bufferCapacity",0),y}return ue(b,v),J(b,[{key:"getDefinition",value:function(){var _=WebGL2RenderingContext,x=_.FLOAT,T=_.TRIANGLE_STRIP;return{VERTICES:4,VERTEX_SHADER_SOURCE:m.vertexShader,FRAGMENT_SHADER_SOURCE:m.fragmentShader,METHOD:T,UNIFORMS:m.uniforms,ATTRIBUTES:[{name:"a_nodeIndex",size:1,type:x},{name:"a_labelWidth",size:1,type:x},{name:"a_labelHeight",size:1,type:x},{name:"a_textHeight",size:1,type:x},{name:"a_positionMode",size:1,type:x},{name:"a_labelAngle",size:1,type:x},{name:"a_backdropColor",size:4,type:x},{name:"a_backdropShadowColor",size:4,type:x},{name:"a_backdropShadowBlur",size:1,type:x},{name:"a_backdropPadding",size:1,type:x},{name:"a_backdropBorderColor",size:4,type:x},{name:"a_backdropExtra",size:4,type:x},{name:"a_labelBoxOffset",size:2,type:x}],CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:x}],CONSTANT_DATA:[[-1,-1],[1,-1],[-1,1],[1,1]]}}},{key:"processBackdrop",value:function(_,x){var T=this.floats,R=this.STRIDE,E=_*R;T[E++]=x.nodeIndex,T[E++]=x.labelWidth,T[E++]=x.labelHeight,T[E++]=x.textHeight,T[E++]=Bt[x.position],T[E++]=x.labelAngle,T[E++]=x.backdropColor[0],T[E++]=x.backdropColor[1],T[E++]=x.backdropColor[2],T[E++]=x.backdropColor[3],T[E++]=x.backdropShadowColor[0],T[E++]=x.backdropShadowColor[1],T[E++]=x.backdropShadowColor[2],T[E++]=x.backdropShadowColor[3],T[E++]=x.backdropShadowBlur,T[E++]=x.backdropPadding,T[E++]=x.backdropBorderColor[0],T[E++]=x.backdropBorderColor[1],T[E++]=x.backdropBorderColor[2],T[E++]=x.backdropBorderColor[3],T[E++]=x.backdropBorderWidth,T[E++]=x.backdropCornerRadius,T[E++]=x.backdropLabelPadding,T[E++]=x.backdropArea,T[E++]=x.labelBoxOffset[0],T[E++]=x.labelBoxOffset[1]}},{key:"setUniforms",value:function(_,x){var T=x.gl,R=x.uniformLocations;T.uniformMatrix3fv(R.u_matrix,!1,_.matrix),T.uniform1f(R.u_sizeRatio,_.sizeRatio),T.uniform1f(R.u_correctionRatio,_.correctionRatio),T.uniform1f(R.u_cameraAngle,_.cameraAngle),T.uniform2f(R.u_resolution,_.width*_.pixelRatio,_.height*_.pixelRatio),T.uniform1f(R.u_pixelRatio,_.pixelRatio),T.uniform1f(R.u_labelMargin,b.labelMargin),T.uniform1f(R.u_zoomLabelSizeRatio,1/f(_.zoomRatio)),T.uniform1f(R.u_labelPixelSnapping,_.labelPixelSnapping),T.uniform1i(R.u_nodeDataTexture,_.nodeDataTextureUnit),T.uniform1i(R.u_nodeDataTextureWidth,_.nodeDataTextureWidth),T.uniform1i(R.u_nodeFrameTexture,_.nodeFrameTextureUnit),T.uniform1i(R.u_nodeFrameTextureWidth,_.nodeFrameTextureWidth);var E=d();R.u_layerAttributeTexture&&E&&(E.bind(it),T.uniform1i(R.u_layerAttributeTexture,it),T.uniform1i(R.u_layerAttributeTextureWidth,E.getTextureWidth()),T.uniform1i(R.u_layerAttributeTexelsPerNode,E.getTexelsPerItem()));var S=M(En(l)),w;try{for(S.s();!(w=S.n()).done;){var F=w.value;this.setTypedUniform(F,x)}}catch(D){S.e(D)}finally{S.f()}}},{key:"hasNothingToRender",value:function(){return this.totalBackdropCount===0}},{key:"drawWebGL",value:function(_,x){var T=x.gl;this.totalBackdropCount!==0&&(this.isInstanced?T.drawArraysInstanced(_,0,this.VERTICES,this.totalBackdropCount):T.drawArrays(_,0,this.totalBackdropCount*this.VERTICES))}},{key:"reallocate",value:function(_){this.totalBackdropCount=_,_>this.bufferCapacity&&(this.bufferCapacity=Math.max(_,Math.ceil(this.bufferCapacity*1.5)||10),ve(b,"reallocate",this,3)([this.bufferCapacity]))}}])}(bt);return A(p,"labelMargin",h),new p(a,n,e)}var Co=function(a){function n(){var e;Q(this,n);for(var t=arguments.length,r=new Array(t),i=0;i<t;i++)r[i]=arguments[i];return e=le(this,n,[].concat(r)),A(e,"totalCharacterCount",0),A(e,"bufferCapacity",0),e}return ue(n,a),J(n,[{key:"processLabel",value:function(t,r,i){if(i.hidden||!i.text)return 0;for(var o=i.text,s=o.length,l=0;l<s;l++){var u=o[l];this.processCharacter(r+l,i,u,l)}return s}},{key:"hasNothingToRender",value:function(){return this.totalCharacterCount===0}},{key:"drawWebGL",value:function(t,r){var i=r.gl;this.totalCharacterCount!==0&&(this.isInstanced?i.drawArraysInstanced(t,0,this.VERTICES,this.totalCharacterCount):i.drawArrays(t,0,this.totalCharacterCount*this.VERTICES))}},{key:"reallocate",value:function(t){this.totalCharacterCount=t,t>this.bufferCapacity&&(this.bufferCapacity=Math.max(t,Math.ceil(this.bufferCapacity*1.5)||1e3),ve(n,"reallocate",this,3)([this.bufferCapacity]))}}])}(bt);function Bd(){var a=`#version 300 es

in float a_nodeIndex;
in vec4 a_id;
in vec4 a_color;
in float a_labelWidth;
in float a_labelHeight;
in float a_textHeight;
in float a_positionMode;
in float a_labelAngle;
in float a_padding;
in vec2 a_quadCorner;

uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
uniform vec2 u_resolution;
uniform float u_pixelRatio;
uniform float u_labelMargin;
uniform float u_zoomLabelSizeRatio;
uniform float u_labelPixelSnapping;
uniform float u_pickingPadding;
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_nodeFrameTexture;
uniform int u_nodeFrameTextureWidth;

out vec4 v_id;
out vec4 v_color;

`.concat(Qe,`
`).concat(mt,`
`).concat(Ht,`
`).concat(Ao,`

void main() {
  int nodeIdx = int(a_nodeIndex);

  // Node data: (x, y, size, shapeId).
  vec4 nodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  vec2 nodePosition = nodeData.xy;
  float nodeSize = nodeData.z;

  // Shape-aware edge distance, read once from the shared frame texture.
  float edgeDist = readFrameTexel(u_nodeFrameTexture, u_nodeFrameTextureWidth, nodeIdx).r;

  // Per-node label rotation alignment: 0 = viewport, 1 = label turns with camera.
  float labelRotation = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx).g;

  `).concat(So,`

  float zoomScale = u_zoomLabelSizeRatio;
  float labelW = a_labelWidth * zoomScale * u_pixelRatio;
  float labelH = a_labelHeight * zoomScale * u_pixelRatio;
  float labelMargin = u_labelMargin * zoomScale * u_pixelRatio;
#ifdef PICKING_MODE
  float padding = u_pickingPadding * u_pixelRatio;
#else
  float padding = a_padding * u_pixelRatio;
#endif

  if (labelW <= 0.0) {
    gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
    v_id = vec4(0.0);
    v_color = vec4(0.0);
    return;
  }

  vec2 labelHalfSize = vec2(labelW * 0.5 + padding, labelH * 0.5 + padding);
  vec2 labelOffset = vec2(0.0);

  // Graph-aligned labels add the camera angle so the rect orbits with the text.
  float labelAngle = a_labelAngle - labelRotation * u_cameraAngle;
  float la_c = cos(labelAngle);
  float la_s = sin(labelAngle);
  mat2 labelRotMat = mat2(la_c, -la_s, la_s, la_c);

  vec3 nodeClip = u_matrix * vec3(nodePosition, 1.0);
  vec2 nodeScreen = vec2(
    (nodeClip.x + 1.0) * u_resolution.x,
    (1.0 - nodeClip.y) * u_resolution.y
  ) * 0.5;
  vec2 snapDelta = (round(nodeScreen) - nodeScreen) * u_labelPixelSnapping;

  if (a_positionMode < 4.0) {
    float labelStart = nodeRadiusPixels * edgeDist + labelMargin;
    float textHalf = a_textHeight * zoomScale * u_pixelRatio * 0.5;
    // Box center uses the text half-size; the padding expands the quad below.
    labelOffset = labelRotMat * labelBoxCenter(a_positionMode, labelStart, vec2(labelW * 0.5, labelH * 0.5), textHalf);
  }

  // Rotate the rect with the label so it stays aligned with the (rotated) text.
  vec2 localPos = labelOffset + labelRotMat * (a_quadCorner * labelHalfSize);
  vec2 ndcOffset = (localPos + snapDelta) * 2.0 / u_resolution;
  ndcOffset.y = -ndcOffset.y;

  gl_Position = vec4(nodeClip.xy + ndcOffset, 0.0, 1.0);
  v_id = a_id;
  v_color = a_color;
}
`);return a}var Ud=`#version 300 es
precision highp float;

in vec4 v_id;
in vec4 v_color;

out vec4 fragColor;

void main() {
  #ifdef PICKING_MODE
    fragColor = v_id;
  #else
    if (v_color.a <= 0.0) discard;
    // v_color is non-premultiplied RGBA (0-1); convert to premultiplied for blending
    fragColor = vec4(v_color.rgb * v_color.a, v_color.a);
  #endif
}
`;function Hd(a,n,e,t){var r,i,o=t.label,s=o===void 0?{}:o,l=(r=s.margin)!==null&&r!==void 0?r:Ut,u=(i=s.zoomToLabelSizeRatioFunction)!==null&&i!==void 0?i:function(){return 1},d=Bd(),c=function(h){function f(){var g;Q(this,f);for(var m=arguments.length,p=new Array(m),v=0;v<m;v++)p[v]=arguments[v];return g=le(this,f,[].concat(p)),A(g,"totalCount",0),A(g,"bufferCapacity",0),g}return ue(f,h),J(f,[{key:"getDefinition",value:function(){var m=WebGL2RenderingContext,p=m.FLOAT,v=m.UNSIGNED_BYTE,b=m.TRIANGLE_STRIP;return{VERTICES:4,VERTEX_SHADER_SOURCE:d,FRAGMENT_SHADER_SOURCE:Ud,METHOD:b,UNIFORMS:["u_matrix","u_sizeRatio","u_correctionRatio","u_cameraAngle","u_resolution","u_pixelRatio","u_labelMargin","u_zoomLabelSizeRatio","u_labelPixelSnapping","u_pickingPadding","u_nodeDataTexture","u_nodeDataTextureWidth","u_nodeFrameTexture","u_nodeFrameTextureWidth"],ATTRIBUTES:[{name:"a_nodeIndex",size:1,type:p},{name:"a_id",size:4,type:v,normalized:!0},{name:"a_color",size:4,type:v,normalized:!0},{name:"a_labelWidth",size:1,type:p},{name:"a_labelHeight",size:1,type:p},{name:"a_textHeight",size:1,type:p},{name:"a_positionMode",size:1,type:p},{name:"a_labelAngle",size:1,type:p},{name:"a_padding",size:1,type:p}],CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:p}],CONSTANT_DATA:[[-1,-1],[1,-1],[-1,1],[1,1]]}}},{key:"processLabelBackground",value:function(m,p){var v=this.floats,b=this.ints,y=m*this.STRIDE;v[y++]=p.nodeIndex,b[y++]=p.id,v[y++]=p.color,v[y++]=p.labelWidth,v[y++]=p.labelHeight,v[y++]=p.textHeight,v[y++]=p.positionMode,v[y++]=p.labelAngle,v[y++]=p.padding}},{key:"setUniforms",value:function(m,p){var v=p.gl,b=p.uniformLocations;v.uniformMatrix3fv(b.u_matrix,!1,m.matrix),v.uniform1f(b.u_sizeRatio,m.sizeRatio),v.uniform1f(b.u_correctionRatio,m.correctionRatio),v.uniform1f(b.u_cameraAngle,m.cameraAngle),v.uniform2f(b.u_resolution,m.width*m.pixelRatio,m.height*m.pixelRatio),v.uniform1f(b.u_pixelRatio,m.pixelRatio),v.uniform1f(b.u_labelMargin,f.labelMargin),v.uniform1f(b.u_zoomLabelSizeRatio,1/u(m.zoomRatio)),v.uniform1f(b.u_labelPixelSnapping,m.labelPixelSnapping),v.uniform1f(b.u_pickingPadding,m.labelPickingPadding),v.uniform1i(b.u_nodeDataTexture,m.nodeDataTextureUnit),v.uniform1i(b.u_nodeDataTextureWidth,m.nodeDataTextureWidth),v.uniform1i(b.u_nodeFrameTexture,m.nodeFrameTextureUnit),v.uniform1i(b.u_nodeFrameTextureWidth,m.nodeFrameTextureWidth)}},{key:"hasNothingToRender",value:function(){return this.totalCount===0}},{key:"drawWebGL",value:function(m,p){var v=p.gl;this.totalCount!==0&&v.drawArraysInstanced(v.TRIANGLE_STRIP,0,this.VERTICES,this.totalCount)}},{key:"reallocate",value:function(m){this.totalCount=m,m>this.bufferCapacity&&(this.bufferCapacity=Math.max(m,Math.ceil(this.bufferCapacity*1.5)||10),ve(f,"reallocate",this,3)([this.bufferCapacity]))}}])}(bt);return A(c,"labelMargin",l),new c(a,n,e)}var Ue={fontSize:64,buffer:8,radius:24,cutoff:.25,maxTextureSize:2048,debounceTimeout:100},yn=2,_n=1e20;function $d(a,n,e,t,r){var i=a+r*4,o=document.createElement("canvas");o.width=i,o.height=i;var s=o.getContext("2d",{willReadFrequently:!0});return s.font="".concat(t," ").concat(e," ").concat(a,"px ").concat(n),s.textBaseline="alphabetic",s.textAlign="left",s.fillStyle="black",{ctx:s,canvasSize:i,gridOuter:new Float64Array(i*i),gridInner:new Float64Array(i*i),f:new Float64Array(i),z:new Float64Array(i+1),v:new Uint16Array(i)}}function Vd(a,n,e,t,r){var i=a.ctx,o=a.canvasSize,s=i.measureText(n),l=s.width,u=s.actualBoundingBoxAscent,d=s.actualBoundingBoxDescent,c=s.actualBoundingBoxLeft,h=s.actualBoundingBoxRight,f=Math.ceil(u),g=Math.ceil(c),m=Math.max(0,Math.min(o-e,Math.ceil(c)+Math.ceil(h))),p=Math.min(o-e,f+Math.ceil(d)),v=m+2*e,b=p+2*e,y=Math.max(v*b,0),_=new Uint8ClampedArray(y),x={data:_,width:v,height:b,glyphWidth:m,glyphHeight:p,glyphTop:f,glyphLeft:g,glyphAdvance:l};if(m===0||p===0)return x;var T=a.gridInner,R=a.gridOuter;i.clearRect(e,e,m,p),i.fillText(n,e+g,e+f);var E=i.getImageData(e,e,m,p);R.fill(_n,0,y),T.fill(0,0,y);for(var S=0;S<p;S++)for(var w=0;w<m;w++){var F=E.data[4*(S*m+w)+3]/255;if(F!==0){var D=(S+e)*v+w+e;if(F===1)R[D]=0,T[D]=_n;else{var P=.5-F;R[D]=P>0?P*P:0,T[D]=P<0?P*P:0}}}ho(R,0,0,v,b,v,a.f,a.v,a.z),ho(T,e,e,m,p,v,a.f,a.v,a.z);for(var L=0;L<y;L++){var I=Math.sqrt(R[L])-Math.sqrt(T[L]);_[L]=Math.round(255-255*(I/t+r))}return x}function ho(a,n,e,t,r,i,o,s,l){for(var u=n;u<n+t;u++)fo(a,e*i+u,i,r,o,s,l);for(var d=e;d<e+r;d++)fo(a,d*i+n,1,t,o,s,l)}function fo(a,n,e,t,r,i,o){i[0]=0,o[0]=-_n,o[1]=_n,r[0]=a[n];for(var s=1,l=0,u=0;s<t;s++){r[s]=a[n+s*e];var d=s*s;do{var c=i[l];u=(r[s]-r[c]+d-c*c)/(s-c)/2}while(u<=o[l]&&--l>-1);l++,i[l]=s,o[l]=u,o[l+1]=_n}for(var h=0,f=0;h<t;h++){for(;o[f+1]<h;)f++;var g=i[f],m=h-g;a[n+h*e]=r[g]+m*m}}var pt=function(a){function n(){var e,t=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{};return Q(this,n),e=le(this,n),A(e,"fonts",new Map),A(e,"textures",[]),A(e,"cursor",{x:0,y:0,rowHeight:0,atlasIndex:0}),A(e,"pendingGlyphs",[]),A(e,"debounceTimer",null),e.options=O(O({},Ue),t),e.canvas=document.createElement("canvas"),e.canvas.width=e.options.maxTextureSize,e.canvas.height=e.options.maxTextureSize,e.ctx=e.canvas.getContext("2d",{willReadFrequently:!0}),e.measureCanvas=document.createElement("canvas"),e.measureCtx=e.measureCanvas.getContext("2d"),e.textures.push(e.ctx.getImageData(0,0,1,1)),e}return ue(n,a),J(n,[{key:"getFontKey",value:function(t){return"".concat(t.family,"-").concat(t.weight,"-").concat(t.style)}},{key:"registerFont",value:function(t){var r=this.getFontKey(t);if(this.fonts.has(r))return r;var i=$d(this.options.fontSize,t.family,t.weight,t.style,this.options.buffer);return this.fonts.set(r,{descriptor:t,generator:i,glyphs:new Map}),r}},{key:"ensureGlyphs",value:function(t,r){var i=this.fonts.get(r);if(!i)throw new Error('Font "'.concat(r,'" is not registered. Call registerFont() first.'));var o=!1,s=M(t),l;try{for(s.s();!(l=s.n()).done;){var u=l.value,d=u.codePointAt(0);d!==void 0&&(i.glyphs.has(d)||(this.pendingGlyphs.push({fontKey:r,charCode:d}),o=!0))}}catch(c){s.e(c)}finally{s.f()}o&&this.scheduleTextureGeneration()}},{key:"measureText",value:function(t,r){var i=this.fonts.get(r);if(!i)throw new Error('Font "'.concat(r,'" is not registered.'));var o=i.descriptor,s=o.family,l=o.weight,u=o.style;return this.measureCtx.font="".concat(u," ").concat(l," ").concat(this.options.fontSize,"px ").concat(s),this.measureCtx.measureText(t).width}},{key:"getGlyph",value:function(t,r){var i=this.fonts.get(r);if(i)return i.glyphs.get(t)}},{key:"getTextures",value:function(){return this.textures}},{key:"getFontCount",value:function(){return this.fonts.size}},{key:"getGlyphCount",value:function(){var t=0,r=M(this.fonts.values()),i;try{for(r.s();!(i=r.n()).done;){var o=i.value;t+=o.glyphs.size}}catch(s){r.e(s)}finally{r.f()}return t}},{key:"hasPendingGlyphs",value:function(){return this.pendingGlyphs.length>0}},{key:"flush",value:function(){this.debounceTimer&&(clearTimeout(this.debounceTimer),this.debounceTimer=null),this.generateTextures()}},{key:"destroy",value:function(){this.debounceTimer&&clearTimeout(this.debounceTimer),this.fonts.clear(),this.textures=[],this.pendingGlyphs=[],this.removeAllListeners()}},{key:"scheduleTextureGeneration",value:function(){var t=this;this.debounceTimer===null&&(this.options.debounceTimeout===null?this.generateTextures():this.debounceTimer=setTimeout(function(){t.debounceTimer=null,t.generateTextures()},this.options.debounceTimeout))}},{key:"generateTextures",value:function(){if(this.pendingGlyphs.length!==0){var t=this.options,r=t.maxTextureSize,i=t.buffer,o=t.radius,s=t.cutoff,l=M(this.pendingGlyphs),u;try{for(l.s();!(u=l.n()).done;){var d=u.value,c=d.fontKey,h=d.charCode,f=this.fonts.get(c);if(!(!f||f.glyphs.has(h))){var g=String.fromCodePoint(h),m=Vd(f.generator,g,i,o,s),p=m.width,v=m.height;this.cursor.x+p+yn>r&&(this.cursor.x=0,this.cursor.y+=this.cursor.rowHeight+yn,this.cursor.rowHeight=0),this.cursor.y+v+yn>r&&(this.finalizeCurrentTexture(),this.cursor={x:0,y:0,rowHeight:0,atlasIndex:this.cursor.atlasIndex+1},this.ctx.clearRect(0,0,r,r));for(var b=m.data,y=new Uint8ClampedArray(p*v*4),_=0;_<b.length;_++){var x=_*4;y[x]=255,y[x+1]=255,y[x+2]=255,y[x+3]=b[_]}var T=new ImageData(y,p,v);this.ctx.putImageData(T,this.cursor.x,this.cursor.y);var R={charCode:h,width:m.glyphWidth,height:m.glyphHeight,bearingX:-m.glyphLeft-i,bearingY:m.glyphTop+i,advance:m.glyphAdvance,atlasX:this.cursor.x,atlasY:this.cursor.y,atlasWidth:p,atlasHeight:v,atlasIndex:this.cursor.atlasIndex};f.glyphs.set(h,R),this.cursor.x+=p+yn,this.cursor.rowHeight=Math.max(this.cursor.rowHeight,v)}}}catch(E){l.e(E)}finally{l.f()}this.finalizeCurrentTexture(),this.pendingGlyphs=[],this.emit(n.ATLAS_UPDATED_EVENT,{textures:this.textures,glyphCount:this.getGlyphCount()})}}},{key:"finalizeCurrentTexture",value:function(){var t=this.options.maxTextureSize,r=this.cursor.y>0||this.cursor.rowHeight>0,i=Math.min(t,Math.max(this.cursor.x,r?t:1)),o=Math.min(t,this.cursor.y+this.cursor.rowHeight+yn),s=this.ctx.getImageData(0,0,i,o);this.cursor.atlasIndex>=this.textures.length?this.textures.push(s):this.textures[this.cursor.atlasIndex]=s}}])}(bo.EventEmitter);A(pt,"ATLAS_UPDATED_EVENT","atlasUpdated");var qd=Ue.fontSize;function Xd(){var a=`  // -------------------------------------------------------------------------
  // Step 3: Calculate position offset from the shared edge distance
  // -------------------------------------------------------------------------
  vec2 positionOffset = vec2(0.0);

  if (a_positionMode < 4.0) {
    vec2 screenDir = getLabelDirection(a_positionMode);
    float boundaryDistPixels = nodeRadiusPixels * edgeDist;
    positionOffset = screenDir * (boundaryDistPixels + margin);
  }`,n=`#version 300 es

// ============================================================================
// Attributes
// ============================================================================

// Per-character (instanced)
in float a_nodeIndex;        // Index into node data texture
in vec2 a_charOffset;        // Character offset from label origin (pixels)
in vec2 a_charSize;          // Character dimensions (pixels)
in vec4 a_texCoords;         // Atlas coords: (x, y, width, height) in pixels
in vec4 a_color;             // Text color (RGBA)
in float a_margin;           // Gap between node edge and label (pixels)
in float a_positionMode;     // Position: 0=right, 1=left, 2=above, 3=below, 4=over
in float a_labelWidth;       // Total label width (pixels)
in float a_labelHeight;      // Label height (pixels)
in float a_verticalCenter;   // Vertical center offset from baseline (pixels)
in float a_textHeight;       // Actual text height: maxAscent + maxDescent (pixels)
in float a_labelAngle;       // Label rotation angle (radians)

// Per-vertex (constant quad corners)
in vec2 a_quadCorner;        // Quad corner: [-1,-1], [1,-1], [-1,1], [1,1]

// ============================================================================
// Uniforms
// ============================================================================

uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
uniform vec2 u_resolution;
uniform vec2 u_atlasSize;
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_nodeFrameTexture;
uniform int u_nodeFrameTextureWidth;
uniform float u_zoomLabelSizeRatio;
uniform float u_labelPixelSnapping;
uniform float u_pixelRatio;

// ============================================================================
// Varyings
// ============================================================================

out vec2 v_texCoord;
out vec4 v_color;
out float v_fontScale;

// ============================================================================
// Constants
// ============================================================================

const float bias = 255.0 / 254.0;
const float ATLAS_FONT_SIZE = `.concat(he(qd),`;

// ============================================================================
// Helper Functions
// ============================================================================

`).concat(Qe,`
`).concat(mt,`
`).concat(Ht,`
`).concat(Ro,`

// ============================================================================
// Main
// ============================================================================

void main() {
  // -------------------------------------------------------------------------
  // Step 0: Fetch node data + shared edge distance from textures
  // -------------------------------------------------------------------------
  // Node-data texture format: vec4(x, y, size, shapeId)
  // 2D texture layout: texCoord = (index % width, index / width)
  int nodeIdx = int(a_nodeIndex);
  vec4 nodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  vec2 a_anchorPosition = nodeData.xy;
  float a_nodeSize = nodeData.z;

  // Normalized edge distance from the shared frame texture (the frame-pass ran
  // the SDF search once; the label just reads the result).
  float edgeDist = readFrameTexel(u_nodeFrameTexture, u_nodeFrameTextureWidth, nodeIdx).r;

  // Per-node label rotation alignment: 0 = viewport, 1 = label turns with camera.
  float labelRotation = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx).g;

  // Apply zoom-dependent label size scaling
  // Positional values are in CSS pixels; multiply by u_pixelRatio to convert to
  // physical pixels, which is what the NDC conversion (/ u_resolution) expects.
  float zoomScale = u_zoomLabelSizeRatio;
  float margin = a_margin * zoomScale * u_pixelRatio;
  vec2 charOffset = a_charOffset * zoomScale * u_pixelRatio;
  vec2 charSize = a_charSize * zoomScale * u_pixelRatio;
  float labelWidth = a_labelWidth * zoomScale * u_pixelRatio;
  float labelHeight = a_labelHeight * zoomScale;

  // Font scale: ratio of CSS label size to the base atlas font size.
  // Divided by u_pixelRatio because the atlas is generated at ATLAS_FONT_SIZE * pixelRatio,
  // which cancels out the u_pixelRatio in the fragment shader's gamma formula and keeps
  // the anti-aliasing band width consistent across pixel densities.
  v_fontScale = a_labelHeight * zoomScale / (ATLAS_FONT_SIZE * u_pixelRatio);

  // -------------------------------------------------------------------------
  // Step 1: Transform node position to clip space
  // -------------------------------------------------------------------------
  vec3 anchorClip = u_matrix * vec3(a_anchorPosition, 1.0);

  // -------------------------------------------------------------------------
  // Step 2: Convert node size to screen pixels
  // -------------------------------------------------------------------------
  float matrixScaleX = length(vec2(u_matrix[0][0], u_matrix[1][0]));
  float nodeRadiusGraphSpace = a_nodeSize * u_correctionRatio / u_sizeRatio * 2.0;
  float nodeRadiusNDC = nodeRadiusGraphSpace * matrixScaleX;
  float nodeRadiusPixels = nodeRadiusNDC * u_resolution.x / 2.0;

`).concat(a,`

  // -------------------------------------------------------------------------
  // Step 4: Calculate final vertex position
  // -------------------------------------------------------------------------
  vec2 cornerOffset = (a_quadCorner + 1.0) * 0.5;
  vec2 charPixelPos = positionOffset + charOffset + cornerOffset * charSize;

  // Apply text alignment based on position mode
  float verticalCenter = a_verticalCenter * zoomScale * u_pixelRatio;
  float textHeight = a_textHeight * zoomScale * u_pixelRatio;
  float baselineToDescent = textHeight / 2.0 - verticalCenter;
  float baselineToAscent = textHeight / 2.0 + verticalCenter;

  if (a_positionMode < 0.5) {
    // Right: vertically center
    charPixelPos.y += verticalCenter;
  } else if (a_positionMode < 1.5) {
    // Left: right-align and vertically center
    charPixelPos.x -= labelWidth;
    charPixelPos.y += verticalCenter;
  } else if (a_positionMode < 2.5) {
    // Above: center horizontally, bottom of text at anchor
    charPixelPos.x -= labelWidth * 0.5;
    charPixelPos.y -= baselineToDescent;
  } else if (a_positionMode < 3.5) {
    // Below: center horizontally, top of text at anchor
    charPixelPos.x -= labelWidth * 0.5;
    charPixelPos.y += baselineToAscent;
  } else {
    // Over: center both
    charPixelPos.x -= labelWidth * 0.5;
    charPixelPos.y += verticalCenter;
  }

  // Apply label angle rotation. Graph-aligned labels add the camera angle so the
  // whole label orbits the node in lockstep with the frame-pass edge distance.
  float labelAngle = a_labelAngle - labelRotation * u_cameraAngle;
  float la_c = cos(labelAngle);
  float la_s = sin(labelAngle);
  mat2 labelRotMat = mat2(la_c, -la_s, la_s, la_c);
  charPixelPos = labelRotMat * charPixelPos;

  // Snap node center to pixel grid so label/backdrop/attachment move as a unit
  vec2 nodeScreen = vec2(
    (anchorClip.x + 1.0) * u_resolution.x,
    (1.0 - anchorClip.y) * u_resolution.y
  ) * 0.5;
  charPixelPos += (round(nodeScreen) - nodeScreen) * u_labelPixelSnapping;

  // Convert to NDC (flip Y: screen Y-down -> clip Y-up)
  vec2 ndcOffset = vec2(charPixelPos.x, -charPixelPos.y) * 2.0 / u_resolution;
  gl_Position = vec4(anchorClip.xy + ndcOffset, 0.0, 1.0);

  // -------------------------------------------------------------------------
  // Step 5: Texture coordinates
  // -------------------------------------------------------------------------
  v_texCoord = (a_texCoords.xy + cornerOffset * a_texCoords.zw) / u_atlasSize;

  // -------------------------------------------------------------------------
  // Step 6: Pass color
  // -------------------------------------------------------------------------
  v_color = a_color;
  v_color.a *= bias;
}
`);return n}function jd(){var a=`#version 300 es
precision highp float;

in vec2 v_texCoord;
in vec4 v_color;
in float v_fontScale;

uniform sampler2D u_atlas;
uniform float u_gamma;
uniform float u_sdfBuffer;
uniform float u_pixelRatio;

// Fragment output (single target - picking handled via separate pass)
out vec4 fragColor;

void main() {
  #ifdef PICKING_MODE
    // Labels are not pickable - discard all fragments in picking mode
    fragColor = vec4(0.0);
    discard;
  #else
    // Sample SDF value from atlas (high = inside glyph, low = outside)
    float sdfValue = texture(u_atlas, v_texCoord).a;

    // Edge threshold: 1.0 - cutoff = 0.75 for default cutoff=0.25
    // This is where the glyph edge is located in the SDF
    float edgeThreshold = 1.0 - u_sdfBuffer;

    // Gamma controls the anti-aliasing band width.
    // Scale inversely with font scale so small labels get a wider AA band
    // (smoother) and large labels get a tighter band (sharper).
    float gamma = u_gamma / (u_pixelRatio * v_fontScale);

    // Pure gamma-based anti-aliasing using smoothstep
    // The AA band extends from (threshold - gamma) to (threshold + gamma)
    float alpha = smoothstep(edgeThreshold - gamma, edgeThreshold + gamma, sdfValue);

    // Premultiplied alpha output for correct blending
    float finalAlpha = v_color.a * alpha;
    fragColor = vec4(v_color.rgb * finalAlpha, finalAlpha);
  #endif
}
`;return a}function Yd(){return["u_matrix","u_sizeRatio","u_correctionRatio","u_cameraAngle","u_resolution","u_atlasSize","u_atlas","u_gamma","u_sdfBuffer","u_pixelRatio","u_nodeDataTexture","u_nodeDataTextureWidth","u_nodeFrameTexture","u_nodeFrameTextureWidth","u_zoomLabelSizeRatio","u_labelPixelSnapping"]}function Kd(){return{vertexShader:Xd(),fragmentShader:jd(),uniforms:Yd()}}function Zd(a,n,e,t){var r,i,o=t.label,s=o===void 0?{}:o,l=(r=s.margin)!==null&&r!==void 0?r:Ut,u=(i=s.zoomToLabelSizeRatioFunction)!==null&&i!==void 0?i:function(){return 1},d=Kd(),c=function(h){function f(g,m,p){var v,b,y,_;if(Q(this,f),_=le(this,f,[g,m,p]),A(_,"atlasTexture",null),A(_,"atlasNeedsUpdate",!1),A(_,"labelGlyphCache",new Map),_.atlasFontSize=Ue.fontSize*bn(),_.atlasManager=new pt({fontSize:_.atlasFontSize}),_.gamma=.025,_.sdfBuffer=Ue.cutoff,_.atlasTexture=g.createTexture(),!_.atlasTexture)throw new Error("NodeLabelProgram: failed to create atlas texture");g.bindTexture(g.TEXTURE_2D,_.atlasTexture),g.texParameteri(g.TEXTURE_2D,g.TEXTURE_WRAP_S,g.CLAMP_TO_EDGE),g.texParameteri(g.TEXTURE_2D,g.TEXTURE_WRAP_T,g.CLAMP_TO_EDGE),g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MIN_FILTER,g.LINEAR),g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MAG_FILTER,g.LINEAR),g.bindTexture(g.TEXTURE_2D,null),_.atlasManager.on(pt.ATLAS_UPDATED_EVENT,function(){_.atlasNeedsUpdate=!0});var x={family:((v=s.font)===null||v===void 0?void 0:v.family)||"sans-serif",weight:((b=s.font)===null||b===void 0?void 0:b.weight)||"normal",style:((y=s.font)===null||y===void 0?void 0:y.style)||"normal"};return _.defaultFontKey=_.atlasManager.registerFont(x),_}return ue(f,h),J(f,[{key:"getDefinition",value:function(){var m=WebGL2RenderingContext,p=m.FLOAT,v=m.UNSIGNED_BYTE,b=m.TRIANGLE_STRIP;return{VERTICES:4,VERTEX_SHADER_SOURCE:d.vertexShader,FRAGMENT_SHADER_SOURCE:d.fragmentShader,METHOD:b,UNIFORMS:d.uniforms,ATTRIBUTES:[{name:"a_nodeIndex",size:1,type:p},{name:"a_charOffset",size:2,type:p},{name:"a_charSize",size:2,type:p},{name:"a_texCoords",size:4,type:p},{name:"a_color",size:4,type:v,normalized:!0},{name:"a_margin",size:1,type:p},{name:"a_positionMode",size:1,type:p},{name:"a_labelWidth",size:1,type:p},{name:"a_labelHeight",size:1,type:p},{name:"a_verticalCenter",size:1,type:p},{name:"a_textHeight",size:1,type:p},{name:"a_labelAngle",size:1,type:p}],CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:p}],CONSTANT_DATA:[[-1,-1],[1,-1],[-1,1],[1,1]]}}},{key:"prepareLabelGlyphs",value:function(m,p){if(p.hidden||!p.text){this.labelGlyphCache.delete(m);return}var v=p.text,b=p.fontKey||this.defaultFontKey;this.atlasManager.ensureGlyphs(v,b);var y=[],_=[],x=0,T=0,R=0,E=M(v),S;try{for(E.s();!(S=E.n()).done;){var w=S.value,F=w.codePointAt(0);if(F===void 0){y.push(void 0),_.push(x);continue}var D=this.atlasManager.getGlyph(F,b);y.push(D),_.push(x),D&&(x+=D.advance,T=Math.max(T,D.bearingY),R=Math.max(R,D.atlasHeight-D.bearingY))}}catch(P){E.e(P)}finally{E.f()}this.labelGlyphCache.set(m,{glyphs:y,xOffsets:_,totalWidth:x,totalHeight:T+R,verticalCenterOffset:(T-R)/2})}},{key:"processCharacter",value:function(m,p,v,b){var y=this.floats,_=this.STRIDE,x=m*_,T=this.labelGlyphCache.get(p.parentKey);if(!T||!T.glyphs[b]){for(var R=0;R<_;R++)y[x+R]=0;return}var E=T.glyphs[b],S=T.xOffsets[b],w=p.size/this.atlasFontSize,F=Pe(p.color),D=x;y[D++]=p.nodeIndex,y[D++]=(S+E.bearingX)*w,y[D++]=-E.bearingY*w,y[D++]=E.atlasWidth*w,y[D++]=E.atlasHeight*w,y[D++]=E.atlasX,y[D++]=E.atlasY,y[D++]=E.atlasWidth,y[D++]=E.atlasHeight,y[D++]=F,y[D++]=p.margin,y[D++]=Bt[p.position],y[D++]=T.totalWidth*w,y[D++]=p.size,y[D++]=T.verticalCenterOffset*w,y[D++]=T.totalHeight*w,y[D++]=p.labelAngle}},{key:"processLabel",value:function(m,p,v){return this.prepareLabelGlyphs(m,v),ve(f,"processLabel",this,3)([m,p,v])}},{key:"updateAtlasTexture",value:function(){if(this.atlasNeedsUpdate){var m=this.normalProgram.gl,p=this.atlasManager.getTextures();if(p.length!==0){var v=p[0];m.bindTexture(m.TEXTURE_2D,this.atlasTexture),m.texImage2D(m.TEXTURE_2D,0,m.RGBA,v.width,v.height,0,m.RGBA,m.UNSIGNED_BYTE,v.data),m.bindTexture(m.TEXTURE_2D,null),this.atlasNeedsUpdate=!1}}}},{key:"setUniforms",value:function(m,p){var v=p.gl,b=p.uniformLocations;v.uniformMatrix3fv(b.u_matrix,!1,m.matrix),v.uniform1f(b.u_sizeRatio,m.sizeRatio),v.uniform1f(b.u_correctionRatio,m.correctionRatio),v.uniform1f(b.u_cameraAngle,m.cameraAngle),v.uniform2f(b.u_resolution,m.width*m.pixelRatio,m.height*m.pixelRatio);var y=this.atlasManager.getTextures();y.length>0?v.uniform2f(b.u_atlasSize,y[0].width,y[0].height):v.uniform2f(b.u_atlasSize,1,1),v.activeTexture(v.TEXTURE0),v.bindTexture(v.TEXTURE_2D,this.atlasTexture),v.uniform1i(b.u_atlas,0),b.u_nodeDataTexture!==void 0&&v.uniform1i(b.u_nodeDataTexture,m.nodeDataTextureUnit),b.u_nodeDataTextureWidth!==void 0&&v.uniform1i(b.u_nodeDataTextureWidth,m.nodeDataTextureWidth),v.uniform1i(b.u_nodeFrameTexture,m.nodeFrameTextureUnit),v.uniform1i(b.u_nodeFrameTextureWidth,m.nodeFrameTextureWidth),v.uniform1f(b.u_gamma,this.gamma),v.uniform1f(b.u_sdfBuffer,this.sdfBuffer),v.uniform1f(b.u_pixelRatio,m.pixelRatio),v.uniform1f(b.u_zoomLabelSizeRatio,1/f.zoomToLabelSizeRatioFunction(m.zoomRatio)),v.uniform1f(b.u_labelPixelSnapping,m.labelPixelSnapping)}},{key:"renderProgram",value:function(m,p){this.updateAtlasTexture(),this.atlasManager.hasPendingGlyphs()&&(this.atlasManager.flush(),this.updateAtlasTexture()),ve(f,"renderProgram",this,3)([m,p])}},{key:"registerFont",value:function(m){var p=arguments.length>1&&arguments[1]!==void 0?arguments[1]:"normal",v=arguments.length>2&&arguments[2]!==void 0?arguments[2]:"normal";return this.atlasManager.registerFont({family:m,weight:p,style:v})}},{key:"getAtlasManager",value:function(){return this.atlasManager}},{key:"measureLabel",value:function(m,p,v){var b=v||this.defaultFontKey;this.atlasManager.ensureGlyphs(m,b),this.atlasManager.hasPendingGlyphs()&&this.atlasManager.flush();var y=0,_=0,x=0,T=M(m),R;try{for(T.s();!(R=T.n()).done;){var E=R.value,S=E.codePointAt(0);if(S!==void 0){var w=this.atlasManager.getGlyph(S,b);w&&(y+=w.advance,_=Math.max(_,w.bearingY),x=Math.max(x,w.atlasHeight-w.bearingY))}}}catch(D){T.e(D)}finally{T.f()}var F=p/this.atlasFontSize;return{width:y*F,height:p,textHeight:(_+x)*F}}},{key:"ensureGlyphsReady",value:function(m,p){var v=p||this.defaultFontKey,b=M(m),y;try{for(b.s();!(y=b.n()).done;){var _=y.value;this.atlasManager.ensureGlyphs(_,v)}}catch(x){b.e(x)}finally{b.f()}this.atlasManager.flush()}},{key:"kill",value:function(){var m=this.normalProgram.gl;this.atlasTexture&&(m.deleteTexture(this.atlasTexture),this.atlasTexture=null),this.atlasManager.destroy(),this.labelGlyphCache.clear(),ve(f,"kill",this,3)([])}}])}(Co);return A(c,"labelMargin",l),A(c,"zoomToLabelSizeRatioFunction",u),new c(a,n,e)}var Qd=`#version 300 es
precision highp float;

in float v_edgeDist;

// R32F target: only the .r channel is stored.
out vec4 fragColor;

void main() {
  fragColor = vec4(v_edgeDist, 0.0, 0.0, 0.0);
}
`;function Jd(a,n,e){var t=pr(a),r=En(a).map(function(g){return"uniform ".concat(g.type," ").concat(g.name,";")}).join(`
`),i=Ed(a,e),o=i.code,s=i.multiShape,l=$t(a,n),u=Object.keys(l.specs).map(function(g){return"float v_".concat(g,";")}).join(`
`),d=Wt(l,{varPrefix:"nodeAttr",baseTexelExpr:"nodeIdx * u_layerAttributeTexelsPerNode",textureWidthUniform:"u_layerAttributeTextureWidth",textureSamplerUniform:"u_layerAttributeTexture"}),c=d.fetchCode,h=d.varyingAssignments,f=`#version 300 es
precision highp float;

uniform float u_cameraAngle;
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform float u_frameTextureWidth;
uniform float u_frameTextureHeight;
uniform sampler2D u_layerAttributeTexture;
uniform int u_layerAttributeTextureWidth;
uniform int u_layerAttributeTexelsPerNode;
`.concat(r,`

in float a_nodeIndex;     // node-data texture index (also the target frame texel)
in float a_positionMode;  // 0=right 1=left 2=above 3=below 4=over
in float a_labelAngle;    // intrinsic label angle (radians)

out float v_edgeDist;

// Shape attributes (plain globals: this pass is vertex-only)
`).concat(u,`

`).concat(Qe,`
`).concat(mt,`
`).concat(t,`
`).concat(o,`
`).concat(Ro,`

void main() {
  int nodeIdx = int(a_nodeIndex);
`).concat(c,`
`).concat(h,`
  `).concat(s?`// Multi-shape: the shape id lives in the node-data texture's .w channel:
  g_shapeId = int(readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx).w);`:"// Single-shape mode, shape id not needed",`

  // Per-node rotation alignment (0 = viewport, 1 = graph).
  vec4 nodeFlags = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, nodeIdx);
  float nodeRotation = nodeFlags.r;
  float labelRotation = nodeFlags.g;

  // Effective angle: intrinsic (style-given) plus the camera angle when the label
  // is graph-aligned. The companions place the box at this same angle.
  float effectiveAngle = a_labelAngle - labelRotation * u_cameraAngle;

  // The "over" mode (4) sits on the node center, so it has no edge distance.
  float edgeDist = 0.0;
  if (a_positionMode < 4.0) {
    vec2 screenDir = getLabelDirection(a_positionMode);
    // Rotate by the effective label angle. Inlined rather than via rotate2D()
    // because the shape SDFs (getShapeGLSLForShapes) already define that helper
    // for multi-shape programs, and redefining it would be a GLSL error.
    float ea_c = cos(effectiveAngle);
    float ea_s = sin(effectiveAngle);
    vec2 rotatedScreenDir = mat2(ea_c, -ea_s, ea_s, ea_c) * screenDir;
    // Screen (Y-down) -> SDF (Y-up).
    vec2 sdfDir = vec2(rotatedScreenDir.x, -rotatedScreenDir.y);
    // Counter-rotate into the shape's local frame for graph-aligned nodes, so the
    // boundary is queried against the shape's actual on-screen orientation.
    float nodeCa = -u_cameraAngle * nodeRotation;
    float nc = cos(nodeCa), ns = sin(nodeCa);
    sdfDir = mat2(nc, -ns, ns, nc) * sdfDir;
    edgeDist = findEdgeDistance(sdfDir, 1.0);
  }
  v_edgeDist = edgeDist;

  // Scatter to this node's texel center in the frame texture.
  float x = mod(a_nodeIndex, u_frameTextureWidth);
  float y = floor(a_nodeIndex / u_frameTextureWidth);
  vec2 ndc = (vec2(x, y) + 0.5) / vec2(u_frameTextureWidth, u_frameTextureHeight) * 2.0 - 1.0;
  gl_Position = vec4(ndc, 0.0, 1.0);
  gl_PointSize = 1.0;
}
`);return f}var Po=function(){function a(n,e){Q(this,a),A(this,"uniformLocations",{});var t=e.shapes,r=e.layers,i=e.shapeGlobalIds;if(t.length===0)throw new Error("NodeLabelFramePass: at least one shape must be provided");this.gl=n,this.shapeUniforms=En(t),this.hasAttributeData=Object.keys($t(t,r).offsets).length>0,this.vertexShader=fr(n,Jd(t,r,i)),this.fragmentShader=gr(n,Qd),this.program=vr(n,[this.vertexShader,this.fragmentShader]);var o=["u_cameraAngle","u_nodeDataTexture","u_nodeDataTextureWidth","u_frameTextureWidth","u_frameTextureHeight","u_layerAttributeTexture","u_layerAttributeTextureWidth","u_layerAttributeTexelsPerNode"].concat(V(this.shapeUniforms.map(function(v){return v.name}))),s=M(o),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;this.uniformLocations[u]=n.getUniformLocation(this.program,u)}}catch(v){s.e(v)}finally{s.f()}var d=a.FLOATS_PER_POINT*4;this.vao=n.createVertexArray(),this.buffer=n.createBuffer(),n.bindVertexArray(this.vao),n.bindBuffer(n.ARRAY_BUFFER,this.buffer);var c=M([["a_nodeIndex",0],["a_positionMode",4],["a_labelAngle",8]]),h;try{for(c.s();!(h=c.n()).done;){var f=te(h.value,2),g=f[0],m=f[1],p=n.getAttribLocation(this.program,g);p>=0&&(n.enableVertexAttribArray(p),n.vertexAttribPointer(p,1,n.FLOAT,!1,d,m))}}catch(v){c.e(v)}finally{c.f()}n.bindVertexArray(null)}return J(a,[{key:"run",value:function(e,t,r,i,o){if(t!==0){var s=this.gl;s.useProgram(this.program),s.bindVertexArray(this.vao),s.bindBuffer(s.ARRAY_BUFFER,this.buffer),s.bufferData(s.ARRAY_BUFFER,e.subarray(0,t*a.FLOATS_PER_POINT),s.DYNAMIC_DRAW);var l=this.uniformLocations;s.uniform1f(l.u_cameraAngle,i.cameraAngle),s.uniform1i(l.u_nodeDataTexture,i.nodeDataTextureUnit),s.uniform1i(l.u_nodeDataTextureWidth,i.nodeDataTextureWidth),s.uniform1f(l.u_frameTextureWidth,r.getTextureWidth()),s.uniform1f(l.u_frameTextureHeight,r.getTextureHeight()),this.hasAttributeData&&o&&(o.bind(it),l.u_layerAttributeTexture&&s.uniform1i(l.u_layerAttributeTexture,it),l.u_layerAttributeTextureWidth&&s.uniform1i(l.u_layerAttributeTextureWidth,o.getTextureWidth()),l.u_layerAttributeTexelsPerNode&&s.uniform1i(l.u_layerAttributeTexelsPerNode,o.getTexelsPerItem()));var u=M(this.shapeUniforms),d;try{for(u.s();!(d=u.n()).done;){var c=d.value;yr(s,this.uniformLocations[c.name],c)}}catch(h){u.e(h)}finally{u.f()}r.bindAsRenderTarget(),s.disable(s.BLEND),s.disable(s.DEPTH_TEST),s.drawArrays(s.POINTS,0,t),s.bindFramebuffer(s.FRAMEBUFFER,null),s.bindVertexArray(null)}}},{key:"kill",value:function(){var e=this.gl;e.deleteProgram(this.program),e.deleteShader(this.vertexShader),e.deleteShader(this.fragmentShader),e.deleteBuffer(this.buffer),e.deleteVertexArray(this.vao)}}])}();A(Po,"FLOATS_PER_POINT",3);function ko(a,n,e,t,r){var i,o=t.label,s=o===void 0?{}:o,l=t.shapes;if(l.length===0)throw new Error("createNodeProgram: at least one shape must be provided in 'shapes'");var u={},d=[],c;l.forEach(function(R,E){var S=vd(R);E===0&&(c=S),u[R.name]=E,d[E]=Sn(S)});var h=V(t.layers),f=co({shapes:l,layers:h,shapeGlobalIds:l.length>1?d:void 0,antialias:r}),g=Zd(a,null,e,{label:s}),m=Wd(a,null,e,{shapes:l,layers:h,getAttributeTexture:function(){return T.getAttributeTexture()},label:s,shapeGlobalIds:l.length>1?d:void 0}),p=Hd(a,n,e,{label:s}),v=t.labelAttachments&&Object.keys(t.labelAttachments).length>0?Pd(a,null,e,{label:s}):null,b=new Po(a,{shapes:l,layers:h,shapeGlobalIds:l.length>1?d:void 0}),y=wa(l,h),_=Fe(y),x=(i=function(R){function E(S,w,F){var D;Q(this,E),D=le(this,E,[S,w,F]),A(D,"layerLifecycles",new Map),A(D,"layersNeedingRegeneration",new Set),A(D,"attrDescriptors",[]),D._pickingBuffer=w;var P=x.layerTextures.get(S);P||(P=new Ra(S,_),x.layerTextures.set(S,P)),D.layerAttributeTexture=P;var L=x.textureRefCounts.get(S)||0;x.textureRefCounts.set(S,L+1),D.packedAttributeData=new Float32Array(_.floatsPerItem),h.forEach(function(z,G){if(z.lifecycle){var k={gl:S,renderer:{refresh:function(){return F.refresh()}},getUniformLocation:function($){return S.getUniformLocation(D.normalProgram.program,$)},requestShaderRegeneration:function(){D.layersNeedingRegeneration.add(G)},requestRefresh:function(){F.refresh()}},C=z.lifecycle(k);D.layerLifecycles.set(G,C)}}),D.layerLifecycles.forEach(function(z){var G;(G=z.init)===null||G===void 0||G.call(z)});var I=new Map;return D.layerLifecycles.forEach(function(z,G){z.getAttributeData&&I.set(G,z)}),D.attrDescriptors=Aa(y,_,I),D}return ue(E,R),J(E,[{key:"getDefinition",value:function(){var w=WebGL2RenderingContext,F=w.FLOAT,D=w.TRIANGLE_STRIP;return{VERTICES:4,VERTEX_SHADER_SOURCE:f.vertexShader,FRAGMENT_SHADER_SOURCE:f.fragmentShader,METHOD:D,UNIFORMS:f.uniforms,ATTRIBUTES:f.attributes,CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:F}],CONSTANT_DATA:[[-1,-1],[1,-1],[-1,1],[1,1]]}}},{key:"maybeRegenerateShaders",value:function(){var w=this;if(this.layersNeedingRegeneration.size!==0){h=h.map(function(G,k){if(w.layersNeedingRegeneration.has(k)){var C=w.layerLifecycles.get(k);if(C!=null&&C.regenerate){var N=C.regenerate();return O(O({},N),{},{lifecycle:G.lifecycle})}}return G}),this.layersNeedingRegeneration.clear(),f=co({shapes:l,layers:h,shapeGlobalIds:l.length>1?d:void 0,antialias:this.renderer.getSetting("antialiasNodes")});var F=this.normalProgram.gl,D=this.normalProgram,P=D.program,L=D.buffer,I=D.vertexShader,z=D.fragmentShader;F.deleteProgram(P),F.deleteBuffer(L),F.deleteShader(I),F.deleteShader(z),this.normalProgram=this.getProgramInfo("normal",F,f.vertexShader,f.fragmentShader,this._pickingBuffer)}}},{key:"getAttributeTexture",value:function(){return this.layerAttributeTexture}},{key:"uploadLayerTexture",value:function(){this.layerAttributeTexture.upload()}},{key:"process",value:function(w,F,D,P){var L=F*this.STRIDE;if(D.visibility==="hidden"){for(var I=L+this.STRIDE;L<I;L++)this.floats[L]=0;this.floats[F*this.STRIDE]=Do;return}this.processVisibleItem(It(w),L,D,P)}},{key:"processVisibleItem",value:function(w,F,D,P){var L,I=this.floats,z=this.ints;if(I[F++]=P,z[F++]=w,I[F++]=(L=D.opacity)!==null&&L!==void 0?L:1,_.floatsPerItem!==0){var G=this.packedAttributeData;Da(this.attrDescriptors,D,G,D.color,this.layerLifecycles,0),this.layerAttributeTexture.updateAllAttributesAtRow(P,G)}}},{key:"setUniforms",value:function(w,F){var D=this,P=F.gl,L=F.uniformLocations;L.u_matrix&&P.uniformMatrix3fv(L.u_matrix,!1,w.matrix),L.u_sizeRatio&&P.uniform1f(L.u_sizeRatio,w.sizeRatio),L.u_correctionRatio&&P.uniform1f(L.u_correctionRatio,w.correctionRatio),L.u_pickingPadding&&P.uniform1f(L.u_pickingPadding,w.nodePickingPadding),L.u_cameraAngle&&P.uniform1f(L.u_cameraAngle,w.cameraAngle),L.u_nodeDataTexture&&P.uniform1i(L.u_nodeDataTexture,w.nodeDataTextureUnit),L.u_nodeDataTextureWidth&&P.uniform1i(L.u_nodeDataTextureWidth,w.nodeDataTextureWidth),L.u_layerAttributeTexture&&(this.layerAttributeTexture.bind(it),P.uniform1i(L.u_layerAttributeTexture,it)),L.u_layerAttributeTextureWidth&&P.uniform1i(L.u_layerAttributeTextureWidth,this.layerAttributeTexture.getTextureWidth()),L.u_layerAttributeTexelsPerNode&&P.uniform1i(L.u_layerAttributeTexelsPerNode,this.layerAttributeTexture.getTexelsPerItem()),l.forEach(function(I){I.uniforms.forEach(function(z){D.setTypedUniform(z,F)})}),h.forEach(function(I){I.uniforms.forEach(function(z){D.setTypedUniform(z,F)})})}},{key:"render",value:function(w,F,D){this.maybeRegenerateShaders(),ve(E,"render",this,3)([w,F,D])}},{key:"renderProgram",value:function(w,F){var D=F.gl,P=F.program;D.useProgram(P),F===this.normalProgram&&this.layerLifecycles.forEach(function(L){var I;(I=L.beforeRender)===null||I===void 0||I.call(L)}),ve(E,"renderProgram",this,3)([w,F])}},{key:"kill",value:function(){this.layerLifecycles.forEach(function(D){var P;(P=D.kill)===null||P===void 0||P.call(D)}),this.layerLifecycles.clear();var w=this.normalProgram.gl,F=(x.textureRefCounts.get(w)||1)-1;F<=0?(this.layerAttributeTexture.kill(),x.layerTextures.delete(w),x.textureRefCounts.delete(w)):x.textureRefCounts.set(w,F),ve(E,"kill",this,3)([])}}])}(bt),A(i,"layerTextures",new WeakMap),A(i,"textureRefCounts",new WeakMap),i),T=new x(a,null,e);return{nodeProgram:T,labelProgram:g,backdropProgram:m,labelBackgroundProgram:p,attachmentProgram:v,framePass:b,shapeSlug:c,shapeNameToIndex:l.length>1?u:void 0,shapeGlobalIds:l.length>1?d:void 0}}var ot=6;function An(a){var n=a.offsets,e=a.specs,t=a.floatsPerItem,r=Object.keys(n);if(r.length===0||t===0)return{uniformDeclarations:"",uniformNames:[],vertexVaryingDeclarations:"",fragmentVaryingDeclarations:"",fetchCode:"",varyingAssignments:""};var i=`
uniform sampler2D u_edgeAttributeTexture;
uniform int u_edgeAttributeTextureWidth;
uniform int u_edgeAttributeTexelsPerEdge;`,o=["u_edgeAttributeTexture","u_edgeAttributeTextureWidth","u_edgeAttributeTexelsPerEdge"],s=r.map(function(f){var g=e[f].size===1?"float":"vec".concat(e[f].size);return"".concat(g," v_").concat(f,";")}),l=s.map(function(f){return"out ".concat(f)}).join(`
`),u=s.map(function(f){return"in ".concat(f)}).join(`
`),d=Wt(a,{varPrefix:"attr",baseTexelExpr:"edgeIdx * u_edgeAttributeTexelsPerEdge",textureWidthUniform:"u_edgeAttributeTextureWidth",textureSamplerUniform:"u_edgeAttributeTexture"}),c=d.fetchCode,h=d.varyingAssignments;return{uniformDeclarations:i,uniformNames:o,vertexVaryingDeclarations:l,fragmentVaryingDeclarations:u,fetchCode:c,varyingAssignments:h}}function ec(a){return`
float findSourceClampT_`.concat(a,`(vec2 source, float sourceSize, int sourceShapeId, float sourceRotateAlign, vec2 target, float margin) {
  float lo = 0.0, hi = 0.5;
  float nodeExtent = sourceSize * u_correctionRatio / u_sizeRatio * 2.0;
  float effectiveSize = 1.0 - u_correctionRatio / nodeExtent;

  // Counter-rotate the query point so viewport-aligned nodes (rotateAlign=0) are
  // clamped against their on-screen orientation; graph-aligned nodes skip it.
  float ca = u_cameraAngle * (1.0 - sourceRotateAlign);
  float rc = cos(ca), rs = sin(ca);
  mat2 rot = mat2(rc, -rs, rs, rc);

  for (int i = 0; i < 12; i++) {
    float mid = (lo + hi) * 0.5;
    vec2 pos = path_`).concat(a,`_position(mid, source, target);
    vec2 localPos = rot * ((pos - source) / nodeExtent);
    float sdf = querySDF(sourceShapeId, localPos, effectiveSize);
    if (sdf < 0.0) lo = mid;
    else hi = mid;
  }

  float pathLen = path_`).concat(a,`_length(source, target);
  float marginT = (margin * u_correctionRatio / u_sizeRatio) / pathLen;
  return (lo + hi) * 0.5 + marginT;
}
`)}function tc(a){return`
float findTargetClampT_`.concat(a,`(vec2 source, vec2 target, float targetSize, int targetShapeId, float targetRotateAlign, float margin) {
  float lo = 0.5, hi = 1.0;
  float nodeExtent = targetSize * u_correctionRatio / u_sizeRatio * 2.0;
  float effectiveSize = 1.0 - u_correctionRatio / nodeExtent;

  // See findSourceClampT_ for the rotation rationale.
  float ca = u_cameraAngle * (1.0 - targetRotateAlign);
  float rc = cos(ca), rs = sin(ca);
  mat2 rot = mat2(rc, -rs, rs, rc);

  for (int i = 0; i < 12; i++) {
    float mid = (lo + hi) * 0.5;
    vec2 pos = path_`).concat(a,`_position(mid, source, target);
    vec2 localPos = rot * ((pos - target) / nodeExtent);
    float sdf = querySDF(targetShapeId, localPos, effectiveSize);
    if (sdf < 0.0) hi = mid;
    else lo = mid;
  }

  float pathLen = path_`).concat(a,`_length(source, target);
  float marginT = (margin * u_correctionRatio / u_sizeRatio) / pathLen;
  return (lo + hi) * 0.5 - marginT;
}
`)}function Fo(a){return`
// Auto-generated numerical tangent (from position via finite differences)
vec2 path_`.concat(a,`_tangent(float t, vec2 source, vec2 target) {
  float epsilon = 0.001;
  float t1 = max(0.0, t - epsilon);
  float t2 = min(1.0, t + epsilon);
  vec2 p1 = path_`).concat(a,`_position(t1, source, target);
  vec2 p2 = path_`).concat(a,`_position(t2, source, target);
  return normalize(p2 - p1);
}

// Auto-generated normal (perpendicular to tangent)
vec2 path_`).concat(a,`_normal(float t, vec2 source, vec2 target) {
  vec2 tangent = path_`).concat(a,`_tangent(t, source, target);
  return vec2(-tangent.y, tangent.x);
}
`)}function nc(a){return`
// Auto-generated path length (samples position 16 times)
float path_`.concat(a,`_length(vec2 source, vec2 target) {
  float len = 0.0;
  vec2 prev = path_`).concat(a,`_position(0.0, source, target);
  for (int i = 1; i <= 16; i++) {
    float t = float(i) / 16.0;
    vec2 curr = path_`).concat(a,`_position(t, source, target);
    len += length(curr - prev);
    prev = curr;
  }
  return len;
}
`)}function ac(a){return`
// Auto-generated closest_t (coarse sample + ternary search)
float path_`.concat(a,`_closest_t(vec2 p, vec2 source, vec2 target) {
  // Coarse search: find best among 10 samples
  float bestT = 0.0;
  float bestDist = 1e10;
  for (int i = 0; i <= 10; i++) {
    float t = float(i) / 10.0;
    vec2 pos = path_`).concat(a,`_position(t, source, target);
    float d = length(p - pos);
    if (d < bestDist) {
      bestDist = d;
      bestT = t;
    }
  }

  // Refine with ternary search
  float lo = max(0.0, bestT - 0.1);
  float hi = min(1.0, bestT + 0.1);
  for (int i = 0; i < 10; i++) {
    float mid1 = lo + (hi - lo) / 3.0;
    float mid2 = hi - (hi - lo) / 3.0;
    float d1 = length(p - path_`).concat(a,`_position(mid1, source, target));
    float d2 = length(p - path_`).concat(a,`_position(mid2, source, target));
    if (d1 < d2) {
      hi = mid2;
    } else {
      lo = mid1;
    }
  }
  return (lo + hi) * 0.5;
}
`)}function rc(a){return`
// Auto-generated signed distance (via closest_t + normal)
float path_`.concat(a,`_distance(vec2 p, vec2 source, vec2 target) {
  float closestT = path_`).concat(a,`_closest_t(p, source, target);
  vec2 closest = path_`).concat(a,`_position(closestT, source, target);
  vec2 diff = p - closest;
  float dist = length(diff);
  if (dist < 0.0001) return 0.0;

  // Get normal at closest point
  vec2 normal = path_`).concat(a,`_normal(closestT, source, target);
  return dist * sign(dot(diff, normal));
}
`)}function ic(a){return`
// Auto-generated t_at_distance (binary search)
float path_`.concat(a,`_t_at_distance(float targetDist, vec2 source, vec2 target) {
  if (targetDist <= 0.0) return 0.0;

  float totalLen = path_`).concat(a,`_length(source, target);
  if (targetDist >= totalLen) return 1.0;

  // Binary search for t
  float lo = 0.0, hi = 1.0;
  for (int i = 0; i < 12; i++) {
    float mid = (lo + hi) * 0.5;

    // Compute arc length from 0 to mid
    float arcLen = 0.0;
    vec2 prev = path_`).concat(a,`_position(0.0, source, target);
    for (int j = 1; j <= 8; j++) {
      float t = mid * float(j) / 8.0;
      vec2 curr = path_`).concat(a,`_position(t, source, target);
      arcLen += length(curr - prev);
      prev = curr;
    }

    if (arcLen < targetDist) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) * 0.5;
}
`)}function ya(a,n){var e=new RegExp("\\b(float|vec[234]|void|int|bool)\\s+".concat(n,"\\s*\\("));return e.test(a)}function Io(a,n){var e=[];return ya(n,"path_".concat(a,"_length"))||e.push(nc(a)),ya(n,"path_".concat(a,"_closest_t"))||e.push(ac(a)),ya(n,"path_".concat(a,"_distance"))||e.push(rc(a)),ya(n,"path_".concat(a,"_t_at_distance"))||e.push(ic(a)),e.length>0?`
// ============================================================================
// Auto-generated fallback functions (path only provided position)
// ============================================================================
`.concat(e.join(`
`)):""}function Go(a){var n,e,t,r=a.paths,i=a.layers,o=(n=a.extremities)!==null&&n!==void 0?n:[];if(r.length===0)throw new Error("At least one path is required in 'paths'");if(i.length===0)throw new Error("At least one layer is required in 'layers'");var s=(e=a.defaultHead)!==null&&e!==void 0?e:"none",l=(t=a.defaultTail)!==null&&t!==void 0?t:"none";return{paths:r,extremities:o,layers:i,path:r[0],layer:i[0],defaultHead:s,defaultTail:l}}var zo=WebGL2RenderingContext,Tn=zo.FLOAT,go=zo.UNSIGNED_BYTE;function oc(a,n,e){var t=new Set(["u_matrix","u_sizeRatio","u_correctionRatio","u_zoomRatio","u_pixelRatio","u_cameraAngle","u_minEdgeThickness","u_pickingPadding","u_nodeDataTexture","u_nodeDataTextureWidth","u_edgeDataTexture","u_edgeDataTextureWidth","u_edgeFrameTexture","u_edgeFrameTextureWidth","u_edgeAttributeTexture","u_edgeAttributeTextureWidth","u_edgeAttributeTexelsPerEdge"]),r=new Set(t);return a.forEach(function(i){return i.uniforms.forEach(function(o){return r.add(o.name)})}),n.forEach(function(i){return i.uniforms.forEach(function(o){return r.add(o.name)})}),e.forEach(function(i){return i.uniforms.forEach(function(o){return r.add(o.name)})}),Array.from(r)}function xr(a){var n=new Set,e=[],t=M(a),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;n.has(i.name)||(n.add(i.name),e.push("// Path: ".concat(i.name)),e.push(i.glsl),e.push(Fo(i.name)),e.push(Io(i.name,i.glsl)))}}catch(o){t.e(o)}finally{t.f()}return e.join(`

`)}function sc(a){var n=[],e=M(a),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;n.push("// Extremity: ".concat(r.name)),n.push(r.glsl)}}catch(i){e.e(i)}finally{e.f()}return n.join(`

`)}var lc=[{queryName:"queryPathPosition",pathFunc:"position",returnType:"vec2",params:"float t, vec2 source, vec2 target",args:"t, source, target"},{queryName:"queryPathTangent",pathFunc:"tangent",returnType:"vec2",params:"float t, vec2 source, vec2 target",args:"t, source, target"},{queryName:"queryPathNormal",pathFunc:"normal",returnType:"vec2",params:"float t, vec2 source, vec2 target",args:"t, source, target"},{queryName:"queryPathLength",pathFunc:"length",returnType:"float",params:"vec2 source, vec2 target",args:"source, target"},{queryName:"queryPathClosestT",pathFunc:"closest_t",returnType:"float",params:"vec2 p, vec2 source, vec2 target",args:"p, source, target"}];function uc(a,n){var e=n.queryName,t=n.pathFunc,r=n.returnType,i=n.params,o=n.args;if(a.length===1)return"".concat(r," ").concat(e,"(int pathId, ").concat(i,`) {
  return path_`).concat(a[0].name,"_").concat(t,"(").concat(o,`);
}`);var s=a.map(function(l,u){return"    case ".concat(u,": return path_").concat(l.name,"_").concat(t,"(").concat(o,");")}).join(`
`);return"".concat(r," ").concat(e,"(int pathId, ").concat(i,`) {
  switch (pathId) {
`).concat(s,`
    default: return path_`).concat(a[0].name,"_").concat(t,"(").concat(o,`);
  }
}`)}function _r(a){return lc.map(function(n){return uc(a,n)}).join(`

`)}function dc(a){if(a.length===1)return`float queryExtremitySDF(int extremityId, vec2 uv, float lengthRatio, float widthRatio) {
  return extremity_`.concat(a[0].name,`(uv, lengthRatio, widthRatio);
}`);var n=a.map(function(e,t){return"    case ".concat(t,": return extremity_").concat(e.name,"(uv, lengthRatio, widthRatio);")}).join(`
`);return`float queryExtremitySDF(int extremityId, vec2 uv, float lengthRatio, float widthRatio) {
  switch (extremityId) {
`.concat(n,`
    default: return extremity_`).concat(a[0].name,`(uv, lengthRatio, widthRatio);
  }
}`)}function cc(a){var n=[],e=M(a),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;n.push(ec(r.name)),n.push(tc(r.name))}}catch(s){e.e(s)}finally{e.f()}if(a.length===1)n.push(`
float queryFindSourceClampT(int pathId, vec2 source, float sourceSize, int sourceShapeId, float sourceRotateAlign, vec2 target, float margin) {
  return findSourceClampT_`.concat(a[0].name,`(source, sourceSize, sourceShapeId, sourceRotateAlign, target, margin);
}

float queryFindTargetClampT(int pathId, vec2 source, vec2 target, float targetSize, int targetShapeId, float targetRotateAlign, float margin) {
  return findTargetClampT_`).concat(a[0].name,`(source, target, targetSize, targetShapeId, targetRotateAlign, margin);
}`));else{var i=a.map(function(s,l){return"    case ".concat(l,": return findSourceClampT_").concat(s.name,"(source, sourceSize, sourceShapeId, sourceRotateAlign, target, margin);")}).join(`
`),o=a.map(function(s,l){return"    case ".concat(l,": return findTargetClampT_").concat(s.name,"(source, target, targetSize, targetShapeId, targetRotateAlign, margin);")}).join(`
`);n.push(`
float queryFindSourceClampT(int pathId, vec2 source, float sourceSize, int sourceShapeId, float sourceRotateAlign, vec2 target, float margin) {
  switch (pathId) {
`.concat(i,`
    default: return findSourceClampT_`).concat(a[0].name,`(source, sourceSize, sourceShapeId, sourceRotateAlign, target, margin);
  }
}

float queryFindTargetClampT(int pathId, vec2 source, vec2 target, float targetSize, int targetShapeId, float targetRotateAlign, float margin) {
  switch (pathId) {
`).concat(o,`
    default: return findTargetClampT_`).concat(a[0].name,`(source, target, targetSize, targetShapeId, targetRotateAlign, margin);
  }
}`))}return n.join(`

`)}function hc(a,n,e,t,r){var i=Fe([].concat(V(a),V(e))),o=An(i),s=$t(t,r),l=Object.keys(s.offsets),u=function(R){var E=s.specs[R].size;return E===1?"float":"vec".concat(E)},d=l.map(function(T){return"".concat(u(T)," v_source_").concat(T,`;
`).concat(u(T)," v_target_").concat(T,";")}).join(`
`),c=Wt(s,{varPrefix:"srcNodeAttr",baseTexelExpr:"srcIdx * u_layerAttributeTexelsPerNode",textureWidthUniform:"u_layerAttributeTextureWidth",textureSamplerUniform:"u_layerAttributeTexture",outputPrefix:"v_source_"}),h=Wt(s,{varPrefix:"tgtNodeAttr",baseTexelExpr:"tgtIdx * u_layerAttributeTexelsPerNode",textureWidthUniform:"u_layerAttributeTextureWidth",textureSamplerUniform:"u_layerAttributeTexture",outputPrefix:"v_target_"}),f=l.map(function(T){return"".concat(u(T)," g_").concat(T,";")}).join(`
`),g=l.map(function(T){return"  g_".concat(T," = v_source_").concat(T,";")}).join(`
`),m=l.map(function(T){return"  g_".concat(T," = v_target_").concat(T,";")}).join(`
`),p=new Set,v=[],b=function(R){p.has(R.name)||(p.add(R.name),v.push("uniform ".concat(R.type," ").concat(R.name,";")))};a.forEach(function(T){return T.uniforms.forEach(b)}),n.forEach(function(T){return T.uniforms.forEach(b)});var y=n.map(function(T){return he(T.widthFactor)}).join(", "),_=Math.max.apply(Math,V(a.map(function(T){return T.minBodyLengthRatio||0}))),x=`#version 300 es

// Node and edge data textures
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_edgeDataTexture;
uniform int u_edgeDataTextureWidth;

// Edge attribute texture (for path-specific attributes like curvature)
`.concat(o.uniformDeclarations,`

// Node attribute texture (for node shape attributes)
uniform sampler2D u_layerAttributeTexture;
uniform int u_layerAttributeTextureWidth;
uniform int u_layerAttributeTexelsPerNode;

// Render params needed for clamping
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
uniform float u_minEdgeThickness;

// Edge-frame texture dimensions, for scattering each point to its texel
uniform float u_frameTextureWidth;
uniform float u_frameTextureHeight;

// Custom path/extremity uniforms
`).concat(v.join(`
`),`

// Path attribute varyings \u2014 assigned so path functions can read them as globals
`).concat(o.vertexVaryingDeclarations,`

// Node size varyings \u2014 read by path functions like loop
out float v_sourceNodeSize;
out float v_targetNodeSize;

// Node shape attributes per endpoint, and the ones querySDF reads
`).concat(d,`
`).concat(f,`

// Scattered output written to the edge-frame texel: [tStart, tEnd, straightenFactor, pathLength]
out vec4 v_clamp;

// Extremity width factor array (needed for extremityScale computation)
const float EXTREMITY_WIDTH_FACTORS[`).concat(n.length,"] = float[](").concat(y,`);

// Node-data fetch helpers (geometry texel + rotation-flags texel)
`).concat(Qe,`
`).concat(mt,`

// Shape SDFs for node boundary clamping
`).concat(pd(),`
`).concat(md(new Set(l)),`

// Path functions
`).concat(xr(a),`
`).concat(_r(a),`
`).concat(cc(a),`

void main() {
  // One point per edge-data row; the row index is the edge-frame texel target.
  int edgeIdx = gl_VertexID;
  int texel0Idx = edgeIdx * 2;
  int texel1Idx = edgeIdx * 2 + 1;
  ivec2 edgeTexCoord0 = ivec2(texel0Idx % u_edgeDataTextureWidth, texel0Idx / u_edgeDataTextureWidth);
  ivec2 edgeTexCoord1 = ivec2(texel1Idx % u_edgeDataTextureWidth, texel1Idx / u_edgeDataTextureWidth);
  vec4 edgeData0 = texelFetch(u_edgeDataTexture, edgeTexCoord0, 0);
  vec4 edgeData1 = texelFetch(u_edgeDataTexture, edgeTexCoord1, 0);

  int srcIdx = int(edgeData0.x);
  int tgtIdx = int(edgeData0.y);
  float a_thickness = edgeData0.z;
  float a_headLengthRatio = edgeData1.x;
  float a_tailLengthRatio = edgeData1.y;
  int pathId = int(edgeData1.z);
  int extremityPacked = int(edgeData1.w);
  int headId = extremityPacked >> 4;
  int tailId = extremityPacked & 15;

  // Fetch path/layer attributes and assign to path-function globals
`).concat(o.fetchCode,`
`).concat(o.varyingAssignments,`

  // Fetch node shape attributes for both endpoints
`).concat(c.fetchCode,`
`).concat(c.varyingAssignments,`
`).concat(h.fetchCode,`
`).concat(h.varyingAssignments,`

  // Fetch node geometry (texel 0) and rotation flags (texel 1).
  vec4 srcNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx);
  vec4 tgtNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx);

  vec2 a_source = srcNodeData.xy;
  vec2 a_target = tgtNodeData.xy;
  float a_sourceSize = srcNodeData.z;
  float a_targetSize = tgtNodeData.z;
  float a_sourceShapeId = srcNodeData.w;
  float a_targetShapeId = tgtNodeData.w;
  // Per-node rotation alignment (0 = viewport, 1 = graph), for boundary clamping.
  float a_sourceRotateAlign = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx).r;
  float a_targetRotateAlign = readNodeFlags(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx).r;

  v_sourceNodeSize = a_sourceSize;
  v_targetNodeSize = a_targetSize;

  float headLengthRatio = a_headLengthRatio;
  float tailLengthRatio = a_tailLengthRatio;
  float headWidthFactor = EXTREMITY_WIDTH_FACTORS[headId];
  float tailWidthFactor = EXTREMITY_WIDTH_FACTORS[tailId];
  float minBodyLengthRatio = `).concat(he(_),`;

  // Thickness in WebGL units (needed to compute clamping margin and extremity lengths)
  float pixelsThickness = max(a_thickness, u_minEdgeThickness * u_sizeRatio);
  float webGLThickness = pixelsThickness * u_correctionRatio / u_sizeRatio;

  // SDF clamping: find where the edge body meets the node boundaries. Always
  // searched (ungated) so labels get a true boundary clamp; the body re-applies
  // its extremity gating in-shader.
`).concat(g,`
  float tStart = queryFindSourceClampT(pathId, a_source, a_sourceSize, int(a_sourceShapeId), a_sourceRotateAlign, a_target, 0.0);
`).concat(m,`
  float tEnd = queryFindTargetClampT(pathId, a_source, a_target, a_targetSize, int(a_targetShapeId), a_targetRotateAlign, 0.0);

  // straightenFactor (frame .z) is consumed only by the body, which runs to the
  // node center when an extremity is absent. Derive the straightening math from
  // these gated clamps \u2014 not the ungated boundary ones above \u2014 so it matches the
  // geometry it drives. The ungated tStart/tEnd remain what labels read.
  float bodyTStart = tailLengthRatio > 0.0 ? tStart : 0.0;
  float bodyTEnd = headLengthRatio > 0.0 ? tEnd : 1.0;

  // Path length and zone boundaries (needed for straightening check)
  float pathLength = queryPathLength(pathId, a_source, a_target);
  float visibleLength = pathLength * (bodyTEnd - bodyTStart);

  float headLength = headLengthRatio * webGLThickness;
  float tailLength = tailLengthRatio * webGLThickness;
  float minBodyLength = minBodyLengthRatio * webGLThickness;

  float totalNeededLength = headLength + tailLength + minBodyLength;
  float extremityScale = 1.0;
  if (totalNeededLength > visibleLength && totalNeededLength > 0.0001) {
    extremityScale = visibleLength / totalNeededLength;
    headLength *= extremityScale;
    tailLength *= extremityScale;
  }

  float headLengthT = pathLength > 0.0001 ? headLength / pathLength : 0.0;
  float tailLengthT = pathLength > 0.0001 ? tailLength / pathLength : 0.0;

  float tTailEnd = bodyTStart + tailLengthT;
  float tHeadStart = bodyTEnd - headLengthT;
  if (tTailEnd > tHeadStart) {
    float mid = (bodyTStart + bodyTEnd) * 0.5;
    tTailEnd = mid;
    tHeadStart = mid;
  }

  // Straighten factor: blend toward straight line when path twists in extremity zones
  float straightenFactor = 0.0;
  {
    float maxDeviation = 0.0;
    if (tailLengthT > 0.0001) {
      vec2 tailTang = queryPathTangent(pathId, tTailEnd, a_source, a_target);
      vec2 tailChord = queryPathPosition(pathId, bodyTStart, a_source, a_target)
                     - queryPathPosition(pathId, tTailEnd, a_source, a_target);
      float tailChordLen = length(tailChord);
      if (tailChordLen > 0.0001) {
        maxDeviation = max(maxDeviation, 1.0 - dot(-tailTang, tailChord / tailChordLen));
      }
    }
    if (headLengthT > 0.0001) {
      vec2 headTang = queryPathTangent(pathId, tHeadStart, a_source, a_target);
      vec2 headChord = queryPathPosition(pathId, bodyTEnd, a_source, a_target)
                     - queryPathPosition(pathId, tHeadStart, a_source, a_target);
      float headChordLen = length(headChord);
      if (headChordLen > 0.0001) {
        maxDeviation = max(maxDeviation, 1.0 - dot(headTang, headChord / headChordLen));
      }
    }
    straightenFactor = smoothstep(0.035, 0.5, maxDeviation);
  }

  // When straightening, blend the ungated tStart/tEnd (the label-facing clamps)
  // toward straight-line clamp positions.
  if (straightenFactor > 0.001) {
    if (tailLengthRatio > 0.0) {
`).concat(g,`
      float srcExtent = a_sourceSize * u_correctionRatio / u_sizeRatio * 2.0;
      float srcEffective = 1.0 - u_correctionRatio / srcExtent;
      float srcCa = u_cameraAngle * (1.0 - a_sourceRotateAlign);
      mat2 srcRot = mat2(cos(srcCa), -sin(srcCa), sin(srcCa), cos(srcCa));
      float lo = 0.0, hi = 0.5;
      for (int i = 0; i < 12; i++) {
        float mid = (lo + hi) * 0.5;
        vec2 pos = mix(a_source, a_target, mid);
        vec2 localPos = srcRot * ((pos - a_source) / srcExtent);
        float sdf = querySDF(int(a_sourceShapeId), localPos, srcEffective);
        if (sdf < 0.0) lo = mid; else hi = mid;
      }
      tStart = mix(tStart, (lo + hi) * 0.5, straightenFactor);
    }
    if (headLengthRatio > 0.0) {
`).concat(m,`
      float tgtExtent = a_targetSize * u_correctionRatio / u_sizeRatio * 2.0;
      float tgtEffective = 1.0 - u_correctionRatio / tgtExtent;
      float tgtCa = u_cameraAngle * (1.0 - a_targetRotateAlign);
      mat2 tgtRot = mat2(cos(tgtCa), -sin(tgtCa), sin(tgtCa), cos(tgtCa));
      float lo = 0.5, hi = 1.0;
      for (int i = 0; i < 12; i++) {
        float mid = (lo + hi) * 0.5;
        vec2 pos = mix(a_source, a_target, mid);
        vec2 localPos = tgtRot * ((pos - a_target) / tgtExtent);
        float sdf = querySDF(int(a_targetShapeId), localPos, tgtEffective);
        if (sdf < 0.0) hi = mid; else lo = mid;
      }
      tEnd = mix(tEnd, (lo + hi) * 0.5, straightenFactor);
    }
  }

  v_clamp = vec4(tStart, tEnd, straightenFactor, pathLength);

  // Scatter this point to its edge's texel center in the frame texture.
  float x = mod(float(edgeIdx), u_frameTextureWidth);
  float y = floor(float(edgeIdx) / u_frameTextureWidth);
  vec2 ndc = (vec2(x, y) + 0.5) / vec2(u_frameTextureWidth, u_frameTextureHeight) * 2.0 - 1.0;
  gl_Position = vec4(ndc, 0.0, 1.0);
  gl_PointSize = 1.0;
}
`);return x}var xa=0,vo=1,_a=2;function fc(a,n,e){var t=[];e&&(t.push([xa,0,-1],[xa,0,1]),t.push([xa,1,-1],[xa,1,1]));for(var r=0;r<=a;r++){var i=r/a;t.push([vo,i,-1],[vo,i,1])}return n&&(t.push([_a,0,-1],[_a,0,1]),t.push([_a,1,-1],[_a,1,1])),{data:t,attributes:[{name:"a_zone",size:1,type:Tn},{name:"a_zoneT",size:1,type:Tn},{name:"a_side",size:1,type:Tn}],verticesPerEdge:t.length}}function gc(a,n,e,t){var r=Fe([].concat(V(a),V(e))),i=An(r),o=new Set(["u_matrix","u_sizeRatio","u_correctionRatio","u_zoomRatio","u_pixelRatio","u_cameraAngle","u_minEdgeThickness","u_pickingPadding","u_nodeDataTexture"]),s=new Set,l=[],u=function(v){!o.has(v.name)&&!s.has(v.name)&&(s.add(v.name),l.push("uniform ".concat(v.type," ").concat(v.name,";")))};a.forEach(function(p){return p.uniforms.forEach(u)}),n.forEach(function(p){return p.uniforms.forEach(u)}),e.forEach(function(p){return p.uniforms.forEach(u)});var d=t.map(function(p){var v=p.size===1?"float":"vec".concat(p.size);return"in ".concat(v," ").concat(p.name,";")}).join(`
`),c=n.map(function(p){return he(p.widthFactor)}).join(", "),h=Math.max.apply(Math,V(a.map(function(p){return p.minBodyLengthRatio||0}))),f=e.some(function(p){return p.needsNodeColors}),g=a.some(function(p){return p.needsNodeSize}),m=`#version 300 es

// Constant attributes (per vertex)
`.concat(d,`

// Per-edge attributes
// Edge data (source/target indices, thickness, extremity ratios, path/extremity IDs)
// is fetched from edge data texture via edge index
in float a_edgeIndex;   // Index into edge data texture
in vec4 a_color;        // Edge color
in vec4 a_id;           // Edge ID for picking
in float a_opacity;     // Edge opacity

// Standard uniforms
uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_zoomRatio;
uniform float u_pixelRatio;
uniform float u_cameraAngle;
uniform float u_minEdgeThickness;
#ifdef PICKING_MODE
uniform float u_pickingPadding;
#endif
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_edgeDataTexture;
uniform int u_edgeDataTextureWidth;
uniform sampler2D u_edgeFrameTexture;
uniform int u_edgeFrameTextureWidth;

// Edge path attribute texture uniforms
`).concat(i.uniformDeclarations,`

// Custom uniforms
`).concat(l.join(`
`),`

// Standard varyings
out vec4 v_color;
out float v_opacity;
out vec4 v_id;
out float v_thickness;       // Edge body thickness (in consistent units)
out float v_t;
out float v_tStart;
out float v_tEnd;
out float v_side;
out float v_antialiasingWidth;  // Anti-aliasing width (normalized: u_correctionRatio / thickness)
out vec2 v_source;
out vec2 v_target;
out float v_edgeLength;
`).concat(g?`
out float v_sourceNodeSize;  // Source node size (mirrored in labels/generator.ts as plain float)
out float v_targetNodeSize;  // Target node size (mirrored in labels/generator.ts as plain float)`:"",`
`).concat(f?`
out vec4 v_sourceColor;
out vec4 v_targetColor;`:"",`
// Zone varyings
out float v_zone;            // 0=tail, 1=body, 2=head
out float v_zoneT;           // Position within zone [0,1]
out float v_headLengthRatio; // Head length as ratio of thickness
out float v_tailLengthRatio; // Tail length as ratio of thickness
out float v_headWidthRatio;  // Head width factor
out float v_tailWidthRatio;  // Tail width factor

// Multi-path/extremity varyings
flat out int v_pathId;
flat out int v_headId;
flat out int v_tailId;

// Path/layer attribute varyings (fetched from edge attribute texture)
`).concat(i.vertexVaryingDeclarations,`

const float bias = 255.0 / 254.0;

// Width factor array for extremities (shared pool for head/tail)
const float EXTREMITY_WIDTH_FACTORS[`).concat(n.length,"] = float[](").concat(c,`);

// All path functions
`).concat(xr(a),`

// Path selector functions
`).concat(_r(a),`

// Node-data fetch helper (geometry texel of the two-texel node stride)
`).concat(Qe,`
`).concat(f?Sd:"",`
// Per-edge clamp from the frame-pass (tStart, tEnd, straightenFactor, pathLength)
`).concat(Ht,`

void main() {
  // Fetch edge data from edge texture (2 texels per edge)
  // Texel 0: sourceNodeIndex, targetNodeIndex, thickness, reserved
  // Texel 1: headLengthRatio, tailLengthRatio, pathId, (headId << 4) | tailId
  int edgeIdx = int(a_edgeIndex);

  // Hidden edges are flagged with a negative row by EdgeProgram.process(). Push
  // the whole primitive outside the clip volume: every vertex lands at the same
  // out-of-range position, so it is fully clipped and rasterizes nothing \u2014
  // neither to the frame buffer nor to the picking buffer.
  if (edgeIdx < 0) {
    gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
    v_color = vec4(0.0);
    v_id = vec4(0.0);
    return;
  }

  int texel0Idx = edgeIdx * 2;
  int texel1Idx = edgeIdx * 2 + 1;
  ivec2 edgeTexCoord0 = ivec2(texel0Idx % u_edgeDataTextureWidth, texel0Idx / u_edgeDataTextureWidth);
  ivec2 edgeTexCoord1 = ivec2(texel1Idx % u_edgeDataTextureWidth, texel1Idx / u_edgeDataTextureWidth);
  vec4 edgeData0 = texelFetch(u_edgeDataTexture, edgeTexCoord0, 0);
  vec4 edgeData1 = texelFetch(u_edgeDataTexture, edgeTexCoord1, 0);

  // Unpack edge data
  int srcIdx = int(edgeData0.x);
  int tgtIdx = int(edgeData0.y);
  float a_thickness = edgeData0.z;
  // edgeData0.w is now reserved (curvature moved to path attribute texture)
  float a_headLengthRatio = edgeData1.x;
  float a_tailLengthRatio = edgeData1.y;
  int pathId = int(edgeData1.z);
  int extremityPacked = int(edgeData1.w);
  int headId = extremityPacked >> 4;
  int tailId = extremityPacked & 15;

  // Fetch path/layer attributes from edge attribute texture
`).concat(i.fetchCode,`

  // Assign path/layer attribute varyings
`).concat(i.varyingAssignments,`

  // Fetch source and target node geometry (texel 0 of the two-texel node stride)
  vec4 srcNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx);
  vec4 tgtNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx);

  vec2 a_source = srcNodeData.xy;
  vec2 a_target = tgtNodeData.xy;
`).concat(g?`
  // Assign node size varyings early (path functions like loops need them during clamping)
  v_sourceNodeSize = srcNodeData.z;
  v_targetNodeSize = tgtNodeData.z;`:"",`
`).concat(f?`
  v_sourceColor = readNodeColor(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx);
  v_targetColor = readNodeColor(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx);`:"",`

  // Convert thickness to WebGL units
  float minThickness = u_minEdgeThickness;
  float pixelsThickness = max(a_thickness, minThickness * u_sizeRatio);
  float webGLThickness = pixelsThickness * u_correctionRatio / u_sizeRatio;

  // Extremity parameters from ID lookups (shared pool)
  float headLengthRatio = a_headLengthRatio;
  float tailLengthRatio = a_tailLengthRatio;
  float headWidthFactor = EXTREMITY_WIDTH_FACTORS[headId];
  float tailWidthFactor = EXTREMITY_WIDTH_FACTORS[tailId];
  float minBodyLengthRatio = `).concat(he(h),`;

  // Per-edge values from the frame-pass texture (read by edge index).
  // tStart/tEnd are the ungated boundary clamps: re-apply the body's extremity
  // gating here (no extremity \u2192 body runs to the node center, 0/1).
  vec4 frameClamp = readFrameTexel(u_edgeFrameTexture, u_edgeFrameTextureWidth, edgeIdx);
  float tStart           = a_tailLengthRatio > 0.0 ? frameClamp.x : 0.0;
  float tEnd             = a_headLengthRatio > 0.0 ? frameClamp.y : 1.0;
  float straightenFactor = frameClamp.z;
  float pathLength       = frameClamp.w;

  // Anti-aliasing width (~1 pixel, normalized by thickness)
  float antialiasingWidth = u_correctionRatio / webGLThickness;

  float visibleLength = pathLength * (tEnd - tStart);

  // Compute extremity lengths in world units
  float headLength = headLengthRatio * webGLThickness;
  float tailLength = tailLengthRatio * webGLThickness;
  float minBodyLength = minBodyLengthRatio * webGLThickness;

  // Handle short edges: scale down extremities if needed
  float totalNeededLength = headLength + tailLength + minBodyLength;
  float extremityScale = 1.0;
  if (totalNeededLength > visibleLength && totalNeededLength > 0.0001) {
    extremityScale = visibleLength / totalNeededLength;
    headLength *= extremityScale;
    tailLength *= extremityScale;
  }

  // Convert lengths to t-values
  float headLengthT = pathLength > 0.0001 ? headLength / pathLength : 0.0;
  float tailLengthT = pathLength > 0.0001 ? tailLength / pathLength : 0.0;

  // Zone boundaries in t-space
  float tTailEnd = tStart + tailLengthT;
  float tHeadStart = tEnd - headLengthT;

  // Ensure body has non-negative length
  if (tTailEnd > tHeadStart) {
    float mid = (tStart + tEnd) * 0.5;
    tTailEnd = mid;
    tHeadStart = mid;
  }

  // Convert to webGL units for geometry expansion
  float aaWidthWebGL = antialiasingWidth * webGLThickness;

  // Extra geometry width for picking padding (0 in visual mode)
  #ifdef PICKING_MODE
    float pickingPaddingWebGL = u_pickingPadding * u_correctionRatio;
  #else
    float pickingPaddingWebGL = 0.0;
  #endif

  // Straight-line direction and normal (for blending when straightenFactor > 0)
  vec2 straightDir = length(a_target - a_source) > 0.0001
    ? normalize(a_target - a_source) : vec2(1.0, 0.0);
  vec2 straightNormal = vec2(-straightDir.y, straightDir.x);

  // Zone-based vertex processing using path selectors
  vec2 position;
  vec2 normal;
  float t;
  float zone = a_zone;
  float zoneT = a_zoneT;
  float side = a_side;

  // Scaled extremity width factors (geometry must be at least as wide as body)
  float scaledTailWidth = max(tailWidthFactor * extremityScale, 1.0);
  float scaledHeadWidth = max(headWidthFactor * extremityScale, 1.0);

  if (zone < 0.5) {
    // TAIL ZONE: rectangular quad with scaled width
    vec2 tang = queryPathTangent(pathId, tTailEnd, a_source, a_target);
    normal = vec2(-tang.y, tang.x);
    vec2 centerPos = mix(queryPathPosition(pathId, tStart, a_source, a_target),
                         queryPathPosition(pathId, tTailEnd, a_source, a_target), zoneT);
    float halfWidth = webGLThickness * scaledTailWidth * 0.5 + aaWidthWebGL + pickingPaddingWebGL;
    position = centerPos + normal * side * halfWidth;
    t = mix(tStart, tTailEnd, zoneT);

  } else if (zone < 1.5) {
    // BODY ZONE: follows path curvature with width = 1.0
    t = mix(tTailEnd, tHeadStart, zoneT);
    normal = queryPathNormal(pathId, t, a_source, a_target);
    float halfWidth = webGLThickness * 0.5 + aaWidthWebGL + pickingPaddingWebGL;
    position = queryPathPosition(pathId, t, a_source, a_target) + normal * side * halfWidth;

  } else {
    // HEAD ZONE: rectangular quad with scaled width
    vec2 tang = queryPathTangent(pathId, tHeadStart, a_source, a_target);
    normal = vec2(-tang.y, tang.x);
    vec2 centerPos = mix(queryPathPosition(pathId, tHeadStart, a_source, a_target),
                         queryPathPosition(pathId, tEnd, a_source, a_target), zoneT);
    float halfWidth = webGLThickness * scaledHeadWidth * 0.5 + aaWidthWebGL + pickingPaddingWebGL;
    position = centerPos + normal * side * halfWidth;
    t = mix(tHeadStart, tEnd, zoneT);
  }

  // Blend toward straight line based on path twist in extremity zones
  if (straightenFactor > 0.001) {
    float zoneWidth = zone < 0.5 ? webGLThickness * scaledTailWidth * 0.5 + aaWidthWebGL + pickingPaddingWebGL :
                      zone < 1.5 ? webGLThickness * 0.5 + aaWidthWebGL + pickingPaddingWebGL :
                      webGLThickness * scaledHeadWidth * 0.5 + aaWidthWebGL + pickingPaddingWebGL;
    vec2 straightPos = mix(a_source, a_target, t) + straightNormal * side * zoneWidth;
    position = mix(position, straightPos, straightenFactor);
  }

  gl_Position = vec4((u_matrix * vec3(position, 1.0)).xy, 0.0, 1.0);

  // Pass varyings to fragment shader
  v_color = a_color;
  v_color.a *= bias;
  v_opacity = a_opacity;
  v_id = a_id;
  v_thickness = webGLThickness;
  v_t = t;
  v_tStart = tStart;
  v_tEnd = tEnd;
  v_side = side;
  v_antialiasingWidth = antialiasingWidth;
  v_source = a_source;
  v_target = a_target;
  v_edgeLength = pathLength;

  // Zone varyings
  v_zone = zone;
  v_zoneT = zoneT;
  v_headLengthRatio = headLengthRatio * extremityScale;
  v_tailLengthRatio = tailLengthRatio * extremityScale;
  // Scale extremity width proportionally with length when crushed
  v_headWidthRatio = headWidthFactor * extremityScale;
  v_tailWidthRatio = tailWidthFactor * extremityScale;

  // Multi-path varyings
  v_pathId = pathId;
  v_headId = headId;
  v_tailId = tailId;
}
`);return m}function vc(a,n,e,t){var r=Fe([].concat(V(a),V(e))),i=An(r),o=new Set(["u_matrix","u_sizeRatio","u_correctionRatio","u_zoomRatio","u_pixelRatio","u_cameraAngle","u_minEdgeThickness","u_pickingPadding"]),s=new Set,l=[],u=function(b){!o.has(b.name)&&!s.has(b.name)&&(s.add(b.name),l.push("uniform ".concat(b.type," ").concat(b.name,";")))};a.forEach(function(v){return v.uniforms.forEach(u)}),n.forEach(function(v){return v.uniforms.forEach(u)}),e.forEach(function(v){return v.uniforms.forEach(u)});var d=n.map(function(v){var b;return he((b=v.baseRatio)!==null&&b!==void 0?b:.5)}).join(", "),c=function(b){var y,_;return n.length>1?"EXTREMITY_BASE_RATIOS[".concat(b,"]"):he((y=(_=n[0])===null||_===void 0?void 0:_.baseRatio)!==null&&y!==void 0?y:.5)},h=n.some(function(v){return Ne(v.length)?!0:v.length>0}),f=e.some(function(v){return v.needsNodeColors}),g=a.some(function(v){return v.needsNodeSize}),m=e.map(function(v,b){return"  // Layer ".concat(b+1,": ").concat(v.name,`
  color = blendOver(color, layer_`).concat(v.name,"(context));")}).join(`

`),p=`#version 300 es
precision highp float;

// Standard varyings
in vec4 v_color;
in float v_opacity;
in vec4 v_id;
in float v_thickness;       // Edge body thickness
in float v_t;
in float v_tStart;
in float v_tEnd;
in float v_side;
in float v_antialiasingWidth;  // Anti-aliasing width (normalized: u_correctionRatio / thickness)
in vec2 v_source;
in vec2 v_target;
in float v_edgeLength;
`.concat(g?`
in float v_sourceNodeSize;   // Source node size (mirrored in labels/generator.ts as plain float)
in float v_targetNodeSize;   // Target node size (mirrored in labels/generator.ts as plain float)`:"",`
`).concat(f?`
in vec4 v_sourceColor;
in vec4 v_targetColor;`:"",`
// Zone varyings
in float v_zone;            // 0=tail, 1=body, 2=head
in float v_zoneT;           // Position within zone [0,1]
in float v_headLengthRatio; // Head length as ratio of thickness (scaled for short edges)
in float v_tailLengthRatio; // Tail length as ratio of thickness (scaled for short edges)
in float v_headWidthRatio;  // Head width factor
in float v_tailWidthRatio;  // Tail width factor

// Multi-path/extremity varyings
flat in int v_pathId;
flat in int v_headId;
flat in int v_tailId;

// Path/layer attribute varyings (from vertex shader texture fetch)
`).concat(i.fragmentVaryingDeclarations,`

// Standard uniforms (needed by some path types)
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_cameraAngle;
#ifdef PICKING_MODE
uniform float u_pickingPadding;
#endif

// Custom uniforms
`).concat(l.join(`
`),`

// Fragment output (single target - picking handled via separate pass)
out vec4 fragColor;

`).concat(n.length>1?`// Base ratio array for extremities (shared pool for head/tail)
const float EXTREMITY_BASE_RATIOS[`.concat(n.length,"] = float[](").concat(d,");"):"",`

// EdgeContext struct
struct EdgeContext {
  float t;                   // Position along path [0, 1]
  float sdf;                 // Signed distance from centerline
  vec2 position;             // World position
  vec2 tangent;              // Path tangent
  vec2 normal;               // Path normal
  float thickness;           // Edge thickness
  float aaWidth;             // Anti-aliasing width
  float edgeLength;          // Total path length
  float tStart;              // Clamped start t
  float tEnd;                // Clamped end t
  float distanceFromSource;  // Arc distance from source
  float distanceToTarget;    // Arc distance to target
};

EdgeContext context;

// Alpha "over" compositing for layer blending
vec4 blendOver(vec4 bg, vec4 fg) {
  float a = fg.a;
  return vec4(mix(bg.rgb, fg.rgb, a), bg.a + a * (1.0 - bg.a));
}

// All path functions
`).concat(xr(a),`

// Path selector functions
`).concat(_r(a),`

// All extremity functions
`).concat(sc(n),`

// Extremity SDF selector (shared pool for head/tail)
`).concat(dc(n),`

// Layer functions
`).concat(e.map(function(v){return v.glsl}).join(`

`),`

// Helper: Compute arc length using path selector
float computeArcLengthMulti(int pathId, float t0, float t1, vec2 source, vec2 target, int samples) {
  float arcLen = 0.0;
  vec2 prev = queryPathPosition(pathId, t0, source, target);
  for (int i = 1; i <= samples; i++) {
    float t = t0 + (t1 - t0) * float(i) / float(samples);
    vec2 curr = queryPathPosition(pathId, t, source, target);
    arcLen += length(curr - prev);
    prev = curr;
  }
  return arcLen;
}

void main() {
  // Compute normalized t within visible edge (0 = start, 1 = end)
  float tNorm = (v_t - v_tStart) / max(v_tEnd - v_tStart, 0.0001);

  // Edge body half-thickness
  float halfThickness = v_thickness * 0.5;

  // Convert normalized AA width to webGL units (~1 pixel)
  float aaWidthWebGL = v_antialiasingWidth * v_thickness;

  // Distance from centerline based on v_side interpolation
  float zoneWidthFactor = v_zone < 0.5 ? v_tailWidthRatio :
                          v_zone < 1.5 ? 1.0 :
                          v_headWidthRatio;
  // In PICKING_MODE, inflate halfGeometryWidth to match the inflated vertex geometry
  #ifdef PICKING_MODE
    float halfGeometryWidth = halfThickness * zoneWidthFactor + aaWidthWebGL + u_pickingPadding * aaWidthWebGL;
  #else
    float halfGeometryWidth = halfThickness * zoneWidthFactor + aaWidthWebGL;
  #endif
  float distFromCenter = abs(v_side) * halfGeometryWidth;

  // Populate EdgeContext (for layer functions)
  context.t = tNorm;
  context.sdf = distFromCenter - halfThickness;
  context.position = queryPathPosition(v_pathId, v_t, v_source, v_target);
  context.tangent = queryPathTangent(v_pathId, v_t, v_source, v_target);
  context.normal = vec2(-context.tangent.y, context.tangent.x);
  context.thickness = v_thickness;
  context.aaWidth = aaWidthWebGL;
  context.edgeLength = v_edgeLength;
  context.tStart = v_tStart;
  context.tEnd = v_tEnd;

  // Compute arc distances
  float visibleLength = v_edgeLength * (v_tEnd - v_tStart);
  float pathT = v_t;
  float pathTNorm = tNorm;
`).concat(a.every(function(v){return v.linearParameterization})?`  // All paths have linear parameterization: t maps directly to arc distance
  context.distanceFromSource = pathTNorm * visibleLength;
  context.distanceToTarget = (1.0 - pathTNorm) * visibleLength;`:a.every(function(v){return!v.linearParameterization})?`  // No paths have linear parameterization: use numerical integration
  context.distanceFromSource = computeArcLengthMulti(v_pathId, v_tStart, pathT, v_source, v_target, 16);
  context.distanceToTarget = computeArcLengthMulti(v_pathId, pathT, v_tEnd, v_source, v_target, 16);`:`  // Mixed parameterization: use analytical for linear paths, numerical for others
  if (`.concat(a.filter(function(v){return v.linearParameterization}).map(function(v){return"v_pathId == ".concat(a.indexOf(v))}).join(" || "),`) {
    context.distanceFromSource = pathTNorm * visibleLength;
    context.distanceToTarget = (1.0 - pathTNorm) * visibleLength;
  } else {
    context.distanceFromSource = computeArcLengthMulti(v_pathId, v_tStart, pathT, v_source, v_target, 16);
    context.distanceToTarget = computeArcLengthMulti(v_pathId, pathT, v_tEnd, v_source, v_target, 16);
  }`),`

  // Compute SDF based on zone using extremity selector (shared pool)
  float bodySDF = distFromCenter - halfThickness;
  float finalSDF;

`).concat(h?`  // Base ratios, from baseRatioLookup
  float headBaseRatio = `.concat(c("v_headId"),`;
  float tailBaseRatio = `).concat(c("v_tailId"),`;

  if (v_zone < 0.5) {
    // TAIL ZONE: v_zoneT goes 0 (tip) to 1 (base)
    vec2 uv = vec2((1.0 - v_zoneT) * v_tailLengthRatio, v_side * v_tailWidthRatio * 0.5);
    float tailSDF = queryExtremitySDF(v_tailId, uv, v_tailLengthRatio, v_tailWidthRatio) * v_thickness;

    // Apply union only near base (v_zoneT > 1 - baseRatio)
    if (v_zoneT > 1.0 - tailBaseRatio) {
      finalSDF = min(tailSDF, bodySDF);
    } else {
      finalSDF = tailSDF;
    }
  } else if (v_zone < 1.5) {
    // BODY ZONE: distance from centerline
    finalSDF = bodySDF;
  } else {
    // HEAD ZONE: v_zoneT goes 0 (base) to 1 (tip)
    vec2 uv = vec2(v_zoneT * v_headLengthRatio, v_side * v_headWidthRatio * 0.5);
    float headSDF = queryExtremitySDF(v_headId, uv, v_headLengthRatio, v_headWidthRatio) * v_thickness;

    // Apply union only near base (v_zoneT < baseRatio)
    if (v_zoneT < headBaseRatio) {
      finalSDF = min(headSDF, bodySDF);
    } else {
      finalSDF = headSDF;
    }
  }`):`  // No extremity draws tail/head geometry, so every vertex is body zone.
  finalSDF = bodySDF;`,`

  #ifdef PICKING_MODE
    // Picking pass: output edge ID for pixels within the picking area
    if (finalSDF > u_pickingPadding * aaWidthWebGL) discard;
    fragColor = v_id;
  #else
`).concat(t?`    // Visual pass: anti-aliased edge with layers, edge opacity applied once
    float alpha = smoothstep(aaWidthWebGL, -aaWidthWebGL, finalSDF) * v_opacity;`:`    // Visual pass: hard-edged (no anti-aliasing gradient) edge with layers, edge opacity applied once
    float alpha = (finalSDF < 0.0 ? 1.0 : 0.0) * v_opacity;`,`
    if (alpha < 0.01) discard;

    // Apply layers sequentially with "over" compositing
    vec4 color = vec4(0.0);

`).concat(m,`

    // Mix with transparent to fade both color AND alpha (pre-multiplied alpha for correct blending)
    fragColor = mix(vec4(0.0), color, alpha);
  #endif
}
`);return p}function pc(a,n,e){var t=Ne(n.length)?!0:n.length>0,r=Ne(e.length)?!0:e.length>0;if(a.generateConstantData){var i=a.generateConstantData();return{data:i.data,attributes:i.attributes,verticesPerEdge:i.verticesPerEdge}}return fc(a.segments,t,r)}function po(a){var n,e=Go(a),t=e.paths,r=e.extremities,i=e.layers,o=(n=a.antialias)!==null&&n!==void 0?n:!0,s=new Map,l=new Map,u=new Map,d=M(t),c;try{for(d.s();!(c=d.n()).done;){var h=c.value,f=M(r),g;try{for(f.s();!(g=f.n()).done;){var m=g.value,p=M(r),v;try{for(p.s();!(v=p.n()).done;){var b=v.value,y="".concat(h.name,":").concat(m.name,":").concat(b.name),_=pc(h,m,b);s.set(y,_.verticesPerEdge),l.set(y,_.data);var x=M(_.attributes),T;try{for(x.s();!(T=x.n()).done;){var R=T.value;u.has(R.name)||u.set(R.name,R)}}catch(X){x.e(X)}finally{x.f()}}}catch(X){p.e(X)}finally{p.f()}}}catch(X){f.e(X)}finally{f.f()}}}catch(X){d.e(X)}finally{d.f()}var E=Array.from(u.values()),S={};E.forEach(function(X,K){S[X.name]=K});var w=0,F="",D=M(s),P;try{for(D.s();!(P=D.n()).done;){var L=te(P.value,2),I=L[0],z=L[1];z>w&&(w=z,F=I)}}catch(X){D.e(X)}finally{D.f()}var G=l.get(F)||[],k=F.split(":"),C=te(k,1),N=C[0],$=t.find(function(X){return X.name===N}),H=[];$!=null&&$.generateConstantData?H=$.generateConstantData().attributes:H=[{name:"a_zone"},{name:"a_zoneT"},{name:"a_side"}];var Z=G.map(function(X){var K=new Array(E.length).fill(0);return H.forEach(function(Ie,Te){var $e=S[Ie.name];$e!==void 0&&Te<X.length&&(K[$e]=X[Te])}),K});return{vertexShader:gc(t,r,i,E),fragmentShader:vc(t,r,i,o),uniforms:oc(t,r,i),attributes:mc(),verticesPerEdge:w,constantData:Z,constantAttributes:E,vertexCountsPerCombination:s,constantDataPerCombination:l}}function mc(a,n,e){return[{name:"a_edgeIndex",size:1,type:Tn},{name:"a_color",size:4,type:go,normalized:!0},{name:"a_id",size:4,type:go,normalized:!0},{name:"a_opacity",size:1,type:Tn}]}var bc=`#version 300 es
precision highp float;

in vec4 v_clamp;

// RGBA32F target: stores (tStart, tEnd, straightenFactor, pathLength).
out vec4 fragColor;

void main() {
  fragColor = v_clamp;
}
`,yc=function(){function a(n,e){Q(this,a),A(this,"uniformLocations",{});var t=e.paths,r=e.extremities,i=e.layers,o=e.nodeShapes,s=e.nodeLayers;this.gl=n,this.hasAttributeData=Fe([].concat(V(t),V(i))).floatsPerItem>0,this.hasNodeAttributeData=Object.keys($t(o,s).offsets).length>0,this.vertexShader=fr(n,hc(t,r,i,o,s)),this.fragmentShader=gr(n,bc),this.program=vr(n,[this.vertexShader,this.fragmentShader]);var l=new Set;this.customUniforms=[];for(var u=0,d=[].concat(V(t),V(r));u<d.length;u++){var c=d[u],h=M(c.uniforms),f;try{for(h.s();!(f=h.n()).done;){var g=f.value;l.has(g.name)||(l.add(g.name),this.customUniforms.push(g))}}catch(y){h.e(y)}finally{h.f()}}var m=["u_sizeRatio","u_correctionRatio","u_cameraAngle","u_minEdgeThickness","u_nodeDataTexture","u_nodeDataTextureWidth","u_edgeDataTexture","u_edgeDataTextureWidth","u_edgeAttributeTexture","u_edgeAttributeTextureWidth","u_edgeAttributeTexelsPerEdge","u_layerAttributeTexture","u_layerAttributeTextureWidth","u_layerAttributeTexelsPerNode","u_frameTextureWidth","u_frameTextureHeight"].concat(V(this.customUniforms.map(function(y){return y.name}))),p=M(m),v;try{for(p.s();!(v=p.n()).done;){var b=v.value;this.uniformLocations[b]=n.getUniformLocation(this.program,b)}}catch(y){p.e(y)}finally{p.f()}this.vao=n.createVertexArray()}return J(a,[{key:"run",value:function(e,t,r,i,o){if(r!==0){var s=this.gl,l=this.uniformLocations;s.useProgram(this.program),s.bindVertexArray(this.vao),l.u_sizeRatio&&s.uniform1f(l.u_sizeRatio,e.sizeRatio),l.u_correctionRatio&&s.uniform1f(l.u_correctionRatio,e.correctionRatio),l.u_cameraAngle&&s.uniform1f(l.u_cameraAngle,e.cameraAngle),l.u_minEdgeThickness&&s.uniform1f(l.u_minEdgeThickness,e.minEdgeThickness),l.u_nodeDataTexture&&s.uniform1i(l.u_nodeDataTexture,e.nodeDataTextureUnit),l.u_nodeDataTextureWidth&&s.uniform1i(l.u_nodeDataTextureWidth,e.nodeDataTextureWidth),l.u_edgeDataTexture&&s.uniform1i(l.u_edgeDataTexture,e.edgeDataTextureUnit),l.u_edgeDataTextureWidth&&s.uniform1i(l.u_edgeDataTextureWidth,e.edgeDataTextureWidth),l.u_frameTextureWidth&&s.uniform1f(l.u_frameTextureWidth,t.getTextureWidth()),l.u_frameTextureHeight&&s.uniform1f(l.u_frameTextureHeight,t.getTextureHeight()),this.hasAttributeData&&i&&(i.bind(ot),l.u_edgeAttributeTexture&&s.uniform1i(l.u_edgeAttributeTexture,ot),l.u_edgeAttributeTextureWidth&&s.uniform1i(l.u_edgeAttributeTextureWidth,i.getTextureWidth()),l.u_edgeAttributeTexelsPerEdge&&s.uniform1i(l.u_edgeAttributeTexelsPerEdge,i.getTexelsPerItem())),this.hasNodeAttributeData&&o&&(o.bind(it),l.u_layerAttributeTexture&&s.uniform1i(l.u_layerAttributeTexture,it),l.u_layerAttributeTextureWidth&&s.uniform1i(l.u_layerAttributeTextureWidth,o.getTextureWidth()),l.u_layerAttributeTexelsPerNode&&s.uniform1i(l.u_layerAttributeTexelsPerNode,o.getTexelsPerItem()));var u=M(this.customUniforms),d;try{for(u.s();!(d=u.n()).done;){var c=d.value;yr(s,this.uniformLocations[c.name],c)}}catch(h){u.e(h)}finally{u.f()}t.bindAsRenderTarget(),s.disable(s.BLEND),s.disable(s.DEPTH_TEST),s.drawArrays(s.POINTS,0,r),s.bindFramebuffer(s.FRAMEBUFFER,null),s.bindVertexArray(null)}}},{key:"kill",value:function(){var e=this.gl;e.deleteProgram(this.program),e.deleteShader(this.vertexShader),e.deleteShader(this.fragmentShader),e.deleteVertexArray(this.vao)}}])}();function xn(a,n,e,t,r,i){if(a.length===1)return"".concat(t," ").concat(n,"(int pathId, ").concat(r,`) {
  return path_`).concat(a[0].name,"_").concat(e,"(").concat(i,`);
}`);var o=a.map(function(s,l){return"    case ".concat(l,": return path_").concat(s.name,"_").concat(e,"(").concat(i,");")}).join(`
`);return"".concat(t," ").concat(n,"(int pathId, ").concat(r,`) {
  switch (pathId) {
`).concat(o,`
    default: return path_`).concat(a[0].name,"_").concat(e,"(").concat(i,`);
  }
}`)}var xc=`
vec3 computeEdgeLabelBodyBounds(
  float tStart, float tEnd, float pathLength,
  float webGLThickness, float headLengthRatio, float tailLengthRatio
) {
  float visibleLength = pathLength * (tEnd - tStart);

  float headLength = headLengthRatio * webGLThickness;
  float tailLength = tailLengthRatio * webGLThickness;
  float totalNeededLength = headLength + tailLength;
  if (totalNeededLength > visibleLength && totalNeededLength > 0.0001) {
    float extremityScale = visibleLength / totalNeededLength;
    headLength *= extremityScale;
    tailLength *= extremityScale;
  }

  float bodyStartDist = tStart * pathLength + tailLength;
  float bodyEndDist = tEnd * pathLength - headLength;
  return vec3(bodyStartDist, bodyEndDist, max(bodyEndDist - bodyStartDist, 0.0));
}
`;function _c(a,n){var e=he(a),t=he(n);return`
float computeEdgeLabelAlpha(float bodyLength, float textWidthWebGL) {
  float ratio = textWidthWebGL > 0.0001 ? min(bodyLength / textWidthWebGL, 1.0) : 1.0;
  if (ratio < `.concat(e,`) return 0.0;
  if (ratio < `).concat(t,") return (ratio - ").concat(e,") / (").concat(t," - ").concat(e,`);
  return 1.0;
}
`)}var Tc=`
float computeEdgeLabelScreenDir(int pathId, float t, vec2 source, vec2 target, mat3 matrix) {
  vec2 tangent = queryPathTangent(pathId, t, source, target);
  return (matrix * vec3(tangent, 0.0)).x < 0.0 ? -1.0 : 1.0;
}
`,Sc=`
float computeEdgeLabelPerpOffset(
  float positionMode,
  float halfThickness, float marginWebGL, float halfTextHeight,
  float readingSign, float screenDir
) {
  float magnitude = halfThickness + marginWebGL + halfTextHeight;
  if (positionMode == 1.0) return magnitude * readingSign;
  if (positionMode == 2.0) return -magnitude * readingSign;
  if (positionMode == 3.0) return magnitude * screenDir;
  return 0.0;
}
`;function No(a){var n=a.paths,e=a.minVisibilityThreshold,t=a.fullVisibilityThreshold,r=n.some(function(s){return s.hasSharpCorners}),i=n.map(function(s){return"// --- Path: ".concat(s.name,` ---
`).concat(s.glsl,`

// Tangent/normal functions: analytical if provided, otherwise numerical
`).concat(s.analyticalTangentGlsl||Fo(s.name),`

// Auto-generated fallbacks for any missing path functions
`).concat(Io(s.name,s.glsl),`

// Corner skip helpers (for paths with sharp corners like step/taxi)
`).concat(s.cornerSkipGlsl||"",`
`)}).join(`
`),o=r?`// Corner function selectors (only some paths have sharp corners)
vec2 queryGetCornerTs(int pathId, vec2 source, vec2 target) {
  switch (pathId) {
`.concat(n.map(function(s,l){return s.hasSharpCorners?"    case ".concat(l,": return path_").concat(s.name,"_getCornerTs(source, target);"):"    case ".concat(l,": return vec2(-1.0, -1.0); // No corners for ").concat(s.name)}).join(`
`),`
    default: return vec2(-1.0, -1.0);
  }
}

vec2 queryGetCornerConcavity(int pathId, vec2 source, vec2 target, float perpOffset) {
  switch (pathId) {
`).concat(n.map(function(s,l){return s.hasSharpCorners?"    case ".concat(l,": return path_").concat(s.name,"_getCornerConcavity(source, target, perpOffset);"):"    case ".concat(l,": return vec2(0.0, 0.0); // No corners for ").concat(s.name)}).join(`
`),`
    default: return vec2(0.0, 0.0);
  }
}`):"";return`
// ============================================================================
// Node data fetch (geometry texel) and per-edge clamp fetch (edge-frame texture)
// ============================================================================

`.concat(Qe,`
`).concat(Ht,`

// ============================================================================
// Path Functions (one block per path)
// ============================================================================

`).concat(i,`

// ============================================================================
// Path Query Selectors (dispatch by pathId)
// ============================================================================

`).concat(xn(n,"queryPathPosition","position","vec2","float t, vec2 source, vec2 target","t, source, target"),`

`).concat(xn(n,"queryPathTangent","tangent","vec2","float t, vec2 source, vec2 target","t, source, target"),`

`).concat(xn(n,"queryPathNormal","normal","vec2","float t, vec2 source, vec2 target","t, source, target"),`

`).concat(xn(n,"queryPathLength","length","float","vec2 source, vec2 target","source, target"),`

`).concat(xn(n,"queryPathTAtDistance","t_at_distance","float","float dist, vec2 source, vec2 target","dist, source, target"),`

`).concat(o,`

// ============================================================================
// Shared helpers (body bounds, alpha ramp, screen direction, perpendicular offset)
// ============================================================================

`).concat(xc,`
`).concat(_c(e,t),`
`).concat(Tc,`
`).concat(Sc,`
`)}var Ec=Ue.fontSize,Rc=new Map,Mo=24,mo=(Mo+1)*2;function Ac(a){var n=a.paths,e=a.fontSizeMode,t=a.headLengthRatio,r=a.tailLengthRatio,i=a.minVisibilityThreshold,o=a.fullVisibilityThreshold,s=a.keepUpright,l=e==="scaled",u=Be(),d=Fe([].concat(V(n),[u])),c=An(d),h=`#version 300 es

// Per-instance attributes
in float a_edgeIndex;
in float a_edgeAttrIndex;
in float a_baseFontSize;
in float a_totalTextWidth;
in float a_positionMode;
in float a_margin;
in float a_padding;
in vec4 a_color;
in vec4 a_id;

// Per-vertex (constant) attribute: strip vertex index
in float a_vertexIndex;

uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_pixelRatio;
uniform float u_cameraAngle;
uniform vec2 u_resolution;
uniform sampler2D u_nodeDataTexture;
uniform int u_nodeDataTextureWidth;
uniform sampler2D u_edgeDataTexture;
uniform int u_edgeDataTextureWidth;
uniform sampler2D u_edgeFrameTexture; // Per-edge clamp (tStart, tEnd, straightenFactor, pathLength)
uniform int u_edgeFrameTextureWidth;
`.concat(l?"uniform float u_zoomSizeRatio;":"",`

`).concat(c.uniformDeclarations,`

out vec4 v_color;
out vec4 v_id;
out float v_alphaModifier;

const float ATLAS_FONT_SIZE = `).concat(he(Ec),`;
const float HEAD_RATIO = `).concat(he(t),`;
const float TAIL_RATIO = `).concat(he(r),`;
const int RIBBON_SEGMENTS = `).concat(Mo,`;

// Path attribute varyings (declared as plain locals since this shader has no FS inputs for them)
`).concat(c.vertexVaryingDeclarations.replace(/out /g,""),`

// Node size variables used by some path functions (self-loops, etc.)
float v_sourceNodeSize;
float v_targetNodeSize;

// Shared preamble: shape SDFs, path functions + selectors, clamp, helpers.
`).concat(No({paths:n,minVisibilityThreshold:i,fullVisibilityThreshold:o}),`

void main() {
  int vIdx = int(a_vertexIndex);
  int pairIdx = vIdx / 2;
  int side = vIdx - pairIdx * 2; // 0 = left/bottom, 1 = right/top

  // --- Fetch edge data (2 texels per edge) ---
  int edgeIdx = int(a_edgeIndex);
  int texel0Idx = edgeIdx * 2;
  int texel1Idx = edgeIdx * 2 + 1;
  ivec2 e0 = ivec2(texel0Idx % u_edgeDataTextureWidth, texel0Idx / u_edgeDataTextureWidth);
  ivec2 e1 = ivec2(texel1Idx % u_edgeDataTextureWidth, texel1Idx / u_edgeDataTextureWidth);
  vec4 edgeData0 = texelFetch(u_edgeDataTexture, e0, 0);
  vec4 edgeData1 = texelFetch(u_edgeDataTexture, e1, 0);

  int srcIdx = int(edgeData0.x);
  int tgtIdx = int(edgeData0.y);
  float thickness = edgeData0.z;
  int pathId = int(edgeData1.z);

  // --- Fetch path attributes (curvature, etc.) ---
  {
    int edgeIdx = int(a_edgeAttrIndex);
`).concat(c.fetchCode,`
`).concat(c.varyingAssignments,`
  }

  // --- Fetch node data: geometry (texel 0) + rotation flags (texel 1) ---
  vec4 srcN = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx);
  vec4 tgtN = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx);

  vec2 source = srcN.xy;
  vec2 target = tgtN.xy;
  float sourceSize = srcN.z;
  float targetSize = tgtN.z;
  v_sourceNodeSize = sourceSize;
  v_targetNodeSize = targetSize;

  // --- Pixel-to-graph conversion (fixed font mode) ---
  float matrixScaleX = length(vec2(u_matrix[0][0], u_matrix[1][0]));
  float pixelToGraph = 2.0 / (matrixScaleX * u_resolution.x);

  float webGLThickness = thickness * u_correctionRatio / u_sizeRatio;

  // --- Body bounds (shared with edge label shader) ---
  vec4 edgeClamp = readFrameTexel(u_edgeFrameTexture, u_edgeFrameTextureWidth, edgeIdx);
  vec3 bodyBounds = computeEdgeLabelBodyBounds(
    edgeClamp.x, edgeClamp.y, edgeClamp.w,
    webGLThickness, HEAD_RATIO, TAIL_RATIO
  );
  float bodyStartDist = bodyBounds.x;
  float bodyEndDist = bodyBounds.y;
  float bodyLength = bodyBounds.z;

  // --- Text dimensions ---
  float baseFontSize = a_baseFontSize;
  `).concat(l?`float fontScale = baseFontSize / ATLAS_FONT_SIZE * u_zoomSizeRatio;
  float textWidthWebGL = a_totalTextWidth * fontScale * u_correctionRatio / u_sizeRatio;
  float halfTextHeight = baseFontSize * 0.35 * u_zoomSizeRatio * u_correctionRatio / u_sizeRatio;
  float marginWebGL = a_margin * u_zoomSizeRatio * u_correctionRatio / u_sizeRatio;`:`float fontScale = baseFontSize / ATLAS_FONT_SIZE;
  float textWidthWebGL = a_totalTextWidth * fontScale * pixelToGraph;
  float halfTextHeight = baseFontSize * 0.35 * pixelToGraph;
  float marginWebGL = a_margin * pixelToGraph;`,`
  float paddingWebGL = a_padding * pixelToGraph;

  // --- Alpha modifier (shared with edge label shader) ---
  float alphaModifier = computeEdgeLabelAlpha(bodyLength, textWidthWebGL);
  if (alphaModifier <= 0.0 || textWidthWebGL <= 0.0) {
    gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
    v_color = vec4(0.0);
    v_id = vec4(0.0);
    v_alphaModifier = 0.0;
    return;
  }

  // --- Perpendicular offset (shared with edge label shader) ---
  float bodyCenterDist = (bodyStartDist + bodyEndDist) * 0.5;
  float centerT = queryPathTAtDistance(pathId, bodyCenterDist, source, target);
  float screenDir = computeEdgeLabelScreenDir(pathId, centerT, source, target, u_matrix);
  float readingSign = `).concat(s?"screenDir":"1.0",`;
  float halfThickness = webGLThickness * 0.5;
  float perpOffset = computeEdgeLabelPerpOffset(
    a_positionMode, halfThickness, marginWebGL, halfTextHeight, readingSign, screenDir
  );

  // --- Ribbon span (clipped to body) ---
  float halfTextWebGL = textWidthWebGL * 0.5;
  float labelStartDist = max(bodyCenterDist - halfTextWebGL, bodyStartDist);
  float labelEndDist = min(bodyCenterDist + halfTextWebGL, bodyEndDist);

  // Sample centerline at this pair, then apply perpendicular offset.
  // The ribbon follows the centerline path (simple & robust); for curved edges
  // this closely matches the offset path the characters sit on.
  float u = float(pairIdx) / float(RIBBON_SEGMENTS);
  float arcDist = mix(labelStartDist, labelEndDist, u);
  float t = queryPathTAtDistance(pathId, arcDist, source, target);
  vec2 pos = queryPathPosition(pathId, t, source, target);
  vec2 tan = queryPathTangent(pathId, t, source, target);
  vec2 perp = vec2(-tan.y, tan.x);

  vec2 centerPos = pos + perp * perpOffset;

  float halfRibbon = halfTextHeight + paddingWebGL;
  float sideSign = side == 0 ? -1.0 : 1.0;
  vec2 ribbonPos = centerPos + perp * (sideSign * halfRibbon);

  vec3 clipPos = u_matrix * vec3(ribbonPos, 1.0);
  gl_Position = vec4(clipPos.xy, 0.0, 1.0);

  v_color = a_color;
  v_id = a_id;
  v_alphaModifier = alphaModifier;
}
`);return h}var Dc=`#version 300 es
precision highp float;

in vec4 v_color;
in vec4 v_id;
in float v_alphaModifier;

out vec4 fragColor;

void main() {
#ifdef PICKING_MODE
  if (v_alphaModifier <= 0.0) discard;
  fragColor = v_id;
#else
  float alpha = v_color.a * v_alphaModifier;
  if (alpha <= 0.0) discard;
  fragColor = vec4(v_color.rgb * alpha, alpha);
#endif
}
`;function wc(a,n,e,t){var r=t.shaderConfig,i=r.paths,o=r.fontSizeMode;if(i.length===0)throw new Error("createEdgeLabelBackgroundProgram: shaderConfig must declare at least one path");var s=Be(),l=Fe([].concat(V(i),[s])),u=Aa([].concat(V(i),[s]),l),d=Ac(r),c=function(h){function f(g,m,p){var v;return Q(this,f),v=le(this,f,[g,m,p]),A(v,"totalCount",0),A(v,"bufferCapacity",0),A(v,"edgeAttributeTexture",null),v.edgeAttributeTexture=new Ra(g,l),v.packedAttributeData=new Float32Array(l.floatsPerItem),v}return ue(f,h),J(f,[{key:"getDefinition",value:function(){for(var m=WebGL2RenderingContext,p=m.FLOAT,v=m.UNSIGNED_BYTE,b=m.TRIANGLE_STRIP,y=[],_=0;_<mo;_++)y.push([_]);var x=["u_matrix","u_sizeRatio","u_correctionRatio","u_pixelRatio","u_cameraAngle","u_resolution","u_nodeDataTexture","u_nodeDataTextureWidth","u_edgeDataTexture","u_edgeDataTextureWidth","u_edgeFrameTexture","u_edgeFrameTextureWidth"];return o==="scaled"&&x.push("u_zoomSizeRatio"),l.floatsPerItem>0&&x.push("u_edgeAttributeTexture","u_edgeAttributeTextureWidth","u_edgeAttributeTexelsPerEdge"),{VERTICES:mo,VERTEX_SHADER_SOURCE:d,FRAGMENT_SHADER_SOURCE:Dc,METHOD:b,UNIFORMS:x,ATTRIBUTES:[{name:"a_edgeIndex",size:1,type:p},{name:"a_edgeAttrIndex",size:1,type:p},{name:"a_baseFontSize",size:1,type:p},{name:"a_totalTextWidth",size:1,type:p},{name:"a_positionMode",size:1,type:p},{name:"a_margin",size:1,type:p},{name:"a_padding",size:1,type:p},{name:"a_color",size:4,type:v,normalized:!0},{name:"a_id",size:4,type:v,normalized:!0}],CONSTANT_ATTRIBUTES:[{name:"a_vertexIndex",size:1,type:p}],CONSTANT_DATA:y}}},{key:"processEdgeLabelBackground",value:function(m,p,v){var b=0;if(this.edgeAttributeTexture&&l.floatsPerItem>0){b=this.edgeAttributeTexture.allocate(p);var y=this.packedAttributeData;Da(u,v.edgeAttributes,y,"",Rc,0),this.edgeAttributeTexture.updateAllAttributes(p,y)}var _=this.floats,x=this.ints,T=m*this.STRIDE;_[T++]=v.edgeIndex,_[T++]=b,_[T++]=v.baseFontSize,_[T++]=v.totalTextWidth,_[T++]=v.positionMode,_[T++]=v.margin,_[T++]=v.padding,_[T++]=v.color,x[T++]=v.id}},{key:"setUniforms",value:function(m,p){var v=p.gl,b=p.uniformLocations;if(v.uniformMatrix3fv(b.u_matrix,!1,m.matrix),v.uniform1f(b.u_sizeRatio,m.sizeRatio),v.uniform1f(b.u_correctionRatio,m.correctionRatio),v.uniform1f(b.u_pixelRatio,m.pixelRatio),v.uniform1f(b.u_cameraAngle,m.cameraAngle),v.uniform2f(b.u_resolution,m.width,m.height),b.u_nodeDataTexture!==void 0&&v.uniform1i(b.u_nodeDataTexture,m.nodeDataTextureUnit),b.u_nodeDataTextureWidth!==void 0&&v.uniform1i(b.u_nodeDataTextureWidth,m.nodeDataTextureWidth),b.u_edgeDataTexture!==void 0&&v.uniform1i(b.u_edgeDataTexture,m.edgeDataTextureUnit),b.u_edgeDataTextureWidth!==void 0&&v.uniform1i(b.u_edgeDataTextureWidth,m.edgeDataTextureWidth),b.u_edgeFrameTexture!==void 0&&v.uniform1i(b.u_edgeFrameTexture,m.edgeFrameTextureUnit),b.u_edgeFrameTextureWidth!==void 0&&v.uniform1i(b.u_edgeFrameTextureWidth,m.edgeFrameTextureWidth),o==="scaled"&&b.u_zoomSizeRatio!==void 0){var y=this.renderer.getSetting("zoomToSizeRatioFunction");v.uniform1f(b.u_zoomSizeRatio,1/y(m.zoomRatio))}this.edgeAttributeTexture&&l.floatsPerItem>0&&b.u_edgeAttributeTexture!==void 0&&(this.edgeAttributeTexture.bind(ot),v.uniform1i(b.u_edgeAttributeTexture,ot),v.uniform1i(b.u_edgeAttributeTextureWidth,this.edgeAttributeTexture.getTextureWidth()),v.uniform1i(b.u_edgeAttributeTexelsPerEdge,this.edgeAttributeTexture.getTexelsPerItem()))}},{key:"renderProgram",value:function(m,p){this.edgeAttributeTexture&&l.floatsPerItem>0&&this.edgeAttributeTexture.upload(),ve(f,"renderProgram",this,3)([m,p])}},{key:"kill",value:function(){this.edgeAttributeTexture&&(this.edgeAttributeTexture.kill(),this.edgeAttributeTexture=null),ve(f,"kill",this,3)([])}},{key:"drawWebGL",value:function(m,p){var v=p.gl;this.totalCount!==0&&v.drawArraysInstanced(v.TRIANGLE_STRIP,0,this.VERTICES,this.totalCount)}},{key:"reallocate",value:function(m){this.totalCount=m,m>this.bufferCapacity&&(this.bufferCapacity=Math.max(m,Math.ceil(this.bufferCapacity*1.5)||10),ve(f,"reallocate",this,3)([this.bufferCapacity]))}}])}(bt);return new c(a,n,e)}function Oo(a){var n,e,t,r,i,o;return{paths:a.paths,headLengthRatio:(n=a.headLengthRatio)!==null&&n!==void 0?n:0,tailLengthRatio:(e=a.tailLengthRatio)!==null&&e!==void 0?e:0,fontSizeMode:(t=a.fontSizeMode)!==null&&t!==void 0?t:"fixed",minVisibilityThreshold:(r=a.minVisibilityThreshold)!==null&&r!==void 0?r:.7,fullVisibilityThreshold:(i=a.fullVisibilityThreshold)!==null&&i!==void 0?i:.8,keepUpright:(o=a.keepUpright)!==null&&o!==void 0?o:!0}}var Lc=Ue.fontSize,Cc=17/64;function Pc(a){var n=a.paths,e=a.hasBorder,t=e===void 0?!1:e,r=a.fontSizeMode,i=r===void 0?"fixed":r,o=a.minVisibilityThreshold,s=o===void 0?.5:o,l=a.fullVisibilityThreshold,u=l===void 0?.6:l,d=a.keepUpright,c=d===void 0?!0:d,h=i==="scaled",f=n.some(function(b){return b.hasSharpCorners}),g=Be(),m=Fe([].concat(V(n),[g])),p=An(m),v=`#version 300 es

// ============================================================================
// Attributes - Per Character (Instanced)
// ============================================================================

// Edge geometry: indices for texture lookup
// Edge data (source/target node indices, thickness, head/tail ratios) is fetched from edge data texture
// Edge path attributes (curvature, etc.) are fetched from edge attribute texture
in float a_edgeIndex;       // Index into edge data texture
in float a_edgeAttrIndex;   // Index into edge attribute texture (for curvature, etc.)
in float a_baseFontSize;    // Base font size in pixels (per-label)

// Character metrics (in glyph units = atlas font size pixels)
in vec4 a_charMetrics;      // (charTextOffset, charAdvance, totalTextWidth, positionMode)
in vec4 a_charDims;         // (charSize.x, charSize.y, charOffset.x, charOffset.y)

// Atlas texture coordinates
in vec4 a_texCoords;        // (x, y, width, height) in atlas pixels

// Label parameters
in vec2 a_labelParams;      // (margin, unused)

// Appearance
in vec4 a_color;            // Character color (RGBA, normalized)
`.concat(t?"in vec4 a_borderColor;      // Border color (RGBA, normalized)":"",`

// ============================================================================
// Attributes - Per Vertex (Constant)
// ============================================================================

in vec2 a_quadCorner;       // Quad corner: (0,0), (1,0), (0,1), (1,1)

// ============================================================================
// Uniforms
// ============================================================================

uniform mat3 u_matrix;
uniform float u_sizeRatio;
uniform float u_correctionRatio;
uniform float u_pixelRatio;
uniform float u_cameraAngle;    // Required by node shape SDFs
// u_sdfBufferPixels kept for ABI compatibility but unused in shader
uniform float u_sdfBufferPixels;
uniform vec2 u_resolution;
uniform vec2 u_atlasSize;
uniform sampler2D u_nodeDataTexture; // Shared texture with node position/size/shape data
uniform int u_nodeDataTextureWidth;  // Width of 2D node data texture for coordinate calculation
uniform sampler2D u_edgeDataTexture; // Shared texture with edge data
uniform int u_edgeDataTextureWidth;  // Width of 2D edge data texture for coordinate calculation
uniform sampler2D u_edgeFrameTexture; // Per-edge clamp (tStart, tEnd, straightenFactor, pathLength)
uniform int u_edgeFrameTextureWidth;
`).concat(h?"uniform float u_zoomSizeRatio;  // Zoom-based size ratio from zoomToSizeRatioFunction":"",`

// Edge path attribute texture uniforms (for curvature and other path attributes)
`).concat(p.uniformDeclarations,`

// ============================================================================
// Varyings
// ============================================================================

out vec2 v_texCoord;
out vec4 v_color;
`).concat(t?"out vec4 v_borderColor;":"",`
out float v_edgeFade;  // 0 = fully visible, 1 = fully faded (outside body)
out float v_alphaModifier;  // 0-1 based on label visibility ratio
out float v_fontScale;  // Ratio of rendered font size to atlas font size
`).concat(t?"out float v_positionMode;  // Position mode for conditional border (0=over needs border)":"",`

// ============================================================================
// Constants
// ============================================================================

const float bias = 255.0 / 254.0;
const float FADE_WIDTH_PIXELS = 15.0;  // Width of fade gradient in pixels
const float ATLAS_FONT_SIZE = `).concat(he(Lc),`;  // Base font size used in SDF atlas
const float VERTICAL_CENTER_RATIO = `).concat(he(Cc),`;  // Baseline to visual center ratio

// ============================================================================
// Path Attribute Variables (set in main, used by path functions)
// ============================================================================
// Path attributes are fetched from the edge attribute texture and stored in
// variables with v_ prefix (e.g., v_curvature) for path functions to access.
`).concat(p.vertexVaryingDeclarations.replace(/out /g,""),`

// Node size variables (set in main, used by some path functions like loops).
// These mirror the v_sourceNodeSize / v_targetNodeSize varyings in generator.ts,
// but are plain floats here since the label shader is vertex-only.
float v_sourceNodeSize;
float v_targetNodeSize;

// Shared preamble: shape SDFs, path functions + selectors, clamp, helpers.
`).concat(No({paths:n,minVisibilityThreshold:s,fullVisibilityThreshold:u}),`

// ============================================================================
// Main
// ============================================================================

void main() {
  // -------------------------------------------------------------------------
  // Fetch edge data from edge texture (2 texels per edge)
  // -------------------------------------------------------------------------
  // Texel 0: sourceNodeIndex, targetNodeIndex, thickness, reserved
  // Texel 1: headLengthRatio, tailLengthRatio, pathId, extremityIds
  int edgeIdx = int(a_edgeIndex);
  int texel0Idx = edgeIdx * 2;
  int texel1Idx = edgeIdx * 2 + 1;
  ivec2 edgeTexCoord0 = ivec2(texel0Idx % u_edgeDataTextureWidth, texel0Idx / u_edgeDataTextureWidth);
  ivec2 edgeTexCoord1 = ivec2(texel1Idx % u_edgeDataTextureWidth, texel1Idx / u_edgeDataTextureWidth);
  vec4 edgeData0 = texelFetch(u_edgeDataTexture, edgeTexCoord0, 0);
  vec4 edgeData1 = texelFetch(u_edgeDataTexture, edgeTexCoord1, 0);

  // Unpack edge data
  int srcIdx = int(edgeData0.x);
  int tgtIdx = int(edgeData0.y);
  float thickness = edgeData0.z;
  // edgeData0.w is reserved
  float headLengthRatio = edgeData1.x;
  float tailLengthRatio = edgeData1.y;
  int pathId = int(edgeData1.z);  // Path type for multi-path support
  float baseFontSize = a_baseFontSize;

  // -------------------------------------------------------------------------
  // Fetch path attributes from edge attribute texture
  // -------------------------------------------------------------------------
  // Note: The fetch code uses 'edgeIdx' variable, so we set it to the attribute texture index
  {
    int edgeIdx = int(a_edgeAttrIndex);  // Use attribute texture index for path attributes
`).concat(p.fetchCode,`
`).concat(p.varyingAssignments,`
  }

  // -------------------------------------------------------------------------
  // Fetch node data from node texture (geometry texel + rotation-flags texel)
  // -------------------------------------------------------------------------
  vec4 srcNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, srcIdx);
  vec4 tgtNodeData = readNodeData(u_nodeDataTexture, u_nodeDataTextureWidth, tgtIdx);

  vec2 source = srcNodeData.xy;
  vec2 target = tgtNodeData.xy;
  float sourceSize = srcNodeData.z;
  float targetSize = tgtNodeData.z;
  v_sourceNodeSize = sourceSize;
  v_targetNodeSize = targetSize;
  float charTextOffset = a_charMetrics.x;
  float charAdvance = a_charMetrics.y;
  float totalTextWidth = a_charMetrics.z;
  float positionMode = a_charMetrics.w;
  vec2 charSize = a_charDims.xy;
  vec2 charOffset = a_charDims.zw;
  float margin = a_labelParams.x;

  // -------------------------------------------------------------------------
  // Compute pixel-to-graph conversion (for fixed font size mode)
  // -------------------------------------------------------------------------
  // This converts screen pixels to graph units such that N pixels on screen
  // becomes N pixels regardless of zoom level.
  // matrixScaleX is how much the matrix scales graph units to clip space
  float matrixScaleX = length(vec2(u_matrix[0][0], u_matrix[1][0]));
  float pixelToGraph = 2.0 / (matrixScaleX * u_resolution.x);

  // -------------------------------------------------------------------------
  // Step 1: Convert thickness to WebGL units
  // -------------------------------------------------------------------------
  float webGLThickness = thickness * u_correctionRatio / u_sizeRatio;

  // -------------------------------------------------------------------------
  // Step 2: Compute body bounds (truncated at node boundaries + extremities)
  // -------------------------------------------------------------------------
  vec4 edgeClamp = readFrameTexel(u_edgeFrameTexture, u_edgeFrameTextureWidth, edgeIdx);
  vec3 bodyBounds = computeEdgeLabelBodyBounds(
    edgeClamp.x, edgeClamp.y, edgeClamp.w,
    webGLThickness, headLengthRatio, tailLengthRatio
  );
  float bodyStartDist = bodyBounds.x;
  float bodyEndDist = bodyBounds.y;
  float bodyLength = bodyBounds.z;

  // -------------------------------------------------------------------------
  // Step 3: Compute font scale and text dimensions
  // -------------------------------------------------------------------------
  // Font size modes:
  // - "fixed": Constant pixel size regardless of zoom, using pixelToGraph conversion
  // - "scaled": Scales with zoom using zoomToSizeRatioFunction
  `).concat(h?`// Scaled mode: font scales with zoom
  float fontScale = baseFontSize / ATLAS_FONT_SIZE * u_zoomSizeRatio;
  // Convert glyph-unit metrics to WebGL units (scales with zoom)
  float textWidthWebGL = totalTextWidth * fontScale * u_correctionRatio / u_sizeRatio;
  float charOffsetWebGL = charTextOffset * fontScale * u_correctionRatio / u_sizeRatio;
  float charAdvanceWebGL = charAdvance * fontScale * u_correctionRatio / u_sizeRatio;`:`// Fixed mode: font stays constant in screen pixels
  float fontScale = baseFontSize / ATLAS_FONT_SIZE;
  // Convert glyph-unit metrics to graph units using pixelToGraph (zoom-independent)
  float textWidthWebGL = totalTextWidth * fontScale * pixelToGraph;
  float charOffsetWebGL = charTextOffset * fontScale * pixelToGraph;
  float charAdvanceWebGL = charAdvance * fontScale * pixelToGraph;`,`

  // Font scale varying for fragment shader gamma scaling.
  // Ratio of rendered font size to atlas font size \u2014 used to tighten the
  // anti-aliasing band for large labels so they stay sharp.
  v_fontScale = fontScale;

  // -------------------------------------------------------------------------
  // Step 4: Alpha modifier from how much of the label fits in the body
  // -------------------------------------------------------------------------
  float alphaModifier = computeEdgeLabelAlpha(bodyLength, textWidthWebGL);

  // -------------------------------------------------------------------------
  // Step 5: Compute character center offset (truncation check moved to after curvature adjustment)
  // -------------------------------------------------------------------------
  // Body center in arc distance
  float bodyCenterDist = (bodyStartDist + bodyEndDist) * 0.5;

  float centerT = queryPathTAtDistance(pathId, bodyCenterDist, source, target);
  float screenDir = computeEdgeLabelScreenDir(pathId, centerT, source, target, u_matrix);

  // Reversed labels lay their characters out from target to source
  float readingSign = `).concat(c?"screenDir":"1.0",`;

  // Character center position relative to label center (on centerline, before curvature adjustment)
  float charCenterOffset = readingSign * (charOffsetWebGL + charAdvanceWebGL * 0.5 - textWidthWebGL * 0.5);

  // -------------------------------------------------------------------------
  // Step 6: Compute perpendicular offset based on position mode
  // -------------------------------------------------------------------------
  // Position modes: 0=over, 1=above, 2=below, 3=auto
  // Needed early for curvature-adaptive character spacing in Step 7
  float halfThickness = webGLThickness * 0.5;
  `).concat(h?`// Scaled mode: margin and text height scale with zoom (same factor as font)
  float marginWebGL = margin * u_zoomSizeRatio * u_correctionRatio / u_sizeRatio;
  float halfTextHeight = baseFontSize * 0.35 * u_zoomSizeRatio * u_correctionRatio / u_sizeRatio;`:`// Fixed mode: margin and text height stay constant in screen pixels
  float marginWebGL = margin * pixelToGraph;
  float halfTextHeight = baseFontSize * 0.35 * pixelToGraph;`,`
  float perpOffset = computeEdgeLabelPerpOffset(
    positionMode, halfThickness, marginWebGL, halfTextHeight, readingSign, screenDir
  );

  // -------------------------------------------------------------------------
  // Step 7: Position character on path using offset path traversal
  // -------------------------------------------------------------------------
  // For "over" mode (perpOffset = 0), use simple centerline placement
  // For above/below modes, walk along the offset path to find correct position
  float charT;

  if (perpOffset == 0.0) {
    // Simple case: place on centerline
    float charArcDist = bodyCenterDist + charCenterOffset;
    charT = queryPathTAtDistance(pathId, charArcDist, source, target);
  } else {
    // Offset path traversal: walk along the offset curve to find character position
    // This ensures even character spacing regardless of curvature

    `).concat(f?`// -----------------------------------------------------------------------
    // Corner skip setup for step/taxi edges with above/below labels
    // -----------------------------------------------------------------------
    // At concave corners (inner side of the bend), characters would bunch up
    // because the offset path has near-zero arc length. We detect corner
    // crossings during the offset path traversal and add skip distance.

    // Get corner t values and concavity
    vec2 cornerTs = queryGetCornerTs(pathId, source, target);
    vec2 concavity = queryGetCornerConcavity(pathId, source, target, perpOffset);

    // Skip distance in graph units, proportional to on-screen font size
    // For fixed mode: use pixelToGraph so gap stays constant regardless of zoom
    // For scaled mode: use the same conversion as text width
    `.concat(h?"float skipDistGraph = STEP_INNER_CORNER_SKIP_FACTOR * baseFontSize * u_zoomSizeRatio * u_correctionRatio / u_sizeRatio;":"float skipDistGraph = STEP_INNER_CORNER_SKIP_FACTOR * baseFontSize * pixelToGraph;",`

    // Corner t values for detecting crossings during traversal
    float corner1T = cornerTs.x;
    float corner2T = cornerTs.y;
    bool corner1IsConcave = concavity.x > 0.5;
    bool corner2IsConcave = concavity.y > 0.5;`):"",`

    // Target distance along offset path from center
    float targetOffsetDist = abs(charCenterOffset);

    // Handle center character (charCenterOffset \u2248 0) - no search needed
    if (targetOffsetDist < 0.0001) {
      charT = centerT;
    } else {
      vec2 centerPos = queryPathPosition(pathId, centerT, source, target);
      vec2 centerNormal = queryPathNormal(pathId, centerT, source, target);
      vec2 offsetCenter = centerPos + centerNormal * perpOffset;

      float searchDir = charCenterOffset > 0.0 ? 1.0 : -1.0;

      // Search bounds (t values for body start and end)
      float tBodyStart = queryPathTAtDistance(pathId, bodyStartDist, source, target);
      float tBodyEnd = queryPathTAtDistance(pathId, bodyEndDist, source, target);

      // Walk along offset path to find character position
      float accumDist = 0.0;
      vec2 prevOffsetPos = offsetCenter;
      float prevT = centerT;
      float foundT = centerT;

      // Search range depends on direction
      float tSearchEnd = searchDir > 0.0 ? tBodyEnd : tBodyStart;

      `).concat(f?`// Track which concave corners we've crossed to add skip distance
      bool crossedCorner1 = false;
      bool crossedCorner2 = false;
      float effectiveTargetDist = targetOffsetDist;`:"",`

      const int STEPS = 32;
      for (int i = 1; i <= STEPS; i++) {
        // Step along centerline t, from center toward target
        float stepT = centerT + searchDir * float(i) * abs(tSearchEnd - centerT) / float(STEPS);

        `).concat(f?`// Check for concave corner crossings and add skip distance
        // Corner 1 crossing check
        if (corner1IsConcave && !crossedCorner1) {
          bool crossingCorner1 = (searchDir > 0.0)
            ? (prevT < corner1T && stepT >= corner1T)
            : (prevT > corner1T && stepT <= corner1T);
          if (crossingCorner1) {
            crossedCorner1 = true;
            effectiveTargetDist += skipDistGraph;
          }
        }

        // Corner 2 crossing check
        if (corner2IsConcave && !crossedCorner2) {
          bool crossingCorner2 = (searchDir > 0.0)
            ? (prevT < corner2T && stepT >= corner2T)
            : (prevT > corner2T && stepT <= corner2T);
          if (crossingCorner2) {
            crossedCorner2 = true;
            effectiveTargetDist += skipDistGraph;
          }
        }`:"",`

        // Compute offset position at this t
        vec2 stepPos = queryPathPosition(pathId, stepT, source, target);
        vec2 stepNormal = queryPathNormal(pathId, stepT, source, target);
        vec2 offsetPos = stepPos + stepNormal * perpOffset;

        // Distance along offset path
        float segDist = length(offsetPos - prevOffsetPos);

        `).concat(f?`if (accumDist + segDist >= effectiveTargetDist) {
          // Interpolate within segment to find exact t
          float remaining = effectiveTargetDist - accumDist;
          float segT = remaining / max(segDist, 0.0001);
          foundT = mix(prevT, stepT, segT);
          break;
        }`:`if (accumDist + segDist >= targetOffsetDist) {
          // Interpolate within segment to find exact t
          float remaining = targetOffsetDist - accumDist;
          float segT = remaining / max(segDist, 0.0001);
          foundT = mix(prevT, stepT, segT);
          break;
        }`,`

        accumDist += segDist;
        prevOffsetPos = offsetPos;
        prevT = stepT;
        // Update foundT to last valid position in case loop exhausts without finding target
        foundT = stepT;
      }

      charT = foundT;
    }
  }

  // Get position and tangent at final character position
  vec2 pathPos = queryPathPosition(pathId, charT, source, target);
  vec2 tangent = queryPathTangent(pathId, charT, source, target);

  // Compute perpendicular direction (90 degrees from tangent)
  vec2 perpDir = vec2(-tangent.y, tangent.x);

  // Apply perpendicular offset to path position
  vec2 offsetPathPos = pathPos + perpDir * perpOffset;

  // -------------------------------------------------------------------------
  // Step 8: Build character quad
  // -------------------------------------------------------------------------
  // Character size in screen pixels
  vec2 charSizePixels = charSize * fontScale;

  // Character offset from origin to the atlas region's top-left corner.
  // bearingX/bearingY already include the SDF buffer.
  vec2 charOffsetPixels = charOffset * fontScale;

  // The character's local X offset from pathPos (which is at character center)
  float charLocalX = -charAdvance * 0.5 * fontScale;

  // Build quad position:
  // - Start at character origin (charLocalX on X axis, 0 on Y axis = baseline)
  // - Add bearing offset to get to atlas region corner
  // - Add quad corner * size to get vertex position
  vec2 quadPos;
  quadPos.x = charLocalX + charOffsetPixels.x + a_quadCorner.x * charSizePixels.x;
  // charOffset.y = -bearingY (negated), so -charOffsetPixels.y = bearingY * fontScale
  // (distance from baseline to atlas region top, positive = upward)
  // Quad corner (0,0) = bottom-left, (1,1) = top-right
  quadPos.y = -charOffsetPixels.y - charSizePixels.y * (1.0 - a_quadCorner.y);

  // Center vertically on the path by offsetting by half the visual text height
  // VERTICAL_CENTER_RATIO is the distance from baseline to visual center as a ratio of atlas font size
  float verticalCenterOffset = VERTICAL_CENTER_RATIO * ATLAS_FONT_SIZE * fontScale;
  quadPos.y -= verticalCenterOffset;

  // -------------------------------------------------------------------------
  // Step 9: Rotate quad to align with tangent
  // -------------------------------------------------------------------------
  // Rotation matrix from the reading direction
  // readingDir = (cos(angle), sin(angle)), so we can build rotation directly
  vec2 readingDir = tangent * readingSign;
  mat2 rotation = mat2(readingDir.x, readingDir.y, -readingDir.y, readingDir.x);

  // Convert pixel offset to WebGL units for rotation
  `).concat(h?"vec2 quadPosWebGL = quadPos * u_correctionRatio / u_sizeRatio; // Scaled mode":"vec2 quadPosWebGL = quadPos * pixelToGraph; // Fixed mode: use pixelToGraph for zoom-independent size",`

  // Rotate around character center on path
  vec2 rotatedOffset = rotation * quadPosWebGL;

  // Final position in graph space (using offset path position for above/below modes)
  vec2 worldPos = offsetPathPos + rotatedOffset;

  // -------------------------------------------------------------------------
  // Step 10: Transform to clip space
  // -------------------------------------------------------------------------
  vec3 clipPos = u_matrix * vec3(worldPos, 1.0);
  gl_Position = vec4(clipPos.xy, 0.0, 1.0);

  // -------------------------------------------------------------------------
  // Step 11: Texture coordinates
  // -------------------------------------------------------------------------
  // Flip Y for texture coordinates (texture Y goes down, quad Y goes up)
  vec2 texCorner = vec2(a_quadCorner.x, 1.0 - a_quadCorner.y);
  v_texCoord = (a_texCoords.xy + texCorner * a_texCoords.zw) / u_atlasSize;

  // -------------------------------------------------------------------------
  // Step 12: Pass color, border color, and alpha modifier
  // -------------------------------------------------------------------------
  v_color = a_color;
  v_color.a *= bias;
`).concat(t?`  v_borderColor = a_borderColor;
  v_borderColor.a *= bias;
  v_positionMode = positionMode;`:"",`
  v_alphaModifier = alphaModifier;

  // -------------------------------------------------------------------------
  // Step 13: Compute edge fade for soft truncation
  // -------------------------------------------------------------------------
  // Convert fade width from pixels to WebGL units
  `).concat(h?"float fadeWidthWebGL = FADE_WIDTH_PIXELS * u_correctionRatio / u_sizeRatio;":"float fadeWidthWebGL = FADE_WIDTH_PIXELS * pixelToGraph;",`

  // Compute the arc position of THIS VERTEX (not just character center)
  // The quad extends from charCenter - advance/2 to charCenter + advance/2
  // a_quadCorner.x is 0 for left edge, 1 for right edge
  float vertexLocalOffset = readingSign * (a_quadCorner.x - 0.5) * charAdvanceWebGL;
  float vertexArcOffset = charCenterOffset + vertexLocalOffset;

  // Compute distance from body edges (positive = inside body, negative = outside)
  float halfBody = bodyLength * 0.5;
  float distFromStart = vertexArcOffset + halfBody;  // Distance from body start edge
  float distFromEnd = halfBody - vertexArcOffset;    // Distance from body end edge
  float distFromEdge = min(distFromStart, distFromEnd);

  // Compute fade: 0 = fully visible (deep inside body), 1 = fully faded (at body edge)
  // Fade goes from 0 (at 2*fadeWidth inside) to 1 (at body edge)
  // This ensures text is fully transparent before reaching extremities
  v_edgeFade = 1.0 - smoothstep(0.0, fadeWidthWebGL * 2.0, distFromEdge);
}
`);return v}function kc(){var a=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{},n=a.hasBorder,e=n===void 0?!1:n,t=`#version 300 es
precision highp float;

in vec2 v_texCoord;
in vec4 v_color;
`.concat(e?"in vec4 v_borderColor;":"",`
in float v_edgeFade;  // 0 = fully visible, 1 = fully faded
in float v_alphaModifier;  // 0-1 based on label visibility ratio
in float v_fontScale;  // Ratio of rendered font size to atlas font size
`).concat(e?"in float v_positionMode;  // Position mode (0=over, 1=above, 2=below, 3=auto)":"",`

uniform sampler2D u_atlas;
uniform float u_gamma;
uniform float u_sdfBuffer;
uniform float u_pixelRatio;
`).concat(e?"uniform float u_borderWidth;  // Border width in SDF units (normalized)":"",`

// Fragment output (single target - picking handled via separate pass)
out vec4 fragColor;

void main() {
  #ifdef PICKING_MODE
    // Edge labels are not pickable - discard all fragments in picking mode
    fragColor = vec4(0.0);
    discard;
  #else
  // SDF stores normalized distance: 0.5 = on edge, >0.5 = inside glyph
  float sdfValue = texture(u_atlas, v_texCoord).a;

  // Edge threshold accounting for SDF buffer padding
  float edge = 1.0 - u_sdfBuffer;

  // Scale gamma inversely with font scale so small labels get a wider AA band
  // (smoother) and large labels get a tighter band (sharper).
  float aaWidth = u_gamma / (u_pixelRatio * v_fontScale);

  // Apply edge fade for soft truncation at body boundaries
  // Also apply visibility-based alpha modifier for short edge labels
  float edgeAlpha = (1.0 - v_edgeFade) * v_alphaModifier;

`).concat(e?`  // Fill alpha: fully opaque inside the glyph
  float fillAlpha = smoothstep(edge - aaWidth, edge + aaWidth, sdfValue);

  // Only apply border for "over" position mode (v_positionMode == 0.0)
  // Labels positioned above/below/auto don't overlap the edge line and don't need borders
  if (v_positionMode < 0.5) {
    // Border rendering: compute alpha for both fill and border regions
    // Border extends from (edge - borderWidth) to edge
    float borderEdge = edge - u_borderWidth;

    // Border alpha: opaque in the border region (between borderEdge and edge)
    float borderAlpha = smoothstep(borderEdge - aaWidth, borderEdge + aaWidth, sdfValue);

    // Composite: fill on top of border
    // Border is visible where borderAlpha > 0 but fillAlpha < 1
    vec3 borderColorPremult = v_borderColor.rgb * v_borderColor.a * borderAlpha * edgeAlpha;
    vec3 fillColorPremult = v_color.rgb * v_color.a * fillAlpha * edgeAlpha;

    // Blend fill over border (fill replaces border where fill is opaque)
    float finalBorderAlpha = borderAlpha * (1.0 - fillAlpha);
    vec3 finalColor = fillColorPremult + v_borderColor.rgb * v_borderColor.a * finalBorderAlpha * edgeAlpha;
    float finalAlpha = (v_color.a * fillAlpha + v_borderColor.a * finalBorderAlpha) * edgeAlpha;

    fragColor = vec4(finalColor, finalAlpha);
  } else {
    // No border for above/below/auto positions - simple text rendering
    float finalAlpha = v_color.a * fillAlpha * edgeAlpha;
    fragColor = vec4(v_color.rgb * finalAlpha, finalAlpha);
  }`:`  // Smooth transition from transparent to opaque at glyph edge
  float alpha = smoothstep(edge - aaWidth, edge + aaWidth, sdfValue);

  // Premultiplied alpha output
  float finalAlpha = v_color.a * alpha * edgeAlpha;
  fragColor = vec4(v_color.rgb * finalAlpha, finalAlpha);`,`
  #endif
}
`);return t}function Fc(a){var n=arguments.length>1&&arguments[1]!==void 0?arguments[1]:!1,e=arguments.length>2&&arguments[2]!==void 0?arguments[2]:"fixed",t=["u_matrix","u_sizeRatio","u_correctionRatio","u_pixelRatio","u_cameraAngle","u_sdfBufferPixels","u_resolution","u_atlasSize","u_atlas","u_gamma","u_sdfBuffer","u_nodeDataTexture","u_nodeDataTextureWidth","u_edgeDataTexture","u_edgeDataTextureWidth","u_edgeFrameTexture","u_edgeFrameTextureWidth","u_edgeAttributeTexture","u_edgeAttributeTextureWidth","u_edgeAttributeTexelsPerEdge"];e==="scaled"&&t.push("u_zoomSizeRatio"),n&&t.push("u_borderWidth");var r=M(a),i;try{for(r.s();!(i=r.n()).done;){var o=i.value,s=M(o.uniforms),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;t.includes(u.name)||t.push(u.name)}}catch(d){s.e(d)}finally{s.f()}}}catch(d){r.e(d)}finally{r.f()}return t}function Ic(a){var n=a.hasBorder,e=n===void 0?!1:n,t=a.fontSizeMode,r=t===void 0?"fixed":t;return{vertexShader:Pc(a),fragmentShader:kc({hasBorder:e}),uniforms:Fc(a.paths,e,r)}}var Gc=new Map;function zc(a){switch(a){case"over":return 0;case"above":return 1;case"below":return 2;case"auto":return 3;default:return 0}}function Nc(a,n,e,t){var r=t.color,i=t.margin,o=t.textBorder,s=Oo(t),l=s.paths,u=s.fontSizeMode,d=s.minVisibilityThreshold,c=s.fullVisibilityThreshold,h=s.keepUpright,f=!!o,g=Ic({paths:l,hasBorder:f,fontSizeMode:u,minVisibilityThreshold:d,fullVisibilityThreshold:c,keepUpright:h}),m=function(p){function v(b,y,_){var x;Q(this,v),x=le(this,v,[b,y,_]),A(x,"atlasTexture",null),A(x,"atlasNeedsUpdate",!1),A(x,"refreshTimeout",null),A(x,"labelGlyphCache",new Map),A(x,"edgeAttributeTexture",null);var T=Be();if(x.attributeLayout=Fe([].concat(V(l),[T])),x.attrDescriptors=Aa([].concat(V(l),[T]),x.attributeLayout),x.edgeAttributeTexture=new Ra(b,x.attributeLayout),x.packedAttributeData=new Float32Array(x.attributeLayout.floatsPerItem),x.atlasManager=new pt,x.gamma=.025,x.sdfBuffer=Ue.cutoff,x.atlasTexture=b.createTexture(),!x.atlasTexture)throw new Error("EdgeLabelProgram: failed to create atlas texture");b.bindTexture(b.TEXTURE_2D,x.atlasTexture),b.texParameteri(b.TEXTURE_2D,b.TEXTURE_WRAP_S,b.CLAMP_TO_EDGE),b.texParameteri(b.TEXTURE_2D,b.TEXTURE_WRAP_T,b.CLAMP_TO_EDGE),b.texParameteri(b.TEXTURE_2D,b.TEXTURE_MIN_FILTER,b.LINEAR),b.texParameteri(b.TEXTURE_2D,b.TEXTURE_MAG_FILTER,b.LINEAR),b.bindTexture(b.TEXTURE_2D,null),x.atlasManager.on(pt.ATLAS_UPDATED_EVENT,function(){x.atlasNeedsUpdate=!0,x.refreshTimeout!==null&&clearTimeout(x.refreshTimeout),x.refreshTimeout=setTimeout(function(){x.refreshTimeout=null,x.renderer.refresh()},0)});var R={family:"sans-serif",weight:"normal",style:"normal"};return x.defaultFontKey=x.atlasManager.registerFont(R),x}return ue(v,p),J(v,[{key:"getDefinition",value:function(){var y=WebGL2RenderingContext,_=y.FLOAT,x=y.UNSIGNED_BYTE,T=y.TRIANGLE_STRIP,R=new Set,E=[],S=M(l),w;try{for(S.s();!(w=S.n()).done;){var F=w.value,D=M(F.attributes),P;try{for(D.s();!(P=D.n()).done;){var L=P.value,I=L.name.startsWith("a_")?L.name:"a_".concat(L.name);R.has(I)||(R.add(I),E.push({name:I,size:L.size,type:L.type}))}}catch(z){D.e(z)}finally{D.f()}}}catch(z){S.e(z)}finally{S.f()}return{VERTICES:4,VERTEX_SHADER_SOURCE:g.vertexShader,FRAGMENT_SHADER_SOURCE:g.fragmentShader,METHOD:T,UNIFORMS:g.uniforms,ATTRIBUTES:[{name:"a_edgeIndex",size:1,type:_},{name:"a_edgeAttrIndex",size:1,type:_},{name:"a_baseFontSize",size:1,type:_},{name:"a_charMetrics",size:4,type:_},{name:"a_charDims",size:4,type:_},{name:"a_texCoords",size:4,type:_},{name:"a_labelParams",size:2,type:_},{name:"a_color",size:4,type:x,normalized:!0}].concat(V(f?[{name:"a_borderColor",size:4,type:x,normalized:!0}]:[]),V(E.filter(function(z){return!["a_curvature","curvature"].includes(z.name)}))),CONSTANT_ATTRIBUTES:[{name:"a_quadCorner",size:2,type:_}],CONSTANT_DATA:[[0,0],[1,0],[0,1],[1,1]]}}},{key:"prepareLabelGlyphs",value:function(y,_){if(_.hidden||!_.text){this.labelGlyphCache.delete(y);return}var x=_.text,T=_.fontKey||this.defaultFontKey;this.atlasManager.ensureGlyphs(x,T);var R=[],E=[],S=0,w=M(x),F;try{for(w.s();!(F=w.n()).done;){var D=F.value,P=D.codePointAt(0);if(P===void 0){R.push(void 0),E.push(S);continue}var L=this.atlasManager.getGlyph(P,T);R.push(L),E.push(S),L&&(S+=L.advance)}}catch(I){w.e(I)}finally{w.f()}this.labelGlyphCache.set(y,{glyphs:R,xOffsets:E,totalWidth:S})}},{key:"processCharacter",value:function(y,_,x,T){var R,E,S,w=this.floats,F=this.STRIDE,D=y*F,P=this.labelGlyphCache.get(_.parentKey);if(!P||!P.glyphs[T]){for(var L=0;L<F;L++)w[D+L]=0;return}var I=P.glyphs[T],z=P.xOffsets[T],G=v.labelColor,k=G&&ee(G)==="object"&&"color"in G&&G.color?G.color:_.color,C=Pe(k),N=D;w[N++]=_.edgeIndex,w[N++]=(R=(E=this.edgeAttributeTexture)===null||E===void 0?void 0:E.getIndex(_.parentKey))!==null&&R!==void 0?R:0,w[N++]=_.size,w[N++]=z,w[N++]=I.advance,w[N++]=P.totalWidth,w[N++]=zc(_.position),w[N++]=I.atlasWidth,w[N++]=I.atlasHeight,w[N++]=I.bearingX,w[N++]=-I.bearingY,w[N++]=I.atlasX,w[N++]=I.atlasY,w[N++]=I.atlasWidth,w[N++]=I.atlasHeight;var $=(S=v.labelMargin)!==null&&S!==void 0?S:_.margin;if(w[N++]=$,w[N++]=0,w[N++]=C,f&&o){var H;typeof o.color=="string"?H=o.color:H=o.color.color||"#ffffff",w[N++]=Pe(H)}var Z=new Set,X=M(l),K;try{for(X.s();!(K=X.n()).done;){var Ie=K.value,Te=M(Ie.attributes),$e;try{for(Te.s();!($e=Te.n()).done;){var Rt=$e.value,en=Rt.name.startsWith("a_")?Rt.name.slice(2):Rt.name;if(en!=="curvature"&&!Z.has(en)){Z.add(en);for(var tn=0;tn<Rt.size;tn++)w[N++]=0}}}catch(nn){Te.e(nn)}finally{Te.f()}}}catch(nn){X.e(nn)}finally{X.f()}}},{key:"processEdgeLabel",value:function(y,_,x){if(this.prepareLabelGlyphs(y,x),this.edgeAttributeTexture&&!x.hidden&&x.text){this.edgeAttributeTexture.allocate(y);var T=this.packedAttributeData;Da(this.attrDescriptors,x.edgeAttributes,T,"",Gc,0),this.edgeAttributeTexture.updateAllAttributes(y,T)}return ve(v,"processLabel",this,3)([y,_,x])}},{key:"updateAtlasTexture",value:function(){if(this.atlasNeedsUpdate){var y=this.normalProgram.gl,_=this.atlasManager.getTextures();if(_.length!==0){var x=_[0];y.bindTexture(y.TEXTURE_2D,this.atlasTexture),y.texImage2D(y.TEXTURE_2D,0,y.RGBA,x.width,x.height,0,y.RGBA,y.UNSIGNED_BYTE,x.data),y.bindTexture(y.TEXTURE_2D,null),this.atlasNeedsUpdate=!1}}}},{key:"setUniforms",value:function(y,_){var x=_.gl,T=_.uniformLocations,R=this.atlasManager.getTextures(),E=R.length>0?[R[0].width,R[0].height]:[1,1];if(x.uniformMatrix3fv(T.u_matrix,!1,y.matrix),x.uniform1f(T.u_sizeRatio,y.sizeRatio),x.uniform1f(T.u_correctionRatio,y.correctionRatio),x.uniform1f(T.u_pixelRatio,y.pixelRatio),x.uniform1f(T.u_cameraAngle,y.cameraAngle),x.uniform1f(T.u_sdfBufferPixels,Ue.buffer),x.uniform2f(T.u_resolution,y.width,y.height),x.uniform2f(T.u_atlasSize,E[0],E[1]),x.uniform1f(T.u_gamma,this.gamma),x.uniform1f(T.u_sdfBuffer,this.sdfBuffer),x.activeTexture(x.TEXTURE0),x.bindTexture(x.TEXTURE_2D,this.atlasTexture),x.uniform1i(T.u_atlas,0),T.u_nodeDataTexture!==void 0&&x.uniform1i(T.u_nodeDataTexture,y.nodeDataTextureUnit),T.u_nodeDataTextureWidth!==void 0&&x.uniform1i(T.u_nodeDataTextureWidth,y.nodeDataTextureWidth),T.u_edgeDataTexture!==void 0&&x.uniform1i(T.u_edgeDataTexture,y.edgeDataTextureUnit),T.u_edgeDataTextureWidth!==void 0&&x.uniform1i(T.u_edgeDataTextureWidth,y.edgeDataTextureWidth),T.u_edgeFrameTexture!==void 0&&x.uniform1i(T.u_edgeFrameTexture,y.edgeFrameTextureUnit),T.u_edgeFrameTextureWidth!==void 0&&x.uniform1i(T.u_edgeFrameTextureWidth,y.edgeFrameTextureWidth),f&&o&&T.u_borderWidth!==void 0){var S=o.width/Ue.buffer*this.sdfBuffer;x.uniform1f(T.u_borderWidth,S)}if(this.edgeAttributeTexture&&T.u_edgeAttributeTexture!==void 0&&(this.edgeAttributeTexture.bind(ot),x.uniform1i(T.u_edgeAttributeTexture,ot),x.uniform1i(T.u_edgeAttributeTextureWidth,this.edgeAttributeTexture.getTextureWidth()),x.uniform1i(T.u_edgeAttributeTexelsPerEdge,this.edgeAttributeTexture.getTexelsPerItem())),u==="scaled"&&T.u_zoomSizeRatio!==void 0){var w=this.renderer.getSetting("zoomToSizeRatioFunction"),F=1/w(y.zoomRatio);x.uniform1f(T.u_zoomSizeRatio,F)}}},{key:"renderProgram",value:function(y,_){this.updateAtlasTexture(),this.atlasManager.hasPendingGlyphs()&&(this.atlasManager.flush(),this.updateAtlasTexture()),this.edgeAttributeTexture&&this.edgeAttributeTexture.upload(),ve(v,"renderProgram",this,3)([y,_])}},{key:"registerFont",value:function(y){var _=arguments.length>1&&arguments[1]!==void 0?arguments[1]:"normal",x=arguments.length>2&&arguments[2]!==void 0?arguments[2]:"normal";return this.atlasManager.registerFont({family:y,weight:_,style:x})}},{key:"getAtlasManager",value:function(){return this.atlasManager}},{key:"ensureGlyphsReady",value:function(y,_){var x=_||this.defaultFontKey,T=M(y),R;try{for(T.s();!(R=T.n()).done;){var E=R.value;this.atlasManager.ensureGlyphs(E,x)}}catch(S){T.e(S)}finally{T.f()}this.atlasManager.flush()}},{key:"measureLabelAtlasWidth",value:function(y,_){var x=_||this.defaultFontKey;this.atlasManager.ensureGlyphs(y,x),this.atlasManager.hasPendingGlyphs()&&this.atlasManager.flush();var T=0,R=M(y),E;try{for(R.s();!(E=R.n()).done;){var S=E.value,w=S.codePointAt(0);if(w!==void 0){var F=this.atlasManager.getGlyph(w,x);F&&(T+=F.advance)}}}catch(D){R.e(D)}finally{R.f()}return T}},{key:"measureLabel",value:function(y,_,x){var T=this.measureLabelAtlasWidth(y,x),R=_/Ue.fontSize;return{width:T*R,height:_,textHeight:_}}},{key:"kill",value:function(){var y=this.normalProgram.gl;this.refreshTimeout!==null&&(clearTimeout(this.refreshTimeout),this.refreshTimeout=null),this.atlasTexture&&(y.deleteTexture(this.atlasTexture),this.atlasTexture=null),this.edgeAttributeTexture&&(this.edgeAttributeTexture.kill(),this.edgeAttributeTexture=null),this.atlasManager.destroy(),this.labelGlyphCache.clear(),ve(v,"kill",this,3)([])}}])}(Co);return A(m,"labelColor",r),A(m,"labelMargin",i),new m(a,n,e)}function Mc(){var a=`
// No extremity - always returns positive (outside)
float extremity_none(vec2 uv, float lengthRatio, float widthRatio) {
  return 1.0;
}
`;return{name:"none",glsl:a,length:0,widthFactor:1,margin:0,uniforms:[],attributes:[]}}function Wo(a,n,e,t,r,i,o){var s,l,u=Go(t),d=u.paths,c=u.layers,h=u.defaultHead,f=u.defaultTail,g=[Mc()].concat(V(u.extremities)),m={},p={};d.forEach(function(D,P){return m[D.name]=P}),g.forEach(function(D,P){return p[D.name]=P});var v=(s=p[h])!==null&&s!==void 0?s:0,b=(l=p[f])!==null&&l!==void 0?l:0,y=null,_=Fe([].concat(V(d),V(c))),x=function(D){function P(L,I,z){var G;Q(this,P),y||(y=po({paths:d,extremities:g,layers:c,antialias:r})),G=le(this,P,[L,I,z]),A(G,"layerLifecycles",new Map),A(G,"needsShaderRegeneration",!1),A(G,"edgeAttributeTexture",null),A(G,"layout",_),A(G,"attrDescriptors",[]),A(G,"lifecycleIndexOffset",d.length),G._pickingBuffer=I,G.edgeAttributeTexture=new Ra(L,G.layout),G.packedAttributeData=new Float32Array(G.layout.floatsPerItem),c.forEach(function(C,N){if(C.lifecycle){var $={gl:L,renderer:{refresh:function(){return z.refresh()}},getUniformLocation:function(Z){return L.getUniformLocation(G.normalProgram.program,Z)},requestShaderRegeneration:function(){G.needsShaderRegeneration=!0},requestRefresh:function(){z.refresh()}};G.layerLifecycles.set(N,C.lifecycle($))}}),G.layerLifecycles.forEach(function(C){var N;return(N=C.init)===null||N===void 0?void 0:N.call(C)});var k=new Map;return G.layerLifecycles.forEach(function(C,N){C.getAttributeData&&k.set(d.length+N,C)}),G.attrDescriptors=Aa([].concat(V(d),V(c)),G.layout,k),G}return ue(P,D),J(P,[{key:"getAttributeTexture",value:function(){return this.edgeAttributeTexture}},{key:"resolveEdgeIds",value:function(I,z,G){var k=I,C=0,N=v,$=b,H=z?k.selfLoopPath:G&&k.parallelPath?k.parallelPath:k.path;H&&m[H]!==void 0&&(C=m[H]),k.head&&k.head!=="none"&&p[k.head]!==void 0&&(N=p[k.head]),k.tail&&k.tail!=="none"&&p[k.tail]!==void 0&&($=p[k.tail]);var Z=g[N],X=g[$];return{pathId:C,headId:N,tailId:$,headLengthRatio:Ne(Z.length)?0:Z.length,tailLengthRatio:Ne(X.length)?0:X.length}}},{key:"getDefinition",value:function(){var I=WebGL2RenderingContext,z=I.TRIANGLE_STRIP,G=z,k=y;return{VERTICES:k.verticesPerEdge,VERTEX_SHADER_SOURCE:k.vertexShader,FRAGMENT_SHADER_SOURCE:k.fragmentShader,METHOD:G,UNIFORMS:k.uniforms,ATTRIBUTES:k.attributes,CONSTANT_ATTRIBUTES:k.constantAttributes,CONSTANT_DATA:k.constantData}}},{key:"maybeRegenerateShaders",value:function(){var I=this;if(this.needsShaderRegeneration){this.needsShaderRegeneration=!1;var z=c.map(function(Z,X){var K=I.layerLifecycles.get(X);return K!=null&&K.regenerate?K.regenerate():Z});y=po({paths:d,extremities:g,layers:z,antialias:this.renderer.getSetting("antialiasEdges")});var G=this.normalProgram.gl,k=this.normalProgram,C=k.program,N=k.buffer,$=k.vertexShader,H=k.fragmentShader;G.deleteProgram(C),G.deleteBuffer(N),G.deleteShader($),G.deleteShader(H),this.normalProgram=this.getProgramInfo("normal",G,y.vertexShader,y.fragmentShader,this._pickingBuffer)}}},{key:"process",value:function(I,z,G,k,C,N){var $=z*this.STRIDE;if(C.visibility==="hidden"||G.visibility==="hidden"||k.visibility==="hidden"){for(var H=$+this.STRIDE;$<H;$++)this.floats[$]=0;this.floats[z*this.STRIDE]=Do;return}this.processVisibleItem(It(I),$,G,k,C,N)}},{key:"processVisibleItem",value:function(I,z,G,k,C,N){var $,H=this.floats,Z=this.ints;H[z++]=N,H[z++]=Pe(C.color),Z[z++]=I,H[z++]=($=C.opacity)!==null&&$!==void 0?$:1;var X=this.packedAttributeData;Da(this.attrDescriptors,C,X,C.color,this.layerLifecycles,this.lifecycleIndexOffset),this.edgeAttributeTexture.updateAllAttributesAtRow(N,X)}},{key:"setUniforms",value:function(I,z){var G=this,k=z.gl,C=z.uniformLocations;C.u_matrix&&k.uniformMatrix3fv(C.u_matrix,!1,I.matrix),C.u_sizeRatio&&k.uniform1f(C.u_sizeRatio,I.sizeRatio),C.u_correctionRatio&&k.uniform1f(C.u_correctionRatio,I.correctionRatio),C.u_zoomRatio&&k.uniform1f(C.u_zoomRatio,I.zoomRatio),C.u_pixelRatio&&k.uniform1f(C.u_pixelRatio,I.pixelRatio),C.u_cameraAngle&&k.uniform1f(C.u_cameraAngle,I.cameraAngle),C.u_feather&&k.uniform1f(C.u_feather,I.antiAliasingFeather),C.u_minEdgeThickness&&k.uniform1f(C.u_minEdgeThickness,I.minEdgeThickness),C.u_pickingPadding&&k.uniform1f(C.u_pickingPadding,I.edgePickingPadding),C.u_nodeDataTexture&&k.uniform1i(C.u_nodeDataTexture,I.nodeDataTextureUnit),C.u_nodeDataTextureWidth&&k.uniform1i(C.u_nodeDataTextureWidth,I.nodeDataTextureWidth),C.u_edgeDataTexture&&k.uniform1i(C.u_edgeDataTexture,I.edgeDataTextureUnit),C.u_edgeDataTextureWidth&&k.uniform1i(C.u_edgeDataTextureWidth,I.edgeDataTextureWidth),C.u_edgeFrameTexture&&k.uniform1i(C.u_edgeFrameTexture,I.edgeFrameTextureUnit),C.u_edgeFrameTextureWidth&&k.uniform1i(C.u_edgeFrameTextureWidth,I.edgeFrameTextureWidth),this.edgeAttributeTexture&&this.layout.floatsPerItem>0&&(this.edgeAttributeTexture.bind(ot),C.u_edgeAttributeTexture&&k.uniform1i(C.u_edgeAttributeTexture,ot),C.u_edgeAttributeTextureWidth&&k.uniform1i(C.u_edgeAttributeTextureWidth,this.edgeAttributeTexture.getTextureWidth()),C.u_edgeAttributeTexelsPerEdge&&k.uniform1i(C.u_edgeAttributeTexelsPerEdge,this.edgeAttributeTexture.getTexelsPerItem()));var N=new Set;d.forEach(function($){$.uniforms.forEach(function(H){N.has(H.name)||(N.add(H.name),G.setTypedUniform(H,z))})}),g.forEach(function($){$.uniforms.forEach(function(H){N.has(H.name)||(N.add(H.name),G.setTypedUniform(H,z))})}),c.forEach(function($){$.uniforms.forEach(function(H){N.has(H.name)||(N.add(H.name),G.setTypedUniform(H,z))})})}},{key:"render",value:function(I,z,G){this.maybeRegenerateShaders(),ve(P,"render",this,3)([I,z,G])}},{key:"renderProgram",value:function(I,z){this.layerLifecycles.forEach(function(G){var k;return(k=G.beforeRender)===null||k===void 0?void 0:k.call(G)}),ve(P,"renderProgram",this,3)([I,z])}},{key:"uploadAttributeTexture",value:function(){this.edgeAttributeTexture&&this.layout.floatsPerItem>0&&this.edgeAttributeTexture.upload()}},{key:"kill",value:function(){this.layerLifecycles.forEach(function(I){var z;return(z=I.kill)===null||z===void 0?void 0:z.call(I)}),this.edgeAttributeTexture&&(this.edgeAttributeTexture.kill(),this.edgeAttributeTexture=null),ve(P,"kill",this,3)([])}}])}(bt),T=g[v],R=g[b],E=O({paths:d,headLengthRatio:Ne(T.length)?0:T.length,tailLengthRatio:Ne(R.length)?0:R.length},t.label),S=Oo(E),w=function(){return{labelProgram:Nc(a,null,e,E),labelBackgroundProgram:wc(a,n,e,{shaderConfig:S})}},F=new yc(a,{paths:d,extremities:g,layers:c,nodeShapes:i,nodeLayers:o});return{edgeProgram:new x(a,null,e),createLabelPrograms:w,framePass:F}}function Oc(a){return ee(a)==="object"&&"uniforms"in a&&Array.isArray(a.uniforms)}function Wc(a){return ee(a)==="object"&&"uniforms"in a&&"attributes"in a&&"glsl"in a}function Bc(a){return ee(a)==="object"&&"uniforms"in a&&"attributes"in a&&"segments"in a}function Uc(a){return ee(a)==="object"&&"uniforms"in a&&"attributes"in a&&"length"in a}function Hc(a){return ee(a)==="object"&&"uniforms"in a&&"attributes"in a&&"glsl"in a}function $c(a){return ee(a)==="object"&&"glsl"in a&&"name"in a&&!("uniforms"in a)}function Vc(a){return ee(a)==="object"&&"glsl"in a&&"name"in a&&!("uniforms"in a)}function qc(a){return ee(a)==="object"&&"glsl"in a&&"name"in a&&!("uniforms"in a)}function Xc(a){if(Oc(a))return a;if($c(a))return{name:a.name,glsl:a.glsl,inradiusFactor:a.inradiusFactor,uniforms:[]};throw new Error("Invalid node shape specification: ".concat(JSON.stringify(a)))}function jc(a){if(Wc(a))return a;if(Hi(a))return{name:a.name,glsl:a.glsl,uniforms:[],attributes:[]};throw new Error("Invalid node layer specification: ".concat(JSON.stringify(a)))}function Yc(a){if(Bc(a))return a;if(Vc(a))return{name:a.name,glsl:a.glsl,segments:a.segments,uniforms:[],attributes:[]};throw new Error("Invalid edge path specification: ".concat(JSON.stringify(a)))}function Kc(a){if(Hc(a))return a;if($i(a))return{name:a.name,glsl:a.glsl,uniforms:[],attributes:[]};throw new Error("Invalid edge layer specification: ".concat(JSON.stringify(a)))}function Zc(a){if(Uc(a))return a;if(qc(a))return{name:a.name,glsl:a.glsl,length:a.length,widthFactor:a.widthFactor,margin:0,uniforms:[],attributes:[]};throw new Error("Invalid edge extremity specification: ".concat(JSON.stringify(a)))}function Bo(a){var n,e,t=(n=a?.shapes)!==null&&n!==void 0?n:vn.shapes,r=(e=a?.layers)!==null&&e!==void 0?e:vn.layers,i=t.map(Xc),o=r.map(jc);if(i.length===0)throw new Error("At least one node shape must be specified.");if(o.length===0)throw new Error("At least one node layer must be specified.");return{shapes:i,layers:o}}function Qc(a){var n,e,t,r=(n=a?.paths)!==null&&n!==void 0?n:Gt.paths,i=(e=a?.extremities)!==null&&e!==void 0?e:Gt.extremities,o=(t=a?.layers)!==null&&t!==void 0?t:Gt.layers,s=r.map(Yc),l=i.map(Zc).filter(function(d){return d!==null}),u=o.map(Kc);if(s.length===0)throw new Error("At least one edge path must be specified.");if(u.length===0)throw new Error("At least one edge layer must be specified.");return{paths:s,extremities:l,layers:u}}function Uo(a,n){var e={},t=M(a),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;i.variables&&Object.assign(e,i.variables)}}catch(o){t.e(o)}finally{t.f()}return Object.assign(e,n||{}),e}function Ho(a,n,e,t,r){var i=Bo(t),o=i.shapes,s=i.layers,l=Uo(o,t?.variables),u=ko(a,n,e,{shapes:o,layers:s,label:t?.label,backdrop:t?.backdrop,labelAttachments:t?.labelAttachments},r);return O(O({},u),{},{variables:l})}function $o(a,n,e,t,r,i){var o=Qc(t),s=o.paths,l=o.extremities,u=o.layers,d=Bo(i),c=d.shapes,h=d.layers,f=Uo(s,t?.variables),g=Wo(a,n,e,{paths:s,extremities:l,layers:u,defaultHead:t?.defaultHead,defaultTail:t?.defaultTail,label:t?.label},r,c,h);return O(O({},g),{},{variables:f,paths:s})}var Jc=2;function Vo(a,n,e){var t=arguments.length>3&&arguments[3]!==void 0?arguments[3]:Jc,r=n.canvas,i=r.width,o=r.height,s=e.x,l=e.y,u=e.rowHeight,d=e.maxRowWidth,c={},h=[],f=M(a),g;try{for(f.s();!(g=f.n()).done;){var m=g.value,p=m.width+t,v=m.height+t;if(p>i||v>o||s+p>i&&l+u+v>o){h.push(m);continue}s+p>i&&(d=Math.max(d,s),s=0,l+=u,u=v),m.draw(n,s,l),c[m.key]={x:s,y:l,width:m.width,height:m.height},s+=p,u=Math.max(u,v)}}catch(b){f.e(b)}finally{f.f()}return d=Math.max(d,s),{atlas:c,cursor:{x:s,y:l,rowHeight:u,maxRowWidth:d},remaining:h}}function Ee(a,n,e,t){var r=Object.defineProperty;try{r({},"",{})}catch{r=0}Ee=function(i,o,s,l){function u(d,c){Ee(i,d,function(h){return this._invoke(d,c,h)})}o?r?r(i,o,{value:s,enumerable:!l,configurable:!l,writable:!l}):i[o]=s:(u("next",0),u("throw",1),u("return",2))},Ee(a,n,e,t)}function Re(){var a,n,e=typeof Symbol=="function"?Symbol:{},t=e.iterator||"@@iterator",r=e.toStringTag||"@@toStringTag";function i(f,g,m,p){var v=g&&g.prototype instanceof s?g:s,b=Object.create(v.prototype);return Ee(b,"_invoke",function(y,_,x){var T,R,E,S=0,w=x||[],F=!1,D={p:0,n:0,v:a,a:P,f:P.bind(a,4),d:function(L,I){return T=L,R=0,E=a,D.n=I,o}};function P(L,I){for(R=L,E=I,n=0;!F&&S&&!z&&n<w.length;n++){var z,G=w[n],k=D.p,C=G[2];L>3?(z=C===I)&&(E=G[(R=G[4])?5:(R=3,3)],G[4]=G[5]=a):G[0]<=k&&((z=L<2&&k<G[1])?(R=0,D.v=I,D.n=G[1]):k<C&&(z=L<3||G[0]>I||I>C)&&(G[4]=L,G[5]=I,D.n=C,R=0))}if(z||L>1)return o;throw F=!0,I}return function(L,I,z){if(S>1)throw TypeError("Generator is already running");for(F&&I===1&&P(I,z),R=I,E=z;(n=R<2?a:E)||!F;){T||(R?R<3?(R>1&&(D.n=-1),P(R,E)):D.n=E:D.v=E);try{if(S=2,T){if(R||(L="next"),n=T[L]){if(!(n=n.call(T,E)))throw TypeError("iterator result is not an object");if(!n.done)return n;E=n.value,R<2&&(R=0)}else R===1&&(n=T.return)&&n.call(T),R<2&&(E=TypeError("The iterator does not provide a '"+L+"' method"),R=1);T=a}else if((n=(F=D.n<0)?E:y.call(_,D))!==o)break}catch(G){T=a,R=1,E=G}finally{S=1}}return{value:n,done:F}}}(f,m,p),!0),b}var o={};function s(){}function l(){}function u(){}n=Object.getPrototypeOf;var d=[][t]?n(n([][t]())):(Ee(n={},t,function(){return this}),n),c=u.prototype=s.prototype=Object.create(d);function h(f){return Object.setPrototypeOf?Object.setPrototypeOf(f,u):(f.__proto__=u,Ee(f,r,"GeneratorFunction")),f.prototype=Object.create(c),f}return l.prototype=u,Ee(c,"constructor",u),Ee(u,"constructor",l),l.displayName="GeneratorFunction",Ee(u,r,"GeneratorFunction"),Ee(c),Ee(c,r,"Generator"),Ee(c,t,function(){return this}),Ee(c,"toString",function(){return"[object Generator]"}),(Re=function(){return{w:i,m:h}})()}function qo(a,n,e,t,r,i,o){try{var s=a[i](o),l=s.value}catch(u){return void e(u)}s.done?n(l):Promise.resolve(l).then(t,r)}function qt(a){return function(){var n=this,e=arguments;return new Promise(function(t,r){var i=a.apply(n,e);function o(l){qo(i,t,r,o,s,"next",l)}function s(l){qo(i,t,r,o,s,"throw",l)}o(void 0)})}}var La=new Map,Xo=!1;function eh(a){return new Promise(function(n,e){var t=new FileReader;t.onload=function(){return n(t.result)},t.onerror=e,t.readAsDataURL(a)})}function th(a){if(!La.has(a)){var n=fetch(a).then(function(e){return e.blob()}).then(eh).catch(function(){return La.delete(a),null});La.set(a,n)}return La.get(a)}function nh(a){return Tr.apply(this,arguments)}function Tr(){return Tr=qt(Re().m(function a(n){var e,t,r;return Re().w(function(i){for(;;)switch(i.n){case 0:return e=document.createElement("div"),e.innerHTML=n,t=Array.from(e.querySelectorAll("img[src]")),r=t.filter(function(o){return!o.getAttribute("src").startsWith("data:")}),i.n=1,Promise.all(r.map(function(){var o=qt(Re().m(function s(l){var u;return Re().w(function(d){for(;;)switch(d.n){case 0:return d.n=1,th(l.getAttribute("src"));case 1:u=d.v,u&&l.setAttribute("src",u);case 2:return d.a(2)}},s)}));return function(s){return o.apply(this,arguments)}}()));case 1:return i.a(2,e.innerHTML)}},a)})),Tr.apply(this,arguments)}function jo(a){return Sr.apply(this,arguments)}function Sr(){return Sr=qt(Re().m(function a(n){var e,t,r,i,o,s,l,u,d,c,h,f,g,m=arguments;return Re().w(function(p){for(;;)switch(p.n){case 0:if(e=m.length>1&&m[1]!==void 0?m[1]:1,t=n instanceof SVGElement?new XMLSerializer().serializeToString(n):n,r=new DOMParser,i=r.parseFromString(t,"image/svg+xml"),o=i.querySelector("svg"),o){p.n=1;break}return p.a(2,null);case 1:if(s=parseFloat(o.getAttribute("width")||""),l=parseFloat(o.getAttribute("height")||""),(!(s>0)||!(l>0))&&(u=o.getAttribute("viewBox"),u&&(d=u.trim().split(/[\s,]+/),s=parseFloat(d[2]),l=parseFloat(d[3]))),!(!(s>0)||!(l>0))){p.n=2;break}return console.warn("Sigma: SVG label attachment has no parseable dimensions \u2014 skipped."),p.a(2,null);case 2:return c=Math.ceil(s*e),h=Math.ceil(l*e),f=new Blob([t],{type:"image/svg+xml"}),g=URL.createObjectURL(f),p.a(2,new Promise(function(v){var b=new Image;b.onload=function(){var y=document.createElement("canvas");y.width=c,y.height=h,y.getContext("2d").drawImage(b,0,0,c,h),URL.revokeObjectURL(g);try{y.getContext("2d").getImageData(0,0,1,1)}catch(_){if(_ instanceof DOMException&&_.name==="SecurityError"){Xo||(Xo=!0,console.warn('Sigma: A label attachment was skipped because the rendered canvas is tainted. SVG with <foreignObject> (used by the "html" attachment type) is blocked in Chromium and Safari. Use type: "canvas" with Canvas 2D rendering instead.')),v(null);return}throw _}v(y)},b.onerror=function(){URL.revokeObjectURL(g),v(null)},b.src=g}))}},a)})),Sr.apply(this,arguments)}function ah(a,n){var e=document.createElement("div");e.style.cssText="position:fixed;left:-99999px;top:0;visibility:hidden;width:max-content;height:max-content",e.innerHTML=(n?"<style>".concat(n,"</style>"):"")+a,document.body.appendChild(e);var t=e.getBoundingClientRect(),r=t.width,i=t.height;return document.body.removeChild(e),{width:Math.ceil(r),height:Math.ceil(i)}}function rh(a,n,e,t){return Er.apply(this,arguments)}function Er(){return Er=qt(Re().m(function a(n,e,t,r){var i,o,s,l,u,d,c,h,f=arguments;return Re().w(function(g){for(;;)switch(g.n){case 0:return i=f.length>4&&f[4]!==void 0?f[4]:1,o=n instanceof HTMLElement?n.outerHTML:n,g.n=1,nh(o);case 1:return s=g.v,(t==null||r==null)&&(l=ah(s,e),t=t??l.width,r=r??l.height),u=Math.ceil(t*i),d=Math.ceil(r*i),c=e?"<style>".concat(e,"</style>"):"",h='<svg xmlns="http://www.w3.org/2000/svg" '+'width="'.concat(u,'" height="').concat(d,'" viewBox="0 0 ').concat(t," ").concat(r,'">')+'<foreignObject width="'.concat(t,'" height="').concat(r,'">')+'<body xmlns="http://www.w3.org/1999/xhtml" style="margin:0;padding:0">'.concat(c).concat(s,"</body>")+"</foreignObject></svg>",g.a(2,jo(h,1))}},a)})),Er.apply(this,arguments)}function ih(a){return Rr.apply(this,arguments)}function Rr(){return Rr=qt(Re().m(function a(n){var e,t=arguments,r;return Re().w(function(i){for(;;)switch(i.n){case 0:e=t.length>1&&t[1]!==void 0?t[1]:1,r=n.type,i.n=r==="canvas"?1:r==="svg"?2:r==="html"?3:4;break;case 1:return i.a(2,n.canvas);case 2:return i.a(2,jo(n.svg,e));case 3:return i.a(2,rh(n.html,n.css,n.width,n.height,e));case 4:return i.a(2)}},a)})),Rr.apply(this,arguments)}var Vt=2048,Yo=function(){function a(n,e,t){Q(this,a),A(this,"cache",new Map),A(this,"pending",new Set),A(this,"atlas",{}),A(this,"glTexture",null),A(this,"dirty",!0),this.gl=n,this.renderers=e,this.scheduleRender=t,this.packCanvas=document.createElement("canvas"),this.packCanvas.width=Vt,this.packCanvas.height=Vt,this.packCtx=this.packCanvas.getContext("2d")}return J(a,[{key:"renderAttachment",value:function(e,t,r){var i=this,o="".concat(e,":").concat(t);if(!(this.cache.has(o)||this.pending.has(o))){var s=this.renderers[t];if(s){var l=s(r);if(l){this.pending.add(o);var u=r.pixelRatio;Promise.resolve(l).then(function(){var d=qt(Re().m(function c(h){var f;return Re().w(function(g){for(;;)switch(g.n){case 0:if(i.pending.has(o)){g.n=1;break}return g.a(2);case 1:if(i.pending.delete(o),h){g.n=2;break}return g.a(2);case 2:return g.n=3,ih(h,u);case 3:if(f=g.v,!(!f||f.width===0||f.height===0)){g.n=4;break}return g.a(2);case 4:i.cache.set(o,{image:f,width:f.width,height:f.height}),i.dirty=!0,i.scheduleRender();case 5:return g.a(2)}},c)}));return function(c){return d.apply(this,arguments)}}())}}}}},{key:"regenerateAtlas",value:function(){if(this.dirty){this.dirty=!1;var e=[];if(this.cache.forEach(function(u,d){e.push({key:d,width:u.width,height:u.height,draw:function(h,f,g){h.drawImage(u.image,f,g)}})}),e.length===0){this.atlas={},this.deleteGLTexture();return}var t={x:0,y:0,rowHeight:0,maxRowWidth:0};this.packCtx.clearRect(0,0,Vt,Vt);var r=Vo(e,this.packCtx,t),i=r.atlas,o=r.remaining;this.atlas=i,o.length>0&&console.warn("Sigma: ".concat(o.length," label attachment(s) could not fit in the ").concat(Vt,"x").concat(Vt," atlas and will not be rendered.")),this.deleteGLTexture();var s=this.gl,l=s.createTexture();s.activeTexture(s.TEXTURE0+Rn),s.bindTexture(s.TEXTURE_2D,l),s.pixelStorei(s.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!0),s.texImage2D(s.TEXTURE_2D,0,s.RGBA,s.RGBA,s.UNSIGNED_BYTE,this.packCanvas),s.pixelStorei(s.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!1),s.texParameteri(s.TEXTURE_2D,s.TEXTURE_MIN_FILTER,s.LINEAR),s.texParameteri(s.TEXTURE_2D,s.TEXTURE_MAG_FILTER,s.LINEAR),s.texParameteri(s.TEXTURE_2D,s.TEXTURE_WRAP_S,s.CLAMP_TO_EDGE),s.texParameteri(s.TEXTURE_2D,s.TEXTURE_WRAP_T,s.CLAMP_TO_EDGE),this.glTexture=l}}},{key:"bindTexture",value:function(e){if(this.glTexture){var t=this.gl;t.activeTexture(t.TEXTURE0+e),t.bindTexture(t.TEXTURE_2D,this.glTexture)}}},{key:"getEntry",value:function(e,t){var r="".concat(e,":").concat(t);return this.atlas[r]||null}},{key:"invalidateNode",value:function(e){var t="".concat(e,":"),r=M(this.cache.keys()),i;try{for(r.s();!(i=r.n()).done;){var o=i.value;o.startsWith(t)&&(this.cache.delete(o),this.dirty=!0)}}catch(d){r.e(d)}finally{r.f()}var s=M(this.pending),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;u.startsWith(t)&&this.pending.delete(u)}}catch(d){s.e(d)}finally{s.f()}}},{key:"restore",value:function(){this.glTexture=null,this.dirty=!0}},{key:"clear",value:function(){this.cache.clear(),this.pending.clear(),this.atlas={},this.dirty=!0,this.deleteGLTexture()}},{key:"kill",value:function(){this.clear(),this.packCanvas=null,this.packCtx=null,this.gl=null}},{key:"deleteGLTexture",value:function(){this.glTexture&&(this.gl.deleteTexture(this.glTexture),this.glTexture=null)}}])}(),Ar=function(){function a(n){Q(this,a),A(this,"buckets",new Map),A(this,"keyDepth",new Map);var e=M(n),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;this.buckets.set(r,new Set)}}catch(i){e.e(i)}finally{e.f()}}return J(a,[{key:"has",value:function(e){return this.keyDepth.has(e)}},{key:"getBucket",value:function(e){return this.buckets.get(e)}},{key:"set",value:function(e,t){var r,i=this.keyDepth.get(e);if(i!==t){var o=this.buckets.get(t);if(!o)throw new Error('Sigma: "'.concat(t,'" is not a declared depth layer'));i!==void 0&&((r=this.buckets.get(i))===null||r===void 0||r.delete(e)),o.add(e),this.keyDepth.set(e,t)}}},{key:"remove",value:function(e){var t=this.keyDepth.get(e);t!==void 0&&(this.buckets.get(t).delete(e),this.keyDepth.delete(e))}},{key:"clearAll",value:function(){var e=M(this.buckets.values()),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;r.clear()}}catch(i){e.e(i)}finally{e.f()}this.keyDepth.clear()}},{key:"getSorted",value:function(e,t){var r=this.buckets.get(e);return!r||r.size===0?[]:V(r).sort(function(i,o){return t(i)-t(o)})}}])}(),Ko=function(a){function n(e,t){return Q(this,n),le(this,n,[e,2,t])}return ue(n,a),J(n,[{key:"updateNode",value:function(t,r,i,o,s,l,u,d){var c=this.indexMap.get(t);if(c===void 0)throw new Error('Node "'.concat(t,'" not allocated in NodeDataTexture'));var h=rt(d),f=te(h,4),g=f[0],m=f[1],p=f[2],v=f[3],b=c*2*4;this.data[b]=r,this.data[b+1]=i,this.data[b+2]=o,this.data[b+3]=s,this.data[b+4]=l,this.data[b+5]=u,this.data[b+6]=g*65536+m*256+p,this.data[b+7]=v/255,this.markDirty(c)}}])}(Ea),oh=1024,sh=1.5,Dr=function(){function a(n,e){var t;if(Q(this,a),A(this,"texture",null),A(this,"framebuffer",null),!n.getExtension("EXT_color_buffer_float"))throw new Error("sigma: EXT_color_buffer_float is required for label/edge placement but is unavailable in this WebGL2 context.");this.gl=n,this.maxTextureSize=n.getParameter(n.MAX_TEXTURE_SIZE),this.channels=e.channels,this.capacity=this.roundUpToPowerOfTwo((t=e.initialCapacity)!==null&&t!==void 0?t:oh);var r=this.computeDimensions(this.capacity);this.textureWidth=r.width,this.textureHeight=r.height,this.create()}return J(a,[{key:"roundUpToPowerOfTwo",value:function(e){return Math.pow(2,Math.ceil(Math.log2(Math.max(1,e))))}},{key:"computeDimensions",value:function(e){var t=Math.min(e,this.maxTextureSize),r=Math.ceil(e/t);return{width:t,height:r}}},{key:"create",value:function(){var e=this.gl,t=this.channels===1?e.R32F:e.RGBA32F,r=this.channels===1?e.RED:e.RGBA;if(this.texture=e.createTexture(),e.activeTexture(e.TEXTURE0),e.bindTexture(e.TEXTURE_2D,this.texture),e.texImage2D(e.TEXTURE_2D,0,t,this.textureWidth,this.textureHeight,0,r,e.FLOAT,null),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MIN_FILTER,e.NEAREST),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MAG_FILTER,e.NEAREST),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_WRAP_S,e.CLAMP_TO_EDGE),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_WRAP_T,e.CLAMP_TO_EDGE),this.framebuffer=e.createFramebuffer(),e.bindFramebuffer(e.FRAMEBUFFER,this.framebuffer),e.framebufferTexture2D(e.FRAMEBUFFER,e.COLOR_ATTACHMENT0,e.TEXTURE_2D,this.texture,0),e.checkFramebufferStatus(e.FRAMEBUFFER)!==e.FRAMEBUFFER_COMPLETE)throw new Error("sigma: float framebuffer for frame-pass placement is incomplete.");e.bindFramebuffer(e.FRAMEBUFFER,null),e.bindTexture(e.TEXTURE_2D,null)}},{key:"ensureCapacity",value:function(e){if(!(e<=this.capacity)){var t=this.gl;this.capacity=this.roundUpToPowerOfTwo(Math.ceil(e*sh));var r=this.computeDimensions(this.capacity);this.textureWidth=r.width,this.textureHeight=r.height,this.texture&&t.deleteTexture(this.texture),this.framebuffer&&t.deleteFramebuffer(this.framebuffer),this.create()}}},{key:"bindAsRenderTarget",value:function(){var e=this.gl;e.bindFramebuffer(e.FRAMEBUFFER,this.framebuffer),e.viewport(0,0,this.textureWidth,this.textureHeight)}},{key:"bind",value:function(e){var t=this.gl;t.activeTexture(t.TEXTURE0+e),t.bindTexture(t.TEXTURE_2D,this.texture)}},{key:"getTexture",value:function(){return this.texture}},{key:"getTextureWidth",value:function(){return this.textureWidth}},{key:"getTextureHeight",value:function(){return this.textureHeight}},{key:"restore",value:function(){this.gl.getExtension("EXT_color_buffer_float"),this.create()}},{key:"kill",value:function(){var e=this.gl;this.texture&&(e.deleteTexture(this.texture),this.texture=null),this.framebuffer&&(e.deleteFramebuffer(this.framebuffer),this.framebuffer=null)}}])}(),Zo=function(a){function n(e,t){return Q(this,n),le(this,n,[e,2,t])}return ue(n,a),J(n,[{key:"updateEdge",value:function(t,r,i,o,s,l){var u=arguments.length>6&&arguments[6]!==void 0?arguments[6]:0,d=arguments.length>7&&arguments[7]!==void 0?arguments[7]:0,c=arguments.length>8&&arguments[8]!==void 0?arguments[8]:0,h=this.indexMap.get(t);if(h===void 0)throw new Error('Edge "'.concat(t,'" not allocated in EdgeDataTexture'));var f=h*this.TEXELS_PER_ITEM*4;this.data[f+0]=r,this.data[f+1]=i,this.data[f+2]=o,this.data[f+3]=0,this.data[f+4]=s,this.data[f+5]=l,this.data[f+6]=u,this.data[f+7]=(d&15)<<4|c&15,this.markDirty(h)}}])}(Ea);var wg=Ve(Dt()),Lg=Ve(sn());function lh(a,n){if(a==null)return{};var e={};for(var t in a)if({}.hasOwnProperty.call(a,t)){if(n.indexOf(t)!==-1)continue;e[t]=a[t]}return e}function Qo(a,n){if(a==null)return{};var e,t,r=lh(a,n);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(a);for(t=0;t<i.length;t++)e=i[t],n.indexOf(e)===-1&&{}.propertyIsEnumerable.call(a,e)&&(r[e]=a[e])}return r}var uh=["factor"],dh=["factor"],Jo=1.5,wr={x:.5,y:.5,angle:0,ratio:1},es=function(a){function n(){var e;Q(this,n);for(var t=arguments.length,r=new Array(t),i=0;i<t;i++)r[i]=arguments[i];return e=le(this,n,[].concat(r)),A(e,"minRatio",null),A(e,"maxRatio",null),A(e,"enabled",!0),A(e,"enabledZooming",!0),A(e,"enabledPanning",!0),A(e,"enabledRotation",!0),A(e,"constrainState",null),A(e,"state",O({},wr)),A(e,"previousState",O({},wr)),A(e,"nextFrame",null),A(e,"currentAnimationFrom",null),A(e,"currentAnimationTo",null),A(e,"animationCallback",null),e}return ue(n,a),J(n,[{key:"x",get:function(){return this.state.x}},{key:"y",get:function(){return this.state.y}},{key:"angle",get:function(){return this.state.angle}},{key:"ratio",get:function(){return this.state.ratio}},{key:"getState",value:function(){return O({},this.state)}},{key:"getPreviousState",value:function(){return O({},this.previousState)}},{key:"getBoundedRatio",value:function(t){var r=t;return typeof this.minRatio=="number"&&(r=Math.max(r,this.minRatio)),typeof this.maxRatio=="number"&&(r=Math.min(r,this.maxRatio)),r}},{key:"validateState",value:function(t){var r=this.getState();return this.enabledPanning&&typeof t.x=="number"&&(r.x=t.x),this.enabledPanning&&typeof t.y=="number"&&(r.y=t.y),this.enabledZooming&&typeof t.ratio=="number"&&(r.ratio=this.getBoundedRatio(t.ratio)),this.enabledRotation&&typeof t.angle=="number"&&(r.angle=t.angle),this.constrainState?this.constrainState(r):r}},{key:"isAnimating",value:function(){return this.nextFrame!==null}},{key:"setState",value:function(t){if(!this.enabled)return this;var r=this.validateState(t);return io(this.state,r)?this:(this.previousState=this.state,this.state=r,this.emit("updated",this.getState()),this)}},{key:"updateState",value:function(t){return this.setState(t(this.getState())),this}},{key:"animate",value:function(t,r){var i=this;return this.enabled?new Promise(function(o){return i.runAnimation(t,O(O({},da),r),o)}):Promise.resolve()}},{key:"cancelAnimation",value:function(){return this.nextFrame!==null&&(cancelAnimationFrame(this.nextFrame),this.nextFrame=null),this.resolveAnimation(),this.emitAnimationEnd(!1),this}},{key:"zoomIn",value:function(){var t=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{},r=t.factor,i=r===void 0?Jo:r,o=Qo(t,uh);return this.animate({ratio:this.ratio/i},o)}},{key:"zoomOut",value:function(){var t=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{},r=t.factor,i=r===void 0?Jo:r,o=Qo(t,dh);return this.animate({ratio:this.ratio*i},o)}},{key:"reset",value:function(t){return this.animate(wr,t)}},{key:"runAnimation",value:function(t,r,i){var o=this,s=zt(r.easing),l=Date.now(),u=this.getState(),d=this.validateState(t),c=function(){if(!o.enabled){o.cancelAnimation();return}var f=r.duration>0?(Date.now()-l)/r.duration:1;if(f>=1){o.nextFrame=null,o.setState(d),o.resolveAnimation(),o.emitAnimationEnd(!0);return}var g=s(f);o.setState({x:u.x+(d.x-u.x)*g,y:u.y+(d.y-u.y)*g,angle:u.angle+(d.angle-u.angle)*g,ratio:u.ratio+(d.ratio-u.ratio)*g}),o.nextFrame=requestAnimationFrame(c)};this.cancelAnimation(),this.currentAnimationFrom=u,this.currentAnimationTo=d,this.animationCallback=i,this.emit("animationStart",{from:u,to:d}),c()}},{key:"resolveAnimation",value:function(){var t=this.animationCallback;this.animationCallback=null,t&&t()}},{key:"emitAnimationEnd",value:function(t){var r=this.currentAnimationFrom,i=this.currentAnimationTo;!r||!i||(this.currentAnimationFrom=null,this.currentAnimationTo=null,this.emit("animationEnd",{from:r,to:i,completed:t}))}}],[{key:"from",value:function(t){var r=new n;return r.setState(t)}}])}(ua);function Ae(a,n){var e=n.getBoundingClientRect();return{x:a.clientX-e.left,y:a.clientY-e.top}}function He(a,n){var e=O(O({},Ae(a,n)),{},{sigmaDefaultPrevented:!1,preventSigmaDefault:function(){e.sigmaDefaultPrevented=!0},original:a});return e}function yt(a){var n="x"in a?a:O(O({},a.touches[0]||a.previousTouches[0]),{},{original:a.original,sigmaDefaultPrevented:a.sigmaDefaultPrevented,preventSigmaDefault:function(){a.sigmaDefaultPrevented=!0,n.sigmaDefaultPrevented=!0}});return n}function ch(a,n){var e=He(a,n);return e.delta=ps(a),e}var hh=2;function ka(a){for(var n=[],e=0,t=Math.min(a.length,hh);e<t;e++)n.push(a[e]);return n}function Dn(a,n,e){var t={touches:ka(a.touches).map(function(r){return Ae(r,e)}),previousTouches:n.map(function(r){return Ae(r,e)}),sigmaDefaultPrevented:!1,preventSigmaDefault:function(){t.sigmaDefaultPrevented=!0},original:a};return t}function ps(a){if(typeof a.deltaY<"u")return a.deltaY*-3/360;if(typeof a.detail<"u")return a.detail/-9;throw new Error("Captor: could not extract delta from event.")}var ms=function(a){function n(e,t){var r;return Q(this,n),r=le(this,n),r.container=e,r.renderer=t,r}return ue(n,a),J(n)}(ua),fh=["doubleClickTimeout","doubleClickZoomingDuration","doubleClickZoomingRatio","dragTimeout","draggedEventsTolerance","enableCameraMouseRotation","gestureTarget","inertiaDuration","inertiaRatio","zoomDuration","zoomingRatio"],gh=fh.reduce(function(a,n){return O(O({},a),{},A({},n,ga[n]))},{});function wn(a){return a instanceof PointerEvent&&a.pointerType==="touch"}var vh=function(a){function n(e,t){var r;return Q(this,n),r=le(this,n,[e,t]),A(r,"enabled",!0),A(r,"draggedEvents",0),A(r,"downStartTime",null),A(r,"lastMouseX",null),A(r,"lastMouseY",null),A(r,"isMouseDown",!1),A(r,"isMoving",!1),A(r,"isPanningStage",!1),A(r,"movingTimeout",null),A(r,"startCameraState",null),A(r,"clicks",0),A(r,"doubleClickTimeout",null),A(r,"isRightMouseDown",!1),A(r,"startRotationAngle",null),A(r,"startCameraAngle",null),A(r,"currentWheelDirection",0),A(r,"lastWheelAnimationId",0),A(r,"settings",gh),r.handleRightClick=r.handleRightClick.bind(r),r.handleDown=r.handleDown.bind(r),r.handleUp=r.handleUp.bind(r),r.handleMove=r.handleMove.bind(r),r.handleWheel=r.handleWheel.bind(r),r.handleLeave=r.handleLeave.bind(r),r.handleEnter=r.handleEnter.bind(r),e.addEventListener("contextmenu",r.handleRightClick,{capture:!1}),e.addEventListener("pointerdown",r.handleDown,{capture:!1}),e.addEventListener("wheel",r.handleWheel,{capture:!1,passive:!1}),e.addEventListener("pointerleave",r.handleLeave,{capture:!1}),e.addEventListener("pointerenter",r.handleEnter,{capture:!1}),document.addEventListener("pointermove",r.handleMove,{capture:!1}),document.addEventListener("pointerup",r.handleUp,{capture:!1}),r}return ue(n,a),J(n,[{key:"kill",value:function(){var t=this.container;t.removeEventListener("contextmenu",this.handleRightClick),t.removeEventListener("pointerdown",this.handleDown),t.removeEventListener("wheel",this.handleWheel),t.removeEventListener("pointerleave",this.handleLeave),t.removeEventListener("pointerenter",this.handleEnter),document.removeEventListener("pointermove",this.handleMove),document.removeEventListener("pointerup",this.handleUp)}},{key:"handleClick",value:function(t){var r=this;if(this.enabled){if(this.clicks++,this.clicks===2)return this.clicks=0,typeof this.doubleClickTimeout=="number"&&(clearTimeout(this.doubleClickTimeout),this.doubleClickTimeout=null),this.handleDoubleClick(t);setTimeout(function(){r.clicks=0,r.doubleClickTimeout=null},this.settings.doubleClickTimeout),this.draggedEvents<this.settings.draggedEventsTolerance&&this.emit("click",He(t,this.container))}}},{key:"handleRightClick",value:function(t){this.enabled&&(this.settings.enableCameraMouseRotation&&t.preventDefault(),this.emit("rightClick",He(t,this.container)))}},{key:"handleDoubleClick",value:function(t){if(this.enabled){t.preventDefault(),t.stopPropagation();var r=He(t,this.container);if(this.emit("doubleClick",r),!r.sigmaDefaultPrevented){var i=this.renderer.getCamera(),o=i.getBoundedRatio(i.getState().ratio/this.settings.doubleClickZoomingRatio);i.animate(this.renderer.getViewportZoomedState(Ae(t,this.container),o),{easing:"quadraticInOut",duration:this.settings.doubleClickZoomingDuration})}}}},{key:"handleDown",value:function(t){if(!(!this.enabled||wn(t))){if(t.button===0){this.startCameraState=this.renderer.getCamera().getState();var r=Ae(t,this.container),i=r.x,o=r.y;this.lastMouseX=i,this.lastMouseY=o,this.draggedEvents=0,this.downStartTime=Date.now(),this.isMouseDown=!0}if(t.button===2&&this.settings.enableCameraMouseRotation){var s=Ae(t,this.container),l=s.x,u=s.y,d=this.container.offsetWidth/2,c=this.container.offsetHeight/2;this.startRotationAngle=Math.atan2(u-c,l-d),this.startCameraAngle=this.renderer.getCamera().getState().angle,this.isRightMouseDown=!0}this.emit("mousedown",He(t,this.container))}}},{key:"handleUp",value:function(t){var r=this;if(!(!this.enabled||wn(t)||!this.isMouseDown&&!this.isRightMouseDown)){if(this.isRightMouseDown){this.isRightMouseDown=!1,this.startRotationAngle=null,this.startCameraAngle=null,this.emit("mouseup",He(t,this.container));return}var i=this.renderer.getCamera();this.isMouseDown=!1,this.isPanningStage&&(this.isPanningStage=!1,this.renderer._setPanning(!1)),typeof this.movingTimeout=="number"&&(clearTimeout(this.movingTimeout),this.movingTimeout=null);var o=Ae(t,this.container),s=o.x,l=o.y,u=i.getState(),d=i.getPreviousState();this.isMoving?i.animate({x:u.x+this.settings.inertiaRatio*(u.x-d.x),y:u.y+this.settings.inertiaRatio*(u.y-d.y)},{duration:this.settings.inertiaDuration,easing:"quadraticOut"}):(this.lastMouseX!==s||this.lastMouseY!==l)&&i.setState({x:u.x,y:u.y}),this.isMoving=!1,setTimeout(function(){var c=r.draggedEvents>0;r.draggedEvents=0;var h=r.renderer.getSetting("hideEdgesOnMove")||r.renderer.getSetting("hideLabelsOnMove");c&&h&&r.renderer.refresh()},0),this.emit("mouseup",He(t,this.container)),(t.target===this.container||t.composedPath()[0]===this.container)&&this.handleClick(t)}}},{key:"handleMove",value:function(t){var r=this;if(!(!this.enabled||wn(t))){var i=He(t,this.container);if(this.emit("mousemovebody",i),(t.target===this.container||t.composedPath()[0]===this.container)&&this.emit("mousemove",i),this.isMouseDown&&this.draggedEvents++,!i.sigmaDefaultPrevented){if(this.isMouseDown){this.isMoving=!0,typeof this.movingTimeout=="number"&&clearTimeout(this.movingTimeout),this.movingTimeout=window.setTimeout(function(){r.movingTimeout=null,r.isMoving=!1},this.settings.dragTimeout);var o=this.renderer.getCamera(),s=Ae(t,this.container),l=s.x,u=s.y,d=this.renderer.viewportToFramedGraph({x:this.lastMouseX,y:this.lastMouseY}),c=this.renderer.viewportToFramedGraph({x:l,y:u}),h=d.x-c.x,f=d.y-c.y,g=o.getState(),m=g.x+h,p=g.y+f;this.isPanningStage||(this.isPanningStage=!0,this.renderer._setPanning(!0)),o.setState({x:m,y:p}),this.lastMouseX=l,this.lastMouseY=u,t.preventDefault(),t.stopPropagation()}if(this.isRightMouseDown){var v=Ae(t,this.container),b=v.x,y=v.y,_=this.container.offsetWidth/2,x=this.container.offsetHeight/2,T=Math.atan2(y-x,b-_),R=T-this.startRotationAngle,E=this.renderer.getCamera();E.setState({angle:this.startCameraAngle+R}),t.preventDefault(),t.stopPropagation()}}}}},{key:"handleLeave",value:function(t){wn(t)||this.emit("mouseleave",He(t,this.container))}},{key:"handleEnter",value:function(t){wn(t)||this.emit("mouseenter",He(t,this.container))}},{key:"handleWheel",value:function(t){var r=this,i=this.renderer.getCamera();if(!(!this.enabled||!i.enabledZooming)){var o=ch(t,this.container);if(this.emit("wheel",o),!o.sigmaDefaultPrevented){var s=this.settings.gestureTarget;if(s!=="page"){if(s==="shared"&&!t.ctrlKey&&!t.metaKey){this.renderer._showGestureHint("wheel");return}var l=ps(t);if(l){t.preventDefault(),t.stopPropagation();var u=i.getState().ratio,d=l>0?1/this.settings.zoomingRatio:this.settings.zoomingRatio,c=i.getBoundedRatio(u*d),h=l>0?1:-1,f=Date.now();if(u!==c&&!(this.currentWheelDirection===h&&this.lastWheelTriggerTime&&f-this.lastWheelTriggerTime<this.settings.zoomDuration/5)){var g=++this.lastWheelAnimationId;i.animate(this.renderer.getViewportZoomedState(Ae(t,this.container),c),{easing:"quadraticOut",duration:this.settings.zoomDuration}).then(function(){r.lastWheelAnimationId===g&&(r.currentWheelDirection=0)}),this.currentWheelDirection=h,this.lastWheelTriggerTime=f}}}}}}},{key:"setSettings",value:function(t){this.settings=t}}])}(ms),ph=["dragTimeout","gestureTarget","inertiaDuration","inertiaRatio","doubleClickTimeout","doubleClickZoomingRatio","doubleClickZoomingDuration","tapMoveTolerance"],mh=ph.reduce(function(a,n){return O(O({},a),{},A({},n,ga[n]))},{}),bh=function(a){function n(e,t){var r;return Q(this,n),r=le(this,n,[e,t]),A(r,"enabled",!0),A(r,"isMoving",!1),A(r,"hasMoved",!1),A(r,"isPanningStage",!1),A(r,"isZoomingStage",!1),A(r,"touchMode",0),A(r,"startTouchesPositions",[]),A(r,"lastTouches",[]),A(r,"lastTap",null),A(r,"settings",mh),r.handleStart=r.handleStart.bind(r),r.handleLeave=r.handleLeave.bind(r),r.handleMove=r.handleMove.bind(r),e.addEventListener("touchstart",r.handleStart,{capture:!1}),e.addEventListener("touchcancel",r.handleLeave,{capture:!1}),document.addEventListener("touchend",r.handleLeave,{capture:!1,passive:!1}),document.addEventListener("touchmove",r.handleMove,{capture:!1,passive:!1}),r}return ue(n,a),J(n,[{key:"kill",value:function(){var t=this.container;t.removeEventListener("touchstart",this.handleStart),t.removeEventListener("touchcancel",this.handleLeave),document.removeEventListener("touchend",this.handleLeave),document.removeEventListener("touchmove",this.handleMove)}},{key:"getDimensions",value:function(){return{width:this.container.offsetWidth,height:this.container.offsetHeight}}},{key:"doesCapture",value:function(t){var r=this.settings.gestureTarget;return r==="graph"?!0:r==="page"?!1:t>=2}},{key:"syncStageFlags",value:function(){var t=this.touchMode===1&&this.hasMoved,r=this.touchMode===2;t!==this.isPanningStage&&(this.isPanningStage=t,this.renderer._setPanning(t)),r!==this.isZoomingStage&&(this.isZoomingStage=r,this.renderer._setZooming(r))}},{key:"handleStart",value:function(t){var r=this;if(this.enabled){var i=ka(t.touches);if(this.touchMode=i.length,this.startCameraState=this.renderer.getCamera().getState(),this.startTouchesPositions=i.map(function(f){return Ae(f,r.container)}),this.touchMode===2){var o=te(this.startTouchesPositions,2),s=o[0],l=s.x,u=s.y,d=o[1],c=d.x,h=d.y;this.startTouchesAngle=Math.atan2(h-u,c-l),this.startTouchesDistance=Math.sqrt(Math.pow(c-l,2)+Math.pow(h-u,2))}this.syncStageFlags(),this.emit("touchdown",Dn(t,this.lastTouches,this.container)),this.lastTouches=i,this.lastTouchesPositions=this.startTouchesPositions,t.cancelable&&(this.doesCapture(t.touches.length)||this.renderer._hasNodeDrag())&&t.preventDefault()}}},{key:"handleLeave",value:function(t){if(!(!this.enabled||!this.startTouchesPositions.length)){switch(t.cancelable&&this.doesCapture(this.touchMode)&&t.preventDefault(),this.movingTimeout&&(this.isMoving=!1,clearTimeout(this.movingTimeout)),this.touchMode){case 2:if(t.touches.length===1){this.handleStart(t);break}case 1:if(this.isMoving){var r=this.renderer.getCamera(),i=r.getState(),o=r.getPreviousState();r.animate({x:i.x+this.settings.inertiaRatio*(i.x-o.x),y:i.y+this.settings.inertiaRatio*(i.y-o.y)},{duration:this.settings.inertiaDuration,easing:"quadraticOut"})}this.hasMoved=!1,this.isMoving=!1,this.touchMode=0;break}if(this.syncStageFlags(),this.emit("touchup",Dn(t,this.lastTouches,this.container)),!t.touches.length){var s=Ae(this.lastTouches[0],this.container),l=this.startTouchesPositions[0],u=Math.pow(s.x-l.x,2)+Math.pow(s.y-l.y,2);if(!t.touches.length&&u<Math.pow(this.settings.tapMoveTolerance,2))if(this.lastTap&&Date.now()-this.lastTap.time<this.settings.doubleClickTimeout){var d=Dn(t,this.lastTouches,this.container);if(this.emit("doubletap",d),this.lastTap=null,!d.sigmaDefaultPrevented&&this.settings.gestureTarget!=="page"){var c=this.renderer.getCamera(),h=c.getBoundedRatio(c.getState().ratio/this.settings.doubleClickZoomingRatio);c.animate(this.renderer.getViewportZoomedState(s,h),{easing:"quadraticInOut",duration:this.settings.doubleClickZoomingDuration})}}else{var f=Dn(t,this.lastTouches,this.container);this.emit("tap",f),this.lastTap={time:Date.now(),position:f.touches[0]||f.previousTouches[0]}}}this.lastTouches=ka(t.touches),this.startTouchesPositions=[]}}},{key:"handleMove",value:function(t){var r=this;if(!(!this.enabled||!this.startTouchesPositions.length)){var i=this.doesCapture(t.touches.length);i&&t.preventDefault();var o=ka(t.touches),s=o.map(function(H){return Ae(H,r.container)}),l=this.lastTouches;this.lastTouches=o,this.lastTouchesPositions=s;var u=Dn(t,l,this.container);if(this.emit("touchmove",u),!u.sigmaDefaultPrevented&&(this.hasMoved||(this.hasMoved=s.some(function(H,Z){var X=r.startTouchesPositions[Z];return X&&(H.x!==X.x||H.y!==X.y)})),!!this.hasMoved)){if(!i){this.settings.gestureTarget==="shared"&&this.renderer._showGestureHint("touch");return}this.isMoving=!0,this.syncStageFlags(),this.movingTimeout&&clearTimeout(this.movingTimeout),this.movingTimeout=window.setTimeout(function(){r.isMoving=!1},this.settings.dragTimeout);var d=this.renderer.getCamera(),c=this.startCameraState,h=this.renderer.getSetting("stagePadding");switch(this.touchMode){case 1:{var f=this.renderer.viewportToFramedGraph((this.startTouchesPositions||[])[0]),g=f.x,m=f.y,p=this.renderer.viewportToFramedGraph(s[0]),v=p.x,b=p.y;d.setState({x:c.x+g-v,y:c.y+m-b});break}case 2:{var y={x:.5,y:.5,angle:0,ratio:1},_=s[0],x=_.x,T=_.y,R=s[1],E=R.x,S=R.y,w=Math.atan2(S-T,E-x)-this.startTouchesAngle,F=Math.hypot(S-T,E-x)/this.startTouchesDistance,D=d.getBoundedRatio(c.ratio/F);y.ratio=D,y.angle=c.angle+w;var P=this.getDimensions(),L=this.renderer.viewportToFramedGraph((this.startTouchesPositions||[])[0],{cameraState:c}),I=Math.min(P.width,P.height)-2*h,z=I/P.width,G=I/P.height,k=D/I,C=x-I/2/z,N=T-I/2/G,$=qa({x:C,y:N},y.angle);C=$.x,N=$.y,y.x=L.x-C*k,y.y=L.y+N*k,d.setState(y);break}}}}}},{key:"setSettings",value:function(t){this.settings=t}}])}(ms),yh=function(){function a(n,e,t,r){Q(this,a),A(this,"pendingNode",null),A(this,"session",null),this.graph=n,this.viewportToGraph=e,this.setNodesState=t,this.emit=r}return J(a,[{key:"start",value:function(e,t,r,i,o){var s=r(e),l=!1;if(this.emit("nodeDragStart",{node:e,allDraggedNodes:s,event:t,preventSigmaDefault:function(){l=!0}}),l)return!1;var u=new Map,d=M(s),c;try{for(d.s();!(c=d.n()).done;){var h=c.value;u.set(h,{x:this.graph.getNodeAttribute(h,i),y:this.graph.getNodeAttribute(h,o)})}}catch(f){d.e(f)}finally{d.f()}return this.session={node:e,allNodes:s,startPosition:this.viewportToGraph(t),startNodePositions:u,xAttr:i,yAttr:o},this.setNodesState(s,{isDragged:!0}),!0}},{key:"applyMove",value:function(e,t){var r=this.session,i=r.allNodes,o=r.startNodePositions,s=r.startPosition,l=r.xAttr,u=r.yAttr,d=this.viewportToGraph(e),c={x:d.x-s.x,y:d.y-s.y},h=M(i),f;try{for(h.s();!(f=h.n()).done;){var g=f.value,m=o.get(g);if(!(!m||!this.graph.hasNode(g))){var p={x:m.x+c.x,y:m.y+c.y};t?this.graph.mergeNodeAttributes(g,t(p,g)):(this.graph.setNodeAttribute(g,l,p.x),this.graph.setNodeAttribute(g,u,p.y))}}}catch(v){h.e(v)}finally{h.f()}}},{key:"end",value:function(){if(this.pendingNode=null,!this.session)return null;var e=this.session,t=e.node,r=e.allNodes;return this.setNodesState(r,{isDragged:!1}),this.session=null,{node:t,allNodes:r}}},{key:"removeNode",value:function(e){e===this.pendingNode&&(this.pendingNode=null),this.session&&(this.session.node===e?(this.setNodesState(this.session.allNodes,{isDragged:!1}),this.session=null):this.session.allNodes.includes(e)&&(this.session.allNodes=this.session.allNodes.filter(function(t){return t!==e}),this.session.startNodePositions.delete(e)))}},{key:"clear",value:function(){this.pendingNode=null,this.session=null}}])}();function ts(a,n){return a<n?"".concat(a,"\0").concat(n):"".concat(n,"\0").concat(a)}var xh=function(){function a(n,e){Q(this,a),A(this,"groups",new Map),A(this,"edgeToGroupKey",new Map),this.graph=n,this.onGroupChanged=e}return J(a,[{key:"getGroupKey",value:function(e){return ts(this.graph.source(e),this.graph.target(e))}},{key:"sortGroup",value:function(e,t){var r=this,i=t.split("\0")[0];e.sort(function(o,s){var l=r.graph.source(o)===i||!r.graph.isDirected(o)?0:1,u=r.graph.source(s)===i||!r.graph.isDirected(s)?0:1;return l-u})}},{key:"register",value:function(e){var t=this.getGroupKey(e),r=this.groups.get(t);r||(r=[],this.groups.set(t,r)),r.includes(e)||r.push(e),this.edgeToGroupKey.set(e,t),r.length>1&&this.sortGroup(r,t),this.onGroupChanged(r,r.length)}},{key:"unregister",value:function(e){var t=this.edgeToGroupKey.get(e);if(t){this.edgeToGroupKey.delete(e);var r=this.groups.get(t);if(r){var i=r.indexOf(e);i!==-1&&r.splice(i,1),r.length===0?this.groups.delete(t):this.onGroupChanged(r,r.length)}}}},{key:"getGroup",value:function(e){var t,r=this.edgeToGroupKey.get(e);return r?(t=this.groups.get(r))!==null&&t!==void 0?t:[]:[]}},{key:"getSiblings",value:function(e){return this.getGroup(e).filter(function(t){return t!==e})}},{key:"rebuild",value:function(){var e=this;this.groups.clear(),this.edgeToGroupKey.clear(),this.graph.forEachEdge(function(l,u,d,c){var h=ts(d,c),f=e.groups.get(h);f||(f=[],e.groups.set(h,f)),f.push(l),e.edgeToGroupKey.set(l,h)});var t=M(this.groups),r;try{for(t.s();!(r=t.n()).done;){var i=te(r.value,2),o=i[0],s=i[1];s.length>1&&this.sortGroup(s,o),this.onGroupChanged(s,s.length)}}catch(l){t.e(l)}finally{t.f()}}},{key:"clear",value:function(){this.groups.clear(),this.edgeToGroupKey.clear()}}])}();function ns(a,n){var e;if(a===!1||a==="extend"||a==="separate")return a;var t=a[n];return t!==void 0?t:(e=a.default)!==null&&e!==void 0?e:!1}function as(a){return a===!1?!1:a==="extend"||a==="separate"?!0:Object.values(a).some(function(n){return n==="extend"||n==="separate"})}function rs(a){return a==="separate"?!0:a===!1||a==="extend"?!1:a.default==="separate"?!0:Object.values(a).includes("separate")}var xe={node:{parent:null,eventSuffix:"Node",payloadKey:"node",isEnabled:function(){return!0},writesPickingThisFrame:function(){return!0},setHover:function(n,e,t){return n.setNodeState(e,{isHovered:t})},getCursor:function(n,e){var t;return(t=n.nodeDataCache[e])===null||t===void 0?void 0:t.cursor},isHitValid:function(n,e){var t;return((t=n.nodeDataCache[e])===null||t===void 0?void 0:t.visibility)!=="hidden"}},edge:{parent:null,eventSuffix:"Edge",payloadKey:"edge",isEnabled:function(n){return!!n.settings.enableEdgeEvents},writesPickingThisFrame:function(n){return!!n.settings.enableEdgeEvents},setHover:function(n,e,t){return n.setEdgeState(e,{isHovered:t})},getCursor:function(n,e){var t;return(t=n.edgeDataCache[e])===null||t===void 0?void 0:t.cursor}},nodeLabel:{parent:"node",eventSuffix:"NodeLabel",payloadKey:"node",isEnabled:function(n){return rs(n.settings.nodeLabelEvents)},writesPickingThisFrame:function(n){return as(n.settings.nodeLabelEvents)},setHover:function(n,e,t){return n.setNodeState(e,{isLabelHovered:t})},getCursor:function(n,e){var t;return(t=n.nodeDataCache[e])===null||t===void 0?void 0:t.labelCursor},resolveForVerb:function(n,e,t){var r=ns(t.settings.nodeLabelEvents,e);return r===!1?null:r==="extend"?{kind:"node",key:n.key}:n}},edgeLabel:{parent:"edge",eventSuffix:"EdgeLabel",payloadKey:"edge",isEnabled:function(n){return rs(n.settings.edgeLabelEvents)},writesPickingThisFrame:function(n){return as(n.settings.edgeLabelEvents)},setHover:function(n,e,t){return n.setEdgeState(e,{isLabelHovered:t})},getCursor:function(n,e){var t;return(t=n.edgeDataCache[e])===null||t===void 0?void 0:t.labelCursor},resolveForVerb:function(n,e,t){var r=ns(t.settings.edgeLabelEvents,e);return r===!1?null:r==="extend"?{kind:"edge",key:n.key}:n}}},Tt=["node","edge","nodeLabel","edgeLabel"];function _h(){return{lookup:[null],idsByKind:{node:new Map,edge:new Map,nodeLabel:new Map,edgeLabel:new Map},nextId:1}}function _t(a,n,e){var t;return(t=a.idsByKind[n].get(e))!==null&&t!==void 0?t:0}function Ca(a,n){var e=M(Tt),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;if(r===n||xe[r].parent===n){var i=M(a.idsByKind[r].values()),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;a.lookup[s]=null}}catch(h){i.e(h)}finally{i.f()}a.idsByKind[r]=new Map}}}catch(h){e.e(h)}finally{e.f()}var l=1,u=M(Tt),d;try{for(u.s();!(d=u.n()).done;){var c=d.value;if(c===n)break;l+=a.idsByKind[c].size}}catch(h){u.e(h)}finally{u.f()}a.nextId=l}function is(a,n,e){var t=a.nextId++;return a.idsByKind[n].set(e,t),a.lookup[t]={kind:n,key:e},t}function os(a,n,e){for(var t=0,r=Fa(n);t<r.length;t++){var i=r[t],o=a.idsByKind[i].get(e);o!==void 0&&(a.lookup[o]=null,a.idsByKind[i].delete(e))}}function Th(a,n){var e=M(Tt),t;try{for(e.s();!(t=e.n()).done;){var r=t.value;if(xe[r].parent!==null){var i=M(a.idsByKind[r].values()),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;a.lookup[s]=null}}catch(x){i.e(x)}finally{i.f()}a.idsByKind[r]=new Map}}}catch(x){e.e(x)}finally{e.f()}a.nextId=1;var l=M(Tt),u;try{for(l.s();!(u=l.n()).done;){var d=u.value;if(xe[d].parent===null){var c=M(a.idsByKind[d].values()),h;try{for(c.s();!(h=c.n()).done;){var f=h.value;f>=a.nextId&&(a.nextId=f+1)}}catch(x){c.e(x)}finally{c.f()}}}}catch(x){l.e(x)}finally{l.f()}var g=M(Tt),m;try{for(g.s();!(m=g.n()).done;){var p=m.value,v=xe[p];if(!(v.parent===null||!v.isEnabled(n))){var b=M(a.idsByKind[v.parent].keys()),y;try{for(b.s();!(y=b.n()).done;){var _=y.value;a.idsByKind[p].set(_,a.nextId),a.lookup[a.nextId]={kind:p,key:_},a.nextId++}}catch(x){b.e(x)}finally{b.f()}}}}catch(x){g.e(x)}finally{g.f()}}function Sh(a,n){var e=M(Tt),t;try{for(e.s();!(t=e.n()).done;){var r=t.value,i=a[r],o=n[r];if(i!==o){if(i.size!==o.size)return!1;var s=M(i),l;try{for(s.s();!(l=s.n()).done;){var u=te(l.value,2),d=u[0],c=u[1];if(o.get(d)!==c)return!1}}catch(h){s.e(h)}finally{s.f()}}}}catch(h){e.e(h)}finally{e.f()}return!0}function ss(a,n,e){xe[n.kind].setHover(a,n.key,e)}function Eh(a,n){return xe[n.kind].getCursor(a,n.key)}function Ln(a,n){return"".concat(n).concat(xe[a].eventSuffix)}function Cn(a,n){return O(O({},n),{},A({},xe[a.kind].payloadKey,a.key))}function Rh(a,n,e){var t=xe[n.kind].resolveForVerb;return t?t(n,e,a):n}function Ah(a,n){var e=xe[n.kind].isHitValid;return e?e(a,n.key):!0}function Fa(a){return Tt.filter(function(n){return n===a||xe[n].parent===a})}function bs(a,n,e){return n&&(n=Rh(a,n,e)),n&&!Ah(a,n)&&(n=null),n}function Lr(a,n,e){var t=e==="wheel"?a.stateManager.hovered:a.getHitAtPosition(n);return bs(a,t,e)}function Dh(a,n){return!a||!n?a===n:a.kind===n.kind&&a.key===n.key}function ys(a,n,e){var t={event:e,preventSigmaDefault:function(){return e.preventSigmaDefault()}},r=a.dragManager.session,i=r?{kind:"node",key:r.node}:bs(a,n,"enter"),o=a.stateManager,s=o.hovered;Dh(s,i)||(s&&(ss(a,s,!1),a.emit(Ln(s.kind,"leave"),Cn(s,t))),o.setHovered(i),i&&(ss(a,i,!0),a.emit(Ln(i.kind,"enter"),Cn(i,t))),a.updateContainerCursor())}function wh(a,n,e,t){t.handleResize=function(){return a.scheduleRefresh()},window.addEventListener("resize",t.handleResize),t.handleMove=function(i){a.hoverResolver.pointerMoved(yt(i))},t.handleMoveBody=function(i){var o=yt(i),s=a.dragManager;if(s.pendingNode&&!s.session){var l=a.nodeStyleAnalysis,u=l.xAttribute,d=l.yAttribute,c=a.settings;s.start(s.pendingNode,o,c.getDraggedNodes,u||"x",d||"y"),s.pendingNode=null}s.session&&(s.applyMove(o,a.settings.dragPositionToAttributes),a.emit("nodeDrag",{node:s.session.node,allDraggedNodes:s.session.allNodes,event:o}),o.preventSigmaDefault()),a.emit("moveBody",{event:o,preventSigmaDefault:function(){return o.preventSigmaDefault()}})},t.handleLeave=function(i){var o=yt(i),s={event:o,preventSigmaDefault:function(){return o.preventSigmaDefault()}};a.hoverResolver.pointerLeft(),ys(a,null,o),a.emit("leaveStage",s)},t.handleEnter=function(i){var o=yt(i);a.emit("enterStage",{event:o,preventSigmaDefault:function(){return o.preventSigmaDefault()}})};var r=function(o){return function(s){var l=yt(s),u={event:l,preventSigmaDefault:function(){return l.preventSigmaDefault()}},d=Lr(a,l,o);if(d){a.emit(Ln(d.kind,o),Cn(d,u));return}a.emit("".concat(o,"Stage"),u)}};t.handleClick=r("click"),t.handleRightClick=r("rightClick"),t.handleDoubleClick=r("doubleClick"),t.handleWheel=r("wheel"),t.handleDown=function(i){var o=yt(i),s={event:o,preventSigmaDefault:function(){return o.preventSigmaDefault()}},l=Lr(a,o,"down");if(l){l.kind==="node"&&a.settings.enableNodeDrag&&(a.dragManager.pendingNode=l.key),a.emit(Ln(l.kind,"down"),Cn(l,s));return}a.emit("downStage",s)},t.handleUp=function(i){var o=yt(i),s={event:o,preventSigmaDefault:function(){return o.preventSigmaDefault()}},l=a.dragManager.end();l&&a.emit("nodeDragEnd",O({node:l.node,allDraggedNodes:l.allNodes},s));var u=Lr(a,o,"up");if(u){a.emit(Ln(u.kind,"up"),Cn(u,s));return}a.emit("upStage",s)},n.on("mousemove",t.handleMove),n.on("mousemovebody",t.handleMoveBody),n.on("click",t.handleClick),n.on("rightClick",t.handleRightClick),n.on("doubleClick",t.handleDoubleClick),n.on("wheel",t.handleWheel),n.on("mousedown",t.handleDown),n.on("mouseup",t.handleUp),n.on("mouseleave",t.handleLeave),n.on("mouseenter",t.handleEnter),e.on("touchdown",t.handleDown),e.on("touchdown",t.handleMove),e.on("touchup",t.handleUp),e.on("touchmove",t.handleMove),e.on("tap",t.handleClick),e.on("doubletap",t.handleDoubleClick),e.on("touchmove",t.handleMoveBody)}function Lh(a,n){var e=a.graph,t=new Set(["x","y","zIndex","type"]);n.eachNodeAttributesUpdatedGraphUpdate=function(r){var i,o=(i=r.hints)===null||i===void 0?void 0:i.attributes,s=!o||o.some(function(l){return t.has(l)});a.refresh({partialGraph:{nodes:e.nodes()},skipIndexation:!s,schedule:!0})},n.eachEdgeAttributesUpdatedGraphUpdate=function(r){var i,o=(i=r.hints)===null||i===void 0?void 0:i.attributes,s=o&&["zIndex","type"].some(function(l){return o?.includes(l)});a.refresh({partialGraph:{edges:e.edges()},skipIndexation:!s,schedule:!0})},n.addNodeGraphUpdate=function(r){a.refresh({partialGraph:{nodes:[r.key]},skipIndexation:!1,schedule:!0})},n.updateNodeGraphUpdate=function(r){a.refresh({partialGraph:{nodes:[r.key]},skipIndexation:!1,schedule:!0})},n.dropNodeGraphUpdate=function(r){a.removeNode(r.key),a.scheduleProcess()},n.addEdgeGraphUpdate=function(r){var i=r.key;a.markNodesDirty([r.source,r.target]),a.edgeGroups.register(i);var o=a.edgeGroups.getSiblings(i);a.refresh({partialGraph:{edges:[i].concat(V(o))},schedule:!0})},n.updateEdgeGraphUpdate=function(r){a.refresh({partialGraph:{edges:[r.key]},skipIndexation:!1,schedule:!0})},n.dropEdgeGraphUpdate=function(r){var i=r.key;a.markNodesDirty([r.source,r.target]);var o=a.edgeGroups.getSiblings(i);a.edgeGroups.unregister(i),a.removeEdge(i);var s=M(o),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;a.addEdge(u)}}catch(d){s.e(d)}finally{s.f()}a.scheduleProcess()},n.clearEdgesGraphUpdate=function(){a.clearEdgeState(),a.clearEdgeIndices(),a.refresh({schedule:!0})},n.clearGraphUpdate=function(){a.clearEdgeState(),a.clearNodeState(),a.clearEdgeIndices(),a.clearNodeIndices(),a.refresh({schedule:!0})},e.on("nodeAdded",n.addNodeGraphUpdate),e.on("nodeDropped",n.dropNodeGraphUpdate),e.on("nodeAttributesUpdated",n.updateNodeGraphUpdate),e.on("eachNodeAttributesUpdated",n.eachNodeAttributesUpdatedGraphUpdate),e.on("edgeAdded",n.addEdgeGraphUpdate),e.on("edgeDropped",n.dropEdgeGraphUpdate),e.on("edgeAttributesUpdated",n.updateEdgeGraphUpdate),e.on("eachEdgeAttributesUpdated",n.eachEdgeAttributesUpdatedGraphUpdate),e.on("edgesCleared",n.clearEdgesGraphUpdate),e.on("cleared",n.clearGraphUpdate)}function Ch(a,n){a.removeListener("nodeAdded",n.addNodeGraphUpdate),a.removeListener("nodeDropped",n.dropNodeGraphUpdate),a.removeListener("nodeAttributesUpdated",n.updateNodeGraphUpdate),a.removeListener("eachNodeAttributesUpdated",n.eachNodeAttributesUpdatedGraphUpdate),a.removeListener("edgeAdded",n.addEdgeGraphUpdate),a.removeListener("edgeDropped",n.dropEdgeGraphUpdate),a.removeListener("edgeAttributesUpdated",n.updateEdgeGraphUpdate),a.removeListener("eachEdgeAttributesUpdated",n.eachEdgeAttributesUpdatedGraphUpdate),a.removeListener("edgesCleared",n.clearEdgesGraphUpdate),a.removeListener("cleared",n.clearGraphUpdate)}var Ph={x:.5,y:.5,angle:0,ratio:1},kh=8,Fh=.001;function Ih(a){var n=a.coords,e=a.nodeData,t=a.dimensions,r=a.stagePadding,i=a.zoomToSizeRatioFunction,o=a.itemSizesReference,s=a.fitLabels,l=a.nodeLabelBox,u=Object.keys(n);if(!u.length)return a.extent;for(var d=i(1)||1,c=o==="positions",h=t.width,f=t.height,g=a.extent,m=0;m<kh;m++){for(var p=mn(g),v={width:g.x[1]-g.x[0]||1,height:g.y[1]-g.y[0]||1},b=at(Ph,t,v,r),y=ls(b,p({x:0,y:0}),h,f),_=ls(b,p({x:1,y:0}),h,f),x=Math.hypot(_.x-y.x,_.y-y.y)||1,T=1/0,R=-1/0,E=1/0,S=-1/0,w=0,F=u.length;w<F;w++){var D=u[w],P=e[D],L=P.size/d*(c?x:1),I=-L,z=L,G=-L,k=L;if(s){var C=l(P,L);C&&(C.minX<I&&(I=C.minX),C.maxX>z&&(z=C.maxX),C.minY<G&&(G=C.minY),C.maxY>k&&(k=C.maxY))}var N=n[D],$=N.x,H=N.y;T=Math.min(T,$+I/x),R=Math.max(R,$+z/x),E=Math.min(E,H-k/x),S=Math.max(S,H-G/x)}var Z={x:[T,R],y:[E,S]},X=Math.max(Z.x[1]-Z.x[0],Z.y[1]-Z.y[0])||1,K=Math.max(Math.abs(Z.x[0]-g.x[0]),Math.abs(Z.x[1]-g.x[1]),Math.abs(Z.y[0]-g.y[0]),Math.abs(Z.y[1]-g.y[1]));if(g=Z,K/X<Fh)break}return g}function ls(a,n,e,t){var r=Ft(a,n);return{x:(1+r.x)*e/2,y:(1-r.y)*t/2}}var Gh=typeof navigator<"u"&&/Mac|iP(hone|ad|od)/.test(navigator.platform),zh=1500,Nh=`.sigma-gesture-hint {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 1em;
  background: #00000066;
  color: #ffffff;
  font-size: 1em;
  pointer-events: none;
  transition: opacity 0.1s;
}`;function us(a){var n,e,t=Ot("style");t.textContent=a,document.head.appendChild(t);var r=((n=(e=t.sheet)===null||e===void 0?void 0:e.cssRules.length)!==null&&n!==void 0?n:0)>0;return t.remove(),r}var xt=null;function Mh(){return xt===null&&(xt=Nh,us("@scope {}")&&(xt=`@scope {
`.concat(xt,`
}`)),us("@layer sigma-gesture-hint {}")&&(xt=`@layer sigma-gesture-hint {
`.concat(xt,`
}`))),xt}var Oh=function(){function a(n){Q(this,a),A(this,"hideTimeout",null),this.styleElement=Ot("style"),this.styleElement.textContent=Mh(),n.appendChild(this.styleElement),this.element=Ot("div",{opacity:"0"},{class:"sigma-gesture-hint"}),n.appendChild(this.element)}return J(a,[{key:"show",value:function(e,t){var r=this,i=e==="touch"?t.sharedGestureTouchMessage:Gh?t.sharedGestureAppleWheelMessage:t.sharedGestureWheelMessage;i&&(this.element.textContent=i,this.element.style.opacity="1",typeof this.hideTimeout=="number"&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(function(){r.hideTimeout=null,r.element.style.opacity="0"},zh))}},{key:"kill",value:function(){typeof this.hideTimeout=="number"&&clearTimeout(this.hideTimeout),this.styleElement.remove(),this.element.remove()}}])}(),Wh=function(){function a(n){Q(this,a),A(this,"readBuffer",null),A(this,"fence",null),A(this,"result",new Uint8Array(4)),A(this,"generation",0),A(this,"readGeneration",0),A(this,"lastEvent",null),A(this,"active",!1),A(this,"dirty",!1),A(this,"rafId",null),A(this,"killed",!1),this.options=n}return J(a,[{key:"pointerMoved",value:function(e){this.lastEvent=e,this.active=!0,!this.options.isRenderPending()&&this.request()}},{key:"pointerLeft",value:function(){this.active=!1,this.dirty=!1}},{key:"frameRendered",value:function(){this.request()}},{key:"invalidate",value:function(){this.generation++}},{key:"request",value:function(){if(!(this.killed||!this.active||!this.lastEvent)){if(this.fence){this.dirty=!0;return}this.startRead()}}},{key:"startRead",value:function(){var e=this.options,t=e.gl,r=e.getFrameBuffer,i=e.getPixelRatio,o=e.getDownSizingRatio;this.readGeneration=this.generation;var s=this.lastEvent,l=Xa(t,s.x,s.y,i(),o()),u=te(l,2),d=u[0],c=u[1];this.readBuffer||(this.readBuffer=t.createBuffer()),t.bindFramebuffer(t.FRAMEBUFFER,r()),t.bindBuffer(t.PIXEL_PACK_BUFFER,this.readBuffer),t.bufferData(t.PIXEL_PACK_BUFFER,4,t.STREAM_READ),t.readPixels(d,c,1,1,t.RGBA,t.UNSIGNED_BYTE,0),t.bindBuffer(t.PIXEL_PACK_BUFFER,null),t.bindFramebuffer(t.FRAMEBUFFER,null),this.fence=t.fenceSync(t.SYNC_GPU_COMMANDS_COMPLETE,0),t.flush(),this.schedulePoll(s)}},{key:"schedulePoll",value:function(e){var t=this;this.rafId=requestAnimationFrame(function(){t.rafId=null,t.poll(e)})}},{key:"poll",value:function(e){var t=this.options,r=t.gl,i=t.onIndex;if(!(this.killed||!this.fence)){var o=r.clientWaitSync(this.fence,0,0);if(o===r.TIMEOUT_EXPIRED){this.schedulePoll(e);return}if(r.deleteSync(this.fence),this.fence=null,o!==r.WAIT_FAILED&&this.readGeneration===this.generation){r.bindBuffer(r.PIXEL_PACK_BUFFER,this.readBuffer),r.getBufferSubData(r.PIXEL_PACK_BUFFER,0,this.result),r.bindBuffer(r.PIXEL_PACK_BUFFER,null);var s=te(this.result,4),l=s[0],u=s[1],d=s[2],c=s[3];this.active&&i(ja(l,u,d,c),e)}this.dirty&&(this.dirty=!1,this.active&&this.lastEvent&&!this.options.isRenderPending()&&this.startRead())}}},{key:"reset",value:function(){this.rafId!==null&&cancelAnimationFrame(this.rafId),this.rafId=null,this.fence=null,this.readBuffer=null,this.dirty=!1}},{key:"kill",value:function(){this.killed=!0,this.rafId!==null&&cancelAnimationFrame(this.rafId),this.rafId=null;var e=this.options.gl;this.fence&&e.deleteSync(this.fence),this.fence=null,this.readBuffer&&e.deleteBuffer(this.readBuffer),this.readBuffer=null}}])}(),ds=function(){function a(n,e){Q(this,a),this.key=n,this.size=e}return J(a,null,[{key:"compare",value:function(e,t){return e.size>t.size?-1:e.size<t.size||e.key>t.key?1:-1}}])}(),Pa=function(){function a(){Q(this,a),A(this,"width",0),A(this,"height",0),A(this,"cellSize",0),A(this,"columns",0),A(this,"rows",0),A(this,"cells",{})}return J(a,[{key:"resizeAndClear",value:function(e,t){this.width=e.width,this.height=e.height,this.cellSize=t,this.columns=Math.ceil(e.width/t),this.rows=Math.ceil(e.height/t),this.cells={}}},{key:"getIndex",value:function(e){var t=Math.floor(e.x/this.cellSize),r=Math.floor(e.y/this.cellSize);return r*this.columns+t}},{key:"add",value:function(e,t,r){var i=new ds(e,t),o=this.getIndex(r),s=this.cells[o];s||(s=[],this.cells[o]=s),s.push(i)}},{key:"organize",value:function(){for(var e in this.cells){var t=this.cells[e];t.sort(ds.compare)}}},{key:"getLabelsToDisplay",value:function(e,t,r){var i=this.cellSize*this.cellSize,o=i/e/e,s=o*t/i,l=Math.ceil(s),u=[];if(r)for(var d=Math.max(0,Math.floor(r.x1/this.cellSize)),c=Math.min(this.columns-1,Math.floor(r.x2/this.cellSize)),h=Math.max(0,Math.floor(r.y1/this.cellSize)),f=Math.min(this.rows-1,Math.floor(r.y2/this.cellSize)),g=h;g<=f;g++)for(var m=d;m<=c;m++){var p=g*this.columns+m,v=this.cells[p];if(v)for(var b=0;b<Math.min(l,v.length);b++)u.push(v[b].key)}else for(var y in this.cells)for(var _=this.cells[y],x=0;x<Math.min(l,_.length);x++)u.push(_[x].key);return u}}])}();function Bh(a){var n=a.graph,e=a.hoveredNode,t=a.highlightedNodes,r=a.displayedNodeLabels,i=new Set,o=new Set(t);e&&o.add(e);var s=M(o),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;n.hasNode(u)&&n.forEachEdge(u,function(f){i.add(f)})}}catch(f){s.e(f)}finally{s.f()}var d=M(r),c;try{var h=function(){var g=c.value;if(o.has(g))return 1;n.forEachEdge(g,function(m,p,v,b){var y=v===g?b:v;r.has(y)&&i.add(m)})};for(d.s();!(c=d.n()).done;)h()}catch(f){d.e(f)}finally{d.f()}return Array.from(i)}var Xt=150,jt=50,Uh={both:0,node:1,label:2},Hh={over:0,above:1,below:2,auto:3},cs=12,$h=3,Vh=function(){function a(n){Q(this,a),A(this,"labelGrid",new Pa),A(this,"edgeAnchorGrid",new Pa),A(this,"displayedNodeLabels",new Set),A(this,"displayedEdgeLabels",new Set),A(this,"edgeLabelCandidates",[]),A(this,"renderedNodeLabels",new Set),A(this,"labelSizeCache",new Map),A(this,"framePassPoints",new Float32Array(0)),A(this,"labelsDirty",!0),this.internals=n}return J(a,[{key:"resetFrame",value:function(){this.displayedNodeLabels=new Set,this.renderedNodeLabels=new Set,this.labelSizeCache.clear()}},{key:"clearEdgeLabels",value:function(){this.displayedEdgeLabels=new Set}},{key:"resetLabelGrid",value:function(){this.labelGrid=new Pa,this.edgeAnchorGrid=new Pa}},{key:"processWebGLLabels",value:function(e){for(var t,r=this.internals,i=r.labelProgram,o=r.primitives,s=r.nodeDataCache,l=(o==null||(t=o.nodes)===null||t===void 0||(t=t.label)===null||t===void 0||(t=t.font)===null||t===void 0?void 0:t.family)||"sans-serif",u=new Map,d=0,c=e.length;d<c;d++){var h=e[d],f=s[h];if(!(f.visibility==="hidden"||!f.label)){var g=f.labelFont||l,m=u.get(g);m?m.push(f.label):u.set(g,[f.label])}}var p=M(u),v;try{for(p.s();!(v=p.n()).done;){var b=te(v.value,2),y=b[0],_=b[1],x=pa(y),T=x.family,R=x.weight,E=x.style,S=i.registerFont(T,R,E);i.ensureGlyphsReady(_,S)}}catch(w){p.e(w)}finally{p.f()}}},{key:"measureNodeLabel",value:function(e){var t,r;if(!e.label)return{width:0,height:0,textHeight:0};var i=this.internals,o=i.labelProgram,s=i.primitives,l=(t=e.labelSize)!==null&&t!==void 0?t:14,u=e.labelFont||(s==null||(r=s.nodes)===null||r===void 0||(r=r.label)===null||r===void 0||(r=r.font)===null||r===void 0?void 0:r.family)||"sans-serif",d="".concat(e.label,"|").concat(l,"|").concat(u);if(this.labelSizeCache.has(d))return this.labelSizeCache.get(d);var c=pa(u),h=c.family,f=c.weight,g=c.style,m=o.registerFont(h,f,g),p=o.measureLabel(e.label,l,m);return this.labelSizeCache.set(d,p),p}},{key:"nodeLabelBox",value:function(e,t){var r,i,o,s,l;if(e.visibility==="hidden"||e.labelVisibility==="hidden")return null;var u=this.measureNodeLabel(e),d=u.width,c=u.height,h=u.textHeight;if(!d)return null;var f=(r=(i=this.internals.primitives)===null||i===void 0||(i=i.nodes)===null||i===void 0||(i=i.label)===null||i===void 0?void 0:i.margin)!==null&&r!==void 0?r:Ut,g=t+f,m=e.labelBackgroundColor?(o=e.labelBackgroundPadding)!==null&&o!==void 0?o:mr:0,p=d/2,v=c/2,b=p+m,y=v+m,_=h/2,x=0,T=0;switch((s=e.labelPosition)!==null&&s!==void 0?s:"right"){case"left":x=-(g+p);break;case"above":T=-(g+_);break;case"below":T=g+_;break;case"over":break;default:x=g+p}var R=(l=e.labelAngle)!==null&&l!==void 0?l:0,E=qa({x,y:T},R),S=E.x,w=E.y,F=Math.abs(Math.cos(R)),D=Math.abs(Math.sin(R)),P=F*b+D*y,L=D*b+F*y;return{minX:S-P,maxX:S+P,minY:w-L,maxY:w+L}}},{key:"computeDisplayedNodeLabels",value:function(){var e=this.internals.getCameraState(),t=this.internals.getDimensions(),r=t.width,i=t.height,o=this.internals.viewportToFramedGraph({x:-Xt,y:-jt}),s=this.internals.viewportToFramedGraph({x:r+Xt,y:-jt}),l=this.internals.viewportToFramedGraph({x:-Xt,y:i+jt}),u=this.internals.viewportToFramedGraph({x:r+Xt,y:i+jt}),d=Math.min(o.x,s.x,l.x,u.x),c=Math.max(o.x,s.x,l.x,u.x),h=Math.min(o.y,s.y,l.y,u.y),f=Math.max(o.y,s.y,l.y,u.y),g=at({x:.5,y:.5,ratio:1,angle:0},{width:r,height:i},this.internals.getGraphDimensions(),this.internals.getStagePadding()),m=function(C){var N=Ft(g,C);return{x:(1+N.x)*r/2,y:(1-N.y)*i/2}},p=m({x:d,y:h}),v=m({x:c,y:h}),b=m({x:d,y:f}),y=m({x:c,y:f}),_={x1:Math.min(p.x,v.x,b.x,y.x),y1:Math.min(p.y,v.y,b.y,y.y),x2:Math.max(p.x,v.x,b.x,y.x),y2:Math.max(p.y,v.y,b.y,y.y)},x=this.internals,T=x.settings,R=x.nodeDataCache,E=x.nodesWithForcedLabels,S=this.labelGrid.getLabelsToDisplay(e.ratio,T.labelDensity,_);lr(S,E);for(var w=0,F=S.length;w<F;w++){var D=S[w],P=R[D];if(!this.displayedNodeLabels.has(D)&&!(P.visibility==="hidden"||P.labelVisibility==="hidden")&&P.label&&!(P.x<d||P.x>c||P.y<h||P.y>f)){var L=this.internals.framedGraphToViewport(P),I=L.x,z=L.y,G=this.internals.scaleSize(P.size);!Ze(P)&&G<T.labelRenderedSizeThreshold||I<-Xt-G||I>r+Xt+G||z<-jt-G||z>i+jt+G||this.displayedNodeLabels.add(D)}}}},{key:"buildFramePassPoints",value:function(){var e=this.internals,t=e.nodeDataCache,r=e.nodeDataTexture;if(!r)return{data:this.framePassPoints,count:0};var i=this.displayedNodeLabels.size*3;this.framePassPoints.length<i&&(this.framePassPoints=new Float32Array(i));var o=this.framePassPoints,s=0,l=M(this.displayedNodeLabels),u;try{for(l.s();!(u=l.n()).done;){var d,c,h=u.value,f=t[h];if(f){var g=r.getIndex(h);g<0||(o[s*3]=g,o[s*3+1]=(d=Bt[f.labelPosition||Ke.labelPosition])!==null&&d!==void 0?d:0,o[s*3+2]=(c=f.labelAngle)!==null&&c!==void 0?c:0,s++)}}}catch(m){l.e(m)}finally{l.f()}return{data:o,count:s}}},{key:"renderWebGLLabels",value:function(e,t){var r=this.internals,i=r.nodeDataCache,o=r.labelProgram,s=r.primitives,l=r.nodeDataTexture,u=[],d=M(this.displayedNodeLabels),c;try{for(d.s();!(c=d.n()).done;){var h=c.value;if(!this.renderedNodeLabels.has(h)){var f=i[h];t&&f.labelDepth!==t||(this.renderedNodeLabels.add(h),u.push(h))}}}catch(Te){d.e(Te)}finally{d.f()}if(u.length!==0){if(this.labelsDirty){for(var g,m,p,v=0,b=0,y=u.length;b<y;b++){var _=i[u[b]];v+=_.label.length}o.reallocate(v);for(var x=14,T=(g=s==null||(m=s.nodes)===null||m===void 0||(m=m.label)===null||m===void 0?void 0:m.margin)!==null&&g!==void 0?g:Ut,R=Ke.labelPosition,E=(s==null||(p=s.nodes)===null||p===void 0||(p=p.label)===null||p===void 0||(p=p.font)===null||p===void 0?void 0:p.family)||"sans-serif",S=new Map,w=0,F=0,D=u.length;F<D;F++){var P,L,I,z,G=u[F],k=i[G],C=k.labelFont||E,N=S.get(C);if(N===void 0){var $=pa(C),H=$.family,Z=$.weight,X=$.style;N=o.registerFont(H,Z,X),S.set(C,N)}var K={text:k.label,x:k.x,y:k.y,size:(P=k.labelSize)!==null&&P!==void 0?P:x,color:k.labelColor,nodeSize:k.size,margin:T,position:(L=k.labelPosition)!==null&&L!==void 0?L:R,hidden:!1,forceLabel:Ze(k),type:"default",zIndex:(I=k.zIndex)!==null&&I!==void 0?I:0,parentType:"node",parentKey:G,fontKey:N,labelAngle:(z=k.labelAngle)!==null&&z!==void 0?z:0,nodeIndex:l.getIndex(G)},Ie=o.processLabel(G,w,K);w+=Ie}o.invalidateBuffers()}o.render(e)}}},{key:"renderBackdrops",value:function(e,t){var r=this.internals,i=r.backdropProgram,o=r.nodeDataCache,s=r.nodesWithBackdrop,l=r.attachmentManager,u=r.pixelRatio,d=r.nodeDataTexture,c=[],h=M(s),f;try{for(h.s();!(f=h.n()).done;){var g,m=f.value,p=o[m];if(!(!p||p.visibility==="hidden")&&!(t&&p.depth!==t)){var v=(g=d?.getIndex(m))!==null&&g!==void 0?g:-1;v<0||c.push({key:m,nodeIndex:v})}}}catch(ct){h.e(ct)}finally{h.f()}if(c.length!==0){i.reallocate(c.length);for(var b=0;b<c.length;b++){var y,_,x,T,R,E,S,w,F=c[b],D=F.key,P=F.nodeIndex,L=o[D],I=this.displayedNodeLabels.has(D),z=I?this.measureNodeLabel(L):{width:0,height:0,textHeight:0},G=z.textHeight,k=z.width,C=z.height,N=0,$=0;if(I&&L.labelAttachment&&l){var H=l.getEntry(D,L.labelAttachment);if(H){var Z=L.labelAttachmentPlacement||"below";if(Z==="below"||Z==="above"){var X=H.height/u;C+=X+st,k=Math.max(k,H.width/u),$=Z==="below"?(X+st)/2:-(X+st)/2}else{var K=H.width/u;k+=K+st,C=Math.max(C,H.height/u),N=Z==="right"?(K+st)/2:-(K+st)/2}}}var Ie=L.backdropColor?rt(L.backdropColor):[255,255,255,255],Te=L.backdropShadowColor?rt(L.backdropShadowColor):[0,0,0,128],$e=Ie.map(function(ct){return ct/255}),Rt=Te.map(function(ct){return ct/255}),en=(y=L.backdropShadowBlur)!==null&&y!==void 0?y:12,tn=(_=L.backdropPadding)!==null&&_!==void 0?_:6,nn=L.backdropBorderColor?rt(L.backdropBorderColor):[0,0,0,0],Xs=nn.map(function(ct){return ct/255}),js=(x=L.backdropBorderWidth)!==null&&x!==void 0?x:0,Ys=(T=L.backdropCornerRadius)!==null&&T!==void 0?T:0,Vr=(R=L.backdropLabelPadding)!==null&&R!==void 0?R:-1,Ks=Vr<0?tn:Vr,Zs=(E=Uh[(S=L.backdropArea)!==null&&S!==void 0?S:"both"])!==null&&E!==void 0?E:0,Qs={key:D,nodeIndex:P,label:L.label,labelWidth:k,labelHeight:C,textHeight:G,type:"default",position:L.labelPosition||Ke.labelPosition,labelAngle:(w=L.labelAngle)!==null&&w!==void 0?w:0,backdropColor:$e,backdropShadowColor:Rt,backdropShadowBlur:en,backdropPadding:tn,backdropBorderColor:Xs,backdropBorderWidth:js,backdropCornerRadius:Ys,backdropLabelPadding:Ks,backdropArea:Zs,labelBoxOffset:[N,$]};i.processBackdrop(b,Qs)}i.invalidateBuffers(),i.render(e)}}},{key:"renderLabelBackgrounds",value:function(e,t){var r=this.internals,i=r.labelBackgroundProgram,o=r.nodeDataCache,s=r.nodeDataTexture,l=xe.nodeLabel.writesPickingThisFrame(this.internals),u=[],d=M(this.displayedNodeLabels),c;try{for(d.s();!(c=d.n()).done;){var h=c.value,f=o[h];!f||f.visibility==="hidden"||t&&f.labelDepth!==t||!l&&!f.labelBackgroundColor||u.push(h)}}catch(P){d.e(P)}finally{d.f()}if(u.length!==0){i.reallocate(u.length);for(var g=0;g<u.length;g++){var m,p,v,b,y=u[g],_=o[y],x=(m=s?.getIndex(y))!==null&&m!==void 0?m:-1;if(!(x<0)){var T=this.measureNodeLabel(_),R=T.width,E=T.height,S=T.textHeight,w=_t(this.internals.pickingState,"nodeLabel",y)||_t(this.internals.pickingState,"node",y),F=_.labelBackgroundColor?Pe(_.labelBackgroundColor):Pe("transparent"),D={nodeIndex:x,id:It(w),color:F,labelWidth:R,labelHeight:E,textHeight:S,positionMode:(p=Bt[_.labelPosition||Ke.labelPosition])!==null&&p!==void 0?p:0,labelAngle:(v=_.labelAngle)!==null&&v!==void 0?v:0,padding:(b=_.labelBackgroundPadding)!==null&&b!==void 0?b:mr};i.processLabelBackground(g,D)}}i.invalidateBuffers(),i.render(e)}}},{key:"cacheAttachments",value:function(e){var t=this.internals,r=t.attachmentManager,i=t.pixelRatio,o=t.nodeDataCache,s=t.nodesWithBackdrop,l=t.graph;if(r){var u=M(s),d;try{for(u.s();!(d=u.n()).done;){var c=d.value;if(this.displayedNodeLabels.has(c)){var h=o[c];if(!(!h||h.visibility==="hidden")&&!(e&&h.depth!==e)&&h.labelAttachment){var f=l.getNodeAttributes(c),g=this.measureNodeLabel(h),m=g.width,p=g.height,v={node:c,attributes:f,pixelRatio:i,labelWidth:m,labelHeight:p};r.renderAttachment(c,h.labelAttachment,v)}}}}catch(b){u.e(b)}finally{u.f()}r.regenerateAtlas()}}},{key:"renderAttachments",value:function(e,t){var r=this.internals,i=r.attachmentManager,o=r.attachmentProgram,s=r.nodeDataCache,l=r.nodesWithBackdrop,u=r.pixelRatio,d=r.nodeDataTexture;if(!(!i||!o)){var c=0;o.reallocateAttachments(l.size);var h=M(l),f;try{for(h.s();!(f=h.n()).done;){var g,m,p,v,b=f.value;if(this.displayedNodeLabels.has(b)){var y=s[b];if(!(!y||y.visibility==="hidden")&&!(t&&y.labelDepth!==t)&&y.labelAttachment){var _=i.getEntry(b,y.labelAttachment);if(_){var x=(g=d?.getIndex(b))!==null&&g!==void 0?g:-1;if(!(x<0)){var T=this.measureNodeLabel(y),R=T.width,E=T.height,S=T.textHeight,w=(m=wo[y.labelAttachmentPlacement||"below"])!==null&&m!==void 0?m:0;o.processAttachment(c,{nodeIndex:x,atlasX:_.x,atlasY:_.y,atlasW:_.width,atlasH:_.height,attachWidth:_.width/u,attachHeight:_.height/u,positionMode:(p=Bt[y.labelPosition||Ke.labelPosition])!==null&&p!==void 0?p:0,attachmentPlacement:w,labelWidth:R,labelHeight:E,textHeight:S,labelAngle:(v=y.labelAngle)!==null&&v!==void 0?v:0}),c++}}}}}}catch(F){h.e(F)}finally{h.f()}c!==0&&(o.reallocateAttachments(c),i.bindTexture(Rn),o.invalidateBuffers(),o.render(e))}}},{key:"computeDisplayedEdgeLabels",value:function(){var e=this.internals,t=e.graph,r=e.stateManager,i=e.settings,o=e.edgesWithForcedLabels,s=r.getHighlightedNodes(),l=i.edgeLabelAnchors==="allNodes"?new Set(this.edgeAnchorGrid.getLabelsToDisplay(this.internals.getCameraState().ratio,i.labelDensity)):this.displayedNodeLabels,u=r.hovered,d=Bh({graph:t,hoveredNode:u?.kind==="node"?u.key:null,displayedNodeLabels:l,highlightedNodes:s});lr(d,o),this.edgeLabelCandidates=d,this.displayedEdgeLabels=new Set}},{key:"filterEdgeLabelsForDepth",value:function(e){for(var t=this.internals,r=t.graph,i=t.nodeDataCache,o=t.edgeDataCache,s=[],l=new Set,u=0,d=this.edgeLabelCandidates.length;u<d;u++){var c=this.edgeLabelCandidates[u];if(!l.has(c)){l.add(c);var h=r.extremities(c),f=i[h[0]],g=i[h[1]],m=o[c];!m||!f||!g||m.visibility==="hidden"||m.labelVisibility==="hidden"||f.visibility==="hidden"||g.visibility==="hidden"||e&&m.labelDepth!==e||m.label&&s.push(c)}}return s}},{key:"renderEdgeLabels",value:function(e,t){var r=this.internals,i=r.graph,o=r.nodeDataCache,s=r.edgeDataCache,l=r.primitives,u=r.edgeLabelProgram,d=r.nodeDataTexture,c=r.edgeDataTexture;if(u){var h=this.filterEdgeLabelsForDepth(t),f=M(h),g;try{for(f.s();!(g=f.n()).done;){var m=g.value;this.displayedEdgeLabels.add(m)}}catch(K){f.e(K)}finally{f.f()}if(h.length!==0){if(this.labelsDirty){var p,v,b=0,y=M(h),_;try{for(y.s();!(_=y.n()).done;){var x=_.value;b+=s[x].label.length}}catch(K){y.e(K)}finally{y.f()}u.reallocate(b);var T=(p=l==null||(v=l.edges)===null||v===void 0||(v=v.label)===null||v===void 0?void 0:v.margin)!==null&&p!==void 0?p:5,R="over",E=0,S=M(h),w;try{for(S.s();!(w=S.n()).done;){var F,D,P=w.value,L=i.extremities(P),I=L[0],z=L[1],G=o[I],k=o[z],C=s[P],N=d.getIndex(I),$=d.getIndex(z),H=c.getIndex(P),Z={text:C.label,x:(G.x+k.x)/2,y:(G.y+k.y)/2,size:cs,color:C.labelColor,nodeSize:0,nodeIndex:-1,margin:T,position:(F=C.labelPosition)!==null&&F!==void 0?F:R,hidden:!1,forceLabel:Ze(C),type:"default",zIndex:(D=C.zIndex)!==null&&D!==void 0?D:0,parentType:"edge",parentKey:P,fontKey:"",labelAngle:0,sourceX:G.x,sourceY:G.y,targetX:k.x,targetY:k.y,sourceSize:G.size,targetSize:k.size,sourceShape:G.shape||"circle",targetShape:k.shape||"circle",edgeSize:C.size,offset:0,edgeAttributes:C,sourceNodeIndex:N,targetNodeIndex:$,edgeIndex:H},X=u.processEdgeLabel(P,E,Z);E+=X}}catch(K){S.e(K)}finally{S.f()}u.invalidateBuffers()}u.render(e)}}}},{key:"renderEdgeLabelBackgrounds",value:function(e,t){var r,i,o=this.internals,s=o.edgeLabelBackgroundProgram,l=o.edgeLabelProgram,u=o.edgeDataCache,d=o.primitives,c=o.edgeDataTexture;if(!(!c||!l||!s)){var h=xe.edgeLabel.writesPickingThisFrame(this.internals),f=(r=d==null||(i=d.edges)===null||i===void 0||(i=i.label)===null||i===void 0?void 0:i.margin)!==null&&r!==void 0?r:5,g="over",m=this.filterEdgeLabelsForDepth(t),p=[],v=M(m),b;try{for(v.s();!(b=v.n()).done;){var y=b.value;!h&&!u[y].labelBackgroundColor||p.push(y)}}catch(G){v.e(G)}finally{v.f()}if(p.length!==0){s.reallocate(p.length);for(var _=0;_<p.length;_++){var x,T,R,E=p[_],S=u[E],w=S.label,F=l.measureLabelAtlasWidth(w),D=(x=S.labelPosition)!==null&&x!==void 0?x:g,P=typeof D=="string"&&(T=Hh[D])!==null&&T!==void 0?T:0,L=_t(this.internals.pickingState,"edgeLabel",E)||_t(this.internals.pickingState,"edge",E),I=S.labelBackgroundColor?Pe(S.labelBackgroundColor):Pe("transparent"),z={edgeIndex:c.getIndex(E),baseFontSize:cs,totalTextWidth:F,positionMode:P,margin:f,padding:(R=S.labelBackgroundPadding)!==null&&R!==void 0?R:$h,color:I,id:It(L),edgeAttributes:S};s.processEdgeLabelBackground(_,E,z)}s.invalidateBuffers(),s.render(e)}}}}])}(),qh=function(){function a(n,e,t,r){Q(this,a),A(this,"nodeStates",new Map),A(this,"edgeStates",new Map),A(this,"hovered",null),A(this,"dirtyNodes",new Set),A(this,"dirtyEdges",new Set),A(this,"graphStateChanged",!1),A(this,"graphStateFlagsDirty",!1),this.scheduleRefresh=n,this.customNodeStateDefaults=e,this.customEdgeStateDefaults=t,this.customGraphStateDefaults=r,this.graphState=tr(r)}return J(a,[{key:"getNodeState",value:function(e){e=""+e;var t=this.nodeStates.get(e);return t||(t=Ji(this.customNodeStateDefaults),this.nodeStates.set(e,t)),t}},{key:"getEdgeState",value:function(e){e=""+e;var t=this.edgeStates.get(e);return t||(t=eo(this.customEdgeStateDefaults),this.edgeStates.set(e,t)),t}},{key:"getGraphState",value:function(){return this.flushGraphStateFlags(),this.graphState}},{key:"getHighlightedNodes",value:function(){var e=new Set,t=M(this.nodeStates),r;try{for(t.s();!(r=t.n()).done;){var i=te(r.value,2),o=i[0],s=i[1];s.isHighlighted&&e.add(o)}}catch(l){t.e(l)}finally{t.f()}return e}},{key:"setNodeState",value:function(e,t){e=""+e;var r=this.getNodeState(e);if(Mt(r,t)){var i=O(O({},r),t);this.nodeStates.set(e,i),this.dirtyNodes.add(e),this.updateHoveredNodeTracking(e,r,i),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}}},{key:"setEdgeState",value:function(e,t){e=""+e;var r=this.getEdgeState(e);if(Mt(r,t)){var i=O(O({},r),t);this.edgeStates.set(e,i),this.dirtyEdges.add(e),this.updateHoveredEdgeTracking(e,r,i),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}}},{key:"setGraphState",value:function(e){if(Mt(this.graphState,e)){var t=O(O({},this.graphState),e);t.isIdle=!t.isPanning&&!t.isZooming&&!t.isDragging,this.graphState=t,this.graphStateChanged=!0,this.scheduleRefresh()}}},{key:"setNodesState",value:function(e,t){var r=!1,i=M(e),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;s=""+s;var l=this.getNodeState(s);if(Mt(l,t)){var u=O(O({},l),t);this.nodeStates.set(s,u),this.dirtyNodes.add(s),this.updateHoveredNodeTracking(s,l,u),r=!0}}}catch(d){i.e(d)}finally{i.f()}r&&(this.graphStateFlagsDirty=!0,this.scheduleRefresh())}},{key:"setEdgesState",value:function(e,t){var r=!1,i=M(e),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;s=""+s;var l=this.getEdgeState(s);if(Mt(l,t)){var u=O(O({},l),t);this.edgeStates.set(s,u),this.dirtyEdges.add(s),this.updateHoveredEdgeTracking(s,l,u),r=!0}}}catch(d){i.e(d)}finally{i.f()}r&&(this.graphStateFlagsDirty=!0,this.scheduleRefresh())}},{key:"markNodesDirty",value:function(e){var t=M(e),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;this.dirtyNodes.add(i)}}catch(o){t.e(o)}finally{t.f()}this.scheduleRefresh()}},{key:"removeNode",value:function(e){this.nodeStates.delete(e),this.dirtyNodes.delete(e),this.clearHoveredFor("node",e),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}},{key:"removeEdge",value:function(e){this.edgeStates.delete(e),this.dirtyEdges.delete(e),this.clearHoveredFor("edge",e),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}},{key:"pruneNodes",value:function(e){var t=M(this.nodeStates.keys()),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;e(i)||this.removeNode(i)}}catch(o){t.e(o)}finally{t.f()}}},{key:"pruneEdges",value:function(e){var t=M(this.edgeStates.keys()),r;try{for(t.s();!(r=t.n()).done;){var i=r.value;e(i)||this.removeEdge(i)}}catch(o){t.e(o)}finally{t.f()}}},{key:"clearNodes",value:function(){this.nodeStates.clear(),this.dirtyNodes.clear(),this.clearHoveredForKinds(Fa("node")),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}},{key:"clearEdges",value:function(){this.edgeStates.clear(),this.dirtyEdges.clear(),this.clearHoveredForKinds(Fa("edge")),this.graphStateFlagsDirty=!0,this.scheduleRefresh()}},{key:"resetGraphState",value:function(){this.graphState=tr(this.customGraphStateDefaults),this.graphStateChanged=!1,this.graphStateFlagsDirty=!1}},{key:"clearDirtyTracking",value:function(){this.dirtyNodes.clear(),this.dirtyEdges.clear(),this.graphStateChanged=!1}},{key:"setHovered",value:function(e){this.hovered=e}},{key:"clearHoveredFor",value:function(e,t){this.hovered&&this.hovered.key===t&&Fa(e).includes(this.hovered.kind)&&(this.hovered=null)}},{key:"clearHoveredForKinds",value:function(e){this.hovered&&e.includes(this.hovered.kind)&&(this.hovered=null)}},{key:"updateGraphStateFromNodes",value:function(){var e,t=!1,r=!1,i=!1,o=M(this.nodeStates),s;try{for(o.s();!(s=o.n()).done;){var l=te(s.value,2),u=l[1];if(u.isHovered&&(t=!0),u.isHighlighted&&(r=!0),u.isDragged&&(i=!0),t&&r&&i)break}}catch(c){o.e(c)}finally{o.f()}!t&&((e=this.hovered)===null||e===void 0?void 0:e.kind)==="edge"&&(t=!0);var d=!this.graphState.isPanning&&!this.graphState.isZooming&&!i;(this.graphState.hasHovered!==t||this.graphState.hasHighlighted!==r||this.graphState.isDragging!==i||this.graphState.isIdle!==d)&&(this.graphStateChanged=!0),this.graphState=O(O({},this.graphState),{},{hasHovered:t,hasHighlighted:r,isDragging:i,isIdle:d})}},{key:"updateGraphStateFromEdges",value:function(){var e,t=((e=this.hovered)===null||e===void 0?void 0:e.kind)==="node";if(!t){var r=M(this.edgeStates),i;try{for(r.s();!(i=r.n()).done;){var o=te(i.value,2),s=o[1];if(s.isHovered){t=!0;break}}}catch(l){r.e(l)}finally{r.f()}}this.graphState.hasHovered!==t&&(this.graphStateChanged=!0),this.graphState=O(O({},this.graphState),{},{hasHovered:t})}},{key:"flushGraphStateFlags",value:function(){this.graphStateFlagsDirty&&(this.updateGraphStateFromNodes(),this.updateGraphStateFromEdges(),this.graphStateFlagsDirty=!1)}},{key:"updateHoveredNodeTracking",value:function(e,t,r){var i;if(t.isHovered!==r.isHovered)if(r.isHovered){var o;if(((o=this.hovered)===null||o===void 0?void 0:o.kind)==="node"&&this.hovered.key!==e){var s=this.hovered.key,l=this.getNodeState(s);this.nodeStates.set(s,O(O({},l),{},{isHovered:!1})),this.dirtyNodes.add(s)}this.hovered={kind:"node",key:e}}else((i=this.hovered)===null||i===void 0?void 0:i.kind)==="node"&&this.hovered.key===e&&(this.hovered=null)}},{key:"updateHoveredEdgeTracking",value:function(e,t,r){var i;if(t.isHovered!==r.isHovered)if(r.isHovered){var o;if(((o=this.hovered)===null||o===void 0?void 0:o.kind)==="edge"&&this.hovered.key!==e){var s=this.hovered.key,l=this.getEdgeState(s);this.edgeStates.set(s,O(O({},l),{},{isHovered:!1})),this.dirtyEdges.add(s)}this.hovered={kind:"edge",key:e}}else((i=this.hovered)===null||i===void 0?void 0:i.kind)==="edge"&&this.hovered.key===e&&(this.hovered=null)}}])}(),hs=1,fs=2,gs=3,vs=4,Xh=function(a){function n(e,t){var r,i,o,s,l,u=arguments.length>2&&arguments[2]!==void 0?arguments[2]:{};Q(this,n),l=le(this,n),A(l,"nodeReducer",null),A(l,"edgeReducer",null),A(l,"stageCanvas",null),A(l,"mouseLayer",null),A(l,"gestureHint",null),A(l,"extraElements",{}),A(l,"webGLContext",null),A(l,"pickingFrameBuffer",null),A(l,"pickingTexture",null),A(l,"pickingDepthBuffer",null),A(l,"activeListeners",{}),A(l,"nodeVariableEntries",[]),A(l,"edgeVariableEntries",[]),A(l,"edgePathsByName",new Map),A(l,"nodeProgramIndex",{}),A(l,"edgeProgramIndex",{}),A(l,"edgeTextureIndexCache",{}),A(l,"nodeGraphCoords",{}),A(l,"nodeExtent",{x:[0,1],y:[0,1]}),A(l,"matrix",Ce()),A(l,"invMatrix",Ce()),A(l,"correctionRatio",1),A(l,"frameId",0),A(l,"customBBox",null),A(l,"gpuTimerExt",void 0),A(l,"activeGpuTimerQuery",null),A(l,"pendingGpuTimerQueries",[]),A(l,"normalizationFunction",mn({x:[0,1],y:[0,1]})),A(l,"graphToViewportRatio",1),A(l,"pickingState",_h()),A(l,"prevNodeVisibilities",{}),A(l,"width",0),A(l,"height",0),A(l,"autoRescaleFrozen",!1),A(l,"stylesDeclaration",null),A(l,"resolvedStageStyle",{}),A(l,"renderFrame",null),A(l,"contextLost",!1),A(l,"pendingProcess","full"),A(l,"needToRefreshState",!1),A(l,"checkEdgesEventsFrame",null),A(l,"edgeStyleAnalysis",{dependency:"static",xAttribute:null,yAttribute:null}),A(l,"depthLayers",V(ia)),A(l,"customLayerPrograms",new Map),A(l,"nodeShapeSlug",null),A(l,"sdfAtlas",null),A(l,"depthRanges",{nodes:{},edges:{}}),A(l,"nodeBaseDepth",{}),A(l,"edgeBaseDepth",{});var d=u.primitives,c=u.styles,h=u.settings,f=h===void 0?{}:h,g=u.nodeReducer,m=u.edgeReducer,p=u.customNodeState,v=u.customEdgeState,b=u.customGraphState;l.stateManager=new qh(function(){return l.scheduleStateRefresh()},p,v,b);var y=d??ao;l.stylesDeclaration=c?{nodes:(r=c.nodes)!==null&&r!==void 0?r:sa.nodes,edges:(i=c.edges)!==null&&i!==void 0?i:sa.edges,stage:c.stage}:sa,l.nodeReducer=g??null,l.edgeReducer=m??null;var _=nr(l.stylesDeclaration.nodes);l.nodeReducer&&(_.dependency="graph-state"),l.edgeStyleAnalysis=nr(l.stylesDeclaration.edges),l.edgeReducer&&(l.edgeStyleAnalysis.dependency="graph-state"),l.stylesDeclaration.stage&&(l.resolvedStageStyle=sr(l.stylesDeclaration.stage,l.stateManager.graphState));var x=so(f);if(va(x),x.enableNodeDrag){var T=_.xAttribute,R=_.yAttribute;if((!T||!R)&&!x.dragPositionToAttributes)throw new Error('Sigma: `enableNodeDrag` is true but position attribute names could not be inferred from styles. Either use attribute bindings for x/y in your node styles (e.g. `x: { attribute: "x" }`), or provide a `dragPositionToAttributes` setting.')}if(dr(e),!(t instanceof HTMLElement))throw new Error("Sigma: container should be an html element.");l.container=t,l.edgeGroups=new xh(e,function(k,C){for(var N=0;N<k.length;N++){var $=l.stateManager.getEdgeState(k[N]);$.parallelIndex=N,$.parallelCount=C}});var E=new yh(e,l.viewportToGraph.bind(l),l.setNodesState.bind(l),function(k,C){return l.emit(k,C)});if(l.depthLayers=(o=y.depthLayers)!==null&&o!==void 0?o:V(ia),!(c!=null&&c.nodes)&&!aa.every(function(k){return l.depthLayers.includes(k)}))throw new Error("Sigma: depthLayers must include ".concat(aa.join(", ")," for the built-in node styles."));if(!(c!=null&&c.edges)&&!ra.every(function(k){return l.depthLayers.includes(k)}))throw new Error("Sigma: depthLayers must include ".concat(ra.join(", ")," for the built-in edge styles."));l.itemBuckets={nodes:new Ar(l.depthLayers),edges:new Ar(l.depthLayers)},l.initWebGLContext(),l.mouseLayer=Ot("div",{position:"absolute",touchAction:"none",userSelect:"none"},{class:"sigma-mouse"}),l.container.appendChild(l.mouseLayer),l.resolvedStageStyle.background&&(l.container.style.backgroundColor=l.resolvedStageStyle.background),l.resolvedStageStyle.cursor&&(l.container.style.cursor=l.resolvedStageStyle.cursor);var S=new Ko(l.webGLContext),w=new Dr(l.webGLContext,{channels:1}),F=new Zo(l.webGLContext),D=new Dr(l.webGLContext,{channels:4}),P=l.webGLContext,L=new Wh({gl:P,getFrameBuffer:function(){return l.pickingFrameBuffer},getPixelRatio:function(){return l.internals.pixelRatio},getDownSizingRatio:function(){return l.internals.settings.pickingDownSizingRatio},isRenderPending:function(){return l.renderFrame!==null},onIndex:function(C,N){var $;return ys(l.internals,($=l.pickingState.lookup[C])!==null&&$!==void 0?$:null,N)}}),I=l.initPrograms(y,x),z=y==null||(s=y.nodes)===null||s===void 0?void 0:s.labelAttachments,G=null;return z&&Object.keys(z).length>0&&(G=new Yo(P,z,function(){return l.scheduleRender()})),l.internals=O(O({nodeDataCache:{},edgeDataCache:{},nodesWithForcedLabels:new Set,nodesWithBackdrop:new Set,edgesWithForcedLabels:new Set,settings:x,primitives:y,pixelRatio:bn(),graph:e,stateManager:l.stateManager,dragManager:E,hoverResolver:L,nodeStyleAnalysis:_,pickingState:l.pickingState},I),{},{attachmentManager:G,nodeDataTexture:S,nodeFrameTexture:w,edgeDataTexture:F,edgeFrameTexture:D,getDimensions:function(){return l.getDimensions()},getGraphDimensions:function(){return l.getGraphDimensions()},getStagePadding:function(){return l.getStagePadding()},getCameraState:function(){return l.camera.getState()},getHitAtPosition:function(C){return l.getHitAtPosition(C)},setNodeState:function(C,N){return l.setNodeState(C,N)},setEdgeState:function(C,N){return l.setEdgeState(C,N)},updateContainerCursor:function(){return l.updateContainerCursor()},scheduleRefresh:function(){return l.scheduleRefresh()},viewportToFramedGraph:function(C){return l.viewportToFramedGraph(C)},viewportToGraph:function(C){return l.viewportToGraph(C)},framedGraphToViewport:function(C){return l.framedGraphToViewport(C)},scaleSize:function(C){return l.scaleSize(C)},emit:function(C,N){return l.emit(C,N)}}),l.labelRenderer=new Vh(l.internals),l.resize(),l.initializeWebGLLabels(),l.camera=new es,l.bindCameraHandlers(),l.mouseCaptor=new vh(l.mouseLayer,l),l.mouseCaptor.setSettings(l.internals.settings),l.touchCaptor=new bh(l.mouseLayer,l),l.touchCaptor.setSettings(l.internals.settings),l.bindEventHandlers(),l.bindGraphHandlers(),l.handleSettingsUpdate(),l.refresh(),l}return ue(n,a),J(n,[{key:"initializeWebGLLabels",value:function(){this.sdfAtlas=new pt,this.sdfAtlas.registerFont({family:"sans-serif",weight:"normal",style:"normal"})}},{key:"resetWebGLTexture",value:function(){var t=this.webGLContext;if(!this.pickingFrameBuffer)return this;var r=Math.ceil(this.width*this.internals.pixelRatio/this.internals.settings.pickingDownSizingRatio),i=Math.ceil(this.height*this.internals.pixelRatio/this.internals.settings.pickingDownSizingRatio);t.bindFramebuffer(t.FRAMEBUFFER,this.pickingFrameBuffer),this.pickingTexture&&t.deleteTexture(this.pickingTexture);var o=t.createTexture();o&&(t.bindTexture(t.TEXTURE_2D,o),t.texImage2D(t.TEXTURE_2D,0,t.RGBA,r,i,0,t.RGBA,t.UNSIGNED_BYTE,null),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MIN_FILTER,t.NEAREST),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MAG_FILTER,t.NEAREST),t.framebufferTexture2D(t.FRAMEBUFFER,t.COLOR_ATTACHMENT0,t.TEXTURE_2D,o,0),this.pickingTexture=o),this.pickingDepthBuffer&&t.deleteRenderbuffer(this.pickingDepthBuffer);var s=t.createRenderbuffer();return s&&(t.bindRenderbuffer(t.RENDERBUFFER,s),t.renderbufferStorage(t.RENDERBUFFER,t.DEPTH_COMPONENT16,r,i),t.framebufferRenderbuffer(t.FRAMEBUFFER,t.DEPTH_ATTACHMENT,t.RENDERBUFFER,s),this.pickingDepthBuffer=s),t.bindFramebuffer(t.FRAMEBUFFER,null),this}},{key:"bindCameraHandlers",value:function(){var t=this;return this.activeListeners.camera=function(){t.refreshMatrices(),t.labelRenderer.labelsDirty=!0,t.scheduleRender()},this.activeListeners.cameraAnimationStart=function(r){var i=r.from,o=r.to;i.ratio!==o.ratio&&t.stateManager.setGraphState({isZooming:!0})},this.activeListeners.cameraAnimationEnd=function(){t.stateManager.setGraphState({isZooming:!1})},this.camera.on("updated",this.activeListeners.camera),this.camera.on("animationStart",this.activeListeners.cameraAnimationStart),this.camera.on("animationEnd",this.activeListeners.cameraAnimationEnd),this}},{key:"unbindCameraHandlers",value:function(){return this.camera.removeListener("updated",this.activeListeners.camera),this.camera.removeListener("animationStart",this.activeListeners.cameraAnimationStart),this.camera.removeListener("animationEnd",this.activeListeners.cameraAnimationEnd),this}},{key:"getHitAtPosition",value:function(t){var r;if(this.contextLost)return null;var i=this.webGLContext;i.bindFramebuffer(i.FRAMEBUFFER,this.pickingFrameBuffer);var o=Ni(i,this.pickingFrameBuffer,t.x,t.y,this.internals.pixelRatio,this.internals.settings.pickingDownSizingRatio),s=ja.apply(void 0,V(o));return(r=this.pickingState.lookup[s])!==null&&r!==void 0?r:null}},{key:"bindEventHandlers",value:function(){return wh(this.internals,this.mouseCaptor,this.touchCaptor,this.activeListeners),this}},{key:"bindGraphHandlers",value:function(){var t=this;return Lh({graph:this.internals.graph,edgeGroups:this.edgeGroups,updateNode:this.updateNode.bind(this),removeNode:this.removeNode.bind(this),addEdge:this.addEdge.bind(this),updateEdge:this.updateEdge.bind(this),removeEdge:this.removeEdge.bind(this),clearEdgeState:this.clearEdgeState.bind(this),clearNodeState:this.clearNodeState.bind(this),clearEdgeIndices:this.clearEdgeIndices.bind(this),clearNodeIndices:this.clearNodeIndices.bind(this),refresh:this.refresh.bind(this),scheduleProcess:function(){t.pendingProcess="full",t.scheduleRender()},markNodesDirty:function(i){t.internals.nodeStyleAnalysis.dependency==="graph-state"&&t.stateManager.markNodesDirty(i)}},this.activeListeners),this}},{key:"unbindGraphHandlers",value:function(){Ch(this.internals.graph,this.activeListeners)}},{key:"getNodeShapeId",value:function(t){return this.internals.nodeShapeMap&&this.internals.nodeGlobalShapeIds&&t.shape&&t.shape in this.internals.nodeShapeMap?this.internals.nodeGlobalShapeIds[this.internals.nodeShapeMap[t.shape]]:Sn(t.shape||"circle")}},{key:"processNodes",value:function(){var t=this,r=this.internals.graph,i=this.internals.settings,o=this.getDimensions(),s=i.autoRescale,l=i.autoRescaleContent,u=this.nodeExtent;if(s===!1){var d=o.width,c=o.height;u={x:[-d/2,d/2],y:[-c/2,c/2]}}else(s!=="once"||!this.autoRescaleFrozen)&&(u=this.computeNodeExtent(),l!=="positions"&&!this.customBBox&&(u=Ih({extent:u,coords:this.nodeGraphCoords,nodeData:this.internals.nodeDataCache,dimensions:o,stagePadding:this.getStagePadding(),zoomToSizeRatioFunction:i.zoomToSizeRatioFunction,itemSizesReference:i.itemSizesReference,fitLabels:l==="labels",nodeLabelBox:function($,H){return t.labelRenderer.nodeLabelBox($,H)}})),s==="once"&&(this.autoRescaleFrozen=!0));this.nodeExtent=u,this.normalizationFunction=mn(this.customBBox||this.nodeExtent);var h=new es,f=at(h.getState(),o,this.getGraphDimensions(),this.getStagePadding());this.labelRenderer.labelGrid.resizeAndClear(o,i.labelGridCellSize),this.labelRenderer.edgeAnchorGrid.resizeAndClear(o,i.labelGridCellSize);var g=i.renderEdgeLabels&&i.edgeLabelAnchors==="allNodes",m=!1;Ca(this.pickingState,"node");for(var p=r.nodes(),v=0,b=p.length;v<b;v++){var y=p[v],_=this.internals.nodeDataCache[y],x=this.nodeGraphCoords[y];_.x=x.x,_.y=x.y,this.normalizationFunction.applyTo(_),_.visibility!==this.prevNodeVisibilities[y]&&(m=!0),typeof _.label=="string"&&_.visibility!=="hidden"&&_.labelVisibility!=="hidden"&&this.labelRenderer.labelGrid.add(y,_.size,this.framedGraphToViewport(_,{matrix:f})),g&&_.visibility!=="hidden"&&this.labelRenderer.edgeAnchorGrid.add(y,_.size,this.framedGraphToViewport(_,{matrix:f}))}this.labelRenderer.labelGrid.organize(),this.labelRenderer.edgeAnchorGrid.organize(),this.nodeProgram.reallocate(p.length);var T=0;this.depthRanges.nodes={},this.nodeBaseDepth={};var R=this.internals.nodeDataCache,E=M(this.depthLayers),S;try{for(E.s();!(S=E.n()).done;){var w=S.value,F=this.itemBuckets.nodes.getSorted(w,function(N){return R[N].zIndex});if(F.length!==0){this.depthRanges.nodes[w]=[{offset:T,count:F.length}];var D=M(F),P;try{for(D.s();!(P=D.n()).done;){var L=P.value;this.nodeBaseDepth[L]=w,is(this.pickingState,"node",L),this.addNodeToProgram(L,T++)}}catch(N){D.e(N)}finally{D.f()}}}}catch(N){E.e(N)}finally{E.f()}this.nodeProgram.invalidateBuffers();for(var I=0,z=p.length;I<z;I++)this.prevNodeVisibilities[p[I]]=this.internals.nodeDataCache[p[I]].visibility;this.labelRenderer.processWebGLLabels(p);var G=M(this.customLayerPrograms.values()),k;try{for(G.s();!(k=G.n()).done;){var C=k.value.program;C.cacheData&&C.cacheData()}}catch(N){G.e(N)}finally{G.f()}return m}},{key:"processEdges",value:function(){var t=this.internals.graph,r=t.edges();this.edgeProgram.reallocate(r.length);var i=0;Ca(this.pickingState,"edge"),this.depthRanges.edges={},this.edgeBaseDepth={};var o=this.internals.edgeDataCache,s=M(this.depthLayers),l;try{for(s.s();!(l=s.n()).done;){var u=l.value,d=this.itemBuckets.edges.getSorted(u,function(g){return o[g].zIndex});if(d.length!==0){this.depthRanges.edges[u]=[{offset:i,count:d.length}];var c=M(d),h;try{for(c.s();!(h=c.n()).done;){var f=h.value;this.edgeBaseDepth[f]=u,is(this.pickingState,"edge",f),this.addEdgeToProgram(f,i++)}}catch(g){c.e(g)}finally{c.f()}}}}catch(g){s.e(g)}finally{s.f()}this.edgeProgram.invalidateBuffers()}},{key:"updateNodeDepthRanges",value:function(t,r,i){var o=this.nodeProgramIndex[t];o!==void 0&&(ha(this.depthRanges.nodes,r,o),fa(this.depthRanges.nodes,i,o))}},{key:"updateEdgeDepthRanges",value:function(t,r,i){var o=this.edgeProgramIndex[t];o!==void 0&&(ha(this.depthRanges.edges,r,o),fa(this.depthRanges.edges,i,o))}},{key:"handleSettingsUpdate",value:function(){var t=this,r=this.internals.settings;return this.camera.minRatio=r.minCameraRatio,this.camera.maxRatio=r.maxCameraRatio,this.camera.enabledZooming=r.enableCameraZooming,this.camera.enabledPanning=r.enableCameraPanning,this.camera.enabledRotation=r.enableCameraRotation,r.cameraPanBoundaries?this.camera.constrainState=function(i){return t.cleanCameraState(i,r.cameraPanBoundaries&&ee(r.cameraPanBoundaries)==="object"?r.cameraPanBoundaries:{})}:this.camera.constrainState=null,this.camera.setState(this.camera.getState()),this.mouseLayer.style.touchAction=r.gestureTarget==="graph"?"none":r.gestureTarget==="shared"?"pan-x pan-y":"auto",r.gestureTarget!=="shared"&&this.gestureHint&&(this.gestureHint.kill(),this.gestureHint=null),this.mouseCaptor.setSettings(this.internals.settings),this.touchCaptor.setSettings(this.internals.settings),this}},{key:"cleanCameraState",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{},i=r.tolerance,o=i===void 0?0:i,s=r.boundaries,l=O({},t),u=s||this.nodeExtent,d=te(u.x,2),c=d[0],h=d[1],f=te(u.y,2),g=f[0],m=f[1],p=[this.graphToViewport({x:c,y:g},{cameraState:t}),this.graphToViewport({x:h,y:g},{cameraState:t}),this.graphToViewport({x:c,y:m},{cameraState:t}),this.graphToViewport({x:h,y:m},{cameraState:t})],v=1/0,b=-1/0,y=1/0,_=-1/0;p.forEach(function(L){var I=L.x,z=L.y;v=Math.min(v,I),b=Math.max(b,I),y=Math.min(y,z),_=Math.max(_,z)});var x=b-v,T=_-y,R=this.getDimensions(),E=R.width,S=R.height,w=0,F=0;if(x>=E?b<E-o?w=b-(E-o):v>o&&(w=v-o):b>E+o?w=b-(E+o):v<-o&&(w=v+o),T>=S?_<S-o?F=_-(S-o):y>o&&(F=y-o):_>S+o?F=_-(S+o):y<-o&&(F=y+o),w||F){var D=this.viewportToFramedGraph({x:0,y:0},{cameraState:t}),P=this.viewportToFramedGraph({x:w,y:F},{cameraState:t});w=P.x-D.x,F=P.y-D.y,l.x+=w,l.y+=F}return l}},{key:"refreshMatrices",value:function(){var t=this.camera.getState(),r=this.getDimensions(),i=this.getGraphDimensions(),o=this.getStagePadding();this.matrix=at(t,r,i,o),this.invMatrix=at(t,r,i,o,!0),this.correctionRatio=Fi(this.matrix,t,r),this.graphToViewportRatio=this.getGraphToViewportRatio()}},{key:"processData",value:function(){var t;this.emit("beforeProcess"),(t=this.internals.attachmentManager)===null||t===void 0||t.clear();var r=O({},this.pickingState.idsByKind),i=this.processNodes();(this.pendingProcess==="full"||i)&&this.processEdges(),Th(this.pickingState,this.internals),Sh(r,this.pickingState.idsByKind)||this.internals.hoverResolver.invalidate(),this.pendingProcess="none",this.emit("afterProcess")}},{key:"render",value:function(){var t=this;if(this.contextLost)return this;this.emit("beforeRender");var r=function(){return t.internals.hoverResolver.frameRendered(),t.emit("afterRender"),t};if(this.renderFrame&&(cancelAnimationFrame(this.renderFrame),this.renderFrame=null),this.resize(),(this.pendingProcess!=="none"||this.needToRefreshState)&&(this.labelRenderer.labelsDirty=!0),this.pendingProcess!=="none"&&this.processData(),this.needToRefreshState&&this.refreshState(),this.needToRefreshState=!1,this.stateManager.clearDirtyTracking(),this.pendingProcess!=="none"&&this.processData(),this.clear(),this.resetWebGLTexture(),!this.internals.graph.order)return r();var i=this.mouseCaptor,o=this.camera.isAnimating()||i.isMoving||i.draggedEvents||i.currentWheelDirection;if(this.refreshMatrices(),this.frameId++,this.internals.settings.renderEdgeLabels&&!this.internals.edgeLabelProgram){var s=this.createEdgeLabelPrograms(),l=s.labelProgram,u=s.labelBackgroundProgram;this.internals.edgeLabelProgram=l,this.internals.edgeLabelBackgroundProgram=u}var d=this.internals.settings.DEBUG_logRenderStats?this.getDebugPrograms():null;d&&d.forEach(function(K){return K.resetDebugStats()}),this.internals.settings.DEBUG_gpuTimerQueries&&this.beginGpuTimerQuery(),this.internals.nodeFrameTexture.ensureCapacity(this.internals.nodeDataTexture.getCapacity()),this.internals.edgeFrameTexture.ensureCapacity(this.internals.edgeDataTexture.getCapacity());var c=this.getRenderParams(),h=xe.edge.writesPickingThisFrame(this.internals)?c:O(O({},c),{},{pickingFrameBuffer:null});this.labelRenderer.resetFrame();var f=this.webGLContext,g=Math.ceil(this.width*this.internals.pixelRatio/this.internals.settings.pickingDownSizingRatio),m=Math.ceil(this.height*this.internals.pixelRatio/this.internals.settings.pickingDownSizingRatio);if(f.bindFramebuffer(f.FRAMEBUFFER,this.pickingFrameBuffer),f.viewport(0,0,g,m),f.clear(f.COLOR_BUFFER_BIT|f.DEPTH_BUFFER_BIT),f.bindFramebuffer(f.FRAMEBUFFER,null),f.viewport(0,0,this.width*this.internals.pixelRatio,this.height*this.internals.pixelRatio),f.clear(f.COLOR_BUFFER_BIT|f.DEPTH_BUFFER_BIT),this.internals.nodeDataTexture.upload(),this.internals.edgeDataTexture.upload(),this.nodeProgram.uploadLayerTexture(),this.edgeProgram.uploadAttributeTexture(),this.emit("afterTexturesUpload"),this.internals.nodeDataTexture.bind(gs),this.internals.edgeDataTexture.bind(vs),this.edgeFramePass.run(c,this.internals.edgeFrameTexture,this.internals.edgeDataTexture.getHighWaterMark(),this.edgeProgram.getAttributeTexture(),this.nodeProgram.getAttributeTexture()),this.internals.edgeFrameTexture.bind(hs),this.internals.settings.renderLabels){this.labelRenderer.computeDisplayedNodeLabels();var p=this.labelRenderer.buildFramePassPoints(),v=p.data,b=p.count;this.nodeFramePass.run(v,b,this.internals.nodeFrameTexture,c,this.nodeProgram.getAttributeTexture()),this.internals.nodeFrameTexture.bind(fs)}this.internals.settings.renderEdgeLabels&&this.labelRenderer.computeDisplayedEdgeLabels();var y=M(this.customLayerPrograms.values()),_;try{for(y.s();!(_=y.n()).done;){var x=_.value.program;x.preRender&&x.preRender(c)}}catch(K){y.e(K)}finally{y.f()}f.bindFramebuffer(f.FRAMEBUFFER,null),f.viewport(0,0,this.width*this.internals.pixelRatio,this.height*this.internals.pixelRatio),f.blendFunc(f.ONE,f.ONE_MINUS_SRC_ALPHA);var T=!this.internals.settings.hideLabelsOnMove||!o,R=M(this.depthLayers),E;try{for(R.s();!(E=R.n()).done;){var S=E.value,w=M(this.customLayerPrograms.values()),F;try{for(w.s();!(F=w.n()).done;){var D=F.value;D.depth===S&&D.program.render(c)}}catch(K){w.e(K)}finally{w.f()}var P=this.depthRanges.edges[S];if(P&&(!this.internals.settings.hideEdgesOnMove||!o)){var L=M(P),I;try{for(L.s();!(I=L.n()).done;){var z=I.value,G=z.offset,k=z.count;k>0&&this.edgeProgram.render(h,G,k)}}catch(K){L.e(K)}finally{L.f()}}this.internals.settings.renderEdgeLabels&&T&&(this.labelRenderer.renderEdgeLabelBackgrounds(xe.edgeLabel.writesPickingThisFrame(this.internals)?c:O(O({},c),{},{pickingFrameBuffer:null}),S),this.labelRenderer.renderEdgeLabels(c,S)),this.labelRenderer.cacheAttachments(S),this.labelRenderer.renderBackdrops(O(O({},c),{},{pickingFrameBuffer:null}),S);var C=this.depthRanges.nodes[S];if(C){var N=M(C),$;try{for(N.s();!($=N.n()).done;){var H=$.value,Z=H.offset,X=H.count;X>0&&this.nodeProgram.render(c,Z,X)}}catch(K){N.e(K)}finally{N.f()}}T&&(this.labelRenderer.renderAttachments(O(O({},c),{},{pickingFrameBuffer:null}),S),this.labelRenderer.renderLabelBackgrounds(xe.nodeLabel.writesPickingThisFrame(this.internals)?c:O(O({},c),{},{pickingFrameBuffer:null}),S),this.internals.settings.renderLabels&&this.labelRenderer.renderWebGLLabels(c,S))}}catch(K){R.e(K)}finally{R.f()}return this.labelRenderer.labelsDirty=!1,this.internals.settings.DEBUG_displayPickingLayer&&(f.bindFramebuffer(f.READ_FRAMEBUFFER,this.pickingFrameBuffer),f.bindFramebuffer(f.DRAW_FRAMEBUFFER,null),f.blitFramebuffer(0,0,g,m,0,0,this.width*this.internals.pixelRatio,this.height*this.internals.pixelRatio,f.COLOR_BUFFER_BIT,f.NEAREST)),this.internals.settings.DEBUG_gpuTimerQueries&&this.endGpuTimerQuery(),this.pollGpuTimerQueries(),d&&this.logRenderStats(d),r()}},{key:"getDebugPrograms",value:function(){return[this.nodeProgram,this.edgeProgram,this.internals.labelProgram,this.internals.edgeLabelProgram,this.internals.edgeLabelBackgroundProgram,this.internals.backdropProgram,this.internals.labelBackgroundProgram,this.internals.attachmentProgram].filter(function(t){return t!==null})}},{key:"logRenderStats",value:function(t){var r={},i=M(t),o;try{for(i.s();!(o=i.n()).done;){var s=o.value;r[s.constructor.name]=O({},s.debugStats)}}catch(l){i.e(l)}finally{i.f()}console.log("[sigma] DEBUG_logRenderStats: frame #".concat(this.frameId)),console.table(r)}},{key:"getGpuTimerExtension",value:function(){return this.gpuTimerExt===void 0&&(this.gpuTimerExt=this.webGLContext.getExtension("EXT_disjoint_timer_query_webgl2"),this.gpuTimerExt||console.warn("Sigma: DEBUG_gpuTimerQueries is enabled, but this browser/driver doesn't support EXT_disjoint_timer_query_webgl2.")),this.gpuTimerExt}},{key:"beginGpuTimerQuery",value:function(){var t=this.getGpuTimerExtension();if(t){var r=this.webGLContext,i=r.createQuery();i&&(r.beginQuery(t.TIME_ELAPSED_EXT,i),this.activeGpuTimerQuery=i)}}},{key:"endGpuTimerQuery",value:function(){!this.gpuTimerExt||!this.activeGpuTimerQuery||(this.webGLContext.endQuery(this.gpuTimerExt.TIME_ELAPSED_EXT),this.pendingGpuTimerQueries.push({query:this.activeGpuTimerQuery,frameId:this.frameId}),this.activeGpuTimerQuery=null)}},{key:"pollGpuTimerQueries",value:function(){if(this.pendingGpuTimerQueries.length!==0){var t=this.webGLContext,r=this.gpuTimerExt;if(!r){this.pendingGpuTimerQueries.forEach(function(c){var h=c.query;return t.deleteQuery(h)}),this.pendingGpuTimerQueries=[];return}var i=t.getParameter(r.GPU_DISJOINT_EXT),o=[],s=M(this.pendingGpuTimerQueries),l;try{for(s.s();!(l=s.n()).done;){var u=l.value;if(!t.getQueryParameter(u.query,t.QUERY_RESULT_AVAILABLE)){o.push(u);continue}if(!i){var d=t.getQueryParameter(u.query,t.QUERY_RESULT);console.log("[sigma] DEBUG_gpuTimerQueries: frame #".concat(u.frameId," GPU time = ").concat((d/1e6).toFixed(2),"ms"))}t.deleteQuery(u.query)}}catch(c){s.e(c)}finally{s.f()}this.pendingGpuTimerQueries=o}}},{key:"postEvaluateNode",value:function(t,r,i){var o=t;o.x===void 0&&(o.x=r.x),o.y===void 0&&(o.y=r.y),t.highlighted=i.isHighlighted;for(var s=0,l=this.nodeVariableEntries.length;s<l;s++){var u,d,c=te(this.nodeVariableEntries[s],2),h=c[0],f=c[1];o[h]=(u=(d=o[h])!==null&&d!==void 0?d:r[h])!==null&&u!==void 0?u:f.default}}},{key:"addNode",value:function(t){var r=this.internals.graph.getNodeAttributes(t),i=this.stateManager.getNodeState(t),o=this.internals.nodeDataCache[t]||{};if(ir(this.stylesDeclaration.nodes,r,i,this.stateManager.graphState,this.internals.graph,o),this.postEvaluateNode(o,r,i),this.nodeReducer){var s=this.nodeReducer(t,o,r,i,this.stateManager.graphState,this.internals.graph);o=O(O({},o),s)}if(typeof o.x!="number"||typeof o.y!="number")throw new Error('Sigma: could not find a valid position (x, y) for node "'.concat(t,'". ')+"Provide coordinates via node attributes, styles, or a nodeReducer.");this.internals.nodeShapeMap?(!o.shape||!(o.shape in this.internals.nodeShapeMap))&&(o.shape=Object.keys(this.internals.nodeShapeMap)[0]):this.nodeShapeSlug&&(o.shape=this.nodeShapeSlug),this.internals.nodeDataCache[t]=o,this.nodeGraphCoords[t]={x:o.x,y:o.y},vt(this.internals.nodesWithForcedLabels,t,Ze(o)),vt(this.internals.nodesWithBackdrop,t,ca(o)),this.itemBuckets.nodes.set(t,o.depth)}},{key:"updateNode",value:function(t){this.addNode(t);var r=this.internals.nodeDataCache[t];this.normalizationFunction.applyTo(r)}},{key:"removeNode",value:function(t){os(this.pickingState,"node",t),this.itemBuckets.nodes.remove(t),delete this.internals.nodeDataCache[t],delete this.nodeGraphCoords[t],delete this.nodeProgramIndex[t],this.internals.nodeDataTexture.free(t),this.internals.dragManager.removeNode(t),this.stateManager.removeNode(t),this.internals.nodesWithForcedLabels.delete(t),this.internals.nodesWithBackdrop.delete(t)}},{key:"postEvaluateEdge",value:function(t,r){for(var i=t,o=0,s=this.edgeVariableEntries.length;o<s;o++){var l,u,d=te(this.edgeVariableEntries[o],2),c=d[0],h=d[1];i[c]=(l=(u=i[c])!==null&&u!==void 0?u:r[c])!==null&&l!==void 0?l:h.default}}},{key:"applyEdgeSpread",value:function(t,r,i){var o;if(!(i.parallelCount<=1)){var s=this.internals.graph.source(t),l=this.internals.graph.target(t),u=s===l,d=u?r.selfLoopPath||r.path:r.parallelPath||r.path,c=d?this.edgePathsByName.get(d):void 0;if(c!=null&&c.spread){var h=(o=r.parallelSpread)!==null&&o!==void 0?o:.25,f=c.spread.compute(i.parallelIndex,i.parallelCount,h);!u&&this.internals.graph.isDirected(t)&&s>l&&(f=-f),r[c.spread.variable]=f}}}},{key:"addEdge",value:function(t){var r=this.internals.graph.getEdgeAttributes(t),i=this.stateManager.getEdgeState(t),o={};if(or(this.stylesDeclaration.edges,r,i,this.stateManager.graphState,this.internals.graph,o),this.postEvaluateEdge(o,r),this.edgeReducer){var s=this.edgeReducer(t,o,r,i,this.stateManager.graphState,this.internals.graph);o=O(O({},o),s)}this.applyEdgeSpread(t,o,i),this.internals.edgeDataCache[t]=o,vt(this.internals.edgesWithForcedLabels,t,Ze(o)),this.itemBuckets.edges.set(t,o.depth)}},{key:"updateEdge",value:function(t){this.addEdge(t)}},{key:"removeEdge",value:function(t){this.itemBuckets.edges.remove(t),delete this.internals.edgeDataCache[t],delete this.edgeProgramIndex[t],delete this.edgeTextureIndexCache[t],this.internals.edgeDataTexture.free(t),os(this.pickingState,"edge",t),this.stateManager.removeEdge(t),this.internals.edgesWithForcedLabels.delete(t)}},{key:"clearNodeIndices",value:function(){var t;this.labelRenderer.resetLabelGrid(),this.autoRescaleFrozen||(this.nodeExtent={x:[0,1],y:[0,1]}),this.internals.nodeDataCache={},this.nodeGraphCoords={},this.nodeProgramIndex={},(t=this.internals.nodeDataTexture)===null||t===void 0||t.clear(),this.internals.nodesWithForcedLabels.clear(),this.internals.nodesWithBackdrop.clear(),this.prevNodeVisibilities={},this.itemBuckets.nodes.clearAll(),this.depthRanges.nodes={},this.nodeBaseDepth={}}},{key:"clearEdgeIndices",value:function(){var t;this.internals.edgeDataCache={},this.edgeProgramIndex={},this.edgeTextureIndexCache={},(t=this.internals.edgeDataTexture)===null||t===void 0||t.clear(),this.internals.edgesWithForcedLabels.clear(),this.itemBuckets.edges.clearAll(),this.depthRanges.edges={},this.edgeBaseDepth={},this.edgeGroups.clear()}},{key:"clearIndices",value:function(){this.clearEdgeIndices(),this.clearNodeIndices()}},{key:"clearNodeState",value:function(){this.labelRenderer.resetFrame(),this.internals.nodesWithBackdrop.clear(),this.internals.dragManager.clear(),this.autoRescaleFrozen=!1,this.stateManager.clearNodes(),Ca(this.pickingState,"node")}},{key:"clearEdgeState",value:function(){this.labelRenderer.clearEdgeLabels(),this.stateManager.clearEdges(),Ca(this.pickingState,"edge")}},{key:"clearState",value:function(){this.clearEdgeState(),this.clearNodeState(),this.stateManager.resetGraphState()}},{key:"addNodeToProgram",value:function(t,r){var i,o=this.internals.nodeDataCache[t];this.internals.nodeDataTexture.allocate(t),(i=this.internals.nodeDataTexture).updateNode.apply(i,[t,o.x,o.y,o.size,this.getNodeShapeId(o)].concat(V(pn(o)),[o.color]));var s=this.internals.nodeDataTexture.getIndex(t);this.nodeProgram.process(_t(this.pickingState,"node",t),r,o,s),this.nodeProgramIndex[t]=r}},{key:"addEdgeToProgram",value:function(t,r){var i,o,s=this.internals.edgeDataCache[t],l=this.internals.graph.source(t),u=this.internals.graph.target(t),d=this.internals.edgeDataTexture.allocate(t);this.edgeTextureIndexCache[t]=d;var c=l===u,h=!c&&((i=(o=this.stateManager.getEdgeState(t))===null||o===void 0?void 0:o.parallelCount)!==null&&i!==void 0?i:1)>1,f=this.edgeProgram.resolveEdgeIds(s,c,h),g=f.pathId,m=f.headId,p=f.tailId,v=f.headLengthRatio,b=f.tailLengthRatio;this.internals.edgeDataTexture.updateEdge(t,this.internals.nodeDataTexture.getIndex(l),this.internals.nodeDataTexture.getIndex(u),s.size,v,b,g,m,p),this.edgeProgram.process(_t(this.pickingState,"edge",t),r,this.internals.nodeDataCache[l],this.internals.nodeDataCache[u],s,d),this.edgeProgramIndex[t]=r}},{key:"getRenderParams",value:function(){return{frameId:this.frameId,matrix:this.matrix,invMatrix:this.invMatrix,width:this.width,height:this.height,pixelRatio:this.internals.pixelRatio,zoomRatio:this.camera.ratio,cameraAngle:this.camera.angle,sizeRatio:1/this.scaleSize(),correctionRatio:this.correctionRatio,downSizingRatio:this.internals.settings.pickingDownSizingRatio,minEdgeThickness:this.internals.settings.minEdgeThickness,antiAliasingFeather:this.internals.settings.antiAliasingFeather,nodePickingPadding:this.internals.settings.nodePickingPadding,edgePickingPadding:this.internals.settings.edgePickingPadding,labelPickingPadding:this.internals.settings.labelPickingPadding,nodeDataTextureUnit:gs,nodeDataTextureWidth:this.internals.nodeDataTexture.getTextureWidth(),nodeFrameTextureUnit:fs,nodeFrameTextureWidth:this.internals.nodeFrameTexture.getTextureWidth(),edgeDataTextureUnit:vs,edgeDataTextureWidth:this.internals.edgeDataTexture.getTextureWidth(),edgeFrameTextureUnit:hs,edgeFrameTextureWidth:this.internals.edgeFrameTexture.getTextureWidth(),pickingFrameBuffer:this.pickingFrameBuffer,labelPixelSnapping:this.internals.settings.labelPixelSnapping?1:0}}},{key:"getStagePadding",value:function(){var t=this.internals.settings,r=t.stagePadding,i=t.autoRescale;return i&&r||0}},{key:"getLayerElement",value:function(t){if(t==="mouse")return this.mouseLayer;var r=this.extraElements[t];if(!r)throw new Error('Sigma: layer "'.concat(t,'" does not exist'));return r}},{key:"initWebGLContext",value:function(){var t=this,r=this.createWebGLContext("stage");this.stageCanvas=this.extraElements.stage,this.webGLContext=r,this.stageCanvas.addEventListener("webglcontextlost",function(i){t.webGLContext&&(i.preventDefault(),t.contextLost=!0,t.renderFrame&&(cancelAnimationFrame(t.renderFrame),t.renderFrame=null),t.gpuTimerExt=void 0,t.activeGpuTimerQuery=null,t.pendingGpuTimerQueries=[],t.emit("webglContextLost"))}),this.stageCanvas.addEventListener("webglcontextrestored",function(){requestAnimationFrame(function(){t.webGLContext&&!t.webGLContext.isContextLost()&&t.restoreWebGLContext()})}),this.initPickingFramebuffer()}},{key:"initPickingFramebuffer",value:function(){var t=this.webGLContext,r=t.createFramebuffer();if(!r)throw new Error("Sigma: cannot create picking frame buffer");t.bindFramebuffer(t.FRAMEBUFFER,r);var i=t.createTexture();if(!i)throw new Error("Sigma: cannot create picking texture");t.bindTexture(t.TEXTURE_2D,i),t.texImage2D(t.TEXTURE_2D,0,t.RGBA,1,1,0,t.RGBA,t.UNSIGNED_BYTE,null),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MIN_FILTER,t.NEAREST),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MAG_FILTER,t.NEAREST),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_S,t.CLAMP_TO_EDGE),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_T,t.CLAMP_TO_EDGE),t.framebufferTexture2D(t.FRAMEBUFFER,t.COLOR_ATTACHMENT0,t.TEXTURE_2D,i,0);var o=t.createRenderbuffer();if(!o)throw new Error("Sigma: cannot create picking depth buffer");if(t.bindRenderbuffer(t.RENDERBUFFER,o),t.renderbufferStorage(t.RENDERBUFFER,t.DEPTH_COMPONENT16,1,1),t.framebufferRenderbuffer(t.FRAMEBUFFER,t.DEPTH_ATTACHMENT,t.RENDERBUFFER,o),t.checkFramebufferStatus(t.FRAMEBUFFER)!==t.FRAMEBUFFER_COMPLETE)throw new Error("Sigma: picking framebuffer is not complete");t.bindFramebuffer(t.FRAMEBUFFER,null),this.pickingFrameBuffer=r,this.pickingTexture=i,this.pickingDepthBuffer=o}},{key:"initPrograms",value:function(t,r){var i=this,o=this.webGLContext,s=Ho(o,this.pickingFrameBuffer,i,t?.nodes,r.antialiasNodes),l=s.nodeProgram,u=s.labelProgram,d=s.backdropProgram,c=s.labelBackgroundProgram,h=s.attachmentProgram,f=s.framePass,g=s.shapeSlug,m=s.shapeNameToIndex,p=s.shapeGlobalIds,v=s.variables;this.nodeProgram=l,this.nodeFramePass=f,this.nodeVariableEntries=Object.entries(v),g&&(this.nodeShapeSlug=g);var b=$o(o,this.pickingFrameBuffer,i,t?.edges,r.antialiasEdges,t?.nodes),y=b.edgeProgram,_=b.createLabelPrograms,x=b.framePass,T=b.variables,R=b.paths;return this.createEdgeLabelPrograms=_,this.edgeProgram=y,this.edgeFramePass=x,this.edgeVariableEntries=Object.entries(T),this.edgePathsByName=new Map(R.map(function(E){return[E.name,E]})),{labelProgram:u,edgeLabelProgram:null,edgeLabelBackgroundProgram:null,backdropProgram:d,labelBackgroundProgram:c,attachmentProgram:h,nodeShapeMap:m??null,nodeGlobalShapeIds:p??null}}},{key:"restoreWebGLContext",value:function(){var t,r,i,o,s,l=this.internals;this.initPickingFramebuffer(),(t=l.nodeDataTexture)===null||t===void 0||t.restore(),(r=l.nodeFrameTexture)===null||r===void 0||r.restore(),(i=l.edgeDataTexture)===null||i===void 0||i.restore(),(o=l.edgeFrameTexture)===null||o===void 0||o.restore(),(s=l.attachmentManager)===null||s===void 0||s.restore(),l.hoverResolver.reset(),Object.assign(l,this.initPrograms(l.primitives,l.settings));var u=M(this.customLayerPrograms.values()),d;try{for(u.s();!(d=u.n()).done;){var c=d.value;c.program.kill(),c.program=c.factory(this.webGLContext)}}catch(h){u.e(h)}finally{u.f()}this.contextLost=!1,this.emit("webglContextRestored"),this.refresh()}},{key:"createLayer",value:function(t,r){var i=arguments.length>2&&arguments[2]!==void 0?arguments[2]:{};if(this.extraElements[t])throw new Error('Sigma: a layer named "'.concat(t,'" already exists'));var o=Ot(r,{position:"absolute"},{class:"sigma-".concat(t)});return i.style&&Object.assign(o.style,i.style),this.extraElements[t]=o,"beforeLayer"in i&&i.beforeLayer?this.getLayerElement(i.beforeLayer).before(o):"afterLayer"in i&&i.afterLayer?this.getLayerElement(i.afterLayer).after(o):this.container.appendChild(o),o}},{key:"createCanvas",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{};return this.createLayer(t,"canvas",r)}},{key:"createWebGLContext",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{},i=this.createCanvas(t,r);r.hidden&&i.remove();var o=i.getContext("webgl2",O({preserveDrawingBuffer:!1,antialias:!1,depth:!0},r));if(!o)throw new Error("Sigma: WebGL 2 is not supported by your browser. Please use a modern browser (Chrome 56+, Firefox 51+, Safari 15+, Edge 79+).");return o.blendFunc(o.ONE,o.ONE_MINUS_SRC_ALPHA),o}},{key:"killLayer",value:function(t){if(t==="stage"||t==="mouse")throw new Error('Sigma: cannot kill built-in layer "'.concat(t,'"'));var r=this.extraElements[t];if(!r)throw new Error("Sigma: cannot kill layer ".concat(t,", which does not exist"));return r.remove(),delete this.extraElements[t],this}},{key:"getWebGLContext",value:function(){if(!this.webGLContext)throw new Error("Sigma: WebGL context is not available");return this.webGLContext}},{key:"getNodeDataTexture",value:function(){if(!this.internals.nodeDataTexture)throw new Error("Sigma: node data texture is not available");return this.internals.nodeDataTexture}},{key:"getNormalizationFunction",value:function(){return this.normalizationFunction}},{key:"addCustomLayerProgram",value:function(t,r,i){var o;if(!this.depthLayers.includes(r))throw new Error('Sigma: cannot add custom layer program at depth "'.concat(r,'", ')+"it must be declared in primitives.depthLayers. Current layers: ".concat(this.depthLayers.join(", ")));(o=this.customLayerPrograms.get(t))===null||o===void 0||o.program.kill();var s=i(this.webGLContext);return this.customLayerPrograms.set(t,{depth:r,factory:i,program:s}),s.cacheData&&s.cacheData(),this.scheduleRender(),this}},{key:"removeCustomLayerProgram",value:function(t){var r=this.customLayerPrograms.get(t);return r&&(r.program.kill(),this.customLayerPrograms.delete(t),this.scheduleRender()),this}},{key:"getCamera",value:function(){return this.camera}},{key:"setCamera",value:function(t){return this.camera.cancelAnimation(),this.unbindCameraHandlers(),this.camera=t,this.bindCameraHandlers(),this.scheduleRender(),this}},{key:"getContainer",value:function(){return this.container}},{key:"getGraph",value:function(){return this.internals.graph}},{key:"setGraph",value:function(t){return t===this.internals.graph?this:(this.stateManager.pruneNodes(function(r){return t.hasNode(r)}),this.stateManager.pruneEdges(function(r){return t.hasEdge(r)}),this.unbindGraphHandlers(),this.checkEdgesEventsFrame!==null&&(cancelAnimationFrame(this.checkEdgesEventsFrame),this.checkEdgesEventsFrame=null),this.internals.graph=t,this.autoRescaleFrozen=!1,this.bindGraphHandlers(),this.refresh(),this)}},{key:"getMouseCaptor",value:function(){return this.mouseCaptor}},{key:"getTouchCaptor",value:function(){return this.touchCaptor}},{key:"getDimensions",value:function(){return{width:this.width,height:this.height}}},{key:"getGraphDimensions",value:function(){var t=this.customBBox||this.nodeExtent;return{width:t.x[1]-t.x[0]||1,height:t.y[1]-t.y[0]||1}}},{key:"getNodeDisplayData",value:function(t){var r=this.internals.nodeDataCache[t];return r?Object.assign({},r):void 0}},{key:"getEdgeDisplayData",value:function(t){var r=this.internals.edgeDataCache[t];return r?Object.assign({},r):void 0}},{key:"getNodeState",value:function(t){return this.stateManager.getNodeState(t)}},{key:"getEdgeState",value:function(t){return this.stateManager.getEdgeState(t)}},{key:"getGraphState",value:function(){return this.stateManager.getGraphState()}},{key:"setNodeState",value:function(t,r){return this.stateManager.setNodeState(t,r),this}},{key:"setEdgeState",value:function(t,r){return this.stateManager.setEdgeState(t,r),this}},{key:"setGraphState",value:function(t){return this.stateManager.setGraphState(t),this}},{key:"_setPanning",value:function(t){this.stateManager.setGraphState({isPanning:t})}},{key:"_setZooming",value:function(t){this.stateManager.setGraphState({isZooming:t})}},{key:"_hasNodeDrag",value:function(){var t=this.internals.dragManager;return!!(t.pendingNode||t.session)}},{key:"_showGestureHint",value:function(t){var r=this.internals.settings;r.gestureTarget==="shared"&&(this.gestureHint=this.gestureHint||new Oh(this.container),this.gestureHint.show(t,r))}},{key:"setNodesState",value:function(t,r){return this.stateManager.setNodesState(t,r),this}},{key:"setEdgesState",value:function(t,r){return this.stateManager.setEdgesState(t,r),this}},{key:"updateContainerCursor",value:function(){var t=this.stateManager.hovered,r=this.resolvedStageStyle.cursor||"";this.container.style.cursor=t&&Eh(this.internals,t)||r}},{key:"refreshStageStyle",value:function(){this.resolvedStageStyle=sr(this.stylesDeclaration.stage,this.stateManager.graphState),this.resolvedStageStyle.background!==void 0&&(this.container.style.backgroundColor=this.resolvedStageStyle.background),this.updateContainerCursor()}},{key:"getNodeDisplayedLabels",value:function(){return new Set(this.labelRenderer.displayedNodeLabels)}},{key:"getEdgeDisplayedLabels",value:function(){return new Set(this.labelRenderer.displayedEdgeLabels)}},{key:"getSettings",value:function(){return O({},this.internals.settings)}},{key:"getSetting",value:function(t){return this.internals.settings[t]}},{key:"getStyles",value:function(){return O({},this.stylesDeclaration)}},{key:"getPrimitives",value:function(){return O({},this.internals.primitives)}},{key:"setSetting",value:function(t,r){return this.internals.settings[t]=r,va(this.internals.settings),this.handleSettingsUpdate(),this.scheduleRefresh(),this}},{key:"updateSetting",value:function(t,r){return this.setSetting(t,r(this.internals.settings[t])),this}},{key:"setSettings",value:function(t){return this.internals.settings=O(O({},this.internals.settings),t),va(this.internals.settings),this.handleSettingsUpdate(),this.scheduleRefresh(),this}},{key:"resize",value:function(t){var r=this.width,i=this.height;if(this.width=this.container.offsetWidth,this.height=this.container.offsetHeight,this.internals.pixelRatio=bn(),this.width===0)if(this.internals.settings.allowInvalidContainer)this.width=1;else throw new Error("Sigma: Container has no width. You can set the allowInvalidContainer setting to true to stop seeing this error.");if(this.height===0)if(this.internals.settings.allowInvalidContainer)this.height=1;else throw new Error("Sigma: Container has no height. You can set the allowInvalidContainer setting to true to stop seeing this error.");if(!t&&r===this.width&&i===this.height)return this;this.labelRenderer.labelsDirty=!0;for(var o=0,s=[this.mouseLayer].concat(V(Object.values(this.extraElements)));o<s.length;o++){var l=s[o];l.style.width=this.width+"px",l.style.height=this.height+"px"}return this.webGLContext&&(this.stageCanvas.setAttribute("width",this.width*this.internals.pixelRatio+"px"),this.stageCanvas.setAttribute("height",this.height*this.internals.pixelRatio+"px"),this.webGLContext.viewport(0,0,this.width*this.internals.pixelRatio,this.height*this.internals.pixelRatio)),this.emit("resize"),this}},{key:"clear",value:function(){return this.emit("beforeClear"),this.webGLContext.bindFramebuffer(WebGLRenderingContext.FRAMEBUFFER,null),this.webGLContext.clear(WebGLRenderingContext.COLOR_BUFFER_BIT),this.emit("afterClear"),this}},{key:"scheduleStateRefresh",value:function(){this.needToRefreshState=!0,this.scheduleRender()}},{key:"refreshState",value:function(){var t=this,r;this.stateManager.flushGraphStateFlags();var i=this.stateManager.graphStateChanged&&this.internals.nodeStyleAnalysis.dependency==="graph-state",o=this.stateManager.graphStateChanged&&this.edgeStyleAnalysis.dependency==="graph-state",s=!1;if(i)this.internals.graph.forEachNode(function(g){t.refreshNodeState(g)&&(s=!0)});else if(this.internals.nodeStyleAnalysis.dependency!=="static"){var l=M(this.stateManager.dirtyNodes),u;try{for(l.s();!(u=l.n()).done;){var d=u.value;this.refreshNodeState(d)&&(s=!0)}}catch(g){l.e(g)}finally{l.f()}}if(o)this.internals.graph.forEachEdge(function(g){t.refreshEdgeState(g)&&(s=!0)});else if(this.edgeStyleAnalysis.dependency!=="static"){var c=M(this.stateManager.dirtyEdges),h;try{for(c.s();!(h=c.n()).done;){var f=h.value;this.refreshEdgeState(f)&&(s=!0)}}catch(g){c.e(g)}finally{c.f()}}this.stateManager.graphStateChanged&&(r=this.stylesDeclaration)!==null&&r!==void 0&&r.stage&&this.refreshStageStyle(),this.stateManager.clearDirtyTracking(),s&&(this.pendingProcess="full")}},{key:"refreshNodeState",value:function(t){var r=this.internals.nodeDataCache[t];if(!r||this.nodeReducer){var i,o,s,l,u=(i=this.internals.nodeDataCache[t])===null||i===void 0?void 0:i.depth,d=(o=this.internals.nodeDataCache[t])===null||o===void 0?void 0:o.zIndex,c=(s=this.internals.nodeDataCache[t])===null||s===void 0?void 0:s.labelAttachment;this.updateNode(t);var h=this.internals.nodeDataCache[t];this.internals.attachmentManager&&h.labelAttachment!==c&&this.internals.attachmentManager.invalidateNode(t);var f;this.internals.nodeShapeMap&&this.internals.nodeGlobalShapeIds&&h.shape&&h.shape in this.internals.nodeShapeMap?f=this.internals.nodeGlobalShapeIds[this.internals.nodeShapeMap[h.shape]]:f=Sn(h.shape||"circle"),(l=this.internals.nodeDataTexture).updateNode.apply(l,[t,h.x,h.y,h.size,f].concat(V(pn(h)),[h.color])),u&&h.depth!==u&&this.updateNodeDepthRanges(t,u,h.depth);var g=this.nodeProgramIndex[t];return g!==void 0&&(this.addNodeToProgram(t,g),this.nodeProgram.invalidateBuffers()),d!==void 0&&h.zIndex!==d}var m=this.internals.graph.getNodeAttributes(t),p=this.stateManager.getNodeState(t),v=r.size,b=r.shape,y=r.depth,_=r.zIndex,x=r.labelAttachment,T=r.rotationAlignment,R=r.labelRotationAlignment,E=r.color;ir(this.stylesDeclaration.nodes,m,p,this.stateManager.graphState,this.internals.graph,r),this.postEvaluateNode(r,m,p);var S=this.nodeGraphCoords[t],w=r.x!==S.x||r.y!==S.y;if(w&&(S.x=r.x,S.y=r.y),this.normalizationFunction.applyTo(r),this.internals.nodeShapeMap?(!r.shape||!(r.shape in this.internals.nodeShapeMap))&&(r.shape=Object.keys(this.internals.nodeShapeMap)[0]):this.nodeShapeSlug&&(r.shape=this.nodeShapeSlug),this.internals.attachmentManager&&r.labelAttachment!==x&&this.internals.attachmentManager.invalidateNode(t),vt(this.internals.nodesWithForcedLabels,t,Ze(r)),vt(this.internals.nodesWithBackdrop,t,ca(r)),w||r.size!==v||r.shape!==b||r.rotationAlignment!==T||r.labelRotationAlignment!==R||r.color!==E){var F,D;this.internals.nodeShapeMap&&this.internals.nodeGlobalShapeIds&&r.shape&&r.shape in this.internals.nodeShapeMap?D=this.internals.nodeGlobalShapeIds[this.internals.nodeShapeMap[r.shape]]:D=Sn(r.shape||"circle"),(F=this.internals.nodeDataTexture).updateNode.apply(F,[t,r.x,r.y,r.size,D].concat(V(pn(r)),[r.color]))}this.itemBuckets.nodes.set(t,r.depth),r.depth!==y&&this.updateNodeDepthRanges(t,y,r.depth);var P=this.nodeProgramIndex[t];return P!==void 0&&(this.addNodeToProgram(t,P),this.nodeProgram.invalidateBuffers()),r.zIndex!==_}},{key:"refreshEdgeState",value:function(t){var r=this.internals.edgeDataCache[t];if(!r||this.edgeReducer){var i=r?.depth,o=r?.zIndex;this.updateEdge(t);var s=this.internals.edgeDataCache[t];i&&s.depth!==i&&this.updateEdgeDepthRanges(t,i,s.depth);var l=this.edgeProgramIndex[t];return l!==void 0&&(this.addEdgeToProgram(t,l),this.edgeProgram.invalidateBuffers()),o!==void 0&&s.zIndex!==o}var u=this.internals.graph.getEdgeAttributes(t),d=this.stateManager.getEdgeState(t),c=r.depth,h=r.zIndex,f=r.size,g=r.path,m=r.selfLoopPath,p=r.parallelPath,v=r.head,b=r.tail;or(this.stylesDeclaration.edges,u,d,this.stateManager.graphState,this.internals.graph,r),this.postEvaluateEdge(r,u),this.applyEdgeSpread(t,r,d),vt(this.internals.edgesWithForcedLabels,t,Ze(r)),this.itemBuckets.edges.set(t,r.depth),r.depth!==c&&this.updateEdgeDepthRanges(t,c,r.depth);var y=this.edgeProgramIndex[t];if(y!==void 0){var _=r.size!==f||r.path!==g||r.selfLoopPath!==m||r.parallelPath!==p||r.head!==v||r.tail!==b;if(_)this.addEdgeToProgram(t,y),this.edgeProgram.invalidateBuffers();else{var x=this.internals.graph.source(t),T=this.internals.graph.target(t),R=this.internals.nodeDataCache[x],E=this.internals.nodeDataCache[T],S=this.edgeTextureIndexCache[t];this.edgeProgram.process(_t(this.pickingState,"edge",t),y,R,E,r,S),this.edgeProgram.invalidateBuffers()}}return r.zIndex!==h}},{key:"refresh",value:function(t){var r=this,i=t?.skipIndexation!==void 0?t?.skipIndexation:!1,o=t?.schedule!==void 0?t.schedule:!1,s=!t||!t.partialGraph;if(s)this.clearEdgeIndices(),this.clearNodeIndices(),this.internals.graph.forEachNode(function(R){return r.addNode(R)}),this.edgeGroups.rebuild(),this.internals.graph.forEachEdge(function(R){return r.addEdge(R)}),this.pendingProcess="full";else{for(var l,u,d=((l=t.partialGraph)===null||l===void 0?void 0:l.nodes)||[],c=0,h=d?.length||0;c<h;c++){var f,g,m=""+d[c],p=(f=this.internals.nodeDataCache[m])===null||f===void 0?void 0:f.labelAttachment;if(this.updateNode(m),this.internals.attachmentManager&&((g=this.internals.nodeDataCache[m])!==null&&g!==void 0&&g.labelAttachment||p)&&this.internals.attachmentManager.invalidateNode(m),i){var v=this.nodeProgramIndex[m];if(v===void 0)throw new Error('Sigma: node "'.concat(m,`" can't be repaint`));this.addNodeToProgram(m,v)}}i&&d.length>0&&(this.nodeProgram.invalidateBuffers(),this.labelRenderer.labelsDirty=!0);for(var b=(t==null||(u=t.partialGraph)===null||u===void 0?void 0:u.edges)||[],y=0,_=b.length;y<_;y++){var x=""+b[y];if(this.updateEdge(x),i){var T=this.edgeProgramIndex[x];if(T===void 0)throw new Error('Sigma: edge "'.concat(x,`" can't be repaint`));this.addEdgeToProgram(x,T)}}i&&b.length>0&&(this.edgeProgram.invalidateBuffers(),this.labelRenderer.labelsDirty=!0),!i&&this.pendingProcess!=="full"&&(this.pendingProcess=b.length>0?"full":"nodes")}return o?this.scheduleRender():this.render(),this}},{key:"scheduleRender",value:function(){var t=this;return this.renderFrame||(this.renderFrame=requestAnimationFrame(function(){t.render()})),this}},{key:"scheduleRefresh",value:function(t){return this.refresh(O(O({},t),{},{schedule:!0}))}},{key:"getViewportZoomedState",value:function(t,r){var i=this.camera.getState(),o=i.ratio,s=i.angle,l=i.x,u=i.y,d=this.internals.settings,c=d.minCameraRatio,h=d.maxCameraRatio;typeof h=="number"&&(r=Math.min(r,h)),typeof c=="number"&&(r=Math.max(r,c));var f=r/o,g={x:this.width/2,y:this.height/2},m=this.viewportToFramedGraph(t),p=this.viewportToFramedGraph(g);return{angle:s,x:(m.x-p.x)*(1-f)+l,y:(m.y-p.y)*(1-f)+u,ratio:r}}},{key:"viewRectangle",value:function(){var t=this.viewportToFramedGraph({x:0,y:0}),r=this.viewportToFramedGraph({x:this.width,y:0}),i=this.viewportToFramedGraph({x:0,y:this.height});return{x1:t.x,y1:t.y,x2:r.x,y2:r.y,height:r.y-i.y}}},{key:"framedGraphToViewport",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{},i=!!r.cameraState||!!r.viewportDimensions||!!r.graphDimensions||!!r.padding,o=r.matrix||(i?at(r.cameraState||this.camera.getState(),r.viewportDimensions||this.getDimensions(),r.graphDimensions||this.getGraphDimensions(),r.padding||this.getStagePadding()):this.matrix),s=Ft(o,t);return{x:(1+s.x)*this.width/2,y:(1-s.y)*this.height/2}}},{key:"viewportToFramedGraph",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{},i=!!r.cameraState||!!r.viewportDimensions||!!r.graphDimensions||!!r.padding,o=r.matrix||(i?at(r.cameraState||this.camera.getState(),r.viewportDimensions||this.getDimensions(),r.graphDimensions||this.getGraphDimensions(),r.padding||this.getStagePadding(),!0):this.invMatrix),s=Ft(o,{x:t.x/this.width*2-1,y:1-t.y/this.height*2});return isNaN(s.x)&&(s.x=0),isNaN(s.y)&&(s.y=0),s}},{key:"viewportToGraph",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{};return this.normalizationFunction.inverse(this.viewportToFramedGraph(t,r))}},{key:"graphToViewport",value:function(t){var r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{};return this.framedGraphToViewport(this.normalizationFunction(t),r)}},{key:"graphToFramedGraph",value:function(t){return this.normalizationFunction(t)}},{key:"framedGraphToGraph",value:function(t){return this.normalizationFunction.inverse(t)}},{key:"getGraphToViewportRatio",value:function(){var t={x:0,y:0},r={x:1,y:1},i=Math.sqrt(Math.pow(t.x-r.x,2)+Math.pow(t.y-r.y,2)),o=this.graphToViewport(t),s=this.graphToViewport(r),l=Math.sqrt(Math.pow(o.x-s.x,2)+Math.pow(o.y-s.y,2));return l/i}},{key:"computeNodeExtent",value:function(){var t=this.nodeGraphCoords,r=Object.keys(t);if(!r.length)return{x:[0,1],y:[0,1]};for(var i=1/0,o=-1/0,s=1/0,l=-1/0,u=0,d=r.length;u<d;u++){var c=t[r[u]],h=c.x,f=c.y;h<i&&(i=h),h>o&&(o=h),f<s&&(s=f),f>l&&(l=f)}return{x:[i,o],y:[s,l]}}},{key:"getBBox",value:function(){return this.nodeExtent}},{key:"getCustomBBox",value:function(){return this.customBBox}},{key:"setCustomBBox",value:function(t){return this.customBBox=t,this.scheduleRender(),this}},{key:"kill",value:function(){var t,r,i,o,s;this.emit("kill"),this.removeAllListeners(),this.camera.cancelAnimation(),this.unbindCameraHandlers(),window.removeEventListener("resize",this.activeListeners.handleResize),this.mouseCaptor.kill(),this.touchCaptor.kill(),this.internals.hoverResolver.kill(),this.unbindGraphHandlers(),this.clearIndices(),this.clearState(),this.internals.nodeDataCache={},this.internals.edgeDataCache={},this.renderFrame&&(cancelAnimationFrame(this.renderFrame),this.renderFrame=null);for(var l=this.container;l.firstChild;)l.removeChild(l.firstChild);this.nodeProgram.kill(),this.nodeFramePass.kill(),this.edgeProgram.kill(),this.edgeFramePass.kill(),this.internals.labelProgram.kill(),(t=this.internals.edgeLabelProgram)===null||t===void 0||t.kill(),(r=this.internals.edgeLabelBackgroundProgram)===null||r===void 0||r.kill(),this.internals.backdropProgram.kill(),this.internals.labelBackgroundProgram.kill(),(i=this.internals.attachmentProgram)===null||i===void 0||i.kill(),(o=this.internals.attachmentManager)===null||o===void 0||o.kill(),this.internals.attachmentProgram=null,this.internals.attachmentManager=null;var u=M(this.customLayerPrograms.values()),d;try{for(u.s();!(d=u.n()).done;){var c=d.value.program;c.kill()}}catch(g){u.e(g)}finally{u.f()}if(this.customLayerPrograms.clear(),this.sdfAtlas&&(this.sdfAtlas=null),this.internals.nodeDataTexture&&(this.internals.nodeDataTexture.kill(),this.internals.nodeDataTexture=null),this.internals.nodeFrameTexture&&(this.internals.nodeFrameTexture.kill(),this.internals.nodeFrameTexture=null),this.internals.edgeDataTexture&&(this.internals.edgeDataTexture.kill(),this.internals.edgeDataTexture=null),this.internals.edgeFrameTexture&&(this.internals.edgeFrameTexture.kill(),this.internals.edgeFrameTexture=null),this.webGLContext){var h;(h=this.webGLContext.getExtension("WEBGL_lose_context"))===null||h===void 0||h.loseContext(),this.webGLContext=null}(s=this.gestureHint)===null||s===void 0||s.kill(),this.gestureHint=null,this.mouseLayer.remove();for(var f in this.extraElements)this.extraElements[f].remove();this.extraElements={}}},{key:"scaleSize",value:function(){var t=arguments.length>0&&arguments[0]!==void 0?arguments[0]:1,r=arguments.length>1&&arguments[1]!==void 0?arguments[1]:this.camera.ratio;return t/this.internals.settings.zoomToSizeRatioFunction(r)*(this.getSetting("itemSizesReference")==="positions"?r*this.graphToViewportRatio:1)}},{key:"getStageCanvas",value:function(){return this.stageCanvas}},{key:"getMouseLayer",value:function(){return this.mouseLayer}}])}(ua),xs=Xh;var Ig=Ve(Dt());var jh="pixels",Yh="butt";function Kh(a){return a===void 0||a===!1?{tail:!1,head:!1}:a===!0?{tail:!0,head:!0}:a==="head"?{tail:!1,head:!0}:{tail:!0,head:!1}}function Zh(a){var n,e;return a===void 0?{tail:0,head:0}:typeof a=="number"?{tail:a,head:a}:{tail:(n=a.tail)!==null&&n!==void 0?n:0,head:(e=a.head)!==null&&e!==void 0?e:0}}function _s(a){var n,e,t,r,i,o,s,l=a??{},u=(n=l.dashColor)!==null&&n!==void 0?n:{attribute:"color"},d=(e=l.gapColor)!==null&&e!==void 0?e:0,c={dashSize:(t=l.dashSize)!==null&&t!==void 0?t:{value:10,mode:"pixels"},gapSize:(r=l.gapSize)!==null&&r!==void 0?r:{value:10,mode:"pixels"},dashOffset:(i=l.dashOffset)!==null&&i!==void 0?i:{value:0,mode:"pixels"}},h=(o=l.align)!==null&&o!==void 0?o:.5,f=(s=l.cap)!==null&&s!==void 0?s:Yh,g=Kh(l.solidExtremities),m=Zh(l.solidMargin),p=fn(u,"dashColor"),v=[c.dashSize,c.gapSize,c.dashOffset].map(function(D){var P;return((P=D.mode)!==null&&P!==void 0?P:jh)==="relative"?1:0}),b=[{name:"u_sizeMode",type:"vec3",value:v},{name:"u_align",type:"float",value:h},{name:"u_solidExtremities",type:"vec2",value:[g.tail?1:0,g.head?1:0]},{name:"u_solidMargin",type:"vec2",value:[m.tail,m.head]}],y=V(p.attributes),_=p.needsNodeColors,x;if(typeof d=="number")x="vec4(dashColor.rgb, dashColor.a * ".concat(he(d),")");else{var T=fn(d,"gapColor");x=T.glsl,y.push.apply(y,V(T.attributes)),_=_||T.needsNodeColors}var R=!("value"in c.dashSize),E=!("value"in c.gapSize),S=!("value"in c.dashOffset);["dashSize","gapSize","dashOffset"].forEach(function(D){if("value"in c[D])b.push({name:"u_".concat(D),type:"float",value:c[D].value});else{var P;y.push({name:"a_".concat(D),size:1,type:WebGL2RenderingContext.FLOAT,source:c[D].attribute}),b.push({name:"u_".concat(D),type:"float",value:(P=c[D].default)!==null&&P!==void 0?P:0})}});var w=function(P,L){return L?"(v_".concat(P," > 0.0 ? v_").concat(P," : u_").concat(P,")"):"u_".concat(P)},F=`
// Dashed pattern layer with antialiased boundaries
// Uniforms:
//   u_dashSize: size of each dash (or default when using attribute)
//   u_gapSize: size of gaps between dashes (or default when using attribute)
//   u_dashOffset: offset to shift the pattern (or default when using attribute)
//   u_sizeMode: vec3 indicating if values are thickness-relative (x=dash, y=gap, z=offset)
//   u_align: pattern alignment (0=start, 0.5=center, 1=end)
//   u_solidExtremities: vec2(tail, head) - 1.0 means solid, 0.0 means dashed
//   u_solidMargin: vec2(tail, head) - extra solid margin in pixels
`.concat(R?"// Varying: v_dashSize for per-edge dash size":"",`
`).concat(E?"// Varying: v_gapSize for per-edge gap size":"",`
`).concat(S?"// Varying: v_dashOffset for per-edge dash offset":"",`

vec4 layer_dashed(EdgeContext ctx) {
  // Dash color (straight alpha, matching v_color and blendOver)
  vec4 dashColor = `).concat(p.glsl,`;

  // Check for solid zones first (extremities and margins)
  // v_zone: 0=tail extremity, 1=body, 2=head extremity
  // v_tailLengthRatio and v_headLengthRatio give extremity lengths as ratio of thickness

  // Tail solid zone check
  if (u_solidExtremities.x > 0.5 && v_zone < 0.5) {
    // In tail extremity zone and solidExtremities.tail is enabled
    return dashColor;
  }
  // Head solid zone check
  if (u_solidExtremities.y > 0.5 && v_zone > 1.5) {
    // In head extremity zone and solidExtremities.head is enabled
    return dashColor;
  }

  // Compute extremity lengths in world units for margin calculation
  float tailExtremityLength = v_tailLengthRatio * ctx.thickness;
  float headExtremityLength = v_headLengthRatio * ctx.thickness;

  // Convert pixel margins to world units (same formula as thickness conversion)
  float tailMarginWorld = u_solidMargin.x * u_correctionRatio / u_sizeRatio;
  float headMarginWorld = u_solidMargin.y * u_correctionRatio / u_sizeRatio;

  // Tail margin check (margin starts after extremity zone)
  float tailSolidZone = (u_solidExtremities.x > 0.5 ? tailExtremityLength : 0.0) + tailMarginWorld;
  if (ctx.distanceFromSource < tailSolidZone) {
    return dashColor;
  }

  // Head margin check (margin starts before extremity zone)
  float headSolidZone = (u_solidExtremities.y > 0.5 ? headExtremityLength : 0.0) + headMarginWorld;
  if (ctx.distanceToTarget < headSolidZone) {
    return dashColor;
  }

  // Get dash size values (from attribute if available, otherwise uniform)
  float dashSizeValue = `).concat(w("dashSize",R),`;
  float gapSizeValue = `).concat(w("gapSize",E),`;
  float dashOffsetValue = `).concat(w("dashOffset",S),`;

  // Compute actual sizes (either in pixels converted to world units, or relative to thickness)
  float pixelToWorld = u_correctionRatio / u_sizeRatio;
  float dashSize = dashSizeValue * (u_sizeMode.x > 0.5 ? ctx.thickness : pixelToWorld);
  float gapSize = gapSizeValue * (u_sizeMode.y > 0.5 ? ctx.thickness : pixelToWorld);
  float dashOffset = dashOffsetValue * (u_sizeMode.z > 0.5 ? ctx.thickness : pixelToWorld);

  // Early return when no visible dash pattern:
  // - dashSize \u2248 0: no dashes to show, return transparent (let plain layer show through)
  // - gapSize \u2248 0: all dash/no gap, effectively solid, return transparent (let plain layer handle it)
  // Threshold scales with pixelToWorld so it stays ~0.1px regardless of zoom
  float dashThreshold = 0.1 * pixelToWorld;
  if (dashSize < dashThreshold || gapSize < dashThreshold) {
    return vec4(0.0);
  }

  // Pattern length is dash + gap
  float patternLength = dashSize + gapSize;

  // Adjust distances for solid zones (pattern starts after solid zones)
  float adjustedDistFromSource = ctx.distanceFromSource - tailSolidZone;
  float adjustedDistToTarget = ctx.distanceToTarget - headSolidZone;

  // Compute alignment anchor point
  // - align: 0 \u2192 anchor at start, pattern begins with a dash
  // - align: 1 \u2192 anchor at end, pattern ends with a dash
  // - align: 0.5 \u2192 anchor at center, pattern is symmetric
  float dashedLength = adjustedDistFromSource + adjustedDistToTarget;
  float anchorDist = u_align * dashedLength;

  // Position within the repeating pattern
  // By subtracting anchorDist, we ensure the anchor point maps to position 0 in the pattern
  // This avoids the unstable mod(dashedLength, patternLength) operation
  float posInPattern = mod(adjustedDistFromSource - anchorDist + dashOffset, patternLength);

  // Signed longitudinal distance to the nearest dash center, wrapping across
  // pattern repetitions so both dash edges antialias correctly
  float longFromCenter =
    mod(posInPattern - dashSize * 0.5 + patternLength * 0.5, patternLength) - patternLength * 0.5;

  // Compute signed distance field for the dash
  // Positive inside dash, negative inside gap
`).concat(f==="round"?`  // Capsule SDF: round caps carved inside the dash length, so a dash never
  // exceeds dashSize. Dashes shorter than the thickness degenerate to circles
  // (dots) of diameter dashSize.
  // ctx.sdf is 0 at the stroke boundary, so shift it back to centerline distance
  float transverse = ctx.sdf + ctx.thickness * 0.5;
  float capRadius = min(ctx.thickness, dashSize) * 0.5;
  float halfLength = dashSize * 0.5 - capRadius;
  vec2 q = vec2(max(abs(longFromCenter) - halfLength, 0.0), transverse);
  float sdf = capRadius - length(q);`:"  float sdf = dashSize * 0.5 - abs(longFromCenter);",`

  // Apply antialiasing using smoothstep
  // aaWidth is in world units, same as our distance
  float dashAlpha = smoothstep(-ctx.aaWidth, ctx.aaWidth, sdf);

  // Gap color (straight alpha, like the dash color)
  vec4 gapColor = `).concat(x,`;

  // Blend between gap and dash colors
  return mix(gapColor, dashColor, dashAlpha);
}
`);return{name:"dashed",glsl:F,uniforms:b,attributes:y,needsNodeColors:_}}var Ng=Ve(sn());var de={surface:"#0d171b",label:"#e6eef0",series:["#5ed6b2","#8f7dff","#ff6b4a"],other:"#5f6b72",hub:"#f1cf86",ghost:"#22343a",dust:"#3a4a50",edge:"#2b4a4e",treeEdge:"#1c3438",dimNode:"#16282c",dimEdge:"#0e1c1f",activeEdge:"#f1cf86",activeTreeEdge:"rgba(241,207,134,0.26)",suspect:"#ff5fd2",restingSuspect:"#6d3a68",dimSuspect:"#2c1a30"},dt=a=>window.webkit?.messageHandlers?.studio?.postMessage(a);window.addEventListener("error",a=>dt({type:"error",message:String(a.message)}));var q=new oe({multi:!1,type:"undirected"}),As=document.getElementById("canvas"),Ts=document.getElementById("areas"),Ds=document.getElementById("under"),ws=document.getElementById("over"),kn=Ds.getContext("2d"),B=ws.getContext("2d"),Ia=2.399963229728653,Yt=null,pe=null,ut=null,Ls=new Map,Cs=new Map,On="links",za={},St=null,Pn=null,Na=[],lt={left:0,right:0,top:0,bottom:0},Je=!0,Ps=1,Qt=!1,Gr=null;function Qh(){return{name:"orb",uniforms:[],attributes:[{name:"orbColor",size:4,type:WebGL2RenderingContext.UNSIGNED_BYTE,normalized:!0,source:"color"}],glsl:`
vec4 layer_orb(vec4 v_orbColor) {
  float radiusInPixels = context.shapeSize / max(context.pixelToUV, 0.0001);
  float shading = smoothstep(2.5, 7.0, radiusInPixels);
  vec2 p = context.uv / context.shapeSize;
  float z = sqrt(clamp(1.0 - dot(p, p), 0.0, 1.0));
  vec3 normal = vec3(p, z);
  vec3 light = normalize(vec3(-0.42, 0.55, 0.72));
  float diffuse = max(dot(normal, light), 0.0);
  float specular = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 32.0);
  float rim = pow(1.0 - z, 2.5);
  vec3 lit = v_orbColor.rgb * (0.34 + 0.86 * diffuse);
  lit += mix(v_orbColor.rgb, vec3(1.0), 0.5) * rim * 0.32;
  lit += vec3(1.0) * specular * 0.8;
  return vec4(mix(v_orbColor.rgb, lit, shading), v_orbColor.a);
}
`}}function Jh(a){if(a.ring===0)return de.hub;if(a.ghost)return de.ghost;if(Kt(a))return de.dust;let n=Ls.get(a.group);return n===void 0||n<0?de.other:de.series[n]}var ks=a=>On==="areas"?Math.min(a,11):a,Kt=a=>(a.noise??0)>=a.value&&a.value>0;function ef(a){return a.tree?de.treeEdge:de.edge}var j=new xs(q,As,{settings:{allowInvalidContainer:!0,itemSizesReference:"screen",zoomToSizeRatioFunction:a=>Math.sqrt(a/Ps),stagePadding:50,renderEdgeLabels:!1,labelDensity:.6,labelGridCellSize:110,labelRenderedSizeThreshold:7},customNodeState:{isActive:!1},customEdgeState:{isActive:!1},customGraphState:{hasFocus:!1,isReviewing:!1},primitives:{nodes:{shapes:[hn()],layers:[Qh()],label:{font:{family:"-apple-system, BlinkMacSystemFont, sans-serif",weight:"500",size:12}}},edges:{paths:[gn()],variables:{plainColor:{type:"color",default:"transparent"},dashColor:{type:"color",default:"transparent"},dashLength:{type:"number",default:0},gapLength:{type:"number",default:0}},layers:[Be({color:{attribute:"plainColor"}}),_s({dashColor:{attribute:"dashColor"},dashSize:{attribute:"dashLength",default:0,mode:"pixels"},gapSize:{attribute:"gapLength",default:0,mode:"pixels"}})]}},styles:{nodes:[{x:{attribute:"x"},y:{attribute:"y"},size:a=>ks(a.size),color:{attribute:"color"},label:{attribute:"label"},labelColor:de.label,labelSize:12,labelFont:"-apple-system, BlinkMacSystemFont, sans-serif",labelVisibility:"auto",depth:"nodes",zIndex:{attribute:"rank",defaultValue:0}},{whenData:"isDust",then:{labelVisibility:"hidden",opacity:.7}},{when:(a,n,e)=>e.hasFocus&&!n.isActive,then:{color:de.dimNode,labelVisibility:"hidden"}},{whenState:"isActive",then:{depth:"topNodes"}},{whenState:"isHighlighted",then:{labelVisibility:"hidden",depth:"topNodes"}},{whenState:"isHovered",then:{label:{attribute:"hoverText"},labelVisibility:"visible",labelBackgroundColor:de.surface,labelBackgroundPadding:5,depth:"topNodes"}}],edges:[{size:{attribute:"size"},color:{attribute:"baseColor"},plainColor:{attribute:"baseColor"},dashColor:"transparent",dashLength:0,gapLength:0,depth:"edges"},{whenData:"isSuspect",then:{plainColor:"transparent",dashColor:de.restingSuspect,dashLength:3,gapLength:5}},{when:(a,n,e)=>e.hasFocus&&!n.isActive&&!a.isSuspect,then:{plainColor:de.dimEdge}},{when:(a,n,e)=>e.hasFocus&&!n.isActive&&a.isSuspect,then:{dashColor:de.dimSuspect}},{when:(a,n)=>n.isActive&&!a.isSuspect,then:{plainColor:{whenData:"tree",then:de.activeTreeEdge,else:de.activeEdge},depth:"topEdges"}},{when:(a,n)=>n.isActive&&a.isSuspect,then:{dashColor:de.suspect,depth:"topEdges"}},{when:(a,n,e)=>e.isReviewing&&a.isSuspect&&!e.hasFocus,then:{dashColor:de.suspect}}]}}),Cr=As.querySelector("canvas");j.on("beforeRender",()=>{let{width:a,height:n}=j.getDimensions(),e=window.devicePixelRatio||1;Cr&&(Cr.width!==Math.floor(a*e)||Cr.height!==Math.floor(n*e))&&j.resize(!0)});function Fs(){matchMedia(`(resolution: ${window.devicePixelRatio||1}dppx)`).addEventListener("change",()=>{j.scheduleRender(),Fs()},{once:!0})}Fs();var Et=new Set,Ga=new Set,Gn=[];function Zt(){let a=Qt?Yt:Yt??pe,n=Yt??pe,e=new Set,t=new Set;if(a!==null&&q.hasNode(a))e.add(a),q.forEachNeighbor(a,r=>e.add(r)),q.forEachEdge(a,r=>t.add(r));else if(Gr!==null)for(let r of Gr)q.hasNode(r)&&e.add(r);else ut!==null&&(q.forEachNode((r,i)=>{i.group===ut&&e.add(r)}),q.forEachEdge((r,i,o,s,l,u)=>{l.group===ut&&u.group===ut&&t.add(r)}));for(let r of Et)e.has(r)||j.setNodeState(r,{isActive:!1});for(let r of e)Et.has(r)||j.setNodeState(r,{isActive:!0});for(let r of Ga)t.has(r)||j.setEdgeState(r,{isActive:!1});for(let r of t)Ga.has(r)||j.setEdgeState(r,{isActive:!0});Et=e,Ga=t,j.setGraphState({hasFocus:e.size>0}),Gn=n===null||!q.hasNode(n)?[]:q.edges(n).filter(r=>q.getEdgeAttribute(r,"isSuspect")).slice(0,40),Wn(),Ms()}function Br(a){pe!==null&&q.hasNode(pe)&&j.setNodeState(pe,{isHighlighted:!1}),pe=a,pe!==null&&j.setNodeState(pe,{isHighlighted:!0}),Ur=performance.now(),Zt()}function tf(){document.body.style.setProperty("--label",de.label)}j.on("enterNode",({node:a})=>{Yt=a,Zt()});j.on("leaveNode",()=>{Yt=null,Zt()});j.on("clickNode",({node:a})=>{Qt||(Br(a),dt({type:"select",id:a}))});j.on("doubleClickNode",({node:a,preventSigmaDefault:n})=>{n(),!Qt&&dt({type:"drill",id:a})});j.on("clickStage",()=>{Qt||(Br(null),dt({type:"clear"}))});var Is=260,nf=80,Ur=0,Gs=[],zs=[],Pr=null,kr=new Map;function af(a){if(kr.has(a))return kr.get(a);let n=128,e=document.createElement("canvas");e.width=n,e.height=n;let t=e.getContext("2d"),r=t.createRadialGradient(n/2,n/2,n*.14,n/2,n/2,n/2);return r.addColorStop(0,`${a}66`),r.addColorStop(.45,`${a}1c`),r.addColorStop(1,`${a}00`),t.fillStyle=r,t.fillRect(0,0,n,n),kr.set(a,e),e}function Ns(a){let n=a|0;return()=>{n=n+1831565813|0;let e=Math.imul(n^n>>>15,1|n);return e=e+Math.imul(e^e>>>7,61|e)^e,((e^e>>>14)>>>0)/4294967296}}function zr(a){let n=2166136261;for(let e=0;e<a.length;e++)n=Math.imul(n^a.charCodeAt(e),16777619);return n}function rf(a){Gs=a.filter(r=>!r.ghost&&!Kt(r)).sort((r,i)=>i.value-r.value).slice(0,nf).map(r=>r.id);let n=a.filter(r=>(r.noise??0)>0&&!Kt(r)),e=n.reduce((r,i)=>r+i.noise,0),t=Math.max(1,e/1600);zs=n.map(r=>{let i=Ns(zr(r.id)),o=Math.min(900,Math.max(6,Math.round(r.noise/t))),s=[];for(let l=0;l<o;l++){let u=i()*Math.PI*2,c=1.5+Math.abs(Math.sqrt(-2*Math.log(i()+1e-9))*Math.cos(Math.PI*2*i()))*2.1;s.push({x:Math.cos(u)*c,y:Math.sin(u)*c,size:.5+i()*1.1,bucket:Math.floor(i()*3)})}return{id:r.id,specks:s}})}function of(){let a=window.devicePixelRatio||1,{width:n,height:e}=j.getDimensions();for(let[t,r]of[[Ds,kn],[ws,B]])(t.width!==Math.round(n*a)||t.height!==Math.round(e*a))&&(t.width=Math.round(n*a),t.height=Math.round(e*a)),r.setTransform(a,0,0,a,0,0)}function zn(a){let{x:n,y:e}=q.getNodeAttributes(a);return j.graphToViewport({x:n,y:e})}var Nr=a=>j.scaleSize(ks(q.getNodeAttribute(a,"size"))),sf=["rgba(160,182,188,0.16)","rgba(160,182,188,0.3)","rgba(160,182,188,0.46)"],lf=["rgba(226,206,160,0.2)","rgba(226,206,160,0.36)","rgba(226,206,160,0.55)"];function uf(){let{width:a,height:n}=j.getDimensions();kn.clearRect(0,0,a,n);let e=Et.size>0;for(let t of Gs){if(!q.hasNode(t)||e&&!Et.has(t))continue;let r=Nr(t);if(r<5)continue;let{x:i,y:o}=zn(t),s=r*3.1;i<-s||o<-s||i>a+s||o>n+s||kn.drawImage(af(q.getNodeAttribute(t,"color")),i-s,o-s,s*2,s*2)}for(let t of zs){if(!q.hasNode(t.id))continue;let r=t.id===pe;if(e&&!Et.has(t.id))continue;let{x:i,y:o}=zn(t.id),s=Math.max(Nr(t.id),4),l=r?lf:sf;for(let u=0;u<3;u++){kn.fillStyle=l[u];for(let d of t.specks){if(d.bucket!==u)continue;let c=i+d.x*s,h=o+d.y*s;c<0||h<0||c>a||h>n||kn.fillRect(c,h,d.size,d.size)}}}}function df(a){return Je?1-(1-Math.min(1,(a-Ur)/Is))**3:1}function cf(a){if(pe===null||!q.hasNode(pe))return;let{x:n,y:e}=zn(pe),t=Math.max(Nr(pe),5),r=df(a),i=q.getNodeAttribute(pe,"value"),o=q.getNodeAttribute(pe,"noise")??0,s=i>0?Math.min(o/i,1):0,l=(t+12)*(.86+.14*r),u=l+15,d=u+11;B.save(),B.globalAlpha=r,B.translate(n,e),B.strokeStyle="rgba(241,207,134,0.6)",B.lineWidth=1,B.beginPath(),B.arc(0,0,l,0,Math.PI*2),B.stroke();for(let c=0;c<72;c++){let h=c/72*Math.PI*2,f=c%6===0;B.strokeStyle=f?"rgba(241,207,134,0.5)":"rgba(241,207,134,0.22)",B.beginPath(),B.moveTo(Math.cos(h)*(l+3),Math.sin(h)*(l+3)),B.lineTo(Math.cos(h)*(l+(f?10:6)),Math.sin(h)*(l+(f?10:6))),B.stroke()}if(s>0){let c=-Math.PI/2,h=s*Math.PI*2*r;B.lineCap="round",B.lineWidth=3,s<1&&(B.strokeStyle="rgba(94,214,178,0.45)",B.beginPath(),B.arc(0,0,u,c+h+.08,c+Math.PI*2-.08),B.stroke()),B.strokeStyle=de.activeEdge,B.shadowColor=de.activeEdge,B.shadowBlur=10,B.beginPath(),B.arc(0,0,u,c,c+h),B.stroke(),B.shadowBlur=0,B.lineCap="butt"}B.strokeStyle="rgba(255,255,255,0.55)",B.lineWidth=1.2;for(let[c,h]of[[-1,-1],[1,-1],[1,1],[-1,1]])B.beginPath(),B.moveTo(c*d,h*(d-10)),B.lineTo(c*d,h*d),B.lineTo(c*(d-10),h*d),B.stroke();B.restore(),hf(n,e,d,s,o,i,r)}function hf(a,n,e,t,r,i,o){let{width:s}=j.getDimensions(),l=q.getNodeAttribute(pe,"label")??"",u=l.length>30?`${l.slice(0,29)}\u2026`:l,d=t>0?`${Math.round(t*100)}%`:"",c=q.getNodeAttribute(pe,"unit")??(i===1?"item":"items"),h=t>0?`${r.toLocaleString()} of ${i.toLocaleString()}`:`${i.toLocaleString()} ${c}`,f="600 12px -apple-system, sans-serif",g="600 13px ui-monospace, Menlo, monospace",m="500 11px -apple-system, sans-serif";B.save(),B.globalAlpha=o,B.font=f;let p=B.measureText(u).width;B.font=g;let v=B.measureText(d).width;B.font=m;let b=t>0?v+B.measureText(" generated").width:0,y=Math.max(p,b,B.measureText(h).width)+18,_=t>0?54:38,x=s-lt.right,T=a+e+10+y>x?a-e-10-y:a+e+10,R=Math.max(n-_/2,8);B.fillStyle="rgba(8,14,16,0.86)",B.strokeStyle="rgba(241,207,134,0.3)",B.lineWidth=1,B.beginPath(),B.roundRect(T,R,y,_,8),B.fill(),B.stroke(),B.textBaseline="alphabetic",B.font=f,B.fillStyle="#fff4dc",B.fillText(u,T+9,R+16);let E=R+32;t>0&&(B.font=g,B.fillStyle=de.activeEdge,B.fillText(d,T+9,E),B.font=m,B.fillStyle="rgba(230,238,240,0.75)",B.fillText(" generated",T+9+v,E),E+=14),B.font=m,B.fillStyle="rgba(154,171,176,0.95)",B.fillText(h,T+9,E),B.restore()}function ff(a){Gn.length!==0&&(B.save(),B.fillStyle=de.suspect,B.shadowColor=de.suspect,B.shadowBlur=8,Gn.forEach((n,e)=>{let[t,r]=q.extremities(n),i=zn(t),o=zn(r);for(let s=0;s<2;s++){let l=e*.17+s*.5,u=Je?(a/1800+l)%1:l%1;B.beginPath(),B.arc(i.x+(o.x-i.x)*u,i.y+(o.y-i.y)*u,1.7,0,Math.PI*2),B.fill()}}),B.restore())}function Wn(){let a=performance.now(),{width:n,height:e}=j.getDimensions();of(),uf(),B.clearRect(0,0,n,e),ff(a),cf(a)}function Ss(){return Je?Gn.length>0||pe!==null&&performance.now()-Ur<Is:!1}function Ms(){if(Pr!==null||!Ss())return;let a=()=>{Wn(),Pr=Ss()?requestAnimationFrame(a):null};Pr=requestAnimationFrame(a)}j.on("afterRender",Wn);function Es(a,n,e,t=22){let r=Math.max(6,Math.min(t,22*Math.sqrt(40/e))),i=Math.max(1.5,Math.min(4,4*Math.sqrt(100/e))),o=n<=1?.3:Math.sqrt(a/n);return i+o*(r-i)}function gf(a){return a<=200?400:a<=1e3?200:80}var Jt=a=>q.getNodeAttribute(a,"value");function Os(a,n){let e=q.getNodeAttribute(a,"group"),t=q.getNodeAttribute(n,"group");return e!==t?e-t:Jt(n)-Jt(a)}function vf(){if(St)return St;if(q.order<2)return St={...za},St;let a={};return q.forEachNode((n,e)=>{a[n]={x:e.x,y:e.y},q.mergeNodeAttributes(n,za[n])}),St=(0,Ir.default)(q,{iterations:gf(q.order),getEdgeWeight:"weight",settings:{...Ir.default.inferSettings(q),barnesHutOptimize:q.order>300,linLogMode:!0,scalingRatio:q.order>100?40:10,outboundAttractionDistribution:!0}}),q.forEachNode(n=>q.mergeNodeAttributes(n,a[n])),St}var Ws=a=>Math.PI/2-a*2*Math.PI;function Bs(){let a=q.nodes().sort(Os),n={};return a.forEach((e,t)=>{let r=Ws(t/a.length);n[e]={x:Math.cos(r)*100,y:Math.sin(r)*100}}),n}var Mr=7,pf=Mr*Mr*2.5,mf=.6180339887498949;function bf(){let a=d=>q.getNodeAttribute(d,"ring"),n=q.filterNodes(d=>a(d)===1).sort(Os);if(n.length===0)return Bs();let e=new Map(n.map(d=>[d,[]]));q.forEachNode((d,c)=>{c.ring===2&&e.has(c.parent)&&e.get(c.parent).push(d)});for(let d of e.values())d.sort((c,h)=>Jt(h)-Jt(c));let r=[...e.values()].some(d=>d.length>0)?150:170,i=250,o=n.map(d=>4+Math.sqrt(e.get(d).length)),s=o.reduce((d,c)=>d+c,0),l={};q.forEachNode((d,c)=>{c.ring===0&&(l[d]={x:0,y:0})});let u=0;return n.forEach((d,c)=>{let h=o[c]/s,f=h*2*Math.PI,g=Ws(u+h/2);l[d]={x:Math.cos(g)*r,y:Math.sin(g)*r};let m=e.get(d);if(m.length>0){let p=f*.9,v=Math.max(1,Math.floor(p*i/Mr));if(m.length<=v)m.forEach((b,y)=>{let _=m.length===1?g:g+p/2-p*(y+.5)/m.length;l[b]={x:Math.cos(_)*i,y:Math.sin(_)*i}});else{let b=Math.sqrt(i**2+2*m.length*pf/p),y=(zr(d)>>>0)/4294967296;m.forEach((_,x)=>{let T=Ns(zr(_)),R=Math.min(1,(x+.1+.8*T())/m.length),E=Math.sqrt(i**2+R*(b**2-i**2)),S=(x*mf+y)%1-.5+(T()-.5)*.12,w=g+Math.max(-.5,Math.min(.5,S))*p;l[_]={x:Math.cos(w)*E,y:Math.sin(w)*E}})}}u+=h}),l}function yf(){let n=new Map;q.forEachNode((i,o)=>{let s=o.area??Cs.get(o.group)??"Other";n.has(s)||n.set(s,[]),n.get(s).push(i)});let e=[...n.entries()].map(([i,o])=>({label:i,ids:o.sort((s,l)=>Jt(l)-Jt(s)),radius:6*(Math.sqrt(o.length)+2),x:0,y:0})).sort((i,o)=>o.ids.length-i.ids.length);e.forEach((i,o)=>{let s=o*Ia,l=o===0?0:(e[0].radius+i.radius)*Math.sqrt(o);i.x=Math.cos(s)*l,i.y=Math.sin(s)*l});let t=6*3;for(let i=0;i<400;i++){for(let s of e)s.x*=.97,s.y*=.97;let o=!1;for(let s=0;s<e.length;s++)for(let l=s+1;l<e.length;l++){let u=e[s],d=e[l],c=d.x-u.x,h=d.y-u.y,f=Math.hypot(c,h),g=u.radius+d.radius+t;if(f>=g)continue;o=!0,f<.001&&(c=Math.cos(l),h=Math.sin(l),f=1);let m=(g-f)/2;u.x-=c/f*m,u.y-=h/f*m,d.x+=c/f*m,d.y+=h/f*m}if(!o&&i>40)break}let r={};for(let i of e)i.ids.forEach((o,s)=>{let l=6*Math.sqrt(s+.5);r[o]={x:i.x+Math.cos(s*Ia)*l,y:i.y+Math.sin(s*Ia)*l}});return Na=e,r}function xf(a){switch(a){case"circle":return Bs();case"rings":return bf();case"areas":return yf();default:return vf()}}function _f(){if(Ts.replaceChildren(),On!=="areas"){Na=[];return}for(let a of Na){if(a.ids.length<2)continue;let n=document.createElement("div");n.className="area",n.textContent=a.label,Ts.appendChild(n),a.element=n}Us()}function Us(){for(let a of Na){if(!a.element)continue;let n=j.graphToViewport({x:a.x,y:a.y+a.radius}),e=j.graphToViewport({x:a.x,y:a.y-a.radius});a.element.style.left=`${n.x}px`,a.element.style.top=`${Math.min(n.y,e.y)-4}px`;let t=ut===null||a.ids.some(r=>q.getNodeAttribute(r,"group")===ut);a.element.style.opacity=t?"0.75":"0.2"}}j.on("afterRender",Us);var Or={x:.5,y:.5,ratio:1,angle:0},Tf=110;function Hr(){let a=j.getSetting("renderLabels")?Tf:0;return{left:lt.left,right:Math.max(lt.right,lt.left)+a,top:lt.top,bottom:lt.bottom}}function Hs(){let a=j.framedGraphToViewport({x:.5,y:.5},{cameraState:Or}),n=j.framedGraphToViewport({x:.6,y:.6},{cameraState:Or});return{x:(n.x-a.x)/.1,y:(n.y-a.y)/.1}}function $r(a,n,e){let t=Hs(),r=Hr(),i=(r.left-r.right)/2,o=(r.top-r.bottom)/2;return{x:a-i*e/t.x,y:n-o*e/t.y,ratio:e,angle:0}}function $s(){let{width:a,height:n}=j.getDimensions(),e=Hr(),t={x:(e.left+a-e.right)/2,y:(e.top+n-e.bottom)/2};return j.viewportToFramedGraph(t,{cameraState:j.getCamera().getState()})}var Wr=null;j.on("afterProcess",()=>{let a=1/0,n=-1/0,e=1/0,t=-1/0;q.forEachNode(r=>{let i=j.getNodeDisplayData(r);i&&(a=Math.min(a,i.x),n=Math.max(n,i.x),e=Math.min(e,i.y),t=Math.max(t,i.y))}),Wr=a===1/0?null:{minX:a,maxX:n,minY:e,maxY:t}});function Sf(){if(!Wr)return Or;let{minX:a,maxX:n,minY:e,maxY:t}=Wr,{width:r,height:i}=j.getDimensions(),o=Hs(),s=Hr(),l=Math.max(120,r-s.left-s.right-48),u=Math.max(120,i-s.top-s.bottom-48),d=Math.max(.75,(n-a)*Math.abs(o.x)/l,(t-e)*Math.abs(o.y)/u),{x:c,y:h}=$r((a+n)/2,(e+t)/2,d);return{x:c,y:h,ratio:d,angle:0}}var Fn=null,Nn=!0,In=null,Fr=(a,n)=>Math.abs(a-n)<=1e-6*Math.max(1,Math.abs(n));function Vs(){if(!Fn)return!0;let a=j.getCamera();if(a.isAnimating())return Nn;let n=a.getState();return Fr(n.x,Fn.x)&&Fr(n.y,Fn.y)&&Fr(n.ratio,Fn.ratio)}function Mn(a){let n=j.getCamera(),e=Sf();Ps=e.ratio,Fn=n.validateState(e),Nn=!0,a>0&&Je?n.animate(e,{duration:a}):(n.isAnimating()&&n.cancelAnimation(),n.setState(e))}function Ef(){if(Vs())Mn(0);else if(In){let a=j.getCamera();a.setState($r(In.x,In.y,a.getState().ratio))}}function Rs(a){let n=Vs();a(),q.order!==0&&(n?Mn(220):In=$s())}j.getCamera().on("updated",()=>{In=$s()});j.on("resize",Ef);for(let a of["wheel","mousedown","doubleClick"])j.getMouseCaptor().on(a,()=>{Nn=!1});function qs(a,n){On=a,j.refresh();let e=xf(a);Pn&&(Pn(),Pn=null),n&&Je&&q.order<=3e3?Pn=ur(q,e,{duration:450,easing:"quadraticInOut"},()=>{Pn=null,j.refresh(),Mn(200)}):(q.updateEachNodeAttributes((t,r)=>({...r,...e[t]}),{attributes:["x","y"]}),j.refresh(),Mn(0)),_f()}function Rf(){if(!Je)return;let a=j.getCamera(),n=a.getState();a.setState({...n,ratio:n.ratio*1.6}),a.animate(n,{duration:420,easing:"cubicOut"})}function Af(a,n,e){Yt=null,pe=null,ut=null,Et=new Set,Ga=new Set,Gn=[],St=null,za={},Ls=new Map(a.groups.map(o=>[o.id,o.slot])),Cs=new Map(a.groups.map(o=>[o.id,o.label])),q.clear();let t=new Map;for(let o of a.nodes){let s=o.ring??"all",l=t.get(s)??{maximum:1,count:0};l.maximum=Math.max(l.maximum,o.value),l.count+=1,t.set(s,l)}let r=Math.max(a.nodes.length,1);a.nodes.forEach((o,s)=>{let l=t.get(o.ring??"all"),u=(o.group+s/r)*Ia,d=10+Math.sqrt(s)*4,c={x:Math.cos(u)*d,y:Math.sin(u)*d};za[o.id]=c,q.addNode(o.id,{...c,size:o.ring===0?Es(2,2,60):Es(Kt(o)?1:o.value,l.maximum,l.count,o.ring===1?16:22)*(Kt(o)?.6:1),label:o.label,hoverText:`${o.label}  \xB7  ${o.value.toLocaleString()}`,value:o.value,group:o.group,ghost:o.ghost,ring:o.ring,parent:o.parent,area:o.area,noise:o.noise,unit:o.unit,isDust:Kt(o),color:Jh(o),rank:Math.round(Math.sqrt(o.value))})});let i=a.edges.reduce((o,s)=>Math.max(o,s.tree?1:s.weight),1);for(let o of a.edges)!q.hasNode(o.source)||!q.hasNode(o.target)||o.source===o.target||q.hasEdge(o.source,o.target)||q.addEdge(o.source,o.target,{size:o.tree?.5:.5+Math.log1p(o.weight)/Math.log1p(i)*2.5,weight:o.weight,tree:!!o.tree,baseColor:ef(o),isSuspect:(o.suspect??0)*2>=o.weight&&!o.tree});rf(a.nodes),qs(n||On,!1),j.setGraphState({hasFocus:!1}),e&&Rf(),Wn(),dt({type:"rendered",nodes:q.order,edges:q.size})}window.studio={render:Af,setLayout(a){a!==On&&qs(a,!0)},setLabels(a){j.getSetting("renderLabels")!==a&&Rs(()=>j.setSetting("renderLabels",a))},isolate(a){ut=a,Zt()},setReviewing(a){Qt=a,j.setGraphState({isReviewing:Qt}),Zt()},spotlight(a){Gr=a?new Set(a):null,Zt()},setMotion(a){Je=a,Ms(),Wn()},setInsets(a){["left","right","top","bottom"].every(e=>lt[e]===a[e])||Rs(()=>{lt=a})},fit(){j.refresh(),Mn(250)},zoom(a){let n=j.getCamera(),e=Je?200:0;Nn=!1,a?n.zoomIn({duration:e}):n.zoomOut({duration:e})},focus(a,n=!0){if(!q.hasNode(a))return!1;if(Br(a),!n)return dt({type:"select",id:a}),!0;let e=j.getNodeDisplayData(a);if(e){Nn=!1;let t=$r(e.x,e.y,.3);Je?j.getCamera().animate(t,{duration:500}):j.getCamera().setState(t)}return dt({type:"select",id:a}),!0}};tf();dt({type:"ready"});})();
/*! Bundled license information:

sigma/dist/edge-data-texture-0ba3f15f.esm.js:
  (*! regenerator-runtime -- Copyright (c) 2014-present, Facebook, Inc. -- license (MIT): https://github.com/babel/babel/blob/main/packages/babel-helpers/LICENSE *)
*/
