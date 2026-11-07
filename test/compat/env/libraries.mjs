// The libraries of the compat laws on melact.compat: every import here resolves in this folder's
// node_modules, where "react" and "react-dom" are melact.compat's.
import * as React from "react";
import * as ReactDOM from "react-dom";
import * as Client from "react-dom/client";
import Select from "react-select";
import * as Popover from "@radix-ui/react-popover";
import { List } from "react-window";

export const shim = { name: "shim", React: React.default ?? React, ReactDOM, Client, Select, Popover, List };
