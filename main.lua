local inspect = require("inspect")

local maze = {}
local size = 10

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


for row = 1,size+1 do
    maze[row] = {}
    for col = 1,size+1 do
        maze[row][col] = {
            down = false,
            right = false,
            visited = false
        }
    end
end

local heads = {
    {
        x = size/2,
        y = size/2
    }
}

function is_visited(x,y)
    if x == 0 or y == 0 then return true end
    if x > size+1 or y > size+1 then return true end
    return maze[x][y].visited
end
function iter()
    print(#heads)
    if (#heads == 0) then return end
    local head = table.remove(heads)
    local directions = {}
    local potential_dirs = {
        {x=1, y=0},
        {x=-1, y=0},
        {x=0, y=1},
        {x=0, y=-1}
    }
    for index, value in ipairs(potential_dirs) do
        if (not is_visited(head.x+value.x, head.y+value.y)) then
            table.insert(directions, #directions+1, value)
        end
    end
    maze[head.x][head.y].visited = true
    if (#directions > 0) then
        local branch = love.math.random(1, #directions)
        local dir = directions[branch]
        local next_head = {x = head.x + dir.x, y = head.y + dir.y}
        print(inspect(dir))
        table.insert(heads, #heads+1, head)
        if not is_visited(next_head.x, next_head.y) and next_head.x > 0 and next_head.y > 0 and next_head.x <= size+1 and next_head.y <= size+1 then
            table.insert(heads, #heads+1, next_head)
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

local px, py = 200, 200
local speed = 100

-- Normalize two numbers.
function math.normalize(x,y) local l=(x*x+y*y)^.5 if l==0 then return 0,0,0 else return x/l,y/l,l end end

function love.keypressed(key, scancode, isrepeat)
    --if isrepeat then return end
    if key == "space" then
        print("spc")
        print(inspect(heads))
        iter()
    end
end

local time = 0
local interval = 0.1
function love.update(dt)
    time += dt
    while time > interval do
        time -= interval
        iter()
    end
    local dx, dy = 0, 0

    if love.keyboard.isDown("a") then
        dx -= 1
    end
    if love.keyboard.isDown("d") then
        dx += 1
    end

    if love.keyboard.isDown("w") then
        dy -= 1
    end
    if love.keyboard.isDown("s") then
        dy += 1
    end

    local vx,vy,len = math.normalize(dx, dy)

    px += vx * speed * dt
    py += vy * speed * dt
end

function love.draw()
    --love.graphics.print("Hello World", px, py)
    local big = 40

    for index, value in ipairs(maze) do
        for index2, value2 in ipairs(value) do
            love.graphics.setColor( 1,1,1 )
            love.graphics.circle( "fill", big*index, big*index2, big/4 )
            if (value2.down) then
                love.graphics.line(big*index, big*index2, big*index, big*(index2+1))
            end
            if (value2.right) then
                love.graphics.line(big*index, big*index2, big*(index+1), big*index2)
            end
        end
    end

    for index, value in ipairs(heads) do
        love.graphics.setColor( 1,0,0 )
        love.graphics.circle( "fill", big*value.x, big*value.y, big/8 )
    end
end
