type tone = [ | `Plain | `Named(string) | `Mixed(tone, tone)];
type node = {
  .
  "label": string,
  "next": Js.Nullable.t(node),
};

let rec depth = (tone: tone) =>
  switch (tone) {
  | `Plain => 0
  | `Named(_) => 1
  | `Mixed(left, right) => 1 + max(depth(left), depth(right))
  };

module Tone = {
  [@react.component]
  let make = (~tone: tone, ~label: string) => <i> {React.string(label ++ string_of_int(depth(tone)))} </i>;
};

module Head = {
  [@react.component]
  let make = (~node: node) => <b> {React.string(node##label)} </b>;
};

[@react.component]
let make = (~start: node) => {
  let (tone, setTone) = React.useState(() => (`Plain: tone));
  let (shade, label) =
    switch (tone) {
    | `Plain => (`Named("plain"): tone, start##label)
    | `Named(name) => (`Mixed(tone, `Plain), name)
    | `Mixed(_, _) => (`Plain, "mixed")
    };
  let current = tone == `Plain ? shade : tone;
  let head = tone == `Plain ? start : start;
  <button className="tone" onClick={_ => setTone(_ => shade)}> <Tone tone=current label /> <Head node=head /> </button>;
};
