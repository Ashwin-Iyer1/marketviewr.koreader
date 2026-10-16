local data = require("marketdata")
-- Network loading is lazy: the sample viewer works offline and without a key.
return function(input, callback, days)
    local ticker, invalid = data.ticker(input)
    if not ticker then callback(nil, invalid); return end
    days = days or 30
    if days ~= 7 and days ~= 30 and days ~= 90 then callback(nil, "Choose a 7, 30 or 90 day range."); return end
    local configured, config = pcall(require, "poly_config")
    if not configured or type(config) ~= "table" or type(config.api_key) ~= "string" or config.api_key == "" or config.api_key:match("YOUR_API_KEY") then
        callback(nil, "Add your API key to poly_config.lua to load market data. The fictional sample works without a key."); return
    end
    local https = require("ssl.https")
    local json = require("json")
    local socketutil = require("socketutil")
    local NetworkMgr = require("ui/network/manager")
    NetworkMgr:runWhenOnline(function()
        local finish = os.time()
        local url = string.format("https://api.massive.com/v2/aggs/ticker/%s/range/1/day/%s/%s?adjusted=true&sort=asc&limit=5000",
            ticker, os.date("!%Y-%m-%d", finish - days * 86400), os.date("!%Y-%m-%d", finish))
        local chunks, size = {}, 0
        socketutil:set_timeout(5, 15)
        local sink = socketutil.table_sink(chunks)
        local ok, result, code = pcall(https.request, {
            url = url, method = "GET", redirect = false,
            headers = { Authorization = "Bearer " .. config.api_key },
            sink = function(chunk, err)
                size = size + (chunk and #chunk or 0)
                if size > 524288 then return nil, "Response too large" end
                return sink(chunk, err)
            end,
        })
        socketutil:reset_timeout()
        if not ok or not result then callback(nil, "Connection failed or timed out. Check Wi-Fi and retry."); return end
        code = tonumber(code)
        if code == 401 or code == 403 then callback(nil, "API access denied. Check the key and subscription's data access."); return end
        if code == 429 then callback(nil, "Provider rate limit reached. Wait a moment before refreshing."); return end
        if code ~= 200 then callback(nil, "The data provider is unavailable (HTTP " .. tostring(code) .. "). Retry later."); return end
        local decoded, response = pcall(json.decode, table.concat(chunks))
        if not decoded then callback(nil, "The provider returned an unreadable response."); return end
        local series, message = data.prepare(response)
        callback(series, message)
    end)
end
