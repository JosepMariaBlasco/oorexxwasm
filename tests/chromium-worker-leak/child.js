// keeps the memory it is given and touches it (as a thread of a WebAssembly
// program would), then stays idle in its event loop
onmessage = (e) => {
  const a = new Uint8Array(e.data.buffer);
  for (let i = 0; i < a.length; i += 4096) a[i] = 1;
  postMessage('up');
};
