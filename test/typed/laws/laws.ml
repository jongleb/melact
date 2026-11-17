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
  | Looped of shape  (** [(< back : 's Js.t; held : shape > as 's) Js.t]: an object type that holds itself. *)
  | Looped_tags of shape  (** [([ `Back of 's | `Held of shape ] as 's)]: a polymorphic variant that holds itself, with no name. *)
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

(** Where a shape is generated: the parameter in scope, the earlier declarations, where [Self] is allowed. *)
type context = {
  parameter : parameter;
  earlier : parameter list;
  self : [ `Guarded | `Unguarded | `Under_row ];  (** [`Under_row]: only inside a polymorphic variant or an object, as an abbreviation allows. *)
}

let shape context =
  let open Gen in
  sized_size (int_bound 4)
  @@ fun size ->
  fix
    (fun shape (self, size) ->
      let leaves =
        [ pure Int; pure Char; pure Bool; pure Unit; pure String; pure Float; pure Int64; pure Bytes ]
        @ (match context.parameter with With_parameter -> [ pure Param ] | Without_parameter -> [])
        @ match self with `Guarded -> [ pure Self ] | `Unguarded | `Under_row -> []
      in
      match size with
      | 0 -> oneof leaves
      | _ ->
          let smaller = shape (self, size - 1) in
          let in_row = shape ((match self with `Under_row -> `Guarded | (`Guarded | `Unguarded) as kept -> kept), size - 1) in
          oneof
            (leaves
            @ [
                map (fun inner -> Array inner) smaller; map (fun inner -> Ref inner) smaller;
                map (fun inner -> List inner) smaller; map (fun inner -> Option inner) smaller;
                map (fun inner -> Lazy inner) smaller; map (fun inner -> Hashtbl inner) smaller;
                map2 (fun left right -> Pair (left, right)) smaller smaller;
                map2 (fun left right -> Arrow (left, right)) smaller smaller;
                map (fun tags -> Tags tags) (list_size (int_range 1 3) (option in_row));
                map (fun fields -> Object fields) (list_size (int_bound 2) in_row);
                map (fun inner -> Looped inner) in_row;
                map (fun inner -> Looped_tags inner) in_row;
              ]
               @
            match context.earlier with
            | [] -> []
            | _ :: _ -> [ map2 (fun index argument -> Earlier (index, argument)) (int_bound (List.length context.earlier - 1)) smaller ]))
    (context.self, size)

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
              map (fun inner -> Abbreviation inner) (shape { parameter; earlier; self = `Under_row });
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
  let loops = ref 0 in
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
    | Looped held ->
        incr loops;
        let name = Printf.sprintf "'s%d" !loops in
        Printf.sprintf "(< back : %s Js.t; held : %s > as %s) Js.t" name (inner held) name
    | Looped_tags held ->
        incr loops;
        let name = Printf.sprintf "'s%d" !loops in
        Printf.sprintf "([ `Back of %s | `Held of %s ] as %s)" name (inner held) name
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
    | Looped held | Looped_tags held -> boxed [ inner held ]
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

(** How a level of a chain holds the level below it twice. *)
type level = Pair_level | Tags_level | Object_level | Applied_level

(** An abbreviation a nested application goes through. *)
type wrapper = Identity | Identity_of_identity | Twice

let nested =
  let open Gen in
  let* leaf =
    oneof_list
      [
        ("int", Melhole_typed.Mutability.Immediate);
        ("int64", Melhole_typed.Mutability.Immutable_boxed);
        ("bytes", Melhole_typed.Mutability.Mutable_inside);
        ("int Lazy.t", Melhole_typed.Mutability.Unknown);
      ]
  in
  let* wrappers = list_size (int_range 1 6) (oneof_list [ Identity; Identity_of_identity; Twice ]) in
  pure (leaf, wrappers)

let nested_source ((leaf, _), wrappers) =
  String.concat "\n"
    [
      "type 'a id = 'a";
      "type 'a same = 'a id";
      "type 'a twice = 'a * 'a";
      "let probe : "
      ^ List.fold_left
          (fun inner wrapper ->
            "(" ^ inner ^ ") " ^ match wrapper with Identity -> "id" | Identity_of_identity -> "same" | Twice -> "twice")
          leaf wrappers
      ^ " = Obj.magic 0";
      "let _ = (probe [@melhole.ask 1])";
    ]

let nested_expected ((_, leaf), wrappers) =
  List.fold_left
    (fun found wrapper ->
      match (wrapper, found) with
      | (Identity | Identity_of_identity), _ -> found
      | Twice, (Melhole_typed.Mutability.Immediate | Melhole_typed.Mutability.Immutable_boxed) -> Melhole_typed.Mutability.Immutable_boxed
      | Twice, ((Melhole_typed.Mutability.Mutable_inside | Melhole_typed.Mutability.Unknown) as kept) -> kept)
    leaf wrappers

(** Raised by the alarm when a classification runs past its time. *)
exception Too_slow

let chains =
  let open Gen in
  let* depth = int_range 40 60 in
  let* leaf =
    oneof_list
      [
        ("int", Melhole_typed.Mutability.Immutable_boxed);
        ("int64", Melhole_typed.Mutability.Immutable_boxed);
        ("bytes", Melhole_typed.Mutability.Mutable_inside);
        ("int Lazy.t", Melhole_typed.Mutability.Unknown);
      ]
  in
  let* levels = list_size (pure depth) (oneof_list [ Pair_level; Tags_level; Object_level; Applied_level ]) in
  pure (leaf, levels)

let chain_source ((leaf, _), levels) =
  String.concat "\n"
    ([ "module Js = struct type 'a t end"; "type 'a twice = 'a * 'a"; "type l0 = " ^ leaf ]
    @ List.mapi
        (fun index level ->
          let below = Printf.sprintf "l%d" index in
          Printf.sprintf "type l%d = %s" (index + 1)
            (match level with
            | Pair_level -> below ^ " * " ^ below
            | Tags_level -> Printf.sprintf "[ `A of %s | `B of %s ]" below below
            | Object_level -> Printf.sprintf "< f0 : %s; f1 : %s > Js.t" below below
            | Applied_level -> below ^ " twice"))
        levels
    @ [ Printf.sprintf "let probe : l%d = Obj.magic 0" (List.length levels); "let _ = (probe [@melhole.ask 1])" ])

let mutability_laws =
  [
    Test.make ~count:300 ~name:"Mutability: an abbreviation nested in itself stays as transparent as it is alone"
      ~print:(fun case ->
        nested_source case ^ "\nexpected " ^ print_mutability (Some (nested_expected case)) ^ ", found "
        ^ print_mutability (Option.map Melhole_typed.Mutability.of_answer (answer (nested_source case))))
      nested
      (fun case -> Option.map Melhole_typed.Mutability.of_answer (answer (nested_source case)) = Some (nested_expected case));
    Test.make ~count:40 ~name:"Mutability: a chain of 40 to 60 levels, each holding the one below twice, is classified within 10 seconds as its leaf says"
      ~print:(fun chain -> chain_source chain ^ "\nexpected " ^ print_mutability (Some (snd (fst chain))))
      chains
      (fun (((_, expected), _) as chain) ->
        let previous = Sys.signal Sys.sigalrm (Sys.Signal_handle (fun _ -> raise Too_slow)) in
        ignore (Unix.alarm 10);
        let found =
          match Option.map Melhole_typed.Mutability.of_answer (answer (chain_source chain)) with
          | found -> found
          | exception Too_slow -> None
        in
        ignore (Unix.alarm 0);
        Sys.set_signal Sys.sigalrm previous;
        found = Some expected);
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
    | Compiled_props -> "< x : unit; y : unit option > React.props"
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
      "module React = struct type element type 'props component = 'props -> element type 'labels props = Props of element [@@unboxed] end";
      "module Js = struct type 'a t end";
      "type el = React.element";
      "type y_props";
      "type thing = Thing of React.element [@@unboxed]";
      "type c = " ^ written;
      "let probe : " ^ (match spelling with Abbreviated -> "c" | Direct | Component_type -> written) ^ " = Obj.magic 0";
      "let _ = (probe [@melhole.ask 1])";
    ]

let component_expected (result, props, label, spelling, arity) =
  match ((spelling, result, label, arity), result, label, arity, props) with
  | (Component_type, Element, Unlabelled, One), _, _, _, Compiled_props -> Some `Compiled
  | (Component_type, Element, Unlabelled, One), _, _, _, (Js_props | Abstract_props | Wrapper_props | Text_props) -> Some `Of_props
  | _, Text_result, _, _, _ | _, _, (Labelled | Optional), _, _ | _, _, _, Two, _ -> None
  | _, (Element | Element_alias), Unlabelled, One, Compiled_props -> Some `Compiled
  | _, (Element | Element_alias), Unlabelled, One, (Js_props | Abstract_props | Wrapper_props | Text_props) -> Some `Of_props

let component_found case =
  Option.map
    (fun component -> match component with Melact_ppx.Typed.Compiled -> `Compiled | Melact_ppx.Typed.Of_props _ -> `Of_props)
    (Option.bind (answer (component_source case)) Melact_ppx.Typed.component)

let labels_case =
  let open Gen in
  let* count = int_range 0 6 in
  let* kinds = list_size (pure count) (oneof_list [ `Labelled; `Optional ]) in
  let* preset = oneof_list [ `Preset; `As_built ] in
  pure (List.mapi (fun index kind -> (Printf.sprintf "l%d" index, kind)) kinds, preset)

let labels_source (labels, preset) =
  let props =
    "< "
    ^ String.concat "; " (List.map (fun (name, kind) -> name ^ " : " ^ match kind with `Labelled -> "unit" | `Optional -> "unit option") labels)
    ^ " > React.props"
  in
  let arrows =
    String.concat "" (List.map (fun (name, kind) -> (match kind with `Labelled -> name ^ ":int -> " | `Optional -> "?" ^ name ^ ":int -> ")) labels)
  in
  String.concat "\n"
    [
      "module React = struct type element type 'labels props = Props of element [@@unboxed] end";
      "module Base = struct let makeProps : " ^ arrows ^ "?key:string -> unit -> " ^ props ^ " = Obj.magic 0 end";
      "module M = struct";
      (match preset with `As_built -> "  let makeProps = Base.makeProps" | `Preset -> "  let makeProps = Base.makeProps ~p:1");
      "  let make : " ^ props ^ " -> React.element = Obj.magic 0";
      "end";
      "let _ = (M.make [@melhole.ask 1])";
    ]

let labels_found case =
  Option.map
    (List.map (fun label ->
         match label with Ppxlib.Labelled name -> (name, `Labelled) | Ppxlib.Optional name -> (name, `Optional) | Ppxlib.Nolabel -> ("", `Labelled)))
    (Option.bind (answer (labels_source case)) (fun answer -> Melact_ppx.Typed.builder_labels answer (Ppxlib.Ldot (Ppxlib.Lident "M", "makeProps"))))

let component_laws =
  let print found = match found with Some `Compiled -> "Compiled" | Some `Of_props -> "Of_props" | None -> "None" in
  [
    Test.make ~count:300 ~name:"Labels: a compiled component is rebuilt with the labels its module's makeProps still takes, in its order, key included"
      ~print:labels_source
      (Gen.map (fun ((labels, preset) : (string * [ `Labelled | `Optional ]) list * [ `Preset | `As_built ]) -> match preset with `Preset -> (("p", `Labelled) :: labels, preset) | `As_built -> (labels, preset)) labels_case)
      (fun ((labels, preset) as case) ->
        labels_found case = Some ((match preset with `Preset -> List.filter (fun (name, _) -> not (String.equal name "p")) labels | `As_built -> labels) @ [ ("key", `Optional) ]));
    Test.make ~count:500 ~name:"Component: a function type is a component exactly as its expanded shape says"
      ~print:(fun case -> component_source case ^ "\nexpected " ^ print (component_expected case) ^ ", found " ^ print (component_found case))
      component_case
      (fun case -> component_found case = component_expected case);
  ]

let () = exit (QCheck_base_runner.run_tests ~verbose:true (mutability_laws @ component_laws))
