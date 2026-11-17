// The stories, users and threads of the OCaml builds, made by the same generator in the same order.
import { seed, next, pick, sentence, words } from "../../common/svelte/classic.js";

export const perPage = 300;
export const user = "pg";

const capitalized = (text) => text.charAt(0).toUpperCase() + text.slice(1);

const userSeed = seed(3);
export const users = Array.from({ length: 120 }, (_, index) => pick(userSeed, words) + index * 7);

export const timeAgo = (minutes) =>
  minutes === 1 ? "1 minute ago"
  : minutes < 60 ? minutes + " minutes ago"
  : minutes < 120 ? "1 hour ago"
  : minutes < 1440 ? Math.floor(minutes / 60) + " hours ago"
  : minutes < 2880 ? "1 day ago"
  : Math.floor(minutes / 1440) + " days ago";

const storySeed = seed(1985);
const domains = ["github.com", "nytimes.com", "arxiv.org", "lwn.net", "ocaml.org", "blog.janestreet.com", "medium.com", "acm.org"];
export const stories = Array.from({ length: perPage * 3 }, (_, index) => {
  const words = 4 + next(storySeed, 6);
  const title = capitalized(sentence(storySeed, words));
  const domain = next(storySeed, 6) === 0 ? null : pick(storySeed, domains);
  const points = 1 + next(storySeed, 900);
  const by = pick(storySeed, users);
  const age = 1 + index * 3 + next(storySeed, 50);
  const descendants = next(storySeed, 600);
  return { id: 40000000 + index, title: domain === null ? "Ask HN: " + title : title, domain, points, by, age, descendants, voted: false };
});

export const threadOf = (story) => {
  const generator = seed((story.id % 100000) * 7);
  let budget = 2000;
  let last = story.id;
  const grow = (depth) => {
    const wanted =
      depth === 0 ? 220 : depth === 1 ? next(generator, 7) : depth === 2 ? next(generator, 5) : depth <= 5 ? next(generator, 3) : 0;
    const count = Math.min(wanted, budget);
    budget -= count;
    return Array.from({ length: count }, () => {
      last += 1;
      const id = last;
      const by = pick(generator, users);
      const age = 1 + next(generator, 600);
      const length = 5 + next(generator, 40);
      const text = capitalized(sentence(generator, length)) + ".";
      const kids = grow(depth + 1);
      return { id, by, age, text, kids };
    });
  };
  return grow(0);
};
