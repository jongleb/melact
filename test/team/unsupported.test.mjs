// Every function of Melact's reason-react API that raises at run time because Melact cannot do it
// ("… is not supported") carries [@@alert unsupported] in its interface, so a build lists every call
// site at once instead of one page load at a time.
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const sources = (directory) =>
  readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return sources(path);
    return /\.ml(\.in)?$/.test(entry.name) ? [path] : [];
  });

const raising = sources("react").flatMap((path) =>
  [...readFileSync(path, "utf8").matchAll(/let (\w+)[^=\n]*=\s*(?:Js\.Exn\.raiseError|failwith)\s*"melact: [^"]*not supported/g)].map((found) => ({
    path,
    name: found[1],
  })),
);

test("every function that raises 'not supported' at run time is marked [@@alert unsupported] in its interface", () => {
  expect(raising.length).toBeGreaterThanOrEqual(4);
  const unmarked = raising.filter(({ path, name }) => {
    const interfacePath = path.replace(/\.ml(\.in)?$/, (_, generated) => `.mli${generated ?? ""}`);
    if (!existsSync(interfacePath)) return true;
    const declared = readFileSync(interfacePath, "utf8").match(new RegExp(`val ${name} :[^\\n]*(?:\\n(?!val )[^\\n]*)*`));
    return !declared || !declared[0].includes("[@@alert unsupported");
  });
  expect(unmarked).toEqual([]);
});
