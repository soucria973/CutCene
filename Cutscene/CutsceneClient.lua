-- StarterPlayer > StarterPlayerScripts > CutsceneClient
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Services
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- RemoteEvents
local CutEvent = ReplicatedStorage:WaitForChild("CutsceneEvent")

-- Estados
local cutsceneActive = false
local character = nil
local hrp = nil

-- Função para bloquear TODOS os inputs durante a cutscene
local function blockAllInputs()
	ContextActionService:BindAction(
		"BlockAllMovement",
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		unpack(Enum.KeyCode:GetEnumItems())
	)

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Função para desbloquear inputs
local function unblockAllInputs()
	ContextActionService:UnbindAction("BlockAllMovement")
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Função para resetar estado
local function resetState()
	cutsceneActive = false

	-- Restaura câmera
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
	end

	-- Desbloqueia inputs
	unblockAllInputs()

	-- Remove renderizações customizadas
	RunService:UnbindFromRenderStep("CutsceneCam")
	RunService:UnbindFromRenderStep("CarCam")

	print("? Estado resetado (Cliente)")
end

-- Eventos de Cutscene
CutEvent.OnClientEvent:Connect(function(action)

	if action == "StartCutscene" then
		cutsceneActive = true
		character = player.Character or player.CharacterAdded:Wait()
		hrp = character:WaitForChild("HumanoidRootPart")

		-- BLOQUEIA TODOS OS INPUTS
		blockAllInputs()

		-- Muda câmera para modo scriptable
		camera.CameraType = Enum.CameraType.Scriptable

		-- Câmera seguindo o personagem durante a caminhada
		RunService:BindToRenderStep("CutsceneCam", Enum.RenderPriority.Camera.Value + 1, function()
			if not cutsceneActive or not hrp or not hrp.Parent then
				RunService:UnbindFromRenderStep("CutsceneCam")
				return
			end

			-- Câmera atrás do personagem (terceira pessoa)
			local cameraCFrame = hrp.CFrame * CFrame.new(0, 3, 8) -- Atrás e acima
			local lookAtPosition = hrp.Position + Vector3.new(0, 2, 0)

			camera.CFrame = CFrame.new(cameraCFrame.Position, lookAtPosition)
		end)

		print("?? Cutscene iniciada - Controles bloqueados")

	elseif action == "SitAnimation" then
		print("?? Animação de sentar")

	elseif action == "CarMoving" then
		print("?? Carro em movimento - Ajustando câmera")

		-- Remove câmera anterior
		RunService:UnbindFromRenderStep("CutsceneCam")

		-- Nova câmera para o carro em movimento (visão cinematográfica)
		RunService:BindToRenderStep("CarCam", Enum.RenderPriority.Camera.Value + 1, function()
			if not cutsceneActive or not hrp or not hrp.Parent then
				RunService:UnbindFromRenderStep("CarCam")
				return
			end

			-- OPÇÃO 1: Câmera atrás do carro (como jogo de corrida)
			local carForward = hrp.CFrame.LookVector
			local carRight = hrp.CFrame.RightVector

			-- Posição da câmera: atrás e acima do carro
			local cameraOffset = (carForward * -15) + (Vector3.new(0, 8, 0)) + (carRight * 0)
			local cameraPosition = hrp.Position + cameraOffset

			-- Olha para a frente do carro
			local lookAtPosition = hrp.Position + (carForward * 10) + Vector3.new(0, 1, 0)

			-- Suaviza a transição da câmera
			local currentCFrame = camera.CFrame
			local targetCFrame = CFrame.new(cameraPosition, lookAtPosition)
			camera.CFrame = currentCFrame:Lerp(targetCFrame, 0.1)

			-- OPÇÃO 2: Câmera lateral (descomente para testar)
			--[[
			local cameraOffset = (carRight * 12) + (Vector3.new(0, 5, 0)) + (carForward * -3)
			local cameraPosition = hrp.Position + cameraOffset
			local lookAtPosition = hrp.Position + Vector3.new(0, 1, 0)
			camera.CFrame = CFrame.new(cameraPosition, lookAtPosition)
			]]--

			-- OPÇÃO 3: Câmera frontal (visão do motorista - descomente para testar)
			--[[
			local cameraOffset = (carForward * 2) + (Vector3.new(0, 3, 0))
			local cameraPosition = hrp.Position + cameraOffset
			local lookAtPosition = hrp.Position + (carForward * 20) + Vector3.new(0, 0, 0)
			camera.CFrame = CFrame.new(cameraPosition, lookAtPosition)
			]]--
		end)

	elseif action == "EndCutscene" then
		resetState()
		print("? Cutscene finalizada - Controles liberados")
	end
end)

-- Detecta morte do personagem para resetar
player.CharacterAdded:Connect(function(newCharacter)
	local humanoid = newCharacter:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		if cutsceneActive then
			resetState()
			print("?? Personagem morreu durante cutscene")
		end
	end)
end)

-- Inicialização para personagem existente
if player.Character then
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if cutsceneActive then
				resetState()
			end
		end)
	end
end

-- Segurança extra: Bloqueia inputs durante cutscene
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if cutsceneActive then
		-- Silenciosamente ignora qualquer input
	end
end)