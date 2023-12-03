-- combiner: grid aggregator
-- https://github.com/dstroud/combiner

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
local combiner = {}
combiner.menu = 1
combiner.rows = 8
combiner.rotation_a = 0
combiner.rotation_b = 0
combiner.intensity_a = 15
combiner.intensity_b = 15
local grid_v = grid.connect(1)  -- Virtual Grid
local grid_a = grid.connect(3)  -- Grid 'a' hardcoded to vport 3
local grid_b = grid.connect(4)  -- Grid 'b' hardcoded to vport 4
local rot = {3, 2, 1, 0, 3, 2, 1}


local function read_prefs()
  prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    combiner.rotation_a = prefs.rotation_a
    combiner.rotation_b = prefs.rotation_b
    combiner.intensity_a = prefs.intensity_a
    combiner.intensity_b = prefs.intensity_b
    grid_a:rotation(combiner.rotation_a)
    grid_b:rotation(combiner.rotation_b)
    grid_a:intensity(combiner.intensity_a)
    grid_b:intensity(combiner.intensity_b)
  end
end


local function write_prefs(from)
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  prefs.rotation_a = combiner.rotation_a
  prefs.rotation_b = combiner.rotation_b
  prefs.intensity_a = combiner.intensity_a
  prefs.intensity_b = combiner.intensity_b
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end


local function init_virtual()
  if grid_a.cols == 16 and grid_b.cols == 16 then -- technically allows a Zero ;)
    print("Combiner: Configuring virtual 16x16 Grid")
    combiner.rows = 16
  elseif grid_a.cols == 8 and grid_b.cols == 8 then
    print("Combiner: Configuring virtual 16x8 Grid")
    combiner.rows = 8
  else
    print("Combiner: Add like-sized Grids in SYSTEM>>DEVICES>>GRID ports 3 and 4")
  end

  grid_v.name = "virtual 16x".. combiner.rows
  grid_v.rows = combiner.rows
  grid_v.cols = 16
  grid_v.device = {
    id = 1,
    port = 1,
    name = "virtual 16x".. combiner.rows,
    serial = "00000000",
    -- dev = NA, @tparam userdata dev : opaque pointer to device.
    cols = 16,
    rows = combiner.rows,
  }

  if combiner.rows == 16 then
    function grid_v:led(x, y, val)
      if y <= 8 then
        grid_a:led(x, y, val)
      else
        grid_b:led(x, y - 8, val)
      end
    end
  elseif combiner.rows == 8 then
    function grid_v:led(x, y, val)
      if x <= 8 then
        grid_a:led(x, y, val)
      else
        grid_b:led(x - 8, y, val)
      end
    end
  end

  function grid_v:all(val)
    grid_a:all(val)
    grid_b:all(val)
  end

  function grid_v:refresh()
    grid_a:refresh()
    grid_b:refresh()
  end

  function grid_v:rotation()
    -- supported through mod menu... is there a reason to pass through script rotation?
  end

  function grid_v:tilt_enable()
    -- LOL
  end

end


-- define new key input handlers that pass to virtual grid
local function define_handlers()

  if combiner.rows == 16 then
    grid_a.key = function(x, y, s)
      grid_v.key(x, y, s)
    end

    grid_b.key = function(x, y, s)
      local y = y + 8
      grid_v.key(x, y, s)
    end

  elseif combiner.rows == 8 then
    grid_a.key = function(x, y, s)
      grid_v.key(x, y, s)
    end

    grid_b.key = function(x, y, s)
      local x = x + 8
      grid_v.key(x, y, s)
    end
  end

end


mod.hook.register("system_post_startup", "combiner post startup", function()
  -- due to update_devices() overwriting vports after mod hook, redefine it
  local old_update_devices = grid.update_devices
  function grid.update_devices()
    old_update_devices()
    init_virtual()    -- generate virtual interface
    read_prefs()      -- load rotation and intensity
  end
end)


-- requires norns 231114
mod.hook.register("script_post_init", "combiner post init", function()
  define_handlers()
end)


-- system mod menu for settings
local m = {}

function m.key(n, z)
  if z == 1 then
    if n == 2 then
      mod.menu.exit()
    end
  end
end


function m.enc(n, d)
  local d = util.clamp(d, -1, 1)
    if n == 2 then
    combiner.menu = util.clamp(combiner.menu + d, 1, 4)
  elseif n == 3 then
    if combiner.menu == 1 then
      combiner.rotation_a = util.clamp(combiner.rotation_a - d, -3, 3)
      grid_a:rotation(combiner.rotation_a)
    elseif combiner.menu == 2 then
        combiner.rotation_b = util.clamp(combiner.rotation_b - d, -3, 3)
        grid_b:rotation(combiner.rotation_b)
    elseif combiner.menu == 3 then
      combiner.intensity_a = util.clamp(combiner.intensity_a + d, 0, 15)
      grid_a:intensity(combiner.intensity_a)
    elseif combiner.menu == 4 then
      combiner.intensity_b = util.clamp(combiner.intensity_b + d, 0, 15)
      grid_b:intensity(combiner.intensity_b)
    end
  end
  m.redraw()
end


function m.redraw()
  screen.clear()
  screen.level(4)
  screen.move(0, 10)
  screen.text("MODS / COMBINER")

  screen.move(0, 30)
  screen.level(combiner.menu == 1 and 15 or 4)
  screen.text("rotation a")
  screen.move(127, 30)
  screen.text_right(combiner.rotation_a * 90 .. "°")

  screen.move(0, 40)
  screen.level(combiner.menu == 2 and 15 or 4)
  screen.text("rotation b")
  screen.move(127, 40)
  screen.text_right(combiner.rotation_b * 90 .. "°")

  screen.move(0, 50)
  screen.level(combiner.menu == 3 and 15 or 4)
  screen.text("intensity a")
  screen.move(127, 50)
  screen.text_right(combiner.intensity_a)

  screen.move(0, 60)
  screen.level(combiner.menu == 4 and 15 or 4)
  screen.text("intensity b")
  screen.move(127, 60)
  screen.text_right(combiner.intensity_b)

  screen.update()
end


function m.init() -- on menu entry
end


function m.deinit() -- on menu exit
  write_prefs()
end


mod.menu.register(mod.this_name, m)