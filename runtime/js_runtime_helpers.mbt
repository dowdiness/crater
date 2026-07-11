///|
/// Helper functions for HTML→DomTree conversion and error handling.
/// Extracted from js_runtime_jsengine.mbt during refactoring.

// ═══════════════════════════════════════════════
// HTML → DomTree conversion
// ═══════════════════════════════════════════════

///|
/// Parse an HTML fragment and create DomTree nodes.
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
/// Convert a parsed @html.Node to a DomTree node.
fn convert_html_node(dom : @dom.DomTree, node : @html_lib.Node) -> @dom.NodeId? {
  match node {
    @html_lib.Node::Text(text) => Some(dom.create_text(text))
    @html_lib.Node::Element(el) => {
      let nid = dom.create_element(el.tag)
      for key in el.attributes.keys() {
        match el.attributes.get(key) {
          Some(value) => {
            let _ = dom.set_attribute(nid, key, value)
          }
          None => ()
        }
      }
      // parse_fragment extracts style from attributes into dedicated field
      match el.style {
        Some(s) => {
          let _ = dom.set_attribute(nid, "style", s)
        }
        None => ()
      }
      for child in el.children {
        match convert_html_node(dom, child) {
          Some(cnid) => {
            let _ = dom.append_child(nid, cnid)
          }
          None => ()
        }
      }
      Some(nid)
    }
  }
}

///|
/// Remove all children of a DomTree node.
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
/// Raise a JS TypeError from a DOM operation error.
fn raise_dom_error(msg : String) -> @runtime.Value raise Error {
  raise @js_errors.TypeError(message=msg)
}

///|
/// Expect a DomTree Result to be Ok, raising TypeError on failure.
fn expect_dom_ok(result : Result[Unit, @dom.CoreError]) -> Unit raise Error {
  match result {
    Ok(_) => ()
    Err(e) => {
      let _ = raise_dom_error("DOM error: " + e.to_string())
    }
  }
}

///|
/// Format a js_engine error into a human-readable string.
fn describe_js_engine_error(err : Error) -> String {
  @js_errors.name_message_if_js_error(err).map_or(err.to_string(), fn(pair) {
    let (name, msg) = pair
    name + ": " + msg
  })
}
