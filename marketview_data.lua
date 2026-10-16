-- Pure Lua 5.1 data preparation; independent of KOReader, networking and secrets.
local M = {}
local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
function M.ticker(input)
    if type(input) ~= "string" then return nil, "Enter a stock ticker, such as AAPL or BRK.B." end
    local value = input:match("^%s*(.-)%s*$"):upper()
    if #value < 1 or #value > 15 or not value:match("^[A-Z][A-Z0-9%.%-]*$") then
        return nil, "Use 1–15 letters, numbers, dots or hyphens, starting with a letter."
    end
    return value
end
function M.prepare(response)
    if type(response) ~= "table" or type(response.results) ~= "table" then return nil, "The provider returned no price series." end
    if response.status == "ERROR" or response.status == "NOT_AUTHORIZED" then return nil, "The provider did not authorize this data request." end
    local by_time, skipped = {}, 0
    for _, bar in ipairs(response.results) do
        if type(bar) == "table" and finite(bar.c) and bar.c >= 0 and finite(bar.t) and bar.t >= 0 and bar.t <= 4102444800000 then
            by_time[bar.t] = { t = bar.t, c = bar.c }
        else skipped = skipped + 1 end
    end
    local bars = {}
    for _, bar in pairs(by_time) do bars[#bars + 1] = bar end
    table.sort(bars, function(a, b) return a.t < b.t end)
    if #bars == 0 then return nil, "No trading observations in this range. Try a longer range or another ticker." end
    local low, high = bars[1].c, bars[1].c
    for _, bar in ipairs(bars) do low = math.min(low, bar.c); high = math.max(high, bar.c) end
    local first, last = bars[1].c, bars[#bars].c
    return { bars = bars, first = first, last = last, change = last - first,
        percent = first ~= 0 and ((last - first) / first * 100) or nil,
        low = low, high = high, skipped = skipped }
end
function M.summary(ticker, series, label)
    local change = series.percent and string.format("%+.2f%%", series.percent) or "percentage unavailable"
    return string.format("%s · %s\nLast close: %.2f\nFirst-to-last close: %+.2f (%s)\nClose range: %.2f – %.2f\n%d observations · %s to %s (UTC)\n%s",
        ticker, label, series.last, series.change, change, series.low, series.high, #series.bars,
        os.date("!%Y-%m-%d", math.floor(series.bars[1].t / 1000)),
        os.date("!%Y-%m-%d", math.floor(series.bars[#series.bars].t / 1000)),
        series.synthetic and "Generated observations, not an instrument or trading calendar." or
        (series.skipped > 0 and (series.skipped .. " invalid observations omitted.") or "Adjusted daily closes. Non-trading days are omitted."))
end
function M.plot(bars, width, height)
    local points = {}
    if not bars or #bars == 0 or width < 80 or height < 50 then return points end
    local low, high = bars[1].c, bars[1].c
    for _, bar in ipairs(bars) do low = math.min(low, bar.c); high = math.max(high, bar.c) end
    if low == high then local pad = math.max(1, math.abs(low) * 0.01); low = low - pad; high = high + pad end
    for i, bar in ipairs(bars) do
        points[i] = { x = math.floor(20 + (#bars == 1 and (width - 40) / 2 or (i - 1) / (#bars - 1) * (width - 40))),
            y = math.floor(10 + (high - bar.c) / (high - low) * (height - 30)) }
    end
    return points
end
function M.sample(days)
    local results = {}
    for i = 1, days or 30 do
        results[#results + 1] = { t = 1767225600000 + i * 86400000, c = 100 + i * 0.22 + math.sin(i * 0.65) * 2.8 }
    end
    local series = M.prepare({ results = results })
    series.synthetic = true
    return series
end
return M
