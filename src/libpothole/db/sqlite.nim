# Copyright © Leo Gavilieau 2023
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# db/sqlite.nim:
## A database backend for sqlite3 (Using the tiny_sqlite module)
## This backend is very much early in development and it is actually untested

# TODO: Finish this.
# TODO TODO: Also only document the stuff thats different between this module and the postgres module. Nothing else.

# From somewhere in Pothole
import ../user, ../post, ../lib, ../crypto

# From somewhere in the standard library
import std/strutils except isEmptyOrWhitespace
import std/tables

# From somewhere else (nimble etc.)
import tiny_sqlite

proc has(db:DbConn,statement:string): bool =
  ## A quick helper function to check if a thing exists.
  if isNone(db.one(statement)):
    return false
  return true

# Store each column like this: {"COLUMN_NAME":"COLUMN_TYPE"}
# For this module to work, both database schemas and user object definitions must be similar
const usersCols: OrderedTable[string,string] = {"id":"BLOB PRIMARY KEY UNIQUE NOT NULL", # The user ID
"handle":"VARCHAR(65535) UNIQUE NOT NULL", # The user's actual username (Fx. alice@alice.wonderland)
"name":"VARCHAR(65535)", # The user's display name (Fx. Alice)
"local":"BOOLEAN NOT NULL", # A boolean indicating whether the user originates from the local server or another one.
"email":"VARCHAR(225)", # The user's email (Empty for remote users)
"bio":"VARCHAR(65535)", # The user's biography 
"password":"VARCHAR(65535)", # The user's hashed & salted password (Empty for remote users obv)
"salt":"VARCHAR(65535)", # The user's salt (Empty for remote users obv)
"kdf":"INTEGER NOT NULL", # The version of the key derivation function. See DESIGN.md's "Key derivation function table" for more.
"admin":"BOOLEAN NOT NULL", # A boolean indicating whether or not this is user is an Admin.
"is_frozen":"BOOLEAN NOT NULL"}.toOrderedTable # A boolean indicating whether this user is frozen (Posts from this user will not be stored)

const postsCols: OrderedTable[string, string] = {"id":"BLOB PRIMARY KEY UNIQUE NOT NULL", # The post Id
"recipients":"VARCHAR(65535)", # A comma-separated list of recipients since sqlite3 does not support arrays by default
"sender":"VARCHAR(65535) NOT NULL", # A string containing the sender handle
"written":"TIMESTAMP NOT NULL", # A timestamp containing the date that the post was written (and published)
"updated":"TIMESTAMP", # An optional timestamp containing the date that the post was updated
"local": "BOOLEAN NOT NULL"}.toOrderedTable # A boolean indicating whether the post originated from this server or other servers.


# This is the database connection we will use.
# It's initialized at startup via the init() procedure defined here.
{.cast(gcsafe).}:
  var db:DbConn; 

proc init*(filename: string, noSchemaCheck:bool = false): bool =
  ## Do any initialization work.
  var caller = "db/sqlite.init" # Just so we dont repeat the same thing a whole lot.

  if filename.startsWith("__eat_flaming_death"):
    debug "Someone or something used the forbidden code", caller
    return false
  
  if isEmptyOrWhitespace(filename):
    debug "String is mostly empty or whitespace. ", caller
    return false

  debug "Opening database at " & filename, caller
  db = openDatabase(filename) 

  # Create tables by running through the postCols and userCols tables.
  var sqlStatement = "CREATE TABLE IF NOT EXISTS users ("
  for key, value in usersCols.pairs:
    sqlStatement.add(key & " " & value & ",")
  sqlStatement = sqlStatement[0 .. ^2]
  sqlStatement.add(");")

  try: # Try to run it and pray for good luck
    db.execScript(sqlStatement)
  except:
    error "Failed to create the users table!", caller

  # And now the posts table
  sqlStatement = "CREATE TABLE IF NOT EXISTS posts (";
  for key, value in postsCols.pairs:
    sqlStatement.add(key & " " & value & ",")
  sqlStatement = sqlStatement[0 .. ^2]
  sqlStatement.add(");")

  try: # Same as before
    db.execScript(sqlStatement)
  except:
    error "Failed to create the posts table!", caller
  
  # Now skip the schema check
  if noSchemaCheck:
    debug "Schema check skipped.", caller
    return true # All thats left is the schema check. So let's return early.

  var cols: seq[string] = @[]
  for row in db.all("PRAGMA table_info('users');"):
    cols.add(row[1].strVal)

  var missing: seq[string] = @[]
  for key in usersCols.keys:
    if key in cols:
      continue
    else:
      missing.add(key)
  
  if len(missing) > 0:
    debug "Major difference between built-in schema and currently-used schema", caller
    debug "Did you forget to migrate? Please migrate before re-running this program", caller
    error "Missing columns from users schema:\n" & $missing, caller

  # Now we do the same above schema check but for the posts table.

  cols = @[]
  for row in db.all("PRAGMA table_info('posts');"):
    cols.add(row[1].strVal)

  missing = @[]
  for key in postsCols.keys:
    if key in cols:
      continue
    else:
      missing.add(key)
  
  if len(missing) > 0:
    debug "Major difference between built-in schema and currently-used schema", caller
    debug "Did you forget to migrate? Please migrate before re-running this program", caller
    error "Missing columns from posts schema:\n" & $missing, caller

  return true

proc uninit*(): bool =
  ## Uninitialize the database.
  ## Or close it basically...
  db.close()

proc addUser*(user: User): User = 
  var caller = "db/sqlite.addUser"
  ## Add a user to the database
  ## This procedure expects an escaped user to be handed to it.
  var handle = escape(sanitizeHandle(user.handle))
  if db.has("SELECT local FROM users WHERE handle = " & handle & ";"):
    debug "User with handle " & user.handle & " already exists!", caller
    return # Simply exit

  while (true):
    if db.has("SELECT local FROM users WHERE id = " & user.id & ";"):
      user.id = randomString() # User's ID already exists! Generate a new one!
    else:
      break 

  # Now we loop over the fields and build an SQL statement as we go.
  # TODO: Look into using macros or templates to automatically generate this code.
  var sqlStatement = "INSERT INTO users("

  for key, value in user[].fieldPairs:
    sqlStatement.add(key & ",")
  
  sqlStatement = sqlStatement[0 .. ^2]
  sqlStatement.add(") VALUES (")

  for key, value in user[].fieldPairs:
    when typeof(value) is string:
      sqlStatement.add(value)
    when typeof(value) is bool:
      sqlStatement.add($value)
    sqlStatement.add(",")
  

  sqlStatement = sqlStatement[0 .. ^2]
  sqlStatement.add(");")

  try:
    db.exec(sqlStatement)
  except:
    debug "sqlStatement: " & sqlStatement, caller
    error "Failed to insert user!", caller

  return user

proc getAdmins*(): seq[string] = 
  ## A procedure that returns the usernames of all administrators.
  for row in db.all("SELECT handle FROM users WHERE admin = true;"):
    result.add(row[0].strVal)
  return result
  
proc getTotalLocalUsers*(): int =
  ## A procedure to get the total number of local users.
  result = 0
  for x in db.all("SELECT handle FROM users WHERE local = true;"):
    inc(result)
  return result

proc userIdExists*(id:string): bool =
  ## A procedure to check if a user exists by id
  return false

proc userHandleExists*(handle:string): bool =
  ## A procedure to check if a user exists by handle
  return false

proc getUserById*(id: string): User =
  ## Retrieve a user from the database using their id
  return User()

proc getUserByHandle*(handle: string): User =
  ## Retrieve a user from the database using their handle
  return User()

proc updateUserByHandle*(handle, column, value: string): bool =
  ## A procedure to update the user by their handle
  return true

proc updateUserById*(id, column, value: string): bool = 
  ## A procedure to update the user by their ID
  return true

proc getIdFromHandle*(handle: string): string =
  ## A function to convert a user handle to an id.
  return ""

proc getHandleFromId*(id: string): string =
  ## A function to convert a  id to a handle.
  return ""

#! This comment marks the beginning of the Post section.
# Procedures here are primarily used for posts.

proc constructPostFromRow*(row: ResultRow): Post =
  ## A procedure that takes a database Row (From the Posts table)
  ## And turns it into a Post object ready for display, parsing and so on.
  var post = Post()[]

  # This looks ugly, I know, I had to wrap it with
  # two specific functions but we don't have to re-write this
  # even if we add new things to the User object. EXCEPT!
  # if we introduce new data types to the User object
  var i: int = 0;

  for key,value in post.fieldPairs:
    inc(i)
    # If its string, add it surrounding quotes
    # Otherwise add it whole
    when post.get(key) is bool:
      post.get(key) = parseBool(row[i - 1].strVal)
    when post.get(key) is string:
      post.get(key) = row[i - 1].strVal
    when post.get(key) is seq[string]:
      post.get(key) = row[i - 1].strVal.split(",")

  new(result); result[] = post
  return result.unescape()

proc addPost*(post: Post): Post =
  ## A function add a post into the database
  return Post()

proc postIdExists*(id: string): bool =
  ## A function to see if a post id exists in the database
  return false

proc updatePostById*(id, column, value: string): bool =
  ## A procedure to update a post using it's id
  return true

proc getPostById*(id: string): Post =
  ## A procedure to get a post object using its id
  return Post()

proc getPostsByUserHandle*(handle:string, limit: int = 15): seq[Post] =
  ## A procedure to get any user's posts using the users handle
  return @[Post()]  

proc getPostsByUserId*(id:string, limit: int = 15): seq[Post] =
  ## A procedure to get any user's posts using the users id
  return @[Post()]

proc getTotalPosts*(): int =
  ## A procedure to get the total number of local posts.
  return 0

proc getLocalPosts*(limit: int = 15): seq[Post] =
  ## A procedure to get posts from local users only.
  ## Set limit to 0 to disable the limit and get all posts from local users.
  # This clearly does not work.
  # TODO: Investigate why it does not work.
  var sqlStatement = "SELECT * FROM posts WHERE local = true;"
  if limit != 0:
    for row in db.all(sqlStatement):
      if len(result) > limit:
        break
      result.add(constructPostFromRow(row))
  else:
    for row in db.all(sqlStatement):
      result.add(constructPostFromRow(row))