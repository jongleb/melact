(** Bindings that a reason-react codebase writes to npm's [react] and [react-dom] directly
    ([external useReducer : … = "useReducer" [@@mel.module "react"]]): every use of its name below it
    in the module becomes Melact's own function, so that hooks get their keys as [React.useReducer]
    does, and the binding itself becomes a definition that calls that function, for other files.
    Dependencies typed as an n-tuple pick [React.useEffectn], an array [React.useEffect1]. Bindings
    to anything else are left as they are. *)

val structure : Ppxlib.structure -> Ppxlib.structure
