// The libraries of the compat laws on npm's React 18, from the repository's node_modules.
import * as React from "react";
import * as ReactDOM from "react-dom";
import * as Client from "react-dom/client";
import Select from "react-select";
import * as Popover from "@radix-ui/react-popover";
import { List } from "react-window";

export const real = { name: "react", React: React.default ?? React, ReactDOM, Client, Select, Popover, List };
