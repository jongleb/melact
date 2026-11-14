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

A custom hook that calls a hook given for a labelled parameter gets a fact naming that label, and one
that passes React's hook for it adds the slots of that hook. A hook-named value the body only reads,
like a flag named useLayoutEffect, keeps the fact from being certain: with -typed the fact is given
when the type shows the value is not a function, and never without -typed. The fact reaches the .cmi,
so a component in another file that calls the hook compiles to an update graph:

  $ mkdir hooks && cd hooks
  $ cat > melact_runtime.mli <<'EOF'
  > module Hook : sig
  >   type 'a key
  >   val key : unit -> 'a key
  >   val unchecked : 'a key -> 'a key
  > end
  > EOF
  $ cat > react.mli <<'EOF'
  > type element
  > val reason_react_is_also_in_this_build_remove_it : unit -> unit
  > val useState : 'k Melact_runtime.Hook.key -> (unit -> 'a) -> 'a * (('a -> 'a) -> unit)
  > val useEffect2 : 'k Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> 'a * 'b -> unit
  > val useMemo1 : 'k Melact_runtime.Hook.key -> (unit -> 'a) -> 'b array -> 'a
  > EOF
  $ ocamlc -c melact_runtime.mli react.mli
  $ cat > remote.ml <<'EOF'
  > let use ?(skip = false) ?(useLayoutEffect = false) ~(useMemo : (unit -> 'deps) -> 'deps -> 'memo) fetch dependencies =
  >   let memo = useMemo (fun () -> dependencies) dependencies in
  >   let data, setData = React.useState (fun () -> None) in
  >   React.useEffect2 (fun () -> if not skip then setData (fun _ -> Some (fetch memo)); None) (memo, useLayoutEffect);
  >   data
  > 
  > let use1 ?skip ?useLayoutEffect fetch dependencies = use ?skip ?useLayoutEffect ~useMemo:React.useMemo1 fetch dependencies
  > 
  > let useBare ~(useMemo : (unit -> 'deps) -> 'deps -> 'memo) dependencies =
  >   let memo = useMemo (fun () -> dependencies) dependencies in
  >   let data, _ = React.useState (fun () -> memo) in
  >   data
  > 
  > let useLayered ~(useLayoutEffect : unit -> unit) dependencies =
  >   let data, _ = React.useState (fun () -> (dependencies, useLayoutEffect)) in
  >   data
  > EOF
  $ ocamlc -stop-after parsing -dsource -ppx '../pp.exe --as-ppx -typed' remote.ml 2>&1 | grep -E '^let (\(\()?use'
  let ((use)[@melhole.hook (2, 2, "useMemo")]) =
  let ((use1)[@melhole.hook (2, 3)]) =
  let ((useBare)[@melhole.hook (2, 1, "useMemo")]) =
  let useLayered ~useLayoutEffect:(useLayoutEffect : unit -> unit) dependencies
  $ ocamlc -stop-after parsing -dsource -ppx '../pp.exe --as-ppx' remote.ml 2>&1 | grep -E '^let (\(\()?use'
  let use ?(skip= false) ?(useLayoutEffect= false)
  let use1 ?skip ?useLayoutEffect fetch dependencies =
  let ((useBare)[@melhole.hook (2, 1, "useMemo")]) =
  let useLayered ~useLayoutEffect:(useLayoutEffect : unit -> unit) dependencies
  $ cat > view.ml <<'EOF'
  > let make ~id () =
  >   let data = Remote.use1 ~useLayoutEffect:true (fun deps -> deps.(0)) [| id |] in
  >   ((p ~children:[ React.string (Option.value ~default:"loading" data) ] ())[@JSX])
  > [@@react.component]
  > EOF
  $ ocamlc -c -ppx '../pp.exe --as-ppx -typed' remote.ml
  $ ocamlc -stop-after parsing -dsource -ppx '../pp.exe --as-ppx -typed' view.ml 2>&1 | grep -E 'Component\.|reaches'
  let __melhole_component_2 = Melact_runtime.Component.pure ~name:"View.make"
                     match Melact_runtime.Instance.reaches __melact_changed 29
  $ ocamlc -c -ppx '../pp.exe --as-ppx' remote.ml
  $ ocamlc -stop-after parsing -dsource -ppx '../pp.exe --as-ppx -typed' view.ml 2>&1 | grep -E 'Component\.|reaches'
  let __melhole_component_1 = Melact_runtime.Component.make ~name:"View.make"
