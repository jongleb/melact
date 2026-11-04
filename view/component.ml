type 'props t = {
  name : string;
  witness : 'props Type.Id.t;
  unchanged : 'props -> 'props -> bool;
}

let make ~name ~unchanged = { name; witness = Type.Id.make (); unchanged }
