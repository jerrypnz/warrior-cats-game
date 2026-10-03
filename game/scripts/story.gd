class_name Story
extends RefCounted
## Everything the cats say, for each part of the story.
## Words in {curly brackets} get filled in: {me} = your name right now, {paw} = apprentice name,
## {warrior} = warrior name, {kp} = kittypet name, {virtue} = what your personality is good at.

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

## The apprentice ceremony when you first arrive in camp
const JOIN_LINES := [
	["Bluestar", "Let all cats old enough to catch their own prey gather beneath the Highrock!"],
	["Bluestar", "This kittypet wants to join ThunderClan and train to be a warrior."],
	["Longtail", "A kittypet?! Ha! It still smells like Twoleg food!"],
	["Bluestar", "Hush, Longtail. From this day on, this apprentice will be known as {paw}!"],
	["Bluestar", "And I will be {paw}'s mentor myself."],
]
const JOIN_AFTER_LINES := [
	["Graypaw", "Yay! We're both apprentices now! Don't worry about Longtail, he's just grumpy."],
	["Bluestar", "Come and find me by the Highrock when you're ready for your first lesson."],
]

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
}

## What Cinderpaw says when you talk to her
const CINDERPAW_CHATS := ["You're the best mentor in the whole forest!", "I practiced my pounce all morning!",
		"Do you think I'll be a warrior one day?", "Let's do something fun!"]

const WARRIOR_CHATS := {
	"Tigerclaw": ["Hmph. You did well, {me}. I suppose you're a real warrior now."],
	"Longtail": ["Fine, fine. You're a real warrior. I'm sorry I called you a kittypet."],
	"Graystripe": ["Want to go hunting together, {me}?", "Warriors get to stay up all night guarding the camp. So cool!"],
	"Dustpaw": ["You're a warrior already?! No fair!"],
}


static func fill(text: String) -> String:
	return text.format({
		"me": GameState.cat_name(),
		"paw": GameState.apprentice_name(),
		"warrior": GameState.warrior_name(),
		"kp": GameState.KITTYPET_NAME,
		"virtue": GameState.personality().virtue,
	})


## Fills in names for a whole list of [speaker, text] lines
static func lines(raw: Array) -> Array:
	var out := []
	for line in raw:
		out.append([fill(line[0]), fill(line[1])])
	return out


## Graypaw gets his warrior name at the end of the story, too
static func display_name(cat_name: String) -> String:
	if cat_name == "Graypaw" and GameState.is_warrior():
		return "Graystripe"
	if cat_name == "Cinderkit" and GameState.has_apprentice:
		return "Cinderpaw"
	return cat_name
