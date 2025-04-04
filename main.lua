local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local marketviewer = require("marketviewer")

local MarketView = WidgetContainer:new{
    name = 'marketview',
    is_doc_only = false,
}

function MarketView:init()
    self.ui.menu:registerToMainMenu(self)
end

function MarketView:addToMainMenu(menu_items)
    menu_items.marketview = {
        text = _("MarketView"),
        sorting_hint = "more_tools",
        keep_menu_open = true,
        callback = function()
            NetworkMgr:runWhenOnline(function()
                local marketview = marketviewer:new {
                    title = _("Market View"),
                    text = _("Input a ticker symbol"),
                  }
                  UIManager:show(marketview)
                end)
        end,
    }
end
return MarketView
