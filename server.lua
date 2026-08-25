local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local sharedItems = exports['qb-core']:GetShared('Items')
local ActiveMission = 0
local MissionPlayer = nil  -- source of the player who accepted the current mission
local RewardCooldowns = {} -- per-player cooldown to prevent rapid re-triggering

RegisterServerEvent('AttackTransport:akceptujto', function()
	local copsOnDuty = 0
	local _source = source
	local xPlayer = exports['qb-core']:GetPlayer(_source)
	local accountMoney = xPlayer.PlayerData.money['bank']
	if ActiveMission == 0 then
		if accountMoney < Config.ActivationCost then
			TriggerClientEvent('QBCore:Notify', _source, 'You need ' .. Config.Currency .. '' .. Config.ActivationCost .. ' in the bank to accept the mission')
		else
			for _, v in pairs(QBCore.Functions.GetPlayers()) do
				local Player = exports['qb-core']:GetPlayer(v)
				if Player ~= nil then
					if (Player.PlayerData.job.name == 'police' or Player.PlayerData.job.type == 'leo') and Player.PlayerData.job.onduty then
						copsOnDuty = copsOnDuty + 1
					end
				end
			end
			if copsOnDuty >= Config.ActivePolice then
				TriggerClientEvent('AttackTransport:Pozwolwykonac', _source)
				xPlayer.Functions.RemoveMoney('bank', Config.ActivationCost, 'armored-truck')
				MissionPlayer = _source
				OdpalTimer()
			else
				TriggerClientEvent('QBCore:Notify', _source, 'Need at least ' .. Config.ActivePolice .. ' police to activate the mission.')
			end
		end
	else
		TriggerClientEvent('QBCore:Notify', _source, 'Someone is already carrying out this mission')
	end
end)

RegisterServerEvent('qb-armoredtruckheist:server:callCops', function(streetLabel, coords)
	-- local place = "Armored Truck"
	-- local msg = "The Alarm has been activated from a "..place.. " at " ..streetLabel
	-- Why is this unused?
	TriggerClientEvent('qb-armoredtruckheist:client:robberyCall', -1, streetLabel, coords)
end)

function OdpalTimer()
	ActiveMission = 1
	Wait(Config.ResetTimer * 1000)
	ActiveMission = 0
	MissionPlayer = nil
	TriggerClientEvent('AttackTransport:CleanUp', -1)
end

RegisterServerEvent('AttackTransport:zawiadompsy', function(x, y, z)
	TriggerClientEvent('AttackTransport:InfoForLspd', -1, x, y, z)
end)

RegisterServerEvent('AttackTransport:graczZrobilnapad', function(lootTime)
	local _source = source

	-- Must be an active mission
	if ActiveMission ~= 1 then
		print('[qb-truckrobbery] Reward rejected for source ' .. _source .. ': no active mission')
		return
	end

	-- Must be the player who accepted the mission
	if MissionPlayer ~= _source then
		print('[qb-truckrobbery] Reward rejected for source ' .. _source .. ': did not start the mission')
		return
	end

	-- lootTime must be a positive number (client sends elapsed milliseconds)
	if type(lootTime) ~= 'number' or lootTime <= 0 then
		print('[qb-truckrobbery] Reward rejected for source ' .. _source .. ': invalid lootTime (' .. tostring(lootTime) .. ')')
		return
	end

	-- Per-player cooldown: prevent duplicate reward calls within the mission window
	local now = os.time()
	if RewardCooldowns[_source] and now - RewardCooldowns[_source] < Config.ResetTimer then
		print('[qb-truckrobbery] Reward rejected for source ' .. _source .. ': cooldown active')
		return
	end
	RewardCooldowns[_source] = now

	local xPlayer = exports['qb-core']:GetPlayer(_source)
	if not xPlayer then return end

	local bags = math.random(1, 3)
	local info = {
		worth = math.random(Config.Payout.Min, Config.Payout.Max)
	}
	exports['qb-inventory']:AddItem(_source, 'markedbills', bags, false, info, 'AttackTransport:graczZrobilnapad')
	TriggerClientEvent('qb-inventory:client:ItemBox', _source, sharedItems['markedbills'], 'add')

	local chance = math.random(1, 100)
	TriggerClientEvent('QBCore:Notify', _source, 'You took ' .. bags .. ' bags of cash from the van')

	if chance >= 95 then
		exports['qb-inventory']:AddItem(_source, 'security_card_01', 1, false, false, 'AttackTransport:graczZrobilnapad')
		TriggerClientEvent('qb-inventory:client:ItemBox', _source, sharedItems['security_card_01'], 'add')
	end

	-- Mission is now complete; reset state so a new mission can start
	ActiveMission = 0
	MissionPlayer = nil
	Wait(2500)
end)
