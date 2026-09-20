import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const brand = resolve(root, 'assets/brand');

function render(svgName, outName, width) {
  const svg = readFileSync(resolve(brand, svgName));
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: width },
    background: 'rgba(0,0,0,0)',
  });
  const png = resvg.render().asPng();
  const out = resolve(brand, outName);
  writeFileSync(out, png);
  console.log(`wrote ${outName} (${width}px, ${png.length} bytes)`);
}

mkdirSync(brand, { recursive: true });
render('app_icon.svg', 'app_icon.png', 1024);
render('splash_logo.svg', 'splash_logo.png', 512);
