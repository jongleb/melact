[@react.component]
let make = (~id) => {
  let path = "#" ++ id;
  let both = {j|$path and $(id)|j};
  <div className="interpolated" title={j|url("$path")|j} id={j|\$$id|j}>
    {React.string(path)}
    {React.string({j|[$both]|j})}
  </div>;
};
