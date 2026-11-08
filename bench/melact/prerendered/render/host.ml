let word words = words.(Random.int (Array.length words))
let dropped ~unwanted items = Array.of_list (List.filter (fun item -> not (unwanted item)) (Array.to_list items))
