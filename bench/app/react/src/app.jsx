import { createContext, useContext, useEffect, useMemo, useReducer, useState } from "react";
import { createRoot } from "react-dom/client";
import { categories, items, owners } from "../../data.mjs";

const categoryColour = { Backlog: "#9ca3af", Doing: "#3b82f6", Review: "#f59e0b", Done: "#10b981" };
const ThemeContext = createContext("light");

function Tab({ label, active, onClick }) {
  __rendered("Tab");
  return (
    <button id={"tab-" + label.toLowerCase()} className={active ? "tab active" : "tab"} onClick={() => onClick()}>
      {label}
    </button>
  );
}

function Badge({ count }) {
  __rendered("Badge");
  const theme = useContext(ThemeContext);
  return <span id="badge" className={"badge " + theme}>{count}</span>;
}

const tabs = [["list", "List"], ["board", "Board"], ["stats", "Stats"]];

function Header({ tab, onTab, notifications, onNotify, onTheme }) {
  __rendered("Header");
  return (
    <header className="header">
      <nav className="tabs">
        {tabs.map(([target, label]) => (
          <Tab key={label} label={label} active={target === tab} onClick={() => onTab(target)} />
        ))}
      </nav>
      <button id="notify" onClick={() => onNotify()}>Notify</button>
      <Badge count={notifications} />
      <button id="theme" onClick={() => onTheme()}>Theme</button>
    </header>
  );
}

function SearchBox({ value, onChange }) {
  __rendered("SearchBox");
  return <input id="search" type="text" placeholder="Search" value={value} onChange={(event) => onChange(event.target.value)} />;
}

function Toolbar({ query, onQuery, shown, onExpandAll, onCollapseAll }) {
  __rendered("Toolbar");
  return (
    <div className="toolbar">
      <SearchBox value={query} onChange={onQuery} />
      <button id="clear-search" onClick={() => onQuery("")}>Clear</button>
      <span id="shown">{shown + " shown"}</span>
      <button id="expand-all" onClick={() => onExpandAll()}>Expand all</button>
      <button id="collapse-all" onClick={() => onCollapseAll()}>Collapse all</button>
    </div>
  );
}

function Tags({ tags }) {
  __rendered("Tags");
  return (
    <span className="tags">
      {tags.map((tag) => (
        <span key={tag} className="tag">{tag}</span>
      ))}
    </span>
  );
}

function Details({ item }) {
  __rendered("Details");
  const theme = useContext(ThemeContext);
  const words = useMemo(() => item.note.split(" ").length, [item]);
  return (
    <div className={"details " + theme}>
      <p className="note">{item.note}</p>
      <dl>
        <dt>Owner</dt>
        <dd>{item.owner}</dd>
        <dt>Points</dt>
        <dd>{item.points}</dd>
        <dt>Status</dt>
        <dd>{item.category}</dd>
        <dt>Words</dt>
        <dd>{words}</dd>
      </dl>
    </div>
  );
}

function Row({ item, selected, bulk, onSelect }) {
  __rendered("Row");
  const theme = useContext(ThemeContext);
  const [expanded, setExpanded] = useState(bulk.expanded);
  useEffect(() => {
    setExpanded(bulk.expanded);
  }, [bulk.generation]);
  return (
    <li
      className={"row " + theme + (selected ? " selected" : "") + (expanded ? " expanded" : "")}
      style={{ borderLeftColor: categoryColour[item.category] }}
    >
      <div className="line">
        <button className="toggle" onClick={() => setExpanded((expanded) => !expanded)}>
          {expanded ? "-" : "+"}
        </button>
        <span className="id">{item.id}</span>
        <a className="title" onClick={() => onSelect()}>{item.title}</a>
        <Tags tags={[item.category, item.owner]} />
        <span className="points">{item.points}</span>
      </div>
      {expanded ? <Details item={item} /> : null}
    </li>
  );
}

function RowList({ items, selected, bulk, onSelect }) {
  __rendered("RowList");
  return (
    <ul className="rows">
      {items.map((item) => (
        <Row key={item.id} item={item} selected={selected === item.id} bulk={bulk} onSelect={() => onSelect(item.id)} />
      ))}
    </ul>
  );
}

function Card({ item, selected, onSelect }) {
  __rendered("Card");
  return (
    <div
      className={selected ? "card selected" : "card"}
      style={{ borderTopColor: categoryColour[item.category] }}
      onClick={() => onSelect()}
    >
      <span className="id">{item.id}</span>
      <span className="title">{item.title}</span>
      <span className="points">{item.points}</span>
    </div>
  );
}

function Column({ category, items, selected, onSelect }) {
  __rendered("Column");
  return (
    <section className="column">
      <h3>{category + " (" + items.length + ")"}</h3>
      {items.map((item) => (
        <Card key={item.id} item={item} selected={selected === item.id} onSelect={() => onSelect(item.id)} />
      ))}
    </section>
  );
}

function Board({ items, selected, onSelect }) {
  __rendered("Board");
  return (
    <div className="board">
      {categories.map((category) => (
        <Column
          key={category}
          category={category}
          items={items.filter((item) => item.category === category)}
          selected={selected}
          onSelect={onSelect}
        />
      ))}
    </div>
  );
}

function StatRow({ total }) {
  __rendered("StatRow");
  return (
    <tr>
      <td>{total.owner}</td>
      <td>{total.count}</td>
      <td>{total.sum}</td>
    </tr>
  );
}

function Stats({ items }) {
  __rendered("Stats");
  const totals = useMemo(
    () =>
      owners.map((owner) => {
        const mine = items.filter((item) => item.owner === owner);
        return { owner, count: mine.length, sum: mine.reduce((sum, item) => sum + item.points, 0) };
      }),
    [items],
  );
  return (
    <table className="stats">
      <tbody>
        {totals.map((total) => (
          <StatRow key={total.owner} total={total} />
        ))}
      </tbody>
    </table>
  );
}

function App() {
  __rendered("App");
  const [tab, setTab] = useState("list");
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState(null);
  const [notifications, setNotifications] = useState(0);
  const [theme, setTheme] = useState("light");
  const [bulk, dispatchBulk] = useReducer((bulk, expanded) => ({ expanded, generation: bulk.generation + 1 }), {
    expanded: false,
    generation: 0,
  });
  const visible = useMemo(() => items.filter((item) => item.title.includes(query)), [query]);
  return (
    <ThemeContext.Provider value={theme}>
      <div className={"app " + theme}>
        <Header
          tab={tab}
          onTab={(next) => setTab(next)}
          notifications={notifications}
          onNotify={() => setNotifications((count) => count + 1)}
          onTheme={() => setTheme((theme) => (theme === "light" ? "dark" : "light"))}
        />
        <Toolbar
          query={query}
          onQuery={(text) => setQuery(text)}
          shown={visible.length}
          onExpandAll={() => dispatchBulk(true)}
          onCollapseAll={() => dispatchBulk(false)}
        />
        {tab === "list" ? (
          <RowList items={visible} selected={selected} bulk={bulk} onSelect={(id) => setSelected(id)} />
        ) : tab === "board" ? (
          <Board items={visible} selected={selected} onSelect={(id) => setSelected(id)} />
        ) : (
          <Stats items={visible} />
        )}
      </div>
    </ThemeContext.Provider>
  );
}

const container = document.getElementById("root");
let root = null;
document.getElementById("mount").addEventListener("click", () => {
  if (root !== null) return;
  root = createRoot(container);
  root.render(<App />);
});
document.getElementById("unmount").addEventListener("click", () => {
  if (root === null) return;
  root.unmount();
  root = null;
});
