-- VSCode-style plugins for better migration experience

-- 速查表函数
local function open_cheatsheet()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  -- 读取 cheatsheet 文件
  local cheatsheet_path = vim.fn.stdpath 'config' .. '/cheatsheet.txt'
  local file = io.open(cheatsheet_path, 'r')
  if not file then
    vim.notify('速查表文件不存在: ' .. cheatsheet_path, vim.log.levels.ERROR)
    return
  end

  local entries = {}
  local current_section = ''
  for line in file:lines() do
    if line:match '^## ' then
      current_section = line:gsub('^## ', ''):gsub(' @%w+', '')
    elseif line:match '|' then
      local desc, key = line:match '(.+)|(.+)'
      if desc and key then
        table.insert(entries, {
          section = current_section,
          desc = vim.trim(desc),
          key = vim.trim(key),
        })
      end
    end
  end
  file:close()

  -- 计算实际显示宽度并填充空格
  local function pad_to_width(str, target_width)
    local display_width = vim.api.nvim_strwidth(str)
    local padding = target_width - display_width
    if padding > 0 then
      return str .. string.rep(' ', padding)
    end
    return str
  end

  pickers
    .new({}, {
      prompt_title = '快捷键速查表 (输入搜索)',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          local section_padded = pad_to_width(entry.section, 14)
          local desc_padded = pad_to_width(entry.desc, 32)
          local display = section_padded .. '│ ' .. desc_padded .. '│ ' .. entry.key
          return {
            value = entry,
            display = display,
            ordinal = entry.section .. ' ' .. entry.desc .. ' ' .. entry.key,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            vim.notify('快捷键: ' .. selection.value.key, vim.log.levels.INFO)
          end
        end)
        return true
      end,
    })
    :find()
end

-- 注册快捷键 (使用 <leader>hk 避免和 Neo-tree 的 ? 冲突)
vim.keymap.set('n', '<leader>hk', open_cheatsheet, { desc = '快捷键速查表' })
vim.keymap.set('n', '<F1>', open_cheatsheet, { desc = '快捷键速查表' })

return {
  -- Comment toggle (gcc for line, gc for selection, Ctrl+/ also works)
  {
    'numToStr/Comment.nvim',
    opts = {},
    config = function()
      require('Comment').setup()
      -- VSCode style Ctrl+/ for commenting
      vim.keymap.set('n', '<C-/>', function()
        require('Comment.api').toggle.linewise.current()
      end, { desc = 'Toggle comment' })
      vim.keymap.set('v', '<C-/>', function()
        local esc = vim.api.nvim_replace_termcodes('<ESC>', true, false, true)
        vim.api.nvim_feedkeys(esc, 'nx', false)
        require('Comment.api').toggle.linewise(vim.fn.visualmode())
      end, { desc = 'Toggle comment' })
    end,
  },

  -- Multi-cursor (Ctrl+D to select word under cursor)
  {
    'mg979/vim-visual-multi',
    branch = 'master',
    init = function()
      vim.g.VM_maps = {
        ['Find Under'] = '<C-d>',
        ['Find Subword Under'] = '<C-d>',
      }
      vim.g.VM_theme = 'iceblue'
    end,
  },

  -- Toggle terminal (Ctrl+J for horizontal, different keys for other types)
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<C-j>]],
        direction = 'horizontal',
        size = function(term)
          if term.direction == 'horizontal' then
            return 15
          elseif term.direction == 'vertical' then
            return vim.o.columns * 0.4
          end
        end,
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        persist_size = true,
        float_opts = {
          border = 'curved',
          width = function()
            return math.floor(vim.o.columns * 0.8)
          end,
          height = function()
            return math.floor(vim.o.lines * 0.8)
          end,
        },
      }

      local Terminal = require('toggleterm.terminal').Terminal

      -- Track current terminal number
      local current_term = 1

      -- Create new terminal (increment and open)
      vim.keymap.set({ 'n', 't' }, '<leader>tc', function()
        current_term = current_term + 1
        vim.cmd(current_term .. 'ToggleTerm')
      end, { desc = 'Create new terminal' })

      -- Next terminal
      vim.keymap.set({ 'n', 't' }, '<leader>t]', function()
        local terms = require('toggleterm.terminal').get_all()
        if #terms == 0 then return end
        local ids = {}
        for _, t in ipairs(terms) do table.insert(ids, t.id) end
        table.sort(ids)
        local next_id = ids[1]
        for _, id in ipairs(ids) do
          if id > current_term then
            next_id = id
            break
          end
        end
        current_term = next_id
        vim.cmd(current_term .. 'ToggleTerm')
      end, { desc = 'Next terminal' })

      -- Previous terminal
      vim.keymap.set({ 'n', 't' }, '<leader>t[', function()
        local terms = require('toggleterm.terminal').get_all()
        if #terms == 0 then return end
        local ids = {}
        for _, t in ipairs(terms) do table.insert(ids, t.id) end
        table.sort(ids, function(a, b) return a > b end)
        local prev_id = ids[1]
        for _, id in ipairs(ids) do
          if id < current_term then
            prev_id = id
            break
          end
        end
        current_term = prev_id
        vim.cmd(current_term .. 'ToggleTerm')
      end, { desc = 'Previous terminal' })

      -- Floating terminal
      local float_term = Terminal:new { direction = 'float', hidden = true }
      vim.keymap.set({ 'n', 't' }, '<C-\\>', function()
        float_term:toggle()
      end, { desc = 'Toggle floating terminal' })

      -- Vertical terminal
      local vertical_term = Terminal:new { direction = 'vertical', hidden = true }
      vim.keymap.set({ 'n', 't' }, '<leader>tv', function()
        vertical_term:toggle()
      end, { desc = 'Toggle vertical terminal' })

      -- Horizontal terminal (same as C-j but with leader)
      vim.keymap.set('n', '<leader>th', '<cmd>ToggleTerm direction=horizontal<CR>', { desc = 'Toggle horizontal terminal' })

      -- Tab terminal
      vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm direction=tab<CR>', { desc = 'Toggle tab terminal' })

      -- Multi-terminal: quick access to terminals 1-5
      for i = 1, 5 do
        vim.keymap.set({ 'n', 't' }, '<leader>t' .. i, function()
          current_term = i
          vim.cmd(i .. 'ToggleTerm')
        end, { desc = 'Toggle terminal ' .. i })
      end

      -- Show all terminals (select from list)
      vim.keymap.set('n', '<leader>ts', '<cmd>TermSelect<CR>', { desc = 'Select terminal' })

      -- Send current line to terminal
      vim.keymap.set('n', '<leader>tl', '<cmd>ToggleTermSendCurrentLine<CR>', { desc = 'Send line to terminal' })

      -- Send visual selection to terminal
      vim.keymap.set('v', '<leader>tl', '<cmd>ToggleTermSendVisualSelection<CR>', { desc = 'Send selection to terminal' })

      -- Terminal navigation (exit terminal mode easily)
      vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], { desc = 'Move to left window' })
      vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], { desc = 'Move to upper window' })
      vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], { desc = 'Move to right window' })

      -- Lazygit integration
      local lazygit = Terminal:new { cmd = 'lazygit', direction = 'float', hidden = true }
      vim.keymap.set('n', '<leader>gg', function()
        lazygit:toggle()
      end, { desc = 'Toggle Lazygit' })

      -- Node REPL
      local node = Terminal:new { cmd = 'node', direction = 'horizontal', hidden = true }
      vim.keymap.set('n', '<leader>tn', function()
        node:toggle()
      end, { desc = 'Toggle Node REPL' })

      -- Python REPL
      local python = Terminal:new { cmd = 'python3', direction = 'horizontal', hidden = true }
      vim.keymap.set('n', '<leader>tp', function()
        python:toggle()
      end, { desc = 'Toggle Python REPL' })
    end,
  },

  -- Buffer tabs (like VSCode tabs)
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    opts = {
      options = {
        mode = 'buffers',
        diagnostics = 'nvim_lsp',
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = 'thin',
        offsets = {
          {
            filetype = 'neo-tree',
            text = 'File Explorer',
            highlight = 'Directory',
            separator = true,
          },
        },
      },
    },
    config = function(_, opts)
      require('bufferline').setup(opts)
      -- Tab navigation like VSCode
      vim.keymap.set('n', '<Tab>', '<cmd>BufferLineCycleNext<CR>', { desc = 'Next buffer' })
      vim.keymap.set('n', '<S-Tab>', '<cmd>BufferLineCyclePrev<CR>', { desc = 'Previous buffer' })
      vim.keymap.set('n', '<leader>x', '<cmd>bdelete<CR>', { desc = 'Close buffer' })
    end,
  },

  -- Auto save (like VSCode auto save)
  {
    'okuuva/auto-save.nvim',
    event = { 'InsertLeave', 'TextChanged' },
    opts = {
      trigger_events = {
        immediate_save = { 'BufLeave', 'FocusLost' },
        defer_save = { 'InsertLeave', 'TextChanged' },
      },
      debounce_delay = 1000,
    },
  },

  -- Better escape (jk or jj to exit insert mode quickly)
  {
    'max397574/better-escape.nvim',
    opts = {
      timeout = 300,
      default_mappings = false,
      mappings = {
        i = {
          j = {
            k = '<Esc>',
            j = '<Esc>',
          },
        },
      },
    },
  },

  -- Smooth scrolling
  {
    'karb94/neoscroll.nvim',
    opts = {
      mappings = { '<C-u>', '<C-d>', '<C-b>', '<C-f>', 'zt', 'zz', 'zb' },
      hide_cursor = true,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
    },
  },
}
