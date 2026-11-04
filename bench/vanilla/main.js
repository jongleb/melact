const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];

const random = (max) => Math.round(Math.random() * 1000) % max;

const rowTemplate = document.createElement("tr");
rowTemplate.innerHTML =
  '<td class="col-md-1"> </td><td class="col-md-4"><a> </a></td><td class="col-md-1"><a><span class="glyphicon glyphicon-remove" aria-hidden="true"></span></a></td><td class="col-md-6"></td>';

let nextId = 1;
const buildData = (count) => {
  const data = new Array(count);
  for (let i = 0; i < count; i++)
    data[i] = { id: nextId++, label: adjectives[random(adjectives.length)] + " " + colours[random(colours.length)] + " " + nouns[random(nouns.length)] };
  return data;
};

const tbody = document.getElementById("tbody");
const table = tbody.parentNode;
let data = [];
let rows = [];
let selectedRow = null;

const createRow = (item) => {
  const tr = rowTemplate.cloneNode(true);
  const td1 = tr.firstChild;
  const a2 = td1.nextSibling.firstChild;
  tr.data_id = item.id;
  td1.firstChild.nodeValue = item.id;
  a2.firstChild.nodeValue = item.label;
  return tr;
};

const appendRows = (items) => {
  const empty = !tbody.firstChild;
  if (empty) table.removeChild(tbody);
  for (let i = 0; i < items.length; i++) {
    const tr = createRow(items[i]);
    rows.push(tr);
    data.push(items[i]);
    tbody.appendChild(tr);
  }
  if (empty) table.insertBefore(tbody, null);
};

const unselect = () => {
  if (selectedRow !== null) {
    selectedRow.className = "";
    selectedRow = null;
  }
};

const removeAllRows = () => {
  tbody.textContent = "";
  rows = [];
  data = [];
};

const actions = {
  run() {
    removeAllRows();
    unselect();
    appendRows(buildData(1000));
  },
  runlots() {
    removeAllRows();
    unselect();
    appendRows(buildData(10000));
  },
  add() {
    appendRows(buildData(1000));
  },
  update() {
    for (let i = 0; i < data.length; i += 10) {
      data[i].label += " !!!";
      rows[i].childNodes[1].firstChild.firstChild.nodeValue = data[i].label;
    }
  },
  clear() {
    removeAllRows();
    unselect();
  },
  swaprows() {
    if (rows.length > 998) {
      const a = rows[1];
      const b = rows[998];
      const afterB = b.nextSibling;
      tbody.insertBefore(b, a);
      tbody.insertBefore(a, afterB);
      rows[1] = b;
      rows[998] = a;
      const d = data[1];
      data[1] = data[998];
      data[998] = d;
    }
  },
};

for (const id of Object.keys(actions))
  document.getElementById(id).addEventListener("click", (e) => {
    e.stopPropagation();
    actions[id]();
  });

tbody.addEventListener("click", (e) => {
  const a = e.target.closest("a");
  if (a === null) return;
  e.stopPropagation();
  const tr = a.parentNode.parentNode;
  const id = tr.data_id;
  if (a.parentNode.className === "col-md-4") {
    unselect();
    selectedRow = tr;
    tr.className = "danger";
  } else {
    const index = data.findIndex((item) => item.id === id);
    tr.remove();
    rows.splice(index, 1);
    data.splice(index, 1);
    if (selectedRow === tr) selectedRow = null;
  }
});
