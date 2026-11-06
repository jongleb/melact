open QCheck2

(** A type expression of a generated declaration. *)
type shape =
  | Int
  | Char
  | Bool
  | Unit
  | String
  | Float
  | Int64
  | Bytes
  | Array of shape
  | Ref of shape
  | List of shape
  | Option of shape
  | Lazy of shape
  | Hashtbl of shape
  | Pair of shape * shape
  | Arrow of shape * shape
  | Param  (** ['a], in a declaration with a parameter. *)
  | Earlier of int * shape  (** An earlier declaration, applied to the shape when it has a parameter. *)
  | Self  (** The declaration itself, with its own parameter. *)
  | Tags of shape option list  (** A closed polymorphic variant. *)
  | Object of shape list  (** A closed [< … > Js.t]. *)
  | Variable  (** A type variable of the probed value's own type. *)

(** A record field or an inline record field. *)
type field = Mutable_field of shape | Field of shape

(** A constructor of a generated variant. *)
type constructor = Constant | Args of shape list | Inline of field list

(** The right-hand side of a generated declaration. *)
type body =
  | Abbreviation of shape
  | Record of field list
  | Variant of constructor list
  | Unboxed of shape  (** [W of shape [@@unboxed]]. *)
  | Abstract

(** Whether a generated declaration takes ['a]. *)
type parameter = With_parameter | Without_parameter

(** Where a shape is generated: the parameter in scope, the earlier declarations, whether [Self] is allowed. *)
type context = { parameter : parameter; earlier : parameter list; self : [ `Guarded | `Unguarded ] }

let shape context =
  let open Gen in
  sized_size (int_bound 4)
  @@ fix (fun shape size ->
         let leaves =
           [ pure Int; pure Char; pure Bool; pure Unit; pure String; pure Float; pure Int64; pure Bytes ]
           @ (match context.parameter with With_parameter -> [ pure Param ] | Without_parameter -> [])
           @ (match context.self with `Guarded -> [ pure Self ] | `Unguarded -> [])
         in
         match size with
         | 0 -> oneof leaves
         | _ ->
             let smaller = shape (size - 1) in
             oneof
               (leaves
               @ [
                   map (fun inner -> Array inner) smaller; map (fun inner -> Ref inner) smaller;
                   map (fun inner -> List inner) smaller; map (fun inner -> Option inner) smaller;
                   map (fun inner -> Lazy inner) smaller; map (fun inner -> Hashtbl inner) smaller;
                   map2 (fun left right -> Pair (left, right)) smaller smaller;
                   map2 (fun left right -> Arrow (left, right)) smaller smaller;
                   map (fun tags -> Tags tags) (list_size (int_range 1 3) (option smaller));
                   map (fun fields -> Object fields) (list_size (int_bound 2) smaller);
                 ]
               @
               match context.earlier with
               | [] -> []
               | _ :: _ ->
                   [ map2 (fun index argument -> Earlier (index, argument)) (int_bound (List.length context.earlier - 1)) smaller ]))

let declarations =
  let open Gen in
  let* count = int_range 1 4 in
  let rec build earlier remaining =
    match remaining with
    | 0 -> pure []
    | _ ->
        let* parameter = oneof_list [ With_parameter; Without_parameter ] in
        let guarded = shape { parameter; earlier; self = `Guarded } in
        let field = oneof [ map (fun inner -> Mutable_field inner) guarded; map (fun inner -> Field inner) guarded ] in
        let* body =
          oneof
            [
              map (fun inner -> Abbreviation inner) (shape { parameter; earlier; self = `Unguarded });
              map (fun fields -> Record fields) (list_size (int_range 1 3) field);
              map
                (fun constructors -> Variant constructors)
                (list_size (int_range 1 3)
                   (oneof
                      [
                        pure Constant;
                        map (fun shapes -> Args shapes) (list_size (int_range 1 2) guarded);
                        map (fun fields -> Inline fields) (list_size (int_range 1 2) field);
                      ]));
              map (fun inner -> Unboxed inner) (shape { parameter; earlier; self = `Unguarded });
              pure Abstract;
            ]
        in
        let* rest = build (earlier @ [ parameter ]) (remaining - 1) in
        pure ((parameter, body) :: rest)
  in
  let* declared = build [] count in
  let general =
    oneof_weighted
      [
        (5, shape { parameter = Without_parameter; earlier = List.map fst declared; self = `Unguarded });
        (1, map (fun held -> List held) (pure Variable));
        (1, pure Variable);
      ]
  in
  let* probe =
    oneof_weighted [ (3, map2 (fun index argument -> Earlier (index, argument)) (int_bound (count - 1)) general); (1, general) ]
  in
  let* marked = oneof_list [ `Variable; `Constraint ] in
  pure (declared, probe, marked)

let source (declared, probe, marked) =
  let rec print current shape =
    let inner = print current in
    match shape with
    | Int -> "int"
    | Char -> "char"
    | Bool -> "bool"
    | Unit -> "unit"
    | String -> "string"
    | Float -> "float"
    | Int64 -> "int64"
    | Bytes -> "bytes"
    | Array held -> "(" ^ inner held ^ ") array"
    | Ref held -> "(" ^ inner held ^ ") ref"
    | List held -> "(" ^ inner held ^ ") list"
    | Option held -> "(" ^ inner held ^ ") option"
    | Lazy held -> "(" ^ inner held ^ ") Lazy.t"
    | Hashtbl held -> "(int, " ^ inner held ^ ") Hashtbl.t"
    | Pair (left, right) -> "(" ^ inner left ^ " * " ^ inner right ^ ")"
    | Arrow (left, right) -> "(" ^ inner left ^ " -> " ^ inner right ^ ")"
    | Param -> "'a"
    | Variable -> "'b"
    | Earlier (index, argument) -> (
        match fst (List.nth declared index) with
        | With_parameter -> Printf.sprintf "(%s) t%d" (inner argument) index
        | Without_parameter -> Printf.sprintf "t%d" index)
    | Self -> (
        match fst (List.nth declared current) with
        | With_parameter -> Printf.sprintf "'a t%d" current
        | Without_parameter -> Printf.sprintf "t%d" current)
    | Tags tags ->
        "[ "
        ^ String.concat " | "
            (List.mapi
               (fun index tag -> Printf.sprintf "`T%d" index ^ Option.fold ~none:"" ~some:(fun held -> " of " ^ inner held) tag)
               tags)
        ^ " ]"
    | Object fields -> "< " ^ String.concat "; " (List.mapi (fun index held -> Printf.sprintf "f%d : %s" index (inner held)) fields) ^ " > Js.t"
  in
  let fields current fields =
    "{ "
    ^ String.concat "; "
        (List.mapi
           (fun index field ->
             match field with
             | Mutable_field held -> Printf.sprintf "mutable f%d : %s" index (print current held)
             | Field held -> Printf.sprintf "f%d : %s" index (print current held))
           fields)
    ^ " }"
  in
  String.concat "\n"
    ([ "module Js = struct type 'a t end" ]
    @ List.mapi
        (fun index (parameter, body) ->
          let head = match parameter with With_parameter -> Printf.sprintf "type 'a t%d" index | Without_parameter -> Printf.sprintf "type t%d" index in
          match body with
          | Abbreviation held -> head ^ " = " ^ print index held
          | Record declared -> head ^ " = " ^ fields index declared
          | Variant constructors ->
              head ^ " = "
              ^ String.concat " | "
                  (List.mapi
                     (fun number constructor ->
                       match constructor with
                       | Constant -> Printf.sprintf "C%d_%d" index number
                       | Args shapes -> Printf.sprintf "C%d_%d of %s" index number (String.concat " * " (List.map (fun held -> "(" ^ print index held ^ ")") shapes))
                       | Inline declared -> Printf.sprintf "C%d_%d of %s" index number (fields index declared))
                     constructors)
          | Unboxed held -> Printf.sprintf "%s = W%d of %s [@@unboxed]" head index (print index held)
          | Abstract -> head)
        declared
    @ [
        "let probe : " ^ print 0 probe ^ " = Obj.magic 0";
        (match marked with
        | `Variable -> "let _ = (probe [@melhole.ask 1])"
        | `Constraint -> "let _ = ((probe : " ^ print 0 probe ^ ") [@melhole.ask 1])");
      ])

let expected (declared, probe, _) =
  let boxed parts =
    List.fold_left
      (fun found part ->
        match (found, part) with
        | Melhole_typed.Mutability.Mutable_inside, _ | _, Melhole_typed.Mutability.Mutable_inside -> Melhole_typed.Mutability.Mutable_inside
        | Melhole_typed.Mutability.Unknown, _ | _, Melhole_typed.Mutability.Unknown -> Melhole_typed.Mutability.Unknown
        | _ -> Melhole_typed.Mutability.Immutable_boxed)
      Melhole_typed.Mutability.Immutable_boxed parts
  in
  let constructed parts = match parts with [] -> Melhole_typed.Mutability.Immediate | _ :: _ -> boxed parts in
  let rec classify argument shape =
    let inner = classify argument in
    match shape with
    | Int | Char | Bool | Unit | String | Float -> Melhole_typed.Mutability.Immediate
    | Int64 | Arrow _ | Self -> Melhole_typed.Mutability.Immutable_boxed
    | Bytes | Array _ | Ref _ | Hashtbl _ -> Melhole_typed.Mutability.Mutable_inside
    | Lazy _ | Variable -> Melhole_typed.Mutability.Unknown
    | List held | Option held -> boxed [ inner held ]
    | Pair (left, right) -> boxed [ inner left; inner right ]
    | Param -> argument
    | Earlier (index, given) -> declaration index (inner given)
    | Tags tags -> constructed (List.filter_map (Option.map inner) tags)
    | Object fields -> boxed (List.map inner fields)
  and declaration index argument =
    let field field =
      match field with
      | Mutable_field _ -> Melhole_typed.Mutability.Mutable_inside
      | Field held -> classify argument held
    in
    match snd (List.nth declared index) with
    | Abbreviation held | Unboxed held -> classify argument held
    | Record fields -> boxed (List.map field fields)
    | Variant constructors ->
        constructed
          (List.concat_map
             (fun constructor ->
               match constructor with
               | Constant -> []
               | Args shapes -> List.map (classify argument) shapes
               | Inline fields -> [ boxed (List.map field fields) ])
             constructors)
    | Abstract -> Melhole_typed.Mutability.Unknown
  in
  classify Melhole_typed.Mutability.Unknown probe

let answer source =
  Option.bind
    (Melhole_typed.File.of_structure (Ppxlib.Parse.implementation (Lexing.from_string source)))
    (fun file -> match Melhole_typed.File.answers file with [ (_, answer) ] -> Some answer | _ -> None)

let print_mutability found =
  match found with
  | Some Melhole_typed.Mutability.Immediate -> "Immediate"
  | Some Melhole_typed.Mutability.Immutable_boxed -> "Immutable_boxed"
  | Some Melhole_typed.Mutability.Mutable_inside -> "Mutable_inside"
  | Some Melhole_typed.Mutability.Unknown -> "Unknown"
  | None -> "not typed"

let mutability_laws =
  [
    Test.make ~count:1500 ~name:"Mutability: the classifier agrees with the definition on generated declarations"
      ~print:(fun generated ->
        source generated ^ "\nexpected " ^ print_mutability (Some (expected generated)) ^ ", found "
        ^ print_mutability (Option.map Melhole_typed.Mutability.of_answer (answer (source generated))))
      declarations
      (fun generated -> Option.map Melhole_typed.Mutability.of_answer (answer (source generated)) = Some (expected generated));
    Test.make ~count:300 ~name:"File: a question marked on two expressions has no answer" ~print:source declarations (fun generated ->
        Option.map
          (fun file -> List.length (Melhole_typed.File.answers file))
          (Melhole_typed.File.of_structure
             (Ppxlib.Parse.implementation (Lexing.from_string (source generated ^ "\nlet _ = (probe [@melhole.ask 1])"))))
        = Some 0);
  ]

(** The result of a generated function type. *)
type result = Element | Element_alias | Text_result

(** The parameter of a generated function type. *)
type props = Js_props | Compiled_props | Abstract_props | Wrapper_props | Text_props

(** How a generated function type takes its parameter. *)
type label = Unlabelled | Labelled | Optional

(** How a generated function type is written. *)
type spelling = Direct | Component_type | Abbreviated

(** How many parameters a generated function type has. *)
type arity = One | Two

let component_case =
  let open Gen in
  let* result = oneof_list [ Element; Element_alias; Text_result ] in
  let* props = oneof_list [ Js_props; Compiled_props; Abstract_props; Wrapper_props; Text_props ] in
  let* label = oneof_list [ Unlabelled; Labelled; Optional ] in
  let* spelling = oneof_list [ Direct; Component_type; Abbreviated ] in
  let* arity = oneof_list [ One; Two ] in
  pure (result, props, label, spelling, arity)

let component_source (result, props, label, spelling, arity) =
  let props =
    match props with
    | Js_props -> "< children : React.element > Js.t"
    | Compiled_props -> "x_props"
    | Abstract_props -> "y_props"
    | Wrapper_props -> "thing"
    | Text_props -> "string"
  in
  let written =
    match (spelling, result, label, arity) with
    | Component_type, Element, Unlabelled, One -> "(" ^ props ^ ") React.component"
    | (Direct | Abbreviated | Component_type), _, _, _ ->
        (match label with Unlabelled -> "" | Labelled -> "x:" | Optional -> "?x:")
        ^ "(" ^ props ^ ") -> "
        ^ (match arity with One -> "" | Two -> "unit -> ")
        ^ match result with Element -> "React.element" | Element_alias -> "el" | Text_result -> "string"
  in
  String.concat "\n"
    [
      "module React = struct type element type 'props component = 'props -> element end";
      "module Js = struct type 'a t end";
      "type el = React.element";
      "type x_props = X_props of React.element [@@unboxed]";
      "type y_props";
      "type thing = Thing of React.element [@@unboxed]";
      "type c = " ^ written;
      "let probe : " ^ (match spelling with Abbreviated -> "c" | Direct | Component_type -> written) ^ " = Obj.magic 0";
      "let _ = (probe [@melhole.ask 1])";
    ]

let component_expected (result, props, label, spelling, arity) =
  match ((spelling, result, label, arity), result, label, arity, props) with
  | (Component_type, Element, Unlabelled, One), _, _, _, (Compiled_props | Abstract_props) -> Some `Compiled
  | (Component_type, Element, Unlabelled, One), _, _, _, (Js_props | Wrapper_props | Text_props) -> Some `Of_props
  | _, Text_result, _, _, _ | _, _, (Labelled | Optional), _, _ | _, _, _, Two, _ -> None
  | _, (Element | Element_alias), Unlabelled, One, (Compiled_props | Abstract_props) -> Some `Compiled
  | _, (Element | Element_alias), Unlabelled, One, (Js_props | Wrapper_props | Text_props) -> Some `Of_props

let component_found case =
  Option.map
    (fun component -> match component with Melact_ppx.Typed.Compiled -> `Compiled | Melact_ppx.Typed.Of_props _ -> `Of_props)
    (Option.bind (answer (component_source case)) Melact_ppx.Typed.component)

let component_laws =
  let print found = match found with Some `Compiled -> "Compiled" | Some `Of_props -> "Of_props" | None -> "None" in
  [
    Test.make ~count:500 ~name:"Component: a function type is a component exactly as its expanded shape says"
      ~print:(fun case -> component_source case ^ "\nexpected " ^ print (component_expected case) ^ ", found " ^ print (component_found case))
      component_case
      (fun case -> component_found case = component_expected case);
  ]

let () = exit (QCheck_base_runner.run_tests ~verbose:true (mutability_laws @ component_laws))
