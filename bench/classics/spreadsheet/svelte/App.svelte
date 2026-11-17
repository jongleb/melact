<script>
  import { seed, next, pick, words } from "../../common/svelte/classic.js";
  import { rows, columns, columnName, address, shift, evaluate, display } from "./formula.js";

  const generator = seed(11);
  const initial = Array.from({ length: rows * columns }, (_, index) => {
    const row = Math.floor(index / columns);
    const col = index % columns;
    const line = String(row + 1);
    switch (col) {
      case 40: return "=SUM(A" + line + ":J" + line + ")";
      case 41: return "=AVG(K" + line + ":T" + line + ")";
      case 42: return "=MAX(U" + line + ":AD" + line + ")";
      case 43: return "=MIN(AE" + line + ":AN" + line + ")";
      case 44: return "=AO" + line + "+AP" + line + "*2";
      case 45: return "=AS" + line + "/(AQ" + line + "-AR" + line + "+1)";
      case 46: return "=AT" + line + "*A1";
      case 47: return row === 0 ? "=AU1" : "=AV" + row + "+AU" + line;
      case 48: return "=SUM(AO1:AO" + line + ")";
      case 49: return "=AV" + line + "-AW" + line;
      default: {
        const kind = next(generator, 9);
        return kind === 0 ? pick(generator, words) : kind === 1 ? "" : String(next(generator, 1000));
      }
    }
  });

  const rowIndices = Array.from({ length: rows }, (_, row) => row);
  const columnIndices = Array.from({ length: columns }, (_, col) => col);

  let raws = $state.raw(initial);
  let past = $state.raw([]);
  let selection = $state({ row: 0, col: 0 });
  let editing = $state(null);
  let sheet;

  const values = $derived(evaluate(raws));
  const shown = $derived(values.map(display));
  let formula = $derived(raws[selection.row * columns + selection.col]);
  const summary = $derived(
    raws.reduce(
      ([formulas, errors, total], raw, index) => [
        raw.startsWith("=") ? formulas + 1 : formulas,
        values[index].kind === "failure" ? errors + 1 : errors,
        values[index].kind === "amount" ? total + values[index].value : total,
      ],
      [0, 0, 0],
    ),
  );
  const columnSum = $derived(
    rowIndices.reduce((sum, row) => {
      const value = values[row * columns + selection.col];
      return value.kind === "amount" ? sum + value.value : sum;
    }, 0),
  );

  const change = (next) => {
    past = [raws, ...past.slice(0, 99)];
    raws = next;
  };

  const moved = ({ row, col }, direction) =>
    direction === "up" ? { row: Math.max(0, row - 1), col }
    : direction === "down" ? { row: Math.min(rows - 1, row + 1), col }
    : direction === "left" ? { row, col: Math.max(0, col - 1) }
    : { row, col: Math.min(columns - 1, col + 1) };

  const commit = (target, text) => {
    const index = target.row * columns + target.col;
    if (raws[index] !== text) {
      const next = raws.slice();
      next[index] = text;
      change(next);
    }
    editing = null;
    selection = moved(target, "down");
  };

  const fillDown = () => {
    const { row, col } = selection;
    const source = raws[row * columns + col];
    const next = raws.slice();
    for (let below = row + 1; below < rows; below++) next[below * columns + col] = shift(source, below - row);
    change(next);
  };

  const clearSelected = () => {
    const next = raws.slice();
    next[selection.row * columns + selection.col] = "";
    change(next);
  };

  const undo = () => {
    if (past.length === 0) return;
    raws = past[0];
    past = past.slice(1);
    editing = null;
  };

  const keyed = (event) => {
    if (editing !== null || event.target !== event.currentTarget) return;
    const move = { ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right" }[event.key];
    if (move) {
      event.preventDefault();
      selection = moved(selection, move);
    } else if (event.key === "Enter") editing = raws[selection.row * columns + selection.col];
    else if (event.key === "Delete" || event.key === "Backspace") clearSelected();
    else if (event.key === "z" && (event.ctrlKey || event.metaKey)) undo();
    else if (event.key.length === 1 && !event.ctrlKey) {
      event.preventDefault();
      editing = event.key;
    }
  };

  $effect(() => {
    if (editing === null) sheet.focus();
  });

  $effect(() => {
    const { row, col } = selection;
    if (editing === null)
      sheet.querySelector(`tbody tr:nth-child(${row + 1}) td:nth-child(${col + 2})`)?.scrollIntoView({ block: "nearest", inline: "nearest" });
  });

  const focus = (node) => {
    node.focus();
  };
</script>

<div class="spreadsheet"><div class="toolbar"><button id="undo" disabled={past.length === 0} onclick={undo}>Undo</button><button
      id="fill-down"
      onclick={fillDown}>Fill down</button
    ><button id="clear-cell" onclick={clearSelected}>Clear</button></div><div class="formula-bar"><span class="address"
      >{address(selection.row, selection.col)}</span
    ><span class="fx">fx</span><input
      id="formula"
      bind:value={formula}
      onkeydown={(event) => {
        if (event.key === "Enter") commit(selection, formula);
        else if (event.key === "Escape") formula = raws[selection.row * columns + selection.col];
      }}
    /></div><div class="sheet" tabindex="0" bind:this={sheet} onkeydown={keyed}><table class="grid"><thead><tr
          ><th class="corner"></th>{#each columnIndices as col (col)}<th class={selection.col === col ? "column-header current" : "column-header"}
              >{columnName(col)}</th
            >{/each}</tr
        ></thead><tbody
        >{#each rowIndices as row (row)}<tr><th class={selection.row === row ? "row-header current" : "row-header"}>{row + 1}</th
            >{#each columnIndices as col (col)}{@const index = row * columns + col}{@const here = selection.row === row && selection.col === col}<td
                class={["cell", here ? (editing === null ? "focused" : "typing") : "", raws[index].startsWith("=") ? "formula" : ""].join(" ")}
                onclick={() => {
                  selection = { row, col };
                  editing = null;
                }}
                ondblclick={() => {
                  selection = { row, col };
                  editing = raws[index];
                }}
                >{#if here && editing !== null}<input
                    class="cell-editor"
                    bind:value={editing}
                    use:focus
                    onkeydown={(event) => {
                      if (event.key === "Enter") commit({ row, col }, editing);
                      else if (event.key === "Escape") editing = null;
                    }}
                  />{:else}{shown[index]}{/if}</td
              >{/each}</tr
          >{/each}</tbody
      ></table></div><footer class="status-bar"><span id="formula-count">{summary[0] + " formulas"}</span><span id="error-count"
      >{summary[1] + " errors"}</span
    ><span id="sheet-total">{"Total " + display({ kind: "amount", value: summary[2] })}</span><span id="column-sum"
      >{"Sum of " + columnName(selection.col) + ": " + display({ kind: "amount", value: columnSum })}</span
    ></footer></div>
