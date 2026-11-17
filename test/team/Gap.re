/* A component whose labels take a variant and a record declared here, given in a caller that does not open this
   module: the constructors and fields are found by the label's type. */
type size =
  | NonAdaptive(int)
  | Adaptive(int, int);

type pad = {top: int};

[@react.component]
let make = (~gap: size=NonAdaptive(0), ~pad: pad, ~tone: option(string)=?, ~note: option(option(string))=?) =>
  <span className="gap">
    {React.string(
       (
         switch (gap) {
         | NonAdaptive(n) => string_of_int(n)
         | Adaptive(a, b) => string_of_int(a) ++ "/" ++ string_of_int(b)
         }
       )
       ++ ":"
       ++ string_of_int(pad.top)
       ++ Option.value(~default="", tone)
       ++ (
         switch (note) {
         | Some(Some(text)) => text
         | Some(None) => "!"
         | None => ""
         }
       ),
     )}
  </span>;

/* Clones its child with a variant label and an optional label the child did not set. */
module Wide = {
  [@react.component]
  let make = (~children) => React.cloneElement(children, {"gap": Adaptive(7, 8), "tone": "w"});
};

/* Clones its child with undefined for an optional label the child set: React reads it as None. */
module Clear = {
  [@react.component]
  let make = (~children) => React.cloneElement(children, {"tone": Js.Undefined.empty, "note": Js.Undefined.empty, "count": 1});
};
