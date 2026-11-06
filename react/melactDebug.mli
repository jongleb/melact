(** Checks for code that is cheap under React but costly under Melact. *)

(** From now on, warns once per component and property in the console when a component reads
    layout (the [offset*], [client*] and [scroll*] properties, [innerText], [getBoundingClientRect],
    [getClientRects], [getComputedStyle]) while it renders or its holes are written: React renders
    every component before it writes the DOM, Melact writes each component as it renders, so each
    such read forces a layout. Reads in effects, ref callbacks and event handlers are fine. *)
val warnLayoutReadsInRender : unit -> unit
