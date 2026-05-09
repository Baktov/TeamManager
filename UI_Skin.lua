-- TeamManager: UI_Skin — ElvUI skinning support

function TM.ApplyElvUISkin()
  if not ElvUI then return end
  local E = unpack(ElvUI)
  if not E or not E.private then return end
  local S = E:GetModule("Skins")
  if not S then return end
  local ui = TM.ui
  local frame = ui.frame
  if not frame then return end

  frame:StripTextures()
  frame:SetTemplate("Transparent")
  if frame.CloseButton then S:HandleCloseButton(frame.CloseButton) end

  if ui.listBG then
    ui.listBG:StripTextures()
    ui.listBG:SetTemplate("Transparent")
  end
  if ui.membersFrame then
    ui.membersFrame:StripTextures()
    ui.membersFrame:SetTemplate("Transparent")
  end
  if ui.optionsBG then
    ui.optionsBG:StripTextures()
    ui.optionsBG:SetTemplate("Transparent")
  end
  if ui.teamName    then S:HandleEditBox(ui.teamName) end
  if ui.memberInput then S:HandleEditBox(ui.memberInput) end
  if ui.prefixInput then S:HandleEditBox(ui.prefixInput) end

  local buttons = {
    ui.createBtn, ui.inviteBtn, ui.delBtn,
    ui.addBtn, ui.addMeBtn, ui.addTargetBtn,
    ui.addGroupBtn, ui.saveBtn,
  }
  for _, btn in ipairs(buttons) do if btn then S:HandleButton(btn) end end
  if ui.listButtons then for _, btn in ipairs(ui.listButtons) do S:HandleButton(btn) end end
  if ui.memberRows then
    for _, row in ipairs(ui.memberRows) do
      if row.promote then S:HandleButton(row.promote) end
      if row.del     then S:HandleButton(row.del)     end
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

  -- ScrollFrame liste équipes : strip + skin + scrollbar ElvUI
  if ui.listScroll then
    ui.listScroll:StripTextures()
    local sb = ui.listScroll.ScrollBar
    if sb then
      sb:StripTextures()
      if sb.ThumbTexture then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        sb.ThumbTexture:SetGradient("VERTICAL",
          CreateColor(0.6, 0.6, 0.6, 0.8),
          CreateColor(0.4, 0.4, 0.4, 0.8))
      end
      if sb.ScrollUpButton   then S:HandleNextPrevButton(sb.ScrollUpButton,   "up")   end
      if sb.ScrollDownButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  -- ScrollFrame membres : strip + skin + scrollbar ElvUI
  if ui.membersScroll then
    ui.membersScroll:StripTextures()
    local sb = ui.membersScroll.ScrollBar
    if sb then
      sb:StripTextures()
      if sb.ThumbTexture then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        sb.ThumbTexture:SetGradient("VERTICAL",
          CreateColor(0.6, 0.6, 0.6, 0.8),
          CreateColor(0.4, 0.4, 0.4, 0.8))
      end
      if sb.ScrollUpButton   then S:HandleNextPrevButton(sb.ScrollUpButton,   "up")   end
      if sb.ScrollDownButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  -- ScrollFrame des options : strip + skin + scrollbar ElvUI
  if ui.optionsScroll then
    ui.optionsScroll:StripTextures()
    local sb = ui.optionsScroll.ScrollBar
    if sb then
      sb:StripTextures()
      if sb.ThumbTexture then
        sb.ThumbTexture:SetTexture(E.media.blankTex)
        sb.ThumbTexture:SetGradient("VERTICAL",
          CreateColor(0.6, 0.6, 0.6, 0.8),
          CreateColor(0.4, 0.4, 0.4, 0.8))
      end
      if sb.ScrollUpButton  then S:HandleNextPrevButton(sb.ScrollUpButton,  "up")   end
      if sb.ScrollDownButton then S:HandleNextPrevButton(sb.ScrollDownButton, "down") end
    end
  end

  TM.DebugPrint("ElvUI skin appliqué à TeamManager")
end

function TM.ApplyElvUISkinMinimap(btn)
  if not ElvUI or not btn then return end
  local E = unpack(ElvUI)
  if not E or not E.private then return end
  local S = E:GetModule("Skins")
  if not S then return end
  btn:SetTemplate("Default")
  if btn.border then btn.border:Hide() end
  TM.DebugPrint("ElvUI skin appliqué au bouton minimap")
end

function TM.SkinFloatingLabel(frame)
  if not ElvUI then return end
  local E = unpack(ElvUI)
  if not E or not E.private then return end
  local S = E:GetModule("Skins")
  if not S then return end
  frame:StripTextures()
  frame:SetTemplate("Transparent")
  TM.DebugPrint("ElvUI skin appliqué au floating label")
end
