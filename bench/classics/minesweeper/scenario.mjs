export default [
  {
    name: "reveal 30 safe cells",
    run: () =>
      __h.repeat(30, (count) => {
        const mines = new Set(window.__mines(Number(document.querySelector("#game-number").textContent)));
        const cells = __h.all(".cell");
        for (let offset = 0; offset < cells.length; offset++) {
          const index = (count * 409 + 17 + offset) % cells.length;
          if (!mines.has(index) && cells[index].classList.contains("covered")) {
            cells[index].click();
            return;
          }
        }
      }),
  },
  {
    name: "flag 40 cells",
    run: () =>
      __h.repeat(40, (count) => {
        const cells = __h.all(".cell");
        for (let offset = 0; offset < cells.length; offset++) {
          const index = (count * 61 + 7 + offset) % cells.length;
          if (cells[index].classList.contains("covered")) {
            __h.mouse("contextmenu", cells[index], 0, { button: 2 });
            return;
          }
        }
      }),
  },
  { name: "unflag 20", run: () => __h.repeat(20, () => __h.mouse("contextmenu", ".cell.flagged", 0, { button: 2 })) },
  { name: "reset", run: () => __h.click("#reset") },
  {
    name: "reveal a big flood-fill region",
    run: () => {
      const size = 50;
      const mines = new Set(window.__mines(Number(document.querySelector("#game-number").textContent)));
      const around = (index) => {
        const row = Math.floor(index / size), column = index % size, out = [];
        for (let down = -1; down <= 1; down++)
          for (let across = -1; across <= 1; across++) {
            const r = row + down, c = column + across;
            if ((down || across) && r >= 0 && r < size && c >= 0 && c < size) out.push(r * size + c);
          }
        return out;
      };
      const zero = (index) => !mines.has(index) && around(index).every((near) => !mines.has(near));
      const seen = new Set();
      let best = -1, bestSize = 0;
      for (let start = 0; start < size * size; start++) {
        if (seen.has(start) || !zero(start)) continue;
        let region = 0;
        const stack = [start];
        seen.add(start);
        while (stack.length) {
          const index = stack.pop();
          region++;
          for (const near of around(index)) if (!seen.has(near) && zero(near)) { seen.add(near); stack.push(near); }
        }
        if (region > bestSize) { best = start; bestSize = region; }
      }
      __h.click(".cell", best);
    },
  },
  {
    name: "chord 10 times",
    run: () =>
      __h.repeat(10, async () => {
        const size = 50;
        const mines = new Set(window.__mines(Number(document.querySelector("#game-number").textContent)));
        const cells = __h.all(".cell");
        const around = (index) => {
          const row = Math.floor(index / size), column = index % size, out = [];
          for (let down = -1; down <= 1; down++)
            for (let across = -1; across <= 1; across++) {
              const r = row + down, c = column + across;
              if ((down || across) && r >= 0 && r < size && c >= 0 && c < size) out.push(r * size + c);
            }
          return out;
        };
        const target = cells.findIndex(
          (cell, index) =>
            cell.classList.contains("open") &&
            cell.textContent !== "" &&
            around(index).some((near) => !mines.has(near) && cells[near].classList.contains("covered")),
        );
        if (target < 0) return;
        for (const near of around(target))
          if (mines.has(near) && cells[near].classList.contains("covered")) {
            __h.mouse("contextmenu", cells[near], 0, { button: 2 });
            await __h.frame();
          }
        __h.click(".cell", target);
      }),
  },
  { name: "tick 30 times", run: () => __h.repeat(30, () => __h.click("#tick")) },
];
