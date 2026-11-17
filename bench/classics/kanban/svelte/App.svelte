<script>
  import { seed, next, pick, sentence } from "../../common/svelte/classic.js";

  const labels = ["bug", "feature", "chore", "design", "research", "urgent"];
  const people = ["AK", "BL", "CM", "DN", "EO", "FP", "GQ", "HR", "IS", "JT"];
  const names = ["Backlog", "Ready", "In progress", "Review", "Testing", "Staging", "Done", "Archived"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  const generator = seed(11);
  let made = 0;
  const initial = names.map((name, key) => ({
    key,
    name,
    cards: Array.from({ length: key === 7 ? 184 : 188 }, () => {
      made += 1;
      const items = next(generator, 9);
      const words = 3 + next(generator, 4);
      const title = sentence(generator, words);
      const description = sentence(generator, 12);
      const tags = labels.filter(() => next(generator, 4) === 0);
      const members = Array.from({ length: next(generator, 4) }, () => pick(generator, people));
      const due = next(generator, 365);
      const checked = items === 0 ? 0 : next(generator, items + 1);
      const comments = next(generator, 12);
      return { id: made, title: title[0].toUpperCase() + title.slice(1), description, labels: tags, members, due, checked, items, comments };
    }),
  }));

  let columns = $state(initial);
  let filter = $state(null);
  let modal = $state(null);
  let drag = $state(null);
  let lanes = $state(names.map(() => ({ expanded: true, hover: false, draft: null })));

  const shown = $derived(
    filter === null ? columns : columns.map((column) => ({ ...column, cards: column.cards.filter((card) => card.labels.includes(filter)) })),
  );
  const total = $derived(columns.reduce((sum, column) => sum + column.cards.length, 0));
  const opened = $derived(modal === null ? null : columns.flatMap((column) => column.cards).find((card) => card.id === modal.id));

  const locate = (id) => {
    for (const column of columns) {
      const index = column.cards.findIndex((card) => card.id === id);
      if (index !== -1) return { column, index };
    }
    return null;
  };

  const place = (id, target) => {
    const found = locate(id);
    if (found === null) return;
    const [card] = found.column.cards.splice(found.index, 1);
    columns[target].cards.unshift(card);
  };

  const moveNext = (id) => {
    const found = locate(id);
    if (found !== null) place(id, (found.column.key + 1) % columns.length);
  };

  const drop = (event, key) => {
    event.preventDefault();
    lanes[key].hover = false;
    const id = Number(event.dataTransfer.getData("text/plain"));
    const found = locate(id);
    if (found !== null && found.column.key !== key) place(id, key);
    drag = null;
  };

  const toggle = (card, label) => {
    const has = card.labels.includes(label);
    card.labels = labels.filter((other) => (other === label ? !has : card.labels.includes(other)));
  };

  const save = () => {
    const card = opened;
    card.title = modal.title;
    card.description = modal.description;
    modal = null;
  };

  const submit = (key) => {
    const title = lanes[key].draft.trim();
    lanes[key].draft = null;
    if (title === "") return;
    const id = 1 + columns.reduce((top, column) => column.cards.reduce((top, card) => Math.max(top, card.id), top), 0);
    columns[key].cards.push({ id, title, description: "", labels: [], members: [], due: 0, checked: 0, items: 0, comments: 0 });
  };

  const preview = (text) =>
    text
      .split("\n")
      .map((line) => line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>"))
      .join("<br>");

  const focus = (node) => {
    node.focus();
  };

  const portal = (node) => {
    document.getElementById("portal").appendChild(node);
    return { destroy: () => node.remove() };
  };
</script>

<svelte:document onkeydown={(event) => { if (modal !== null && event.key === "Escape") modal = null; }} />

{#snippet chip(label)}<span class={"label label-" + label} title={label}>{label}</span>{/snippet}

{#snippet badges(card)}<div class="badges">{#if card.due !== 0}<span class="badge due"
        >{months[Math.floor(card.due / 31) % 12] + " " + (1 + (card.due % 28))}</span
      >{/if}{#if card.items !== 0}<span class={card.checked === card.items ? "badge checklist complete" : "badge checklist"}
        >{card.checked + "/" + card.items}</span
      >{/if}{#if card.comments !== 0}<span class="badge comments">{"💬 " + card.comments}</span>{/if}{#if card.description !== ""}<span
        class="badge described">≡</span
      >{/if}</div>{/snippet}

<div class="kanban"><header class="board-header"><h1>Product board</h1><span class="total">{total + " cards"}</span><div
      class="filter-bar"
    ><span>Filter:</span><div class="label-filter">{#each labels as label (label)}<button
            class={filter === label ? "chip active" : "chip"}
            onclick={() => (filter = label)}>{label}</button
          >{/each}</div><button id="clear-filter" onclick={() => (filter = null)}>Clear filter</button></div></header><div
    class="board"
  >{#each shown as column, key (column.key)}<section
        class={["column", lanes[key].expanded ? "expanded" : "collapsed", drag !== null && lanes[key].hover ? "drop-target" : ""].join(" ")}
      ><header class="column-header"><h2>{column.name}</h2><span class="count">{column.cards.length}</span><button
            class="fold"
            onclick={() => (lanes[key].expanded = !lanes[key].expanded)}>{lanes[key].expanded ? "‹" : "›"}</button
          ></header>{#if lanes[key].expanded}<div
            class="column-body"
            ondragenter={(event) => {
              event.preventDefault();
              lanes[key].hover = true;
            }}
            ondragover={(event) => event.preventDefault()}
            ondragleave={() => (lanes[key].hover = false)}
            ondrop={(event) => drop(event, key)}
          >{#each column.cards as card (card.id)}<div
                class={drag === card.id ? "card dragging" : "card"}
                draggable="true"
                ondragstart={(event) => {
                  event.dataTransfer.setData("text/plain", String(card.id));
                  drag = card.id;
                }}
                ondragend={() => (drag = null)}
              >{#if card.labels.length !== 0}<div class="labels">{#each card.labels as label (label)}{@render chip(label)}{/each}</div
                  >{/if}<a class="card-title" onclick={() => (modal = { id: card.id, title: card.title, description: card.description })}
                  >{card.title}</a
                >{@render badges(card)}<div class="card-footer"><div class="members">{#each card.members as initials}<span
                        class="avatar"
                        style:background-color={"hsl(" + ((initials.charCodeAt(0) * 37) % 360) + ", 55%, 45%)"}>{initials}</span
                      >{/each}</div><button class="move-next" title="Move to next column" onclick={() => moveNext(card.id)}>→</button
                  ></div></div
              >{/each}</div
          >{#if lanes[key].draft === null}<button class="add-card" onclick={() => (lanes[key].draft = "")}>+ Add a card</button
            >{:else}<div class="composer"><textarea
                class="text-area"
                placeholder="Enter a title for this card..."
                bind:value={lanes[key].draft}
                use:focus
                onkeydown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    submit(key);
                  } else if (event.key === "Escape") lanes[key].draft = null;
                }}
              ></textarea><button class="composer-add" onclick={() => submit(key)}>Add card</button><button
                class="composer-cancel"
                onclick={() => (lanes[key].draft = null)}>×</button
              ></div>{/if}{/if}</section
      >{/each}</div
  >{#if opened}<div class="modal-backdrop" use:portal onclick={() => (modal = null)}><div
        class="modal"
        onclick={(event) => event.stopPropagation()}
      ><input class="title-field" bind:value={modal.title} use:focus /><div class="modal-labels"
          >{#each labels as label (label)}<button
              class={opened.labels.includes(label) ? "label-toggle on" : "label-toggle"}
              onclick={() => toggle(opened, label)}>{@render chip(label)}</button
            >{/each}</div
        ><label>Description</label><textarea class="description-field" bind:value={modal.description}></textarea><div
          class="description-preview"
        >{@html preview(modal.description)}</div>{@render badges(opened)}<div class="modal-actions"><button
            class="save"
            onclick={save}>Save</button
          ><button class="close" onclick={() => (modal = null)}>Close</button></div></div></div
    >{/if}</div>
