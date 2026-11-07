export default [
  { name: "type 'ec' one key per frame", run: () => __h.type("#search", "ec") },
  { name: "erase 2 keys one per frame", run: () => __h.erase("#search", 2) },
  { name: "type 'track 1' one key per frame", run: () => __h.type("#search", "track 1") },
  { name: "erase 7 keys one per frame", run: () => __h.erase("#search", 7) },
];
