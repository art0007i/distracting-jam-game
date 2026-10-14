local inspect = require("inspect")
local a_star = require("a_star")

local maze = {}
local size = 50

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

for row = 1, size + 1 do
    maze[row] = {}
    for col = 1, size + 1 do
        maze[row][col] = {
            down = false,
            right = false,
            visited = false
        }
    end
end

local heads = {
    {
        x = size / 2,
        y = size / 2
    }
}

function inbounds(x, y)
    if x < 1 or y < 1 then return false end
    if x > size + 1 or y > size + 1 then return false end
    return true
end

function is_visited(x, y)
    if not inbounds(x, y) then return true end
    return maze[x][y].visited
end

function iter()
    if (#heads == 0) then return end
    local head = table.remove(heads)
    local directions = {}
    local potential_dirs = {
        { x = 1, y = 0 },
        { x = -1, y = 0 },
        { x = 0, y = 1 },
        { x = 0, y = -1 }
    }
    for index, value in ipairs(potential_dirs) do
        if (not is_visited(head.x + value.x, head.y + value.y)) then
            table.insert(directions, #directions + 1, value)
        end
    end
    maze[head.x][head.y].visited = true
    if (#directions > 0) then
        local branch = love.math.random(1, #directions)
        local dir = directions[branch]
        local next_head = { x = head.x + dir.x, y = head.y + dir.y }
        table.insert(heads, #heads + 1, head)
        if not is_visited(next_head.x, next_head.y) and inbounds(next_head.x, next_head.y) then
            table.insert(heads, #heads + 1, next_head)
        end
        if dir.x < 0 or dir.y < 0 then
            head = next_head
        end
        if dir.x ~= 0 then
            maze[head.x][head.y].right = true
        end
        if dir.y ~= 0 then
            maze[head.x][head.y].down = true
        end
    end
end

while #heads > 0 do
    iter()
end

local cell_size = 40
local wall_size = 4
local px, py = cell_size * 1.5, cell_size * 1.5
local camx, camy = px, py
local player_size = 1
local player_sprite_size = cell_size / 2

local npcx, npcy = cell_size * 5.5, cell_size * 5.5

-- Normalize two numbers.
function math.normalize(x, y)
    local l = (x * x + y * y) ^ .5
    if l == 0 then return 0, 0, 0 else return x / l, y / l, l end
end

local mouse_locked = false
local jumping = false
local jump_startx, jump_starty = 0, 0
local jump_radius = 0
local jump_speed = cell_size * 3
local jump_maxdist = cell_size * 1.75

function love.keypressed(key, scancode, isrepeat)
    if key == "l" then
        mouse_locked = !mouse_locked
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 2 then
        jumping = true
        jump_startx, jump_starty = px, py
        jump_radius = 0
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 2 and jumping then
        jumping = false
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

function love.mousemoved(x, y, dx, dy, istouch)
    if love.mouse.getRelativeMode() then
        if jumping then
            local tx = px + dx
            local ty = py + dy
            local dxn,dyn,len = math.normalize(tx - jump_startx, ty - jump_starty)
            if len > jump_radius then
                tx = jump_startx + dxn * jump_radius
                ty = jump_starty + dyn * jump_radius
            end
            if (tx <= cell_size) then tx = cell_size+1 end
            if (ty <= cell_size) then ty = cell_size+1 end
            print(tx, ty)
            if (tx > cell_size*(size+2)-wall_size) then tx = cell_size*(size+2)-wall_size end
            if (ty > cell_size*(size+2)-wall_size) then ty = cell_size*(size+2)-wall_size end
            px = tx
            py = ty
            return
        end


        local dxn,dyn,len = math.normalize(dx, dy)
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

local timeloop = 0
function love.update(dt)
    love.mouse.setRelativeMode(mouse_locked)

    if jumping then
        jump_radius = math.min(jump_maxdist, jump_radius + jump_speed * dt)
    end

    camx = px
    camy = py

    timeloop = timeloop + dt
    if timeloop > 0.1 then
        timeloop = timeloop - 0.1
        local path = a_star(get_cell(px,py), get_cell(npcx, npcy), maze)
        if path then
            local near = path[#path-1]
            if near then
                npcx, npcy = (near.x * cell_size) + cell_size / 2, (near.y * cell_size) + cell_size / 2
            end
        end
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.translate(-camx + w / 2, -camy + h / 2)


    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press 'L' to lock cursor\nHold right click to jump", -40, -40)

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

    if jumping then
        love.graphics.setColor(0, 0, 1)
        love.graphics.circle("fill", jump_startx, jump_starty, jump_radius)
    end


    love.graphics.setColor(34 / 255, 221 / 255, 136 / 255)
    love.graphics.rectangle("fill", px - player_sprite_size / 2, py - player_sprite_size / 2, player_sprite_size, player_sprite_size)

    local path = a_star(get_cell(px,py), get_cell(npcx, npcy), maze)
    if path ~= nil then
        local last = path[1]
        local half = cell_size / 2
        for k, v in pairs(path) do
            local lx = cell_size * last.x
            local ly = cell_size * last.y
            local x = cell_size * v.x
            local y = cell_size * v.y
            last = v
            love.graphics.line(lx+half, ly+half, x+half, y+half)
        end
    end

    love.graphics.pop()
end
