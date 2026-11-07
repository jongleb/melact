type rendering = Pure | Impure
type t = { name : string; rendering : rendering }

let make ~name = { name; rendering = Impure }
let pure ~name = { name; rendering = Pure }
