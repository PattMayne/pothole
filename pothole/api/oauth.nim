# Copyright © penguinite 2024 <penguinite@tuta.io>
#
# This file is part of Pothole.
# 
# Pothole is free software: you can redistribute it and/or modify it under the terms of
# the GNU Affero General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
# 
# Pothole is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
# for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with Pothole. If not, see <https://www.gnu.org/licenses/>. 
# api/oauth.nim:
## This module contains all the routes for the oauth method in the api


# From somewhere in Quark
import quark/[strextra]

# From somewhere in Pothole
import pothole/[database, routeutils, conf]

# From somewhere in the standard library
import std/[json]
import std/strutils except isEmptyOrWhitespace, parseBool

# From nimble/other sources
import mummy

proc getSeparator(s: string): char =
  for ch in s:
    case ch:
    of '+': return '+'
    of ' ': return ' '
    else:
      continue
  return ' '

proc renderAuthForm(req: Request, scopes: seq[string], client_id, redirect_uri: string) =
  ## A function to render the auth form.
  ## I don't want to repeat myself 2 times in the POST and GET section so...
  ## here it is.
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html"

  var human_scopes = ""
  for scope in scopes:
    human_scopes.add(
      "<li>" & scope & ": " & humanizeScope(scope) & "</li>"
    )
  
  let session = req.fetchSessionCookie()
  var appname, login = ""
  dbPool.withConnection db:
    appname = db.getClientName(client_id)
    login = db.getSessionUserHandle(session)

  templatePool.withConnection obj:
    req.respond(
      200, headers, 
      obj.render(
        "oauth.html",
        {
          "human_scope": human_scopes,
          "scope": scopes.join(" "),
          "login": login,
          "session": session,
          "client_id": client_id,
          "redirect_uri": redirect_uri
        }
      )
    )

proc redirectToLogin*(req: Request, client, redirect_uri: string, scopes: seq[string], force_login: bool) =
  var headers: HttpHeaders
  configPool.withConnection config:
    # If the client has requested force login then remove the session cookie.
    if force_login:
      headers["Set-Cookie"] = deleteSessionCookie()
    
    templatePool.withConnection obj:
      var return_to = "http://$#oauth/authorize?response_type=code&client_id=$#&redirect_uri=$#&scope=$#&lang=en" % [obj.realURL, client, redirect_uri, scopes.join(" ")]
      headers["Location"] = "http://" & obj.realURL & "auth/sign_in/?return_to=" & encodeQueryComponent(return_to)

  req.respond(
    303, headers, ""
  )
  return

proc oauthAuthorizeGET*(req: Request) =
  # If response_type exists
  if not req.isValidQueryParam("response_type"):
    respJsonError("Missing required field: response_type")
  
  # If response_type doesn't match "code"
  if req.getQueryParam("response_type") != "code":
    respJsonError("Required field response_type has been set to an invalid value.")

  # If client id exists
  if not req.isValidQueryParam("client_id"):
    respJsonError("Missing required field: response_type")

  # Check if client_id is associated with a valid app
  dbPool.withConnection db:
    if not db.clientExists(req.getQueryParam("client_id")):
      respJsonError("Client_id isn't registered to a valid app.")
  var client_id = req.getQueryParam("client_id")
  
  # If redirect_uri exists
  if not req.isValidQueryParam("redirect_uri"):
    respJsonError("Missing required field: redirect_uri")
  var redirect_uri = htmlEscape(req.getQueryParam("redirect_uri"))

  # Check if redirect_uri matches the redirect_uri for the app
  dbPool.withConnection db:
    if redirect_uri != db.getClientRedirectUri(client_id):
      respJsonError("The redirect_uri used doesn't match the one provided during app registration")

  var
    scopes = @["read"]
    scopeSeparator = ' '
  if req.isValidQueryParam("scope"):
    # According to API, we can either split by + or space.
    # so we run this to figure it out. Defaulting to spaces if need
    scopeSeparator = getSeparator(req.getQueryParam("scope")) 
    scopes = req.getQueryParam("scope").split(scopeSeparator)
  
    for scope in scopes:
      # Then verify if every scope is valid.
      if not scope.verifyScope():
        respJsonError("Invalid scope: \"" & scope & "\" (Separator: " & scopeSeparator & ")")

  dbPool.withConnection db:
    # And then we see if the scopes have been specified during app registration
    # This isn't in the for loop above, since this uses db calls, and I don't wanna
    # flood the server with excessive database calls.
    if not db.hasScopes(client_id, scopes):
      respJsonError("An attached scope wasn't specified during app registration.")
  
  var force_login = false
  if req.isValidQueryParam("force_login"):
    try:
      force_login = req.getQueryParam("force_login").parseBool()
    except:
      force_login = true
  
  #var lang = "en" # Unused and unparsed. TODO: Implement checks for this.

  # Check for authorization or "force_login" parameter
  # If auth isnt present or force_login is true then redirect user to the login page
  if not req.hasSessionCookie() or force_login:
    req.redirectToLogin(client_id, redirect_uri, scopes, force_login)
    return

  dbPool.withConnection db:
    if not db.sessionExists(req.fetchSessionCookie()):
      req.redirectToLogin(client_id, redirect_uri, scopes, force_login)
      return

  req.renderAuthForm(scopes, client_id, redirect_uri)


proc oauthAuthorizePOST*(req: Request) =
  let fm = req.unrollForm()

  # If response_type exists
  if not fm.isValidFormParam("response_type"):
    respJsonError("Missing required field: response_type")
  
  # If response_type doesn't match "code"
  if fm.getFormParam("response_type") != "code":
    respJsonError("Required field response_type has been set to an invalid value.")

  # If client id exists
  if not fm.isValidFormParam("client_id"):
    respJsonError("Missing required field: response_type")

  # Check if client_id is associated with a valid app
  dbPool.withConnection db:
    if not db.clientExists(fm.getFormParam("client_id")):
      respJsonError("Client_id isn't registered to a valid app.")
  var client_id = fm.getFormParam("client_id")
  
  # If redirect_uri exists
  if not fm.isValidFormParam("redirect_uri"):
    respJsonError("Missing required field: redirect_uri")
  var redirect_uri = htmlEscape(fm.getFormParam("redirect_uri"))

  # Check if redirect_uri matches the redirect_uri for the app
  dbPool.withConnection db:
    if redirect_uri != db.getClientRedirectUri(client_id):
      respJsonError("The redirect_uri used doesn't match the one provided during app registration")

  var
    scopes = @["read"]
    scopeSeparator = ' '
  if fm.isValidFormParam("scope"):
    # According to API, we can either split by + or space.
    # so we run this to figure it out. Defaulting to spaces if need
    scopeSeparator = getSeparator(fm.getFormParam("scope")) 
    scopes = fm.getFormParam("scope").split(scopeSeparator)
  
    for scope in scopes:
      # Then verify if every scope is valid.
      if not scope.verifyScope():
        respJsonError("Invalid scope: \"" & scope & "\" (Separator: " & scopeSeparator & ")")

  dbPool.withConnection db:
    # And then we see if the scopes have been specified during app registration
    # This isn't in the for loop above, since this uses db calls, and I don't wanna
    # flood the server with excessive database calls.
    if not db.hasScopes(client_id, scopes):
      respJsonError("An attached scope wasn't specified during app registration.")
  
  var force_login = false
  if fm.isValidFormParam("force_login"):
    try:
      force_login = fm.getFormParam("force_login").parseBool()
    except:
      force_login = true
  
  # Check for authorization or "force_login" parameter
  # If auth isnt present or force_login is true then redirect user to the login page
  if not req.hasSessionCookie() or force_login:
    req.redirectToLogin(client_id, redirect_uri, scopes, force_login)
    return
  
  dbPool.withConnection db:
    if not db.sessionExists(req.fetchSessionCookie()):
      req.redirectToLogin(client_id, redirect_uri, scopes, force_login)
      return

  if not fm.isValidFormParam("action"):
    req.renderAuthForm(scopes, client_id, redirect_uri)
    return
  
  var user = ""
  dbPool.withConnection db:
    user = db.getSessionUser(req.fetchSessionCookie())
    if db.authCodeExists(user, client_id):
      db.deleteAuthCode(
        db.getSpecificAuthCode(user, client_id)
      )

  case fm.getFormParam("action").toLowerAscii():
  of "authorized":
    var code = ""

    dbPool.withConnection db:
      code = db.createAuthCode(user, client_id, scopes.join(" "))
    
    if redirect_uri == "urn:ietf:wg:oauth:2.0:oob":
      ## Show code to user
      var headers: HttpHeaders
      headers["Content-Type"] = "text/html"

      templatePool.withConnection obj:
        req.respond(
          200, headers,
          obj.renderSuccess(
            "Authorization code: " & code
          )
        )

    else:
      ## Redirect them elsewhere
      var headers: HttpHeaders
      headers["Location"] = redirect_uri & "?code=" & code

      req.respond(
        303, headers, ""
      )
      return
  else:
    # There's not really anything to do.
    var headers: HttpHeaders
    headers["Content-Type"] = "text/html"

    templatePool.withConnection obj:
      req.respond(
        200, headers,
        obj.renderSuccess(
          "Authorization request has been rejected!"
        )
      )
  
proc oauthToken*(req: Request) =
  var
    grant_type, code, client_id, client_secret, redirect_uri = ""
    scopes = @["read"]

  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"

  ## We gotta check for both url-form-encoded or whatever
  ## And for JSON body requests.
  case req.headers["Content-Type"]:
  of "application/x-www-form-urlencoded":
    let fm = req.unrollForm()

    # Check if the required stuff is there
    for thing in @["client_id", "client_secret", "redirect_uri", "grant_type"]:
      if not fm.isValidFormParam(thing): 
        respJsonError("Missing required parameter: " & thing)

    grant_type = fm.getFormParam("grant_type")
    client_id = fm.getFormParam("client_id")
    client_secret = fm.getFormParam("client_secret")
    redirect_uri = fm.getFormParam("redirect_uri")

    if fm.isValidFormParam("code"):
      code = fm.getFormParam("code")
    
    # According to API, we can either split by + or space.
    # so we run this to figure it out. Defaulting to spaces if need
    if fm.isValidFormParam("scope"):
      scopes = fm.getFormParam("scope").split(getSeparator(fm.getFormParam("scope")) )
  of "application/json":
    var json: JsonNode = newJNull()
    try:
      json = parseJSON(req.body)
    except:
      respJsonError("Invalid JSON.")

    # Double check if the parsed JSON is *actually* valid.
    if json.kind == JNull:
      respJsonError("Invalid JSON.")
    
    # Check if the required stuff is there
    for thing in @["client_id", "client_secret", "redirect_uri", "grant_type"]:
      if not json.hasValidStrKey(thing): 
        respJsonError("Missing required parameter: " & thing)

    grant_type = json["grant_type"].getStr()
    client_id = json["client_id"].getStr()
    client_secret = json["client_secret"].getStr()
    redirect_uri = json["redirect_uri"].getStr()

    # Get the website if it exists
    if json.hasValidStrKey("code"):
      code = json["code"].getStr()

    # Get the scopes if they exist
    if json.hasValidStrKey("scope"):
      scopes = json["scope"].getStr().split(getSeparator(json["scope"].getStr()))
  else:
    respJsonError("Unknown content-type.")
  
  for scope in scopes:
    # Verify if scopes are valid.
    if not scope.verifyScope():
      respJsonError("Invalid scope: " & scope)

  if grant_type notin @["authorization_code", "client_credentials"]:
    respJsonError("Unknown grant_type")
  
  var token = ""
  dbPool.withConnection db:
    if not db.clientExists(client_id):
      respJsonError("Client doesn't exist")
    
    if db.getClientSecret(client_id) != client_secret:
      respJsonError("Client secret doesn't match client id")
    
    if db.getClientRedirectUri(client_id) != redirect_uri:
      respJsonError("Redirect_uri not specified during app creation")
    
    if not db.hasScopes(client_id, scopes):
        respJsonError("An attached scope wasn't specified during app registration.")
    
    if grant_type == "authorization_code":
      if not db.authCodeValid(code):
        respJsonError("Invalid code")
      
      scopes = db.getScopesFromCode(code)
      
      if not db.codeHasScopes(code, scopes):
        respJsonError("An attached scope wasn't specified during oauth authorization.")
    
      if db.getTokenFromCode(code) != "":
        respJsonError("Token aleady registered for this auth code.")

    token = db.createToken(client_id, code)
  
  req.respond(
    200, headers,
    $(%*{
      "access_token": token,
      "token_type": "Bearer",
      "scope": scopes.join(" "),
      "created_at": toTime(utc(now())).toUnix()
    })
  )

    


  return
  
proc oauthRevoke*(req: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"

  ## We gotta check for both url-form-encoded or whatever
  ## And for JSON body requests.
  var client_id, client_secret, token = ""
  case req.headers["Content-Type"]:
  of "application/x-www-form-urlencoded":
    let fm = req.unrollForm()

    # Check if the required stuff is there
    for thing in @["client_id", "client_secret", "token"]:
      if not fm.isValidFormParam(thing): 
        respJsonError("Missing required parameter: " & thing)

    client_id = fm.getFormParam("client_id")
    client_secret = fm.getFormParam("client_secret")
    token = fm.getFormParam("token")
  of "application/json":
    var json: JsonNode = newJNull()
    try:
      json = parseJSON(req.body)
    except:
      respJsonError("Invalid JSON.")

    # Double check if the parsed JSON is *actually* valid.
    if json.kind == JNull:
      respJsonError("Invalid JSON.")
    
    # Check if the required stuff is there
    for thing in @["client_id", "client_secret", "token"]:
      if not json.hasValidStrKey(thing): 
        respJsonError("Missing required parameter: " & thing)

    client_id = json["client_id"].getStr()
    client_secret = json["client_secret"].getStr()
    token = json["token"].getStr()
  else:
    respJsonError("Unknown content-type.")

  # Now we check if the data submitted is actually valid.
  dbPool.withConnection db:
    if not db.clientExists(client_id):
      respJsonError("Client doesn't exist", 403)
      
    if not db.tokenExists(token):
      respJsonError("Token doesn't exist.", 403)

    if not db.tokenMatchesClient(token, client_id):
      respJsonError("Client doesn't own this token", 403)

    if db.getClientSecret(client_id) != client_secret:
      respJsonError("Client secret doesn't match client id", 403)

    # Finally, delete the OAuth token.
    db.deleteOAuthToken(token)
  # And respond with nothing
  respJson($(%*{}))

  # By the way, how is this API supposed to be idempotent?
  # You're supposed to simultaneously check if the token exists and to let it be deleted multiple times?
  # I think Mastodon either doesn't actually delete the token (they just mark it as deleted, which is stupid)
  # or they don't check for the existence of the token before deleting it.
  # Anyway, this API is not idempotent because thats stupid
  #
  # In our case, if we delete a non-existent OAuth token, then we will get a database error
  

  
    
    
