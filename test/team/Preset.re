// Components that preset another's props by partial application of its makeProps, two levels deep, as the team's
// design system does; one of them is also passed as a value to a JavaScript function.
type color =
  | Current
  | Previous;
type kind =
  | Simple
  | ListItem;

module Base = {
  [@react.component]
  let make = (~color: color, ~kind: kind=Simple, ~children: React.element) =>
    <div
      className={
        (
          switch (color) {
          | Current => "current"
          | Previous => "previous"
          }
        )
        ++ (
          switch (kind) {
          | Simple => " simple"
          | ListItem => " list-item"
          }
        )
      }>
      children
    </div>;
};

module Current = {
  let make = Base.make;
  let makeProps = Base.makeProps(~color=Current);
};

module CurrentListItem = {
  let make = Current.make;
  let makeProps = Current.makeProps(~kind=ListItem);
};

module Tag = {
  [@react.component]
  let make = (~color: color, ~kind: kind=Simple, ~label: string) =>
    <span className={(color == Current ? "current" : "previous") ++ (kind == ListItem ? " list-item" : " simple")}>
      {React.string(label)}
    </span>;
};

module CurrentTag = {
  let make = Tag.make;
  let makeProps = Tag.makeProps(~color=Current);
};

module CurrentListTag = {
  let make = CurrentTag.make;
  let makeProps = CurrentTag.makeProps(~kind=ListItem);
};

let drawn: ('props => React.element) => React.element = [%mel.raw
  {|function (component) { return component({color: 0, kind: 1, label: "js"}) }|}
];

[@react.component]
let make = () =>
  <section className="preset">
    <Current> {React.string("a")} </Current>
    <CurrentListItem> {React.string("b")} </CurrentListItem>
    {drawn(Tag.make)}
    {drawn(CurrentTag.make)}
    {drawn(CurrentListTag.make)}
    <CurrentListTag label="jsx" />
  </section>;
