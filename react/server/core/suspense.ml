let boundary ~fallback child =
  Melhole_server.recover
    (Melhole_server.element (fun writer ->
         Melhole_server.hydration_markup writer "<!--$-->";
         Melhole_server.write writer child;
         Melhole_server.hydration_markup writer "<!--/$-->"))
    (fun _ ->
      Melhole_server.element (fun writer ->
          Melhole_server.hydration_markup writer "<!--$!--><template></template>";
          Melhole_server.write writer fallback;
          Melhole_server.hydration_markup writer "<!--/$-->"))
