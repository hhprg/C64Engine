// Todo: Auto-generate based on SpritePad file?
// Todo: Enum for SpriteClip names instead of strings.

//
// Define SpriteClipKeys here and add them to list of all SpriteClipKeys.
//

.eval AllSpriteClipKeys.add(SpriteClipKeys("PingPong0-6, hold4", 4, List().add(0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1)))
.eval AllSpriteClipKeys.add(SpriteClipKeys("PingPong0-4, hold4", 4, List().add(0, 1, 2, 3, 4, 3, 2, 1)))
.eval AllSpriteClipKeys.add(SpriteClipKeys(    "Ramp0-7, hold4", 4, List().add(0, 1, 2, 3, 4, 5, 6, 7)))
.eval AllSpriteClipKeys.add(SpriteClipKeys(    "Ramp0-8, hold8", 8, List().add(0, 1, 2, 3, 4, 5, 6, 7, 8)))
.eval AllSpriteClipKeys.add(SpriteClipKeys(    "Ramp0-3, hold4", 4, List().add(0, 1, 2, 3)))
.eval AllSpriteClipKeys.add(SpriteClipKeys(    "Ramp3-0, hold4", 4, List().add(3, 2, 1, 0)))

//
// Define SpriteClips here and add them to list of all SpriteClips.
//

.eval AllSpriteClips.add(SpriteClip(       "MainShipLoop", "PingPong0-6, hold4",  0, LIGHT_GRAY))
.eval AllSpriteClips.add(SpriteClip(     "Enemy1LoopCyan", "PingPong0-6, hold4", 14, CYAN))
.eval AllSpriteClips.add(SpriteClip( "Enemy1LoopLightRed", "PingPong0-6, hold4", 14, LIGHT_RED))
.eval AllSpriteClips.add(SpriteClip("Enemy1LoopLightBlue", "PingPong0-6, hold4", 14, LIGHT_BLUE))
.eval AllSpriteClips.add(SpriteClip(     "Enemy1LoopGray", "PingPong0-6, hold4", 14, GRAY))
.eval AllSpriteClips.add(SpriteClip(    "Enemy1LoopGreen", "PingPong0-6, hold4", 14, GREEN))
.eval AllSpriteClips.add(SpriteClip(    "Enemy2LoopGreen", "PingPong0-6, hold4",  7, GREEN))
.eval AllSpriteClips.add(SpriteClip( "Enemy2LoopLightRed", "PingPong0-6, hold4",  7, LIGHT_RED))
.eval AllSpriteClips.add(SpriteClip(          "Explosion",     "Ramp0-8, hold8", 46, LIGHT_RED))
.eval AllSpriteClips.add(SpriteClip(     "BeaconLoopCyan", "PingPong0-4, hold4", 30, CYAN))
.eval AllSpriteClips.add(SpriteClip( "BeaconLoopLightRed", "PingPong0-4, hold4", 30, LIGHT_RED))
.eval AllSpriteClips.add(SpriteClip("BeaconLoopLightBlue", "PingPong0-4, hold4", 30, LIGHT_BLUE))
.eval AllSpriteClips.add(SpriteClip(     "BeaconLoopGray", "PingPong0-4, hold4", 30, GRAY))
.eval AllSpriteClips.add(SpriteClip(   "BeaconLoopPurple", "PingPong0-4, hold4", 30, PURPLE))
.eval AllSpriteClips.add(SpriteClip( "MiniBossOpenCannon",     "Ramp3-0, hold4",152, LIGHT_BLUE))
.eval AllSpriteClips.add(SpriteClip("MiniBossCloseCannon",     "Ramp0-3, hold4",152, LIGHT_BLUE))
