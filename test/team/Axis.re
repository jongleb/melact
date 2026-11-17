// Stands in for recharts' tick prop: the library calls the function it is given with a props object of its own.
let drawTick: ('tickProps => React.element) => React.element = [%mel.raw
  {|function (tick) { return tick({x: 3, y: 4, payload: {value: "p"}, index: 0, visibleTicksCount: 2}) }|}
];

let drawSuffixed: ('tickProps => React.element) => React.element = [%mel.raw
  {|function (tick) { return tick({x: 5, y: 6, payload: {value: "q"}, suffix: "%"}) }|}
];

[@react.component]
let local = (~x: float, ~y: float, ~payload: {. "value": string}, ~suffix=?) =>
  <text className="tick local" x={Js.Float.toString(x +. y)}>
    {React.string(payload##value ++ Option.value(suffix, ~default=""))}
  </text>;

[@react.component]
let make = (~double) => {
  let pick = double ? Tick.doubled : Tick.default;
  let picked = double ? local : Tick.default;
  let ticks = [|Tick.default, Tick.doubled, local|];
  <svg className="axis">
    {drawTick(pick)}
    {drawSuffixed(pick)}
    {drawTick(Tick.default)}
    {drawSuffixed(picked)}
    {drawTick(local)}
    {React.array(Array.mapi((index, each) => <g key={string_of_int(index)}> {drawTick(each)} </g>, ticks))}
    {React.createElement(Tick.doubled, Tick.doubledProps(~x=1., ~y=2., ~payload={"value": "c"}, ()))}
    <Tick.default x=7. y=8. payload={"value": "j"} suffix="!" />
  </svg>;
};
