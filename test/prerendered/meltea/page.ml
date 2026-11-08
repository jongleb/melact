include Shipped_page

let views = ref 0

let view model =
  incr views;
  Shipped_page.view model
