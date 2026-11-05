# The Melact compiler

Melact only looks like React. The surface is reason-react's: components are functions, hooks
keep state, a state change calls the component again. Underneath, the view is compiled the way
[dartea](https://github.com/jongleb/dartea) compiles Elm views: templates with holes, and per
template a generated `refresh` that guards every hole by the values it is computed from.

It relies on the contract React already sets, the Rules of React: rendering is a pure function
of props, state and context. React Compiler relies on the same contract; dartea gets it for free
from Elm.

## Status

Guards are implemented in the shared compiler (`melhole/compiler/free.ml`, `scope.ml`, `element.ml`)
and used by both front ends. The compiler writes out the walk to every hole, and the refresh
writes the holes directly. The runtime is split so that a bundle carries only what the compiled
code calls.

## Guards at the JSX site

The expressions inside a JSX tree only read variables in scope at the JSX site: props, state,
`let`s of the component body, parameters of an enclosing `fun`. For each hole the ppx computes
its free variables, scope-aware, from the AST. Module-qualified names (`String.length`, `Row.make`)
are constants. The ppx then emits, per template site, a refresh function:

```ocaml
View.compiled template 2 (fun scope (click, label, rows_hole) ->
  let count_changed = View.check scope 0 count in          (* one === against the last count *)
  let rows_changed = View.check scope 1 rows in
  View.set_handler click dec;                              (* handlers: swapped, never guarded *)
  (match count_changed with
   | Unchanged -> ()
   | Changed -> View.set_text label (string_of_int count));     (* evaluated only now *)
  match rows_changed with
  | Unchanged -> ()
  | Changed -> View.set_content rows_hole (React.array (Array.map row rows)))
```

`View.check scope k value` compares `value` with the `k`-th remembered dependency and stores
it. On mount nothing is remembered yet, so every hole is evaluated once. A hole whose free
variables are all physically unchanged is neither evaluated nor compared, and a nested JSX tree
inside it is not built at all: `lazy` everywhere, without writing it.

### What is never guarded

- event handlers: a fresh closure each render, swapped on the element without touching the DOM;
- an expression that reads mutable state: `!r`, `r.contents`, `r.current`, `Js.Date`,
  `Js.Math.random`, an assignment, or a variable bound by `for`/`while`;
- an expression with no free variables is constant: evaluated on mount only.

## A runtime made of parts

Nothing at run time interprets a description of the whole view. Every kind of child (text, list,
keyed list, template block, memo, portal) is a value that carries its own code to mount itself and
to patch a mounted child of its kind, and every hole is a typed value written by its own `set_*`.
A bundle therefore contains only the parts its compiled code names.

melhole knows no components: like Elm, it has views that are functions and children that are
values. The child protocol is open (`View.host`, `View.live`, `View.hosted`), and Melact implements
React's components on it in its own library, `melact.runtime`: instances with hook slots, effects in
commit order, context and the scheduler. Meltea never links any of it.

## Compiled walks

The compiler knows the shape of every template, so it writes out how to reach each hole on a
fresh clone, sharing every step:

```ocaml
View.template (Template.html "<p>a<!---->b<!----><b></b></p>") (fun scope p ->
  let n0 = Template.first p in
  let n1 = Template.next n0 in
  ...
  (View.text_hole { parent = p; before = Template.next_or_end n0 }, ...))
```

It also decides at compile time whether the root is an SVG element. The runtime keeps no paths
and no tag tables. A law checks the walk: interpreted over the parsed HTML, every step starts
from a node reached before it and lands on the node the hole names.

## Direct writes

The walk makes the holes once per clone: a text node, an attribute, a property, a handler, a
place for child content. The refresh gets them as a typed tuple and writes each one directly,
`set_text label (string_of_int count)`, with no index, no table of bindings and no "not bound
yet" case. Mounting is the same refresh on fresh holes, where every check reports a change, so
each hole expression appears once in the generated code. A later render of the same JSX site
finds the mounted holes through its template: the mounted clone lends them to the template, and
the refresh that belongs to that template takes them back, typed, without `Obj` or a type witness.

## Compiled lists

`Html.list (List.map row items)` in a content hole compiles to a keyed loop, `View.each`, instead
of a list of row descriptions. The compiler finds what a row reads besides its item: the free
variables of `row`, looking through local `let` definitions. If none of them changed and an item is
physically the same as before, the loop keeps the row as it is and never calls `row`.

When an outer variable does change, the loop does not re-render every row. As in Vue Vapor's
selectors, the compiler splits the row into its item and the smallest pieces without JSX that read
outer variables (its leaves), for example

```ocaml
match selected with Some id when id = item.id -> "danger" | _ -> ""
```

and emits a projection that evaluates only those leaves for an item. A row is re-rendered only when
its projection changed: selecting a row of 1,000 re-renders two. Leaves that build fresh values
(closures, records) never compare equal, so such rows simply re-render; that is slower, never wrong.
A law runs random messages against a view whose rows read two outer values and compares the page
with a fresh mount.

When a row is a single lowercase element with a `key` (after any `let`s), the compiler goes one step
further and emits `View.rows` with what all rows share, once per loop: the template, how many
values a row guards, one refresh that takes the item, and a function from an item to its key; the
`let`s before the element are repeated in both, after the item. No row allocates a description of
itself. The loop keeps one record per row (`Mounted_row`: the root element, the scope, the holes and
a witness of the holes' type) and calls the refresh directly. A row no longer needs a child description, a `with_key`
wrapper or the three closures of a generic mounted child. Creating 1,000 rows of the benchmark
allocates a third less, and the heap with 1,000 rows shrinks from 1.68 to 1.40 MB. Text, attribute
and handler holes are flat as well: the generated holes are the bare text node, element and event
key, and the last value written to a text or attribute is kept in a slot of the scope's `deps`, next
to the guarded locals. With both, 1,000 rows take 1.31 MB.

In Meltea an event prop is a message, so its handler does not need to be a closure per element.
The compiler hoists one handler per site to module level (`View.link`): a function of the locals
the message reads and of the dispatch. The element carries only those locals (`View.put_linked`
writes them to a property named after the site); the shared handler reads them from the event's
`currentTarget`, which delegation sets to the element, and builds the message when the user
clicks. With `Html.map` the dispatch changes and the site makes a new shared handler, once per
render rather than per element. A benchmark row now allocates no closure: 1,000 rows take 1.23 MB,
and creating them allocates half of what it did before compiled rows.

A dynamic text that is the only child of its element (`<td>(Html.int id)</td>`) is not a slot at a
position but a hole on the element: the first write sets `textContent`, later writes go to
`firstChild.data`. The template keeps the element empty, the walk stops at the element, and server
HTML needs no markers around such a text, because the element already bounds it. Rows of another
shape, or components such as Melact's `<Row>`, keep `View.each`.

### Moves that keep state

A keyed row that moves is moved with `parentNode.moveBefore` where the browser has it (Chrome 133,
Firefox), so a focused input, a playing video, an iframe or a running CSS animation inside the row
survive the move, as with Preact 11 and Solid; elsewhere, or if `moveBefore` refuses (a node outside
the document), it is `insertBefore` as before. A law stubs `moveBefore` and checks over random
edits of both compiled loops that no row is ever inserted again and that the page is right.

## Server rendering and hydration

`Served.render` renders a view into HTML in any JavaScript environment with a DOM (a server with
linkedom or jsdom, a build step), in the format of React's `renderToString`: no markers around
dynamic parts, a `<!-- -->` comment only between two adjacent texts, and nothing for an empty text.
server-reason-react writes the same format natively, so a Melact app can render on an OCaml
server with it and hydrate in the browser with Melact.

`Served.hydrate` takes such HTML over in document order. Without markers, a dynamic part's extent
is known only once its value is known, so the compiler generates, for every template, an `adopt`
function next to the walk and the refresh: it goes through the template's static structure and
the server's nodes together, checks every static element and text, takes a text hole's node, puts
back the anchors the template keeps between neighbours, and hands each content hole's child a
cursor; the child takes exactly its own nodes (a text one, a template one element, a list as many
rows as it has) and the cursor moves on. The values come first, from the template's own refresh
run on an off-page clone whose content holes only remember their children; then `adopt` runs on
the server's element, and the refresh runs once more on the adopted holes to set handlers. If the
HTML does not match, hydration falls back to a plain render, as React does, and the error says what
it expected and what it found. Hand-written templates (`Template.make`) are taken over by an
interpreter that follows their hole paths.

`adopt` costs about a fifth of a small app's bundle, so it is generated only with the ppx's
`-hydratable` flag, as Svelte's `hydratable` option: `(pps melact-ppx -hydratable)`. Without it the
server's HTML shows until the app mounts over it. Laws: on random trees of every kind of child,
hydration shows what mounting shows, the only comments left separate two texts, the page holds
exactly the elements the server sent, and patching afterwards matches mounting; TodoMVC hydrates a
random model and then behaves like a mounted one; and a dual law hydrates the output of React's own
`renderToString` for random pages (adjacent texts, static text next to dynamic text, keyed lists,
conditional blocks, components, neighbouring dynamic parts), then patches it through a series of
changes, under React 18 and under Melact.

### Events before the code arrives

Between the server's HTML appearing and the code hydrating it, a page looks alive and is not:
clicks and typing go nowhere. `Melhole_server.capture` is a script of a few hundred bytes for the page's
`<head>`, after Angular's event contract: it listens on `document` in the capture phase for
`click`, `dblclick`, `input`, `change`, `keydown`, `keyup` and `submit`, and keeps each event with
the `value` and `checked` its target had at that moment. The first hydration stops it and, once
the program is running, delivers the events inside its root in order: a delegated type through the
same path as a live event, any other type to the handlers from the target up to the root. Before
each event the target gets back the value it had then, so an `onInput` that reads the field sees
what was typed by that keystroke, not the field's final text; afterwards the final values return,
and a controlled field is put back from the state as after any input. A native server writes the
script; it is a string in `melhole.server`, which builds natively and under Melange. A law types, presses Enter and clicks on
TodoMVC's server page before hydration, and the page must then match a mounted page that got the
same actions, and keep matching through later ones.

### Without a DOM: the server renderer

`Served.render` needs a DOM, so on a server it needs jsdom or linkedom, and it cannot run in native
OCaml. Under the ppx flag `-server` (meltea-ppx) a view compiles to code that writes its HTML
instead: the static markup of each JSX tree is joined at compile time into as few strings as
possible, and every dynamic part becomes one call into `melhole.server`, a library of plain OCaml
that builds natively and under Melange. For the counter:

```ocaml
Melhole_server.markup w "<div class=\"counter\"><button>-</button><output";
Melhole_server.attribute w "class" (Some (if count < 0 then "negative" else ""));
Melhole_server.markup w ">";
Melhole_server.dynamic_text w (string_of_int count);
Melhole_server.markup w "</output><button>+</button><button";
Melhole_server.attribute w "disabled" (if count = 0 then Some "" else None);
Melhole_server.markup w ">reset</button></div>"
```

The format is React's `renderToString`: `<!-- -->` only between two texts, nothing for an empty
text, `checked=""`, a textarea's value as its text, a style as `name:value` pairs with hyphenated
names, void tags closed with `/>`, and `&<>"'` escaped. Where the node before a static text is
known at compile time (a tag, or another static text), the separator is decided there; after a
dynamic part the writer decides it from the last node it wrote. Floats are written as JavaScript's
`String` writes them, shortest digits that read back to the same float with ties to even, so a
native server and the browser agree. Handlers and refs are dropped, but still typed, so the module
must type-check the same way on both targets.

`meltea.server` has the same `Html`, `Cmd`, `Sub` and `Program` modules as `meltea`, so one module
with the model, `update` and `view` builds twice: against `meltea` for the browser and against
`meltea.server` with `meltea-ppx -server` for the server, natively or in Node. Commands and
subscriptions are inert there. [`examples/served`](../examples/served) is a native server that
writes a page with the capture script and the counter, and a client that hydrates it.

The model goes into the page as data, so the browser starts from it without running `init` and
its commands again: `Melhole_server.data ~id json` writes a `<script type="application/json">`
with every `<` written as `\u003c`, and `Served.data ~id` reads the text back. A law puts random
text full of `</script>`, `<!--` and `<script>` through a full HTML parse and reads it back
unchanged, with nothing after the script swallowed.

Laws, on a view with every kind of part (texts next to texts, empty texts, attributes of every
type, a style, a checkbox, a textarea, rows, a keyed list, `Html.map`, `Html.memo`, a
transition, void tags): the server's HTML parses into the same nodes, separators and attributes as
the DOM renderer writes; the browser hydrates it with none of its own elements and then patches
like a mounted page; a native corpus of 300 pages is byte for byte what the Melange build writes;
and floats are written as `String` writes them, for random doubles under Melange and natively.

## Types, where dune can give them

`meltea-ppx` has an optional typed pass, `-typed`, for builds that run it as a staged rewriter:
`(preprocess (staged_pps melange.ppx meltea-ppx -- -typed))`. Then the compiler runs the ppx with
its load path, and after rewriting, the pass types the file with OCaml's compiler-libs. It only
reads the types: if typing fails for any reason it does nothing, and a law compiles an app with and
without it and compares the JavaScript byte for byte. Its first use needs types and nothing else
gives it: a view that reads a model field which can change in place (an array, `bytes`, a
`mutable` field, or a type that contains one) gets an alert, `mutable_model`, at that read, because
Meltea redraws only when the model value changes. It works on `.mlx` and `.ml` files alike; the law
compiles TodoMVC both ways.

## The Rules of Hooks, checked by the type checker

Every hook in `React` carries an alert, `[@@alert hook]`. `melact-ppx` turns the alert off for the
whole file and back on in the branches, loops and callbacks of a component body. A hook called
there is then reported by the OCaml type checker itself, which resolves it through any alias
(`module R = React`, `open React`). It is a warning, not an error, so reason-react code that bends
the rule still compiles.

## Fields an update changes

`meltea-ppx` reads `update` the way Svelte 4 reads assignments. For every message it finds which
model fields the branch can change: `{ model with draft }` changes `draft`, `model` changes
nothing, anything it does not recognise changes everything. It reads `view` the same way: the
fields a record pattern names, or the fields read through `model.field`. Both become bit masks over
field names, and `Program` keeps the fields changed since the last draw. If none of them is one the
view reads, the view is not called at all. No signals and nothing in the user's code: the masks are
generated next to `update` and `view` and passed to `Program` by the compiler. Inside the view,
`===` stays the exact check for what to write.

`subscriptions` is read the same way. After a draw a program asks for the subscriptions again
only when a field they read changed; TodoMVC's `fun _ -> Sub.hash …` reads none, so it is asked
once, at the start. A law counts the calls against the draws after a message that writes the field
they read.

The masks travel between modules without types. Each companion is evidence: the masks and the
function they were found in. At `Program.element ~update:Todomvc.update` the compiler looks the
companion up with `open! Todomvc` over a fallback that says "not analysed", so a module the
compiler never saw, or an `.mli` that hides the companion, still compiles. `Program.track` then
checks once that the companion describes the function in use (`analysed == Todomvc.update`); a
redefined `update` or a different function gets no masks. A wrapper such as
`fun message model -> let next, command = Todomvc.update message model in (next, …)` changes what
`Todomvc.update` changes, and is recognised as such. `update` may start with helper `let`s before
its `match`.

### Remembered values in the view

A `let` at the top of a view, `let shown = List.filter … model.items`, builds a new list on every
call, and a new list fails the `===` of every hole that reads it, so typing in a field made the
list check all its rows although no item changed. `meltea-ppx` knows what such a `let` reads: the
model fields it reaches through `model.field`, the locals of the record pattern and the `let`s
before it. It compiles the `let` to `View.remember memory [| model.filter; model.items |] (fun ()
-> …)`, with one memory per site at module level: when every input is the one the value was
computed from, the old value comes back, the same object, and the holes that read it are not
evaluated. Only a `let` with a call in it that builds no view is remembered, and a view is pure, so
the old value is the value. A law counts how often such a `let` is computed over random messages and
checks it against the number of draws where its fields changed, and that the page is the view.

### Fanout: frequent events that reach a list

The same reading gives the compiler the whole path of an event, with no annotations: a handler
sends a message, the message's branch of `update` writes fields, and a list in `view` reads some of
them, through record patterns, `model.field` and the `let`s before it. When a frequent event
(`onInput`, key and pointer moves, scroll, drag) sends a message whose fields a list reads, every
such event makes the list check all its rows, and `meltea-ppx` says so at the handler, as an alert
named `fanout`:

```
File "todomvc.mlx", line 142, characters 19-44:
142 |            onInput=(fun text -> Retype text)
                         ^^^^^^^^^^^^^^^^^^^^^^^^^
Alert fanout: each input event here sends Retype, which changes editing;
the list at line 187 reads editing, so every input event checks all of its rows
```

Branches of a key handler matched on a literal key (`"Enter" -> Add`) are single actions, not
every key press, and do not count; an `update` or a list the analysis cannot read (a whole model
passed to a function) gives no alert rather than a guess. The alert is a compiler warning, not an
error, and `(handler [@alert "-fanout"])` keeps it quiet where the cost is accepted: TodoMVC's edit
field does that, since its rows show the text being edited. The alert costs no code: it is a local
module whose one value carries the message, and Melange drops it. A native law generates modules
whose branches write random fields, whose views read them through chains of `let`s into lists, and
whose handlers send random messages on input, on keys (with literal branches) and on clicks, and
checks that alerts stand at exactly the handlers an independent model of the path predicts.

### Pacing

A program draws at the next microtask after a message, so every click and keystroke is on screen
before the browser paints. Pointer moves, scroll, wheel and drag fire many times a frame; their
handlers run with `Events.pace` set to `Continuous`, and a message sent then waits for the next
animation frame, as in the Elm runtime, so a burst of moves is one draw. A discrete message while
a frame is pending moves the draw to the next microtask. A model-based law sends random moves and
clicks between microtask and frame boundaries (with a stubbed `requestAnimationFrame`) and checks
the number of view calls and the page after every boundary against a model of the schedule.

### Hot reload

A model lives outside the code, so new code can take it over, as elm-watch does. `meltea-ppx`
writes a shape next to `update`: a digest of the type declarations of its module. A program leaves
its model, its shape and a way to stop on its root. `Program.element ~start:Program.hot` (and
`sandbox`) finds the program running on the root, stops it, and starts from its model when the
shapes are the same, or from `init` when the types changed, without running `init`'s commands. With
Vite, `main.mlx` accepts its own updates (`import.meta.hot.accept()`), so an edit runs it again and
the page shows the new view of the old state; examples/todomvc does this. A stopped program drops
the messages that still reach it. A law runs a program, starts new code on its root with the same
or another shape, and checks the page against a mount of the new view on the carried model or on
`init`, and that the old program no longer draws.

### View transitions on request

`Cmd.view_transition`, returned by an update, makes the next draw run inside
`document.startViewTransition`, so the browser animates the whole page from the old state to the
new one, with no classes and no FLIP code; where the API is missing, the draw is as usual. A law
stubs the API and checks that a transition starts exactly for the draws that follow an update that
asked for one, and that the page is the view after the transitions finish.

## Components without hooks

By the Rules of React every hook is named `use…`, so `melact-ppx` sees whether a component's body
can call one. A component that calls none is a function of its props: it compiles to
`View.pure`, a child that keeps the component's identity and props and nothing else. The same
component with the same props is left as it is, new props re-render it, and another component in
its place mounts afresh, as React does. Only components that call hooks get an instance with hook
slots, effects and a place in the scheduler. A dual test checks the remount against React 18:
replacing one hookless component by another with the same output resets the state below it.

## Controlled inputs

`value` and `checked` are properties the user changes too. A guard compares a value with the one
written last, so when typing changes the DOM but not the state (an update that rejects or
filters the text, or a field cleared to the `""` it already held), nothing would write it back.
These two props become controlled holes, as in React: after an `input` or `change` event on the
element, and after the redraw the event causes, the hole puts its last written value back if the
DOM differs. The guard stays; the check after input costs one property read. One law, run against
reason-react with React 18 and against Melact, types and clicks into a controlled field and
checkbox whose handlers keep or reject the input, and compares what the page shows.

## Events and makeProps

A handler prop compiles to `fun event -> handler (React.Event.ofNative event)`: `ofNative` is the
identity, and its result is polymorphic, so the handler's own type (`React.Event.Mouse.t`,
`Keyboard.t`, …) picks the family and the compiler needs no table of them. Every accessor reads the
native event; React's own members map onto the native ones (`isDefaultPrevented` is
`defaultPrevented`, `isPropagationStopped` is `cancelBubble`, `persist` does nothing). Delegation
sets `currentTarget` to the element whose handler runs, as React does, and removes it afterwards.

melact-ppx writes `makeProps` next to every `[@react.component]`. It takes the component's labels,
an optional `key` and `()`, and returns the call to `make` with them, so
`React.createElement Foo.make (Foo.makeProps ~label ())` is `make ~label ()` with a key, checked
by the type checker, and no props object exists at run time.

## DOM elements built at run time

Some reason-react code picks a tag at run time: `React.createElement (ReactDOM.stringToComponent
tag) (ReactDOM.domProps ~className ())`, `ReactDOM.createElement tag ~props children`,
`createDOMElementVariadic`, `ReactDOM.jsx`, `React.createElementVariadic`. No template can be made
for a tag the compiler does not know, so these elements are built by the runtime. `ReactDOM.domProps`
takes every DOM prop as an optional label with reason-react's types, generated at build time from the
same table `melact-ppx` uses (`Dom_props`), with an event's family (`Mouse`, `Form`, `UI`, …) taken
from its DOM event; it returns the props as a function of the element to build, so that
`React.createElement` applies it as it applies a component's `makeProps`. The generated table also
says how each prop reaches the element: an attribute (text, flag, `"true"`/`"false"`, number), a
property, a controlled value, a delegated event, a style, a ref or inner HTML. A patch with the same
tag keeps the element, writes only the props whose values changed (`===`), removes those that went
and updates the children; another tag builds a new element. An app that does not use these functions
does not carry the table. A dual law builds elements all five ways from random tags, classes,
titles, flags, styles, handlers and children, and checks the page and the element's identity against
a model after every render and click, under React 18 and Melact.

React keeps an empty `style=""` once an element has had a style; Melact now does the same, for
compiled elements too, where it used to remove the attribute.

## Transitions

`Melhole.Transition.make` and `group` are a hosted child, like Melact's components, so the core
knows nothing about them and a bundle without them carries none of their code. The wrapper stays
mounted while its content changes. Around each patch of the content it takes the content's
top-level nodes before and after: a node that was there and is gone is an element that leaves, so
it is put back before the node that followed it (walking back through nodes that left too) and
runs the leave classes; a node that is new runs the enter classes. In a group it also reads every
kept element's rectangle before and after, and an element that moved gets a transform back to
its old place, cleared on the next frame with `name-move` on, as FLIP does. Each phase stops the
one before it on the same element, so an element removed while it enters only leaves. Classes are
switched after two animation frames, and the phase ends after `duration`, or when every animation
`getAnimations()` returns has finished, or, without the Web Animations API, after the longest delay
plus duration of its computed transition or animation. An element that leaves is `inert`. When the wrapper itself goes, the
elements still leaving go with it. meltea-ppx looks through `Html.transition_group` for
`Html.list (List.map …)`, so the list inside is still the keyed loop with selectors.

## Laws

Accepted only with these holding, by property-based tests:

- **Equivalence:** a guarded refresh renders the same DOM and runs the same effects as an
  unguarded one, for any component and any sequence of state and prop changes.
- **Guard soundness:** a hole is evaluated whenever one of its free variables changed.
- **Guard economy:** a hole whose free variables are all unchanged is not evaluated.
- **Volatility:** a hole that reads mutable state is evaluated on every render.
