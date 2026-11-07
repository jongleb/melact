let () =
  Classics.laws ~part:"quick 2" ~pace:Quick
    [
      { path = "conduit"; skipped = [] };
      { path = "spreadsheet"; skipped = [] };
      { path = "repro/deferred-value"; skipped = [] };
      { path = "feed"; skipped = [ ("like 30 posts", "it likes posts the infinite scroll loads, and jsdom's IntersectionObserver never sees the sentinel"); ("unlike 10 posts", "it unlikes the posts the step before liked"); ("hide 20 posts", "it hides posts the infinite scroll loads"); ("undo 5 hides", "it undoes the hides of the step before") ] };
      { path = "repro/menu-measure"; skipped = [] };
      { path = "repro/controlled-input-flush"; skipped = [] };
      { path = "repro/rows-context"; skipped = [] };
    ]
