-- Scans ~/.config/hypr/hyprland.lua for every hl.bind() call by faking out
-- the hl/o API and `dofile`-ing the live config in a throwaway `lua`
-- process -- no interaction with the running Hyprland session at all. Same
-- sandboxing trick as /usr/share/omarchy/bin/omarchy-menu-keybindings'
-- build_lua_bind_cache(), except this records the verbatim `keys` string
-- rather than a decomposed modmask: hl.unbind() (confirmed live via
-- `hyprctl eval`) requires the exact modifier order a bind was made with,
-- so the literal string is what later needs reproducing, not a normalised
-- form of it.
--
-- Modes (argv[1]):
--   dump                  print every "keys<TAB>description" pair, in the
--                         order encountered (dedup'd on keys).
--   unbinds <keep-file>   print one `hl.unbind("...") -- description` line
--                         per currently-bound keys string that is NOT the
--                         first tab-field of a non-comment line in
--                         <keep-file>.
--
-- hl.on callback bodies (the screenshot region-picker's temporary binds in
-- utilities.lua) are never invoked here, since we never fire the
-- "layer.opened" event -- those ephemeral binds correctly never appear.
-- hl.unbind is faked as a no-op so a previous run's generated unbinds don't
-- suppress anything from this scan: every scan recomputes the full live
-- universe from scratch against the current allowlist.

local mode = arg[1]
local keep

if mode == "unbinds" then
  keep = {}
  local keep_file = assert(arg[2], "unbinds mode needs a keep-file path")
  for line in io.lines(keep_file) do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed ~= "" and not trimmed:match("^#") then
      local keys = trimmed:match("^([^\t]+)")
      if keys then
        keep[(keys:gsub("%s+$", ""))] = true
      end
    end
  end
end

local noop
noop = setmetatable({}, {
  __index = function()
    return noop
  end,
  __call = function()
    return noop
  end,
})

-- A dispatcher call (hl.dsp.window.close(), etc.) must return a plain,
-- metatable-free table: helpers.lua's command_from() probes fields like
-- .omarchy/.launch/.webapp/.tui with `if value.field then` to decide how to
-- stringify a dispatcher, and the shared `noop` answers every such probe
-- truthily (its own metatable), which sends it down the wrong branch and
-- then fails trying to concatenate a string with that table.
local function dsp_proxy()
  return setmetatable({}, {
    __index = function()
      return dsp_proxy()
    end,
    __call = function()
      return {}
    end,
  })
end

-- A later hl.bind() for the same combo replaces the earlier one at runtime
-- (that's exactly how window-switcher-bindings.lua turns SUPER+TAB from the
-- default "Next workspace" into "Window switcher: next" -- it's require'd
-- after the defaults). So descriptions are kept last-write-wins, while
-- `order` preserves first-seen position for stable, readable output.
local order = {}
local description_of = {}

hl = setmetatable({
  dsp = dsp_proxy(),
  bind = function(keys, dispatcher, opts)
    opts = opts or {}
    local key = tostring(keys)

    if description_of[key] == nil then
      order[#order + 1] = key
    end
    description_of[key] = opts.description or ""

    return noop
  end,
  unbind = function() end,
  get_config = function()
    return nil
  end,
}, {
  __index = function()
    return noop
  end,
})

local config = os.getenv("HOME") .. "/.config/hypr/hyprland.lua"
local file = io.open(config, "r")

if file then
  file:close()
  local ok, err = pcall(dofile, config)
  if not ok then
    io.stderr:write("[keybind-scan] warning: config raised an error mid-scan: " .. tostring(err) .. "\n")
  end
else
  io.stderr:write("[keybind-scan] " .. config .. " not found\n")
  os.exit(1)
end

for _, key in ipairs(order) do
  local description = description_of[key]

  if mode == "unbinds" then
    if not keep[key] then
      print(string.format("hl.unbind(%q) -- %s", key, description))
    end
  else
    print(key .. "\t" .. description)
  end
end
