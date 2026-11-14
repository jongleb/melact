open Ppxlib
open Melhole_compiler

type rendering =
  | Pure
  | Reads_the_page  (** Reads the [current] of a ref it made with [useRef], and nothing else of the world. *)
  | Impure

(** A name a body binds that its render may use: a [ref] it made, or a ref [useRef] made. *)
type local = Own_cell of string | Own_ref of string

exception Reads_the_world

let rendering ~hooks body =
  let hook callee =
    match callee.pexp_desc with
    | Pexp_ident { txt; _ } -> (
        match Melhole_compiler.Hook_name.of_name (Longident.last_exn txt) with
        | Hook { base; _ } -> Some base
        | Plain -> None)
    | _ -> None
  in
  let found = ref Pure in
  let rec now cells expression =
    let each = List.iter (now cells) in
    let unbound cells pattern =
      List.filter
        (fun local -> match local with Own_cell name | Own_ref name -> not (List.mem name (Free.bound pattern)))
        cells
    in
    let cases cells branches =
      List.iter
        (fun case ->
          Option.iter (now (unbound cells case.pc_lhs)) case.pc_guard;
          now (unbound cells case.pc_lhs) case.pc_rhs)
        branches
    in
    let called_later value = match value.pexp_desc with Pexp_function _ -> () | _ -> now cells value in
    match expression.pexp_desc with
    | Pexp_ident { txt = Ldot (Ldot (Lident "Js", ("Date" | "Math")), _) | Ldot (Lident ("Random" | "Sys" | "Unix"), _); _ } ->
        raise Reads_the_world
    | Pexp_ident _ | Pexp_constant _ | Pexp_unreachable -> ()
    | Pexp_apply
        ( { pexp_desc = Pexp_ident { txt = Lident ("!" | ":=" | "incr" | "decr"); _ }; _ },
          (Nolabel, { pexp_desc = Pexp_ident { txt = Lident cell; _ }; _ }) :: rest )
      when List.mem (Own_cell cell) cells ->
        List.iter (fun (_, value) -> now cells value) rest
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident ("!" | ":=" | "incr" | "decr"); _ }; _ }, _) ->
        raise Reads_the_world
    | Pexp_apply (_, arguments) when Option.is_some (Element.without_jsx expression.pexp_attributes) ->
        List.iter
          (fun (label, value) ->
            match (label, Element.list_items value) with
            | Labelled "children", Some items -> each items
            | _ -> called_later value)
          arguments
    | Pexp_apply (callee, arguments) -> (
        let values = List.map snd arguments in
        match (hook callee, arguments) with
        | Some ("useEffect" | "useLayoutEffect" | "useInsertionEffect" | "useCallback" | "useImperativeHandle"), _ ->
            List.iter called_later values
        | Some ("useReducer" | "useReducerWithMapState"), _ -> (
            match values with
            | reducer :: rest ->
                called_later reducer;
                each rest
            | [] -> ())
        | Some ("useState" | "useMemo" | "useContext" | "useRef" | "useId" | "useDebugValue"), _ -> each values
        | Some _, _ -> (
            match hooks callee with Some _ -> each values | None -> raise Reads_the_world)
        | None, [ (Nolabel, { pexp_desc = Pexp_construct ({ txt = Lident "()"; _ }, None); _ }) ] -> raise Reads_the_world
        | None, _ ->
            now cells callee;
            each values)
    | Pexp_field ({ pexp_desc = Pexp_ident { txt = Lident name; _ }; _ }, { txt = Lident "current" | Ldot (_, "current"); _ })
      when List.mem (Own_ref name) cells ->
        found := Reads_the_page
    | Pexp_field (_, { txt = Lident ("contents" | "current") | Ldot (_, ("contents" | "current")); _ }) ->
        raise Reads_the_world
    | Pexp_field (target, _) -> now cells target
    | Pexp_let (_, bindings, rest) ->
        List.iter (fun binding -> now cells binding.pvb_expr) bindings;
        now
          (List.fold_left
             (fun cells binding ->
               match (binding.pvb_pat.ppat_desc, binding.pvb_expr.pexp_desc) with
               | Ppat_var { txt; _ }, Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident "ref"; _ }; _ }, [ _ ]) ->
                   Own_cell txt :: unbound cells binding.pvb_pat
               | Ppat_var { txt; _ }, Pexp_apply (callee, _) when Option.equal String.equal (hook callee) (Some "useRef") ->
                   Own_ref txt :: unbound cells binding.pvb_pat
               | _ -> unbound cells binding.pvb_pat)
             cells bindings)
          rest
    | Pexp_function (params, _, function_body) -> (
        let inner =
          List.fold_left
            (fun cells param ->
              match param.pparam_desc with
              | Pparam_val (_, default, pattern) ->
                  Option.iter (now cells) default;
                  unbound cells pattern
              | Pparam_newtype _ -> cells)
            cells params
        in
        match function_body with
        | Pfunction_body body -> now inner body
        | Pfunction_cases (branches, _, _) -> cases inner branches)
    | Pexp_match (target, branches) | Pexp_try (target, branches) ->
        now cells target;
        cases cells branches
    | Pexp_tuple items | Pexp_array items -> each items
    | Pexp_construct (_, argument) | Pexp_variant (_, argument) -> Option.iter (now cells) argument
    | Pexp_record (fields, base) ->
        List.iter (fun (_, value) -> now cells value) fields;
        Option.iter (now cells) base
    | Pexp_ifthenelse (test, yes, no) ->
        now cells test;
        now cells yes;
        Option.iter (now cells) no
    | Pexp_sequence (first, second) ->
        now cells first;
        now cells second
    | Pexp_constraint (inner, _)
    | Pexp_coerce (inner, _, _)
    | Pexp_lazy inner
    | Pexp_assert inner
    | Pexp_newtype (_, inner)
    | Pexp_poly (inner, _)
    | Pexp_open (_, inner) ->
        now cells inner
    | Pexp_setfield _ | Pexp_while _ | Pexp_for _ | Pexp_send _ | Pexp_new _ | Pexp_setinstvar _ | Pexp_override _
    | Pexp_letmodule _ | Pexp_letexception _ | Pexp_object _ | Pexp_pack _ | Pexp_letop _ | Pexp_extension _ ->
        raise Reads_the_world
  in
  match now [] body with () -> !found | exception Reads_the_world -> Impure

type step =
  | Statement of expression
  | Called of pattern * expression
  | Context of { pattern : pattern; context : expression; bit : int }
  | Memo of { pattern : pattern; hook : expression; mask : int }
  | Effect of { hook : expression; mask : int }
  | Derived of { pattern : pattern; value : expression; mask : int }

type plan = { steps : step list; result : expression; reads : int }

let every_source = (1 lsl 30) - 1

(** What makes a memo or an effect run again. *)
type dependencies =
  | Every_render  (** No dependencies given. *)
  | Once  (** The numbered hook with none, [useEffect0]. *)
  | Reading of expression  (** The dependencies given. *)

(** What a binding or a statement of a body is to its update graph, before bits are given. *)
type shape =
  | Run of expression
  | Cell of pattern * expression  (** [useState], [useReducer]: the first of the pair is the cell's value. *)
  | Stable of pattern * expression  (** [useRef], [useId]: the same value on every render. *)
  | Read of pattern * expression  (** [useContext] of a context. *)
  | Remembered of pattern * expression * dependencies  (** [useMemo], [useCallback]. *)
  | Effected of expression * dependencies
  | Computed of pattern * expression
  | Changing of pattern * expression  (** A value the rest of the body may change in place: made on every render. *)
  | Custom of pattern option * expression * int  (** A custom hook whose fact gives its hook slots. *)

exception Beyond

type fact = { slots : int; through : string list }

type 'condition counted = { fact : fact; values : expression list; conditions : 'condition list }

let react_slots name =
  match Melhole_compiler.Hook_name.of_name name with
  | Plain -> None
  | Hook { base; _ } -> (
      match base with
      | "useState" | "useReducer" | "useReducerWithMapState" | "useRef" | "useId" | "useMemo" | "useCallback" | "useEffect"
      | "useLayoutEffect" | "useInsertionEffect" | "useImperativeHandle" ->
          Some 1
      | "useContext" | "useDebugValue" -> Some 0
      | _ -> None)

let combined found more =
  {
    fact = { slots = found.fact.slots + more.fact.slots; through = found.fact.through @ more.fact.through };
    values = found.values @ more.values;
    conditions = found.conditions @ more.conditions;
  }

let passed ~hooks ~named counted arguments =
  let hook label =
    match
      List.find_map
        (fun (given, value) -> match given with Labelled name when String.equal name label -> Some value | _ -> None)
        arguments
    with
    | None -> raise Beyond
    | Some value -> (
        match (value.pexp_desc, named value, hooks value) with
        | Pexp_ident { txt = Ldot (Lident "React", name); _ }, _, _ -> (
            match react_slots name with
            | Some slots -> { fact = { slots; through = [] }; values = []; conditions = [] }
            | None -> raise Beyond)
        | _, `Local local, _ -> local
        | _, `Outer, Some ({ fact = { through = []; _ }; _ } as known) -> known
        | _, (`Shadowed | `Outer), _ -> raise Beyond)
  in
  ( List.fold_left
      (fun found label -> combined found (hook label))
      { counted with fact = { counted.fact with through = [] } }
      counted.fact.through,
    List.filter
      (fun (given, _) ->
        match given with Labelled name -> not (List.mem name counted.fact.through) | Nolabel | Optional _ -> true)
      arguments )

(** What the update graph makes of a value that may read mutable state. *)
type volatile =
  | Renders_whole  (** Nothing: the component renders whole. *)
  | Runs_every_render  (** A step that reads it runs on every render, as does what is made from it. *)

let plan ~hooks ~inputs ~props ~volatile body =
  let hook expression =
    match expression.pexp_desc with
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", name); _ }; _ }, arguments) -> (
        match Melhole_compiler.Hook_name.of_name name with
        | Plain -> None
        | Hook { base; dependencies } ->
            let values = List.map snd arguments in
            let dependencies =
              match (dependencies, List.rev values) with
              | "", _ -> Every_render
              | "0", _ -> Once
              | _, last :: _ -> Reading last
              | _, [] -> raise Beyond
            in
            Some (base, dependencies, values))
    | _ -> None
  in
  let checked expression =
    let finder =
      object
        inherit Ast_traverse.iter as super

        method! expression expression =
          match expression.pexp_desc with
          | Pexp_ident { txt; _ } -> (
              match Melhole_compiler.Hook_name.of_name (Longident.last_exn txt) with
              | Hook _ -> raise Beyond
              | Plain -> ())
          | _ -> super#expression expression
      end
    in
    finder#expression expression;
    expression
  in
  let shaped pattern value rest =
    let custom =
      match value.pexp_desc with
      | Pexp_apply (callee, arguments) ->
          Option.map
            (fun fact ->
              let counted, rest =
                passed
                  ~hooks:(fun hook -> Option.map (fun fact -> { fact; values = []; conditions = [] }) (hooks hook))
                  ~named:(fun _ -> `Outer)
                  { fact; values = []; conditions = [] }
                  arguments
              in
              List.iter (fun (_, argument) -> ignore (checked argument)) rest;
              Custom (pattern, value, counted.fact.slots))
            (hooks callee)
      | _ -> None
    in
    match (custom, hook value, pattern) with
    | Some shape, _, _ -> shape
    | None, None, None -> Run (checked value)
    | None, None, Some pattern -> (
        let value = Polymorphic.kept pattern value rest in
        match
          List.fold_left
            (fun found name ->
              match (found, Frozen.uses name rest) with
              | Frozen.Read_only, Frozen.Read_only -> Frozen.Read_only
              | (Frozen.Read_only | Frozen.Possibly_changed), _ -> Frozen.Possibly_changed)
            Frozen.Read_only (Free.bound pattern)
        with
        | Frozen.Possibly_changed -> Changing (pattern, checked value)
        | Frozen.Read_only -> Computed (pattern, checked value))
    | None, Some (base, dependencies, arguments), _ -> (
        List.iter (fun argument -> ignore (checked argument)) arguments;
        match (base, pattern) with
        | ("useState" | "useReducer" | "useReducerWithMapState"), Some pattern -> Cell (pattern, value)
        | ("useRef" | "useId"), Some pattern -> Stable (pattern, value)
        | "useContext", Some pattern -> (
            match arguments with [ context ] -> Read (pattern, context) | _ -> raise Beyond)
        | ("useMemo" | "useCallback"), Some pattern -> Remembered (pattern, value, dependencies)
        | ("useEffect" | "useLayoutEffect" | "useInsertionEffect" | "useImperativeHandle"), None ->
            Effected (value, dependencies)
        | "useDebugValue", None -> Run value
        | _ -> raise Beyond)
  in
  let rec read expression shapes =
    match expression.pexp_desc with
    | Pexp_sequence (first, rest) -> read rest (shaped None first rest :: shapes)
    | Pexp_let (Nonrecursive, [ binding ], rest) -> (
        match binding.pvb_pat.ppat_desc with
        | Ppat_construct ({ txt = Lident "()"; _ }, None) -> read rest (shaped None binding.pvb_expr rest :: shapes)
        | _ -> read rest (shaped (Some binding.pvb_pat) binding.pvb_expr rest :: shapes))
    | _ -> (List.rev shapes, checked expression)
  in
  match read body [] with
  | exception Beyond -> None
  | shapes, result -> (
      let slots =
        1
        + List.fold_left (fun found shape -> match shape with Custom (_, _, count) -> found + count | _ -> found) 0 shapes
        + List.length
            (List.filter
               (fun shape ->
                 match shape with
                 | Cell _ | Stable _ | Remembered _ | Effected _ -> true
                 | Run _ | Read _ | Computed _ | Changing _ | Custom _ -> false)
               shapes)
      in
      let contexts = List.length (List.filter (fun shape -> match shape with Read _ -> true | _ -> false) shapes) in
      match inputs + slots + contexts <= 30 with
      | false -> None
      | true -> (
          let mask env expression =
            match (Free.of_expression expression, volatile) with
            | Free.Volatile, Renders_whole -> raise Beyond
            | Free.Volatile, Runs_every_render -> every_source
            | Free.Reads names, (Renders_whole | Runs_every_render) ->
                List.fold_left
                  (fun found name -> found lor Option.value ~default:0 (List.assoc_opt name env))
                  0 names
          in
          let bind env pattern bits = List.map (fun name -> (name, bits)) (Free.bound pattern) @ env in
          let sources env dependencies =
            match dependencies with
            | Every_render -> every_source
            | Once -> 0
            | Reading value -> mask env value
          in
          let rec given env slot context shapes steps =
            match shapes with
            | [] -> (env, List.rev steps)
            | shape :: rest -> (
                match shape with
                | Run value -> given env slot context rest (Statement value :: steps)
                | Custom (pattern, value, count) ->
                    let bits = ((1 lsl count) - 1) lsl (inputs + slot) lor mask env value in
                    given
                      (Option.fold ~none:env ~some:(fun pattern -> bind env pattern bits) pattern)
                      (slot + count) context rest
                      (Option.fold ~none:(Statement value) ~some:(fun pattern -> Called (pattern, value)) pattern :: steps)
                | Cell (pattern, value) ->
                    let bit = 1 lsl (inputs + slot) in
                    let env =
                      match pattern.ppat_desc with
                      | Ppat_tuple [ shown; setter ] -> bind (bind env setter 0) shown bit
                      | _ -> bind env pattern bit
                    in
                    given env (slot + 1) context rest (Called (pattern, value) :: steps)
                | Stable (pattern, value) -> given (bind env pattern 0) (slot + 1) context rest (Called (pattern, value) :: steps)
                | Read (pattern, value) ->
                    let bit = 1 lsl (inputs + slots + context) in
                    given (bind env pattern bit) slot (context + 1) rest
                      (Context { pattern; context = value; bit } :: steps)
                | Remembered (pattern, hook, dependencies) ->
                    let bits = sources env dependencies in
                    given (bind env pattern bits) (slot + 1) context rest (Memo { pattern; hook; mask = bits } :: steps)
                | Effected (hook, dependencies) ->
                    let bits = sources env dependencies in
                    given env (slot + 1) context rest (Effect { hook; mask = bits } :: steps)
                | Computed (pattern, value) ->
                    let bits = mask env value in
                    given (bind env pattern bits) slot context rest (Derived { pattern; value; mask = bits } :: steps)
                | Changing (pattern, value) ->
                    given (bind env pattern every_source) slot context rest
                      (Derived { pattern; value; mask = every_source } :: steps))
          in
          match given props 1 0 shapes [] with
          | exception Beyond -> None
          | env, steps -> (
              match mask env result with
              | exception Beyond -> None
              | reads -> Some { steps; result; reads })))

let slots ~hooks body =
  let rec peeled expression found =
    match expression.pexp_desc with
    | Pexp_function (given, _, Pfunction_body body) ->
        peeled body
          (List.fold_left
             (fun found param ->
               match param.pparam_desc with
               | Pparam_val
                   ( Labelled label,
                     None,
                     { ppat_desc = Ppat_var { txt; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _); _ } ) -> (
                   match Melhole_compiler.Hook_name.of_name txt with Hook _ -> (txt, label) :: found | Plain -> found)
               | Pparam_val _ | Pparam_newtype _ -> found)
             found given)
    | _ -> (expression, found)
  in
  let inner, params = peeled body [] in
  let own hook = match hook.pexp_desc with Pexp_ident { txt = Lident name; _ } -> List.assoc_opt name params | _ -> None in
  let read = ref [] in
  let free_of_hooks expression =
    (object
       inherit Ast_traverse.iter as super

       method! expression expression =
         match expression.pexp_desc with
         | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) -> (
             match Melhole_compiler.Hook_name.of_name (Longident.last_exn txt) with
             | Hook _ -> raise Beyond
             | Plain -> super#expression expression)
         | Pexp_ident { txt; _ } -> (
             match Melhole_compiler.Hook_name.of_name (Longident.last_exn txt) with
             | Hook _ -> read := expression :: !read
             | Plain -> ())
         | _ -> super#expression expression
    end)
      #expression expression
  in
  let none = { fact = { slots = 0; through = [] }; values = []; conditions = [] } in
  let named locals hook =
    match hook.pexp_desc with
    | Pexp_ident { txt = Lident name; _ } -> (
        match (List.assoc_opt name locals, own hook) with
        | Some (Some local), _ -> `Local local
        | Some None, _ -> `Shadowed
        | None, Some label -> `Local { none with fact = { slots = 0; through = [ label ] } }
        | None, None -> `Outer)
    | _ -> `Outer
  in
  let rec chosen locals value =
    match value.pexp_desc with
    | Pexp_ident { txt = Ldot (Lident "React", name); _ } ->
        Option.map (fun slots -> { none with fact = { slots; through = [] } }) (react_slots name)
    | Pexp_ident _ -> (
        match (named locals value, hooks value) with
        | `Local local, _ -> Some local
        | `Outer, Some ({ fact = { through = []; _ }; _ } as known) -> Some known
        | `Shadowed, _ | `Outer, (Some _ | None) -> None)
    | Pexp_ifthenelse (test, yes, Some no) -> alike locals [ test ] [ yes; no ]
    | Pexp_match (target, cases) ->
        alike locals (target :: List.filter_map (fun case -> case.pc_guard) cases) (List.map (fun case -> case.pc_rhs) cases)
    | _ -> None
  and alike locals tests branches =
    match List.map (chosen locals) branches with
    | Some first :: rest ->
        Option.map
          (fun found ->
            List.iter free_of_hooks tests;
            found)
          (List.fold_left
             (fun found branch ->
               match (found, branch) with
               | Some found, Some branch
                 when Int.equal found.fact.slots branch.fact.slots
                      && List.equal String.equal found.fact.through branch.fact.through ->
                   Some { found with values = found.values @ branch.values; conditions = found.conditions @ branch.conditions }
               | (Some _ | None), _ -> None)
             (Some first) rest)
    | None :: _ | [] -> None
  in
  let taken locals value =
    match value.pexp_desc with
    | Pexp_apply (({ pexp_desc = Pexp_ident { txt; _ }; _ } as callee), arguments) -> (
        let called counted =
          let counted, rest = passed ~hooks ~named:(named locals) counted arguments in
          List.iter (fun (_, argument) -> free_of_hooks argument) rest;
          counted
        in
        match (named locals callee, hooks callee, txt) with
        | `Local local, _, _ ->
            List.iter (fun (_, argument) -> free_of_hooks argument) arguments;
            local
        | `Outer, Some counted, _ -> called counted
        | `Outer, None, Ldot (Lident "React", name) -> (
            match react_slots name with
            | Some slots -> called { none with fact = { slots; through = [] } }
            | None ->
                free_of_hooks value;
                none)
        | `Shadowed, _, _ | `Outer, None, _ ->
            free_of_hooks value;
            none)
    | _ ->
        free_of_hooks value;
        none
  in
  let rec counted locals expression =
    match expression.pexp_desc with
    | Pexp_sequence (first, rest) -> combined (taken locals first) (counted locals rest)
    | Pexp_let (Nonrecursive, [ binding ], rest) -> (
        let local =
          match binding.pvb_pat.ppat_desc with
          | Ppat_var { txt = name; _ } -> (
              match Melhole_compiler.Hook_name.of_name name with
              | Hook _ -> Option.map (fun hook -> (name, hook)) (chosen locals binding.pvb_expr)
              | Plain -> None)
          | _ -> None
        in
        match local with
        | Some (name, hook) -> counted ((name, Some hook) :: locals) rest
        | None ->
            combined (taken locals binding.pvb_expr)
              (counted (List.map (fun name -> (name, None)) (Free.bound binding.pvb_pat) @ locals) rest))
    | _ -> taken locals expression
  in
  match
    rendering
      ~hooks:(fun callee -> Option.fold ~none:(Option.map ignore (hooks callee)) ~some:(fun _ -> Some ()) (own callee))
      body
  with
  | Impure | Reads_the_page -> None
  | Pure -> (
      match counted [] inner with
      | found -> Some { found with values = found.values @ !read }
      | exception Beyond -> None)
