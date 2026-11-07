let () =
  Classics.laws ~part:"quick 4" ~pace:Quick
    [
      { path = "repro/unicode-layout-cost"; skipped = [] };
      { path = "admin"; skipped = [] };
      { path = "trace"; skipped = [] };
      { path = "wizard"; skipped = [] };
      { path = "calendar"; skipped = [] };
      { path = "repro/change-event"; skipped = [] };
      { path = "repro/search-debounce"; skipped = [] };
      { path = "repro/list-in-match"; skipped = [] };
      { path = "virtuallist"; skipped = [ ("expand 20 visible rows", "it picks rows by their getBoundingClientRect inside the viewport, which jsdom does not lay out") ] };
      { path = "repro/layout-read-after-parent-write"; skipped = [] };
      { path = "repro/radio-same-name"; skipped = [] };
    ]
