# Tutorial Script

All the speaking in the tutorial (levels/tutorial.gd), in the order it plays, with what happens in between. Dialogue is copied exactly from the code, typos included.

**How lines show up**
- **Center box** (`talk`): the game pauses, and the player clicks through each line.
- **Side box** (`say`): appears in the left panel while the game keeps going.
- **Card** (`show_info`): a tutorial card with a video clip. The game pauses until it's closed.
- After the talking in each wave, that wave's instructions and challenge fade into the right panel.
- If a challenge isn't completed, the wave replays **without** its dialogue and cards. Only the retry and fail lines play.

Speakers: **RED FROG** (the examiner) and **FROG** (the player).

---

## WAVE 0: INTRO / MOVEMENT

*Nothing on screen yet. Movement only: no shooting, jumping or absorbing.*

**[Center box]**

**RED FROG:** Howdy new friend!

**FROG:** ...

**RED FROG:** Er, I mean old friend.

**FROG:** ...

**RED FROG:** Well I mean I guess we're not friends, but I've seen you around at the conferences. Great field research on the indigenous hexagonal lotus root by the way.

**RED FROG:** Where are my manners. I'm Red Frog. And you are?

**FROG:** Frog.

**RED FROG:** Oh, so you do speak! I thought your coms were fried for a second. More of the strong and almost silent type eh.

**RED FROG:** Anyway, says here you're looking to renew your intergalactic travel lisence. Was the photo really that bad?

**FROG:** ...

**RED FROG:** Sorry just a little joke, guess it didn't land. Speaking of joke, this test should be a hop in the pond for someone like you.

**RED FROG:** I'm sure you have important research to do and I wouldn't want to waste your time. If you want, Gary from lisencing owes me a favor, well actually a few favors. 

**RED FROG:** I could have him check all the boxes for us. Oh, but also if you wanted some practice, I'm happy to administer.

**[Choice]**

**RED FROG:** Totally up to you
- > Start Tutorial
- > Cash in one of the Gary favors

*(Right now both choices continue the same way. The Gary path is still a TODO.)*

**[Center box]**

**RED FROG:** Great! This'll give us a chance to get to know eachother a little better!

**RED FROG:** First, we'll have to test out your ships maneuverability. Luckily there are a bunch of loose astroids just looking to be avoided.

**[Card: Movement]** *Movement video, with the W / A S D keys lighting up.*

*Challenge: "Avoid the astroids without losing all your health." About 40 seconds of small astroids, mostly falling top to bottom, with some crossing side to side.*

**Retry line [side]:**
**RED FROG:** Let's try that again. With less crashing this time.

---

## WAVE 1: JUMP

*Jumping unlocked. Still no shooting or absorbing.*

**[Center box]**

**RED FROG:** Says here your ship is equiped with hyperdimensional optimized propulsion. Oh I get it H.O.P.! Cause you're a frog.

**FROG:** ...

**FROG\*:** Seems like you have more a sense of humor than you let on. Would love to see H.O.P. in action! I don't think I've seen modifications this advance on such an old model.

**FROG\*:** Oh um, not old model like old old. I meant more like vintage. Or um distinguished.

> \* In the code, these last two lines have the speaker set to "Frog", so the game shows them under Frog's name. They read like Red Frog's lines. The first of the two also has its portrait set to `FLAG_PROCESS_THREAD_MESSAGES`, which isn't a face, instead of `FACE_RED`. I haven't changed either one.

**[Card: Jump]** *Press L to jump. After you land, the jump needs a moment to recharge before you can use it again.*

*Challenge: "Take damage fewer than 3 times." Three full rows of astroids, then two diagonal walls and a ring, all of which can only be jumped.*

**Fail line [side]** *(when the 3rd hit lands)*:
**RED FROG:** Oof that didn't look great for your deductible.

**Retry line [side]:**
**RED FROG:** Again. Jump OVER the rocks this time.

---

## WAVE 2: SHOOT

*Shooting unlocked. Jumping and absorbing are off.*

**[Center box]**

**RED FROG:** That was awesome! How you got a ship to jump in the vacuum of space, I'll never know. Now time to see what kind of firepower we are working with. Your ship has blasters right?

**FROG:** Yup.

**RED FROG:** Of course it does, that's regulation. Why don't you use those blasters to clear out some of this astroid field.

**RED FROG** *(neutral face)*: Funny story, I was actually supposed to clear these out this morning, but got trapped in a conversation with Gary. It was the kids again.

**RED FROG:** You'd actually be doing me a huge favor by clearing these out.

**[Card: Shoot]** *Hold J to fire. Damaging enemies fills your multiplier.*

*Challenge: "Destroy 10 astroids." A row of small astroids, then medium astroids that split, then two diagonal walls.*

*About 30 seconds in, a golden astroid comes down, stops a third of the way down the screen, and waits there to be shot.*

**[Side box]** *(as the golden astroid appears)*
**RED FROG:** Golden astroids, huh. Heard there's a wave of them. They're stocked full of quantum energy. Grabbing them is like snagging two flies with one tongue.

**Retry line [side]:**
**RED FROG:** Looks like there's still a lot more astroids to clear.

---

## WAVE 3: ABSORB

*Absorbing unlocked (K, plus the white absorb-ready outline). Shooting is on, jumping is off.*

**[Center box]**

**RED FROG:** Look you're ship's glowing. Is that another mod you added?

**FROG:** Phase absorption.

**RED FROG:** Genius! Hyper-grafting other ships parts for a temporary boost. That's pretty advanced tech. I'm not sure if I've even seen it before.

**RED FROG:** Luckily there are a bunch of old junk ships around you could try it on. Might make clearning the area even faster.

**[Card: Absorb]** *At 4x multiplier, press K to fire an absorb beam. Hit an enemy with it to take on its form for a while.*

*Challenge: "Absorb an enemy." A golden astroid, then a gray bee, keep dropping in random lanes until the player absorbs something. There's no retry line: the wave just keeps going until the absorb lands.*

---

## WAVE 3b: BUBBLES

*Three green target bubbles appear. The wave waits for the absorb from wave 3 to finish.*

**[Center box]** *(only if the player is transformed)*

**RED FROG:** Hmmmm, the changes aren't too drastic. I guess since it's using scrap ships, but your ship still seems a bit upgraded.

**[Card: Transformations]** *Transformations give you different boosts, but they're temporary. When your ship starts flashing, the transformation is about to run out.*

**[Card: Bubbles]** *While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble off your ship into the green bubbles to pop them.*

*Challenge: "Pop all 3 green bubbles with your bubble." The same golden astroid and gray bee drops as wave 3, plus random astroids falling.*

**[Side box]** *(when all 3 are popped)*
**RED FROG:** Pop, pop, pop. Look at you go.

---

## WAVE 5a: USING BUBBLES (JUMP)

*Everything unlocked from here on.*

**[Center box]**

**RED FROG:** Some weird astroid formations ahead. If I were taking this test, I'd hit the bombs in the center with a triple barrel flipturn switcheroo.

**RED FROG:** Kinda advanced for you so you may need to get a bit creative.

**[Card: Using Bubbles: Jump]** *Jump (L) on a bubble to pop it in a big explosion - and get its transformation back.*

*Challenge: "Destroy all 3 bombs by jumping on a bubble." Three bombs inside rings of armored astroids, with golden astroid and gray bee drops.*

**[Side box]** *(on success)*
**RED FROG:** Ha! Three bombs down. Not bad.

**Fail line [side]** *(a bomb set off the wrong way)*:
**RED FROG:** That one doesn't count. Land a jump on a bubble next to the bomb.

**Retry line [side]:**
**RED FROG:** Rings are back. Jump on a bubble and let it blow.

---

## WAVE 5b: USING BUBBLES (SHOOT)

**[Center box]**

**RED FROG:** More rings. Let's try a different trick this time.

**[Card: Using Bubbles: Shoot]** *Shoot (J) a bubble to power it up. A powered-up bubble damages the enemies it hits.*

*Challenge: "Destroy all 3 bombs with a shot-powered bubble." Same bomb rings.*

**[Side box]** *(on success)*
**RED FROG:** Kaboom. Love that.

**Fail line [side]:**
**RED FROG:** Doesn't count. Shoot the bubble to power it up, then bounce it into the bomb.

**Retry line [side]:**
**RED FROG:** One more time. Power it up, then send it in.

---

## WAVE 5c: USING BUBBLES (COMBINE)

**[Center box]**

**RED FROG:** One more set. Last trick, and it's my favorite.

**[Card: Using Bubbles: Combine]** *Combine two bubbles to get a permanent buff.*

*Challenge: "Destroy all 3 bombs with Penetrator Rounds." Same bomb rings. There's no success line.*

**Fail line [side]:**
**RED FROG:** Nope. Combine two bubbles, then shoot through the ring.

**Retry line [side]:**
**RED FROG:** Again. Combine first, then shoot.

---

## WAVE 6: FINAL EXAM

**[Center box]**

**RED FROG:** And check! Mandatory insurance requirements fullfilled. Now guess all that's left is for you to get out of this super dangerous astroid field.

**RED FROG:** Hmmmm looks like the next section is even more dangerous. Use everything I taught...

**RED FROG:** Err I guess use all the stuff you already knew to not die which would force me to do even more paper work.

*Challenge: "Make it to the end without losing all your health." There's no card. It runs in three parts: astroid columns with gaps, medium astroids and a gray hive; then jump walls with gray bees, and a big astroid ring with a bomb ring inside it; then bomb walls with medium astroids and two gray flowers.*

**Retry line [side]:**
**RED FROG:** Paperwork says you have to finish in one piece. From the top.

---

## WAVE 7: OUTRO

*The right panel clears.*

**[Center box]**

**RED FROG:** You made it?

**RED FROG:** I mean, you made it!

**RED FROG:** I knew you had it in you the whole time. If the whole time started five seconds ago.

**RED FROG:** That's enough of that. I'm outta here. Have a great day or night or whatever time it is in space.

*The level ends.*

---

## ANYTIME LINES

**When the player runs out of health** *(any wave; you can't die in the tutorial, so health refills right after)* **[side]:**
**RED FROG:** So you're actually supposed to avoid the giant boulders hurdling towards you.

**Default retry line** *(used if a wave doesn't set its own; currently none of them use it)* **[side]:**
**RED FROG:** Not quite. Let's run that one back.
