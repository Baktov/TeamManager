-- TeamManager: UI_Minimap — minimap button creation and positioning

function TM.UpdateMinimapButtonPos(button)
  local angle  = ((TM.db and TM.db.minimap and TM.db.minimap.angle) or 45) % 360
  local rad    = math.rad(angle)
  local radius = 80
  button:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(rad), radius * math.sin(rad))
end

function TM.CreateMinimapButton()
  if TeamManagerMinimapButton then return end
  if not TM.db.minimap then TM.db.minimap = { angle = 45 } end

  local btn = CreateFrame("Button", "TeamManagerMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")

  btn.border = btn:CreateTexture(nil, "BORDER")
  btn.border:SetPoint("TOPLEFT",     -1,  1)
  btn.border:SetPoint("BOTTOMRIGHT",  1, -1)
  btn.border:SetTexture("Interface\\Buttons\\WHITE8X8")
  btn.border:SetVertexColor(0, 0, 0, 0.6)

  btn:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  local ht = btn:GetHighlightTexture()
  if ht then ht:SetVertexColor(1, 1, 1, 0.15) end

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetAllPoints()
  btn.icon:SetTexture("Interface\\AddOns\\TeamManager\\team_icon.tga")

  btn:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" or button == "LeftButton" then TM.ToggleUI() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("TeamManager")
    GameTooltip:AddLine("Clic: Ouvrir l'addon", 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)
  btn:SetScript("OnDragStart", function(self) end)
  btn:SetScript("OnDragStop", function(self)
    local scale = Minimap:GetEffectiveScale()
    local x, y  = GetCursorPosition()
    x = x / scale; y = y / scale
    local cx, cy = Minimap:GetCenter()
    TM.db.minimap.angle = math.deg(math.atan2(y - cy, x - cx))
    TM.UpdateMinimapButtonPos(self)
  end)

  TM.UpdateMinimapButtonPos(btn)
  TM.ApplyElvUISkinMinimap(btn)
end
