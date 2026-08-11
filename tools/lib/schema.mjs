/**
 * The subset of JSON Schema these three contracts actually use.
 *
 * Zero dependencies, on the same argument `stackvo/tools/validate-contracts.mjs`
 * makes: this repository is data, its CI has to run in a fresh clone with
 * nothing installed, and a validator is one more thing that can go
 * unmaintained. What is implemented is exactly what `schema/*.json` uses —
 * nothing more, and an unknown keyword is a **failure** rather than something
 * quietly ignored, because a rule nobody enforces reads as a rule that holds.
 *
 * Supported: type, const, enum, not.enum, required, properties,
 * additionalProperties (boolean and schema), items, pattern, minLength,
 * maxLength, minimum, maximum, minItems, minProperties, uniqueItems, default,
 * description, title, $schema, $id, $ref (to `#/properties/...` only), format
 * (documented, not enforced).
 */

const KNOWN = new Set([
  '$schema',
  '$id',
  '$ref',
  'title',
  'description',
  'default',
  'type',
  'const',
  'enum',
  'not',
  'required',
  'properties',
  'additionalProperties',
  'propertyNames',
  'items',
  'pattern',
  'minLength',
  'maxLength',
  'minimum',
  'maximum',
  'minItems',
  'minProperties',
  'uniqueItems',
  'format',
]);

const typeOf = (value) => {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (Number.isInteger(value)) return 'integer';
  return typeof value === 'number' ? 'number' : typeof value;
};

const matchesType = (value, expected) => {
  const actual = typeOf(value);
  const wanted = Array.isArray(expected) ? expected : [expected];
  return wanted.some((t) => (t === 'number' ? actual === 'number' || actual === 'integer' : t === actual));
};

/**
 * Resolve the one `$ref` shape these schemas use: a JSON pointer into the same
 * document. Anything else is refused rather than fetched — a validator that
 * follows a URL is a validator with a network dependency.
 */
function deref(node, root, at, problems) {
  if (!node || typeof node.$ref !== 'string') return node;
  if (!node.$ref.startsWith('#/')) {
    problems.push(`${at}: $ref ${JSON.stringify(node.$ref)} is not a local pointer`);
    return null;
  }
  let target = root;
  for (const part of node.$ref.slice(2).split('/')) {
    target = target?.[part.replaceAll('~1', '/').replaceAll('~0', '~')];
  }
  if (!target) {
    problems.push(`${at}: $ref ${JSON.stringify(node.$ref)} resolves to nothing`);
    return null;
  }
  return target;
}

/**
 * @returns {string[]} one line per problem, empty when the value conforms.
 */
export function validate(value, schema, { root = schema, at = '' } = {}) {
  const problems = [];
  const node = deref(schema, root, at, problems);
  if (!node) return problems;

  for (const keyword of Object.keys(node)) {
    if (!KNOWN.has(keyword)) {
      problems.push(`${at}: the schema uses ${JSON.stringify(keyword)}, which this validator does not implement`);
    }
  }

  if (node.type && !matchesType(value, node.type)) {
    problems.push(`${at}: expected ${[node.type].flat().join(' or ')}, found ${typeOf(value)}`);
    return problems; // Everything below assumes the type held.
  }
  if ('const' in node && JSON.stringify(value) !== JSON.stringify(node.const)) {
    problems.push(`${at}: must be ${JSON.stringify(node.const)}`);
  }
  if (node.enum && !node.enum.some((v) => JSON.stringify(v) === JSON.stringify(value))) {
    problems.push(`${at}: ${JSON.stringify(value)} is not one of ${JSON.stringify(node.enum)}`);
  }
  if (node.not?.enum?.some((v) => JSON.stringify(v) === JSON.stringify(value))) {
    problems.push(`${at}: ${JSON.stringify(value)} is forbidden here`);
  }

  if (typeof value === 'string') {
    if (node.pattern && !new RegExp(node.pattern).test(value)) {
      problems.push(`${at}: ${JSON.stringify(value)} does not match ${node.pattern}`);
    }
    if (node.minLength !== undefined && value.length < node.minLength) {
      problems.push(`${at}: shorter than ${node.minLength}`);
    }
    if (node.maxLength !== undefined && value.length > node.maxLength) {
      problems.push(`${at}: longer than ${node.maxLength}`);
    }
  }

  if (typeof value === 'number') {
    if (node.minimum !== undefined && value < node.minimum) problems.push(`${at}: below ${node.minimum}`);
    if (node.maximum !== undefined && value > node.maximum) problems.push(`${at}: above ${node.maximum}`);
  }

  if (Array.isArray(value)) {
    if (node.minItems !== undefined && value.length < node.minItems) {
      problems.push(`${at}: fewer than ${node.minItems} items`);
    }
    if (node.uniqueItems) {
      const seen = new Set(value.map((v) => JSON.stringify(v)));
      if (seen.size !== value.length) problems.push(`${at}: has a duplicate`);
    }
    if (node.items) {
      value.forEach((item, i) => {
        problems.push(...validate(item, node.items, { root, at: `${at}[${i}]` }));
      });
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of node.required ?? []) {
      if (!(key in value)) problems.push(`${at}: missing required "${key}"`);
    }
    if (node.minProperties !== undefined && Object.keys(value).length < node.minProperties) {
      problems.push(`${at}: needs at least ${node.minProperties} entries`);
    }
    for (const [key, child] of Object.entries(value)) {
      const declared = node.properties?.[key];
      if (declared) {
        problems.push(...validate(child, declared, { root, at: `${at}.${key}` }));
        continue;
      }
      if (node.additionalProperties === false) {
        // The rule that catches a field somebody added on one side only.
        problems.push(`${at}: ${JSON.stringify(key)} is not a field this schema declares`);
      } else if (node.additionalProperties && typeof node.additionalProperties === 'object') {
        problems.push(...validate(child, node.additionalProperties, { root, at: `${at}.${key}` }));
      }
    }
  }

  return problems;
}
