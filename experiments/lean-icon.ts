// lean-icon.ts: a folder icon written by hand. The icon file holds only the PNGs given; the resource fork holds one
// 'icns' resource (id -16455). The first folder gets a real hidden `Icon\r`; the others get hard links to it, so the
// bytes are on disk once.
//
//   deno run -A lean-icon.ts <png128> <png512> <folder>...

const [p128, p512, ...folders] = Deno.args;
const be = (n: number, len: number) => Array.from({ length: len }, (_, i) => (n >>> (8 * (len - 1 - i))) & 0xff);
const ascii = (s: string) => [...s].map((c) => c.charCodeAt(0));

const entry = (type: string, png: Uint8Array) => [...ascii(type), ...be(8 + png.length, 4), ...png];
const body = [...entry("ic07", Deno.readFileSync(p128)), ...entry("ic09", Deno.readFileSync(p512))];
const icns = [...ascii("icns"), ...be(8 + body.length, 4), ...body];

// Resource fork: header, data (length-prefixed), map with one type and one reference, as the system writes it.
const data = [...be(icns.length, 4), ...icns], dataOff = 0x100, mapOff = dataOff + data.length, mapLen = 0x32;
const header = [...be(dataOff, 4), ...be(mapOff, 4), ...be(data.length, 4), ...be(mapLen, 4)];
const map = [
  ...header, ...be(0, 4), ...be(0, 2), ...be(0, 2), // copy of header, next map, file ref, attributes
  ...be(0x1c, 2), ...be(mapLen, 2), // type list offset, name list offset (empty, at the end)
  ...be(0, 2), ...ascii("icns"), ...be(0, 2), ...be(0x0a, 2), // one type, one resource, its reference at +10
  ...be(0xbfb9, 2), ...be(0xffff, 2), 0, ...be(0, 3), ...be(0, 4), // id -16455, no name, data at 0
];
const fork = new Uint8Array([...header, ...new Array(dataOff - 16).fill(0), ...data, ...map]);

const hex = (b: Uint8Array | number[]) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const xattr = (name: string, value: Uint8Array | number[], path: string) => {
  const r = new Deno.Command("/usr/bin/xattr", { args: ["-wx", name, hex(value), path] }).outputSync();
  if (!r.success) throw new Error(`${path}: ${new TextDecoder().decode(r.stderr)}`);
};
const finderInfo = (byte8: number) => [...new Array(8).fill(0), byte8, ...new Array(23).fill(0)];

let first: string | undefined;
for (const folder of folders) {
  const icon = `${folder}/Icon\r`;
  if (first) Deno.linkSync(first, icon);
  else {
    Deno.writeFileSync(icon, new Uint8Array());
    xattr("com.apple.ResourceFork", fork, icon);
    xattr("com.apple.FinderInfo", finderInfo(0x40), icon); // invisible
    first = icon;
  }
  xattr("com.apple.FinderInfo", finderInfo(0x04), folder); // has custom icon
}
console.log(`icon file ${icns.length} bytes, fork ${fork.length} bytes, ${folders.length} folders`);
