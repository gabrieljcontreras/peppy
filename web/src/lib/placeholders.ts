function randDigit(min: number, max: number): string {
  return String(Math.floor(Math.random() * (max - min + 1)) + min);
}

function randDigits(count: number): string {
  let out = "";
  for (let i = 0; i < count; i++) out += randDigit(0, 9);
  return out;
}

export function randomPhoneSample(): string {
  const area = randDigit(2, 9) + randDigits(2);
  const exchange = randDigit(2, 9) + randDigits(2);
  const line = randDigits(4);
  return `+1-${area}-${exchange}-${line}`;
}

const FIRST_NAMES = [
  "alex",
  "sam",
  "jordan",
  "taylor",
  "morgan",
  "casey",
  "riley",
  "jamie",
];

export function randomEmailSample(): string {
  const name = FIRST_NAMES[Math.floor(Math.random() * FIRST_NAMES.length)];
  return `${name}@example.com`;
}
