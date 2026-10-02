# contract/

The backend contract this app is built against, pinned by `SOURCE`:

- `fixtures/`: `packages/protocol/fixtures` of DimaM18/SpoRand (WS, REST and emoji goldens,
  variants, invalid frames);
- `generated/client-registry.json`: what the app mirrors (config keys, init steps, features,
  paywall placements, products, content guard).

Never edit these files by hand. The backend team changes the contract in DimaM18/SpoRand
(`packages/protocol`, CLAUDE.md rule 8 there); this repository takes it with
`tool/contract.sh sync <SpoRand checkout>` (a clean checkout at the commit to pin), runs
`flutter test`, adapts the DTOs in `lib/core/net/protocol/` and commits `contract/` together
with them. CI checks out the pinned commit, runs `tool/contract.sh check` and the end-to-end
suite against that backend (`.github/workflows/e2e.yml`).
