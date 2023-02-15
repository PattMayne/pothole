# Copyright © Leo Gavilieau 2022-2023
# Licensed under AGPL version 3 or later.
# lib.nim:
## This module contains shared data across Pothole.
## It also contains useful procedures and functions that are
## used across the app.
## 
## Things like object definitions, string-handling functions
## and debugging functions fit well here but functions that are
## less commonly used or needed should be put elsewhere (Fx. the escape functions for the User & Post objects are rarely used so they are in separate modules.)
## 
## This module is very huge. Please try to put your stuff somewhere else.

# For macro definition
from std/macros import newIdentNode, newDotExpr, strVal

# User data type, which represents actual users in the database.
# Confusingly, "name" means display name and "handle" means
# actual username. It's too late to change this now sadly.
#
# NOTE: If you are going to extend this  type then please
# edit the database schema in the exact order of User.
#
# EXTRA NOTE: If you are going to add a new datatype,
# maybe int for the number of followers, then please
# edit escape() and unescape() from data.nim and also edit
# addUser() and constructUserFromRow() from db.nim
# so they won't error out!
## Here are all of the fields in a user objects, with an explanation:
type 
  User* = ref object
    id*: string # An OID that represents the actual user
    handle*: string # A string containing the user's actual username 
    name*: string # A string containing the user's display name
    local*: bool # A boolean indicating if this user is from this instance 
    email*: string # A string containing the user's email
    bio*: string # A string containing the user's biography
    password*: string # A string to store a hashed + salted password 
    salt*: string # The actual salt with which to hash the password. 
    admin*: bool # A boolean indicating if the user is an admin.
    is_frozen*: bool #  A boolean indicating if the user is frozen/banned. (Can't log in, posts don't federate and cannot be followed.)

# ActivityPub Object/Post
type 
  Post* = ref object
    id*: string # A unique id. (If its an internal post then just leave out the domain name, if it's external then add the full link)
    contexts*: seq[string] # A sequence of the contexts that this post has.
    recipients*: seq[string] # A sequence of recipient's handles.
    sender*: string # aka attributedTo, basically the person replying. (AP: Actor)
    replyto*: string # Resource/Post person was replying to,  
    content*: string # The actual content of the post
    written*: string # A timestamp of when the Post was created
    updated*: string # A timestamp of when then Post was last edited
    local*:bool # A boolean indicating whether or not the post came from the local server or external servers

var debugBuffer: seq[string]; # A sequence to store debug strings in.

# Required configuration file options to check for.
# Split by ":" and use the first item as a section and the other as a key
const requiredConfigOptions*: seq[string] = @[
  "db:type",
  "instance:name",
  "instance:description",
  "instance:uri"
]

# A set of unsafe characters, this filters anything that doesn't make a valid email.
const unsafeHandleChars*: set[char] = {'!',' ','"','#','$','%','&','\'','(',')','*','+',',',';','<','=','>','?','[','\\',']','^','`','{','}','|','~'}

# A set of charatcer that you cannot use
# when registering a local user.
const localInvalidHandle*: set[char] = {'@',':','.'}

# App version
const version*: string = "0.0.2"

# How many items can be in debugBuffer before deleting some to save memory
const maxDebugItems: int = 40;

when defined(dontPrintDebug):
  const debugPrint: bool = false; # A boolean indicating whether or not to print strings as they come.
else:
  const debugPrint: bool = true; # A boolean indicating whether or not to print strings as they come.

# A set of whitespace characters
const whitespace*: set[char] = {' ', '\t', '\v', '\r', '\l', '\f'}

proc exit*() {.noconv.} =
  quit(1)


proc debug*(str, caller: string) =
  ## Adds a string to the debug buffer and optionally
  ## prints it if debugPrint is set to true.
   
  # Delete an item from the debug buffer if it gets too big
  if len(debugBuffer) > maxDebugItems - 1:
    debugBuffer.del(0)

    # Actually add it to the debug buffer
  var toBeAdded = "(" & caller & "): " & str
  debugBuffer.add(toBeAdded)

  # Optionally print it. (If debugPrint is set to true)
  if debugPrint:
    stdout.writeLine(toBeAdded)

proc error*(str,caller: string) =
  ## Exits the program, writes a stacktrace and maybe print the debug buffer.
  stderr.writeLine("Printing stacktrace...")
  writeStackTrace()

  # Only print debug buffer if debugPrint is disabled
  # If this isn't here then the output gets too messy.
  if debugPrint == false:
    stderr.writeLine("Printing debug buffer...")
    for x in debugBuffer:
      stderr.writeLine(x)

  stderr.writeLine("\nError (" & caller & "): " & str)
  quit(1)

macro get*(obj: object, fld: string): untyped =
  ## A procedure to get a field of an object using a string.
  ## Like so: user.get("local") == user.local
  newDotExpr(obj, newIdentNode(fld.strVal))

func isEmptyOrWhitespace*(str: string): bool =
  ## A faster implementation of strutils.isEmptyOrWhitespace
  ## This is basically the same thing.
  for x in str:
    if x notin whitespace:
      return false
  return true

func cleanString*(str: string, charset: set[char] = whitespace): string =
  ## A procedure to clean a string of whitespace characters.
  var startnum = 0;
  var endnum = len(str) - 1;
  
  while str[startnum] in charset:
    inc(startnum)

  while endnum >= 0 and str[endnum] in charset:
    dec(endnum)

  return str[startnum .. endnum]

func cleanLeading*(str: string, charset: set[char] = whitespace): string =
  ## A procedure to clean the beginning of a string.
  var startnum = 0;
  
  while str[startnum] in charset:
    inc(startnum)

  return str[startnum .. len(str) - 1]

func cleanTrailing*(str: string, charset: set[char] = whitespace): string =
  ## A procedure to clean the end of a string.
  var endnum = len(str) - 1;

  while endnum >= 0 and str[endnum] in charset:
    dec(endnum)

  return str[0 .. endnum]