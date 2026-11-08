let () =
  Prerendering.laws ~framework:"Meltea" ~page:Shipped.page ~renders:Page.views
    ~import:[%mel.raw {|function (file) { return import(/* @vite-ignore */ "./" + file).then(() => undefined); }|}]
