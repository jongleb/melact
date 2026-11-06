"""Prints module ReactDOM.Style for melact from reason-react's style properties.

python3 react/style.py path/to/reason-react/src/ReactDOM.rei
prints the signature, a line with ----, then the implementation of module Style.
"""

import re
import sys

source = open(sys.argv[1]).read()
block = source[source.index("module Style: {"):source.index("external combine")]
names = list(dict.fromkeys(re.findall(r"~(\w+): string=\?", block)))

signature = ["module Style : sig",
             "  (** Inline style declarations: a JavaScript object of camelCase properties, as reason-react's. *)",
             "  type t",
             "",
             "  external make :"]
signature += [f"    ?{name}:string ->" for name in names]
signature += ["    unit ->", "    t = \"\"", "  [@@mel.obj]", "",
              "  external combine : (_[@mel.as {json|{}|json}]) -> t -> t -> t = \"assign\" [@@mel.scope \"Object\"]",
              "  val unsafeAddProp : t -> string -> string -> t",
              "  val declarations : t -> (string * string) list",
              "end"]

implementation = ["module Style = struct",
                  "  type t", "",
                  "  external make :"]
implementation += [f"    ?{name}:string ->" for name in names]
implementation += ["    unit ->", "    t = \"\"", "  [@@mel.obj]", "",
                   "  external combine : (_[@mel.as {json|{}|json}]) -> t -> t -> t = \"assign\" [@@mel.scope \"Object\"]",
                   "  external set : t -> string -> string -> unit = \"\" [@@mel.set_index]",
                   "  external get : t -> string -> string = \"\" [@@mel.get_index]",
                   "  external names : t -> string array = \"keys\" [@@mel.scope \"Object\"]",
                   "",
                   "  let unsafeAddProp style name value =",
                   "    let added = combine style (make ()) in",
                   "    set added name value;",
                   "    added",
                   "",
                   "  let declarations style = Array.to_list (Array.map (fun name -> (name, get style name)) (names style))",
                   "end"]

print("\n".join(signature))
print("----")
print("\n".join(implementation))
