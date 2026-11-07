let () =
  Classics.laws ~part:"slow 4" ~pace:Slow
    [
      { path = "chat"; skipped = [] };
      { path = "todomvc"; skipped = [] };
    ]
