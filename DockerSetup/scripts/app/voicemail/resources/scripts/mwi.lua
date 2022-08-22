--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include the lua script
	require "resources.functions.config";

--define general settings
	sleep = 300;

--define the run file
	run_file = scripts_dir .. "/run/voicemail-mwi.tmp";

--debug
	debug["sql"] = false;
	debug["info"] = false;

--only run the script a single time
	runonce = false;

--connect to the database
	local Database = require "resources.functions.database";
	dbh = Database.new('system');

--used to stop the lua service
	local file = assert(io.open(run_file, "w"));
	file:write("remove this file to stop the script");

--define the trim function
	require "resources.functions.trim";

--check if a file exists
	require "resources.functions.file_exists";

--send MWI NOTIFY message
	require "app.voicemail.resources.functions.mwi_notify";

--get message count for mailbox
	require "app.voicemail.resources.functions.message_count";

--create the api object
	api = freeswitch.API();

--run lua as a service
	while true do

		--exit the loop when the file does not exist
			if (not file_exists(run_file)) then
				freeswitch.consoleLog("NOTICE", run_file.." not found\n");
				break;
			end

		--Send MWI events for voicemail boxes with messages
			local sql = [[SELECT v.voicemail_id, v.voicemail_uuid, v.domain_uuid, d.domain_name, COUNT(*) AS message_count
				FROM v_voicemail_messages as m, v_voicemails as v, v_domains as d
				WHERE v.voicemail_uuid = m.voicemail_uuid
				AND v.domain_uuid = d.domain_uuid
				GROUP BY v.voicemail_id, v.voicemail_uuid, v.domain_uuid, d.domain_name;]];
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "\n");
			end
			dbh:query(sql, function(row)

				--get saved and new message counts
					local new_messages, saved_messages = message_count_by_uuid(
						row["voicemail_uuid"], row["domain_uuid"]
					)

				--send the message waiting event
					local account = row["voicemail_id"].."@"..row["domain_name"]
					mwi_notify(account, new_messages, saved_messages)

				--log to console
					if (debug["info"]) then
						freeswitch.consoleLog("notice", "[voicemail] mailbox: "..account.." messages: " .. (new_messages or "0") .. "/" .. (saved_messages or "0") .. " \n");
					end
			end);

		if (runonce) then
			freeswitch.consoleLog("notice", "mwi.lua has ended\n");
			break;
		else
			--slow the loop down
			os.execute("sleep "..sleep);
		end

	end
