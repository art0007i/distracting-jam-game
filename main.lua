local a_star = require("a_star")
local mazegen = require("mazegen")

local mouse_locked = false

-- conf
function reset_settings()
    dyncam = 0
    camera_smooth = 1
    zoom_modifier = 0.5
    music_volume = 0.25
    sfx_volume = 0.25
    showhints = 1
    cursor_speed = 1
end

function reset_gameplay_settings()
    cheese_count = 1
    jump_cooldown = 5
    maze_size = 10
    mouse_speed_mod = 1
    task_interval_multiplier = 1
    task_duration_multiplier = 1
end

local gameplay_settings = {
    "cheese_count",
    "jump_cooldown",
    "maze_size",
    "mouse_speed_mod",
    "task_interval_multiplier",
    "task_duration_multiplier",
}

reset_settings()
reset_gameplay_settings()

function clamp(val, min, max) return math.max(math.min(val, max), min) end

function clamp01(a) return clamp(a, 0, 1) end

function lerp(a, b, t) return a * (1 - t) + b * t end

function colorlerp(a, b, t)
    return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end

-- ez asset cache stuff
local images = {}
function img(name)
    if images[name] ~= nil then return images[name] end

    images[name] = love.graphics.newImage("assets/image/" .. name .. ".png")
    return images[name]
end

local sounds = {}
function snd_cache(name, loop)
    if sounds[name] ~= nil then return sounds[name] end

    sounds[name] = love.audio.newSource("assets/sound/" .. name .. ".ogg", "static")
    if loop then
        sounds[name]:setLooping(true)
    end
    return sounds[name]
end

function snd(name, loop)
    local sound = snd_cache(name, loop)
    if loop then
        sound:setVolume(music_volume)
    else
        sound:setVolume(sfx_volume)
    end
    return sound
end

local strings = {
    credits = "Credits",
    settings = "Options",
    main = "Main Menu",
    mainmenu = "Main Menu",
    maze = "In Maze",
    zoom_modifier = "Zoom",
    mouse_speed_mod = "Mouse Speed",
    maze_size = "Maze Size",
    jump_cooldown = "Jump Cooldown",
    reset_all = "Reset Page",
    music_volume = "Music Volume",
    sfx_volume = "Sound Volume",
    showhints = "Explain Tasks",
    cheese_count = "Cheese Count",
    dyncam = "Dynamic Camera",
    camera_smooth = "Camera Smoothing",
    cursor_speed = "Cursor Speed",
    gameplay_settings = "Balancing",
    reset_gameplay = "Reset Page",
    task_interval_multiplier = "Task Frequency Mult",
    task_duration_multiplier = "Task Duration Mult",
}
function l(txt)
    if strings[txt] then return strings[txt] end
    return txt
end

function add_setting(x, y, prop, min, max, decimal)
    y = setting_height
    setting_height = setting_height + 40
    if decimal == nil then
        decimal = 2
    end
    local bg = { type = "slider_bg", x = x, y = y, w = 120, h = 40, nopickup = true, prop = prop, decimal = decimal }
    table.insert(pickups, bg)
    local slider = { type = "slider", x = x, y = y, w = 40, h = 40, parent = bg, min = min, max = max }
    table.insert(pickups, slider)
    slider.x = slider.x + lerp(0, 80, (_G[prop] - min) / max)
end

-- possible pages main, settings, credits
function set_menu_page(page)
    if page == "reset_all" then
        reset_settings()
        set_menu_page("settings")
        for k, v in pairs(sounds) do
            if v:isLooping() and v:isPlaying() then
                v:setVolume(music_volume)
            end
        end
        return
    end
    if page == "reset_gameplay" then
        reset_gameplay_settings()
        set_menu_page("gameplay_settings")
        return
    end
    
    export_msg_time = 0
    export_msg_color = {0,1,0}
    export_msg_str = ""

    setting_height = 40
    held_item = nil
    pickups = {}
    menupage = page
    if page == "main" then
        table.insert(pickups, { type = "menu_button", x = 80, y = 330, w = 120, h = 40, page = "credits" })
        table.insert(pickups, { type = "menu_button", x = 330, y = 330, w = 120, h = 40, page = "settings" })
        table.insert(pickups,
            { type = "cheese", x = cell_size * 6, y = cell_size * 8, w = cell_size * 1.5, h = cell_size * 1.5 })
    end
    if page == "settings" then
        -- todo create sliders?
        table.insert(pickups, { type = "menu_button", x = 330, y = 440, w = 150, h = 40, page = "main" })
        table.insert(pickups, { type = "menu_button", x = 330, y = 400, w = 150, h = 40, page = "gameplay_settings" })
        table.insert(pickups, { type = "menu_button", x = 40, y = 440, w = 150, h = 40, page = "reset_all" })
        add_setting(250, 160, "music_volume", 0, 1)
        add_setting(250, 160, "sfx_volume", 0, 1)
        add_setting(250, 40, "zoom_modifier", 0, 1)
        add_setting(250, 40, "cursor_speed", 0.1, 2)
        -- add_setting(250, 40, "dyncam", 0, 1, 0) -- its bad... and i dont have space for other settings
        add_setting(250, 40, "camera_smooth", 0, 1, 0)
        add_setting(250, 160, "showhints", 0, 1, 0)
    end
    if page == "gameplay_settings" then
        table.insert(pickups, { type = "menu_button", x = 330, y = 400, w = 150, h = 40, page = "settings" })
        table.insert(pickups, { type = "menu_button", x = 330, y = 440, w = 150, h = 40, page = "main" })
        table.insert(pickups, { type = "menu_button", x = 40, y = 440, w = 150, h = 40, page = "reset_gameplay" })
        add_setting(250, 80, "mouse_speed_mod", 1, 5)
        add_setting(250, 120, "maze_size", 5, 50, 0)
        add_setting(250, 160, "jump_cooldown", 0, 30)
        add_setting(250, 160, "cheese_count", 1, 5, 0)
        add_setting(250, 160, "task_interval_multiplier", 0.25, 10)
        add_setting(250, 160, "task_duration_multiplier", 0.25, 10)
    end
    if page == "credits" then
        -- back button
        table.insert(pickups, {
            type = "hyperlink",
            x = 400,
            y = 60,
            w = 40,
            h = 40,
            thing = "Game Over Sound",
            author = "Plants vs Zombies",
            link = "https://store.steampowered.com/app/3590/Plants_vs_Zombies_GOTY_Edition/"
        })
        table.insert(pickups, {
            type = "hyperlink",
            x = 400,
            y = 120,
            w = 40,
            h = 40,
            thing = "Nom Nom Nom Sound",
            author = "That One Parry Gripp Song",
            link = "https://youtube.com/watch?v=SMWi7CLoZ2Q"
        })
        table.insert(pickups, {
            type = "hyperlink",
            x = 400,
            y = 180,
            w = 40,
            h = 40,
            thing = "Angry Birds Font",
            author = "dafont.com",
            link = "https://www.dafont.com/angrybirds.font"
        })
        table.insert(pickups, {
            type = "hyperlink",
            x = 400,
            y = 240,
            w = 40,
            h = 40,
            thing = "Music: joyful - chess smw version",
            author = "bebn legg on smwcentral",
            link = "https://www.smwcentral.net/?p=section&a=details&id=41689"
        })

        table.insert(pickups, { type = "menu_button", x = 330, y = 410, w = 120, h = 40, page = "main" })
    end
end

function reset_game(new_level)
    for k, v in pairs(sounds) do
        v:stop()
    end

    level = new_level -- mainmenu, maze
    menupage = "main"

    size = 10
    if level == "maze" then
        size = maze_size
    end
    maze = mazegen.generate(size)
    if new_level == "mainmenu" then
        for k, v in pairs(maze) do
            for k2, v2 in pairs(v) do

                if k2 ~= size+1 then
                    v2.down = true
                end
                if k ~= size+1 then
                    v2.right = true
                end

                if k2 == 9 and k > 9 then
                    v2.down = false
                end
                if k == 9 and k2 > 9 then
                    v2.right = false
                end
            end
        end
    end

    cell_size = 40
    wall_size = 4
    px, py = cell_size * 1.5, cell_size * 1.5
    camx, camy = px, py
    camzoom = 2

    screenshake_time = 0
    task_interval = 10
    task_duration = 30

    player_size = 1
    player_sprite_size = cell_size / 2
    player_pickup_dist = cell_size / 2
    held_item = nil

    -- each pickup = { type="sprite", x=1, y=2, w=3, h=4 }
    pickups = {}

    -- tasks { type="button", expire=4 }
    tasks = {}
    complete_tasks = 0
    total_time = 0
    speedup_time = 60

    npcx, npcy = cell_size * (size + 0.5), cell_size * (size + 0.5)
    last_npcx, last_npcy = npcx, npcy

    jumping = false
    jump_startx, jump_starty = 0, 0
    jump_radius = 0
    jump_maxdist = cell_size * 1.75
    jump_duration = 1
    jump_timer = 0

    gameover = false
    gameovertime = 0
    mouse_jump_interval = 1
    timeloop = 0
    current_path = nil

    task_timer = task_interval * task_interval_multiplier

    if level == "mainmenu" then
        px, py = cell_size * 11, cell_size * 11
        camx, camy = px, py
        set_menu_page("main")
    end

    if level == "maze" then
        table.insert(pickups, {
            type = "cheese",
            x = cell_size * 1.25,
            y = cell_size * 1.25,
            w = cell_size / 2,
            h =
                cell_size / 2
        })

        for i = 1, cheese_count - 1, 1 do
            local pos = get_safe_space()
            local sz = cell_size * 0.5
            local nudge = (cell_size - sz) / 2
            table.insert(pickups,
                { type = "cheese", x = ((pos.x) * cell_size) + nudge, y = (pos.y * cell_size) + nudge, w = sz, h = sz })
        end
    end

    snd("music_" .. level, true):play()

    love.window.setTitle("A Mouse's Maze - " .. l(level))
end

reset_game("mainmenu")

-- Normalize two numbers.
function math.normalize(x, y)
    local l = (x * x + y * y) ^ .5
    if l == 0 then return 0, 0, 0 else return x / l, y / l, l end
end

function inbounds(x, y)
    if x < 1 or y < 1 then return false end
    if x > size + 1 or y > size + 1 then return false end
    return true
end

function intersect(a, b) -- a and b are 'x,y,w,h' tables
    return a.x < b.x + b.w and
        a.x + a.w > b.x and
        a.y < b.y + b.h and
        a.y + a.h > b.y
end

function player_pickup_index()
    for k, v in pairs(pickups) do
        if v.nopickup == true then
        else
            local s = player_pickup_dist / 2
            if intersect({ x = px - s, y = py - s, w = player_pickup_dist, h = player_pickup_dist }, v) then
                return k
            end
        end
    end
    return -1
end

function drop_item()
    if (held_item ~= nil) then
        table.insert(pickups, held_item)
        held_item = nil
    end
end

-- shoutout this guy doing way too much reasearch into how to trim a string http://lua-users.org/wiki/StringTrim
function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function parse_setting(text)
    local txt = trim(text)
    local equal = string.find(txt, "=", 1, true)
    if equal == nil then return end
    local name = trim(string.sub(txt, 0, equal-1))
    local value = trim(string.sub(txt, equal+1))
    local val = tonumber(value)
    if val == nil then return end
    _G[name] = val
end

function love.keypressed(key, scancode, isrepeat)
    if key == "l" then
        mouse_locked = not mouse_locked
    end
    if key == "r" then
        reset_game("mainmenu")
    end
    if key == "c" and menupage == "gameplay_settings" then
        local export_str = "==== A Mouse's Maze Settings ====\n"
        for k, v in pairs(gameplay_settings) do
            export_str = export_str .. v .. "=" .. _G[v] .. "\n"
        end
        export_str = export_str.."=================================\n"
        print(export_str)
        love.system.setClipboardText(export_str)
        export_msg_color = {0,1,0}
        export_msg_time = 1
        export_msg_str = "Copied settings to clipboard!"
    end
    if key == "v" and menupage == "gameplay_settings" then
        local settings = love.system.getClipboardText()
        while true do
            local newline = string.find(settings, "\n", 1, true)
            if newline == nil then break end

            local line = string.sub(settings, 0, newline - 1)
            parse_setting(line)
            settings = string.sub(settings, newline + 1)
        end
        parse_setting(settings)

        set_menu_page("gameplay_settings")
    end
end

local showhint = 0

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        if not love.mouse.getRelativeMode() and level == "mainmenu" then
            showhint = 1
        end

        if love.mouse.getRelativeMode() then
            if held_item ~= nil then
                drop_item()
            else
                -- grab an item
                local item = player_pickup_index()
                if (item > 0) then
                    local it = table.remove(pickups, item)
                    held_item = it
                    if it.type == "hyperlink" then
                        love.system.openURL(it.link)
                    elseif it.type == "menu_button" then
                        set_menu_page(it.page)
                    elseif it.type == "push_button" then
                        complete_task(it.task)
                    end
                end
            end
        end
    end
    if button == 2 and jump_timer < 0 then
        jumping = true
        jump_startx, jump_starty = px, py
        jump_radius = 0
        jump_timer = jump_duration
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 2 and jumping then
        stop_jump()
    end
end

function sign(n)
    if n > 0 then return 1 end
    if n < 0 then return -1 end
    return 0
end

function collide(pos)
    local halfplayer = player_size / 2
    if pos - halfplayer <= 0 then
        return halfplayer
    end
    if pos + halfplayer >= cell_size - wall_size then
        return cell_size - halfplayer - wall_size
    end
    return pos
end

function get_cell(px, py)
    return {
        x = math.floor(px / cell_size),
        y = math.floor(py / cell_size)
    }
end

function get_item_cell(v)
    return get_cell(v.x + v.w / 2, v.y + v.h / 2)
end

function cell_key(cell_coord)
    return cell_coord.x .. "," .. cell_coord.y
end

function move_player(dx, dy)
    local cell = get_cell(px, py)
    local cx = cell.x
    local cy = cell.y

    if not inbounds(cx, cy) then
        -- EMERGENCY FAILSAFE!
        px = cell_size * 1.5
        py = cell_size * 1.5
        return
    end

    local has_x_wall = true
    local has_y_wall = true

    if dx > 0 then
        if inbounds(cx, cy) and maze[cx][cy].right then
            has_x_wall = false
        end
    elseif dx < 0 then
        if inbounds(cx - 1, cy) and maze[cx - 1][cy].right then
            has_x_wall = false
        end
    else
        has_x_wall = false
    end

    if dy > 0 then
        if inbounds(cx, cy) and maze[cx][cy].down then
            has_y_wall = false
        end
    elseif dy < 0 then
        if inbounds(cx, cy - 1) and maze[cx][cy - 1].down then
            has_y_wall = false
        end
    else
        has_y_wall = false
    end

    local ccx = cx * cell_size
    local ccy = cy * cell_size
    local tx = px - ccx + dx
    local ty = py - ccy + dy
    if (has_x_wall) then
        tx = collide(tx)
    end
    if (has_y_wall) then
        ty = collide(ty)
    end
    px = tx + ccx
    py = ty + ccy
end

function stop_jump()
    jumping = false
    jump_timer = jump_cooldown
end

function delete_item(v)
    if v == held_item then
        held_item = nil
        return
    end

    for k, val in pairs(pickups) do
        if v == val then
            table.remove(pickups, k)
            return
        end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if love.mouse.getRelativeMode() then
        dx = dx * cursor_speed
        dy = dy * cursor_speed

        if level == "maze" and dyncam == 1 then
            camx = camx + dx * 1
            camy = camy + dy * 1
        end

        if gameover then
            return
        end

        local ismain = level == "mainmenu" and menupage ~= "main"
        if jumping or ismain then
            local tx = px + dx
            local ty = py + dy
            local dxn, dyn, len = math.normalize(tx - jump_startx, ty - jump_starty)
            if ismain and not jumping then
                len = -math.huge
            end
            if len > jump_radius then
                tx = jump_startx + dxn * jump_radius
                ty = jump_starty + dyn * jump_radius
            end
            if (tx <= cell_size) then tx = cell_size + 1 end
            if (ty <= cell_size) then ty = cell_size + 1 end
            if (tx > cell_size * (size + 2) - wall_size) then tx = cell_size * (size + 2) - wall_size end
            if (ty > cell_size * (size + 2) - wall_size) then ty = cell_size * (size + 2) - wall_size end
            px = tx
            py = ty
            return
        end


        local dxn, dyn, len = math.normalize(dx, dy)
        -- if dx or dy is > cell_size the player can probably jump over walls
        -- so instead we do smaller steps that never go above that limit
        if (len > cell_size / 2) then
            while len > 0.1 do
                local rem = math.min(cell_size / 2, len)
                move_player(dxn * rem, dyn * rem)
                len = len - rem
            end
        else
            move_player(dx, dy)
        end
    end
end

function get_safe_space()
    local tries = 100
    local unsafe = true
    local rx, ry = 0, 0

    local pcell = get_cell(px, py)
    local ecell = get_cell(npcx, npcy)
    while unsafe and tries > 0 do
        tries = tries - 1
        rx = math.random(size + 1)
        ry = math.random(size + 1)

        local skip = false
        for k, v in pairs(pickups) do
            if cell_key(get_item_cell(v)) == cell_key({ x = rx, y = ry }) then
                skip = true
            end
        end
        if skip then
        else
            local _, _, len = math.normalize(pcell.x - rx, pcell.y - ry)
            local _, _, len2 = math.normalize(ecell.x - rx, ecell.y - ry)
            if len > size / 2 and len2 > size / 2 then
                unsafe = false
            end
        end
    end

    return { x = rx, y = ry }
end

function add_task_item(type, task, size, nopick)
    if nopick == nil then nopick = false end
    local pos = get_safe_space()
    local sz = cell_size * size
    local nudge = (cell_size - sz) / 2
    table.insert(pickups,
        {
            type = type,
            x = ((pos.x) * cell_size) + nudge,
            y = (pos.y * cell_size) + nudge,
            w = sz,
            h = sz,
            task = task,
            nopickup =
                nopick
        })
end

local colors = { { .8, 0, 0 }, { 0, .8, 0 }, { 0, 0, .8 }, { .8, .8, 0 }, { .8, 0, .8 }, { 0, .8, .8 } }

function get_task_color()
    if #colors == 0 then
        return { math.random(), math.random(), math.random(), true }
    end
    local rng = math.random(#colors)
    return table.remove(colors, rng)
end

function create_random_task()
    -- tasks:
    --   button -- you must push a button
    --   alt_button -- mouse must push a button
    --   delivery -- deliver battery to device
    --   cheese_delivery -- put the cheese in this location
    local rng = math.random(4)
    local exp = task_duration * task_duration_multiplier
    if rng == 1 then
        local task = { type = "button", expire = exp, exp1 = exp, color = { 134 / 255, 221 / 255, 136 / 255, true } }
        add_task_item("push_button", task, 0.5)
        return task
    elseif rng == 2 then
        local task = { type = "alt_button", expire = exp, exp1 = exp, color = { 1, 1, 1, true } }
        add_task_item("mouse_button", task, 0.5)
        return task
    elseif rng == 3 then
        local task = { type = "delivery", expire = exp, exp1 = exp, color = get_task_color() }
        add_task_item("device", task, 0.75, true)
        add_task_item("battery", task, 0.5)
        return task
    elseif rng == 4 then
        local task = { type = "cheese_delivery", expire = exp, exp1 = exp, color = { 1, 1, 1, true } }
        add_task_item("cheese_task", task, 0.75, true)
        return task
    else
        print("ERROR: tried generating invalid task " .. rng)
    end
end

function delete_task(v)
    v.consumed = true
    for k, val in pairs(all_items()) do
        if val.task == v then
            delete_item(val)
        end
    end

    for k, val in pairs(tasks) do
        if v == val then
            if val.color[4] == nil then
                table.insert(colors, val.color)
            end
            table.remove(tasks, k)
            return
        end
    end
end

function complete_task(v)
    if v.consumed then return end
    delete_task(v)
    local sfx = snd("task_success")
    sfx:stop()
    sfx:play()
    complete_tasks = complete_tasks + 1
end

function fail_task(v)
    if v.consumed then return end
    delete_task(v)
    local sfx = snd("task_fail")
    sfx:stop()
    sfx:play()
    screenshake_time = screenshake_time + 0.5
    mouse_jump_interval = mouse_jump_interval * 0.9
end

function task_logic(v)
    if v.expire < 0 then
        fail_task(v)
    end
end

function format_task(v)
    return string.format("%s: %.1f", l(v.type), v.expire)
end

function format_time(v)
    local hours = math.floor(v / 3600)
    v = v % 3600
    local minutes = math.floor(v / 60)
    v = v % 60
    local seconds = math.floor(v)
    v = math.floor((v % 1) * 100)

    if hours > 0 then
        return string.format("%d:%02d:%02d.%02d", hours, minutes, seconds, v)
    elseif minutes > 0 then
        return string.format("%d:%02d.%02d", minutes, seconds, v)
    else
        return string.format("%d.%02d", seconds, v)
    end
end

local mainmenurect = { x = 150, y = 150, w = 10, h = 10 }

function love.update(dt)
    export_msg_time = export_msg_time - dt
    screenshake_time = screenshake_time - dt
    love.mouse.setRelativeMode(mouse_locked)

    showhint = showhint - dt

    -- camera logic
    local camspeed = 10
    local tx, ty = px, py
    if level == "mainmenu" then
        tx, ty = cell_size * 7, cell_size * 6.5
    end
    if gameover then
        tx, ty = npcx, npcy
        camspeed = 20
    end
    camx = camx + (tx - camx) * (1.0 - math.exp(-camspeed * dt))
    camy = camy + (ty - camy) * (1.0 - math.exp(-camspeed * dt))
    local w, h = love.graphics.getDimensions()
    w = w / (2 * camzoom)
    h = h / (2 * camzoom)
    if camx > tx + w then
        camx = tx + w
    end
    if camx < tx - w then
        camx = tx - w
    end
    if camy > ty + h then
        camy = ty + h
    end
    if camy < ty - h then
        camy = ty - h
    end

    if not gameover and camera_smooth == 0 then
        camx = tx
        camy = ty
    end

    if gameover then
        gameovertime = gameovertime - dt
        if (gameovertime < 0) then
            local ate = false
            for k, v in pairs(all_items()) do
                if v.type ~= "cheese" then
                else
                    ate = true
                    delete_item(v)
                end
            end
            if ate then
                snd("nom"):play()
            end
        end
        return
    end

    -- handle deliver task
    if (held_item ~= nil and held_item.type == "battery") then
        local held_key = cell_key(get_item_cell(held_item))
        for k, v in pairs(pickups) do
            if v.type == "device" and v.task == held_item.task and cell_key(get_item_cell(v)) == held_key then
                complete_task(v.task)
                break
            end
        end
    end
    -- handle deliver_cheese task
    if (held_item ~= nil and held_item.type == "cheese") then
        local held_key = cell_key(get_item_cell(held_item))
        for k, v in pairs(pickups) do
            if v.type == "cheese_task" and cell_key(get_item_cell(v)) == held_key then
                complete_task(v.task)
                break
            end
        end
    end

    total_time = total_time + dt

    if level == "maze" then
        speedup_time = speedup_time - dt
        if speedup_time < 0 then
            speedup_time = speedup_time + 60
            task_duration = math.max(5, task_duration - 1)
            task_interval = math.max(2, task_interval - 1)
        end
    end

    -- pin held item to player
    if held_item ~= nil then
        if held_item.type == "slider" then
            held_item.x = clamp(px - held_item.w / 2, held_item.parent.x, held_item.parent.x + 80)
            held_item.y = held_item.parent.y
            _G[held_item.parent.prop] = (((held_item.x - held_item.parent.x) / 80) * (held_item.max - held_item.min)) +
                held_item.min
            if held_item.parent.decimal == 0 then
                _G[held_item.parent.prop] = math.floor(_G[held_item.parent.prop] + 0.5) -- epic math.round impl from love2d forum (just add 0.5)
            end
            if held_item.parent.prop == "music_volume" then
                for k, v in pairs(sounds) do
                    if v:isLooping() and v:isPlaying() then
                        v:setVolume(music_volume)
                    end
                end
            elseif held_item.parent.prop == "sfx_volume" then
                snd("nom"):play()
                for k, v in pairs(sounds) do
                    if not v:isLooping() and v:isPlaying() then
                        v:setVolume(sfx_volume)
                    end
                end
            end
        else
            held_item.x = px - held_item.w / 2
            held_item.y = py - held_item.h / 2
        end
    end

    -- handle jumping logic
    jump_timer = jump_timer - dt
    if jumping then
        local jump_speed = jump_maxdist * 2 / jump_duration
        jump_radius = math.min(jump_maxdist, jump_radius + jump_speed * dt)
        if jump_timer < 0 then
            stop_jump()
        end
    end

    if level == "mainmenu" then
        for k, v in pairs(all_items()) do
            if v.type ~= "cheese" then
            else
                if intersect(v, mainmenurect) then
                    reset_game("maze")
                end
            end
        end
    end

    if level == "maze" then
        -- tasks
        for k, v in pairs(tasks) do
            v.expire = v.expire - dt
            task_logic(v)
        end

        task_timer = task_timer - dt
        if task_timer < 0 then
            task_timer = task_timer + (task_interval*task_interval_multiplier)
            table.insert(tasks, create_random_task())
        end

        -- npc movement
        timeloop = timeloop + dt
        local mouse_interval = mouse_jump_interval / mouse_speed_mod
        if timeloop > mouse_interval then
            timeloop = timeloop - mouse_interval
            local shortest_path = nil
            for k, v in pairs(all_items()) do
                if v.type ~= "cheese" then
                else
                    local path = a_star(get_item_cell(v), get_cell(npcx, npcy), maze)
                    if path then
                        if not shortest_path or #path < #shortest_path then
                            shortest_path = path
                        end
                    end
                end
            end
            current_path = shortest_path
            if shortest_path then
                local near = shortest_path[#shortest_path - 1]
                if near then
                    last_npcx, last_npcy = npcx, npcy
                    npcx, npcy = (near.x * cell_size) + cell_size / 2, (near.y * cell_size) + cell_size / 2
                end
            end
        end

        -- npc eat cheese
        local npc_key = cell_key(get_cell(npcx, npcy))
        local to_eat = {}
        local total_cheese = 0
        for k, v in pairs(all_items()) do
            local skip = false
            if v.type ~= "cheese" then
                if v.type == "mouse_button" and cell_key(get_item_cell(v)) == npc_key then
                    complete_task(v.task)
                end
                skip = true
            end

            if skip then
            else
                total_cheese = total_cheese + 1
                if cell_key(get_item_cell(v)) == npc_key then
                    table.insert(to_eat, v)
                end
            end
        end
        if not gameover and #to_eat == total_cheese then
            gameover = true
            gameovertime = 5
            snd("music_" .. level, true):stop()
            snd("gameover"):play()
        else
            for k, v in pairs(to_eat) do
                delete_item(v)
                snd("nom"):play()
            end
        end
    end
end

local font_scale = 4
local font_scale_inv = 1 / font_scale

function draw_item(v)
    if v.task ~= nil then
        local max = v.task.exp1
        local min = v.task.expire
        local t = min / max
        local col = colorlerp({ 1, 0, 0 }, { 0, 1, 0 }, t)
        love.graphics.setColor(col)
        love.graphics.arc("fill", v.x + v.w / 2, v.y + v.h / 2, math.max(v.w, v.h) / 1.5, 0, math.pi * 2 * t)

        local c = v.task.color
        love.graphics.setColor(c[1], c[2], c[3])
    else
        love.graphics.setColor(1, 1, 1)
    end
    local pic = img(v.type)
    local w = pic:getWidth()
    local h = pic:getHeight()
    love.graphics.draw(pic, v.x, v.y, 0, v.w / w, v.h / h)
    local font = love.graphics.getFont()
    if v.type == "menu_button" then
        love.graphics.setColor(0, 0, 0)
        local fs = font_scale_inv * 2
        local w1 = font:getWidth(l(v.page)) * fs
        love.graphics.print(l(v.page), v.x - w1 / 2 + v.w / 2, v.y + 5, 0, fs, fs)
    end
    if v.type == "hyperlink" then
        love.graphics.setColor(0, 0, 0)
        local w1 = font:getWidth(v.thing) * font_scale_inv
        local w2 = font:getWidth(" - " .. v.author) * font_scale_inv
        local mw = math.max(w1, w2)
        love.graphics.print(v.thing, v.x - mw, v.y, 0, font_scale_inv, font_scale_inv)
        love.graphics.print(" - " .. v.author, v.x - mw, v.y + 20, 0, font_scale_inv, font_scale_inv)
    end
    if v.type == "slider_bg" then
        love.graphics.setColor(0, 0, 0)
        local w = font:getWidth(l(v.prop)) * font_scale_inv * 1.5
        love.graphics.print(l(v.prop), v.x - w, v.y + 10, 0, font_scale_inv * 1.5, font_scale_inv * 1.5)
        local st = string.format("%." .. v.decimal .. "f", _G[v.prop])
        if v.prop == "showhints" or v.prop == "dyncam" or v.prop == "camera_smooth" then
            if _G[v.prop] == 1 then
                st = "Yes"
            else
                st = "No"
            end
        end
        if v.prop == "maze_size" then
            st = string.format("%." .. v.decimal .. "f", _G[v.prop] + 1)
        end
        love.graphics.print(st, v.x + 120, v.y + 10, 0, font_scale_inv * 1.5, font_scale_inv * 1.5)
    end
end

function all_items()
    local copy = {}
    for k, v in pairs(pickups) do
        copy[k] = v
    end
    if held_item then
        copy[#copy + 1] = held_item
    end
    return copy
end

function love.load()
    local font = love.graphics.newFont(12 * font_scale)
    love.graphics.setFont(font)
end

function print_right(text, x, y, rot, size)
    if rot == nil then rot = 0 end
    if size == nil then size = 1 end
    local font = love.graphics.getFont()
    local w = font:getWidth(text) * font_scale_inv * size
    love.graphics.print(text, x - w, y, rot, font_scale_inv * size, font_scale_inv * size)
end

local rotation = 0

function love.draw()
    local w, h = love.graphics.getDimensions()
    camzoom = h / 600 * (0.25 * (16 ^ zoom_modifier))

    -- camera manipulation
    love.graphics.push()
    love.graphics.scale(camzoom)
    if screenshake_time > 0 then
        local shakex = ((math.random() * 2) - 1) * 15 * screenshake_time
        local shakey = ((math.random() * 2) - 1) * 15 * screenshake_time
        love.graphics.translate(shakex, shakey)
    end
    love.graphics.translate(-camx + w / (2 * camzoom), -camy + h / (2 * camzoom))


    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.print("Press 'L' to lock cursor\nHold right click to jump", -40, -40, 0, font_scale_inv, font_scale_inv)

    -- draw maze walls
    if level == "maze" then
        for x, cells in ipairs(maze) do
            for y, cell in ipairs(cells) do
                love.graphics.setColor(1, 1, 1)
                local thickness = cell_size - wall_size
                love.graphics.rectangle("fill", cell_size * x, cell_size * y, thickness, thickness)
                if (cell.right) then
                    love.graphics.rectangle("fill", cell_size * (x + 0.5), cell_size * y, cell_size, thickness)
                end
                if (cell.down) then
                    love.graphics.rectangle("fill", cell_size * x, cell_size * (y + 0.5), thickness, cell_size)
                end
                love.graphics.setColor(0, 0, 1)
                -- love.graphics.print(x .. " " .. y, cell_size * x, cell_size * y)
            end
        end
    else
        -- white bg
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", cell_size, cell_size, cell_size * (size + 1), cell_size * (size + 1))
    
        -- tutorial wall
        if menupage == "main" then
            love.graphics.setColor(0,0,0)
            love.graphics.rectangle("fill", cell_size*10 - wall_size, cell_size*10 - wall_size, wall_size, cell_size*3)
            love.graphics.rectangle("fill", cell_size*10 - wall_size, cell_size*10 - wall_size, cell_size*3, wall_size)
        end

        if menupage == "main" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img("logo"), cell_size * 6.5, cell_size * 5, 0, .33, .33, 512, 512)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("Give the cheese to the mouse to start.",
                150, 300, 0, font_scale_inv, font_scale_inv)
            love.graphics.print(
                "Press 'L' to lock cursor\nHold right click to jump\nPress left click to grab/drop item\nFailing to complete a task will make the mouse faster\nThe mouse follows the nearest cheese\nDon't let it eat all your cheese",
                50, 388, 0, font_scale_inv, font_scale_inv)
        end
        if menupage == "credits" then
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("Everything else by art0007i", 100, 330, 0, font_scale_inv * 2, font_scale_inv * 2)
        end
        if menupage == "gameplay_settings" then
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("Press C to copy these settings.\nPress V to paste these settings.", 100, 330, 0,
                font_scale_inv * 1.5, font_scale_inv * 1.5)
        end
        -- love.graphics.rectangle("fill", mainmenurect.x, mainmenurect.y, mainmenurect.w, mainmenurect.h)
    end

    -- draw jump radius
    if jumping then
        local larp = clamp01((jump_duration - jump_timer * 2))
        love.graphics.setColor(colorlerp({ 0, 0, 1 }, { 1, 0, 0 }, larp))
        love.graphics.circle("fill", jump_startx, jump_starty, jump_radius)
    end

    -- draw pickups
    for k, v in pairs(all_items()) do
        draw_item(v)
    end

    -- draw npc path
    --[[
    love.graphics.setColor(.2, .2, .8)
    if current_path ~= nil then
        local last = current_path[1]
        local half = cell_size / 2
        for k, v in pairs(current_path) do
            local lx = cell_size * last.x
            local ly = cell_size * last.y
            local x = cell_size * v.x
            local y = cell_size * v.y
            last = v
            love.graphics.line(lx+half, ly+half, x+half, y+half)
        end
    end
    ]] --

    -- draw player hitbox
    --love.graphics.setColor(34 / 255, 221 / 255, 136 / 255, 0.5)
    --love.graphics.rectangle("fill", px - player_sprite_size / 2, py - player_sprite_size / 2, player_sprite_size, player_sprite_size)
    -- draw player sprite
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img("cursor"), px - 6, py - 6, 0, 0.5, 0.5)

    -- draw npc sprite
    if level == "maze" then
        local npc_scale = .66
        local npc_scalex = npc_scale
        local ndx = npcx - last_npcx
        local ndy = npcy - last_npcy
        local npc_rot = math.atan(ndy, ndx)
        if (ndx < 0) then npc_scalex = -npc_scalex end

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img("mouse"), npcx, npcy, npc_rot, npc_scalex, npc_scale, 32, 32)
    else

    end
    love.graphics.pop()

    -- draw cooldown bar
    if not gameover and not jumping and jump_timer > 0 then
        local barsize = w / 5
        local fillsize = barsize * (1 - jump_timer / jump_cooldown)
        local bg_barsize = barsize + 4
        love.graphics.setColor(.2, .2, .2)
        love.graphics.rectangle("fill", w / 2 - bg_barsize / 2, (h - h / 9) - 2, bg_barsize, h / 32 + 4)
        love.graphics.setColor(.2, .2, .8)
        love.graphics.rectangle("fill", w / 2 - barsize / 2, h - h / 9, fillsize, h / 32)
    end
    if level == "maze" then
        -- draw tasks
        if not gameover and showhints == 1 then
            love.graphics.setColor(.2, .8, 0)
            local height = 48
            love.graphics.print("Tasks:", 24, 24, 0, font_scale_inv * 2, font_scale_inv * 2)
            local has_btn = false
            local has_btn2 = false
            local has_device = false
            local has_deliver2 = false
            for k, v in pairs(tasks) do
                if v.type == "button" then
                    has_btn = true
                end
                if v.type == "alt_button" then
                    has_btn2 = true
                end
                if v.type == "delivery" then
                    has_device = true
                end
                if v.type == "cheese_delivery" then
                    has_deliver2 = true
                end
            end
            if has_btn then
                love.graphics.print("Push the push button by clicking it.", 24, height, 0, font_scale_inv * 2,
                    font_scale_inv * 2)
                height = height + 24
            end
            if has_btn2 then
                love.graphics.print("Deliver the cookie to the mouse.", 24, height, 0, font_scale_inv * 2,
                    font_scale_inv * 2)
                height = height + 24
            end
            if has_device then
                love.graphics.print("Deliver the battery to the same colored device.", 24, height, 0, font_scale_inv * 2,
                    font_scale_inv * 2)
                height = height + 24
            end
            if has_deliver2 then
                love.graphics.print("Put the cheese in the square hole.", 24, height, 0, font_scale_inv * 2,
                    font_scale_inv * 2)
                height = height + 24
            end
        end
        --[[
        if not gameover then
            love.graphics.setColor(.2, .8, 0)
            local height = 48
            love.graphics.print("Tasks:", 24, 24, 0, font_scale_inv * 2, font_scale_inv * 2)
            for k, v in pairs(tasks) do
                love.graphics.print(format_task(v), 24, height, 0, font_scale_inv * 2, font_scale_inv*2)
                height = height + 24
            end
        end
        ]] --

        -- draw time and completion
        love.graphics.setColor(.2, .8, 0)
        print_right(format_time(total_time) .. " time survived", w - 24, 24, 0, 1.5)
        print_right(complete_tasks .. " tasks completed", w - 24, 48, 0, 1.5)
    end

    if gameover and gameovertime < -0.5 then
        local img_scale = math.min(w, h) / 1024
        img_scale = img_scale * clamp01(-(gameovertime + 0.5) * 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img("gameover"), w / 2, h / 2, 0, img_scale, img_scale, 512, 512)
    end
    if showhint > 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Use in-game cursor to click\n(press L to lock cursor)", love.mouse.getX() - 100,
            love.mouse.getY() + 20, 0, font_scale_inv * 2  * camzoom, font_scale_inv * 2  * camzoom)
    end

    if export_msg_time > 0 then
        local font = love.graphics.getFont()
        local scl = font_scale_inv * 2 * camzoom
        local wid = font:getWidth(export_msg_str) * scl
        love.graphics.setColor(export_msg_color)
        love.graphics.print(export_msg_str, w / 2 - wid / 2, h / 2 + 20, 0, scl, scl)
    end
end
