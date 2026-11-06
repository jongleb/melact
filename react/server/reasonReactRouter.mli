(** reason-react's router in Melact's server build: [useUrl] gives [serverUrl], or the URL of the page
    where there is one. *)

(** The URL without its scheme and host. *)
type url = {
  path : string list;  (** The path split at [/], without empty parts. *)
  hash : string;  (** The fragment without its [#]. *)
  search : string;  (** The query without its [?]. *)
}

(** A subscription made by [watchUrl]. *)
type watcherID

val push : string -> unit
val replace : string -> unit
val watchUrl : (url -> unit) -> watcherID
val unwatchUrl : watcherID -> unit
val dangerouslyGetInitialUrl : ?serverUrlString:string -> unit -> url

val useUrl : ?serverUrl:url -> unit -> url
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
