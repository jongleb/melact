module Collections = {
  module Array = {
    include Stdlib.Array;
    include Belt.Array;
    let mapi = (a, f) => Js.Array.mapi(~f, a);
  };
  module List = {
    include Stdlib.List;
    include Belt.List;
  };
};

let days = [|1, 2|];

module Only = {
  open Collections;
  [@react.component]
  let make = () => <tr> {days->Array.map(day => <td key={string_of_int(day)}> {React.int(day)} </td>)->React.array} </tr>;
};

open Collections;

let weeks = [|[|3, 4|], [|5, 6|]|];

[@react.component]
let make = () => {
  let cell = day => <td key={string_of_int(day)}> {React.int(day)} </td>;
  <table>
    <tbody>
      <Only />
      <tr> {days->Array.map(day => <td key={string_of_int(day)}> {React.int(day)} </td>)->React.array} </tr>
      <tr> {React.array(Array.map(days, day => <td key={string_of_int(day)}> {React.int(day * 10)} </td>))} </tr>
      <tr> {days->Array.map(cell)->React.array} </tr>
      <tr>
        {days
         ->Array.mapi((day, index) => <td key={string_of_int(day)}> {React.int(day * 100 + index)} </td>)
         ->React.array}
      </tr>
      <tr> {React.list(List.map([7, 8], day => <td key={string_of_int(day)}> {React.int(day)} </td>))} </tr>
      <tr> {React.array(Stdlib.Array.map(day => <td key={string_of_int(day)}> {React.int(day)} </td>, days))} </tr>
      {weeks
       ->Array.map(week =>
           <tr key={week->Array.reduce(0, (+))->string_of_int}>
             {week->Array.map(day => <td key={string_of_int(day)}> {React.int(day)} </td>)->React.array}
           </tr>
         )
       ->React.array}
    </tbody>
  </table>;
};
