local robot = require("robot")
local sides = require("sides")
local component = require("component")
local computer = require("computer")
local inventory_Controller = component.inventory_controller

local hole_Size = { -- Размер фермы
    length = 8,
    width = 6,
}

local robot_Settings = {
    action_Delay = 0, -- Задержка перед каждым действием
    base_Wait = 900, -- Сколько секунд робот будет стоять на базе перед следующим сбором (или стрижкой)
    tool_Name = "thermalfoundation:tool.shears_diamond", -- Название инструмента
    tool_Ignore = false, -- Игнорировать отсутствие инструмента
}



local navi_Data_Default = { -- НЕ ТРОГАТЬ
    x = 1,
    z = 0,
    last_Turn = "left",
    body_Rotation = "normal",
    navi_X = 1,
    navi_Z = 1,
}

local internal_Data = { -- НЕ ТРОГАТЬ
    return_Requested = false,
    internal_Inventory_Size = 16,
    works_Count = 0,
}



function clear_Navi()
    navi_Data = {}

    for key, value in pairs(navi_Data_Default) do
        navi_Data[key] = value
    end
end



function navi_Calculation(axis)
    if axis == "x" then -- Расчет координаты прохождения вперед
        if navi_Data["body_Rotation"] == "normal" then
            navi_Data["navi_X"] = navi_Data["navi_X"] + 1
        elseif navi_Data["body_Rotation"] == "backward" then
            navi_Data["navi_X"] = navi_Data["navi_X"] - 1
        end
    elseif axis == "z" then -- Расчет координаты сдвига робота в сторону
            navi_Data["navi_Z"] = navi_Data["navi_Z"] + 1
    elseif axis == "body_Rotation" then -- Расчет поворота робота
        if navi_Data["body_Rotation"] == "normal" then
            navi_Data["body_Rotation"] = "backward"
        elseif navi_Data["body_Rotation"] == "backward" then
            navi_Data["body_Rotation"] = "normal"
        end
    end
end



function inventory_Handling()
    robot.turnAround()

    local external_Inventory_Size = inventory_Controller.getInventorySize(sides.front)

    for int_Slot = 1, internal_Data["internal_Inventory_Size"] do
        robot.select(int_Slot)
        robot.drop()
    end

    robot.select(1)

    if not robot_Settings["tool_Ignore"] then
        local tool_Data, tool_String = robot.durability()

        if tool_String == "no tool equipped" then
            for ext_Slot = 1, external_Inventory_Size do
                local ext_Data = inventory_Controller.getStackInSlot(sides.front, ext_Slot)

                if ext_Data then
                    if ext_Data["name"] == robot_Settings["tool_Name"] then
                        inventory_Controller.suckFromSlot(sides.front, ext_Slot)
                        break
                    end
                end
            end

            inventory_Controller.equip()
        end
    end

    while ((computer.energy() + 500) < computer.maxEnergy()) do -- Спим пока уровень заряда ниже приемлимого
        os.sleep(1)
    end

    robot.turnAround()

    navi_To_Position()
    internal_Data["return_Requested"] = false
end



function return_Check()
    if not robot_Settings["tool_Ignore"] then
        local tool_Data, tool_String = robot.durability()

        if tool_String == "no tool equipped" then
            internal_Data["return_Requested"] = true
        end
    end

    if computer.energy() <= 10000 then
        internal_Data["return_Requested"] = true
    end


    if internal_Data["return_Requested"] then
        navi_To_Base()
        inventory_Handling()
    end
end



function right_Rotate()
    robot.turnRight()

    while not robot.forward() do -- Ждать пока путь не освободится
        os.sleep(1)
    end
    robot.useDown()

    robot.turnRight()
    navi_Calculation("z")
    navi_Calculation("body_Rotation")
    navi_Data["last_Turn"] = "right"
    navi_Data["z"] = navi_Data["z"] + 1

    os.sleep(robot_Settings["action_Delay"])
end



function left_Rotate()
    robot.turnLeft()

    while not robot.forward() do -- Ждать пока путь не освободится
        os.sleep(1)
    end
    robot.useDown()

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

    while not robot.forward() do -- Ждать пока путь не освободится
        os.sleep(1)
    end

    robot.useDown()
    navi_Calculation("x")
    navi_Data["x"] = navi_Data["x"] + 1

    os.sleep(robot_Settings["action_Delay"])
end



function navi_To_Position()
    for x_Pos = 0, (navi_Data["navi_X"] - 2) do
        while not robot.forward() do
            os.sleep(1)
        end
    end

    robot.turnRight()
    for z_Pos = 0, (navi_Data["navi_Z"] - 2) do
        while not robot.forward() do
            os.sleep(1)
        end
    end
    robot.turnLeft()

    if navi_Data["body_Rotation"] == "backward" then
        robot.turnAround()
    end
end



function navi_To_Base()
    if navi_Data["body_Rotation"] == "backward" then
        robot.turnAround()
    end

    robot.turnLeft()
    for z_Pos = (navi_Data["navi_Z"] - 2), 0, -1 do
        while not robot.forward() do
            os.sleep(1)
        end
    end
    robot.turnLeft()

    for x_Pos = (navi_Data["navi_X"] - 2), 0, -1 do
        while not robot.forward() do
            os.sleep(1)
        end
    end

    robot.turnAround()
end



clear_Navi()
print("Starting work in 3 second...")
os.sleep(3)



while true do
    if not internal_Data["return_Requested"] then
        if navi_Data["x"] < hole_Size["length"] then -- Если еще не дошли до конца линии едем вперед
            go_Forward()
        elseif navi_Data["x"] == hole_Size["length"] then -- Если дошли до конца линии, поворачиваем в противоположную сторону
            navi_Data["x"] = 1

            if navi_Data["last_Turn"] == "left" then
                right_Rotate()
            elseif navi_Data["last_Turn"] == "right" then
                left_Rotate()
            end
        end

        return_Check() -- Проверям надо ли вернуться

        if navi_Data["navi_X"] == 1 and navi_Data["navi_Z"] == hole_Size["width"] then -- Проверяем готова ли работа
            internal_Data["works_Count"] = internal_Data["works_Count"] + 1
            print(" ")
            print("Work is done. Work #" .. internal_Data["works_Count"])

            navi_To_Base()
            clear_Navi()
            inventory_Handling()

            os.sleep(robot_Settings["base_Wait"])
        end
    end
end