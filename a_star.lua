-- huge shoutout to https://en.wikipedia.org/wiki/A*_search_algorithm#Pseudocode
function heuristic(n, goal)
    return math.abs(n.x - goal.x) + math.abs(n.y - goal.y)
end

function key(pos)
    return pos.x .. "," .. pos.y
end

local size = 50
function inbounds(x, y)
    if x < 1 or y < 1 then return false end
    if x > size + 1 or y > size + 1 then return false end
    return true
end

function wall_intersect(cx, cy, dx, dy, maze)
    local has_x_wall = true
    local has_y_wall = true

    if dx > 0 then
        if inbounds(cx, cy) 
        and 
        maze[cx][cy].right then
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

    return has_x_wall or has_y_wall
end

function reconstruct_path(came_from, current)
    local total_path = { current }
    
    while came_from[key(current)] ~= nil do
        current = came_from[key(current)]
        table.insert(total_path, 1, current)
    end

    return total_path
end

local dirs = {
    { x = 1, y = 0 },
    { x = -1, y = 0 },
    { x = 0, y = 1 },
    { x = 0, y = -1 },
}

function a_star(start, goal, maze)
    local open_set = { }
    open_set[key(start)] = start
    local came_from = { }

    local g_score = {} -- default value = infinity
    g_score[key(start)] = 0

    local f_score = {} -- default value = infinity
    f_score[key(start)] = heuristic(start, goal)

    while next(open_set) ~= nil do
        local current
        local lowest_f = math.huge
        for k, v in pairs(open_set) do
            local f = f_score[key(v)]
            if f == nil then f = math.huge end
            if f < lowest_f then
                current = v
                lowest_f = f
            end
        end

        if key(current) == key(goal) then
            return reconstruct_path(came_from, current)
        end
        
        open_set[key(current)] = nil

        for k, v in pairs(dirs) do
            if wall_intersect(current.x, current.y, v.x, v.y, maze) then
                goto continue
            end

            local neighbor = { x = current.x + v.x, y = current.y + v.y }
            local tentative_g_score = g_score[key(current)] + 1
            local neighbor_g = g_score[key(neighbor)]
            if (neighbor_g == nil) then neighbor_g = math.huge end
            if tentative_g_score < neighbor_g then
                -- This path to neighbor is better than any previous one. Record it!
                came_from[key(neighbor)] = current
                g_score[key(neighbor)] = tentative_g_score
                f_score[key(neighbor)] = tentative_g_score + heuristic(neighbor, goal)
                
                open_set[key(neighbor)] = neighbor
            end

            ::continue::
        end
    end

    return nil
end

return a_star