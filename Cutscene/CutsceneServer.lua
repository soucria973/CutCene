-- ServerScriptService > CutsceneServer
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configurações
local WALK_SPEED = 16
local ARRIVAL_DISTANCE_PLAYER = 3
local CAR_SPEED = 50 -- Velocidade do carro em studs/segundo

-- Objetos do jogo
local DESTINO = workspace.Tree1:WaitForChild("DESTINO")
local Carrin = workspace:WaitForChild("CenarioCC"):WaitForChild("Car")
local carModel = Carrin
local entryPoint = workspace:WaitForChild("CarEntryPoint")

-- Encontra o VehicleSeat
local vehicleSeat = carModel:FindFirstChild("VehicleSeat", true)
if not vehicleSeat then
	warn("? VehicleSeat não encontrado no carro!")
end

-- Configura PrimaryPart se não estiver definido
if not carModel.PrimaryPart then
	local chassis = carModel:FindFirstChild("Chassis") or carModel:FindFirstChild("Body")
	if chassis then
		carModel.PrimaryPart = chassis
	else
		warn("? Nenhum PrimaryPart definido para o carro!")
	end
end

-- RemoteEvents
local CutEvent = ReplicatedStorage:WaitForChild("CutsceneEvent")

-- Controle de jogadores
local activeCutscenes = {}

-- Função para ancorar/desancorar o carro
local function setCarAnchored(car, anchored)
	for _, part in ipairs(car:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

-- Função para mover o carro usando loop (mais confiável que Tween para models)
local function moveCarToDestination(car, destination, speed)
	local primaryPart = car.PrimaryPart
	if not primaryPart then
		warn("? PrimaryPart não encontrado no carro!")
		return false
	end

	-- Desancora o carro
	setCarAnchored(car, false)

	-- Movimento em loop
	local running = true
	task.spawn(function()
		while running do
			local currentPos = primaryPart.Position
			local targetPos = destination.Position
			local distance = (targetPos - currentPos).Magnitude

			-- Chegou ao destino
			if distance < 5 then
				running = false
				break
			end

			-- Calcula direção e movimento
			local direction = (targetPos - currentPos).Unit
			local moveAmount = math.min(speed * task.wait(), distance)

			-- Move o carro
			local newCFrame = primaryPart.CFrame + (direction * moveAmount)
			car:SetPrimaryPartCFrame(newCFrame)
		end

		-- Ancor o carro no destino
		setCarAnchored(car, true)
	end)

	-- Retorna uma promise
	return {
		Wait = function()
			while running do
				task.wait()
			end
		end
	}
end

-- Função principal da cutscene
local function startCutscene(player, character)
	-- Validação inicial
	local humanoid = character:FindFirstChild("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then 
		warn("? Humanoid ou HRP não encontrado para " .. player.Name)
		return
	end

	print("?? Iniciando cutscene para " .. player.Name)

	-- Desativa controle do jogador COMPLETAMENTE
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	-- Inicia cutscene no cliente (bloqueia controles)
	CutEvent:FireClient(player, "StartCutscene")

	-- FASE 1: Caminhada até o ponto de entrada
	print("?? Fase 1: Caminhando até o carro...")
	humanoid.WalkSpeed = WALK_SPEED
	humanoid:MoveTo(entryPoint.Position)

	-- Aguarda chegada
	local maxWait = 15
	local waited = 0
	while (hrp.Position - entryPoint.Position).Magnitude > ARRIVAL_DISTANCE_PLAYER do
		if not character or not character.Parent or waited > maxWait then
			warn("?? Cutscene cancelada para " .. player.Name)
			CutEvent:FireClient(player, "EndCutscene")
			return
		end
		task.wait(0.1)
		waited = waited + 0.1
	end

	-- Para o personagem
	humanoid.WalkSpeed = 0
	humanoid:MoveTo(hrp.Position) -- Para o movimento
	task.wait(0.3)

	-- FASE 2: Teleporta para dentro do carro
	print("?? Fase 2: Entrando no carro...")

	if not vehicleSeat then
		warn("? VehicleSeat não encontrado!")
		CutEvent:FireClient(player, "EndCutscene")
		return
	end

	-- Desabilita colisões do personagem temporariamente
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Posiciona o personagem no banco (sentado)
	local seatCFrame = vehicleSeat.CFrame * CFrame.new(0, 0.5, 0) -- Ligeiramente acima
	hrp.CFrame = seatCFrame
	hrp.Anchored = true -- Ancora temporariamente

	-- Animação de sentar
	CutEvent:FireClient(player, "SitAnimation")
	task.wait(0.5)

	-- Solda o personagem ao banco para seguir o movimento
	local weld = Instance.new("Weld")
	weld.Name = "CutsceneWeld"
	weld.Part0 = hrp
	weld.Part1 = vehicleSeat
	weld.C0 = CFrame.new(0, 0.5, 0) -- Offset para ficar sentado
	weld.Parent = hrp

	-- Desancora o HRP agora que está soldado
	hrp.Anchored = false

	print("? Personagem soldado ao carro")
	task.wait(0.5)

	-- FASE 3: Mover o carro automaticamente
	print("?? Fase 3: Carro em movimento...")
	CutEvent:FireClient(player, "CarMoving")

	-- Move o carro
	local carMovement = moveCarToDestination(carModel, DESTINO, CAR_SPEED)

	if carMovement then
		carMovement.Wait()
	end

	print("? Fase 4: Chegou ao destino!")
	task.wait(0.5)

	-- Remove a solda
	if weld and weld.Parent then
		weld:Destroy()
	end

	-- Reabilita colisões
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end

	-- Coloca o personagem no chão próximo ao destino
	local exitPosition = DESTINO.Position + Vector3.new(3, 3, 0) -- 3 studs ao lado
	hrp.CFrame = CFrame.new(exitPosition)

	task.wait(0.5)

	-- FASE 4: Restaura controles
	CutEvent:FireClient(player, "EndCutscene")

	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	humanoid.AutoRotate = true

	print("?? Cutscene finalizada para " .. player.Name)
	activeCutscenes[player] = nil
end

-- Quando jogador entra
Players.PlayerAdded:Connect(function(player)
	if activeCutscenes[player] then
		return
	end

	activeCutscenes[player] = true

	local character = player.Character or player.CharacterAdded:Wait()
	task.spawn(function()
		startCutscene(player, character)
	end)
end)

-- Quando jogador sai
Players.PlayerRemoving:Connect(function(player)
	activeCutscenes[player] = nil
end)

-- Para jogadores já no servidor
for _, player in ipairs(Players:GetPlayers()) do
	if not activeCutscenes[player] then
		activeCutscenes[player] = true
		local character = player.Character
		if character then
			task.spawn(function()
				startCutscene(player, character)
			end)
		end
	end
end