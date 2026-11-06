import { memo, useReducer } from "react";

const reducer = (state, action) => {
  switch (action.type) {
    case "increment":
      return { ...state, count: state.count + 1 };
    case "decrement":
      return { ...state, count: state.count - 1 };
    case "select":
      return { ...state, selected: action.id };
    case "remove":
      return { ...state, rows: state.rows.filter((row) => row.id !== action.id) };
    default:
      return state;
  }
};

const Row = memo(({ row, selected, dispatch }) => (
  <tr className={selected ? "danger" : ""}>
    <td className="col-md-1">{row.id}</td>
    <td className="col-md-4">
      <a onClick={() => dispatch({ type: "select", id: row.id })}>{row.label}</a>
    </td>
    <td className="col-md-1">
      <a onClick={() => dispatch({ type: "remove", id: row.id })}>
        <span className="glyphicon glyphicon-remove" aria-hidden="true" />
      </a>
    </td>
    <td className="col-md-6" />
  </tr>
));

export const App = ({ rows }) => {
  const [state, dispatch] = useReducer(reducer, { count: 0, rows, selected: 0 });
  return (
    <div className="container">
      <div className="jumbotron">
        <h1>Server-rendered rows</h1>
        <div className="counter">
          <button type="button" id="decrement" onClick={() => dispatch({ type: "decrement" })}>-</button>
          <output id="count">{state.count}</output>
          <button type="button" id="increment" onClick={() => dispatch({ type: "increment" })}>+</button>
        </div>
      </div>
      <table className="table table-hover table-striped test-data">
        <tbody>
          {state.rows.map((row) => (
            <Row key={row.id} row={row} selected={state.selected === row.id} dispatch={dispatch} />
          ))}
        </tbody>
      </table>
    </div>
  );
};
