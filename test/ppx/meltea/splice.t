A helper called as a child with constant arguments joins the page's template; the helper is gone:

  $ cat > spliced.ml <<'EOF_'
  > type message = Run | Add
  > let view () =
  >   let button id message = ((button ~id ~onClick:message ~children:[ Html.text id ] ()) [@JSX]) in
  >   ((div ~children:[ button "run" Run; button "add" Add ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl spliced.ml | grep -A1 "Template.html"
      (Melhole.Template.html
         "<div><button id=\"run\">run</button><button id=\"add\">add</button></div>")

A name the helper reads, bound again before the call, keeps the call and the helper's own template:

  $ cat > shadowed.ml <<'EOF_'
  > let view mark =
  >   let item label = ((em ~children:[ Html.text (label ^ mark) ] ()) [@JSX]) in
  >   let mark = "!" in
  >   ((div ~children:[ item mark ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl shadowed.ml | grep -A1 "Template.html"
    Meltea_runtime.View.template (Melhole.Template.html "<em></em>")
      {
  --
    Meltea_runtime.View.template (Melhole.Template.html "<div></div>")
      {
