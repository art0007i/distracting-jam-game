function in_maze(x, y, size)
    if x < 1 or y < 1 then return false end
    if x > size + 1 or y > size + 1 then return false end
    return true
end


function is_visited(x, y, maze, size)
    if not in_maze(x, y, size) then return true end
    return maze[x][y].visited
end

function iter(maze, size)
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
        if (not is_visited(head.x + value.x, head.y + value.y, maze, size)) then
            table.insert(directions, #directions + 1, value)
        end
    end
    maze[head.x][head.y].visited = true
    if (#directions > 0) then
        local branch = love.math.random(1, #directions)
        local dir = directions[branch]
        local next_head = { x = head.x + dir.x, y = head.y + dir.y }
        table.insert(heads, #heads + 1, head)
        if not is_visited(next_head.x, next_head.y, maze, size) and inbounds(next_head.x, next_head.y) then
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

function populate(size)
    local maze = {}
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
    return maze
end

function generate(size)
    local maze = populate(size)
    heads = {
        {
            x = size / 2,
            y = size / 2
        }
    }

    while #heads > 0 do
        iter(maze, size)
    end

    return maze
end

return { generate=generate, populate=populate }