#!KAMAILIO
##!define WITH_DEBUG
#!define WITH_PGSQL
#!define WITH_AUTH
#!define WITH_IPAUTH
#!define WITH_USRLOCDB
#!define WITH_NAT
#!define WITH_ANTIFLOOD
#!define WITH_ACCDB
#!define WITH_CFGLUA
#!define WITH_VOICEMAIL
#!define WITH_FREESWITCH
#!define WITH_PBX
#!define WITH_XHTTP
# #!define WITH_PRESENCE
#!define WITH_ALIASDB
#!define WITH_NATSIPPING
#!define WITH_MULTIDOMAIN
#!define WITH_TLS
#!define WITH_LOADBALANCE
#!define WITH_WEBSOCKETS
#!define WITH_PSTN
#!define WITH_XMLRPC
#!define WITH_REGISTRAR
#!define WITH_RLS
#!define WITH_UUID
# #!define WITH_ASYNC

##-------------------------------- Binding Kamailio Instance --------------------------------##

#!substdef "!MY_IP_ADDR!172.31.23.44!g"
#!substdef "!EXTERNAL_IP!13.36.87.234!g"
#!substdef "!MY_UDP_PORT!5060!g"
#!substdef "!MY_TCP_PORT!5060!g"
#!substdef "!MY_TLS_PORT!5061!g"
#!substdef "!MY_WS_PORT!5066!g"
#!substdef "!MY_WSS_PORT!7443!g"
#!substdef "!MY_UDP_ADDR!udp:MY_IP_ADDR:MY_UDP_PORT!g"
#!substdef "!MY_TCP_ADDR!tcp:MY_IP_ADDR:MY_TCP_PORT!g"
#!substdef "!MY_TLS_ADDR!tls:MY_IP_ADDR:MY_TLS_PORT!g"
#!substdef "!MY_WS_ADDR!tcp:MY_IP_ADDR:MY_WS_PORT!g"
#!substdef "!MY_WSS_ADDR!tls:MY_IP_ADDR:MY_WSS_PORT!g"

#!define DB_QUERY_TIMEOUT 5

##--------------------------------- Data Bases Settings ------------------------------------##

#!define DBURL "postgres://postgres:BngrpF2vAqIdn4MbTVTUVUO9I@65.2.67.84:5432/kamailio"
#!define KAMDBH "ca=>postgres://postgres:BngrpF2vAqIdn4MbTVTUVUO9I@65.2.67.84:5432/kamailio"
#!define UCALLDBH "dbh=>postgres://postgres:BngrpF2vAqIdn4MbTVTUVUO9I@65.2.67.84:5432/ucall"

##---------------------------- Include Local Config If Exists -------------------------------##
import_file "kamailio-local.cfg"

##---------------------------------- Defined Values -----------------------------------------##

#!ifdef WITH_MULTIDOMAIN
#!define MULTIDOMAIN 1
#!else
#!define MULTIDOMAIN 0
#!endif

#!define FLT_ACC 1
#!define FLT_ACCMISSED 2
#!define FLT_ACCFAILED 3
#!define FLT_NATS 5
#!define FLT_DLG 9
#!define FLT_DLGINFO 10

#!define FLB_NATB 6
#!define FLB_NATSIPPING 7

#!define TRUSTED_ADR_GR_SBC    "2"
#!define TRUSTED_ADR_GR_FS     "1"

#!define FLAG_FROM_FS   11
#!define FLAG_FROM_SBC  12

#!define DEFAULT_DISPATCHER_GRP   "1"
#!define DEFAULT_DISPATCHER_ALGR  "4"

#!define DS_PING_FROM  "sip:HEPTA@hepta.com"

listen=MY_UDP_ADDR advertise EXTERNAL_IP:MY_UDP_PORT
listen=MY_TCP_ADDR advertise EXTERNAL_IP:MY_TCP_PORT
listen=MY_TLS_ADDR advertise EXTERNAL_IP:MY_TLS_PORT
#listen=MY_WS_ADDR advertise EXTERNAL_IP:MY_WS_PORT
listen=MY_WSS_ADDR advertise EXTERNAL_IP:MY_WSS_PORT

##------------------------------------- Global Parameters -----------------------------------##

### LOG Levels: 3=DBG, 2=INFO, 1=NOTICE, 0=WARN, -1=ERR
#!ifdef WITH_DEBUG
debug=4
log_stderror=yes
#!else
debug=2
log_stderror=no
#!endif

memdbg=5
memlog=5

log_facility = LOG_LOCAL0
check_via = no	# (cmd. line: -v)
dns = no          # (cmd. line: -r)
rev_dns = no      # (cmd. line: -R)

async_workers = 1
children = 4
disable_tcp = no
auto_aliases = no
http_reply_parse = yes
use_dns_cache = no
server_signature = no

server_header="Server: HEPTA SBC"
user_agent_header = "User-Agent: HEPTA SBC"

#!ifdef WITH_CFGLUA
log_prefix="LUA {$rm}: "
#!endif

latency_cfg_log=2
latency_log=2
latency_limit_action=100000
latency_limit_db=200000
log_facility=LOG_LOCAL0
fork=yes
alias="hepta-media.heptadial.com"

#!ifdef WITH_TLS
enable_tls=yes
#!endif
tcp_max_connections=8192
tls_max_connections=65536
tcp_connection_lifetime = 3605
tcp_accept_no_cl = yes
tcp_rd_buf_size = 16384
tcp_clone_rcvbuf = 1

mem_safety = 1
tcp_send_timeout = 120
tcp_no_connect = 0
mem_join = 1

log_name = "proxy"
log_prefix = "[$rm:$ci]"

##--------------------------------- Custom Parameters --------------------------------------##
#!ifdef WITH_PSTN
pstn.gw_ip = "" desc "PSTN GW Address"
pstn.gw_port = "" desc "PSTN GW Port"
#!endif

#!ifdef WITH_VOICEMAIL
voicemail.srv_ip = "" desc "VoiceMail IP Address"
voicemail.srv_port = "5060" desc "VoiceMail Port"
#!endif

##----------------------------------- Modules Section ---------------------------------------##

/* set paths to location of modules (to sources or installation folders) */
# mpath="/usr/local/lib/kamailio/modules/"

loadmodule "db_postgres.so"
loadmodule "jsonrpcs.so"
loadmodule "kex.so"
loadmodule "corex.so"
loadmodule "tm.so"
loadmodule "tmx.so"
loadmodule "sl.so"
loadmodule "rr.so"
loadmodule "pv.so"
loadmodule "maxfwd.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "textops.so"
loadmodule "siputils.so"
loadmodule "xlog.so"
loadmodule "sanity.so"
loadmodule "ctl.so"
loadmodule "cfg_rpc.so"
loadmodule "acc.so"
loadmodule "kemix.so"
loadmodule "dispatcher.so"
loadmodule "carrierroute.so"
loadmodule "sqlops.so"
loadmodule "dialog.so"
loadmodule "uac.so"
loadmodule "keepalive.so"

#!ifdef WITH_AUTH
loadmodule "auth.so"
loadmodule "auth_db.so"
#!ifdef WITH_IPAUTH
loadmodule "permissions.so"
#!endif
#!endif

#!ifdef WITH_ALIASDB
loadmodule "alias_db.so"
#!endif

#!ifdef WITH_SPEEDDIAL
loadmodule "speeddial.so"
#!endif

#!ifdef WITH_MULTIDOMAIN
loadmodule "domain.so"
#!endif

#!ifdef WITH_PRESENCE
loadmodule "presence.so"
loadmodule "presence_xml.so"
loadmodule "presence_dialoginfo.so"
loadmodule "presence_mwi.so"
loadmodule "presence_afe.so"
loadmodule "pua.so"
loadmodule "pua_dialoginfo.so"
# loadmodule "pua_usrloc.so"
#!endif

#!ifdef WITH_NAT
loadmodule "nathelper.so"
#loadmodule "rtpproxy.so"
#!endif

#!ifdef WITH_TLS
loadmodule "tls.so"
#!endif

#!ifdef WITH_DEBUG
loadmodule "debugger.so"
#!endif

#!ifdef WITH_XMLRPC
loadmodule "xmlrpc.so"
#!endif

#!ifdef WITH_ANTIFLOOD
loadmodule "htable.so"
loadmodule "pike.so"
#!endif

#!ifdef WITH_CFGLUA
loadmodule "app_lua.so"
#!endif

#!ifdef WITH_WEBSOCKETS
loadmodule "xhttp.so"
loadmodule "websocket.so"
#!endif

# ----------------- setting module-specific parameters ---------------

# ----- jsonrpcs params -----
modparam("jsonrpcs", "pretty_format", 1)

# ----- ctl params -----
modparam("ctl", "binrpc", "unix:/var/run/kamailio/kamailio_ctl")
modparam("ctl", "binrpc", "tcp:2049")

#------- keepalive params -------
modparam("keepalive", "ping_interval", 30)
modparam("keepalive", "ping_from", "sip:heptacall.com")

# ----- tm params -----
modparam("tm", "failure_reply_mode", 0)
modparam("tm", "remap_503_500", 0)
modparam("tm", "contacts_avp", "tm_contacts");
modparam("tm", "contact_flows_avp", "tm_contact_flows");
modparam("tm", "auto_inv_100", 1)
modparam("tm", "auto_inv_100_reason", "Trying")

# ----- rr params -----
modparam("rr", "enable_full_lr", 1)
modparam("rr", "append_fromtag", 1)

# ----- registrar params -----
modparam("registrar", "method_filtering", 1)
#modparam("registrar", "append_branches", 0)
#modparam("registrar", "max_contacts", 10)
modparam("registrar", "max_expires", 3600)
modparam("registrar", "gruu_enabled", 0)

# ----- acc params -----
modparam("acc", "early_media", 0)
modparam("acc", "report_ack", 0)
modparam("acc", "report_cancels", 0)
modparam("acc", "detect_direction", 0)
modparam("acc", "log_flag", FLT_ACC)
modparam("acc", "log_missed_flag", FLT_ACCMISSED)
modparam("acc", "log_extra",
	"src_user=$fU;src_domain=$fd;src_ip=$si;"
	"dst_ouser=$tU;dst_user=$rU;dst_domain=$rd")
modparam("acc", "failed_transaction_flag", FLT_ACCFAILED)

# --------- carrierroute -----------
modparam("carrierroute", "config_source", "db" )
modparam("carrierroute", "db_url", DBURL)
modparam("carrierroute", "carrierroute_table", "carrierroute")
modparam("carrierroute", "use_domain", 1)

#!ifdef WITH_ACCDB
modparam("acc", "db_flag", FLT_ACC)
modparam("acc", "db_missed_flag", FLT_ACCMISSED)
modparam("acc", "db_url", DBURL)
modparam("acc", "db_extra",
	"src_user=$fU;src_domain=$fd;src_ip=$si;"
	"dst_ouser=$tU;dst_user=$rU;dst_domain=$rd")
#!endif

# ----- usrloc params -----
modparam("usrloc", "preload", "location")
#!ifdef WITH_USRLOCDB
modparam("usrloc", "db_url", DBURL)
modparam("usrloc", "db_mode", 2)
modparam("usrloc", "use_domain", MULTIDOMAIN)
#!endif

# ----- auth_db params -----
#!ifdef WITH_AUTH
modparam("auth_db", "db_url", DBURL)
modparam("auth_db", "calculate_ha1", yes)
modparam("auth_db", "password_column", "password")
modparam("auth_db", "load_credentials", "")
modparam("auth_db", "use_domain", MULTIDOMAIN)

# ----- permissions params -----
#!ifdef WITH_IPAUTH
modparam("permissions", "db_url", DBURL)
modparam("permissions", "db_mode", 1)
#!endif
#!endif

# ----- alias_db params -----
#!ifdef WITH_ALIASDB
modparam("alias_db", "db_url", DBURL)
modparam("alias_db", "use_domain", MULTIDOMAIN)
#!endif

# ----- speeddial params -----
#!ifdef WITH_SPEEDDIAL
modparam("speeddial", "db_url", DBURL)
modparam("speeddial", "use_domain", MULTIDOMAIN)
#!endif

# ----- domain params -----
#!ifdef WITH_MULTIDOMAIN
modparam("domain", "db_url", DBURL)
/* register callback to match myself condition with domains list */
# modparam("domain", "register_myself", 1)
#!endif

# ----------- presence params -----------
#!ifdef WITH_PRESENCE
modparam("presence", "db_url", DBURL)
modparam("presence", "fs_db_url", FUS_DBURL)
modparam("presence", "pbx_db_url", FUS_DBURL)
modparam("presence", "server_address", PRESENCE_ADDR)
modparam("presence", "send_fast_notify", 1)
modparam("presence", "db_update_period", 20)
modparam("presence", "clean_period", 10)
modparam("presence", "max_expires", 14430)
modparam("presence", "subs_db_mode", 0)
modparam("presence", "fetch_rows", 1000)
modparam("presence", "sip_uri_match", 1)
modparam("presence", "local_log_level", 4)
modparam("presence", "local_log_facility", "LOG_LOCAL3")
modparam("presence", "seconds_per_ring", SECONDS_PER_RING)
modparam("presence", "min_ring_count", MINIMUM_RING_COUNT)
modparam("presence", "ring_count_based_user_agents", RING_BASED_ON_COUNT_USER_AGENTS)
modparam("presence", "ring_seconds_based_user_agents", RING_BASED_ON_SECONDS_USER_AGENTS)

# -------- presence_xml params -------------
modparam("presence_xml", "db_url", DBURL)
modparam("presence_xml", "force_active", 1)
modparam("presence_xml", "force_dummy_presence", 1)

# --------- presence_dialoginfo params ----------
modparam("presence_dialoginfo", "force_single_dialog", 0)
modparam("presence_dialoginfo", "force_dummy_dialog", 1)
modparam("presence_dialoginfo", "call_flow_feature_code_list", CALL_FLOW_FEATURE_CODE_LIST)
modparam("presence_dialoginfo", "call_park_feature_code_list", CALL_PARK_FEATURE_CODE_LIST)

# ---------- pau params --------------
modparam("pua", "db_url", DBURL)
modparam("pua", "db_mode", 0)
modparam("pua", "update_period", 20)
modparam("pua", "dlginfo_increase_version", 0)
modparam("pua", "reginfo_increase_version", 0)
modparam("pua", "check_remote_contact", 0)
modparam("pua", "fetch_rows", 1000)
modparam("pua", "outbound_proxy", OUTBOUND_PROXY)
modparam("pua", "db_url", DBURL)

# --------- pau_dialoginfo params ------------
modparam("pua_dialoginfo", "include_callid", 1)
modparam("pua_dialoginfo", "send_publish_flag", FLT_DLGINFO)
modparam("pua_dialoginfo", "caller_confirmed", 1)
modparam("pua_dialoginfo", "callee_trying", 1)
modparam("pua_dialoginfo", "include_tags", 1)
modparam("pua_dialoginfo", "override_lifetime", 10)
modparam("pua_dialoginfo", "pubruri_caller_dlg_var", "pubruri_caller")
modparam("pua_dialoginfo", "pubruri_callee_dlg_var", "pubruri_callee")
modparam("pua_dialoginfo", "call_park_feature_code_list", CALL_PARK_FEATURE_CODE_LIST)
modparam("pua_dialoginfo", "call_flow_feature_code_list", CALL_FLOW_FEATURE_CODE_LIST)
modparam("pua_dialoginfo", "internal_fs_port", LOCAL_ROUTING_FS_PORT)
modparam("pua_dialoginfo", "external_fs_port", PSTN_ROUTING_FS_PORT)
modparam("pua_dialoginfo", "sbc_ip_list", SBC_IP_LIST)
modparam("pua_dialoginfo", "db_url", DBURL)
modparam("pua_dialoginfo", "domain_list_hdr","Subscription-Domain-List")
modparam("pua_dialoginfo", "enable_special_call_handling",ENABLE_SPECIAL_CALL_HANDLING)
modparam("pua_dialoginfo", "call_pickup_feature_code_len",CALL_PICKUP_FEATURE_CODE_LEN)
modparam("pua_dialoginfo", "call_pickup_feature_codes",CALL_PICKUP_FEATURE_CODES)
modparam("pua_dialoginfo", "call_barge_feature_code_len",CALL_BARGE_FEATURE_CODE_LEN)
modparam("pua_dialoginfo", "call_barge_feature_codes",CALL_BARGE_FEATURE_CODES)
modparam("pua_dialoginfo", "call_park_no_refer_user_agents",CALL_PARK_NO_REFER_USER_AGENTS)
#modparam("pua_dialoginfo", "xcap_host",XCAP_HOST)
#modparam("pua_dialoginfo", "xcap_port",XCAP_PORT)
modparam("pua_dialoginfo", "supported_call_types",CALL_TYPES_FOR_MONITOR)

# modparam("pua_usrloc", "default_domain", DEFAULT_DOMAIN)
# modparam("pua_usrloc", "branch_flag", FLT_DLGINFO)
#!endif

# --------- uac params -------------
modparam("uac","auth_username_avp","$avp(auser)")
modparam("uac","auth_password_avp","$avp(apass)")
modparam("uac","auth_realm_avp","$avp(arealm)")
modparam("uac","reg_db_url",DBURL)
modparam("uac", "reg_contact_addr", "13.36.87.234:5060")

# --------- dialog params ----------
modparam("dialog", "dlg_flag", FLT_DLG)
modparam("dialog", "dlg_match_mode", 1)
modparam("dialog", "detect_spirals", 1)
modparam("dialog", "db_url", DBURL)
modparam("dialog", "db_mode", 1)
modparam("dialog", "enable_stats", 1)
modparam("dialog", "track_cseq_updates", 1)

#!ifdef WITH_NAT
# ----- rtpproxy params -----
#modparam("rtpproxy", "rtpproxy_sock", "udp:127.0.0.1:7722")

# ----- nathelper params -----
modparam("nathelper", "natping_interval", 30)
modparam("nathelper", "ping_nated_only", 1)
modparam("nathelper", "sipping_bflag", FLB_NATSIPPING)
modparam("nathelper", "sipping_from", "sip:pinger@kamailio.org")
modparam("nathelper|registrar", "received_avp", "$avp(RECEIVED)")
modparam("usrloc", "nat_bflag", FLB_NATB)
#!endif

#!ifdef WITH_TLS
# ----- tls params -----
modparam("tls", "config", "/etc/kamailio/tls.cfg")
modparam("tls", "tls_force_run", 11)
#!endif

#!ifdef WITH_DEBUG
# ----- debugger params -----
modparam("debugger", "cfgtrace", 1)
#!endif

#!ifdef WITH_ANTIFLOOD
# ----- pike params -----
modparam("pike", "sampling_time_unit", 2)
modparam("pike", "reqs_density_per_unit", 16)
modparam("pike", "remove_latency", 4)

# ----- htable params -----
modparam("htable", "htable", "ipban=>size=8;autoexpire=300;")
#!endif

#!ifdef WITH_XMLRPC
# ----- xmlrpc params -----
modparam("xmlrpc", "route", "XMLRPC");
modparam("xmlrpc", "url_match", "^/RPC")
#!endif

#!ifdef WITH_WEBSOCKETS
# ---------- websocket params ---------
modparam("websocket", "keepalive_mechanism", 1)
modparam("websocket", "keepalive_timeout", 30)
modparam("websocket", "keepalive_processes", 1)
modparam("websocket", "keepalive_interval", 1)
modparam("websocket", "verbose_list", 1)
modparam("websocket", "cors_mode", 2)
#!endif

# --------- dispatcher params ------------
modparam("dispatcher","db_url", DBURL)
modparam("dispatcher", "table_name", "dispatcher")
modparam("dispatcher", "flags", 2)
modparam("dispatcher", "setid_col", "setid")
modparam("dispatcher", "destination_col", "destination")
modparam("dispatcher", "flags_col", "flags")
modparam("dispatcher", "priority_col", "priority")
modparam("dispatcher", "ds_ping_from", DS_PING_FROM)
modparam("dispatcher", "ds_ping_interval",60 )
modparam("dispatcher", "ds_probing_mode", 0)
modparam("dispatcher", "ds_ping_reply_codes", "class=4;code=503;code=408")
modparam("dispatcher", "force_dst", 1)
modparam("dispatcher", "ds_probing_threshold", 3)

# ----------  sqlops params -----------
modparam("sqlops", "sqlcon", KAMDBH)
modparam("sqlops", "sqlcon", UCALLDBH)

#!ifdef WITH_CFGLUA
# ----------- app_lua params -----------
modparam("app_lua", "load", "/etc/kamailio/kamailio-lua.lua")
cfgengine "lua"
#!endif

#!ifdef WITH_WEBSOCKETS
event_route[xhttp:request] {
	
	xlog("L_INFO","[hepta-cc] =>Event Route : [xhttp:request] Request [$rv] $rm => $hu\n");

	set_reply_close();
	set_reply_no_connect();

	if ($Rp != MY_WS_PORT && $Rp != MY_WSS_PORT) 
	{
		xlog("L_ERR","[hepta-cc] =>HTTP request Forbidden.\n");
		xhttp_reply("403", "Forbidden", "", "");
		exit;
	}
	
	xlog("L_INFO","[hepta-cc] =>HTTP request Received [RP:$Rp][HU:$hu]\n");

	if ($hdr(Upgrade) =~ "websocket" && $hdr(Connection) =~ "Upgrade" && $rm=~"GET") {
		if ($hdr(Host) == $null ) {
			xlog("L_ERR","[hepta-cc] =>Bad host $hdr(Host)\n");
			xhttp_reply("403", "Forbidden", "", "");
			exit;
		}

		if (ws_handle_handshake()) {
			xlog("L_INFO","[hepta-cc] =>WebSocket Connection Successful.\n");
			exit;
		}
    	}
	xlog("L_ERR","[hepta-cc] =>Invalid url[$hu][$Rp][$rb]\n");
	xhttp_reply("404", "Not found", "", "");
}

event_route[usrloc:contact-expired] {
	xlog("L_INFO","[hepta-cc] =>Expired contact for $ulc(exp=>aor)\n");
}

event_route[websocket:closed] {
	xlog("L_NOTICE","[hepta-cc] =>WebSocket connection from $si:$sp has closed\n");
}
#!endif

event_route[uac:reply] {
    xlog("L_INFO","[kamailio] =>received reply code is: $uac_req(evcode)\n");
}
