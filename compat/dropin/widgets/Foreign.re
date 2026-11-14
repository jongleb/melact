module List = {
  [@react.component] [@mel.module "react-window"]
  external make:
    (~height: int, ~width: int, ~itemCount: int, ~itemSize: int, ~children: React.element) =>
    React.element =
    "FixedSizeList";
};
