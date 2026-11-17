(** Bindings that a reason-react codebase writes to npm's [react] and [react-dom] directly
    ([external useReducer : … = "useReducer" [@@mel.module "react"]]): every use of its name below it
    in the module becomes Melact's own function, so that hooks get their keys as [React.useReducer]
    does, and the binding itself becomes a definition that calls that function, for other files.
    Dependencies typed as an n-tuple pick [React.useEffectn], an array [React.useEffect1]. Bindings
    to anything else are left as they are. A hook of a module whose callers give their call site's
    key ([keys] says [`Given], as for [-hook-modules]) takes that key first instead of keeping one. *)

val structure : keys:(string -> string -> [ `Given | `Own ]) -> Ppxlib.structure -> Ppxlib.structure
