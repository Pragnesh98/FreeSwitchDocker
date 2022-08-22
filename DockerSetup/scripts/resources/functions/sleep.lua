--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


if freeswitch then

function sleep(ms)
  freeswitch.msleep(ms)
end

else

local socket = require "socket"

function sleep(ms)
  socket.sleep(ms/1000)
end

end
