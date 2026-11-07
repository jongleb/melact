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
View.compiled template (fun frame ->
  let count_changed = View.check frame.slot_0 count in     (* one === against the last count *)
  frame.slot_0 <- Input count;
  let rows_changed = View.check frame.slot_1 rows in
  frame.slot_1 <- Input rows;
  View.put_handler frame.click key dec;                    (* handlers: swapped, never guarded *)
  (match count_changed with
   | Unchanged -> ()
   | Changed -> View.write_sole_text frame.label (string_of_int count));  (* evaluated only now *)
  match rows_changed with
  | Unchanged -> ()
  | Changed -> View.set_content frame.rows_hole (React.array (Array.map row rows)))
```

`View.check slot value` compares `value` with the dependency the frame remembers, and the refresh
stores the new one. On mount nothing is remembered yet, so every hole is evaluated once. A hole whose free
variables are all physically unchanged is neither evaluated nor compared, and a nested JSX tree
inside it is not built at all: `lazy` everywhere, without writing it.

A local function is a fresh closure on every render, so a guard on it would always fire. A hole that
calls one, such as `(button "run" "Create 1,000 rows" Run)` with `button` defined in the view, is
guarded instead by what the function captures, looking through further local definitions. A
helper that captures nothing outer is evaluated on mount only.

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
View.template (Template.html "<p>a<!---->b<!----><b></b></p>") (fun p ->
  let n0 = Template.first p in
  let n1 = Template.next n0 in
  ...
  { text_1 = View.text_at { parent = p; before = Template.next_or_end n0 }; ...; slot_0 = View.unset })
```

It also decides at compile time whether the root is an SVG element. The runtime keeps no paths
and no tag tables. A law checks the walk: interpreted over the parsed HTML, every step starts
from a node reached before it and lands on the node the hole names.

## Direct writes

The walk makes the holes once per clone: a text node, an element, a property, a place for child
content. They go into one record, the clone's frame: for every template the compiler declares a
record type with a field per hole (its type a parameter, so the compiler need not name DOM types)
and a mutable field per value the refresh remembers. The frame is all a mounted clone keeps; there
is no scope, no array of dependencies and no tuple of holes beside it. The refresh takes the frame
and writes each hole directly, `write_sole_text frame.label (string_of_int count)`, with no index,
no table of bindings and no "not bound yet" case. Mounting is the same refresh on a fresh frame,
whose fields hold `View.unset`, so every check reports a change and each hole expression appears
once in the generated code. A later render of the same JSX site finds the mounted frame through its
template's witness and gives it to the refresh typed, without `Obj`.

What a frame needs at moments only the runtime sees is generated per template too, and shared by
every clone: what to do once the root is placed (refs get their element), when it goes (content
released, direct listeners removed, refs called with null), and, in Melact, after a render threw
halfway (every remembered value forgotten). A mounted child of any kind is itself one value: what
it is (text, list, compiled template, a library's component) and what it holds; visiting its
nodes, finding its first one and releasing it are functions of that value, and a library's own
kind of child (Melact's components, transitions) gives them once per kind, not as closures per
child.

## Compiled lists

`Html.list (List.map row items)` in a content hole compiles to a keyed loop, `View.each`, instead
of a list of row descriptions. The compiler finds what a row reads besides its item: the free
variables of `row`, looking through local `let` definitions. If none of them changed and an item is
physically the same as before, the loop keeps the row as it is and never calls `row`.

Melact compiles the forms reason-react code writes lists in: `React.array` over `Array.map`,
`Belt.Array.map` or `Js.Array.map ~f`, called directly or through `|.` and `|>`, and `React.list`
over `List.map`. `Array.mapi`, `Belt.Array.mapWithIndex` and `Js.Array.mapi ~f` give a numbered
loop: a row that reads its index is drawn again when its index changes, and a row whose index is
ignored compiles as a plain one. A law runs every form against React after random edits.

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

The loop remembers the list it was drawn from. When the next render passes the same list (`===`)
and no outer value changed, the loop does nothing at all: no array is made from the list and no row
is looked at. When only an outer value changed, the rows are reselected over the array already made.

Re-projecting is still a pass over every row, so the compiler also recognises the leaves that pick
rows by key, `match o with p when x = i -> a | q -> b` (or `if e = i then a else b`) where `p` binds
`x` alone, `q` binds nothing, `o` reads no row name and `i`, `a`, `b` read no outer one. Such a
leaf is a selector: the loop gets the key `o` chooses this render (`match o with p -> Some x | _ ->
None`), a function from a row to its key `i`, and, once per site, the bits of the outer inputs the
row's other pieces read. When only inputs that no other piece reads change and every item is the
one it was, the loop looks up the rows whose key the selector chose before or chooses now in a
JavaScript `Map` from key to rows (built at the first such change, dropped when items change or
move) and re-projects those alone; otherwise it takes the pass above. `=` is structural, so the
`Map` is used for it only when the keys are numbers, strings or booleans, and for `==` always.
Selecting a row of 1,000 now projects two rows instead of 1,000. Laws over `View.each` (numbered
or not) and `View.rows` with string, tuple, shared-object and index keys, duplicated across rows,
compare every patch with a fresh mount and count renders and projections; mutants that keep the
`Map` across edits, forget the old key, ignore another piece's input or drop the primitive check
each break them, and a dual law selects component rows against React 18.

When a row is a single lowercase element with a `key` (after any `let`s), the compiler goes one step
further and emits `View.rows` with what all rows share, once per loop: the template, the root of a
row's frame, one refresh that takes the item, and a function from an item to its key; the
`let`s before the element are repeated in both, after the item. No row allocates a description of
itself. The loop keeps one record per row and calls the refresh directly. A row no longer needs a child description, a `with_key`
wrapper or the three closures of a generic mounted child. Creating 1,000 rows of the benchmark
allocates a third less, and the heap with 1,000 rows shrinks from 1.68 to 1.40 MB. Text, attribute
and handler holes are flat as well: the generated holes are the bare text node, element and event
key, and the last value written to a text or attribute is kept next to the guarded locals. With
both, 1,000 rows take 1.31 MB.

In Meltea an event prop is a message, so its handler does not need to be a closure per element.
The compiler hoists one handler per site to module level (`View.link`): a function of the locals
the message reads and of the dispatch. The element carries only those locals (`View.put_linked`
writes them to a property named after the site); the shared handler reads them from the event's
`currentTarget`, which delegation sets to the element, and builds the message when the user
clicks. With `Html.map` the dispatch changes and the site makes a new shared handler, once per
render rather than per element. A benchmark row now allocates no closure: 1,000 rows take 1.23 MB,
and creating them allocates half of what it did before compiled rows.

A row is now its frame and nothing else: the root element, the holes the refresh writes and the
values it remembers, in one record of the template's own type. The loop keeps the frames in one
array and reaches a row's root through a function generated once per loop site; the template's
witness, checked once per patch rather than per row, proves the frames' type, and a hole that
switches to another loop builds that loop afresh. A text or attribute whose value is a local
itself, `string_of_int` of it or `Some` of it changes exactly when the local does, so it keeps no
value of its own. The benchmark row went from four JavaScript objects and two array stores (the
row record, its scope, the dependency array and the holes tuple) to one object of nine fields: 1,000 rows
take 1.07 MB instead of 1.19. Melact's rows gain more, because every mounted child lost its three
closures and every content hole its cleanup closure and the child description it kept for an
identity check (1.61 to 1.26 MB), and the app benchmark's 2,009 components take 2.82 MB after
mount, where they took 4.93 and React takes 4.00.

A dynamic text that is the only child of its element (`<td>(Html.int id)</td>`) is not a slot at a
position but a hole on the element: the first write sets `textContent`, later writes go to
`firstChild.data`. The template keeps the element empty, the walk stops at the element, and server
HTML needs no markers around such a text, because the element already bounds it. Rows of another
shape, or components such as Melact's `<Row>`, keep `View.each`.

### Long lists in groups

On a long page most of the work is the browser's: style, layout and paint of rows nobody sees.
`content-visibility: auto` lets it skip an element out of view, but set on every row it halves the
creation of 10,000 rows and makes updates slower (496 → 253 ms and 66.5 → 85.3 ms, Chrome 151, 4x
CPU), because each row becomes its own containment. On groups of 100 rows it gives 65.5 ms and
6.4 ms. `View.chunks`, offered as `Html.chunks` in Meltea and `MelactLayout.chunked` in Melact,
cuts a keyed list into groups of `size` rows (default 100), each a wrapper (default `div`) with
`content-visibility: auto; contain-intrinsic-size: auto <size × row height>px`. A group whose keys
did not change patches its rows in place; when keys move, every row that stays is moved into its
group with its node, its component instance and its state, and only new rows are made. It is a
choice, not the default: the wrappers change the DOM, so selectors such as `:nth-child` and a
`<ul>`'s content model see them, and a filter that removes most rows costs more than without groups.
On the corpus's log viewer (a Melact build with groups against one without, 1x CPU, 5 runs):
mount 300 → 75 ms, toggling line wrap 448 → 23 ms, selecting ranges 382 → 149 ms, clearing the
query 698 → 272 ms, appending 30 batches 702 → 455 ms, and typing a query 95 → 128 ms. A law edits
random keyed lists in groups of random sizes: rows show in order, groups hold at most `size` rows,
and every row that stays keeps its node in whatever group it lands; a Melact law moves stateful rows
within and across groups and they keep their counts. Making moved rows again, or rebuilding the
groups, breaks them. Groups are written on the client only; a server page shows the rows ungrouped.

### One block removed or added

When the outer values are kept and the list only lost or gained one block of rows, the loop finds
the longest run of physically equal items at both ends and touches only the middle: it removes the
rows that went, or mounts the new ones before the first row that follows them. Loops of components
(`View.each`) do the same when rows ignore their index; a row that shows nothing is skipped when
looking for the node to insert before. Removing a row or
appending 1,000 compares each kept item once and builds no plan.

### A few rows that change places

When a compiled loop keeps its length and its outer values, and at most 64 rows changed places
among themselves (a swap, a short shuffle), it does not plan the whole list: it finds the rows
whose key changed, matches each to the row it came from, moves exactly those, last first, and
refreshes only rows whose item changed. Swapping two rows of 1,000 moves two rows, as hand-written
code does. A law with repeated keys checks that no old row is taken twice.

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

`Program.resume` starts a served Meltea program without taking its page over: it runs no view and
touches no node, and listens on `window`, in the capture phase, for the first click, double click,
input, change, key, submit or pointer press inside its root. That input takes the page over at once,
as `Program.hydrate` does at startup, and then goes on to the handlers it just attached, its target's
value and checked state as the user left them; a message from a command or a subscription takes the
page over at its draw, and events the capture script kept take it over at the next microtask and are
replayed, as with `hydrate`. It moves the work rather than removing it. On a served TodoMVC
([`bench/resume`](../bench/resume/run.mjs), headless Chrome, a click pressed for 80 ms) the main
thread's work over the load falls from 84 to 67 ms with 1,000 rows and from 228 to 158 ms with 5,000,
and at 4× CPU throttling from 266 to 200 ms and from 899 to 634 ms, with 134 ms of blocking time
gone; the first click pays the takeover instead (its longest task 5 → 33 ms and 15 → 98 ms at 4×),
mostly hidden because the pointer press starts it, so that the time from the press to the paint after
the click stays 89 ms with 1,000 rows and grows from 106 to 125 ms with 5,000. Taking over in an idle
callback after the first paint saves nothing: it is the same single long task. `hydrate` stays the
default; `resume` is for long pages that are mostly read. Laws, on a page whose model records every
message in order: after random inputs before and after the code arrives, route changes and command
replies, a resumed page shows what an eagerly hydrated page and a mounted page show; with no early
input it runs no view and changes no node until its first input; that input runs the view once,
keeps every element the server sent and creates none. Skipping the replay, taking over twice, losing
the first input, replaying before taking over, taking over at startup, dropping the typed value and
taking over with the current model each break one of them.

### Without a DOM: the server renderer

`Served.render` needs a DOM, so on a server it needs jsdom or linkedom, and it cannot run in native
OCaml. Under the ppx flag `-server` (meltea-ppx, melact-ppx) a view compiles to code that writes its HTML
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
subscriptions are inert there. [`meltea/examples/served`](../meltea/examples/served) is a native server that
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

The writer is fast under both backends. Escaping returns the text itself when it holds none of
`&<>"'`, and copies by slices otherwise. Natively the HTML goes into a `Buffer`; under Melange it is
one JavaScript string grown with `^`, which V8 joins as a rope, because Melange's `Buffer` is built
on `Bytes` and costs a copy per character. A 1,000-row page renders in 0.16 ms under Node (React's
`renderToString`: 1.2 ms; it was 2 ms before) and in 0.26 ms natively; a mutant that skips escaping
breaks two served laws.


### Melact without a DOM

`melact-ppx -server` compiles reason-react components the same way, against `melact.server`
(Melange, in Node) or `melact.server.native` (native OCaml): the same `React`, `ReactDOM` and
`ReactDOMServer`, where `renderToString` and `renderToStaticMarkup` write what React 18's write,
byte for byte. A server build is one more stanza, `(libraries melact.server) (preprocess (pps
melange.ppx melact-ppx -server))`. Natively the API is the portable part of reason-react's, with
records where reason-react has JavaScript objects: a provider's `makeProps` builds
`React.Context.props`, and `dangerouslySetInnerHTML` takes an object with an `__html` method.

An element is a writer. A component writes itself when its parent writes it: it renders once with
fresh hook slots (`useState` and `useReducer` give their initial state, `useMemo`, `useCallback` and
`useRef` their first value, `useContext` the value of the provider being written around it), and
effects of every kind never run. A state set while the component renders makes it render again with
the update, as React's server and Melact's client do, and a dispatch afterwards
is dropped. Handlers and refs are typed and dropped. A Suspense boundary is written as
`<!--$-->…<!--/$-->`; if a child throws, what it wrote is taken back and the boundary is left to the
client, `<!--$!--><template></template>`, the fallback, `<!--/$-->`, as React writes it in
production. An error boundary writes its children, as on React's server.

The format follows React's server rather than the DOM: attributes in reason-react's order (the order
of its `domProps`, with `?label` props after the others), React's names (`tabindex`, `readonly`, …),
`cols`, `rows`, `size` and `span` only from 1, an input's `checked` and `value` last, a textarea's
value as its text and a select's value as `selected=""` on its options (also on options written by
components below it), one more newline at the start of a `textarea`, `pre` or `listing` whose
content starts with one, and style values trimmed. Elements built at run time
(`ReactDOM.createElement`, `createDOMElementVariadic`, `React.createElement` of `stringToComponent`,
`ReactDOM.jsx`, npm-style `createElement` of a tag) go through the same rules from their props
object.

`useId` gives React's ids, `:R` and the position's tree id: every JavaScript array of children
(`React.array`, a JSX list of two or more children, a fragment, the variadic children of
`createElement`) numbers its items, a component that took an id numbers its output as the only
child, and a component's second and later ids add `H` and a count, as React's `pushTreeContext`
does. The compiler knows the arrays of a template, so each content hole carries its path of
positions; the writer keeps the position. Melact's client numbers positions the same way while it
hydrates: the generated `adopt` passes each content hole's path, lists number their rows, and an
instance that takes a server's nodes keeps its position, so `useId` there gives the server's id;
components mounted later keep Melact's own ids. One difference remains: a JSX fragment with one
child and the one variadic child of `createElement` stay lists on the client, so that the child
keeps its state when the same place later shows more children, as under React; a `useId` right below
them is numbered as an array item there, and hydration writes the client's id. Hydration also takes
React's Suspense markers over (and renders a boundary the server left to the client), and keeps the
server's `dangerouslySetInnerHTML`. The client now also writes an `option`'s `value` as an
attribute, so a `select` in the same template finds its option, and a `textarea`'s `defaultValue` as
its text.

Laws, on random pages of components with every hook, nested providers, ids in arrays, fragments and
components, forms, styles, attributes, elements built at run time, Suspense with children that
render or throw, render-phase updates, floats and texts next to texts
([`test/mserver`](../test/mserver)): Melact's server under Melange writes exactly what React 18's
`renderToString` (a boundary left to the client as in production) and `renderToStaticMarkup` write
for the same reason-react code; a native corpus is byte for byte the Melange output; no effect runs
on either server; and Melact's client hydrates the HTML with the server's own elements and ids, also
after a hydration that failed, then patches like a mounted page. Mutants that drop a text separator,
skip escaping, run effects or layout effects, ignore a provider, number array items from 0, forget
the position below a component that took an id, ignore the JSX children's positions, do not reset
the client's position, number every row of a list alike, keep source attribute order, write an
input's value before `checked`, ignore a select's value, drop the leading newline, drop render-phase
updates, drop Suspense markers, keep what a failed Suspense child wrote, make fresh refs in a
render-phase pass, keep untrimmed styles, write `rows` below 1, keep separators in static markup,
rewrite the server's inner HTML or keep React's markers on the client each break a law (24 mutants).

On the SSR benchmark (1,000 rows, median of 200 renders, Node 26), Melact's server renders a page in
0.26 ms natively and 0.15 ms under Node, where React 18's `renderToString` takes 1.1 ms, Svelte 5's
0.04 ms and Meltea 0.27 and 0.15 ms; with 10,000 rows 3.0 and 1.8 ms against React's 17.7 ms.
Before, Melact's `renderToString` needed a DOM in Node and was 13 to 55 times slower than React.

`ReactDOM.Client.resumeRoot` is Melact's own, not React's: it leaves a server's page as the server
wrote it, rendering no component and running no effect, until the first click, key, input, submit or
pointer press inside the container, through `Served.resumable` as Meltea's `Program.resume` does.
That input hydrates the page as `hydrateRoot` does and flushes its effects, layout and passive,
before it reaches its handlers, as React 18 does for a hydration a discrete input forces. A law on
random server pages: before the first click the page's markup is unchanged and no effect has run;
the click keeps every element the server sent, finds as many effects run when its handler runs as a
hydrated page does, and leaves the page as a hydrated page that got the same click. Taking over at
startup, running no effect after the takeover, or only the layout ones, each break it. Melact's
hydration is cheap, so the gain is modest: on a served page of 5,000 rows at 4× CPU throttling the
main thread's work over the load falls from 1,119 to 1,012 ms and its blocking time from 645 to
609 ms, while the first click pays the takeover (to paint 38 → 175 ms); with 1,000 rows at 4×, 243
to 193 ms and 95 to 74 ms. The rest of the load is the browser parsing, styling and laying out the
page. `hydrateRoot` stays the default; `resumeRoot` is for long pages that are mostly read.

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

`melact-ppx` takes the same flag, `(preprocess (staged_pps melange.ppx melact-ppx -- -typed))`, and
both passes are built on one library, `melhole.typed`. The untyped rewrite runs first and is complete
on its own. Where it wants an answer from types it asks a question, `[@melhole.ask n]` on an
expression or an external, and leaves a site, `[@melhole.site n]` on an expression or on an
`include struct … end` around items, together with the function that decides it. After every
rewriter, a file that has a site is typed (an external that is not a function is typed as
`let x : t = assert false`); each question gets the type of the one node that carries its mark, a mark
found twice gets none, and the sites are decided innermost first. Without `-typed` nothing is marked;
when the file does not type, every site stays as the untyped rewrite wrote it and the marks are
removed, so the output is exactly the untyped one. Two readings are provided.
`Melhole_typed.Mutability` says what `===` tells for a type, after expanding abbreviations and
substituting parameters: `Immediate` (int, char, bool, unit, int32, constant constructors, string,
float: JavaScript primitives), `Immutable_boxed`, `Mutable_inside` (an array, `bytes`, a `mutable` or
atomic field, a ref, a `Js.dict`, a `Js.t` with a setter, a `Hashtbl.t`, or a type that holds one) or
`Unknown` (type variables, abstract and open types, OCaml objects, modules, `lazy`). Meltea's alert is
`Mutable_inside`. `Melact_ppx.Typed.component` says whether a type is a component: `Compiled`
(`x_props -> React.element`, a `[@react.component]`) or `Of_props` (`props -> React.element`). The
first site: a binding to npm's `Fragment` whose written type does not show a component, but expands
to one of a `Js.t` with `children : React.element`, becomes `let fragment : t = Melact_npm.fragment`.
The dual suite and the reported apps compile to the same JavaScript with and without `-typed`. The
dual suite also runs with a test probe that asks the type of every variable passed to a function and
checks that every question is answered and each variable typed `Immediate` is a JavaScript
primitive. A native law checks the classifier and the component reading against their definitions on
generated declarations; 33 mutants of them and of the sites are caught. Typing takes the compilation
of the dual suite's 2170 lines from about 0.45 s to 0.6 s; a file without a site is not typed.

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
the page shows the new view of the old state; meltea/examples/todomvc does this. A stopped program drops
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

### Spliced into the caller

Where a hookless component is the row of a `map`, `melact-ppx` splices its body in: the props
become `let`s and the body joins the caller's template, so a list of such rows compiles to
`View.rows` with one template and no child per row. In a child slot of a DOM element it stays a
component. Spliced there, its DOM writes would happen in its parent's pass instead of the next
round, before the render of a later component that reads layout (`offsetTop` of a ref): each such
read then forces a layout. In an event table, sorting went from 2 layouts to 4 and from 73 to 106 ms.
An element that flows as a value (passed to `render`, returned from a branch) keeps the component
too, since two places of one component must keep its state when they swap. The
body is spliced only when no name it reads is shadowed where it lands, it takes required labelled
props and no `children`, and `React.memo` carries no comparison of its own. On the keyed benchmark
creating 1,000 rows went from 20.7 to 16.6 ms and 10,000 rows from 193.9 to 179.0 ms.

Across modules the body travels in the component's signature. When a file's top-level `make` can
be spliced, `melact-ppx` puts it, with a format version, on the `external make` it emits, as the
attribute `melhole.inline`; names of the file that the body reads (values, constructors, fields,
types, modules, each in its own namespace) are written as paths of the module itself. The attribute
reaches the `.cmi`. A caller compiled under `(preprocess (staged_pps melange.ppx melact-ppx))` has
the dependencies' `.cmi` on its load path: at `<Row …/>` it finds `Row.make`, reads the attribute,
replaces the module placeholder by `Row` and splices the body as for a component of its own file.
Under `pps` the load path is empty and every call stays a call; a file with `open` or `include`, a
parameter named like a value of its file, an older format version or a shadowed name keep the call
too. A law runs one app of four files three ways, reason-react with React 18, Melact under
`staged_pps` and Melact under `pps`: every build shows what React shows through random reorders,
clicks and prop changes, children's state stays with its key, and the `staged_pps` build calls no
spliced component, the `pps` build calls them all. Accepting any format version, ignoring a shadowed
name, or not writing the module's own names as its paths each break it.

### Props read through their fields

A component compares its props with the ones of its last render, each with `===`. When the body
uses a prop only as `p.f` (never `p` itself, never rebinding it), the compiler compares the fields
it reads instead of the record: a parent that builds a fresh record with the same title and count
on every render, as code that maps server data does, no longer renders a child that shows only the
title and the count, and a prop the body never reads is not compared at all. React compares props
by reference and cannot do this. The fields are read where the component is compiled, so a
component of another module gets it too. A law makes a parent build a fresh three-field record on
every change: a child that reads two fields renders only when one of them changed, a child that
passes the whole record to a function renders on every change and shows the third field, and a
child whose prop default reads a field follows it; comparing the record whole, or treating a whole
use as a field use, break it.

The same holds for a compiled list. A loop's rows are refreshed when one of its outer inputs
changes, the values of the component the rows read. A record the rows use only as `r.f` counts by
those fields: in the keyed benchmark the rows read `state.selection`, so updating every tenth row
or swapping two, which make a new `state`, no longer project all the other rows again. A name a row
reaches through a `let` of the component, or uses whole anywhere in the row, stays a whole input. A
dual law reads one record three ways (a field, a let of another field, a function given the whole
record) through random changes; refining through the let, or treating a whole use as fields, each
break it.

## Values written in props

reason-react code writes closures, style records, arrays, tuples and child elements straight into
the props of the components it renders, and each render makes them again, so the child sees new
props although nothing it shows has changed. In a component with an instance, `melact-ppx` caches
each such value on what it captures, as React Compiler does: `Free.captured` reads the free
variables, a closure's body counting as run when it is called, and the value is kept in the
instance's cells while they are the same (`===`). The prop becomes `let found = Memo.lookup2 cells
at index setCount in match Memo.kept found with Some kept -> kept | None -> Memo.store cells (at +
2) found value`, which allocates no closure: the kept branch is typed first and `found` is invariant
in the value's type, so the type the prop expects reaches `value`, and the bare constructors and
labels of a type declared in a module that is not opened resolve as they do in reason-react (a thunk
`fun () -> value` passed to a function would lose that type, and such code would not compile). A
value that calls a hook, or reads mutable state while rendering, is left as written. Hole guards
already skip a child whose reads did not change, so the cache pays when a hole is evaluated again
and the child's props are equal anyway: a derived value that came out the same, or several children
in one hole. A dual law clicks through closures and state changes against React 18; two Melact laws
count the child's renders, and mutants that always or never hit the cache, or cache a value that
reads a `ref`, each break one. A regression test renders a child whose props use the bare names of
another file's record and variants, in records, constructors, tuples, arrays, lists, and closures
that return them, read fields or match on them.

The same cache keeps the `let`s of a component's body. A closure is always kept on what it
captures. A computed value is kept only when `Frozen` finds that the rest of the body just reads
it: in JSX, a hook's dependencies, a `match`, a field, or a library function known not to change
its argument (`List`, `Belt.Array.keep`, `Js.Array.map`, …); `let total = ref 0` followed by
`total := …` is computed on every render. A kept `let` carries `[@melhole.cached value]` until the
scope traversal records `value`, so a loop whose row function is such a `let` still compiles. Two
Melact laws count the computations, and mutants that ignore `Frozen` or keep no `let` break them.

### State set while rendering

React's way to adjust state when a prop changes is to set it while rendering: the component renders
again at once with the update, before any child, at most 25 times. Melact does the same: a setter
called by the component that is rendering marks it to render again, any other setter called while
rendering still throws. An effect queued by the attempt that set the state takes the next attempt's
closure, whatever its dependencies, so it sees the last render, as React's does. A dual law follows
a prop through random changes: the text and what the effect saw match React; a mutant that keeps
the first attempt's effect breaks it. A component that sets its own state on every render throws
"too many re-renders", as React does.

### Deferred values

`useDeferredValue` gives the render that changed its value the value it showed before, and asks
for a render of its own in a later task, where the deferred value catches up, as React's background
render does without interrupting it. A keystroke in a search field paints at once and the long list
that reads the deferred text renders in the next task; several keystrokes before it runs catch up
once. `act` runs that work too, as React's does. A dual law logs every render's pair of text and
deferred text through random changes and finds React's two renders per change; the hook that
returned its value at once breaks it. On the corpus's playlist search Melact went from 1.14 to 1.21
times React's time to 0.75 to 1.07.

### Reading layout while rendering

React renders every dirty component first and writes the DOM afterwards, in its commit, so a
render that reads `offsetTop` or `getBoundingClientRect` sees a clean layout and costs nothing
extra. Melact writes a component's holes as soon as the component renders, and its children render
inside that write, so the next component that reads geometry forces the browser to lay out the
page again. A user team's table read `offsetTop` in each row's render: Expand all on 400 rows took
401 layouts under Melact against 4 under React; reading it in a layout effect instead, which Melact
runs after all the dirty instances are written, made Melact faster than React there. Ref callbacks
wait the same way: a placed ref is queued and gets its element when the outermost `View.mount` or
`View.patch` ends, or, in Melact, after a flush's renders and before its layout effects, so a
callback sees the whole tree, as in React; a dual law reads the number of rows from each row's ref.
A flush now renders in rounds. A round renders every dirty instance that has no dirty ancestor,
in document order, and only then writes them; instances made dirty by those writes (a context's
consumers, children with new state) form the next round, still before refs and layout effects, while
state set during the writes (a ref called with null) waits for the next pass, as React's commit does.
So the user team's rows, which read `offsetTop` and re-render through a context, now cost one
layout. A dual law counts DOM writes from inside each row's render and finds the same count in all
of them under React 18 and under Melact; a mutant that writes each instance right after rendering it
breaks it. A component that re-renders because its parent passed new props is put off to the next
round too (unless its render is pure, see "The update graph"), so rows given new props by their parent also all render before any of them writes; a
pass that put any off sorts its effects into the order of the tree, children first, as React runs
them. Two dual laws check both, and a mutant without either fails one. A component without hooks
has no instance and still renders inside its parent's write. Only instances of the same round count as dirty ancestors: a component whose own
state waits for the next pass, hidden from its dirty parent by a memoized one in between, must not
hold back the context consumers under it, or the rounds never end. A dual law sets the state of
such a component together with the context above it.

`MelactDebug.warnLayoutReadsInRender ()` wraps the layout getters and methods of the DOM
(`offset*`, `client*`, `scroll*`, `innerText`, `getBoundingClientRect`, `getClientRects`,
`getComputedStyle`) and warns once per component and property when one is read while a component
renders or its holes are written; components are named by their module path (`Main.Row.make`). A
Melact law reads layout in a body, a hole, a layout effect, a ref callback and a handler, and expects
a warning for the first two only; mutants that ignore holes, warn every time, or attach refs at once
each break it. Rendering is
meant to be pure, and React's docs say the same; this is the one place where code that bends the
rule costs more under Melact.

## The update graph

A render is a function of what React lets it read: props, state, context and the values of hooks.
`melact-ppx` reads every component body for two facts it can use at build time: whether the render
reads anything else, and, for each value the body computes, which of those sources it comes from.
Neither needs annotations or signals in the user's code; both come from the reason-react source as
it is (`ppx/melact/graph.ml`).

### Pure renders

A render is pure when, evaluated now, it reads nothing a DOM write or another render can change: no
`r.current`, `r.contents` or `!r` of a ref it did not make itself, no assignment to one, no loop, no
`Js.Date` or `Js.Math.random`, no getter called with `()` alone (`dom_writes ()`), no method call
and no hook the compiler does not know. A ref made by the same render (`let matched = ref ...` in a
`useMemo`) may be written and read: that is local mutation, which React allows. A function's body
counts as run while rendering (a row function, a `useMemo` or `useState` initialiser, a let-bound
helper) unless the function is a JSX prop or the callback of an effect, of `useCallback` or a
reducer: those run when the user or React calls them. Calls to other functions are taken as pure, as
the props cache above already takes them. The answer goes into the component's definition,
`Component.pure` or `Component.make`.

Rounds exist for renders that read the page (see "Reading layout while rendering"): all of a round
render before any of them writes. For a pure render that ordering cannot be seen, so the scheduler
drops it where it costs work:

- A pure child given new props renders at once, inside the parent's write, when the parent patches
  its children in document order (a template's holes, or a list patched in place, which now goes
  from the first row) and no component that may read the page is due to render later in the same
  flush. A list that patches from its last row, reconciles moves, shuffles or picks the rows a
  selection changed sets `View.patch_order` to `Out_of_order`; a child reached there, or while an
  impure component waits for a later round, is put off to the next round as before, so that its
  writes stay behind those reads. (Rendering it at once there cost eventtable's selection one forced
  style recalculation more per key: its inspector wrote its portal before the rows read `offsetTop`.)
- A round whose dirty instances are all pure is one pass in document order. An instance whose
  ancestor rendered earlier in the pass comes after it: skipped if the ancestor's write reached it,
  rendered with its current props if not. A tree of readers of one context renders in one round
  instead of one round per level, and the page is walked once to order it instead of once per level.
- Effects need sorting into the order of the tree only when an instance that queued effects
  committed after one of its ancestors in the same pass. The scheduler now notes exactly that (it
  keeps the instances committed in the pass and looks up the ancestors of the next one) and sorts
  only then; before, any put-off child forced the sort, a walk over the whole document.

An impure component that reads a context renders, when the context changes during a flush's
writes, right where its provider is patched: before the provider's subtree is written, so it reads
the page as the update found it, as React's render phase does; the scheduler keeps the result and
writes it in its round, unless new props or new state arrive first. The event table of the corpus,
whose rows read `offsetTop` and the selection from a context, forced 30 layouts over its scenario
and now forces none (React 18: 4, in its layout effects), and the ratchet's generated programs go
from 103 forced layouts more than React to 96. Components given new props by a parent's write
still render after that write; doing better needs a refresh that hands children their props before
it writes, which is not built yet.

A root rendered inside a discrete event now runs its passive effects at the next microtask, as React
18 runs those of a commit in its sync lane, instead of after the next paint. Found while measuring:
the app benchmark's first click on a row, after mounting with a click, raced the mount's effects.

### Sources and masks

The sources of an instance are numbered at build time: its inputs (each prop, or each field of a
prop read only through fields), then its hook slots in order (slot 0 is the instance's memory), then
its context reads. The body is read as steps (a hook called on every render: `useState`,
`useReducer`, `useRef`, `useId` or a known custom hook; a context read; a memo or callback; an
effect; a statement; a let) and the expression it returns. Each step gets a mask, the bits of the
sources it reads, through the lets before it:

```ocaml
let theme = React.useContext theme_context in               (* the context's bit *)
let fold, setFold = React.useState (fun () -> bulk.fold) in (* fold: the cell's bit; setFold: none *)
React.useEffect1 (fun () -> setFold (fun _ -> bulk.fold); None) [| bulk.generation |]; (* bulk's bits *)
let label = item.title ^ theme_class theme in               (* item's bits and the context's *)
<li className=(label ^ ...) ...> ... </li>                  (* label, fold, highlight, item, ... *)
```

The runtime knows which sources changed: a state cell's bit when its value differs from the one the
last render read, a context's bit when its provider's value changed (a provider keeps its readers in
a `Map`, each with the bits its value is to it), the bits of the inputs that differ when a parent
patches a child. Before the render, `Instance.changed ()` holds them: `Bits` of the sources that
changed, or `Every` when that is not known (a mount, a boundary, a deferred value catching up, a
component that set its own state while rendering). The body then runs only the steps whose mask
meets them, every step for `Every`:

```ocaml
let theme =
  let found = Melact_runtime.Memo.graph memory 1 changed 512 in   (* the context's bit *)
  match Melact_runtime.Memo.kept found with
  | Some kept -> kept
  | None -> Melact_runtime.Memo.store memory 1 found (Melact_runtime.Instance.consume_source ... (Bits 512) ...)
in
...
(match Melact_runtime.Instance.reaches changed 24 with Unreached -> Melact_runtime.Instance.skip_hook () | Reached -> React.useEffect1 ...);
...
match Melact_runtime.Instance.reaches changed 679 with
| Unreached -> React.of_child Melact_runtime.Instance.unchanged       (* nothing the view reads changed *)
| Reached -> <the template>
```

A let or a context read keeps its value in the instance's memory, a memo or an effect whose
dependencies read no changed source is passed over without evaluating them (`skip_hook` moves the
slot cursor on), and when the returned expression reads none of the changed sources the render
returns `Instance.unchanged` and the instance's holes are not touched at all: a context or a prop
that only an effect reads costs the effect's comparison and nothing else. Hooks called on every
render and statements always run, so hook slots, render-phase logs and `useEffect` without
dependencies behave as before. A value a later statement may change in place (`Frozen`) is made on
every render.

A body the compiler cannot read as steps renders whole, as before: a hook it does not know
(`useSyncExternalStore`, `useDeferredValue`, a custom hook without a fact), a hook inside an
expression, `open React` with bare hook names, more than thirty sources, or an impure render.

### Across modules

The graphs of a parent and a child are linked at run time, not through types: the parent's patch
gives the child the bits of the inputs that changed, and the child's own graph, compiled in its own
module, does the rest. That works under `pps`, through an `.mli` and across libraries.

What a module boundary hides is a custom hook. A top-level `useX` whose body is pure and calls only
React's hooks and known custom hooks at its top level gets a fact on its pattern, which reaches the
`.cmi`: `[@melhole.hook (1, slots)]`, a format version and the hook slots it takes on every call. A
component that calls it, in the same file or, under `staged_pps`, from another module (read with
`Env.lookup_value`, as `melhole.inline` is), keeps its purity and its graph: the call is a step that
runs on every render, and the hook's state cells are numbered after the component's slots before
it, as the runtime numbers them. Without the fact (under `pps`, behind an `.mli` that hides it, or an
older version) the hook is unknown and the component renders whole, as before. melact-ppx's bindings
to npm's React hooks are such custom hooks too.

### Laws and measurements

- A QCheck law (`test/graph`) builds random bodies from pure pieces and reads of the world (a ref's
  `current`, `!r` of an outer ref, `Js.Date`, a getter, an assignment, an unknown hook, a method
  call) placed while rendering or in a handler, effect, callback or reducer, with render-local refs
  and a known custom hook, and checks that a body is impure exactly when a read of the world runs
  while it renders. Treating JSX props as run now, ignoring `.current`, taking `useMemo`'s function
  as run later or allowing getters each break it.
- Dual laws, under React 18 and Melact: a tree of pure components that read a context and pass a
  prop down, through random context changes, new props and keyed moves in one batch, shows every
  change and runs effects children first in the order of the page; a component with a state cell,
  a reducer, a context, two props, lets, a memo, a callback passed to a memo child and effects with
  and without dependencies shows, computes and runs what React does after any batch of changes to
  any of its sources; a pure component given new props in the same update as components that read the
  page writes only after they rendered, so they all see the page as it was; a root rendered inside a
  click runs its passive effects at the next microtask.
  The existing laws of rounds (all render before any writes, effects children first) hold.
- A Melact law counts renders and page walks: a context read by a tree of pure components three
  levels deep renders every reader once per change and walks the page once.
- Under `staged_pps` a component of `test/xmodule` that calls another module's custom hook is
  compiled with its graph, under `pps` it renders whole, and both show what React shows.
- Mutants, each caught: rendering pure children at once whatever the patch order, patching in place
  from the last row unmarked, dropping the ancestor check before effects, taking every render as
  pure, rendering a pure child at once while a component that reads the page waits, a fused pass
  without document order, no fused pass, deferring a root's passive effects; a
  kept value that ignores its mask, a context read without its bit, effects that never run again,
  a view whose mask reads nothing, hook slots numbered from 0, input bits shifted by one, a
  provider that drops its readers' bits, a patch that drops the changed input bits, a let whose
  bits are not passed on; a custom hook's slots counted one short, a fact of another version accepted.

Measured against main (`8526b22`) on a machine other sessions were benchmarking on too. The app
benchmark (4× CPU, 7 loads, Melact's script and task ms): collapse all 50.9 and 83.8 → 35.8 and
70.9, expand all 36.9 and 174.5 → 28.0 and 164.8, clear search 32.9 and 111.3 → 31.7 and 106.1; the
other operations stay within run-to-run noise. Of that, the scheduler's part (pure renders, fused
passes, the effect sort only when needed) is nearly all: measured alone on the earlier base it took
collapse all from 52.2 to 35.1 ms of script, and the masks then took it to 33.4. The corpus (eight
apps, 1×, three runs) moves from a geometric mean of 0.849 times React's time to 0.857, within its
noise; the steps where Melact was slowest improve: jsontree search typing 1.21 → 1.08 and collapse
all 1.17 → 1.09 (one round instead of one per level), logs live batches 1.14 → 0.66, appending
batches 1.12 → 0.90, pausing follow 1.47 → 1.08. Two steps measured worse: jsontree hover
0.34 → 0.51 and chat reply in thread 1.09 → 1.40 (reruns: 0.74 and 1.01 before, 1.05 and 1.16
after). js-framework-benchmark's rows are hookless and have no instance: 1.08 → 1.11 of vanilla, run
to run.

The masks save less than the scheduler work did: profiles of these apps spend little in hook calls
and guards, and much in ordering instances by the page and in rounds; skipping a context read, a
memo or an effect's dependencies is a few comparisons per instance.

## Controlled inputs

`value` and `checked` are properties the user changes too. A guard compares a value with the one
written last, so when typing changes the DOM but not the state (an update that rejects or
filters the text, or a field cleared to the `""` it already held), nothing would write it back.
These two props become controlled holes, as in React: after an `input` or `change` event on the
element, and after the redraw the event causes, the hole puts its last written value back if the
DOM differs. The guard stays; the check after input costs one property read. One law, run against
reason-react with React 18 and against Melact, types and clicks into a controlled field and
checkbox whose handlers keep or reject the input, and compares what the page shows.

`onChange` follows the element, as React's change plugin does. On a `select` it listens to
`change` and fires on every one. On an `input` or a `textarea` it listens to both `input` and
`change` and fires only when what the element shows, its value or checked state, differs from what
was recorded, as React's value tracker does: the handler and every controlled write record it. So
typing fires once per character, the `change` a blur sends after it fires nothing, a checkbox click
(click, input, change) fires once, and a lone `change`, as Testing Library's `fireEvent.change`
sends, reaches the handler. The compiler picks the event from the tag; `ReactDOM.createElement`
does the same at run time. A dual law sends random typing, lone changes, blurs, checkbox clicks and
select changes to a page with all four and compares the calls and what the page shows with React's;
listening to `input` alone, or not checking the recorded value, each break it.

After the handlers of an `input` or `change` event on a controlled field Melact renders at once,
before it puts the field's value back, as React does with `flushSync` there: a key handler in the
same task, Enter after typing, sees the typed value. A dual law types a random word and presses
Enter in one task; rendering at the next microtask breaks it. And when a layout effect sets state,
the passive effects of that commit run before the render it causes, as React 18 flushes them before
sync work, so a `useEffect` sees the page of its own commit: a popover hidden until its layout
effect measured it is seen hidden; running them after the whole flush breaks a dual law.

## Two copies on one page

Two separately built apps on one page (a Meltea widget on a Melact site, two versions of the
package in one bundle) each carry their own melhole and each listen on `document`. Every copy
keeps its handlers on elements under its own property name (`$$melhole`, then `$$melhole2`, …,
counted on `globalThis`), so a click reaches the handlers of the copy that rendered the element,
once. A law mounts the same Meltea widget from two builds beside each other and nested, presses
and types at random, and checks every count; sharing one name doubles the first press.

## Events and makeProps

A handler prop compiles to `fun event -> handler (React.Event.ofNative event)`: `ofNative` is the
identity, and its result is polymorphic, so the handler's own type (`React.Event.Mouse.t`,
`Keyboard.t`, …) picks the family and the compiler needs no table of them. Every accessor reads the
native event; React's own members map onto the native ones (`isDefaultPrevented` is
`defaultPrevented`, `isPropagationStopped` is `cancelBubble`, `persist` does nothing). Delegation
sets `currentTarget` to the element whose handler runs, as React does, and removes it afterwards.

A `[@react.component]` has reason-react's shape: `make : props -> React.element`, so `Foo.make` is a
`Foo.props React.component` that wrappers, `React.memo` and `React.createElement` take as they do in
reason-react, and `makeProps` takes the labels, an optional `key` and `()`. Here `props` is abstract
and unboxed: `makeProps` builds the element itself (the component's instance or pure view, with the
key), and `make` is `%identity`. JSX `<Foo label />` compiles to `Foo.make (Foo.makeProps ~label ())`,
which is one call with no props object at run time. A module written by hand in reason-react's style,
with a `[@mel.obj] external makeProps` and `let make = props => …props##label…`, goes through the same
call and gets its props object, as under React.

## DOM elements built at run time

Some reason-react code picks a tag at run time: `React.createElement (ReactDOM.stringToComponent
tag) (ReactDOM.domProps ~className ())`, `ReactDOM.createElement tag ~props children`,
`createDOMElementVariadic`, `ReactDOM.jsx`, `React.createElementVariadic`. No template can be made
for a tag the compiler does not know, so these elements are built by the runtime. `ReactDOM.domProps`
takes every DOM prop as an optional label with reason-react's types, generated at build time from the
same table `melact-ppx` uses (`Dom_props`), with an event's family (`Mouse`, `Form`, `UI`, …) taken
from its DOM event; it returns the props object, and `stringToComponent tag` is a
`domProps React.component` that `React.createElement` applies to it. The generated table also
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
- **Graph soundness:** a step of a component's update graph runs whenever a source in its mask changed,
  and a render that knows nothing of what changed runs every step.
- **Ratchet:** a change may keep or lower the work done, never raise it. `test/ratchet` patches
  jsdom's prototypes to count DOM writes by kind, created nodes and layouts (a layout read after a
  write is a forced one), steps of DOM walks (TreeWalker, `compareDocumentPosition`, `contains`),
  and the programs count renders, effects, hole evaluations, keys and row
  refreshes, all per step. Law A runs random component trees and the bench's event table under
  React 18 and under Melact: in no step may Melact do more of a compared kind; a kind where it does
  more today is a known gap with its reason, and its total excess may only shrink. Law B keeps the
  totals of fixed Melact, Meltea and melhole runs in `test/ratchet/baseline.json`, which
  `node test/ratchet/lower.mjs` rewrites only downwards. Splicing hookless components into child
  slots again, sending `View.rows` always through the general keyed path, dropping a loop's no-op
  for the same list, unguarding the first hole of every template, or ordering effects by walking
  the whole document each break a law. A counter new to the suite is recorded once with
  `--admit=<counter>`.

  What else is counted. Timers (`setTimeout`, `setInterval`, `requestIdleCallback`), animation
  frames, tasks (`setImmediate`, `MessagePort.postMessage`), microtasks (`queueMicrotask`) and
  promise reactions (`then`). Event listeners added and removed, on any target. The mutation records
  a `MutationObserver` sees on the document: another law checks that every record comes from a write
  the counters saw, so a write path the counters miss shows up. After the unmount, and a full garbage
  collection, what the run left behind: nodes it made that are out of the document and still
  reachable, listeners it added on targets still alive, timers and frame requests still pending, and
  properties it added to `window` or `document`. Selector matching (`querySelector`, `matches`,
  `closest`) is the browser's work and does not count as walking.

  The whole corpus runs. `test/ratchet/classics/driver.mjs` mounts each app of `bench/classics` and
  each repro in jsdom, in its React 18 (production) and its Melact build, and drives it through its
  own `scenario.mjs`, as `bench/classics/run.mjs` does in Chromium. Time is virtual: every timeout,
  interval, frame and `setImmediate` waits in one queue that the driver runs in order, so a run counts
  the same each time; a frame boundary is a paint. jsdom gets cheap stand-ins: `ResizeObserver` and
  `IntersectionObserver` report once (never intersecting), `scrollIntoView` and `scrollTo` do
  nothing, layout values are fixed (an element is 1000 by 20, a scroll box 600 high) and scroll
  positions are kept. A step that needs real geometry is skipped, with its reason, in the part file
  that lists the app (feed's steps on posts its infinite scroll loads, virtuallist's pick of visible
  rows). The apps are split into parts that run in parallel; the slowest parts run only with
  `RATCHET_SLOW` set, as CI and `lower.mjs` set it.

  A small change on a big page costs the same as on a small one. `test/ratchet/bigpage` is a page
  of rows of twelve elements each, more than 20,000 elements at 2,000 rows, with a debounced search
  field, rows that read `offsetTop`, forty rows marked from a context and a popover. Every step after
  the mount must count exactly the same at 2,000 rows as at 200, under React and under Melact; the
  constant allowed is zero. A walk of the whole page fails it. `Big_page.keystroke build rows` gives
  the counters of one keystroke on a page of that many rows.

  Server output. `test/ratchet/served` renders `bench/ssr`'s page with Melact's server at 10, 100 and
  1,000 rows: its HTML may have no more bytes than React's `renderToString` (Law A) or than last time
  (Law B, as `bytes served`). The page is then hydrated by Melact and, from React's own HTML, by
  React; after the hydration Law A holds per step, and the hydration's own excess over React's is
  recorded and may only shrink.

  Bundle size. `node test/ratchet/sizes.mjs` bundles every production build of Melact and Meltea
  code (bench/melact, bench/meltea, the hydrating clients of bench/ssr, each app of bench/classics,
  the examples) with esbuild and compares their gzip -9 sizes with `test/ratchet/sizes.json`; the
  law test fails when one grows. `--lower` records what shrank. Growth is recorded only with
  `--allow-growth=<reason>`, which the user approves and which keeps the reason in the file; a new
  bundle needs `--admit=<bundle>`.

  Each of these laws has caught a mutant: ordering effects by walking from the document root to its
  end (the big page, and Law B on nodes walked), a timeout per render (Law B on timers), skipping
  effect cleanups at unmount (listeners and nodes kept), a list of every cloned template (nodes
  kept), 2.5 kB more in the runtime (the size ratchet), a second space before each attribute the
  server writes (bytes served), and the counters forgetting `setAttribute` (the mutation record
  check). Time is virtual in every ratchet test, the ones driven by `act` too, so a timer never fires
  because the machine was slow.
