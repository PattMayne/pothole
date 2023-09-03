echo "Test 01 - Database Operations"

import libpothole/[lib, database, user, post, debug]

echo("Version reported: ", version)
echo("Database engine: ", dbEngine)

echo "Initializing database"

when dbEngine == "sqlite":
  var db: DbConn;
  if not init(db, "main.db"):
    error "Couldn't initialize database", "test_db"
    

when not defined(iHaveMyOwnStuffThanks):
  echo "Adding fake users"
  for x in getFakeUsers():
    discard db.addUser(escape(x))

  echo "Adding fake posts"
  for x in getFakePosts():
    discard db.addPost(escape(x))

## getTotalPosts
stdout.write "\nTesting getTotalPosts() "
try:
  assert db.getTotalPosts() == len(fakeStatuses)
  stdout.write "Pass!\n"
except:
  stdout.write "Fail!\n"

#[ Uncomment this if you want, I guess?
## getLocalPosts
echo "Displaying local Posts"
  for x in getLocalPosts(0):
  stdout.write("\n---\n")
  echo "From: @", x.sender
  if isEmptyOrWhitespace(x.replyto):
    echo "To: Public"
  else:
    var printOut: string = ""
    for user in x.recipients:
      printOut.add("@" & user)
    echo "To: ", printOut
  echo "\n" & x.content
  stdout.write("\n")
]#


## getAdmins
stdout.write "Testing getAdmins() "
# Create a new admin user
var adminuser = newUser("johnadminson","John Adminson","123",true,true)
adminuser.bio = "I am John Adminson! The son of the previous admin, George Admin"
adminuser.email = "johnadminson@adminson.family.testinternal" # inb4 Google creates a testinternal TLD
discard db.addUser(escape(adminuser))

var adminFlag = false # This flag will get flipped when it sees the name "johnadminson" in the list of names that getAdmins() provides. If this happens then the test passes!
for handle in db.getAdmins():
  if handle == adminuser.handle:
    adminFlag = true
    break

try:
  assert adminFlag == true
  stdout.write "Pass!\n"
except:
  stdout.write "Fail!\n"

## getTotalLocalUsers
stdout.write "Testing getTotalLocalUsers() "
# By this point we have added the fakeUsers + our fake admin user above.
# So let's just test for this:
try:
  assert db.getTotalLocalUsers() > len(fakeHandles)
  stdout.write "Pass!\n"
except:
  stdout.write "Fail!\n"

## userIdExists
stdout.write "Testing userIdExists() "
# We already have a user whose ID we know.
# We can check for its ID easily.
try:
  assert db.userIdExists(adminuser.id) == true
  stdout.write("Pass!\n")
except:
  stdout.write "Fail!\n"

## userHandleExists
stdout.write "Testing userHandleExists() "
# Same exact thing but with the handle this time.
try:
  assert db.userHandleExists(adminuser.handle) == true
  stdout.write("Pass!\n")
except:
  stdout.write "Fail!\n"

## getUserById
stdout.write "Testing getUserById() "
try:
  assert db.getUserById(adminuser.id) == adminuser
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getUserByHandle
stdout.write "Testing getUserByHandle() "
try:
  assert db.getUserByHandle(adminuser.handle) == adminuser
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getIdFromHandle
stdout.write "Testing getIdFromHandle() "
try:
  assert db.getIdFromHandle(adminuser.handle) == adminuser.id
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getHandleFromId
stdout.write "Testing getHandleFromId() "
try:
  assert db.getHandleFromId(adminuser.id) == adminuser.handle
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## updateUserByHandle
# Make the johnadminson user no longer admin(son)
stdout.write "Testing updateUserByHandle() "
try:
  discard db.updateUserByHandle(adminuser.handle,"admin","false")
  assert db.getUserByHandle(adminuser.handle).admin == false
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## updateUserById
# Make the johnadminson user admin(son)
stdout.write "Testing updateUserById() "
try:
  discard db.updateUserById(adminuser.id,"admin","true")
  assert db.getUserById(adminuser.id).admin == true
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

# For these next few tests, it helps to have a post we control every aspect of.
var custompost = newPost("johnadminson","","@scout @soldier @pyro @demoman @heavy @engineer @medic @sniper @spy Debate: is it pronounced Gif or Jif?",@["scout","soldier","pyro","demoman","heavy","engineer","medic","sniper","spy"],true)

discard db.addPost(custompost)

## postIdExists
stdout.write "Testing postIdExists() "
try:
  assert db.postIdExists(custompost.id) == true
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## updatePost
stdout.write "Testing updatePost() "
try:
  discard db.updatePost(custompost.id,"content","\"@scout @soldier @pyro @demoman @heavy @engineer @medic @sniper @spy Wow! You will never be able to read what I said previously because something has mysteriously changed my post!\"")
  assert db.getPost(custompost.id).content == "@scout @soldier @pyro @demoman @heavy @engineer @medic @sniper @spy Wow! You will never be able to read what I said previously because something has mysteriously changed my post!"
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getPost
stdout.write "Testing getPost() "
try:
  # We changed customPost because of the previous test, remember?
  custompost.content = "@scout @soldier @pyro @demoman @heavy @engineer @medic @sniper @spy Wow! You will never be able to read what I said previously because something has mysteriously changed my post!"
  assert db.getPost(custompost.id) == custompost
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getPostsByUserHandle()
stdout.write "Testing getPostsByUserHandle() "
try:
  assert db.getPostsByUserHandle("johnadminson",1) == @[custompost]
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")

## getPostsByUserId()
stdout.write "Testing getPostsByUserId() "
try:
  assert db.getPostsByUserId(adminuser.id,1) == @[custompost]
  stdout.write("Pass!\n")
except:
  stdout.write("Fail!\n")