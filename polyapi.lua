local _ = require("gettext")



local api_key = nil
local CONFIGURATION = nil

-- Attempt to load the api_key module. IN A LATER VERSION, THIS WILL BE REMOVED
local success, result = pcall(function() return require("poly_config") end)
if success then
  api_key = result
else
  print("poly_config.lua not found, skipping...")
  print(success)
end


-- Define your queryChatGPT function
local https = require("ssl.https")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

local function polyapi(ticker)
  -- Use api_key from CONFIGURATION or fallback to the api_key module
  local api_key_value = api_key and api_key.api_key or api_key
  local yesterday = os.date("%Y-%m-%d", os.time() - 86400) -- 86400 seconds in a day
  local curr_date = os.date("%Y-%m-%d")
  local api_url = string.format("https://api.polygon.io/v2/aggs/ticker/%s/range/1/hour/%s/%s?adjusted=true&sort=asc&apiKey=%s", ticker, yesterday, curr_date, api_key_value)
print(api_url)
    if api_key_value == nil then
    print(api_key_value)
    return("API Key not set properly")
    end

  local responseBody = {}


  local res, code, responseHeaders = https.request {
    url = api_url,
    method = "GET",
    sink = ltn12.sink.table(responseBody),
  }

  if code ~= 200 then
    error("Error querying Poly API: " .. code)
  end

  local response = json.decode(table.concat(responseBody))
  return response
end

return polyapi