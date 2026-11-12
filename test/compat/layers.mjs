// JavaScript components for the mixed laws, written once against whichever React they are given:
// npm's for the reason-react build, melact.compat's for the Melact build.
export function layers(React, ReactDOM) {
  const h = React.createElement;
  const Theme = React.createContext("none");

  function Box({ name, log, stop, children }) {
    React.useLayoutEffect(() => {
      log("layout js:" + name);
      return () => log("layout cleanup js:" + name);
    });
    React.useEffect(() => {
      log("effect js:" + name);
      return () => log("effect cleanup js:" + name);
    });
    return h(
      "div",
      {
        className: "js",
        title: name,
        onClick: (event) => {
          log("click js:" + name);
          if (stop === name) event.stopPropagation();
        },
        onClickCapture: () => log("capture js:" + name),
      },
      children,
    );
  }

  function Provide({ value, children }) {
    return h(Theme.Provider, { value }, children);
  }

  function Show({ name }) {
    const value = React.useContext(Theme);
    return h("span", { className: "theme", title: name }, value);
  }

  function Portal({ container, children }) {
    return ReactDOM.createPortal(children, container);
  }

  class Tally extends React.Component {
    constructor(props) {
      super(props);
      this.state = { count: 0 };
    }
    componentDidMount() {
      this.props.log("mount class:" + this.props.name);
    }
    componentDidUpdate() {
      this.props.log("update class:" + this.props.name);
    }
    componentWillUnmount() {
      this.props.log("unmount class:" + this.props.name);
    }
    render() {
      return h(
        "div",
        { className: "tally", title: this.props.name, onClick: () => this.setState((state) => ({ count: state.count + 1 })) },
        String(this.state.count),
        this.props.children,
      );
    }
  }

  function RowFrame({ frame, children }) {
    return h("div", { style: frame.style, ...frame.ariaAttributes, className: "frame" }, children);
  }

  function Counted({ name, value, log, children }) {
    log("render " + name);
    return h("div", { className: "counted", title: name }, String(value), children);
  }

  return { Box, Provide, Show, Portal, Tally, RowFrame, Counted };
}
