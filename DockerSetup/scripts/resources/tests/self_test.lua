--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

local Cache    = require 'resources.functions.cache'
local Database = require 'resources.functions.database'

Database.__self_test__({
  "native",
  "luasql",
  "odbc",
  "odbcpool",
},
"system")

Cache._self_test()
