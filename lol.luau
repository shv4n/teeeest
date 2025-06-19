local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Animations = ReplicatedStorage.Assets.Animations
local HollowAnimations = ReplicatedStorage.Assets.HollowAnimations
local Sounds = ReplicatedStorage.Assets.Sounds

local HitDetection = require(ServerStorage.Modules.Utility.HitDetection)
local CombatManager = require(ServerStorage.Modules.Managers.CombatManager)
local SharedFunctions = require(ReplicatedStorage.Modules.Shared.SharedFunctions)
local EntityManager = require(ServerStorage.Modules.Managers.EntityManager)
local WeaponData = require(ServerStorage.Modules.Utility.WeaponData)
local KnockbackModule = require(ServerStorage.Modules.Utility.Knockback)
local DataManager = require(ServerStorage.Modules.Managers.DataManager)
local Ragdoll = require(ServerStorage.Modules.Utility.Ragdoll)
local NetworkManager = require(ReplicatedStorage.Modules.Shared.NetworkManager)
local PartyManager = require(ServerStorage.Modules.Managers.PartyManager)
local RankManager = require(ServerStorage.Modules.Managers.RankManager)
local SkillModule = require(ServerStorage.Modules.SkillModules.Skills.ServerSkills)
local AntiCheatManager = require(ServerStorage.Modules.Managers.AntiCheatManager)
local ClanData = require(ServerStorage.Modules.Utility.ClanData)
local PassivesManager = require(ServerStorage.Modules.Managers.PassivesManager)
local NPCManager = require(ServerStorage.Modules.Managers.NPCManager)
local StatData = require(ServerStorage.Modules.Utility.StatData)
local FactionManager = require(ServerStorage.Modules.Managers.FactionManager)
local Webhooks = require(ServerStorage.Modules.Utility.Webhooks)
local HairWhitelist = require(ServerStorage.Modules.Utility.HairWhitelist)
local PositionTitles = require(ServerStorage.Modules.Utility.FactionPositions)
local PlayerBonus = require(ServerStorage.Modules.Utility.PlayerBonus)
local SpecData = require(ServerStorage.Modules.Utility.SpecData)
local DamageTracker = require(ServerStorage.Modules.Utility.DamageTracker)
local TradeablesData = require(ServerStorage.Modules.Utility.TradeablesData)
local ServerSkillReqs = require(ServerStorage.Modules.Utility.ServerSkillReqs)

local HitEffectClient = ReplicatedStorage.Modules.ClientModules.ClientHitEffects
local FlashstepClient = ReplicatedStorage.Modules.ClientModules.FlashstepClient

local WebhookChannel = "VastoPatrol"

local HollowForms = { -- RANKBASED
	[15] = "VastoLorde";
	[16] = "Adjuchas";
	[17] = "Menos";
	[18] = "Fishbone";
}

local HollowComboData = { -- Their actual combo amount
	Adjuchas = 3; 
	Menos = 1;
	Fishbone = 2;
	VastoLorde = 5;
}

local HollowEXP = NPCManager:RequestEXP()

local PlayerData = {}

local function TrackDamage(Character, AttackOwner, Damage, AttackData)
	local Player = Players:GetPlayerFromCharacter(AttackOwner)
	if Player and Character:GetAttribute("CurrentState") ~= "Unconscious" then
		DamageTracker:Track(Character, AttackOwner, Damage)
		
		if Character:GetAttribute("DelayedDeath") then
			if AttackOwner.Name == Character:GetAttribute("DelayedDeathOwner") then
				local DelayedDeathDamage = Character:GetAttribute("DelayedDeath")
				DelayedDeathDamage += Damage
				Character:SetAttribute("DelayedDeath", DelayedDeathDamage)
			end
		end
		
		local Profile = DataManager:RequestProfile(Player)
		local Race = Profile.ClientData.Race
		local UltAmount = Profile.ClientData.BankaiMeter
		
		local ChargeRate = StatData.BankaiChargeRate
		if FactionManager:GladiatorActive() then
			ChargeRate = StatData.GladiatorBankaiChargeRate
		end

		local BankaiMeterGain = Damage * ChargeRate
		local AccessoryMeterGain = AttackOwner:GetAttribute("AccessoryMeterGain")
		if AccessoryMeterGain then
			BankaiMeterGain += BankaiMeterGain * AccessoryMeterGain
		end
		
		local OpposingFaction = true
		if StatData.Factions[Profile.ClientData.Race] ~= "Shinigami" then
			--OpposingFaction = nil
		end
		
		local TimeDifference = DateTime.now().UnixTimestamp - Profile.ClientData.BankaiTimer
		
		local BankaiCooldown = StatData.BankaiCooldown * 60
		if StatData.Factions[Profile.ClientData.Race] == "Arrancar" then
			BankaiCooldown = StatData.ResCooldown * 60
		end
		
		if Profile.ClientData.BankaiUnlocked == true and OpposingFaction then
			if TimeDifference >= BankaiCooldown then
				if AttackOwner:GetAttribute("ZanpakutoState") <= 1 then
					if UltAmount + BankaiMeterGain < Profile.ClientData.MaxBankaiMeter then
						UltAmount += BankaiMeterGain
						Profile.ClientData.BankaiMeter = UltAmount
						AttackOwner:SetAttribute("BankaiMeter", UltAmount)
					else
						Profile.ClientData.BankaiMeter = Profile.ClientData.MaxBankaiMeter
						AttackOwner:SetAttribute("BankaiMeter", AttackOwner:GetAttribute("MaxBankaiMeter"))
					end
				elseif AttackOwner:GetAttribute("ZanpakutoState") == 2 then
					if Race == "Vastocar" then
						local SecondBankaiMeter = AttackOwner:GetAttribute("SecondBankaiMeter")
						if SecondBankaiMeter + BankaiMeterGain < AttackOwner:GetAttribute("MaxSecondBankaiMeter") then
							SecondBankaiMeter += BankaiMeterGain
							AttackOwner:SetAttribute("SecondBankaiMeter", SecondBankaiMeter)
						else
							AttackOwner:SetAttribute("SecondBankaiMeter", AttackOwner:GetAttribute("MaxSecondBankaiMeter"))
						end
					end
				end
			end
			
			if AttackOwner:GetAttribute("Kenpachi") then
				local UltAmount = AttackOwner:GetAttribute("BankaiMeter")
				local MaxBankaiMeter = AttackOwner:GetAttribute("MaxBankaiMeter")
				
				BankaiMeterGain *= SpecData.Nozarashi.DamageToMeterRate
				
				if UltAmount + BankaiMeterGain < MaxBankaiMeter then
					UltAmount += BankaiMeterGain
					AttackOwner:SetAttribute("BankaiMeter", UltAmount)
				else
					AttackOwner:SetAttribute("BankaiMeter", AttackOwner:GetAttribute("MaxBankaiMeter"))
				end
			end
		end
		
		if Race == "Visored" then
			local SecondBankaiMeter = AttackOwner:GetAttribute("SecondBankaiMeter")
			local MeterGain = Damage
			local HealthVariant = AttackOwner:GetAttribute("VisoredHealth") or (AttackOwner:GetAttribute("VisoredDownsideHealth") and AttackOwner:GetAttribute("VisoredMastered") == true)

			if not AttackOwner:GetAttribute("VisoredActive") then -- or HealthVariant	
				if SecondBankaiMeter + MeterGain < AttackOwner:GetAttribute("MaxSecondBankaiMeter") then
					if HealthVariant then
						MeterGain *= 0.15
					end
					SecondBankaiMeter += MeterGain
					AttackOwner:SetAttribute("SecondBankaiMeter", SecondBankaiMeter)
				else
					AttackOwner:SetAttribute("SecondBankaiMeter", AttackOwner:GetAttribute("MaxSecondBankaiMeter"))
				end
			end
		elseif StatData.Factions[Race] == "Quincy" and Profile.ClientData.LetztStil then
			local SecondBankaiMeter = AttackOwner:GetAttribute("SecondBankaiMeter")
			local MeterGain = Damage

			if not AttackOwner:GetAttribute("LetztStilActive") then	
				if SecondBankaiMeter + MeterGain < AttackOwner:GetAttribute("MaxSecondBankaiMeter") then
					SecondBankaiMeter += MeterGain
					AttackOwner:SetAttribute("SecondBankaiMeter", SecondBankaiMeter)
				else
					AttackOwner:SetAttribute("SecondBankaiMeter", AttackOwner:GetAttribute("MaxSecondBankaiMeter"))
				end
			end
		end
	end
end

local function DamageTaken(Character, AttackData, AttackOwner, HitType)
	local Player = Players:GetPlayerFromCharacter(Character)
	local Profile = DataManager:RequestProfile(Player)
	
	local Player = Players:GetPlayerFromCharacter(Character)
	local ImpactSound = AttackData.ImpactSound
	local Damage = AttackData.Damage
	local HitEffect = AttackData.HitEffect
	
	Damage = PassivesManager:ApplyActivePassives(Character, AttackData, AttackOwner, HitType, Profile.ClientData, PlayerData[Character.Name])
	
	--[[if not AttackData.TrueDamage then
		local HierroHit
		if Character:GetAttribute("EntityType") == "VastoLorde" then
			Damage *= 0.7

			local RandomHierro = math.random(1, 5)
			ImpactSound = ReplicatedStorage.Assets.SkillSounds.Hollow["HierroImpact" .. RandomHierro]
			HitEffect = "Hierro"
		end
	end]]
	if (Character.Humanoid.Health - Damage) <= 1 then	
		Damage = 0
		EntityManager:ChangeState(Character, "TriggerUnconscious", AttackOwner)
	end
	Character.Humanoid:TakeDamage(Damage)
	if AttackOwner ~= Character then
		TrackDamage(Character, AttackOwner, Damage, AttackData)
	end
	
	if Character.Head:FindFirstChildWhichIsA("BodyVelocity") then
		Character.Head:FindFirstChildWhichIsA("BodyVelocity"):Destroy()
	end
	
	if not AttackData.NoHitEffect then
		if ImpactSound then
			if ImpactSound ~= "None" then
				local Impact = ImpactSound:Clone()
				Impact.PlayOnRemove = true
				Impact.Parent = Character.HumanoidRootPart
				Impact:Destroy()
				Impact = nil
			end
		else
			local Impact = Sounds["ImpactSound" .. math.random(1, 2)]:Clone()
			Impact.PlayOnRemove = true
			Impact.Parent = Character.HumanoidRootPart
			Impact:Destroy()
			Impact = nil
		end
		
		local PathData = {Module = HitEffectClient, Skill = "ApplyHitEffect"}
		local RenderDistance = 1000
		NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathData, AttackData.HitEffect, AttackOwner)
	end
	
	FactionManager:DropCaptureItem(Player)

	if Character:GetAttribute("EntityType") == "VastoLorde" then
		local HealCutDuration = 5
		PlayerData[Character.Name].HighSpeedTimer = DateTime.now().UnixTimestampMillis
		Character:SetAttribute("HSPCut", true)
		task.delay(HealCutDuration, function()
			if PlayerData[Character.Name] and DateTime.now().UnixTimestampMillis - PlayerData[Character.Name].HighSpeedTimer >= HealCutDuration * 995 then
				Character:SetAttribute("HSPCut", nil)
			end
		end)
	end
end

local function PerfectFlashstep(Character, AttackOwner)	
	local PathData = {Module = FlashstepClient, Skill = "Evaded"}
	local RenderDistance = 1000
	NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathData, "Arrancar")
end

local HollowData = {
	Idle = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerSprint = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				StateMachine:SetState("Sprinting")
				StateMachine:Trigger("Sprint", StateMachine, Character)
			end
		end,	
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		TriggerHollowTransform = function(StateMachine, Character)
			StateMachine:SetState("Action")
			StateMachine:Trigger("HollowTransform", StateMachine, Character)
		end,
		TriggerLAttack = function(StateMachine, Character)
			StateMachine:SetState("Attacking")
			StateMachine:Trigger("LightAttack", StateMachine, Character)
			
			if PlayerData[Character.Name].FeintQueued then
				PlayerData[Character.Name].FeintQueued = nil
				task.delay(0.25, function()
					StateMachine:Trigger("TriggerM2", StateMachine, Character)
				end)
			end
		end,
		TriggerM2 = function(StateMachine, Character)			
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("FeintTimer")
			if TimeDifference >= 1500 then
				PlayerData[Character.Name].FeintQueued = true
				task.delay(0.7, function()
					if PlayerData[Character.Name].FeintQueued then
						PlayerData[Character.Name].FeintQueued = nil
					end
				end)
			end
		end,
		TriggerCAttack = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:SetState("CriticalAttacking")
				StateMachine:Trigger("CriticalAttack", StateMachine, Character)
			end
		end,
		TriggerParry = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:SetState("Parrying")
				StateMachine:Trigger("Parry", StateMachine, Character)
			end
		end,
		TriggerExecute = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:SetState("Executing")
				StateMachine:Trigger("Execute", StateMachine, Character)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)	
			end
		end,
		TriggerSkill = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			StateMachine:SetState("Skill")
			StateMachine:Trigger("SkillPress", StateMachine, Character, ...)
		end,
		TriggerDash = function(StateMachine, Character, KeyPressed)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("DashTimer")
			
			if HollowForms[ShinigamiRank] == "VastoLorde" and TimeDifference >= 1750 then
				StateMachine:PushState("Idle")
				StateMachine:SetState("Dashing")
				StateMachine:Trigger("Dash", StateMachine, Character, KeyPressed)
			end
		end,
		TriggerFlashstep = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if HollowForms[ShinigamiRank] == "VastoLorde" or HollowForms[ShinigamiRank] == "Menos" then
				local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("FlashstepTimer")
				
				local Cooldown = Character:GetAttribute("FlashstepCooldown")
				local MaxHealth = Character.Humanoid.MaxHealth
				local Health = Character.Humanoid.Health

				if Health <= MaxHealth * 0.8 then
					local HealthRange = (MaxHealth * 0.8) - 1
					local FlashstepCDRange = Cooldown - StatData.FlashstepCooldownScale * Cooldown
					local ScaledFlashstepCD = (((Health - 1) * FlashstepCDRange) / HealthRange) + StatData.FlashstepCooldownScale * Cooldown
					Cooldown = ScaledFlashstepCD
				end
				
				local ReiatsuValue = Character:GetAttribute("Reiatsu")
				ReiatsuValue -= 5
				if TimeDifference >= Cooldown and ReiatsuValue >= 0 then
					StateMachine:PushState("Idle")
					StateMachine:SetState("Flashstep")
					StateMachine:Trigger("Flashstep", StateMachine, Character)
				end
			end
		end,
		TriggerReset = function(StateMachine, Character)
			StateMachine:SetState("Action")
			StateMachine:Trigger("Reset", StateMachine, Character)
		end,
	},
	Attacking = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerM2 = function(StateMachine, Character)
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("FeintTimer")
			if PlayerData[Character.Name].AllowFeint and TimeDifference >= 1500 then
				Character:SetAttribute("FeintTimer", DateTime.now().UnixTimestampMillis)
				local Combo = Character:GetAttribute("Combo")
				Combo -= 1
				if Combo <= 1 then
					Combo = 1
				end
				Character:SetAttribute("Combo", Combo)

				local FeintSound = Sounds.Feint:Clone()
				FeintSound.PlayOnRemove = true
				FeintSound.Parent = Character.HumanoidRootPart
				FeintSound:Destroy()
				FeintSound = nil	
				SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", true)

				task.delay(0.13, function()
					if Character then
						StateMachine:Trigger("ReleaseAttacking", StateMachine, Character)
					end
				end)
			end
		end,
		LightAttack = function(StateMachine, Character, DeflectAnimation)
			if not Character:GetAttribute("AttackCD") then
				local Player = Players:GetPlayerFromCharacter(Character)
				local Profile = DataManager:RequestProfile(Player)
				local ShinigamiRank = Profile.ClientData.ShinigamiRank
				
				Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") - 2
				Character.Humanoid.JumpHeight = 0				
				
				local WeaponTable = {
					Adjuchas = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 14,

						BlockDamage = 17,
						DeflectDamage = 21,

						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.1,
						SoftStunTime = 0.3,

						Properties = {
							Range = 12,
							Width = 12,
							Height = 12,
							Length = 0,
						},
					};
					Fishbone = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 7,

						BlockDamage = 10,
						DeflectDamage = 15,

						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.1,
						SoftStunTime = 0.3,

						Properties = {
							Range = 11,
							Width = 11,
							Height = 12,
							Length = 0,
						},
					};
					VastoLorde = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 9,

						BlockDamage = 10,
						DeflectDamage = 15,

						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.1,
						SoftStunTime = 0.3,

						Properties = {
							Range = 7,
							Width = 6,
							Height = 7,
							Length = 0,
						},
					};
				}
				local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("ComboTimer")
				if TimeDifference >= 1500 then 
					Character:SetAttribute("Combo", 1)
				end
				Character:SetAttribute("ComboTimer", DateTime.now().UnixTimestampMillis)
				
				local Combo = Character:GetAttribute("Combo")
				
				if Combo > HollowComboData[HollowForms[ShinigamiRank]] then
					Combo = HollowComboData[HollowForms[ShinigamiRank]]
				end
				
				local ShinigamiRank = Profile.ClientData.ShinigamiRank
				local LightAttack = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]]["Attack" .. Combo])
				LightAttack:Play()
				
				Combo += 1
				Character:SetAttribute("Combo", Combo)

				LightAttack.KeyframeReached:Connect(function(KeyframeName)
					if KeyframeName == "HitFrame" then
						if HollowForms[ShinigamiRank] == "Menos" then
							Character:SetAttribute("AttackCD", true)
							local MenosAttackTable = {
								Blockable = false,	
								Parryable = true,
								Endlag = 0.3,
								Damage = 60,

								BlockDamage = 99,
								DeflectDamage = 99,

								ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

								TrueStunTime = 0.1,
								SoftStunTime = 0.4,

								Properties = {
									Range = 40,
									Width = 60,
									Height = 20,
									Length = 7,
								},
							}
							
							local MenosStomp = ReplicatedStorage.Assets.HollowSounds.MenosStomp:Clone()
							MenosStomp.Parent = Character.MenosFootLeft
							MenosStomp:Play()
							game:GetService("Debris"):AddItem(MenosStomp, 1.8)
							
							local AccurateCFrame = Character.HumanoidRootPart.CFrame * CFrame.new(Vector3.new(0, -61, 0))
							local DetectedEntities = HitDetection:SphereMagnitude(Character, AccurateCFrame, MenosAttackTable.Properties)
							if DetectedEntities then
								local DamagedEntities = CombatManager:ApplyDamage(Character, DetectedEntities, MenosAttackTable)
								if DamagedEntities and Combo >= HollowComboData[HollowForms[ShinigamiRank]] then
									for _, v in pairs(DamagedEntities) do
										KnockbackModule:Knockback(Character, v, 40)
									end
								end
								for i, v in pairs(DetectedEntities) do
									if i:GetAttribute("CurrentState") == "Unconscious" then
										EntityManager:ChangeState(i, "TriggerDying")
										EntityManager:ChangeState(i, "TriggerDeath", Character)
										
										if not Character:GetAttribute("CorruptMenos") then
											local ValidPlayer = Players:GetPlayerFromCharacter(i)
											if ValidPlayer then
												if Character:GetAttribute("EntityType") == "Fishbone" or Character:GetAttribute("EntityType") == "Menos" then
													RankManager:AddEXP(Player, 10)
												else
													RankManager:AddEXP(Player, StatData.EatingEXP)
												end
											else
												if i:GetAttribute("Corrupt") > 1 then
													RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Corrupt)
												else
													if i:GetAttribute("EntityType") == "Menos" then
														RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Normal * 3)
													else
														RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Normal)
													end
												end
											end
										end
									elseif i:GetAttribute("CurrentState") == "Food" and not i:GetAttribute("Death") then
										EntityManager:ChangeState(i, "TriggerDeath", Character)
										
										if not Character:GetAttribute("CorruptMenos") then
											if i:GetAttribute("Corrupt") > 1 then
												RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Corrupt)
											else
												if i:GetAttribute("EntityType") == "Menos" then
													RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Normal * 2)
												else
													RankManager:AddEXP(Player, HollowEXP[i:GetAttribute("EntityType")].Normal)
												end
											end
										end
									end
								end
							end
						else
							local DetectedEntities = HitDetection:SphereMagnitude(Character, Character.HumanoidRootPart.CFrame, WeaponTable[HollowForms[ShinigamiRank]].Properties)
							if DetectedEntities then
								local DamagedEntities = CombatManager:ApplyDamage(Character, DetectedEntities, WeaponTable[HollowForms[ShinigamiRank]])
								if DamagedEntities and Combo >= HollowComboData[HollowForms[ShinigamiRank]] + 1 then
									for _, v in pairs(DamagedEntities) do
										KnockbackModule:Knockback(Character, v, 40)
									end
								end
							end

							local HollowSwing = ReplicatedStorage.Assets.HollowSounds.HollowSwing:Clone()
							HollowSwing.PlayOnRemove = true
							HollowSwing.Parent = Character.PrimaryPart
							HollowSwing:Destroy()
							HollowSwing = nil
						end
					elseif KeyframeName == "FeintStart" then
						PlayerData[Character.Name].AllowFeint = true
					elseif KeyframeName == "FeintEnd" then
						PlayerData[Character.Name].AllowFeint = false
					elseif KeyframeName == "AnimationEnd" then
						if Combo >= HollowComboData[HollowForms[ShinigamiRank]] + 1 then
							Character:SetAttribute("Combo", 1)
							Character.Humanoid.WalkSpeed = 0
							if HollowForms[ShinigamiRank] ~= "Menos" then
								task.delay(WeaponTable[HollowForms[ShinigamiRank]].Endlag, function()
									StateMachine:Trigger("ReleaseAttacking", StateMachine, Character)
								end)
							else
								task.delay(0.3, function()
									StateMachine:Trigger("ReleaseAttacking", StateMachine, Character)
								end)
								
								local MenosAttackCD = 5
								if Character:GetAttribute("CorruptMenos") then
									MenosAttackCD = 5
								end
								
								task.delay(MenosAttackCD, function()
									Character:SetAttribute("AttackCD", nil)
								end)
							end
						else
							StateMachine:Trigger("ReleaseAttacking", StateMachine, Character)
						end
					end
				end)
			else
				StateMachine:Trigger("ReleaseAttacking", StateMachine, Character)
			end
		end,
		ReleaseAttacking = function(StateMachine, Character)
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			if Character:GetAttribute("EntityType") ~= "Menos" then
				Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			end
			StateMachine:SetState("Idle")
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", "SearchByReference")
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		AttackDeflected = function(StateMachine, Character, DeflectDamage, DeflectAnimation, ParryStunTime)	
			--SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", "SearchByReference")		
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			
			if HollowForms[ShinigamiRank] ~= "Menos" then
				local DeflectAnimation = Character.Humanoid.Animator:LoadAnimation(CombatAnimations["Deflected" .. DeflectAnimation])
				DeflectAnimation:Play()
				
				local AttackData = {
					ImpactSound = "None",
					StunAnimation = "None",
					TrueStunTime = 0,
					SoftStunTime = DeflectAnimation.Length + ParryStunTime,
				}
				StateMachine:Trigger("TriggerTrueStun", StateMachine, Character, AttackData)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then			
				SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", "SearchByReference")

				StateMachine:PushState("Idle")
				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)
			end
		end,
		TriggerAttackBlocked = function(StateMachine, Character, AttackData)
			--[[local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then	
				StateMachine:SetState("AttackBlocked")
				StateMachine:Trigger("AttackBlocked", StateMachine, Character, BlockDamage)
			end]]
		end,
	},
	CriticalAttacking = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		CriticalAttack = function(StateMachine, Character)
			if not Character:GetAttribute("CriticalCD") then
				Character:SetAttribute("CriticalCD", true)

				Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") - 9
				
				local HollowRoar = ReplicatedStorage.Assets.HollowSounds.HollowRoar:Clone()
				HollowRoar.PlayOnRemove = true
				HollowRoar.Parent = Character.HumanoidRootPart
				HollowRoar:Destroy()
				HollowRoar = nil
				
				local Player = Players:GetPlayerFromCharacter(Character)
				local Profile = DataManager:RequestProfile(Player)
				local ShinigamiRank = Profile.ClientData.ShinigamiRank
				
				local Critical = HollowAnimations[HollowForms[ShinigamiRank]].Critical
				local CriticalAnimation = Character.Humanoid.Animator:LoadAnimation(Critical)
				
				if HollowForms[ShinigamiRank] == "Adjuchas" or HollowForms[ShinigamiRank] == "Fishbone" then
					Character:SetAttribute("HyperArmor", true)
					task.delay(1.3, function()
						Character:SetAttribute("HyperArmor", false)
					end)
				end
				
				local WeaponTable = {
					Adjuchas = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 14,

						BlockDamage = 120,
						DeflectDamage = 120,
						
						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.3,
						SoftStunTime = 0.3,

						Properties = {
							Range = 12,
							Width = 12,
							Height = 12,
							Length = 0,
						},
					};
					Fishbone = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 9,

						BlockDamage = 120,
						DeflectDamage = 120,
						
						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.3,
						SoftStunTime = 0.3,

						Properties = {
							Range = 11,
							Width = 11,
							Height = 12,
							Length = 0,
						},	
					};
					VastoLorde = {
						Blockable = true,	
						Parryable = true,
						Endlag = 0.4,
						Damage = 1,

						BlockDamage = 10,
						DeflectDamage = 15,

						ImpactSound = ReplicatedStorage.Assets.HollowSounds["HollowPunch" .. math.random(1, 3)],

						TrueStunTime = 0.5,
						SoftStunTime = 0.5,

						Properties = {
							Range = 35,
							Width = 6,
							Height = 7,
							Length = 0,
						},
					};
				}
				
				
				CriticalAnimation:Play()
				CriticalAnimation.KeyframeReached:Connect(function(KeyframeName)
					if KeyframeName == "HitFrame" then
						if HollowForms[ShinigamiRank] ~= "VastoLorde" then
							local Detection = HitDetection:SphereMagnitude(Character, Character.HumanoidRootPart.CFrame, WeaponTable[HollowForms[ShinigamiRank]].Properties)
							if Detection then
								local DetectedEntities = CombatManager:ApplyDamage(Character, Detection, WeaponTable[HollowForms[ShinigamiRank]])
								for i, v in ipairs(DetectedEntities) do
									KnockbackModule:Knockback(Character, v, 35)
									Ragdoll:Enable(v)
									task.delay(0.6, function()
										Ragdoll:Disable(v, "UnconsciousCheck")
									end)
								end
							end
							
							local HollowCritical = ReplicatedStorage.Assets.HollowSounds.HollowCritical:Clone()
							HollowCritical.PlayOnRemove = true
							HollowCritical.Parent = Character.PrimaryPart
							HollowCritical:Destroy()
							HollowCritical = nil
						else
							local VastoRoar = ReplicatedStorage.Assets.HollowSounds.HollowScream:Clone()
							VastoRoar.Parent = Character.HumanoidRootPart
							VastoRoar.PlayOnRemove = false
							VastoRoar:Play()
							game:GetService("Debris"):AddItem(VastoRoar, VastoRoar.TimeLength)

							local RoarEffect = ReplicatedStorage.Assets.Effects.Hollow.Roar:Clone()
							RoarEffect.Parent = Character.PrimaryPart
							game:GetService("Debris"):AddItem(RoarEffect, 3)

							local Weld = Instance.new("Weld")
							Weld.Part0 = RoarEffect
							Weld.Part1 = Character.PrimaryPart
							Weld.Parent = RoarEffect

							for i, v in ipairs(RoarEffect:GetDescendants()) do
								if v:IsA("ParticleEmitter") then
									v.Enabled = true
									task.delay(1, function()
										v.Enabled = false
									end)
								end
							end

							local MagnitudeCenter = Character.HumanoidRootPart.CFrame.Position
							local HitDetection = HitDetection:Magnitude(Character, MagnitudeCenter, WeaponTable.VastoLorde.Properties.Range)
							if HitDetection then
								for Target, HitType in pairs(HitDetection) do
									if HitType == "FrontalHit" or HitType == "BackHit" then
										if Target:GetAttribute("HyperArmor") == false then
											EntityManager:ChangeState(Target, "TriggerPostureBreak")
										end
									end
								end
							end
						end
					elseif KeyframeName == "AnimationEnd" then
						Character:SetAttribute("HyperArmor", false)
						StateMachine:Trigger("ReleaseHAttack", StateMachine, Character)
					end
				end)
				
				local CDTime = 4
				if HollowForms[ShinigamiRank] == "VastoLorde" then
					CDTime = 16
				end
				
				task.delay(CDTime, function()
					Character:SetAttribute("CriticalCD", nil)
				end)
			else
				StateMachine:Trigger("ReleaseHAttack", StateMachine, Character)
			end
		end,
		ReleaseHAttack = function(StateMachine, Character)
			Character:SetAttribute("HyperArmor", false)
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			Character.Humanoid.AutoRotate = true
			StateMachine:SetState("Idle")
		end,
		AttackDeflected = function(StateMachine, Character, DeflectDamage, DeflectAnimation, ParryStunTime)	
			SharedFunctions:CancelAnimation(Character.Humanoid, "Critical", "SearchByReference")
			Character:SetAttribute("HyperArmor", false)
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			local DeflectAnimation = Character.Humanoid.Animator:LoadAnimation(CombatAnimations["Deflected" .. DeflectAnimation])
			DeflectAnimation:Play()

			local AttackData = {
				ImpactSound = "None",
				StunAnimation = "None",
				TrueStunTime = 0,
				SoftStunTime = DeflectAnimation.Length + ParryStunTime,
			}
			StateMachine:Trigger("TriggerTrueStun", StateMachine, Character, AttackData)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			SharedFunctions:CancelAnimation(Character.Humanoid, "Critical", "SearchByReference")
			StateMachine:SetState("TrueStunned")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			SharedFunctions:CancelAnimation(Character.Humanoid, "Critical", "SearchByReference")
			
			if Character.Head:FindFirstChildWhichIsA("BodyVelocity") then
				Character.Head:FindFirstChildWhichIsA("BodyVelocity"):Destroy()
			end
			
			StateMachine:PushState("Idle")
			StateMachine:SetState("PostureBroken")
			StateMachine:Trigger("PostureBreak", StateMachine, Character)	
		end,
	},
	Skill = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		SkillPress = function(StateMachine, Character, KeyPressed, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local InventorySkill = DataManager:RequestSkillInventory(Player)[KeyPressed]

			if InventorySkill ~= "Empty" then
				local Skill = SkillModule[InventorySkill]

				local ReiatsuValue = Character:GetAttribute("Reiatsu")
				ReiatsuValue -= Skill.ReiatsuCost

				if Skill and Character:GetAttribute(KeyPressed) == false and ReiatsuValue >= 0 then
					Character:SetAttribute("Reiatsu", ReiatsuValue)
					Character:SetAttribute("HitCheck", true)
					Skill.SkillFunction(Character, StateMachine, KeyPressed, PlayerData[Character.Name]) 
				else
					StateMachine:Trigger("ReleaseSkill", StateMachine, Character)
				end
			else
				StateMachine:Trigger("ReleaseSkill", StateMachine, Character)
			end
		end,
		TriggerAttackBlocked = function(StateMachine, Character, AttackData)
			--[[local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:SetState("AttackBlocked")
				StateMachine:Trigger("AttackBlocked", StateMachine, Character, BlockDamage)
			end]]
		end,
		ReleaseSkill = function(StateMachine, Character)
			StateMachine:SetState("Idle")
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then	
				Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			end
			Character.Humanoid.AutoRotate = true
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				SharedFunctions:CancelAnimation(Character.Humanoid, "Skill", true)
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				SharedFunctions:CancelAnimation(Character.Humanoid, "Skill", "SearchByReference")

				StateMachine:PushState("Idle")
				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)
			end
		end,
		AttackDeflected = function(StateMachine, Character, DeflectDamage, DeflectAnimation, ParryStunTime)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			if HollowForms[ShinigamiRank] ~= "Menos" then
				local DeflectAnimation = Character.Humanoid.Animator:LoadAnimation(CombatAnimations["Deflected" .. DeflectAnimation])
				DeflectAnimation:Play()
				
				local AttackData = {
					ImpactSound = "None",
					StunAnimation = "None",
					TrueStunTime = 0,
					SoftStunTime = DeflectAnimation.Length + ParryStunTime,
				}
				StateMachine:Trigger("TriggerTrueStun", StateMachine, Character, AttackData)
			end
		end,
	},
	Parrying = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			Character:SetAttribute("DeflectFrames", false)
			Character:SetAttribute("BlockFrames", false)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		Parry = function(StateMachine, Character)
			PlayerData[Character.Name].BlockHeld = true
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("BlockTimer")
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if TimeDifference >= Character:GetAttribute("ParryCooldown") and HollowForms[ShinigamiRank] ~= "Menos" then
				Character:SetAttribute("ParryCooldown", 1700)
				Character:SetAttribute("BlockTimer", DateTime.now().UnixTimestampMillis) 
				local Player = Players:GetPlayerFromCharacter(Character)
				local Profile = DataManager:RequestProfile(Player)
				local ShinigamiRank = Profile.ClientData.ShinigamiRank

				local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
				local ParryAnimation = Character.Humanoid.Animator:LoadAnimation(CombatAnimations.Parry)
				Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") - 5
				ParryAnimation:Play()
				ParryAnimation.KeyframeReached:Connect(function(KeyframeName)
					if KeyframeName == "DeflectStart" then
						Character:SetAttribute("DeflectFrames", true)
					elseif KeyframeName == "DeflectEnd" then
						Character:SetAttribute("DeflectFrames", false)
						if PlayerData[Character.Name].BlockHeld == true then
							StateMachine:Trigger("TriggerBlock", StateMachine, Character)
						else
							Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
							StateMachine:SetState("Idle")
						end
					end
				end)
			else
				if PlayerData[Character.Name].BlockHeld == true then
					StateMachine:Trigger("TriggerBlock", StateMachine, Character)
				end
			end	
		end,
		TriggerBlock = function(StateMachine, Character)
			Character:SetAttribute("DeflectFrames", false)
			StateMachine:SetState("Blocking")
			StateMachine:Trigger("TrueBlock", StateMachine, Character)
		end,	
		ReleaseBlock = function(StateMachine, Character)
			Character:SetAttribute("DeflectFrames", false)
			Character:SetAttribute("BlockFrames", false)
			
			PlayerData[Character.Name].BlockHeld = nil
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			Character:SetAttribute("DeflectFrames", false)
			Character:SetAttribute("BlockFrames", false)
			
			PlayerData[Character.Name].BlockHeld = nil
			StateMachine:PushState("Idle")
			StateMachine:SetState("TrueStunned")
			SharedFunctions:CancelAnimation(Character.Humanoid, "Parry", "SearchByReference")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			PlayerData[Character.Name].BlockHeld = nil
			SharedFunctions:CancelAnimation(Character.Humanoid, "Parry", "SearchByReference")
			Character:SetAttribute("DeflectFrames", false)
			Character:SetAttribute("BlockFrames", false)
			
			StateMachine:PushState("Idle")
			StateMachine:SetState("PostureBroken")
			StateMachine:Trigger("PostureBreak", StateMachine, Character)	
		end,
		AttackDeflected = function(StateMachine, Character, DeflectDamage, DeflectAnimation, ParryStunTime)
			Character:SetAttribute("ParryCooldown", 200)
			Character:SetAttribute("DeflectFrames", true)
			SharedFunctions:CancelAnimation(Character.Humanoid, "Parry", "SearchByReference")
			PlayerData[Character.Name].BlockHeld = nil
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			local DeflectAnimation = Character.Humanoid.Animator:LoadAnimation(CombatAnimations["Parrying" .. DeflectAnimation])
			DeflectAnimation:Play()

			local PathData = {Module = HitEffectClient, Skill = "ApplyHitEffect"}
			local RenderDistance = 1000
			NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathData, "Deflected")

			local Stance = Character:GetAttribute("Posture")
			Stance -= DeflectDamage
			if Stance <= 0 then
				Character:SetAttribute("Posture", 0)
			else
				Character:SetAttribute("Posture", Stance)	
			end
			task.delay(0.1, function()
				Character:SetAttribute("DeflectFrames", false)
			end)
			task.delay(DeflectAnimation.Length + ParryStunTime, function()
				StateMachine:Trigger("TriggerWeaponDrawn", StateMachine, Character)
			end)
		end,
		TriggerWeaponDrawn = function(StateMachine, Character)
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			Character.Humanoid.AutoRotate = true
			StateMachine:SetState("Idle")
		end,
	},
	Blocking = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			Character:SetAttribute("BlockFrames", false)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		TrueBlock = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			
			Character:SetAttribute("BlockFrames", true)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			local BlockAnimation = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]].Block)
			BlockAnimation:Play()

			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") - 5
		end,
		ReleaseBlock = function(StateMachine, Character)
			Character:SetAttribute("BlockFrames", false)
			SharedFunctions:CancelAnimation(Character.Humanoid, "Block", "SearchByReference")
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			StateMachine:SetState("Idle")	
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			Character:SetAttribute("BlockFrames", false)
			StateMachine:PushState("Idle")
			StateMachine:SetState("TrueStunned")
			SharedFunctions:CancelAnimation(Character.Humanoid, "Block", "SearchByReference")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			PlayerData[Character.Name].BlockHeld = nil
			SharedFunctions:CancelAnimation(Character.Humanoid, "Block", "SearchByReference")
			Character:SetAttribute("BlockFrames", false)
			Character:SetAttribute("DeflectFrames", false)
			
			StateMachine:PushState("Idle")
			StateMachine:SetState("PostureBroken")
			StateMachine:Trigger("PostureBreak", StateMachine, Character)	
		end,
		SoftBlock = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			Character:SetAttribute("BlockFrames", true)
			local BlockAnimation = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]].Block)
			BlockAnimation:Play()

			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") - 5
		end,
		BlockedAttack = function(StateMachine, Character, AttackData, AttackOwner)
			local HitBlockAnim = Character.Humanoid.Animator:LoadAnimation(Animations.HitBlock)
			HitBlockAnim:Play()

			local PathData = {Module = HitEffectClient, Skill = "ApplyHitEffect"}
			local RenderDistance = 1000
			NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathData, "Blocked")

			local Posture = Character:GetAttribute("Posture")
			Posture += AttackData.BlockDamage
			if Posture >= Character:GetAttribute("MaxPosture") then
				StateMachine:SetState("PostureBroken")
				StateMachine:PushState("Idle")
				Character:SetAttribute("BlockFrames", false)
				Character:SetAttribute("DeflectFrames", false)
				SharedFunctions:CancelAnimation(Character.Humanoid, "Block", "SearchByReference")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)	
				
				local PostureBrokenDamage = AttackData.Damage / 3

				CombatManager:ApplyDamage(AttackOwner, {[Character] = "FrontalHit"}, {Damage = PostureBrokenDamage})
			else
				if Posture <= 0 then
					Character:SetAttribute("Posture", 0)
				else
					Character:SetAttribute("Posture", Posture)	
				end
			end
		end,
	},
	TrueStunned = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		TrueStun = function(StateMachine, Character, AttackData, AttackOwner)
			if not PlayerData[Character.Name].StunnedDuration then
				PlayerData[Character.Name].StunnedTime = DateTime.now().UnixTimestampMillis
				PlayerData[Character.Name].StunnedDuration = AttackData.TrueStunTime
			elseif AttackData.TrueStunTime >= PlayerData[Character.Name].StunnedDuration then
				PlayerData[Character.Name].StunnedTime = DateTime.now().UnixTimestampMillis
				PlayerData[Character.Name].StunnedDuration = AttackData.TrueStunTime
			end

			Character:SetAttribute("Combo", 1)
			Character.Humanoid.JumpHeight = 0
			Character.Humanoid.WalkSpeed = 0
			
			if Character.Head:FindFirstChildWhichIsA("BodyVelocity") then
				Character.Head:FindFirstChildWhichIsA("BodyVelocity"):Destroy()
			end
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local HitReaction = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]]["Hitstun" .. math.random(1, 2)])
			HitReaction:Play()
			
			if PlayerData[Character.Name].AttackerRemoving then
				PlayerData[Character.Name].AttackerRemoving:Disconnect()
				PlayerData[Character.Name].AttackerRemoving = nil
			end
			
			local Player = Players:GetPlayerFromCharacter(AttackOwner)
			if Player then
				PlayerData[Character.Name].AttackerRemoving = Player.CharacterRemoving:Connect(function()
					if PlayerData[Character.Name] then
						if PlayerData[Character.Name].AttackerRemoving then
							PlayerData[Character.Name].AttackerRemoving:Disconnect()
							PlayerData[Character.Name].AttackerRemoving = nil
						end
						if PlayerData[Character.Name].StunnedDuration then
							PlayerData[Character.Name].StunnedDuration = 0
						end
					end

					Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
					Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
					Character.Humanoid.AutoRotate = true
					StateMachine:PopState()
				end)
			end
			
			task.delay(AttackData.TrueStunTime, function()
				if PlayerData[Character.Name] and DateTime.now().UnixTimestampMillis - PlayerData[Character.Name].StunnedTime >= (PlayerData[Character.Name].StunnedDuration * 995) then -- Multiplying the truestuntime by 1000 gives us the time in milliseconds
					PlayerData[Character.Name].StunnedDuration = 0
					StateMachine:Trigger("TriggerSoftStun", StateMachine, Character, AttackData.SoftStunTime)
				end

				if PlayerData[Character.Name].AttackerRemoving then
					PlayerData[Character.Name].AttackerRemoving:Disconnect()
					PlayerData[Character.Name].AttackerRemoving = nil
				end
			end)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		TriggerSoftStun = function(StateMachine, Character, SoftStunTime)
			PlayerData[Character.Name].StunnedDuration = 0
			Character.Humanoid.WalkSpeed = 4
			StateMachine:SetState("SoftStunned")	
			StateMachine:Trigger("SoftStun", StateMachine, Character, SoftStunTime)
		end,
	},
	SoftStunned = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		SoftStun = function(StateMachine, Character, SoftStunTime)
			if SoftStunTime <= 0 then
				StateMachine:Trigger("ReleaseSoftStun", StateMachine, Character)
			else
				task.delay(SoftStunTime, function()
					StateMachine:Trigger("ReleaseSoftStun", StateMachine, Character)
				end)
			end
		end,
		ReleaseSoftStun = function(StateMachine, Character)
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			StateMachine:SetState("Idle")
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			StateMachine:SetState("TrueStunned")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
	},
	AttackBlocked = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		AttackBlocked = function(StateMachine, Character, BlockDamage)
			PlayerData[Character.Name].AttackBlockedTimer = DateTime.now().UnixTimestampMillis
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local Endlag = 0.15

			local Combo = Character:GetAttribute("Combo")
			if Combo >= HollowComboData[HollowForms[ShinigamiRank]] + 1 then
				Character:SetAttribute("Combo", 1)
				Endlag = 0.4
			end

			task.delay(Endlag, function()
				if DateTime.now().UnixTimestampMillis - PlayerData[Character.Name].AttackBlockedTimer >= Endlag * 998 then
					StateMachine:Trigger("ReleaseAttackBlocked", StateMachine, Character)
				end
			end)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", true)
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if HollowForms[ShinigamiRank] ~= "Menos" then
				SharedFunctions:CancelAnimation(Character.Humanoid, "Attack", "SearchByReference")

				if Character.Head:FindFirstChild("DashForce") then
					Character.Head.DashForce:Destroy()
				end

				StateMachine:PushState("Idle")
				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)
			end
		end,
		ReleaseAttackBlocked = function(StateMachine, Character)
			StateMachine:SetState("Idle")
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			Character.Humanoid.AutoRotate = true
		end,
	},
	PostureBroken = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		PostureBreak = function(StateMachine, Character)
			PlayerData[Character.Name].PostureBreakDuration = DateTime.now().UnixTimestampMillis
			
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			if HollowForms[Profile.ClientData.ShinigamiRank] == "VastoLorde" then
				Character.Humanoid.Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.PostureBroken):Play()
			end
			
			local PathData = {Module = HitEffectClient, Skill = "ApplyHitEffect"}
			local RenderDistance = 1000
			NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathData, "PostureBreak")

			Character:SetAttribute("Posture", 0)
			Character:SetAttribute("Combo", 1)
			Character.Humanoid.JumpHeight = 0
			Character.Humanoid.WalkSpeed = 0

			task.delay(StatData.PostureBreakTime, function()
				if DateTime.now().UnixTimestampMillis - PlayerData[Character.Name].PostureBreakDuration >= StatData.PostureBreakTime * 995 then
					Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
					Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")

					SharedFunctions:CancelAnimation(Character.Humanoid, "PostureBroken")
					StateMachine:Trigger("ReleasePostureBreak", StateMachine, Character)
				end
			end)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			SharedFunctions:CancelAnimation(Character.Humanoid, "PostureBroken")
			StateMachine:SetState("TrueStunned")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		ReleasePostureBreak = function(StateMachine, Character)
			StateMachine:PopState()
		end,
	},
	Action = {
		TakeDamage = function(StateMachine, Character, ...)
			if PlayerData[Character.Name].ResetConnection then
				PlayerData[Character.Name].ResetConnection:Disconnect()
				PlayerData[Character.Name].ResetConnection = nil

				local ResetTimer = workspace.Effects[Character.Name]:FindFirstChild("ResetTimer")
				if ResetTimer then
					ResetTimer:Destroy()
				end
			end
			
			StateMachine:Trigger("ReleaseAction", StateMachine, Character)
			DamageTaken(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			if PlayerData[Character.Name].ResetConnection then
				PlayerData[Character.Name].ResetConnection:Disconnect()
				PlayerData[Character.Name].ResetConnection = nil

				local ResetTimer = workspace.Effects[Character.Name]:FindFirstChild("ResetTimer")
				if ResetTimer then
					ResetTimer:Destroy()
				end
			end
			
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			if PlayerData[Character.Name].ResetConnection then
				PlayerData[Character.Name].ResetConnection:Disconnect()
				PlayerData[Character.Name].ResetConnection = nil

				local ResetTimer = workspace.Effects[Character.Name]:FindFirstChild("ResetTimer")
				if ResetTimer then
					ResetTimer:Destroy()
				end
			end
			
			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:PushState("Idle")
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		HollowTransform = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			
			if Profile.ClientData.ShinigamiRank <= 17 then -- RANKBASED
				EntityManager:CleanupEntity(Character.Name)
				for i, v in pairs(PlayerData[Player.Name]) do
					if typeof(v) == "RBXScriptConnection" then -- disconnects any existing connections to prevent memory leaks
						PlayerData[Player.Name][i]:Disconnect()
						PlayerData[Player.Name][i] = nil
					else
						PlayerData[Player.Name][i] = nil
					end
				end
				PlayerData[Player.Name] = nil
				RankManager:MaskRip(Player) -- play cool visual for mask rip

				Player.Character:Destroy()
				Player.Character = nil

				local StateModule = Profile.ClientData.StateModule
				local Race = Profile.ClientData.Race

				AntiCheatManager:ClearLastPosition(Player)
				DataManager.createRaceData(Player, Race) -- Create their data based on their original race
				EntityManager:CreateEntity(Player.Name, StateModule, Player)
			else
				StateMachine:Trigger("ReleaseAction", StateMachine, Character)
			end
		end,
		Reset = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			Character.Humanoid.WalkSpeed = 0
			Character.Humanoid.JumpHeight = 0
			
			local TimeDifference = DateTime.now().UnixTimestamp - Profile.ClientData.ResetTimer
			local Minutes = TimeDifference / 60

			if Minutes >= StatData.ResetCD then
				local ResetLabelInfo = {
					Fishbone = {
						WorldOffset = Vector3.new(0, 7, 0);	
					};
					Menos = {
						WorldOffset = Vector3.new(0, 3.9, 0);
						Size = UDim2.new(15, 0, 4, 0);
						MaxDistance = 200;
					};
					Adjuchas = {
						WorldOffset = Vector3.new(0, 12, -4)
					}
				}
				
				local ResetTimer = ServerStorage.Assets.Misc.ResetLabel:Clone()
				ResetTimer.Enabled = true
				ResetTimer.Name = "ResetTimer"
				ResetTimer.Division:Destroy()
				ResetTimer.PlayerName.Text = 30
				ResetTimer.AlwaysOnTop = true
				ResetTimer.MaxDistance = 150
				ResetTimer.Adornee = Character.HumanoidRootPart
				ResetTimer.PlayerToHideFrom = nil
				ResetTimer.ExtentsOffsetWorldSpace = ResetLabelInfo[HollowForms[ShinigamiRank]].WorldOffset
				if ResetLabelInfo[HollowForms[ShinigamiRank]].Size then
					ResetTimer.Size = ResetLabelInfo[HollowForms[ShinigamiRank]].Size
				end
				if ResetLabelInfo[HollowForms[ShinigamiRank]].MaxDistance then
					ResetTimer.MaxDistance = ResetLabelInfo[HollowForms[ShinigamiRank]].MaxDistance
				end
				ResetTimer.ExtentsOffsetWorldSpace += Vector3.new(0, 1, 0)
				ResetTimer.Parent = workspace.Effects[Character.Name]
				game:GetService("Debris"):AddItem(ResetTimer, 31)

				local Timer = 30
				local Rate = 1
				local Accumulated = 0
				PlayerData[Character.Name].ResetConnection = RunService.Heartbeat:Connect(function(DeltaTime)
					Accumulated += DeltaTime
					if Accumulated > Rate then
						Accumulated -= Rate
						Timer -= Rate

						if ResetTimer and ResetTimer.Parent then
							ResetTimer.PlayerName.Text = Timer
						end

						if Timer <= 0 then
							Profile.ClientData.ResetTimer = DateTime.now().UnixTimestamp

							PlayerData[Character.Name].ResetConnection:Disconnect()
							PlayerData[Character.Name].ResetConnection = nil

							Character:SetAttribute("DeathBypass", true)
							StateMachine:SetState("Dying")
							StateMachine:Trigger("TriggerDeath", StateMachine, Character)
						end
					end
				end)
			else
				local ResetTimer = Player.PlayerGui.ScreenEffects.ResetTimer:Clone()
				ResetTimer.TextLabel.Text = StatData.ResetCD - math.floor(Minutes) .. " minutes left until reset is available."
				ResetTimer.TextLabel.TextTransparency = 1
				ResetTimer.TextLabel.TextStrokeTransparency = 1
				ResetTimer.Visible = true
				ResetTimer.Parent = Player.PlayerGui.ScreenEffects
				game:GetService("Debris"):AddItem(ResetTimer, 2.5)

				TweenService:Create(ResetTimer.TextLabel, TweenInfo.new(0.5), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
				task.delay(2, function()
					TweenService:Create(ResetTimer.TextLabel, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
				end)
				
				StateMachine:Trigger("ReleaseAction", StateMachine, Character)
			end
		end,
		ReleaseAction = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			if HollowForms[Profile.ClientData.ShinigamiRank] ~= "Menos" then
				Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			end			
			
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") 
			Character.Humanoid.AutoRotate = true
			StateMachine:SetState("Idle")
		end,
	},
	Sprinting = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		Sprint = function(StateMachine, Character)
			local SprintSpeed = 10
			if Character:GetAttribute("EntityType") == "Adjuchas" then
				SprintSpeed = 15
			end
			
			if Character.Humanoid.Health <= (Character.Humanoid.MaxHealth * 0.3) then
				SprintSpeed = math.floor(SprintSpeed / 1.5)
			end
			
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") + SprintSpeed
			PlayerData[Character.Name].SprintHeld = true

			local Profile = DataManager:RequestProfile(Players:GetPlayerFromCharacter(Character))
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]]["Sprint"]):Play()
		end,
		StopSprint = function(StateMachine, Character)
			PlayerData[Character.Name].SprintHeld = nil
			SharedFunctions:CancelAnimation(Character.Humanoid, "Sprint", "SearchByReference")
			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
			StateMachine:PopState()
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:Trigger("StopSprint", StateMachine, Character)
				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:Trigger("StopSprint", StateMachine, Character)

				StateMachine:PushState("Idle")
				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)	
			end
		end,
		TriggerHollowTransform = function(StateMachine, Character)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:SetState("Action")
			StateMachine:Trigger("HollowTransform", StateMachine, Character)
		end,
		TriggerParry = function(StateMachine, Character)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:SetState("Parrying")
			StateMachine:Trigger("Parry", StateMachine, Character)
		end,
		TriggerExecute = function(StateMachine, Character)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:SetState("Executing")
			StateMachine:Trigger("Execute", StateMachine, Character)
		end,
		TriggerLAttack = function(StateMachine, Character)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:SetState("Attacking")
			StateMachine:Trigger("LightAttack", StateMachine, Character)
		end,
		TriggerCAttack = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:Trigger("StopSprint", StateMachine, Character)
				StateMachine:SetState("CriticalAttacking")
				StateMachine:Trigger("CriticalAttack", StateMachine, Character)
			end
		end,
		TriggerSkill = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:SetState("Skill")
			StateMachine:Trigger("SkillPress", StateMachine, Character, ...)
		end,
		TriggerDash = function(StateMachine, Character, KeyPressed)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("DashTimer")
			
			if HollowForms[ShinigamiRank] == "VastoLorde" and TimeDifference >= 1750 then
				StateMachine:PushState("Idle")
				StateMachine:SetState("Dashing")
				StateMachine:Trigger("Dash", StateMachine, Character, KeyPressed)
			end
		end,
		TriggerFlashstep = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] == "VastoLorde" and HollowForms[ShinigamiRank] == "Menos" then
				local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("FlashstepTimer")
				
				local Cooldown = Character:GetAttribute("FlashstepCooldown")
				local MaxHealth = Character.Humanoid.MaxHealth
				local Health = Character.Humanoid.Health

				if Health <= MaxHealth * 0.8 then
					local HealthRange = (MaxHealth * 0.8) - 1
					local FlashstepCDRange = Cooldown - StatData.FlashstepCooldownScale * Cooldown
					local ScaledFlashstepCD = (((Health - 1) * FlashstepCDRange) / HealthRange) + StatData.FlashstepCooldownScale * Cooldown
					Cooldown = ScaledFlashstepCD
				end
				
				local ReiatsuValue = Character:GetAttribute("Reiatsu")
				ReiatsuValue -= 5
				if TimeDifference >=Cooldown and ReiatsuValue >= 0 then
					StateMachine:PushState("Idle")
					StateMachine:SetState("Flashstep")
					StateMachine:Trigger("Flashstep", StateMachine, Character)
				end
			end
		end,
	},
	Dying = {
		TriggerDeath = function(StateMachine, Character, Executor)
			Character:SetAttribute("Death", true)
			StateMachine:CleanStack()
			if Character:FindFirstChild("Humanoid") then
				Character.Humanoid.WalkSpeed = 0
				Character.Humanoid.JumpHeight = 0
			end
			
			local MaskCracked
			
			local ExecutorPlayer = Players:GetPlayerFromCharacter(Executor)
			local Player = Players:GetPlayerFromCharacter(Character)	
			if ExecutorPlayer and Player then
				local ExecutorProfile = DataManager:RequestProfile(ExecutorPlayer)
				local Profile = DataManager:RequestProfile(Player)
				local Race = Profile.ClientData.Race				
				
				RankManager:AddQuincyProgress(Player, 2)
				
				
				if StatData.Factions[ExecutorProfile.ClientData.Race] == "Arrancar" then
					local MaxHealth = ExecutorProfile.ClientData.MaxHealth
					local ShinigamiRank = ExecutorProfile.ClientData.ShinigamiRank
					local PlayerStats = RankManager:RetrievePlayerStats(ShinigamiRank)
					if MaxHealth < PlayerStats.Health then
						MaxHealth += StatData.HealthRestoreAmount
						if MaxHealth < PlayerStats.Health then
							ExecutorProfile.ClientData.MaxHealth = MaxHealth
							
							local HealthAmount = ExecutorProfile.ClientData.MaxHealth
							HealthAmount = PlayerBonus:ApplyHealth(ExecutorPlayer, HealthAmount)
							
							Executor.Humanoid.MaxHealth = HealthAmount
						else
							ExecutorProfile.ClientData.MaxHealth = PlayerStats.Health
							
							local HealthAmount = PlayerStats.Health
							HealthAmount = PlayerBonus:ApplyHealth(ExecutorPlayer, HealthAmount)
							
							Executor.Humanoid.MaxHealth = HealthAmount
						end
					end
				end
				
				--[[local Elo = Profile.ClientData.Elo
				local ExeuctorElo = ExecutorProfile.ClientData.Elo
				local MinimumRankReq = 12 -- 5

				if Elo < 0 then
					Elo = 0
				end	
				
				if ExecutorProfile.ClientData.ShinigamiRank <= MinimumRankReq and Profile.ClientData.ShinigamiRank <= MinimumRankReq then
					if ExecutorProfile.ClientData.GlobalRank > 0 then
						if Profile.ClientData.GlobalRank > 0 then
							if Profile.ClientData.GlobalRank >= ExecutorProfile.ClientData.GlobalRank then
								local SetElo = (Elo * 0.1) + 2
								ExeuctorElo += SetElo
								ExecutorProfile.ClientData.Elo = ExeuctorElo

								if Elo - SetElo < 0 then
									Profile.ClientData.Elo = -1
								else
									Elo -= SetElo
									Profile.ClientData.Elo = Elo
								end
							elseif Profile.ClientData.GlobalRank < ExecutorProfile.ClientData.GlobalRank then
								local SetElo = (Elo * 0.05) + 1
								ExeuctorElo += SetElo
								ExecutorProfile.ClientData.Elo = ExeuctorElo

								if Elo - SetElo < 0 then
									Profile.ClientData.Elo = -1
								else
									Elo -= SetElo
									Profile.ClientData.Elo = Elo
								end
							end
						end
					else
						local SetElo = (Elo * 0.05) + 1
						ExeuctorElo += SetElo
						ExecutorProfile.ClientData.Elo = ExeuctorElo

						if Elo - SetElo < 0 then
							Profile.ClientData.Elo = -1
						else
							Elo -= SetElo
							Profile.ClientData.Elo = Elo
						end
					end
				end]]
				
				-- RANKBASED
				
				if Profile.ClientData.Race == "Hollow" then
					if HollowForms[Profile.ClientData.ShinigamiRank] == "Fishbone" then
						RankManager:AddSchriftProgress(ExecutorPlayer, "Fishbone")
					elseif HollowForms[Profile.ClientData.ShinigamiRank] == "Menos" then
						RankManager:AddSchriftProgress(ExecutorPlayer, "Menos")
					elseif HollowForms[Profile.ClientData.ShinigamiRank] == "Adjuchas" then
						RankManager:AddSchriftProgress(ExecutorPlayer, "Adjuchas")
					end
				end
				
				local ClientProgression = ReplicatedStorage.Modules.ClientModules.ClientProgression
				local PathData = {Module = ClientProgression, Skill = "DeathScreen"}
				NetworkManager.FireClient(Player, Character, "ClientEffects", -1, PathData, ExecutorPlayer)
				
				if not StatData.LockVasto and not Character:GetAttribute("MaskCracked") then
					Character:SetAttribute("MaskCracked", true)
					local ExecutorRank = ExecutorProfile.ClientData.ShinigamiRank
					local ExecutorRace = ExecutorProfile.ClientData.Race
					if Profile.ClientData.ShinigamiRank == 16 and Profile.ClientData.Race == "Hollow" and ExecutorRank == 16 and ExecutorRace == "Hollow" then
						local MaskCrackCD = 60 -- minutes
						-- (DateTime.now().UnixTimestamp - Profile.ClientData.VastoLordeReqs.MaskCrackTimer) / 60
						if Profile.ClientData.VastoLordeReqs.MaskCracks > 0 then
							Profile.ClientData.VastoLordeReqs.MaskCrackTimer = DateTime.now().UnixTimestamp
							Profile.ClientData.VastoLordeReqs.MaskCracked = true
							
							ExecutorProfile.ClientData.VastoLordeReqs.MaskCracks += 1
							ReplicatedStorage.Remotes.MaskCrackUpdate:FireClient(ExecutorPlayer, ExecutorProfile.ClientData.VastoLordeReqs.MaskCracks)
							
							local Message = Executor.Name .. " cracked " .. Character.Name .. "'s mask\nTotal Mask Cracks: " .. ExecutorProfile.ClientData.VastoLordeReqs.MaskCracks
							
							if Profile.ClientData.VastoLordeReqs.MaskCracks >= StatData.MaskCrackReq and not ExecutorProfile.ClientData.VastoLordeReqs.RivalCrack and not ExecutorProfile.ClientData.VastoFailed and ExecutorProfile.ClientData.VastoLordeReqs.MaskCracks >= StatData.MaskCrackReq then
								ExecutorProfile.ClientData.VastoLordeReqs.RivalCrack = true
								Profile.ClientData.VastoLordeReqs.MaskCracks = 0
								Profile.ClientData.VastoFailed = true
								Message = Executor.Name .. " has gained Vasto potential from " .. Character.Name .. ". " ..  Character.Name .. "'s progress has been reset."
							end
							
							Character.Mask["Meshes/aaaaaa_Color"]:FindFirstChildWhichIsA("Weld"):Destroy()
							MaskCracked = true
							
							task.delay(1.5, function()
								Character.Mask["Meshes/aaaaaa_Skull"].Main:Emit(15)

								local MaskCrackSound = ReplicatedStorage.Assets.HollowSounds.MaskCrack:Clone()
								MaskCrackSound.Parent = Character.Mask["Meshes/aaaaaa_Skull"]
								MaskCrackSound:Play()
								game:GetService("Debris"):AddItem(MaskCrackSound, MaskCrackSound.TimeLength)
							end)
							
							local WebhookInfo = {
								Message = Message;
							}

							Webhooks:Post(WebhookChannel, WebhookInfo)
							
							ReplicatedStorage.Remotes.MaskCrackUpdate:FireClient(Player, Profile.ClientData.VastoLordeReqs.MaskCracks)
						end
					end
				end
			end
			
			for i, v in ipairs(Character:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = true
					if MaskCracked then
						if v.Parent ~= Character.Mask then
							local Particle = ReplicatedStorage.Assets.Effects.Hollow.DeadHollow.flare:Clone()
							Particle.Parent = v

							v.Material = Enum.Material.Neon
							TweenService:Create(v, TweenInfo.new(1), {Color = Color3.fromRGB(65, 65, 65)}):Play()
						else
							task.delay(1.5, function()
								TweenService:Create(v, TweenInfo.new(1), {Transparency = 1}):Play()
							end)
						end
					else
						local Particle = ReplicatedStorage.Assets.Effects.Hollow.DeadHollow.flare:Clone()
						Particle.Parent = v

						v.Material = Enum.Material.Neon
						TweenService:Create(v, TweenInfo.new(1), {Color = Color3.fromRGB(65, 65, 65)}):Play()
					end
				end
			end
			Character.PrimaryPart:Destroy()
			Character:BreakJoints()
			Character.Humanoid.Health = -5
			
			if workspace.Effects[Character.Name]:FindFirstChild(Character.Name .. "Head") then
				workspace.Effects[Character.Name][Character.Name .. "Head"]:Destroy()
			end
		end,	
	},
	Flashstep = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		StopSprint = function(StateMachine, Character)
			PlayerData[Character.Name].SprintHeld = nil
		end,
		TriggerSprint = function(StateMachine, Character)
			PlayerData[Character.Name].SprintHeld = true
		end,
		Flashstep = function(StateMachine, Character)
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("FlashstepTimer")
			local ReiatsuValue = Character:GetAttribute("Reiatsu")
			ReiatsuValue -= 3 -- Subtracts the cost of the skill from the players current reiatsu
			
			local Cooldown = Character:GetAttribute("FlashstepCooldown")
			local MaxHealth = Character.Humanoid.MaxHealth
			local Health = Character.Humanoid.Health

			if Health <= MaxHealth * 0.8 then
				local HealthRange = (MaxHealth * 0.8) - 1
				local FlashstepCDRange = Cooldown - StatData.FlashstepCooldownScale * Cooldown
				local ScaledFlashstepCD = (((Health - 1) * FlashstepCDRange) / HealthRange) + StatData.FlashstepCooldownScale * Cooldown
				Cooldown = ScaledFlashstepCD
			end
			
			if TimeDifference >= Character:GetAttribute("FlashstepCooldown") and ReiatsuValue >= 0 then
				PlayerData[Character.Name].FlashstepDuration = DateTime.now().UnixTimestampMillis
				PlayerData[Character.Name].Flashstepping = true
				Character:SetAttribute("FlashstepTimer", DateTime.now().UnixTimestampMillis)
				Character:SetAttribute("EvasiveFrames", true)
				Character:SetAttribute("Reiatsu", ReiatsuValue)

				local Player = Players:GetPlayerFromCharacter(Character)
				local Profile = DataManager:RequestProfile(Player)
				local ShinigamiRank = Profile.ClientData.ShinigamiRank
				local Race = Profile.ClientData.Race
				
				local FlashstepSpeed = 55
				if Character.Humanoid.Health <= (Character.Humanoid.MaxHealth * 0.3) then
					FlashstepSpeed = math.floor(FlashstepSpeed / 2)
				end
				
				local BonusWalkspeed = FlashstepSpeed
				local MenosStep
				if HollowForms[ShinigamiRank] == "Menos" then
					MenosStep = true
					BonusWalkspeed = 85
				end
				
				AntiCheatManager:AddDistance(Player, BonusWalkspeed, 3)
				
				Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") + BonusWalkspeed
				
				local PathDataStart = {Module = FlashstepClient, Skill = "Flashstep"}
				local PathDataAudio = {Module = FlashstepClient, Skill = "FlashstepAudio"}
				local RenderDistance = -1
				NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataAudio, Race, MenosStep)
				NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataStart, Race, MenosStep)
				
				local Disconnect
				local Duration = 3
				local Rate = 0.75
				local Accumulated = 0
				local Connection
				Connection = RunService.Heartbeat:Connect(function(DeltaTime)
					Accumulated += DeltaTime
					Duration -= DeltaTime
					
					if not PlayerData[Character.Name] or not PlayerData[Character.Name].Flashstepping then
						Disconnect = true
					end
					
					if Disconnect or Duration <= 0 then
						Connection:Disconnect()
						Connection = nil
						StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character)
						Disconnect = true
					end
					
					if Accumulated > Rate then
						Accumulated -= Rate

						if not Disconnect then
							NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataStart, Race, MenosStep)
						end
					end
				end)

				local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
				Character.Humanoid.Animator:LoadAnimation(CombatAnimations.Sprint):Play()

				task.delay(StatData.FlashstepEvasiveFrames, function()
					Character:SetAttribute("EvasiveFrames", false)
				end)
			end
		end,
		TriggerM2 = function(StateMachine, Character, ...)
			StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, ...)
		end,
		ReleaseFlashstep = function(StateMachine, Character, State, ...)
			PlayerData[Character.Name].Flashstepping = nil

			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local Race = Profile.ClientData.Race
			local ShinigamiRank = Profile.ClientData.ShinigamiRank
			
			local MenosStep
			if HollowForms[ShinigamiRank] == "Menos" then
				MenosStep = true
			end
			
			local PathDataAudio = {Module = FlashstepClient, Skill = "FlashstepAudio"}
			local PathDataStop = {Module = FlashstepClient, Skill = "StopFlashstep"}
			local RenderDistance = -1
			NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataStop, Race, MenosStep)
			NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataAudio, Race, MenosStep)

			SharedFunctions:CancelAnimation(Character.Humanoid, "Sprint", "SearchByReference")

			if PlayerData[Character.Name].SprintHeld and HollowForms[ShinigamiRank] ~= "Menos" then
				StateMachine:SetState("Sprinting")
				StateMachine:Trigger("Sprint", StateMachine, Character, ...)
			else
				Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed")
				StateMachine:PopState()
				StateMachine:Trigger(State, StateMachine, Character, ...)
			end
		end,
		-- Actions below auto exit flash step --
		TriggerLAttack = function(StateMachine, Character)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:PushState("Attacking")
			StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, "LightAttack")
		end,
		TriggerCAttack = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] ~= "Menos" then
				if not Character:GetAttribute("CriticalCooldown") then
					StateMachine:Trigger("StopSprint", StateMachine, Character)
					StateMachine:PushState("CriticalAttacking")
					StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, "CriticalAttack")
				end
			end
		end,
		TriggerSkill = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:PushState("Skill")
			StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, "SkillPress", ...)
		end,
		TriggerParry = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			if HollowForms[ShinigamiRank] == "VastoLorde" then
				StateMachine:Trigger("StopSprint", StateMachine, Character)
				StateMachine:PushState("Parrying")
				StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, "Parry")
			end
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:Trigger("StopSprint", StateMachine, Character)
			StateMachine:PushState("Unconscious")
			StateMachine:Trigger("ReleaseFlashstep", StateMachine, Character, "TriggerDying", ...)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			if HollowForms[ShinigamiRank] ~= "Menos" then
				PlayerData[Character.Name].Flashstepping = nil
				local PathDataStop = {Module = FlashstepClient, Skill = "StopFlashstep"}
				local RenderDistance = -1
				NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataStop)
				SharedFunctions:CancelAnimation(Character.Humanoid, "Sprint", "SearchByReference")

				StateMachine:SetState("TrueStunned")
				StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
			end
		end,
		TriggerPostureBreak = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			local ShinigamiRank = Profile.ClientData.ShinigamiRank

			local CombatAnimations = HollowAnimations[HollowForms[ShinigamiRank]]
			if HollowForms[ShinigamiRank] ~= "Menos" then
				PlayerData[Character.Name].Flashstepping = nil

				local PathDataStop = {Module = FlashstepClient, Skill = "StopFlashstep"}
				local RenderDistance = -1
				NetworkManager.FireAllClients(Character, "ClientEffects", RenderDistance, PathDataStop)
				SharedFunctions:CancelAnimation(Character.Humanoid, "Sprint", "SearchByReference")

				StateMachine:SetState("PostureBroken")
				StateMachine:Trigger("PostureBreak", StateMachine, Character)
			end	
		end,
	},
	Dashing = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		Dash = function(StateMachine, Character, KeyPressed)
			local TimeDifference = DateTime.now().UnixTimestampMillis - Character:GetAttribute("DashTimer")
			if TimeDifference >= 1750 then
				Character:SetAttribute("EvasiveFrames", true)
				Character:SetAttribute("DashTimer", DateTime.now().UnixTimestampMillis)
				
				local Player = Players:GetPlayerFromCharacter(Character)
				AntiCheatManager:AddDistance(Player, 45, 0.45)
				
				local BodyVelocity = Instance.new("BodyVelocity")
				BodyVelocity.Name = "DashForce"
				BodyVelocity.MaxForce = Vector3.new(80000, 0, 80000)
				BodyVelocity.Parent = Character.Head

				local DashSound = Sounds.Dash:Clone()
				DashSound.PlayOnRemove = true
				DashSound.Parent = Character.PrimaryPart
				DashSound:Destroy()
				DashSound = nil

				local Player = Players:GetPlayerFromCharacter(Character)
				ReplicatedStorage.Remotes.RotationalDash:FireClient(Player, BodyVelocity, KeyPressed, 45, true)

				task.delay(0.15, function()
					Character:SetAttribute("EvasiveFrames", false)
					StateMachine:Trigger("ReleaseDashing", StateMachine, Character)
				end)
				task.delay(.45, function()
					if BodyVelocity then
						BodyVelocity:Destroy()
						BodyVelocity = nil
					end
					StateMachine:Trigger("ReleaseDashing", StateMachine, Character)
				end)
			else
				StateMachine:Trigger("ReleaseDashing", StateMachine, Character)
			end
		end,
		ReleaseDashing = function(StateMachine, Character)
			--local Stack = EntityManager:RetrieveData(Character).EntityMachine.Stack
			--if Stack[#Stack] == "Sprinting" then 
			if PlayerData[Character.Name].SprintHeld then 
				StateMachine:SetState("Sprinting")
				StateMachine:Trigger("Sprint", StateMachine, Character)
			else
				StateMachine:PopState()
			end
		end,
		--[[TriggerM2 = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			if Character.Head:FindFirstChild("DashForce") then
				Character.Head.DashForce:Destroy()
			end
			ReplicatedStorage.Remotes.CancelClientAnimation:FireClient(Player, "Dash", "SearchByReference")
			StateMachine:Trigger("ReleaseDashing", StateMachine, Character)
		end,]]
	},
	Unconscious = {
		TriggerDying = function(StateMachine, Character, ...)
			if not PlayerData[Character.Name].HealthpackTimer then
				PlayerData[Character.Name].HealthpackTimer = true
				PassivesManager:Healthpack(Character, DamageTracker:RetrieveData(Character).Counter, StatData.ReiatsuPack)

				task.delay(30, function()
					if PlayerData[Character.Name] and PlayerData[Character.Name].HealthpackTimer then
						PlayerData[Character.Name].HealthpackTimer = nil
					end
				end)
			end
			
			DamageTracker:Reset(Character)
			
			StateMachine:SetState("Dying")
			StateMachine:Trigger("TriggerDeath", StateMachine, Character, ...)
		end,
	},
	Executing = {
		TakeDamage = function(StateMachine, Character, ...)
			DamageTaken(Character, ...)
		end,
		PerfectFlashstep = function(StateMachine, Character, ...)
			PerfectFlashstep(Character, ...)
		end,
		Execute = function(StateMachine, Character)
			local KillCheck = false
			for i, v in pairs(workspace.Entities:GetChildren()) do
				if v.PrimaryPart and v:GetAttribute("CurrentState") == "Unconscious" and not v:GetAttribute("Carried") and not v:GetAttribute("Death") and v ~= Character  and not KillCheck and not v:GetAttribute("GripBypass") then
					if (v.HumanoidRootPart.Position - Character.PrimaryPart.Position).Magnitude < 10 then
						local Player = Players:GetPlayerFromCharacter(Character)
						local Profile = DataManager:RequestProfile(Player)
						local ShinigamiRank = Profile.ClientData.ShinigamiRank
						KillCheck = true

						Character.Humanoid.WalkSpeed = 0
						Character.Humanoid.JumpHeight = 0

						PlayerData[Character.Name].Victim = v
						
						EntityManager:ChangeState(v, "TriggerDying")
						
						if HollowForms[ShinigamiRank] ~= "VastoLorde" then
							local RightHand = Character:FindFirstChild("Right Hand")
							if not RightHand then
								RightHand = Character.RightHand
							end
							
							v.HumanoidRootPart.CFrame = RightHand.CFrame * CFrame.new(Vector3.new(0, -3, 0))
							
							local Weld = Instance.new("Weld")
							Weld.Name = "EatWeld"
							Weld.Part0 = RightHand
							Weld.Part1 = v.HumanoidRootPart
							Weld.Parent = RightHand
						end
						
						local EatAnimation = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]].Eat)
						EatAnimation:Play()

						local ExecutorDestroyed
						local VictimDestroyed
						
						EatAnimation.KeyframeReached:Connect(function(KeyframeName)
							if KeyframeName == "EventFrame" then
								PlayerData[Character.Name].VictimDestroyed:Disconnect()
								PlayerData[Character.Name].VictimDestroyed = nil
								v:BreakJoints()
								EntityManager:ChangeState(v, "TriggerDeath", Character)
								PlayerData[Character.Name].Victim = nil
								
								if not v:GetAttribute("Death") then
									if Character:GetAttribute("EntityType") == "Fishbone" or Character:GetAttribute("EntityType") == "Menos" then
										RankManager:AddEXP(Player, 10)
									else
										RankManager:AddEXP(Player, StatData.EatingEXP)
									end
								end
							elseif KeyframeName == "AnimationEnd" then
								PlayerData[Character.Name].ExecutorDestroyed:Disconnect()
								PlayerData[Character.Name].ExecutorDestroyed = nil
								StateMachine:Trigger("ReleaseExecute", StateMachine, Character)
							end
						end)
						
						PlayerData[Character.Name].ExecutorDestroyed = Player.CharacterRemoving:Connect(function() -- Player left
							EntityManager:Trigger(v, "ReleaseDying")
							VictimDestroyed:Disconnect()
							VictimDestroyed = nil
							ExecutorDestroyed:Disconnect()
							ExecutorDestroyed = nil
						end)

						PlayerData[Character.Name].VictimDestroyed = v.Destroying:Connect(function() -- Target left
							StateMachine:Trigger("ReleaseExecute", StateMachine, Character)
							ExecutorDestroyed:Disconnect()
							ExecutorDestroyed = nil
							VictimDestroyed:Disconnect()
							VictimDestroyed = nil
						end)
					end
				elseif v:GetAttribute("CurrentState") == "Food" and Character:GetAttribute("EntityType") ~= "VastoLorde" and not v:GetAttribute("Death") and v ~= Character  and not KillCheck and not v:GetAttribute("GripBypass") then
					if (v.Torso.Position - Character.PrimaryPart.Position).Magnitude < 20 then
						local Player = Players:GetPlayerFromCharacter(Character)
						local Profile = DataManager:RequestProfile(Player)
						KillCheck = true
						
						v:SetAttribute("Death", true)
						
						Character.Humanoid.WalkSpeed = 0
						Character.Humanoid.JumpHeight = 0

						local ShinigamiRank = Profile.ClientData.ShinigamiRank
						local FeedAnimation = Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]].Feed)
						FeedAnimation:Play()
						
						local FeedSound = Sounds.Feed:Clone()
						FeedSound.Parent = Character.PrimaryPart
						FeedSound:Play()
						
						FeedAnimation.KeyframeReached:Connect(function(KeyframeName)
							if KeyframeName == "EventFrame" then
								
							elseif KeyframeName == "AnimationEnd" then
								EntityManager:ChangeState(v, "TriggerDeath")
								
								if v:GetAttribute("Corrupt") > 1 then
									RankManager:AddEXP(Player, HollowEXP[v:GetAttribute("EntityType")].Corrupt)
								else
									RankManager:AddEXP(Player, HollowEXP[v:GetAttribute("EntityType")].Normal)
								end
								
								PlayerData[Character.Name].Victim = nil
								StateMachine:Trigger("ReleaseExecute", StateMachine, Character)
								
								if v == PlayerData[Character.Name].VastoLordeFight and HollowForms[ShinigamiRank] == "Adjuchas" then
									RankManager.HollowEvolution[16](Player, Profile)
									
									local WebhookInfo = {
										Message = "The birth of a Vasto Lorde.";
										Title = Player.Name .. " " .. Player.UserId;
									}

									Webhooks:Post(WebhookChannel, WebhookInfo)
								end
							end
						end)
					end
				end
			end		
			if not KillCheck then
				StateMachine:SetState("Idle")
			end
		end,
		TriggerExecute = function(StateMachine, Character)
			if PlayerData[Character.Name].Victim then
				EntityManager:ChangeState(PlayerData[Character.Name].Victim, "ReleaseDying")
				PlayerData[Character.Name].Victim = nil
				StateMachine:Trigger("ReleaseExecute", StateMachine, Character)
			end
		end,
		TriggerUnconscious = function(StateMachine, Character, ...)
			StateMachine:SetState("Unconscious")
			StateMachine:Trigger("TriggerDying", StateMachine, Character, ...)
		end,
		TriggerTrueStun = function(StateMachine, Character, ...)			
			StateMachine:Trigger("ReleaseExecute", StateMachine, Character)
			StateMachine:PushState("Idle")
			StateMachine:SetState("TrueStunned")
			StateMachine:Trigger("TrueStun", StateMachine, Character, ...)
		end,
		ReleaseExecute = function(StateMachine, Character)
			local Player = Players:GetPlayerFromCharacter(Character)
			local Profile = DataManager:RequestProfile(Player)
			if HollowForms[Profile.ClientData.ShinigamiRank] ~= "VastoLorde" then
			local RightHand = Character:FindFirstChild("Right Hand")
				if not RightHand then
					RightHand = Character.RightHand
				end
				
				if RightHand:FindFirstChild("EatWeld") then
					RightHand.EatWeld:Destroy()
				end
				
				if Character.PrimaryPart:FindFirstChild("Feed") then
					Character.PrimaryPart.Feed:Destroy()
				end
			end
			
			if PlayerData[Character.Name].VictimDestroyed then
				PlayerData[Character.Name].VictimDestroyed:Disconnect()
				PlayerData[Character.Name].VictimDestroyed = nil
			end

			if PlayerData[Character.Name].ExecutorDestroyed then
				PlayerData[Character.Name].ExecutorDestroyed:Disconnect()
				PlayerData[Character.Name].ExecutorDestroyed = nil
			end
			
			if PlayerData[Character.Name].Victim then
				EntityManager:ChangeState(PlayerData[Character.Name].Victim, "ReleaseDying")
				PlayerData[Character.Name].Victim = nil
			end
			--SharedFunctions:CancelAnimation(Character.Humanoid, "Feed")
			SharedFunctions:CancelAnimation(Character.Humanoid, "Eat")

			Character.Humanoid.WalkSpeed = Character:GetAttribute("BaseWalkspeed") 
			Character.Humanoid.JumpHeight = Character:GetAttribute("BaseJumpheight")
			Character.Humanoid.AutoRotate = true
			StateMachine:SetState("Idle")
		end,
	},
	
}

function HollowData:SetupEntity(EntityID, Player)
	PlayerData[Player.Name] = {}
	local Profile = DataManager:RequestProfile(Player)
	
	local function SetupVastoLorde(Player, Profile)
		local Character = Player.Character
		local PlayerAvatar
		if Player.UserId > 0 then
			local Success, Error = pcall(function()
				PlayerAvatar = Players:GetCharacterAppearanceAsync(Player.UserId)
			end)
			if not Success then
				PlayerAvatar = ServerStorage.Assets.Misc.AppearanceFailedToLoad:Clone()
				warn(Error)
			end
		else
			PlayerAvatar = ServerStorage.Assets.Misc.AppearanceFailedToLoad:Clone()
		end
		PlayerAvatar.Parent = ServerStorage

		task.delay(5, function()
			PlayerAvatar:Destroy()
			PlayerAvatar = nil
		end)	

		local AppearanceData = {
			PlayerHair = {},
			BodyColor = Color3.fromRGB(255, 255, 255)
		}
		
		local BodyColors = Instance.new("BodyColors")
		BodyColors.HeadColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.LeftArmColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.LeftLegColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.RightArmColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.RightLegColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.TorsoColor = BrickColor.new(AppearanceData.BodyColor)
		BodyColors.Parent = Character
		
		Character.Head.face:Destroy()
		local FakeHead = Character.Head:Clone()
		FakeHead.Name = Character.Name .. "Head"
		FakeHead.CanCollide = false
		FakeHead.Massless = true
		FakeHead.Transparency = 1

		local Weld = Instance.new("Weld")
		Weld.Part0 = FakeHead
		Weld.Part1 = Character.Head
		Weld.Parent = FakeHead
		FakeHead.Parent = workspace.Effects[Player.Name]
		
		for _, Child in ipairs(PlayerAvatar:GetChildren()) do -- Only stores the players hair accessories
			if Child.ClassName == "Accessory" then
				if Child.Handle:FindFirstChild("HairAttachment") or table.find(HairWhitelist, Child.Name) or Child.Name:match("hair") or Child.Name:match("Hair") or Child.Name:match("bangs") or Child.Name:match("Bangs") then
					table.insert(AppearanceData.PlayerHair, Child)
				end	
			end
		end

		local function color3ToVector3(c3)
			return Vector3.new(c3.r, c3.g, c3.b)
		end

		-- Clone and change color of any hair accessories the player has
		for _, v in pairs(AppearanceData.PlayerHair) do 
			local NewAccessory = v:Clone()
			local Mesh = NewAccessory.Handle:FindFirstChildWhichIsA("SpecialMesh")
			if Mesh then
				Mesh.TextureId = "rbxassetid://4486606505" -- rbxassetid://2880764254 (OLD TEXTURE)
				NewAccessory.Handle.Color = Color3.fromRGB(6, 0, 0)
				Mesh.VertexColor = color3ToVector3(NewAccessory.Handle.Color)
			end
			NewAccessory.Parent = Character
		end
		
		--[[local Abs = ServerStorage.Assets.Accessories.VastoLorde.Abs:Clone()
		Abs.Color = AppearanceData.BodyColor
		Abs.Parent = Character

		local AbsWeld = Instance.new("Weld")
		AbsWeld.Part1 = Character.Torso
		AbsWeld.C0 = CFrame.new(-0.000207901001, 0, 0.503204346, 1, 0, 0, 0, 1, 0, 0, 0, 0.999998987)
		AbsWeld.Part0 = Abs
		AbsWeld.Parent = Abs]]
		
		Character.Torso.Transparency = 0.001
		Character.HumanoidRootPart.Color = Color3.fromRGB(255, 255, 255)
		
		local VastoHole = ServerStorage.Assets.Accessories.VastoLorde.ChestHole:Clone()
		VastoHole.Parent = Character
		
		local VastoHoleWeld = Instance.new("Weld")
		VastoHoleWeld.Part1 = Character.Torso
		VastoHoleWeld.C0 = CFrame.new(0.367999315, -0.00370025635, -0.00149822235, 0, -1, 0, 0, 0, -0.999999821, 1, -0, -0)
		VastoHoleWeld.Part0 = VastoHole.PrimaryPart
		VastoHoleWeld.Parent = VastoHole.PrimaryPart
		
		local Fur = ServerStorage.Assets.Accessories.VastoLorde.Fur:Clone()
		Fur.Parent = Character
		
		local FurHeadWeld = Instance.new("Weld")
		FurHeadWeld.Part1 = Character.Head
		FurHeadWeld.C0 = CFrame.new(-0.11366272, 0.42651701, 0.00032043457, 0, 0, 1, 0, 1, 0, -1, 0, 0)
		FurHeadWeld.Part0 = Fur.NeckFur
		FurHeadWeld.Parent = Fur.NeckFur
		
		local FurLeftArm = Instance.new("Weld")
		FurLeftArm.Part1 = Character["Left Arm"]
		FurLeftArm.C0 = CFrame.new(-4.57763672e-05, 0.384243011, -0.167770386, 0, 0, 1, 0, 1, 0, -1, 0, 0)
		FurLeftArm.Part0 = Fur.LeftArmFur
		FurLeftArm.Parent = Fur.LeftArmFur

		local FurRightArm = Instance.new("Weld")
		FurRightArm.Part1 = Character["Right Arm"]
		FurRightArm.C0 = CFrame.new(-4.57763672e-05, 0.384243011, 0.1743927, 0, 0, 1, 0, 1, 0, -1, 0, 0)
		FurRightArm.Part0 = Fur.RightArmFur
		FurRightArm.Parent = Fur.RightArmFur
		
		--[[local FurLeftLeg = Instance.new("Weld")
		FurLeftLeg.Part1 = Character["Left Leg"]
		FurLeftLeg.C0 = CFrame.new(-0.000444412231, 0.410229325, 0.011505127, 1, 0, 0, 0, 0.999999881, 0, 0, 0, 0.999997616)
		FurLeftLeg.Part0 = Fur.FurLeftLeg
		FurLeftLeg.Parent = Fur.FurLeftLeg

		local FurRightLeg = Instance.new("Weld")
		FurRightLeg.Part1 = Character["Right Leg"]
		FurRightLeg.C0 = CFrame.new(-0.0184440613, 0.410229325, 0.011505127, 1, 0, 0, 0, 0.999999881, 0, 0, 0, 0.999997616)
		FurRightLeg.Part0 = Fur.FurRightLeg
		FurRightLeg.Parent = Fur.FurRightLeg]]

		local Pants = ServerStorage.Assets.Accessories.VastoLorde.Pants:Clone()
		Pants.Parent = Character
		
		local PantsRightWeld = Instance.new("Weld")
		PantsRightWeld.Part1 = Character["Right Leg"]
		PantsRightWeld.C0 = CFrame.new(0.0202770233, -0.703414202, -0.00966644287, -1, 0, 0, 0, 0.999999881, 0, 0, 0, -0.999999821)
		PantsRightWeld.Part0 = Pants.RightUpperLeg
		PantsRightWeld.Parent = Pants.RightUpperLeg
		
		local PantsLeftWeld = Instance.new("Weld")
		PantsLeftWeld.Part1 = Character["Left Leg"]
		PantsLeftWeld.C0 = CFrame.new(-0.0181217194, -0.716425896, -0.00966644287, -1, 0, 0, 0, 0.999999881, 0, 0, 0, -0.999999821)
		PantsLeftWeld.Part0 = Pants.LeftUpperLeg
		PantsLeftWeld.Parent = Pants.LeftUpperLeg
		
		local BeltWeld = Instance.new("Weld")
		BeltWeld.Part1 = Character["Torso"]
		BeltWeld.C0 = CFrame.new(-0.0204277039, 1.00640297, -0.133163452, -1, 0, 0, 0, 1, 0, 0, 0, -0.999999821)
		BeltWeld.Part0 = Pants.LowerTorso
		BeltWeld.Parent = Pants.LowerTorso
		
		local Shirt = ServerStorage.Assets.Accessories.VastoLorde.VastoShirt:Clone()
		Shirt.Parent = Character
		
		local VastoLordeMask = ServerStorage.Assets.Accessories.VastoLorde.VastoLordeMask:Clone()
		VastoLordeMask.Parent = Character
		
		local MaskWeld = Instance.new("Weld")
		MaskWeld.Part1 = Character.Head
		MaskWeld.C0 = CFrame.new(0.000161647797, -3.81469727e-06, -0.000267028809, 1, 0, 0, 0, 1, 0, 0, 0, 0.999999285);
		MaskWeld.Part0 = VastoLordeMask.PrimaryPart
		MaskWeld.Parent = VastoLordeMask.PrimaryPart
		
		Character.Animate.Disabled = false
		
		local Name
		local FirstName = Profile.ClientData.Name
		local ClanName = Profile.ClientData.Clan
		local Title = Profile.ClientData.Title
		local ClanInfo = ClanData[ClanName]
		
		Name = FirstName .. " " .. ClanName
		if ClanInfo.HideClanName then
			Name = FirstName
		end
		
		local Settings = Player.PlayerGui:FindFirstChild("Settings")
		if Settings then
			Settings.Frame.CharacterName.Text = Name
		end

		local Info = {
			Rank = Profile.ClientData.GlobalRank,
			Grade = DataManager:RequestRank(Player),
			Name = Name,
			ClanName = ClanName,
			Title = Title,
			Race = Profile.ClientData.Race,
		}
		
		Player:SetAttribute("Race", Profile.ClientData.Race)
		ReplicatedStorage.Remotes.LeaderboardEvent:FireAllClients("Update", Player.Name, Info)
		
		Character.Humanoid.DisplayName = Name
		Character.Humanoid.MaxHealth = Profile.ClientData.MaxHealth
		Character.Humanoid.Health = Profile.ClientData.MaxHealth - 1
		
		for i, v in ipairs(Character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CollisionGroup = "Entity"
			end
		end
		
		Character.Parent = workspace.Entities
	end
	
	local function SetupHollowForm(Player, Profile)
		local ShinigamiRank = Profile.ClientData.ShinigamiRank
		local HollowForm = ServerStorage.Assets.Entities[HollowForms[ShinigamiRank]]:Clone()
		HollowForm.Name = Player.Name
		
		local CameraDistance = 30
		
		if HollowForms[ShinigamiRank] ~= "Menos" then
			local ColorTable = {
				{135, 135, 135},
				{129, 113, 135},
				{135, 87, 88},
				{112, 121, 135},
				{135, 104, 95},
				{131, 135, 107},
				{135, 103, 64},
				{135, 79, 80},
				{107, 120, 135},
			}

			local RandomColor = ColorTable[math.random(1, #ColorTable)]

			for i, v in ipairs(HollowForm:GetChildren()) do
				if v:IsA("BasePart") then
					v.Color = Color3.fromRGB(RandomColor[1], RandomColor[2], RandomColor[3])
				end
			end
		else
			CameraDistance = 200
		end
		
		HollowForm.Parent = workspace.Entities
		Player.Character = HollowForm
		
		local Blacklist = {
			CharacterTilt = true;
			Animate = true;
		}
		
		local StarterPlayer = game:GetService("StarterPlayer")
		for i, v in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
			if not Blacklist[v.Name] then
				local Scripts = v:Clone()
				Scripts.Parent = Player.Character
			end
		end
		
		Player.Character.Humanoid.MaxHealth = Profile.ClientData.MaxHealth
		Player.Character.Humanoid.Health = Profile.ClientData.MaxHealth
		
		for i, v in ipairs(Player.Character:GetDescendants()) do
			if v:IsA("BasePart") then
				if HollowForms[ShinigamiRank] ~= "Menos" then
					v.CollisionGroup = "Entity"
				else
					v.CollisionGroup = "Entity2"
				end
			end
		end

		local ClientAnimation = HollowForm["Animate" .. HollowForms[ShinigamiRank]]:Clone()
		HollowForm["Animate" .. HollowForms[ShinigamiRank]]:Destroy()
		ClientAnimation.Parent = Player.Character
		ClientAnimation.Disabled = false
		
		local Name
		local FirstName = Profile.ClientData.Name
		local ClanName = Profile.ClientData.Clan
		local Title = Profile.ClientData.Title
		local ClanInfo = ClanData[ClanName]
		
		local Spacer = " "
		if ClanInfo.Spacer then
			Spacer = ClanInfo.Spacer
		end

		Name = FirstName .. Spacer .. ClanName
		if ClanInfo.HideClanName then
			Name = FirstName
		end
		
		Player.Character.Humanoid.DisplayName = Name
		Player.Character.Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		Player.Character.Humanoid.NameDisplayDistance = 50
		Player.Character.Humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
		Player.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		
		local Info = {
			Rank = Profile.ClientData.GlobalRank,
			Grade = DataManager:RequestRank(Player),
			Name = Name,
			ClanName = ClanName,
			Title = Title,
			Race = Profile.ClientData.Race,
		}
		
		Player:SetAttribute("Race", Profile.ClientData.Race)
		ReplicatedStorage.Remotes.LeaderboardEvent:FireAllClients("Update", Player.Name, Info)
		ReplicatedStorage.Remotes.HollowCameraChange:FireClient(Player, CameraDistance)
		
		if HollowForms[ShinigamiRank] ~= "Menos" then
			local IdleAnim = Player.Character.Humanoid.Animator:LoadAnimation(HollowAnimations[HollowForms[ShinigamiRank]].Idle)
			IdleAnim.Priority = Enum.AnimationPriority.Core
			IdleAnim:Play()
			
			local EXP = Profile.ClientData.EXP
			
			local Eyes = Player.Character.Mask.Eyes
			local Yellow = Color3.fromRGB(255, 255, 142)
			local Red = Color3.fromRGB(255, 0, 0)
			Eyes.Color = Yellow:Lerp(Red, EXP / RankManager:RetrieveEXPReqs()[ShinigamiRank])
			
			if Profile.ClientData.VastoLordeReqs.MaskCracks >= StatData.MaskCrackReq and not Profile.ClientData.FailedVasto then
				task.spawn(function()
					for i, v in ipairs(Player.Character:GetChildren()) do
						if v:IsA("BasePart") then
							v.Color = Color3.fromRGB(248, 248, 248)
						end
					end

					Player.Character.Mask.Eyes.Color = Color3.fromRGB(255, 0, 0)
					Player.Character.Chest["Jackal Hair"].Color = Color3.fromRGB(89, 0, 0)
				end)
			end
		else
			local CorruptMenos = {
				3427072680; -- haniyura
				77857290; -- 4Data
				36710249; -- MassRelays
			}
			
			if table.find(CorruptMenos, Player.UserId) then
				Player.Character:SetAttribute("CorruptMenos", true)
				for i, v in ipairs(Player.Character:GetDescendants()) do
					if v:IsA("BasePart") and v.Color == Color3.fromRGB(17, 17, 17) then
						v.Color = Color3.fromRGB(255, 255, 255)
					end
				end
			end
		end
	end

	local function CreateAttributes(Character, Profile, EntityID)
		local PlayerSPTable = DataManager:RequestSP(Player)
		local PlayerUnlockedSkills = Profile.UnlockedSkills
		local Toolbar = DataManager:RequestSkillInventory(Player)
		
		local ShinigamiRank = Profile.ClientData.ShinigamiRank
		
		PassivesManager:SetupPassives(Player, PlayerUnlockedSkills)
		DamageTracker:Setup(Character)
		
		Character:SetAttribute("Respawning", true)
		Character:SetAttribute("EntityType", HollowForms[ShinigamiRank])
		
		Character:SetAttribute("Speed", PlayerSPTable.Speed)
		Character:SetAttribute("Kendo", PlayerSPTable.Kendo)
		
		Character:SetAttribute("EntityID", EntityID)
		Character:SetAttribute("MaxHealth", Character.Humanoid.MaxHealth)
		Character:SetAttribute("MaxPosture", Profile.ClientData.MaxPosture + (PlayerSPTable.Kendo * StatData.KendoScalingMaxPosture))
		Character:SetAttribute("Posture", 0)
		Character:SetAttribute("TrueMaxReiatsu", RankManager:RetrievePlayerStats(Profile.ClientData.ShinigamiRank).Reiatsu)
		Character:SetAttribute("MaxReiatsu", Profile.ClientData.MaxReiatsu)
		Character:SetAttribute("Reiatsu", Profile.ClientData.MaxReiatsu - 1)
		Character:SetAttribute("Combo", 1)
		Character:SetAttribute("BaseWalkspeed", StatData.WalkSpeeds.Base)
		Character:SetAttribute("BaseJumpheight", StatData.JumpHeights.Base)
		
		Character:SetAttribute("CounterType", "string")
		Character:SetAttribute("CounterFrames", false)
		Character:SetAttribute("EvasiveFrames", false)
		Character:SetAttribute("DeflectFrames", false)
		Character:SetAttribute("BlockFrames", false)
		Character:SetAttribute("IFrames", true)
		Character:SetAttribute("HyperArmor", false)

		Character:SetAttribute("CurrentState", "Idle")

		Character:SetAttribute("FlashstepCooldown", 3000)
		Character:SetAttribute("ParryCooldown", 1700) -- Time in milliseconds for parry to come off cooldown (just checks current time compares to this value)
		Character:SetAttribute("BlockTimer", DateTime.now().UnixTimestampMillis)
		Character:SetAttribute("FlashstepTimer", DateTime.now().UnixTimestampMillis)
		Character:SetAttribute("ComboTimer", DateTime.now().UnixTimestampMillis)
		Character:SetAttribute("DashTimer", DateTime.now().UnixTimestampMillis)
		Character:SetAttribute("FeintTimer", DateTime.now().UnixTimestampMillis)
		Character:SetAttribute("ShikaiTimer", DateTime.now().UnixTimestampMillis)

		Character:SetAttribute("CombatTag", 0)
		Character:SetAttribute("PlayerCombatTag", 0)
		Character:SetAttribute("SternritterCombatTag", 0)

		Character:SetAttribute("Z", false)
		Character:SetAttribute("X", false)
		Character:SetAttribute("C", false)
		Character:SetAttribute("T", false)
		Character:SetAttribute("G", false)
		Character:SetAttribute("CriticalAttack", false)

		Character:SetAttribute("One", false)
		Character:SetAttribute("Two", false)
		Character:SetAttribute("Three", false)
		Character:SetAttribute("Four", false)
		Character:SetAttribute("Five", false)
		Character:SetAttribute("Six", false)
		Character:SetAttribute("Seven", false)
		Character:SetAttribute("Eight", false)
		Character:SetAttribute("Nine", false)
		Character:SetAttribute("Zero", false)
		Character:SetAttribute("Minus", false)
		Character:SetAttribute("Equals", false)
		
		PlayerData[Player.Name].Cooldowns = {
			One = 0;
			Two = 0;
			Three = 0;
			Four = 0;
			Five = 0;
			Six = 0;
			Seven = 0;
			Eight = 0;
			Nine = 0;
			Zero = 0;
			Minus = 0;
			Equals = 0;
			Z = 0;
			X = 0;
			C = 0;
			T = 0;
			G = 0;
		}
		
		Character.Humanoid.BreakJointsOnDeath = false
		Character:SetAttribute("ZanpakutoState", 0) 
		Character:SetAttribute("Kan", Profile.ClientData.Kan)
		
		task.delay(1.4, function()
			local PlayerItemInventory = Profile.ItemInventory
			ReplicatedStorage.Remotes.LoadClient:FireClient(Player, Profile.Settings, true)
			task.delay(0.2, function()
				ReplicatedStorage.Remotes.UpdateSkillTreeEvent:FireClient(Player, PlayerSPTable, PlayerUnlockedSkills, Toolbar, nil, PlayerItemInventory)
				ReplicatedStorage.Remotes.UpdateToolbarEvent:FireClient(Player, Toolbar)
			end)
			
			local ItemInventory = Profile.ItemInventory
			
			local function CreateTradeableButtons()
				for ItemName, Quantity in pairs(ItemInventory) do
					local ValidItem = TradeablesData[ItemName]
					if ValidItem then
						local ItemInfo = {
							ItemName = ItemName;
							Info = ValidItem;
						}
						ReplicatedStorage.Remotes.UpdateAccessoryUIEvent:FireClient(Player, ItemInfo, ItemInventory)
					end
				end
			end
			coroutine.wrap(CreateTradeableButtons)()	
			
			for i, v in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					if v:IsDescendantOf(Players) then
						local Profile = DataManager:RequestProfile(v)
						if Profile then
							local Name
							local FirstName = Profile.ClientData.Name
							local ClanName = Profile.ClientData.Clan
							local ClanInfo = ClanData[ClanName]
							local Spacer = " "
							if ClanInfo.Spacer then
								Spacer = ClanInfo.Spacer
							end

							Name = FirstName .. Spacer .. ClanName
							if ClanInfo.HideClanName then
								Name = FirstName
							end

							local Info = {
								Rank = Profile.ClientData.GlobalRank,
								Grade = DataManager:RequestRank(v),
								Name =  Name,
								Title = Profile.ClientData.Title,
								LeaderboardHidden = ClanInfo.LeaderboardHidden,
								Race = Profile.ClientData.Race,
							}
							
							if Profile.ClientData.Race == "Visored" or Profile.ClientData.Race == "Vastocar" then
								Info.HiddenGrade = "???"
								if Profile.ClientData.WeakVisored or Profile.ClientData.WeakVasto then
									Info.HiddenGrade = "?"
								end
							end

							ReplicatedStorage.Remotes.LeaderboardEvent:FireAllClients("Create", v.Name, Info)
						end
					end
				end)
			end
		end)
	end
	
	local function CheckVastoLordeQuest(Character, Profile)
		if StatData.IsReserved then
			return
		end
		
		if StatData.HuecoMundo and HollowForms[Profile.ClientData.ShinigamiRank] == "Adjuchas" and not Profile.ClientData.VastoFailed then
			local VastoDestinations = workspace.VastoLordeQuest:GetChildren()
			
			local ChosenGrace = VastoDestinations[math.random(1, #VastoDestinations)]
			
			local RandomColors = {
				Color3.fromRGB(255, 255, 255);
				Color3.fromRGB(0, 0, 0);
				Color3.fromRGB(255, 0, 0);
				Color3.fromRGB(251, 255, 0);
				Color3.fromRGB(4, 255, 0);
				Color3.fromRGB(0, 255, 238);
				Color3.fromRGB(3, 41, 255);
				Color3.fromRGB(115, 0, 255);
				Color3.fromRGB(247, 0, 255);
				Color3.fromRGB(182, 134, 106);
				Color3.fromRGB(74, 42, 88);
				Color3.fromRGB(188, 129, 129);
			}
			
			local function DeepCopyTable(t)
				local copy = {}
				for key, value in pairs(t) do
					if type(value) == "table" then
						copy[key] = DeepCopyTable(value)
					else
						copy[key] = value
					end
				end
				return copy
			end
			
			local FalseGraces = {}
			local ChosenColor = RandomColors[math.random(1, #RandomColors)]
			local CopiedColorTable = DeepCopyTable(RandomColors)
			table.remove(CopiedColorTable, table.find(CopiedColorTable, ChosenColor))
			for i, v in ipairs(CopiedColorTable) do
				local FalseGrace = {}
				local FalseColor = CopiedColorTable[math.random(1, #CopiedColorTable)]
				FalseGrace.Color = FalseColor
				FalseGrace.Destination = VastoDestinations[math.random(1, #VastoDestinations)]
				table.remove(CopiedColorTable, table.find(CopiedColorTable, FalseColor))
				table.insert(FalseGraces, FalseGrace)
			end
			
			
			local ClientProgression = ReplicatedStorage.Modules.ClientModules.ClientProgression
			local WhisperPath = {Module = ClientProgression, Skill = "VastoLordeWhispers"}
			local PathData = {Module = ClientProgression, Skill = "VastoLordeQuest"}
			local FightPath = {Module = ClientProgression, Skill = "VastoLordeFight"}
			local RenderDistance = -1
			
			local function InsidePartRegion(PartRegion, Point)
				local v3 = PartRegion.CFrame:PointToObjectSpace(Point)
				return (math.abs(v3.X) <= PartRegion.Size.X / 2)
					and (math.abs(v3.Y) <= PartRegion.Size.Y / 2)
					and (math.abs(v3.Z) <= PartRegion.Size.Z / 2)
			end
			
			local ColorChanged
			
			local Reached
			local WhisperRate = 0
			local TrailRate = 0.5
			local Rate = 0.1
			local Accumulated = 0
			PlayerData[Character.Name].VastoLordeConnection = RunService.Heartbeat:Connect(function(DeltaTime)
				Accumulated += DeltaTime
				if Accumulated > Rate then
					Accumulated -= Rate
					
					if Profile.ClientData.VastoLordeReqs.MaskCracks >= StatData.MaskCrackReq then
						WhisperRate -= Rate
						
						if not ColorChanged then
							ColorChanged = true
							
							task.spawn(function()
								for i, v in ipairs(Character:GetChildren()) do
									if v:IsA("BasePart") then
										v.Color = Color3.fromRGB(248, 248, 248)
									end
								end

								Character.Mask.Eyes.Color = Color3.fromRGB(255, 0, 0)
								Character.Chest["Jackal Hair"].Color = Color3.fromRGB(89, 0, 0)
							end)
						end
						
						if Profile.ClientData.VastoLordeReqs.RivalCrack then
							TrailRate -= Rate
						end

						if WhisperRate <= 0 then
							WhisperRate = 3
							
							if Profile.ClientData.VastoLordeReqs.RivalCrack then
								NetworkManager.FireClient(Player, Player.Character, "ClientEffects", RenderDistance, WhisperPath)
							else
								NetworkManager.FireClient(Player, Player.Character, "ClientEffects", RenderDistance, WhisperPath, true)
							end
						end
						if TrailRate <= 0 then
							TrailRate = 20
							
							local RandomNumber = math.random(1, 10)
							if RandomNumber <= 1 then
								NetworkManager.FireClient(Player, Player.Character, "ClientEffects", RenderDistance, PathData, ChosenGrace.CFrame, ChosenColor)
							else
								local RandomGrace = FalseGraces[math.random(1, #FalseGraces)]
								NetworkManager.FireClient(Player, Player.Character, "ClientEffects", RenderDistance, PathData, RandomGrace.Destination.CFrame, RandomGrace.Color)
							end
						end
						
						if Player.Character and Player.Character.PrimaryPart and Profile.ClientData.VastoLordeReqs.RivalCrack then
							if InsidePartRegion(ChosenGrace, Player.Character.PrimaryPart.Position) and not Reached then
								Reached = true

								NetworkManager.FireClient(Player, Player.Character, "ClientEffects", RenderDistance, FightPath)

								Profile.ClientData.VastoWipeTag = true

								task.delay(3, function()
									if PlayerData[Character.Name] and Character and Character:FindFirstChild("Humanoid") and Character.Humanoid.Health > 0 then
										Character:SetAttribute("DoingVastoQuest", true)
										
										PlayerData[Character.Name].VastoLordeFight = NPCManager:NPC("VastoLorde", "NPCVastoLorde", ChosenGrace.Position, Player, Player.Character)
										PlayerData[Character.Name].VastoLordeFightConnection = PlayerData[Character.Name].VastoLordeFight.Humanoid.Died:Connect(function()
											Profile.ClientData.VastoWipeTag = nil
											PlayerData[Character.Name].VastoLordeFightConnection:Disconnect()
											PlayerData[Character.Name].VastoLordeFightConnection = nil
										end)
									end
								end)

								PlayerData[Character.Name].VastoLordeConnection:Disconnect()
								PlayerData[Character.Name].VastoLordeConnection = nil
							end
						end
					end
				end
			end)
		end
		
		task.delay(0.3, function()
			if Profile.ClientData.VastoFailed then
				ReplicatedStorage.Remotes.MaskCrackUpdate:FireClient(Player, Profile.ClientData.VastoLordeReqs.MaskCracks, "Failed")
			else
				if HollowForms[Profile.ClientData.ShinigamiRank] == "Adjuchas" then
					ReplicatedStorage.Remotes.MaskCrackUpdate:FireClient(Player, Profile.ClientData.VastoLordeReqs.MaskCracks)
				end
			end
		end)
	end
	
	local function ForcefieldOnSpawn(Character)
		Character:SetAttribute("IFrames", true)
		
		for i, v in ipairs(Character:GetDescendants()) do
			if v:IsA("BasePart") then
				if v.Anchored == false then
					v:SetNetworkOwner(Player)
				end
				v.CollisionGroup = "Entity2"
			end
		end

		local ForceFieldHighlight = Instance.new("Highlight")
		ForceFieldHighlight.OutlineColor = Color3.fromRGB(0, 234, 255)
		ForceFieldHighlight.OutlineTransparency = 0.5
		ForceFieldHighlight.FillColor = Color3.fromRGB(0, 234, 255)
		ForceFieldHighlight.FillTransparency = 0.5
		ForceFieldHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		ForceFieldHighlight.Parent = Character
		
		local SpawnPosition = Character.HumanoidRootPart.Position
		local Accumulated = 0

		PlayerData[Player.Name].CharacterForcefield = RunService.Heartbeat:Connect(function(DeltaTime)
			Accumulated += DeltaTime
			
			if Accumulated > 30 and PlayerData[Player.Name].CharacterForcefield then
				Character:SetAttribute("IFrames", false)
				Character:SetAttribute("Forcefield", nil)

				PlayerData[Player.Name].CharacterForcefield:Disconnect()
				PlayerData[Player.Name].CharacterForcefield = nil

				for i, v in ipairs(Character:GetDescendants()) do
					if v:IsA("BasePart") then
						v.CollisionGroup = "Entity"
					end
				end
				
				ForceFieldHighlight:Destroy()
				ForceFieldHighlight = nil
				return
			end

			if Character and Character:FindFirstChild("HumanoidRootPart") then
				local Magnitude = (Character.HumanoidRootPart.Position - SpawnPosition).Magnitude
				if Magnitude >= 10 then
					Character:SetAttribute("IFrames", false)
					Character:SetAttribute("Forcefield", nil)

					if PlayerData[Player.Name].CharacterForcefield then
						PlayerData[Player.Name].CharacterForcefield:Disconnect()
						PlayerData[Player.Name].CharacterForcefield = nil

						for i, v in ipairs(Character:GetDescendants()) do
							if v:IsA("BasePart") then
								if HollowForms[Profile.ClientData.ShinigamiRank] ~= "Menos" then
									v.CollisionGroup = "Entity"
								else
									v.CollisionGroup = "Entity2"
								end
							end
						end
						
						ForceFieldHighlight:Destroy()
						ForceFieldHighlight = nil
					end
				end
			end
		end)
	end
	
	PlayerData[Player.Name].CharacterAdded = Player.CharacterAdded:Connect(function(Character)
		PlayerData[Player.Name].PlayerDied = Character.Humanoid.Died:Connect(function()
			AntiCheatManager:PlayerNotLoaded(Player)
			
			if PlayerData[Character.Name].ResetConnection then
				PlayerData[Character.Name].ResetConnection:Disconnect()
				PlayerData[Character.Name].ResetConnection = nil
			end
			
			if not StatData.LockVasto and HollowForms[Profile.ClientData.ShinigamiRank] == "Adjuchas" then
				if not Character:GetAttribute("DeathBypass") and Character:GetAttribute("CombatTag") > 0 then
					RankManager:AddEXP(Player, StatData.DeathEXPLoss)

					local MaskCracks = Profile.ClientData.VastoLordeReqs.MaskCracks
					MaskCracks -= StatData.MasksLostOnDeath
					if MaskCracks <= 0 then
						MaskCracks = 0
					end
					Profile.ClientData.VastoLordeReqs.MaskCracks = MaskCracks

					ReplicatedStorage.Remotes.MaskCrackUpdate:FireClient(Player, Profile.ClientData.VastoLordeReqs.MaskCracks)

					local WebhookInfo = {
						Message = Player.Name .. " lost " .. StatData.MasksLostOnDeath .. " masks";
					}

					--Webhooks:Post(WebhookChannel, WebhookInfo)	
				end
			end
			
			Character:SetAttribute("CombatTag", 0)
			Profile.ClientData.CombatLogged = 0
			
			AntiCheatManager:ClearLastPosition(Player)
			
			CombatManager:ResetCombatTags(Character, Player)
			CombatManager:ClearAllTags(Character)
			
			ServerStorage.LiveAssets[Character.Name]:ClearAllChildren()
			workspace.Effects[Character.Name]:ClearAllChildren()
			
			if PlayerData[Player.Name].CharacterForcefield then
				PlayerData[Player.Name].CharacterForcefield:Disconnect()
				PlayerData[Player.Name].CharacterForcefield = nil
			end
			if PlayerData[Character.Name].VastoLordeFight then
				EntityManager:ForceState(PlayerData[Character.Name].VastoLordeFight, "Food")
				EntityManager:ChangeState(PlayerData[Character.Name].VastoLordeFight, "TriggerDeath")
				PlayerData[Character.Name].VastoLordeFight = nil
			end
			if PlayerData[Character.Name].VastoLordeConnection then
				PlayerData[Character.Name].VastoLordeConnection:Disconnect()
				PlayerData[Character.Name].VastoLordeConnection = nil
			end
			if PlayerData[Character.Name].VastoLordeFightConnection then
				PlayerData[Character.Name].VastoLordeFightConnection:Disconnect()
				PlayerData[Character.Name].VastoLordeFightConnection = nil
			end
			if Profile.ClientData.VastoWipeTag then
				Profile.ClientData.VastoWipeTag = nil
				Profile.ClientData.VastoFailed = true
				RankManager:SetRank(Player, 17)
				Profile.ClientData.EXP = 0
				
				local WebhookInfo = {
					Message = "Has de-evolved during their Vasto Lorde quest.";
					Title = Player.Name .. " " .. Player.UserId;
				}

				Webhooks:Post(WebhookChannel, WebhookInfo)
			end
			
			task.delay(3, function()
				if Player:IsDescendantOf(Players) then
					Player:LoadCharacter()
					
					if HollowForms[Profile.ClientData.ShinigamiRank] == "VastoLorde" then
						SetupVastoLorde(Player, Profile)
					else
						if not StatData.LockVasto then
							CheckVastoLordeQuest(Player.Character, Profile)
						end
						SetupHollowForm(Player, Profile)
					end
					CreateAttributes(Player.Character, Profile, EntityID)
					EntityManager:UpdateCharacter(EntityID, Player.Character)
					EntityManager:ForceState(Player.Character, "Idle")
					
					local HollowSpawns = workspace.ShinigamiSpawns:GetChildren()
					local RandomHollowSpawn = HollowSpawns[math.random(1, #HollowSpawns)].CFrame
					
					local AntiProfile = AntiCheatManager:RequestProfile(Player)
					if Player.Character:GetAttribute("EntityType") == "Menos" then
						AntiProfile:Initialize(Player.Character, RandomHollowSpawn * CFrame.new(0, 60, 0), true)
					else
						AntiProfile:Initialize(Player.Character, RandomHollowSpawn, true)
					end
					
					Player.Character:SetAttribute("Respawning", nil)
					ForcefieldOnSpawn(Player.Character)
					
					DamageTracker:Reset(Character, "Elo")
					DamageTracker:Reset(Character)
					
					local CurrentParty = Player:GetAttribute("Party")
					local Party = PartyManager.Parties[CurrentParty]
					if Party then
						local PartyMembers = Party.Members
						local ClientParty = ReplicatedStorage.Modules.ClientModules.ClientParty
						local RefreshPathData = {Module = ClientParty, Skill = "Refresh"}
						local RenderDistance = -1

						local PartyPosition
						for i, v in ipairs(PartyMembers) do
							if v == Player then
								PartyPosition = i
								break
							end
						end

						for i, Members in ipairs(PartyMembers) do
							NetworkManager.FireClient(Members, Members.Character, "ClientEffects", RenderDistance, RefreshPathData, PartyPosition, Player.Character)
						end
					end
					
					ReplicatedStorage.Remotes.DisableBlur:FireClient(Player)
				end
			end)
		end)
	end)
	
	Player:LoadCharacter()
	if HollowForms[Profile.ClientData.ShinigamiRank] == "VastoLorde" then
		SetupVastoLorde(Player, Profile)
	else
		if not StatData.LockVasto then
			CheckVastoLordeQuest(Player.Character, Profile)
		end
		SetupHollowForm(Player, Profile)
	end
	CreateAttributes(Player.Character, Profile, EntityID)
	
	if Profile.ClientData.LoggedPlace ~= StatData.Places[game.PlaceId] then
		Profile.ClientData.LoggedPosition = false
	end
	Profile.ClientData.LoggedPlace = StatData.Places[game.PlaceId]
	local LoggedPosition = Profile.ClientData.LoggedPosition
	
	local SpawnCFrame
	if LoggedPosition ~= false then
		local Position = Vector3.new(LoggedPosition[1], LoggedPosition[2], LoggedPosition[3])

		SpawnCFrame = CFrame.new(Position)
	else
		local HollowSpawns = workspace.ShinigamiSpawns:GetChildren()
		local RandomHollowSpawn = HollowSpawns[math.random(1, #HollowSpawns)].CFrame
		if Player.Character:GetAttribute("EntityType") == "Menos" then
			SpawnCFrame = RandomHollowSpawn * CFrame.new(0, 60, 0)
		else
			SpawnCFrame = RandomHollowSpawn
		end
	end
	
	local AntiProfile = AntiCheatManager:RequestProfile(Player)
	if Player.Character:GetAttribute("EntityType") == "Menos" then
		AntiProfile:Initialize(Player.Character, SpawnCFrame, true)
	else
		AntiProfile:Initialize(Player.Character, SpawnCFrame, true)
	end
	
	Player.Character:SetAttribute("Respawning", nil)
	ForcefieldOnSpawn(Player.Character)
	
	if Profile.ServerData.FirstLoad  then
		--Player.PlayerGui.DisplayUI.Enabled = true
		
		
		ReplicatedStorage.Remotes.ChooseName:FireClient(Player, "Disabled")
	else
		--Player.PlayerGui.DisplayUI.Enabled = true
	end
	
	AntiCheatManager:PlayerLoaded(Player)
	
	local PlayerDisconnected
	PlayerDisconnected = Player.Destroying:Connect(function()
		if PlayerData[Player.Name].VastoLordeFight then
			task.spawn(function()
				EntityManager:ForceState(PlayerData[Player.Name].VastoLordeFight, "Food")
				EntityManager:ChangeState(PlayerData[Player.Name].VastoLordeFight, "TriggerDeath")
			end)
		end
		
		if PlayerData[Player.Name] then
			for i, v in pairs(PlayerData[Player.Name]) do
				if typeof(v) == "RBXScriptConnection" then -- disconnects any existing connections to prevent memory leaks
					PlayerData[Player.Name][i]:Disconnect()
					PlayerData[Player.Name][i] = nil
				else
					PlayerData[Player.Name][i] = nil
				end
			end
		end
		PlayerData[Player.Name] = nil
		PlayerDisconnected:Disconnect()
		PlayerDisconnected = nil
	end)

	return Player.Character
end

return HollowData
