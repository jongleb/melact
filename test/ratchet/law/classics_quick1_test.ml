let () =
  Classics.laws ~part:"quick 1" ~pace:Quick
    [
      { path = "jsontree"; skipped = [] };
      { path = "dashboard"; skipped = [] };
      { path = "blocks"; skipped = [] };
      { path = "repro/stale-layout-read"; skipped = [] };
      { path = "repro/unicode-static-text"; skipped = [] };
      { path = "repro/select-value"; skipped = [] };
    ]
