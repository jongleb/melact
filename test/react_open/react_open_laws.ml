open QCheck2

(** A small expression of strings, read under and around [open React], with React's names and others bound in it. *)
type expression =
  | Name of string
  | Bound of string * expression * expression
  | Paired of string * string * expression * expression
  | Called of string * expression * expression
  | Sequence of expression * expression
  | Joined of expression * expression
  | Chosen of expression * expression * expression * expression
  | Boxed of expression
  | Field of expression
  | Listed of expression * expression
  | Constrained of expression
  | Opened of expression

let prelude =
  {|module React = struct
  type 'value ref = { mutable current : 'value }
  type element = string
  let string = "React.string"
  let null = "React.null"
  let useState = "React.useState"
  let array = "React.array"
  module Uncurried = struct let useState = "React.Uncurried.useState" end
end
type element = int
type box = { current : int }
let string = "outer string"
let null = "outer null"
let useState = "outer useState"
let count = "outer count"
let total = "outer total"
module Uncurried = struct let useState = "outer Uncurried.useState" end
|}

let rec source expression =
  match expression with
  | Name name -> name
  | Bound (name, value, body) -> Printf.sprintf "(let %s = %s in %s)" name (source value) (source body)
  | Paired (first, second, value, body) ->
      Printf.sprintf "(let (%s, %s) = (%s, %s) in %s)" first second (source value) (source value) (source body)
  | Called (name, body, argument) -> Printf.sprintf "((fun %s -> %s) %s)" name (source body) (source argument)
  | Sequence (first, rest) -> Printf.sprintf "(ignore %s; %s)" (source first) (source rest)
  | Joined (first, second) -> Printf.sprintf "(%s ^ %s)" (source first) (source second)
  | Chosen (left, right, yes, no) ->
      Printf.sprintf "(if String.equal %s %s then %s else %s)" (source left) (source right) (source yes) (source no)
  | Boxed value -> Printf.sprintf "({ current = %s }.current)" (source value)
  | Field value -> Printf.sprintf "((fun box -> box.current) { current = %s })" (source value)
  | Constrained value -> Printf.sprintf "(%s : element)" (source value)
  | Listed (first, second) -> Printf.sprintf "(String.concat \"\" [ %s; %s ])" (source first) (source second)
  | Opened body -> Printf.sprintf "React.(%s)" (source body)

let expression =
  let open Gen in
  let names = [ "string"; "null"; "useState"; "count"; "total" ] in
  let name = oneof_list (names @ [ "Uncurried.useState"; "array" ]) and binder = oneof_list names in
  sized_size (int_bound 6)
  @@ fix (fun self size ->
         match size with
         | 0 -> map (fun name -> Name name) name
         | _ ->
             let smaller = self (size / 2) in
             oneof
               [
                 map (fun name -> Name name) name;
                 map3 (fun name value body -> Bound (name, value, body)) binder smaller smaller;
                 map3 (fun (first, second) value body -> Paired (first, second, value, body)) (pair binder binder) smaller smaller;
                 map3 (fun name body argument -> Called (name, body, argument)) binder smaller smaller;
                 map2 (fun first rest -> Sequence (first, rest)) smaller smaller;
                 map2 (fun first second -> Joined (first, second)) smaller smaller;
                 map2 (fun (left, right) (yes, no) -> Chosen (left, right, yes, no)) (pair smaller smaller) (pair smaller smaller);
                 map (fun value -> Boxed value) smaller;
                 map (fun value -> Field value) smaller;
                 map (fun value -> Constrained value) smaller;
                 map2 (fun first second -> Listed (first, second)) smaller smaller;
                 map (fun body -> Opened body) smaller;
               ])

let evaluated phrase =
  match Toploop.execute_phrase false Format.str_formatter (Ptop_def (Parse.implementation (Lexing.from_string phrase))) with
  | true -> `Ran
  | false -> `Rejected
  | exception _ -> `Rejected

let rewritten written =
  Ppxlib.Pprintast.string_of_expression (Melact_ppx.React_open.qualified (Ppxlib.Parse.expression (Lexing.from_string written)))

let reads_the_same =
  Test.make ~name:"an open React pushed down reads every name as it did under the open" ~count:2000
    ~print:(fun expression -> source (Opened expression))
    expression
    (fun expression ->
      let written = source (Opened expression) in
      match evaluated (Printf.sprintf "let _ = %s" written) with
      | `Rejected -> assume_fail ()
      | `Ran -> (
          match
            evaluated
              (Printf.sprintf "let () = if not (String.equal (%s) (%s)) then failwith \"differs\"" written (rewritten written))
          with
          | `Ran -> true
          | `Rejected -> Test.fail_reportf "rewritten as %s" (rewritten written)))

let () =
  Toploop.initialize_toplevel_env ();
  ignore (Warnings.parse_options false "-a");
  match evaluated prelude with
  | `Rejected -> failwith "the prelude does not compile"
  | `Ran -> exit (QCheck_base_runner.run_tests [ reads_the_same ])
