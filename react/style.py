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
             "  (** Inline style declarations, in the order they are applied. *)",
             "  type t = Declarations of (string * string) list [@@unboxed]",
             "",
             "  val make :"]
signature += [f"    ?{name}:string ->" for name in names]
signature += ["    unit ->", "    t", "",
              "  val combine : t -> t -> t",
              "  val unsafeAddProp : t -> string -> string -> t",
              "  val declarations : t -> (string * string) list",
              "end"]

implementation = ["module Style = struct",
                  "  type t = Declarations of (string * string) list [@@unboxed]", "",
                  "  let make " + " ".join(f"?{name}" for name in names) + " () ="]
implementation += ["    let declared name (value : string option) declarations =",
                   "      match value with Some value -> (name, value) :: declarations | None -> declarations",
                   "    in",
                   "    Declarations"]
implementation += [f'      (declared "{names[0]}" {names[0]}']
implementation += [f'      @@ declared "{name}" {name}' for name in names[1:]]
implementation += ["      @@ [])", "",
                   "  let combine (Declarations first) (Declarations second) = Declarations (first @ second)",
                   "",
                   "  let unsafeAddProp (Declarations declarations) name value =",
                   "    Declarations (declarations @ [ (name, value) ])",
                   "",
                   "  let declarations (Declarations declarations) = declarations",
                   "end"]

print("\n".join(signature))
print("----")
print("\n".join(implementation))
