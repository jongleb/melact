let () =
  Classics.laws ~part:"slow 5" ~pace:Slow
    [
      { path = "email"; skipped = [] };
      { path = "gallery"; skipped = [] };
    ]
