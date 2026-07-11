///|
/// DOM bindings for js_engine — wraps crater DomTree operations
/// as JavaScript-callable native functions.
///
/// Extracted from js_runtime_jsengine.mbt during refactoring.


///|
/// Create a property descriptor for an accessor (getter + optional setter).
fn accessor_desc(
  getter : @runtime.Value,
  setter : @runtime.Value?,
) -> @runtime.PropDescriptor {
  {
    writable: true, enumerable: true, configurable: true,
    getter: Some(getter),
    setter,
    is_accessor: true,
  }
}

///|
/// Create a property descriptor for a read-only data property with getter.
fn data_desc(getter : @runtime.Value) -> @runtime.PropDescriptor {
  {
    writable: true, enumerable: true, configurable: true,
    getter: Some(getter),
    setter: None,
    is_accessor: false,
  }
}
// ═══════════════════════════════════════════════
// Document bindings injection
// ═══════════════════════════════════════════════

///|
/// Inject document and element methods into the interpreter global scope.
fn inject_dom_bindings(
  env : @interpreter.Environment,
  realm_state : @runtime.RealmState,
  dom : @dom.DomTree,
) -> Unit {
  let doc_id = dom.get_document()

  // ── document.querySelector(selector) ──
  let query_selector = @runtime.make_method_func(
    name="querySelector",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
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
    name="getElementById",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
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
    name="createElement",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
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
    (_this, _args) => {
    
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
    (_this, _args) => {
    
      match dom.query_selector(doc_id, "body") {
        Ok(Some(nid)) => wrap_element(dom, nid, realm_state)
        _ => @runtime.Null
      }
    },
  )

  // ── Build document object ──
  let doc_props : Map[String, @runtime.Value] = {}
  let doc_descs : Map[String, @runtime.PropDescriptor] = {}
  doc_descs["title"] = data_desc(title_getter)
  doc_descs["body"] = data_desc(body_getter)

  let document = @runtime.make_object(
    doc_props,
    @runtime.Null,
    None,
    "HTMLDocument",
    doc_descs,
    true,
  )
  match document {
    @runtime.Value::Object(data) => {
      @runtime.install_builtin_method(data, "querySelector", query_selector)
      @runtime.install_builtin_method(data, "getElementById", get_element_by_id)
      @runtime.install_builtin_method(data, "createElement", create_element)
    }
    _ => ()
  }

  // ── window: separate object with `document` property ──
  let win_props : Map[String, @runtime.Value] = {}
  win_props["document"] = document
  let window = @runtime.make_object(
    win_props,
    @runtime.Null,
    None,
    "Window",
    {},
    true,
  )

  env.def_builtin("document", document)
  env.def_builtin("window", window)
  env.def_builtin("self", window)
}

// ═══════════════════════════════════════════════
// Element wrapper
// ═══════════════════════════════════════════════

///|
/// Wrap a crater NodeId as a JS Element object with DOM properties and methods.
fn wrap_element(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  realm_state : @runtime.RealmState,
) -> @runtime.Value {
  let nid_int = node_id.to_int()

  // ── textContent getter/setter ──
  let text_content_getter = @runtime.make_method_func(
    name="textContent",
    realm_state=Some(realm_state),
    (_this, _args) => {
    
      match dom.get_text_content(node_id) {
        Ok(text) => @runtime.Value::String_(text)
        Err(_) => @runtime.Value::String_("")
      }
    },
  )
  let text_content_setter = @runtime.make_method_func(
    name="textContent",
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let value = if args.length() > 0 { args[0].to_string() } else { "" }
      clear_children(dom, node_id)
      expect_dom_ok(dom.append_child(node_id, dom.create_text(value)))
      @runtime.Undefined
    },
  )

  // ── id getter ──
  let id_getter = @runtime.make_method_func(
    name="id",
    realm_state=Some(realm_state),
    (_this, _args) => {
    
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
    (_this, _args) => {
    
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
    (_this, _args) => {
    
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) => @runtime.Value::String_(val)
        _ => @runtime.Value::String_("")
      }
    },
  )
  let class_name_setter = @runtime.make_method_func(
    name="className",
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let value = if args.length() > 0 { args[0].to_string() } else { "" }
      expect_dom_ok(dom.set_attribute(node_id, "class", value))
      @runtime.Undefined
    },
  )

  // ── innerHTML getter/setter ──
  let inner_html_getter = @runtime.make_method_func(
    name="innerHTML",
    realm_state=Some(realm_state),
    (_this, _args) => {
    
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
  let inner_html_setter = @runtime.make_method_func(
    name="innerHTML",
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let html = if args.length() > 0 { args[0].to_string() } else { "" }
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
    (_this, _args) => {
    
      match dom.get_attribute(node_id, "style") {
        Ok(Some(s)) => @runtime.Value::String_(s)
        _ => @runtime.Value::String_("")
      }
    },
  )

  // ── classList object ──
  let class_list_contains = @runtime.make_method_func(
    name="contains",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) =>
          @runtime.Value::Bool(val.split(" ").any(fn(c) { c == cls }))
        _ => @runtime.Value::Bool(false)
      }
    },
  )
  let class_list_add = @runtime.make_method_func(
    name="add",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) => {
          let classes = val.split(" ")
          if !classes.any(fn(c) { c == cls }) {
            expect_dom_ok(dom.set_attribute(node_id, "class", val + " " + cls))
          }
        }
        _ => expect_dom_ok(dom.set_attribute(node_id, "class", cls))
      }
      @runtime.Undefined
    },
  )
  let class_list_remove = @runtime.make_method_func(
    name="remove",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let cls = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, "class") {
        Ok(Some(val)) =>
          expect_dom_ok(
            dom.set_attribute(
              node_id,
              "class",
              val.split(" ").filter(fn(c) { c != cls }).join(" "),
            ),
          )
        _ => ()
      }
      @runtime.Undefined
    },
  )

  let class_list_props : Map[String, @runtime.Value] = {}
  let class_list = @runtime.make_object(
    class_list_props,
    @runtime.Null,
    None,
    "DOMTokenList",
    {},
    true,
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
    name="setAttribute",
    length=2,
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let name = if args.length() > 0 { args[0].to_string() } else { "" }
      let value = if args.length() > 1 { args[1].to_string() } else { "" }
      expect_dom_ok(dom.set_attribute(node_id, name, value))
      @runtime.Undefined
    },
  )

  // ── getAttribute(name) ──
  let get_attr = @runtime.make_method_func(
    name="getAttribute",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
      let name = if args.length() > 0 { args[0].to_string() } else { "" }
      match dom.get_attribute(node_id, name) {
        Ok(Some(val)) => @runtime.Value::String_(val)
        _ => @runtime.Null
      }
    },
  )

  // ── appendChild(child) ──
  let append_child = @runtime.make_method_func(
    name="appendChild",
    length=1,
    realm_state=Some(realm_state),
    (_this, args) => {
    
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

  descs["textContent"] = accessor_desc(text_content_getter, Some(text_content_setter))
  descs["id"] = data_desc(id_getter)
  descs["tagName"] = data_desc(tag_name_getter)
  descs["className"] = accessor_desc(class_name_getter, Some(class_name_setter))
  descs["innerHTML"] = accessor_desc(inner_html_getter, Some(inner_html_setter))
  descs["style"] = data_desc(style_getter)

  let el = @runtime.make_object(
    props,
    @runtime.Null,
    None,
    "Element",
    descs,
    true,
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
/// Extract NodeId from a JS Element wrapper (reads __crater_nid property).
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
