let () =
  Classics.laws ~part:"quick 3" ~pace:Quick
    [
      { path = "repro/effect-sort"; skipped = [] };
      { path = "chess"; skipped = [] };
      { path = "gantt"; skipped = [] };
      { path = "eventtable"; skipped = [] };
      { path = "minesweeper"; skipped = [] };
      { path = "repro/popover-focus"; skipped = [] };
      { path = "repro/set-state-in-render"; skipped = [] };
    ]
