--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


function is_absolute_path(file_name)
	return string.sub(file_name, 1, 1) == '/' or string.sub(file_name, 2, 1) == ':'
end

return is_absolute_path
