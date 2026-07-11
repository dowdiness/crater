///|
/// Test: JsEngine Runtime Integration + Full DOM Bindings
///
/// Verifies js_engine-based JsRuntime with DOM API surface.
/// All tests use whitebox access to runtime internals.

///|
test "jsengine executes basic arithmetic" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("1 + 2")
  guard result.value == "3" else { fail("expected 3, got " + result.value) }
  guard result.success else { fail("expected success") }
}

///|
test "jsengine executes string operations" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("\"hello\".toUpperCase()")
  guard result.success else { fail("expected success: " + result.value) }
  guard result.value == "HELLO" else {
    fail("expected HELLO, got " + result.value)
  }
}

///|
test "jsengine captures console output" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("console.log(42)")
  guard result.success else { fail("expected success, got: " + result.value) }
  guard result.logs.length() > 0 else { fail("expected console output") }
  guard result.logs[0] == "42" else {
    fail("expected '42', got " + result.logs[0])
  }
}

///|
fn make_simple_dom() -> (@dom.DomTree, @dom.NodeId) {
  let dom = @dom.DomTree::new()
  let d = dom.get_document()
  let h = dom.create_element("html")
  let _ = dom.append_child(d, h)
  let b = dom.create_element("body")
  let _ = dom.append_child(h, b)
  let dv = dom.create_element("div")
  let _ = dom.append_child(b, dv)
  let _ = dom.set_attribute(dv, "id", "root")
  (dom, dv)
}

///|
fn run_js(dom : @dom.DomTree, code : String) -> JsResult raise {
  JsContext::new(dom).execute(code)
}

///|
test "document.querySelector + textContent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var el=document.querySelector('#root');console.log(el.textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "document.getElementById + textContent" {
  let (dom, dv) = make_simple_dom()
  let t = dom.create_text("hello")
  let _ = dom.append_child(dv, t)
  let r = run_js(
    dom, "console.log(document.getElementById('root').textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "hello" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "textContent getter and setter" {
  let (dom, dv) = make_simple_dom()
  let _ = dom.set_attribute(dv, "id", "root")
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.textContent='after';console.log(e.textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "after" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "innerHTML getter" {
  let (dom, dv) = make_simple_dom()
  let sp = dom.create_element("span")
  let _ = dom.append_child(dv, sp)
  let tx = dom.create_text("hi")
  let _ = dom.append_child(sp, tx)
  let r = run_js(dom, "console.log(document.querySelector('#root').innerHTML);")
  guard r.logs.length() > 0 && r.logs[0] == "<span>hi</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "innerHTML setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.innerHTML='<span class=x>hi</span>';console.log(e.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "<span class=\"x\">hi</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "setAttribute and getAttribute" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.setAttribute('data-x','42');console.log(e.getAttribute('data-x'));",
  )
  guard r.logs.length() > 0 && r.logs[0] == "42" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "tagName getter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(dom, "console.log(document.querySelector('#root').tagName);")
  guard r.logs.length() > 0 && r.logs[0] == "DIV" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "createElement + appendChild + textContent setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var p=document.querySelector('#root');var c=document.createElement('span');c.textContent='new';p.appendChild(c);console.log(p.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "<span>new</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "nested innerHTML" {
  let (dom, _) = make_simple_dom()
  // Create <ul><li>A</li><li>B</li></ul> manually
  let ul = dom.create_element("ul")
  let _ = dom.append_child(dv_from_id(dom, "root"), ul)
  let l1 = dom.create_element("li")
  let _ = dom.append_child(ul, l1)
  let l2 = dom.create_element("li")
  let _ = dom.append_child(ul, l2)
  let _ = dom.append_child(l1, dom.create_text("A"))
  let _ = dom.append_child(l2, dom.create_text("B"))
  let r = run_js(dom, "console.log(document.querySelector('ul').innerHTML);")
  guard r.logs.length() > 0 && r.logs[0] == "<li>A</li><li>B</li>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
fn dv_from_id(dom : @dom.DomTree, id : String) -> @dom.NodeId {
  let doc = dom.get_document()
  match dom.query_selector(doc, "#" + id) {
    Ok(Some(nid)) => nid
    _ => abort("element not found: " + id)
  }
}

///|
test "className getter and setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');console.log(e.className);e.className='foo bar';console.log(e.className);",
  )
  guard r.logs.length() == 2 && r.logs[0] == "" && r.logs[1] == "foo bar" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList add and contains" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.classList.add('active');console.log(e.classList.contains('active'));console.log(e.classList.contains('nope'));",
  )
  guard r.logs.length() == 2 && r.logs[0] == "true" && r.logs[1] == "false" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList remove" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.className='a b c';e.classList.remove('b');console.log(e.className);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "a c" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "window and self globals" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(typeof window);console.log(typeof self);console.log(window.document===document);",
  )
  guard r.logs.length() == 3 &&
    r.logs[0] == "object" &&
    r.logs[1] == "object" &&
    r.logs[2] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "document.body" {
  let (dom, _) = make_simple_dom()
  let r = run_js(dom, "console.log(document.body.tagName);")
  guard r.logs.length() > 0 && r.logs[0] == "BODY" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "style getter" {
  let (dom, dv) = make_simple_dom()
  let _ = dom.set_attribute(dv, "style", "color:red")
  let r = run_js(dom, "console.log(document.querySelector('#root').style);")
  guard r.logs.length() > 0 && r.logs[0] == "color:red" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "document.title" {
  let (dom, _) = make_simple_dom()
  // Add a <title> tag
  let doc = dom.get_document()
  let h = dom.create_element("html")
  let _ = dom.append_child(doc, h)
  let head = dom.create_element("head")
  let _ = dom.append_child(h, head)
  let title = dom.create_element("title")
  let _ = dom.append_child(head, title)
  let _ = dom.append_child(title, dom.create_text("My Page"))
  let _ = dom.append_child(h, dom.create_element("body"))
  let r = run_js(dom, "console.log(document.title);")
  guard r.logs.length() > 0 && r.logs[0] == "My Page" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "innerHTML setter with style attribute" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.innerHTML='<span style=color:red>hi</span>';console.log(document.querySelector('span').getAttribute('style'));",
  )
  guard r.logs.length() > 0 && r.logs[0] == "color:red" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "empty innerHTML setter" {
  let (dom, dv) = make_simple_dom()
  let sp = dom.create_element("span")
  let _ = dom.append_child(dv, sp)
  let _ = dom.append_child(sp, dom.create_text("content"))
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.innerHTML='';console.log(e.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "querySelector returns null for non-existent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(document.querySelector('nonexistent')===null);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "getAttribute returns null for non-existent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(document.querySelector('#root').getAttribute('missing')===null);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList add deduplicates" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.classList.add('x');e.classList.add('x');console.log(e.className);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "x" else {
    fail("unexpected: " + r.logs.join(","))
  }
}
