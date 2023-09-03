# Copyright © Leo Gavilieau 2022-2023 <xmoo@privacyrequired.com>
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

# From libpothole or pothole's server codebase
import libpothole/[lib,conf,database]
import assets

# From stdlib
import std/tables
import std/strutils except isEmptyOrWhitespace

# From nimble/other sources
import prologue

proc init*(config: var Table[string, string], uploadsFolder, staticFolder: var string, db: var DbConn, configFile: string): string =
  ## Initializes the routes module by setting up the global configs.
  try:
    config = conf.setup(configFile)
    uploadsFolder = assets.initUploads(config)
    staticFolder = assets.initStatic(config)
    db.initFromConfig(config)
    return ""
  except CatchableError as e:
    return e.msg

#! Actual prologue routes

# our serveStatic route reads from static/FILENAME and renders it as a template.
# This helps keep everything simpler, since we just add our route to the string, it's asset and
# Bingo! We've got a proper route that also does templating!

# But this won't work for /auth/ routes!

const staticURLs: Table[string,string] = {
  "/": "index.html", 
  "/about": "about.html", "/about/more": "about.html", # About pages, they run off of the same template.
}.toTable

proc prepareTable(config: Table[string, string], db: DbConn): Table[string,string] =
  var table = { # Config table for the templating library.
    "name":config.getString("instance","name"), # Instance name
    "description":config.getString("instance","description"), # Instance description
    "version":"", # Pothole version
    "staff": "<p>None</p>", # Instance staff (Any user with the admin attribute)
    "rules": "<p>None</p>" # Instance rules (From config)
  }.toTable

   # Add admins and other staff
  if config.getBool("web","show_staff"):
    table["staff"] = "" # Clear whatever is in it first.
    # Build the list, item by item using database functions.
    table["staff"].add("<ul>")
    for user in db.getAdmins():
      table["staff"].add("<li><a href=\"/@" & user & "\">" & user & "</a></li>") # Add every admin as a list item.
    table["staff"].add("</ul>")

   # Add instance rules
  if config.exists("instance","rules"):
    table["rules"] = "" # Again, clear whatever is in it first.
    # Build the list, item by item using data from the config file.
    table["rules"].add("<ol>")
    for rule in config.getArray("instance","rules"):
      table["rules"].add("<li>" & rule & "</li>")
    table["rules"].add("</ol>")

  when not defined(phPrivate):
    if config.getBool("web","show_version"):
      table["version"] = lib.phVersion

  return table

proc serveStatic*(ctx: Context) {.async, gcsafe.} =
  var path = ctx.request.path

  # If the path has a slash at the end, remove it.
  # Except if the path is the root, aka. literally just a slash
  if path.endsWith("/") and path != "/": path = path[0..^2]

  resp renderTemplate(
    getAsset(staticFolder, staticURLs[path]), # Get path from thing
    prepareTable() # The command table, for the templating function.
  )

proc serveCSS*(ctx:Context) {.async, gcsafe.} =
  resp plainTextResponse(getAsset(staticFolder,"style.css"), Http200)

proc genStaticURLs(): seq[UrlPattern] =
  for x in staticURLs.keys:
    result.add(pattern(x, serveStatic))
  result.add(pattern("/css/style.css",serveCSS))

let staticURLRoutes* = genStaticURLs() # This will be used by the main pothole.nim file