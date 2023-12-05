-- mod to combine multiple Grids into a single virtual Grid
-- https://github.com/dstroud/combiner

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
combiner = {}     -- TODO LOCAL!
combiner.version = 0.2  -- TODO UPDATE
combiner.menu_lvl = 1
combiner.menu_pos_l1 = 1
combiner.menu_pos_l2 = 1
combiner.rows = 8
combiner.rotation_1 = 0
combiner.rotation_2 = 0
combiner.intensity_1 = 15
combiner.intensity_2 = 15

vgrid = grid.connect(1)  -- Virtual Grid -- saves having to set path for setting functions
-- TODO LOCAL!
port = {}  -- local!
setup = {}  -- local
glist = {}  -- 1-indexed list of configured vports -- LOCAL!
glookup = {} -- lookup vport id for entries in glist since we want this even when device is not connected

-- for now settings will follow the vport id I suppose. could track device id or serial I guess
-- or reinit when a change is detected'
for i = 2, 4 do
  setup[i] = {}
  setup[i] = {x = 0, y = 0, hw_rot = 0, sw_rot = 0, intensity = 0}
end

local setup_keys = { "x", "y", "hw_rot", "sw_rot", "intensity"}
local rot = {3, 2, 1, 0, 3, 2, 1}


local function read_prefs()
  local prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    if (prefs.version or 0) >= 0.2 then -- TODO adjust for breaking changes
      -- combiner.rotation_1 = prefs.rotation_1
      -- combiner.rotation_2 = prefs.rotation_2
      -- combiner.intensity_1 = prefs.intensity_1
      -- combiner.intensity_2 = prefs.intensity_2
      -- port[3]:rotation(combiner.rotation_1)
      -- port[4]:rotation(combiner.rotation_2)
      -- port[3]:intensity(combiner.intensity_1)
      -- port[4]:intensity(combiner.intensity_2)
    end
  end
end


local function write_prefs(from)
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  prefs.version = combiner.version
  -- prefs.rotation_1 = combiner.rotation_1
  -- prefs.rotation_2 = combiner.rotation_2
  -- prefs.intensity_1 = combiner.intensity_1
  -- prefs.intensity_2 = combiner.intensity_2
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end


local function calc_dimensions()
  local x_max = 0
  local y_max = 0  
  for i = 1, #glist do -- todo test with 0 configured!
    -- print("i="..i)
    -- tab.print(glist[i])
    if glist[i].device ~= nil then  -- don't count unless device is connected
      -- local port = glist[i].device.port -- fn?
      local port = glookup[i]
      
      local x = glist[i].cols + setup[port].x
      if x > x_max then
        x_max = x
        combiner.cols = x
      end
      
      local y = glist[i].rows + setup[port].y
      if y > y_max then 
        y_max = y
        combiner.rows = y
      end
      
    end
  end
  
  print("Combiner: Virtual cols = " .. combiner.cols)
  print("Combiner: Virtual rows = " .. combiner.rows)
end
  
  local function init_virtual()
  
  -- h s example
  
  -- 16x8
  -- grid_data.a[1].orientation  = "std"
  -- grid_data.a[1].cols         = 16
  -- grid_data.a[1].rows         = 8

  -- grid_data.a[2].orientation  = "rot"
  -- grid_data.a[2].cols         = 8
  -- grid_data.a[2].rows         = 16
  
  -- 16x16
  -- grid_data.a[1].orientation  = "std"
  -- grid_data.a[1].cols         = 16
  -- grid_data.a[1].rows         = 16
  
  -- no rotation for square!

  

  -- if grid_data.a[1].cols == grid_data.b[1].cols then ... horizontal
  -- if grid_data.a[1].rows == grid_data.b[1].rows then ... vertical
  
  
  -- for a = 1, #grid_data.a
    -- for b = 1, #grid_data.b
      
  -- final 'configuration' table needs to have:
  -- layout: horizontal or vertical
  -- rotation_1 bool
  -- rotation_2 bool
  
  
  -- shape = {}
  -- for i = 1, 2 do
    -- if port[3].cols == port[3].rows then
    --   shape.a = "square"
    -- elseif port[3].cols > port[3].rows then
    --   shape.a = "horizontal"
    -- elseif port[3].cols < port[3].rows then
    --   shape.a = "vertical"
    -- end
    -- if port[4].cols == port[4].rows then
    --   shape.b = "square"
    -- elseif port[4].cols > port[4].rows then
    --   shape.b = "horizontal"
    -- elseif port[4].cols < port[4].rows then
    --   shape.b = "vertical"
    -- end
    
  -- for i = 3, 4 do
  --   if port[i].cols == port[i].rows then
  --     shape[i] = "square"
  --   elseif port[i].cols > port[i].rows then
  --     shape[i] = "horizontal"
  --   elseif port[i].cols < port[i].rows then
  --     shape[i] = "vertical"
  --   end
  --   -- if port[4].cols == port[4].rows then
  --   --   shape[2] = "square"
  --   -- elseif port[4].cols > port[4].rows then
  --   --   shape[2] = "horizontal"
  --   -- elseif port[4].cols < port[4].rows then
  --   --   shape[2] = "vertical"
  --   -- end  
  -- end
  

  
  -- grid_data = {{},{}}
  -- for i = 3, 4 do
  --   table.insert(grid_data[i], {type = "std", cols = port[i].cols, rows = port[i].rows})
  --   if shape[i] ~= "square" then
  --     table.insert(grid_data[i], {type = "rot", cols = port[i].rows, rows = port[i].cols})
  --   end
  -- end 
  
  
  -- joins = {}
  
  -- if port[3].cols == port[4].cols then table.insert(joins, "cols==cols") end
  -- if port[3].rows == port[4].rows then table.insert(joins, "rows==rows") end
  -- if port[3].cols == port[4].rows then table.insert(joins, "cols==rows") end
  -- if port[3].rows == port[4].cols then table.insert(joins, "rows==cols") end

  
  -- dimensions = {}
  
  -- if port[3].cols == port[4].cols then
  --   cols = port[3].cols
  --   rows = port[3].rows + port[4].rows
  --   -- table.insert(dimensions, "1: a+b vertical " .. port[3].cols .. "x" .. port[3].rows + port[4].rows)
  --   table.insert(dimensions, "1: a+b vertical " .. cols .. "x" .. rows)
  --   table.insert(dimensions, "1: a_r+b_r horizontal " .. rows .. "x" .. cols) -- actually worse to rotate if square... hmmm
  -- end
  
  -- if port[3].rows == port[4].rows then
  --   table.insert(dimensions, "2: a+b horizontal " .. port[3].cols + port[3].cols .. "x" .. port[3].rows)
  -- end

  -- if port[3].cols == port[4].rows then
  --   table.insert(dimensions, "3: a+(b rotated) vertical " .. port[3].cols .. "x" .. port[3].rows + port[4].cols)
  -- end
  
  -- if port[3].rows == port[4].cols then
  --   table.insert(dimensions, "4: a+(b rotated) horizontal " .. port[3].cols + port[3].rows .. "x" .. port[3].rows)
  -- end

  
  -- if port[3].cols == 16 and port[4].cols == 16 then -- technically allows a Zero ;)
  --   print("Combiner: Configuring virtual 16x16 Grid")
  --   combiner.rows = 16
  -- elseif port[3].cols == 8 and port[4].cols == 8 then
  --   print("Combiner: Configuring virtual 16x8 Grid")
  --   combiner.rows = 8
  -- else
  --   print("Combiner: Add like-sized Grids in SYSTEM>>DEVICES>>GRID ports 3 and 4")
  -- end
  
  glist = {}
  glookup = {}
  for i = 2, 4 do
    if grid.vports[i].name ~= "none" then 
      port[i] = grid.connect(i)
      print("Combiner: " .. grid.vports[i].name .. " configured on port " .. i)
      table.insert(glist, grid.vports[i])
      table.insert(glookup, i)
      

      -- -- uh oh. this will reinitialize every time something is detected or plugged in!
      -- -- should these be associated with the vport id, serial, or what?
      -- setup[i] = {}
      -- setup[i] = {x = 0, y = 0, hw_rot = 0, sw_rot = 0, intensity = 0}
   
    end
    
  end

  -- function calc_dimensions()
  --   local x_max = 0
  --   local y_max = 0  
  --   for i = 1, #glist do -- todo test with 0 configured!
  --     -- print("i="..i)
  --     -- tab.print(glist[i])
  --     if glist[i].device ~= nil then  -- don't count unless device is connected
  --       -- local port = glist[i].device.port -- fn?
  --       local port = glookup[i]
        
  --       local x = glist[i].cols + setup[port].x
  --       if x > x_max then
  --         x_max = x
  --         combiner.cols = x
  --       end
        
  --       local y = glist[i].rows + setup[port].y
  --       if y > y_max then 
  --         y_max = y
  --         combiner.rows = y
  --       end
        
  --     end
  --   end
    
  --   print("Combiner: Virtual cols = " .. combiner.cols)
  --   print("Combiner: Virtual rows = " .. combiner.rows)
  -- end
  
  calc_dimensions()
  
  vgrid.name = "virtual 16x".. combiner.rows
  vgrid.rows = combiner.rows
  vgrid.cols = 16
  vgrid.device = {
    id = 1,
    port = 1,
    name = "virtual 16x".. combiner.rows,
    serial = "00000000",
    -- dev = NA, @tparam userdata dev : opaque pointer to device.
    cols = combiner.cols,
    rows = combiner.rows,
  }

  -- if combiner.rows == 16 then
  --   function vgrid:led(x, y, val)
  --     if y <= 8 then
  --       port[3]:led(x, y, val)
  --     else
  --       port[4]:led(x, y - 8, val)
  --     end
  --   end
  -- elseif combiner.rows == 8 then
  --   function vgrid:led(x, y, val)
  --     if x <= 8 then
  --       port[3]:led(x, y, val)
  --     else
  --       port[4]:led(x - 8, y, val)
  --     end
  --   end
  -- end
  
  if combiner.rows == 24 then -- TESTING
    function vgrid:led(x, y, val)
      if y <= 8 then
        port[3]:led(x, y, val)
      else
        port[4]:led(x, y - 8, val)
      end
    end
  elseif combiner.rows == 8 then
    function vgrid:led(x, y, val)
      if x <= 8 then
        port[3]:led(x, y, val)
      else
        port[4]:led(x - 8, y, val)
      end
    end
  end
  

  function vgrid:all(val)
    port[3]:all(val)
    port[4]:all(val)
  end

  function vgrid:refresh()
    port[3]:refresh()
    port[4]:refresh()
  end

  function vgrid:rotation()
    -- supported through mod menu... is there a reason to pass through script rotation?
  end

  function vgrid:tilt_enable()
    -- LOL
  end

end


-- define new key input handlers that pass to virtual grid
local function define_handlers()

  if combiner.rows == 24 then -- 16 then -- TEST
    port[3].key = function(x, y, s)
      vgrid.key(x, y, s)
    end

    port[4].key = function(x, y, s)
      local y = y + 8
      vgrid.key(x, y, s)
    end

  elseif combiner.rows == 8 then
    port[3].key = function(x, y, s)
      vgrid.key(x, y, s)
    end

    port[4].key = function(x, y, s)
      local x = x + 8
      vgrid.key(x, y, s)
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
      if combiner.menu_lvl == 2 then
        combiner.menu_lvl = 1
        m.redraw()
      else
        mod.menu.exit()
      end
    elseif n == 3 then
      combiner.menu_lvl = 2
      -- combiner.menu_port = combiner.menu_pos_l1
      combiner.menu_pos_l2 = 1
      m.redraw()
    end
  end
end


function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    if combiner.menu_lvl == 1 then
      combiner.menu_pos_l1 = util.clamp(combiner.menu_pos_l1 + d, 1, #glist)
    else
      combiner.menu_pos_l2 = util.clamp(combiner.menu_pos_l2 + d, 1, #setup_keys)
    end
  elseif n == 3 then
    if combiner.menu_lvl == 2 then
      -- local port = glist[combiner.menu_pos_l1].device.port -- fn?
      local port = glookup[combiner.menu_pos_l1]
      local key = setup_keys[combiner.menu_pos_l2]
      setup[port][key] = setup[port][key] + d -- TODO ranges + clamp!
      
      calc_dimensions() --  may just do when closing menu l2?
    
    
      --   for _, v in ipairs(setup_keys) do
      -- screen.level(combiner.menu_pos_l2 == pos and 15 or 4)
      -- screen.move(0, (pos + 1) * 10)
      -- screen.text(v)
      -- screen.move(127, (pos + 1) * 10)
      -- screen.text_right(setup[port][v])
      -- pos = pos + 1
      
    end
  
  
  -- if combiner.menu_pos_l1 == 1 then
  --   combiner.rotation_1 = util.clamp(combiner.rotation_1 - d, -3, 3)
  --   port[3]:rotation(combiner.rotation_1)
  -- elseif combiner.menu_pos == 2 then
  --     combiner.rotation_2 = util.clamp(combiner.rotation_2 - d, -3, 3)
  --     port[4]:rotation(combiner.rotation_2)
  -- elseif combiner.menu_pos == 3 then
  --   combiner.intensity_1 = util.clamp(combiner.intensity_1 + d, 0, 15)
  --   port[3]:intensity(combiner.intensity_1)
  -- elseif combiner.menu_pos == 4 then
  --   combiner.intensity_2 = util.clamp(combiner.intensity_2 + d, 0, 15)
  --   port[4]:intensity(combiner.intensity_2)
  -- end
  end
  m.redraw()
end


function m.redraw()
  screen.clear()
  -- screen.level(4)
  -- screen.move(0, 10)
  -- screen.text("MODS / COMBINER")

  -- screen.move(0, 30)
  -- screen.level(combiner.menu_pos == 1 and 15 or 4)
  -- screen.text("rotation a")
  -- screen.move(127, 30)
  -- screen.text_right(combiner.rotation_1 * 90 .. "°")

  -- screen.move(0, 40)
  -- screen.level(combiner.menu_pos == 2 and 15 or 4)
  -- screen.text("rotation b")
  -- screen.move(127, 40)
  -- screen.text_right(combiner.rotation_2 * 90 .. "°")

  -- screen.move(0, 50)
  -- screen.level(combiner.menu_pos == 3 and 15 or 4)
  -- screen.text("intensity a")
  -- screen.move(127, 50)
  -- screen.text_right(combiner.intensity_1)

  -- screen.move(0, 60)
  -- screen.level(combiner.menu_pos == 4 and 15 or 4)
  -- screen.text("intensity b")
  -- screen.move(127, 60)
  -- screen.text_right(combiner.intensity_2)
  
  if (combiner.menu_lvl or 1) == 1 then
    screen.level(4)
    screen.move(0, 10)
    screen.text("MODS / COMBINER")
    local pos = 1 -- reset on menu entry?
    -- for k, v in pairs(port) do
    --   if port[k].name ~= "none" then -- shows disconnected Grids. What about clones or old Grids?
    --     screen.move(0, (pos + 2) * 10)
    --     screen.level(combiner.menu_pos_l1 == (pos) and 15 or 4)
    --     -- local string = -- maybe strip serial or rename as colsxrows, status, etc...
    --     screen.text(util.trim_string_to_width("port " .. k .. ": ".. port[k].name, 128))
    --     pos = pos + 1
    --   end
    -- end  
    
    for i = 1, #glist do
      -- if port[k].name ~= "none" then -- shows disconnected Grids. What about clones or old Grids?
        
        -- local port = glist[combiner.menu_pos_l1].device.port  -- fn?  -- what about disconnected grids?
        local port = glookup[i]
        screen.move(0, (pos + 2) * 10)
        screen.level(combiner.menu_pos_l1 == (pos) and 15 or 4)
        -- local string = -- maybe strip serial or rename as colsxrows, status, etc...
        screen.text(util.trim_string_to_width(port .. ": ".. glist[i].name, 128))
        pos = pos + 1
      -- end
    end  
    
  else -- if combiner.menu_lvl == 2 then
    -- local port = glist[combiner.menu_port].device.port
    -- local port = glist[combiner.menu_pos_l1].device.port  -- fn?
    local port = glookup[combiner.menu_pos_l1]
    
    screen.level(4)
    screen.move(0, 10)
    screen.text(glist[combiner.menu_pos_l1].name)
    
    local pos = 1
    for _, v in ipairs(setup_keys) do
        screen.level(combiner.menu_pos_l2 == pos and 15 or 4)
        screen.move(0, (pos + 1) * 10)
        screen.text(v)
        screen.move(127, (pos + 1) * 10)
        screen.text_right(setup[port][v])
        pos = pos + 1
      
      -- for k, v in pairs(setup[port]) do
      --   screen.level(combiner.menu_pos == pos and 15 or 4)
      --   screen.move(0, (pos + 2) * 10)
      --   screen.text(k)
      --   screen.move(127, (pos + 2) * 10)
      --   screen.text_right(v)
      --   pos = pos + 1
      -- end
    end
    -- screen.level(combiner.menu_pos == 1 and 15 or 4)
    -- screen.move(0, 30)
    -- screen.text("x offset")
    -- screen.move(127, 30)
    -- screen.text_right(setup[port].x)
    
    -- screen.level(combiner.menu_pos == 2 and 15 or 4)
    -- screen.move(0, 40)
    -- screen.text("y offet")
    -- screen.move(127, 40)
    -- screen.text_right(setup[port].y)
    
    -- screen.level(combiner.menu_pos == 3 and 15 or 4)
    -- screen.move(0, 50)  
    -- screen.text("hw_rot")
    -- screen.move(127, 50)
    -- screen.text_right(setup[port].hw_rot)
    
    -- screen.level(combiner.menu_pos == 4 and 15 or 4)
    -- screen.move(0, 60)
    -- screen.text("sw_rot")
    -- screen.move(127, 60)
    -- screen.text_right(setup[port].sw_rot)
    
    -- screen.level(combiner.menu_pos == 5 and 15 or 4)
    -- screen.move(0, 70)  
    -- screen.text("intensity")
    -- screen.move(127, 70)
    -- screen.text_right(setup[port].intensity)
  end
  
  screen.update()
end


function m.init() -- on menu entry
end


function m.deinit() -- on menu exit
  write_prefs()
end


mod.menu.register(mod.this_name, m)