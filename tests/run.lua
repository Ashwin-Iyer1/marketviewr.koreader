package.path = "./?.lua;" .. package.path
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local data = require("marketview_data")
check(data.ticker(" brk.b ") == "BRK.B", "Trim and normalize ticker")
for _, input in ipairs({"", "../AAPL", "AAPL?apiKey=secret", "123", string.rep("A", 16)}) do check(not data.ticker(input), "Reject malformed ticker") end
local series = assert(data.prepare({results={{t=2000,c=12},{t=1000,c=10},{t=2000,c=13},{t=3000,c=0/0},{t=4000,c=-1},{t=math.huge,c=5}}}))
check(#series.bars == 2 and series.first == 10 and series.last == 13, "Sort/deduplicate observations")
check(series.change == 3 and math.abs(series.percent - 30) < 0.001 and series.skipped == 3, "Calculate change and skipped rows")
check(not data.prepare({results={}}), "Empty response must be explicit")
check(not data.prepare({results={{t=1e100,c=5}}}), "Unrepresentable dates must be rejected")
check(not data.prepare({status="NOT_AUTHORIZED",results={{t=1,c=1}}}), "Provider errors must not show as data")
local zero = assert(data.prepare({results={{t=1000,c=0},{t=2000,c=1}}}))
check(zero.percent == nil and data.summary("TEST",zero,"test"):find("unavailable"), "Zero baseline must not divide by zero")
check(data.summary("DEMO",data.sample(7),"FICTIONAL"):find("Generated observations"), "Sample provenance")

local Widget = {}
function Widget:extend(values) values.__index=values; return setmetatable(values,{__index=self}) end
function Widget:new(values) local instance=setmetatable(values or {},{__index=self}); if instance.init then instance:init() end; return instance end
package.loaded["ui/widget/widget"] = Widget
package.loaded["ffi/blitbuffer"] = {COLOR_WHITE="white",COLOR_BLACK="black",COLOR_GRAY="gray"}
package.loaded["ui/geometry"] = {new=function(_,t)return t end}
local Graph = require("marketview_graph")
local a,b=Graph:new{width=320.5,height=170.5},Graph:new{}
a:setData(data.sample(7)); check(#b.bars == 0, "Graphs must not share data")
for _, values in ipairs({{},{{t=1,c=2}},{{t=1,c=2},{t=2,c=2}},{{t=1,c=2},{t=2,c=8},{t=3,c=4}},data.sample(90).bars}) do
  a:setData({bars=values}); local painted=0
  a:paintTo({paintRect=function(_,x,y,w,h)
    painted=painted+1; assert(painted<10000,"Paint must terminate")
    assert(x%1==0 and y%1==0 and x>=0 and y>=0 and x+w<=a.width and y+h<=a.height,"Drawing must stay in integer bounds")
  end},0,0)
  check(painted>=1,"Render empty/single/flat/short/long series")
end

local call = require("marketview_api")
local result, message
local function receive(value,err) result=value; message=err end
call("AAPL",receive); check(not result and message:find("API key"),"Missing key must be actionable without loading network modules")
package.loaded.marketview_config={api_key="fixture-only"}
local status, body, fail, reset = 200, "ok", false, 0
package.loaded["ui/network/manager"]={runWhenOnline=function(_,fn)fn()end}
package.loaded.socketutil={set_timeout=function()end, reset_timeout=function()reset=reset+1 end,table_sink=function(t)return function(chunk)if chunk then t[#t+1]=chunk end;return 1 end end}
package.loaded.json={decode=function(text)if text=="bad" then error("invalid JSON") end;return {results={{t=1000,c=5},{t=2000,c=6}}}end}
package.loaded["ssl.https"]={request=function(options)
  check(not options.url:find("fixture%-only") and options.headers.Authorization=="Bearer fixture-only","Credentials belong in header, not URL")
  check(options.redirect==false and options.url:find("api.massive.com"),"Do not redirect credentials")
  if fail then error("exception with secret must not leak") end
  local accepted=options.sink(body); if not accepted then return nil,"sink" end
  return 1,status
end}
call("AAPL",receive,7);check(result and result.last==6 and message==nil,"Successful request returns normalized data")
for _, code in ipairs({401,403,429,500}) do status=code;call("AAPL",receive);check(not result and message~=nil,"HTTP errors remain distinct") end
status=200;body="bad";call("AAPL",receive);check(not result and message:find("unreadable"),"Malformed JSON")
body=string.rep("x",524289);call("AAPL",receive);check(not result,"Bound response size")
fail=true;call("AAPL",receive);check(not result and not message:find("secret"),"Transport exceptions do not leak secrets")
check(reset==8,"Timeouts restored on all network outcomes")

-- Exercise the real viewer's request lifecycle without a KOReader device.
for _, name in ipairs({"ui/widget/buttontable","ui/widget/container/centercontainer","ui/widget/container/framecontainer","ui/widget/container/inputcontainer","ui/widget/inputdialog","ui/widget/scrolltextwidget","ui/widget/titlebar","ui/widget/verticalgroup","ui/widget/container/widgetcontainer","ui/widget/infomessage"}) do package.loaded[name]=Widget end
package.loaded.device={screen={getWidth=function()return 600 end,getHeight=function()return 800 end}}
package.loaded["ui/font"]={getFace=function()return {} end}
package.loaded["ui/size"]={padding={large=10,default=5},margin={small=5}}
package.loaded.gettext=function(text)return text end
local queue, callbacks = {}, {}
package.loaded["ui/uimanager"]={scheduleIn=function(_,_,fn)queue[#queue+1]=fn end,show=function()end,close=function()end}
package.loaded.marketview_api=function(ticker,callback)callbacks[#callbacks+1]=callback end
local Viewer=require("marketview_viewer")
local viewed={ticker="DEMO",days=30,revision=0,closed=false,graph={setData=function(self,value)self.value=value end},setText=function(self,text)self.text=text end}
setmetatable(viewed,{__index=Viewer})
viewed:getTicker("AAPL");viewed:getTicker("MSFT");queue[1]();queue[2]()
check(#callbacks==1,"Superseded scheduled requests are discarded")
viewed:getTicker("DEMO");local sampleText=viewed.text;callbacks[1](data.sample(7))
check(viewed.text==sampleText and viewed.graph.value.synthetic,"Late network result cannot replace sample")
viewed:getTicker("AAPL");queue[3]();viewed:onClose();callbacks[2](data.sample(7))
check(viewed.closed and viewed.graph.value==nil,"Closed viewer cannot be repopulated")
print(count .. " data, graph, request and viewer assertions passed (Lua 5.1 compatible).")
