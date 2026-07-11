///|
/// JavaScript Runtime - js_engine implementation with DOM bindings
///
/// Uses dowdiness/js_engine (pure MoonBit JavaScript interpreter)
/// for JavaScript execution on the native target.
///
/// Registers document.querySelector, document.getElementById,
/// and element.textContent as native MoonBit functions that
/// operate directly on crater's DomTree.

///|
priv struct JsEngineRuntime {
  _unused : Int
}

///|
let jsengine_runtime : JsEngineRuntime = { _unused: 0 }

///|
/// Module-level reference to the current DomTree for native function closures.
let current_dom : Ref[@dom.DomTree?] = { val: None }

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
/// Execute JavaScript against the DomTree using js_engine.
///
/// Creates a fresh interpreter with DOM bindings injected,
/// so document.querySelector and element.textContent work
/// directly on crater's DomTree.
impl JsRuntime for JsEngineRuntime with fn execute(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = (self, context_id, async_mode)

  // Update the current DOM reference for native function closures
  current_dom.val = Some(dom)

  try {
    // Create a fully-wired interpreter (standard JS builtins + harness)
    let interp = @interpreter.new_interpreter()

    // Inject DOM bindings into the interpreter's global scope
    inject_dom_bindings(interp.global, interp.realm_state, dom)

    // Parse and execute the JavaScript code
    let prog = @parser.parse(code)
    let result = interp.run(prog.stmts)
    interp.run_microtasks()
    interp.run_timers()

    JsResult::new(result.to_string(), interp.host.output, true)
  } catch {
    e => raise JsError::ExecutionError(describe_js_engine_error(e))
  }
}

///|
/// Inject document object with DOM methods into the interpreter global scope.
fn inject_dom_bindings(
  env : @interpreter.Environment,
  realm_state : @runtime.RealmState,
  dom : @dom.DomTree,
) -> Unit {
  let doc_id = dom.get_document()

  // -- document.querySelector(selector) --
  let query_selector = @runtime.make_method_func(
    name="querySelector",
    length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let selector = if args.length() > 0 {
        args[0].to_string()
      } else {
        ""
      }
      match dom.query_selector(doc_id, selector) {
        Ok(Some(node_id)) => wrap_element_node(dom, node_id, realm_state)
        _ => @runtime.Null
      }
    },
  )

  // -- document.getElementById(id) --
  let get_element_by_id = @runtime.make_method_func(
    name="getElementById",
    length=1,
    realm_state=Some(realm_state),
    fn(this, args) {
      let _ = this
      let id = if args.length() > 0 {
        args[0].to_string()
      } else {
        ""
      }
      match dom.query_selector(doc_id, "#" + id) {
        Ok(Some(node_id)) => wrap_element_node(dom, node_id, realm_state)
        _ => @runtime.Null
      }
    },
  )

  // -- document.title getter --
  let title_getter = @runtime.make_method_func(
    name="title",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.query_selector(doc_id, "title") {
        Ok(Some(title_id)) =>
          match dom.get_text_content(title_id) {
            Ok(text) => @runtime.Value::String_(text)
            _ => @runtime.Value::String_("")
          }
        _ => @runtime.Value::String_("")
      }
    },
  )

  // Build the document object
  let doc_props : Map[String, @runtime.Value] = {}
  let doc_descs : Map[String, @runtime.PropDescriptor] = {}
  doc_descs["title"] = {
    writable: true,
    enumerable: true,
    configurable: true,
    getter: Some(title_getter),
    setter: None,
    is_accessor: false,
  }

  let document = @runtime.make_object(
    doc_props,
    @runtime.Null,
    None,
    "HTMLDocument",
    doc_descs,
    true,
  )

  // Install methods onto document
  match document {
    @runtime.Value::Object(data) => {
      @runtime.install_builtin_method(data, "querySelector", query_selector)
      @runtime.install_builtin_method(data, "getElementById", get_element_by_id)
    }
    _ => ()
  }

  // Register document in global scope
  env.def_builtin("document", document)
}

///|
/// Wrap a crater NodeId as a JS Element object with textContent property.
fn wrap_element_node(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  realm_state : @runtime.RealmState,
) -> @runtime.Value {
  // Create the textContent getter — captures node_id and dom
  let text_content_getter = @runtime.make_method_func(
    name="textContent",
    realm_state=Some(realm_state),
    fn(this, _args) {
      let _ = this
      match dom.get_text_content(node_id) {
        Ok(text) => @runtime.Value::String_(text)
        Err(_) => @runtime.Undefined
      }
    },
  )

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

  // Create Element wrapper object with getters
  let props : Map[String, @runtime.Value] = {}
  let descs : Map[String, @runtime.PropDescriptor] = {}

  descs["textContent"] = {
    writable: true,
    enumerable: true,
    configurable: true,
    getter: Some(text_content_getter),
    setter: None,
    is_accessor: false,
  }
  descs["id"] = {
    writable: true,
    enumerable: true,
    configurable: true,
    getter: Some(id_getter),
    setter: None,
    is_accessor: false,
  }

  @runtime.make_object(props, @runtime.Null, None, "Element", descs, true)
}

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
/// Format a js_engine error for Crater's JsError type.
fn describe_js_engine_error(err : Error) -> String {
  @js_errors.name_message_if_js_error(err)
  .map_or(err.to_string(), fn(pair) {
    let (name, msg) = pair
    name + ": " + msg
  })
}
