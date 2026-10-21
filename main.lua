local inspect = require("inspect")
local a_star = require("a_star")
local mazegen = require("mazegen")

local mouse_locked = false

-- conf
function reset_settings()
    zoom_modifier = 0.5
    mouse_speed_mod = 1
    task_interval = 10 -- todo
    task_duration = 30 -- todo
    max_tasks = 5 -- todo
    maze_real_size = 10
    jump_cooldown = 5
end

reset_settings()

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
function snd(name, loop)
    if sounds[name] ~= nil then return sounds[name] end

    sounds[name] = love.audio.newSource("assets/sound/" .. name .. ".ogg", "static")
    if loop then
        sounds[name]:setLooping(true)
    end
    return sounds[name]
end

local strings = {
    credits = "Credits",
    settings = "Options",
    main = "Back",
    mainmenu = "Main Menu",
    maze = "In Maze",
    zoom_modifier = "Zoom",
    mouse_speed_mod = "Mouse Speed",
    maze_real_size = "Maze Size",
    jump_cooldown = "Jump Cooldown",
    reset_all = "Reset All"
}
function l(txt)
    if strings[txt] then return strings[txt] end
    return txt
end

function add_setting(x, y, prop, min, max, decimal)
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
    if (page == "reset_all") then
        reset_settings()
        set_menu_page("settings")
        return
    end
    held_item = nil
    pickups = {}
    menupage = page
    if page == "main" then
        table.insert(pickups, { type = "menu_button", x = 80, y = 330, w = 120, h = 40, page = "credits" })
        table.insert(pickups, { type = "menu_button", x = 330, y = 330, w = 120, h = 40, page = "settings" })
        table.insert(pickups, { type = "cheese", x = cell_size * 6, y = cell_size * 8, w = cell_size * 1.5, h = cell_size * 1.5 })
    end
    if page == "settings" then
        -- todo create sliders?
        table.insert(pickups, { type = "menu_button", x = 330, y = 410, w = 120, h = 40, page = "main" })
        table.insert(pickups, { type = "menu_button", x = 40, y = 440, w = 120, h = 40, page = "reset_all" })
        add_setting(250, 40, "zoom_modifier", 0, 1)
        add_setting(250, 80, "mouse_speed_mod", 1, 5)
        add_setting(250, 120, "maze_real_size", 5, 50, 0)
        add_setting(250, 160, "jump_cooldown", 0, 30)
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
        size = maze_real_size
    end
    maze = mazegen.generate(size)

    cell_size = 40
    wall_size = 4
    px, py = cell_size * 1.5, cell_size * 1.5
    camx, camy = px, py
    camzoom = 2
    player_size = 1
    player_sprite_size = cell_size / 2
    player_pickup_dist = cell_size / 2
    held_item = nil

    -- each pickup = { type="sprite", x=1, y=2, w=3, h=4 }
    pickups = {}

    -- tasks { type="button", expire=4 }
    tasks = {}

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

    task_timer = task_interval

    if level == "mainmenu" then
        px, py = cell_size * 11, cell_size * 11
        camx, camy = px, py
        set_menu_page("main")
    end

    if level == "maze" then
        table.insert(pickups, { type = "cheese", x = cell_size * 1.25, y = cell_size * 1.25, w = cell_size / 2, h =
        cell_size / 2 })
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
            goto continue
        end
        local s = player_pickup_dist / 2
        if intersect({ x = px - s, y = py - s, w = player_pickup_dist, h = player_pickup_dist }, v) then
            return k
        end
        ::continue::
    end
    return -1
end

function drop_item()
    -- handle tasks?
    table.insert(pickups, held_item)
    held_item = nil
end

function love.keypressed(key, scancode, isrepeat)
    if key == "l" then
        mouse_locked = not mouse_locked
    end
    if key == "r" then
        reset_game("mainmenu")
    end
end

local showhint = 0

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        if not love.mouse.getRelativeMode() and level == "mainmenu" then
            showhint = 1
        end
        if held_item ~= nil then
            drop_item()
        else
            -- grab an item
            local item = player_pickup_index()
            if (item > 0) then
                held_item = table.remove(pickups, item)
                if held_item.type == "hyperlink" then
                    love.system.openURL(held_item.link)
                end
                if held_item.type == "menu_button" then
                    set_menu_page(held_item.page)
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
        if level == "maze" then
            camx = camx + dx * 1
            camy = camy + dy * 1
        end

        if gameover then
            return
        end

        if jumping or level == "mainmenu" then
            local tx = px + dx
            local ty = py + dy
            local dxn, dyn, len = math.normalize(tx - jump_startx, ty - jump_starty)
            if level == "mainmenu" then
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

function create_random_task()
    return { type = "button", expire = task_duration }
end

function delete_task(v)
    for k, val in pairs(tasks) do
        if v == val then
            table.remove(tasks, k)
            return
        end
    end
end

function fail_task(v)
    delete_task(v)
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

local mainmenurect = { x = 150, y = 150, w = 10, h = 10 }

function love.update(dt)
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

    if gameover then
        gameovertime = gameovertime - dt
        if (gameovertime < 0) then
            local ate = false
            for k, v in pairs(all_items()) do
                if v.type ~= "cheese" then goto continue end
                ate = true
                delete_item(v)
                ::continue::
            end
            if ate then
                snd("nom"):play()
            end
        end
        return
    end

    -- pin held item to player
    if held_item ~= nil then
        if held_item.type == "slider" then
            held_item.x = clamp(px - held_item.w / 2, held_item.parent.x, held_item.parent.x + 80)
            held_item.y = held_item.parent.y
            _G[held_item.parent.prop] = (((held_item.x - held_item.parent.x) / 80) * (held_item.max - held_item.min)) +
            held_item.min
            if held_item.parent.decimal == 0 then
                _G[held_item.parent.prop] = math.floor(_G[held_item.parent.prop])
            end
            print(held_item.parent.prop)
            print(_G[held_item.parent.prop])
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
            if v.type ~= "cheese" then goto continue end

            if intersect(v, mainmenurect) then
                reset_game("maze")
            end
            ::continue::
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
            task_timer = task_timer + task_interval
            table.insert(tasks, create_random_task())
        end

        -- npc movement
        timeloop = timeloop + dt
        local mouse_interval = mouse_jump_interval / mouse_speed_mod
        if timeloop > mouse_interval then
            timeloop = timeloop - mouse_interval
            local shortest_path = nil
            for k, v in pairs(all_items()) do
                if v.type ~= "cheese" then goto continue end

                local path = a_star(get_item_cell(v), get_cell(npcx, npcy), maze)
                if path then
                    if not shortest_path or #path < #shortest_path then
                        shortest_path = path
                    end
                end
                ::continue::
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
            if v.type ~= "cheese" then goto continue end

            total_cheese = total_cheese + 1
            if cell_key(get_item_cell(v)) == npc_key then
                table.insert(to_eat, v)
            end
            ::continue::
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
    love.graphics.setColor(1, 1, 1)
    local pic = img(v.type)
    local w = pic:getWidth()
    local h = pic:getHeight()
    love.graphics.draw(pic, v.x, v.y, 0, v.w / w, v.h / h)
    local font = love.graphics.getFont()
    if v.type == "menu_button" then
        love.graphics.setColor(0, 0, 0)
        local fs = font_scale_inv * 2
        local w1 = font:getWidth(l(v.page)) * fs
        love.graphics.print(l(v.page), v.x - w1/2 + v.w/2, v.y + 5, 0, fs, fs)
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
        local st = string.format("%."..v.decimal.."f", _G[v.prop])
        love.graphics.print(st, v.x+120, v.y+10, 0, font_scale_inv * 1.5, font_scale_inv * 1.5)
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

    local w, h = love.graphics.getDimensions()
    love.window.setMode(w, h, {
        resizable = true
    })
end

local rotation = 0

function love.draw()
    local w, h = love.graphics.getDimensions()
    camzoom = h / 600 * (0.25 * (16 ^ zoom_modifier))

    -- camera manipulation
    love.graphics.push()
    love.graphics.scale(camzoom)
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
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", cell_size, cell_size, cell_size * (size + 1), cell_size * (size + 1))

        if menupage == "main" then
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
    -- draw tasks
    if not gameover then
        local height = 48
        love.graphics.print("Tasks:", 24, 24, 0, font_scale_inv * 2, font_scale_inv * 2)
        for k, v in pairs(tasks) do
            love.graphics.print(format_task(v), 20, height, 0, font_scale_inv, font_scale_inv)
            height = height + 24
        end
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
            love.mouse.getY() + 20, 0, font_scale_inv * 2, font_scale_inv * 2)
    end
end
