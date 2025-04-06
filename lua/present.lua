local M = {}

local function create_floating_window(config)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, config)
  return { buf = buf, win = win }
end

M.setup = function()
  -- nothing
end

---@class present.Slides
---@field slides present.Slides[]: The slides of the file

---@class present.Slides
---@field title string: Title of the slide
---@field body string[]: Body of the slide

--- Takes some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
  local data = { slides = {} }
  local current_slide = {
    title = "",
    body = {},
  }

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(data.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {},
      }
    else
      table.insert(current_slide.body, line)
    end
  end

  table.insert(data.slides, current_slide)
  return data
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = opts.bufnr })
  if filetype ~= "markdown" then
    vim.notify("Presentation only works on markdown files", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parse_slides(lines)

  ---@type vim.api.keyset.win_config[]
  local width = vim.o.columns
  local height = vim.o.lines

  local windows = {
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      col = 0,
      row = 0,
    },
    body = {
      relative = "editor",
      width = width,
      height = height - 5,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      col = 1,
      row = 4,
    },
    -- footer = {}
  }

  local header_float = create_floating_window(windows.header)
  local body_float = create_floating_window(windows.body)

  vim.bo[header_float.buf].filetype = "markdown"
  vim.bo[body_float.buf].filetype = "markdown"

  vim.api.nvim_win_set_option(header_float.win, "winhl", "Normal:Normal")
  vim.api.nvim_win_set_option(body_float.win, "winhl", "Normal:Normal")

  vim.api.nvim_set_current_win(body_float.win)

  local set_slide_content = function(idx)
    local slide = parsed.slides[idx]

    local padding = string.rep(" ", (width - #slide.title) / 2)
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
  end

  local current_slide = 1
  vim.keymap.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    set_slide_content(current_slide)
  end, {
    buffer = body_float.buf,
  })

  vim.keymap.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    set_slide_content(current_slide)
  end, {
    buffer = body_float.buf,
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(body_float.win, true)
  end, {
    buffer = body_float.buf,
  })

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0,
    },
  }

  for option, config in pairs(restore) do
    vim.opt[option] = config.present
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = body_float.buf,
    callback = function()
      -- reset the stuff before closing the presentation
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end

      pcall(vim.api.nvim_win_close, header_float.win, true)
    end,
  })

  set_slide_content(current_slide)
end

-- M.start_presentation()

return M
