/* Props React does not know, given to an element built at run time from a props object, as floating-ui's
   getReferenceProps or reason-react's Spread give them: data-* and aria-* (booleans kept as text), custom
   names (booleans, functions, null and on* names dropped), and the ones a later render no longer gives. */
let closed: ReactDOM.domProps = [%mel.raw
  {|{"data-state": "closed", "aria-expanded": false, "data-flag": true, "custom": "c", "custombool": true, "count": 3, "onFoo": "x", "fn": function () {}, "nothing": null, "id": "spread-a", "aria-label": "L", "data-n": 0}|}
];
let opened: ReactDOM.domProps = [%mel.raw
  {|{"data-state": "open", "aria-expanded": true, "data-flag": false, "custom": "d", "custombool": false, "id": "spread-b", "aria-controls": "menu", "nothing": "now"}|}
];

[@react.component]
let make = () => {
  let (on, setOn) = React.useState(() => false);
  <div className="spread">
    <button className="spread-toggle" onClick={_ => setOn(o => !o)}> {React.string("toggle")} </button>
    {ReactDOM.createElement("span", ~props=on ? opened : closed, [|React.string("spread")|])}
  </div>;
};
