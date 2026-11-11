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
