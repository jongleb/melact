// The app's 1,000 items. bench/app/src/app.mlx builds the same items with the same formulas,
// and the harness checks every page against a model built from this module.
export const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
export const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "grey", "white", "black", "orange"];
export const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];
export const categories = ["Backlog", "Doing", "Review", "Done"];
export const owners = ["Ada", "Brian", "Chloe", "Dmitri", "Elena", "Farid", "Grace", "Hiro"];

export const items = Array.from({ length: 1000 }, (_, index) => {
  const id = index + 1;
  return {
    id,
    title: `${adjectives[(index * 7 + 3) % 25]} ${colours[(index * 5 + 1) % 11]} ${nouns[(index * 3 + 2) % 13]}`,
    category: categories[index % 4],
    owner: owners[(index * 13) % 8],
    points: ((index * 37) % 13) + 1,
    note: `Item ${id} needs ${((index * 37) % 13) + 1} points of work from ${owners[(index * 13) % 8]}.`,
  };
});

export const matches = (query) => (item) => item.title.includes(query);
