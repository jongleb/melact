import * as React from "react";
import * as ReactDOM from "react-dom";
import { layers } from "../layers.mjs";

export const { Box, Provide, Show, Portal, Tally, RowFrame } = layers(React.default ?? React, ReactDOM.default ?? ReactDOM);
