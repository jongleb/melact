With -typed, a binding to npm's Fragment that only its type shows to be a component of children
becomes Melact's fragment, constrained to the type it was declared with; one whose type is not
stays as it is. The compiler runs the rewriter, so the typed pass has its load path:

  $ cat > react.mli <<'EOF'
  > type element
  > type 'props component = 'props -> element
  > val reason_react_is_also_in_this_build_remove_it : unit -> unit
  > EOF
  $ cat > js.mli <<'EOF'
  > type 'a t
  > EOF
  $ cat > melact_npm.mli <<'EOF'
  > val fragment : < children : React.element ; .. > Js.t -> React.element
  > EOF
  $ ocamlc -c react.mli js.mli melact_npm.mli
  $ cat > fragments.ml <<'EOF'
  > type props = < children : React.element ; key : string > Js.t
  > type fragment = props React.component
  > type text = string -> React.element
  > external fragment : fragment = "Fragment" [@@mel.module "react"]
  > external text : text = "Fragment" [@@mel.module "react"]
  > EOF
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx -typed' fragments.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  type props = < children: React.element  ;key: string   >  Js.t
  type fragment = props React.component
  type text = string -> React.element
  let (fragment : fragment) = Melact_npm.fragment[@@warning "-32"]
  external text : text = "Fragment"[@@mel.module "react"]

Without -typed, both stay:

  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx' fragments.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  type props = < children: React.element  ;key: string   >  Js.t
  type fragment = props React.component
  type text = string -> React.element
  external fragment : fragment = "Fragment"[@@mel.module "react"]
  external text : text = "Fragment"[@@mel.module "react"]

A file that does not type is left exactly as the untyped rewrite wrote it, with no mark of the
typed pass:

  $ cat >> fragments.ml <<'EOF'
  > let broken = not_defined_anywhere
  > EOF
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx' fragments.ml 2> untyped.ml
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx -typed' fragments.ml 2> typed.ml
  $ diff untyped.ml typed.ml
  $ grep -c melhole typed.ml
  0
  [1]
  $ grep -c not_defined_anywhere typed.ml
  1
