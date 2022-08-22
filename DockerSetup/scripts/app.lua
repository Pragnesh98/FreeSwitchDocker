--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


--include config.lua
	require "resources.functions.config";

--get the argv values
	script_name = argv[0];
	app_name = argv[1];

--example use command
	--luarun app.lua app_name 'a' 'b 123' 'c'

--for loop through arguments
	arguments = "";
	for key,value in pairs(argv) do
		if (key > 1) then
			arguments = arguments .. " '" .. value .. "'";
			--freeswitch.consoleLog("notice", "[app.lua] argv["..key.."]: "..argv[key].."\n");
		end
	end

--route the request to the application
	--freeswitch.consoleLog("notice", "["..app_name.."]".. scripts_dir .. "/app/" .. app_name .. "/index.lua\n");
	loadfile(scripts_dir .. "/app/" .. app_name .. "/index.lua")(argv);
