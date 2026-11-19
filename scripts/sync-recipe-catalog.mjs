// Keep the compiled demo in sync with the shared, reviewed recipe catalog.
// Usage: node scripts/sync-recipe-catalog.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const recipes = JSON.parse(fs.readFileSync(path.join(root,
  'apps/fridge-app/assets/data/home-recipes-v2.json'), 'utf8'));
const target = path.join(root,
  'apps/fridge-app/lib/features/recipe/data/home_recipe_catalog.dart');
const quote = value => "'" + String(value).replaceAll('\\', '\\\\')
  .replaceAll("'", "\\'").replaceAll('$', '\\$') + "'";
let output = '// Generated from assets/data/home-recipes-v2.json by scripts/sync-recipe-catalog.mjs.\n'
  + '// The compiled demo avoids asset I/O during session and route transitions.\n'
  + "import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';\n\n"
  + 'const homeRecipes = <Recipe>[\n';
for (const r of recipes) {
  output += `  Recipe(\n    id: ${r.id}, name: ${quote(r.name)},\n`
    + `    summary: ${quote(r.summary)},\n`
    + `    category: ${quote(r.category)}, durationMinutes: ${r.durationMinutes},\n`
    + `    calories: ${r.calories}, difficulty: ${quote(r.difficulty)}, servings: ${r.servings},\n`
    + `    coverEmoji: ${quote(r.coverEmoji)}, featured: ${r.featured},\n`
    + `    steps: [${r.steps.map(quote).join(', ')}],\n    ingredients: [\n`;
  for (const i of r.ingredients) output += `      RecipeIngredient(name: ${quote(i.name)}, quantity: ${i.quantity}, unit: ${quote(i.unit)}, optional: ${i.optional}),\n`;
  output += '    ],\n  ),\n';
}
output += '];\n';
// Dart's formatter is the source of formatting truth; check through stdin so
// verification never rewrites the checked-in output.
const dart = process.platform === 'win32' ? 'dart.bat' : 'dart';
const formatted = spawnSync(dart, ['format', '--output=show'], {
  input: output, encoding: 'utf8', shell: process.platform === 'win32',
});
if (formatted.status !== 0) throw new Error(formatted.stderr || 'dart format failed');
const marker = formatted.stdout.indexOf('// Generated');
const end = formatted.stdout.lastIndexOf('];');
if (marker < 0 || end < marker) throw new Error('Formatted catalog not found');
const normalized = formatted.stdout.slice(marker, end + 2).replaceAll('\r\n', '\n') + '\n';
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target, 'utf8').replaceAll('\r\n', '\n') !== normalized) {
    throw new Error('Compiled demo differs from the shared catalog; run sync-recipe-catalog.mjs');
  }
  console.log(`Catalog matches: ${recipes.length} recipes`);
} else {
  fs.writeFileSync(target, normalized);
  console.log(`Updated compiled catalog: ${recipes.length} recipes`);
}
