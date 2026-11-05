let renderToString element = Melhole.Served.render (React.to_child element)

let renderToStaticMarkup element =
  Js.String.replaceByRe ~regexp:[%re "/<!--[\\[\\]]?-->/g"] ~replacement:"" (renderToString element)
