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
local logger = require("logger")

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
  local default_buttons =
  {
    {
      text = _("Choose Ticker"),
      id = "choose_ticker",
      callback = function()
        self:promptTicker()

      end,
    },
    {
      text = _("Close"),
      callback = function()
        self:onClose()
      end,
      hold_callback = self.default_hold_callback,
    },
  }
  local buttons = self.buttons_table or {}
  if self.add_default_buttons or not self.buttons_table then
    table.insert(buttons, default_buttons)
  end
  self.button_table = ButtonTable:new {
    width = self.width - 2 * self.button_padding,
    buttons = buttons,
    zero_sep = true,
    show_parent = self,
  }
  local graph_height = self.height / 4 -- match the fixed graph height

  local textw_height = self.height- titlebar:getHeight()- graph_height- self.button_table:getSize().h


  self.scroll_text_w = ScrollTextWidget:new {
    text = self.text,
    face = self.text_face,
    fgcolor = self.fgcolor,
    width = self.width - 2 * self.text_padding - 2 * self.text_margin,
    height = textw_height - 2 * self.text_padding - 2 * self.text_margin,
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
  UIManager:setDirty(nil, function()
    return "partial", self.frame.dimen
  end)
end

function marketviewer:getTicker(ticker)
  UIManager:show(InfoMessage:new{
    text = _("Loading..."),
    timeout = 0.1
  })
  print("Loading ticker data for: " .. ticker)
  polyapi(ticker, function(table_vals, err)
    if not table_vals then
      logger.err("Error loading ticker data: " .. tostring(err))
      UIManager:show(InfoMessage:new{
        text = _("Failed to load data."),
        timeout = 2,
      })
      return
    end
  
    GraphWidget:setData(table_vals)
    UIManager:setDirty(self.graph, function()
      return "partial", self.graph:getSize()
    end)
  
  local last_price = 0
  local first_price = 0
  if type(table_vals) == "table" then
    for key, value in pairs(table_vals) do
      if key == "results" then
        for i, result in ipairs(value) do
          for k, v in pairs(result) do
            if k == "c" then
              last_price = v
            end
            if k == "o" and i == 1 then
              first_price = v
            end
          end
        end
      end
    end
  end
  
  local price_change = last_price - first_price
  local display_text = "Ticker: " .. ticker .. "\n" ..
                       "Price: " .. last_price .. "\n" ..
                       "Change: " .. price_change
  
  -- Create a new text widget with the updated text
  local old_text_widget = self.scroll_text_w
  
  -- Create a new ScrollTextWidget with the updated text
  self.scroll_text_w = ScrollTextWidget:new {
    text = display_text,
    face = self.text_face,
    fgcolor = self.fgcolor,
    width = self.width - 2 * self.text_padding - 2 * self.text_margin,
    height = old_text_widget:getTextHeight(),
    dialog = self,
    alignment = self.alignment,
    justified = self.justified,
    lang = self.lang,
    para_direction_rtl = self.para_direction_rtl,
    auto_para_direction = self.auto_para_direction,
    alignment_strict = self.alignment_strict,
    scroll_callback = self._buttons_scroll_callback,
  }
  
  -- Replace the old widget with the new one in the textw container
  self.textw[1] = self.scroll_text_w
  
  -- Mark widget as dirty to trigger a redraw
  UIManager:setDirty(self.textw, function()
    return "ui", self.textw:getSize()
  end)
end)
end


function marketviewer:promptTicker()
  local input_dialog
  input_dialog = InputDialog:new {
    title = _("Choose Ticker"),
    input = "",
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
  UIManager:close(self)
  if self.close_callback then
    self.close_callback()
  end
  return true
end


return marketviewer
