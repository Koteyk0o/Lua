local component = require("component")
local term = require('term')
local computer = require('computer')
local gpu = component.gpu
local screen = component.screen
if component.isAvailable('br_reactor') then
	reactor = component.br_reactor
else
	print('Reactor is not connected. Please connect computer to reactor computer port')
	os.exit()
end
if component.isAvailable('me_controller') then
	me_controller = component.me_controller
end
if component.isAvailable('energy_device') then
	eio_capacitor = component.energy_device
end



local display_Settings = {
	reactor_Control = false, -- Разрешить управление реактором
	reactor_Storage_Mode = false, -- Режим хранения реактора, программа всегда будет поддерживать ВЫКЛЮЧЕННОЕ состояние
	ME_Storage_Support = true, -- Поддержка внешнего хранилища (Расчет остатка времени работы с учетом топлива в хранилище, и вывод топлива в хранилище на экран)
	EIO_Capacitor_Support = true, -- Поддержка EnderIO (Вывод запаса энергии на экран)
	reactor_Percent_Off = 100, -- Процент заполнения батареи реактора при котором он автоматически выключится
	reactor_Percent_Hysteresis = 5, -- Гистерезис заполнения батареи реактора
	reactor_Name = 'Nexus-6', -- Имя реактора
}



local ME_Filter = {
	name = 'bigreactors:ingotyellorium' -- ID слитка йеллоурита
}

local raw_Data = {
	reactor_Active = false,
	reactor_State = 'Storage',
	reactor_Casing_Temp = 0,
	reactor_Fuel_Info = {
		fuelAmount = 0,
		fuelCapacity = 0,
		fuelConsumedLastTick = 0,
		fuelReactivity = 0,
		fuelTemperature = 0,
		wasteAmount = 0,
	},
	reactor_Energy_Info = {
		energyCapacity = 0,
		energyProducedLastTick = 0,
		energyStored = 0,
	},
	ME_Data = {},
	ME_Yellorium_Amount = 0,
	EIO_Capacity_Max = 0,
	EIO_Capacity_Current = 0,
}

local calculated_Data = {
	reactor_Casing_Temp = 0,
	fuel_Temp = 0,
	fuel_Consume = 0,
	ME_Fuel_Store = 0,
	ME_Support_String = '',
	EIO_Charge_Percent = 0,
	EIO_Charge_Capacity = 0,
	Total_Reactor_Fuel = 0,
	out_Of_Fuel = 0,
	time_Suffix = ' min',
	energy_Stored = 0,
	energy_Generation = 0,
	energy_Suffix = ' kRF/t',
	energy_Percent = 0,
	last_On_Sec = 0,
	last_On_Time = 0,
	last_On_Suffix = ' sec ago',
}



function support_Check()
	if display_Settings['ME_Storage_Support'] and not me_controller then
		print('ME Controller is not connected. ME Support turned Off.')
		display_Settings['ME_Storage_Support'] = false
		os.sleep(3)
	end
	
	if display_Settings['EIO_Capacitor_Support'] and not eio_capacitor then
		print('EnderIO capacitor is not connected. EnderIO Support turned Off.')
		display_Settings['EIO_Capacitor_Support'] = false
		os.sleep(3)
	end
end



function time_Calculation()
	if raw_Data['reactor_Active'] then
		calculated_Data['last_On_Sec'] = 0
		calculated_Data['last_On_Suffix'] = ' '
		calculated_Data['last_On_Time'] = 'Now'
	else
		calculated_Data['last_On_Sec'] = calculated_Data['last_On_Sec'] + 1
		
		if calculated_Data['last_On_Sec'] < 60 then
			calculated_Data['last_On_Suffix'] = ' sec ago'
			calculated_Data['last_On_Time'] = calculated_Data['last_On_Sec']
		elseif calculated_Data['last_On_Sec'] > 86400 then
			calculated_Data['last_On_Suffix'] = ' days ago'
			calculated_Data['last_On_Time'] = math.floor(calculated_Data['last_On_Sec'] / 86400)
		elseif calculated_Data['last_On_Sec'] > 3600 then
			calculated_Data['last_On_Suffix'] = ' hours ago'
			calculated_Data['last_On_Time'] = math.floor(calculated_Data['last_On_Sec'] / 3600)
		elseif calculated_Data['last_On_Sec'] >= 60 then
			calculated_Data['last_On_Suffix'] = ' min ago'
			calculated_Data['last_On_Time'] = math.floor(calculated_Data['last_On_Sec'] / 60)
		end
	end
end



function reactor_Control()
	if display_Settings['reactor_Storage_Mode'] then
		raw_Data['reactor_State'] = 'Storage'
		reactor.setActive(false)
	else
		
		if raw_Data['reactor_Fuel_Info']['fuelAmount'] > 0 then
			if display_Settings['reactor_Control'] then
				if calculated_Data['energy_Percent'] >= display_Settings['reactor_Percent_Off'] then
					reactor.setActive(false)
				elseif calculated_Data['energy_Percent'] <= display_Settings['reactor_Percent_Off'] - display_Settings['reactor_Percent_Hysteresis'] then
					reactor.setActive(true)
				end
			end
		else
			reactor.setActive(false)
		end
			
		if raw_Data['reactor_Active'] then
			raw_Data['reactor_State'] = 'On'
		else
			raw_Data['reactor_State'] = 'Off'
		end
		
		if raw_Data['reactor_Fuel_Info']['fuelAmount'] == 0 then
			raw_Data['reactor_State'] = 'Out_Fuel'
		end
	end
end



function data_Collector()
	if component.isAvailable('br_reactor') then
		raw_Data['reactor_Active'] = reactor.getActive()
		raw_Data['reactor_Casing_Temp'] = reactor.getCasingTemperature()
		raw_Data['reactor_Fuel_Info'] = reactor.getFuelStats()
		raw_Data['reactor_Energy_Info'] = reactor.getEnergyStats()
		
		reactor_Control()
		data_Calculation()
	else
		time_Calculation()
	end
	
	if component.isAvailable('me_controller') then
		raw_Data['ME_Data'] = me_controller.getItemsInNetwork(ME_Filter)
		
		if raw_Data['ME_Data'][1] then -- Топ фикс ин зе ворлд
			raw_Data['ME_Yellorium_Amount'] = raw_Data['ME_Data'][1]['size']
		else
			raw_Data['ME_Yellorium_Amount'] = 0
		end
	end
	
	if component.isAvailable('energy_device') then
		raw_Data['EIO_Capacity_Current'] = eio_capacitor.getEnergyStored()
		raw_Data['EIO_Capacity_Max'] = eio_capacitor.getMaxEnergyStored()
	end
end



function data_Calculation()
	calculated_Data['reactor_Casing_Temp'] = math.floor(raw_Data['reactor_Casing_Temp'])
	calculated_Data['fuel_Temp'] = math.floor(raw_Data['reactor_Fuel_Info']['fuelTemperature'])
	calculated_Data['fuel_Consume'] = math.floor((((raw_Data['reactor_Fuel_Info']['fuelConsumedLastTick'] * 25) * 60) / 1000) * 100) / 100
	calculated_Data['energy_Stored'] = math.floor(raw_Data['reactor_Energy_Info']['energyStored'] / 1000)
	calculated_Data['energy_Generation'] = raw_Data['reactor_Energy_Info']['energyProducedLastTick']
	calculated_Data['energy_Percent'] = math.floor((raw_Data['reactor_Energy_Info']['energyStored'] / raw_Data['reactor_Energy_Info']['energyCapacity']) * 100)
	calculated_Data['EIO_Charge_Capacity'] = math.floor(raw_Data['EIO_Capacity_Current'] / 1000)
	calculated_Data['EIO_Charge_Percent'] = math.floor((raw_Data['EIO_Capacity_Current'] / raw_Data['EIO_Capacity_Max']) * 100)
	
	if display_Settings['ME_Storage_Support'] then
		calculated_Data['Total_Reactor_Fuel'] = raw_Data['reactor_Fuel_Info']['fuelAmount'] + raw_Data['ME_Yellorium_Amount'] * 1000
	else
		calculated_Data['Total_Reactor_Fuel'] = raw_Data['reactor_Fuel_Info']['fuelAmount']
	end
	
	if raw_Data['reactor_Active'] then
		local time_To_Reactor_Stop = (((calculated_Data['Total_Reactor_Fuel'] / raw_Data['reactor_Fuel_Info']['fuelConsumedLastTick']) / 25) / 60)
		
		if time_To_Reactor_Stop < 60 then
			calculated_Data['out_Of_Fuel'] = math.floor(time_To_Reactor_Stop)
			calculated_Data['time_Suffix'] = ' min'
		elseif time_To_Reactor_Stop > 3600 then
			calculated_Data['out_Of_Fuel'] = math.floor(time_To_Reactor_Stop / 3600)
			calculated_Data['time_Suffix'] = ' days'
		elseif time_To_Reactor_Stop >= 60 then
			calculated_Data['out_Of_Fuel'] = math.floor(time_To_Reactor_Stop / 60)
			calculated_Data['time_Suffix'] = ' hours'
		end
	else
		calculated_Data['out_Of_Fuel'] = '---'
		calculated_Data['time_Suffix'] = ' '
	end
	
	if raw_Data['reactor_Energy_Info']['energyProducedLastTick'] > 1000 then
		calculated_Data['energy_Generation'] = math.floor(raw_Data['reactor_Energy_Info']['energyProducedLastTick'] / 1000)
		calculated_Data['energy_Suffix'] = ' kRF/t'
	else
		calculated_Data['energy_Generation'] = math.floor(raw_Data['reactor_Energy_Info']['energyProducedLastTick'])
		calculated_Data['energy_Suffix'] = ' RF/t'
	end
	
	if display_Settings['ME_Storage_Support'] then
		calculated_Data['ME_Support_String'] = '(' .. raw_Data['ME_Yellorium_Amount'] .. 'k mB in ME' .. ')'
	else
		calculated_Data['ME_Support_String'] = ''
	end
	
	time_Calculation()
end



function draw_On_Screen()
	term.clear()
	gpu.setForeground(0xffffff)
	local x, y = 1, 1
	
	gpu.set(x, y, 'Reactor Name: ' .. display_Settings['reactor_Name'])
	y = y + 2
	
	gpu.set(x, y, 'Reactor State: ')
	y = y + 2
	
	gpu.set(x, y, 'Generation: ' .. calculated_Data['energy_Generation'] .. calculated_Data['energy_Suffix'])
	y = y + 2
	
	gpu.set(x, y, 'Available Fuel: ' .. raw_Data['reactor_Fuel_Info']['fuelAmount'] .. ' / ' .. raw_Data['reactor_Fuel_Info']['fuelCapacity'] .. ' mB ' .. calculated_Data['ME_Support_String'])
	y = y + 2
	
	gpu.set(x, y, 'Fuel Consume: ' .. calculated_Data['fuel_Consume'] .. ' Ingot / min')
	y = y + 2
	
	gpu.set(x, y, 'Out Of Fuel: ' .. calculated_Data['out_Of_Fuel'] .. calculated_Data['time_Suffix'])
	y = y + 2
	
	gpu.set(x, y, 'Reactor Capacity: ' .. calculated_Data['energy_Stored'] .. ' kRF ' .. '(' .. calculated_Data['energy_Percent'] .. '%)')
	y = y + 2
	
	if display_Settings['EIO_Capacitor_Support'] then
		gpu.set(x, y, 'Battery Capacity: ' .. calculated_Data['EIO_Charge_Capacity'] .. ' kRF ' .. '(' .. calculated_Data['EIO_Charge_Percent'] .. '%)')
		y = y + 2
	end
	
	gpu.set(x, y, 'Reactor Last ON: ' .. calculated_Data['last_On_Time'] .. calculated_Data['last_On_Suffix'])
	y = y + 2
	
	if raw_Data['reactor_State'] == 'On' then
		gpu.setForeground(0x00ff00)
		gpu.set(16, 3, 'ON')
	elseif raw_Data['reactor_State'] == 'Off' then
		gpu.setForeground(0xff0000)
		gpu.set(16, 3, 'OFF')
	elseif raw_Data['reactor_State'] == 'Storage' then
		gpu.setForeground(0xfffa00)
		gpu.set(16, 3, 'Storage Mode')
	elseif raw_Data['reactor_State'] == 'Out_Fuel' then
		gpu.setForeground(0xfffa00)
		gpu.set(16, 3, 'Out Of Fuel')
	end
end



function resolution_Calculation()
	local x, y = 52, 15

	if display_Settings['EIO_Capacitor_Support'] then
		y = y + 2
	end
	
	gpu.setResolution(x, y)
end



support_Check()
resolution_Calculation()
term.clear()
while true do
	data_Collector()
	draw_On_Screen()
	os.sleep(1)
end
