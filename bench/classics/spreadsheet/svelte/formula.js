// The spreadsheet's formulas, the same language as the OCaml builds' Formula module.
export const rows = 100;
export const columns = 50;

export const columnName = (col) => {
  const letter = (index) => String.fromCharCode(65 + index);
  return col < 26 ? letter(col) : letter(Math.floor(col / 26) - 1) + letter(col % 26);
};

export const address = (row, col) => columnName(col) + (row + 1);

class Failed extends Error {
  constructor(failure) {
    super(failure);
    this.failure = failure;
  }
}

const isDigit = (c) => c >= "0" && c <= "9";
const isLetter = (c) => (c >= "A" && c <= "Z") || (c >= "a" && c <= "z");

const tokens = (text) => {
  const found = [];
  let index = 0;
  while (index < text.length) {
    const c = text[index];
    if (c === " ") index++;
    else if (isDigit(c) || c === ".") {
      let stop = index;
      while (stop < text.length && (isDigit(text[stop]) || text[stop] === ".")) stop++;
      const number = Number(text.slice(index, stop));
      found.push({ kind: "number", value: Number.isNaN(number) ? 0 : number });
      index = stop;
    } else if (isLetter(c)) {
      let lettersEnd = index;
      while (lettersEnd < text.length && isLetter(text[lettersEnd])) lettersEnd++;
      const letters = text.slice(index, lettersEnd).toUpperCase();
      let digitsEnd = lettersEnd;
      while (digitsEnd < text.length && isDigit(text[digitsEnd])) digitsEnd++;
      if (digitsEnd > lettersEnd) {
        let col = 0;
        for (const letter of letters) col = col * 26 + (letter.charCodeAt(0) - 64);
        found.push({ kind: "cell", col: col - 1, row: Number(text.slice(lettersEnd, digitsEnd)) - 1 });
      } else found.push({ kind: "name", value: letters });
      index = digitsEnd;
    } else if ("+-*/():,".includes(c)) {
      found.push({ kind: "symbol", value: c });
      index++;
    } else throw new Failed("malformed");
  }
  return found;
};

const parse = (text) => {
  const rest = tokens(text);
  let at = 0;
  const peek = () => rest[at];
  const expect = (symbol) => {
    const token = peek();
    if (token?.kind === "symbol" && token.value === symbol) at++;
    else throw new Failed("malformed");
  };
  const factor = () => {
    const token = peek();
    if (token === undefined) throw new Failed("malformed");
    if (token.kind === "number") {
      at++;
      return { kind: "literal", value: token.value };
    }
    if (token.kind === "cell") {
      at++;
      return { kind: "reference", col: token.col, row: token.row };
    }
    if (token.kind === "symbol" && token.value === "-") {
      at++;
      return { kind: "negate", inner: factor() };
    }
    if (token.kind === "symbol" && token.value === "(") {
      at++;
      const inner = sum();
      expect(")");
      return inner;
    }
    if (token.kind === "name") {
      at++;
      expect("(");
      const [first, colon, second, close] = rest.slice(at, at + 4);
      if (first?.kind === "cell" && colon?.kind === "symbol" && colon.value === ":" && second?.kind === "cell" && close?.kind === "symbol" && close.value === ")") {
        at += 4;
        return {
          kind: "aggregate",
          name: token.value,
          from: { col: Math.min(first.col, second.col), row: Math.min(first.row, second.row) },
          to: { col: Math.max(first.col, second.col), row: Math.max(first.row, second.row) },
        };
      }
      throw new Failed("malformed");
    }
    throw new Failed("malformed");
  };
  const product = () => {
    let left = factor();
    while (peek()?.kind === "symbol" && (peek().value === "*" || peek().value === "/")) {
      const op = peek().value;
      at++;
      left = { kind: "binary", op, left, right: factor() };
    }
    return left;
  };
  const sum = () => {
    let left = product();
    while (peek()?.kind === "symbol" && (peek().value === "+" || peek().value === "-")) {
      const op = peek().value;
      at++;
      left = { kind: "binary", op, left, right: product() };
    }
    return left;
  };
  const tree = sum();
  if (at !== rest.length) throw new Failed("malformed");
  return tree;
};

export const shift = (raw, offset) => {
  if (!raw.startsWith("=")) return raw;
  let found;
  try {
    found = tokens(raw.slice(1));
  } catch (error) {
    if (error instanceof Failed) return raw;
    throw error;
  }
  return (
    "=" +
    found
      .map((token) =>
        token.kind === "number" ? String(token.value) : token.kind === "cell" ? address(token.row + offset, token.col) : token.value,
      )
      .join("")
  );
};

export const evaluate = (raws) => {
  const states = new Array(raws.length).fill(undefined);
  const visiting = {};
  const cell = (row, col) => {
    if (!(row >= 0 && row < rows && col >= 0 && col < columns)) return { kind: "failure", failure: "range" };
    const index = row * columns + col;
    const state = states[index];
    if (state === visiting) return { kind: "failure", failure: "cycle" };
    if (state !== undefined) return state;
    states[index] = visiting;
    const value = compute(raws[index]);
    states[index] = value;
    return value;
  };
  const compute = (raw) => {
    const text = raw.trim();
    if (text === "") return { kind: "blank" };
    if (text[0] === "=") {
      try {
        return { kind: "amount", value: number(parse(text.slice(1))) };
      } catch (error) {
        if (error instanceof Failed) return { kind: "failure", failure: error.failure };
        throw error;
      }
    }
    const value = Number(text);
    return Number.isNaN(value) ? { kind: "text", value: text } : { kind: "amount", value };
  };
  const amount = (row, col) => {
    const value = cell(row, col);
    if (value.kind === "amount") return value.value;
    if (value.kind === "blank") return 0;
    if (value.kind === "text") throw new Failed("value");
    throw new Failed(value.failure);
  };
  const number = (expr) => {
    switch (expr.kind) {
      case "literal":
        return expr.value;
      case "reference":
        return amount(expr.row, expr.col);
      case "negate":
        return -number(expr.inner);
      case "binary": {
        const left = number(expr.left);
        const right = number(expr.right);
        if (expr.op === "+") return left + right;
        if (expr.op === "-") return left - right;
        if (expr.op === "*") return left * right;
        if (right === 0) throw new Failed("division");
        return left / right;
      }
      case "aggregate": {
        const values = [];
        for (let row = expr.from.row; row <= expr.to.row; row++)
          for (let col = expr.from.col; col <= expr.to.col; col++) {
            const value = cell(row, col);
            if (value.kind === "amount") values.unshift(value.value);
            else if (value.kind === "failure") throw new Failed(value.failure);
          }
        const total = () => values.reduce((sum, value) => sum + value, 0);
        if (expr.name === "SUM") return total();
        if (expr.name === "COUNT") return values.length;
        if (["AVG", "MIN", "MAX"].includes(expr.name) && values.length === 0) return 0;
        if (expr.name === "AVG") return total() / values.length;
        if (expr.name === "MIN") return values.reduce((low, value) => Math.min(low, value));
        if (expr.name === "MAX") return values.reduce((high, value) => Math.max(high, value));
        throw new Failed("malformed");
      }
    }
  };
  return raws.map((_, index) => cell(Math.floor(index / columns), index % columns));
};

const failures = { malformed: "#ERR", cycle: "#CYCLE", division: "#DIV/0!", range: "#REF!", value: "#VALUE!" };

export const display = (value) => {
  switch (value.kind) {
    case "blank":
      return "";
    case "text":
      return value.value;
    case "amount":
      return Number.isInteger(value.value) ? String(value.value) : value.value.toFixed(2);
    case "failure":
      return failures[value.failure];
  }
};
