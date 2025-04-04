local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local NetworkMgr = require("ui/network/manager")

local api_key = nil

-- Attempt to load the api_key module. IN A LATER VERSION, THIS WILL BE REMOVED
local success, result = pcall(function() return require("poly_config") end)
if success then
  api_key = result.api_key
else
  print("poly_config.lua not found, skipping...")
end

local function polyapi_async(ticker, callback)
  local api_key_value = api_key

  if not api_key_value then
    callback(nil, "API key missing")
    return
  end

  local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
  local curr_date = os.date("%Y-%m-%d")
  local api_url = string.format(
    "https://api.polygon.io/v2/aggs/ticker/%s/range/1/hour/%s/%s?adjusted=true&sort=asc&apiKey=%s",
    ticker, yesterday, curr_date, api_key_value
  )

  NetworkMgr:runWhenOnline(function()
    local responseBody = {}
    local res, code = https.request {
      url = api_url,
      method = "GET",
      sink = ltn12.sink.table(responseBody),
    }

    if code ~= 200 then
      callback(nil, "HTTP error code: " .. tostring(code))
      return
    end

    local ok, response = pcall(function()
      return json.decode(table.concat(responseBody))
    end)

    if not ok or not response then
      callback(nil, "JSON decode failed")
      return
    end

    callback(response, nil)
  end)
end

return polyapi_async
