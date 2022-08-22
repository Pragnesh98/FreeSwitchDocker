--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--Description:
	--purpose: send an email
	--freeswitch.email(to, from, headers, body, file, convert_cmd, convert_ext)
		--to (mandatory) a valid email address
		--from (mandatory) a valid email address
		--headers (mandatory) for example "subject: you've got mail!\n"
		--body (optional) your regular mail body
		--file (optional) a file to attach to your mail
		--convert_cmd (optional) convert file to a different format before sending
		--convert_ext (optional) to replace the file's extension

--Example
	--luarun email.lua to@domain.com from@domain.com 'headers' 'subject' 'body'

--get the argv values
	script_name = argv[0];
	to = argv[1];
	from = argv[2];
	headers = argv[3];
	subject = argv[4];
	body = argv[5];
	file = argv[6];
	delete = argv[7];
	--convert_cmd = argv[8];
	--convert_ext = argv[9];

--replace the &#39 with a single quote
	body = body:gsub("&#39;", "'");

--replace the &#34 with double quote
	body = body:gsub("&#34;", [["]]);

--send the email
	if (file == nil) then
		freeswitch.email(to,
			from,
			"To: "..to.."\nFrom: "..from.."\nX-Headers: "..headers.."\nSubject: "..subject,
			body
			);
	else
		if (convert_cmd == nil) then
			freeswitch.email(to,
				from,
				"To: "..to.."\nFrom: "..from.."\nX-Headers: "..headers.."\nSubject: "..subject,
				body,
				file
				);
		else
			freeswitch.email(to,
				from,
				"To: "..to.."\nFrom: "..from.."\nX-Headers: "..headers.."\nSubject: "..subject,
				body,
				file,
				convert_cmd,
				convert_ext
				);
		end
	end

--delete the file
	if (delete == "true") then
		os.remove(file);
	end
