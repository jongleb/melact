type t0 = int;
type t1 = (t0, t0);
type t2 = [ | `A(t1) | `B(t1)];
type t3 = {. "f0": t2, "f1": t2};
type twice('a) = ('a, 'a);
type t4 = twice(t3);
type t5 = (t4, t4);
type t6 = [ | `A(t5) | `B(t5)];
type t7 = {. "f0": t6, "f1": t6};
type t8 = twice(t7);
type t9 = (t8, t8);
type t10 = [ | `A(t9) | `B(t9)];
type t11 = {. "f0": t10, "f1": t10};
type t12 = twice(t11);
type t13 = (t12, t12);
type t14 = [ | `A(t13) | `B(t13)];
type t15 = {. "f0": t14, "f1": t14};
type t16 = twice(t15);
type t17 = (t16, t16);
type t18 = [ | `A(t17) | `B(t17)];
type t19 = {. "f0": t18, "f1": t18};
type t20 = twice(t19);
type t21 = (t20, t20);
type t22 = [ | `A(t21) | `B(t21)];
type t23 = {. "f0": t22, "f1": t22};
type t24 = twice(t23);
type t25 = (t24, t24);
type t26 = [ | `A(t25) | `B(t25)];
type t27 = {. "f0": t26, "f1": t26};
type t28 = twice(t27);
type t29 = (t28, t28);
type t30 = [ | `A(t29) | `B(t29)];
type t31 = {. "f0": t30, "f1": t30};
type t32 = twice(t31);

[@react.component]
let make = (~flag: bool, ~seed: t32) => {
  let (hovered, setHovered) = React.useState(() => false);
  let shown = flag ? seed : seed;
  <div className="shared" onMouseEnter={_ => setHovered(_ => true)} onClick={_ => setHovered(hovered => !hovered)}>
    {React.string(hovered ? "a" : "b")}
    <span> {React.string(Obj.magic(shown))} </span>
  </div>;
};
