// Repros the team reported, in Reason: a constructor found by the type annotation of a let in a component with
// hooks (under -typed), record fields found by the annotation of a let's pattern there, and a component whose
// .rei declares [@react.component] make while the .re rebinds make with React.memo, and top-level JSX inside a local
// open of a module that has top-level JSX of its own (TosUsat opens TosT), and a component calling a data hook that
// takes React.useMemo1 as a parameter and reads a bool named useLayoutEffect (UseRemoteData), whose fact makes the
// component pure, and types -typed must classify without unfolding them: 32 levels that each hold the one below
// twice (Shared), a polymorphic variant and a Js.t object that hold themselves (Looping), and one attribute that reads 30 props,
// whose guard must compile in linear time (Wide), and closures a data hook calls only in its effect that call a
// getter with () (RemoteRequest), components without props (Bare), a field read with ## named as a local (Tooltip), and components passed as values to a
// JavaScript function that calls them with a props object of its own, switched between components with the same labels (Axis), local functions annotated
// type a. in a component with hooks (LocalGadt), and server-reason-react's make_client, which gives a component a props
// object through React.createElement (ClientLinks),
// components that preset another's makeProps two levels deep (Preset), and a module named by -hook-modules that binds
// npm's useEffect6 itself (Shadow, called from Shadowed), and routes split by a binding to npm's React.lazy over Js.import of each
// route's make, rendered by createElement with makeProps or a props object and by JSX, under one Suspense (Routes), and props React
// does not know on an element built at run time from a props object, given and taken away (Spread), and React.cloneElement of
// elements given as JSX: a tooltip merging handlers into a DOM element (Hint), through a component that forwards its children
// (HintCard), a menu injecting labels its items did not set through Children.mapWithIndex (Menu), and a label other than
// children through Children.only, Children.toArray and Array.mapi, given literals in both branches of a conditional (Tabs). Melact must build them and
// show what reason-react on React 18 shows, click after click.
import * as Reason from "../../_build/default/test/team/react/output/test/team/react/Main.mjs";
import * as Melact from "../../_build/default/test/team/melact/output/test/team/melact/Main.mjs";
import { readFileSync } from "node:fs";
import { tick, shown } from "../compat/harness.mjs";

const settle = async (root) => {
  for (let round = 0; round < 4 || (root.querySelector(".route-loading") && round < 2000); round++) await tick();
};

test("constructors found by annotations and memoized components declared in .rei render as under React 18", async () => {
  const traces = [];
  for (const build of [Reason, Melact]) {
    const root = document.body.appendChild(document.createElement("div"));
    const layer = document.body.appendChild(document.createElement("div"));
    build.mount(root);
    await settle(root);
    const trace = [shown({ root, layer }).root];
    for (const selector of [".tabs-next", ".tabs-next", '[title="tip"]', '[title="card"]', '[title="tip"]', ".menu-item", ".menu-item", ".spread-toggle", ".spread-toggle", ".spread-toggle", ".route-count", ".route-title", ".route-count", ".route-switch", ".route-settings", ".route-title", ".route-switch", ".route-count", ".notify", ".double", ".gadt", ".gadt-whole", ".client-badge", ".shadowed", "button", ".say", ".remote", "button", ".tone", ".pattern", ".say", ".tone", ".remote", ".shared", ".pattern", ".tone", ".remote", ".say", ".shared"]) {
      root.querySelectorAll(selector)[0].click();
      await settle(root);
      trace.push(shown({ root, layer }).root);
    }
    traces.push(trace);
    root.remove();
    layer.remove();
  }
  expect(traces[1]).toEqual(traces[0]);
  expect(traces[0][traces[0].length - 1]).toContain("hi!!!");
  expect(traces[0][0]).toContain('href="/legal/usat"');
  expect(traces[0][1]).toContain('<div class="tabs"><button class="tabs-next">"next"</><span class="tab">"tab0"</><span class="tab active">"tab1"</></>');
  expect(traces[0][3]).toContain('<span class="hint"><button class="trigger open" title="tip">"hint"</><span class="hint-label">"tip"</></>');
  expect(traces[0][4]).toContain('<div class="hint-card"><span class="hint"><button class="trigger open" title="card">"card"</><span class="hint-label">"card"</>');
  expect(traces[0][6]).toContain('<button class="menu-item">"first"</><button class="menu-item focused">"second"</><button class="menu-item">"third"</><span class="menu-picked">"first"</>');
  expect([traces[0][7], traces[0][8]].map((trace) => trace.match(/<span[^>]*>"spread"/)[0])).toEqual([
    '<span aria-expanded="false" aria-label="L" count="3" custom="c" data-flag="true" data-n="0" data-state="closed" id="spread-a">"spread"',
    '<span aria-controls="menu" aria-expanded="true" custom="d" data-flag="false" data-state="open" id="spread-b" nothing="now">"spread"',
  ]);
  expect(traces[0][13]).toContain(
    '<section class="route-dashboard"><h2>"Board!"</><button class="route-count">"2"</></><section class="route-dashboard"><h2>"Board! raw?"</>',
  );
  expect(traces[0][18]).toContain('<h2>"Board!! jsx?"</><button class="route-count">"0"</>');
  expect(traces[0][0]).toContain('<div class="bare">"bare"</><span class="bare-inner"></>');
  expect(traces[0][0]).toContain('<span class="bare-inner"></>"4"');
  expect(traces[0][traces[0].length - 1]).toContain(
    '<div class="interpolated" id="$hi!!!!!" title="url(\\"#hi!!!!!\\")">"#hi!!!!!""[#hi!!!!! and hi!!!!!]"</><div class="rows"><span>"v1"</><span>"hi!!!!!"</><i>"hi!!!!!v1"</><i>"n2hi!!!!!"</></><button class="notify">"4"</>',
  );
  expect(traces[0][traces[0].length - 1]).toContain(`"data hi!!!!!"" shown"`);
  expect(traces[0][0]).toContain(
    '<svg class="axis"><text class="tick" x="3" y="4">"p"</><text class="tick" x="5" y="6">"q%"</><text class="tick" x="3" y="4">"p"</><text class="tick" x="5" y="6">"q%"</><text class="tick local" x="7">"p"</>',
  );
  expect(traces[0][traces[0].length - 1]).toContain(
    '<button class="gadt">"16"</><div class="clients"><a class="client-link" href="/rsc/a">"A"</><a class="client-link" href="/rsc/b">"/rsc/b"</><button class="client-badge">"41"</><h3 class="client-title">"CLIENTS"</></><section class="preset"><div class="current simple">"a"</><div class="current list-item">"b"</><span class="current list-item">"js"</><span class="current list-item">"js"</><span class="current list-item">"js"</><span class="current list-item">"jsx"</></><button class="shadowed">"23"</><button class="gadt-whole">"13"</>',
  );
  expect(traces[0][traces[0].length - 1]).toContain(
    '<svg class="axis"><text class="tick doubled" x="6" y="8">"pp"</><text class="tick doubled" x="10" y="12">"qq%"</><text class="tick" x="3" y="4">"p"</><text class="tick local" x="11">"q%"</>',
  );
});

test("a closure a data hook calls only in its effect leaves the component pure, as one it calls while rendering does not", () => {
  const compiled = readFileSync("_build/default/test/team/melact/output/test/team/melact/RemoteRequest.mjs", "utf8");
  const kind = (name) => compiled.match(new RegExp(`Component\\.(pure|make)\\("RemoteRequest\\.${name}\\.make"`))?.[1];
  expect([kind("ViaUse1"), kind("ViaUse"), kind("CalledNow")]).toEqual(["pure", "pure", "make"]);
});

test("hooks named as plain functions get facts across files under -typed: Chained is pure, Modal reads the page through Previous.whenChanged's ref", () => {
  const kind = (file, name) =>
    readFileSync(`_build/default/test/team/melact/output/test/team/melact/${file}.mjs`, "utf8").match(
      new RegExp(`Component\\.(pure|make)\\("${name}"`),
    )?.[1];
  expect([kind("Modal", "Modal.make"), kind("Chained", "Chained.make")]).toEqual(["make", "pure"]);
});
