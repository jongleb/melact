import { real } from "./libraries.mjs";
import { shim } from "./env/libraries.mjs";
import { stage, shown } from "./harness.mjs";

const app = (lib, log) => {
  const h = lib.React.createElement;
  const options = [
    { value: "a", label: "Apple" },
    { value: "b", label: "Banana" },
  ];
  function Counter() {
    const [n, setN] = lib.React.useState(0);
    lib.React.useEffect(() => { log.push("effect " + n); }, [n]);
    return h("button", { className: "count", onClick: () => setN(n + 1) }, "n=", n);
  }
  return h("div", { className: "app" }, h(Counter), h(lib.Select, { options, onChange: (o) => log.push("change " + o.value) }));
};

test("a counter and a react-select render alike", async () => {
  const sides = [stage(real), stage(shim)];
  for (const side of sides) await side.render(app(side.lib, side.log));
  const [a, b] = sides.map(shown);
  console.log(b.root.slice(0, 1500)); expect(b.root).toEqual(a.root);
  for (const side of sides) await side.settle(() => side.root.querySelector(".count").click());
  expect(shown(sides[1]).root).toEqual(shown(sides[0]).root);
  expect(sides[1].log).toEqual(sides[0].log);
  for (const side of sides) await side.unmount();
});
