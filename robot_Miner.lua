local robot = require("robot")
local sides = require("sides")
local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local serialization = require('serialization')
local inventory_Controller = component.inventory_controller

local hole_Size = { -- Размер ямы для выкапывания
    length = 5,
    width = 5,
    height = 3,
}

local robot_Settings = {
    action_Delay = 0, -- Задержка перед каждым действием
    tool_Charging_Time = 10, -- Сколько секунд робот будет ждать зарядки инструмента
    tool_Keeping = true, -- Возврат для подзарядки инструмента
    inventory_Keeping = true, -- Возврат для выкладывания вещей
    navi_Data_Path = "/home/navi_Data.dat", -- Путь для сохранения навигационных данных (лучше не трогать)
}



local navi_Data = { -- НЕ ТРОГАТЬ
    x = 1,
    y = 0,
    z = 0,
    last_Turn = "left",
    body_Rotation = "normal",
    total_Blocks = 0,
    task_Blocks = 0,
    navi_X = 1,
    navi_Y = 1,
    navi_Z = 1,
}

local internal_Data = { -- НЕ ТРОГАТЬ
    return_Requested = false,
    program_Pause = false,
    internal_Inventory_Size = 0,
    tool_Charging_Count = 0,
    inventory_Clear_Count = 0,
    battery_Charging_Count = 0,
}



function save_Navi() -- Сохранение навигационных данных на жесткий диск
	local file = io.open(robot_Settings["navi_Data_Path"], "w")
	file:write(serialization.serialize(navi_Data))
	file:close()
end



function read_Navi() -- Чтение навигационных данных с жесткого диска
    local file = io.open(robot_Settings["navi_Data_Path"], 'r')
    navi_Data = serialization.unserialize(file:read("*a"))
    file:close()
end



function navi_Calculation(axis)
    if axis == "x" then -- Расчет координаты прохождения вперед
        if navi_Data["body_Rotation"] == "normal" then
            navi_Data["navi_X"] = navi_Data["navi_X"] + 1
        elseif navi_Data["body_Rotation"] == "backward" then
            navi_Data["navi_X"] = navi_Data["navi_X"] - 1
        end
    elseif axis == "y" then -- Расчет координаты сдвига вниз
        navi_Data["navi_Y"] = navi_Data["navi_Y"] - 1
    elseif axis == "z" then -- Расчет координаты сдвига робота в сторону
        if (navi_Data["navi_Y"] + 1) % 2 == 0 then
            navi_Data["navi_Z"] = navi_Data["navi_Z"] + 1
        else
            navi_Data["navi_Z"] = navi_Data["navi_Z"] - 1
        end
    elseif axis == "body_Rotation" then -- Расчет поворота робота
        if navi_Data["body_Rotation"] == "normal" then
            navi_Data["body_Rotation"] = "backward"
        elseif navi_Data["body_Rotation"] == "backward" then
            navi_Data["body_Rotation"] = "normal"
        end
    end
end



function inventory_Handling()
    local external_Inventory_Size = inventory_Controller.getInventorySize(sides.top)
    local tool_Charge = 1
    local tool_On_Charge = false

    if robot.durability() <= 0.12 then -- Если бур надо заряжать - заряжаем
        robot.select(1)
        inventory_Controller.equip()
        inventory_Controller.dropIntoSlot(sides.front, 1)

        tool_On_Charge = true
    end

    for int_Slot = 1, internal_Data["internal_Inventory_Size"] do -- Для каждой ячейки инвентаря робота
        robot.select(int_Slot)

        for ext_Slot = 1, external_Inventory_Size do
            if robot.count(int_Slot) == 0 then -- Если нашли пустую ячейку ломаем цикл, не надо терять время
                break
            end

            if not inventory_Controller.getStackInSlot(sides.top, ext_Slot) then -- Искать пустую ячейку сундука
                inventory_Controller.dropIntoSlot(sides.top, ext_Slot)
                break -- В случае успешной выкладки прервать цикл для экономии времени
            end
        end
    end

    robot.select(1)

    if tool_On_Charge then -- Если был инструмент на зарядке
        while tool_Charge > 0 do -- Спим пока уровень заряда инструмента ниже приемлимого
            if inventory_Controller.getStackInSlot(sides.front, 1) then
                tool_Charge = inventory_Controller.getStackInSlot(sides.front, 1)["damage"]
            end

            os.sleep(1)
        end

        inventory_Controller.suckFromSlot(sides.front, 1) -- Забираем бур с зарядки
        inventory_Controller.equip()
    end
end



function robot_Care()
    robot.turnAround() -- Надо развернуться для взаимодействия с МФСУ
    inventory_Handling() -- Взаимодействуем с инвентарем
    robot.turnAround() -- Надо развернуться обратно для выезда обратно

    while ((computer.energy() + 500) < computer.maxEnergy()) do -- Спим пока уровень заряда ниже приемлимого
        os.sleep(1)
    end

    navi_To_Position() -- Возвращаемся обратно
    internal_Data["return_Requested"] = false
end



function return_Check()
    if robot_Settings["tool_Keeping"] then
        if robot.durability() <= 0.12 then
            internal_Data["return_Requested"] = true
            internal_Data["tool_Charging_Count"] = internal_Data["tool_Charging_Count"] + 1
        end
    end

    if robot_Settings["inventory_Keeping"] then
        if robot.count(internal_Data["internal_Inventory_Size"]) > 0 then
            internal_Data["return_Requested"] = true
            internal_Data["inventory_Clear_Count"] = internal_Data["inventory_Clear_Count"] + 1
        end
    end

    if computer.energy() <= 10000 then
        internal_Data["return_Requested"] = true
        internal_Data["battery_Charging_Count"] = internal_Data["battery_Charging_Count"] + 1
    end

    if internal_Data["return_Requested"] then
        navi_To_Base()
        robot_Care()
    end
end



function right_Rotate()
    robot.turnRight()

    while not robot.forward() do -- Бить блок впереди пока путь не освободится
        robot.swing(sides.left)
    end

    robot.turnRight()
    navi_Calculation("z")
    navi_Calculation("body_Rotation")
    navi_Data["last_Turn"] = "right"
    navi_Data["z"] = navi_Data["z"] + 1

    os.sleep(robot_Settings["action_Delay"])
end



function left_Rotate()
    robot.turnLeft()

    while not robot.forward() do -- Бить блок впереди пока путь не освободится
        robot.swing(sides.left)
    end

    robot.turnLeft()
    navi_Calculation("z")
    navi_Calculation("body_Rotation")
    navi_Data["last_Turn"] = "left"
    navi_Data["z"] = navi_Data["z"] + 1

    os.sleep(robot_Settings["action_Delay"])
end



function go_Forward()
    if navi_Data["x"] == 0 then
        navi_Data["x"] = 1
    end

    robot.swing(sides.front)
    if robot.forward() then
        navi_Calculation("x")
        navi_Data["x"] = navi_Data["x"] + 1
        navi_Data["total_Blocks"] = navi_Data["total_Blocks"] + 1
    else
        robot.swing(sides.front)
    end

    os.sleep(robot_Settings["action_Delay"])
end



function go_Descent()
    while not robot.forward() do -- Бить блок впереди пока путь не освободится
        robot.swing(sides.front)
    end

    while not robot.down() do -- Бить блок снизу пока путь не освободится
        robot.swingDown()
    end

    navi_Calculation("x")
    navi_Calculation("y")
    navi_Calculation("body_Rotation")
    navi_Data["y"] = navi_Data["y"] + 1
    navi_Data["total_Blocks"] = navi_Data["total_Blocks"] + 2

    os.sleep(robot_Settings["action_Delay"])
end



function go_Backwards()
    robot.turnAround()

    os.sleep(robot_Settings["action_Delay"])
end



function navi_To_Position()
    for x_Pos = 0, (navi_Data["navi_X"] - 2) do
        while not robot.forward() do
            robot.swing(sides.front)
        end
    end

    robot.turnRight()
    for z_Pos = 0, (navi_Data["navi_Z"] - 2) do
        while not robot.forward() do
            robot.swing(sides.front)
        end
    end
    robot.turnLeft()

    for y_Pos = navi_Data["navi_Y"], 0 do
        while not robot.down() do
            robot.swingDown()
        end
    end

    if navi_Data["body_Rotation"] == "backward" then
        robot.turnAround()
    end
end



function navi_To_Base()
    if navi_Data["body_Rotation"] == "backward" then
        robot.turnAround()
    end

    for y_Pos = navi_Data["navi_Y"], 0 do
        while not robot.up() do
            robot.swingUp()
        end
    end

    robot.turnLeft()
    for z_Pos = (navi_Data["navi_Z"] - 2), 0, -1 do
        while not robot.forward() do
            robot.swing(sides.front)
        end
    end
    robot.turnLeft()

    for x_Pos = (navi_Data["navi_X"] - 2), 0, -1 do
        while not robot.forward() do
            robot.swing(sides.front)
        end
    end

    robot.turnAround()
end



function work_Is_Done()
    print("                      ")
    print("Tool charging count   ", internal_Data["tool_Charging_Count"])
    print("Inventory clear count ", internal_Data["inventory_Clear_Count"])
    print("Battery charge count  ", internal_Data["battery_Charging_Count"])
    print("                      ")
    print("Work is done")
    print("Return to base...")
end



function start_Mining()
    navi_Data["task_Blocks"] = hole_Size["length"] * hole_Size["width"] * hole_Size["height"]
    internal_Data["internal_Inventory_Size"] = robot.inventorySize()

    if fs.exists(robot_Settings["navi_Data_Path"]) then
        print("An incomplete operation was found. Continue the operation? Enter Y or N")
    
        local user_Answer = io.read()

        if (user_Answer == "Y") or (user_Answer == "y") then
            print("Ok. Return to the previous point and work will begin in 5 seconds...")
            --os.sleep(5)
            read_Navi()
            navi_To_Position()
        elseif (user_Answer == "N") or (user_Answer == "n") then
            print("OK. The previous route has been deleted")
            fs.remove(robot_Settings["navi_Data_Path"])
        else
            print("I did not understand the answer")
            os.exit()
        end
    end
    
    print("Mining starts in 5 seconds...")
    print("Job: ", navi_Data["task_Blocks"], " blocks")
    os.sleep(5)
end



start_Mining()



while true do
    local _, _, _, code, _ = event.pull(0, "key_down")

    if not internal_Data["program_Pause"] then
        if not internal_Data["return_Requested"] then
            if (navi_Data["x"] + 1) >= hole_Size["length"] and (navi_Data["z"] + 1) >= hole_Size["width"] then -- Если первый слой готов, опускаемся вниз
                navi_Data["x"] = 0
                navi_Data["z"] = 0
                go_Descent()
                go_Backwards()
            end

            if navi_Data["x"] < hole_Size["length"] then -- Если еще не дошли до конца линии едем вперед
                go_Forward()
            elseif navi_Data["x"] == hole_Size["length"] then -- Если дошли до конца линии, поворачиваем в противоположную сторону
                navi_Data["x"] = 0

                if navi_Data["last_Turn"] == "left" then
                    right_Rotate()
                elseif navi_Data["last_Turn"] == "right" then
                    left_Rotate()
                end
            end

            return_Check() -- Проверям надо ли вернуться

            if (navi_Data["navi_X"] + 1) >= hole_Size["length"] and navi_Data["navi_Z"] >= hole_Size["width"] and navi_Data["y"] >= hole_Size["height"] then -- Проверяем готова ли работа
                work_Is_Done()
                os.sleep(3)
                navi_To_Base()
                break
            end
        end
    end

    if code == 19 then -- Если нажали кнопку R
        print("Saving navi data and return to base")
        save_Navi()
        navi_To_Base()
        work_Is_Done()
        break
    elseif code == 25 then -- Если нажали кнопку P
        if internal_Data["program_Pause"] then
            internal_Data["program_Pause"] = false
            print("Mining resumed")
            os.sleep(0.5)
        else
            internal_Data["program_Pause"] = true
            print("Mining paused")
            os.sleep(0.5)
        end
    end
	
	if computer.energy() <= 500 then -- Если батарея села полностью, сохраняем маршрут и выключаемся
		save_Navi()
		computer.shutdown()
	end
end
