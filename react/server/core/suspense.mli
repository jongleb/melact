(** A Suspense boundary as React's [renderToString] writes it: [<!--$-->], the children and
    [<!--/$-->]; when a child throws or suspends, what they wrote is taken back and the boundary is
    left for the client: [<!--$!--><template></template>], the fallback and [<!--/$-->]. *)
val boundary : fallback:Melhole_server.child -> Melhole_server.child -> Melhole_server.child
