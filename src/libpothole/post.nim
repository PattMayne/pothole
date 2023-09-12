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
#
# post.nim:
## This module contains various functions and procedures for handling Post objects.
## The Post object type has been moved here after commit 9f3077d
## Database-related procedures are in db.nim

# From Pothole
import lib, crypto
from database import dbEngine

# From Nim's standard library
import std/strutils except isEmptyOrWhitespace
import std/times

# ActivityPub Object/Post
type

  # Generic "Like" object
  Favorite* = object
    reactor*: string # The reactor's id
    reaction*: string # The reactor's reaction

  Post* = object
    id*: string # A unique id.
    recipients*: seq[string] # A sequence of recipient's handles.
    sender*: string # Basically, the person sending the message
    replyto*: string # Resource/Post person was replying to,  
    content*: string # The actual content of the post
    written*: string # A timestamp of when the Post was created
    updated*: string # A timestamp of when then Post was last edited
    local*:bool # A boolean indicating whether or not the post came from the local server or external servers
    favorites*: seq[Favorite]


when dbEngine == "sqlite":
  # Sqlite is deranged.
  func escape*(str,a,b:string): string = 
    if str.isEmptyOrWhitespace():
      return str

    result = strutils.escape(str,a,b)
    var
      i = -1
      skipFlag = false

    var oldstr = result
    result = ""
    for ch in oldstr:
      inc(i)
      if ch == '\\' and oldstr[i + 1] == '\'':
        result.add("''")
        skipFlag = true
        continue
      if skipFlag:
        skipFlag = false
        continue
      result.add(ch)
    
    return result

func escape*(obj: Favorite): Favorite =
  ## A function to escape a Favorite object
  result.reactor = escape(obj.reactor)
  result.reaction = escape(obj.reaction)
  return result

proc escape*(post: Post): Post =
  ## A procedure to escape a Post object
  result = post

  for key,val in result.fieldPairs:
    when typeof(val) is bool:
      result.get(key) = val

    when typeof(val) is string:
      result.get(key) = escape(val,"","")

    when typeof(val) is seq[string]:
      var newseq: seq[string] = @[]
      for x in val:
        newseq.add(escape(x))
      result.get(key) = newseq

    when typeof(val) is seq[Favorite]:
      var newseq: seq[Favorite] = @[]
      for reaction in val:
        newseq.add(escape(reaction))
      result.get(key) = newseq

  return result

func unescape*(obj: Favorite): Favorite =
  result.reaction = unescape(obj.reaction)
  result.reactor = unescape(obj.reactor)
  return result

proc unescape*(post: Post): Post =
  ## A procedure to unescape a Post object
  result = post

  # TODO: Look into using templates or macros to automatically
  #       generate the loop that unescapes Posts
  for key,val in result.fieldPairs:
    when typeof(val) is bool:
      result.get(key) = val

    when typeof(val) is string:
      result.get(key) = unescape(val,"","")

    when typeof(val) is seq[string]:
      var newseq: seq[string] = @[]
      for x in val:
        newseq.add(unescape(x,"",""))
      result.get(key) = newseq

    when typeof(val) is seq[Favorite]:
      var newseq: seq[Favorite] = @[]
      for x in val:
        newseq.add(unescape(x))
      result.get(key) = newseq

  return result

proc newPost*(sender,replyto,content: string, recipients: seq[string] = @[], local: bool = false, written: string = "", contexts: seq[string] = @[]): Post =
  var post: Post = Post()
  if isEmptyOrWhitespace(sender) or isEmptyOrWhitespace(content):
    error "Missing critical fields for post." 

  # Generate post id
  post.id = randomString(18)
  
  # Just do this stuff...
  post.sender = sender
  post.recipients = recipients
  post.local = local
  post.content = content

  if isEmptyOrWhitespace(replyto):
    post.replyto = ""
  else:
    post.replyto = replyto

  if isEmptyOrWhitespace(written):
    post.written = $(now().utc) # Writing time-related code is always going to be messy...
  else:
    post.written = written

  return post

func `$`*(obj: Post): string =
  ## Turns a Post object into a human-readable string
  result.add("[")
  for key,val in obj.fieldPairs:
    result.add("\"" & key & "\": \"" & $val & "\",")
  result = result[0 .. len(result) - 2]
  result.add("]")

proc convertFromPlain*(sequence: seq[string]): seq[Favorite] = 
  for thing in sequence:
    var stuff = split(thing, '\\')
    var obj = Favorite()
    obj.reaction = stuff[0]
    obj.reactor = stuff[1]
    result.add(obj)
  return result