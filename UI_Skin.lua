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

    if ui.teamName then
      ui.teamName:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
      ui.teamName:SetBackdropColor(0.08, 0.08, 0.09, 1)
      ui.teamName:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    if ui.memberInput then
      ui.memberInput:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
      ui.memberInput:SetBackdropColor(0.08, 0.08, 0.09, 1)
      ui.memberInput:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    if ui.prefixInput then
      ui.prefixInput:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
      ui.prefixInput:SetBackdropColor(0.08, 0.08, 0.09, 1)
      ui.prefixInput:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    TM.DebugPrint("Fallback EllesmereUI skin appliqué à TeamManager")
    return
  end

  local ui = TM.ui
  local frame = ui and ui.frame
  if not frame then return end

  TM.ApplySkinTemplate(frame, "Transparent")
  if frame.CloseButton and S.HandleCloseButton then S:HandleCloseButton(frame.CloseButton) end

  if ui.listBG then TM.ApplySkinTemplate(ui.listBG, "Transparent") end
  if ui.membersFrame then TM.ApplySkinTemplate(ui.membersFrame, "Transparent") end
  if ui.optionsBG then TM.ApplySkinTemplate(ui.optionsBG, "Transparent") end
  if ui.teamName    and S.HandleEditBox then S:HandleEditBox(ui.teamName) end
  if ui.memberInput and S.HandleEditBox then S:HandleEditBox(ui.memberInput) end
  if ui.prefixInput and S.HandleEditBox then S:HandleEditBox(ui.prefixInput) end

  local buttons = {
    ui.createBtn, ui.inviteBtn, ui.delBtn,
    ui.addBtn, ui.addMeBtn, ui.addTargetBtn,
    ui.addGroupBtn, ui.saveBtn,
  }
  for _, btn in ipairs(buttons) do if btn and S.HandleButton then S:HandleButton(btn) end end
  if ui.listButtons then for _, btn in ipairs(ui.listButtons) do if S.HandleButton then S:HandleButton(btn) end end end
  if ui.memberRows then
    for _, row in ipairs(ui.memberRows) do
      if row.promote and S.HandleButton then S:HandleButton(row.promote) end
      if row.del and S.HandleButton then S:HandleButton(row.del) end
    end
  end
  if ui.debugToggle then S:HandleCheckBox(ui.debugToggle) end
  if ui.stateToggle then S:HandleCheckBox(ui.stateToggle) end
  if ui.questToggle then S:HandleCheckBox(ui.questToggle) end
  if ui.validateQuestToggle then S:HandleCheckBox(ui.validateQuestToggle) end
  if ui.gossipToggle then S:HandleCheckBox(ui.gossipToggle) end
  if ui.cinematicToggle then S:HandleCheckBox(ui.cinematicToggle) end
  if ui.taxiToggle then S:HandleCheckBox(ui.taxiToggle) end
  if ui.instanceToggle then S:HandleCheckBox(ui.instanceToggle) end
  if ui.dungeonToggle then S:HandleCheckBox(ui.dungeonToggle) end
  if ui.followAlertToggle then S:HandleCheckBox(ui.followAlertToggle) end
  if ui.autoMountToggle then S:HandleCheckBox(ui.autoMountToggle) end
  if ui.hearthToggle then S:HandleCheckBox(ui.hearthToggle) end

  -- ScrollFrame liste équipes : strip + skin + scrollbar
  if ui.listScroll then
    if ui.listScroll.StripTextures then ui.listScroll:StripTextures() end
    local sb = ui.listScroll.ScrollBar
    if sb then
      if sb.StripTextures then sb:StripTextures() end
      if sb.ThumbTexture and E.media and E.media.blankTex then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        if sb.ThumbTexture.SetGradient then
          sb.ThumbTexture:SetGradient("VERTICAL",
            CreateColor(0.6, 0.6, 0.6, 0.8),
            CreateColor(0.4, 0.4, 0.4, 0.8))
        end
      end
      if sb.ScrollUpButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollUpButton, "up") end
      if sb.ScrollDownButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  -- ScrollFrame membres : strip + skin + scrollbar
  if ui.membersScroll then
    if ui.membersScroll.StripTextures then ui.membersScroll:StripTextures() end
    local sb = ui.membersScroll.ScrollBar
    if sb then
      if sb.StripTextures then sb:StripTextures() end
      if sb.ThumbTexture and E.media and E.media.blankTex then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        if sb.ThumbTexture.SetGradient then
          sb.ThumbTexture:SetGradient("VERTICAL",
            CreateColor(0.6, 0.6, 0.6, 0.8),
            CreateColor(0.4, 0.4, 0.4, 0.8))
        end
      end
      if sb.ScrollUpButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollUpButton, "up") end
      if sb.ScrollDownButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  -- ScrollFrame des options : strip + skin + scrollbar
  if ui.optionsScroll then
    if ui.optionsScroll.StripTextures then ui.optionsScroll:StripTextures() end
    local sb = ui.optionsScroll.ScrollBar
    if sb then
      if sb.StripTextures then sb:StripTextures() end
      if sb.ThumbTexture and E.media and E.media.blankTex then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        if sb.ThumbTexture.SetGradient then
          sb.ThumbTexture:SetGradient("VERTICAL",
            CreateColor(0.6, 0.6, 0.6, 0.8),
            CreateColor(0.4, 0.4, 0.4, 0.8))
        end
      end
      if sb.ScrollUpButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollUpButton, "up") end
      if sb.ScrollDownButton and S.HandleNextPrevButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  TM.DebugPrint((skinName or "UI") .. " skin appliqué à TeamManager")
end

TM.ApplyElvUISkinMinimap = function(btn)
  local E, S, skinName = TM.GetSkinningAPI()
  if not E or not S or not btn then return end
  if btn.SetTemplate then btn:SetTemplate("Default") end
  if btn.border then btn.border:Hide() end
  TM.DebugPrint((skinName or "UI") .. " skin appliqué au bouton minimap")
end

TM.SkinFloatingLabel = function(frame)
  local E, S, skinName = TM.GetSkinningAPI()
  if not E or not S or not frame then return end
  if frame.StripTextures then frame:StripTextures() end
  if frame.SetTemplate then frame:SetTemplate("Transparent") end
  TM.DebugPrint((skinName or "UI") .. " skin appliqué au floating label")
end
