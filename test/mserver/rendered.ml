let page values = ReactDOMServer.renderToString (Pages.shown values)
let markup values = ReactDOMServer.renderToStaticMarkup (Pages.shown values)
let effects () = !Pages.effects
