type 'value t = { mutable value : 'value }

let make value = { value }
let read context = context.value

let provide context value child =
  Melhole_server.element (fun writer ->
      let around = context.value in
      context.value <- value;
      match Melhole_server.write writer child with
      | () -> context.value <- around
      | exception error ->
          context.value <- around;
          raise error)
