let () =
  Classics.laws ~part:"slow 7" ~pace:Slow
    [
      { path = "playlist"; skipped = [] };
      { path = "shop"; skipped = [] };
    ]
