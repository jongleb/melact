A list in an element whose declared stylesheet cannot see groups is grouped for rendering:

  $ cat > safe.css <<'EOF_'
  > .list li { padding: 4px; }
  > @media (min-width: 600px) { .list li.done { color: gray; } }
  > EOF_
  $ cat > safe.ml <<'EOF_'
  > [@@@meltea.styles "safe.css"]
  > let view rows = ((ul ~className:"list" ~children:[ Html.list (List.map (fun row -> ((li ~children:[ Html.text row ] ()) [@JSX])) rows) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl safe.ml | grep -c "Html.grouped"
  1

A selector that counts the rows keeps the list whole, and says which:

  $ cat > counting.css <<'EOF_'
  > .list li:last-child { border: none; }
  > EOF_
  $ sed 's/safe.css/counting.css/' safe.ml > counting.ml
  $ ./pp.exe -impl counting.ml | grep -c "Html.grouped"
  0
  [1]
  $ ./pp.exe -impl counting.ml | grep -o "the selector .list li:last-child in ./counting.css"
  the selector .list li:last-child in ./counting.css

So does a child combinator from the list's element to its rows:

  $ cat > child.css <<'EOF_'
  > ul > li { margin: 0; }
  > EOF_
  $ sed 's/safe.css/child.css/' safe.ml > child.ml
  $ ./pp.exe -impl child.ml | grep -c "Html.grouped"
  0
  [1]

With no declared stylesheet the compiler knows nothing of the CSS, and the list stays whole:

  $ sed '1d' safe.ml > undeclared.ml
  $ ./pp.exe -impl undeclared.ml | grep -c "Html.grouped"
  0
  [1]
