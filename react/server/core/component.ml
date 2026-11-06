(** Whether a state set during the render asks for another pass. *)
type pass = Settled | Again

(** Whether the component is rendering: dispatches count only then. *)
type status = Rendering | Rendered

type frame = {
  slots : Hook.slots;
  writer : Melhole_server.writer;
  mutable ids : int;
  mutable pass : pass;
  mutable status : status;
}

let active = ref None

let current () =
  match !active with Some frame -> frame | None -> failwith "melact: hooks can only be called while a component renders"

let render body =
  Melhole_server.element (fun writer ->
      let frame = { slots = Hook.slots (); writer; ids = 0; pass = Settled; status = Rendering } in
      let around = !active in
      active := Some frame;
      let rec passes count =
        Hook.rewind frame.slots;
        frame.ids <- 0;
        frame.pass <- Settled;
        let output = body () in
        match (frame.pass, count < 25) with
        | Settled, _ -> output
        | Again, true -> passes (count + 1)
        | Again, false -> failwith "Too many re-renders. React limits the number of renders to prevent an infinite loop."
      in
      match passes 1 with
      | output -> (
          active := around;
          frame.status <- Rendered;
          match frame.ids with
          | 0 -> Melhole_server.write writer output
          | _ -> Melhole_server.forked writer [| 1; 0 |] output)
      | exception error ->
          active := around;
          frame.status <- Rendered;
          raise error)

let take frame key init =
  match Hook.found frame.slots key with
  | Some value -> value
  | None ->
      let value = init () in
      Hook.put frame.slots key value;
      value

let id frame =
  let local = frame.ids in
  frame.ids <- local + 1;
  Melhole_server.Tree.id (Melhole_server.position frame.writer) local

type ('state, 'action) state = { mutable value : 'state; mutable pending : 'action list; owner : frame }

let state key reduce initial =
  let frame = current () in
  let cell =
    match Hook.found frame.slots key with
    | Some cell ->
        cell.value <- List.fold_left reduce cell.value (List.rev cell.pending);
        cell.pending <- [];
        cell
    | None ->
        let cell = { value = initial (); pending = []; owner = frame } in
        Hook.put frame.slots key cell;
        cell
  in
  ( cell.value,
    fun action ->
      match cell.owner.status with
      | Rendering ->
          cell.pending <- action :: cell.pending;
          cell.owner.pass <- Again
      | Rendered -> () )

type ('deps, 'value) memo = { mutable deps : 'deps; mutable value : 'value }

let memo key compare deps compute =
  let frame = current () in
  match Hook.found frame.slots key with
  | Some cell -> (
      match compare cell.deps deps with
      | Deps.Same -> cell.value
      | Changed ->
          cell.deps <- deps;
          cell.value <- compute ();
          cell.value)
  | None ->
      let cell = { deps; value = compute () } in
      Hook.put frame.slots key cell;
      cell.value
