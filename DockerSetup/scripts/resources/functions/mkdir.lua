--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


--add the mkdir function
	function mkdir(dir)
		api = freeswitch.API();
		dir = dir:gsub([[\]], "/");
		if (package.config:sub(1,1) == "/") then
			--unix
			cmd = [[mkdir -p "]] .. dir .. [["]];
		elseif (package.config:sub(1,1) == [[\]]) then
			--windows
			cmd = [[mkdir "]] .. dir .. [["]];
		end
		-- os.execute(cmd);
		api:executeString("system " .. cmd  );
		return cmd;
	end
