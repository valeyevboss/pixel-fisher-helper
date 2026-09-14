script_name('Pixel Fisher Helper')
script_author('Nikita Valeyev')
script_version('1.0.0')

-- =========================
-- Подключаемые библиотеки
-- =========================
local imgui = require 'mimgui'
local encoding = require 'encoding'
local json = require 'dkjson'
local render = require 'lib.render'
local inicfg = require 'inicfg'
local lfs = require 'lfs'
local ffi = require "ffi"

-- Для воспроизведения звуков, аудио
ffi.cdef[[
    int PlaySoundA(const char *pszSound, void* hmod, unsigned int fdwSound);
]]

local winmm = ffi.load("winmm")
local SND_ASYNC = 0x0001
local SND_FILENAME = 0x00020000

require 'lib.moonloader'
require 'lib.sampfuncs'
require 'vkeys'
local sampev = require 'lib.samp.events'

encoding.default = 'CP1251'
u8 = encoding.UTF8

-- Пользовательские + данные
local authorName = "Nikita Valeyev"
local lastdateUpdate = "15.09.2026"
local nickname = "Not found"

-- ==========================
-- Переменные
-- ==========================

-- Окна и состояния
local window = {
    mainMenu = imgui.new.bool(false),
	itemView = imgui.new.bool(false),
	histSession = imgui.new.bool(false),
	confirm = imgui.new.bool(false),
	settings = imgui.new.bool(false)
}

-- Переменные данных
local FishAmount = 0
local FishLoseAmount = 0
local moneyAmount = 0

-- Переменные сессии
local sessionData = nil
local sessionActive = false
local sessionStartTime = 0
local sessionStartDate = ""

-- Переменные сессии
local sessionHistory = {
    sessions = {}
}

local expanded = {}
local showConfirmDelete = false
local confirmTimer = 0
local confirmDelay = 10

local selectedSessionItems = {}
local valuableItems = {}
local commonItems = {}

-- Иконки
local Icons = {
    logo = nil
}

-- Переменные оверлея уведомлений
local ovlPushM = {
    -- Состояние и данные
    active = false,
    text = "",
    timer = 0,
    duration = 9999,
    alpha = 0,
	
	queue = {}, -- Очередь уведомлений
	
	-- Шрифты, размеры и цвета
    fontSize = 14,
    font = renderCreateFont('Arial', 14, 5),
    
    colors = {
        default = 0xFFFFFFFF,
        yellow  = 0xFFFFD200
    },
	
	-- Конфигурация типов (звуки, акцентные цвета и т.д.)
    types = {
        success = {
            sound = getWorkingDirectory() .. "\\config\\pixel_fisherhelper\\sound\\success.wav",
            accentColor = 0xFF2ECC71 -- Зеленый
        },
        warning = {
            sound = getWorkingDirectory() .. "\\config\\pixel_fisherhelper\\sound\\warning.wav",
            accentColor = 0xFFF1C40F -- Желтый
        },
        error = {
            sound = getWorkingDirectory() .. "\\config\\pixel_fisherhelper\\sound\\error.wav",
            accentColor = 0xE74C3C -- Красный
        },
        info = {
            sound = nil,
            accentColor = 0xFF3498DB -- Синий
        }
    },
	
    -- Режим редактирования позиции
    editPos = false,
    isDragging = false,
    dragOffset = { x = 0, y = 0 },
	
	-- Расположение и размеры
    pos = { x = 20, y = 20 },
    padding = 10,
    radius = 12
}

-- Переменные оверлея статистики рыбалки
local ovlFish = {
    fontSizes = { "Маленький", "Средний", "Большой" },
    fontSizeValues = { 9, 11, 14 },
    fontSizeIndex = imgui.new.int(1), -- По умолчанию 1 ("Средний")

    font = renderCreateFont('Arial', 11, 5),
    lineSpacing = 22,

    -- Режим редактирования позиции
    editPos = false,
    isDragging = false,
    dragOffset = { x = 0, y = 0 },

    -- Цвета
    colors = {
        bgDefault  = 0xC2000000, -- Полупрозрачный фон
        bgEdit     = 0x99000000, -- Фон в режиме редактирования
        text       = 0xFFFFFFFF  -- Белый цвет текста
    }
}

-- Переменные настроек
local settings = {
	hotkeys = {
		mainMenu = 0x78, -- F9
    },
	overlayPushM = true,
	overlayPushMSound = true,
	overlayPushMPos = { x = 20, y = 20 },
	overlayFish = true,
	overlayFishBackground = true,
	overlayFishPos = { x = 15, y = 0 },
	overlayFishFontSize = 11
}

-- Пустышки для настроек в imgui
local overlayPushM = imgui.new.bool()
local overlayPushMSound = imgui.new.bool()
local overlayFish = imgui.new.bool()
local overlayFishBackground = imgui.new.bool()

-- ===================================
-- Функции скрипта
-- Тут находится основа, ядро работы
-- Разработчик: Nikita Valeyev
-- ===================================

-- ==============================
-- Функция форматирования и ввода
-- ==============================

-- Функция для форматирования числа с разделителями тысяч
local function formatNumber(num)
    local s = tostring(num)
    local formatted = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return u8(formatted)
end

-- Преобразование кода клавиши в понятное название
local function keyToName(key)
    if not key or type(key) ~= "number" or key == 0 then return "Не выбрано" end
    
    local names = {
        [0x01] = "LMB", [0x02] = "RMB", [0x04] = "MMB",
        [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter",
        [0x10] = "Shift", [0x11] = "Ctrl", [0x12] = "Alt",
        [0x13] = "Pause", [0x14] = "CapsLock", [0x1B] = "Esc", [0x20] = "Space",
        [0x21] = "PageUp", [0x22] = "PageDown", [0x23] = "End", [0x24] = "Home",
        [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down",
        [0x2C] = "PrintScreen", [0x2D] = "Insert", [0x2E] = "Delete", [0x91] = "ScrollLock",
        [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4", [0x74] = "F5",
        [0x76] = "F7", [0x77] = "F8", [0x78] = "F9", [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12",
    }

    if key >= 0x41 and key <= 0x5A then return string.char(key) end -- A-Z
    if key >= 0x30 and key <= 0x39 then return string.char(key) end -- 0-9
    if key >= 0x60 and key <= 0x69 then return "Num " .. tostring(key - 0x60) end -- NumPad

    if names[key] then return names[key] end
    return "VK_" .. tostring(key)
end

-- =========================
-- UI стили
-- =========================

-- Перевод HEX-цветов в ImVec4
local function hexToImVec4(hex, alpha)
    local r = tonumber(hex:sub(1, 2), 16) / 255.0
    local g = tonumber(hex:sub(3, 4), 16) / 255.0
    local b = tonumber(hex:sub(5, 6), 16) / 255.0
    return imgui.ImVec4(r, g, b, alpha or 1.0)
end

-- Цветовая палитра
local bgMatte      = hexToImVec4("121316", 0.96) -- Фон окна
local cardBg       = hexToImVec4("1B1D22", 1.00) -- Подложка карточек
local borderClr    = hexToImVec4("2D2D2D", 1.00) -- Обводка блоков
local separatorClr = hexToImVec4("2F2F2F", 1.00) -- Разделитель
local btnBlue      = hexToImVec4("0077FF", 1.00) -- Синий

imgui.OnInitialize(function()
    local style = imgui.GetStyle()

    style.WindowRounding    = 12.0
    style.FrameRounding     = 10.0
    style.ChildRounding     = 10.0
    style.GrabRounding      = 10.0
    style.PopupRounding     = 10.0
    style.ScrollbarRounding = 8.0
    style.WindowBorderSize  = 1.0
    style.ChildBorderSize   = 1.0
    style.WindowPadding     = imgui.ImVec2(14, 14)
    style.ItemSpacing       = imgui.ImVec2(8, 6)

    -- Применяем цвета к стилям окон
    style.Colors[imgui.Col.WindowBg]         = bgMatte
    style.Colors[imgui.Col.ChildBg]          = cardBg
    style.Colors[imgui.Col.Border]           = borderClr
    style.Colors[imgui.Col.Separator]        = separatorClr

    -- Цвет шапки
    style.Colors[imgui.Col.TitleBg]          = bgMatte
    style.Colors[imgui.Col.TitleBgActive]    = bgMatte
    style.Colors[imgui.Col.TitleBgCollapsed] = bgMatte

    -- Текстуры / Логотип
    Icons.logo = imgui.CreateTextureFromFile("moonloader\\config\\pixel_fisherhelper\\img\\pfh_logo.png")
end)

-- Текстовые цвета
local textColor    = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
local gray1        = imgui.ImVec4(0.65, 0.65, 0.65, 1.00)
local green1       = imgui.ImVec4(0.20, 0.85, 0.35, 1.00)
local red1         = imgui.ImVec4(0.90, 0.25, 0.25, 1.00)
local yellow1      = imgui.ImVec4(1.00, 0.85, 0.25, 1.00)
local pink1        = imgui.ImVec4(0.95, 0.55, 0.85, 1.00)
local blue         = imgui.ImVec4(0.00, 0.47, 1.00, 1.00)

-- Кнопки с единым стилем и возвратом значения нажатия (Кастомный стиль)
local function ButtonWithStyle(label, width, height, colorNormal, colorHovered, colorActive)
    imgui.PushStyleColor(imgui.Col.Button, colorNormal)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, colorHovered)
    imgui.PushStyleColor(imgui.Col.ButtonActive, colorActive)

    local clicked = imgui.Button(label, imgui.ImVec2(width, height))

    imgui.PopStyleColor(3)

    return clicked
end

-- Выпадающий список
local dropdownState = {}
function StyledDropdown(id, label, items, currentIndex, width)
    if not items or #items == 0 then return false end
    
    width = width or 140
    dropdownState[id] = dropdownState[id] or false
    local opened = dropdownState[id]

    local changed = false
    local buttonHeight = 26
    local io = imgui.GetIO()
    local mouseX, mouseY = io.MousePos.x, io.MousePos.y

    if label ~= "" then
        imgui.TextColored(textColor, label)
        imgui.SameLine()
    end

    local min = imgui.GetCursorScreenPos()
    local max = imgui.ImVec2(min.x + width, min.y + buttonHeight)
    imgui.Dummy(imgui.ImVec2(width, buttonHeight))
    
    local hovered = mouseX >= min.x and mouseX <= max.x and mouseY >= min.y and mouseY <= max.y
    local draw = imgui.GetWindowDrawList()
    local bgColor = hovered and imgui.ImVec4(0.15, 0.15, 0.16, 1.0) or imgui.ImVec4(0.10, 0.10, 0.12, 1.0)

    draw:AddRectFilled(min, max, imgui.ColorConvertFloat4ToU32(bgColor), 6)
    
    local currentText = u8(tostring(items[currentIndex[0] + 1] or "Выберите..."))
    local textPos = imgui.ImVec2(min.x + 8, min.y + (buttonHeight - imgui.GetTextLineHeight()) / 2)
    draw:AddText(textPos, imgui.ColorConvertFloat4ToU32(textColor), currentText)

    local arrowSize = 6
    local arrowCenterX = max.x - 15
    local arrowCenterY = min.y + buttonHeight / 2
    local arrowColor = imgui.ColorConvertFloat4ToU32(gray1)

    if opened then
        draw:AddTriangleFilled(
            imgui.ImVec2(arrowCenterX - arrowSize, arrowCenterY + arrowSize/2),
            imgui.ImVec2(arrowCenterX + arrowSize, arrowCenterY + arrowSize/2),
            imgui.ImVec2(arrowCenterX, arrowCenterY - arrowSize/2),
            arrowColor
        )
    else
        draw:AddTriangleFilled(
            imgui.ImVec2(arrowCenterX - arrowSize, arrowCenterY - arrowSize/2),
            imgui.ImVec2(arrowCenterX + arrowSize, arrowCenterY - arrowSize/2),
            imgui.ImVec2(arrowCenterX, arrowCenterY + arrowSize/2),
            arrowColor
        )
    end

    if hovered and imgui.IsMouseClicked(0) then
        dropdownState[id] = not opened
    end

    if opened then
        local foreDraw = imgui.GetForegroundDrawList()
        local listMin = imgui.ImVec2(min.x, max.y + 2)
        local listMax = imgui.ImVec2(min.x + width, max.y + 2 + #items * 24)
        
		foreDraw:AddRectFilled(listMin, listMax, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.07, 0.07, 0.08, 0.98)), 8)
        foreDraw:AddRect(listMin, listMax, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.20, 0.20, 0.22, 1.0)), 8)

        for i, value in ipairs(items) do
            local itemMin = imgui.ImVec2(listMin.x + 2, listMin.y + (i-1)*24 + 2)
            local itemMax = imgui.ImVec2(listMax.x - 2, listMin.y + i*24)
            local itemHovered = mouseX >= itemMin.x and mouseX <= itemMax.x and mouseY >= itemMin.y and mouseY <= itemMax.y
            
            local valText = u8(tostring(value or ""))

            if itemHovered then
                foreDraw:AddRectFilled(itemMin, itemMax, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.20, 0.50, 0.75, 0.85)), 6)
                if imgui.IsMouseClicked(0) then
                    currentIndex[0] = i - 1
                    dropdownState[id] = false
                    changed = true
                end
            end
            foreDraw:AddText(imgui.ImVec2(itemMin.x + 8, itemMin.y + 4), imgui.ColorConvertFloat4ToU32(textColor), valText)
        end

        if imgui.IsMouseClicked(0) and not hovered and not (mouseX >= listMin.x and mouseX <= listMax.x and mouseY >= listMin.y and mouseY <= listMax.y) then
            dropdownState[id] = false
        end
    end

    return changed
end

-- Переключатель / Тоггл / Чекбокс (Кастомный стиль)
-- Хранение состояния анимации кружка для каждого тоггла (относительная позиция: 0 = выключено, 1 = включено)
local toggleAnimationProgress = {}
function ToggleSwitch(id, state)
    local drawList = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()

    local height = 22
    local width = height * 1.8
    local radius = height * 0.5

    -- Цвет фона
    local bgColor = state[0]
        and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.2, 0.4, 1.0, 1.0))
        or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.2, 0.2, 1.0))

    local knobColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 1))

    -- Инициализация анимации
    if toggleAnimationProgress[id] == nil then
        toggleAnimationProgress[id] = state[0] and 1 or 0
    end

    -- Анимация
    local target = state[0] and 1 or 0
    toggleAnimationProgress[id] =
        toggleAnimationProgress[id] + (target - toggleAnimationProgress[id]) * 0.2

    -- Рисование
    drawList:AddRectFilled(pos, imgui.ImVec2(pos.x + width, pos.y + height), bgColor, radius)

    local knobX = pos.x + radius + toggleAnimationProgress[id] * (width - 2 * radius)
    drawList:AddCircleFilled(imgui.ImVec2(knobX, pos.y + radius), radius - 1, knobColor)

    -- КНОПКА (ID - КРИТИЧЕСКИ ВАЖНО)
    imgui.InvisibleButton("##" .. id, imgui.ImVec2(width, height))

    if imgui.IsItemClicked() then
        state[0] = not state[0]
        return true
    end

    return false
end

-- Кнопка для назначения/перезначения клавиш
local function drawKeyInput(target, tooltip)
    tooltip = tooltip or "Нажмите для смены клавиши"
    local BTN_WIDTH  = 110
    local BTN_HEIGHT = 26
    
    local currentKey = settings.hotkeys[target] or 0
    local keyName = keyToName(currentKey)
    
    local names = {
        mainMenu = "Главное окно",
    }
    local displayName = names[target] or target

	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.50, 0.75, 0.85))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.60, 0.88, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15, 0.40, 0.65, 1.00))

    if imgui.Button(u8(keyName .. "##" .. target), imgui.ImVec2(BTN_WIDTH, BTN_HEIGHT)) then
        waitingKeyInputType = target
        ovlPushM.show("Назначить клавишу для: " .. displayName, 60)
    end

    imgui.PopStyleColor(3)
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8(tooltip))
    end
end

-- Красивая анимация рамки
local function drawAnimatedBorder(x, y, w, h, thickness)

    local t = os.clock()

    -- Плавное переливание красного
    -- значение 0..1
    local pulse = (math.sin(t * 2) + 1) / 2

    -- интерполяция яркости
    local red = math.floor(150 + pulse * 105)
    local green = math.floor(40 + pulse * 30)

    local borderColor =
        bit.bor(
            bit.lshift(0xAA, 24),
            bit.lshift(red, 16),
            bit.lshift(green, 8),
            40
        )

    -- Движение по периметру
    local time = t * 180
    local perimeter = (w + h) * 2
    local progress = time % perimeter

    local px, py

    if progress < w then
        px = x + progress
        py = y
    elseif progress < w + h then
        px = x + w
        py = y + (progress - w)
    elseif progress < w + h + w then
        px = x + w - (progress - w - h)
        py = y + h
    else
        px = x
        py = y + h - (progress - w - h - w)
    end

    -- Анимированная красная рамка
    renderDrawBox(x - thickness, y - thickness, w + thickness * 2, thickness, borderColor)
    renderDrawBox(x - thickness, y + h, w + thickness * 2, thickness, borderColor)
    renderDrawBox(x - thickness, y, thickness, h, borderColor)
    renderDrawBox(x + w, y, thickness, h, borderColor)

    -- Белое свечение
    local glowSize = 10
    local glowAlpha = 120 + math.sin(t * 6) * 40
    local glowColor = bit.bor(bit.lshift(math.floor(glowAlpha), 24), 0xFFFFFF)

    renderDrawBox(px - glowSize, py - glowSize, glowSize * 2, glowSize * 2, glowColor)
    renderDrawBox(px - 2, py - 2, 4, 4, 0xFFFFFFFF)

    -- Микро-частицы
    for i = 1, 3 do
        local offset = (i * 12) % perimeter
        local p = (progress - offset + perimeter) % perimeter

        local tx, ty

        if p < w then
            tx = x + p
            ty = y
        elseif p < w + h then
            tx = x + w
            ty = y + (p - w)
        elseif p < w + h + w then
            tx = x + w - (p - w - h)
            ty = y + h
        else
            tx = x
            ty = y + h - (p - w - h - w)
        end

        renderDrawBox(tx - 1, ty - 1, 2, 2, 0x88FFFFFF)
    end
end

-- =========================
-- Функции работы с файлами
-- =========================

-- Создание папок
local function getFolderPSC()
    local folder = "moonloader/config/pixel_fisherhelper"
    if not lfs.attributes(folder) then
        lfs.mkdir(folder)
    end
    return folder
end

local function getStatsPath()
    return getFolderPSC().."/"..nickname.."_session.json"
end

local function getSettingsPath()
    return getFolderPSC().."/"..nickname.."_settings.json"
end

-- Сохранение настроек
local function saveSettings()
    local path = getSettingsPath()
    local file = io.open(path, "w")

    if file then
        file:write(json.encode(settings, { indent = true }))
        file:close()
    end
end

-- Загрузка настроек
local function loadSettings()
    local path = getSettingsPath()
    local file = io.open(path, "r")

    if file then
        local content = file:read("*a")
        file:close()

        local data = json.decode(content)
        if data then
            settings = data
        end
    else
        saveSettings()
    end
	
	settings.hotkeys = settings.hotkeys or {}
	settings.hotkeys.mainMenu = settings.hotkeys.mainMenu or 0x78 -- F9
	
	-- синхронизируем тогл и overlay
	overlayPushM[0] = (settings.overlayPushM ~= false)
	overlayPushMSound[0] = (settings.overlayPushMSound ~= false)
	settings.overlayPushMPos = settings.overlayPushMPos or { x = 20, y = 20 }
	
	overlayFish[0] = (settings.overlayFish ~= false)
	overlayFishBackground[0] = (settings.overlayFishBackground ~= false)
	settings.overlayFishPos = settings.overlayFishPos or { x = 15, y = 0 }
	settings.overlayFishFontSize = settings.overlayFishFontSize or 11
	
	-- Выставляем правильный индекс для Dropdown (Маленький / Средний / Большой)
	for i, v in ipairs(ovlFish.fontSizeValues) do
		if v == settings.overlayFishFontSize then
			ovlFish.fontSizeIndex[0] = i - 1
			break
		end
	end
	ovlFish.font = renderCreateFont('Arial', settings.overlayXyzFontSize, 5)
end

-- Сброс настроек
local function resetSettings()
    settings = {
		-- Все горячие клавиши
        hotkeys = {
            mainMenu = 0x78,
        },
		overlayPushM = true,
		overlayPushMSound = true,
		overlayPushMPos = { x = 20, y = 20 },
		overlayFish = true,
		overlayFishBackground = true,
		overlayFishPos = { x = 15, y = 0 },
		overlayFishFontSize = 11,
    }
	
	-- пересоздаём шрифты оверлеев
	ovlFish.fontSizeIndex[0] = 1 -- Средний
	ovlFish.font = renderCreateFont('Arial', 11, 5)
	
	-- синхронизация imgui-переменных
	overlayPushM[0] = true
	overlayPushMSound[0] = true
	overlayFish[0] = true
	overlayFishBackground[0] = true

	-- Режим редактирования (перемещения оверлеев)
	ovlPushM.editPos = false
	ovlPushM.isDragging = false
	
	ovlFish.editPos = false
	ovlFish.isDragging = false
	
	showCursor(false)
	
    saveSettings()
    sampAddChatMessage("{78DBE2}[Pixel FH]: {FFFFFF}Настройки сброшены к дефолтным значениям.", -1)
end

-- Загрузка сессии
local function loadSessions()
    local path = getStatsPath()
    local file = io.open(path, "r")

    if file then
        local content = file:read("*a")
        file:close()

        local data, pos, err = json.decode(content)
        if data then
            sessionHistory = data
        end
    else
        -- если файла нет – создаём пустой
        local newFile = io.open(path, "w")
        newFile:write(json.encode(sessionHistory, { indent = true }))
        newFile:close()
    end
end

-- Сохранение сессии
local function saveSessions()
    local path = getStatsPath()
    local file = io.open(path, "w")

    if file then
        file:write(json.encode(sessionHistory, { indent = true }))
        file:close()
    end
end

-- =========================
-- Вспомогательные функции
-- =========================

-- Проигрывания звука, аудио
local function playNotificationSound(soundPath)
    if soundPath and soundPath ~= "" and doesFileExist(soundPath) then
        winmm.PlaySoundA(soundPath, nil, bit.bor(SND_ASYNC, SND_FILENAME))
    end
end

-- Расчёта размеров текста (Оверлея уведомлений)
function ovlPushM.calcSize(text, lineHeight)
    local maxWidth, lines = 0, 0
    for line in text:gmatch("[^\n]+") do
        local w = renderGetFontDrawTextLength(ovlPushM.font, line)
        if w > maxWidth then maxWidth = w end
        lines = lines + 1
    end
    return maxWidth, lines * lineHeight
end

-- Функция отрисовки цвета строки с тегами (Оверлея уведомлений)
function ovlPushM.drawRichLine(x, y, line, alpha)
    local ax = x
    local a = bit.lshift(math.floor(alpha * 255), 24)
    local color = ovlPushM.colors.default

    for chunk, tag in line:gmatch("([^%[]*)(%b[])") do
        if chunk ~= "" then
            renderFontDrawText(ovlPushM.font, chunk, ax, y, color + a)
            ax = ax + renderGetFontDrawTextLength(ovlPushM.font, chunk)
        end

        if tag == "[y]" then
            color = ovlPushM.colors.yellow
        elseif tag == "[/]" then
            color = ovlPushM.colors.default
        end
    end

    local tail = line:gsub(".*%]", "")
    if tail ~= "" then
        renderFontDrawText(ovlPushM.font, tail, ax, y, color + a)
    end
end

-- Управление отображением (Оверлея уведомлений)
function ovlPushM.show(typeOrText, textOrDuration, duration)
    local nType, nText, nDuration

    -- Автоопределение формата вызова для гибридной совместимости
    if ovlPushM.types[typeOrText] then
        nType = typeOrText
        nText = tostring(textOrDuration or "")
        nDuration = duration or 2.5
    else
        nType = "info"
        nText = tostring(typeOrText or "")
        nDuration = textOrDuration or 2.5
    end

    table.insert(ovlPushM.queue, {
        type = nType,
        text = nText,
        duration = nDuration
    })
end

-- Принудительная очистка оверлея и очереди
function ovlPushM.hide()
    ovlPushM.active = false
    ovlPushM.queue = {}
end

-- =========================
-- Сессии
-- =========================

-- Старт сессии
local function startSession()
    if sessionActive then return end

    sessionActive = true
    sessionStartTime = os.time()
    sessionStartDate = os.date("%d.%m.%Y %H:%M:%S")

    FishAmount = 0
    FishLoseAmount = 0

    sessionData = {
        fish_caught = 0,
        fish_lost = 0,
        money_earned = 0,
        items = 0,
        fish_coins = 0,
        transactions = {}
    }

    sampAddChatMessage("{78DBE2}[Pixel FH]: {FFFFFF}Сессия начата!", -1)
end

-- Конец сессии
local function endSession()
    if not sessionActive then return end

    sessionActive = false

	local totalTime = os.time() - sessionStartTime
	local hours = math.floor(totalTime / 3600)
	local minutes = math.floor((totalTime % 3600) / 60)
	local seconds = totalTime % 60
	
    -- сохраняем в историю
    table.insert(sessionHistory.sessions, {
        date = sessionStartDate,
        duration = string.format("%02d:%02d:%02d", hours, minutes, seconds),
        fish_caught = sessionData.fish_caught,
        fish_lost = sessionData.fish_lost,
		money_earned = sessionData.money_earned,
		items = sessionData.items,
		fish_coins = sessionData.fish_coins,
        transactions = sessionData.transactions
    })
	
	sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Сессия завершена! Длительность: {FFD700}%02d:%02d:%02d{FFFFFF}, рыб: {00FF00}%d{FFFFFF}, упущено: {FF3333}%d", hours, minutes, seconds, FishAmount, FishLoseAmount), -1)

    sessionData = nil -- очищаем объект текущей сессии
	
    -- Сбрасываем счётчики для UI
    FishAmount = 0
    FishLoseAmount = 0
	moneyAmount = 0
	itemAmount = 0
	fishcoinAmount = 0
    sessionStartTime = 0
    sessionStartDate = ""
	
    saveSessions()
end

-- ====================================================
-- Функции вычисления, обработка сообщения из чата
-- ====================================================

-- Получаем сообщения из чата о рыбалке
function sampev.onServerMessage(color, text)
    if not sessionActive or not sessionData then return end

    -- Чистим цветовые коды
    local cleanText = text:gsub("{.-}", "")

    ----------------------------------------
    -- [1] Пойманная рыба
    ----------------------------------------
    local fishName = cleanText:match("Вы поймали рыбу%s+'(.+)'")
    if fishName and not cleanText:match("У вас нет места или ваш инвентарь заблокирован!") then
        -- Если сообщение не о полном инвентаре

        sessionData.fish_caught = sessionData.fish_caught + 1
        FishAmount = sessionData.fish_caught

        table.insert(sessionData.transactions, {
            type = "fish",
            name = u8(fishName),
            amount = 1
        })

        sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Вы поймали рыбу {AE433D}'%s'{FFFFFF}", fishName), -1)
		if settings.overlayPushM and ovlPushM and ovlPushM.show then
            ovlPushM.show("success", string.format("Поймана рыба: [g]%s[/]", fishName), 3)
        end

        saveSessions()
        return
    end
	
    ----------------------------------------
    -- [2] Поймана сразу несколько рыб (бонусы, удочка)
    ----------------------------------------
    local fishCount = cleanText:match("Вы поймали сразу (%d+) рыбы! %((.+)%)")
    if fishCount and not cleanText:match("У вас нет места или ваш инвентарь заблокирован!") then
        local count = tonumber(fishCount) or 1
        local additionalFish = count - 1  -- Дополнительные рыбы, которые были пойманы

        sessionData.fish_caught = sessionData.fish_caught + additionalFish
        FishAmount = sessionData.fish_caught

        table.insert(sessionData.transactions, {
            type = "fish",
            name = u8("Неизвестная рыба"),
            amount = additionalFish
        })

        sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Вы поймали %d дополнительные рыбы! (всего: %d)", additionalFish, sessionData.fish_caught), -1)
		if settings.overlayPushM and ovlPushM and ovlPushM.show then
            ovlPushM.show("success", string.format("Бонус улова: [g]+%d шт.[/] (всего: %d)", additionalFish, sessionData.fish_caught), 3)
        end

        saveSessions()
        return
    end

    ----------------------------------------
    -- [3] Упущенная рыба
    ----------------------------------------
    if cleanText:match("Вы слишком ослабили леску, рыба ушла") then
        sessionData.fish_lost = sessionData.fish_lost + 1
        FishLoseAmount = sessionData.fish_lost

        table.insert(sessionData.transactions, {
            type = "fish_lost",
            reason = u8("Упущено"),
            amount = 1
        })

        sampAddChatMessage("{78DBE2}[Pixel FH]: {FF3333}Рыба упущена!", -1)
		if settings.overlayPushM and ovlPushM and ovlPushM.show then
            ovlPushM.show("error", "Рыба сорвалась с крючка!", 3)
        end

        saveSessions()
        return
    end
	
	----------------------------------------
	-- [4] Продажа рыбы
	----------------------------------------
	local soldAmount, soldMoneyRaw = cleanText:match("Вы успешно продали рыбу в кол%-ве (%d+) шт%. за%s+.-([%d%,%.]+)")
	if soldAmount and soldMoneyRaw then
		soldAmount = tonumber(soldAmount)

		-- Очищаем сумму от точек и запятых
		local cleanMoneyStr = soldMoneyRaw:gsub("[%.,]", "")
		local soldMoney = tonumber(cleanMoneyStr)

		if not soldMoney then
			sampAddChatMessage("{78DBE2}[Pixel FH]: {FF0000}Ошибка при обработке суммы продажи. Проверьте формат.", -1)
			return
		end

		-- Если все корректно, обновляем данные сессии
		sessionData.money_earned = (sessionData.money_earned or 0) + soldMoney
		moneyAmount = sessionData.money_earned

		table.insert(sessionData.transactions, {
			type = "money",
			amount = soldMoney,
			fish_count = soldAmount
		})

		sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Вы продали %d рыб за $%d", soldAmount, soldMoney), -1)
		if settings.overlayPushM and ovlPushM and ovlPushM.show then
			ovlPushM.show("success", string.format("Продано: [y]%d шт.[/] за [g]$%d[/]", soldAmount, soldMoney), 4)
		end

		saveSessions()
		return
	end
	
	----------------------------------------
	-- [5] Получение предметов (добыча)
	----------------------------------------
	local rawItemName = cleanText:match("Вы поймали%s+'(.+)'")

	-- Проверка, что пойман предмет И нет ошибки о полном инвентаре
	if rawItemName and not cleanText:match("У вас нет места или ваш инвентарь заблокирован!") then
		local itemName = rawItemName:gsub("^%s*(.-)%s*$", "%1")

		-- Защита от кракозябр
		if #itemName < 2 or itemName:match("?") then
			itemName = "Неизвестный предмет"
		end

		local itemPrices = {
			["Лечебные водоросли"] = 1,
			["Кожанный сапог"] = 1,
			["Серебряная цепь"] = 1,
			["Брошь"] = 1,
			["Кулон"] = 1,
			["Череп"] = 1,
			["Шляпа рыбака"] = 1,
			["Древнее копьё"] = 1,
			["Амулет"] = 1,
			["Маска шамана"] = 1,
			["Старый нож"] = 1,
			["Сломанный телефон"] = 1,

			["Наручные часы"] = 2,
			["Пустая бутылка"] = 2,
			["Ржавый револьвер"] = 2,
			["Золотое кольцо"] = 2,
			["Ритуальная чаша"] = 2,
			["Неизвестная статуэтка"] = 2
		}

		local itemPrice = itemPrices[itemName] or 0

		-- Сохранение статистики
		sessionData.items = sessionData.items + 1
		sessionData.fish_coins = sessionData.fish_coins + itemPrice

		itemAmount = sessionData.items
		fishcoinAmount = sessionData.fish_coins


	    local found = false
		for _, v in ipairs(sessionData.transactions) do
			if v.type == "item" and v.name == u8(itemName) then
				v.amount = v.amount + 1
				v.fish_coins = v.fish_coins + itemPrice
				found = true
				break
			end
		end

		-- Если ещё нет этого предмета в списке – добавляем
		if not found then
			table.insert(sessionData.transactions, {
				type = "item",
				name = u8(itemName),
				amount = 1,
				fish_coins = itemPrice
			})
		end

		sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Получен предмет: {FFE55C}%s{FFFFFF} (+%d рыб. мон.)", itemName, itemPrice), -1)
		if settings.overlayPushM and ovlPushM and ovlPushM.show then
            if itemPrice > 0 then
                ovlPushM.show("warning", string.format("Находка: [y]%s[/]\n[g]+%d рыб. монет[/]", itemName, itemPrice), 4)
            else
                ovlPushM.show("warning", string.format("Находка: [y]%s[/]", itemName), 3)
            end
        end

		saveSessions()
		return
	end
end

-- =========================
-- Регистрация команд
-- =========================

-- Открытие главного окна
function cmd_fmenu()
    window.mainMenu[0] = not window.mainMenu[0]
end

-- Открытие окна настроек
function cmd_fsettings()
    window.settings[0] = not window.settings[0]
end

-- Открытие окна сессионной статистики
function cmd_fstats()
	window.histSession[0] = not window.histSession[0]
end

-- Просмотр доступных команд
function cmd_fhelp()
    local prefix = "{78DBE2}[Pixel FH]: {FFFFFF}"
    sampAddChatMessage(prefix .. "Список всех доступных команд:", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fmenu{FFFFFF} - открыть главное меню", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fsettings{FFFFFF} - открыть настройки", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fstats{FFFFFF} - статистика и история сессий", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fstart{FFFFFF} - начать сессию рыбалки", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fend{FFFFFF} - завершить сессию рыбалки", -1)
    sampAddChatMessage(prefix .. "{78DBE2}/fhelp{FFFFFF} - просмотр всех команд", -1)
end

-- Запуск сессии
function cmd_fstart()
    if sessionActive then
        sampAddChatMessage("{78DBE2}[Pixel FH]: {FF3333}Сессия уже запущена!", -1)
    else
        startSession()
    end
end

-- Завершает сессию
function cmd_fend()
    if not sessionActive then
        sampAddChatMessage("{78DBE2}[Pixel FH]: {FF3333}У вас нет активной сессии!", -1)
    else
        endSession()
    end
end

-- =========================
-- Все окна
-- =========================

-- Главное окно
imgui.OnFrame(function() return window.mainMenu[0] end, function()
    local sw, sh = getScreenResolution()

    imgui.SetNextWindowSize(imgui.ImVec2(700, 380), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

    imgui.Begin(u8"Pixel Fisher Helper", window.mainMenu, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

    -- Информационные карточки
    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.BeginChild("left_dashboard", imgui.ImVec2(430, 390), false, imgui.WindowFlags.NoScrollbar)
    imgui.PopStyleColor()
	
	-- Динамические стили для неактивного состояния блоков
	local sessionBg = sessionActive and cardBg or hexToImVec4("16171A", 1.0)
	local sessionHeaderClr = sessionActive and blue or gray1

        -- 1. Ваши данные
        imgui.BeginChild("card_user", imgui.ImVec2(430, 70), true, imgui.WindowFlags.NoScrollbar)
            imgui.TextColored(blue, u8"ВАШИ ДАННЫЕ")
            imgui.Dummy(imgui.ImVec2(0, 2))
            
            imgui.TextColored(gray1, u8"Вы:")
            imgui.SameLine()
            imgui.TextColored(yellow1, u8(nickname or "Kira_Kimchosu"))

            imgui.SameLine(220)
            imgui.TextColored(gray1, u8"Статус сессии:")
            imgui.SameLine()
            if sessionActive then
                imgui.TextColored(green1, u8"Активна")
            else
                imgui.TextColored(red1, u8"Неактивна")
            end
        imgui.EndChild()

		-- 2. Текущая сессия
		imgui.PushStyleColor(imgui.Col.ChildBg, sessionBg)
		imgui.BeginChild("card_session", imgui.ImVec2(430, 70), true, imgui.WindowFlags.NoScrollbar)
		imgui.PopStyleColor()

			imgui.TextColored(sessionHeaderClr, u8"ТЕКУЩАЯ СЕССИЯ")
			imgui.Dummy(imgui.ImVec2(0, 2))

			local activeTextColor = sessionActive and textColor or gray1

			imgui.TextColored(gray1, u8"Дата начала:")
			imgui.SameLine()
			imgui.TextColored(activeTextColor, sessionActive and sessionStartDate or u8"—")

			imgui.SameLine(245)
			imgui.TextColored(gray1, u8"Длительность:")
			imgui.SameLine()
			
			local passed = "—"
			if sessionActive then
				local t = os.time() - sessionStartTime
				passed = string.format("%02d:%02d:%02d", math.floor(t/3600), math.floor((t%3600)/60), t%60)
			end
			imgui.TextColored(activeTextColor, passed)
		imgui.EndChild()

        -- 3. Статистика
		imgui.PushStyleColor(imgui.Col.ChildBg, sessionBg)
		imgui.BeginChild("card_stats", imgui.ImVec2(430, 100), true, imgui.WindowFlags.NoScrollbar)
		imgui.PopStyleColor()

			imgui.TextColored(sessionHeaderClr, u8"СТАТИСТИКА")
			imgui.Dummy(imgui.ImVec2(0, 2))

			imgui.Columns(2, "stats_cols", false)
			imgui.SetColumnWidth(0, 210)

			-- Значения
			local fishText = sessionActive and tostring(FishAmount or 0) or "—"
			local fishLoseText = sessionActive and tostring(FishLoseAmount or 0) or "—"
			local itemText = sessionActive and tostring(itemAmount or 0) or "—"
			local fishcoinText = sessionActive and tostring(fishcoinAmount or 0) or "—"

			-- Цвета значений (серые, если неактивно)
			local valColor = sessionActive and textColor or gray1
			local valRed = sessionActive and red1 or gray1
			local valPink = sessionActive and pink1 or gray1

			imgui.TextColored(gray1, u8"Поймано рыб:")
			imgui.SameLine()
			imgui.TextColored(valColor, fishText)

			imgui.TextColored(gray1, u8"Упущено рыб:")
			imgui.SameLine()
			imgui.TextColored(valRed, fishLoseText)

			imgui.NextColumn()

			imgui.TextColored(gray1, u8"Предметов добыто:")
			imgui.SameLine()
			imgui.TextColored(valColor, itemText)

			imgui.TextColored(gray1, u8"Рыбные монеты:")
			imgui.SameLine()
			imgui.TextColored(valPink, fishcoinText)

			imgui.Columns(1)
		imgui.EndChild()

        -- 4. Финансы
		imgui.PushStyleColor(imgui.Col.ChildBg, sessionBg)
		imgui.BeginChild("card_finance", imgui.ImVec2(430, 75), true, imgui.WindowFlags.NoScrollbar)
		imgui.PopStyleColor()

			imgui.TextColored(sessionHeaderClr, u8"ФИНАНСЫ")
			imgui.Dummy(imgui.ImVec2(0, 4))

			local moneyText = "—"
			if sessionActive then
				local formattedMoney = (formatNumber and formatNumber(moneyAmount or 0) or tostring(moneyAmount or 0))
				moneyText = formattedMoney .. " $"
			end
			
			local valGreen = sessionActive and green1 or gray1

			imgui.TextColored(gray1, u8"Заработано с продажи:")
			imgui.SameLine()
			imgui.TextColored(valGreen, moneyText)
		imgui.EndChild()

    imgui.EndChild()

    imgui.SameLine()

    -- Логотип, название автор и меню
    imgui.BeginChild("right_branding", imgui.ImVec2(235, 335), true, imgui.WindowFlags.NoScrollbar)
        
        -- Логотип
        local logoSize = 75
        imgui.SetCursorPosX((235 - logoSize) / 2)
        if Icons.logo then
            imgui.Image(Icons.logo, imgui.ImVec2(logoSize, logoSize))
        else
            imgui.Dummy(imgui.ImVec2(logoSize, logoSize))
        end

        imgui.Dummy(imgui.ImVec2(0, 2))

        -- Название и автор
        local titleText = u8"Pixel Fisher Helper"
        imgui.SetCursorPosX((235 - imgui.CalcTextSize(titleText).x) / 2)
        imgui.TextColored(textColor, titleText)

        local authorStr = u8"Author: "
        local authorVal = u8(authorName)
        local totalAuthorW = imgui.CalcTextSize(authorStr).x + imgui.CalcTextSize(authorVal).x
        imgui.SetCursorPosX((235 - totalAuthorW) / 2)
        imgui.TextColored(gray1, authorStr)
        imgui.SameLine(0, 0)
        imgui.TextColored(yellow1, authorVal)

        imgui.Dummy(imgui.ImVec2(0, 4))
        
        -- Разделитель под шапкой логотипа
        imgui.PushStyleColor(imgui.Col.Separator, separatorClr)
        imgui.Separator()
        imgui.PopStyleColor()

        imgui.Dummy(imgui.ImVec2(0, 6))

        -- Кнопки
        local btnW, btnH = 200, 38

		-- Динамическая кнопка: Старта/Завершия сессии
		if not sessionActive then
			if ButtonWithStyle(
				u8"Начать сессию", 
				btnW, btnH, 
				imgui.ImVec4(0/255, 119/255, 255/255, 1.0),
				imgui.ImVec4(26/255, 133/255, 255/255, 1.0),
				imgui.ImVec4(0/255, 102/255, 221/255, 1.0)
			) then
				startSession()
			end
		else
			if ButtonWithStyle(
				u8"Завершить сессию", 
				btnW, btnH, 
				imgui.ImVec4(255/255, 59/255, 48/255, 1.0),
				imgui.ImVec4(255/255, 83/255, 73/255, 1.0),
				imgui.ImVec4(215/255, 38/255, 30/255, 1.0)
			) then
				endSession()
			end
		end

        imgui.Dummy(imgui.ImVec2(0, 3))

		-- Кнопка История
		if ButtonWithStyle(
			u8"История сессий", 
			btnW, btnH, 
			imgui.ImVec4(0/255, 119/255, 255/255, 1.0),
			imgui.ImVec4(26/255, 133/255, 255/255, 1.0),
			imgui.ImVec4(0/255, 102/255, 221/255, 1.0)
		) then
			window.histSession[0] = not window.histSession[0]
		end

		imgui.Dummy(imgui.ImVec2(0, 3))

		-- Кнопка Настройки
		if ButtonWithStyle(
			u8"Настройки", 
			btnW, btnH, 
			imgui.ImVec4(0/255, 119/255, 255/255, 1.0),
			imgui.ImVec4(26/255, 133/255, 255/255, 1.0),
			imgui.ImVec4(0/255, 102/255, 221/255, 1.0)
		) then
			window.settings[0] = not window.settings[0]
		end

    imgui.EndChild()

    imgui.End()
end)

-- Окно: История сессий
imgui.OnFrame(function() return window.histSession[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(520, 420), imgui.Cond.FirstUseEver)
	
    imgui.Begin(u8"История сессий", window.histSession, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar)

    imgui.TextColored(textColor, u8"Всего сессий: " .. tostring(#sessionHistory.sessions))
    imgui.Separator()

    imgui.BeginChild("list", imgui.ImVec2(0, 300), true)

    for i = #sessionHistory.sessions, 1, -1 do
        local s = sessionHistory.sessions[i]

        -- Заголовок строки
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.2, 0.2, 0.5))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.3, 0.3, 0.6))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15, 0.15, 0.15, 0.5))

		-- Строка для кнопки
		local arrow = expanded[i] and u8"v " or u8"> "
		local btnLabel = arrow
			.. u8("Сессия №" .. i)
			.. u8("    |    Дата: " .. s.date)
			.. u8("    |    Время: " .. s.duration)

		if imgui.Button(btnLabel, imgui.ImVec2(480, 30)) then
			expanded[i] = not expanded[i]
		end

        imgui.PopStyleColor(3)

        -- Если строка раскрыта, показываем детали
        if expanded[i] then
            imgui.Indent(20)

            imgui.TextColored(yellow1, u8("Дата: ") .. s.date)
            imgui.Text(u8("Длительность: ") .. s.duration)
			
            imgui.Text(u8("Поймано рыб: ") .. tostring(s.fish_caught))
			
			imgui.TextColored(textColor, u8"Упущено рыб: ")
			imgui.SameLine()
			imgui.TextColored(red1, tostring(s.fish_lost or 0))

			imgui.TextColored(textColor, u8"Заработано: ")
			imgui.SameLine()
			imgui.TextColored(green1, formatNumber(s.money_earned or 0))

			imgui.Text(u8("Предметов: ") .. tostring(s.items or 0))
			imgui.SameLine()

			-- только если предметы есть
			if s.items and s.items > 0 then
				if imgui.SmallButton(u8"Подробнее") then
					-- очищаем прошлые данные
					selectedSessionItems = {}

					-- собираем предметы этой сессии
					for _, tr in ipairs(s.transactions or {}) do
						if tr.type == "item" then
							table.insert(selectedSessionItems, {
								name = tr.name or "Неизвестно",
								coins = tr.fish_coins or 0,
								amount = tr.amount or 1
							})
						end
					end

					window.itemView[0] = true
				end
			end
			
			imgui.TextColored(textColor, u8"Рыбных монет: ")
			imgui.SameLine()
			imgui.TextColored(pink1, tostring(s.fish_coins or 0))

            imgui.Dummy(imgui.ImVec2(0, 4))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 4))

            imgui.Unindent(20)
        end
    end

    imgui.EndChild()
	
	imgui.Dummy(imgui.ImVec2(0, 2))
	
	local btnWidth = 150
	local btnHeight = 35
	local indent = (imgui.GetWindowSize().x - btnWidth) / 2
	imgui.Indent(indent)

	-- Кнопка Очистить историю
	if #sessionHistory.sessions == 0 or window.confirm[0] then
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
		imgui.Button(u8"Очистить историю", imgui.ImVec2(btnWidth, btnHeight))
		imgui.PopStyleColor(3)
	else
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 0.8))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.9, 0.3, 0.3, 0.9))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.7, 0.15, 0.15, 0.8))

		if imgui.Button(u8"Очистить историю", imgui.ImVec2(btnWidth, btnHeight)) then
			window.confirm[0] = true
		end

		imgui.PopStyleColor(3)
	end

	imgui.Unindent(indent)
    imgui.End()
end)

-- Окно выпавших предметов (список)
imgui.OnFrame(function() return window.itemView[0] end, function()
    local sw, sh = getScreenResolution()
	
    imgui.SetNextWindowSize(imgui.ImVec2(420, 300), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

    imgui.Begin(u8"Предметы за сессию", window.itemView, imgui.WindowFlags.NoResize)

    imgui.TextColored(textColor, u8"Список полученных предметов")
    imgui.Separator()

    imgui.BeginChild("itemList", imgui.ImVec2(0, 220), true)

    if #selectedSessionItems == 0 then
        imgui.TextColored(gray1, u8"В этой сессии предметов нет.")
    else
        -- Разделяем предметы
        local valuableItems = {}
        local commonItems = {}

        for _, it in ipairs(selectedSessionItems) do
            if it.coins and it.coins > 0 then
                table.insert(valuableItems, it)
            else
                table.insert(commonItems, it)
            end
        end
		
        -- Ценные предметы
        imgui.TextColored(yellow1, u8"Ценные предметы:")
        imgui.Separator()

        if #valuableItems == 0 then
            imgui.TextColored(gray1, u8"Нет ценных предметов.")
        else
            for i, it in ipairs(valuableItems) do
                imgui.Text((string.format("%d) %s", i, it.name)))

                imgui.SameLine()
                imgui.TextColored(yellow1, u8(" + " .. it.coins .. " мон."))

                imgui.SameLine()
                imgui.TextColored(gray1, u8(" x" .. it.amount))

                imgui.Separator()
            end
        end

        imgui.NewLine()

        -- Обычные предметы
        imgui.TextColored(textColor, u8"Обычные предметы:")
        imgui.Separator()

        if #commonItems == 0 then
            imgui.TextColored(gray1, u8"Нет обычных предметов.")
        else
            for i, it in ipairs(commonItems) do
                imgui.Text((string.format("%d) %s", i, it.name)))

                imgui.SameLine()
                imgui.TextColored(gray1, u8(" x" .. it.amount))

                imgui.Separator()
            end
        end
    end

    imgui.EndChild()
    imgui.End()
end)


-- Мини-окно подтверждения
imgui.OnFrame(function() return window.confirm[0] end, function()
    -- Запускаем таймер, если ещё не запущен
    if confirmTimer == 0 then 
        confirmTimer = os.time() 
    end

    imgui.SetNextWindowSize(imgui.ImVec2(400, 150), imgui.Cond.Appearing)

    if imgui.Begin(u8"Подтверждение действия", window.confirm, imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize) then

        -- Основной текст
        imgui.TextWrapped(u8"Вы действительно хотите удалить историю сессий?\nПосле очистки все сохранённые данные будут утеряны.")
        imgui.Dummy(imgui.ImVec2(0, 10))

        -- Таймер обратного отсчёта
        local elapsed = os.time() - confirmTimer
        local remaining = math.max(confirmDelay - elapsed, 0)
        local canDelete = remaining == 0

        -- Текст таймера по центру
        if not canDelete then
            local winWidth = imgui.GetWindowSize().x
            local text = u8("Подождите ещё " .. tostring(remaining) .. " секунд")
            local textWidth = imgui.CalcTextSize(text).x
            imgui.SetCursorPosX((winWidth - textWidth)/2)
            imgui.TextColored(imgui.ImVec4(1, 0.7, 0.2, 1), text)
            imgui.Dummy(imgui.ImVec2(0, 10))
        end

        -- Кнопки по центру
        local btnWidthConfirm = 100
        local winWidth = imgui.GetWindowSize().x
        local spacing = 10
        local totalWidth = btnWidthConfirm * 2 + spacing
        imgui.SetCursorPosX((winWidth - totalWidth)/2)

        -- Стиль кнопки "Удалить" с проверкой таймера
        if canDelete then
            -- Таймер истёк — кнопка красная
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 0.8))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.9, 0.3, 0.3, 0.9))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.7, 0.15, 0.15, 0.8))
        else
            -- Таймер не истёк — кнопка серая и "неактивная"
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
        end

        -- Кнопка всегда рисуется
        local pressed = imgui.Button(u8"Удалить", imgui.ImVec2(btnWidthConfirm, 30))

        -- Действие выполняется только если таймер истёк
        if canDelete and pressed then
            sessionHistory.sessions = {}
            expanded = {}
            saveSessions()
            sampAddChatMessage("{78DBE2}[Pixel FH]: {FF0000}Вы очистили историю сессий: {FFFFFF} данные обнулены.", -1)
            window.confirm[0] = false
            confirmTimer = 0
        end

        imgui.PopStyleColor(3)

        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 1.0, 0.9))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.7, 1.0, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15, 0.5, 0.9, 0.9))
        
        if imgui.Button(u8"Отмена", imgui.ImVec2(btnWidthConfirm, 30)) then
            window.confirm[0] = false
            confirmTimer = 0
        end
        
        imgui.PopStyleColor(3)

        imgui.End()
    else
        -- Если окно закрыто кликом на крестик
        confirmTimer = 0
    end
end)

-- Окно настроек
imgui.OnFrame(function() return window.settings[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(520, 450), imgui.Cond.FirstUseEver)
    
    imgui.Begin(u8"Настройки", window.settings, imgui.WindowFlags.NoResize)
    imgui.BeginChild("##SettingsScrollRegion", imgui.ImVec2(0, -50), true)

        -- Голубые цвета для шапок
        imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(0.12, 0.35, 0.55, 0.65))
        imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0.20, 0.50, 0.75, 0.85))
        imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0.15, 0.40, 0.65, 1.00))

        -- Задаем высоту и закругление плашек
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8.0)                -- Скруглённые края
        imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 8)) -- Толщина (высота) плашки
        
        local headerFlags = imgui.TreeNodeFlags.Framed + imgui.TreeNodeFlags.NoAutoOpenOnLog

        -- РАЗДЕЛ 1: ГОРЯЧИЕ КЛАВИШИ
        if imgui.CollapsingHeader(u8" ГОРЯЧИЕ КЛАВИШИ", headerFlags) then
            imgui.Indent(10)
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.TextColored(textColor, u8"Открытие главного меню:")
            imgui.SameLine(320)
            drawKeyInput("mainMenu", "Нажмите, чтобы изменить клавишу открытия меню")
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Unindent(10)
        end

        imgui.Spacing()

        -- РАЗДЕЛ 2: ОВЕРЛЕИ И УВЕДОМЛЕНИЯ
        if imgui.CollapsingHeader(u8" ОВЕРЛЕИ И УВЕДОМЛЕНИЯ", headerFlags) then
            imgui.Indent(10)
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.TextColored(blue, u8"Главный оверлей (Статистика)")
            imgui.Dummy(imgui.ImVec2(0, 5))

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Отображение оверлея")
            imgui.SameLine(320)
            if ToggleSwitch("overlay_fish", overlayFish) then
                settings.overlayFish = overlayFish[0]
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Включает отображение оверлея статистики сбоку экрана во время активной сессии")
            end

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Фон оверлея")
            imgui.SameLine(320)
            if ToggleSwitch("overlay_fish_bg", overlayFishBackground) then
                settings.overlayFishBackground = overlayFishBackground[0]
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Добавляет полупрозрачную подложку под текст для лучшей читаемости")
            end

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Позиция оверлея")
            imgui.SameLine(320)

            local btnWidth = 100
            local btnHeight = 24

            if not sessionActive then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.3, 0.3, 0.3, 0.5))

                imgui.Button(u8"Изменить##fisher", imgui.ImVec2(btnWidth, btnHeight))
                imgui.PopStyleColor(3)

                if imgui.IsItemHovered() then
                    imgui.SetTooltip(u8"Редактирование доступно только при активной сессии.")
                end
            else
                if ButtonWithStyle(
                    u8"Изменить##fisher",
                    btnWidth,
                    btnHeight,
                    imgui.ImVec4(0.2, 0.6, 1.0, 0.9),
                    imgui.ImVec4(0.3, 0.7, 1.0, 1.0),
                    imgui.ImVec4(0.15, 0.5, 0.9, 0.9)
                ) then
                    ovlFish.editPos = true
                    showCursor(true)
                    if ovlPushM and ovlPushM.show then
                        ovlPushM.show("Режим редактирования: Перетащите оверлей\n[y]ESC - сохранить[/]", 9999)
                    end
                end

                if imgui.IsItemHovered() then
                    imgui.SetTooltip(u8"Перетащите оверлей в нужное место.\nESC — сохранить позицию.")
                end
            end
            
            imgui.SetCursorPosX(30)
            imgui.Text(u8"Размер текста")
            imgui.SameLine(320)
            if StyledDropdown("ov_fish_font_size", "", ovlFish.fontSizes, ovlFish.fontSizeIndex, 120) then
                settings.overlayFishFontSize = ovlFish.fontSizeValues[ovlFish.fontSizeIndex[0] + 1]
                ovlFish.font = renderCreateFont('Arial', settings.overlayFishFontSize, 5)
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Выбор размера текста и шрифта оверлея")
            end

            imgui.Dummy(imgui.ImVec2(0, 10))

            imgui.TextColored(blue, u8"Оверлей уведомлений")
            imgui.Dummy(imgui.ImVec2(0, 5))

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Отображение")
            imgui.SameLine(320)
            if ToggleSwitch("overlay_push_m", overlayPushM) then
                settings.overlayPushM = overlayPushM[0]
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Включает и выключает отображение оверлея уведомлений на экране")
            end

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Звуки")
            imgui.SameLine(320)
            if ToggleSwitch("overlay_push_m_sound", overlayPushMSound) then
                settings.overlayPushMSound = overlayPushMSound[0]
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Включает и выключает воспроизведение звуков оверлея уведомлений")
            end

            imgui.SetCursorPosX(30)
            imgui.Text(u8"Позиция уведомлений")
            imgui.SameLine(320)
            if ButtonWithStyle(
                u8"Изменить##pushm", 
                100, 
                24, 
                imgui.ImVec4(0.2, 0.6, 1.0, 0.9),
                imgui.ImVec4(0.3, 0.7, 1.0, 1.0),
                imgui.ImVec4(0.15, 0.5, 0.9, 0.9)
            ) then
                ovlPushM.editPos = true
                showCursor(true)
                if ovlPushM and ovlPushM.show then
                    ovlPushM.show("Режим редактирования: Перетащите оверлей уведомлений\n[y]ESC - сохранить[/]", 9999)
                end
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8"Переходит в режим интерактивного перемещения оверлея по экрану мышью")
            end

            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Unindent(10)
        end

        imgui.PopStyleVar(2)
        imgui.PopStyleColor(3)

    imgui.EndChild()

    -- Кнопка сбросить настройки
    imgui.Dummy(imgui.ImVec2(0, 2))
    local btnResetW, btnResetH = 180, 32
    imgui.SetCursorPosX((imgui.GetWindowWidth() - btnResetW) / 2)

    if ButtonWithStyle(
        u8"Сбросить настройки", 
        btnResetW, 
        btnResetH, 
        imgui.ImVec4(120/255, 0/255, 0/255, 1.0),
        imgui.ImVec4(160/255, 0/255, 0/255, 1.0),
        imgui.ImVec4(80/255, 0/255, 0/255, 1.0)
    ) then
        if resetSettings then
            resetSettings()
        end
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Сбрасывает настройки к дефолтным значениям.")
    end

    imgui.End()
end)

-- =========================
-- Оверлеи
-- =========================

-- Оверлей уведомлений
lua_thread.create(function()
    while true do
        local dt = wait(0) or 0.016

        -- Cледующее сообщение из очереди
        if overlayPushM[0] and not ovlPushM.active and #ovlPushM.queue > 0 and ovlPushM.alpha <= 0 then
            local nextMsg = table.remove(ovlPushM.queue, 1)
            ovlPushM.text = nextMsg.text
            ovlPushM.type = nextMsg.type or "info"
            ovlPushM.duration = nextMsg.duration
            ovlPushM.timer = 0
            ovlPushM.active = true

            -- Проигрываем звук при появлении
            local typeConfig = ovlPushM.types[ovlPushM.type]
            if typeConfig and typeConfig.sound and (settings.overlayPushMSound ~= false) then
                playNotificationSound(typeConfig.sound)
            end
        end

        -- Анимация альфы и таймер
        if not ovlPushM.active or not overlayPushM[0] then
            ovlPushM.alpha = math.max(ovlPushM.alpha - dt * 5, 0)
        else
            ovlPushM.timer = ovlPushM.timer + dt
            ovlPushM.alpha = math.min(ovlPushM.alpha + dt * 5, 1)

            if ovlPushM.timer >= ovlPushM.duration then
                ovlPushM.active = false
            end
        end

        -- Позиция
        local posX = settings.overlayPushMPos and settings.overlayPushMPos.x or 20
        local posY = settings.overlayPushMPos and settings.overlayPushMPos.y or 20

        local renderText = ovlPushM.text
        local currentAlpha = ovlPushM.alpha

        if ovlPushM.editPos then
            currentAlpha = 1.0
            if renderText == "" then
                renderText = "Тестовое уведомление\n[y]Вы в режиме редактирования[/]"
            end
        end

        -- Отрисовка
        if currentAlpha > 0 and (overlayPushM[0] or ovlPushM.editPos) then
            local lineHeight = ovlPushM.fontSize + 8
            local textWidth, textHeight = ovlPushM.calcSize(renderText, lineHeight)
            
            local bgWidth  = textWidth + ovlPushM.padding * 2 + 6
            local bgHeight = textHeight + ovlPushM.padding * 2

            local alphaByte = math.floor(currentAlpha * 0xCC)
            local bgColor = bit.lshift(alphaByte, 24) + 0x000000

            -- 1. Режим редактирования
            if ovlPushM.editPos then
                local mx, my = getCursorPos()
                local mouseDown = isKeyDown(VK_LBUTTON)

                if renderDrawBoxRounded then
                    renderDrawBoxRounded(posX - 2, posY - 2, bgWidth + 4, bgHeight + 4, ovlPushM.radius, 0xFFE01C47)
                else
                    renderDrawBox(posX - 2, posY - 2, bgWidth + 4, bgHeight + 4, 0xFFE01C47)
                end

                if not ovlPushM.isDragging and mouseDown then
                    if mx >= posX and mx <= posX + bgWidth and my >= posY and my <= posY + bgHeight then
                        ovlPushM.isDragging = true
                        ovlPushM.dragOffset.x = mx - posX
                        ovlPushM.dragOffset.y = my - posY
                    end
                end

                if ovlPushM.isDragging then
                    if mouseDown then
                        settings.overlayPushMPos.x = mx - ovlPushM.dragOffset.x
                        settings.overlayPushMPos.y = my - ovlPushM.dragOffset.y
                    else
                        ovlPushM.isDragging = false
                        saveSettings()
                    end
                end

                if isKeyJustPressed(VK_ESCAPE) then
                    ovlPushM.editPos = false
                    ovlPushM.isDragging = false
                    showCursor(false)
                    if ovlPushM.hide then ovlPushM.hide() end
                    saveSettings()
                end
            end

            -- 2. Отрисовка фона
            if renderDrawBoxRounded then
                renderDrawBoxRounded(posX, posY, bgWidth, bgHeight, ovlPushM.radius, bgColor)
            else
                renderDrawBox(posX, posY, bgWidth, bgHeight, bgColor)
            end

            -- 3. Отрисовка вертикальной цветной полоски индикатора типа
            local currentTypeConfig = ovlPushM.types[ovlPushM.type] or ovlPushM.types.info
            local accentAlpha = bit.lshift(math.floor(currentAlpha * 255), 24)
            local accentColor = currentTypeConfig.accentColor + accentAlpha

            if renderDrawBoxRounded then
                renderDrawBoxRounded(posX + 4, posY + 6, 3, bgHeight - 12, 2, accentColor)
            else
                renderDrawBox(posX + 4, posY + 6, 3, bgHeight - 12, accentColor)
            end

            -- 4. Отрисовка текста
            local ty = posY + ovlPushM.padding
            for line in renderText:gmatch("[^\n]+") do
                ovlPushM.drawRichLine(posX + ovlPushM.padding + 6, ty, line, currentAlpha)
                ty = ty + lineHeight
            end
        end
    end
end)

-- Оверлей рыбной статистики
lua_thread.create(function()
    while true do
        if settings.overlayFish and sessionActive and sessionData then

            local screenX, screenY = getScreenResolution()
            local posX = settings.overlayFishPos.x or 15

            local posY
            if settings.overlayFishPos.y and settings.overlayFishPos.y ~= 0 then
                posY = settings.overlayFishPos.y
            else
                posY = math.floor(screenY / 2 - 50)
            end

            local elapsed = os.time() - sessionStartTime
            local timeText = string.format("%02d:%02d:%02d",
                math.floor(elapsed / 3600),
                math.floor((elapsed % 3600) / 60),
                elapsed % 60
            )

            local line1 = "Длительность: " .. timeText
            local line2 = "Поймано рыб: " .. tostring(sessionData.fish_caught)
            local line3 = "Предметы: " .. tostring(sessionData.items)

            local w = 0
            local function calc(text)
                w = math.max(w, renderGetFontDrawTextLength(ovlFish.font, text))
            end

            calc(line1)
            calc(line2)
            calc(line3)

            local width = w + 30
            local height = 80
			
            -- Отрисовка фона
            if settings.overlayFishBackground then
                renderDrawBox(posX, posY, width, height, ovlFish.colors.bgDefault)
            end

            -- Текст
            local y = posY + 8
            renderFontDrawText(ovlFish.font, line1, posX + 15, y, ovlFish.colors.text); y = y + ovlFish.lineSpacing
            renderFontDrawText(ovlFish.font, line2, posX + 15, y, ovlFish.colors.text); y = y + ovlFish.lineSpacing
            renderFontDrawText(ovlFish.font, line3, posX + 15, y, ovlFish.colors.text); y = y + ovlFish.lineSpacing
            
			-- Режим редактора
            if ovlFish.editPos then
                local mx, my = getCursorPos()
                local mouseDown = isKeyDown(VK_LBUTTON)

                drawAnimatedBorder(posX, posY, width, height, 2)
                renderDrawBox(posX, posY, width, height, ovlFish.colors.bgEdit)

                if not ovlFish.isDragging and mouseDown then
                    if mx >= posX and mx <= posX + width and my >= posY and my <= posY + height then
                        ovlFish.isDragging = true
                        ovlFish.dragOffset.x = mx - posX
                        ovlFish.dragOffset.y = my - posY
                    end
                end
                
                if ovlFish.isDragging then
                    if mouseDown then
                        settings.overlayFishPos.x = mx - ovlFish.dragOffset.x
                        settings.overlayFishPos.y = my - ovlFish.dragOffset.y
                    else
                        ovlFish.isDragging = false
                    end
                end
                
                if isKeyJustPressed(VK_ESCAPE) then
                    ovlFish.editPos = false
                    ovlFish.isDragging = false
                    showCursor(false)
                    if ovlPushM and ovlPushM.hide then ovlPushM.hide() end
                    saveSettings()
                end
            end
        end
        wait(0)
    end
end)

-- =========================
-- Основной цикл
-- =========================
function main()
    repeat wait(0) until isSampAvailable()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if result then nickname = sampGetPlayerNickname(id) end
	
	-- Регистрация команд
    sampRegisterChatCommand("fmenu", cmd_fmenu)
    sampRegisterChatCommand("fsettings", cmd_fsettings)
    sampRegisterChatCommand("fstats", cmd_fstats)
    sampRegisterChatCommand("fhelp", cmd_fhelp)
    sampRegisterChatCommand("fstart", cmd_fstart)
    sampRegisterChatCommand("fend", cmd_fend)
	
	-- Загрузка данных из файлов конфигурации
	loadSessions()
	loadSettings()

    while true do
        wait(0)

        -- Если скрипт ожидает нажатия клавиши для её смены
        if waitingKeyInputType then
            for k = 0, 255 do
                if k ~= 0x10 and k ~= 0x11 and k ~= 0x12 and 
                   k ~= 0xA0 and k ~= 0xA1 and k ~= 0xA2 and k ~= 0xA3 and k ~= 0xA4 and k ~= 0xA5 then
                    
                    if wasKeyPressed(k) then
                        local newKey = (k == 0x1B) and 0 or k -- Esc снимает клавишу (ставит 0)

                        if type(waitingKeyInputType) == "string" and settings.hotkeys[waitingKeyInputType] ~= nil then
                            settings.hotkeys[waitingKeyInputType] = newKey
                            saveSettings()
                            sampAddChatMessage("{FF1493}[Pixel XYZ Helper]: {35FF35}Клавиша успешно обновлена!", -1)
                            waitingKeyInputType = nil
                            ovlPushM.hide()
                        end
                        break
                    end
                end
            end
        else
            -- Автоматическая проверка открытия окон по горячим клавишам
            for windowName, targetKey in pairs(settings.hotkeys) do
                if targetKey and targetKey ~= 0 and wasKeyPressed(targetKey) then
                    if window[windowName] then
                        window[windowName][0] = not window[windowName][0]
                    end
                end
            end
        end
    end
end

-- =========================
-- Сообщение при запуске
-- =========================
lua_thread.create(function()
    wait(4000)
	sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Автор скрипта: {FFD700}%s", authorName), -1)
	sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Последнее обновление: {FFD700}%s", lastdateUpdate), -1)
    sampAddChatMessage(string.format("{78DBE2}[Pixel FH]: {FFFFFF}Скрипт загружен! %s - меню.", keyToName(settings.hotkeys.mainMenu)), -1)
	sampAddChatMessage("{78DBE2}[Pixel FH]: {FFFFFF}Альтернативный способ открытия меню доступен по команде /fmenu.", -1)
	sampAddChatMessage("{78DBE2}[Pixel FH]: {FFFFFF}Открыть окно помощи, просмотр всех доступных команд /fhelp.", -1)
end)
