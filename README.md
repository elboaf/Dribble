Dribble - Druid Assistant Addon for Turtle WoW (1.12)

A smart companion for Druids to automate buffs, healing, and combat support in parties.
📜 Overview

Dribble is an intelligent assistant for Druids in Turtle WoW (1.12) that helps automate:
✅ Healing (smart rank selection for Healing Touch, Regrowth, Rejuvenation, Swiftmend)
✅ Buffs (Mark of the Wild, Thorns)
✅ Combat Assistance (Moonfire, Faerie Fire, Insect Swarm, Wrath)
✅ Stealth Coordination (follows stealthed party members in Cat/Prowl form)
✅ Emergency Crowd Control (Hibernate on gouged targets)
🎯 Key Features
1️⃣ Smart Healing System

    Prioritizes missing health + incoming HoT healing to avoid overhealing.

    Auto-selects best spell rank based on missing HP and mana efficiency.

    HoT Tracking: Predicts remaining healing from Rejuvenation & Regrowth.

    Swiftmend Optimization: Uses Swiftmend efficiently when HoTs are about to expire.

2️⃣ Buff Management

    Automatically applies:

        Mark of the Wild (when missing)

        Thorns (when missing)

    Can optionally buff party pets (/dribblepetbuffs to toggle).

3️⃣ Combat Assistance

    Damage Spells: Casts Moonfire, Faerie Fire, Insect Swarm, and Wrath on party targets.

    Avoids breaking CC: Won't attack hibernated/gouged targets.

    Mana Conservation: Stops DPS below 50% mana (configurable).

4️⃣ Stealth & Follow Support

    Follows party members (/dribblefollow to toggle).

    Auto-enter Cat Form + Prowl when following a stealthed party member.

    Leaves Prowl if the party member exits stealth.

5️⃣ Emergency Crowd Control

    Auto-Hibernate on gouged beasts/dragonkin (prevents accidental breaks).

🔧 Slash Commands (User Controls)
Command	Function
/dribble	Runs all automated checks (healing, buffs, combat)
/dribblefollow	Toggle auto-follow mode
/dribblefollowtarget [1-4]	Set which party member to follow
/dribbledps	Toggle damage spell casting
/dribblepetbuffs	Toggle pet buffing
/dribblerejuv	Toggle Rejuvenation usage
/dribbleregrowth	Toggle Regrowth usage
/dribbleht	Toggle Healing Touch usage
/dribblemoonfire	Toggle Moonfire usage
/dribblefaeriefire	Toggle Faerie Fire usage
/dribbleinsectswarm	Toggle Insect Swarm usage
/dribblewrath	Toggle Wrath usage
/dribbleswiftmend	Toggle Swiftmend usage
⚙️ Configuration & Thresholds

    Healing Thresholds:

        Healing Touch below 50% HP

        Regrowth below 60% HP

        Rejuvenation below 70% HP

        Swiftmend below 60% HP (or HoT about to expire)

    Minimum Mana for DPS: 50% (prevents OOM situations)

📌 Notes for Users

✔ Works in parties (not designed for solo play).
✔ Avoids breaking CC (won't attack hibernated/gouged targets).
✔ Smart HoT tracking reduces overhealing.
✔ Follow mode helps in dungeons/stealth runs.
🔹 Final Thoughts

Dribble is a lightweight, efficient addon that helps Druids focus on gameplay rather than micromanaging buffs and heals. It adapts to your playstyle with toggleable features, making it useful for both casual and hardcore players.

Happy adventuring! 🌿🐾
