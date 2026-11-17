<script>
  import { seed, next, pick, sentence } from "../../common/svelte/classic.js";

  const columns = ["Id", "Name", "Email", "Country", "Amount", "Status", "Joined"];
  const titles = { Id: "ID", Name: "Name", Email: "Email", Country: "Country", Amount: "Amount", Status: "Status", Joined: "Joined" };
  const statuses = ["active", "pending", "suspended", "closed"];
  const pageSize = 1000;
  const money = (amount) => "$" + amount.toFixed(2);

  const generator = seed(2024);
  const first = ["Ada", "Ben", "Chloe", "Dmitri", "Elena", "Farid", "Grace", "Hugo", "Ines", "Jonas", "Kira", "Liam", "Maya", "Nils", "Olga", "Pablo", "Quinn", "Rosa", "Sven", "Tara", "Umar", "Vera", "Wen", "Yara", "Zoe"];
  const last = ["Andersen", "Brown", "Costa", "Dubois", "Eriksen", "Fischer", "Garcia", "Horvat", "Ivanova", "Jensen", "Kowalski", "Lopez", "Muller", "Nakamura", "Okafor", "Petrov", "Rossi", "Silva", "Tanaka", "Weber"];
  const countries = ["Argentina", "Brazil", "Canada", "Denmark", "Egypt", "France", "Germany", "India", "Japan", "Kenya", "Mexico", "Norway", "Poland", "Spain", "Sweden", "Turkey", "Ukraine", "Vietnam"];
  const domains = ["example.com", "mail.test", "corp.local", "post.example"];
  const people = Array.from({ length: 10000 }, (_, index) => {
    const given = pick(generator, first);
    const family = pick(generator, last);
    const month = next(generator, 12) + 1;
    const day = next(generator, 28) + 1;
    const name = given + " " + family;
    const email = given.toLowerCase() + "." + family.toLowerCase() + (index % 97) + "@" + pick(generator, domains);
    const country = pick(generator, countries);
    const amount = next(generator, 1000000) / 100;
    const status = [0, 0, 0, 1, 2, 3][next(generator, 6)];
    const joined = 2015 + next(generator, 10) + (month < 10 ? "-0" : "-") + month + (day < 10 ? "-0" : "-") + day;
    return { id: index + 1, name, email, country, amount, status, joined };
  });

  const text = (person, column) =>
    column === "Id" ? String(person.id)
    : column === "Name" ? person.name
    : column === "Email" ? person.email
    : column === "Country" ? person.country
    : column === "Amount" ? money(person.amount)
    : column === "Status" ? statuses[person.status]
    : person.joined;

  let picked = $state(new Set());
  let sort = $state(null);
  let filters = $state([]);
  let page = $state(0);
  let drawer = $state(null);

  const matching = $derived.by(() => {
    const needles = filters.map(([column, value]) => [column, value.toLowerCase()]);
    return people.filter((person) => needles.every(([column, needle]) => text(person, column).toLowerCase().includes(needle)));
  });
  const ordered = $derived.by(() => {
    if (sort === null) return matching;
    const { column, order } = sort;
    const compare = (left, right) => {
      const [a, b] =
        column === "Id" ? [left.id, right.id]
        : column === "Amount" ? [left.amount, right.amount]
        : column === "Status" ? [left.status, right.status]
        : [text(left, column), text(right, column)];
      return a < b ? -1 : a > b ? 1 : 0;
    };
    return matching.slice().sort((left, right) => (order === "ascending" ? compare(left, right) : compare(right, left)));
  });
  const pages = $derived(Math.max(1, Math.floor((ordered.length + pageSize - 1) / pageSize)));
  const shown = $derived(ordered.slice(page * pageSize, (page + 1) * pageSize));
  const allPicked = $derived(ordered.every((person) => picked.has(person.id)));
  const ids = $derived([...picked].sort((a, b) => a - b));
  const total = $derived(ids.reduce((sum, id) => sum + people[id - 1].amount, 0));

  const sortBy = (column) => {
    sort = sort !== null && sort.column === column && sort.order === "ascending" ? { column, order: "descending" } : { column, order: "ascending" };
    page = 0;
  };
  const filter = (column, value) => {
    filters = [[column, value], ...filters.filter(([other]) => other !== column)].filter(([, value]) => value !== "");
    page = 0;
  };
  const toggle = (id) => {
    const next = new Set(picked);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    picked = next;
  };
  const marks = { ascending: " â\u0096²", descending: " â\u0096¼" };

  const transactions = (person) => {
    const generator = seed(person.id);
    return Array.from({ length: 25 }, (_, index) => {
      const kind = next(generator, 4) === 0 ? "refund" : "charge";
      return { index, memo: sentence(generator, 3), value: next(generator, 50000) / 100, kind };
    });
  };

  const portalled = (node) => {
    document.getElementById("portal").appendChild(node);
    return { destroy: () => node.remove() };
  };
</script>

{#snippet badge(status)}<span class={"badge badge-" + statuses[status]}>{statuses[status]}</span>{/snippet}

<div class="datagrid-app"><div class="grid-page"><div class="grid-toolbar"><span id="match-count">{ordered.length + " of 10000 people"}</span><button
        id="clear-filters"
        onclick={() => {
          filters = [];
          page = 0;
        }}>Clear filters</button
      ><nav class="pager"><button id="prev-page" disabled={page === 0} onclick={() => (page -= 1)}>Previous</button
        >{#each { length: pages }, index (index)}<button class={index === page ? "page current" : "page"} onclick={() => (page = index)}
            >{index + 1}</button
          >{/each}<button id="next-page" disabled={page >= pages - 1} onclick={() => (page += 1)}>Next</button></nav
      ></div><div class="table-scroll"><table class="data-grid"><thead><tr><th><input
                id="select-all"
                type="checkbox"
                checked={allPicked && ordered.length > 0}
                onchange={() => (picked = allPicked ? new Set() : new Set([...picked, ...ordered.map((person) => person.id)]))}
              /></th
            >{#each columns as column (column)}{@const mark = sort !== null && sort.column === column ? sort.order : "none"}<th
                class="sortable"
                aria-sort={mark}
                onclick={() => sortBy(column)}>{titles[column]}<span class="sort-mark">{marks[mark] ?? ""}</span></th
              >{/each}</tr
          ><tr class="filters"><th></th>{#each columns as column (column)}<th
                ><input
                  class={"filter filter-" + titles[column].toLowerCase()}
                  placeholder={"Filter " + titles[column].toLowerCase()}
                  value={filters.find(([other]) => other === column)?.[1] ?? ""}
                  oninput={(event) => filter(column, event.target.value)}
                /></th
              >{/each}</tr
          ></thead
        ><tbody
          >{#each shown as person (person.id)}{@const isPicked = picked.has(person.id)}<tr class={isPicked ? "row picked" : "row"}
              ><td><input class="row-select" type="checkbox" checked={isPicked} onchange={() => toggle(person.id)} /></td><td class="num"
                >{person.id}</td
              ><td
                ><a
                  class="open-detail"
                  href="#"
                  onclick={(event) => {
                    event.preventDefault();
                    drawer = person.id;
                  }}>{person.name}</a
                ></td
              ><td>{person.email}</td><td>{person.country}</td><td class="num">{money(person.amount)}</td><td
                >{@render badge(person.status)}</td
              ><td>{person.joined}</td></tr
            >{/each}</tbody
        ></table
      ></div
    >{#if drawer !== null}{@const person = people[drawer - 1]}<aside class="drawer" use:portalled
        ><header><h2 id="drawer-title">{person.name}</h2><button id="close-drawer" onclick={() => (drawer = null)}>Close</button></header
        ><dl
          ><dt>Email</dt><dd>{person.email}</dd><dt>Country</dt><dd>{person.country}</dd><dt>Balance</dt><dd>{money(person.amount)}</dd><dt
            >Status</dt
          ><dd>{@render badge(person.status)}</dd><dt>Joined</dt><dd>{person.joined}</dd></dl
        ><label class="drawer-pick"
          ><input type="checkbox" checked={picked.has(person.id)} onchange={() => toggle(person.id)} /> Selected</label
        ><h3>Recent transactions</h3><table class="transactions"><tbody
            >{#each transactions(person) as row (row.index)}<tr class={row.kind}><td>{row.memo}</td><td>{row.kind}</td><td class="num"
                  >{money(row.value)}</td
                ></tr
              >{/each}</tbody
          ></table
        ></aside
      >{/if}</div
  ><footer class="summary"><span id="selected-count">{ids.length + " selected"}</span><span id="selected-total"
      >{"Total " + money(total)}</span
    ><span class="by-status"
      >{#each [0, 1, 2, 3] as status (status)}<span class="status-count"
          >{@render badge(status)}{ids.filter((id) => people[id - 1].status === status).length}</span
        >{/each}</span
    ><button id="clear-selection" disabled={ids.length === 0} onclick={() => (picked = new Set())}>Clear selection</button></footer
  ></div>
