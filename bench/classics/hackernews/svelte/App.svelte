<script>
  import Comment from "./Comment.svelte";
  import { perPage, user, timeAgo, stories as initial, threadOf } from "./data.js";

  let stories = $state(initial);
  let route = $state({ page: 0, item: null });
  let thread = $state.raw([]);
  let draft = $state("");
  let command = $state(null);

  const labels = ["new", "past", "comments", "ask", "show", "jobs", "submit"];
  const shown = $derived(stories.slice(0, (route.page + 1) * perPage));
  const opened = $derived(route.item === null ? null : stories.find((story) => story.id === route.item));

  const open = (story) => {
    route = { page: 0, item: story.id };
    thread = threadOf(story);
    draft = "";
    command = null;
  };
  const vote = (story, voted) => {
    story.voted = voted;
    story.points += voted ? 1 : -1;
  };
  const fold = (folded) => {
    command = { folded, generation: (command?.generation ?? 0) + 1 };
  };
  const submit = (event) => {
    event.preventDefault();
    thread = [{ id: Math.imul(route.item, 10), by: user, age: 0, text: draft, kids: [] }, ...thread];
    draft = "";
  };
</script>

{#snippet rows(story, rank)}<tr class="athing"><td class="rank">{rank + "."}</td><td class="votelinks"><a
        class={story.voted ? "votearrow nosee" : "votearrow"}
        title="upvote"
        onclick={() => {
          if (!story.voted) vote(story, true);
        }}
      ></a></td
    ><td class="title"
      >{#if story.domain !== null}<a class="titlelink" href={"https://" + story.domain + "/" + story.id}>{story.title}</a><span class="sitebit"
          >{" (" + story.domain + ")"}</span
        >{:else}<a class="titlelink" onclick={() => open(story)}>{story.title}</a>{/if}</td
    ></tr
  ><tr><td colspan="2"></td><td class="subtext"><span class="subline"><span class="score">{story.points + " points"}</span>{" by "}<a
          class="hnuser">{story.by}</a
        >{" "}<span class="age" title={String(story.age)}>{timeAgo(story.age)}</span>{#if story.voted}{" | "}<a
            class="unvote"
            onclick={() => vote(story, false)}>unvote</a
          >{/if}{" | "}<a class="hide-link" onclick={() => (stories = stories.filter((other) => other.id !== story.id))}>hide</a
        >{" | "}<a class="comments-link" onclick={() => open(story)}
          >{story.descendants === 0 ? "discuss" : story.descendants === 1 ? "1 comment" : story.descendants + "Â comments"}</a
        ></span
      ></td
    ></tr
  ><tr class="spacer"></tr>{/snippet}

<center><div class="hn"><table class="hn-header"><tbody><tr><td class="logo"><span class="y">Y</span></td><td class="pagetop"
            ><b class="hnname"><a class="hn-home" onclick={() => (route = { page: 0, item: null })}>Hacker News</a></b
            >{#each labels as label (label)}{" | "}<a>{label}</a>{/each}</td
          ><td class="pagetop user"><a>{user}</a></td></tr
        ></tbody
      ></table
    >{#if route.item === null}<table class="itemlist"><tbody
          >{#each shown as story, index (story.id)}{@render rows(story, index + 1)}{/each}{#if stories.length > shown.length}<tr
              class="morespace"
              ><td colspan="2"></td><td><a class="morelink" onclick={() => (route = { page: route.page + 1, item: null })}>More</a></td></tr
            >{/if}</tbody
        ></table
      >{:else if opened}<div class="item-page"><table class="fatitem"><tbody
            >{@render rows(opened, 0)}<tr><td colspan="2"></td><td
                ><form class="reply-form" onsubmit={submit}><textarea class="reply-input" rows="4" cols="60" bind:value={draft}></textarea
                  ><br /><button class="reply-submit" type="submit">reply</button></form
                ></td
              ></tr
            ></tbody
          ></table
        ><div class="comment-tree"><div class="tree-tools"><a id="collapse-top" onclick={() => fold(true)}>collapse all top-level</a
            >{" | "}<a id="expand-top" onclick={() => fold(false)}>expand all top-level</a></div
          >{#each thread as comment (comment.id)}<Comment {comment} {command} />{/each}</div
        ></div
      >{:else}<p>No such item.</p>{/if}<div class="footer">Guidelines | FAQ | Lists | API | Security | Legal | Apply to YC | Contact</div
    ></div
  ></center>
