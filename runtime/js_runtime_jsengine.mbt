///|
/// JavaScript Runtime - js_engine implementation with DOM bindings
///
/// Uses dowdiness/js_engine (pure MoonBit JavaScript interpreter)
/// for JavaScript execution on the native target.

///|
const CRATER_NODE_ID_KEY : String = "__crater_nid"

///|
priv struct JsEngineRuntime {
  _unused : Int
}

///|
let jsengine_runtime : JsEngineRuntime = { _unused: 0 }

///|
fn allocate_runtime_context_id() -> Int {
  0
}

///|
fn default_js_runtime() -> &JsRuntime {
  jsengine_runtime as &JsRuntime
}

///|
impl JsRuntime for JsEngineRuntime with fn init(self : JsEngineRuntime) -> Unit {
  let _ = self
}

///|
impl JsRuntime for JsEngineRuntime with fn execute(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = (self, context_id, async_mode)
  try {
    let interp = @interpreter.new_interpreter()
    inject_dom_bindings(interp.global, interp.realm_state, dom)
    let prog = @parser.parse(code)
    let result = interp.run(prog.stmts)
    interp.run_microtasks()
    interp.run_timers()
    JsResult::new(result.to_string(), interp.host.output, true)
  } catch {
    e => raise JsError::ExecutionError(describe_js_engine_error(e))
  }
}

// ═══════════════════════════════════════════════
// HTML → DomTree
// ═══════════════════════════════════════════════

///|
fn fragment_to_domtree(dom : @dom.DomTree, html : String) -> Array[@dom.NodeId] {
  if html.length() == 0 {
    return []
  }
  let root = @html_lib.parse_fragment(html)
  let result : Array[@dom.NodeId] = []
  let mut found_body = false
  for node in root.children {
    match node {
      @html_lib.Node::Element(el) =>
        if el.tag == "body" {
          for child in el.children {
            match convert_html_node(dom, child) {
              Some(nid) => result.push(nid)
              None => ()
            }
          }
          found_body = true
        }
      _ => ()
    }
  }
  if !found_body {
    // parse_fragment may not wrap in body (e.g. plain text fragments)
    for child in root.children {
      match convert_html_node(dom, child) {
        Some(nid) => result.push(nid)
        None => ()
      }
    }
  }
  result
}

///|
fn convert_html_node(dom : @dom.DomTree, node : @html_lib.Node) -> @dom.NodeId? {
  match node {
    @html_lib.Node::Text(text) => Some(dom.create_text(text))
    @html_lib.Node::Element(el) => {
      let nid = dom.create_element(el.tag)
      for key in el.attributes.keys() {
        match el.attributes.get(key) {
          Some(value) => { let _ = dom.set_attribute(nid, key, value) }
          None => ()
        }
      }
      for child in el.children {
        match convert_html_node(dom, child) {
          Some(cnid) => { let _ = dom.append_child(nid, cnid) }
          None => ()
        }
      }
      Some(nid)
    }
  }
}

///|
fn clear_children(dom : @dom.DomTree, node_id : @dom.NodeId) -> Unit {
  match dom.get_children(node_id) {
    Ok(children) =>
      for child in children {
        let _ = dom.remove_child(node_id, child)
      }
    Err(_) => ()
  }
}

// ═══════════════════════════════════════════════
// Error helpers
// ═══════════════════════════════════════════════

///|
/// Raise a JS TypeError with the given message, suitable for native callbacks.
fn raise_dom_error(msg : String) -> @runtime.Value raise Error {
  raise @js_errors.TypeError(message=msg)
}

///|
/// Map a DomTree CoreError to a JS TypeError message and raise it.
fn expect_dom_ok(result : Result[Unit, @dom.CoreError]) -> Unit raise Error {
  match result {
    Ok(_) => ()
    Err(e) => {
      let _ = raise_dom_error("DOM error: " + e.to_string())
    }
  }
}

// ═══════════════════════════════════════════════
// Document bindings
// ═══════════════════════════════════════════════

///|
fn inject_dom_bindings(
  env : @interpreter.Environment,
  realm_state : @runtime.RealmState,
  dom : @dom.DomTree,
) -> Unit {
  let doc_id = dom.get_document()

  // ── document.querySelector(selector) ──
  let query_selector = @runtime.make_method_func(
    name="querySelector", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let sel = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.query_selector(doc_id, sel) {
        Ok(Some(nid)) => wrap_element(dom, nid, realm_state)
        Ok(None) => @runtime.Null
        Err(_) => @runtime.Null
      }
    },
  )

  // ── document.getElementById(id) ──
  let get_element_by_id = @runtime.make_method_func(
    name="getElementById", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let id = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.query_selector(doc_id, "#" + id) {
        Ok(Some(nid)) => wrap_element(dom, nid, realm_state)
        Ok(None) => @runtime.Null
        Err(_) => @runtime.Null
      }
    },
  )

  // ── document.createElement(tag) ──
  let create_element = @runtime.make_method_func(
    name="createElement", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let tag = if args.length() > 0 {
        args[0].to_string()
      } else {
        return raise_dom_error("createElement: tag name required")
      }
      wrap_element(dom, dom.create_element(tag), realm_state)
    },
  )

  // ── document.title getter ──
  let title_getter = @runtime.make_method_func(
    name="title",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.query_selector(doc_id, "title") {
        Ok(Some(tid)) =>
          match dom.get_text_content(tid) {
            Ok(text) => @runtime.Value::String_(text)
            _ => @runtime.Value::String_("")
          }
        _ => @runtime.Value::String_("")
      }
    },
  )

  // ── document.body getter ──
  let body_getter = @runtime.make_method_func(
    name="body",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.query_selector(doc_id, "body") {
        Ok(Some(nid)) => wrap_element(dom, nid, realm_state)
        _ => @runtime.Null
      }
    },
  )

  // ── Build document object ──
  let doc_props : Map[String, @runtime.Value] = {}
  let doc_descs : Map[String, @runtime.PropDescriptor] = {}
  doc_descs["title"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(title_getter), setter: None, is_accessor: false,
  }
  doc_descs["body"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(body_getter), setter: None, is_accessor: false,
  }

  let document = @runtime.make_object(
    doc_props, @runtime.Null, None, "HTMLDocument", doc_descs, true,
  )
  match document {
    @runtime.Value::Object(data) => {
      @runtime.install_builtin_method(data, "querySelector", query_selector)
      @runtime.install_builtin_method(data, "getElementById", get_element_by_id)
      @runtime.install_builtin_method(data, "createElement", create_element)
    }
    _ => ()
  }

  // ── window: a separate object with `document` property ──
  let win_props : Map[String, @runtime.Value] = {}
  win_props["document"] = document
  let win_descs : Map[String, @runtime.PropDescriptor] = {}
  let window = @runtime.make_object(
    win_props, @runtime.Null, None, "Window", win_descs, true,
  )

  // Register globals
  env.def_builtin("document", document)
  // `window` is a separate object (not the same as global this)
  env.def_builtin("window", window)
  // `self` points to `window` per spec
  env.def_builtin("self", window)
}

// ═══════════════════════════════════════════════
// Element wrapper
// ═══════════════════════════════════════════════

///|
fn wrap_element(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  realm_state : @runtime.RealmState,
) -> @runtime.Value {
  let nid_int = node_id.to_int()

  // ── textContent getter ──
  let text_content_getter = @runtime.make_method_func(
    name="textContent",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_text_content(node_id) {
        Ok(text) => @runtime.Value::String_(text)
        Err(_) => @runtime.Value::String_("")
      }
    },
  )

  // ── textContent setter ──
  let text_content_setter = @runtime.make_method_func(
    name="textContent",
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let value = if args.length() > 0 {
        args[0].to_string()
      } else {
        ""
      }
      clear_children(dom, node_id)
      let text_nid = dom.create_text(value)
      expect_dom_ok(dom.append_child(node_id, text_nid))
      @runtime.Undefined
    },
  )

  // ── id getter ──
  let id_getter = @runtime.make_method_func(
    name="id",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_attribute(node_id, "id") {
        Ok(Some(val)) => @runtime.Value::String_(val)
        _ => @runtime.Value::String_("")
      }
    },
  )

  // ── tagName getter ──
  let tag_name_getter = @runtime.make_method_func(
    name="tagName",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_tag_name(node_id) {
        Ok(name) => @runtime.Value::String_(name.to_upper())
        Err(_) => @runtime.Value::String_("")
      }
    },
  )

  // ── className getter/setter ──
  let class_name_getter = @runtime.make_method_func(
    name="className",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) => @runtime.Value::String_(val)
        _ => @runtime.Value::String_("")
      }
    },
  )
  let class_name_setter = @runtime.make_method_func(
    name="className",
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let value = if args.length() > 0 {
        args[0].to_string()
      } else {
        ""
      }
      expect_dom_ok(dom.set_attribute(node_id, "class", value))
      @runtime.Undefined
    },
  )

  // ── innerHTML getter ──
  let inner_html_getter = @runtime.make_method_func(
    name="innerHTML",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      let buf = StringBuilder::new()
      match dom.get_children(node_id) {
        Ok(children) =>
          for child in children {
            serialize_node_to_html_in_context(dom, child, buf, None)
          }
        Err(_) => ()
      }
      @runtime.Value::String_(buf.to_string())
    },
  )

  // ── innerHTML setter ──
  let inner_html_setter = @runtime.make_method_func(
    name="innerHTML",
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let html = if args.length() > 0 {
        args[0].to_string()
      } else {
        ""
      }
      clear_children(dom, node_id)
      let new_nodes = fragment_to_domtree(dom, html)
      for child in new_nodes {
        expect_dom_ok(dom.append_child(node_id, child))
      }
      @runtime.Undefined
    },
  )

  // ── style getter ──
  let style_getter = @runtime.make_method_func(
    name="style",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_attribute(node_id, "style") {
        Ok(Some(s)) => @runtime.Value::String_(s)
        _ => @runtime.Value::String_("")
      }
    },
  )

  // ── classList object ──
  let class_list_contains = @runtime.make_method_func(
    name="contains", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) =>
          @runtime.Value::Bool(val.split(" ").any(fn(c) { c == cls }))
        _ => @runtime.Value::Bool(false)
      }
    },
  )
  let class_list_add = @runtime.make_method_func(
    name="add", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) => {
          if !val.split(" ").any(fn(c) { c == cls }) {
            expect_dom_ok(dom.set_attribute(node_id, "class", val + " " + cls))
          }
        }
        _ => { expect_dom_ok(dom.set_attribute(node_id, "class", cls)) }
      }
      @runtime.Undefined
    },
  )
  let class_list_remove = @runtime.make_method_func(
    name="remove", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) => {
          expect_dom_ok(
            dom.set_attribute(
              node_id, "class",
              val.split(" ").filter(fn(c) { c != cls }).join(" "),
            ),
          )
        }
        _ => ()
      }
      @runtime.Undefined
    },
  )

  let class_list_props : Map[String, @runtime.Value] = {}
  let class_list_descs : Map[String, @runtime.PropDescriptor] = {}
  let class_list = @runtime.make_object(
    class_list_props, @runtime.Null, None, "DOMTokenList", class_list_descs, true,
  )
  match class_list {
    @runtime.Value::Object(data) => {
      @runtime.install_builtin_method(data, "contains", class_list_contains)
      @runtime.install_builtin_method(data, "add", class_list_add)
      @runtime.install_builtin_method(data, "remove", class_list_remove)
    }
    _ => ()
  }

  // ── setAttribute(name, value) ──
  let set_attr = @runtime.make_method_func(
    name="setAttribute", length=2,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let name = if args.length() > 0 { args[0].to_string() } else { "" }
      let value = if args.length() > 1 { args[1].to_string() } else { "" }
      expect_dom_ok(dom.set_attribute(node_id, name, value))
      @runtime.Undefined
    },
  )

  // ── getAttribute(name) ──
  let get_attr = @runtime.make_method_func(
    name="getAttribute", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let name = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, name) {
        Ok(Some(val)) => @runtime.Value::String_(val)
        _ => @runtime.Null
      }
    },
  )

  // ── appendChild(child) ──
  let append_child = @runtime.make_method_func(
    name="appendChild", length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      if args.length() == 0 {
        return raise_dom_error("appendChild: child element required")
      }
      let child_val = args[0]
      match extract_node_id(child_val) {
        Some(cnid) => {
          expect_dom_ok(dom.append_child(node_id, cnid))
          child_val
        }
        None => raise_dom_error("appendChild: invalid child element")
      }
    },
  )

  // ── Build the Element JS object ──
  let props : Map[String, @runtime.Value] = {}
  props["classList"] = class_list
  let descs : Map[String, @runtime.PropDescriptor] = {}

  descs["textContent"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(text_content_getter),
    setter: Some(text_content_setter),
    is_accessor: true,
  }
  descs["id"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(id_getter), setter: None, is_accessor: false,
  }
  descs["tagName"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(tag_name_getter), setter: None, is_accessor: false,
  }
  descs["className"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(class_name_getter),
    setter: Some(class_name_setter),
    is_accessor: true,
  }
  descs["innerHTML"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(inner_html_getter),
    setter: Some(inner_html_setter),
    is_accessor: true,
  }
  descs["style"] = {
    writable: true, enumerable: true, configurable: true,
    getter: Some(style_getter), setter: None, is_accessor: false,
  }

  let el = @runtime.make_object(
    props, @runtime.Null, None, "Element", descs, true,
  )

  match el {
    @runtime.Value::Object(data) => {
      @runtime.install_builtin_method(data, "setAttribute", set_attr)
      @runtime.install_builtin_method(data, "getAttribute", get_attr)
      @runtime.install_builtin_method(data, "appendChild", append_child)
      data.bag.properties[CRATER_NODE_ID_KEY] = @runtime.Value::Number(
        nid_int.to_double(),
      )
    }
    _ => ()
  }
  el
}

///|
fn extract_node_id(val : @runtime.Value) -> @dom.NodeId? {
  match val {
    @runtime.Value::Object(data) =>
      match data.bag.properties.get(CRATER_NODE_ID_KEY) {
        Some(@runtime.Value::Number(n)) =>
          Some(@dom.NodeId::from_int(n.to_int()))
        _ => None
      }
    _ => None
  }
}

// ═══════════════════════════════════════════════
// JsRuntime trait
// ═══════════════════════════════════════════════

///|
impl JsRuntime for JsEngineRuntime with fn tick(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom)
  JsResult::new("false", [], true)
}

///|
pub fn init_js_runtime() -> Unit {
  jsengine_runtime.init()
}

///|
fn describe_js_engine_error(err : Error) -> String {
  @js_errors.name_message_if_js_error(err)
  .map_or(err.to_string(), fn(pair) {
    let (name, msg) = pair
    name + ": " + msg
  })
}
