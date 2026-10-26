// one round: a shared memory, four children that receive it, then the
// children terminated (unless told to keep them) and the page told
onmessage = (e) => {
  let memory;
  try { memory = new WebAssembly.Memory({ initial: 1024, maximum: 8192, shared: true }); }
  catch (err) { postMessage({ error: String(err) }); return; }
  const children = [];
  let up = 0;
  for (let i = 0; i < 4; i++) {
    const c = new Worker('child.js');
    children.push(c);
    c.onmessage = () => {
      if (++up < 4) return;
      if (!e.data.keep) for (const k of children) k.terminate();
      postMessage({ error: null });
    };
    c.postMessage(memory);
  }
};
