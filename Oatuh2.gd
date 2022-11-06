extends Node
class_name Oauth2

#Parametros generales
var redirect_server := TCP_Server.new() 
const BINDING := "localhost"
const PORT := 8060
const BINDING_DESKTOP := "127.0.0.1"
const auth_server := "https://id.twitch.tv/oauth2/authorize"
const client_ID := "Your client ID"
const client_secret := "Your client secret"
const token_req := "https://id.twitch.tv/oauth2/token"
var refresh_token
var redirect_uri := ""
var response_type := ""
var token := ""

signal token_recieved

#Parametros para oauth en web
var redirect_uri_web := "http://%s:%s/tmp_js_export.html" % [BINDING, PORT]
var response_type_web = "token"

#Parametros para oauth en desktop
var redirect_uri_desktop := "http://%s:%s" % [BINDING, PORT]
var response_type_desktop = "code"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	set_process(false)
	
	if (OS.has_feature("web")):
		redirect_uri = redirect_uri_web
		response_type = response_type_web
		var location_hash = JavaScript.eval("window.location.hash")
		if !location_hash:
			get_auth_code()
		else:
			print(location_hash)
			token = get_token(location_hash)
			if token:
				emit_signal("token_recieved")
			else:
				print("No se pudo conseguir el token")
	else:
		redirect_uri = redirect_uri_desktop
		response_type = response_type_desktop
		get_auth_code()

func get_token(location_hash : String):
#	Devuelve algo parecido a esto
	#	#access_token=u79ssrh41hyshj77bul11xx50ej8g2&scope=chat%3Aread+chat%3Aedit&token_type=bearer
	var hash_params = location_hash.substr(1).split("&",false)
#	Lo dividimos por parametros con el separador &
	for hash_param in hash_params:
		print(hash_param)
#		Si es el access_token, pues devovlemos el valor
		var token_split = hash_param.split("=")
		if token_split:
			if token_split.size() == 2:
				if token_split[0] == "access_token":
					return token_split[1]
	
	return ""

func get_auth_code():

	if (!OS.has_feature("web")):
		set_process(true)
		var redir_err = redirect_server.listen(PORT, BINDING_DESKTOP)
	
	var body_parts = [
		"client_id=%s" % client_ID,
		"redirect_uri=%s" % redirect_uri,
		"response_type=%s" % response_type,
		"scope=chat%3Aread chat%3Aedit",
	]
	
	var url = auth_server + "?" + PoolStringArray(body_parts).join("&")
	
	if (OS.has_feature("web")):
		JavaScript.eval("window.location.replace('"+url+"')")
	else:
		OS.shell_open(url)

func _process(_delta):
	if redirect_server:
		if redirect_server.is_connection_available():
			var connection = redirect_server.take_connection()
			var request = connection.get_string(connection.get_available_bytes())
			if request:
				set_process(false)
				var auth_code = request.split("&scope")[0].split("=")[1]
				get_token_from_auth(auth_code)

				connection.put_data(("HTTP/1.1 %d\r\n" % 200).to_ascii())
				connection.put_data(load_HTML("<style>body{background-color:1A1A1A;position:absolute;top:50%;left:50%;-ms-transform:translate(-50%,-50%);transform:translate(-50%,-50%);text-align:center;vertical-align:middle;font-family:arial;font-size:24px;font-weight:700}</style><br><h2 style=color:e0e0e0>Success!</h2><h2 style=color:e0e0e0>Please close this tab and return to the application.</h2>").to_ascii())
				redirect_server.stop()

func load_HTML(page):
	var HTML = page.replace("    ", "\t").insert(0, "\n")
	return HTML
	
func get_token_from_auth(auth_code):
	
	var headers = [
		"Content-Type: application/x-www-form-urlencoded"
	]
	headers = PoolStringArray(headers)

	var body_parts = [
		"code=%s" % auth_code, 
		"client_id=%s" % client_ID,
		"client_secret=%s" % client_secret,
		"redirect_uri=%s" % redirect_uri,
		"grant_type=authorization_code"
	]

	var body = PoolStringArray(body_parts).join("&")

	# warning-ignore:return_value_discarded
	var http_request = HTTPRequest.new()
	add_child(http_request)

	var error = http_request.request(token_req, headers, true, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request with ERR Code: %s" % error)

	var response = yield(http_request, "request_completed")
	var response_body = parse_json(response[3].get_string_from_utf8())

	token = response_body["access_token"]
	refresh_token = response_body["refresh_token"]

	http_request = null
	
	emit_signal("token_recieved")
