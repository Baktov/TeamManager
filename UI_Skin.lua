-- TeamManager: UI_Skin — ElvUI/EllesmereUI skinning support

TM.GetSkinningAPI = function()
  if _G.ElvUI then
    local E = unpack(_G.ElvUI)
    if E and E.GetModule then
      local S = E:GetModule("Skins")
      if S then return E, S, "ElvUI" end
    end
  end

  local candidates = {
    _G.EllesmereUI,
    _G.Ellesmere,
    _G.ElvUI_Ellesmere,
  }

  for _, addon in ipairs(candidates) do
    if addon then
      local E
      if type(addon) == "table" then
        if addon[1] then
          E = addon[1]
        elseif addon.GetModule then
          E = addon
        end
      end

      if E and E.GetModule then
        local S = E:GetModule("Skins")
        if S then return E, S, "EllesmereUI" end
      end
    end
  end

  return nil, nil, nil
end

TM.ApplySkinTemplate = function(frame, template)
  if not frame then return end
  if frame.StripTextures then frame:StripTextures() end

  local regions = { frame:GetRegions() }
  for _, region in ipairs(regions) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end

  -- Hide common Blizzard template pieces that StripTextures does not always remove.
  if frame.NineSlice and frame.NineSlice.Hide then frame.NineSlice:Hide() end
  if frame.Bg and frame.Bg.Hide then frame.Bg:Hide() end
  if frame.Inset and frame.Inset.Hide then frame.Inset:Hide() end

  if frame.SetTemplate then
    frame:SetTemplate(template)
    return
  end

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.07, 0.82)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    return
  end

  if not frame._tmBackdrop then
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local level = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
    bg:SetFrameLevel(math.max(0, level - 1))
    frame._tmBackdrop = bg
  end

  local bg = frame._tmBackdrop
  if bg and bg.SetBackdrop then
    bg:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.06, 0.06, 0.07, 0.82)
    bg:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
  end
end

local function HandleButton(S, button)
  if not button then return end
  if S and S.HandleButton then
    S:HandleButton(button)
  else
    TM.ApplyFallbackButtonStyle(button)
  end
end

local function HandleEditBox(S, editBox)
  if not editBox then return end
  local handledBySkin = false
  if S and S.HandleEditBox then
    S:HandleEditBox(editBox)
    handledBySkin = true
  end

  if handledBySkin then
    if editBox.backdrop or editBox.Backdrop or editBox.backdropTexture then
      return
    end
  end

  local regions = { editBox:GetRegions() }
  for _, region in ipairs(regions) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end

  if not editBox._tmBackdrop then
    local bg = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, 0)
    bg:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, 0)
    local level = (editBox.GetFrameLevel and editBox:GetFrameLevel()) or 1
    bg:SetFrameLevel(math.max(0, level - 1))
    editBox._tmBackdrop = bg
  end

  local target = editBox.SetBackdrop and editBox or editBox._tmBackdrop
  if target and target.SetBackdrop then
    target:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    target:SetBackdropColor(0.08, 0.08, 0.09, 1)
    target:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  end
end

local function HandleDragHandle(S, dragHandle)
  if not dragHandle then return end
  HandleButton(S, dragHandle)

  if dragHandle.SetBackdrop then
    dragHandle:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    dragHandle:SetBackdropColor(0.1, 0.1, 0.11, 0.95)
    dragHandle:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
  end
  if dragHandle.icon then
    dragHandle.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local function HandleCheckBox(S, checkBox)
  if not checkBox then return end
  if S and S.HandleCheckBox then
    S:HandleCheckBox(checkBox)
  end
end

local function HandleCloseButton(S, closeButton)
  if not closeButton then return end
  if S and S.HandleCloseButton then
    S:HandleCloseButton(closeButton)
    return
  end

  if closeButton.SetNormalTexture then closeButton:SetNormalTexture(nil) end
  if closeButton.SetPushedTexture then closeButton:SetPushedTexture(nil) end
  if closeButton.SetHighlightTexture then closeButton:SetHighlightTexture(nil) end
  TM.ApplyFallbackButtonStyle(closeButton)

  if not closeButton._tmCloseText then
    local fs = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText("x")
    closeButton._tmCloseText = fs
  end
end

local function HandleNextPrevButton(S, button, direction)
  if not button then return end
  if S and S.HandleNextPrevButton then
    S:HandleNextPrevButton(button, direction)
  else
    TM.ApplyFallbackButtonStyle(button)
  end
end

local function SkinScrollBar(E, S, scrollFrame)
  if not scrollFrame then return end
  if scrollFrame.StripTextures then scrollFrame:StripTextures() end

  local sb = scrollFrame.ScrollBar
  if not sb then return end
  if sb.StripTextures then sb:StripTextures() end

  local sbRegions = { sb:GetRegions() }
  for _, region in ipairs(sbRegions) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end

  if sb.SetBackdrop then
    sb:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    sb:SetBackdropColor(0.08, 0.08, 0.09, 0.9)
    sb:SetBackdropBorderColor(0.28, 0.28, 0.3, 0.9)
  end

  if sb.ThumbTexture then
    local thumbTex = (E and E.media and E.media.blankTex) or "Interface\\Buttons\\WHITE8x8"
    sb.ThumbTexture:SetTexture(thumbTex)
    if sb.ThumbTexture.SetVertexColor then sb.ThumbTexture:SetVertexColor(0.62, 0.62, 0.62, 0.85) end
    if sb.ThumbTexture.SetGradient and CreateColor then
      sb.ThumbTexture:SetGradient("VERTICAL",
        CreateColor(0.6, 0.6, 0.6, 0.8),
        CreateColor(0.4, 0.4, 0.4, 0.8))
    end
  end

  HandleNextPrevButton(S, sb.ScrollUpButton, "up")
  HandleNextPrevButton(S, sb.ScrollDownButton, "down")
  if sb.ScrollUpButton then
    if sb.ScrollUpButton.SetSize then sb.ScrollUpButton:SetSize(16, 16) end
    local upRegions = { sb.ScrollUpButton:GetRegions() }
    for _, region in ipairs(upRegions) do
      if region and region.GetObjectType and region:GetObjectType() == "Texture" then
        region:SetTexture(nil)
        region:SetAlpha(0)
        region:Hide()
      end
    end
  end
  if sb.ScrollDownButton then
    if sb.ScrollDownButton.SetSize then sb.ScrollDownButton:SetSize(16, 16) end
    local downRegions = { sb.ScrollDownButton:GetRegions() }
    for _, region in ipairs(downRegions) do
      if region and region.GetObjectType and region:GetObjectType() == "Texture" then
        region:SetTexture(nil)
        region:SetAlpha(0)
        region:Hide()
      end
    end
  end
end

TM.ApplyFallbackButtonStyle = function(button)
  if not button then return end
  if button.SetNormalTexture and not button._tmFallbackStyled then
    button:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    button:GetNormalTexture():SetVertexColor(0.18, 0.2, 0.22, 1)
    button:GetHighlightTexture():SetVertexColor(0.26, 0.36, 0.5, 0.75)
    button:GetPushedTexture():SetVertexColor(0.12, 0.16, 0.2, 1)
    button._tmFallbackStyled = true
  end
  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.14, 0.14, 0.15, 1)
    button:SetBackdropBorderColor(0.52, 0.52, 0.52, 0.9)
  end
end

TM.ApplyElvUISkin = function()
  local E, S, skinName = TM.GetSkinningAPI()
  if not E or not S then
    local ui = TM.ui
    local frame = ui and ui.frame
    if not frame then return end

    TM.ApplySkinTemplate(frame, "Transparent")
    if ui.listBG then TM.ApplySkinTemplate(ui.listBG, "Transparent") end
    if ui.membersFrame then TM.ApplySkinTemplate(ui.membersFrame, "Transparent") end
    if ui.optionsBG then TM.ApplySkinTemplate(ui.optionsBG, "Transparent") end

    local buttons = {
      ui.createBtn, ui.inviteBtn, ui.delBtn,
      ui.addBtn, ui.addMeBtn, ui.addTargetBtn,
      ui.addGroupBtn, ui.saveBtn,
    }
    for _, btn in ipairs(buttons) do TM.ApplyFallbackButtonStyle(btn) end
    if ui.listButtons then for _, btn in ipairs(ui.listButtons) do TM.ApplyFallbackButtonStyle(btn) end end
    if ui.memberRows then
      for _, row in ipairs(ui.memberRows) do
        if row.promote then TM.ApplyFallbackButtonStyle(row.promote) end
        if row.del then TM.ApplyFallbackButtonStyle(row.del) end
      end
    end

    HandleEditBox(nil, ui.teamName)
    HandleEditBox(nil, ui.memberInput)
    HandleEditBox(nil, ui.prefixInput)
    HandleDragHandle(nil, ui.dragHandle)
    TM.ApplyFallbackButtonStyle(ui.resizeBtn)

    TM.DebugPrint("Fallback EllesmereUI skin appliqué à TeamManager")
    return
  end

  local ui = TM.ui
  local frame = ui and ui.frame
  if not frame then return end

  TM.ApplySkinTemplate(frame, "Transparent")
  HandleCloseButton(S, frame.CloseButton)

  if ui.listBG then TM.ApplySkinTemplate(ui.listBG, "Transparent") end
  if ui.membersFrame then TM.ApplySkinTemplate(ui.membersFrame, "Transparent") end
  if ui.optionsBG then TM.ApplySkinTemplate(ui.optionsBG, "Transparent") end
  HandleEditBox(S, ui.teamName)
  HandleEditBox(S, ui.memberInput)
  HandleEditBox(S, ui.prefixInput)

  local buttons = {
    ui.createBtn, ui.inviteBtn, ui.delBtn,
    ui.addBtn, ui.addMeBtn, ui.addTargetBtn,
    ui.addGroupBtn, ui.saveBtn,
  }
  for _, btn in ipairs(buttons) do HandleButton(S, btn) end
  if ui.listButtons then for _, btn in ipairs(ui.listButtons) do HandleButton(S, btn) end end
  if ui.memberRows then
    for _, row in ipairs(ui.memberRows) do
      HandleButton(S, row.promote)
      HandleButton(S, row.del)
    end
  end
  HandleCheckBox(S, ui.debugToggle)
  HandleCheckBox(S, ui.stateToggle)
  HandleCheckBox(S, ui.questToggle)
  HandleCheckBox(S, ui.validateQuestToggle)
  HandleCheckBox(S, ui.gossipToggle)
  HandleCheckBox(S, ui.cinematicToggle)
  HandleCheckBox(S, ui.taxiToggle)
  HandleCheckBox(S, ui.instanceToggle)
  HandleCheckBox(S, ui.dungeonToggle)
  HandleCheckBox(S, ui.followAlertToggle)
  HandleCheckBox(S, ui.autoMountToggle)
  HandleCheckBox(S, ui.hearthToggle)
  HandleDragHandle(S, ui.dragHandle)
  HandleButton(S, ui.resizeBtn)

  SkinScrollBar(E, S, ui.listScroll)
  SkinScrollBar(E, S, ui.membersScroll)
  SkinScrollBar(E, S, ui.optionsScroll)

  TM.DebugPrint((skinName or "UI") .. " skin appliqué à TeamManager")
end

TM.ApplyElvUISkinInviteDialog = function(dialog)
  local E, S, skinName = TM.GetSkinningAPI()
  if not dialog then return end

  TM.ApplySkinTemplate(dialog, "Transparent")
  HandleEditBox(S, dialog.prefixEdit)
  HandleButton(S, dialog.confirmBtn)
  HandleButton(S, dialog.cancelBtn)

  if dialog.CloseButton and S and S.HandleCloseButton then
    S:HandleCloseButton(dialog.CloseButton)
  end

  TM.DebugPrint((skinName or "UI") .. " skin appliqué au dialogue d'invitation")
end

TM.ApplyElvUISkinMinimap = function(btn)
  local E, S, skinName = TM.GetSkinningAPI()
  if not E or not S or not btn then return end
  if btn.SetTemplate then btn:SetTemplate("Default") end
  if btn.border then btn.border:Hide() end
  TM.DebugPrint((skinName or "UI") .. " skin appliqué au bouton minimap")
end

TM.SkinFloatingLabel = function(frame)
  local _, _, skinName = TM.GetSkinningAPI()
  if not frame then return end
  TM.ApplySkinTemplate(frame, "Transparent")
  TM.DebugPrint((skinName or "UI") .. " skin appliqué au floating label")
end
