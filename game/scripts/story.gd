class_name Story
extends RefCounted
## Everything the cats say, for each part of the story.
## Words in {curly brackets} get filled in: {me} = your name right now, {paw} = apprentice name,
## {warrior} = warrior (or medicine cat) name, {leader} = leader name, {kp} = kittypet name,
## {virtue} = what your personality is good at, {deputy} = the deputy you picked.

## What the cat in camp says right before a story step starts
const START_LINES := {
	"hunt_lesson": [
		["Bluestar", "Ready for your first lesson, {paw}? A warrior always feeds the Clan first."],
		["Bluestar", "Let's go hunting! Catch 5 mice for the elders."],
	],
	"battle_lesson": [
		["Bluestar", "Today we'll practice battle moves in the training hollow. Just you and me!"],
		["Bluestar", "Don't worry, we keep our claws in when we practice. Dodge my leaps, and pounce on me when I'm tired!"],
	],
	"patrol": [
		["Lionheart", "Hello, {paw}! Graypaw, Ravenpaw and I are going on border patrol. Want to come?"],
		["Lionheart", "We'll visit ThunderClan's special places and leave scent markers. Stay close to the group!"],
	],
	"yellowfang": [
		["Bluestar", "{paw}, you've trained hard. Today you may hunt on your own."],
		["Bluestar", "Go to the forest near Snakerocks. But be careful... I smell a stranger in our territory."],
	],
	"rescue": [
		["Bluestar", "Take Graypaw and follow the kits' scent into ShadowClan territory."],
		["Bluestar", "Stay hidden in the shadows! I'll bring our warriors right behind you."],
	],
	"ceremony": [
		["Bluestar", "{paw}, Graypaw, come to the Highrock. You have both shown great courage."],
		["Bluestar", "It is time for your warrior ceremony!"],
	],
}

## What happens when you come back to camp after a story step
const RETURN_LINES := {
	"hunt_lesson": [
		["Bluestar", "Great hunting, {paw}! Take a mouse to the elders. They'll love it."],
		["Smallear", "Mmm, a juicy mouse! Thank you, young one!"],
	],
	"battle_lesson": [
		["Bluestar", "Excellent fighting, {paw}! Your {virtue} really showed today."],
		["Tigerclaw", "Hmph. Not bad... for a kittypet."],
	],
	"patrol": [
		["Lionheart", "What a great patrol! You kept up with the group the whole way."],
		["Graypaw", "That was SO fun! Did you see that RiverClan cat's face?"],
	],
	"yellowfang": [
		["Bluestar", "Yellowfang may stay in camp until her leg is better. Spottedleaf will look after her."],
		["Yellowfang", "Hmph. Thank you, {paw}. You're kinder than most cats."],
		["", "That night, while everyone was asleep..."],
		["Frostfur", "HELP! My kits are gone! Cinderkit and Brightkit are missing!"],
		["Tigerclaw", "And Yellowfang is gone too! I KNEW we couldn't trust her!"],
		["{paw}", "No! Yellowfang wouldn't take kits. I'm sure of it!"],
		["Spottedleaf", "I smell ShadowClan by the camp wall... ShadowClan took the kits!"],
		["Bluestar", "{paw}, come and talk to me. We must get those kits back!"],
	],
	"rescue": [
		["Frostfur", "My kits! You brought them home! Thank you, {paw}!"],
		["Bluestar", "Brokenstar has been chased out of ShadowClan, thanks to Yellowfang's help."],
		["Bluestar", "Yellowfang, ThunderClan would be honored if you stayed and helped Spottedleaf as a medicine cat."],
		["Yellowfang", "Hmph... I suppose I could stay. Somebody has to keep you young cats out of trouble!"],
		["Bluestar", "{paw}, come to the Highrock. I have something important to tell you."],
	],
	"ceremony": [
		["Graystripe", "We're WARRIORS now, {warrior}! Let's go sleep in the warriors' den!"],
	],
}

## Medicine cat apprentices hear different words for some parts of the story
const MEDICINE_START_LINES := {
	"herb_lesson": [
		["Spottedleaf", "Welcome to your first lesson, {paw}! A medicine cat must know every herb in the forest."],
		["Spottedleaf", "Let's go herb hunting! I'll tell you which plants to find."],
	],
	"healing_lesson": [
		["Spottedleaf", "Some of our Clanmates aren't feeling well today. Let's help them!"],
		["Spottedleaf", "Listen to what's wrong, then give them the right herb from our store."],
	],
	"patrol": [
		["Lionheart", "Hello, {paw}! Spottedleaf says a medicine cat should know every corner of the territory."],
		["Lionheart", "So come on border patrol with Graypaw, Ravenpaw and me! Stay close to the group!"],
	],
	"yellowfang": [
		["Spottedleaf", "{paw}, StarClan sent me a dream... a hurt cat is hiding near Snakerocks."],
		["Spottedleaf", "Take some herbs and go help her. You're ready!"],
	],
	"medicine_ceremony": [
		["Spottedleaf", "{paw}, you have learned so much. Tonight we travel to the Moonstone."],
		["Spottedleaf", "There, StarClan will welcome you as a real medicine cat!"],
	],
}
const MEDICINE_RETURN_LINES := {
	"herb_lesson": [
		["Spottedleaf", "Wonderful herb hunting, {paw}! Our medicine den is full of good things now."],
		["Graypaw", "It smells like a flower garden in here! Achoo!"],
	],
	"healing_lesson": [
		["Spottedleaf", "You picked just the right herbs, {paw}! Your {virtue} will make you a great healer."],
		["Smallear", "My tummy feels SO much better. Thank you, young one!"],
	],
	"rescue": [
		["Frostfur", "My kits! You brought them home! Thank you, {paw}!"],
		["Bluestar", "Brokenstar has been chased out of ShadowClan, thanks to Yellowfang's help."],
		["Bluestar", "Yellowfang, ThunderClan would be honored if you stayed and helped Spottedleaf as a medicine cat."],
		["Yellowfang", "Hmph... I suppose I could stay. Somebody has to keep you young cats out of trouble!"],
		["Spottedleaf", "{paw}, come and see me. I have something important to tell you!"],
	],
	"medicine_ceremony": [
		["Graystripe", "{warrior}! I got my warrior name while you were at the Moonstone. I'm Graystripe now!"],
		["Graystripe", "And you're a real medicine cat! Can you fix my sore paw? Hee hee."],
	],
}

## The apprentice ceremony when you first arrive in camp
const JOIN_LINES := [
	["Bluestar", "Let all cats old enough to catch their own prey gather beneath the Highrock!"],
	["Bluestar", "This kittypet wants to join ThunderClan."],
	["Longtail", "A kittypet?! Ha! It still smells like Twoleg food!"],
	["Spottedleaf", "Hush, Longtail. Bluestar, last night StarClan showed me a sign... this cat has a special path."],
	["Bluestar", "Warriors hunt and guard the Clan, and one day one of them might even become leader."],
	["Spottedleaf", "Medicine cats heal sick cats with herbs and share dreams with StarClan. But they can never be leader."],
]
const JOIN_QUESTION := "{kp}, which path will you follow?"
const JOIN_ANSWERS := ["Warrior!", "Medicine cat!"]
const JOIN_NAMED_LINES := {
	"warrior": [
		["Bluestar", "A warrior! From this day on, this apprentice will be known as {paw}!"],
		["Bluestar", "And I will be {paw}'s mentor myself."],
	],
	"medicine": [
		["Bluestar", "A medicine cat! From this day on, this apprentice will be known as {paw}!"],
		["Spottedleaf", "And I will be {paw}'s mentor. Welcome to the medicine den!"],
	],
}
const JOIN_AFTER_LINES := {
	"warrior": [
		["Graypaw", "Yay! We're both apprentices now! Don't worry about Longtail, he's just grumpy."],
		["Bluestar", "Come and find me by the Highrock when you're ready for your first lesson."],
	],
	"medicine": [
		["Graypaw", "A medicine cat apprentice? Cool! You can fix my sore paws after training!"],
		["Spottedleaf", "Come and find me when you're ready for your first lesson. I'm usually near the medicine den."],
	],
}

## Big news in camp after the story is over
const NEWS_LINES := {
	"graduate": [
		["Bluestar", "Let all cats old enough to catch their own prey gather beneath the Highrock!"],
		["Bluestar", "{me} has taught Cinderpaw very well. Cinderpaw, step forward!"],
		["Bluestar", "Cinderpaw, from this moment you will be known as Cinderpelt!"],
	],
	"graduate_after": [
		["Cinderpelt", "Thank you, {me}! You were the BEST mentor in the whole forest!"],
	],
	"deputy": [
		["Bluestar", "{me}, I have news. Lionheart has decided to rest his old paws in the elders' den."],
		["Lionheart", "It's true! I'm looking forward to long naps and stories with the other elders."],
		["Bluestar", "So ThunderClan needs a new deputy. The warrior code says a deputy must have trained an apprentice."],
		["Bluestar", "You trained Cinderpelt, and you have always been brave and true."],
		["Bluestar", "I say these words before StarClan: {me} will be the new deputy of ThunderClan!"],
	],
	"deputy_after": [
		["Tigerclaw", "Hmph. I wanted to be deputy... but fine. You've earned it, {me}."],
		["Bluestar", "A deputy leads patrols for the Clan. Go out the gorse tunnel and lead {tasks} patrols!"],
	],
	"leader": [
		["Bluestar", "{me}, you have been a wonderful deputy. I am proud of you."],
		["Bluestar", "I have led ThunderClan for many, many moons. My paws are tired, and the elders' den looks so cozy."],
		["Bluestar", "It is time for a new leader. Go to the Moonstone with Spottedleaf..."],
		["Bluestar", "...and StarClan will give you nine lives and your leader name!"],
	],
	"head": [
		["Spottedleaf", "{me}, you have learned everything I know. And you've even taught Cinderpelt!"],
		["Spottedleaf", "I'm getting old, and the elders' den has the sunniest spot in camp."],
		["Spottedleaf", "So from now on, YOU are ThunderClan's medicine cat!"],
		["Yellowfang", "Hmph. Don't worry, I'll still help. Somebody has to keep you out of trouble."],
	],
	"head_after": [
		["Spottedleaf", "Help sick cats in the medicine den, and gather herbs through the gorse tunnel. StarClan is with you!"],
	],
	"nine_lives": [
		["Graystripe", "{me}! You're back! Did StarClan really give you NINE lives?"],
		["Bluestar", "Welcome home, {leader}. ThunderClan is in good paws."],
		["Bluestar", "Now, a new leader must choose a deputy before moonhigh. Who will it be?"],
	],
}
## Cats you can choose as your deputy when you become leader
const DEPUTY_CHOICES := ["Graystripe", "Whitestorm", "Cinderpelt"]

## Things cats say when you chat with them. [before battle practice, after battle practice]
const CHATS := {
	"Graypaw": ["Want to share a mouse later?", "Tigerclaw is SO scary. But he's a great warrior.",
			"I hope we become warriors at the same time!"],
	"Ravenpaw": ["H-hi, {me}. Tigerclaw is my mentor... he's very strict.", "I like the quiet places in the forest."],
	"Tigerclaw": ["Hmph. Kittypets don't belong in the Clan.", "Train hard, apprentice. Or go back to your Twolegs."],
	"Lionheart": ["Graypaw is my apprentice. He's a good cat, but SO noisy!", "Always remember the warrior code, {me}."],
	"Spottedleaf": ["I'm the medicine cat. I use herbs to help sick cats feel better.",
			"StarClan sends me signs... I think you have a special path, {me}."],
	"Longtail": ["Hmph. Kittypet.", "Why are you looking at me? Go catch a mouse or something."],
	"Frostfur": ["Shh, my kits are napping.", "Thank you for helping keep ThunderClan safe."],
	"Cinderkit": ["When I'm an apprentice, I want YOU to be my mentor!", "Let's play hunting! I'll be the mouse!"],
	"Brightkit": ["Is it true you used to be a kittypet? What's Twoleg food like?", "Wheee! Chase me!"],
	"Smallear": ["When I was young, I caught a fish with my bare paws!", "Ahh, my old bones love the warm sun."],
	"Sandpaw": ["Hmph, a kittypet apprentice? We'll see who's the better hunter!", "Okay... maybe you ARE a good hunter."],
	"Dustpaw": ["I'm going to be a warrior before you, kittypet!", "Sandpaw and I are the best apprentices. Well... we WERE."],
	"Yellowfang": ["Stop staring and fetch me some moss, youngster!", "Hmph. You're not so bad, {me}."],
	"Bluestar": ["StarClan is watching over you, {me}.", "Remember: a warrior protects the Clan and helps cats in need."],
}
const DEN_CHATS := {
	"Darkstripe": ["Hmph. What do you want?", "Tigerclaw is the greatest warrior in the whole forest."],
	"Brackenkit": ["Shh! Goldenflower is sleeping!", "I'm going to be the bravest warrior EVER!"],
	"Halftail": ["Want to hear a story? Long ago, LionClan and TigerClan lived in the forest!",
			"When I was young, I chased a dog all the way back to Twolegplace!"],
	"Cinderpaw": ["This is the best den ever!", "Let's go on an adventure, {me}!"],
	"Bluestar": ["I'm so proud of you, {me}. ThunderClan is in good paws.", "Being an elder is wonderful. So many naps!"],
	"Lionheart": ["Ahh, no more dawn patrols for me!", "How is my old apprentice Graystripe doing?"],
	"Spottedleaf": ["I hear you're a wonderful medicine cat, {me}.", "The sun is so warm in here!"],
}

## What Cinderpaw says when you talk to her
const CINDERPAW_CHATS := ["You're the best mentor in the whole forest!", "I practiced my pounce all morning!",
		"Do you think I'll be a warrior one day?", "Let's do something fun!"]
const CINDERPAW_MEDICINE_CHATS := ["Marigold for scratches... catmint for coughs... I remembered!",
		"You're the best mentor in the whole forest!", "I want to be a great healer, just like you!",
		"Let's do something fun!"]

## What the cats say once you're grown up (these win over CHATS)
const GROWN_CHATS := {
	"Tigerclaw": ["Hmph. You did well, {me}. I suppose you're a real warrior now."],
	"Longtail": ["Fine, fine. You're a real warrior. I'm sorry I called you a kittypet."],
	"Graystripe": ["Want to go hunting together, {me}?", "Warriors get to stay up all night guarding the camp. So cool!"],
	"Dustpaw": ["You're a warrior already?! No fair!"],
	"Cinderpelt": ["I still remember everything you taught me, {me}!", "Want to share a mouse?"],
	"Brightpaw": ["My mentor is teaching me SO much!", "Thank you for making me an apprentice, {me}!"],
}
const MEDICINE_CHATS := {
	"Spottedleaf": ["Remember: marigold for scratches, catmint for coughs!", "StarClan shares dreams with medicine cats, {me}."],
	"Yellowfang": ["Hmph. You're not a bad healer, {me}.", "Watch out for deathberries. Those red ones make cats VERY sick!"],
	"Tigerclaw": ["Hmph. A kittypet medicine cat. Well... my scratch did heal fast."],
	"Longtail": ["Got any honey? My throat's scratchy. Not that I need help from YOU."],
}
const LEADER_CHATS := {
	"Tigerclaw": ["Yes, {me}. I'll lead the dawn patrol.", "Hmph. You make a fine leader. Don't tell anyone I said that."],
	"Longtail": ["I'm sorry I ever called you a kittypet, {me}!"],
	"Graystripe": ["You're LEADER now! I always knew you'd be amazing, {me}!"],
	"Whitestorm": ["ThunderClan is lucky to have you, {me}."],
	"Frostfur": ["My kits want to be just like you when they grow up, {me}!"],
}
## What your friends from other save slots say
const FRIEND_CHATS := ["Hi, best friend! What should we do?", "I'm so happy to see you, {me}! What should we do today?",
		"Guess what? I saw a HUGE squirrel! Want to do something together?", "Hello, {me}! Let's play!"]

## The deputy you chose
const DEPUTY_CHAT := ["I'll be the best deputy ever, {me}!", "The patrols are all ready, {me}!"]


static func fill(text: String) -> String:
	return text.format({
		"me": GameState.cat_name(),
		"paw": GameState.apprentice_name(),
		"warrior": GameState.warrior_name(),
		"leader": GameState.leader_name(),
		"kp": GameState.KITTYPET_NAME,
		"virtue": GameState.personality().virtue,
		"deputy": GameState.deputy_name,
		"tasks": GameState.DEPUTY_TASKS,
	})


## What the cat in camp says before this part of the story starts
static func start_lines(id: String) -> Array:
	if GameState.is_medicine() and MEDICINE_START_LINES.has(id):
		return lines(MEDICINE_START_LINES[id])
	return lines(START_LINES[id])


## What happens back in camp after a part of the story (empty if nothing)
static func return_lines(id: String) -> Array:
	if GameState.is_medicine() and MEDICINE_RETURN_LINES.has(id):
		return lines(MEDICINE_RETURN_LINES[id])
	return lines(RETURN_LINES.get(id, []))


## Something a cat in camp says when you chat with them
static func chat(cat_name: String) -> String:
	var gs := GameState
	if cat_name == gs.deputy_name and gs.is_leader():
		return fill(DEPUTY_CHAT.pick_random())
	return fill(chat_options(cat_name, gs.is_grown(), gs.is_medicine(), gs.is_leader()).pick_random())


## The things a Clan cat might say to a cat of this rank (lines still have {me} in them)
static func chat_options(cat_name: String, grown: bool, medicine: bool, leader: bool) -> Array:
	var lists := [CHATS]
	if grown:
		lists.push_front(GROWN_CHATS)
	if medicine:
		lists.push_front(MEDICINE_CHATS)
	if leader:
		lists.push_front(LEADER_CHATS)
	for list: Dictionary in lists:
		if list.has(cat_name):
			return list[cat_name]
	return CHATS.Graypaw


## Fills in names for a whole list of [speaker, text] lines
static func lines(raw: Array) -> Array:
	var out := []
	for line in raw:
		out.append([fill(line[0]), fill(line[1])])
	return out


## Graypaw gets his warrior name at the end of the story, too
static func display_name(cat_name: String) -> String:
	if cat_name == "Graypaw" and GameState.is_grown():
		return "Graystripe"
	if cat_name == "Cinderkit" and GameState.has_apprentice:
		return "Cinderpelt" if GameState.apprentice_graduated else "Cinderpaw"
	if cat_name == "Brightkit" and GameState.brightpaw_mentor != "":
		return "Brightpaw"
	return cat_name
