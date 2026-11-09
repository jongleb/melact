# From hooks to Meltea, one screen at a time

Melact keeps hooks so that a reason-react app moves over by changing two lines. Hooks are not what
makes it fast: the compiler guards every hole by the values it reads, so a pure function of a model
renders as little as a component tuned with `useMemo`. Meltea is that pure function, written
plainly: a model, messages, `update` and `view`. This guide moves an app from the first to the
second without a rewrite. Each step leaves an app that builds, passes its tests and ships.

Two bridges make it gradual. Both come from one library, `melact.meltea`, and both compile to the
same runtime, so a page with both still has one copy of melhole, one event listener per event
type on `document` and one scheduler that draws.

| bridge | what it is | used at |
|---|---|---|
| `MelteaProgram` | a Melact component that runs a Meltea program in its place in the tree | step 3 |
| `MelactHtml.element` | a node of a Meltea view that shows a Melact element, hooks and all | step 4 |

## Step 0: switch reason-react to Melact

In every `dune` file:

```diff
- (libraries reason-react)
+ (libraries melact)
- (preprocess (pps melange.ppx reason-react-ppx))
+ (preprocess (staged_pps melange.ppx melact-ppx -- -typed))
```

Under `staged_pps` the compiler runs `melact-ppx`, with the `.cmi` of the app's other modules on
its load path: a hookless component of another file is spliced into its caller's rows as one of its
own file is, and a component that calls another file's custom hook keeps its update graph. `-typed` lets it ask the
type checker where the syntax does not tell; a file that does not type is compiled exactly as
without it. Plain `(pps melange.ppx melact-ppx)` still works, with fewer optimizations: every
component of another module stays a call and its custom hooks are unknown. The benchmark apps and
the examples of this repository build with the staged stanza.

Nothing else changes. Run the tests; `compat/run.sh` shows what real reason-react apps look like
after this step.

## Step 1: pull state out of hooks into a reducer

Take one screen. Gather its `useState` calls into one record and every way it changes into one
variant. The component keeps its hooks for now, but it has one `useReducer` and a pure function
that says what each action does:

```ocaml
(* before: three cells and a handler that knows about all of them *)
let[@react.component] make ~initial =
  let items, setItems = React.useState (fun () -> initial) in
  let draft, setDraft = React.useState (fun () -> "") in
  let filter, setFilter = React.useState (fun () -> All) in
  let add _ =
    setItems (fun items -> items @ [ draft ]);
    setDraft (fun _ -> "")
  in
  ...

(* after: one state, one reducer *)
type state = { items : string list; draft : string; filter : filter }
type action = Type of string | Add | Show of filter

let reduce state action =
  match action with
  | Type draft -> { state with draft }
  | Add -> { state with items = state.items @ [ state.draft ]; draft = "" }
  | Show filter -> { state with filter }

let[@react.component] make ~initial =
  let state, send = React.useReducer reduce { items = initial; draft = ""; filter = All } in
  <section>
    <input value=state.draft onChange=(fun event -> send (Type (React.Event.Form.target event)##value)) />
    <button onClick=(fun _ -> send Add)>(React.string "add")</button>
    ...
  </section>
```

The reducer is already a Meltea `update` in all but name. Keep the tests green and move on.

To find the components that are ready, add `-meltea-hints` to `melact-ppx` for one build:

```lisp
(preprocess (staged_pps melange.ppx melact-ppx -- -typed -meltea-hints))
```

Every `[@react.component]` whose only hooks are `useState` and `useReducer` gets an alert, `meltea`,
that names it and counts its cells: its state is a model and its setters are messages already. A
component with any other hook gets none. The alert is a warning; it costs no code.

## Step 2: turn the reducer into update and messages

Move the state, the actions and the reducer into a module of their own, compiled by `meltea-ppx`.
`state` becomes `model`, `action` becomes `message`, `reduce state action` becomes
`update message model`, and the JSX becomes a view: a handler is the message it sends, and text is
`Html.text`.

```ocaml
(* todos.mlx, compiled by meltea-ppx *)
type model = { items : string list; draft : string; filter : filter }
type message = Type of string | Add | Show of filter

let init initial = { items = initial; draft = ""; filter = All }

let update message model =
  match message with
  | Type draft -> { model with draft }
  | Add -> { model with items = model.items @ [ model.draft ]; draft = "" }
  | Show filter -> { model with filter }

let view model =
  <section>
    <input value=model.draft onInput=(fun text -> Type text) />
    <button onClick=Add>(Html.text "add")</button>
    ...
  </section>
```

One library can hold modules of both kinds: dune's `per_module` gives each its own ppx.

```lisp
(library
 (name app)
 (libraries melact melact.meltea meltea)
 (modes melange)
 (preprocess
  (per_module
   ((staged_pps melange.ppx meltea-ppx -- -typed) todos)
   ((staged_pps melange.ppx melact-ppx -- -typed) app main))))
```

## Step 3: embed the screen as a Meltea program inside the Melact app

`MelteaProgram.sandbox` (or `element`, with commands and subscriptions) describes the program once,
at the top level of a Melact module. `<MelteaProgram program input onReport />` runs it:

```ocaml
(* app.mlx, compiled by melact-ppx *)
let todos =
  MelteaProgram.sandbox ~init:Todos.init ~update:Todos.update ~view:Todos.view
    ~receive:(fun filter -> Some (Todos.Show filter))
    ~report:(fun message (model : Todos.model) ->
      match message with Todos.Add -> Some (List.length model.items) | _ -> None)
    "Todos"

let[@react.component] make () =
  let filter, setFilter = React.useState (fun () -> Todos.All) in
  let total, setTotal = React.useState (fun () -> 0) in
  <main>
    <Tabs filter onChange=(fun filter -> setFilter (fun _ -> filter)) />
    <p>(React.string (string_of_int total ^ " items"))</p>
    <MelteaProgram program=todos input=filter onReport=(fun count -> setTotal (fun _ -> count)) />
  </main>
```

- **Props flow in as messages.** `init` makes the first model from the first `input`. Each later
  `input` that is a different value (`!==`) becomes the message `receive input`, if it gives one,
  applied in the same render, so the new input and the program's answer to it are drawn together.
- **Reports flow out.** Every message the program sends itself (an event, a command's result, a
  subscription) is offered to `report message model`, with the model it made; a `Some` calls the
  latest `onReport`, inside the same event, as a React callback would be. Messages made by `receive`
  are not reported: the component around already knows them, and reporting them back would loop.
- **One delegation, one draw.** The program's view is a child of the component, drawn by Melact's
  scheduler in the same flush as the rest of the page. A message that changes nothing draws
  nothing; a re-render of the parent that gives the same input does not call the view.
- **Unmount stops it.** Subscriptions stop, and messages that commands send afterwards are dropped.

The same program value always means the same component: two different programs at one place in
the tree remount, as two different components would.

## Step 4: move the leaf widgets

A screen often uses widgets that still have hooks: a date picker, a rating, a combobox. They do not
have to move first. `MelactHtml.element` puts a Melact element into a Meltea view; its callbacks
send messages:

```ocaml
(* stars_html.mlx, compiled by melact-ppx *)
let view ~stars ~rated = MelactHtml.element (fun send -> <Stars stars onRate=(fun value -> send (rated value)) />)

(* todos.mlx, compiled by meltea-ppx *)
let row item =
  <li key=(string_of_int item.id)>
    <span>(Html.text item.title)</span>
    (Stars_html.view ~stars:item.stars ~rated:(fun stars -> Rate (item.id, stars)))
  </li>
```

The widget keeps its own state and effects; its effects run after the program's draw, as they run
after a Melact render. Then move the widgets one by one: its `useState`s become fields of the
screen's model, its handlers become messages, and the widget becomes a view function of the part
of the model it shows:

```ocaml
let stars hover item =
  let shown = Option.fold ~none:item.stars ~some:(fun (id, star) -> if id = item.id then star else item.stars) hover in
  <span className="stars" onMouseLeave=(Hover None)>
    (Html.list
       (List.init 5 (fun index ->
            let value = index + 1 in
            <button
              key=(string_of_int value)
              className=(if value <= shown then "star on" else "star")
              onMouseEnter=(Hover (Some (item.id, value)))
              onClick=(Rate (item.id, value))>
              (Html.text "★")
            </button>)))
  </span>
```

## Step 5: drop Melact

When the root itself is a Meltea program, the app no longer needs Melact. The shell's state moves
into the model the same way, and the program takes over the root:

```ocaml
let () = Option.iter (fun root -> ignore (Program.sandbox ~init ~update ~view root)) (element_by_id document "root")
```

Remove `melact` and `melact.meltea` from `libraries`, and `melact-ppx` from `preprocess`.
`meltea-ppx` now sees `Program.sandbox ~update ~view` and adds what it found in them: a message that
changes no field the view reads does not call the view at all.

[`examples/halfway`](../examples/halfway) is an app at step 4: a Melact shell with tabs and a
total, a Meltea screen with the list, and a Melact rating widget in every row.
[`meltea/examples/migrated`](../meltea/examples/migrated/main.mlx) is the same app after step 5.

## Every hook and its Meltea counterpart

| hook | in Meltea |
|---|---|
| `useState`, `useReducer` | fields of the model, and the branches of `update` that change them |
| `useEffect` that runs once or on a change | a `Cmd` returned by the `update` branch that makes the change (`Cmd.perform`, `Cmd.focus`, `Cmd.port`, `Cmd.message`) |
| `useEffect` that listens (timers, the URL) | a `Sub` from `subscriptions model` (`Sub.every`, `Sub.hash`); the program starts and stops it as the model changes |
| `useLayoutEffect` for focus | `Cmd.focus id` |
| `useContext` | a field of the model, or an argument of the view functions that need it |
| `useMemo`, `useCallback` | a plain `let`: every hole is guarded by `===` on what it reads, and a derived `let` at the top of a view is remembered by the fields it reads |
| `useRef` for a value | a field of the model |
| `useRef` for a timer or a listener | a `Sub` |
| `useId` | an id kept in the model |
| `useSyncExternalStore` | a `Sub` that sends the store's new value as a message |

Effects in Meltea are values, so `update` stays pure and its tests need no DOM: compare the model
and the commands it returns.

## Limits today

- A program run by `MelteaProgram` is not read by `meltea-ppx` for the fields each message
  changes, since the ppx looks only at `Program.sandbox` and `Program.element`; its view is called
  whenever the model is a new value, and the holes inside are guarded as usual.
- `Cmd.view_transition` and `Program.hot` have no effect inside `MelteaProgram`.
- `Sub` has two sources, `Sub.every` and `Sub.hash`. An effect that listens to something else can
  stay in a Melact leaf under `MelactHtml.element` until `Sub` grows.
- A `key` on the element given to `MelactHtml.element` is not seen by the list around it: put the key
  on the Meltea node that holds it.
- Server rendering of a page with a bridge is not covered by a law yet.

## Laws

[`test/bridge`](../test/bridge/bridge_test.mlx) checks, with fast-check in jsdom:

- a Meltea program inside a Melact app, under random clicks, typing, URL changes and unmounts,
  shows the same page and calls the parent's callbacks with the same values in the same order as
  the same app written with hooks; a command that settles after the unmount sends nothing;
- its view runs exactly once for each input that changes its model, and never for a re-render of
  the parent that gives the same input; while it is mounted it holds one URL listener, and none
  once it is gone;
- a Meltea app with a Melact widget shows the same page as the same app with the widget written in
  Meltea; the widget's effects run, and unmounting the widget or stopping the program leaves no
  listener.

Each law is checked against mutants of the bridges: subscriptions that outlive the unmount, inputs
that are ignored or reported back, a message that does not draw, commands that still send after the
unmount, a view called on every render, a stale `onReport`, a widget whose effects never run, a
message sent twice, a widget made again on every draw. Every mutant breaks a law.
