// npm's "react", implemented on Melact's runtime. An app aliases "react" to this file.
import * as Api from "./api.mjs";
import * as Element from "./element.mjs";
import * as Hooks from "./hooks.mjs";
import * as Render from "./render.mjs";

const rest = (args, from) => Array.prototype.slice.call(args, from);

export const version = Api.version;
export const Fragment = Element.Mark.fragment;
export const StrictMode = Element.Mark.strict_mode;
export const Profiler = Element.Mark.profiler;
export const Suspense = Element.Mark.suspense;

export function createElement(type, config) {
  return Element.create(type, config, rest(arguments, 2));
}
export function cloneElement(element, config) {
  return Element.clone(element, config, rest(arguments, 2));
}
export const isValidElement = (value) => Api.isValidElement(value);
export const createRef = () => Api.createRef();
export const createContext = (value) => Render.context(value);
export const forwardRef = (render) => Api.forwardRef(render);
export const memo = (type, compare) => Api.memo(type, compare);
export const lazy = (load) => Api.lazy_(load);

export const Children = {
  map: (children, fn, context) => Api.childrenMap(children, fn, context),
  forEach: (children, fn, context) => Api.childrenForEach(children, fn, context),
  count: (children) => Api.childrenCount(children),
  toArray: (children) => Api.childrenToArray(children),
  only: (children) => Api.childrenOnly(children),
};

const quiet = { isMounted: () => false, enqueueSetState() {}, enqueueReplaceState() {}, enqueueForceUpdate() {} };

export function Component(props, context, updater) {
  this.props = props;
  this.context = context;
  this.refs = {};
  this.updater = updater || quiet;
}
Component.prototype.isReactComponent = {};
Component.prototype.setState = function (partial, callback) {
  this.updater.enqueueSetState(this, partial, callback, "setState");
};
Component.prototype.forceUpdate = function (callback) {
  this.updater.enqueueForceUpdate(this, callback, "forceUpdate");
};

export function PureComponent(props, context, updater) {
  Component.call(this, props, context, updater);
}
PureComponent.prototype = Object.create(Component.prototype);
PureComponent.prototype.constructor = PureComponent;
PureComponent.prototype.isPureReactComponent = true;

export const useState = (initial) => Hooks.useState(initial);
export const useReducer = (reducer, initial, init) => Hooks.useReducer(reducer, initial, init);
export const useEffect = (create, deps) => Hooks.useEffect(create, deps);
export const useLayoutEffect = (create, deps) => Hooks.useLayoutEffect(create, deps);
export const useInsertionEffect = (create, deps) => Hooks.useInsertionEffect(create, deps);
export const useMemo = (compute, deps) => Hooks.useMemo(compute, deps);
export const useCallback = (callback, deps) => Hooks.useCallback(callback, deps);
export const useRef = (initial) => Hooks.useRef(initial);
export const useContext = (context) => Render.read(context);
export const useId = () => Hooks.useId();
export const useImperativeHandle = (ref, create, deps) => Hooks.useImperativeHandle(ref, create, deps);
export const useSyncExternalStore = (subscribe, snapshot, server) => Hooks.useSyncExternalStore(subscribe, snapshot, server);
export const useDebugValue = () => {};
export const useTransition = () => Hooks.useTransition();
export const startTransition = (run) => Hooks.startTransition(run);
export const useDeferredValue = (value) => value;

export function act(callback) {
  const result = callback();
  if (result && typeof result.then === "function")
    return result.then((value) => {
      Api.settled();
      return value;
    });
  Api.settled();
  return { then: (resolve) => resolve(result) };
}

const React = {
  version, Fragment, StrictMode, Profiler, Suspense, createElement, cloneElement, isValidElement, createRef,
  createContext, forwardRef, memo, lazy, Children, Component, PureComponent, useState, useReducer, useEffect,
  useLayoutEffect, useInsertionEffect, useMemo, useCallback, useRef, useContext, useId, useImperativeHandle,
  useSyncExternalStore, useDebugValue, useTransition, startTransition, useDeferredValue, act,
};
export default React;
