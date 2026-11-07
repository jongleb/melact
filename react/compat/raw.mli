(** Any JavaScript value that React's API receives or returns, and what [typeof] says about it. *)

type t

type view =
  | Missing  (** [undefined] or [null]. *)
  | Flag of bool
  | Number of float
  | Text of string
  | Callable of t
  | Listed of t array
  | Record of t  (** An object that is not an array or a function. *)
  | Other of t  (** A symbol or a bigint. *)

val view : t -> view

external of_any : 'a -> t = "%identity"
external to_any : t -> 'a = "%identity"
external get : t -> string -> t = "" [@@mel.get_index]
external set : t -> string -> 'a -> unit = "" [@@mel.set_index]
external same : t -> t -> bool = "is" [@@mel.scope "Object"]
external keys : t -> string array = "keys" [@@mel.scope "Object"]
external undefined : t = "undefined"
external null : t = "null"
external symbol : string -> t = "for" [@@mel.scope "Symbol"]
external call0 : t -> (_[@mel.as {json|undefined|json}]) -> t = "call" [@@mel.send]
external call1 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t = "call" [@@mel.send]
external call2 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t -> t = "call" [@@mel.send]
external call3 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t -> t -> t = "call" [@@mel.send]
external call_on : t -> t -> t array -> t = "apply" [@@mel.send]
external construct : t -> t array -> t = "construct" [@@mel.scope "Reflect"]
external text_of : t -> string = "String"
external merged : t -> t -> t -> t = "assign" [@@mel.scope "Object"]
external make_object : unit -> t = "Object" [@@mel.new]
external list_of : t array -> t = "%identity"
external own : t -> string -> bool = "hasOwn" [@@mel.scope "Object"]

(** The value of a property, [None] when it is [undefined] or [null]. *)
val find : t -> string -> t option

(** The value itself, [None] when it is [undefined] or [null]. *)
val present : t -> t option

(** A plain object of the given fields. *)
val record : (string * t) list -> t

(** [Unchanged] when both objects have the same fields with the same values ([Object.is]), as React's [shallowEqual]. *)
val shallow : t -> t -> Melhole.View.change

(** A JavaScript [WeakMap] from objects to values of one type. *)
type 'value table

val table : unit -> 'value table
val lookup : 'value table -> t -> 'value option
external store : 'value table -> t -> 'value -> unit = "set" [@@mel.send]
