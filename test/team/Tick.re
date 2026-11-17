[@react.component]
let default = (~x: float, ~y: float, ~payload: {. "value": string}, ~suffix=?) =>
  <text className="tick" x={Js.Float.toString(x)} y={Js.Float.toString(y)}>
    {React.string(payload##value ++ Option.value(suffix, ~default=""))}
  </text>;

[@react.component]
let doubled = (~x: float, ~y: float, ~payload: {. "value": string}, ~suffix=?) =>
  <text className="tick doubled" x={Js.Float.toString(x *. 2.)} y={Js.Float.toString(y *. 2.)}>
    {React.string(payload##value ++ payload##value ++ Option.value(suffix, ~default=""))}
  </text>;
