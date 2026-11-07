let () =
  Classics.laws ~part:"slow 6" ~pace:Slow
    [
      { path = "repro/logs-chunked"; skipped = [] };
      { path = "filetree"; skipped = [] };
    ]
