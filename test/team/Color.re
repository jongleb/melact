type t =
  | Selected
  | Default;

let name = (color: t) =>
  switch (color) {
  | Selected => "selected"
  | Default => "default"
  };
