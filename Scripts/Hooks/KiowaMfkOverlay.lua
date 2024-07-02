-- Kiowa MFK Overlay

--[[ KiowaMfkOverlay:
    This project adds an onscreen ingame GUI with which you
    can use the Kiowa Multifunction Keyboard on a 2D GUI.
    Great for VR users.
--]]

--[[ Future Feature Goals:
    - Text field for pressed buttons, like a calculator
--]]

--[[ Bugs:
--]]

--[[ Change Notes:
    v0.1
    - Initial Release
    v0.2
    - Left click "Kiowa MFK Overlay" to toggle app size
    - Right click "Kiowa MFK Overlay" to hide app
    - User toggle hotkey will be displayed at the top of the app, even if customized
    - Enabled Config Settings
    -- hideToggleHotkey: edit this to change the toggle hotkey
    -- hideOnLaunch: toggle to hide the app on launch of DCS or not
    -- appSize: 0 is default mode, 1 is mode with only numpad and logo
    -- buttonPressTime: time in ms that the buttons are pressed by the program
--]]

local function loadKiowaMfkOverlay()
    package.path = package.path .. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

    local lfs = require("lfs")
    local U = require("me_utilities")
    local Skin = require("Skin")
    local DialogLoader = require("DialogLoader")
    local Tools = require("tools")
    --local sound = require("sound")

    -- KiowaMfkOverlay resources
    local window = nil
    local windowDefaultSkin = nil
    local windowSkinHidden = Skin.windowSkinChatMin()
    local panel = nil
    local logFile = io.open(lfs.writedir() .. [[Logs\KiowaMfkOverlay.log]], "w")
    local config = nil

    -- State
    local isHidden = true
    local mfkButton
    local isPressed = false
    local pleasePressMFK = false
    local whenToDepress = nil
    local SkinUtils = require("SkinUtils")

    -- Resizing
    local buttonHeight = 25
    local buttonWidth = 50

    local columnSpacing = buttonWidth + 5

    local rowSpacing = buttonHeight * 0.8
    local row1 = 0
    local row2 = rowSpacing + row1

    local function log(str)
        if not str then
            return
        end

        if logFile then
            logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
            logFile:flush()
        end
    end

    local function dump(o) -- for debug
        if type(o) == 'table' then
            local s = '{ '
            for k, v in pairs(o) do
                if type(k) ~= 'number' then k = '"' .. k .. '"' end
                s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end

    local function saveConfiguration()
        U.saveInFile(config, "config", lfs.writedir() .. "Config/KiowaMfkOverlay/KiowaMfkOverlayConfig.lua")
    end

    local function loadConfiguration()
        log("Loading config file...")
        lfs.mkdir(lfs.writedir() .. [[Config\KiowaMfkOverlay\]])
        local tbl = Tools.safeDoFile(lfs.writedir() .. "Config/KiowaMfkOverlay/KiowaMfkOverlayConfig.lua", false)
        if (tbl and tbl.config) then
            log("Configuration exists...")
            config = tbl.config

            -- move content into text file
            if config.content ~= nil then
                config.content = nil
                saveConfiguration()
            end
        else
            log("Configuration not found, creating defaults...")
            config = {
                hideToggleHotkey = "Ctrl+Shift+F11",   -- show/hide
                windowPosition   = { x = 50, y = 50 }, -- default values should be on screen for any resolution
                windowSize       = { w = 458, h = 491 },
                hideOnLaunch     = false,              -- user editable
                buttonPressTime  = 100,                -- time in ms that the buttons are pressed by the program. user editable.
                appSize          = 0,                  -- 0 is default mode, 1 is mode with only numpad and logo
            }
            saveConfiguration()
        end
    end

    local function setVisible(b)
        window:setVisible(b)
    end

    -- button resize is dsiabled due to early development complexity
    local function handleResize(self)
        local w, h = self:getSize()

        panel:setBounds(0, 0, w, h - 20) -- TODO what is this -20 used for?

        -- resize for Walkman
        -- can be adjusted for KiowaMfkOverlay
        -- (xpos, ypos, width, height)
        --HeadingSlider:setBounds(0, row2, w, 25)
        --[[
        local numberOfButtons = 5
        local buttonSpacing = w / numberOfButtons * 0.02

        WalkmanStopButton:setBounds(w * (0 / numberOfButtons) + buttonSpacing / 2,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanPrevButton:setBounds(w * (1 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanPlayButton:setBounds(w * (2 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanNextButton:setBounds(w * (3 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanFolderButton:setBounds(w * (4 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
--]]

        -- determine the bounds of the minimum and maximum window width and height
        local minHeight = 295
        local minWidth  = 270
        local maxHeight = 491
        local maxWidth  = 458
        if h < minHeight then h = minHeight end
        if w < minWidth then w = minWidth end
        if h > maxHeight then h = maxHeight end
        if w > maxWidth then w = maxWidth end

        config.windowSize = { w = w, h = h }
        saveConfiguration()
    end

    local function handleMove(self)
        local x, y = self:getPosition()
        config.windowPosition = { x = x, y = y }
        saveConfiguration()
    end



    local function hide()
        window:setSkin(windowSkinHidden)
        panel:setVisible(false)
        window:setHasCursor(false)
        -- window.setVisible(false) -- if you make the window invisible, its destroyed
        isHidden = true
    end

    local function createKiowaMfkOverlayWindow()
        if window ~= nil then
            return
        end

        window               = DialogLoader.spawnDialogFromFile(
            lfs.writedir() .. "Scripts\\KiowaMfkOverlay\\KiowaMfkOverlay.dlg",
            cdata
        )
        --load background from the location of the users saved games
        local bgSkin         = window.Box.pictureWidget:getSkin()
        local mfkPicturePath = lfs.writedir() .. "Scripts\\KiowaMfkOverlay\\MFK75p.png"
        -- bgSkin.skinData.states.released[1].picture.file --couldnt i just define it here via hard code?
        window.Box.pictureWidget:setSkin(SkinUtils.setStaticPicture(mfkPicturePath, bgSkin))

        windowDefaultSkin = window:getSkin()
        panel             = window.Box
        -- MFK testing
        StaticImage       = panel.pictureWidget
        LogoButton        = panel.logoButton
        Num1Button        = panel.c1r1Button
        Num4Button        = panel.c1r2Button
        Num7Button        = panel.c1r3Button
        NumClrButton      = panel.c1r4Button

        -- c2
        Num2Button        = panel.c2r1Button
        Num5Button        = panel.c2r2Button
        Num8Button        = panel.c2r3Button
        Num0Button        = panel.c2r4Button

        -- c3
        Num3Button        = panel.c3r1Button
        Num6Button        = panel.c3r2Button
        Num9Button        = panel.c3r3Button
        NumDecimalButton  = panel.c3r4Button

        -- c4
        NumIffButton      = panel.c4r1Button
        NumTuneButton     = panel.c4r2Button
        NumScanButton     = panel.c4r3Button
        NumSpaceButton    = panel.c4r4Button

        NumDashButton     = panel.c1r5Button
        NumEnterButton    = panel.c2r5Button
        NumIdntButton     = panel.c4r5Button

        AButton           = panel.alphaC1R1Button
        BButton           = panel.alphaC2R1Button
        CButton           = panel.alphaC3R1Button
        DButton           = panel.alphaC4R1Button
        EButton           = panel.alphaC5R1Button
        FButton           = panel.alphaC6R1Button
        GButton           = panel.alphaC7R1Button
        HButton           = panel.alphaC1R2Button
        IButton           = panel.alphaC2R2Button
        JButton           = panel.alphaC3R2Button
        KButton           = panel.alphaC4R2Button
        LButton           = panel.alphaC5R2Button
        MButton           = panel.alphaC6R2Button
        NButton           = panel.alphaC7R2Button
        OButton           = panel.alphaC1R3Button
        PButton           = panel.alphaC2R3Button
        QButton           = panel.alphaC3R3Button
        RButton           = panel.alphaC4R3Button
        SButton           = panel.alphaC5R3Button
        TButton           = panel.alphaC6R3Button
        UButton           = panel.alphaC7R3Button
        LeftButton        = panel.alphaC1R4Button
        VButton           = panel.alphaC2R4Button
        WButton           = panel.alphaC3R4Button
        XButton           = panel.alphaC4R4Button
        YButton           = panel.alphaC5R4Button
        ZButton           = panel.alphaC6R4Button
        RightButton       = panel.alphaC7R4Button

        -- Skins
        GreenButtonSkin   = Num1Button:getSkin()
        GrayButtonSkin    = Num4Button:getSkin()

        -- setup window
        window:setBounds(
            config.windowPosition.x,
            config.windowPosition.y,
            config.windowSize.w,
            config.windowSize.h
        )
        window:setVisible(true)
        handleResize(window)
        handleMove(window)

        local function show() -- duplicated
            if window == nil then
                local status, err = pcall(createKiowaMfkOverlayWindow)
                if not status then
                    net.log("[KiowaMfkOverlay] Error creating window: " .. tostring(err))
                end
            end

            window:setVisible(true)
            window:setSkin(windowDefaultSkin)
            panel:setVisible(true)
            window:setHasCursor(true)
            window:setText(' Kiowa MFK Overlay by Bailey (' .. config.hideToggleHotkey .. ')')

            isHidden = false
        end

        window:addHotKeyCallback(
            config.hideToggleHotkey,
            function()
                if isHidden == true then
                    show()
                else
                    hide()
                end
            end
        )

        window:addSizeCallback(handleResize)
        window:addPositionCallback(handleMove)
        window:setVisible(true)

        LogoButton:addMouseDownCallback(
            function(self, x, y, button)
                if button == 1 then -- resize toggle
                    if config.appSize == 1 then
                        local w           = 458
                        local h           = 491

                        config.windowSize = { w = w, h = h }

                        window:setBounds(
                            config.windowPosition.x,
                            config.windowPosition.y,
                            config.windowSize.w,
                            config.windowSize.h
                        )
                        config.appSize = 0
                        saveConfiguration()
                    else -- appSize is 0
                        local w           = 458
                        local h           = 295
                        config.windowSize = { w = w, h = h }
                        window:setBounds(
                            config.windowPosition.x,
                            config.windowPosition.y,
                            config.windowSize.w,
                            config.windowSize.h
                        )
                        config.appSize = 1
                        saveConfiguration()
                    end
                elseif button == 3 then -- hide
                    hide()
                end
            end
        )
        -- mfkButtons are from clickabledata.lua

        LeftButton:addMouseDownCallback(
            function(self)
                mfkButton = 51
                pleasePressMFK = true
            end
        )

        RightButton:addMouseDownCallback(
            function(self)
                mfkButton = 52
                pleasePressMFK = true
            end
        )

        AButton:addMouseDownCallback(
            function(self)
                mfkButton = 25
                pleasePressMFK = true
            end
        )

        BButton:addMouseDownCallback(
            function(self)
                mfkButton = 26
                pleasePressMFK = true
            end
        )

        CButton:addMouseDownCallback(
            function(self)
                mfkButton = 27
                pleasePressMFK = true
            end
        )

        DButton:addMouseDownCallback(
            function(self)
                mfkButton = 28
                pleasePressMFK = true
            end
        )

        EButton:addMouseDownCallback(
            function(self)
                mfkButton = 29
                pleasePressMFK = true
            end
        )

        FButton:addMouseDownCallback(
            function(self)
                mfkButton = 30
                pleasePressMFK = true
            end
        )

        GButton:addMouseDownCallback(
            function(self)
                mfkButton = 31
                pleasePressMFK = true
            end
        )

        HButton:addMouseDownCallback(
            function(self)
                mfkButton = 32
                pleasePressMFK = true
            end
        )

        IButton:addMouseDownCallback(
            function(self)
                mfkButton = 33
                pleasePressMFK = true
            end
        )
        JButton:addMouseDownCallback(
            function(self)
                mfkButton = 34
                pleasePressMFK = true
            end
        )
        KButton:addMouseDownCallback(
            function(self)
                mfkButton = 35
                pleasePressMFK = true
            end
        )
        LButton:addMouseDownCallback(
            function(self)
                mfkButton = 36
                pleasePressMFK = true
            end
        )
        MButton:addMouseDownCallback(
            function(self)
                mfkButton = 37
                pleasePressMFK = true
            end
        )
        NButton:addMouseDownCallback(
            function(self)
                mfkButton = 38
                pleasePressMFK = true
            end
        )
        OButton:addMouseDownCallback(
            function(self)
                mfkButton = 39
                pleasePressMFK = true
            end
        )
        PButton:addMouseDownCallback(
            function(self)
                mfkButton = 40
                pleasePressMFK = true
            end
        )
        QButton:addMouseDownCallback(
            function(self)
                mfkButton = 41
                pleasePressMFK = true
            end
        )
        RButton:addMouseDownCallback(
            function(self)
                mfkButton = 42
                pleasePressMFK = true
            end
        )
        SButton:addMouseDownCallback(
            function(self)
                mfkButton = 43
                pleasePressMFK = true
            end
        )
        TButton:addMouseDownCallback(
            function(self)
                mfkButton = 44
                pleasePressMFK = true
            end
        )
        UButton:addMouseDownCallback(
            function(self)
                mfkButton = 45
                pleasePressMFK = true
            end
        )
        VButton:addMouseDownCallback(
            function(self)
                mfkButton = 46
                pleasePressMFK = true
            end
        )
        WButton:addMouseDownCallback(
            function(self)
                mfkButton = 47
                pleasePressMFK = true
            end
        )
        XButton:addMouseDownCallback(
            function(self)
                mfkButton = 48
                pleasePressMFK = true
            end
        )
        YButton:addMouseDownCallback(
            function(self)
                mfkButton = 49
                pleasePressMFK = true
            end
        )
        ZButton:addMouseDownCallback(
            function(self)
                mfkButton = 50
                pleasePressMFK = true
            end
        )

        Num1Button:addMouseDownCallback(
            function(self)
                mfkButton = 6
                pleasePressMFK = true
            end
        )
        Num2Button:addMouseDownCallback(
            function(self)
                mfkButton = 7
                pleasePressMFK = true
            end
        )
        Num3Button:addMouseDownCallback(
            function(self)
                mfkButton = 8
                pleasePressMFK = true
            end
        )
        Num4Button:addMouseDownCallback(
            function(self)
                mfkButton = 9
                pleasePressMFK = true
            end
        )
        Num5Button:addMouseDownCallback(
            function(self)
                mfkButton = 10
                pleasePressMFK = true
            end
        )
        Num6Button:addMouseDownCallback(
            function(self)
                mfkButton = 11
                pleasePressMFK = true
            end
        )
        Num7Button:addMouseDownCallback(
            function(self)
                mfkButton = 12
                pleasePressMFK = true
            end
        )
        Num8Button:addMouseDownCallback(
            function(self)
                mfkButton = 13
                pleasePressMFK = true
            end
        )
        Num9Button:addMouseDownCallback(
            function(self)
                mfkButton = 14
                pleasePressMFK = true
            end
        )
        Num0Button:addMouseDownCallback(
            function(self)
                mfkButton = 15
                pleasePressMFK = true
            end
        )

        NumDashButton:addMouseDownCallback(
            function(self)
                mfkButton = 24
                pleasePressMFK = true
            end
        )
        NumEnterButton:addMouseDownCallback(
            function(self)
                mfkButton = 23
                pleasePressMFK = true
            end
        )
        NumIdntButton:addMouseDownCallback(
            function(self)
                mfkButton = 22
                pleasePressMFK = true
            end
        )
        NumIffButton:addMouseDownCallback(
            function(self)
                mfkButton = 18
                pleasePressMFK = true
            end
        )
        NumTuneButton:addMouseDownCallback(
            function(self)
                mfkButton = 19
                pleasePressMFK = true
            end
        )
        NumScanButton:addMouseDownCallback(
            function(self)
                mfkButton = 20
                pleasePressMFK = true
            end
        )
        NumSpaceButton:addMouseDownCallback(
            function(self)
                mfkButton = 21
                pleasePressMFK = true
            end
        )
        NumClrButton:addMouseDownCallback(
            function(self)
                mfkButton = 17
                pleasePressMFK = true
            end
        )
        NumDecimalButton:addMouseDownCallback(
            function(self)
                mfkButton = 16
                pleasePressMFK = true
            end
        )



        --[[
--Example
        window:addHotKeyCallback(
            config.hotkeyVolUp,
            function()
                local newVolume = HeadingSlider:getValue() + 10
                if newVolume > 100 then newVolume = 100 end
                HeadingSlider:setValue(newVolume)
                setEffectsVolume(newVolume)
            end
        )
--]]

        if config.hideOnLaunch then
            hide()
            isHidden = true
        end

        window:setText(' Kiowa MFK Overlay by Bailey (' .. config.hideToggleHotkey .. ')')

        lfs.mkdir(lfs.writedir() .. [[Config\KiowaMfkOverlay\]])
        log("KiowaMfkOverlay window created")
    end

    local function show()
        if window == nil then
            local status, err = pcall(createKiowaMfkOverlayWindow)
            if not status then
                net.log("[KiowaMfkOverlay] Error creating window: " .. tostring(err))
            end
        end

        window:setVisible(true)
        window:setSkin(windowDefaultSkin)
        panel:setVisible(true)
        window:setHasCursor(true)
        window:setText(' Kiowa MFK Overlay by Bailey (' .. config.hideToggleHotkey .. ')')

        isHidden = false
    end

    local function detectPlayerAircraft()
        -- the way that this is currently, it will stay on in kiowa, and after kiowa
        -- in the menus. when in a different aircraft it will dissapear.
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        if aircraft == "OH58D" then
            isHidden = false
            show()
        else
            isHidden = true
            hide()
        end
    end


    local function PressMFK()
        if pleasePressMFK then -- if you want to press the mfk
            if isPressed then  -- if there is a button alread pressed
                -- check if the time has come to depress
                local currTime = Export.LoGetModelTime()
                if currTime >= whenToDepress then
                    -- check if it even needs a depress
                    local command = mfkButton + 3000
                    Export.GetDevice(14):performClickableAction(command, 0)
                    isPressed = false
                    pleasePressMFK = false
                end
            else -- if there is no button pressed
                --local delay = 100 -- in milliseconds. can set at top or in config file
                -- Push the button
                local command = mfkButton + 3000
                Export.GetDevice(14):performClickableAction(command, 1)
                --Store the time when we will need to depress
                whenToDepress = Export.LoGetModelTime() + (config.buttonPressTime / 1000)
                isPressed = true
            end
        end
    end

    local handler = {}

    function handler.onSimulationFrame()
        if config == nil then
            loadConfiguration()
        end

        if not window then
            log("Creating Kiowa MFK Overlay window...")
            createKiowaMfkOverlayWindow()
        end
        PressMFK()
    end

    function handler.onMissionLoadEnd()
        inMission = true

        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        if aircraft == "OH58D" then
            isHidden = false
            show()
        else
            isHidden = true
            hide()
        end
    end

    function handler.onSimulationStop()
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        inMission = false
        hide()                             -- hides the app when returning to the main game menus
    end

    function handler.onPlayerChangeSlot() -- MP only
        detectPlayerAircraft()
    end

    DCS.setUserCallbacks(handler)

    net.log("[KiowaMfkOverlay] Loaded ...")
end

local status, err = pcall(loadKiowaMfkOverlay)
if not status then
    net.log("[KiowaMfkOverlay] Load Error: " .. tostring(err))
end
