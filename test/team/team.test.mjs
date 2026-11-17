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
// object through React.createElement (ClientLinks). Melact must build them and
// show what reason-react on React 18 shows, click after click.
import * as Reason from "../../_build/default/test/team/react/output/test/team/react/Main.mjs";
import * as Melact from "../../_build/default/test/team/melact/output/test/team/melact/Main.mjs";
import { readFileSync } from "node:fs";
import { tick, shown } from "../compat/harness.mjs";

const settle = async () => {
  for (let round = 0; round < 4; round++) await tick();
};

test("constructors found by annotations and memoized components declared in .rei render as under React 18", async () => {
  const traces = [];
  for (const build of [Reason, Melact]) {
    const root = document.body.appendChild(document.createElement("div"));
    const layer = document.body.appendChild(document.createElement("div"));
    build.mount(root);
    await settle();
    const trace = [shown({ root, layer }).root];
    for (const selector of [".notify", ".double", ".gadt", ".gadt-whole", ".client-badge", "button", ".say", ".remote", "button", ".tone", ".pattern", ".say", ".tone", ".remote", ".shared", ".pattern", ".tone", ".remote", ".say", ".shared"]) {
      root.querySelectorAll(selector)[0].click();
      await settle();
      trace.push(shown({ root, layer }).root);
    }
    traces.push(trace);
    root.remove();
    layer.remove();
  }
  expect(traces[1]).toEqual(traces[0]);
  expect(traces[0][traces[0].length - 1]).toContain("hi!!!");
  expect(traces[0][0]).toContain('href="/legal/usat"');
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
    '<button class="gadt">"16"</><div class="clients"><a class="client-link" href="/rsc/a">"A"</><a class="client-link" href="/rsc/b">"/rsc/b"</><button class="client-badge">"41"</><h3 class="client-title">"CLIENTS"</></><button class="gadt-whole">"13"</>',
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
