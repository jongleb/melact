<script>
  import { seed, next, sentence } from "../../common/svelte/classic.js";

  const generator = seed(7);
  const initial = Array.from({ length: 5000 }, (_, index) => {
    const completed = next(generator, 3) === 0;
    return { id: index + 1, title: sentence(generator, 4), completed };
  });

  let todos = $state(initial);
  let filter = $state("all");
  let draft = $state("");
  let editing = $state(null);
  let text = $state("");

  const shown = $derived(filter === "all" ? todos : todos.filter((todo) => todo.completed === (filter === "completed")));
  const active = $derived(todos.filter((todo) => !todo.completed).length);
  const completed = $derived(todos.length - active);

  const add = (event) => {
    if (event.key !== "Enter") return;
    const title = draft.trim();
    if (title === "") return;
    const id = todos.reduce((top, todo) => Math.max(top, todo.id), 0) + 1;
    todos.push({ id, title, completed: false });
    draft = "";
  };

  const destroy = (id) => {
    todos = todos.filter((todo) => todo.id !== id);
  };

  const toggleAll = () => {
    const done = active !== 0;
    for (const todo of todos) todo.completed = done;
  };

  const edit = (todo) => {
    text = todo.title;
    editing = todo.id;
  };

  const finish = () => {
    if (editing === null) return;
    const id = editing;
    editing = null;
    const title = text.trim();
    if (title === "") destroy(id);
    else todos.find((todo) => todo.id === id).title = title;
  };

  const show = (event, target) => {
    event.preventDefault();
    filter = target;
  };

  const focus = (node) => {
    node.focus();
  };
</script>

<section class="todoapp"><header class="header"><h1>todos</h1><input
      class="new-todo"
      placeholder="What needs to be done?"
      bind:value={draft}
      onkeydown={add}
    /></header><section class="main"><input
      id="toggle-all"
      class="toggle-all"
      type="checkbox"
      checked={active === 0}
      onchange={toggleAll}
    /><label for="toggle-all">Mark all as complete</label><ul class="todo-list">
      {#each shown as todo (todo.id)}
        <li class={(todo.completed ? "completed" : "") + " " + (editing === todo.id ? "editing" : "")}><div class="view"><input
              class="toggle"
              type="checkbox"
              checked={todo.completed}
              onchange={() => (todo.completed = !todo.completed)}
            /><label ondblclick={() => edit(todo)}>{todo.title}</label><button
              class="destroy"
              onclick={() => destroy(todo.id)}
            ></button></div>{#if editing === todo.id}<input
              class="edit"
              bind:value={text}
              use:focus
              onblur={finish}
              onkeydown={(event) => {
                if (event.key === "Enter") finish();
                else if (event.key === "Escape") editing = null;
              }}
            />{/if}</li>
      {/each}
    </ul></section><footer class="footer"><span class="todo-count"><strong>{active}</strong>{active === 1 ? " item left" : " items left"}</span><ul
      class="filters"
    ><li><a href="#" class={filter === "all" ? "selected" : ""} onclick={(event) => show(event, "all")}>All</a></li><li
      ><a href="#" class={filter === "active" ? "selected" : ""} onclick={(event) => show(event, "active")}>Active</a></li><li
      ><a href="#" class={filter === "completed" ? "selected" : ""} onclick={(event) => show(event, "completed")}
          >Completed</a
        ></li></ul>{#if completed !== 0}<button class="clear-completed" onclick={() => (todos = todos.filter((todo) => !todo.completed))}
        >Clear completed</button
      >{/if}</footer></section>
