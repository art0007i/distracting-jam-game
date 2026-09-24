local inspect = require("inspect")

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
local player_size = cell_size / 4
local speed = 100

-- Normalize two numbers.
function math.normalize(x, y)
    local l = (x * x + y * y) ^ .5
    if l == 0 then return 0, 0, 0 else return x / l, y / l, l end
end

function love.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 2 then
        love.mouse.setRelativeMode(true)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 2 then
        love.mouse.setRelativeMode(false)
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

function move_player(dx, dy)
    local cx = math.floor(px / cell_size)
    local cy = math.floor(py / cell_size)

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
        local target_pos = { x = px + dx, y = py + dy }
        -- TODO: if dx or dy is > cell_size the player can probably jump over walls
        -- I will fix it later probably by just moving the player several times per frame,
        -- so they move at most 1 cell_size in 1 step
        move_player(dx, dy)
        --px = target_pos.x
        --py = target_pos.y
    end
end

function love.update(dt)
    camx = px
    camy = py
end

function t(x, y)
    local w, h = love.graphics.getDimensions()
    return x - camx + w / 2, y - camy + h / 2
end

function rect_cam(type, x, y, cx, cy)
    local x, y = t(x, y)
    love.graphics.rectangle(type, x, y, cx, cy)
end

function print_cam(text, x, y)
    local x, y = t(x, y)
    love.graphics.print(text, x, y)
end

function love.draw()
    for x, cells in ipairs(maze) do
        for y, cell in ipairs(cells) do
            love.graphics.setColor(1, 1, 1)
            local thickness = cell_size - wall_size
            rect_cam("fill", cell_size * x, cell_size * y, thickness, thickness)
            if (cell.right) then
                rect_cam("fill", cell_size * (x + 0.5), cell_size * y, cell_size, thickness)
            end
            if (cell.down) then
                rect_cam("fill", cell_size * x, cell_size * (y + 0.5), thickness, cell_size)
            end
            love.graphics.setColor(0, 0, 1)
            print_cam(x .. " " .. y, cell_size * x, cell_size * y)
        end
    end
    love.graphics.setColor(34 / 255, 221 / 255, 136 / 255)
    rect_cam("fill", px - player_size / 2, py - player_size / 2, player_size, player_size)
end
