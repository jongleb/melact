let () =
  Classics.laws ~part:"slow 3" ~pace:Slow
    [
      { path = "diff"; skipped = [] };
      { path = "autocomplete"; skipped = [] };
    ]
