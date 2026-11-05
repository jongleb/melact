(** Bindings that a reason-react codebase writes to npm's [react] and [react-dom] directly
    ([external useReducer : … = "useReducer" [@@mel.module "react"]]): each one is dropped, and
    every use of its name below it in the module becomes Melact's own function, so that hooks get
    their keys as [React.useReducer] does. Bindings to anything else are left as they are. *)

val structure : Ppxlib.structure -> Ppxlib.structure
