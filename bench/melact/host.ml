let word words = words.(Js.Math.random_int 0 (Array.length words))
let dropped ~unwanted items = Js.Array.filter ~f:(fun item -> not (unwanted item)) items
