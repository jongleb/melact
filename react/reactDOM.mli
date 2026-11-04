(** reason-react's [ReactDOM] for melact: mounting roots. *)

module Client : sig
  (** A container element and what is rendered into it. *)
  type root

  val createRoot : Dom.element -> root
  val render : root -> React.element -> unit
  val unmount : root -> unit -> unit
end

val render : React.element -> Dom.element -> unit
[@@deprecated "Use ReactDOM.Client.createRoot and ReactDOM.Client.render instead."]

val flushSync : (unit -> unit) -> unit
