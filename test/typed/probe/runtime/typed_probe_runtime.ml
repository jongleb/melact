external test : string -> (unit -> unit) -> unit = "test"

let immediate : 'value -> 'value =
  [%mel.raw
    {|function (value) {
  if ((typeof value === "object" && value !== null) || typeof value === "function")
    throw new Error("typed-probe: a value typed Immediate is a JavaScript object: " + String(value));
  return value;
}|}]

let fail : string -> unit = [%mel.raw {|function (message) { throw new Error(message); }|}]

let untyped file = test ("typed-probe: " ^ file ^ " types") (fun () -> fail ("typed-probe: " ^ file ^ " did not type"))

let typed file ~asked ~answered ~immediate =
  test
    (Printf.sprintf "typed-probe: %s types; each of its %d arguments that are variables has a type, and the %d typed Immediate are JavaScript primitives"
       file asked immediate)
    (fun () ->
      match asked = answered with
      | true -> ()
      | false -> fail (Printf.sprintf "typed-probe: %s answered %d of %d questions" file answered asked))
