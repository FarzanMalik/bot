-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function addLog(msg, text)
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function findTargetsInGrid(x, y, range)
    local count = 0
    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id then
            if inRange(x, y, state.x, state.y, range) then
                count = count + 1
            end
        end
    end
    return count
end

function findNearestPlayer()
    local me = LatestGameState.Players[ao.id]

    local nearestPlayer = nil
    local nearestDistance = nil

    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then
            goto continue
        end

        local other = state;
        local xdiff = me.x - other.x
        local ydiff = me.y - other.y
        local distance = math.sqrt(xdiff * xdiff + ydiff * ydiff)

        if nearestPlayer == nil or nearestDistance > distance then
            nearestPlayer = other
            nearestDistance = distance
        end

        ::continue::
    end

    return nearestPlayer
end

function normalizeDirection(direction)
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    return { x = direction.x / length, y = direction.y / length }
end

function decideNextAction()
    local me = LatestGameState.Players[ao.id]

    local nearbyTargets = findTargetsInGrid(me.x, me.y, 1)

    if nearbyTargets < 3 then
        -- Move in any direction
        local direction = { x = math.random(-1, 1), y = math.random(-1, 1) }
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
        InAction = false -- Reset InAction after moving
    elseif nearbyTargets > 5 then
        -- Move diagonally to escape grid
        local direction = { x = math.random(-1, 1), y = math.random(-1, 1) }
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
        InAction = false -- Reset InAction after moving
    else
        local nearestPlayer = findNearestPlayer()
        local attackPower = 1.0

        if nearestPlayer.health >= 50 and nearestPlayer.health < 70 then
            attackPower = 0.5 -- 50% power if target health is between 50 and 70
        elseif nearestPlayer.health < 50 then
            attackPower = 0.25 -- 25% power if target health is below 50
        else
            -- Don't engage, escape using diagonal movement
            local direction = { x = math.random(-1, 1), y = math.random(-1, 1) }
            ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
            InAction = false -- Reset InAction after moving
            return
        end

        -- Attack with calculated power
        print(colors.red .. "Attacking with " .. (attackPower * 100) .. "% power." .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(me.energy * attackPower) })
        InAction = false -- Reset InAction after attacking
    end
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            InAction = true  -- InAction logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then -- InAction logic added
            print("Previous action still in progress. Skipping.")
        end

        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print \'LatestGameState\' for detailed view.")
        print("energy:" .. LatestGameState.Players[ao.id].energy)
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if LatestGameState.GameMode ~= "Playing" then
            print("game not start")
            InAction = false -- InAction logic added
            return
        end
        print("Deciding next action.")
        decideNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == undefined then
                print(colors.red .. "Unable to read energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
            InAction = false -- InAction logic added
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
