let () =
  Classics.laws ~part:"slow 8" ~pace:Slow
    [
      { path = "hackernews"; skipped = [] };
      { path = "markdown"; skipped = [] };
      { path = "kanban"; skipped = [] };
      { path = "repro/nested-context-consumers"; skipped = [] };
      { path = "datagrid"; skipped = [] };
    ]
