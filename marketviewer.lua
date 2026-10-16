--[[--
Displays some text in a scrollable view.

@usage
    local marketviewer = marketviewer:new{
        title = _("I can scroll!"),
        text = _("I'll need to be longer than this example to scroll."),
    }
    UIManager:show(marketviewer)
]]
local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local Size = require("ui/size")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local GraphWidget = require("graphwidget")
local Screen = Device.screen
local InfoMessage = require("ui/widget/infomessage")
local data = require("marketdata")

local polyapi = require("polyapi")

local marketviewer = InputContainer:extend {
  title = nil,
  text = nil,
  width = nil,
  height = nil,
  buttons_table = nil,
  -- See TextBoxWidget for details about these options
  -- We default to justified and auto_para_direction to adapt
  -- to any kind of text we are given (book descriptions,
  -- bookmarks' text, translation results...).
  -- When used to display more technical text (HTML, CSS,
  -- application logs...), it's best to reset them to false.
  alignment = "left",
  justified = true,
  lang = nil,
  para_direction_rtl = nil,
  auto_para_direction = true,
  alignment_strict = false,

  title_face = nil,               -- use default from TitleBar
  title_multilines = nil,         -- see TitleBar for details
  title_shrink_font_to_fit = nil, -- see TitleBar for details
  text_face = Font:getFace("x_smallinfofont"),
  fgcolor = Blitbuffer.COLOR_BLACK,
  text_padding = Size.padding.large,
  text_margin = Size.margin.small,
  button_padding = Size.padding.default,
  -- Bottom row with Close, Find buttons. Also added when no caller's buttons defined.
  add_default_buttons = nil,
  default_hold_callback = nil,   -- on each default button
  find_centered_lines_count = 5, -- line with find results to be not far from the center
}

function marketviewer:init()
  self.ticker = "DEMO"
  self.days = 30
  self.revision = 0
  self.closed = false
  self.series = data.sample(self.days)
  self.text = data.summary("DEMO", self.series, "FICTIONAL SAMPLE — not market data")
  -- calculate window dimension
  self.align = "center"
  self.region = Geom:new {
    x = 0, y = 0,
    w = Screen:getWidth(),
    h = Screen:getHeight(),
  }
  self.width = self.width or Screen:getWidth() - Screen:scaleBySize(30)
  self.height = self.height or Screen:getHeight() - Screen:scaleBySize(30)

  self._find_next = false
  self._find_next_button = false
  self._old_virtual_line_num = 1

  if Device:hasKeys() then
    self.key_events.Close = { { Device.input.group.Back } }
  end

  local titlebar = TitleBar:new {
    width = self.width,
    align = "center",
    with_bottom_line = true,
    title = self.title,
    title_face = self.title_face,
    title_multilines = self.title_multilines,
    title_shrink_font_to_fit = self.title_shrink_font_to_fit,
    close_callback = function() self:onClose() end,
    show_parent = self,
  }


  -- buttons
  local buttons = {
    {
      { text = _("7 days"), callback = function() self:setRange(7) end },
      { text = _("30 days"), callback = function() self:setRange(30) end },
      { text = _("90 days"), callback = function() self:setRange(90) end },
    },
    {
      { text = _("Ticker"), callback = function() self:promptTicker() end },
      { text = _("Refresh"), callback = function() self:getTicker(self.ticker) end },
      { text = _("Sample"), callback = function() self:getTicker("DEMO") end },
      { text = _("Close"), callback = function() self:onClose() end },
    },
  }
  self.button_table = ButtonTable:new {
    width = self.width - 2 * self.button_padding,
    buttons = buttons,
    zero_sep = true,
    show_parent = self,
  }
  local graph_height = self.height / 4 -- match the fixed graph height

  local textw_height = self.height- titlebar:getHeight()- graph_height- self.button_table:getSize().h
  self.text_height = math.max(40, textw_height - 2 * self.text_padding - 2 * self.text_margin)


  self.scroll_text_w = ScrollTextWidget:new {
    text = self.text,
    face = self.text_face,
    fgcolor = self.fgcolor,
    width = self.width - 2 * self.text_padding - 2 * self.text_margin,
    height = self.text_height,
    dialog = self,
    alignment = self.alignment,
    justified = self.justified,
    lang = self.lang,
    para_direction_rtl = self.para_direction_rtl,
    auto_para_direction = self.auto_para_direction,
    alignment_strict = self.alignment_strict,
    scroll_callback = self._buttons_scroll_callback,
  }
  self.textw = FrameContainer:new {
    padding = self.text_padding,
    margin = self.text_margin,
    bordersize = 0,
    self.scroll_text_w
  }
  self.graph = GraphWidget:new {
    margin = 20,
    width = self.width,   -- dynamically scale to half screen width
    height = graph_height, -- dynamically scale to a third of screen height
    color = Blitbuffer.COLOR_BLACK,
  }
  

  self.graph:setData(self.series)

  self.frame = FrameContainer:new {
    radius = Size.radius.window,
    padding = 0,
    margin = 0,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new {
      titlebar,
      CenterContainer:new {
        dimen = Geom:new {
          w = self.graph:getSize().w,
          h = self.graph:getSize().h,
        },
        self.graph,
      },
      CenterContainer:new {
        dimen = Geom:new {
          w = self.width,
          h = self.textw:getSize().h,
        },
        self.textw,
      },
      CenterContainer:new {
        dimen = Geom:new {
          w = self.width,
          h = self.button_table:getSize().h,
        },
        self.button_table,
      }
    }
  }

  self[1] = WidgetContainer:new {
    align = self.align,
    dimen = self.region,
    self.frame,
  }
end


function marketviewer:onCloseWidget()
  self.closed = true
  self.revision = self.revision + 1
  UIManager:setDirty(nil, function()
    return "partial", self.frame.dimen
  end)
end

function marketviewer:setText(text)
  local old = self.scroll_text_w
  self.scroll_text_w = ScrollTextWidget:new {
    text = text, face = self.text_face, fgcolor = self.fgcolor,
    width = self.width - 2 * self.text_padding - 2 * self.text_margin,
    height = self.text_height, dialog = self, alignment = "left", justified = false,
  }
  self.textw[1] = self.scroll_text_w
  if old and old.free then old:free() end
  UIManager:setDirty(self, function() return "ui", self.frame.dimen end)
end

function marketviewer:setRange(days)
  self.days = days
  self:getTicker(self.ticker)
end

function marketviewer:getTicker(input)
  local ticker, invalid = data.ticker(input)
  if not ticker then UIManager:show(InfoMessage:new { text = invalid, timeout = 4 }); return end
  self.revision = self.revision + 1
  local revision = self.revision
  self.ticker = ticker
  self.graph:setData(nil)
  self.series = nil
  if ticker == "DEMO" then
    self.series = data.sample(self.days)
    self.graph:setData(self.series)
    self:setText(data.summary(ticker, self.series, "FICTIONAL SAMPLE — not market data"))
    return
  end
  self:setText(string.format("%s · %d calendar days\nLoading adjusted daily closes…", ticker, self.days))
  -- Give KOReader a chance to paint the loading state before the bounded request.
  UIManager:scheduleIn(0.1, function()
    if self.closed or revision ~= self.revision then return end
    polyapi(ticker, function(series, err)
      if self.closed or revision ~= self.revision then return end
      self.series = series
      self.graph:setData(series)
      if not series then self:setText(ticker .. "\n" .. tostring(err) .. "\nChoose Refresh to retry or Sample to explore offline."); return end
      self:setText(data.summary(ticker, series, self.days .. " day range") .. "\nData may be delayed by your plan. Fetched " .. os.date("!%Y-%m-%d %H:%M UTC") .. ".")
    end, self.days)
  end)
end

function marketviewer:promptTicker()
  local input_dialog
  input_dialog = InputDialog:new {
    title = _("Choose Ticker"),
    input = self.ticker == "DEMO" and "" or self.ticker,
    input_type = "text",
    description = _("Enter the ticker symbol:"),
    buttons = {
      {
        {
          text = _("Cancel"),
          callback = function()
            UIManager:close(input_dialog)
          end,
        },
        {
          text = _("Set"),
          is_enter_default = true,
          callback = function()
            local input_text = input_dialog:getInputText()
            if input_text and input_text ~= "" then
              self:getTicker(input_text)
            end
            UIManager:close(input_dialog)
          end,
        },
      },
    },
  }
  UIManager:show(input_dialog)
  input_dialog:onShowKeyboard()
end

function marketviewer:onShow()
  UIManager:setDirty(self, function()
    return "partial", self.frame.dimen
  end)
  return true
end


function marketviewer:onClose()
  self.closed = true
  self.revision = self.revision + 1
  UIManager:close(self)
  if self.close_callback then
    self.close_callback()
  end
  return true
end


return marketviewer
