<script>
	let { rows } = $props();
	let data = $state.raw(rows);
	let selected = $state.raw(0);
	let count = $state.raw(0);

	const remove = (row) => {
		data = data.filter((other) => other !== row);
	};
</script>

<div class="container"
	><div class="jumbotron"
		><h1>Server-rendered rows</h1
		><div class="counter"
			><button type="button" id="decrement" onclick={() => count--}>-</button
			><output id="count">{count}</output
			><button type="button" id="increment" onclick={() => count++}>+</button
		></div
	></div
	><table class="table table-hover table-striped test-data"
		><tbody
			>{#each data as row (row.id)}<tr class={selected === row.id ? 'danger' : ''}
					><td class="col-md-1">{row.id}</td
					><td class="col-md-4"><a onclick={() => (selected = row.id)}>{row.label}</a></td
					><td class="col-md-1"
						><a onclick={() => remove(row)}
							><span class="glyphicon glyphicon-remove" aria-hidden="true"></span></a
						></td
					><td class="col-md-6"></td
				></tr
			>{/each}</tbody
		></table
	></div>
