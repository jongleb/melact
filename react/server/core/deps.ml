type change = Same | Changed

let of_same same = match same with true -> Same | false -> Changed
let always () () = Changed
let never () () = Same
let array a b = of_same (Array.length a = Array.length b && Array.for_all2 (fun x y -> x == y) a b)
let two (a, b) (a', b') = of_same (a == a' && b == b')
let three (a, b, c) (a', b', c') = of_same (a == a' && b == b' && c == c')
let four (a, b, c, d) (a', b', c', d') = of_same (a == a' && b == b' && c == c' && d == d')
let five (a, b, c, d, e) (a', b', c', d', e') = of_same (a == a' && b == b' && c == c' && d == d' && e == e')

let six (a, b, c, d, e, f) (a', b', c', d', e', f') =
  of_same (a == a' && b == b' && c == c' && d == d' && e == e' && f == f')

let seven (a, b, c, d, e, f, g) (a', b', c', d', e', f', g') =
  of_same (a == a' && b == b' && c == c' && d == d' && e == e' && f == f' && g == g')
