///|
/// Test helper for HTML + JS testing with js_engine.
///
/// Provides a simple API for setting up HTML content, executing
/// JavaScript, and making assertions on the resulting DOM.

///|
/// Test context wrapping a DomTree with JS execution support.
pub struct TestCtx {
  dom : @dom.DomTree
  context : JsContext
}

///|
/// Create a TestCtx from an HTML string. Parses the HTML, builds
/// a DomTree, and sets up js_engine for script execution.
pub fn html(html_src : String) -> TestCtx {
  let doc = @html_lib.parse_document(html_src)
  let dom = @dom.DomTree::new()
  build_dom_from_parsed(dom, doc.root)
  let ctx = JsContext::new_with_runtime(dom, jsengine_runtime as &JsRuntime)
  { dom, context: ctx }
}

///|
/// Query the DOM with a CSS selector. Returns the first matching
/// element's text content, or None if not found.
pub fn TestCtx::query_text(self : TestCtx, selector : String) -> String? {
  let doc_id = self.dom.get_document()
  match self.dom.query_selector(doc_id, selector) {
    Ok(Some(nid)) =>
      match self.dom.get_text_content(nid) {
        Ok(text) => Some(text)
        _ => None
      }
    _ => None
  }
}

///|
/// Evaluate JavaScript in the test context. The script runs against
/// the current DomTree with full DOM API access.
pub fn TestCtx::eval(self : TestCtx, js : String) -> JsResult raise JsError {
  self.context.execute(js)
}

///|
/// Find and execute all inline <script> tags from the parsed HTML.
/// Returns the number of scripts executed.
pub fn TestCtx::run_scripts(self : TestCtx) -> Int raise JsError {
  let doc_id = self.dom.get_document()
  execute_found_scripts(self.dom, self.context, doc_id)
}

///|
/// Assert that a selector matches an element with the expected text.
pub fn TestCtx::assert_text(
  self : TestCtx,
  selector : String,
  expected : String,
) -> Unit {
  let actual = self.query_text(selector)
  guard actual == Some(expected) else {
    abort(
      "assert_text failed: " + selector +
      " expected \"" + expected +
      "\" got \"" + actual.unwrap_or("(none)") + "\"",
    )
  }
}

///|
/// Assert that a selector matches an element.
pub fn TestCtx::assert_exists(self : TestCtx, selector : String) -> Unit {
  let doc_id = self.dom.get_document()
  match self.dom.query_selector(doc_id, selector) {
    Ok(Some(_)) => ()
    _ => abort("assert_exists failed: " + selector + " not found")
  }
}

///|
/// Get console log output from executed scripts.
pub fn TestCtx::logs(self : TestCtx) -> Array[String] {
  self.context.get_logs()
}

// ═══════════════════════════════════════════════
// Internal helpers
// ═══════════════════════════════════════════════

///|
/// Build a DomTree from a parsed @html.Element (recursive).
fn build_dom_from_parsed(dom : @dom.DomTree, el : @html_lib.Element) -> Unit {
  let doc_id = dom.get_document()
  let root_nid = dom.create_element(el.tag)
  let _ = dom.append_child(doc_id, root_nid)
  // Set attributes
  for key in el.attributes.keys() {
    match el.attributes.get(key) {
      Some(value) => { let _ = dom.set_attribute(root_nid, key, value) }
      None => ()
    }
  }
  // Process children
  for child in el.children {
    build_node_recursive(dom, root_nid, child)
  }
}

///|
/// Recursively build a node and its children into the DomTree.
fn build_node_recursive(
  dom : @dom.DomTree,
  parent_nid : @dom.NodeId,
  node : @html_lib.Node,
) -> Unit {
  match node {
    @html_lib.Node::Text(text) => {
      let text_nid = dom.create_text(text)
      let _ = dom.append_child(parent_nid, text_nid)
    }
    @html_lib.Node::Element(el) => {
      let nid = dom.create_element(el.tag)
      let _ = dom.append_child(parent_nid, nid)
      for key in el.attributes.keys() {
        match el.attributes.get(key) {
          Some(value) => { let _ = dom.set_attribute(nid, key, value) }
          None => ()
        }
      }
      match el.style {
        Some(s) => { let _ = dom.set_attribute(nid, "style", s) }
        None => ()
      }
      for child in el.children {
        build_node_recursive(dom, nid, child)
      }
    }
  }
}

///|
/// Find and execute all inline <script> elements in the DomTree.
fn execute_found_scripts(
  dom : @dom.DomTree,
  ctx : JsContext,
  root_id : @dom.NodeId,
) -> Int raise JsError {
  let mut count = 0
  let scripts = find_script_nodes(dom, root_id)
  for script_id in scripts {
    match dom.get_text_content(script_id) {
      Ok(src) if src.length() > 0 => {
        let _ = ctx.execute(src)
        count = count + 1
      }
      _ => ()
    }
  }
  count
}

///|
/// Find all <script> element NodeIds in the DOM tree (recursive).
fn find_script_nodes(
  dom : @dom.DomTree,
  parent_id : @dom.NodeId,
) -> Array[@dom.NodeId] {
  let result : Array[@dom.NodeId] = []
  match dom.get_children(parent_id) {
    Ok(children) =>
      for child in children {
        match dom.get_tag_name(child) {
          Ok(tag) =>
            if tag.to_lower() == "script" {
              result.push(child)
            }
          Err(_) => ()
        }
        // Recurse into children
        let sub_scripts = find_script_nodes(dom, child)
        for s in sub_scripts {
          result.push(s)
        }
      }
    Err(_) => ()
  }
  result
}
