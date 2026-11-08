let () =
  Prerendering.laws ~framework:"Melact" ~page:Shipped.page ~renders:Page.renders
    ~import:[%mel.raw {|function (file) { return import(/* @vite-ignore */ "./" + file).then(() => undefined); }|}]
