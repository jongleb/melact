<script>
  import Comment from "./Comment.svelte";
  import { timeAgo, user } from "./data.js";

  let { comment, command } = $props();
  let folded = $state(false);
  let reply = $state(null);
  let added = $state.raw([]);

  $effect(() => {
    if (command !== null) folded = command.folded;
  });

  const count = (comment) => comment.kids.reduce((total, kid) => total + count(kid), 1);

  const submit = (event) => {
    event.preventDefault();
    added = [{ id: (Math.imul(comment.id, 1000) + added.length + 1) | 0, by: user, age: 0, text: reply, kids: [] }, ...added];
    reply = null;
  };
</script>

<div class="comtr" id={String(comment.id)}><div class="comhead"><a class="hnuser">{comment.by}</a> <span class="age">{timeAgo(comment.age)}</span> <a
      class={folded ? "togg collapsed" : "togg"}
      onclick={() => (folded = !folded)}>{folded ? "[" + (count(comment) + added.length) + " more]" : "[â\u0080\u0093]"}</a
    ></div
  >{#if !folded}<div class="comment"><div class="commtext">{comment.text}</div>{#if reply === null}<div class="reply"
          ><a class="reply-link" onclick={() => (reply = "")}>reply</a></div
        >{:else}<form class="reply-form" onsubmit={submit}><textarea class="reply-input" rows="4" cols="60" bind:value={reply}></textarea
          ><br /><button class="reply-submit" type="submit">reply</button></form
        >{/if}<div class="kids">{#each [...added, ...comment.kids] as kid (kid.id)}<Comment comment={kid} command={null} />{/each}</div></div
    >{/if}</div>
