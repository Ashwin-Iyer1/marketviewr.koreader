# MarketView for KOReader

A stock-history viewer designed for a monochrome e-reader: a clean close-price graph, readable summary, and an offline sample you can try without an API key.

## Use it

Open **More tools → MarketView**. The initial chart is an explicitly fictional sample, not a market quote. Choose **7 days**, **30 days**, or **90 days** to change the window. **Ticker** accepts a stock symbol such as `AAPL` or `BRK.B`; **Refresh** retries the current selection; **Sample** returns to the offline fixture.

The summary shows first/last close, absolute and percentage change, observed close range, number of observations, and actual observation dates in UTC. The graph uses one equally spaced point per observation; non-trading days are omitted. Flat series and one-to-three observations render safely. Each viewer owns its data, and a late response cannot replace a newer selection or a closed window.

## Install

Install [KOReader](https://github.com/koreader/koreader) using its supported instructions for your device. Build an installable archive from this checkout:

```sh
python3 scripts/package.py
```

Extract `dist/marketview.koplugin.zip` into KOReader's `plugins` directory, so the result is `plugins/marketview.koplugin/main.lua`. Restart KOReader. CI also builds the same archive as an Actions artifact. The archive explicitly excludes your API configuration.

## Market data configuration

The offline sample needs no account or network. For market history, copy `marketview_config.lua.sample` to `marketview_config.lua` inside the installed plugin and replace its placeholder with your own API key. This file is gitignored and excluded from packaging.

[Massive (formerly Polygon)](https://massive.com/blog/polygon-is-now-massive/) supports existing Polygon keys. Requests use its current `api.massive.com` endpoint and an Authorization header; keys never enter the URL or error messages. A ticker request sends the symbol, selected date range, and key to the provider. Data access and delay depend on your subscription. No paid subscription is required to explore the sample.

The plugin requests [adjusted daily aggregates](https://massive.com/docs/rest/stocks/aggregates/custom-bars). Invalid, missing, duplicate, or unsorted observations are handled before charting. Access-denied, rate-limit, malformed-response, empty-range, and connection errors have separate messages. The last bar may be incomplete or delayed; this is a historical viewer, not a real-time trading feed.

## Verification and limits

```sh
luajit tests/run.lua
python3 scripts/package.py
```

The suite exercises the actual Lua 5.1-compatible data, graph painting, API adapter, and viewer request lifecycle with isolated KOReader/network mocks. It covers fractional display sizes, sparse/flat series, independent graph state, request races, close handling, UTC dates, secret-safe errors, and a 512 KiB response limit. No real API key is used.

The update was tested under LuaJIT 2.1; actual GraphWidget drawing was inspected through a recorded paint-buffer render. A physical KOReader device and authenticated provider request have **not** been verified. Networking uses KOReader's 5-second block and 15-second transfer timeouts; DNS resolution can exceed those timeouts, and the synchronous request can briefly block UI interaction. Wi-Fi is requested only when you choose actual market data. The plugin does not place trades.

## Attribution

The original viewer was based on [drewbaumann/AskGPT](https://github.com/drewbaumann/AskGPT/). That provenance is retained. License: GPLv3, as declared by the original project.
