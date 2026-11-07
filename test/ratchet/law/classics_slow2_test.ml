let () =
  Classics.laws ~part:"slow 2" ~pace:Slow
    [
      { path = "logs"; skipped = [] };
    ]
