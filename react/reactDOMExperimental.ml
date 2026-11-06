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

type preinitOptions = {
  _as : [ `script | `style ]; [@mel.as "as"]
  fetchPriority : [ `auto | `high | `low ] option; [@mel.optional]
  precedence : [ `reset | `low | `medium | `high ] option; [@mel.optional]
  crossOrigin : string option; [@mel.optional]
  integrity : string option; [@mel.optional]
  nonce : string option; [@mel.optional]
}
[@@deriving jsProperties]

type preOptions = {
  _as : [ `script ]; [@mel.as "as"]
  crossOrigin : string option; [@mel.optional]
  integrity : string option; [@mel.optional]
  nonce : string option; [@mel.optional]
}
[@@deriving jsProperties]

(** What a hint adds to the head, and what it is found by when it is already there. *)
type tag = Link of string | Script

(** Where a new tag goes: at the end of the head, or right after another one. *)
type place = At_end | After of Dom.element

external document : Dom.document = "document"
external head : Dom.document -> Dom.element = "head" [@@mel.get]
external create_element : Dom.document -> string -> Dom.element = "createElement" [@@mel.send]
external set_attribute : Dom.element -> string -> string -> unit = "setAttribute" [@@mel.send]
external query : Dom.element -> string -> Dom.element Js.null = "querySelector" [@@mel.send]
external append_child : Dom.element -> Dom.element -> unit = "appendChild" [@@mel.send]
external insert_after : Dom.element -> string -> Dom.element -> unit = "insertAdjacentElement" [@@mel.send]
external query_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external elements : Dom.nodeList -> Dom.element array = "from" [@@mel.scope "Array"]
external field : 'options -> string -> string Js.undefined = "" [@@mel.get_index]

let added ?(place = fun () -> At_end) tag href attributes =
  let quoted = "\"" ^ String.concat "\\\\" (String.split_on_char '\\' href |> List.map (fun part -> String.concat "\\\"" (String.split_on_char '"' part))) ^ "\"" in
  let selector, name, located =
    match tag with
    | Link rel -> ("link[rel=\"" ^ rel ^ "\"][href=" ^ quoted ^ "]", "link", [ ("rel", rel); ("href", href) ])
    | Script -> ("script[src=" ^ quoted ^ "]", "script", [ ("src", href) ])
  in
  match Js.Null.toOption (query (head document) selector) with
  | Some _ -> ()
  | None ->
      let element = create_element document name in
      List.iter (fun (name, value) -> set_attribute element name value) (located @ attributes);
      match place () with
      | At_end -> append_child (head document) element
      | After previous -> insert_after previous "afterend" element

let given options names =
  List.filter_map
    (fun (attribute, name) ->
      Option.bind options (fun options -> Option.map (fun value -> (attribute, value)) (Js.Undefined.toOption (field options name))))
    names

let preconnect href = added (Link "preconnect") href []
let prefetchDNS href = added (Link "dns-prefetch") href []

let preload href ?options () =
  Option.iter
    (fun options ->
      added (Link "preload") href
        (given (Some options)
           [
             ("as", "as"); ("fetchpriority", "fetchPriority"); ("referrerpolicy", "referrerPolicy");
             ("imagesrcset", "imageSrcSet"); ("imagesizes", "imageSizes"); ("crossorigin", "crossOrigin");
             ("integrity", "integrity"); ("nonce", "nonce");
           ]))
    (Option.bind options (fun options -> Option.map (fun (_ : string) -> options) (Js.Undefined.toOption (field options "as"))))

let preloadModule href ?options () =
  added (Link "modulepreload") href
    (given options [ ("crossorigin", "crossOrigin"); ("integrity", "integrity"); ("nonce", "nonce") ])

let preinit href ?options () =
  let common = given options [ ("crossorigin", "crossOrigin"); ("integrity", "integrity"); ("fetchpriority", "fetchPriority") ] in
  match Option.map (fun (options : preinitOptions) -> options._as) options with
  | Some `style ->
      let precedence =
        Option.value ~default:"default"
          (Option.bind options (fun (options : preinitOptions) ->
               Option.map
                 (fun precedence -> match precedence with `reset -> "reset" | `low -> "low" | `medium -> "medium" | `high -> "high")
                 options.precedence))
      in
      let last selector =
        let found = elements (query_all (head document) selector) in
        match Array.length found with 0 -> None | count -> Some found.(count - 1)
      in
      added
        ~place:(fun () ->
          match (last ("link[rel=\"stylesheet\"][data-precedence=\"" ^ precedence ^ "\"]"), last "link[rel=\"stylesheet\"][data-precedence]") with
          | Some same, _ -> After same
          | None, Some other -> After other
          | None, None -> At_end)
        (Link "stylesheet") href
        (("data-precedence", precedence) :: common)
  | Some `script | None -> added Script href (("async", "") :: common @ given options [ ("nonce", "nonce") ])

let preinitModule href ?options () =
  added Script href
    (("type", "module") :: ("async", "")
    :: given options [ ("crossorigin", "crossOrigin"); ("integrity", "integrity"); ("nonce", "nonce") ])
