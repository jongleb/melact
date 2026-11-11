module Modal = {
  [@react.component]
  let make = (~onClose: unit => unit, ~children) => <div onClick={_ => onClose()}> children </div>;
};

module Button = {
  [@react.component]
  let make = (~onClick: React.Event.Mouse.t => unit) => <button onClick> {React.string("x")} </button>;
};

module Effected = {
  [@react.component]
  let make = (~busy: bool) => {
    let (closed, setClosed) = React.useState(() => 0);
    let close = _ => busy ? () : setClosed(closed => closed + 1);
    React.useEffect1(() => None, [|busy|]);
    <Modal onClose=close> <Button onClick=close /> {React.int(closed)} </Modal>;
  };
};

module Passed = {
  [@react.component]
  let make = (~busy: bool, ~onClose) => {
    let close = _ => busy ? () : onClose();
    React.useEffect1(() => None, [|busy|]);
    <Modal onClose=close> <Button onClick=close /> </Modal>;
  };
};

module Stated = {
  [@react.component]
  let make = (~busy: bool) => {
    let (closed, setClosed) = React.useState(() => 0);
    let close = _ => busy ? () : setClosed(closed => closed + 1);
    <Modal onClose=close> <Button onClick=close /> {React.int(closed)} </Modal>;
  };
};

module Clicked = {
  [@react.component]
  let make = (~onClick: React.Event.Mouse.t => unit) => <button onClick> {React.string("c")} </button>;
};

module Keyed = {
  [@react.component]
  let make = (~onKeyDown: React.Event.Keyboard.t => unit) => <input onKeyDown />;
};

module Read = {
  [@react.component]
  let make = (~busy: bool, ~onClose) => {
    let close = e => {
      ignore(e);
      busy ? () : onClose();
    };
    React.useEffect1(() => None, [|busy|]);
    <Modal onClose=close> <Button onClick=close /> </Modal>;
  };
};

module Stopped = {
  [@react.component]
  let make = (~busy: bool, ~onClose) => {
    let stop = e => {
      React.Event.Synthetic.stopPropagation(e);
      busy ? () : onClose();
    };
    React.useEffect1(() => None, [|busy|]);
    <div> <Clicked onClick=stop /> <Keyed onKeyDown=stop /> </div>;
  };
};

module Closed = {
  [@react.component]
  let make = (~busy: bool, ~onClose) => {
    let ignored = _ => ();
    React.useEffect1(() => None, [|busy|]);
    <Modal onClose=ignored> <Button onClick=ignored /> <Clicked onClick={_ => onClose()} /> </Modal>;
  };
};

module Rows = {
  [@react.component]
  let make = (~items: array(string), ~busy: bool) => {
    let row = item => <li key=item> {React.string(busy ? "" : item)} </li>;
    React.useEffect1(() => None, [|busy|]);
    <ul> {React.array(Array.map(row, items))} {row("last")} </ul>;
  };
};
