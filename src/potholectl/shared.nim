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
# potholectl/shared.nim:
## Shared procedures for potholectl.

# From somewhere in Pothole
import pothole/[lib]

# From somewhere in the standard library
import std/[osproc]

proc exec*(cmd: string): string {.discardable.} =
  try:
    log "Executing: ", cmd
    let (output,exitCode) = execCmdEx(cmd)
    if exitCode != 0:
      log "Command returns code: ", exitCode
      log "command returns output: ", output
      return ""
    return output
  except CatchableError as err:
    log "Couldn't run command:", err.msg