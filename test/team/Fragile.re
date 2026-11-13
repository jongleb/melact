/* Built with warning 4 (fragile match) as an error, as the team builds: no code Melact writes for a
   dynamic attribute may trip it. */

[@react.component]
let make = (~cls: string, ~title: string) =>
  <div className=cls title> {React.string("x")} </div>;
