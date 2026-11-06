(** React 19's resource hints, as reason-react 0.17 declares them in [ReactDOM.Experimental]: each
    adds one tag to the document's head, once per resource, as React does on the client. *)

(** The options of [preload]. *)
type preloadOptions

external preloadOptions :
  _as:
    [ `audio [@mel.as "audio"]
    | `document [@mel.as "document"]
    | `embed [@mel.as "embed"]
    | `fetch [@mel.as "fetch"]
    | `font [@mel.as "font"]
    | `image [@mel.as "image"]
    | `object_ [@mel.as "object"]
    | `script [@mel.as "script"]
    | `style [@mel.as "style"]
    | `track [@mel.as "track"]
    | `video [@mel.as "video"]
    | `worker [@mel.as "worker"] ] ->
  ?fetchPriority:[ `auto | `high | `low ] ->
  ?referrerPolicy:
    [ `noReferrer [@mel.as "no-referrer"]
    | `noReferrerWhenDowngrade [@mel.as "no-referrer-when-downgrade"]
    | `origin [@mel.as "origin"]
    | `originWhenCrossOrigin [@mel.as "origin-when-cross-origin"]
    | `unsafeUrl [@mel.as "unsafe-url"] ] ->
  ?imageSrcSet:string ->
  ?imageSizes:string ->
  ?crossOrigin:string ->
  ?integrity:string ->
  ?nonce:string ->
  unit ->
  preloadOptions = ""
[@@mel.obj]

(** The options of [preinit]: a script or a stylesheet, with its precedence. *)
type preinitOptions = {
  _as : [ `script | `style ]; [@mel.as "as"]
  fetchPriority : [ `auto | `high | `low ] option; [@mel.optional]
  precedence : [ `reset | `low | `medium | `high ] option; [@mel.optional]
  crossOrigin : string option; [@mel.optional]
  integrity : string option; [@mel.optional]
  nonce : string option; [@mel.optional]
}
[@@deriving jsProperties]

(** The options of [preinitModule] and [preloadModule]. *)
type preOptions = {
  _as : [ `script ]; [@mel.as "as"]
  crossOrigin : string option; [@mel.optional]
  integrity : string option; [@mel.optional]
  nonce : string option; [@mel.optional]
}
[@@deriving jsProperties]

val preconnect : string -> unit
val prefetchDNS : string -> unit
val preinit : string -> ?options:preinitOptions -> unit -> unit
val preinitModule : string -> ?options:preOptions -> unit -> unit
val preload : string -> ?options:preloadOptions -> unit -> unit
val preloadModule : string -> ?options:preOptions -> unit -> unit
