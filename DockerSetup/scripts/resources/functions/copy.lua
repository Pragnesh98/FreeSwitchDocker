--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--add the copy function
	function copy(src,dst)
		if (package.config:sub(1,1) == "/") then
			--unix
			cmd = [[cp "]] .. src .. [[" "]] .. dst .. [["]];
		elseif (package.config:sub(1,1) == [[\]]) then
			--windows
			src = src:gsub("/",[[\]]);
			dst = dst:gsub("/",[[\]]);
			cmd = [[copy "]] .. src .. [[" "]] ..dst.. [["]];
		end
		os.execute(cmd);
		return cmd;
	end
