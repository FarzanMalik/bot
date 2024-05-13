-- Function to roll a dice
local function rollDice()
    return math.random(1, 6)  -- Assuming a standard six-sided dice
end

-- Function to calculate the mean of a table of numbers
local function calculateMean(numbers)
    local sum = 0
    for _, num in ipairs(numbers) do
        sum = sum + num
    end
    return sum / #numbers
end

-- Function to eliminate players with rolls less than the mean
local function eliminatePlayers(players, mean)
    local remainingPlayers = {}
    for _, player in ipairs(players) do
        if player.roll >= mean then
            table.insert(remainingPlayers, player)
        end
    end
    return remainingPlayers
end

-- Function to play the game
local function playGame(numPlayers)
    math.randomseed(os.time())  -- Seed the random number generator

    local players = {}
    for i = 1, numPlayers do
        table.insert(players, {id = i, roll = rollDice()})
    end

    local winner = nil
    while #players > 1 do
        local rolls = {}
        for _, player in ipairs(players) do
            table.insert(rolls, player.roll)
        end

        local mean = calculateMean(rolls)
        players = eliminatePlayers(players, mean)

        if #players == 1 then
            winner = players[1]
        else
            -- Reset rolls for the next round
            for _, player in ipairs(players) do
                player.roll = rollDice()
            end
        end
    end

    return winner
end

-- Main function
local function main()
    local numPlayers = 25  -- Change this to adjust the number of players
    local winner = playGame(numPlayers)

    print("Winner: Player " .. winner.id .. " with a roll of " .. winner.roll)
end

-- Run the game
main()
